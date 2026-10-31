#!/usr/bin/env python3
"""Differential test harness: run the game's SQL on BOTH engines and compare.

    python3 tools/pysqf_modules/dbdiff.py --setup      # build both scratch databases
    python3 tools/pysqf_modules/dbdiff.py              # run the comparison
    python3 tools/pysqf_modules/dbdiff.py -v           # show every statement

WHY THIS AND NOT THE PARSE CHECK
    `PREPARE` proves a translated statement is valid PostgreSQL and that every
    column it names exists. It does NOT prove the statement DOES THE SAME THING.
    Those are different questions, and the second one is where a migration
    actually hurts: an UPDATE whose WHERE clause matches a different set of rows,
    an upsert that inserts where it should have updated, a DELETE bounded
    differently, a boolean comparison that is now always false. Every one of
    those parses perfectly and quietly corrupts data.

    So: seed IDENTICAL rows into MariaDB and PostgreSQL, run the ORIGINAL
    statement against MariaDB and the TRANSLATED statement against PostgreSQL,
    and compare what came back AND what the table looks like afterwards. A
    divergence is a finding whichever engine is right, because the game's
    behaviour is defined by what MariaDB did.

WHAT A DIVERGENCE MEANS
    Not automatically a bug in the translator. Some are deliberate: `DELETE ...
    LIMIT` is bounded by ctid on one side and by MySQL's own arbitrary choice on
    the other, and an `ORDER BY` that does not fully determine the order is free
    to differ. Those are listed as EXPECTED with the reason. Anything else is
    something to look at before the freeze.

SAFETY
    Both databases are scratch, created by --setup, named `apdb_diff`, and
    dropped and rebuilt on every run. Nothing here touches the game's databases;
    the PostgreSQL side refuses any name that does not look like scratch, and the
    MariaDB side is a database the game does not know exists.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, "tools", "pgmigrate"))

try:
    import apdb_sql                        # retired at Phase T; the rig's translated
except ImportError:                        # mode is historical -- baseline runs only
    apdb_sql = None as X                                           # noqa: E402

PG_DB = "apdb_diff_scratch"
MY_DB = "apdb_diff"
MY_CONTAINER = "looneybin-db"

CORPUS = os.path.join(REPO, "tools", "pgmigrate", "sqlcorpus", "corpus.json")
LIVE_SCHEMA = os.path.expanduser("~/pgmigrate-dumps/live-schema-20260815.sql")
TARGET_SCHEMA = os.path.join(REPO, "tools", "pgmigrate", "target_schema.sql")

#: Statements whose two engines legitimately disagree, with the reason. Listed
#: rather than silently skipped: an expected divergence that stops happening is
#: itself worth noticing.
EXPECTED_DIVERGENCE = {
    "ORDER BY that does not fully determine the order":
        re.compile(r"ORDER\s+BY(?!.*\b(id|playerid|oid)\b)", re.I),
    "DELETE/UPDATE ... LIMIT picks a different arbitrary row":
        re.compile(r"^\s*(DELETE|UPDATE)\b.*\bLIMIT\b", re.I | re.S),
    "MySQL's permissive GROUP BY returns one arbitrary row per group":
        re.compile(r"\bGROUP\s+BY\b", re.I),
    "QUOTE() adds the quotes on MariaDB; the bridge adds them back on the other side":
        re.compile(r"\bQUOTE\s*\(", re.I),
    "reads the clock, so the two engines answer a moment apart":
        re.compile(r"\b(UNIX_TIMESTAMP|NOW|CURDATE|CURTIME|UTC_TIMESTAMP)\s*\(", re.I),
    "returns a surrogate id: auto_increment and an identity sequence allocate independently":
        re.compile(r"^\s*SELECT\s+(?:[A-Za-z0-9_.]+\s*,\s*)*`?id`?\s*(,|\s+FROM)", re.I),
}


# ---------------------------------------------------------------------------
# Engines
# ---------------------------------------------------------------------------


# `quiet` controls PRINTING, never whether an error is REPORTED. An earlier
# version swallowed the error when quiet, so a statement PostgreSQL rejected came
# back as (output, no error) -- and the comparison then read the unchanged table
# as a DIVERGENCE rather than a failure. It is the difference between "this
# statement does something different" and "this statement does not run", and the
# harness was reporting the first for both. That accounted for most of 112
# findings, and it is exactly the conflation the whole PySQF layer was designed
# to avoid: an error must never be able to look like a result.


def pg(sql: str, db: str = PG_DB, quiet: bool = False):
    r = subprocess.run(["psql", "-d", db, "-v", "ON_ERROR_STOP=1", "-tAF", "\x1f", "-c", sql],
                       capture_output=True, text=True)
    if r.returncode:
        detail = [l for l in r.stderr.strip().split("\n") if l.startswith("ERROR")]
        return None, (detail or [r.stderr.strip().split("\n")[0]])[0][:160]
    return r.stdout, None


def my(sql: str, db: str = MY_DB, quiet: bool = False):
    r = subprocess.run(
        ["docker", "exec", "-i", MY_CONTAINER, "mariadb", "-ulooneybin", "-plooneybin",
         "-N", "-B", "--default-character-set=utf8mb4", db, "-e", sql],
        capture_output=True, text=True)
    err = "\n".join(l for l in r.stderr.split("\n") if "Using a password" not in l).strip()
    if r.returncode:
        return None, err.split("\n")[-1][:160]
    return r.stdout, None


# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------


def normalise(text: str) -> list:
    """Rows as lists of strings, with the differences that are NOT differences
    flattened: the two clients render NULL, booleans and decimals their own way,
    and none of that is the game's behaviour changing."""
    rows = []
    body = (text or "").strip("\n")
    if not body.strip():
        return []
    for line in body.split("\n"):
        # An EMPTY line is a row whose single column is NULL -- `SELECT
        # MIN(started_at)` over an empty table returns exactly that. Skipping it
        # made one engine look like it returned no row at all, which is a
        # different answer to "no value".
        if line == "" and len(body.split("\n")) == 1:
            rows.append([""])
            continue
        if not line:
            continue
        cells = line.split("\x1f") if "\x1f" in line else line.split("\t")
        # psql drops a trailing empty field where the mariadb client keeps it, so
        # a row whose last column is NULL compares as a different SHAPE rather
        # than a different value. Padded at the comparison instead of guessing
        # which client is right.
        out = []
        for cell in cells:
            v = cell.strip()
            if v in ("NULL", "\\N", ""):
                v = ""
            elif v in ("t", "true", "1"):
                v = "1"
            elif v in ("f", "false", "0"):
                v = "0"
            elif re.fullmatch(r"-?\d+\.0+", v):
                v = v.split(".")[0]                    # 5.0000 and 5 are one value
            elif re.match(r"\d{4}-\d\d-\d\d[ T]\d\d:\d\d:\d\d", v):
                # `20:07:11` and `20:07:11.446703+00` are the same instant
                # rendered by two clients. Seconds is as fine as either is.
                v = v[:19].replace("T", " ")
            out.append(v)
        rows.append(out)
    return rows


#: Columns that move on their own and would make every write look divergent.
#: `lastupdated` has an ON UPDATE trigger on one side and a rewritten trigger on
#: the other; a surrogate `id` is auto_increment here and an identity sequence
#: there, so two fresh databases hand out different numbers for the same INSERT.
#: Neither is the game behaving differently.
VOLATILE = {"lastupdated", "seen", "ts", "updated", "updated_at", "bought_at",
            "created_at", "decided_at", "last_auto", "watch_start", "watch_until"}


_COMMON_CACHE: dict = {}


def common_columns(table: str) -> list:
    """Columns present on BOTH sides, in a stable order, minus the volatile ones.

    `SELECT *` cannot be compared across these two schemas, and that is not a
    defect: the migration RENAMES columns (isswat -> ismaxtac), ADDS one the
    source never had (qh_detonate_cd) and drops values the target regenerates.
    Comparing the whole row therefore reports a divergence for every write to
    every table, drowning the real ones -- 128 of them on the first run, none of
    which were about behaviour.

    So the comparison is over the intersection, under the SOURCE's names, which
    is the set where "did this statement do the same thing" is a real question.
    """
    if table in _COMMON_CACHE:
        return _COMMON_CACHE[table]
    try:
        import rules                                          # noqa: PLC0415
        rename = dict(rules.CARRY[table].rename) if table in rules.CARRY else {}
    except Exception:                                          # noqa: BLE001
        rename = {}

    my_out, _ = my("SELECT column_name FROM information_schema.columns WHERE table_schema='%s' "
                   "AND table_name='%s' ORDER BY ordinal_position" % (MY_DB, table), quiet=True)
    pg_out, _ = pg("SELECT column_name FROM information_schema.columns WHERE table_schema='public' "
                   "AND table_name='%s'" % table, quiet=True)
    my_cols = [c.strip().lower() for c in (my_out or "").split() if c.strip()]
    pg_cols = {c.strip().lower() for c in (pg_out or "").split() if c.strip()}

    pairs = []
    for col in my_cols:
        if col in VOLATILE:
            continue
        target = rename.get(col, col)
        if target in pg_cols:
            pairs.append((col, target))
    # A surrogate key that neither side was told is not comparable: auto_increment
    # and an identity sequence hand out different numbers for the same INSERT.
    pairs = [(a, b) for a, b in pairs if a != "id"]
    # Any TIMESTAMP column, by type rather than by name. A write that stamps the
    # current time stamps it a moment apart on two engines, and no list of column
    # names stays complete -- `malden_skin`'s table has a `tax_last` nobody would
    # have thought to add. Clocks are not behaviour.
    types = column_types()
    pairs = [(a, b) for a, b in pairs
             if "timestamp" not in types.get((table, b), "")
             and types.get((table, b)) != "date"]
    _COMMON_CACHE[table] = pairs
    return pairs


def state_of(table: str):
    """(mariadb rows, postgres rows) over the comparable columns only."""
    pairs = common_columns(table)
    if not pairs:
        return None, None
    order = pairs[0][0]
    my_out, _ = my("SELECT %s FROM `%s` ORDER BY %s"
                   % (", ".join("`%s`" % a for a, _ in pairs), table, order), quiet=True)
    pg_out, _ = pg("SELECT %s FROM %s ORDER BY %s"
                   % (", ".join(b for _, b in pairs), table, pairs[0][1]), quiet=True)
    return my_out, pg_out


def _blank(rows: list) -> bool:
    """A single row whose every column is NULL, or nothing at all.

    The two clients disagree about how to print an all-NULL row: one emits a row
    of empty fields, the other emits nothing. `SELECT vinv,pinv FROM houses` over
    a row with both unset is the same answer either way, and the difference is
    the client, not the engine.
    """
    return not rows or (len(rows) == 1 and all(cell == "" for cell in rows[0]))


def same_rows(left: list, right: list, ordered: bool = False) -> bool:
    if _blank(left) and _blank(right):
        return True
    """Row sets equal, tolerating a dropped trailing empty field.

    Compared as a MULTISET unless the statement asked for an order. Two engines
    returning the same rows in a different order is not the game behaving
    differently -- neither engine promises an order without ORDER BY, and three
    identical `bones_dm` rows were being reported as a divergence from a
    comparison that could not tell them apart anyway.
    """
    if len(left) != len(right):
        return False
    if not ordered:
        left, right = sorted(left), sorted(right)
    for a, b in zip(left, right):
        width = max(len(a), len(b))
        if (a + [""] * (width - len(a))) != (b + [""] * (width - len(b))):
            return False
    return True


def table_of(sql: str) -> str | None:
    m = re.search(r"\b(?:FROM|INTO|UPDATE)\s+`?([A-Za-z_][A-Za-z0-9_]*)`?", sql, re.I)
    return m.group(1).lower() if m else None


# ---------------------------------------------------------------------------
# Making a statement runnable
# ---------------------------------------------------------------------------

#: Values the seed actually contains, keyed by the column a placeholder sits
#: beside. Substituting a placeholder with a value that EXISTS is what makes the
#: comparison meaningful -- a WHERE that matches nothing compares two empty
#: results and proves nothing at all.
SEED = {
    "playerid": "76561190000000002", "pid": "76561190000000002",
    "uid": "76561190000000002", "owner": "76561190000000002",
    "owner_uid": "76561190000000002", "owners": "76561190000000002",
    "to_uid": "76561190000000002", "from_pid": "76561190000000042",
    "oid": "H1", "plate": "111111", "classname": "Land_i_House_Big_01_V1_F",
    "name": "Ada", "gang_id": "1", "gangid": "1", "gang0": "1", "id": "1",
    "chip": "firewall", "family": "virt", "item_key": "pickaxe",
    "atm_key": "ATM1", "cartel": "north", "instance": "1", "index": "200",
    "discord_id": "1234567890", "station": "1", "houseid": "1",
}


_TYPES: dict = {}


def column_types() -> dict:
    """(table, column) -> a value of the right TYPE for that column.

    Substituting `'x'` everywhere made MariaDB coerce it to 0 and PostgreSQL
    refuse the statement -- 31 "PostgreSQL rejects" that were all about the fake
    value and none about the game's SQL. A placeholder has to be filled with
    something the column can hold, or the comparison is between a statement that
    ran and one that did not.
    """
    if _TYPES:
        return _TYPES
    out, _ = pg("SELECT table_name||'.'||column_name||'.'||data_type FROM "
                "information_schema.columns WHERE table_schema='public'")
    for line in (out or "").split():
        try:
            table, column, kind = line.strip().split(".", 2)
        except ValueError:
            continue
        _TYPES[(table, column)] = kind
    return _TYPES


def value_for(table: str, column: str) -> str:
    """A literal the column will accept, preferring one the seed contains."""
    seeded = SEED.get(column)
    kind = column_types().get((table, column), "character varying")
    if kind in ("jsonb", "json"):
        return "'[]'"
    if kind == "boolean":
        return "TRUE"
    if "int" in kind or kind in ("numeric", "double precision", "real"):
        if seeded and re.fullmatch(r"-?\d+", seeded):
            return seeded
        return "1"
    if kind in ("timestamp without time zone", "timestamp with time zone", "date"):
        return "'2026-08-15 12:00:00'"
    return "'%s'" % (seeded if seeded is not None else "x")


def realise(sql: str):
    """Substitute format[] placeholders with values the seed contains.

    Returns None when the statement cannot be made runnable honestly -- a
    placeholder standing in for a whole SET or WHERE clause, or for the table
    name. Guessing those produces failures that are about the guess.
    """
    if re.search(r"(?:FROM|INTO|UPDATE|JOIN)\s+`?%\d+`?", sql, re.I):
        return None
    if re.search(r"\b(SET|WHERE|ORDER\s+BY|BY|FROM)\s+%\d+", sql, re.I):
        return None
    if "pysqf_conform" in sql or "generate_series" in sql:
        return None

    where_table = table_of(sql)

    # `col='%1'` and `col=%1` both take a value the COLUMN can hold, preferring
    # one the seed contains so the predicate actually matches a row.
    def by_column(m):
        # Backticks come off before the lookup: `\`id\`` is not a key in any
        # table of column names, and missing it sent the substitution down the
        # `'x'` fallback and straight into "invalid input syntax for integer".
        col = m.group(1).strip("`").rsplit(".", 1)[-1].lower()
        if not where_table:
            return m.group(0)
        if (where_table, col) not in column_types() and col not in SEED:
            return m.group(0)
        return "%s%s%s" % (m.group(1), m.group(2), value_for(where_table, col))

    sql = re.sub(r"(`?[A-Za-z_][A-Za-z0-9_.]*`?)\s*(=\s*)'?%\d+'?", by_column, sql)

    # INSERT ... (cols) VALUES (...): fill each remaining placeholder with a
    # value of the type ITS OWN column takes, matched positionally.
    table = table_of(sql)
    ins = re.match(r"(\s*(?:INSERT|REPLACE)\s+(?:IGNORE\s+)?INTO\s+`?[A-Za-z0-9_]+`?\s*\()([^)]*)"
                   r"(\)\s*VALUES\s*\()([^)]*)(\).*)$", sql, re.I | re.S)
    if ins and table:
        columns = [c.strip().strip("`").lower() for c in ins.group(2).split(",")]
        values = [v.strip() for v in ins.group(4).split(",")]
        if len(columns) == len(values):
            filled = []
            for column, value in zip(columns, values):
                if re.fullmatch(r"'?%\d+'?", value):
                    filled.append(value_for(table, column))
                else:
                    filled.append(value)
            sql = ins.group(1) + ins.group(2) + ins.group(3) + ", ".join(filled) + ins.group(5)

    # Anything still unfilled: a bare number reads as a number, a quoted one as
    # text, which is the best that can be said without a column to ask.
    sql = re.sub(r"'%\d+'", "'x'", sql)
    sql = re.sub(r"%\d+", "1", sql)
    return sql


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

SEED_SQL = """
INSERT INTO players (id, playerid, name, cash, bankacc) VALUES
 (1, '76561190000000002','Ada', 9007199254740993, 250000),
 (2, '76561190000000042','O''Brien', 25, 17);
INSERT INTO players_global (playerid, adminlevel, coplevel, mediclevel) VALUES
 ('76561190000000002', 5, 7, 7),
 ('76561190000000042', 0, 0, 0);
INSERT INTO gangs (id, name, bank, inviterank, kickrank) VALUES
 (1, 'Testers', 5000, 2, 2);
INSERT INTO vehicles (id, side, pid, classname, type, plate, alive, active) VALUES
 (1, 'civ', '76561190000000002', 'C_Offroad_01_F', 'Car', 111111, TRUE, FALSE);
-- TRUE/FALSE, not 1/0: `alive` and `active` are boolean in the target and
-- tinyint in the source, and both engines accept the keywords. Writing the
-- seed in the one form both take is the only way it stays a single source.
INSERT INTO houses (id, oid, owners, classname, worldspace) VALUES
 (1, 'H1', '76561190000000002', 'Land_i_House_Big_01_V1_F', '[[14200,16100,0],180]');
INSERT INTO player_names (id, playerid, name) VALUES
 (1, '76561190000000002', 'Ada');
"""


def setup(verbose: bool) -> int:
    print("== building both scratch databases")

    if not os.path.exists(TARGET_SCHEMA):
        print("generating %s" % TARGET_SCHEMA)
        r = subprocess.run([sys.executable,
                            os.path.join(REPO, "tools", "pgmigrate", "gen_target_schema.py"),
                            LIVE_SCHEMA, os.path.expanduser("~/pgmigrate-dumps/devdb-20260815.sql"),
                            "-o", TARGET_SCHEMA], capture_output=True, text=True)
        if r.returncode:
            print(r.stderr[:400], file=sys.stderr)
            return 1

    subprocess.run(["dropdb", "--if-exists", PG_DB], capture_output=True)
    subprocess.run(["createdb", PG_DB], check=True)
    r = subprocess.run(["psql", "-q", "-d", PG_DB, "-v", "ON_ERROR_STOP=1", "-f", TARGET_SCHEMA],
                       capture_output=True, text=True)
    if r.returncode:
        print("postgres schema failed: %s" % r.stderr[-400:], file=sys.stderr)
        return 1

    my("DROP DATABASE IF EXISTS %s" % MY_DB, db="")
    my("CREATE DATABASE %s" % MY_DB, db="")
    with open(LIVE_SCHEMA, encoding="utf-8", errors="replace") as fh:
        schema = fh.read()
    r = subprocess.run(["docker", "exec", "-i", MY_CONTAINER, "mariadb",
                        "-ulooneybin", "-plooneybin", MY_DB],
                       input=schema, capture_output=True, text=True)
    if r.returncode:
        print("mariadb schema failed: %s" % r.stderr[-400:], file=sys.stderr)
        return 1

    print("  postgres: %s tables" % (pg("SELECT count(*) FROM information_schema.tables "
                                        "WHERE table_schema='public'")[0] or "").strip())
    print("  mariadb : %s tables" % (my("SELECT count(*) FROM information_schema.tables "
                                        "WHERE table_schema='%s'" % MY_DB)[0] or "").strip())
    return 0


def _seed_scripts():
    """The seed as ONE script per engine, built once.

    Per-statement seeding meant ~26 subprocess round trips before every one of
    400 statements; at docker-exec latency that is twenty minutes of process
    spawning to run a few seconds of SQL. One script per engine, and only before
    a statement that can actually change anything, brings it to about a minute.
    """
    statements = [s.strip() for s in SEED_SQL.split(";") if s.strip()]
    tables = []
    for statement in statements:
        table = table_of(statement)
        if table and table not in tables:
            tables.append(table)
    my_script = "SET FOREIGN_KEY_CHECKS=0; " + \
        " ".join("DELETE FROM `%s`;" % t for t in tables) + \
        " " + " ".join(s + ";" for s in statements)
    pg_script = " ".join('DELETE FROM "%s";' % t for t in tables) + \
        " " + " ".join(s.replace("`", '"') + ";" for s in statements)
    return my_script, pg_script


_MY_SEED, _PG_SEED = None, None

#: Tables the seed itself populates and therefore resets on its own.
SEEDED_TABLES = {table_of(x.strip()) for x in SEED_SQL.split(";") if x.strip()}


def seed() -> None:
    """Identical rows on both sides, from one source of truth.

    LOUD ON FAILURE, and that is the whole point. psql runs a multi-statement
    `-c` as ONE transaction, so a single bad INSERT rolls back the DELETEs with
    it and the seed becomes a no-op -- while the MariaDB side, which autocommits,
    applies what it can. The two databases then drift apart and every comparison
    after that is between two different worlds. It took a `plate` column that is
    an integer in the schema and a string in the seed to produce 110 "findings",
    none of which were about a statement.
    """
    global _MY_SEED, _PG_SEED
    if _MY_SEED is None:
        _MY_SEED, _PG_SEED = _seed_scripts()
    _, my_err = my(_MY_SEED)
    _, pg_err = pg(_PG_SEED)
    if my_err or pg_err:
        raise SystemExit("seed failed, so no comparison below it means anything:\n"
                         "  mariadb : %s\n  postgres: %s" % (my_err, pg_err))


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------


def expected_reason(sql: str) -> str | None:
    for reason, pattern in EXPECTED_DIVERGENCE.items():
        if pattern.search(sql):
            return reason
    return None


def run(verbose: bool) -> int:
    with open(CORPUS, encoding="utf-8") as fh:
        corpus = json.load(fh)

    tally = Counter()
    findings, expected = [], []
    seed()          # reads run against the seeded state from here on

    for row in corpus:
        original = realise(row["sql"])
        if original is None:
            tally["skipped: not realisable"] += 1
            continue
        try:
            plan = X.translate(original)
        except X.UntranslatableSQL as exc:
            tally["REFUSED by the translator"] += 1
            findings.append((row["file"], original[:100], "refused: %s" % str(exc)[:110]))
            continue

        table = table_of(original)
        is_write = bool(re.match(r"\s*(INSERT|UPDATE|DELETE|REPLACE)", original, re.I))

        # EVERY statement starts from the same known state, reads included.
        # Seeding only before writes looked like a saving and was a correctness
        # bug: a write that lands differently on the two engines leaves them
        # drifted, and every statement after it then compares two different
        # databases. It showed up as `SELECT COALESCE(MAX(id),0)+1` answering 2
        # on one side and 50001 on the other -- a real difference, in state I
        # had let diverge, not in the statement under test.
        seed()
        # The seed resets the tables it populates. A statement that writes to a
        # table OUTSIDE that set -- `exchange`, `bones_dm`, `gang_bank_log` --
        # would otherwise accumulate rows across the run, so by the twentieth
        # INSERT the two databases are comparing piles rather than a statement.
        if is_write and table and table not in SEEDED_TABLES:
            my("DELETE FROM `%s`" % table, quiet=True)
            pg('DELETE FROM "%s"' % table, quiet=True)
        my_out, my_err = my(original, quiet=True)
        pg_out, pg_err = pg(plan.sql, quiet=True)
        for extra in plan.follow_up:
            pg(extra, quiet=True)

        if my_err and pg_err:
            tally["both engines refuse (not a translation problem)"] += 1
            continue
        if my_err:
            tally["MariaDB refuses, PostgreSQL accepts"] += 1
            continue
        if pg_err:
            tally["POSTGRESQL REFUSES"] += 1
            findings.append((row["file"], plan.sql[:100], pg_err))
            continue

        if is_write and table:
            my_state, pg_state = state_of(table)
            if my_state is None:
                tally["skipped: no comparable columns"] += 1
                continue
            same = same_rows(normalise(my_state), normalise(pg_state))
            what = "post-state of %s" % table
        else:
            same = same_rows(normalise(my_out), normalise(pg_out),
                             ordered=bool(re.search(r"\bORDER\s+BY\b", original, re.I)))
            what = "returned rows"

        if same:
            tally["MATCH"] += 1
            if verbose:
                print("  match  %s" % original[:110])
        else:
            reason = expected_reason(original)
            if reason:
                tally["expected divergence"] += 1
                expected.append((row["file"], original[:90], reason))
            else:
                tally["DIVERGED"] += 1
                findings.append((row["file"], "%s\n      mariadb=%r\n      postgres=%r"
                                 % (original[:100],
                                    normalise(my_state if is_write else my_out)[:3],
                                    normalise(pg_state if is_write else pg_out)[:3]),
                                 what))

    print("\n== results")
    for key, count in tally.most_common():
        print("  %-46s %4d" % (key, count))

    if expected:
        print("\n== expected divergences (%d) -- listed, not hidden" % len(expected))
        for f, sql, reason in expected[:10]:
            print("  %s\n     %s\n     %s" % (os.path.basename(f), sql, reason))

    if findings:
        print("\n== FINDINGS (%d)" % len(findings))
        for f, sql, detail in findings:
            print("  %s\n     %s\n     %s" % (os.path.basename(f), sql, detail))
        return 1

    print("\nno unexplained divergence between the two engines.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--setup", action="store_true", help="build both scratch databases")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    if args.setup:
        return setup(args.verbose)
    return run(args.verbose)


if __name__ == "__main__":
    raise SystemExit(main())
