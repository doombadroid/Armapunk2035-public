"""The shared data contract every pgmigrate module speaks.

Purpose:
    Define the four types that move between the reader, the DDL translator,
    the rules engine, the transcoder and the emitter — `Column`, `Table`,
    `Row`, `Issue` — plus the error type that carries a failure out of a
    transform (`TransformError`) and the exact-integer currency carrier
    (`Money`).

WHY THIS EXISTS:
    Two failures.

    (1) Positional coupling. The game's own login read selects 30 columns
    positionally and consumes them as `select 0` .. `select 29`; insert or
    reorder one column and every field after it shifts, so `bankacc` is read as
    a different column entirely and the next save writes it back. That hazard
    applies to this ETL with more force, because here a one-column slip moves
    every player's money at once and there is no reverse path. So every type
    here is keyed **by name**: `Row.values` is a dict, never a list, and
    nothing in this package may index a row by position.

    (2) Currency becoming a float. SQF's only numeric type is a 32-bit float,
    exact only to 2**24; Python's is a double, exact only to 2**53. The source
    stores balances in a bigint and in an exact decimal, and both must
    round-trip byte-exactly. `Money` refuses to be converted to `float` at all
    — `float(money)` raises rather than rounding — so a currency value that
    reaches a float context fails loudly instead of silently losing cents.

    The dataclass shapes below are fixed by the project contract. Do not
    reorder or rename their fields; other modules are written against them.

Usage:
    from pgmigrate.model import Column, Table, Row, Issue, TransformError, Money

    col = Column(name="cash", mysql_type="bigint(20)", nullable=False,
                 default="0", extra="")
    tbl = Table(name="players", columns=[col], primary_key=["pid"],
                indexes=[("idx_pid", ["pid"], True)])
    row = Row(table="players", values={"pid": "76561198000000000", "cash": "42"})

    cash = Money.parse(row.values["cash"], table="players", column="cash",
                       pk=row.values["pid"])
    float(cash)          # raises TransformError — this is the point

    raise TransformError(Issue(severity="error", table="players", column="cash",
                               pk="765...", message="not an integer"))

STATUS:
    Unvalidated against real data — no live dump exists here.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation, localcontext

__all__ = [
    "Column",
    "Table",
    "Row",
    "Issue",
    "TransformError",
    "Money",
    "error",
    "assert_not_float",
    "CURRENCY_PRECISION",
]

# Wide enough that summing every balance in a player database cannot lose a
# digit: 60 significant digits against a bigint's 19 leaves 41 to spare.
CURRENCY_PRECISION = 60


# --------------------------------------------------------------------------
# The four contract types. Shape is fixed — see the module docstring.
# --------------------------------------------------------------------------


@dataclass
class Column:
    """One column of a source table, exactly as the dump declared it."""

    name: str
    mysql_type: str          # full declared type, e.g. "bigint(20) unsigned"
    nullable: bool
    default: str | None      # literal default text as written, or None if absent
    extra: str               # e.g. "auto_increment", "on update current_timestamp()"

    # `extra` is written by two independent parsers (`dump._parse_column` and
    # `ddl._parse_column`) and read by a third place. Two producers formatting
    # the same field differently — "on update current_timestamp()" against
    # "ON UPDATE CURRENT_TIMESTAMP()" — is how a consumer's `in` test starts
    # matching one of them only, silently dropping the trigger that keeps
    # `lastupdated` moving. Read the field through these accessors, never by
    # substring, and both producers agree by construction.

    @property
    def is_identity(self) -> bool:
        """True when the source declared AUTO_INCREMENT on this column."""
        return "auto_increment" in self.extra.lower()

    @property
    def on_update(self) -> str | None:
        """The `ON UPDATE <expr>` expression, lower-cased, or None.

        Normalised here so the two parsers cannot disagree about the spelling
        of a clause whose loss freezes a timestamp column forever.
        """
        m = re.search(r"on update\s+(.*)$", self.extra, re.I)
        if not m:
            return None
        return m.group(1).strip().lower()


@dataclass
class Table:
    """One source table: its columns, its primary key and its indexes."""

    name: str
    columns: list[Column]
    primary_key: list[str]
    indexes: list[tuple[str, list[str], bool]]  # (name, columns, unique)

    def column_names(self) -> list[str]:
        return [c.name for c in self.columns]

    def column(self, name: str) -> Column:
        """Look a column up by name. Raises rather than returning None.

        A missing column is a schema-drift bug, and the one thing this ETL
        must never do with schema drift is guess.
        """
        for c in self.columns:
            if c.name == name:
                return c
        raise TransformError(
            Issue(
                severity="error",
                table=self.name,
                column=name,
                pk=None,
                message=(
                    "no such column in the dumped schema; known columns: "
                    + ", ".join(self.column_names())
                ),
            )
        )

    def has_column(self, name: str) -> bool:
        return any(c.name == name for c in self.columns)


@dataclass
class Row:
    """One source row. Values are keyed by column name, never by position.

    Values arriving from `dump` are `str` (the text exactly as the dump held
    it, unescaped) or `None` for SQL NULL. Nothing is coerced on the way in —
    coercion is a transform's job, and a premature `float()` here is how
    currency gets corrupted.
    """

    table: str
    values: dict[str, object]

    def pk(self, table: Table) -> object | None:
        """Primary key of this row as a scalar (single-column PK) or tuple.

        Used only to name the offending row in an `Issue`. Returns None when
        the table has no primary key, which several log-style tables do not.
        """
        if not table.primary_key:
            return None
        parts = [self.values.get(c) for c in table.primary_key]
        return parts[0] if len(parts) == 1 else tuple(parts)


@dataclass
class Issue:
    """A single problem, always naming enough to find the row that caused it."""

    severity: str            # "error" | "warn"
    table: str
    column: str | None
    pk: object | None
    message: str

    def __post_init__(self) -> None:
        if self.severity not in ("error", "warn"):
            raise ValueError(
                f"Issue.severity must be 'error' or 'warn', got {self.severity!r}"
            )

    def format(self) -> str:
        where = self.table
        if self.column:
            where += f".{self.column}"
        if self.pk is not None:
            where += f" [pk={self.pk!r}]"
        return f"{self.severity}: {where}: {self.message}"

    def to_json(self) -> dict[str, object]:
        """Report-safe form. `pk` is stringified so the report stays JSON."""
        return {
            "severity": self.severity,
            "table": self.table,
            "column": self.column,
            "pk": None if self.pk is None else str(self.pk),
            "message": self.message,
        }


class TransformError(Exception):
    """Raised when a value cannot be transformed. Carries the `Issue`.

    Never swallow one of these into a default. A value this ETL cannot
    transform is a value nobody has decided the rule for yet, and inventing
    one here means inventing it for every player at once.
    """

    def __init__(self, issue: Issue):
        if not isinstance(issue, Issue):
            raise TypeError("TransformError takes an Issue, got " + type(issue).__name__)
        self.issue = issue
        super().__init__(issue.format())


def error(table: str, column: str | None, pk: object | None, message: str) -> TransformError:
    """Build a fatal TransformError. Shorthand for the common construction."""
    return TransformError(
        Issue(severity="error", table=table, column=column, pk=pk, message=message)
    )


# --------------------------------------------------------------------------
# Currency
# --------------------------------------------------------------------------

_INT_TEXT = re.compile(r"^[+-]?[0-9]+$")
_DEC_TEXT = re.compile(r"^[+-]?[0-9]+(\.[0-9]+)?$")


class Money:
    """An exact currency value that cannot become a float.

    Holds the *source text* verbatim alongside an exact `Decimal`. Emitting
    `.text` reproduces the dump's bytes exactly, so a value that is merely
    carried across (the overwhelmingly common case) round-trips with no
    arithmetic at all.

    `float(money)` raises. That is the entire feature: it converts the silent
    failure mode (a balance quietly rounded on its way through a double) into
    a loud one that names the table, column and primary key.
    """

    __slots__ = ("text", "value", "table", "column", "pk")

    def __init__(self, text: str, value: Decimal, table: str, column: str | None, pk: object | None):
        self.text = text
        self.value = value
        self.table = table
        self.column = column
        self.pk = pk

    # -- construction ------------------------------------------------------

    @classmethod
    def parse(
        cls,
        raw: object,
        *,
        table: str,
        column: str | None,
        pk: object | None,
        allow_decimal: bool = True,
    ) -> "Money":
        """Parse a currency value from dump text (or an int/Decimal/Money).

        Rejects `float` outright — including a float that happens to be
        integral, because by the time it is a float the damage may already be
        done and there is no way to tell from the value whether it is.
        """
        if isinstance(raw, Money):
            return raw
        if isinstance(raw, bool):
            raise error(table, column, pk, "currency value is a bool")
        if isinstance(raw, float):
            raise error(
                table,
                column,
                pk,
                "currency value arrived as a float ({!r}); currency must stay "
                "text/int/Decimal end to end".format(raw),
            )
        if isinstance(raw, int):
            return cls(str(raw), Decimal(raw), table, column, pk)
        if isinstance(raw, Decimal):
            return cls(format(raw, "f"), raw, table, column, pk)
        if not isinstance(raw, str):
            raise error(
                table, column, pk,
                f"currency value has unsupported type {type(raw).__name__}",
            )

        text = raw.strip()
        if text == "":
            raise error(table, column, pk, "currency value is an empty string")
        pattern = _DEC_TEXT if allow_decimal else _INT_TEXT
        if not pattern.match(text):
            raise error(
                table, column, pk,
                f"currency value {raw!r} is not an exact "
                + ("decimal" if allow_decimal else "integer"),
            )
        try:
            with localcontext() as ctx:
                ctx.prec = CURRENCY_PRECISION
                value = Decimal(text)
        except InvalidOperation as exc:  # pragma: no cover - regex should prevent
            raise error(table, column, pk, f"currency value {raw!r} is not exact: {exc}")
        return cls(text, value, table, column, pk)

    # -- behaviour ---------------------------------------------------------

    def __float__(self):
        raise error(
            self.table,
            self.column,
            self.pk,
            "refused to convert a currency value to float; use .value "
            "(Decimal) or .text",
        )

    # NO `scaled()` METHOD, DELIBERATELY. Balance scaling lives in exactly one
    # place — `rules.scale_currency` — because it is a *policy*: the factor, the
    # rounding direction and the declared decimal scale of the column are all
    # decisions recorded in `rules`/DECISIONS.md. A second implementation here
    # (quantizing to whatever exponent the source value happened to carry) would
    # round differently from the one the reconciliation checks its totals
    # against, and the two would disagree only on the values that round.

    def __str__(self) -> str:
        return self.text

    def __repr__(self) -> str:
        return f"Money({self.text!r})"

    def __eq__(self, other: object) -> bool:
        if isinstance(other, Money):
            return self.value == other.value
        if isinstance(other, (int, Decimal)) and not isinstance(other, bool):
            return self.value == Decimal(other)
        return NotImplemented

    def __hash__(self) -> int:
        return hash(self.value)


def assert_not_float(value: object, *, table: str, column: str | None, pk: object | None) -> object:
    """Guard: raise if `value` is (or contains) a float. Returns it otherwise.

    Called by `etl` at the boundary a currency value crosses outside `Money`'s
    hands: the value a scaling or compensation policy hands back. Everywhere
    else the guard is `Money.parse`, which refuses a float outright. Cheap, and
    it is the only thing standing between a refactor and a rounded bank balance.
    """
    if isinstance(value, float):
        raise error(
            table, column, pk,
            f"value passed through float ({value!r}); currency must stay "
            "text/int/Decimal end to end",
        )
    if isinstance(value, (list, tuple)):
        for item in value:
            assert_not_float(item, table=table, column=column, pk=pk)
    elif isinstance(value, dict):
        for item in value.values():
            assert_not_float(item, table=table, column=column, pk=pk)
    return value

# NO `sum_exact()` HELPER, DELIBERATELY. Currency totals are accumulated in
# `etl.run` inside a single `localcontext(prec=CURRENCY_PRECISION)` that spans
# the whole stream, and in `reconcile` as plain integer unit counts. A third
# summing helper that nothing called was one more place for the two totals the
# whole run is judged on to be computed differently.
