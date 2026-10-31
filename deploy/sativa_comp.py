#!/usr/bin/env python3
"""
ONE-TIME comp (owner 2026-06-18): convert Sativa Bud (cannas_3) + Sativa Seed (cannas_0) -> Indica Bud
(cannai_3) + Indica Seed (cannai_0) in all PERSISTED virtual storage, MERGING any resulting duplicate
stacks (sum qty) and preserving each container's total. This is a player COMP after sativa->wax was
removed -- it does NOT touch the market. Targets houses.vinv + vehicles.inventory (player carried inv
isn't persisted; sprouts/adult plants aren't stored).

Storage value format (extDB3 mres): outer double-quotes wrapping an SQF array whose strings use DOUBLE
backticks, e.g.  "[[[``cannas_0``,1],[``cannai_0``,1]],2]"  ==  [ [[name,qty],...], totalCount ].

Run:  sativa_comp.py            # DRY-RUN (prints before->after, no writes)
      sativa_comp.py --apply    # backs up the tables, then writes
MUST run while the server is OFFLINE (e.g. from run-boot2 during a restart) so the in-memory houses
don't save over it.
"""
import subprocess, json, sys, os, datetime

APPLY = "--apply" in sys.argv
MAP = {"cannas_3": "cannai_3", "cannas_0": "cannai_0"}
TARGETS = [("houses", "vinv"), ("vehicles", "inventory")]
ROOT = os.path.dirname(os.path.abspath(__file__))


def db(sql):
    r = subprocess.run(
        ["docker", "exec", "-i", "looneybin-db", "mariadb", "-ulooneybin", "-plooneybin", "-N", "looneybin", "-e", sql],
        capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise SystemExit("DB error on: %s" % sql[:80])
    return r.stdout


def decode(raw):
    """mres string -> python [items, total], or None if not the expected shape."""
    s = raw.strip()
    if not (s.startswith('"') and s.endswith('"')):
        return None
    j = s[1:-1].replace("``", '"')          # double-backtick -> double-quote
    try:
        arr = json.loads(j)
    except Exception:
        return None
    if not (isinstance(arr, list) and len(arr) == 2 and isinstance(arr[0], list) and isinstance(arr[1], (int, float))):
        return None
    for e in arr[0]:
        if not (isinstance(e, list) and len(e) == 2 and isinstance(e[0], str) and isinstance(e[1], (int, float))):
            return None
    return arr


def encode(arr):
    """python [items, total] -> mres string (outer quotes + double-backticks), compact."""
    body = json.dumps(arr, separators=(",", ":")).replace('"', "``")
    return '"' + body + '"'


def convert(arr):
    """rename sativa->indica + merge same-name stacks. Returns new arr or None if unchanged."""
    items, total = arr[0], arr[1]
    merged, order, changed = {}, [], False
    for name, qty in items:
        nn = MAP.get(name, name)
        if nn != name:
            changed = True
        if nn in merged:
            merged[nn] += qty
            changed = True
        else:
            merged[nn] = qty
            order.append(nn)
    if not changed:
        return None
    return [[[n, merged[n]] for n in order], total]


def main():
    print("=== sativa->indica comp  (%s) ===" % ("APPLY" if APPLY else "DRY-RUN"))
    updates = []  # (table, col, id, newval)
    for table, col in TARGETS:
        rows = db("SELECT id, %s FROM %s WHERE %s LIKE '%%cannas\\_3%%' OR %s LIKE '%%cannas\\_0%%'" % (col, table, col, col))
        for line in rows.splitlines():
            if not line.strip():
                continue
            rid, raw = line.split("\t", 1)
            arr = decode(raw)
            if arr is None:
                print("  [SKIP] %s id=%s  unparseable: %s" % (table, rid, raw[:60]))
                continue
            new = convert(arr)
            if new is None:
                continue
            newval = encode(new)
            updates.append((table, col, rid, newval))
            print("  %s id=%s" % (table, rid))
            print("      OLD %s" % raw.strip())
            print("      NEW %s" % newval)
    print("\n%d row(s) to convert." % len(updates))
    if not APPLY:
        print("DRY-RUN only. Re-run with --apply (server OFFLINE) to write.")
        return
    # backup the two tables first
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    bk = os.path.join(ROOT, "db_backups", "looneybin_pre_sativacomp_%s.sql" % ts)
    with open(bk, "w") as fh:
        d = subprocess.run(["docker", "exec", "looneybin-db", "mariadb-dump", "-ulooneybin", "-plooneybin",
                            "--single-transaction", "looneybin", "houses", "vehicles"], stdout=fh, text=True)
    print("backup: %s" % bk)
    sql = "START TRANSACTION;\n"
    for table, col, rid, newval in updates:
        sql += "UPDATE %s SET %s='%s' WHERE id='%s';\n" % (table, col, newval, rid)
    sql += "COMMIT;\n"
    db(sql)
    print("APPLIED %d update(s)." % len(updates))


if __name__ == "__main__":
    main()
