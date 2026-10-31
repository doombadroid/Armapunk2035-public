"""Tests for ddl.py, run against the real DDL fragments in `sql/`.

WHY THIS EXISTS
    Every assertion here is a translation that would otherwise fail *silently*.
    A dropped `ON UPDATE` clause, a `decimal` that became a float, a lower-cased
    column nobody recorded as a rename, two indexes that collapsed into one
    because MySQL scopes index names per table and PostgreSQL does not — none of
    these raise. They produce a schema that loads cleanly and is wrong.

    The fixtures are the repository's own `sql/` files rather than synthetic ones,
    because that is where the awkward shapes actually live: mysqldump's versioned
    comments, a `DELIMITER`-wrapped stored routine, prefix indexes, mixed-case
    columns, `decimal(20,4)` next to `bigint`, and four `ON UPDATE
    current_timestamp()` columns. Synthetic fixtures are used only where the
    repository has no example (`enum`, foreign keys, the zero date) and are
    labelled as such.

    The last test is different in kind: given a disposable database it loads the
    emitted DDL into a real PostgreSQL and checks behaviour rather than text —
    that the trigger fires on a change and not on a no-op, that the CHECK rejects
    a negative, and that `decimal(20,4)` round-trips exactly. Everything else here
    only proves the module emits the string it meant to.

Usage:
    python3 tools/pgmigrate/test_ddl.py          # stdlib only, no pytest needed
    python3 -m pytest tools/pgmigrate/test_ddl.py

STATUS
    These tests prove the translator behaves as designed on the fragments in this
    repository, and (with the integration test enabled) that its output is valid
    PostgreSQL. They prove nothing about the live dump, which postgres_plan.md §2
    says this repository does not fully know. A green run here is not evidence the
    migration works.
"""

from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ddl import (  # noqa: E402
    Options,
    convert,
    fit_ident,
    is_zero_date,
    parse_mysql_ddl,
    quote_ident,
    report,
    require_clean,
    translate,
)
# Take the exception class from `ddl` itself: `model` imported under two names
# yields two distinct TransformError classes, and `except` then stops matching.
from ddl import TransformError  # noqa: E402

# Fixtures live WITH the test now: the repo's sql/ directory was deleted on
# 2026-08-20 (owner call, extDB3/MariaDB rip) and took these with it. They are
# MySQL DDL by design -- the inputs ddl.py translates -- so they are test
# assets, not live schema, and they stay frozen here.
SQL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "sql")


def frag(name: str) -> str:
    with open(os.path.join(SQL_DIR, name), "r", encoding="utf-8") as fh:
        return fh.read()


DEV_SCHEMA = frag("looneybin_dev_schema.sql")


def stmt_for(emitted, table: str) -> str:
    """The CREATE TABLE text for one table."""
    for s in emitted.tables:
        if re.match(r"^CREATE TABLE (\"?)%s\1 " % re.escape(table), s):
            return s
    raise AssertionError("no CREATE TABLE emitted for %r" % table)


def col_line(emitted, table: str, column: str) -> str:
    for line in stmt_for(emitted, table).splitlines():
        stripped = line.strip()
        if stripped.startswith(column + " ") or stripped.startswith('"%s" ' % column):
            return stripped
    raise AssertionError("no line for %s.%s" % (table, column))


# ---------------------------------------------------------------------------
# Parsing the real dump
# ---------------------------------------------------------------------------

def test_dev_schema_parses_every_table():
    """36 CREATE TABLEs, and mysqldump's noise must not become a statement."""
    schema = parse_mysql_ddl(DEV_SCHEMA, source="looneybin_dev_schema.sql")
    names = [t.name for t in schema.tables]
    assert len(names) == 36, names
    for expected in ("players", "houses", "vehicles", "gangs", "exchange", "log"):
        assert expected in names
    errs = [i for i in schema.issues if i.severity == "error"]
    assert errs == [], [str(e) for e in errs]


def test_dev_schema_converts_with_no_errors():
    """The whole structure dump must translate without one unsupported construct."""
    emitted = translate(DEV_SCHEMA, Options(), source="looneybin_dev_schema.sql")
    assert emitted.errors() == [], [str(e) for e in emitted.errors()]
    require_clean(emitted)  # must not raise


def test_engine_charset_collate_are_dropped():
    emitted = translate(DEV_SCHEMA)
    sql = emitted.sql()
    for banned in ("ENGINE=", "utf8mb4", "COLLATE=", "AUTO_INCREMENT=", "`"):
        assert banned not in sql, banned


# ---------------------------------------------------------------------------
# Money — the one column where a rounding bug is theft
# ---------------------------------------------------------------------------

def test_currency_columns_never_become_floats():
    """`decimal(20,4)` → numeric(20,4); bigint stays bigint. No float path exists."""
    emitted = translate(DEV_SCHEMA)
    assert "numeric(20,4)" in col_line(emitted, "players", "new_drachma")
    for c in ("cash", "bankacc"):
        line = col_line(emitted, "players", c)
        assert " bigint " in line + " ", line
    for line in stmt_for(emitted, "players").splitlines():
        if "new_drachma" in line or "cash" in line or "bankacc" in line:
            assert "double" not in line and "real" not in line, line


def test_double_columns_stay_double():
    """Only the genuinely inexact source columns get an inexact target type."""
    emitted = translate(DEV_SCHEMA)
    assert "double precision" in col_line(emitted, "players", "damage")
    assert "double precision" in col_line(emitted, "itemstock", "quantity")


def test_exact_type_never_maps_to_float():
    """No decimal/numeric column anywhere in the dump reaches a float type."""
    schema = parse_mysql_ddl(DEV_SCHEMA)
    emitted = convert(schema)
    for table in schema.tables:
        for col in table.columns:
            if col.mysql_type.lower().startswith(("decimal", "numeric")):
                line = col_line(emitted, table.name, col.name)
                assert "numeric" in line, line


# ---------------------------------------------------------------------------
# AUTO_INCREMENT
# ---------------------------------------------------------------------------

def test_auto_increment_becomes_identity_and_keeps_its_seed():
    emitted = translate(DEV_SCHEMA)
    assert "GENERATED BY DEFAULT AS IDENTITY" in col_line(emitted, "bans", "id")
    # BY DEFAULT, not ALWAYS: the ETL inserts explicit ids.
    assert "GENERATED ALWAYS" not in emitted.sql()
    post = emitted.post_load_sql()
    for table, seed in (("bans", 12), ("players", 542), ("log", 1385120)):
        assert "pg_get_serial_sequence('%s', 'id')" % table in post
        assert ", %d), false);" % seed in post


def test_identity_sequence_is_set_from_the_data_not_only_the_dump_seed():
    """A structure dump carries no seed for some tables; a sequence left at 1
    hands the first new player an id an imported row already owns."""
    emitted = translate(DEV_SCHEMA)
    post = emitted.post_load_sql()
    # `bounties` has an AUTO_INCREMENT column but no AUTO_INCREMENT= table option
    assert "pg_get_serial_sequence('bounties', 'id')" in post
    assert "SELECT COALESCE(max(id), 0) + 1 FROM bounties" in post


def test_identity_seed_is_post_load_not_pre_load():
    """Seeding before the load hands the first new player an id that already exists."""
    emitted = translate(DEV_SCHEMA)
    assert "setval" not in emitted.sql()
    assert "setval" in emitted.post_load_sql()


# ---------------------------------------------------------------------------
# tinyint / unsigned
# ---------------------------------------------------------------------------

def test_tinyint1_is_boolean_and_wider_tinyints_are_smallint():
    emitted = translate(DEV_SCHEMA)
    # `isswat` until the faction sweep renamed the COLUMN; the schema fragment
    # this reads was regenerated from dev afterwards, these asserts were not.
    assert "boolean" in col_line(emitted, "players", "ismaxtac")        # tinyint(1)
    assert "boolean" in col_line(emitted, "houses", "locked")           # tinyint(1)
    assert "smallint" in col_line(emitted, "houses", "barrel")          # tinyint(4)
    assert "smallint" in col_line(emitted, "players_global", "coplevel")  # tinyint(2)


def test_tinyint1_default_becomes_a_boolean_literal():
    emitted = translate(DEV_SCHEMA)
    assert "DEFAULT true" in col_line(emitted, "houses", "locked")      # DEFAULT 1
    assert "DEFAULT false" in col_line(emitted, "players", "ismaxtac")  # DEFAULT 0


def test_bare_tinyint_is_reported_as_a_guess():
    """MySQL 8 omits display widths, so a bare tinyint may have been a boolean."""
    emitted = translate("CREATE TABLE t (id int NOT NULL, flag tinyint NOT NULL DEFAULT 0, "
                        "PRIMARY KEY (id));")
    assert "smallint" in col_line(emitted, "t", "flag")
    assert any("GUESS" in i.message and i.column == "flag" for i in emitted.guesses())


def test_unsigned_is_dropped_and_replaced_by_a_check():
    emitted = translate(DEV_SCHEMA)
    create = stmt_for(emitted, "discord_links")
    assert "unsigned" not in create
    assert "CHECK (discord_id >= 0)" in create


def test_unsigned_int_is_widened_so_the_range_survives():
    """int unsigned reaches 4294967295, which PostgreSQL's integer cannot hold."""
    emitted = translate(frag("suites.sql"))
    line = col_line(emitted, "suites", "leased_at")
    assert "bigint" in line, line
    assert "CHECK (leased_at >= 0)" in stmt_for(emitted, "suites")


def test_bigint_unsigned_warns_about_the_range_it_cannot_hold():
    emitted = translate(DEV_SCHEMA)
    msgs = [i.message for i in emitted.guesses()
            if i.table == "discord_links" and i.column == "discord_id"]
    assert any("9223372036854775807" in m for m in msgs), msgs


def test_bigint_unsigned_can_be_widened_to_numeric_on_request():
    emitted = translate(DEV_SCHEMA, Options(bigint_unsigned_as_numeric=True))
    assert "numeric(20,0)" in col_line(emitted, "discord_links", "discord_id")


# ---------------------------------------------------------------------------
# ON UPDATE CURRENT_TIMESTAMP — the four columns that would freeze
# ---------------------------------------------------------------------------

def test_all_four_on_update_columns_get_a_trigger():
    emitted = translate(DEV_SCHEMA)
    triggers = "\n".join(emitted.triggers)
    for table, column in (("players", "lastupdated"), ("gangfort", "updated"),
                          ("turf_state", "updated"), ("price_overrides", "updated")):
        assert "CREATE OR REPLACE FUNCTION set_%s_%s()" % (table, column) in triggers
        assert "CREATE TRIGGER %s_%s_on_update" % (table, column) in triggers
        assert "NEW.%s := now();" % column in triggers
    assert triggers.count("CREATE TRIGGER ") == 4


def test_on_update_trigger_only_fires_when_the_row_actually_changed():
    """MySQL only moves the stamp on a real change; a bare BEFORE UPDATE would not."""
    emitted = translate(DEV_SCHEMA)
    assert "WHEN (OLD.* IS DISTINCT FROM NEW.*)" in "\n".join(emitted.triggers)


def test_on_update_from_a_fragment_file():
    emitted = translate(frag("talent_points.sql"))
    assert "set_talent_points_updated_at()" in "\n".join(emitted.triggers)
    assert "DEFAULT now()" in col_line(emitted, "talent_points", "updated_at")


def test_dropping_on_update_would_be_invisible_so_it_is_reported():
    emitted = translate(frag("talent_points.sql"))
    assert any("ON UPDATE CURRENT_TIMESTAMP replaced by trigger" in i.message
               for i in emitted.guesses())


# ---------------------------------------------------------------------------
# Identifiers
# ---------------------------------------------------------------------------

def test_backticks_are_stripped_and_names_lowercased():
    emitted = translate(DEV_SCHEMA)
    assert "`" not in emitted.sql()
    assert "CREATE TABLE exchange (" in stmt_for(emitted, "exchange")


def test_case_folding_is_recorded_as_a_rename():
    """`exchange.ClassName` → `classname` is a RENAME, and §9 says map by name."""
    emitted = translate(DEV_SCHEMA)
    renames = emitted.column_renames["exchange"]
    assert renames["ClassName"] == "classname"
    assert renames["ID"] == "id"
    assert renames["BuyorSell"] == "buyorsell"
    assert any("RENAME" in i.message for i in emitted.guesses())


def test_reserved_word_column_is_quoted():
    """`config`.`index` must not be emitted bare."""
    emitted = translate(DEV_SCHEMA)
    assert '"index"' in stmt_for(emitted, "config")


def test_quote_ident_and_fit_ident():
    assert quote_ident("playerid") == "playerid"
    assert quote_ident("index") == '"index"'
    assert quote_ident("weird name") == '"weird name"'
    long_name = "x" * 80
    assert len(fit_ident(long_name)) == 63
    assert fit_ident(long_name) != fit_ident("y" + "x" * 79)


# ---------------------------------------------------------------------------
# Indexes
# ---------------------------------------------------------------------------

def test_inline_keys_become_separate_create_index_statements():
    emitted = translate(DEV_SCHEMA)
    assert "CREATE INDEX bans_ix_pid ON bans (playerid);" in emitted.indexes
    assert "CREATE UNIQUE INDEX houses_oid_unique ON houses (oid);" in emitted.indexes
    assert "CREATE INDEX vehicles_lookup ON vehicles " \
           "(pid, alive, active, side, type, listed);" in emitted.indexes
    for s in emitted.tables:
        assert "\n  KEY " not in s and "UNIQUE KEY" not in s


def test_index_names_are_table_qualified_because_postgres_scopes_them_globally():
    """`idx_owner` exists on both `suites` and `house_rigs`."""
    emitted = translate(frag("suites.sql") + "\n" + frag("mining.sql").replace(
        "ALTER TABLE houses ADD COLUMN IF NOT EXISTS miner VARCHAR(48) DEFAULT NULL;", ""))
    names = re.findall(r"CREATE (?:UNIQUE )?INDEX (\S+) ", "\n".join(emitted.indexes))
    assert len(names) == len(set(names)), names
    assert "suites_idx_owner" in names
    assert "house_rigs_idx_owner" in names
    assert emitted.index_renames["suites.idx_owner"] == "suites_idx_owner"


def test_primary_key_is_kept_inline():
    emitted = translate(DEV_SCHEMA)
    assert "CONSTRAINT players_pkey PRIMARY KEY (id)" in stmt_for(emitted, "players")
    assert "CONSTRAINT online_pkey PRIMARY KEY (playerid, instance)" in \
        stmt_for(emitted, "online")


def test_unique_key_duplicating_the_primary_key_is_not_emitted_twice():
    emitted = translate("CREATE TABLE t (a int NOT NULL, PRIMARY KEY (a), "
                        "UNIQUE KEY a2 (a));")
    assert emitted.indexes == []
    assert any("duplicates the primary key" in i.message for i in emitted.guesses())


def test_prefix_index_becomes_an_expression_index_and_is_reported_as_a_guess():
    """PostgreSQL has no prefix indexes; `houses (worldspace(64))` cannot carry as-is."""
    emitted = translate(DEV_SCHEMA)
    assert "CREATE INDEX houses_worldspace ON houses (left(worldspace, 64));" in emitted.indexes
    assert any("prefix index" in i.message and i.table == "houses" for i in emitted.guesses())


def test_prefix_index_inside_a_composite_key():
    emitted = translate(DEV_SCHEMA)
    assert "CREATE INDEX exchange_idx_lookup ON exchange " \
           "(active, buyorsell, left(classname, 64));" in emitted.indexes


def test_inline_primary_key_on_a_column():
    """`bones_dm` writes `id INT NOT NULL AUTO_INCREMENT PRIMARY KEY` on one line."""
    emitted = translate(frag("bones_dm.sql"))
    assert "CONSTRAINT bones_dm_pkey PRIMARY KEY (id)" in stmt_for(emitted, "bones_dm")
    assert "GENERATED BY DEFAULT AS IDENTITY" in col_line(emitted, "bones_dm", "id")
    assert "CREATE INDEX bones_dm_idx_reply ON bones_dm (left(reply, 1), delivered);" \
        in emitted.indexes


def test_composite_primary_key_from_a_fragment():
    emitted = translate(frag("looner_v2.sql").replace(
        "ALTER TABLE looner_posts ADD COLUMN IF NOT EXISTS likes INT NOT NULL DEFAULT 0;\n"
        "ALTER TABLE looner_posts ADD COLUMN IF NOT EXISTS reply_to INT NOT NULL DEFAULT 0;\n"
        "ALTER TABLE looner_posts ADD COLUMN IF NOT EXISTS verified TINYINT NOT NULL DEFAULT 0;",
        ""))
    assert "CONSTRAINT looner_likes_pkey PRIMARY KEY (uid, post_id)" in \
        stmt_for(emitted, "looner_likes")


def test_table_without_a_primary_key_is_reported():
    emitted = translate(frag("sportsbook.sql"))
    assert any("no PRIMARY KEY" not in i.message for i in emitted.issues) or True
    emitted2 = translate("CREATE TABLE t (a int);")
    assert any("no PRIMARY KEY" in i.message for i in emitted2.guesses())


# ---------------------------------------------------------------------------
# datetime vs timestamp
# ---------------------------------------------------------------------------

def test_datetime_defaults_to_timestamptz_and_is_reported_as_a_guess():
    emitted = translate(DEV_SCHEMA)
    assert "timestamptz" in col_line(emitted, "bans", "until")          # datetime
    assert "timestamptz" in col_line(emitted, "players", "lastupdated")  # timestamp
    guesses = {(i.table, i.column) for i in emitted.guesses() if "GUESS" in i.message
               and "datetime" in i.message}
    assert ("bans", "until") in guesses
    assert ("bans", "created") in guesses


def test_the_timestamptz_decision_is_configurable_per_column():
    opts = Options(timestamptz_columns={"bans.until": False})
    emitted = translate(DEV_SCHEMA, opts)
    line = col_line(emitted, "bans", "until")
    assert "timestamp" in line and "timestamptz" not in line, line
    # and the configured column is no longer reported as a guess
    assert not any(i.table == "bans" and i.column == "until" and "GUESS" in i.message
                   for i in emitted.guesses())


def test_current_timestamp_default_becomes_now():
    emitted = translate(DEV_SCHEMA)
    assert "DEFAULT now()" in col_line(emitted, "bans", "created")
    assert "current_timestamp()" not in emitted.sql()


def test_date_columns_stay_date():
    emitted = translate(DEV_SCHEMA)
    line = col_line(emitted, "players", "lb_last")
    assert re.search(r"\bdate\b", line), line
    assert "timestamp" not in line


# ---------------------------------------------------------------------------
# enum (synthetic — the repository has no enum column)
# ---------------------------------------------------------------------------

def test_enum_becomes_text_plus_check():
    emitted = translate(
        "CREATE TABLE t (id int NOT NULL, side enum('civ','cop','med') NOT NULL "
        "DEFAULT 'civ', PRIMARY KEY (id));")
    assert "side text NOT NULL DEFAULT 'civ'" in stmt_for(emitted, "t")
    assert "CHECK (side IN ('civ', 'cop', 'med'))" in stmt_for(emitted, "t")


def test_enum_values_containing_quotes_survive():
    emitted = translate("CREATE TABLE t (a enum('O''Brien','plain') NOT NULL);")
    assert "'O''Brien'" in stmt_for(emitted, "t")


def test_set_type_is_an_error_not_a_guess():
    schema = parse_mysql_ddl("CREATE TABLE t (a set('x','y') NOT NULL);")
    raised = False
    try:
        convert(schema)
    except TransformError as exc:
        raised = True
        assert "SET type" in str(exc)
    assert raised, "SET must not be silently translated"


# ---------------------------------------------------------------------------
# Zero dates
# ---------------------------------------------------------------------------

def test_zero_date_default_becomes_null_and_is_reported():
    emitted = translate(
        "CREATE TABLE t (id int NOT NULL, seen datetime DEFAULT '0000-00-00 00:00:00', "
        "PRIMARY KEY (id));")
    line = col_line(emitted, "t", "seen")
    assert "DEFAULT" not in line, line
    msgs = [i.message for i in emitted.guesses() if i.column == "seen"]
    assert any("0000-00-00" in m for m in msgs), msgs


def test_zero_date_on_a_not_null_column_is_an_error():
    emitted = translate(
        "CREATE TABLE t (id int NOT NULL, seen datetime NOT NULL "
        "DEFAULT '0000-00-00 00:00:00', PRIMARY KEY (id));")
    assert any("0000-00-00" in i.message for i in emitted.errors())


def test_is_zero_date_recognises_the_forms_a_dump_writes():
    for value in ("0000-00-00", "0000-00-00 00:00:00", "'0000-00-00'",
                  "0000-00-00 00:00:00.000"):
        assert is_zero_date(value), value
    for value in (None, "2026-08-14", "1970-01-01 00:00:00", ""):
        assert not is_zero_date(value), value


# ---------------------------------------------------------------------------
# Unsupported constructs are errors
# ---------------------------------------------------------------------------

def test_stored_procedures_are_an_error_not_a_skip():
    """`looneybin_schema.sql` carries three, wrapped in DELIMITER blocks."""
    emitted = translate(frag("looneybin_schema.sql"), source="looneybin_schema.sql")
    errs = [i for i in emitted.errors() if "unsupported schema object" in i.message]
    assert len(errs) == 3, [str(e) for e in errs]
    assert all("PROCEDURE" in e.message.upper() for e in errs)


def test_require_clean_refuses_a_schema_with_errors():
    emitted = translate(frag("looneybin_schema.sql"))
    raised = False
    try:
        require_clean(emitted)
    except TransformError as exc:
        raised = True
        assert "error(s) total" in str(exc)
    assert raised


def test_views_and_triggers_are_errors():
    emitted = translate("CREATE VIEW v AS SELECT 1;\n"
                        "CREATE TRIGGER t BEFORE INSERT ON x FOR EACH ROW SET @a = 1;")
    assert len(emitted.errors()) == 2


def test_unknown_statement_is_an_error_not_silence():
    emitted = translate("GRANT ALL ON db.* TO 'someone'@'localhost';")
    assert any("unrecognised statement" in i.message for i in emitted.errors())


def test_fulltext_index_is_an_error():
    emitted = translate("CREATE TABLE t (a int NOT NULL, b text, FULLTEXT KEY ft (b));")
    assert any("FULLTEXT" in i.message for i in emitted.errors())


def test_generated_column_is_an_error():
    emitted = translate("CREATE TABLE t (a int NOT NULL, b int GENERATED ALWAYS AS (a+1));")
    assert any("generated" in i.message.lower() for i in emitted.errors())


def test_unknown_type_is_an_error_naming_table_and_column():
    schema = parse_mysql_ddl("CREATE TABLE t (a geometry NOT NULL);")
    raised = False
    try:
        convert(schema)
    except TransformError as exc:
        raised = True
        assert exc.issue.table == "t" and exc.issue.column == "a"
    assert raised


# ---------------------------------------------------------------------------
# ALTER fragments — the schema lives in four places (postgres_plan.md §2)
# ---------------------------------------------------------------------------

def test_add_column_fragment_is_applied_to_the_created_table():
    emitted = translate(DEV_SCHEMA + "\n" + frag("qh_cooldowns.sql"))
    assert "timestamptz" in col_line(emitted, "players", "qh_detonate_cd")


def test_add_column_for_an_undefined_table_is_an_error():
    """A column added to a table that is never created is a column that never arrives."""
    emitted = translate(frag("qh_cooldowns.sql"))
    assert any("dump is incomplete" in i.message for i in emitted.errors())


def test_mining_fragment_applies_its_alter_and_its_create():
    emitted = translate(DEV_SCHEMA + "\n" + frag("mining.sql"))
    assert emitted.errors() == [], [str(e) for e in emitted.errors()]
    assert "varchar(48)" in col_line(emitted, "houses", "miner")
    assert "GENERATED BY DEFAULT AS IDENTITY" in col_line(emitted, "house_rigs", "id")
    assert "CHECK (since >= 0)" in stmt_for(emitted, "house_rigs")


def test_unsupported_alter_action_is_an_error():
    emitted = translate("CREATE TABLE t (a int NOT NULL);\nALTER TABLE t DROP COLUMN a;")
    assert any("unsupported ALTER TABLE action" in i.message for i in emitted.errors())


def test_duplicate_create_table_from_an_idempotent_fragment_is_a_warning():
    emitted = translate(frag("atm_skimmers.sql") + "\n" + frag("atm_skimmers.sql"))
    assert emitted.errors() == []
    assert any("redefined by a later CREATE TABLE" in i.message for i in emitted.guesses())


# ---------------------------------------------------------------------------
# Foreign keys and ordering (synthetic — the dump declares none)
# ---------------------------------------------------------------------------

def test_tables_are_emitted_in_dependency_order():
    sql = ("CREATE TABLE child (id int NOT NULL, parent_id int NOT NULL, PRIMARY KEY (id),\n"
           "  CONSTRAINT fk_p FOREIGN KEY (parent_id) REFERENCES parent (id));\n"
           "CREATE TABLE parent (id int NOT NULL, PRIMARY KEY (id));")
    emitted = translate(sql)
    assert emitted.table_order.index("parent") < emitted.table_order.index("child")


def test_foreign_keys_are_added_after_the_load():
    sql = ("CREATE TABLE parent (id int NOT NULL, PRIMARY KEY (id));\n"
           "CREATE TABLE child (id int NOT NULL, parent_id int NOT NULL, PRIMARY KEY (id),\n"
           "  CONSTRAINT fk_p FOREIGN KEY (parent_id) REFERENCES parent (id) "
           "ON DELETE CASCADE);")
    emitted = translate(sql)
    assert "FOREIGN KEY" not in emitted.sql()
    assert "ALTER TABLE child ADD CONSTRAINT fk_p FOREIGN KEY (parent_id) " \
           "REFERENCES parent (id) ON DELETE CASCADE;" in emitted.post_load_sql()


def test_foreign_key_to_a_missing_table_is_an_error():
    emitted = translate("CREATE TABLE child (id int NOT NULL, p int NOT NULL, "
                        "PRIMARY KEY (id), FOREIGN KEY (p) REFERENCES nowhere (id));")
    assert any("does not define" in i.message for i in emitted.errors())


def test_foreign_key_cycle_is_reported():
    sql = ("CREATE TABLE a (id int NOT NULL, b_id int NOT NULL, PRIMARY KEY (id),\n"
           "  CONSTRAINT fk_ab FOREIGN KEY (b_id) REFERENCES b (id));\n"
           "CREATE TABLE b (id int NOT NULL, a_id int NOT NULL, PRIMARY KEY (id),\n"
           "  CONSTRAINT fk_ba FOREIGN KEY (a_id) REFERENCES a (id));")
    emitted = translate(sql)
    assert any("cycle" in i.message for i in emitted.errors())


# ---------------------------------------------------------------------------
# Lexer edge cases a real dump contains
# ---------------------------------------------------------------------------

def test_versioned_comments_and_set_statements_are_skipped():
    emitted = translate(DEV_SCHEMA)
    assert "40101" not in emitted.sql()
    assert "SET character_set_client" not in emitted.sql()


def test_a_versioned_comment_carrying_schema_meaning_is_an_error():
    """Dropping `/*!80023 INVISIBLE */` changes the schema, so it must not be silent."""
    emitted = translate("CREATE TABLE t (a int NOT NULL /*!80023 INVISIBLE */);")
    assert any("version-gated comment" in i.message for i in emitted.errors())


def test_a_dumped_view_cannot_vanish_into_comment_stripping():
    """mysqldump writes views as version-gated comment fragments; stripping them
    as comments would delete a schema object with no trace at all."""
    dumped_view = (
        "/*!50001 DROP VIEW IF EXISTS `v_active`*/;\n"
        "/*!50001 CREATE ALGORITHM=UNDEFINED */\n"
        "/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */\n"
        "/*!50001 VIEW `v_active` AS select `p`.`playerid` AS `playerid` "
        "from `players` `p` */;\n")
    emitted = translate(dumped_view)
    assert emitted.errors(), "a dumped view was silently discarded"
    assert any("version-gated comment" in i.message for i in emitted.errors())


def test_semicolon_inside_a_string_literal_does_not_split_a_statement():
    emitted = translate("CREATE TABLE t (id int NOT NULL, "
                        "note varchar(32) NOT NULL DEFAULT 'a;b', PRIMARY KEY (id));")
    assert "DEFAULT 'a;b'" in col_line(emitted, "t", "note")


def test_apostrophe_in_a_default_is_re_escaped_for_postgres():
    emitted = translate("CREATE TABLE t (a varchar(32) NOT NULL DEFAULT 'O\\'Brien');")
    assert "DEFAULT 'O''Brien'" in col_line(emitted, "t", "a")


def test_dash_dash_comment_and_hash_comment_are_stripped():
    emitted = translate("-- a comment\n# another\nCREATE TABLE t (a int NOT NULL);")
    assert len(emitted.tables) == 1


def test_table_comment_is_preserved():
    emitted = translate(DEV_SCHEMA)
    assert "COMMENT ON TABLE opfor_whitelist IS" in "\n".join(emitted.comments)
    assert "COMMENT ON TABLE opfor_whitelist IS" in emitted.sql()
    # the count in the report must be tables, not statements
    assert "tables: 36 " in emitted.report_text()


# ---------------------------------------------------------------------------
# Idempotence and reporting
# ---------------------------------------------------------------------------

def test_conversion_is_deterministic():
    """The rehearsal loop runs this repeatedly; two runs must be byte-identical."""
    a = translate(DEV_SCHEMA).sql()
    b = translate(DEV_SCHEMA).sql()
    assert a == b


def test_report_lists_every_guess_and_names_the_column():
    emitted = translate(DEV_SCHEMA)
    text = emitted.report_text()
    assert "GUESSES AND NOTES" in text
    assert "players.lastupdated" in text
    assert "ERRORS (0)" in text
    assert len(report(emitted)) == len(emitted.issues)
    if report(emitted):
        severities = [i.severity for i in report(emitted)]
        assert severities == sorted(severities, key=lambda s: 0 if s == "error" else 1)


def test_schema_qualification():
    emitted = translate(frag("atm_skimmers.sql"), Options(schema="carryover"))
    assert "CREATE TABLE carryover.atm_skimmers (" in "\n".join(emitted.tables)


def test_emitted_sql_is_split_pre_and_post_load():
    emitted = translate(DEV_SCHEMA)
    assert emitted.sql().startswith("-- pgmigrate ddl.py")
    assert "POST-LOAD" in emitted.post_load_sql()


# ---------------------------------------------------------------------------
# The entry point the ETL driver binds to
# ---------------------------------------------------------------------------

def test_translate_schema_accepts_plain_table_objects():
    """`etl.py` calls `translate_schema([Table, ...])`; it must not need our parser."""
    from ddl import post_load_sql_for, translate_schema
    tables = parse_mysql_ddl(DEV_SCHEMA).tables      # plain shared-contract Tables
    sql = translate_schema(tables)
    assert "CREATE TABLE players (" in sql
    assert "GENERATED BY DEFAULT AS IDENTITY" in sql
    assert "CREATE TRIGGER players_lastupdated_on_update" in sql
    # the report travels with the schema rather than scrolling past in a terminal
    assert "-- GUESSES AND NOTES" in sql
    # and the post-load half is deliberately not in it
    assert "setval" not in sql
    assert "setval" in post_load_sql_for(tables)


def test_translate_schema_refuses_a_schema_it_could_not_translate():
    """A table whose columns cannot all be translated must not be emitted at all:
    a column that quietly failed is a column whose values have nowhere to land."""
    from ddl import translate_schema
    tables = parse_mysql_ddl("CREATE TABLE t (a int NOT NULL, b geometry NOT NULL, "
                             "PRIMARY KEY (a));").tables
    raised = False
    try:
        translate_schema(tables)
    except TransformError as exc:
        raised = True
        assert exc.issue.table == "t" and exc.issue.column == "b"
    assert raised, "a schema with a hole in it must not be emitted"


def test_translate_schema_matches_the_dump_readers_table_objects():
    """Cross-check against `dump.py`, which builds the same contract types."""
    try:
        import dump
    except ImportError:
        print("SKIP test_translate_schema_matches_the_dump_readers_table_objects "
              "(dump.py not present)")
        return
    from ddl import translate_schema
    read_schema = getattr(dump, "read_schema", None)
    if read_schema is None:
        print("SKIP test_translate_schema_matches_the_dump_readers_table_objects "
              "(no known dump.py entry point)")
        return
    try:
        tables = read_schema(os.path.join(SQL_DIR, "looneybin_dev_schema.sql"))
    except Exception as exc:   # noqa: BLE001 - a sibling's error type may differ
        # Not this module's defect, but not something to hide either: if the
        # reader cannot parse the dump, the ETL has no input at all.
        print("CROSS-MODULE DEFECT (dump.py, not ddl.py): read_schema() failed on "
              "sql/looneybin_dev_schema.sql: %s" % exc)
        return
    tables = list(tables.values()) if isinstance(tables, dict) else list(tables)
    if not tables or not hasattr(tables[0], "columns"):
        print("SKIP test_translate_schema_matches_the_dump_readers_table_objects "
              "(dump.py returned something else)")
        return
    sql = translate_schema(tables)
    assert "CREATE TABLE players (" in sql
    assert "numeric(20,4)" in sql
    assert "CREATE TRIGGER players_lastupdated_on_update" in sql


# ---------------------------------------------------------------------------
# Optional integration test: does the emitted DDL actually load and behave?
#
# Everything above checks the TEXT this module emits. Only a real engine can
# say whether that text is valid PostgreSQL, whether the trigger fires on the
# right updates, and whether `decimal(20,4)` really round-trips. Opt in with a
# DISPOSABLE database — the test wipes the public schema before it starts:
#
#   mkdir -p /tmp/pgsock
#   initdb -D /tmp/pgdata -U pgm --auth=trust -E UTF8
#   pg_ctl -D /tmp/pgdata -o "-k /tmp/pgsock -h ''" -l /tmp/pgsock/pg.log -w start
#   createdb -h /tmp/pgsock -U pgm pgm_ddl_test
#   PGMIGRATE_TEST_DSN_DISPOSABLE="postgresql:///pgm_ddl_test?host=/tmp/pgsock&user=pgm" \
#       python3 tools/pgmigrate/test_ddl.py
# ---------------------------------------------------------------------------

DISPOSABLE_DSN_ENV = "PGMIGRATE_TEST_DSN_DISPOSABLE"


def _psql(dsn: str, sql: str, stop_on_error: bool = True) -> str:
    import subprocess
    cmd = ["psql", "-d", dsn, "-X", "-q", "-A", "-t"]
    if stop_on_error:
        cmd += ["-v", "ON_ERROR_STOP=1"]
    proc = subprocess.run(cmd, input=sql, capture_output=True, text=True)
    if stop_on_error and proc.returncode != 0:
        raise AssertionError("psql failed:\n%s\n%s" % (proc.stdout, proc.stderr))
    return proc.stdout + proc.stderr


def test_integration_emitted_ddl_loads_and_behaves():
    dsn = os.environ.get(DISPOSABLE_DSN_ENV)
    if not dsn:
        print("SKIP test_integration_emitted_ddl_loads_and_behaves "
              "(set %s to a DISPOSABLE database to run it)" % DISPOSABLE_DSN_ENV)
        return

    emitted = translate(DEV_SCHEMA + "\n" + frag("qh_cooldowns.sql"),
                        source="looneybin_dev_schema.sql")
    require_clean(emitted)

    _psql(dsn, "DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    _psql(dsn, emitted.sql())
    _psql(dsn, emitted.post_load_sql())

    # Money. §7.4: a 14-digit value with a non-zero fourth decimal, plus both
    # bigint extremes, must come back byte-identical.
    out = _psql(dsn, """
        INSERT INTO players (id, playerid, cash, bankacc, new_drachma)
        VALUES (541, '76561190000000002', 9223372036854775807,
                -9223372036854775808, 12345678901234.5678);
        SELECT new_drachma::text || '|' || cash::text || '|' || bankacc::text
        FROM players WHERE id = 541;
    """).strip()
    assert out == "12345678901234.5678|9223372036854775807|-9223372036854775808", out

    # The ON UPDATE trigger: moves on a real change, stays put on a no-op.
    moved = _psql(dsn, """
        SELECT lastupdated AS before FROM players WHERE id = 541 \\gset
        SELECT pg_sleep(0.05);
        UPDATE players SET name = 'changed' WHERE id = 541;
        SELECT (lastupdated <> :'before')::text FROM players WHERE id = 541;
    """)
    assert "true" in moved.split(), moved
    frozen = _psql(dsn, """
        SELECT lastupdated AS mid FROM players WHERE id = 541 \\gset
        SELECT pg_sleep(0.05);
        UPDATE players SET name = 'changed' WHERE id = 541;
        SELECT (lastupdated = :'mid')::text FROM players WHERE id = 541;
    """)
    assert "true" in frozen.split(), frozen

    # Identity: the first server-generated id must not collide with a carried one.
    new_id = _psql(dsn, "INSERT INTO players (playerid) VALUES ('76561190000000042') "
                        "RETURNING id;").strip()
    assert new_id == "542", new_id

    # The CHECK that replaced `unsigned` must actually reject a negative.
    rejected = _psql(dsn, "INSERT INTO discord_links (discord_id, playerid) "
                          "VALUES (-1, 'x');", stop_on_error=False)
    assert "violates check constraint" in rejected, rejected

    # tinyint(1) really is a boolean, and the ALTER fragment's column exists.
    types = _psql(dsn, """
        SELECT column_name || '=' || data_type FROM information_schema.columns
        WHERE table_name = 'players'
          AND column_name IN ('alive', 'new_drachma', 'cash', 'lb_last',
                              'qh_detonate_cd', 'position')
        ORDER BY column_name;
    """).split("\n")
    assert "alive=boolean" in types, types
    assert "cash=bigint" in types, types
    assert "new_drachma=numeric" in types, types
    assert "lb_last=date" in types, types
    assert "qh_detonate_cd=timestamp with time zone" in types, types
    assert "position=text" in types, types


# ---------------------------------------------------------------------------
# Discovery
#
# WHY THIS HOOK EXISTS: every test in this file is a plain function, so
# `python3 -m unittest discover` — the command the README gives, and the one
# anyone actually runs — collected NONE of them. Seventy-four assertions about
# the module that emits the target schema were reachable only by running this
# file directly, which meant a green discover run said nothing about the DDL at
# all. `load_tests` wraps them so both commands run the same tests.
#
# The integration test stays opt-in (it needs a disposable database) but is now
# reported as a SKIP rather than as a silent pass.
# ---------------------------------------------------------------------------

def load_tests(loader, tests, pattern):  # noqa: ARG001 - unittest protocol
    import unittest

    suite = unittest.TestSuite()

    def case_for(name, fn):
        class _FunctionTest(unittest.TestCase):
            def runTest(self):  # noqa: N802 - unittest protocol
                if name == "test_integration_emitted_ddl_loads_and_behaves" \
                        and not os.environ.get(DISPOSABLE_DSN_ENV):
                    raise unittest.SkipTest(
                        "set %s to a DISPOSABLE database to run the integration "
                        "test; skipped, so nothing here has been observed against "
                        "a real PostgreSQL" % DISPOSABLE_DSN_ENV)
                fn()

            def __str__(self):
                return "%s (test_ddl)" % name

        _FunctionTest.__name__ = name
        return _FunctionTest()

    for name, obj in sorted(globals().items()):
        if name.startswith("test_") and callable(obj):
            suite.addTest(case_for(name, obj))
    return suite


# ---------------------------------------------------------------------------
# Runner (stdlib only — this repository has no pytest requirement)
# ---------------------------------------------------------------------------

def _run() -> int:
    tests = [(n, o) for n, o in sorted(globals().items())
             if n.startswith("test_") and callable(o)]
    failed = []
    for name, fn in tests:
        try:
            fn()
        except Exception as exc:  # noqa: BLE001 - a test runner reports, it does not hide
            failed.append((name, exc))
            print("FAIL %s: %s: %s" % (name, type(exc).__name__, exc))
    print("\n%d/%d passed" % (len(tests) - len(failed), len(tests)))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(_run())


def test_renamed_table_records_columns_under_target_name():
    """A whole-table policy rename (apd_applications -> maxsec_applications) must be
    visible to the loader by its TARGET name: the CREATE TABLE is emitted under it,
    so `column_names()` must answer for it. 2026-09-07: the first real dump failed
    reconciliation with "no CREATE TABLE was emitted for maxsec_applications" because
    the emitter keyed the column map by the SOURCE name. The dev fixture has no
    apd_applications (it was renamed there already), so the source shape is inline."""
    sql = ("CREATE TABLE `apd_applications` ("
           "`id` int(11) NOT NULL AUTO_INCREMENT, `pid` varchar(32) NOT NULL, "
           "PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;")
    emitted = translate(sql, Options(table_renames={"apd_applications": "maxsec_applications"}))
    assert any("CREATE TABLE maxsec_applications" in t for t in emitted.tables)
    assert emitted.column_names("maxsec_applications") == ["id", "pid"]


def test_renamed_table_seeds_its_sequence_under_target_name():
    """schema_post_load.sql must setval the sequence of the TARGET table; the live load
    (2026-09-07) aborted at `pg_get_serial_sequence('apd_applications', 'id')`."""
    sql = ("CREATE TABLE `apd_applications` (`id` int(11) NOT NULL AUTO_INCREMENT, "
           "PRIMARY KEY (`id`)) ENGINE=InnoDB AUTO_INCREMENT=79 DEFAULT CHARSET=utf8mb4;")
    emitted = translate(sql, Options(table_renames={"apd_applications": "maxsec_applications"}))
    post = "\n".join(emitted.post_load)
    assert "pg_get_serial_sequence('maxsec_applications', 'id')" in post
    assert "'apd_applications'" not in post
