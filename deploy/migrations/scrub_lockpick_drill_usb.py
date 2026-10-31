#!/usr/bin/env python3
"""
LooneyBin 2026-07-18: scrub the RETIRED items (lockpick, drill, usb) out of every player's saved gear
and every house's virtual/physical storage. The Cyberdeck replaced all three, so these are dead ghost items.

Safe + idempotent. Gear/storage are serialized SQF strings that contain backticks (extDB3 quote-escaping),
so we transport values as BASE64 (TO_BASE64/FROM_BASE64) to sidestep ALL shell/SQL escaping. Run again any time.

Usage:
    python3 scrub_lockpick_drill_usb.py --schema looneybin_test          # DEV dry-run
    python3 scrub_lockpick_drill_usb.py --schema looneybin_test --apply  # DEV apply
    python3 scrub_lockpick_drill_usb.py --schema looneybin --apply       # LIVE apply (backup first!)
"""
import subprocess, base64, re, argparse

ITEMS = ("lockpick", "drill", "usb")
# match a virtual-item pair  [``name``,COUNT]  (names are double-backtick-quoted in the DB)
PAIR = re.compile(r'\[``(?:' + '|'.join(ITEMS) + r')``,\d+\]')

def scrub(s):
    if not s:
        return s, False
    orig = s
    s = PAIR.sub('', s)
    for _ in range(5):
        s = s.replace('[,', '[').replace(',]', ']').replace(',,', ',')
    return s, (s != orig)

def db(container, schema, sql):
    r = subprocess.run(
        ["docker", "exec", "-i", container, "mariadb", "-ulooneybin", "-plooneybin", "-N", "--raw", schema],
        input=sql, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout

def collect(container, schema, table, key, cols):
    like = " OR ".join(f"{c} LIKE '%{i}%'" for c in cols for i in ITEMS)
    sel = ", ".join(f"HEX(COALESCE({c},''))" for c in cols)   # HEX never line-wraps (TO_BASE64 wraps at 76)
    rows = db(container, schema, f"SELECT {key}, {sel} FROM {table} WHERE {like};")
    updates, n = [], 0
    for line in rows.splitlines():
        p = line.split("\t")
        if len(p) < 1 + len(cols):
            continue
        sets = []
        for c, b in zip(cols, p[1:1 + len(cols)]):
            val = bytes.fromhex(b).decode("utf-8", "replace") if b else ""
            nv, changed = scrub(val)
            if changed:
                sets.append(f"{c}=UNHEX('{nv.encode().hex()}')")
        if sets:
            updates.append(f"UPDATE {table} SET {', '.join(sets)} WHERE {key}={p[0]};")
            n += 1
    return updates, n

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="looneybin")
    ap.add_argument("--container", default="looneybin-db")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    pu, pn = collect(a.container, a.schema, "players", "id", ["civ_gear", "cop_gear", "med_gear"])
    hu, hn = collect(a.container, a.schema, "houses", "id", ["vinv", "pinv"])
    updates = pu + hu
    print(f"[scrub] schema={a.schema}: {pn} players + {hn} houses affected -> {len(updates)} UPDATEs")
    if not updates:
        print("[scrub] nothing to do."); return
    if not a.apply:
        with open("/tmp/scrub_lockpick_preview.sql", "w") as f:
            f.write("\n".join(updates))
        print("[scrub] DRY-RUN -- preview at /tmp/scrub_lockpick_preview.sql ; re-run with --apply to write.")
        return
    db(a.container, a.schema, "\n".join(updates))
    print(f"[scrub] APPLIED {len(updates)} UPDATEs. (Item weights self-correct on the player's next inventory change.)")

if __name__ == "__main__":
    main()
