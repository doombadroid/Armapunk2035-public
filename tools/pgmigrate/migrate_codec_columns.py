#!/usr/bin/env python3
"""M2+M3: the 36 codec columns become text, one stored shape (RAN 2026-08-20).

Kept as the canonical record and for any future PG target (a fresh rehearsal
DB, live at the freeze). Idempotent: text columns are skipped, normalized
rows are skipped.

ORDER MATTERS AND IT IS ALTER-FIRST. The first run did normalize-then-ALTER
and to_jsonb(blob::text) wrapped the blob in a SECOND JSON-string layer that
::text then kept, escapes and all -- nine rows had to be peeled by hand.
ALTER first, and every subsequent write is a plain text write with no JSON
layer to mis-nest:
  1. ALTER ... TYPE text USING col::text
       - game-written rows (jsonb strings) come out byte-identical to what
         the game INSERTed (PG consumed the outer quotes as JSON delimiters
         on the way in; serialization re-adds them);
       - ETL-written rows (jsonb arrays/objects) come out as bare JSON text.
  2. UPDATE rows that are bare JSON (start with [ or {, no leading quote)
     to the game-blob shape via pgmigrate mres.encode -- the codec the
     migration was validated with.

Usage: PYSQF_DB_DSN=... python3 migrate_codec_columns.py [--dry-run]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mres  # noqa: E402

COLUMNS = {
    "gang_vehicles": ["inventory", "mods"],
    "gangs": ["talents", "wars"],
    "loadouts": ["gear"],
    "players": ["aliases", "arrested", "civ_gear", "civ_licenses", "civ_talents",
                "completed_quests", "cop_gear", "cop_licenses", "cop_talents",
                "crimes", "gov_data", "infamy_talents", "med_gear", "med_licenses",
                "med_talents", "medic_talents", "pre_talents", "prestige",
                "progress_quests"],
    "players_global": ["achievements", "honor_talents", "keys", "lifetime_stats",
                       "lootrewards", "mailbox", "stats"],
    "storage_vault": ["pinv", "vinv"],
    "vehicles": ["inventory", "mods"],
    "wanted": ["crimes"],
}
PK = {"players": "playerid", "players_global": "playerid", "vehicles": "id",
      "gang_vehicles": "id", "gangs": "id", "wanted": "playerid",
      "storage_vault": "slot_id", "loadouts": "id"}


def main() -> int:
    import psycopg
    dry = "--dry-run" in sys.argv
    dsn = os.environ.get("PYSQF_DB_DSN", "")
    if not dsn or "scratch" not in dsn:
        print("refusing: PYSQF_DB_DSN must name a scratch database", file=sys.stderr)
        return 2
    conn = psycopg.connect(dsn, autocommit=False)
    altered = normalized = 0
    with conn.cursor() as cur:
        for table, cols in COLUMNS.items():
            for col in cols:
                cur.execute(
                    "SELECT data_type FROM information_schema.columns "
                    "WHERE table_schema='public' AND table_name=%s AND column_name=%s",
                    (table, col))
                row = cur.fetchone()
                if row is None:
                    print("MISSING %s.%s" % (table, col))
                    continue
                if row[0] == "jsonb":
                    if not dry:
                        cur.execute("ALTER TABLE %s ALTER COLUMN %s TYPE text USING %s::text"
                                    % (table, col, col))
                    altered += 1
                # normalize bare-JSON rows (ETL generation) to the blob shape
                cur.execute(
                    "SELECT %s, %s FROM %s WHERE %s IS NOT NULL "
                    "AND LEFT(%s,1) IN ('[','{')" % (PK[table], col, table, col, col))
                for key, val in cur.fetchall():
                    blob = mres.encode(json.loads(val))
                    if not dry:
                        cur.execute("UPDATE %s SET %s = %%s WHERE %s = %%s"
                                    % (table, col, PK[table]), (blob, key))
                    normalized += 1
    if dry:
        conn.rollback()
    else:
        conn.commit()
    print("-- %s: %d columns altered, %d rows normalized"
          % ("DRY RUN" if dry else "done", altered, normalized))
    return 0


if __name__ == "__main__":
    sys.exit(main())
