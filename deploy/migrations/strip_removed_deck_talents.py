#!/usr/bin/env python3
"""
LooneyBin 2026-07-23 (0.2.0): strip the RETIRED Hackerman deck talent tree (ids 250-256) from saved
talent columns.

0.2.0 replaces the deck talent tree with the firmware/module model, so fn_talentCfg no longer defines:
    250 Hackerman | 251 Cache Injection | 252 Autocomplete | 253 Cooldown Bypass
    254 Ghost Protocol | 255 Root Kit | 256 Overclock
Points spent on them stay debited against the per-side cap while granting nothing, and the talent menu
reads a spend total it can no longer explain (same failure shape as the b0097 force-grant pollution).
Stripping the ids refunds those points implicitly -- the player re-picks on their next visit.

Safe + idempotent: only removes the listed ids, leaves every other id and ordering intact, backs the
touched rows up to an in-DB table first. Dry-run by default.

Usage:
    python3 strip_removed_deck_talents.py --schema looneybin_test          # DEV dry-run
    python3 strip_removed_deck_talents.py --schema looneybin --apply       # LIVE apply (backup first!)
"""
import subprocess, re, argparse

DEAD = {250, 251, 252, 253, 254, 255, 256}
COLS = ("civ_talents", "cop_talents", "med_talents")

def strip(s):
    """talent columns are SQF int arrays, e.g. "[1,2,250]" (may be NULL/empty)."""
    if not s or not s.strip():
        return s, False
    found = [int(x) for x in re.findall(r'-?\d+', s)]
    kept = [x for x in found if x not in DEAD]
    if len(kept) == len(found):
        return s, False
    return "[" + ",".join(str(x) for x in kept) + "]", True

def db(container, schema, sql):
    r = subprocess.run(
        ["docker", "exec", "-i", container, "mariadb", "-ulooneybin", "-plooneybin", "-N", "--raw", schema],
        input=sql, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="looneybin")
    ap.add_argument("--container", default="looneybin-db")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    like = " OR ".join(f"{c} REGEXP '(^|[^0-9])25[0-6]([^0-9]|$)'" for c in COLS)
    sel = ", ".join(f"HEX(COALESCE({c},''))" for c in COLS)
    rows = db(a.container, a.schema, f"SELECT id, {sel} FROM players WHERE {like};")

    updates, n = [], 0
    for line in rows.splitlines():
        p = line.split("\t")
        if len(p) < 1 + len(COLS):
            continue
        sets = []
        for c, b in zip(COLS, p[1:1 + len(COLS)]):
            val = bytes.fromhex(b).decode("utf-8", "replace") if b else ""
            nv, changed = strip(val)
            if changed:
                sets.append(f"{c}=UNHEX('{nv.encode().hex()}')")
        if sets:
            updates.append(f"UPDATE players SET {', '.join(sets)} WHERE id={p[0]};")
            n += 1

    print(f"[talents] schema={a.schema}: {n} players hold retired deck talents -> {len(updates)} UPDATEs")
    if not updates:
        print("[talents] nothing to do."); return
    if not a.apply:
        with open("/tmp/strip_deck_talents_preview.sql", "w") as f:
            f.write("\n".join(updates))
        print("[talents] DRY-RUN -- preview at /tmp/strip_deck_talents_preview.sql ; re-run with --apply.")
        return
    backup = ("CREATE TABLE IF NOT EXISTS _backup_deck_talents AS "
              "SELECT id, playerid, civ_talents, cop_talents, med_talents, NOW() AS backed_up "
              f"FROM players WHERE {like};")
    db(a.container, a.schema, backup)
    db(a.container, a.schema, "\n".join(updates))
    print(f"[talents] APPLIED {len(updates)} UPDATEs (backup table _backup_deck_talents). "
          "Affected players re-pick those points on their next talent-menu visit.")

if __name__ == "__main__":
    main()
