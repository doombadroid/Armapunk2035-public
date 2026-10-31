#!/usr/bin/env python3
"""PREPARE gate: every realisable corpus statement must be valid PostgreSQL.

PREPARE proves syntax and that every named column exists; it does NOT prove a
statement does the right thing (dbdiff.py's job) or that its call site sends
sane values (dbSoak's job). It is the cheapest gate with real teeth, so it
runs per port batch and repo-wide.

Placeholder handling is realise.py's (extracted from the retired translator's suite) --
because the two must agree about which statements are realisable. The
UNREALISABLE set (dynamic table / SET / WHERE) is REPORTED, not hidden: those
are exactly the highest-risk hand-ports and each must be covered by dbSoak or
the equivalence rig instead. The report is the contract.

One mode since Phase T: the corpus text IS what executes.

Statements are gated with EXPLAIN -- it parses AND plans without executing,
for SELECT and DML alike, and unlike PREPARE it leaves nothing behind in the
session (a PREPAREd name survives rollback; the first draft of this gate
found that out 221 times). realise()'s quoted placeholder becomes '1', not
'x': the planner type-checks literals, and '1' satisfies integer and text
columns both. DDL (ALTER/CREATE/DROP) cannot be EXPLAINed without executing
-- reported as DDL and left to the runtime-DDL port batch's own tests.

    PYSQF_DB_DSN="host=... dbname=..." python3 prepare_gate.py [--native]
    python3 prepare_gate.py --files server/AP_server/core/DB/fn_queryRequest.sqf ...
                                     # gate only statements harvested from these files
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pysqf_modules"))

from realise import realise                                    # noqa: E402

CORPUS = os.path.join(HERE, "sqlcorpus", "corpus.json")

DDL = re.compile(r"^\s*(ALTER|CREATE|DROP|TRUNCATE)\b", re.I)
SELECT = re.compile(r"^\s*SELECT\b", re.I)


def connect():
    import psycopg
    dsn = os.environ.get("PYSQF_DB_DSN", "")
    if not dsn:
        print("PYSQF_DB_DSN is not set -- this gate needs the dev PostgreSQL", file=sys.stderr)
        sys.exit(2)
    if "scratch" not in dsn:
        # same refusal dbdiff.py carries: never point a gate at anything that
        # is not visibly a scratch database.
        print("refusing: PYSQF_DB_DSN's dbname does not look like a scratch DB", file=sys.stderr)
        sys.exit(2)
    return psycopg.connect(dsn, autocommit=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--files", nargs="*", default=None,
                    help="gate only statements harvested from these repo-relative files")
    args = ap.parse_args()

    corpus = json.load(open(CORPUS, encoding="utf-8"))
    if args.files:
        wanted = set(args.files)
        corpus = [e for e in corpus if e["file"] in wanted]
        if not corpus:
            print("no corpus statements from the named files -- re-harvest first?")
            return 2

    conn = connect()
    ok, failed, unrealisable, ddl = 0, [], [], 0
    expected_path = os.path.join(HERE, "sqlcorpus", "expected_failures.json")
    expected = set(json.load(open(expected_path))) if os.path.exists(expected_path) else set()
    expected_hit = set()

    for entry in corpus:
        sql = entry["sql"]
        if DDL.match(sql):
            ddl += 1
            continue
        if entry.get("partial"):
            unrealisable.append(entry)   # half a statement; needs dbSoak/rig coverage
            continue
        real = realise(sql)
        if real is None:
            unrealisable.append(entry)
            continue
        real = real.replace("'x'", "'1'")   # planner type-checks literals; '1' fits int and text
        probe = "EXPLAIN %s" % real
        try:
            with conn.cursor() as cur:
                cur.execute(probe)
            ok += 1
        except Exception as exc:  # noqa: BLE001 -- every failure is a finding
            if sql in expected:
                expected_hit.add(sql)    # a known port-pending statement; tracked, not red
            else:
                failed.append((entry, str(exc).split("\n")[0]))
        finally:
            conn.rollback()      # DEALLOCATE + discard any planner state

    print("-- prepare gate (native): %d ok, %d failed, %d unrealisable, %d DDL"
          % (ok, len(failed), len(unrealisable), ddl))
    for entry, msg in failed:
        print("FAIL %s:%d\n     %s\n     -> %s" % (entry["file"], entry["line"],
                                                   entry["sql"][:160], msg))
    if unrealisable:
        print("-- unrealisable (dynamic table/clause; MUST appear in dbSoak or the rig):")
        for entry in unrealisable:
            print("   %s:%d: %s" % (entry["file"], entry["line"], entry["sql"][:120]))

    if expected and not args.files:
        # staleness is only assessable on a FULL run: a --files scope that never
        # executes a listed statement would mislabel it stale.
        stale = expected - expected_hit
        print("-- expected failures (port-pending, list must only SHRINK): %d hit, %d stale"
              % (len(expected_hit), len(stale)))
        for sql_text in sorted(stale):
            print("   STALE (now passes -- remove from expected_failures.json): %s" % sql_text[:120])
        if stale:
            return 1


if __name__ == "__main__":
    sys.exit(main())
