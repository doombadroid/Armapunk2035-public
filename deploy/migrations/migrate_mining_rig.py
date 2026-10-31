#!/usr/bin/env python3
"""
LooneyBin 2026-07-18: migrate the OLD virtual crypto miner to the NEW placeable-composition rig.

Old system: houses.miner = "sinceUnix:lastCollectUnix" (a virtual, position-less miner).
New system: houses.rig = "x:y:z:dir" (a physically placed Eden composition, spawned at boot).

For every house that still has the OLD miner but NO new rig, we DON'T auto-place a composition (we can't pick a
good spot for them) -- instead we hand the owner a `cryptoRig` item in their HOUSE storage (vinv) so they can
re-place it themselves (owner call 2026-07-18: "just put the rig in home inventory"), and clear the dead `miner`.

Base64 transport (vinv is a backtick-escaped SQF string). Dry-run by default.
NOTE: verify on the FIRST live house before a bulk --apply (no dev rows exist to test against).

Usage:
    python3 migrate_mining_rig.py --schema looneybin_test           # DEV dry-run (expect 0)
    python3 migrate_mining_rig.py --schema looneybin --apply        # LIVE apply (backup first!)
"""
import subprocess, base64, re, argparse

RIG_WEIGHT = 15   # cryptoRig virtual-item weight (fn_virtItemCfg)

def db(container, schema, sql):
    r = subprocess.run(
        ["docker", "exec", "-i", container, "mariadb", "-ulooneybin", "-plooneybin", "-N", "--raw", schema],
        input=sql, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout

def add_rig(vinv):
    """Insert [``cryptoRig``,1] into a house vinv "[[<pairs>],<weight>]" and bump the weight by 15."""
    v = (vinv or "").strip()
    flat = v.replace(" ", "")
    if flat in ("", '""', '"[[],0]"'):
        return '"[[[``cryptoRig``,1]],' + str(RIG_WEIGHT) + ']"'
    if flat.startswith('"[[]'):                       # empty item list
        v = v.replace('"[[]', '"[[[``cryptoRig``,1]]', 1)
    else:                                             # prepend to the existing item list
        v = v.replace('"[[', '"[[[``cryptoRig``,1],', 1)
    # bump the trailing weight number:  ...,<weight>]"
    v = re.sub(r',\s*(\d+)\]"\s*$', lambda m: f',{int(m.group(1)) + RIG_WEIGHT}]"', v)
    return v

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="looneybin")
    ap.add_argument("--container", default="looneybin-db")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    rows = db(a.container, a.schema,
        "SELECT id, HEX(COALESCE(vinv,'')) FROM houses "   # HEX never line-wraps (TO_BASE64 wraps at 76)
        "WHERE miner IS NOT NULL AND miner<>'' AND (rig IS NULL OR rig='');")
    updates = []
    for line in rows.splitlines():
        p = line.split("\t")
        if len(p) < 2:
            continue
        vinv = bytes.fromhex(p[1]).decode("utf-8", "replace") if p[1] else ""
        newv = add_rig(vinv)
        updates.append(f"UPDATE houses SET vinv=UNHEX('{newv.encode().hex()}'), miner=NULL WHERE id={p[0]};")

    print(f"[rig-migrate] schema={a.schema}: {len(updates)} house(s) with old miner + no rig -> grant cryptoRig, clear miner")
    if not updates:
        print("[rig-migrate] nothing to do."); return
    if not a.apply:
        with open("/tmp/migrate_rig_preview.sql", "w") as f:
            f.write("\n".join(updates))
        print("[rig-migrate] DRY-RUN -- preview at /tmp/migrate_rig_preview.sql ; VERIFY one house, then --apply.")
        return
    db(a.container, a.schema, "\n".join(updates))
    print(f"[rig-migrate] APPLIED {len(updates)} UPDATEs.")

if __name__ == "__main__":
    main()
