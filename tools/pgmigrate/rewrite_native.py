#!/usr/bin/env python3
"""Mechanical half of the native-PG port: apply the SAFE rewrite rules to the
harvested statements of the named source files, editing the files in place.

Safe = text-local, semantics-preserving under the typed transport:
  backticks off; QUOTE(x) -> x (typed transport already returns strings for
  string columns; every consumer formats before parsing); QUOTE(COALESCE(x,l))
  -> COALESCE(x,l) AS x; LIMIT a,b -> LIMIT b OFFSET a; INSERT IGNORE ->
  ON CONFLICT DO NOTHING; CURDATE() -> CURRENT_DATE; UNIX_TIMESTAMP() ->
  extract(epoch from now())::bigint; DATEDIFF(A,B) -> (A::date - B::date);
  CAST(x AS SIGNED|UNSIGNED) -> x (PG ints are signed; the casts guarded
  MySQL's unsigned wrap); NOW() stays (valid PG). Unaliased expressions left
  in a SELECT list get position-stable aliases only when created here.

NOT touched (semantic, port by hand): REPLACE INTO, ON DUPLICATE KEY,
FIND_IN_SET, DATE_FORMAT, INTERVAL arithmetic, multi-table DML, dynamic
identifiers. The tool prints what it changed and what it left.

    python3 rewrite_native.py <file.sqf> [...]     # edit in place
    python3 rewrite_native.py --dry <files>        # show, do not write
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "pysqf_modules"))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CORPUS = os.path.join(HERE, "sqlcorpus", "corpus.json")


class _NoTranslator(Exception):
    pass

MANUAL = re.compile(r"REPLACE\s+INTO|ON\s+DUPLICATE|FIND_IN_SET|DATE_FORMAT|INTERVAL\s", re.I)


def rewrite(sql: str) -> str:
    out = sql
    out = out.replace("`", "")
    # QUOTE(COALESCE(col,lit)) -> COALESCE(col,lit) AS col
    def q_coalesce(m):
        return "COALESCE(%s,%s) AS %s" % (m.group(1), m.group(2), m.group(1).split(".")[-1])
    out = re.sub(r"QUOTE\(\s*COALESCE\(\s*([A-Za-z_][\w.]*)\s*,\s*('[^']*')\s*\)\s*\)",
                 q_coalesce, out, flags=re.I)
    # QUOTE(bare column) -> bare column
    out = re.sub(r"QUOTE\(\s*([A-Za-z_][\w.]*)\s*\)", r"\1", out, flags=re.I)
    # LIMIT a,b -> LIMIT b OFFSET a  (a may be %N)
    out = re.sub(r"\bLIMIT\s+(%?\d+)\s*,\s*(\d+)", r"LIMIT \2 OFFSET \1", out, flags=re.I)
    # INSERT IGNORE INTO t (...) VALUES (...) -> ... ON CONFLICT DO NOTHING
    if re.match(r"\s*INSERT\s+IGNORE\b", out, flags=re.I):
        out = re.sub(r"^(\s*INSERT)\s+IGNORE\b", r"\1", out, flags=re.I)
        out = out.rstrip()
        out += " ON CONFLICT DO NOTHING"
    out = re.sub(r"\bCURDATE\(\)", "CURRENT_DATE", out, flags=re.I)
    out = re.sub(r"\bUNIX_TIMESTAMP\(\)", "extract(epoch from now())::bigint", out, flags=re.I)
    out = re.sub(r"\bDATEDIFF\(\s*NOW\(\)\s*,\s*([A-Za-z_][\w.]*)\s*\)",
                 r"(now()::date - \1::date)", out, flags=re.I)
    out = re.sub(r"\bDATEDIFF\(\s*CURRENT_DATE\s*,\s*([A-Za-z_][\w.]*)\s*\)",
                 r"(CURRENT_DATE - \1::date)", out, flags=re.I)
    out = re.sub(r"\bCAST\(\s*([A-Za-z_][\w.]*)\s+AS\s+(?:SIGNED|UNSIGNED)(?:\s+INTEGER)?\s*\)",
                 r"\1", out, flags=re.I)
    return out


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--dry"]
    dry = "--dry" in sys.argv
    try:
        import apdb_sql                    # retired at Phase T; fixpoint pass inert without it
    except ImportError:
        apdb_sql = None
    from realise import realise            # noqa: F401 (kept for future rule passes)
    corpus = json.load(open(CORPUS, encoding="utf-8"))
    changed = left = 0
    for rel in args:
        path = os.path.join(REPO, rel)
        src = open(path, encoding="utf-8").read()
        orig_src = src
        for e in corpus:
            if e["file"] != rel or e.get("partial"):
                continue
            new = rewrite(e["sql"])
            # Let the translator FINISH the mechanical work (aliasing of computed
            # columns, spacing) -- but only adopt its output when it is a fixpoint
            # (translate(out) == out), i.e. genuinely native. Placeholders survive
            # because translate() is run on the realised text only to VALIDATE the
            # fixpoint; the adopted text is produced from the template itself.
            try:
                if apdb_sql is None:
                    raise _NoTranslator
                t1 = apdb_sql.translate(new)
                if not t1.follow_up and not t1.stringify and t1.sql != new:
                    t2 = apdb_sql.translate(t1.sql)
                    if t2.sql == t1.sql and not t2.follow_up and not t2.stringify:
                        new = t1.sql
            except Exception:              # translator retired or refused: rules-only
                pass
            if new == e["sql"]:
                if MANUAL.search(e["sql"]):
                    print("MANUAL  %s:%d: %s" % (rel, e["line"], e["sql"][:110]))
                    left += 1
                continue
            if MANUAL.search(new):
                print("MANUAL+ %s:%d (partly rewritten, finish by hand): %s" % (rel, e["line"], new[:110]))
            # the harvester UNESCAPES SQF's doubled quotes; the source holds the
            # escaped form, so search both spellings
            candidates = [(e["sql"], new), (e["sql"].replace('"', '""'), new.replace('"', '""'))]
            hit = next((c for c in candidates if src.count(c[0]) == 1), None)
            if hit is None:
                print("SKIP (x%d in source) %s:%d" % (src.count(e["sql"]), rel, e["line"]))
                left += 1
                continue
            src = src.replace(hit[0], hit[1])
            changed += 1
            print("OK      %s:%d" % (rel, e["line"]))
        if not dry and src != orig_src:
            open(path, "w", encoding="utf-8").write(src)
    print("-- %d rewritten, %d need hands" % (changed, left))
    return 0


if __name__ == "__main__":
    sys.exit(main())
