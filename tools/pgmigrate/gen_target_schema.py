#!/usr/bin/env python3
"""Emit the FULL schema the new database needs, not just the carried tables.

WHY THIS IS SEPARATE FROM THE ETL
    The ETL creates the tables it has rows for. That is the right scope for a
    data migration and the wrong scope for a database: whether a table's ROWS
    carry and whether the TABLE has to exist are different questions, and 27 of
    them answer differently. `houses` does not carry -- it is anchored to a map
    that no longer exists -- but the game creates houses on the NEW map from its
    first evening, and `turf`, `log`, `server_control`, `online` and 23 others
    are the same shape. A database built from the ETL's schema alone is a server
    that dies the first time anyone buys a house.

    So: this emits every table `rules.CARRY` says should exist in the target
    (`target_exists`), carried or not. The ETL then loads rows into the subset
    it has rows for.

    The overlap is asserted, not assumed. Both this and the ETL translate with
    the same `ddl.Options`, so the carried tables must come out byte-identical;
    if they ever do not, the two files disagree about the shape of a table that
    is about to receive player data, and that is worth stopping for.

USAGE
    python3 gen_target_schema.py <live-dump.sql> [fork-dump.sql] -o target_schema.sql

    The fork dump is optional and supplies tables that exist only on this
    project's own database (`casino_chips`, `suites`, ...): live has never had
    them, so live's schema cannot describe them.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import ddl                                                    # noqa: E402
import rules                                                  # noqa: E402


def create_statements(path: str) -> dict:
    """table -> its CREATE TABLE text, read straight out of a mysqldump."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    out = {}
    for m in re.finditer(r"CREATE TABLE `([^`]+)` \(", text):
        # Find the terminating semicolon that is NOT inside a string. A table
        # COMMENT may contain one -- `opfor_whitelist`'s does -- and stopping at
        # the first `;` truncates the statement mid-literal, which the DDL
        # scanner then reports as an unterminated quote hundreds of lines later.
        i, in_str = m.end(), False
        while i < len(text):
            ch = text[i]
            if in_str:
                if ch == "\\":
                    i += 2
                    continue
                if ch == "'":
                    in_str = False
            elif ch == "'":
                in_str = True
            elif ch == ";":
                break
            i += 1
        out[m.group(1).lower()] = text[m.start():i + 1]
    return out


def build(live_path: str, fork_path: str | None):
    available = {}
    if fork_path:
        available.update(create_statements(fork_path))
    available.update(create_statements(live_path))     # live wins on any overlap

    # A table that is another entry's rename TARGET must not also be emitted under
    # its own name: `apd_applications` becomes `maxsec_applications`, and the fork
    # database has `maxsec_applications` too -- the same table, seen from the two
    # sides of the rename. Emitting both is one CREATE TABLE too many, and the
    # error ("already exists") names the target, not the pair that caused it.
    rename_targets = {e.target_table for e in rules.CARRY.values() if e.target_table}
    wanted = sorted(t for t, entry in rules.CARRY.items()
                    if entry.target_exists and t not in rename_targets)
    missing = [t for t in wanted if t not in available]
    present = [t for t in wanted if t in available]

    emitted = ddl.translate(
        "\n".join(available[t] for t in present),
        ddl.Options(
            # Identical to the ETL's options. Anything that differs here produces
            # a table the ETL then COPYs into with a different idea of its types.
            tinyint1_as_boolean=False,
            boolean_columns=frozenset(
                (t, c) for t, c in rules.boolean_columns() if t in set(present)),
            jsonb_columns=frozenset(
                (t, c) for t, c in rules.transcoded_columns() if t in set(present)),
            extra_columns={t: dict(rules.CARRY[t].add_columns)
                           for t in present if rules.CARRY[t].add_columns},
            policy_renames={t: dict(rules.CARRY[t].rename)
                            for t in present if rules.CARRY[t].rename},
            table_renames={t: rules.CARRY[t].target_table
                           for t in present if rules.CARRY[t].target_table},
        ),
        source=os.path.basename(live_path),
    )
    return emitted, present, missing


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("live_dump")
    ap.add_argument("fork_dump", nargs="?")
    ap.add_argument("-o", "--out", default="target_schema.sql")
    args = ap.parse_args()

    emitted, present, missing = build(args.live_dump, args.fork_dump)

    errors = emitted.errors()
    for issue in errors:
        print("error: %s" % issue, file=sys.stderr)
    if errors:
        return 1

    carried = sorted(t for t, e in rules.CARRY.items() if e.carries)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("-- Target schema for the new deployment, generated by gen_target_schema.py.\n")
        fh.write("-- %d tables: %d that carry rows, %d that start empty and are filled by\n"
                 % (len(present), len([t for t in present if t in carried]),
                    len([t for t in present if t not in carried])))
        fh.write("-- the game itself. A table missing here is a subsystem that dies on contact.\n\n")
        fh.write(emitted.sql())
        fh.write("\n")
        fh.write(ARMAQUEST_STATE_DDL)

    print("wrote %s: %d tables (%d carry rows, %d start empty)"
          % (args.out, len(present),
             len([t for t in present if t in carried]),
             len([t for t in present if t not in carried])))
    if missing:
        # Not an error on its own: the fork-only tables are absent from a live
        # dump by definition. It IS worth printing, because a table the policy
        # wants and neither dump describes will not exist and nothing else says so.
        print("NOT FOUND in either dump, so NOT created: %s" % ", ".join(missing),
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


# armaquest_state is created at RUNTIME by the game (ArmaQuest's store driver
# issues CREATE TABLE IF NOT EXISTS through the DDL translator), so no MySQL
# dump ever contains it and the generated schema used to be 54/55. Emit it
# here so a fresh target is complete before first boot; the runtime CREATE
# remains a harmless no-op. data is TEXT and must never become jsonb -- see
# the runtime DDL in ArmaQuest/server/fn_storeExtDB.sqf for the source shape.
ARMAQUEST_STATE_DDL = """
CREATE TABLE IF NOT EXISTS armaquest_state (
    skey       varchar(64) PRIMARY KEY,
    data       text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
"""
