#!/usr/bin/env python3
"""Harvest every SQL statement out of the SQF into sqlcorpus/corpus.json.

The corpus (400 statements when this script was written) predates this file:
its original producer was never committed and re-harvesting was a lost manual
step -- the one real gap a 2026-08-20 survey found in the migration tooling.
This is that producer, rebuilt, and it doubles as the extractor for the
MySQL-ism lint (tools/run_checks.sh): both need "the SQL string literals in
the SQF, with format placeholders intact, and nothing from comments".

What counts as a statement:
  * an SQF double-quoted string literal ("" is the escape, never \\")
  * outside // and /* */ comments
  * whose first word is an SQL verb (SELECT/INSERT/UPDATE/DELETE/REPLACE/
    ALTER/CREATE/CALL/DROP/TRUNCATE)
  * with adjacent `+`-concatenated string literals folded in, because the
    DATE_FORMAT statements are deliberately built by concatenation -- SQF
    `format` eats %b/%e/%H/%i (see fn_loonerSRV.sqf:30) -- and a harvest
    that splits them ships half a statement to the PREPARE gate.

Line numbers are where the statement STARTS. `%N` placeholders stay verbatim;
realising them into executable SQL is test_apdb_sql.realise()'s job, not ours.

Usage:
    python3 harvest_corpus.py                 # rewrite sqlcorpus/corpus.json
    python3 harvest_corpus.py --check         # exit 1 if corpus.json is stale
    python3 harvest_corpus.py --diff OLD.json # report added/removed vs OLD
    python3 harvest_corpus.py --print         # dump statements to stdout

The corpus is sorted (file, line) so the diff against git is stable.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

#: Where SQL lives. mission/ ships ArmaQuest's store and the quest profile
#: closures; everything else is the server addon.
ROOTS = ("server", "mission")

VERB = re.compile(
    r"^\s*(SELECT|INSERT|UPDATE|DELETE|REPLACE|ALTER|CREATE|CALL|DROP|TRUNCATE)\b",
    re.I)

#: UPDATE is also an English word ("UPDATE the marker...") and CREATE/DELETE
#: appear in UI strings. A statement has to look like SQL, not merely start
#: like it: require a second SQL-ish token somewhere after the verb.
SQLISH = re.compile(
    r"\b(FROM|INTO|SET|TABLE|WHERE|VALUES|JOIN|INDEX|COLUMN|IGNORE|"
    r"UNIX_TIMESTAMP|CONVERT_TZ|"          # bare-expression SELECTs (boot clock, restart window)
    r"resetLifeVehicles|resetAusVehicles|updateLifeHouses)\b", re.I)


def _strings(text):
    """Yield (line, literal, end_index) for every SQF string literal outside
    comments. Doubled "" inside a literal is one quote character."""
    i, n, line = 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            seg = text[i:(n if j < 0 else j + 2)]
            line += seg.count("\n")
            i = n if j < 0 else j + 2
        elif c == '"':
            start_line, j, out = line, i + 1, []
            while j < n:
                if text[j] == '"':
                    if j + 1 < n and text[j + 1] == '"':
                        out.append('"')
                        j += 2
                        continue
                    break
                if text[j] == "\n":
                    line += 1
                out.append(text[j])
                j += 1
            yield start_line, "".join(out), j + 1
            i = j + 1
        else:
            i += 1


def harvest_file(path):
    """Every SQL statement in one file, `+`-concatenation folded.

    A fold chain that continues into a NON-literal (`+ str(_x) + ...`) cannot
    be completed from source text alone; the entry is marked partial so the
    PREPARE gate skips it instead of failing on half a statement -- it then
    needs dbSoak/rig coverage exactly like a dynamic-table statement.
    """
    text = open(path, encoding="utf-8", errors="replace").read()
    found = []
    lits = list(_strings(text))
    k = 0
    while k < len(lits):
        line, lit, end = lits[k]
        if VERB.match(lit) and SQLISH.search(lit):
            sql, cursor, partial = [lit], end, False
            # fold `+ "..."` chains: between this literal's end and the next
            # literal there must be only whitespace and a single `+`.
            while k + 1 < len(lits):
                nline, nlit, nend = lits[k + 1]
                # scan raw text from this literal's end to the next quote char
                j = cursor
                gap = []
                while j < len(text) and text[j] != '"':
                    gap.append(text[j])
                    j += 1
                gap = "".join(gap)
                stripped = gap.strip()
                if stripped == "+":
                    sql.append(nlit)
                    cursor = nend
                    k += 1
                elif stripped.startswith("+"):
                    partial = True   # continues into an expression we cannot see
                    break
                else:
                    break
            entry = {"line": line, "sql": "".join(sql)}
            if partial:
                entry["partial"] = True
            found.append(entry)
        k += 1
    return found


def harvest():
    entries = []
    for root in ROOTS:
        for dirpath, dirnames, filenames in os.walk(os.path.join(REPO, root)):
            dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules", "pysqf")]
            # core/pysqf/ is the VENDORED transport (generated files); its SQL
            # strings are conformance fixtures, not game statements.
            for fn in filenames:
                if not fn.endswith(".sqf"):
                    continue
                if fn == "fn_dbSoak.sqf":
                    # the soak harness's own statements run against a scratch
                    # table that exists only mid-run; they are self-verifying
                    # fixtures, not game statements -- same policy as core/pysqf
                    continue
                path = os.path.join(dirpath, fn)
                rel = os.path.relpath(path, REPO)
                for hit in harvest_file(path):
                    e = {"file": rel.replace(os.sep, "/"),
                         "line": hit["line"], "sql": hit["sql"]}
                    if hit.get("partial"):
                        e["partial"] = True
                    entries.append(e)
    # one entry per distinct statement text, first occurrence wins -- the
    # corpus is a statement catalogue, not a call-site index.
    seen, out = set(), []
    for e in sorted(entries, key=lambda e: (e["file"], e["line"])):
        if e["sql"] in seen:
            continue
        seen.add(e["sql"])
        out.append(e)
    return out


MYSQLISM = re.compile(
    r"QUOTE\s*\(|`|\bINSERT\s+IGNORE\b|\bON\s+DUPLICATE\b|\bREPLACE\s+INTO\b|"
    r"\bLIMIT\s+%?\d+\s*,|\bCURDATE\b|\bUNIX_TIMESTAMP\b|\bDATE_FORMAT\b|"
    r"\bCONVERT_TZ\b|\bFIND_IN_SET\b|\bAUTO_INCREMENT\b|\bTINYINT\b|"
    r"\bIFNULL\b|\bDATEDIFF\b|\bTIMESTAMPDIFF\b|\bSTRAIGHT_JOIN\b|"
    r"\bDATE_SUB\b|\bDATE_ADD\b|AS\s+SIGNED|AS\s+UNSIGNED|\bCALL\s+\w+\s*\(",
    re.I)


def lint(fresh):
    """T3: the permanent sweep gate. Every harvested statement must be free of
    MySQL-isms -- the port is DONE and this is what keeps it done. Uses the
    same extractor as the harvest, so comments cannot false-positive."""
    bad = 0
    for e in fresh:
        m = MYSQLISM.search(e["sql"])
        if m:
            print("MYSQLISM %s:%d [%s]: %s" % (e["file"], e["line"],
                                               m.group(0).strip(), e["sql"][:110]))
            bad += 1
    print("-- lint: %s" % ("clean" if not bad else "%d statements carry MySQL-isms" % bad))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lint", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--diff", metavar="OLD_JSON")
    ap.add_argument("--print", dest="do_print", action="store_true")
    args = ap.parse_args()

    corpus_path = os.path.join(os.path.dirname(__file__), "sqlcorpus", "corpus.json")
    fresh = harvest()

    if args.lint:
        return 1 if lint(fresh) else 0

    if args.do_print:
        for e in fresh:
            print("%s:%d: %s" % (e["file"], e["line"], e["sql"]))
        print("-- %d statements" % len(fresh), file=sys.stderr)
        return 0

    if args.diff:
        old = {e["sql"] for e in json.load(open(args.diff))}
        new = {e["sql"] for e in fresh}
        for s in sorted(old - new):
            print("REMOVED: %s" % s[:140])
        for s in sorted(new - old):
            print("ADDED:   %s" % s[:140])
        print("-- old %d, fresh %d, common %d" % (len(old), len(new), len(old & new)))
        return 0

    if args.check:
        current = json.load(open(corpus_path)) if os.path.exists(corpus_path) else []
        if len(fresh) <= 350:
            print("corpus FLOOR breached: only %d statements harvested" % len(fresh))
            return 1
        if {e["sql"] for e in current} == {e["sql"] for e in fresh}:
            print("corpus.json is current (%d statements)" % len(fresh))
            return 0
        print("corpus.json is STALE: %d on disk, %d harvested -- rerun harvest_corpus.py"
              % (len(current), len(fresh)))
        return 1

    if len(fresh) <= 350:
        print("REFUSING to write: only %d statements harvested (floor 350) -- "
              "the extractor is broken, not the codebase smaller" % len(fresh))
        return 1
    json.dump(fresh, open(corpus_path, "w"), indent=1)
    print("wrote %d statements to %s" % (len(fresh), corpus_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
