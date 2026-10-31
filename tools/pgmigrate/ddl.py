"""MySQL `CREATE TABLE` DDL → PostgreSQL DDL, for the one-time carry-over.

WHY THIS EXISTS
    The source schema is a `mysqldump` file, and roughly every line of it is
    dialect the target engine will reject or, worse, accept with a different
    meaning. Four failures this module exists to prevent, all of them silent:

    1. **A frozen timestamp.** Four columns carry `ON UPDATE current_timestamp()`
       (`players.lastupdated`, `gangfort.updated`, `turf_state.updated`,
       `price_overrides.updated`). PostgreSQL has no column-level equivalent, so a
       naive translation drops the clause without error — and `lastupdated` drives
       an activity filter, which would then match every player forever.
       Translating it means emitting a trigger function and a trigger per column.
    2. **Money becoming a float.** `players.new_drachma` is `decimal(20,4)` and the
       balances are `bigint`. Anything that lands them in `double precision` is a
       rounding bug in the one column where rounding is theft. The type map here
       has no path from an exact type to an inexact one; `_map_type` raises rather
       than widen-to-float.
    3. **A renamed column nobody noticed.** MySQL identifiers are case-sensitive
       on disk; PostgreSQL folds unquoted names to lower case. `exchange.ClassName`
       becomes `classname`. That is a *rename*, and postgres_plan.md §9 is explicit
       that columns must be mapped by name — so every fold is recorded in
       `Emitted.column_renames` for the row transform to consume, never left
       implicit.
    4. **An index that silently vanished.** MySQL index names are unique per table;
       PostgreSQL's are unique per schema. `idx_owner` exists on both `suites` and
       `house_rigs`, and `idx_uid` on two more. Emitting them verbatim makes the
       second `CREATE INDEX` fail — or, if errors are being tolerated, leaves a
       table unindexed. Every index is therefore table-qualified.

    Anything this module cannot translate is an **error**, not a warning, and the
    error names the table and column. A guess is only ever allowed where the source
    is genuinely ambiguous (`datetime` vs `timestamp`), and every guess is listed in
    `report()` so a human signs it off before the load runs.

Usage:
    python3 -m pgmigrate.ddl live-dump.sql --out-dir /tmp/pgmigrate-out

    # or, from Python:
    >>> from pgmigrate.ddl import Options, translate
    >>> emitted = translate(open("live-dump.sql").read(), Options())   # doctest: +SKIP
    >>> print(emitted.sql())                       # pre-load: tables, indexes, triggers
    >>> print(emitted.post_load_sql())             # after the rows land: identity seeds, FKs
    >>> print(emitted.report_text())               # every guess and every unsupported thing

    Two output scripts, not one, and the order matters: identity sequences must be
    restarted *after* the rows with explicit ids are inserted, or the first new row
    on the new map collides with an imported one.

STATUS
    **Unvalidated against real data.** No live dump exists in this repository.

    What is checked ONLY WHEN THE OPT-IN INTEGRATION TEST IS RUN, and skipped by
    default: `test_ddl.test_integration_emitted_ddl_loads_and_behaves` runs only
    when `PGMIGRATE_TEST_DSN_DISPOSABLE` names a disposable database; without it
    the test is SKIPPED and none of the following has been observed in the run
    you just did. It has been run, once, against PostgreSQL 18.4 (2026-08-14),
    and when it runs it checks that the DDL
    emitted from `sql/looneybin_dev_schema.sql` plus the fragments loads without
    error, that the `ON UPDATE` triggers fire on a changed row and stay put on a
    no-op update, that the `unsigned` CHECKs reject negatives, that the identity
    sequences hand out an id past the carried ones, and that `decimal(20,4)`
    round-trips a 14-digit value with a non-zero fourth decimal byte-for-byte.

    Everything else in `test_ddl.py` proves only that this module emits the string
    it meant to. A green `python3 -m unittest discover` is that, and no more.

    What has NOT been checked: anything about the live schema. postgres_plan.md §2
    states the repository's picture of it is incomplete — six live columns exist
    only in a boot script, two tables exist only in runtime SQF, and a trigger
    exists on the live box that no `.sql` file here mentions. This module will
    report constructs it cannot translate rather than guess at them, but it has
    never seen the input it was written for. Do not treat a clean run here as
    evidence that the migration works.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from dataclasses import dataclass, field

# Import order matters more than it looks: `model` imported twice under two
# names produces two `TransformError` classes, and `except TransformError`
# silently stops catching the sibling modules' errors. `pgmigrate.model` is
# tried before a bare `model` so that direct execution lands on the same module
# object the package entry point uses.
try:  # package import (python3 -m pgmigrate.ddl, PYTHONPATH=tools)
    from .model import Column, Issue, Table, TransformError
except ImportError:
    try:
        from pgmigrate.model import Column, Issue, Table, TransformError  # type: ignore
    except ImportError:  # direct execution (python3 tools/pgmigrate/ddl.py)
        from model import Column, Issue, Table, TransformError  # type: ignore


# ---------------------------------------------------------------------------
# Identifiers
# ---------------------------------------------------------------------------

# PostgreSQL reserved words, plus a handful that are merely non-reserved but
# turn up as column names in this schema (`config`.`index`). Quoting a name that
# did not need it is a no-op — a double-quoted lower-case identifier is the same
# identifier — so this list errs deliberately towards over-quoting.
_PG_RESERVED = frozenset("""
all analyse analyze and any array as asc asymmetric authorization binary both case cast
check collate collation column concurrently constraint create cross current_catalog
current_date current_role current_schema current_time current_timestamp current_user
default deferrable desc distinct do else end except false fetch for foreign freeze from
full grant group having ilike in initially inner intersect into is isnull join lateral
leading left like limit localtime localtimestamp natural not notnull null offset on only
or order outer over overlaps placing primary references returning right select
session_user similar some symmetric table then to trailing true union unique user using
variadic verbose when where window with
index key
""".split())

_SAFE_IDENT = re.compile(r"^[a-z_][a-z0-9_$]*$")
_MAX_IDENT = 63  # PostgreSQL NAMEDATALEN - 1


def quote_ident(name: str) -> str:
    """Render an already-lower-cased identifier for PostgreSQL."""
    if _SAFE_IDENT.match(name) and name not in _PG_RESERVED:
        return name
    return '"' + name.replace('"', '""') + '"'


def fit_ident(name: str) -> str:
    """Truncate to PostgreSQL's identifier limit, keeping it collision-free.

    Silent truncation is how two different indexes become one index, so the
    truncated form carries a hash of the original rather than just its head.
    """
    if len(name) <= _MAX_IDENT:
        return name
    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    return name[: _MAX_IDENT - 9] + "_" + digest


def _unbacktick(tok: str) -> str:
    tok = tok.strip()
    if len(tok) >= 2 and tok[0] == "`" and tok[-1] == "`":
        return tok[1:-1].replace("``", "`")
    if len(tok) >= 2 and tok[0] == '"' and tok[-1] == '"':
        return tok[1:-1].replace('""', '"')
    return tok


# ---------------------------------------------------------------------------
# Lexing: a mysqldump is not line-oriented and not comment-free
# ---------------------------------------------------------------------------

# Bodies of MySQL's executable comments (/*!50503 ... */) are dropped. Most hold
# SET statements this module skips anyway — but two kinds carry real schema, and
# dropping either silently is the exact failure this module exists to prevent:
#
#   * column attributes:  `a int /*!80023 INVISIBLE */`
#   * whole objects:      mysqldump writes every VIEW as three version-gated
#     fragments (`/*!50001 CREATE ALGORITHM=UNDEFINED */`, `/*!50013 DEFINER=… */`,
#     `/*!50001 VIEW `v` AS select … */`). Strip those as comments and the view
#     vanishes without a trace — and postgres_plan.md §12 says the live box has
#     objects this repository has never seen.
_COMMENT_DANGER = re.compile(
    r"\b(INVISIBLE|VIRTUAL|STORED|GENERATED|CHECK|VIEW|TRIGGER|PROCEDURE|FUNCTION|"
    r"EVENT|ALGORITHM|DEFINER)\b", re.I)


@dataclass
class _Statement:
    text: str
    line: int


def _scan_statements(sql: str, issues: list[Issue], source: str) -> list[_Statement]:
    """Split a dump into statements, stripping comments but not string bodies.

    Handles `'`, `"` and backtick quoting (with both `\\'` and `''` escapes),
    `--` / `#` / `/* */` comments, MySQL's versioned comments, and `DELIMITER`
    — without which a dump containing a stored routine cannot even be split.
    """
    out: list[_Statement] = []
    buf: list[str] = []
    delim = ";"
    i = 0
    line = 1
    start_line = 1
    n = len(sql)

    def flush() -> None:
        text = "".join(buf).strip()
        buf.clear()
        if text:
            out.append(_Statement(text, start_line))

    while i < n:
        ch = sql[i]

        if ch == "\n":
            line += 1
            buf.append(ch)
            i += 1
            continue

        # statement-leading DELIMITER directive
        if not "".join(buf).strip():
            m = re.match(r"DELIMITER[ \t]+(\S+)", sql[i:], re.I)
            if m:
                delim = m.group(1)
                i += m.end()
                buf.clear()
                continue
            start_line = line

        if ch in ("'", '"', "`"):
            j = i + 1
            while j < n:
                if sql[j] == "\\" and ch != "`":
                    j += 2
                    continue
                if sql[j] == ch:
                    if j + 1 < n and sql[j + 1] == ch:  # doubled quote
                        j += 2
                        continue
                    j += 1
                    break
                if sql[j] == "\n":
                    line += 1
                j += 1
            else:
                raise TransformError(
                    Issue("error", source, None, None,
                          "unterminated %s-quoted literal starting at line %d" % (ch, line))
                )
            buf.append(sql[i:j])
            i = j
            continue

        if sql.startswith("--", i) and (i + 2 >= n or sql[i + 2] in " \t\r\n"):
            j = sql.find("\n", i)
            i = n if j == -1 else j
            continue

        if ch == "#":
            j = sql.find("\n", i)
            i = n if j == -1 else j
            continue

        if sql.startswith("/*", i):
            j = sql.find("*/", i + 2)
            if j == -1:
                raise TransformError(
                    Issue("error", source, None, None,
                          "unterminated block comment starting at line %d" % line)
                )
            body = sql[i + 2 : j]
            line += body.count("\n")
            if body.startswith("!") or body.startswith("M!"):
                if _COMMENT_DANGER.search(body):
                    issues.append(Issue(
                        "error", source, None, None,
                        "line %d: version-gated comment carries schema meaning and was "
                        "dropped: /*%s*/ — translate it by hand" % (start_line, body.strip()),
                    ))
            buf.append(" ")
            i = j + 2
            continue

        if sql.startswith(delim, i):
            i += len(delim)
            flush()
            continue

        buf.append(ch)
        i += 1

    flush()
    return out


def _split_top_level(text: str, sep: str = ",") -> list[str]:
    """Split on `sep` at paren depth 0, ignoring separators inside quotes."""
    parts: list[str] = []
    buf: list[str] = []
    depth = 0
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in ("'", '"', "`"):
            j = i + 1
            while j < n:
                if text[j] == "\\" and ch != "`":
                    j += 2
                    continue
                if text[j] == ch:
                    if j + 1 < n and text[j + 1] == ch:
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            buf.append(text[i:j])
            i = j
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == sep and depth == 0:
            parts.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    parts.append("".join(buf))
    return [p.strip() for p in parts if p.strip()]


def _match_paren(text: str, start: int) -> int:
    """Index just past the `)` matching the `(` at `start`."""
    depth = 0
    i = start
    n = len(text)
    while i < n:
        ch = text[i]
        if ch in ("'", '"', "`"):
            j = i + 1
            while j < n:
                if text[j] == "\\" and ch != "`":
                    j += 2
                    continue
                if text[j] == ch:
                    if j + 1 < n and text[j + 1] == ch:
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            i = j
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced parentheses")


# ---------------------------------------------------------------------------
# Parsed schema (the shared `Table` plus what the shared contract has no room for)
# ---------------------------------------------------------------------------

@dataclass
class IndexSpec:
    """One secondary index, before it is renamed for PostgreSQL's flat namespace."""

    name: str
    columns: list[str]          # raw MySQL forms, may include a prefix: "worldspace(64)"
    unique: bool
    method: str | None = None   # "btree" / "hash"


@dataclass
class ForeignKey:
    name: str
    columns: list[str]
    ref_table: str
    ref_columns: list[str]
    on_delete: str | None = None
    on_update: str | None = None


@dataclass
class TableExtras:
    """Per-table facts the shared `Table` dataclass deliberately does not carry."""

    source_name: str                                   # pre-fold, e.g. "exchange"
    auto_increment_seed: int | None = None
    comment: str | None = None
    foreign_keys: list[ForeignKey] = field(default_factory=list)
    index_specs: list[IndexSpec] = field(default_factory=list)
    column_source_names: dict[str, str] = field(default_factory=dict)  # folded -> original
    column_comments: dict[str, str] = field(default_factory=dict)
    declared_order: int = 0


@dataclass
class Schema:
    tables: list[Table] = field(default_factory=list)
    extras: dict[str, TableExtras] = field(default_factory=dict)
    issues: list[Issue] = field(default_factory=list)

    def by_name(self, name: str) -> Table | None:
        for t in self.tables:
            if t.name == name:
                return t
        return None


# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

@dataclass
class Options:
    """Every knob that changes emitted SQL. All of them default to the safe side.

    `timestamptz_columns` is the explicit half of the `datetime` vs `timestamp`
    decision: map "table.column" to True (timestamptz) or False (timestamp,
    i.e. naive wall clock). Anything not listed is a **guess**, reported by
    `report()`, so the list can be filled in from the report and the run repeated.

    THE POLICY CHANNEL — `boolean_columns`, `jsonb_columns`, `extra_columns`.
    This module translates the SOURCE schema; the carry-over policy (`rules.py`)
    decides three things about the TARGET that no amount of reading MySQL DDL can
    reveal, and if they are not passed in, the two files hold different ideas of
    the target shape and the mismatch surfaces at `psql` time with every internal
    check green:

    * `boolean_columns` — {(table, column)} that become a real `boolean`. An
      ALLOWLIST. Its whole reason for existing is that `players.intake_path` is
      declared `tinyint(1)` and holds 0/1/2/3/9, so the blanket
      `tinyint(1) -> boolean` rule destroys it — and for the values 0 and 1, most
      of them, it does so *silently*. Passing this (necessarily with
      `tinyint1_as_boolean=False`) is how the allowlist reaches the type map.
    * `jsonb_columns` — {(table, column)} that hold the bespoke array codec in the
      source and land as `jsonb` in the target (plan §7.1). Without it they map
      `text -> text`, the transcoded JSON is stored as an opaque string, and the
      single largest saving in the plan is silently not taken.
    * `extra_columns` — {table: {column: "<PostgreSQL definition>"}} for target
      columns the source has no counterpart for at all
      (`players.cyberdeck_modules`). The ETL writes them into the COPY header;
      this emits them into the CREATE TABLE.

    Names are matched folded to lower case, the same fold `_parse_column` applies.
    """

    timestamptz_columns: dict[str, bool] = field(default_factory=dict)
    default_timestamptz: bool = True
    source_timezone: str = "UTC"
    tinyint1_as_boolean: bool = True
    bigint_unsigned_as_numeric: bool = False
    schema: str | None = None
    boolean_columns: frozenset[tuple[str, str]] | None = None
    jsonb_columns: frozenset[tuple[str, str]] | None = None
    extra_columns: dict[str, dict[str, str]] = field(default_factory=dict)
    #: {source_table: target_table} for tables the policy renames whole.
    table_renames: dict[str, str] = field(default_factory=dict)
    #: {table: {source_column: target_column}} -- renames the CARRY POLICY asks for,
    #: as distinct from the case-folding renames this module discovers itself. The
    #: ETL renames on the way out, so without these the COPY header and the schema
    #: disagree by exactly the renamed column and psql fails on line one.
    policy_renames: dict[str, dict[str, str]] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if self.boolean_columns is not None:
            if self.tinyint1_as_boolean:
                raise ValueError(
                    "boolean_columns is an explicit allowlist and tinyint1_as_boolean "
                    "is a blanket rule; they contradict each other. Pass "
                    "tinyint1_as_boolean=False with an allowlist.")
            self.boolean_columns = frozenset(
                (t.lower(), c.lower()) for t, c in self.boolean_columns)
        if self.jsonb_columns is not None:
            self.jsonb_columns = frozenset(
                (t.lower(), c.lower()) for t, c in self.jsonb_columns)
        self.policy_renames = {
            t: {str(a): str(b) for a, b in cols.items()}
            for t, cols in (self.policy_renames or {}).items()
        }
        self.extra_columns = {
            t.lower(): {c.lower(): d for c, d in cols.items()}
            for t, cols in self.extra_columns.items()
        }

    def qualified(self, table: str) -> str:
        t = quote_ident(table)
        return quote_ident(self.schema) + "." + t if self.schema else t

    def is_boolean(self, table: str, column: str) -> bool:
        return (self.boolean_columns is not None
                and (table, column) in self.boolean_columns)

    def is_jsonb(self, table: str, column: str) -> bool:
        return (self.jsonb_columns is not None
                and (table, column) in self.jsonb_columns)


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

_CREATE_TABLE = re.compile(
    r"^CREATE\s+(?:TEMPORARY\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(`[^`]+`|\"[^\"]+\"|[A-Za-z0-9_$]+)"
    r"\s*(?:\.\s*(`[^`]+`|\"[^\"]+\"|[A-Za-z0-9_$]+))?\s*\(",
    re.I | re.S,
)
_ALTER_TABLE = re.compile(
    r"^ALTER\s+(?:ONLINE\s+)?TABLE\s+(`[^`]+`|\"[^\"]+\"|[A-Za-z0-9_$]+)\s+(.*)$", re.I | re.S
)
_CREATE_INDEX = re.compile(
    r"^CREATE\s+(UNIQUE\s+)?INDEX\s+(`[^`]+`|[A-Za-z0-9_$]+)\s+ON\s+"
    r"(`[^`]+`|[A-Za-z0-9_$]+)\s*\(", re.I | re.S
)

# statements a structure dump is full of and that carry no schema
_IGNORABLE = re.compile(
    r"^(SET|USE|DROP\s+(TABLE|VIEW|INDEX|PROCEDURE|FUNCTION|TRIGGER|DATABASE|EVENT)|"
    r"LOCK\s+TABLES|UNLOCK\s+TABLES|INSERT\s+|REPLACE\s+|CREATE\s+DATABASE|"
    r"CREATE\s+SCHEMA|COMMIT|START\s+TRANSACTION|BEGIN|FLUSH|ANALYZE|OPTIMIZE|"
    r"DELIMITER)\b",
    re.I,
)
# statements that are real schema this module cannot translate
_UNSUPPORTED_STMT = re.compile(
    r"^CREATE\s+(OR\s+REPLACE\s+)?(?:(DEFINER\s*=\s*\S+)\s+)?"
    r"(ALGORITHM|SQL\s+SECURITY|VIEW|TRIGGER|PROCEDURE|FUNCTION|EVENT|SERVER|"
    r"TABLESPACE|LOGFILE)\b",
    re.I,
)

# A type name is one word, or one of the two-word spellings MySQL accepts.
# Greedy multi-word matching would swallow the `NOT` of `int NOT NULL`.
_TYPE_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)((?:\s+(?:precision|varying|character))?)", re.I)
_TYPE_MODIFIERS = ("unsigned", "signed", "zerofill")


def _split_type(text: str) -> tuple[str, str, str]:
    """Read `base`, `(args)` and the rest off the front of a type declaration.

    The argument list is read with a paren matcher, not a regex: `enum('a)b')`
    contains a close paren inside a string literal, and a regex that stops at
    the first `)` silently truncates the value list.
    """
    m = _TYPE_RE.match(text)
    if not m:
        return "", "", text
    base = re.sub(r"\s+", " ", (m.group(1) + m.group(2)).strip().lower())
    rest = text[m.end():].lstrip()
    args = ""
    if rest.startswith("("):
        end = _match_paren(rest, 0)
        args = rest[1 : end - 1].strip()
        rest = rest[end:].lstrip()
    return base, args, rest

_KEY_RE = re.compile(
    r"^(?:(UNIQUE|FULLTEXT|SPATIAL)\s+)?(?:KEY|INDEX)\s*(`[^`]+`|\"[^\"]+\"|[A-Za-z0-9_$]+)?\s*"
    r"(?:USING\s+(BTREE|HASH)\s*)?\(",
    re.I | re.S,
)
_PK_RE = re.compile(r"^PRIMARY\s+KEY\s*(?:USING\s+\w+\s*)?\(", re.I | re.S)
_FK_RE = re.compile(
    r"^(?:CONSTRAINT\s+(`[^`]+`|[A-Za-z0-9_$]+)\s+)?FOREIGN\s+KEY\s*(?:\S+\s*)?\(", re.I | re.S
)
_CONSTRAINT_PREFIX = re.compile(r"^CONSTRAINT\s+(`[^`]+`|[A-Za-z0-9_$]+)\s+", re.I)

_KNOWN_TABLE_OPTIONS = re.compile(
    r"\b(ENGINE|DEFAULT\s+CHARSET|CHARSET|CHARACTER\s+SET|DEFAULT\s+CHARACTER\s+SET|COLLATE|"
    r"DEFAULT\s+COLLATE|AUTO_INCREMENT|COMMENT|ROW_FORMAT|PACK_KEYS|CHECKSUM|DELAY_KEY_WRITE|"
    r"KEY_BLOCK_SIZE|MAX_ROWS|MIN_ROWS|AVG_ROW_LENGTH|STATS_PERSISTENT|STATS_AUTO_RECALC|"
    r"STATS_SAMPLE_PAGES|TABLESPACE|COMPRESSION|ENCRYPTION|CONNECTION|DATA\s+DIRECTORY|"
    r"INDEX\s+DIRECTORY|INSERT_METHOD|UNION|TRANSACTIONAL|PAGE_CHECKSUM|PAGE_COMPRESSED)\b",
    re.I,
)


def _parse_string_literal(tok: str) -> str:
    """MySQL string literal → Python str (both `''` and `\\'` escapes)."""
    q = tok[0]
    body = tok[1:-1]
    out: list[str] = []
    i = 0
    while i < len(body):
        c = body[i]
        if c == "\\" and i + 1 < len(body):
            nxt = body[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", "0": "\0",
                        "b": "\b", "Z": "\x1a"}.get(nxt, nxt))
            i += 2
            continue
        if c == q and i + 1 < len(body) and body[i + 1] == q:
            out.append(q)
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _pg_string_literal(value: str) -> str:
    """Python str → PostgreSQL literal, without depending on backslash settings."""
    escaped = value.replace("'", "''")
    if "\\" in value:
        return "E'" + escaped.replace("\\", "\\\\") + "'"
    return "'" + escaped + "'"


def _read_default(text: str) -> tuple[str, str]:
    """Read a DEFAULT expression off the front of `text`; return (expr, rest)."""
    text = text.lstrip()
    if not text:
        return "", ""
    if text[0] == "(":
        end = _match_paren(text, 0)
        return text[:end], text[end:]
    if text[0] in ("'", '"'):
        q = text[0]
        i = 1
        while i < len(text):
            if text[i] == "\\":
                i += 2
                continue
            if text[i] == q:
                if i + 1 < len(text) and text[i + 1] == q:
                    i += 2
                    continue
                i += 1
                break
            i += 1
        return text[:i], text[i:]
    m = re.match(r"[-+]?[A-Za-z0-9_.]+", text)
    if not m:
        return "", text
    end = m.end()
    rest = text[end:]
    if rest[:1] == "(":  # function call, e.g. current_timestamp()
        close = _match_paren(rest, 0)
        return text[: end + close], rest[close:]
    return text[:end], rest


@dataclass
class _ParsedColumn:
    """A parsed column plus the per-column facts the shared contract has no room for.

    WHY NOT ATTRIBUTES ON `Column`: `model.Column` belongs to the shared contract
    and is used by every module. Hanging `_inline_pk`/`_inline_unique`/`_comment`
    on it worked only because that dataclass happens to have a `__dict__` —
    adding `__slots__` to it later (the obvious thing to do for memory on a large
    dump) would break this parser at its first column, in a module whose author
    never touched `model.py`.
    """

    column: Column
    inline_pk: bool = False
    inline_unique: bool = False
    comment: str | None = None


def _parse_column(defn: str, table: str, source: str, issues: list[Issue]) -> _ParsedColumn:
    m = re.match(r"^(`[^`]+`|\"[^\"]+\"|[A-Za-z0-9_$]+)\s+(.*)$", defn, re.S)
    if not m:
        raise TransformError(Issue("error", table, None, None,
                                   "cannot parse column definition: %r" % defn))
    name = _unbacktick(m.group(1))
    rest = m.group(2).strip()

    base, args, rest = _split_type(rest)
    if not base:
        raise TransformError(Issue("error", table, name, None,
                                   "cannot parse column type in: %r" % defn))
    args = "(%s)" % args if args else ""
    rest = rest.strip()

    mods: list[str] = []
    while True:
        wm = re.match(r"^(unsigned|signed|zerofill)\b", rest, re.I)
        if not wm:
            break
        mods.append(wm.group(1).lower())
        rest = rest[wm.end():].strip()

    # charset/collation on the column: display-layer only, dropped
    while True:
        cm = re.match(r"^(?:CHARACTER\s+SET|CHARSET|COLLATE)\s+\S+\s*", rest, re.I)
        if not cm:
            break
        rest = rest[cm.end():].strip()

    mysql_type = (base + args + (" " + " ".join(mods) if mods else "")).strip()

    nullable = True
    default: str | None = None
    extra: list[str] = []
    inline_pk = False
    inline_unique = False
    comment: str | None = None

    while rest:
        if re.match(r"^NOT\s+NULL\b", rest, re.I):
            nullable = False
            rest = re.sub(r"^NOT\s+NULL\s*", "", rest, flags=re.I)
            continue
        if re.match(r"^NULL\b", rest, re.I):
            nullable = True
            rest = re.sub(r"^NULL\s*", "", rest, flags=re.I)
            continue
        if re.match(r"^AUTO_INCREMENT\b", rest, re.I):
            extra.append("auto_increment")
            rest = re.sub(r"^AUTO_INCREMENT\s*", "", rest, flags=re.I)
            continue
        if re.match(r"^DEFAULT\b", rest, re.I):
            rest = re.sub(r"^DEFAULT\s*", "", rest, flags=re.I)
            default, rest = _read_default(rest)
            rest = rest.strip()
            continue
        if re.match(r"^ON\s+UPDATE\b", rest, re.I):
            rest = re.sub(r"^ON\s+UPDATE\s*", "", rest, flags=re.I)
            expr, rest = _read_default(rest)
            # Lower-cased to match `dump._parse_column`, the other producer of
            # this field; `model.Column.on_update` is the reader both agree with.
            extra.append("on update " + expr.lower())
            rest = rest.strip()
            continue
        if re.match(r"^PRIMARY\s+KEY\b", rest, re.I):
            inline_pk = True
            rest = re.sub(r"^PRIMARY\s+KEY\s*", "", rest, flags=re.I)
            continue
        if re.match(r"^UNIQUE(\s+KEY)?\b", rest, re.I):
            inline_unique = True
            rest = re.sub(r"^UNIQUE(\s+KEY)?\s*", "", rest, flags=re.I)
            continue
        if re.match(r"^KEY\b", rest, re.I):
            extra.append("index")
            rest = re.sub(r"^KEY\s*", "", rest, flags=re.I)
            continue
        if re.match(r"^COMMENT\b", rest, re.I):
            rest = re.sub(r"^COMMENT\s*", "", rest, flags=re.I)
            lit, rest = _read_default(rest)
            if lit[:1] in ("'", '"'):
                comment = _parse_string_literal(lit)
            rest = rest.strip()
            continue
        if re.match(r"^(GENERATED\s+ALWAYS\s+AS|AS)\s*\(", rest, re.I):
            issues.append(Issue(
                "error", table, name, None,
                "generated/computed column is not translated: %r — decide whether the "
                "target stores it or recomputes it, and write it by hand" % defn,
            ))
            break
        if re.match(r"^(VIRTUAL|STORED|PERSISTENT|INVISIBLE|SERIAL\s+DEFAULT\s+VALUE|"
                    r"COLUMN_FORMAT\s+\S+|STORAGE\s+\S+|CHECK\s*\()", rest, re.I):
            issues.append(Issue(
                "error", table, name, None,
                "unsupported column attribute in %r — translate it by hand" % rest.strip(),
            ))
            break
        if re.match(r"^(REFERENCES)\b", rest, re.I):
            issues.append(Issue(
                "warn", table, name, None,
                "inline REFERENCES clause dropped; declare the foreign key at table level",
            ))
            break
        issues.append(Issue(
            "error", table, name, None,
            "unrecognised column attribute %r in definition %r" % (rest.strip()[:40], defn),
        ))
        break

    return _ParsedColumn(
        column=Column(name=name, mysql_type=mysql_type, nullable=nullable,
                      default=default, extra=" ".join(extra)),
        inline_pk=inline_pk,
        inline_unique=inline_unique,
        comment=comment,
    )


def _plain_index_column(raw: str) -> str:
    """`worldspace(64) DESC` → `worldspace`. The bare name, for the shared model."""
    return re.sub(r"\s+(ASC|DESC)$", "", re.sub(r"\(.*", "", raw), flags=re.I).strip().lower()


def _parse_index_columns(spec: str) -> list[str]:
    """Index column list → plain names, keeping any prefix length and direction.

    `` `worldspace`(64) `` must lose its backticks and keep its `(64)`: the
    prefix is the part PostgreSQL has no equivalent for, and dropping it here
    would turn a reported guess into a silent change of meaning.
    """
    out: list[str] = []
    for raw in _split_top_level(spec):
        raw = raw.strip()
        m = re.match(r"^(`[^`]*`|\"[^\"]*\"|[^\s(]+)\s*(\(\s*\d+\s*\))?\s*(ASC|DESC)?$",
                     raw, re.I)
        if not m:
            out.append(_unbacktick(raw))
            continue
        name = _unbacktick(m.group(1))
        suffix = re.sub(r"\s+", "", m.group(2) or "")
        direction = (" " + m.group(3).upper()) if m.group(3) else ""
        out.append(name + suffix + direction)
    return out


def _parse_create_table(stmt: _Statement, schema: Schema, source: str, opts: Options) -> None:
    m = _CREATE_TABLE.match(stmt.text)
    if not m:
        raise TransformError(Issue("error", source, None, None,
                                   "line %d: cannot parse CREATE TABLE" % stmt.line))
    raw_name = _unbacktick(m.group(2) or m.group(1))
    table_name = raw_name.lower()

    open_paren = m.end() - 1
    close = _match_paren(stmt.text, open_paren)
    body = stmt.text[open_paren + 1 : close - 1]
    tail = stmt.text[close:].strip()

    if schema.by_name(table_name) is not None:
        schema.issues.append(Issue(
            "warn", table_name, None, None,
            "line %d: redefined by a later CREATE TABLE; the first definition is kept "
            "(fragments in sql/ are idempotent `IF NOT EXISTS` forms)" % stmt.line,
        ))
        return

    table = Table(name=table_name, columns=[], primary_key=[], indexes=[])
    extras = TableExtras(source_name=raw_name, declared_order=len(schema.tables))

    for item in _split_top_level(body):
        if _PK_RE.match(item):
            start = item.index("(")
            end = _match_paren(item, start)
            table.primary_key = _parse_index_columns(item[start + 1 : end - 1])
            continue

        km = _KEY_RE.match(item)
        if km:
            kind = (km.group(1) or "").lower()
            if kind in ("fulltext", "spatial"):
                schema.issues.append(Issue(
                    "error", table_name, None, None,
                    "%s index %r has no direct PostgreSQL equivalent — translate it by hand "
                    "(GIN/tsvector or PostGIS)" % (kind.upper(), _unbacktick(km.group(2) or "")),
                ))
                continue
            start = item.index("(", km.end() - 1)
            end = _match_paren(item, start)
            cols = _parse_index_columns(item[start + 1 : end - 1])
            idx_name = _unbacktick(km.group(2) or "").lower() or ("_".join(
                _plain_index_column(c) for c in cols))
            extras.index_specs.append(IndexSpec(
                name=idx_name, columns=cols, unique=(kind == "unique"),
                method=(km.group(3) or "").lower() or None,
            ))
            continue

        fm = _FK_RE.match(item)
        if fm:
            start = item.index("(", fm.end() - 1)
            end = _match_paren(item, start)
            cols = _parse_index_columns(item[start + 1 : end - 1])
            rm = re.search(r"REFERENCES\s+(`[^`]+`|[A-Za-z0-9_$]+)\s*\(", item[end:], re.I)
            if not rm:
                schema.issues.append(Issue(
                    "error", table_name, None, None,
                    "FOREIGN KEY without a parseable REFERENCES clause: %r" % item))
                continue
            ref_start = end + rm.end() - 1
            ref_end = _match_paren(item, ref_start)
            ref_cols = _parse_index_columns(item[ref_start + 1 : ref_end - 1])
            rest = item[ref_end:]
            od = re.search(r"ON\s+DELETE\s+(CASCADE|SET\s+NULL|RESTRICT|NO\s+ACTION|SET\s+DEFAULT)",
                           rest, re.I)
            ou = re.search(r"ON\s+UPDATE\s+(CASCADE|SET\s+NULL|RESTRICT|NO\s+ACTION|SET\s+DEFAULT)",
                           rest, re.I)
            name = _unbacktick(fm.group(1) or "").lower() or "%s_%s_fkey" % (
                table_name, "_".join(cols))
            extras.foreign_keys.append(ForeignKey(
                name=name, columns=[c.lower() for c in cols],
                ref_table=_unbacktick(rm.group(1)).lower(),
                ref_columns=[c.lower() for c in ref_cols],
                on_delete=od.group(1).upper() if od else None,
                on_update=ou.group(1).upper() if ou else None,
            ))
            continue

        if re.match(r"^(CONSTRAINT\s+\S+\s+)?CHECK\s*\(", item, re.I):
            schema.issues.append(Issue(
                "error", table_name, None, None,
                "source CHECK constraint is not translated: %r — MySQL and PostgreSQL "
                "differ on what a CHECK may reference; translate it by hand" % item,
            ))
            continue

        cm = _CONSTRAINT_PREFIX.match(item)
        if cm and re.match(r"^(UNIQUE|PRIMARY)", item[cm.end():], re.I):
            item = item[cm.end():]
            if _PK_RE.match(item):
                start = item.index("(")
                table.primary_key = _parse_index_columns(item[start + 1 : _match_paren(item, start) - 1])
            else:
                km2 = _KEY_RE.match(item)
                if km2:
                    start = item.index("(", km2.end() - 1)
                    end = _match_paren(item, start)
                    extras.index_specs.append(IndexSpec(
                        name=_unbacktick(cm.group(1)).lower(),
                        columns=_parse_index_columns(item[start + 1 : end - 1]),
                        unique=True,
                    ))
            continue

        parsed = _parse_column(item, table_name, source, schema.issues)
        col = parsed.column
        folded = col.name.lower()
        if folded != col.name:
            schema.issues.append(Issue(
                "warn", table_name, col.name, None,
                "identifier folded to lower case (%r → %r): this is a RENAME, and the row "
                "transform must map it by name" % (col.name, folded),
            ))
        extras.column_source_names[folded] = col.name
        if parsed.comment:
            extras.column_comments[folded] = parsed.comment
        col.name = folded
        table.columns.append(col)
        if parsed.inline_pk:
            table.primary_key.append(folded)
        if parsed.inline_unique:
            extras.index_specs.append(IndexSpec(
                name="%s_key" % folded, columns=[folded], unique=True))

    # table options
    if tail:
        am = re.search(r"\bAUTO_INCREMENT\s*=\s*(\d+)", tail, re.I)
        if am:
            extras.auto_increment_seed = int(am.group(1))
        cm2 = re.search(r"\bCOMMENT\s*=\s*('(?:[^'\\]|\\.|'')*')", tail, re.I)
        if cm2:
            extras.comment = _parse_string_literal(cm2.group(1))
        if re.search(r"\bPARTITION\s+BY\b", tail, re.I):
            schema.issues.append(Issue(
                "error", table_name, None, None,
                "PARTITION BY clause is not translated — declarative partitioning differs; "
                "translate it by hand",
            ))
        leftovers = _KNOWN_TABLE_OPTIONS.sub(" ", tail)
        leftovers = re.sub(r"=\s*('(?:[^'\\]|\\.|'')*'|\"(?:[^\"\\]|\\.)*\"|[A-Za-z0-9_.]+)",
                           " ", leftovers)
        leftovers = re.sub(r"[\s,;=]+", " ", leftovers).strip()
        if leftovers and not re.match(r"^(PARTITION BY.*)$", leftovers, re.I):
            schema.issues.append(Issue(
                "warn", table_name, None, None,
                "unrecognised table options dropped: %r" % leftovers,
            ))

    table.indexes = [(i.name, [_plain_index_column(c) for c in i.columns], i.unique)
                     for i in extras.index_specs]
    schema.tables.append(table)
    schema.extras[table_name] = extras


def _parse_alter_table(stmt: _Statement, schema: Schema, source: str) -> None:
    m = _ALTER_TABLE.match(stmt.text)
    if not m:
        raise TransformError(Issue("error", source, None, None,
                                   "line %d: cannot parse ALTER TABLE" % stmt.line))
    table_name = _unbacktick(m.group(1)).lower()
    table = schema.by_name(table_name)

    for action in _split_top_level(m.group(2)):
        add_col = re.match(
            r"^ADD\s+(?:COLUMN\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(.*)$", action, re.I | re.S)
        add_key = re.match(
            r"^ADD\s+(?:CONSTRAINT\s+\S+\s+)?(UNIQUE\s+)?(?:KEY|INDEX)\s+(.*)$",
            action, re.I | re.S)

        if add_key and re.search(r"\(", add_key.group(2)):
            if table is None:
                schema.issues.append(Issue(
                    "error", table_name, None, None,
                    "line %d: ALTER TABLE adds an index to a table that no CREATE TABLE in "
                    "this input defines — the dump is incomplete" % stmt.line))
                continue
            rest = add_key.group(2)
            nm = re.match(r"^(`[^`]+`|[A-Za-z0-9_$]+)?\s*\(", rest)
            start = rest.index("(")
            end = _match_paren(rest, start)
            cols = _parse_index_columns(rest[start + 1 : end - 1])
            name = _unbacktick(nm.group(1) or "").lower() if nm and nm.group(1) else \
                "_".join(_plain_index_column(c) for c in cols)
            schema.extras[table_name].index_specs.append(
                IndexSpec(name=name, columns=cols, unique=bool(add_key.group(1))))
            continue

        if add_col and not re.match(r"^(KEY|INDEX|UNIQUE|PRIMARY|CONSTRAINT|FOREIGN)\b",
                                    add_col.group(1), re.I):
            if table is None:
                schema.issues.append(Issue(
                    "error", table_name, None, None,
                    "line %d: ALTER TABLE adds a column to a table that no CREATE TABLE in "
                    "this input defines — the dump is incomplete, and a column added to a "
                    "table that is not created is a column that never arrives" % stmt.line))
                continue
            col = _parse_column(add_col.group(1).strip(), table_name, source,
                                schema.issues).column
            folded = col.name.lower()
            if any(c.name == folded for c in table.columns):
                schema.issues.append(Issue(
                    "warn", table_name, folded, None,
                    "line %d: ALTER TABLE ADD COLUMN IF NOT EXISTS for a column the "
                    "CREATE TABLE already declares; the CREATE TABLE wins" % stmt.line))
                continue
            schema.extras[table_name].column_source_names[folded] = col.name
            col.name = folded
            table.columns.append(col)
            continue

        schema.issues.append(Issue(
            "error", table_name, None, None,
            "line %d: unsupported ALTER TABLE action %r — this module translates "
            "ADD COLUMN and ADD [UNIQUE] KEY only" % (stmt.line, action.strip()[:60]),
        ))


def _parse_create_index(stmt: _Statement, schema: Schema) -> None:
    m = _CREATE_INDEX.match(stmt.text)
    if not m:
        return
    table_name = _unbacktick(m.group(3)).lower()
    if table_name not in schema.extras:
        schema.issues.append(Issue(
            "error", table_name, None, None,
            "line %d: CREATE INDEX on a table no CREATE TABLE in this input defines"
            % stmt.line))
        return
    start = stmt.text.index("(", m.end() - 1)
    end = _match_paren(stmt.text, start)
    schema.extras[table_name].index_specs.append(IndexSpec(
        name=_unbacktick(m.group(2)).lower(),
        columns=_parse_index_columns(stmt.text[start + 1 : end - 1]),
        unique=bool(m.group(1)),
    ))


def parse_mysql_ddl(sql: str, source: str = "<dump>", opts: Options | None = None) -> Schema:
    """Parse every `CREATE TABLE` (and supported `ALTER`) in a mysqldump.

    Unsupported *statements* — views, triggers, stored routines, events — are
    recorded as errors rather than skipped, because postgres_plan.md §12 states a
    trigger exists on the live box that no file in this repository mentions.
    """
    opts = opts or Options()
    schema = Schema()
    for stmt in _scan_statements(sql, schema.issues, source):
        head = stmt.text.lstrip()
        if _IGNORABLE.match(head):
            continue
        if _UNSUPPORTED_STMT.match(head):
            what = re.sub(r"\s+", " ", head[:80])
            schema.issues.append(Issue(
                "error", source, None, None,
                "line %d: unsupported schema object, not translated: %r … — views, "
                "triggers, stored routines and events must be ported by hand"
                % (stmt.line, what),
            ))
            continue
        if _CREATE_TABLE.match(head):
            _parse_create_table(stmt, schema, source, opts)
            continue
        if _CREATE_INDEX.match(head):
            _parse_create_index(stmt, schema)
            continue
        if _ALTER_TABLE.match(head):
            _parse_alter_table(stmt, schema, source)
            continue
        schema.issues.append(Issue(
            "error", source, None, None,
            "line %d: unrecognised statement, not translated: %r"
            % (stmt.line, re.sub(r"\s+", " ", head[:80])),
        ))
    return schema


# ---------------------------------------------------------------------------
# Type mapping
# ---------------------------------------------------------------------------

_ZERO_DATE = re.compile(r"^'?0000-00-00([ T]00:00:00(\.0+)?)?'?$")

_TEXT_TYPES = {"tinytext": "text", "text": "text", "mediumtext": "text", "longtext": "text"}
_BLOB_TYPES = {"tinyblob", "blob", "mediumblob", "longblob", "binary", "varbinary"}
_EXACT_NUMERIC = {"decimal", "numeric", "dec", "fixed"}


def is_zero_date(value: object) -> bool:
    """True for MySQL's zero date in any of the forms a dump writes it.

    Exposed for the row transform: the zero date is a *value* problem as much as
    a default problem, and both sides must agree on what counts as one.
    """
    if value is None:
        return False
    return bool(_ZERO_DATE.match(str(value).strip()))


@dataclass
class _MappedType:
    pg_type: str
    checks: list[str] = field(default_factory=list)   # table-level CHECK expressions
    notes: list[Issue] = field(default_factory=list)


def _map_type(table: str, col: Column, opts: Options) -> _MappedType:
    raw = col.mysql_type.strip()
    mods = set()
    for m in _TYPE_MODIFIERS:
        if re.search(r"\b%s\b" % m, raw, re.I):
            mods.add(m)
            raw = re.sub(r"\s*\b%s\b" % m, "", raw, flags=re.I)
    unsigned = "unsigned" in mods or "zerofill" in mods
    base, args, leftover = _split_type(raw.strip())
    if not base or leftover.strip():
        raise TransformError(Issue("error", table, col.name, None,
                                   "cannot parse MySQL type %r" % col.mysql_type))
    q = quote_ident(col.name)
    out = _MappedType(pg_type="")
    nonneg = "%s >= 0" % q

    def note(sev: str, msg: str) -> None:
        out.notes.append(Issue(sev, table, col.name, None, msg))

    # --- the policy channel, before the source's own type has a say ----------
    # These two are decisions about the TARGET (Options), not readings of the
    # source. They come first so a column cannot be mapped by its MySQL type and
    # then quietly disagree with the policy that names it.
    if opts.is_jsonb(table, col.name):
        if base not in _TEXT_TYPES and base not in ("varchar", "char", "character",
                                                    "character varying", "json"):
            raise TransformError(Issue(
                "error", table, col.name, None,
                "the carry-over policy transcodes this column to jsonb, but the source "
                "declares it %r — the transcoder reads TEXT. One of the two is wrong; "
                "no type is guessed here." % col.mysql_type))
        out.pg_type = "jsonb"
        note("warn", "transcoded to jsonb by carry-over policy (plan §7.1): the bespoke "
                     "array codec is decoded once, in the ETL, and never emitted again. "
                     "The target stores a JSON document, not a string that looks like one.")
        return out

    if opts.is_boolean(table, col.name):
        if base not in ("tinyint", "smallint", "int", "integer", "bit", "bool", "boolean"):
            raise TransformError(Issue(
                "error", table, col.name, None,
                "the carry-over policy declares this column a flag, but the source "
                "declares it %r; a boolean cast of that is not a translation."
                % col.mysql_type))
        out.pg_type = "boolean"
        if unsigned:
            note("warn", "unsigned dropped: the column maps to boolean, where it "
                         "cannot express a range")
        return out

    if base == "tinyint":
        width = args.strip()
        if width == "1" and opts.tinyint1_as_boolean:
            out.pg_type = "boolean"
            if unsigned:
                note("warn", "unsigned dropped: the column maps to boolean, where it "
                             "cannot express a range")
            return out
        if width == "":
            out.pg_type = "smallint"
            note("warn", "GUESS: `tinyint` with no display width — mapped to smallint. "
                         "MySQL 8 omits display widths, so this may have been `tinyint(1)`, "
                         "i.e. a boolean. Confirm against the data before loading.")
            if unsigned:
                out.checks.append(nonneg)
            return out
        out.pg_type = "smallint"
        if unsigned:
            out.checks.append(nonneg)
        return out

    if base == "smallint":
        out.pg_type = "integer" if unsigned else "smallint"
        if unsigned:
            out.checks.append(nonneg)
            note("warn", "unsigned smallint widened to integer so the full 0..65535 range "
                         "survives; the CHECK keeps the sign constraint")
        return out

    if base in ("mediumint", "int", "integer"):
        if base == "mediumint":
            out.pg_type = "integer"
        else:
            out.pg_type = "bigint" if unsigned else "integer"
            if unsigned:
                note("warn", "unsigned int widened to bigint so the full 0..4294967295 "
                             "range survives; the CHECK keeps the sign constraint")
        if unsigned:
            out.checks.append(nonneg)
        return out

    if base == "bigint":
        if unsigned:
            if opts.bigint_unsigned_as_numeric:
                out.pg_type = "numeric(20,0)"
                note("warn", "unsigned bigint mapped to numeric(20,0) to keep the full "
                             "unsigned range; still an exact integer type, never a float")
            else:
                out.pg_type = "bigint"
                note("warn", "unsigned bigint mapped to bigint: values above 2^63-1 "
                             "(9223372036854775807) CANNOT be represented and will fail the "
                             "load. Set Options.bigint_unsigned_as_numeric if the source "
                             "holds any. The CHECK keeps the sign constraint.")
            out.checks.append(nonneg)
        else:
            out.pg_type = "bigint"
        return out

    if base in _EXACT_NUMERIC:
        # Currency lives here. There is deliberately no path from an exact type to
        # an inexact one: postgres_plan.md §7.4 rests on this value never becoming
        # a float.
        out.pg_type = "numeric(%s)" % args if args else "numeric"
        if unsigned:
            out.checks.append(nonneg)
        return out

    if base in ("float",):
        out.pg_type = "real"
        if unsigned:
            out.checks.append(nonneg)
        return out

    if base in ("double", "double precision", "real"):
        out.pg_type = "double precision"
        if unsigned:
            out.checks.append(nonneg)
        return out

    if base in ("bit",):
        if args in ("", "1"):
            out.pg_type = "boolean"
            note("warn", "GUESS: bit(1) mapped to boolean")
            return out
        out.pg_type = "bit(%s)" % args
        return out

    if base in ("char", "character"):
        out.pg_type = "char(%s)" % args if args else "char(1)"
        return out

    if base in ("varchar", "character varying", "varying character"):
        if not args:
            raise TransformError(Issue("error", table, col.name, None,
                                       "varchar with no length"))
        out.pg_type = "varchar(%s)" % args
        return out

    if base in _TEXT_TYPES:
        out.pg_type = "text"
        return out

    if base in _BLOB_TYPES:
        out.pg_type = "bytea"
        note("warn", "binary column mapped to bytea; the loader must send bytes, not str")
        return out

    if base == "json":
        out.pg_type = "jsonb"
        return out

    if base == "date":
        out.pg_type = "date"
        return out

    if base == "time":
        out.pg_type = "time"
        return out

    if base == "year":
        out.pg_type = "smallint"
        note("warn", "GUESS: MySQL YEAR mapped to smallint; PostgreSQL has no YEAR type")
        return out

    if base in ("datetime", "timestamp"):
        key = "%s.%s" % (table, col.name)
        if key in opts.timestamptz_columns:
            out.pg_type = "timestamptz" if opts.timestamptz_columns[key] else "timestamp"
            return out
        out.pg_type = "timestamptz" if opts.default_timestamptz else "timestamp"
        if base == "datetime":
            note("warn",
                 "GUESS: MySQL `datetime` is a naive wall clock with no zone; mapped to %s "
                 "assuming the source stored %s. Set Options.timestamptz_columns[%r] to "
                 "make the choice explicit." % (out.pg_type, opts.source_timezone, key))
        else:
            note("warn",
                 "GUESS: MySQL `timestamp` is UTC-normalised on store, so %s is the "
                 "faithful mapping — but it is still a guess until the dump's session "
                 "time_zone is confirmed. Set Options.timestamptz_columns[%r] to fix it."
                 % (out.pg_type, key))
        return out

    if base == "enum":
        values = _split_top_level(args)
        if not values:
            raise TransformError(Issue("error", table, col.name, None,
                                       "enum with no values"))
        literals = [_pg_string_literal(_parse_string_literal(v)) for v in values]
        out.pg_type = "text"
        out.checks.append("%s IN (%s)" % (q, ", ".join(literals)))
        note("warn", "enum mapped to text + CHECK rather than a PostgreSQL enum type: "
                     "adding a value to a CHECK is one statement, adding one to an enum "
                     "type is a migration")
        return out

    if base == "set":
        raise TransformError(Issue(
            "error", table, col.name, None,
            "MySQL SET type has no faithful PostgreSQL equivalent (text[] and a bitmask "
            "both change the query surface) — decide and write this column by hand"))

    raise TransformError(Issue(
        "error", table, col.name, None,
        "unsupported MySQL type %r — no translation is attempted rather than guessing"
        % col.mysql_type))


def _map_default(table: str, col: Column, pg_type: str, opts: Options,
                 issues: list[Issue]) -> str | None:
    d = col.default
    if d is None:
        return None
    stripped = d.strip()
    low = stripped.lower().rstrip("()").strip()

    if low == "null":
        return None if not col.nullable else "NULL"

    if low in ("current_timestamp", "now", "localtime", "localtimestamp") or \
            re.match(r"^current_timestamp\(\d*\)$", stripped, re.I):
        return "now()"

    if is_zero_date(stripped):
        if not col.nullable:
            issues.append(Issue(
                "error", table, col.name, None,
                "DEFAULT '0000-00-00' on a NOT NULL column: the zero date is not a valid "
                "PostgreSQL timestamp and there is no correct substitute. Make the column "
                "nullable, or choose a real sentinel — do not let this be guessed.",
            ))
            return None
        issues.append(Issue(
            "warn", table, col.name, None,
            "DEFAULT '0000-00-00' rewritten to NULL; every zero-date VALUE in this column "
            "must be rewritten to NULL by the row transform too",
        ))
        return None

    if stripped[:1] in ("'", '"'):
        value = _parse_string_literal(stripped)
        numericish = re.match(r"^(smallint|integer|bigint|numeric|real|double|boolean)", pg_type)
        if numericish:
            if pg_type == "boolean":
                if value in ("0", "1"):
                    return "false" if value == "0" else "true"
                issues.append(Issue("error", table, col.name, None,
                                    "quoted default %r on a boolean column" % value))
                return None
            if re.match(r"^[-+]?\d+(\.\d+)?$", value):
                issues.append(Issue(
                    "warn", table, col.name, None,
                    "quoted default %r unquoted for a %s column" % (value, pg_type)))
                return value
            issues.append(Issue("error", table, col.name, None,
                                "non-numeric default %r on a %s column" % (value, pg_type)))
            return None
        return _pg_string_literal(value)

    if re.match(r"^[-+]?\d+(\.\d+)?([eE][-+]?\d+)?$", stripped):
        if pg_type == "boolean":
            if stripped in ("0", "1"):
                return "false" if stripped == "0" else "true"
            issues.append(Issue("error", table, col.name, None,
                                "numeric default %r on a boolean column" % stripped))
            return None
        return stripped

    if stripped[:1] == "(":
        issues.append(Issue(
            "error", table, col.name, None,
            "expression default %s is not translated — MySQL and PostgreSQL differ on what "
            "an expression default may do; write it by hand" % stripped))
        return None

    issues.append(Issue(
        "error", table, col.name, None,
        "unrecognised DEFAULT %r — not guessed" % stripped))
    return None


# ---------------------------------------------------------------------------
# Emission
# ---------------------------------------------------------------------------

@dataclass
class EmittedColumn:
    """One column as the target will actually have it.

    Exists so a caller can check its own idea of the target against the schema
    that was really emitted, by name, without re-parsing the SQL text. The ETL
    does exactly that: every column in a COPY header must appear here, and every
    column here that the COPY does not supply must be able to fill itself in.
    """

    table: str
    name: str
    pg_type: str
    nullable: bool
    has_default: bool
    identity: bool
    added_by_policy: bool = False


@dataclass
class Emitted:
    """The translated schema, split into what runs before and after the data load."""

    tables: list[str] = field(default_factory=list)
    comments: list[str] = field(default_factory=list)
    indexes: list[str] = field(default_factory=list)
    triggers: list[str] = field(default_factory=list)
    post_load: list[str] = field(default_factory=list)
    issues: list[Issue] = field(default_factory=list)
    column_renames: dict[str, dict[str, str]] = field(default_factory=dict)
    index_renames: dict[str, str] = field(default_factory=dict)
    table_order: list[str] = field(default_factory=list)
    columns: dict[str, list[EmittedColumn]] = field(default_factory=dict)

    def column_names(self, table: str) -> list[str]:
        """Columns the emitted CREATE TABLE declares, in order. Raises if unknown."""
        if table not in self.columns:
            raise TransformError(Issue(
                "error", table, None, None,
                "no CREATE TABLE was emitted for this table, so nothing can be loaded "
                "into it; known tables: " + (", ".join(sorted(self.columns)) or "(none)")))
        return [c.name for c in self.columns[table]]

    def column(self, table: str, name: str) -> EmittedColumn | None:
        for c in self.columns.get(table, ()):
            if c.name == name:
                return c
        return None

    def errors(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "error"]

    def guesses(self) -> list[Issue]:
        return [i for i in self.issues if i.severity == "warn"]

    def sql(self) -> str:
        """Everything that must exist BEFORE the rows are loaded."""
        parts = [
            "-- pgmigrate ddl.py — generated PostgreSQL schema (pre-load).",
            "-- Unvalidated against a real dump. Read the report before running this.",
            "",
            "\n".join(self.tables),
        ]
        if self.comments:
            parts += ["", "\n".join(self.comments)]
        if self.indexes:
            parts += ["", "-- Indexes. Names are table-qualified: MySQL index names are unique",
                      "-- per table, PostgreSQL's are unique per schema.",
                      "\n".join(self.indexes)]
        if self.triggers:
            parts += ["", "-- ON UPDATE CURRENT_TIMESTAMP replacements. Dropping these freezes",
                      "-- the column forever, and one of them drives an activity filter.",
                      "\n".join(self.triggers)]
        return "\n".join(parts).rstrip() + "\n"

    def post_load_sql(self) -> str:
        """Everything that must run AFTER the rows are loaded.

        Identity sequences are restarted here on purpose: the ETL inserts rows with
        their original ids, so a sequence seeded before the load hands the first
        new player an id that already exists.
        """
        if not self.post_load:
            return "-- pgmigrate ddl.py — nothing to run after the load.\n"
        return ("-- pgmigrate ddl.py — POST-LOAD. Run only after every row is in.\n"
                "-- Identity sequences are seeded here because the load supplies explicit ids.\n\n"
                + "\n".join(self.post_load).rstrip() + "\n")

    def report_text(self) -> str:
        lines = ["pgmigrate ddl.py report",
                 "=======================",
                 "tables: %d   indexes: %d   triggers: %d   post-load statements: %d"
                 % (len(self.tables), len(self.indexes),
                    "\n".join(self.triggers).count("CREATE TRIGGER "),
                    len(self.post_load)),
                 ""]
        errs = self.errors()
        lines.append("ERRORS (%d) — an unsupported construct is an error, not a warning."
                     % len(errs))
        lines += ["  " + i.format() for i in errs] or ["  (none)"]
        lines.append("")
        guesses = self.guesses()
        lines.append("GUESSES AND NOTES (%d) — every one of these is a decision this module "
                     "made for you." % len(guesses))
        lines += ["  " + i.format() for i in guesses] or ["  (none)"]
        if self.index_renames:
            lines += ["", "INDEX RENAMES (%d)" % len(self.index_renames)]
            lines += ["  %s -> %s" % (k, v) for k, v in sorted(self.index_renames.items())]
        folded = {t: r for t, r in self.column_renames.items() if r}
        if folded:
            lines += ["", "COLUMN RENAMES (case folding) — map BY NAME in the row transform"]
            for t in sorted(folded):
                for src, dst in sorted(folded[t].items()):
                    lines.append("  %s.%s -> %s" % (t, src, dst))
        return "\n".join(lines) + "\n"

    def write(self, out_dir: str) -> dict[str, str]:
        os.makedirs(out_dir, exist_ok=True)
        paths = {
            "schema": os.path.join(out_dir, "schema.sql"),
            "post_load": os.path.join(out_dir, "schema_post_load.sql"),
            "report": os.path.join(out_dir, "ddl_report.txt"),
        }
        with open(paths["schema"], "w", encoding="utf-8") as fh:
            fh.write(self.sql())
        with open(paths["post_load"], "w", encoding="utf-8") as fh:
            fh.write(self.post_load_sql())
        with open(paths["report"], "w", encoding="utf-8") as fh:
            fh.write(self.report_text())
        return paths


def _topological_order(schema: Schema, issues: list[Issue]) -> list[Table]:
    """Order tables so a parent exists before its children.

    Foreign keys are emitted post-load regardless, so this ordering is belt and
    braces — but a schema that reads in dependency order is a schema a human can
    check, and a cycle is worth knowing about before load night rather than during.
    """
    names = {t.name for t in schema.tables}
    deps: dict[str, set[str]] = {}
    for t in schema.tables:
        ex = schema.extras[t.name]
        deps[t.name] = {fk.ref_table for fk in ex.foreign_keys
                        if fk.ref_table in names and fk.ref_table != t.name}
        for fk in ex.foreign_keys:
            if fk.ref_table not in names:
                issues.append(Issue(
                    "error", t.name, None, None,
                    "foreign key %r references table %r, which this input does not define"
                    % (fk.name, fk.ref_table)))

    ordered: list[str] = []
    done: set[str] = set()
    remaining = sorted(names, key=lambda n: (len(deps[n]), schema.extras[n].declared_order))
    while remaining:
        progressed = False
        for name in list(remaining):
            if deps[name] <= done:
                ordered.append(name)
                done.add(name)
                remaining.remove(name)
                progressed = True
        if not progressed:
            issues.append(Issue(
                "error", ", ".join(sorted(remaining)), None, None,
                "foreign-key cycle between these tables: no load order exists that satisfies "
                "them all; the constraints must be deferred or dropped"))
            ordered.extend(sorted(remaining))
            break
    index = {n: i for i, n in enumerate(ordered)}
    return sorted(schema.tables, key=lambda t: index[t.name])


def _index_columns_sql(table: str, spec: IndexSpec, issues: list[Issue],
                       renames: dict[str, str] | None = None) -> str:
    renames = renames or {}
    rendered: list[str] = []
    for raw in spec.columns:
        m = re.match(r"^(.*?)\s*\((\d+)\)\s*(ASC|DESC)?$", raw, re.I)
        if m:
            col = renames.get(m.group(1).strip().lower(), m.group(1).strip().lower())
            issues.append(Issue(
                "warn", table, col, None,
                "GUESS: prefix index %s(%s) rewritten as an expression index "
                "left(%s, %s). PostgreSQL has no prefix indexes, so this index is only "
                "used by queries written the same way — check the query surface, or drop "
                "the prefix if the column is short enough to index whole."
                % (col, m.group(2), quote_ident(col), m.group(2))))
            expr = "left(%s, %s)" % (quote_ident(col), m.group(2))
            if m.group(3):
                expr += " " + m.group(3).upper()
            rendered.append(expr)
            continue
        m2 = re.match(r"^(.*?)\s+(ASC|DESC)$", raw, re.I)
        if m2:
            _c = m2.group(1).strip().lower()
            rendered.append(quote_ident(renames.get(_c, _c)) + " " + m2.group(2).upper())
            continue
        _c = raw.strip().lower()
        rendered.append(quote_ident(renames.get(_c, _c)))
    return ", ".join(rendered)


def convert(schema: Schema, opts: Options | None = None) -> Emitted:
    """Translate a parsed MySQL schema into PostgreSQL DDL."""
    opts = opts or Options()
    em = Emitted()
    em.issues.extend(schema.issues)

    ordered = _topological_order(schema, em.issues)
    em.table_order = [t.name for t in ordered]
    seen_index_names: dict[str, str] = {}

    for table in ordered:
        ex = schema.extras[table.name]
        tname = opts.qualified(opts.table_renames.get(table.name, table.name))
        renames = {src: folded for folded, src in ex.column_source_names.items()
                   if src != folded}
        if renames:
            em.column_renames[table.name] = renames

        lines: list[str] = []
        checks: list[str] = []
        emitted_cols: list[EmittedColumn] = []
        # Keyed by the TARGET name: a policy rename (apd_applications -> maxsec_applications)
        # emits the CREATE TABLE under the target, and the loader asks column_names() by
        # that name. Keying by source left the renamed table unloadable (first real dump,
        # 2026-09-07). The source name stays as an alias for anything reading it that way.
        em.columns[opts.table_renames.get(table.name, table.name)] = emitted_cols
        if table.name in opts.table_renames:
            em.columns[table.name] = emitted_cols

        # The policy may name columns of a table it does not have; that is a
        # policy bug, and a silent one — the column is simply never emitted and
        # the mismatch turns up at load time.
        declared_names = {c.name for c in table.columns}
        for label, declared in (("boolean", opts.boolean_columns),
                                ("transcoded to jsonb", opts.jsonb_columns)):
            for t, c in sorted(declared or ()):
                if t == table.name and c not in declared_names:
                    em.issues.append(Issue(
                        "error", table.name, c, None,
                        "the carry-over policy declares this column %s, but the source "
                        "schema for this table has no such column" % label))

        out_table = opts.table_renames.get(table.name, table.name)
        renames_here = opts.policy_renames.get(table.name, {})
        for source_col, target_col in sorted(renames_here.items()):
            if source_col not in declared_names:
                em.issues.append(Issue(
                    "error", table.name, source_col, None,
                    "the carry-over policy renames this column, but the source schema for "
                    "this table has no such column"))
            elif target_col in declared_names:
                em.issues.append(Issue(
                    "error", table.name, target_col, None,
                    "the policy renames %r to this name, which the source already declares; "
                    "the rename would collide with a real column" % source_col))

        for col in table.columns:
            mapped = _map_type(table.name, col, opts)
            em.issues.extend(mapped.notes)
            is_identity = col.is_identity
            out_name = renames_here.get(col.name, col.name)

            if opts.is_boolean(table.name, col.name) and mapped.pg_type != "boolean":
                # Unreachable while _map_type honours the allowlist; asserted
                # anyway because the failure is silent and permanent: a five-state
                # column collapsed to two states, for every player at once.
                em.issues.append(Issue(
                    "error", table.name, col.name, None,
                    "policy declares this column boolean but it mapped to %r"
                    % mapped.pg_type))

            piece = "  %s %s" % (quote_ident(out_name), mapped.pg_type)
            if not col.nullable or is_identity:
                piece += " NOT NULL"

            default = None
            if is_identity:
                if col.default is not None and col.default.strip().lower() != "null":
                    em.issues.append(Issue(
                        "warn", table.name, col.name, None,
                        "DEFAULT %r dropped: the column is an identity column" % col.default))
                if not re.match(r"^(smallint|integer|bigint)$", mapped.pg_type):
                    em.issues.append(Issue(
                        "error", table.name, col.name, None,
                        "AUTO_INCREMENT on a %s column: PostgreSQL identity columns must be "
                        "an integer type" % mapped.pg_type))
                piece += " GENERATED BY DEFAULT AS IDENTITY"
            else:
                default = _map_default(table.name, col, mapped.pg_type, opts, em.issues)
                if default is not None:
                    piece += " DEFAULT " + default

            lines.append(piece)
            emitted_cols.append(EmittedColumn(
                table=table.name, name=out_name, pg_type=mapped.pg_type,
                nullable=col.nullable and not is_identity,
                has_default=default is not None,
                identity=is_identity))
            for chk in mapped.checks:
                cname = fit_ident("%s_%s_chk" % (table.name, out_name))
                checks.append("  CONSTRAINT %s CHECK (%s)" % (quote_ident(cname), chk))

        # Target columns the source has no counterpart for. Emitted here, from
        # the same policy the ETL builds its COPY header from, so the two cannot
        # hold different ideas of the target's shape.
        for cname, definition in sorted(opts.extra_columns.get(table.name, {}).items()):
            if cname in declared_names:
                em.issues.append(Issue(
                    "error", table.name, cname, None,
                    "the policy adds this column as new, but the source schema already "
                    "declares it; one of the two is out of date"))
                continue
            lines.append("  %s %s" % (quote_ident(cname), definition))
            low = definition.lower()
            emitted_cols.append(EmittedColumn(
                table=table.name, name=cname, pg_type=definition.split()[0],
                nullable="not null" not in low,
                has_default="default" in low, identity=False,
                added_by_policy=True))
            em.issues.append(Issue(
                "warn", table.name, cname, None,
                "column added by carry-over policy (%s): the source has no such column, "
                "so every carried row takes the policy's default" % definition))

        if table.primary_key:
            # Target names: a PRIMARY KEY that still names the source column is a
            # schema that does not compile.
            pk_cols = ", ".join(quote_ident(renames_here.get(c.lower(), c.lower()))
                                for c in table.primary_key)
            declared = {c.name for c in table.columns}
            missing = [c for c in table.primary_key if c.lower() not in declared]
            if missing:
                em.issues.append(Issue(
                    "error", table.name, None, None,
                    "PRIMARY KEY names columns this table does not declare: %s"
                    % ", ".join(missing)))
            checks.append("  CONSTRAINT %s PRIMARY KEY (%s)"
                          % (quote_ident(fit_ident("%s_pkey" % out_table)), pk_cols))
        else:
            em.issues.append(Issue(
                "warn", table.name, None, None,
                "no PRIMARY KEY: reconciliation can count these rows but cannot match them "
                "one for one, and the load is not idempotent for this table"))

        body = ",\n".join(lines + checks)
        em.tables.append("CREATE TABLE %s (\n%s\n);" % (tname, body))

        if ex.comment:
            em.comments.append("COMMENT ON TABLE %s IS %s;"
                               % (tname, _pg_string_literal(ex.comment)))
        for cname, ctext in sorted(ex.column_comments.items()):
            em.comments.append("COMMENT ON COLUMN %s.%s IS %s;"
                               % (tname, quote_ident(cname), _pg_string_literal(ctext)))

        # --- indexes -------------------------------------------------------
        pk_signature = [c.lower() for c in table.primary_key]
        for spec in ex.index_specs:
            plain = [_plain_index_column(c) for c in spec.columns]
            if spec.unique and plain == pk_signature:
                em.issues.append(Issue(
                    "warn", table.name, None, None,
                    "unique key %r duplicates the primary key and was not emitted"
                    % spec.name))
                continue
            base = spec.name if spec.name.startswith(table.name + "_") \
                else "%s_%s" % (table.name, spec.name)
            iname = fit_ident(base)
            if iname != spec.name:
                em.index_renames["%s.%s" % (table.name, spec.name)] = iname
            if iname in seen_index_names:
                em.issues.append(Issue(
                    "error", table.name, None, None,
                    "index name %r collides with the one already emitted for %r; "
                    "PostgreSQL index names are unique per schema"
                    % (iname, seen_index_names[iname])))
                continue
            seen_index_names[iname] = table.name
            method = ""
            if spec.method and spec.method != "btree":
                if spec.method == "hash":
                    method = " USING hash"
                else:
                    em.issues.append(Issue(
                        "error", table.name, None, None,
                        "index %r uses method %r, which is not translated"
                        % (spec.name, spec.method)))
                    continue
            cols_sql = _index_columns_sql(table.name, spec, em.issues, renames_here)
            em.indexes.append("CREATE%s INDEX %s ON %s%s (%s);" % (
                " UNIQUE" if spec.unique else "", quote_ident(iname), tname, method, cols_sql))

        # --- ON UPDATE CURRENT_TIMESTAMP ------------------------------------
        for col in table.columns:
            # Read through the contract accessor, not by substring: two parsers
            # write this field and only `model.Column.on_update` knows both
            # spellings. A missed match here freezes the column forever, and one
            # of them drives an activity filter.
            raw_expr = col.on_update
            if raw_expr is None:
                continue
            expr = raw_expr.rstrip("()").strip()
            if expr not in ("current_timestamp", "now", "localtime", "localtimestamp") and \
                    not re.match(r"^current_timestamp\(\d*\)$", raw_expr):
                em.issues.append(Issue(
                    "error", table.name, col.name, None,
                    "ON UPDATE %r is not translated" % raw_expr))
                continue
            fn = fit_ident("set_%s_%s" % (table.name, col.name))
            trg = fit_ident("%s_%s_on_update" % (table.name, col.name))
            fq_fn = (quote_ident(opts.schema) + "." if opts.schema else "") + quote_ident(fn)
            em.triggers.append(
                "CREATE OR REPLACE FUNCTION %s() RETURNS trigger LANGUAGE plpgsql AS $$\n"
                "BEGIN\n"
                "    NEW.%s := now();\n"
                "    RETURN NEW;\n"
                "END;\n"
                "$$;" % (fq_fn, quote_ident(col.name)))
            em.triggers.append(
                "DROP TRIGGER IF EXISTS %s ON %s;\n"
                "CREATE TRIGGER %s\n"
                "    BEFORE UPDATE ON %s\n"
                "    FOR EACH ROW\n"
                "    WHEN (OLD.* IS DISTINCT FROM NEW.*)\n"
                "    EXECUTE FUNCTION %s();"
                % (quote_ident(trg), tname, quote_ident(trg), tname, fq_fn))
            em.issues.append(Issue(
                "warn", table.name, col.name, None,
                "ON UPDATE CURRENT_TIMESTAMP replaced by trigger %r. The WHEN clause "
                "reproduces MySQL's rule that the stamp only moves when the row actually "
                "changes; without it an UPDATE that writes identical values would still "
                "bump the clock." % trg))

        # --- post-load -------------------------------------------------------
        ident = next((c for c in table.columns if c.is_identity), None)
        if ex.auto_increment_seed is not None and ident is None:
            em.issues.append(Issue(
                "warn", table.name, None, None,
                "table option AUTO_INCREMENT=%d with no AUTO_INCREMENT column; ignored"
                % ex.auto_increment_seed))
        if ident is not None:
            # The identity sequence is set from the DATA, not only from the dump's
            # seed: a structure-only dump carries no seed at all for some tables,
            # and a sequence left at 1 hands the first new player an id that an
            # imported row already owns. The dump's seed is kept as a floor so a
            # deleted-tail table cannot reuse ids either.
            # The TARGET name: a renamed table's sequence lives under the name the
            # CREATE TABLE used (live load 2026-09-07: 'apd_applications' does not exist).
            qualified_literal = _pg_string_literal(
                (opts.schema + "." if opts.schema else "")
                + opts.table_renames.get(table.name, table.name))
            floor = ""
            if ex.auto_increment_seed is not None:
                floor = ", %d" % ex.auto_increment_seed
            em.post_load.append(
                "-- %s.%s identity: max(id)+1 from the carried rows%s.\n"
                "SELECT setval(pg_get_serial_sequence(%s, %s),\n"
                "              GREATEST((SELECT COALESCE(max(%s), 0) + 1 FROM %s)%s), false);"
                % (table.name, ident.name,
                   "" if not floor else ", floored at the dump's seed %d"
                   % ex.auto_increment_seed,
                   qualified_literal, _pg_string_literal(ident.name),
                   quote_ident(ident.name), tname, floor))

        for fk in ex.foreign_keys:
            clause = "ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s)" % (
                tname, quote_ident(fit_ident(fk.name)),
                ", ".join(quote_ident(c) for c in fk.columns),
                opts.qualified(fk.ref_table),
                ", ".join(quote_ident(c) for c in fk.ref_columns))
            if fk.on_delete:
                clause += " ON DELETE " + fk.on_delete
            if fk.on_update:
                clause += " ON UPDATE " + fk.on_update
            em.post_load.append(clause + ";")
            em.issues.append(Issue(
                "warn", table.name, None, None,
                "foreign key %r is added after the load, not before: a row-at-a-time load "
                "in any order would otherwise fail on a parent that has not arrived yet. "
                "Adding it afterwards also validates the carried data." % fk.name))

    return em


def translate(sql: str, opts: Options | None = None, source: str = "<dump>") -> Emitted:
    """Parse and convert in one step. Does not raise on errors — read `report()`."""
    opts = opts or Options()
    return convert(parse_mysql_ddl(sql, source=source, opts=opts), opts)


def schema_from_tables(tables: list[Table]) -> Schema:
    """Wrap plain `Table` objects (as `dump.py` produces them) as a `Schema`.

    The shared `Table` contract has no room for a table's AUTO_INCREMENT seed,
    its foreign keys or an index's prefix lengths, so a schema built this way
    translates with slightly less information than one parsed here directly.
    That is fine — the identity sequences are set from the loaded data, not from
    the seed — but it is the reason `parse_mysql_ddl` exists alongside this.
    """
    schema = Schema()
    for order, src in enumerate(tables):
        name = src.name.lower()
        extras = TableExtras(source_name=src.name, declared_order=order)
        columns: list[Column] = []
        for col in src.columns:
            folded = col.name.lower()
            if folded != col.name:
                schema.issues.append(Issue(
                    "warn", name, col.name, None,
                    "identifier folded to lower case (%r → %r): this is a RENAME, and "
                    "the row transform must map it by name" % (col.name, folded)))
            extras.column_source_names[folded] = col.name
            columns.append(Column(name=folded, mysql_type=col.mysql_type,
                                  nullable=col.nullable, default=col.default,
                                  extra=col.extra))
        extras.index_specs = [IndexSpec(name=iname.lower(),
                                        columns=[c for c in icols], unique=bool(uniq))
                              for iname, icols, uniq in src.indexes]
        schema.tables.append(Table(
            name=name, columns=columns,
            primary_key=[p.lower() for p in src.primary_key],
            indexes=[(n, list(c), u) for n, c, u in src.indexes]))
        schema.extras[name] = extras
    return schema


def _comment_block(text: str) -> str:
    return "".join("-- %s\n" % line if line else "--\n"
                   for line in text.rstrip().splitlines())


def translate_schema(tables: list[Table], opts: Options | None = None) -> str:
    """Entry point for the ETL driver: `Table` objects in, PostgreSQL DDL out.

    Returns only what must run BEFORE the rows are loaded, with the full report
    embedded as a leading comment block so the guesses travel with the schema
    into the output directory instead of scrolling past in a terminal.

    Raises `TransformError` if anything could not be translated. It refuses
    rather than emitting a schema with a hole in it, because a table that
    quietly failed to translate is a table whose rows have nowhere to land.

    The post-load half — identity sequences and foreign keys — is NOT in this
    string. Get it from `post_load_sql_for(tables)` and run it after the load,
    or the first id the target generates collides with a carried one.
    """
    emitted = convert(schema_from_tables(tables), opts)
    require_clean(emitted)
    return (_comment_block(emitted.report_text())
            + "\n" + emitted.sql()
            + "\n-- Not finished: run post_load_sql_for(tables) AFTER the rows land.\n")


def post_load_sql_for(tables: list[Table], opts: Options | None = None) -> str:
    """The half of the schema that must run after the data. See `translate_schema`."""
    emitted = convert(schema_from_tables(tables), opts)
    require_clean(emitted)
    return emitted.post_load_sql()


def report(emitted: Emitted) -> list[Issue]:
    """Every guess and every unsupported construct, errors first."""
    return sorted(emitted.issues, key=lambda i: 0 if i.severity == "error" else 1)


def require_clean(emitted: Emitted) -> Emitted:
    """Raise unless the translation is error-free. The gate before any load."""
    errs = emitted.errors()
    if errs:
        raise TransformError(Issue(
            errs[0].severity, errs[0].table, errs[0].column, errs[0].pk,
            "%s  [%d error(s) total; see report()]" % (errs[0].message, len(errs))))
    return emitted


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _extra_columns_from(rules) -> dict[str, dict[str, str]]:
    """{table: {column: definition}} for the policy's target-only columns."""
    out: dict[str, dict[str, str]] = {}
    for table, column, definition in rules.added_columns():
        out.setdefault(table, {})[column] = definition
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="pgmigrate.ddl",
        description="Translate the CREATE TABLE statements in a mysqldump into "
                    "PostgreSQL DDL. Reads a dump file; never connects to anything.")
    ap.add_argument("dump", nargs="+", help="mysqldump file(s), in order")
    ap.add_argument("--out-dir", help="write schema.sql, schema_post_load.sql, ddl_report.txt")
    ap.add_argument("--schema", help="target PostgreSQL schema name to qualify with")
    ap.add_argument("--timestamptz", action="append", default=[], metavar="TABLE.COLUMN",
                    help="force this column to timestamptz (repeatable)")
    ap.add_argument("--timestamp-naive", action="append", default=[], metavar="TABLE.COLUMN",
                    help="force this column to naive timestamp (repeatable)")
    ap.add_argument("--bigint-unsigned-numeric", action="store_true",
                    help="map unsigned bigint to numeric(20,0) instead of bigint")
    ap.add_argument("--no-tinyint1-boolean", action="store_true",
                    help="keep tinyint(1) as smallint instead of boolean")
    ap.add_argument("--policy", action="store_true",
                    help="apply the carry-over policy from rules.py: the boolean "
                         "ALLOWLIST, the columns transcoded to jsonb, and the target-only "
                         "columns. Without this the emitted schema is a translation of the "
                         "source only — it is NOT the schema the ETL loads into, and the "
                         "two differ in ~30 columns")
    ap.add_argument("--allow-errors", action="store_true",
                    help="write output even though unsupported constructs were found")
    args = ap.parse_args(argv)

    policy_kwargs: dict[str, object] = {}
    if args.policy:
        try:
            from . import rules  # type: ignore
        except ImportError:
            import rules  # type: ignore
        policy_kwargs = {
            "tinyint1_as_boolean": False,
            "boolean_columns": frozenset(rules.boolean_columns()),
            "jsonb_columns": frozenset(rules.transcoded_columns()),
            "extra_columns": _extra_columns_from(rules),
        }
    elif args.no_tinyint1_boolean:
        policy_kwargs = {"tinyint1_as_boolean": False}

    opts = Options(
        timestamptz_columns={**{c.lower(): True for c in args.timestamptz},
                             **{c.lower(): False for c in args.timestamp_naive}},
        bigint_unsigned_as_numeric=args.bigint_unsigned_numeric,
        schema=args.schema,
        **policy_kwargs,  # type: ignore[arg-type]
    )

    text = []
    for path in args.dump:
        with open(path, "r", encoding="utf-8", errors="strict") as fh:
            text.append(fh.read())
    emitted = translate("\n".join(text), opts, source=os.path.basename(args.dump[0]))

    sys.stderr.write(emitted.report_text())

    if emitted.errors() and not args.allow_errors:
        sys.stderr.write(
            "\nREFUSING TO WRITE: %d unsupported construct(s). An unsupported construct is "
            "an error, not a warning — translate it by hand or pass --allow-errors and "
            "know what you are shipping.\n" % len(emitted.errors()))
        return 2

    if args.out_dir:
        paths = emitted.write(args.out_dir)
        for k in ("schema", "post_load", "report"):
            sys.stderr.write("wrote %s\n" % paths[k])
    else:
        sys.stdout.write(emitted.sql())
        sys.stdout.write("\n")
        sys.stdout.write(emitted.post_load_sql())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
