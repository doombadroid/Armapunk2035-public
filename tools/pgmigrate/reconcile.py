"""pgmigrate.reconcile — prove the one-time carry-over was lossless.

PURPOSE
    Compare the source database dump against the artefacts the ETL emitted and
    assert, per table and per player, that nothing was lost, duplicated,
    invented, silently defaulted, rounded, or re-encoded into something that no
    longer decodes to the same structure. Emits a machine-readable JSON report
    plus a human summary, and exits non-zero on any error-severity finding so a
    rehearsal script can gate on it.

WHY THIS EXISTS
    The failure mode of a silent ETL is not a crash. It is discovering three
    weeks after open beta that 4% of players lost their licences, or that one
    table's rows were paired by position instead of by name so every player's
    money moved one row over. Those bugs produce a database that boots, logs
    nothing, and looks fine. Nothing else in this tool can catch them: the
    transform cannot audit itself, because a transform bug and the transform's
    own idea of what it produced share a cause. This module therefore re-reads
    the source dump with its OWN parser and re-derives every total independently
    — a shared parser would cancel its own bugs out.

    Six specific disasters it is built to make impossible:
      1. A table quietly emerging with fewer rows than it went in with, or a
         dropped table's absence being *observed* rather than *expected*.
      2. A player id lost or duplicated. Reported one id at a time, never as an
         aggregate count, because "541 in, 541 out" hides one lost plus one
         duplicated perfectly.
      3. A currency total drifting. Compared as exact integers end to end; no
         value in this module is ever allowed to become a float, including
         inside the JSON reader (see JsonFloat).
      4. A property column transcoded to JSONB that no longer decodes back to
         the structure the source held. Historically the failure that destroyed
         stored player property, so property columns are checked exhaustively,
         never sampled.
      5. Rows left pointing at a parent that the carry-over rules dropped.
      6. An exact integer arriving as a float, or a non-null arriving as null,
         because some default filled in for a value the transform could not
         produce.

    The report is written in a stable, fully sorted, float-free form so two
    rehearsal runs can be diffed against each other; volatile provenance is
    isolated under the top-level "run" key and can be suppressed entirely with
    --omit-run-meta so the comparison is byte-for-byte.

STATUS — READ THIS BEFORE TRUSTING ANY OUTPUT
    UNVALIDATED. No dump of the live database exists in this workspace, so this
    module has never been run against real data. Every check here is reasoned
    from the schema and the plan document, not observed. The first run against a
    real dump should be assumed to find bugs in THIS FILE before it finds bugs
    in the carry-over. In particular the dump reader has only ever been exercised
    against the small hand-written fixtures in test_reconcile.py.

INPUTS
    source  A mysqldump file (plain or .gz). Not a live connection: the contract
            for this tool is a dump, so a rehearsal is reproducible from a file
            that can be kept, diffed and re-run.
    output  A directory of newline-delimited JSON, one file per table, named
            <table>.jsonl, one JSON object per line keyed by target column name.
            This is the ETL's inspectable intermediate; reconciling against the
            intermediate rather than against a loaded database keeps this check
            runnable without a database driver.
    spec    A Python file defining RECONCILE_SPEC (a ReconcileSpec), which
            declares the carry-over rules: what each table's disposition is,
            which columns are currency, which are encoded, which foreign keys
            must hold, and which player ids are excluded and why.

            Ship: `carryover_spec.py`, three lines, which calls
            `rules.reconcile_spec()`. Generated rather than hand-written because
            a hand-written spec drifts from the policy, and drift's failure mode
            here is a table that stopped carrying and reconciled clean because
            the spec still said to expect zero rows. The independence that
            matters — this module's own parser, decoder and totals — is
            untouched by sharing the *rules*.

Usage:
    # as a gate in a rehearsal script
    python3 reconcile.py \
        --dump   /srv/dumps/live-2026-08-14.sql.gz \
        --output /srv/pgmigrate/out/jsonl \
        --spec   carryover_spec.py \
        --report /srv/pgmigrate/reports/rehearsal-07.json \
        --omit-run-meta
    echo $?          # 0 = clean, 1 = error-severity findings, 2 = bad invocation

    # compare two rehearsals
    diff rehearsal-06.json rehearsal-07.json

    # from Python
    from reconcile import DumpSource, JsonlDirSource, reconcile, render_json
    report = reconcile(DumpSource(dump_path), JsonlDirSource(out_dir), SPEC)
    if report.error_count:
        raise SystemExit(render_human(report))
"""

from __future__ import annotations

import argparse
import decimal
import gzip
import io
import json
import os
import re
import sys
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Callable, Iterable, Iterator, Mapping, Sequence

# --------------------------------------------------------------------------
# Shared contract. model.py is owned by the etl agent; both import paths are
# tried so this file works as a package module and as a directly-run script.
# --------------------------------------------------------------------------
try:  # pragma: no cover - trivial import plumbing
    from .model import Issue, Row, TransformError  # type: ignore
except ImportError:  # pragma: no cover
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from model import Issue, Row, TransformError  # type: ignore

TOOL_NAME = "pgmigrate.reconcile"
REPORT_FORMAT_VERSION = 1

ERROR = "error"
WARN = "warn"


# ==========================================================================
# Errors
# ==========================================================================


class ReconcileConfigError(Exception):
    """The spec or the invocation is wrong. Not a data finding — a bug in the
    setup, raised rather than reported so it can never be mistaken for a clean
    run."""


class DumpParseError(Exception):
    """The source dump could not be read. Never recoverable by guessing: a dump
    this module cannot parse is a dump it cannot reconcile, and reporting
    "0 rows" for an unparseable table is the exact silent failure this file
    exists to prevent."""


class EncodingError(Exception):
    """A legacy-encoded value could not be decoded."""


# ==========================================================================
# Numeric carriers. Nothing in this module may hold money in a float.
# ==========================================================================


class _NumberText(str):
    """Base for the two float-shaped literals this module refuses to float()."""

    __slots__ = ()

    @property
    def decimal(self) -> Decimal:
        return Decimal(str(self))

    @property
    def is_integral(self) -> bool:
        d = self.decimal
        return d == d.to_integral_value()


class NumericText(_NumberText):
    """A numeric literal read from the source dump that is not an exact integer.

    WHY: float(x) is how money stops being money. The dump reader never calls
    float(); anything with a decimal point or an exponent is carried as its
    original text and converted, if at all, to exact integer units by
    decimal_to_units(). A value that is still a NumericText when a check wants
    an integer is an error, not a cast.
    """

    __slots__ = ()


class JsonFloat(_NumberText):
    """A JSON number the output emitted with a decimal point or exponent.

    WHY: json.loads() would hand that back as a Python float, and once it is a
    float the evidence that it was ever exact is gone. The reader installs this
    as parse_float, so a float literal in the ETL's output survives as a
    *labelled* value and check_type_sanity / check_currency can call it what it
    is: money (or an exact integer) emitted as a float.
    """

    __slots__ = ()


def _unwrap_money(value: object) -> object:
    """Accept an exact-currency carrier from the transform side without ever
    touching float(). Anything exposing verbatim source text is read as text."""
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    text = getattr(value, "text", None)
    if isinstance(text, str):
        return text
    if isinstance(value, Decimal):
        return format(value, "f")
    return value


_INT_RE = re.compile(r"[+-]?\d+\Z")
_DEC_RE = re.compile(r"([+-]?)(\d*)(?:\.(\d*))?\Z")


def to_exact_int(value: object, *, table: str, column: str, pk: object) -> int:
    """Return value as an exact Python int, or raise TransformError-shaped Issue
    data via ValueError. Never rounds, never casts a float."""
    value = _unwrap_money(value)
    if isinstance(value, bool):
        raise ValueError(
            f"{table}.{column} pk={pk!r}: boolean where an exact integer was expected"
        )
    if isinstance(value, int):
        return value
    if isinstance(value, JsonFloat):
        raise ValueError(
            f"{table}.{column} pk={pk!r}: emitted as a JSON float literal "
            f"({str(value)!r}); an exact integer column must never be a float"
        )
    if isinstance(value, str):
        text = value.strip()
        if _INT_RE.match(text):
            return int(text)
        if "e" in text.lower():
            raise ValueError(
                f"{table}.{column} pk={pk!r}: scientific notation {text!r} in an "
                f"exact-integer column; this is the float-exactness hazard, not a "
                f"format quirk"
            )
        raise ValueError(
            f"{table}.{column} pk={pk!r}: {text!r} is not an exact integer"
        )
    if isinstance(value, float):
        raise ValueError(
            f"{table}.{column} pk={pk!r}: Python float {value!r} reached an "
            f"exact-integer column"
        )
    raise ValueError(
        f"{table}.{column} pk={pk!r}: {type(value).__name__} cannot be an exact integer"
    )


def decimal_to_units(
    value: object, scale: int, *, table: str, column: str, pk: object
) -> int:
    """Return an exact-decimal value as an integer count of 10**-scale units.

    WHY: the exact-decimal currency column's correctness rests on the value
    never becoming a float, and automatic type conversion is precisely the
    mechanism that would make it one. Working in integer units means the whole
    of this module's currency arithmetic — sums, scaling, deltas — is integer
    arithmetic, and the comparison at the end is `==` on ints.
    """
    value = _unwrap_money(value)
    if isinstance(value, bool):
        raise ValueError(f"{table}.{column} pk={pk!r}: boolean in a currency column")
    if isinstance(value, float):
        raise ValueError(
            f"{table}.{column} pk={pk!r}: Python float {value!r} reached a currency "
            f"column; exactness is already lost by the time it gets here"
        )
    if isinstance(value, int):
        return value * (10**scale)
    if not isinstance(value, str):
        raise ValueError(
            f"{table}.{column} pk={pk!r}: {type(value).__name__} is not a decimal value"
        )
    text = value.strip()
    if "e" in text.lower():
        raise ValueError(
            f"{table}.{column} pk={pk!r}: scientific notation {text!r} in a currency "
            f"column"
        )
    m = _DEC_RE.match(text)
    if not m or (not m.group(2) and not m.group(3)):
        raise ValueError(f"{table}.{column} pk={pk!r}: {text!r} is not a decimal value")
    sign, whole, frac = m.group(1), m.group(2) or "0", m.group(3) or ""
    if len(frac) > scale:
        keep, extra = frac[:scale], frac[scale:]
        if extra.strip("0"):
            raise ValueError(
                f"{table}.{column} pk={pk!r}: {text!r} carries more precision than the "
                f"column's scale of {scale}; truncating it would silently lose money"
            )
        frac = keep
    frac = frac.ljust(scale, "0")
    units = int(whole + frac) if frac else int(whole)
    return -units if sign == "-" else units


def units_to_text(units: int, scale: int) -> str:
    """Render integer units back to decimal text. Report output only — never fed
    back into arithmetic."""
    if scale == 0:
        return str(units)
    sign = "-" if units < 0 else ""
    digits = str(abs(units)).rjust(scale + 1, "0")
    return f"{sign}{digits[:-scale]}.{digits[-scale:]}"


ROUNDINGS = ("floor", "half_up", "half_even")


@dataclass(frozen=True)
class Scaling:
    """An economy rescale applied by the ETL, as an exact rational.

    WHY: "carry balances at 1:2" must be reproducible here bit for bit, and
    0.5 as a float is a trap waiting for the first odd balance. numerator and
    denominator are integers, the rounding mode is named, and the arithmetic
    below is integer-only. reconcile must mirror the rule the transform used —
    per-row then summed, NOT summed then scaled, because those differ by up to
    one unit per player.
    """

    numerator: int = 1
    denominator: int = 1
    rounding: str = "half_up"

    def __post_init__(self) -> None:
        if self.denominator == 0:
            raise ReconcileConfigError("Scaling.denominator must not be zero")
        if self.rounding not in ROUNDINGS:
            raise ReconcileConfigError(
                f"Scaling.rounding {self.rounding!r} unknown; expected one of {ROUNDINGS}"
            )

    @property
    def identity(self) -> bool:
        return self.numerator == self.denominator

    def apply(self, units: int) -> int:
        n = units * self.numerator
        d = self.denominator
        if d < 0:
            n, d = -n, -d
        if n % d == 0:
            return n // d
        if self.rounding == "floor":
            return n // d
        neg = n < 0
        a = -n if neg else n
        q, r = divmod(a, d)
        twice = r * 2
        if twice > d:
            q += 1
        elif twice == d:
            if self.rounding == "half_up":
                q += 1
            elif q % 2 == 1:  # half_even
                q += 1
        return -q if neg else q


# ==========================================================================
# Spec — everything reconcile needs to know, declared explicitly.
# ==========================================================================

# DISP_ prefixed on purpose. `rules.CARRY` is the policy dict and `reconcile.CARRY`
# was the string "carry": two modules, one name, two entirely different objects,
# and a spec file has to import both. `rules.DROP` and this module's DISP_DROP being
# the same string was a coincidence, not an agreement.
DISP_CARRY = "carry"  # every source row must appear, minus documented exclusions
DISP_DROP = "drop"  # output must hold zero rows, and that zero is EXPECTED
DISP_FILTER = "filter"  # a predicate over source rows decides the expected count
DISP_REBUILD = "rebuild"  # output count is stated outright by the spec

DISPOSITIONS = (DISP_CARRY, DISP_DROP, DISP_FILTER, DISP_REBUILD)


@dataclass(frozen=True)
class TableRule:
    """What the carry-over rules say happens to one table.

    reason is mandatory for DROP: a dropped table's zero row count must be
    something a human wrote down on purpose, not something the run observed.
    """

    name: str
    disposition: str
    primary_key: tuple[str, ...] = ()
    reason: str = ""
    keep: Callable[[Mapping[str, object]], bool] | None = None  # DISP_FILTER
    expected_rows: int | None = None  # DISP_REBUILD
    player_id_column: str | None = None  # for exclusion accounting

    def __post_init__(self) -> None:
        if self.disposition not in DISPOSITIONS:
            raise ReconcileConfigError(
                f"table {self.name!r}: disposition {self.disposition!r} unknown; "
                f"expected one of {DISPOSITIONS}"
            )
        if self.disposition == DISP_DROP and not self.reason:
            raise ReconcileConfigError(
                f"table {self.name!r}: a DROP rule must carry a reason, so that an "
                f"empty table in the output is documented rather than merely observed"
            )
        if self.disposition == DISP_FILTER and self.keep is None:
            raise ReconcileConfigError(
                f"table {self.name!r}: a FILTER rule needs keep=<predicate over source "
                f"rows> so the expected count is derived, not read off the output"
            )
        if self.disposition == DISP_REBUILD and self.expected_rows is None:
            raise ReconcileConfigError(
                f"table {self.name!r}: a REBUILD rule needs expected_rows=<int>"
            )


@dataclass(frozen=True)
class IdentityRule:
    """Where player identity lives, and who is deliberately not coming."""

    table: str
    column: str
    exclusions: Mapping[str, str] = field(default_factory=dict)  # id -> reason

    def __post_init__(self) -> None:
        for pid, reason in self.exclusions.items():
            if not reason:
                raise ReconcileConfigError(
                    f"identity exclusion {pid!r} has no documented reason; an "
                    f"undocumented exclusion is indistinguishable from a lost player"
                )


@dataclass(frozen=True)
class CurrencyColumn:
    """A column whose total must survive exactly."""

    table: str
    column: str
    kind: str = "integer"  # "integer" | "decimal"
    scale: int = 0  # decimal digits, for kind == "decimal"
    scaling: Scaling = Scaling()
    output_column: str | None = None  # when the target renamed it

    def __post_init__(self) -> None:
        if self.kind not in ("integer", "decimal"):
            raise ReconcileConfigError(
                f"{self.table}.{self.column}: kind {self.kind!r} must be 'integer' or "
                f"'decimal'"
            )
        if self.kind == "integer" and self.scale:
            raise ReconcileConfigError(
                f"{self.table}.{self.column}: an integer currency column has no scale"
            )

    @property
    def target(self) -> str:
        return self.output_column or self.column


@dataclass(frozen=True)
class EncodingColumn:
    """A column carried from the legacy array codec into JSONB."""

    table: str
    column: str
    exhaustive: bool = True
    sample_every: int = 1
    empty_policy: str | None = None  # "null" | "empty_array"
    output_column: str | None = None

    def __post_init__(self) -> None:
        if not self.exhaustive and self.sample_every < 2:
            raise ReconcileConfigError(
                f"{self.table}.{self.column}: sampling asked for but sample_every="
                f"{self.sample_every}"
            )
        if self.empty_policy not in (None, "null", "empty_array"):
            raise ReconcileConfigError(
                f"{self.table}.{self.column}: empty_policy {self.empty_policy!r} must "
                f"be 'null' or 'empty_array'"
            )

    @property
    def target(self) -> str:
        return self.output_column or self.column


@dataclass(frozen=True)
class FKCheck:
    """A reference that must still resolve after the carry-over.

    Named FKCheck, not ForeignKey: `ddl.ForeignKey` is a different dataclass with
    different fields (a constraint to emit, with ON DELETE/ON UPDATE actions),
    and one file importing both under one name is a bug waiting for whoever
    writes the spec. This one is an assertion about data, not a constraint.
    """

    child_table: str
    child_column: str
    parent_table: str
    parent_column: str
    nullable: bool = True


@dataclass(frozen=True)
class CompensationRule:
    """How to re-derive the compensation credits the ETL paid, INDEPENDENTLY.

    Without this the auditor reconciles the credit column against
    `source x scale` and reports every credited player as a delta — which reads
    exactly like money being invented, and is the finding most likely to get the
    money check switched off to make a run "pass".

    It re-values the dropped property from the SOURCE dump with the same policy
    rather than reading a ledger the ETL wrote. That keeps the check adversarial:
    an ETL that paid the wrong credit still fails here, which a ledger comparison
    could not catch.

    `sources` maps source TABLE -> compensation source NAME, because the policy is
    keyed by name and the dump is keyed by table. `order` is BEFORE_SCALING or
    AFTER_SCALING and must match what the ETL used; the two give different numbers
    for the same player at any factor other than 1:1.
    """

    sources: Mapping[str, str]
    credit_table: str
    credit_column: str
    credit_owner_column: str
    valuer: Callable[[str, Mapping[str, object]], int]
    owner_of: Callable[[str, Mapping[str, object]], object]
    order: str = "before_scaling"


@dataclass(frozen=True)
class ReconcileSpec:
    """The full declaration. Anything not declared here is an error when it is
    encountered — no table, column or exclusion gets to be implicit."""

    tables: tuple[TableRule, ...]
    identity: IdentityRule
    currency: tuple[CurrencyColumn, ...] = ()
    encoded: tuple[EncodingColumn, ...] = ()
    foreign_keys: tuple[FKCheck, ...] = ()
    dropped_columns: Mapping[tuple[str, str], str] = field(default_factory=dict)
    allowed_null_columns: Mapping[tuple[str, str], str] = field(default_factory=dict)
    renamed_columns: Mapping[tuple[str, str], str] = field(default_factory=dict)
    ignore_source_tables: tuple[str, ...] = ()
    compensation: "CompensationRule | None" = None
    cross_check_decoder: bool = True

    def __post_init__(self) -> None:
        seen: set[str] = set()
        for rule in self.tables:
            if rule.name in seen:
                raise ReconcileConfigError(f"table {rule.name!r} declared twice")
            seen.add(rule.name)
        for mapping, label in (
            (self.dropped_columns, "dropped_columns"),
            (self.allowed_null_columns, "allowed_null_columns"),
        ):
            for key, reason in mapping.items():
                if not reason:
                    raise ReconcileConfigError(
                        f"{label}{key!r} has no documented reason"
                    )
        if self.identity.table not in seen:
            raise ReconcileConfigError(
                f"identity table {self.identity.table!r} has no TableRule"
            )

    def rule(self, table: str) -> TableRule | None:
        for r in self.tables:
            if r.name == table:
                return r
        return None

    def target_column(self, table: str, column: str) -> str:
        return self.renamed_columns.get((table, column), column)

    def retained_tables(self) -> set[str]:
        """Tables whose rows must be held in memory for value-level checks.

        Every carried table with a declared primary key is retained, not only the
        ones naming currency or encoded columns. The narrower rule left tables
        like `bans`, `talent_points` and `player_names` with a row count and
        nothing else — so a `bans` table that carried every row with the reason
        nulled, or `talent_points` carrying zeros, passed clean. Anything still
        not retained is reported by `check_type_sanity` as a skipped check rather
        than left absent from the report.

        The cost is memory: bounded by the sum of the carried tables rather than
        by the largest inspected one. Dropped tables — the big ones, `log` above
        all — are still counted and never retained.
        """
        keep = {self.identity.table}
        if self.compensation is not None:
            # Dropped, and retained anyway: their rows are the only evidence of
            # what each credit was FOR, so a credit cannot be checked without
            # them. They are small (property, not events) — `log`, the table this
            # rule exists to keep out of memory, is not among them.
            keep.update(self.compensation.sources)
        for r in self.tables:
            if r.disposition == DISP_FILTER:
                keep.add(r.name)
            elif r.disposition in (DISP_CARRY, DISP_REBUILD) and r.primary_key:
                keep.add(r.name)
        for c in self.currency:
            keep.add(c.table)
        for e in self.encoded:
            keep.add(e.table)
        for fk in self.foreign_keys:
            keep.add(fk.child_table)
            keep.add(fk.parent_table)
        return keep


def spec_from_module(path: str) -> ReconcileSpec:
    """Load RECONCILE_SPEC from a Python file. Fails loud and names what it
    looked for; a spec that silently defaults to "everything carries" would make
    every check below vacuous."""
    import importlib.util

    if not os.path.isfile(path):
        raise ReconcileConfigError(f"spec file not found: {path}")
    module_spec = importlib.util.spec_from_file_location("pgmigrate_spec", path)
    if module_spec is None or module_spec.loader is None:
        raise ReconcileConfigError(f"spec file is not importable: {path}")
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    if not hasattr(module, "RECONCILE_SPEC"):
        raise ReconcileConfigError(
            f"{path} defines no RECONCILE_SPEC; reconcile needs an explicit "
            f"ReconcileSpec naming every table's disposition"
        )
    spec = module.RECONCILE_SPEC
    # Identity by name, not by `isinstance`: the spec file imports `reconcile`
    # as a module while this file may be running as `__main__`, which makes two
    # distinct class objects with the same definition. An isinstance check there
    # rejects a perfectly good spec and reads like a broken spec.
    if type(spec).__name__ != "ReconcileSpec" or not hasattr(spec, "tables"):
        raise ReconcileConfigError(
            f"{path}: RECONCILE_SPEC is {type(spec).__name__}, expected ReconcileSpec"
        )
    return spec


# ==========================================================================
# The legacy array codec.
# ==========================================================================


def _exact_number(literal: str) -> object:
    """Parse a JSON numeric literal without inventing a float.

    A literal that denotes a whole number becomes an int — including the
    `1e+015` forms the source engine emits, which are integers wearing a float's
    clothes. Everything else becomes an exact Decimal. Written independently of
    the transform's own decoder on purpose (see decode_legacy_array), but to the
    same stated rule, so that a disagreement between the two is a finding rather
    than noise.
    """
    value = Decimal(literal)
    if value == value.to_integral_value():
        return int(value)
    return value


def decode_legacy_array(text: str) -> object:
    """Decode one value of the bespoke array text codec.

    The textual steps are deliberately byte-identical to the decoder that has
    been validated round-trip against real property columns; two things differ
    on purpose:

      - it raises instead of returning None. That decoder's None is
        indistinguishable from an empty column, and that conflation is the exact
        mechanism that has destroyed stored player property before;
      - it is re-implemented here rather than imported from the transform. A
        reconciliation that shares a decoder with the thing it audits cannot see
        a decoder bug, because the bug is applied identically to both sides and
        cancels itself out. check_encoding cross-checks the two against each
        other when the transform's decoder is importable.
    """
    if not isinstance(text, str):
        raise EncodingError(f"expected text, got {type(text).__name__}")
    s = text.replace("`", '"')
    if s.startswith('"') and s.endswith('"') and len(s) >= 2:
        s = s[1:-1]
    s = s.replace('""', '"')
    try:
        return json.loads(s, parse_float=_exact_number)
    except (ValueError, RecursionError, decimal.InvalidOperation) as exc:
        raise EncodingError(f"{exc}") from exc


_NUMERIC_TYPES = (int, float, Decimal, _NumberText)


def _is_number(v: object) -> bool:
    return isinstance(v, _NUMERIC_TYPES) and not isinstance(v, bool)


def _numeric_value(v: object) -> Decimal:
    if isinstance(v, _NumberText):
        return v.decimal
    if isinstance(v, Decimal):
        return v
    if isinstance(v, int):
        return Decimal(v)
    return Decimal(repr(v))  # float: repr round-trips exactly


def _is_integral_form(v: object) -> bool:
    """True when the value's *written form* is an exact integer, not merely its
    value. `1` is; `1.0` and `1e+015` are not."""
    return isinstance(v, int) and not isinstance(v, bool)


def structure_diff(a: object, b: object, path: str = "$") -> tuple[str | None, str]:
    """Compare a decoded source structure against an emitted one.

    Returns (severity, detail) for the first difference, or (None, "") when they
    match. Type-strict on purpose: in Python True == 1 and 1 == 1.0, and the
    consumer at the far end of this data compares with a type-strict equality
    operator, so a flag that came back as a number or an integer that came back
    as 1.0 is a real behavioural change even though `==` calls them equal.

    An integer whose *value* survived but whose *form* became a float literal is
    a warning rather than an error: it is numerically intact but will not
    compare equal downstream, so it needs a human decision rather than a silent
    pass or a blocked run.
    """
    if isinstance(a, bool) or isinstance(b, bool):
        if isinstance(a, bool) and isinstance(b, bool) and a is b:
            return None, ""
        return ERROR, f"{path}: {_short(a, 60)} vs {_short(b, 60)} (boolean mismatch)"
    if a is None or b is None:
        if a is None and b is None:
            return None, ""
        return ERROR, f"{path}: {_short(a, 60)} vs {_short(b, 60)} (null mismatch)"
    if _is_number(a) and _is_number(b):
        try:
            same_value = _numeric_value(a) == _numeric_value(b)
        except (decimal.InvalidOperation, ValueError):
            return ERROR, f"{path}: {_short(a, 60)} vs {_short(b, 60)} (unparseable number)"
        if not same_value:
            return ERROR, f"{path}: {_short(a, 60)} vs {_short(b, 60)}"
        if _is_integral_form(a) and not _is_integral_form(b):
            return (
                WARN,
                f"{path}: exact integer {a} was emitted as the float literal "
                f"{str(b)}; the value survives but a type-strict consumer will not "
                f"match it",
            )
        return None, ""
    if isinstance(a, str) and isinstance(b, str):
        return (None, "") if a == b else (ERROR, f"{path}: {a!r} vs {b!r}")
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return ERROR, f"{path}: length {len(a)} vs {len(b)}"
        worst: tuple[str | None, str] = (None, "")
        for i, (x, y) in enumerate(zip(a, b)):
            sev, detail = structure_diff(x, y, f"{path}[{i}]")
            if sev == ERROR:
                return sev, detail
            if sev == WARN and worst[0] is None:
                worst = (sev, detail)
        return worst
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a) != set(b):
            missing = sorted(set(a) - set(b))
            extra = sorted(set(b) - set(a))
            return ERROR, f"{path}: keys missing={missing} extra={extra}"
        worst = (None, "")
        for k in sorted(a):
            sev, detail = structure_diff(a[k], b[k], f"{path}.{k}")
            if sev == ERROR:
                return sev, detail
            if sev == WARN and worst[0] is None:
                worst = (sev, detail)
        return worst
    return (
        ERROR,
        f"{path}: {type(a).__name__} {_short(a, 60)} vs {type(b).__name__} "
        f"{_short(b, 60)}",
    )


def structurally_equal(a: object, b: object) -> bool:
    """True when the two structures match with no error-severity difference."""
    return structure_diff(a, b)[0] != ERROR


def reference_decoder() -> Callable | None:
    """The transform's own decoder, if it is importable.

    Used only as a cross-check. Two independently written decoders that
    disagree about what a player's stored property means is a finding in its own
    right, and one of them is wrong.
    """
    mod = None
    try:  # pragma: no cover - import plumbing
        from . import mres as mod  # type: ignore
    except ImportError:  # pragma: no cover
        try:
            import mres as mod  # type: ignore
        except ImportError:
            return None
    return getattr(mod, "decode_strict", None)


# ==========================================================================
# Source reader — an independent mysqldump parser.
# ==========================================================================

_UNESCAPE = {
    "0": "\0",
    "'": "'",
    '"': '"',
    "b": "\b",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "Z": "\x1a",
    "\\": "\\",
}

_OUT_SCAN = re.compile(r"['`;]")
_STR_SCAN = re.compile(r"['\\]")
_IDENT_SCAN = re.compile("`")


def iter_statements(stream: Iterable[str]) -> Iterator[str]:
    """Yield complete SQL statements from a dump, quote- and identifier-aware.

    WHY hand-rolled: splitting a dump on ';' or on newlines works right up until
    a player name contains a semicolon or an escaped quote, at which point rows
    are silently dropped from the count that is supposed to prove nothing was
    dropped.
    """
    buf: list[str] = []
    state = "out"
    for line in stream:
        pos = 0
        n = len(line)
        while pos < n:
            if state == "out":
                m = _OUT_SCAN.search(line, pos)
                if not m:
                    buf.append(line[pos:])
                    pos = n
                    break
                buf.append(line[pos : m.end()])
                pos = m.end()
                ch = m.group()
                if ch == "'":
                    state = "str"
                elif ch == "`":
                    state = "ident"
                else:  # ';'
                    stmt = "".join(buf).strip()
                    buf = []
                    if stmt:
                        yield stmt
            elif state == "str":
                m = _STR_SCAN.search(line, pos)
                if not m:
                    buf.append(line[pos:])
                    pos = n
                    break
                buf.append(line[pos : m.end()])
                pos = m.end()
                if m.group() == "\\":
                    if pos < n:
                        buf.append(line[pos])
                        pos += 1
                else:  # closing quote, unless it is a doubled ''
                    if pos < n and line[pos] == "'":
                        buf.append("'")
                        pos += 1
                    else:
                        state = "out"
            else:  # ident
                m = _IDENT_SCAN.search(line, pos)
                if not m:
                    buf.append(line[pos:])
                    pos = n
                    break
                buf.append(line[pos : m.end()])
                pos = m.end()
                if pos < n and line[pos] == "`":
                    buf.append("`")
                    pos += 1
                else:
                    state = "out"
    tail = "".join(buf).strip()
    if tail:
        yield tail


_CREATE_RE = re.compile(r"\ACREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`([^`]+)`", re.I)
_INSERT_RE = re.compile(
    r"\AINSERT\s+(?:LOW_PRIORITY\s+|DELAYED\s+|HIGH_PRIORITY\s+)?"
    r"(?:IGNORE\s+)?INTO\s+`([^`]+)`\s*(\([^)]*\))?\s*VALUES\s*",
    re.I,
)
# The type may itself contain commas — decimal(20,4), enum('a','b') — so this
# cannot stop at the first one. Getting that wrong drops a column from the
# name map, and a dropped column name is how values shift one place along.
_COLDEF_RE = re.compile(r"\A\s*`([^`]+)`\s+(.*?)\s*,?\s*\Z")
_PK_RE = re.compile(r"\A\s*PRIMARY\s+KEY\s*\(([^)]*)\)", re.I)
_NONCOL_RE = re.compile(
    r"\A\s*(PRIMARY\s+KEY|UNIQUE\s+KEY|KEY|INDEX|CONSTRAINT|FULLTEXT|SPATIAL|CHECK)\b",
    re.I,
)


def statement_head(stmt: str) -> str:
    """A statement with its leading comments removed, or "" if it is only comments.

    WHY: a comment does not end a statement, so `-- Table structure ...` followed
    by `CREATE TABLE` arrives here as ONE string starting with `--`. Skipping the
    whole thing on that first character loses the CREATE TABLE — and a table
    whose column names were never read is a table whose rows cannot be read by
    name at all. mysqldump usually terminates its own preamble with a `;`, which
    is why this survives most dumps; "usually" is not a property to rely on in
    the file that decides whether a migration was lossless.
    """
    text = stmt.lstrip()
    while text:
        if text.startswith("--") or text.startswith("#"):
            nl = text.find("\n")
            if nl < 0:
                return ""
            text = text[nl + 1:].lstrip()
            continue
        if text.startswith("/*"):
            end = text.find("*/")
            if end < 0:
                return ""
            text = text[end + 2:].lstrip()
            continue
        break
    return text


@dataclass
class DumpTable:
    name: str
    columns: list[str]
    types: dict[str, str]
    primary_key: list[str]


def parse_create_table(stmt: str) -> DumpTable:
    m = _CREATE_RE.match(stmt)
    if not m:
        raise DumpParseError(f"not a CREATE TABLE: {stmt[:80]!r}")
    name = m.group(1)
    open_paren = stmt.find("(", m.end() - 1)
    if open_paren < 0:
        raise DumpParseError(f"CREATE TABLE {name}: no column list")
    body = stmt[open_paren + 1 :]
    columns: list[str] = []
    types: dict[str, str] = {}
    pk: list[str] = []
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        pm = _PK_RE.match(line)
        if pm:
            pk = [c.strip().strip("`") for c in pm.group(1).split(",") if c.strip()]
            continue
        if _NONCOL_RE.match(line):
            continue
        cm = _COLDEF_RE.match(line)
        if cm:
            col = cm.group(1)
            columns.append(col)
            types[col] = cm.group(2)
    if not columns:
        raise DumpParseError(f"CREATE TABLE {name}: no columns parsed")
    return DumpTable(name=name, columns=columns, types=types, primary_key=pk)


def _unescape(text: str) -> str:
    """Decode the body of a single-quoted literal. Mirrors the CONTRACT, not the code.

    Two rules that look like details and are not:

    * The short-circuit tests for BOTH escape forms. A dump taken with
      NO_BACKSLASH_ESCAPES writes `O''Brien` and contains no backslash at all, so
      a `"\\\\" not in text` short-circuit returns the doubled quote verbatim —
      and every apostrophe-bearing name in the database then reads as a value the
      ETL changed. Those are the same names the source's sanitizers have been
      mangling for years, so they are exactly the rows a human would be asked to
      adjudicate.
    * `\\%` and `\\_` KEEP their backslash. MySQL leaves them alone so LIKE
      patterns survive a dump/restore. Dropping it here is not cosmetic: the
      transcoder refuses any value containing a backslash (mres DIVERGENCE 7), so
      this parser would decode a value the ETL refused and the cross-check would
      report a *decoder* divergence whose real cause is a *parser* divergence —
      sending the operator to the wrong file.

    Kept byte-compatible with `dump.unescape_mysql_string` by a shared fixture of
    hostile literals (see test_reconcile), never by sharing code: a shared parser
    would cancel its own bugs out, which is the whole point of this module.
    """
    if "\\" not in text and "''" not in text:
        return text
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "\\" and i + 1 < n:
            nxt = text[i + 1]
            if nxt in ("%", "_"):
                out.append("\\" + nxt)
            else:
                out.append(_UNESCAPE.get(nxt, nxt))
            i += 2
        elif ch == "'" and i + 1 < n and text[i + 1] == "'":
            out.append("'")
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def _from_hex(digits: str, table: str) -> str:
    """Decode a hex literal (`mysqldump --hex-blob`) to text, or refuse.

    WHY: --hex-blob is routine for binary and text columns, and keeping the
    literal `0x48656C6C6F` while the transform decodes it to `Hello` makes every
    such column mismatch — including, potentially, the property columns, which
    would turn the encoding check into a wall of false findings with the real
    ones buried in it. Non-UTF-8 bytes are an error, not a mojibake string.
    """
    if len(digits) % 2:
        digits = "0" + digits
    try:
        raw = bytes.fromhex(digits)
    except ValueError as exc:
        raise DumpParseError(f"{table}: malformed hex literal 0x{digits}: {exc}") from exc
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise DumpParseError(
            f"{table}: hex literal 0x{digits[:32]}… is not valid UTF-8 ({exc}); this "
            f"column is binary and needs an explicit rule, not a guess"
        ) from exc


_VAL_NULL = re.compile(r"NULL", re.I)
_VAL_NUM = re.compile(r"[+-]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?")
_VAL_HEX = re.compile(r"0x[0-9a-fA-F]+|[xX]'([0-9a-fA-F]*)'")
_VAL_BIN = re.compile(r"[bB]'([01]*)'")
_VAL_PREFIX = re.compile(r"_[a-zA-Z0-9]+\s*")


def parse_values(text: str, table: str) -> Iterator[list[object]]:
    """Tokenise the VALUES clause into row tuples.

    Integer literals become int. Everything else numeric becomes NumericText —
    float() is never called, because this parser feeds the money check.
    """
    i = 0
    n = len(text)
    while i < n:
        while i < n and text[i] in " \t\r\n,":
            i += 1
        if i >= n or text[i] == ";":
            return
        if text[i] != "(":
            raise DumpParseError(
                f"{table}: expected '(' in VALUES near {text[i : i + 40]!r}"
            )
        i += 1
        row: list[object] = []
        while True:
            while i < n and text[i] in " \t\r\n":
                i += 1
            if i >= n:
                raise DumpParseError(f"{table}: unterminated VALUES tuple")
            if text[i] == ")":
                i += 1
                break
            pm = _VAL_PREFIX.match(text, i)
            if pm and text[pm.end() : pm.end() + 1] == "'":
                i = pm.end()
            ch = text[i]
            if ch == "'":
                j = i + 1
                while j < n:
                    if text[j] == "\\":
                        j += 2
                        continue
                    if text[j] == "'":
                        if j + 1 < n and text[j + 1] == "'":
                            j += 2
                            continue
                        break
                    j += 1
                if j >= n:
                    raise DumpParseError(f"{table}: unterminated string literal")
                row.append(_unescape(text[i + 1 : j]))
                i = j + 1
            else:
                m = _VAL_NULL.match(text, i)
                if m and (
                    m.end() >= n or text[m.end()] in " \t\r\n,)"
                ):
                    row.append(None)
                    i = m.end()
                else:
                    m = _VAL_HEX.match(text, i)
                    if m:
                        digits = m.group(1)
                        if digits is None:          # the 0x… form
                            digits = m.group(0)[2:]
                        row.append(_from_hex(digits, table))
                        i = m.end()
                    else:
                        m = _VAL_BIN.match(text, i)
                        if m:
                            row.append(int(m.group(1) or "0", 2))
                            i = m.end()
                        else:
                            m = _VAL_NUM.match(text, i)
                            if not m:
                                raise DumpParseError(
                                    f"{table}: unparseable value near "
                                    f"{text[i : i + 40]!r}"
                                )
                            lit = m.group(0)
                            row.append(
                                int(lit) if _INT_RE.match(lit) else NumericText(lit)
                            )
                            i = m.end()
            while i < n and text[i] in " \t\r\n":
                i += 1
            if i < n and text[i] == ",":
                i += 1
                continue
            if i < n and text[i] == ")":
                i += 1
                break
            raise DumpParseError(
                f"{table}: expected ',' or ')' near {text[i : i + 40]!r}"
            )
        yield row


@dataclass
class Snapshot:
    """One side of the comparison: counts for every table, rows for the tables
    the spec needs to inspect.

    `missing_tables` names tables the spec asked to retain that this side does
    not contain at all. Recorded rather than raised: a spec generated from the
    whole carry-over policy legitimately names tables a given dump has never had
    (the policy knows more tables than any one source box), and aborting the
    whole audit for one of them buys nothing. It is reported as an error finding
    by `check_row_counts`, so it still fails the run.
    """

    origin: str
    counts: dict[str, int]
    rows: dict[str, list[dict[str, object]]]
    columns: dict[str, list[str]] = field(default_factory=dict)
    missing_tables: set[str] = field(default_factory=set)


def _open_text(path: str) -> io.TextIOBase:
    if path.endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="surrogateescape")
    return open(path, "rt", encoding="utf-8", errors="surrogateescape")


class DumpSource:
    """Reads the source mysqldump in a single pass.

    Counts every table; retains full rows only for the tables the spec asks for,
    so memory stays bounded by the largest inspected table rather than by the
    dump.
    """

    def __init__(self, path: str):
        self.path = path

    def snapshot(self, retain: set[str]) -> Snapshot:
        counts: dict[str, int] = {}
        rows: dict[str, list[dict[str, object]]] = {t: [] for t in retain}
        columns: dict[str, list[str]] = {}
        tables: dict[str, DumpTable] = {}
        with _open_text(self.path) as fh:
            for stmt in iter_statements(fh):
                head = statement_head(stmt)
                if not head:
                    continue
                cm = _CREATE_RE.match(head)
                if cm:
                    t = parse_create_table(head)
                    tables[t.name] = t
                    columns[t.name] = list(t.columns)
                    counts.setdefault(t.name, 0)
                    continue
                im = _INSERT_RE.match(head)
                if not im:
                    continue
                table = im.group(1)
                explicit = im.group(2)
                if explicit:
                    names = [
                        c.strip().strip("`")
                        for c in explicit.strip("()").split(",")
                        if c.strip()
                    ]
                elif table in tables:
                    names = tables[table].columns
                else:
                    raise DumpParseError(
                        f"INSERT INTO {table} before its CREATE TABLE and with no "
                        f"column list; column names cannot be resolved and a "
                        f"positional guess is exactly the hazard this tool exists to "
                        f"prevent"
                    )
                counts.setdefault(table, 0)
                want = table in retain
                for values in parse_values(head[im.end() :], table):
                    if len(values) != len(names):
                        raise DumpParseError(
                            f"{table}: row has {len(values)} values for "
                            f"{len(names)} columns; refusing to align by position"
                        )
                    counts[table] += 1
                    if want:
                        rows[table].append(dict(zip(names, values)))
        missing = {t for t in retain if t not in counts}
        return Snapshot(
            origin=f"dump:{os.path.basename(self.path)}",
            counts=counts,
            rows=rows,
            columns=columns,
            missing_tables=missing,
        )


class JsonlDirSource:
    """Reads the ETL's emitted output: <table>.jsonl, one JSON object per line."""

    def __init__(self, directory: str):
        self.directory = directory

    def snapshot(self, retain: set[str]) -> Snapshot:
        if not os.path.isdir(self.directory):
            raise ReconcileConfigError(f"output directory not found: {self.directory}")
        counts: dict[str, int] = {}
        rows: dict[str, list[dict[str, object]]] = {t: [] for t in retain}
        columns: dict[str, list[str]] = {}
        for entry in sorted(os.listdir(self.directory)):
            if not entry.endswith(".jsonl"):
                continue
            table = entry[: -len(".jsonl")]
            counts[table] = 0
            want = table in retain
            seen_cols: list[str] = []
            with open(self.directory + os.sep + entry, "rt", encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, 1):
                    if not line.strip():
                        continue
                    try:
                        obj = json.loads(line, parse_float=JsonFloat)
                    except ValueError as exc:
                        raise DumpParseError(
                            f"{entry}:{lineno}: output is not valid JSON: {exc}"
                        ) from exc
                    if not isinstance(obj, dict):
                        raise DumpParseError(
                            f"{entry}:{lineno}: expected one JSON object per line, got "
                            f"{type(obj).__name__}"
                        )
                    counts[table] += 1
                    if not seen_cols:
                        seen_cols = list(obj.keys())
                    if want:
                        rows[table].append(obj)
            columns[table] = seen_cols
        for t in retain:
            counts.setdefault(t, 0)
        return Snapshot(
            origin=f"output:{os.path.basename(os.path.abspath(self.directory))}",
            counts=counts,
            rows=rows,
            columns=columns,
        )


class MappingSource:
    """In-memory source, for tests and for callers that already hold rows.

    Accepts either plain dicts or model.Row objects.
    """

    def __init__(self, data: Mapping[str, Sequence[object]], origin: str = "memory"):
        self.data = data
        self.origin = origin

    def snapshot(self, retain: set[str]) -> Snapshot:
        counts = {t: len(v) for t, v in self.data.items()}
        rows: dict[str, list[dict[str, object]]] = {}
        columns: dict[str, list[str]] = {}
        for t in self.data:
            vals = [values_of(r) for r in self.data[t]]
            columns[t] = list(vals[0].keys()) if vals else []
            if t in retain:
                rows[t] = vals
        missing = {t for t in retain if t not in self.data}
        for t in retain:
            rows.setdefault(t, [])
            counts.setdefault(t, 0)
        return Snapshot(origin=self.origin, counts=counts, rows=rows,
                        columns=columns, missing_tables=missing)


def values_of(row: object) -> dict[str, object]:
    if isinstance(row, dict):
        return row
    if isinstance(row, Row):
        return dict(row.values)
    raise ReconcileConfigError(f"cannot read a row of type {type(row).__name__}")


# ==========================================================================
# Findings and report
# ==========================================================================


@dataclass(frozen=True)
class Finding:
    check: str
    issue: Issue

    def sort_key(self) -> tuple:
        return (
            self.check,
            self.issue.table or "",
            self.issue.column or "",
            _pk_key(self.issue.pk),
            self.issue.message,
        )

    def to_json(self) -> dict:
        return {
            "check": self.check,
            "severity": self.issue.severity,
            "table": self.issue.table,
            "column": self.issue.column,
            "pk": _pk_json(self.issue.pk),
            "message": self.issue.message,
        }


def _pk_key(pk: object) -> str:
    if pk is None:
        return ""
    if isinstance(pk, tuple):
        return "\x00".join(str(p) for p in pk)
    return str(pk)


def _pk_json(pk: object) -> object:
    if pk is None:
        return None
    if isinstance(pk, tuple):
        return [str(p) for p in pk]
    return str(pk)


def finding(
    check: str,
    severity: str,
    table: str,
    message: str,
    *,
    column: str | None = None,
    pk: object = None,
) -> Finding:
    return Finding(
        check=check,
        issue=Issue(
            severity=severity, table=table, column=column, pk=pk, message=message
        ),
    )


@dataclass
class Report:
    findings: list[Finding] = field(default_factory=list)
    checks: dict[str, dict] = field(default_factory=dict)
    run: dict = field(default_factory=dict)

    @property
    def error_count(self) -> int:
        return sum(1 for f in self.findings if f.issue.severity == ERROR)

    @property
    def warn_count(self) -> int:
        return sum(1 for f in self.findings if f.issue.severity == WARN)

    @property
    def ok(self) -> bool:
        return self.error_count == 0

    def add(self, f: Finding) -> None:
        self.findings.append(f)

    def sorted_findings(self) -> list[Finding]:
        return sorted(self.findings, key=Finding.sort_key)


CHECK_NAMES = (
    "row_counts",
    "player_identity",
    "currency",
    "encoding",
    "referential_integrity",
    "type_sanity",
)


# ==========================================================================
# Check 1 — row counts, against an expectation the rules derive.
# ==========================================================================


def check_row_counts(src: Snapshot, out: Snapshot, spec: ReconcileSpec, rep: Report) -> None:
    """Per table: source count, output count, and the count the carry-over rules
    say to expect.

    WHY the expectation is computed rather than compared: "the dropped table is
    empty" is only reassuring if something wrote down that it was meant to be
    empty. A table that vanished by accident and a table that was dropped on
    purpose look identical in the output.
    """
    check = "row_counts"
    excluded = set(spec.identity.exclusions)
    declared = {r.name for r in spec.tables}
    ignored = set(spec.ignore_source_tables)
    rows_out: list[dict] = []

    for name in sorted(src.missing_tables - ignored):
        # Severity matches `rules.check`, which calls the same fact a warning:
        # the carry-over policy legitimately knows more tables than any one
        # source box has (a feature that never shipped there). It becomes an
        # ERROR the moment the OUTPUT has rows for it, because rows that exist
        # on no source side came from nowhere.
        invented = out.counts.get(name, 0)
        rep.add(
            finding(
                check,
                ERROR if invented else WARN,
                name,
                "the spec needs this table's rows to check them, but the source "
                "contains no such table"
                + (f" — yet the output holds {invented} row(s) for it, which "
                   "exist on no source side"
                   if invented else
                   ". Either the spec names a table this box never had, or the "
                   "dump is incomplete (a dump taken without --routines "
                   "--triggers --events parses fine and is wrong). Nothing was "
                   "checked for it."),
            )
        )

    for name in sorted(set(src.counts) | set(out.counts) | declared):
        if name in ignored:
            continue
        rule = spec.rule(name)
        s = src.counts.get(name, 0)
        o = out.counts.get(name, 0)
        if rule is None:
            rep.add(
                finding(
                    check,
                    ERROR,
                    name,
                    f"table {name!r} appears in "
                    f"{'the source' if name in src.counts else ''}"
                    f"{' and ' if name in src.counts and name in out.counts else ''}"
                    f"{'the output' if name in out.counts else ''} but has no rule in "
                    f"the spec; every table must be explicitly carried, dropped, "
                    f"filtered or rebuilt",
                )
            )
            rows_out.append(
                {
                    "table": name,
                    "disposition": None,
                    "source": s,
                    "output": o,
                    "expected": None,
                    "delta": None,
                }
            )
            continue

        exclusion_loss = 0
        if rule.player_id_column and excluded:
            if name not in src.rows:
                rep.add(
                    finding(
                        check,
                        ERROR,
                        name,
                        f"rule names player_id_column={rule.player_id_column!r} but the "
                        f"table's rows were not retained, so the exclusion count "
                        f"cannot be derived",
                    )
                )
            else:
                exclusion_loss = sum(
                    1
                    for r in src.rows[name]
                    if _as_text(r.get(rule.player_id_column)) in excluded
                )

        if rule.disposition == DISP_DROP:
            expected = 0
        elif rule.disposition == DISP_REBUILD:
            expected = int(rule.expected_rows or 0)
        elif rule.disposition == DISP_FILTER:
            if name not in src.rows:
                rep.add(
                    finding(
                        check,
                        ERROR,
                        name,
                        "FILTER rule needs the table's rows retained to derive the "
                        "expected count",
                    )
                )
                expected = -1
            else:
                assert rule.keep is not None
                expected = sum(
                    1
                    for r in src.rows[name]
                    if rule.keep(r)
                    and not (
                        rule.player_id_column
                        and _as_text(r.get(rule.player_id_column)) in excluded
                    )
                )
        else:  # DISP_CARRY
            expected = s - exclusion_loss

        rows_out.append(
            {
                "table": name,
                "disposition": rule.disposition,
                "source": s,
                "output": o,
                "expected": expected,
                "delta": o - expected,
                "reason": rule.reason or None,
            }
        )
        if expected >= 0 and o != expected:
            rep.add(
                finding(
                    check,
                    ERROR,
                    name,
                    f"row count {o} but the {rule.disposition} rule expects {expected} "
                    f"(source {s}"
                    + (f", {exclusion_loss} excluded player rows" if exclusion_loss else "")
                    + f"); delta {o - expected:+d}",
                )
            )

    rep.checks[check] = {"tables": rows_out}


def _as_text(v: object) -> str | None:
    if v is None:
        return None
    return str(v)


# ==========================================================================
# Check 2 — player identity, one id at a time.
# ==========================================================================


def check_player_identity(
    src: Snapshot, out: Snapshot, spec: ReconcileSpec, rep: Report
) -> None:
    """Every distinct player id in the source appears exactly once in the output,
    or is on the documented exclusion list.

    WHY it reports ids individually: one player lost and one player duplicated
    cancel out perfectly in a count, and that is not a hypothetical — it is what
    a keying bug looks like from the outside.
    """
    check = "player_identity"
    table, column = spec.identity.table, spec.identity.column
    target = spec.target_column(table, column)
    src_rows = src.rows.get(table)
    out_rows = out.rows.get(table)
    if src_rows is None or out_rows is None:
        rep.add(
            finding(
                check,
                ERROR,
                table,
                "identity table rows were not retained on both sides",
                column=column,
            )
        )
        rep.checks[check] = {"status": "not_run"}
        return

    src_counts: dict[str, int] = {}
    for r in src_rows:
        if column not in r:
            rep.add(
                finding(
                    check, ERROR, table, f"source row has no {column!r} column",
                    column=column,
                )
            )
            continue
        pid = _as_text(r[column])
        if pid is None:
            rep.add(
                finding(check, ERROR, table, "source row has a NULL player id", column=column)
            )
            continue
        src_counts[pid] = src_counts.get(pid, 0) + 1

    out_counts: dict[str, int] = {}
    for r in out_rows:
        if target not in r:
            rep.add(
                finding(
                    check, ERROR, table, f"output row has no {target!r} column",
                    column=target,
                )
            )
            continue
        pid = _as_text(r[target])
        if pid is None:
            rep.add(
                finding(check, ERROR, table, "output row has a NULL player id", column=target)
            )
            continue
        out_counts[pid] = out_counts.get(pid, 0) + 1

    exclusions = spec.identity.exclusions
    lost: list[str] = []
    duplicated: list[str] = []
    invented: list[str] = []
    excluded_present: list[str] = []
    dup_in_source: list[str] = []

    for pid in sorted(src_counts):
        if src_counts[pid] > 1:
            dup_in_source.append(pid)
            rep.add(
                finding(
                    check,
                    ERROR,
                    table,
                    f"player id appears {src_counts[pid]} times in the SOURCE; the "
                    f"uniqueness this check relies on does not hold upstream",
                    column=column,
                    pk=pid,
                )
            )
        n = out_counts.get(pid, 0)
        if pid in exclusions:
            if n:
                excluded_present.append(pid)
                rep.add(
                    finding(
                        check,
                        ERROR,
                        table,
                        f"player id is on the exclusion list ({exclusions[pid]}) but "
                        f"appears {n} time(s) in the output",
                        column=column,
                        pk=pid,
                    )
                )
            continue
        if n == 0:
            lost.append(pid)
            rep.add(
                finding(
                    check,
                    ERROR,
                    table,
                    "player id present in the source is absent from the output and is "
                    "not on the exclusion list",
                    column=column,
                    pk=pid,
                )
            )
        elif n > 1:
            duplicated.append(pid)
            rep.add(
                finding(
                    check,
                    ERROR,
                    table,
                    f"player id appears {n} times in the output; expected exactly once",
                    column=column,
                    pk=pid,
                )
            )

    for pid in sorted(out_counts):
        if pid not in src_counts:
            invented.append(pid)
            rep.add(
                finding(
                    check,
                    ERROR,
                    table,
                    "player id appears in the output but exists nowhere in the source",
                    column=target,
                    pk=pid,
                )
            )

    rep.checks[check] = {
        "table": table,
        "column": column,
        "source_distinct": len(src_counts),
        "output_distinct": len(out_counts),
        "excluded_declared": sorted(exclusions),
        "lost": lost,
        "duplicated": duplicated,
        "invented": invented,
        "excluded_but_present": excluded_present,
        "duplicated_in_source": dup_in_source,
    }


# ==========================================================================
# Check 3 — currency conservation, exact integers.
# ==========================================================================


def _pk_of(rule: TableRule, row: Mapping[str, object], spec: ReconcileSpec, *, output: bool) -> object:
    cols = rule.primary_key
    if not cols:
        raise ReconcileConfigError(
            f"table {rule.name!r} needs primary_key=(...) in its TableRule for "
            f"value-level checks; pairing rows by position is the bug that moves "
            f"every player's money one row over"
        )
    keys = []
    for c in cols:
        name = spec.target_column(rule.name, c) if output else c
        if name not in row:
            return None
        keys.append(_as_text(row[name]))
    return keys[0] if len(keys) == 1 else tuple(keys)


def _recompute_credits(comp: CompensationRule, src: Snapshot,
                       rep: Report, check: str) -> dict[str, int]:
    """uid -> total compensation credit, valued from the SOURCE rows.

    A source table that is retained but empty contributes nothing, which is
    correct and is also how a dump that simply has no `suites` yet behaves. A
    source table that was never retained is NOT nothing — it would silently
    reduce every affected player's expected balance and turn a real shortfall
    into a clean bill — so it is reported.
    """
    credits: dict[str, int] = {}
    for table, source_name in sorted(comp.sources.items()):
        rows = src.rows.get(table)
        if rows is None:
            rep.add(finding(
                check, ERROR, table,
                "compensation source was not retained, so the credits paid out of it "
                "cannot be re-derived; the expected balance of every player it paid "
                "would be short by exactly the amount they were paid",
                column=None))
            continue
        for row in rows:
            owner = comp.owner_of(source_name, row)
            if owner is None:
                continue                    # unowned row: the ETL pays nobody either
            uid = _as_text(owner)
            if not uid:
                continue
            credits[uid] = credits.get(uid, 0) + int(comp.valuer(source_name, row))
    return credits


def check_currency(src: Snapshot, out: Snapshot, spec: ReconcileSpec, rep: Report) -> None:
    """Totals and per-row values for every currency column, as exact integers.

    WHY both totals and per-row: a total is what you would report to a player,
    but a total is also conserved by a bug that gives A's balance to B. The
    per-row pass makes that visible; the total pass makes drift visible even
    where per-row pairing is impossible.
    """
    check = "currency"
    results: list[dict] = []

    for cc in spec.currency:
        rule = spec.rule(cc.table)
        if rule is None:
            rep.add(
                finding(check, ERROR, cc.table, "currency column on a table with no rule",
                        column=cc.column)
            )
            continue
        src_rows = src.rows.get(cc.table)
        out_rows = out.rows.get(cc.table)
        if src_rows is None or out_rows is None:
            rep.add(
                finding(check, ERROR, cc.table, "rows not retained on both sides",
                        column=cc.column)
            )
            continue

        scale = cc.scale if cc.kind == "decimal" else 0

        def read(value: object, pk: object, column: str) -> int | None:
            try:
                if cc.kind == "decimal":
                    return decimal_to_units(value, scale, table=cc.table, column=column, pk=pk)
                return to_exact_int(value, table=cc.table, column=column, pk=pk)
            except ValueError as exc:
                rep.add(finding(check, ERROR, cc.table, str(exc), column=column, pk=pk))
                return None

        src_units: dict[object, int] = {}
        src_total = 0
        src_unreadable = 0
        for r in src_rows:
            pk = _pk_of(rule, r, spec, output=False)
            if cc.column not in r:
                rep.add(
                    finding(check, ERROR, cc.table, "column missing from the source row",
                            column=cc.column, pk=pk)
                )
                continue
            v = r[cc.column]
            if v is None:
                rep.add(
                    finding(check, ERROR, cc.table, "NULL in a currency column",
                            column=cc.column, pk=pk)
                )
                src_unreadable += 1
                continue
            u = read(v, pk, cc.column)
            if u is None:
                src_unreadable += 1
                continue
            src_total += u
            if pk is not None:
                src_units[pk] = u

        out_units: dict[object, int] = {}
        out_total = 0
        for r in out_rows:
            pk = _pk_of(rule, r, spec, output=True)
            if cc.target not in r:
                rep.add(
                    finding(check, ERROR, cc.table, "column missing from the output row",
                            column=cc.target, pk=pk)
                )
                continue
            v = r[cc.target]
            if v is None:
                rep.add(
                    finding(check, ERROR, cc.table, "NULL in a currency column",
                            column=cc.target, pk=pk)
                )
                continue
            u = read(v, pk, cc.target)
            if u is None:
                continue
            out_total += u
            if pk is not None:
                out_units[pk] = u

        excluded = set(spec.identity.exclusions)
        pid_col = rule.player_id_column

        # Compensation, re-derived from the source dump rather than trusted. Only
        # the ONE column credits land in gets this treatment; every other currency
        # column still reconciles against source x scale alone, which is what keeps
        # the check strict everywhere it can be.
        comp = spec.compensation
        credits: dict[str, int] = {}
        if (comp is not None and cc.table == comp.credit_table
                and cc.column == comp.credit_column):
            credits = _recompute_credits(comp, src, rep, check)

        expected_total = 0
        expected_units: dict[object, int] = {}
        for r in src_rows:
            pk = _pk_of(rule, r, spec, output=False)
            if pid_col and _as_text(r.get(pid_col)) in excluded:
                continue
            if pk is None or pk not in src_units:
                continue
            credit = 0
            if credits and comp is not None:
                credit = credits.get(_as_text(r.get(comp.credit_owner_column)) or "", 0)
            if credit and comp.order == "before_scaling":
                e = cc.scaling.apply(src_units[pk] + credit)
            else:
                e = cc.scaling.apply(src_units[pk]) + credit
            expected_units[pk] = e
            expected_total += e

        deltas: list[dict] = []
        for pk in sorted(expected_units, key=_pk_key):
            got = out_units.get(pk)
            want = expected_units[pk]
            if got is None:
                deltas.append(
                    {"pk": _pk_json(pk), "expected": units_to_text(want, scale),
                     "output": None, "delta": None}
                )
                rep.add(
                    finding(
                        check,
                        ERROR,
                        cc.table,
                        f"row carries {units_to_text(want, scale)} in the source but has "
                        f"no readable value in the output",
                        column=cc.column,
                        pk=pk,
                    )
                )
            elif got != want:
                deltas.append(
                    {
                        "pk": _pk_json(pk),
                        "expected": units_to_text(want, scale),
                        "output": units_to_text(got, scale),
                        "delta": units_to_text(got - want, scale),
                    }
                )
                rep.add(
                    finding(
                        check,
                        ERROR,
                        cc.table,
                        f"expected {units_to_text(want, scale)} but output holds "
                        f"{units_to_text(got, scale)} (delta "
                        f"{units_to_text(got - want, scale)})",
                        column=cc.column,
                        pk=pk,
                    )
                )
        for pk in sorted(out_units, key=_pk_key):
            if pk not in expected_units:
                deltas.append(
                    {"pk": _pk_json(pk), "expected": None,
                     "output": units_to_text(out_units[pk], scale), "delta": None}
                )
                rep.add(
                    finding(
                        check,
                        ERROR,
                        cc.table,
                        f"output row holds {units_to_text(out_units[pk], scale)} but has "
                        f"no corresponding source row",
                        column=cc.target,
                        pk=pk,
                    )
                )

        if out_total != expected_total:
            rep.add(
                finding(
                    check,
                    ERROR,
                    cc.table,
                    f"total is {units_to_text(out_total, scale)} but the rules expect "
                    f"{units_to_text(expected_total, scale)} "
                    f"(source {units_to_text(src_total, scale)}, scaling "
                    f"{cc.scaling.numerator}/{cc.scaling.denominator} {cc.scaling.rounding}); "
                    f"delta {units_to_text(out_total - expected_total, scale)}",
                    column=cc.column,
                )
            )

        results.append(
            {
                "table": cc.table,
                "column": cc.column,
                "output_column": cc.target,
                "kind": cc.kind,
                "scale": scale,
                "scaling": f"{cc.scaling.numerator}/{cc.scaling.denominator}:{cc.scaling.rounding}",
                "source_total": units_to_text(src_total, scale),
                "expected_total": units_to_text(expected_total, scale),
                "output_total": units_to_text(out_total, scale),
                "total_delta": units_to_text(out_total - expected_total, scale),
                "unreadable_source_values": src_unreadable,
                "row_deltas": deltas,
            }
        )

    rep.checks[check] = {"columns": results}


# ==========================================================================
# Check 4 — encoding round-trip.
# ==========================================================================


def check_encoding(src: Snapshot, out: Snapshot, spec: ReconcileSpec, rep: Report) -> None:
    """Every transcoded value must decode back to the same structure.

    Property columns are checked exhaustively. Sampling is available for bulk
    columns, but it is a deliberate, declared downgrade: the columns whose
    decode failures have historically destroyed stored player property do not
    get to be sampled, because the one row that fails is exactly the row a
    sample misses.
    """
    check = "encoding"
    results: list[dict] = []
    reference = reference_decoder() if spec.cross_check_decoder else None

    for ec in spec.encoded:
        rule = spec.rule(ec.table)
        if rule is None:
            rep.add(finding(check, ERROR, ec.table, "encoded column on a table with no rule",
                            column=ec.column))
            continue
        src_rows = src.rows.get(ec.table)
        out_rows = out.rows.get(ec.table)
        if src_rows is None or out_rows is None:
            rep.add(finding(check, ERROR, ec.table, "rows not retained on both sides",
                            column=ec.column))
            continue

        out_index: dict[object, dict[str, object]] = {}
        for r in out_rows:
            pk = _pk_of(rule, r, spec, output=True)
            if pk is not None:
                out_index[pk] = r

        excluded = set(spec.identity.exclusions)
        pid_col = rule.player_id_column
        checked = skipped = 0
        empties = 0
        mismatches = 0
        form_warnings = 0
        divergences = 0

        ordered = sorted(src_rows, key=lambda r: _pk_key(_pk_of(rule, r, spec, output=False)))
        for idx, r in enumerate(ordered):
            pk = _pk_of(rule, r, spec, output=False)
            if pid_col and _as_text(r.get(pid_col)) in excluded:
                continue
            if not ec.exhaustive and idx % ec.sample_every:
                skipped += 1
                continue
            if ec.column not in r:
                rep.add(finding(check, ERROR, ec.table, "column missing from the source row",
                                column=ec.column, pk=pk))
                continue
            target_row = out_index.get(pk)
            if target_row is None:
                # absence is the row-count/identity check's finding, not this one
                skipped += 1
                continue
            if ec.target not in target_row:
                rep.add(
                    finding(check, ERROR, ec.table,
                            f"output row has no {ec.target!r} column to compare against",
                            column=ec.target, pk=pk)
                )
                continue
            checked += 1
            source_value = r[ec.column]
            emitted = target_row[ec.target]

            if source_value is None:
                if emitted is not None:
                    mismatches += 1
                    rep.add(
                        finding(check, ERROR, ec.table,
                                f"source is NULL but the output holds {emitted!r}",
                                column=ec.column, pk=pk)
                    )
                continue

            text = source_value if isinstance(source_value, str) else str(source_value)
            if text.strip() == "":
                empties += 1
                if ec.empty_policy is None:
                    rep.add(
                        finding(
                            check,
                            ERROR,
                            ec.table,
                            "source value is empty and the spec declares no "
                            "empty_policy; an empty legacy value and a decode failure "
                            "are not the same thing and must not be guessed apart",
                            column=ec.column,
                            pk=pk,
                        )
                    )
                    continue
                want: object = None if ec.empty_policy == "null" else []
                if not structurally_equal(emitted, want):
                    mismatches += 1
                    rep.add(
                        finding(check, ERROR, ec.table,
                                f"empty source value should become {want!r} under the "
                                f"declared empty_policy={ec.empty_policy!r} but the "
                                f"output holds {emitted!r}",
                                column=ec.column, pk=pk)
                    )
                continue

            try:
                decoded = decode_legacy_array(text)
            except EncodingError as exc:
                mismatches += 1
                rep.add(
                    finding(
                        check,
                        ERROR,
                        ec.table,
                        f"source value cannot be decoded ({exc}), so the transcode "
                        f"cannot be proven correct for this row",
                        column=ec.column,
                        pk=pk,
                    )
                )
                continue

            if reference is not None:
                divergence = _cross_check(reference, text, decoded, ec, pk)
                if divergence is not None:
                    divergences += 1
                    rep.add(
                        finding(check, ERROR, ec.table, divergence, column=ec.column, pk=pk)
                    )

            severity, detail = structure_diff(decoded, emitted)
            if severity == ERROR:
                mismatches += 1
                rep.add(
                    finding(
                        check,
                        ERROR,
                        ec.table,
                        f"round-trip mismatch at {detail}; source decodes to "
                        f"{_short(decoded)} but the output holds {_short(emitted)}",
                        column=ec.column,
                        pk=pk,
                    )
                )
            elif severity == WARN:
                form_warnings += 1
                rep.add(
                    finding(check, WARN, ec.table, detail, column=ec.column, pk=pk)
                )

        results.append(
            {
                "table": ec.table,
                "column": ec.column,
                "output_column": ec.target,
                "mode": "exhaustive" if ec.exhaustive else f"every {ec.sample_every}",
                "cross_checked": reference is not None,
                "checked": checked,
                "skipped": skipped,
                "empty_values": empties,
                "mismatches": mismatches,
                "numeric_form_warnings": form_warnings,
                "decoder_divergences": divergences,
            }
        )

    rep.checks[check] = {"columns": results}


def _cross_check(
    reference: Callable, text: str, decoded: object, ec: EncodingColumn, pk: object
) -> str | None:
    """Compare this module's decode against the transform's own.

    Returns a message when they disagree, None when they agree. A disagreement
    means one of the two decoders is wrong, and until that is settled every
    verdict in this check about that column is untrustworthy — so it is reported
    rather than resolved in favour of either side.
    """
    try:
        other = reference(text, table=ec.table, column=ec.column, pk=pk)
    except TransformError as exc:
        return (
            f"decoder divergence: this module decoded the value but the transform's "
            f"decoder refused it ({exc.issue.message}); one of the two is wrong"
        )
    except (TypeError, ValueError) as exc:
        return (
            f"decoder divergence: the transform's decoder raised {type(exc).__name__}: "
            f"{exc}"
        )
    severity, detail = structure_diff(decoded, other)
    if severity == ERROR:
        return (
            f"decoder divergence at {detail}: this module decodes the source to "
            f"{_short(decoded)}, the transform's decoder to {_short(other)}"
        )
    return None


def _short(v: object, limit: int = 160) -> str:
    try:
        s = json.dumps(v, default=str, sort_keys=True)
    except (TypeError, ValueError):
        s = repr(v)
    return s if len(s) <= limit else s[: limit - 3] + "..."


# ==========================================================================
# Check 5 — referential integrity.
# ==========================================================================


def check_referential_integrity(
    src: Snapshot, out: Snapshot, spec: ReconcileSpec, rep: Report
) -> None:
    """No output row may point at a parent that is not there.

    WHY it matters specifically here: the map change drops whole parent tables.
    A child row that survives its parent is not a constraint violation the target
    engine will necessarily catch — it is a row that renders as a house nobody
    owns or a vehicle keyed to a gang that no longer exists.
    """
    check = "referential_integrity"
    results: list[dict] = []

    for fk in spec.foreign_keys:
        child_rows = out.rows.get(fk.child_table)
        parent_rows = out.rows.get(fk.parent_table)
        parent_rule = spec.rule(fk.parent_table)
        if child_rows is None:
            rep.add(
                finding(check, ERROR, fk.child_table, "child rows not retained",
                        column=fk.child_column)
            )
            continue
        parent_dropped = parent_rule is not None and parent_rule.disposition == DISP_DROP
        parent_col = spec.target_column(fk.parent_table, fk.parent_column)
        keys: set[str] = set()
        if parent_rows is not None:
            for r in parent_rows:
                v = _as_text(r.get(parent_col))
                if v is not None:
                    keys.add(v)

        child_col = spec.target_column(fk.child_table, fk.child_column)
        child_rule = spec.rule(fk.child_table)
        orphans: list[dict] = []
        null_violations = 0
        for r in child_rows:
            # a log-style child table may legitimately have no primary key; the
            # orphan is still reported, just without a row name
            pk = (
                _pk_of(child_rule, r, spec, output=True)
                if child_rule and child_rule.primary_key
                else None
            )
            if child_col not in r:
                rep.add(
                    finding(check, ERROR, fk.child_table,
                            f"output row has no {child_col!r} column",
                            column=child_col, pk=pk)
                )
                continue
            v = r[child_col]
            if v is None:
                if not fk.nullable:
                    null_violations += 1
                    rep.add(
                        finding(check, ERROR, fk.child_table,
                                f"NULL reference to {fk.parent_table}.{fk.parent_column}, "
                                f"which the spec declares NOT NULL",
                                column=child_col, pk=pk)
                    )
                continue
            key = _as_text(v)
            if key not in keys:
                orphans.append({"pk": _pk_json(pk), "value": key})
                rep.add(
                    finding(
                        check,
                        ERROR,
                        fk.child_table,
                        f"references {fk.parent_table}.{fk.parent_column}={key!r}, which "
                        + (
                            f"is not in the output because {fk.parent_table} was dropped "
                            f"({parent_rule.reason if parent_rule else ''})"
                            if parent_dropped
                            else "does not exist in the output"
                        ),
                        column=child_col,
                        pk=pk,
                    )
                )

        results.append(
            {
                "child": f"{fk.child_table}.{fk.child_column}",
                "parent": f"{fk.parent_table}.{fk.parent_column}",
                "parent_dropped": parent_dropped,
                "parent_keys": len(keys),
                "orphans": orphans,
                "null_violations": null_violations,
            }
        )

    rep.checks[check] = {"references": results}


# ==========================================================================
# Check 6 — type sanity.
# ==========================================================================


def check_type_sanity(src: Snapshot, out: Snapshot, spec: ReconcileSpec, rep: Report) -> None:
    """Nothing exact became approximate, nothing present became absent.

    Two distinct failures, both silent:
      - an exact integer emitted as a float, which is how a balance above the
        float-exact range loses its last digits into a column that accepts it
        without complaint;
      - a non-null arriving as null, which is what a transform does when it
        cannot produce a value and something downstream substitutes a plausible
        default.
    A column missing from the output is a third: legitimate only when the spec
    declares it dropped, and an error otherwise.
    """
    check = "type_sanity"
    summary: list[dict] = []
    skipped: list[dict] = []

    for rule in spec.tables:
        if rule.disposition == DISP_DROP:
            continue
        src_rows = src.rows.get(rule.name)
        out_rows = out.rows.get(rule.name)
        # A check that did not run must be VISIBLE. Silence here reads exactly
        # like a pass: the table carried its rows, nobody looked at the values,
        # and the report said nothing at all about it.
        if not rule.primary_key:
            skipped.append({"table": rule.name, "reason": "no primary_key in the rule"})
            rep.add(
                finding(
                    check,
                    WARN,
                    rule.name,
                    "value-level checks were SKIPPED for this carried table: its rule "
                    "declares no primary_key, so rows cannot be paired by name and "
                    "pairing them by position is the bug this tool exists to prevent. "
                    "Nothing here has verified that its values survived.",
                )
            )
            continue
        if src_rows is None or out_rows is None:
            side = "source" if src_rows is None else "output"
            skipped.append({"table": rule.name, "reason": f"rows not retained ({side})"})
            rep.add(
                finding(
                    check,
                    WARN,
                    rule.name,
                    f"value-level checks were SKIPPED for this carried table: its rows "
                    f"were not retained on the {side} side, so only its row count was "
                    f"checked",
                )
            )
            continue

        src_index: dict[object, dict[str, object]] = {}
        for r in src_rows:
            pk = _pk_of(rule, r, spec, output=False)
            if pk is not None:
                src_index[pk] = r

        floats = nulled = missing_cols = 0
        reported_missing: set[str] = set()
        for r in out_rows:
            pk = _pk_of(rule, r, spec, output=True)
            source = src_index.get(pk)
            if source is None:
                continue
            for col, sval in source.items():
                target = spec.target_column(rule.name, col)
                if target not in r:
                    if (rule.name, col) in spec.dropped_columns:
                        continue
                    if target not in reported_missing:
                        reported_missing.add(target)
                        missing_cols += 1
                        rep.add(
                            finding(
                                check,
                                ERROR,
                                rule.name,
                                f"column is present in the source but absent from the "
                                f"output, and the spec does not declare it dropped",
                                column=col,
                                pk=pk,
                            )
                        )
                    continue
                oval = r[target]
                if sval is not None and oval is None:
                    if (rule.name, col) in spec.allowed_null_columns:
                        continue
                    nulled += 1
                    rep.add(
                        finding(
                            check,
                            ERROR,
                            rule.name,
                            f"non-null source value {_short(sval, 60)} became NULL in the "
                            f"output, and the spec does not allow this column to be "
                            f"nulled",
                            column=col,
                            pk=pk,
                        )
                    )
                    continue
                if isinstance(sval, int) and not isinstance(sval, bool):
                    if isinstance(oval, JsonFloat):
                        floats += 1
                        rep.add(
                            finding(
                                check,
                                ERROR,
                                rule.name,
                                f"exact integer {sval} in the source was emitted as the "
                                f"float literal {str(oval)}",
                                column=col,
                                pk=pk,
                            )
                        )
                    elif isinstance(oval, float):
                        floats += 1
                        rep.add(
                            finding(
                                check,
                                ERROR,
                                rule.name,
                                f"exact integer {sval} in the source is a Python float "
                                f"{oval!r} in the output",
                                column=col,
                                pk=pk,
                            )
                        )
                if sval is None and oval is not None:
                    rep.add(
                        finding(
                            check,
                            WARN,
                            rule.name,
                            f"source value was NULL and the output holds "
                            f"{_short(oval, 60)}; confirm this is a declared default",
                            column=col,
                            pk=pk,
                        )
                    )

        summary.append(
            {
                "table": rule.name,
                "paired_rows": sum(
                    1
                    for r in out_rows
                    if _pk_of(rule, r, spec, output=True) in src_index
                ),
                "integers_become_floats": floats,
                "non_null_become_null": nulled,
                "undeclared_missing_columns": missing_cols,
            }
        )

    rep.checks[check] = {"tables": summary, "skipped": skipped}


# ==========================================================================
# Driver
# ==========================================================================

CHECKS: tuple[tuple[str, Callable], ...] = (
    ("row_counts", check_row_counts),
    ("player_identity", check_player_identity),
    ("currency", check_currency),
    ("encoding", check_encoding),
    ("referential_integrity", check_referential_integrity),
    ("type_sanity", check_type_sanity),
)


def reconcile(source, output, spec: ReconcileSpec) -> Report:
    """Run every check and return the report. Raises only on setup errors; data
    problems are findings."""
    retain = spec.retained_tables()
    src = source.snapshot(retain)
    out = output.snapshot(retain)
    rep = Report()
    rep.run = {
        "tool": TOOL_NAME,
        "report_format": REPORT_FORMAT_VERSION,
        "source": src.origin,
        "output": out.origin,
    }
    for name, fn in CHECKS:
        fn(src, out, spec, rep)
        rep.checks.setdefault(name, {})
    return rep


def render_json(rep: Report, *, omit_run_meta: bool = False) -> str:
    """Stable, sorted, float-free JSON.

    WHY: two rehearsals must be diffable. Any nondeterminism — dict order, a
    timestamp, a float's repr — turns a one-line regression into a whole-file
    diff, and a whole-file diff gets skimmed.
    """
    doc = {
        "report_format": REPORT_FORMAT_VERSION,
        "result": "pass" if rep.ok else "fail",
        "counts": {"errors": rep.error_count, "warnings": rep.warn_count},
        "checks": {
            name: rep.checks.get(name, {}) for name in sorted(rep.checks)
        },
        "findings": [f.to_json() for f in rep.sorted_findings()],
    }
    if not omit_run_meta:
        doc["run"] = dict(rep.run)
    return json.dumps(doc, indent=2, sort_keys=True, default=str) + "\n"


def render_human(rep: Report, *, max_listed: int = 40) -> str:
    lines: list[str] = []
    lines.append(f"{TOOL_NAME}: {rep.run.get('source', '?')} -> {rep.run.get('output', '?')}")
    lines.append("")
    per_check: dict[str, list[Finding]] = {name: [] for name, _ in CHECKS}
    for f in rep.sorted_findings():
        per_check.setdefault(f.check, []).append(f)
    for name, _ in CHECKS:
        fs = per_check.get(name, [])
        errs = sum(1 for f in fs if f.issue.severity == ERROR)
        warns = len(fs) - errs
        status = "FAIL" if errs else ("warn" if warns else "ok")
        lines.append(f"  {name:<24} {status:<5} errors={errs} warnings={warns}")

    counts = rep.checks.get("row_counts", {}).get("tables", [])
    if counts:
        lines.append("")
        lines.append("  table                          source    output  expected   delta")
        for row in counts:
            lines.append(
                "  {:<28} {:>8} {:>9} {:>9} {:>7}".format(
                    row["table"][:28],
                    row["source"],
                    row["output"],
                    "-" if row["expected"] is None else row["expected"],
                    "-" if row["delta"] is None else f"{row['delta']:+d}",
                )
            )

    money = rep.checks.get("currency", {}).get("columns", [])
    if money:
        lines.append("")
        for m in money:
            lines.append(
                f"  {m['table']}.{m['column']}: source {m['source_total']} -> expected "
                f"{m['expected_total']}, output {m['output_total']} "
                f"(delta {m['total_delta']}, scaling {m['scaling']})"
            )

    sorted_f = rep.sorted_findings()
    if sorted_f:
        lines.append("")
        lines.append(f"  findings ({len(sorted_f)}):")
        for f in sorted_f[:max_listed]:
            where = f.issue.table
            if f.issue.column:
                where += "." + f.issue.column
            if f.issue.pk is not None:
                where += f" pk={_pk_key(f.issue.pk)}"
            lines.append(f"    [{f.issue.severity}] {f.check} {where}: {f.issue.message}")
        if len(sorted_f) > max_listed:
            lines.append(f"    ... {len(sorted_f) - max_listed} more (see the JSON report)")

    lines.append("")
    lines.append(
        f"  RESULT: {'PASS' if rep.ok else 'FAIL'}  "
        f"errors={rep.error_count} warnings={rep.warn_count}"
    )
    return "\n".join(lines)


def main(argv: Sequence[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="reconcile",
        description="Prove the one-time carry-over was lossless. Exits non-zero on any "
        "error-severity finding.",
    )
    ap.add_argument("--dump", required=True, help="source mysqldump file (.sql or .sql.gz)")
    ap.add_argument("--output", required=True, help="directory of <table>.jsonl emitted by the ETL")
    ap.add_argument("--spec", required=True, help="Python file defining RECONCILE_SPEC")
    ap.add_argument("--report", help="write the JSON report here (default: stdout)")
    ap.add_argument(
        "--omit-run-meta",
        action="store_true",
        help="leave provenance out of the report so two runs compare byte for byte",
    )
    ap.add_argument("--max-listed", type=int, default=40, help="findings shown in the summary")
    ap.add_argument("--quiet", action="store_true", help="suppress the human summary")
    args = ap.parse_args(argv)

    try:
        spec = spec_from_module(args.spec)
        rep = reconcile(DumpSource(args.dump), JsonlDirSource(args.output), spec)
    except (ReconcileConfigError, DumpParseError, OSError) as exc:
        sys.stderr.write(f"{TOOL_NAME}: {type(exc).__name__}: {exc}\n")
        return 2

    doc = render_json(rep, omit_run_meta=args.omit_run_meta)
    if args.report:
        with open(args.report, "wt", encoding="utf-8") as fh:
            fh.write(doc)
    else:
        sys.stdout.write(doc)
    if not args.quiet:
        sys.stderr.write(render_human(rep, max_listed=args.max_listed) + "\n")
    return 0 if rep.ok else 1


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
