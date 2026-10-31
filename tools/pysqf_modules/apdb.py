"""The game's database entry point, over PySQF, against PostgreSQL.

    ["apdb.query", [sql, mode, multiarr]] call APS_fnc_pysqfCall

This is the PostgreSQL half of `DB_fnc_asyncQuery`. It exists so that the 1478
call sites and 400 SQL statements in the mission do not have to change: the SQL
that arrives is MariaDB-flavoured and the rows that leave are shaped exactly the
way extDB3 shaped them.

THE CONTRACT IT IS COPYING, AND WHY EACH PART MATTERS

    mode 1      fire and forget. Returns True. Callers do not read a result.
    mode 2      returns the first row, or every row when `multiarr`.
    no rows     returns [] -- and that is DIFFERENT from a failure, which comes
                back as [false, "..."] through APS_fnc_pysqfCall. The blocking
                helper this replaces returned [] for both, and every caller
                downstream guessed wrong in the same direction.

    Rows are ARRAYS, in SELECT order, because that is what the callers index.
    `pysqf.db.query` hands back dicts; turning them into positional rows is most
    of what this module does, and doing it by the cursor's own column order is
    the only version that survives a SELECT with two columns of the same name.

VALUE SHAPES -- each of these is a bug that would otherwise be silent

    booleans      -> 0 / 1. The carry-over makes 14 tinyint(1) columns into real
                     booleans, but the SQF reading them was written against 0/1
                     and compares with `isEqualTo 1`. Handing it `true` makes
                     every one of those comparisons false, quietly.
    money/big int -> string, when the value is beyond a 32-bit float's exact
                     range (16,777,216). SQF numbers ARE 32-bit floats; a bank
                     balance above that arrives rounded, and rounding money on
                     read is how a dupe becomes possible.
    Decimal       -> string, always. `new_drachma` is decimal(20,4) and every
                     route through a float loses places.
    NULL          -> "". extDB3 rendered NULL as an empty string and the callers
                     were written against that.
    timestamps    -> "YYYY-MM-DD HH:MM:SS", MySQL's rendering, because that is
                     what the SQF parses.
    jsonb         -> re-encoded into the game's own array codec. The carry-over
                     stores these columns as real JSON documents; the game still
                     speaks `mres`. Translating at this boundary keeps both true
                     at once, and keeps it in ONE place.
"""

from __future__ import annotations

import datetime
import decimal
import json
import os
import sys


# The carry-over's own codec implementation, reused rather than reimplemented:
# a second encoder would drift from the one the migration validated the data
# with, and the drift would only show as items quietly changing shape.
import pysqf                                                   # noqa: E402
from pysqf import db                                           # noqa: E402

try:
    from .apdb_coerce import coerce                            # noqa: E402
except ImportError:                                            # pragma: no cover
    from apdb_coerce import coerce                             # noqa: E402


#: Above this, an integer is no longer exactly representable as a 32-bit float,
#: which is what an SQF number is. Values past it travel as strings.
_FLOAT_EXACT = 16_777_216

def _unwrap_text(text: str) -> str:
    """Consume a MATCHED outer quote pair, exactly as extDB3's compile did.

    extDB3 returned SQF SOURCE and the caller `call compile`d it: a text
    value's outer quotes were consumed as string delimiters and interior `""`
    un-doubled on the way past. The bridge builds values instead of compiling,
    so it reproduces that here -- and ONLY that. A matched pair means the first
    and last characters are quotes and the interior contains no LONE quote
    (doubled `""` is the escape); anything else -- a value that merely starts,
    ends, or has quotes inside -- is data and passes verbatim. Without this,
    `houses.pinv` (the game's own codec, itself quote-wrapped) was read one
    layer too deep, decoded as empty, and SAVED BACK empty over the player's
    storage.
    """
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        inner = text[1:-1]
        if '"' not in inner.replace('""', ''):
            return inner.replace('""', '"')
    return text


def _to_sqf(value, *, column: str = "") -> object:
    """One database value, in the shape extDB3 used to hand the SQF."""
    if value is None:
        out = ""
    elif isinstance(value, bool):
        out = 1 if value else 0
    elif isinstance(value, decimal.Decimal):
        out = str(value)
    elif isinstance(value, int):
        out = str(value) if abs(value) > _FLOAT_EXACT else value
    elif isinstance(value, float):
        out = value
    elif isinstance(value, (datetime.datetime, datetime.date, datetime.time)):
        out = (value.strftime("%Y-%m-%d %H:%M:%S")
               if isinstance(value, datetime.datetime) else value.isoformat())
    elif isinstance(value, (dict, list)):
        # A jsonb column. JSON text IS a valid SQF array literal for the
        # parseSimpleArray consumers that read these columns (compact form --
        # PostgreSQL's own jsonb::text adds spaces, parseSimpleArray does not
        # care, but the byte-stable form keeps fixtures honest). The old
        # `mres.encode` here wrapped the document in quotes and broke every
        # garage read, and its stdlib-JSON path lost cents on nested numerics.
        out = json.dumps(value, separators=(",", ":"))
    elif isinstance(value, (bytes, bytearray)):
        out = _unwrap_text(value.decode("utf-8", "replace"))
    else:
        out = _unwrap_text(str(value))
    # The QUOTE()-position stringify machinery is gone with the translator:
    # exactness rides the TYPES now (Decimal and past-float-exact integers
    # always arrive as strings above), and the two former QUOTE-an-int sites
    # were ported with explicit ::text casts.
    return out


@pysqf.export
def query(sql, mode=2, multiarr=False):
    """Run one MariaDB-flavoured statement against PostgreSQL.

    Raises on anything it cannot translate, which reaches the SQF as
    `[false, "<message>"]` -- a failure the caller can see, rather than an empty
    result it would read as "no rows".
    """
    if not isinstance(sql, str):
        raise TypeError("apdb.query: sql must be a string, got %r" % type(sql))
    mode = int(mode)

    # Phase T (2026-08-20): THE TRANSLATOR IS RETIRED. Every statement in the
    # tree is native PostgreSQL -- proven by the repo-wide census (0 statements
    # transform), the EXPLAIN gate (346/0) and the harvest lint (0 MySQL-isms),
    # which now guards the door in run_checks. What arrives here executes as-is.

    sql = coerce(sql)   # MariaDB's implicit int rounding, kept as transport semantics

    if mode == 1:
        db.execute(sql)
        return True

    rows = db.query(sql)
    if not rows:
        return []

    # Column ORDER is the cursor's, not the dict's: two columns with the same
    # name collapse in a dict, and `SELECT a.id, b.id` is a real statement here.
    columns = list(rows[0].keys())
    out = []
    for row in rows:
        out.append([_to_sqf(row[name], column=name) for name in columns])
    return out if multiarr else out[0]


@pysqf.export
def queryp(sql, params=None, mode=2, multiarr=False):
    """`query`, parameterised. Values travel OUTSIDE the SQL text.

    This is the injection-proof path: the statement carries %s / %(name)s
    placeholders and the values ride a separate list or object, so no caller
    ever formats a player-controlled string into SQL again. The layer below
    refuses a statement that interpolates (db._validate), so misuse fails loud.

    Same shaping contract as `query` in both directions -- rows positional in
    cursor order, the extDB3 value shapes, [] only ever meaning "no rows".
    """
    if not isinstance(sql, str):
        raise TypeError("apdb.queryp: sql must be a string, got %r" % type(sql))
    mode = int(mode)
    sql = coerce(sql)
    if mode == 1:
        db.execute(sql, params)
        return True
    rows = db.query(sql, params)
    if not rows:
        return []
    columns = list(rows[0].keys())
    out = [[_to_sqf(r[name], column=name) for name in columns] for r in rows]
    return out if multiarr else out[0]


@pysqf.export
def execp(sql, params=None):
    """Run one WRITE and say what it did: `[1, rowcount, rows]`.

    This is the end of the [] ambiguity for writes. `query` mode 1 returns True
    whether the UPDATE hit one row or none, and a failure had to be proven by a
    re-SELECT; this returns the rowcount (so `UPDATE ... WHERE` guards report 0
    when the guard refused), and an actual failure still surfaces as
    [false, "..."] through the transport -- three distinguishable outcomes.

    `rows` carries a RETURNING clause's rows (shaped like query's) or [].
    `rowcount` is -1 for DDL, the driver's convention passed through.
    """
    if not isinstance(sql, str):
        raise TypeError("apdb.execp: sql must be a string, got %r" % type(sql))
    r = db.execute(coerce(sql), params)
    raw = r.get("rows") or []
    shaped = []
    if raw:
        columns = list(raw[0].keys())
        shaped = [[_to_sqf(row[name], column=name) for name in columns] for row in raw]
    return [1, int(r.get("rowcount", -1)), shaped]


@pysqf.export
def txn(statements):
    """Several statements, ONE transaction: all commit or none do.

    `statements` is [[sql, params], ...]. Returns [1, [rowcount, ...]] in
    order; any error rolls the whole batch back and surfaces as [false, "..."]
    with nothing partially applied. This is what a two-sided transfer rides.
    """
    prepared = []
    for item in statements:
        if isinstance(item, (list, tuple)) and item:
            prepared.append([coerce(item[0]), item[1] if len(item) > 1 else []])
        else:
            raise TypeError("apdb.txn: each statement is [sql, params]")
    results = db.transaction(prepared)
    return [1, [int(r.get("rowcount", -1)) for r in results]]


@pysqf.export
def explain(sql):
    """EXPLAIN without executing -- the smoke test's liveness probe."""
    return [str(r[0]) for r in [list(x.values()) for x in db.query("EXPLAIN %s" % sql)]]


@pysqf.export
def enabled():
    """[True] when this deployment is meant to use PostgreSQL, [False] otherwise.

    The game cannot read an environment variable -- SQF has no such command -- so
    the flag lives here, in the process that must already be running for the
    PostgreSQL path to work. One setting, one place, and flipping it is a systemd
    drop-in plus a daemon restart rather than a repack.

    Returned as a one-element ARRAY because APS_fnc_pysqfCall wraps a scalar and
    the caller checks element 0; a bare bool would arrive as something the SQF
    side has to special-case.
    """
    return [os.environ.get("AP_DB_POSTGRES", "").strip().lower() in ("1", "true", "yes", "on")]


@pysqf.export
def ping():
    """Liveness: the pool answers and a trivial statement round-trips. The old
    translator-loaded probe went with the translator (Phase T)."""
    info = db.ping()
    alive = db.query("SELECT 1 AS ok")
    return {"db": info, "roundtrip": [list(r.values()) for r in alive]}
