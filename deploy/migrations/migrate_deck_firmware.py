#!/usr/bin/env python3
"""
LooneyBin 2026-07-23 (0.2.0 launch): convert LEGACY cyberdeck ITEMS into the firmware entitlement.

0.1.6x sold the Cyberdeck as a $10k virtual item (AP_inv_cyberdeck gating). 0.2.0 replaces that with
the $1k firmware-flash model: access = id 0 present in players.cyberdeck_modules (JSON int array read
by fn_queryRequest into AP_cdMods). Without this migration every live deck owner silently loses
hacking on the 0.2.0 boot and the dead item rots in their gear.

What it does (idempotent, dry-run by default):
  1. players: any [``cyberdeck``,N] pair in civ/cop/med_gear -> pair scrubbed + firmware id 0 merged
     into cyberdeck_modules (created as [0] when empty/NULL; appended when the column already holds
     chips; skipped when 0 already present).
  2. houses: any [``cyberdeck``,N] pair in vinv/pinv -> pair scrubbed + firmware granted to the
     house's owner pid (houses.owners = single Steam64) via the same merge rule.

Transport is HEX (extDB3 backtick strings; same machinery as scrub_lockpick_drill_usb.py).
REQUIRES players.cyberdeck_modules to exist (additive ALTER ships separately) -- asserts up front.

Usage:
    python3 migrate_deck_firmware.py --schema looneybin_test          # DEV dry-run
    python3 migrate_deck_firmware.py --schema looneybin_test --apply  # DEV apply
    python3 migrate_deck_firmware.py --schema looneybin --apply       # LIVE apply (backup first!)
"""
import subprocess, re, json, argparse

PAIR = re.compile(r'\[``cyberdeck``,\d+\]')

def scrub(s):
    if not s:
        return s, False
    orig = s
    s = PAIR.sub('', s)
    for _ in range(5):
        s = s.replace('[,', '[').replace(',]', ']').replace(',,', ',')
    return s, (s != orig)

def merge_fw(cur):
    """current cyberdeck_modules text -> (new text, changed)"""
    try:
        arr = json.loads(cur) if cur and cur.strip() else []
        if not isinstance(arr, list):
            arr = []
    except Exception:
        arr = []
    if 0 in arr:
        return cur, False
    return json.dumps([0] + [x for x in arr if x != 0], separators=(',', ':')), True

def db(container, schema, sql):
    r = subprocess.run(
        ["docker", "exec", "-i", container, "mariadb", "-ulooneybin", "-plooneybin", "-N", "--raw", schema],
        input=sql, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout

def hx(b):
    return bytes.fromhex(b).decode("utf-8", "replace") if b else ""

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="looneybin")
    ap.add_argument("--container", default="looneybin-db")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    # hard prereq: the column must exist (this script must not half-run)
    col = db(a.container, a.schema, "SHOW COLUMNS FROM players LIKE 'cyberdeck_modules';").strip()
    if not col:
        raise SystemExit("[deckfw] ABORT: players.cyberdeck_modules does not exist -- run the ALTER first.")

    updates, grant_pids = [], set()

    # -- players carrying the deck item -------------------------------------------------------------
    rows = db(a.container, a.schema,
              "SELECT id, playerid, HEX(COALESCE(civ_gear,'')), HEX(COALESCE(cop_gear,'')), HEX(COALESCE(med_gear,'')), "
              "HEX(COALESCE(cyberdeck_modules,'')) FROM players "
              "WHERE civ_gear LIKE '%cyberdeck%' OR cop_gear LIKE '%cyberdeck%' OR med_gear LIKE '%cyberdeck%';")
    pn = 0
    for line in rows.splitlines():
        p = line.split("\t")
        if len(p) < 6:
            continue
        rid, pid = p[0], p[1]
        sets = []
        for colname, b in zip(("civ_gear", "cop_gear", "med_gear"), p[2:5]):
            nv, changed = scrub(hx(b))
            if changed:
                sets.append(f"{colname}=UNHEX('{nv.encode().hex()}')")
        if sets:  # only players actually holding the ITEM get gear writes; firmware merged either way below
            nm, mchanged = merge_fw(hx(p[5]))
            if mchanged:
                sets.append(f"cyberdeck_modules=UNHEX('{nm.encode().hex()}')")
            updates.append(f"UPDATE players SET {', '.join(sets)} WHERE id={rid};")
            grant_pids.add(pid)
            pn += 1

    # -- house-stored decks: scrub + owner grant ----------------------------------------------------
    rows = db(a.container, a.schema,
              "SELECT id, owners, HEX(COALESCE(vinv,'')), HEX(COALESCE(pinv,'')) FROM houses "
              "WHERE vinv LIKE '%cyberdeck%' OR pinv LIKE '%cyberdeck%';")
    hn = 0
    house_owner_pids = set()
    for line in rows.splitlines():
        p = line.split("\t")
        if len(p) < 4:
            continue
        rid, owner = p[0], p[1].strip()
        sets = []
        for colname, b in zip(("vinv", "pinv"), p[2:4]):
            nv, changed = scrub(hx(b))
            if changed:
                sets.append(f"{colname}=UNHEX('{nv.encode().hex()}')")
        if sets:
            updates.append(f"UPDATE houses SET {', '.join(sets)} WHERE id={rid};")
            hn += 1
            if re.fullmatch(r'\d{17}', owner):
                house_owner_pids.add(owner)

    # firmware grants for house owners not already granted via their gear row
    gn = 0
    for pid in sorted(house_owner_pids - grant_pids):
        rows = db(a.container, a.schema,
                  f"SELECT id, HEX(COALESCE(cyberdeck_modules,'')) FROM players WHERE playerid='{pid}' LIMIT 1;")
        line = rows.strip().splitlines()
        if not line:
            continue
        p = line[0].split("\t")
        nm, mchanged = merge_fw(hx(p[1] if len(p) > 1 else ""))
        if mchanged:
            updates.append(f"UPDATE players SET cyberdeck_modules=UNHEX('{nm.encode().hex()}') WHERE id={p[0]};")
            gn += 1

    print(f"[deckfw] schema={a.schema}: {pn} carrying players, {hn} houses scrubbed, "
          f"{gn} extra owner grants -> {len(updates)} UPDATEs")
    if not updates:
        print("[deckfw] nothing to do."); return
    if not a.apply:
        with open("/tmp/deckfw_preview.sql", "w") as f:
            f.write("\n".join(updates))
        print("[deckfw] DRY-RUN -- preview at /tmp/deckfw_preview.sql ; re-run with --apply to write.")
        return
    db(a.container, a.schema, "\n".join(updates))
    print(f"[deckfw] APPLIED {len(updates)} UPDATEs. Deck owners now hold firmware id 0; ghost items gone.")

if __name__ == "__main__":
    main()
