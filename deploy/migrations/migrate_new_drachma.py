#!/usr/bin/env python3
"""
LooneyBin 2026-07-24: retire the legacy wallet column -- players.blood_money becomes players.new_drachma.

Two starting states are handled (detected from information_schema, never guessed):
  * LIVE  : blood_money BIGINT with legacy-denominated balances -> rename to new_drachma DECIMAL(20,4)
            AND convert values at 6000:1 (CEIL to 4dp, players favoured; matches AP_fnc_ndFromLegacy).
  * DEV   : blood_money already DECIMAL(20,4) with ND-valued balances (converted 2026-07-23)
            -> rename ONLY. Re-running the 6000:1 division here would destroy balances, so the
            conversion step is gated on the PRE-migration column type being an integer.
  * DONE  : new_drachma exists / blood_money gone -> no-op (idempotent, safe to re-run).

Dry-run by default; --apply executes. Writes deploy/.nd_migrated next to this script on success.
Run AFTER the server is on the new PBO (update.md Step 7) and AFTER the players backup.

Usage:
    python3 migrate_new_drachma.py --schema looneybin_test          # DEV dry-run
    python3 migrate_new_drachma.py --schema looneybin --apply       # LIVE apply (backup first!)
"""
import subprocess, argparse, os, datetime

def db(container, schema, sql):
    r = subprocess.run(
        ["docker", "exec", "-i", container, "mariadb", "-ulooneybin", "-plooneybin", "-N", "--raw", schema],
        input=sql, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return r.stdout.strip()

def col_type(container, schema, col):
    return db(container, schema,
        "SELECT DATA_TYPE FROM information_schema.COLUMNS "
        f"WHERE TABLE_SCHEMA='{schema}' AND TABLE_NAME='players' AND COLUMN_NAME='{col}';")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="looneybin")
    ap.add_argument("--container", default="looneybin-db")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    old_t = col_type(a.container, a.schema, "blood_money")
    new_t = col_type(a.container, a.schema, "new_drachma")

    if new_t and not old_t:
        print(f"[{a.schema}] already migrated (new_drachma {new_t}, no blood_money) -- nothing to do.")
        return
    if not old_t:
        raise SystemExit(f"[{a.schema}] NEITHER column exists?! refusing to touch anything.")
    if new_t:
        raise SystemExit(f"[{a.schema}] BOTH columns exist -- manual state, refusing.")

    convert = old_t in ("bigint", "int", "mediumint", "smallint", "tinyint")
    n, total, top = db(a.container, a.schema,
        "SELECT COUNT(*), COALESCE(SUM(blood_money),0), COALESCE(MAX(blood_money),0) "
        "FROM players WHERE blood_money > 0;").split("\t")
    # the wallet was never a legitimately carryable item, but admin grant-all inventories carry the
    # 'bloodmoney' vItem key (seen on live: one account with 15x of everything). The key is renamed to
    # 'newdrachma' in fn_virtItemCfg, so rewrite it in every persisted blob instead of orphaning it.
    strays = {}
    for tbl, col in (("players", "civ_gear"), ("players", "cop_gear"), ("players", "med_gear"),
                     ("houses", "vinv"), ("houses", "pinv")):
        strays[f"{tbl}.{col}"] = int(db(a.container, a.schema,
            f"SELECT COUNT(*) FROM {tbl} WHERE {col} LIKE '%bloodmoney%';") or 0)

    print(f"[{a.schema}] blood_money is {old_t}; {n} players hold >0 (sum {total}, max {top}); "
          f"stray 'bloodmoney' item-key blobs: {strays}")
    print(f"[{a.schema}] plan: RENAME to new_drachma DECIMAL(20,4)" +
          (" + CONVERT 6000:1 (CEIL 4dp)" if convert else " (values already ND -- NO conversion)"))

    if not a.apply:
        print("dry-run only; re-run with --apply to execute.")
        return

    db(a.container, a.schema,
       "ALTER TABLE players CHANGE COLUMN blood_money new_drachma DECIMAL(20,4) NOT NULL DEFAULT 0;")
    if convert:
        db(a.container, a.schema,
           "UPDATE players SET new_drachma = CEIL(new_drachma / 6000 * 10000) / 10000 WHERE new_drachma > 0;")
    for key, cnt in strays.items():
        if cnt:
            tbl, col = key.split(".")
            db(a.container, a.schema,
               f"UPDATE {tbl} SET {col} = REPLACE({col}, 'bloodmoney', 'newdrachma') "
               f"WHERE {col} LIKE '%bloodmoney%';")
            print(f"[{a.schema}] rewrote 'bloodmoney' -> 'newdrachma' in {cnt} {key} blob(s).")
    n2, total2, top2 = db(a.container, a.schema,
        "SELECT COUNT(*), COALESCE(SUM(new_drachma),0), COALESCE(MAX(new_drachma),0) "
        "FROM players WHERE new_drachma > 0;").split("\t")
    print(f"[{a.schema}] done: {n2} players hold >0 ND (sum {total2}, max {top2}).")
    if n != n2:
        raise SystemExit(f"[{a.schema}] HOLDER COUNT CHANGED ({n} -> {n2}) -- restore the backup and investigate.")

    marker = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".nd_migrated")
    with open(marker, "w") as f:
        f.write(f"{a.schema} migrated {datetime.datetime.now().isoformat()} ({n2} holders, sum {total2})\n")
    print(f"marker written: {marker}")

if __name__ == "__main__":
    main()
