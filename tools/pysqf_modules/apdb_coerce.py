"""Value coercion the retired translator used to provide -- and the one piece
of it that is NOT dialect translation, so it survives Phase T as a permanent
transport concern: MariaDB implicitly rounded fractional writes at integer
columns (half away from zero) and the game's writers were built on that.
PostgreSQL refuses the whole statement instead -- and the refused statement
usually carries other assignments (the bought-vehicle-absent-from-garage bug:
the refused fuel write also carried active='0').

Extracted verbatim from the retired apdb_sql.py (git 262cb63d): the
alias-resolved, string-masked rewrite over INTEGER_COLUMNS, applied by
apdb.query to every statement. It touches nothing but col='<fractional>'
assignments at columns on the allowlist.
"""
from __future__ import annotations

import re
from decimal import Decimal, ROUND_HALF_UP

try:
    from .apdb_schema import INTEGER_COLUMNS
except ImportError:                       # pragma: no cover -- daemon imports top-level
    from apdb_schema import INTEGER_COLUMNS

_STRING = re.compile(r"'(?:[^'\\]|''|\\.)*'")

def _split_strings(sql: str) -> list:
    """[(is_string, text), ...] so rewrites can skip literals entirely."""
    out, pos = [], 0
    for m in _STRING.finditer(sql):
        if m.start() > pos:
            out.append((False, sql[pos:m.start()]))
        out.append((True, m.group(0)))
        pos = m.end()
    if pos < len(sql):
        out.append((False, sql[pos:]))
    return out


def _mask_strings(sql: str) -> str:
    """Same string, every literal's CONTENT replaced by spaces.

    Offsets are preserved exactly, so a match found in the mask slices the real
    statement correctly. This is what makes paren matching work across a literal:
    `QUOTE(IFNULL(name,'Contested'))` closes two brackets after a string, and a
    scan that skipped literals entirely never saw the closer -- 40 statements in
    the corpus failed exactly that way.
    """
    out = []
    for is_str, chunk in _split_strings(sql):
        if is_str:
            # The QUOTES ARE KEPT and only the content is blanked. Blanking the
            # whole token turns `'b'` into three spaces, and a regex written as
            # `(.*?)\s+LIMIT` then treats the literal as whitespace and eats it:
            # `WHERE oid='b' LIMIT 1` came out as `WHERE oid=`, which deletes by
            # a truncated predicate. Masked text must still look like a token.
            out.append(chunk[0] + " " * (len(chunk) - 2) + chunk[-1] if len(chunk) >= 2 else chunk)
        else:
            out.append(chunk)
    return "".join(out)


_NOT_AN_ALIAS = {"set", "where", "on", "using", "join", "left", "right", "inner",
                 "outer", "group", "order", "limit", "values", "as", "and", "or"}

def _table_aliases(sql: str) -> tuple:
    """({alias: table}, [tables in order]) for this statement.

    The ALIAS map is what makes boolean rewriting safe. `active` is a real
    boolean on `vehicles` and a 1/2 listing state on `exchange`, and one
    statement names both: without resolving `e.active` to `exchange`, the
    rewriter turns a listing state into `true` and the row stops meaning what it
    meant. Five tables in this schema have a column called `active` and they do
    not agree on its type.
    """
    masked = _mask_strings(sql)
    aliases, tables = {}, []
    for m in re.finditer(r"\b(?:FROM|INTO|UPDATE|JOIN)\s+([A-Za-z_][A-Za-z0-9_]*)"
                         r"(?:\s+(?:AS\s+)?([A-Za-z_][A-Za-z0-9_]*))?", masked, re.I):
        table = m.group(1).lower()
        tables.append(table)
        alias = (m.group(2) or "").lower()
        if alias and alias not in _NOT_AN_ALIAS:
            aliases[alias] = table
        aliases.setdefault(table, table)
    return aliases, tables


def _round_integer_literals(sql: str) -> str:
    """`fuel='99.9228'` -> `fuel=100`, for THIS column's real integer table.

    Found in game: a bought vehicle stored and then absent from the garage. The
    game writes fractional floats at integer columns everywhere (`fuel`,
    `damage`) and MariaDB silently rounded them; PostgreSQL refuses the ENTIRE
    statement -- and the refused statement also carried `active='0'`, so the car
    silently never reached the garage. Rounding is half-AWAY-from-zero
    (decimal ROUND_HALF_UP), which is MariaDB's rule, not Python's banker's
    rounding.

    Same resolution discipline as _boolean_literals directly above, for the same
    three historical reasons: resolve through the statement's alias map, an
    unqualified column resolves against the primary table, an unresolvable one
    is left alone, and a match inside a string literal is data, not SQL.
    Only fractional values are touched -- an integer-valued write ('0', '25')
    is already acceptable to PostgreSQL as a quoted literal and stays verbatim.
    """
    aliases, tables = _table_aliases(sql)
    if not tables:
        return sql
    primary = tables[0]
    integers = {(t, c) for t, c in INTEGER_COLUMNS}
    names = {c for t, c in integers if t in set(tables)}
    if not names:
        return sql

    pattern = re.compile(r"(?:\b([A-Za-z_][A-Za-z0-9_]*)\.)?\b(%s)\s*=\s*('?)(-?\d+\.\d+)\3(?![\w.])"
                         % "|".join(sorted(re.escape(n) for n in names)), re.I)

    masked = _mask_strings(sql)
    out, last = [], 0
    for m in pattern.finditer(sql):
        if masked[m.start(2):m.end(2)] != sql[m.start(2):m.end(2)]:
            continue
        qualifier = (m.group(1) or "").lower()
        table = aliases.get(qualifier, primary) if qualifier else primary
        if (table, m.group(2).lower()) not in integers:
            continue
        rounded = int(Decimal(m.group(4)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
        out.append(sql[last:m.start()])
        prefix = "%s." % m.group(1) if m.group(1) else ""
        out.append("%s%s=%d" % (prefix, m.group(2), rounded))
        last = m.end()
    out.append(sql[last:])
    return "".join(out)


def coerce(sql: str) -> str:
    """The one public entry point."""
    return _round_integer_literals(sql)
