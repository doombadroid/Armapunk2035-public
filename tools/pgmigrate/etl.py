"""The pgmigrate orchestrator: dump in, PostgreSQL COPY files out, counted.

Purpose:
    Run the one-time carry-over end to end. Read the source DDL (`dump`),
    translate it (`ddl`), validate the carry-over policy (`rules`), stream
    every row, apply that policy, transcode the bespoke array codec to JSON
    (`mres`), emit PostgreSQL `COPY` data plus a schema file — and then prove
    the result against the source before declaring success.

WHY THIS EXISTS:
    The failure this whole tool is built around is a migration that reports
    success. Live MariaDB -> new PostgreSQL happens once, at open beta, in one
    direction, with no reverse path: from the first post-migration login,
    going back would mean a reverse transform nobody has written. So the
    orchestrator's real job is not moving rows — that part is easy — it is
    refusing to finish when it cannot account for what it moved.

    Seven specific refusals, each with a documented way of going wrong:

    1. Unreconciled counts. Rows in must equal rows out plus rows deliberately
       dropped, per table — INCLUDING the tables that do not carry, which are
       counted in their own pass so "the policy dropped 12,431 houses" cannot
       read the same as "the parser never saw this table". Currency totals must
       match exactly per column. On any mismatch this writes the report, leaves
       the output unfinished and exits non-zero. Nothing is promoted from
       `.partial`.
    2. Undecided tables and undecided policy — two separate refusals with two
       separate waivers. The map changes, so anything anchored to the old map
       cannot carry: worldspace, positions, vehicle restart state, turf,
       cartels, capture points. A table nobody has decided is `DECIDE` and needs
       `--allow-decide`; the four global decisions (compensation policy and
       order, balance scale, freeze) need `--allow-undecided-policy`. One flag
       for both meant a switch named for the first silently granted the second.
       A source table with no policy entry at all is always an error: that is
       the silent-drop hole.
    3. Currency through a float. Every currency value is carried as text,
       `int` or `Decimal` and guarded at each stage boundary — `model.Money`
       raises on `float()` rather than rounding. A balance above 2**53 that
       passed through a double would be wrong by an amount no reconciliation
       on rounded numbers could see, which is why the guard is on the type and
       not on the totals.
    4. The old encoding leaking through. Transcoding happens here, once, via
       `mres.to_json`, which refuses a value it cannot parse instead of
       returning an empty-ish one. Treating an unreadable inventory as empty
       is the exact mechanism that has destroyed stored player property
       before.
    5. Position-based column matching. Every value is matched by name from the
       dump through the policy to the COPY header. A one-column slip in this
       schema moves every player's money.
    6. A COPY header the target cannot take. The translated schema is built
       from the same policy this file transforms rows with — the boolean
       allowlist, the jsonb transcodes, the target-only columns — and then every
       column in every COPY header is checked against the schema that was
       actually emitted. Without that check the run reports success on output
       `psql` refuses at its first line.
    7. Compensation that goes nowhere. Property the map change destroys is
       valued from the rows before they are dropped, credited to the owning
       player, and reconciled per source: what was valued must equal what was
       credited must equal what was applied. A credit for a player with no
       account row fails the run rather than evaporating.

    Output is `COPY` data plus a schema file rather than one large INSERT
    script: an order of magnitude faster to load, and diffable, which matters
    because the rehearsal loop is "dump, transform, load, inspect, repeat".
    A parallel `jsonl/` tree is written for `reconcile.py`, the independent
    auditor, which re-reads the source dump with its own parser — a shared
    parser would cancel its own bugs out.

    The run is idempotent: same dump in, byte-identical files out. Nothing
    written here contains a timestamp, precisely so two rehearsals can be
    diffed and show only what the rules changed.

Usage:
    PYTHONPATH=tools python3 -m pgmigrate.etl \\
        --dump live.sql --out ./pgout --report report.json

    # rehearsal, before the product decisions are made:
    ... --allow-decide --allow-undecided-policy --limit 1000

    # optional, and the only place a third-party package is touched:
    ... --load "postgresql:///pgm_scratch"

    Exit codes: 0 success · 1 usage or I/O · 2 transform or reconciliation
    failure · 3 unresolved tables without --allow-decide.

STATUS:
    No live dump exists in this repository, so this has never been run against
    real data. The reconciliation is what will tell you it is wrong the first
    time it meets one; read the report, not the exit code.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import os
import re
import sys
from dataclasses import dataclass, field
from decimal import Decimal, localcontext
from typing import Iterable

if __package__ in (None, ""):  # allow `python3 etl.py` from this directory
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from pgmigrate import dump as dumpmod
    from pgmigrate.model import (
        CURRENCY_PRECISION, Issue, Money, Row, Table, TransformError,
        assert_not_float, error,
    )
else:
    from . import dump as dumpmod
    from .model import (
        CURRENCY_PRECISION, Issue, Money, Row, Table, TransformError,
        assert_not_float, error,
    )

__all__ = ["main", "run", "Plan", "Backend", "resolve_backend", "copy_escape",
           "render_cell", "CopyWriter", "ReconciliationError"]

CONTRACT_VERSION = 1


# --------------------------------------------------------------------------
# Binding the sibling modules
#
# `ddl`, `rules` and `mres` are separate modules with their own owners. They
# are resolved by name here, and every symbol this orchestrator calls is
# checked up front, so an interface drift fails before a single row is read
# rather than half way through a table.
# --------------------------------------------------------------------------

_REQUIRED: dict[str, tuple[str, ...]] = {
    "ddl": ("translate", "Options"),
    "rules": ("CARRY", "validate", "tables_by_mode", "currency_columns",
              "transcoded_columns", "scaled_columns", "scale_currency",
              "boolean_columns", "added_columns", "unpopulated_columns",
              "compensation_tables", "compute_compensation", "apply_compensation",
              "COMPENSATION_POLICY", "COMPENSATION_ORDER",
              "COMPENSATION_CREDIT_TABLE", "COMPENSATION_CREDIT_COLUMN",
              "COMPENSATION_CREDIT_OWNER_COLUMN",
              "CARRY_AS_IS", "CARRY_TRANSFORM", "DROP", "DECIDE"),
    "mres": ("to_json",),
}


@dataclass
class Backend:
    """The three sibling modules, plus anything about them that did not resolve.

    Held as objects rather than imported directly so the orchestrator can be
    tested against stand-ins — the tests exercise this file's refusals, not
    another module's policy.
    """

    ddl: object = None
    rules: object = None
    mres: object = None
    missing: list[str] = field(default_factory=list)


def resolve_backend(package: str | None = None) -> Backend:
    """Import `ddl`, `rules` and `mres`; verify every symbol used here."""
    base = package or (__package__ or "pgmigrate")
    backend = Backend()
    for name, required in _REQUIRED.items():
        try:
            module = importlib.import_module(f"{base}.{name}")
        except ImportError as exc:
            backend.missing.append(f"{name}.py could not be imported: {exc}")
            continue
        absent = [s for s in required if not hasattr(module, s)]
        if absent:
            backend.missing.append(
                f"{name}.py is missing: {', '.join(absent)}"
            )
        setattr(backend, name, module)
    return backend


# --------------------------------------------------------------------------
# COPY emission
# --------------------------------------------------------------------------

# PostgreSQL COPY text format. Backslash first — order matters.
_COPY_TRANS = str.maketrans({
    "\\": "\\\\",
    "\n": "\\n",
    "\r": "\\r",
    "\t": "\\t",
    "\b": "\\b",
    "\f": "\\f",
    "\v": "\\v",
})


def copy_escape(text: str, *, table: str, column: str | None, pk: object | None) -> str:
    """Escape one field for COPY text format.

    A NUL byte is a hard error, not an escape: PostgreSQL text columns cannot
    hold one at all, so a value containing one needs a decision (strip it?
    reject the row? bytea?) that this tool must not make on its own.
    """
    if "\0" in text:
        raise error(table, column, pk,
                    "value contains a NUL byte, which PostgreSQL text cannot "
                    "store; this column needs an explicit rule")
    return text.translate(_COPY_TRANS)


def render_cell(value: object, *, table: str, column: str, pk: object | None,
                issues: list[Issue]) -> str:
    """Render one transformed value as a COPY field."""
    if value is None:
        return "\\N"
    if isinstance(value, Money):
        return copy_escape(value.text, table=table, column=column, pk=pk)
    if isinstance(value, bool):
        return "t" if value else "f"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, Decimal):
        return copy_escape(format(value, "f"), table=table, column=column, pk=pk)
    if isinstance(value, float):
        # Currency floats are impossible by here (Money.parse rejects them). A
        # float in a non-currency column means a transform coerced it; repr()
        # round-trips, but it is worth saying out loud.
        issues.append(Issue(
            severity="warn", table=table, column=column, pk=pk,
            message="a float reached the emitter; pass text or Decimal so the "
                    "value cannot drift",
        ))
        return repr(value)
    if isinstance(value, str):
        return copy_escape(value, table=table, column=column, pk=pk)
    if isinstance(value, (list, dict)):
        try:
            text = json.dumps(value, ensure_ascii=False, allow_nan=False,
                              separators=(",", ":"))
        except (TypeError, ValueError) as exc:
            raise error(table, column, pk, f"value is not JSON-serialisable: {exc}")
        return copy_escape(text, table=table, column=column, pk=pk)
    raise error(table, column, pk,
                f"cannot render a value of type {type(value).__name__} for COPY")


def jsonl_value(value: object, *, table: str, column: str, pk: object | None) -> object:
    """Render one transformed value for the auditor's JSONL intermediate.

    Money is written as a JSON integer when it is integral — Python's JSON
    writes arbitrary-precision integers exactly — and as a *string* when it is
    not, because a JSON float would round the one kind of number that must not
    round.
    """
    if isinstance(value, Money):
        if value.value == value.value.to_integral_value():
            return int(value.value)
        return value.text
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, (type(None), bool, int, str, list, dict)):
        return value
    if isinstance(value, float):
        return repr(value)
    raise error(table, column, pk,
                f"cannot represent a value of type {type(value).__name__} in JSONL")


_SAFE_NAME = re.compile(r"^[A-Za-z0-9_.-]+$")


def _safe_filename(table: str, suffix: str) -> str:
    if _SAFE_NAME.match(table):
        return f"{table}{suffix}"
    safe = "".join(ch if _SAFE_NAME.match(ch) else f"%{ord(ch):02x}" for ch in table)
    return f"{safe}{suffix}"


def _quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


class CopyWriter:
    """Writes one table's COPY file (and its JSONL twin), hashing as it goes.

    Writes to `<name>.partial` and is promoted only on a successful,
    reconciled run — so a failed migration cannot leave behind an output
    directory that looks complete.
    """

    def __init__(self, out_dir: str, target: str, source: str, *, jsonl: bool = True):
        self.target = target
        self.source = source
        self.filename = _safe_filename(target, ".copy")
        self.final_path = os.path.join(out_dir, "data", self.filename)
        self.path = self.final_path + ".partial"
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        self._fh = open(self.path, "w", encoding="utf-8", newline="\n")
        self._digest = hashlib.sha256()
        self.rows = 0

        self.jsonl_filename: str | None = None
        self._jsonl_fh = None
        self.jsonl_final_path: str | None = None
        self.jsonl_path: str | None = None
        if jsonl:
            # Named for the SOURCE table: the auditor's rules are keyed by the
            # table the dump held, not by whatever the target calls it.
            self.jsonl_filename = _safe_filename(source, ".jsonl")
            self.jsonl_final_path = os.path.join(out_dir, "jsonl", self.jsonl_filename)
            self.jsonl_path = self.jsonl_final_path + ".partial"
            os.makedirs(os.path.dirname(self.jsonl_path), exist_ok=True)
            self._jsonl_fh = open(self.jsonl_path, "w", encoding="utf-8", newline="\n")

    def write(self, cells: Iterable[str], record: dict | None = None) -> None:
        line = "\t".join(cells) + "\n"
        self._fh.write(line)
        self._digest.update(line.encode("utf-8"))
        self.rows += 1
        if self._jsonl_fh is not None and record is not None:
            self._jsonl_fh.write(
                json.dumps(record, ensure_ascii=False, allow_nan=False,
                           separators=(",", ":")) + "\n"
            )

    def close(self) -> None:
        if not self._fh.closed:
            self._fh.close()
        if self._jsonl_fh is not None and not self._jsonl_fh.closed:
            self._jsonl_fh.close()

    def count_lines_on_disk(self, *, block: int = 1 << 20) -> int:
        """Re-read the finished file and count its lines.

        Independent of the in-memory counter on purpose: this is the check
        that catches a short write, a full disk, or a writer bug that counts a
        row it never emitted. Every field's newlines are escaped, so one
        newline byte is exactly one row. Costs one sequential read of the
        output — a cheap price for the number the whole run is judged on.
        """
        self.close()
        path = self.path if os.path.exists(self.path) else self.final_path
        total = 0
        with open(path, "rb") as fh:
            while True:
                chunk = fh.read(block)
                if not chunk:
                    break
                total += chunk.count(b"\n")
        return total

    def promote(self) -> None:
        self.close()
        os.replace(self.path, self.final_path)
        if self.jsonl_path and self.jsonl_final_path:
            os.replace(self.jsonl_path, self.jsonl_final_path)

    @property
    def sha256(self) -> str:
        return self._digest.hexdigest()


# --------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------


@dataclass
class TableStat:
    disposition: str = "decide"
    rows_in: int = 0
    rows_out: int = 0
    rows_dropped: int = 0
    target: str | None = None
    columns: list[str] = field(default_factory=list)
    file: str | None = None
    jsonl: str | None = None
    sha256: str | None = None


@dataclass
class Plan:
    """Everything the run needs, resolved before a single row is read."""

    dump_path: str
    out_dir: str
    report_path: str
    #: Waive UNDECIDED **tables** only (mode DECIDE): they are listed loudly and
    #: their rows are not migrated. Waives nothing else.
    allow_decide: bool = False
    #: Waive the four GLOBAL product decisions (compensation policy, compensation
    #: order, balance-scale confirmation, freeze). Separate from `allow_decide`
    #: because they are separate refusals: one skips tables nobody has ruled on,
    #: the other proceeds with the decisions DECISIONS.md exists to force still
    #: unmade — which among other things means paying out no compensation at all.
    allow_undecided_policy: bool = False
    limit: int | None = None
    encoding: str = "utf-8"
    jsonl: bool = True


class ReconciliationError(Exception):
    """Counts did not add up. The run is refused; nothing is promoted."""


def run(plan: Plan, backend: Backend) -> dict:
    """Execute the migration. Returns the report; raises on refusal."""
    if backend.missing:
        raise error("<backend>", None, None,
                    "cannot run: " + " | ".join(backend.missing))
    rules = backend.rules
    mres = backend.mres

    issues: list[Issue] = []
    scan = dumpmod.scan_schema(plan.dump_path, encoding=plan.encoding)
    tables = scan.tables

    for orphan in scan.insert_tables:
        if orphan not in tables:
            issues.append(Issue(
                severity="error", table=orphan, column=None, pk=None,
                message="the dump has data for this table but no CREATE TABLE; "
                        "its column names are unknowable",
            ))
    for note in scan.routines:
        issues.append(Issue(
            severity="warn", table="<dump>", column=None, pk=None,
            message=f"skipped a routine/trigger/view/event ({note}); not migrated",
        ))

    # --- policy -----------------------------------------------------------
    # Dispositions first, so the two different refusals can be told apart: a
    # table nobody has *decided* about is an open product question (exit 3,
    # waivable for a rehearsal with --allow-decide), while a table with no
    # policy entry at all is a defect in the policy — the silent-drop hole —
    # and is never waivable.
    stats: dict[str, TableStat] = {}
    carried: list[str] = []
    undecided: list[str] = []
    unlisted: list[str] = []
    for name in tables:
        entry = rules.CARRY.get(name)
        stat = TableStat()
        stats[name] = stat
        if entry is None:
            stat.disposition = "unlisted"
            unlisted.append(name)
            continue
        stat.disposition = entry.mode
        if entry.carries:
            carried.append(name)
        elif entry.mode == rules.DECIDE:
            undecided.append(name)

    if unlisted:
        # rules.validate refuses an unlisted table even when unresolved
        # decisions are being waived; call it so the message comes from the
        # policy module rather than being paraphrased here.
        rules.validate(list(tables), allow_unresolved_tables=True,
                       allow_undecided_policy=True)
        raise error(unlisted[0], None, None,
                    "this source table has no entry in the carry-over policy, "
                    "so nothing decides whether it carries")

    if undecided:
        banner = ("UNRESOLVED TABLES — no carry-over rule has been decided:\n"
                  + "\n".join(f"    {n}" for n in undecided))
        if not plan.allow_decide:
            raise error("<rules>", None, None,
                        banner + "\n  Decide each one in rules.py, or re-run "
                        "with --allow-decide to skip them (their rows will NOT "
                        "be migrated).")
        print(banner, file=sys.stderr)
        print("  --allow-decide given: these tables are SKIPPED, not migrated.\n",
              file=sys.stderr)
        for name in undecided:
            issues.append(Issue(
                severity="warn", table=name, column=None, pk=None,
                message="unresolved carry-over rule; skipped under --allow-decide",
            ))

    # The rest of the policy gate: the decisions that are not per-table
    # (compensation policy and order, balance-scale confirmation, freeze).
    # `allow_undecided_policy` is a SEPARATE waiver from `allow_decide`: one
    # skips tables nobody has ruled on, the other proceeds with the four
    # decisions DECISIONS.md exists to force still unmade. One flag doing both
    # meant a rehearsal switch quietly turned off every product gate.
    issues.extend(rules.validate(
        list(tables),
        allow_unresolved_tables=plan.allow_decide,
        allow_undecided_policy=plan.allow_undecided_policy))

    # --- schema translation, carried tables only --------------------------
    missing_ddl = [n for n in carried if n not in scan.ddl_text]
    if missing_ddl:
        raise error(missing_ddl[0], None, None,
                    "the policy carries this table but the dump has no CREATE "
                    "TABLE for it")
    # The policy channel. Without it `ddl` translates the SOURCE schema and this
    # file transforms rows for a DIFFERENT target: the transcoded columns land in
    # `text` instead of `jsonb`, every `tinyint(1)` becomes a boolean including
    # the ones holding 0/1/2/3/9, and the columns the policy adds exist in the
    # COPY header and nowhere else. All three are invisible here and fatal at
    # `psql` time.
    emitted = backend.ddl.translate(
        "\n".join(scan.ddl_text[n] for n in carried),
        backend.ddl.Options(
            tinyint1_as_boolean=False,
            boolean_columns=frozenset(
                (t, c) for t, c in rules.boolean_columns() if t in set(carried)),
            jsonb_columns=frozenset(
                (t, c) for t, c in rules.transcoded_columns() if t in set(carried)),
            extra_columns=_extra_columns(rules, carried),
            # Policy renames, so the schema declares the TARGET name the COPY
            # header will use. Without this the two disagree by exactly the
            # renamed column and psql fails on the first line of the load.
            policy_renames={t: dict(rules.CARRY[t].rename)
                            for t in carried if rules.CARRY[t].rename},
            table_renames={t: rules.CARRY[t].target_table
                           for t in carried if rules.CARRY[t].target_table},
        ),
        source=os.path.basename(plan.dump_path),
    )
    ddl_errors = emitted.errors()
    issues.extend(ddl_errors)
    issues.extend(emitted.guesses())
    renames: dict[str, dict[str, str]] = dict(getattr(emitted, "column_renames", {}) or {})

    for name in carried:
        entry = rules.CARRY[name]
        for column in entry.drop:
            if not tables[name].has_column(column):
                issues.append(Issue(
                    severity="warn", table=name, column=column, pk=None,
                    message="the policy drops a column the dump does not have "
                            "(schema drift, or already gone)",
                ))

    # --- column sets ------------------------------------------------------
    currency_cols = {(t, c) for t, c in rules.currency_columns()}
    scaled_cols = {(t, c) for t, c in rules.scaled_columns()}
    transcoded = {(t, c) for t, c in rules.transcoded_columns()}
    for table, column in sorted(currency_cols | transcoded):
        if table in tables and not tables[table].has_column(column):
            issues.append(Issue(
                severity="error", table=table, column=column, pk=None,
                message="declared as a currency/encoded column but the dumped "
                        "schema has no such column",
            ))

    # --- pass A: what does NOT carry --------------------------------------
    # Two jobs, one pass over the rest of the dump, because both need the rows
    # the carried stream skips:
    #
    #   1. COUNT the dropped and undecided tables. Without this every DROP table
    #      reports `rows_in: 0, rows_dropped: 0`, and "the policy dropped 12,431
    #      houses", "the table was empty" and "the parser never saw this table"
    #      become the same report line. The last one reconciles clean.
    #   2. VALUE what the map change destroys. Compensation is computed from rows
    #      that are about to stop existing, so it has to happen while they can
    #      still be read — and with the stream restricted to carried tables it was
    #      not merely unimplemented, it was structurally impossible.
    #
    # The cost is parsing the dump's data twice. That is minutes on a one-time
    # run, against a compensation credit nobody can recompute afterwards.
    compensating = [t for t in rules.compensation_tables() if t in tables]
    credit_key = (rules.COMPENSATION_CREDIT_TABLE, rules.COMPENSATION_CREDIT_COLUMN)
    compensation = None
    credits: dict[str, int] = {}

    not_carried = [t for t in tables if t not in set(carried)]
    comp_rows: list[Row] = []
    if not_carried:
        for row in dumpmod.iter_rows(plan.dump_path, tables, only=not_carried,
                                     encoding=plan.encoding,
                                     values=bool(compensating)):
            stat = stats[row.table]
            stat.rows_in += 1
            stat.rows_dropped += 1
            if compensating and row.table in set(compensating):
                comp_rows.append(row)

    if compensating:
        if not callable(getattr(rules, "COMPENSATION_POLICY", None)):
            # rules.validate has already refused this unless the operator waived
            # it explicitly; say what the waiver actually costs.
            issues.append(Issue(
                severity="warn", table="<compensation>", column=None, pk=None,
                message="COMPENSATION_POLICY is UNDECIDED and the run was allowed to "
                        "proceed anyway: %d rows of destroyed property across %s were "
                        "valued at NOTHING. This is a rehearsal result, not a migration."
                        % (len(comp_rows), ", ".join(compensating)),
            ))
        elif credit_key not in scaled_cols:
            issues.append(Issue(
                severity="error", table=credit_key[0], column=credit_key[1], pk=None,
                message="compensation credits land in this column, but it is not a "
                        "scaled currency column — so there is no defined order in "
                        "which the credit and the balance scale apply to it. Declare "
                        "it currency+scaled, or move the credit.",
            ))
        else:
            try:
                compensation = rules.compute_compensation(comp_rows)
                credits = dict(compensation.credits)
            except TransformError as exc:
                issues.append(exc.issue)
    comp_rows = []          # released: the valuation is all that was needed

    # --- stream rows ------------------------------------------------------
    writers: dict[str, CopyWriter] = {}
    currency_in: dict[tuple[str, str], Decimal] = {}
    currency_out: dict[tuple[str, str], Decimal] = {}
    currency_dropped: dict[tuple[str, str], Decimal] = {}
    currency_scaled: set[tuple[str, str]] = set()
    credit_applied: dict[str, int] = {}
    fatal: TransformError | None = None

    try:
        with localcontext() as ctx:
            ctx.prec = CURRENCY_PRECISION
            for row in dumpmod.iter_rows(plan.dump_path, tables, only=carried,
                                         encoding=plan.encoding):
                source = row.table
                stat = stats[source]
                if plan.limit is not None and stat.rows_in >= plan.limit:
                    continue
                stat.rows_in += 1
                table_def = tables[source]
                entry = rules.CARRY[source]
                pk = _natural_key(entry, row, table_def)

                # Money in, counted from the untouched source text. Currency
                # accounting is keyed by the SOURCE column throughout, because
                # that is the identity a rename cannot move.
                befores: dict[tuple[str, str], Decimal | None] = {}
                for column, raw in row.values.items():
                    key = (source, column)
                    if key not in currency_cols:
                        continue
                    before = None if raw is None else Money.parse(
                        raw, table=source, column=column, pk=pk).value
                    befores[key] = before
                    if before is not None:
                        currency_in[key] = currency_in.get(key, Decimal(0)) + before

                # The compensation credit for THIS player, if any. Taken out of
                # the ledger as it is spent, so whatever is left at the end is
                # credit owed to somebody with no account row — which is an
                # error, not a rounding difference.
                credit = 0
                if credits and source == credit_key[0]:
                    uid = row.values.get(rules.COMPENSATION_CREDIT_OWNER_COLUMN)
                    if uid is not None:
                        credit = credits.pop(str(uid), 0)
                        if credit:
                            credit_applied[str(uid)] = credit

                values = _carry_row(row, table_def, entry, rules, mres,
                                    currency_cols, currency_scaled, pk,
                                    credit=credit, credit_key=credit_key)
                if values is None:
                    if credit:
                        raise error(
                            source, credit_key[1], pk,
                            "this row was excluded from the migration but carries a "
                            "compensation credit of %d; the credit would vanish with "
                            "it. Decide explicitly: exclude the property row too, or "
                            "carry the player." % credit)
                    stat.rows_dropped += 1
                    for key, before in befores.items():
                        if before is not None:
                            currency_dropped[key] = (
                                currency_dropped.get(key, Decimal(0)) + before)
                    continue

                # Money out. `Money.parse` refuses a float outright — that is
                # the assertion that currency never passes through one,
                # checked per value rather than per total, because a rounded
                # total looks perfectly plausible.
                for column, value in list(values.items()):
                    key = (source, column)
                    if key not in currency_cols or value is None:
                        continue
                    money = Money.parse(value, table=source, column=column, pk=pk)
                    values[column] = money
                    currency_out[key] = currency_out.get(key, Decimal(0)) + money.value

                # Renames last, so every rule above is written in source names.
                # The TABLE can be renamed too: `apd_applications` on the source
                # box is `maxsec_applications` here, same columns, and without
                # this the rows land in a table nothing reads.
                target = entry.target_table or source
                fold = renames.get(source) or {}
                mapped = {}
                for column, value in values.items():
                    name_out = entry.rename.get(column, column)
                    name_out = fold.get(name_out, fold.get(column, name_out))
                    if name_out in mapped:
                        raise error(source, column, pk,
                                    f"two source columns map to {name_out!r}")
                    mapped[name_out] = value
                values = mapped

                writer = writers.get(target)
                if writer is None:
                    writer = CopyWriter(plan.out_dir, target, source, jsonl=plan.jsonl)
                    writers[target] = writer
                    stat.target = target
                    stat.columns = _target_columns(table_def, entry, fold, values)
                    stat.file = writer.filename
                    stat.jsonl = writer.jsonl_filename
                expected = stat.columns
                if set(values) != set(expected):
                    missing = sorted(set(expected) - set(values))
                    extra = sorted(set(values) - set(expected))
                    raise error(target, None, pk,
                                "transformed row does not match the target "
                                f"columns (missing: {missing or 'none'}; "
                                f"unexpected: {extra or 'none'}); columns are "
                                "matched by name, never by position")
                record = None
                if plan.jsonl:
                    record = {
                        c: jsonl_value(values[c], table=target, column=c, pk=pk)
                        for c in expected
                    }
                writer.write(
                    (render_cell(values[c], table=target, column=c, pk=pk,
                                 issues=issues) for c in expected),
                    record,
                )
                stat.rows_out += 1
    except TransformError as exc:
        fatal = exc
    finally:
        for writer in writers.values():
            writer.close()

    for stat in stats.values():
        writer = writers.get(stat.target or "")
        if writer is not None:
            stat.sha256 = writer.sha256

    # --- reconcile --------------------------------------------------------
    failures: list[str] = []
    if fatal is not None:
        failures.append(fatal.issue.format())
    for name in carried:
        stat = stats[name]
        if stat.rows_in != stat.rows_out + stat.rows_dropped:
            failures.append(
                f"{name}: {stat.rows_in} rows in but {stat.rows_out} out + "
                f"{stat.rows_dropped} dropped"
            )
    # The other half of "count in, count out": a table the policy does NOT carry
    # was counted too, and every one of its rows must be accounted for as
    # dropped. Nothing may be emitted for it.
    for name in tables:
        if name in set(carried):
            continue
        stat = stats[name]
        if stat.rows_out or stat.rows_in != stat.rows_dropped:
            failures.append(
                f"{name}: not carried, so all {stat.rows_in} rows must be dropped, "
                f"but {stat.rows_out} were emitted and {stat.rows_dropped} dropped"
            )

    # The COPY header against the schema that was actually emitted. Every check
    # in this file used to pass on output that `psql` refused on its first line:
    # the policy added a column, this file put it in the COPY header, and `ddl`
    # — handed only the SOURCE DDL — never emitted it.
    for name in carried:
        stat = stats[name]
        if not stat.columns:
            continue          # no rows carried, so no header to check
        target = stat.target or name
        try:
            target_columns = emitted.column_names(target)
        except TransformError as exc:
            failures.append(exc.issue.format())
            continue
        for column in stat.columns:
            if column not in target_columns:
                failures.append(
                    f"{target}.{column}: the COPY header names this column but the "
                    f"translated schema has no such column, so the load fails on its "
                    f"first line. Columns are matched by name end to end; a column the "
                    f"policy adds must be declared in the policy's add_columns too."
                )
        for column in target_columns:
            if column in stat.columns:
                continue
            spec = emitted.column(target, column)
            if spec is None or spec.nullable or spec.has_default or spec.identity:
                continue
            failures.append(
                f"{target}.{column}: the translated schema requires this column "
                f"(NOT NULL, no default, not an identity) and nothing in the "
                f"carry-over supplies it, so every row fails. Carry the column, or "
                f"give the target a default."
            )

    # Compensation: what was valued must equal what was paid, per source and in
    # total. A credit computed for a player with no account row is not a rounding
    # difference — it is money the policy decided somebody was owed, going
    # nowhere.
    if compensation is not None:
        valued = sum(compensation.per_source.values())
        by_uid = sum(compensation.credits.values())
        paid = sum(credit_applied.values())
        unmatched = sorted(credits)          # whatever the row stream did not claim
        if valued != by_uid:
            failures.append(
                f"compensation: sources total {valued} but the per-player ledger "
                f"totals {by_uid}"
            )
        if paid + sum(credits[u] for u in unmatched) != by_uid:
            failures.append(
                f"compensation: {by_uid} was credited but {paid} was applied and "
                f"{sum(credits[u] for u in unmatched)} is unaccounted for"
            )
        if unmatched:
            detail = ", ".join(f"{u}={credits[u]}" for u in unmatched[:10])
            message = (
                f"compensation: {len(unmatched)} player(s) are owed credit but have "
                f"no row in {credit_key[0]}: {detail}"
                + (" …" if len(unmatched) > 10 else "")
            )
            if plan.limit is not None:
                # A sample run carries only the first N players, so most credits
                # legitimately have nobody to land on. Say so; do not fail on it.
                issues.append(Issue(severity="warn", table="<compensation>",
                                    column=None, pk=None,
                                    message=message + " (expected under --limit)"))
            else:
                failures.append(message)

    for target, writer in sorted(writers.items()):
        expected_rows = sum(s.rows_out for s in stats.values() if s.target == target)
        if writer.rows != expected_rows:
            failures.append(
                f"{target}: counted {expected_rows} rows out but the writer "
                f"counted {writer.rows}"
            )
        on_disk = writer.count_lines_on_disk()
        if on_disk != expected_rows:
            failures.append(
                f"{target}: counted {expected_rows} rows out but the data file "
                f"holds {on_disk} lines"
            )
    credited_total = Decimal(sum(credit_applied.values()))
    for key in sorted(set(currency_in) | set(currency_out) | set(currency_dropped)):
        if key in currency_scaled:
            continue    # BALANCE_SCALE moved these deliberately; both totals are reported
        got_in = currency_in.get(key, Decimal(0))
        got_out = currency_out.get(key, Decimal(0))
        gone = currency_dropped.get(key, Decimal(0))
        # Compensation is money that did not come from this column, so it is on
        # the IN side of the identity rather than an excuse to skip the check.
        added = credited_total if key == credit_key else Decimal(0)
        if got_in + added != got_out + gone:
            failures.append(
                f"{key[0]}.{key[1]}: currency in {got_in}"
                + (f" + compensation {added}" if added else "")
                + f" != out {got_out} + dropped {gone} "
                f"(difference {got_in + added - got_out - gone})"
            )
    for issue in issues:
        if issue.severity == "error":
            failures.append(issue.format())

    status = "ok" if not failures else "failed"
    if status == "ok" and (plan.allow_undecided_policy or undecided):
        # Stamped into the artefact, not only into the operator's memory. A run
        # made with the product decisions unmade, or with tables nobody has ruled
        # on left behind, is a rehearsal — and six weeks later report.json is the
        # only thing that still knows which kind of run this was.
        status = "rehearsal"
    if plan.limit is not None and status in ("ok", "rehearsal"):
        status = "sample"

    report = _build_report(plan, scan, stats, currency_in, currency_out,
                           currency_dropped, currency_scaled, issues, failures,
                           status, undecided, carried, rules,
                           compensation, credit_applied, credits)
    _write_json(plan.report_path, report)

    if failures:
        # A previous successful run may have left promoted files here. They are
        # now older than the report and must not be mistaken for this run's
        # output, so say so in the directory itself rather than only on stderr.
        _write_text(os.path.join(plan.out_dir, "FAILED.txt"),
                    "This run was REFUSED. Any data files in this directory are\n"
                    "left over from an earlier run and do NOT match "
                    f"{os.path.basename(plan.report_path)}.\n"
                    "Do not load them.\n\n"
                    + "\n".join(failures) + "\n")
        raise ReconciliationError(
            f"refusing to complete — {len(failures)} reconciliation failure(s):\n  "
            + "\n  ".join(failures)
        )

    # --- promote ----------------------------------------------------------
    stale = os.path.join(plan.out_dir, "FAILED.txt")
    if os.path.exists(stale):
        os.unlink(stale)
    _write_text(os.path.join(plan.out_dir, "schema.sql"), emitted.sql())
    _write_text(os.path.join(plan.out_dir, "schema_post_load.sql"),
                emitted.post_load_sql())
    _write_text(os.path.join(plan.out_dir, "ddl_report.txt"), emitted.report_text())
    for writer in writers.values():
        writer.promote()
    _write_text(os.path.join(plan.out_dir, "load.sql"), _load_script(stats, carried))
    manifest = _manifest(stats, carried, emitted)
    _write_json(os.path.join(plan.out_dir, "MANIFEST.json"), manifest)
    _write_text(os.path.join(plan.out_dir, "SHA256SUMS"),
                "".join(f"{h}  {p}\n" for p, h in sorted(manifest["files"].items())))
    report["output"] = manifest
    _write_json(plan.report_path, report)
    return report


# --------------------------------------------------------------------------
# The carry-over itself
# --------------------------------------------------------------------------


def _natural_key(entry, row: Row, table_def: Table) -> object:
    """The row's identity for error messages: the policy's natural key.

    Falls back to the dumped primary key, then to nothing — an unnamed row in
    an error message is bad, but inventing an identity would be worse.
    """
    keys = tuple(entry.natural_key) or tuple(table_def.primary_key)
    if not keys:
        return None
    parts = [row.values.get(k) for k in keys]
    return parts[0] if len(parts) == 1 else tuple(parts)


# What a source value may say when the policy declares the column a flag.
# NOTE the absences. An EMPTY STRING is not here: it used to coerce to False,
# which is precisely the silent default this file's whole job is to refuse — a
# column that arrived empty is a column nobody has decided the rule for, and
# `false` is a guess with a player-visible consequence (an empty `casino_banned`
# reads as "not banned"). `yes`/`no` are gone too: a `tinyint` cannot produce
# them, so accepting them only widened what could pass unnoticed.
_TRUE = {"1", "true", "t"}
_FALSE = {"0", "false", "f"}


def _carry_row(row: Row, table_def: Table, entry, rules, mres,
               currency_cols: set, currency_scaled: set,
               pk: object, *, credit: int = 0,
               credit_key: tuple[str, str] | None = None) -> dict[str, object] | None:
    """Apply one table's carry policy to one row. Source column names in.

    Order is deliberate: drop, then transcode, then booleans, then scale, then
    defaults and forced values. Renames happen in the caller, last of all, so
    that every rule above can be written — and read — in the names the source
    actually uses.
    """
    table = row.table
    values = dict(row.values)

    # Optional per-row exclusion, for the "excluded ids, and why" case (a
    # banned account nobody wants carried, a test account). Absent from the
    # policy module today; wired here so that adding it later cannot mean
    # rewriting the counting, which is the part that must not be touched
    # casually.
    exclude = getattr(rules, "exclude_row", None)
    if exclude is not None and exclude(row, table_def):
        return None

    for column in entry.drop:
        values.pop(column, None)

    for column in entry.transcode:
        if column not in values:
            raise error(table, column, pk,
                        "the policy transcodes this column but the row does "
                        "not have it")
        raw = values[column]
        if raw is None:
            continue
        if not isinstance(raw, str):
            raise error(table, column, pk,
                        f"encoded column holds {type(raw).__name__}; expected "
                        "the source's text encoding")
        # mres.to_json refuses rather than returning an empty-ish value: an
        # unreadable inventory read as empty is how stored property has been
        # destroyed before.
        values[column] = mres.to_json(raw, table=table, column=column, pk=pk)

    for column in entry.booleans:
        if column not in values:
            raise error(table, column, pk,
                        "the policy makes this column boolean but the row does "
                        "not have it")
        raw = values[column]
        if raw is None or isinstance(raw, bool):
            continue
        text = str(raw).strip().lower()
        if text in _TRUE:
            values[column] = True
        elif text in _FALSE:
            values[column] = False
        else:
            raise error(table, column, pk,
                        f"value {raw!r} is not a boolean; a tinyint(1) holding "
                        "anything but 0/1 must not be declared a flag")

    credit_landed = False
    for column in entry.scaled:
        if column not in values or values[column] is None:
            continue
        key = (table, column)
        if key not in currency_cols:
            raise error(table, column, pk,
                        "scaled column is not declared as currency")
        before = Money.parse(values[column], table=table, column=column, pk=pk)
        plain = rules.scale_currency(table, column, pk, values[column])
        # The one stage boundary a currency value crosses outside Money's hands.
        assert_not_float(plain, table=table, column=column, pk=pk)
        # Only a scale that actually moved the number relaxes reconciliation.
        # At 1:1 — the default, and quite possibly the final answer — the
        # totals must still match to the unit, or the check is worthless. The
        # comparison is against the SCALE ALONE: a compensation credit also moves
        # the number, and letting that relax the check would switch off the money
        # reconciliation for the one column compensation is paid into.
        if Money.parse(plain, table=table, column=column, pk=pk).value != before.value:
            currency_scaled.add(key)
        if credit and key == credit_key:
            # Scaling and the credit in one call, because their ORDER changes the
            # number and the order is a recorded decision (DECISIONS.md #2), not
            # something this loop gets to pick.
            scaled = rules.apply_compensation(table=table, column=column, pk=pk,
                                              balance=values[column], credit=credit)
            assert_not_float(scaled, table=table, column=column, pk=pk)
            credit_landed = True
        else:
            scaled = plain
        values[column] = scaled

    if credit and not credit_landed:
        raise error(table, credit_key[1] if credit_key else None, pk,
                    "this player is owed a compensation credit of %d but the credit "
                    "column is missing or NULL on their row, so there is nothing to "
                    "add it to. A credit that cannot land must not be dropped."
                    % credit)

    for column, value in entry.defaults.items():
        if column not in values:
            values[column] = value

    for column, value in entry.force.items():
        values[column] = value

    # LAST, on purpose. A row rewrite is the only rule that can see a row whole —
    # every column rule above has already run, so what it reads is what would
    # have been written. Returning None drops the row, which the caller already
    # counts and already routes through the dropped-currency totals, so a rewrite
    # cannot quietly lose money it was holding.
    if entry.rewrite:
        fn = rules.ROW_REWRITES.get(entry.rewrite)
        if fn is None:
            raise error(table, None, pk,
                        "the policy names row rewrite %r, which is not registered in "
                        "rules.ROW_REWRITES" % entry.rewrite)
        rewritten = fn(values)
        if rewritten is None:
            return None
        if not isinstance(rewritten, dict):
            raise error(table, None, pk,
                        "row rewrite %r returned %r; it must return the row dict or None"
                        % (entry.rewrite, type(rewritten).__name__))
        values = rewritten

    return values


def _target_columns(table_def: Table, entry, fold: dict[str, str],
                    first_row: dict[str, object]) -> list[str]:
    """Column order for a table's COPY file, in the source's declared order.

    Source order is used on purpose: it is the order a human reading the
    original schema expects, which makes the emitted file reviewable next to
    the dump it came from. Columns the policy adds follow, sorted.
    """
    ordered: list[str] = []
    for col in table_def.columns:
        name = entry.rename.get(col.name, col.name)
        name = fold.get(name, fold.get(col.name, name))
        if name in first_row and name not in ordered:
            ordered.append(name)
    extra = sorted(c for c in first_row if c not in ordered)
    return ordered + extra


# --------------------------------------------------------------------------
# Output files
# --------------------------------------------------------------------------


def _load_script(stats: dict[str, TableStat], carried: list[str]) -> str:
    lines = [
        "-- pgmigrate load script. Run from the output directory:",
        "--     psql -v ON_ERROR_STOP=1 -f schema.sql -f load.sql \\",
        "--          -f schema_post_load.sql <dsn>",
        "-- schema_post_load.sql seeds identity sequences and must run AFTER",
        "-- these copies: the rows carry their original ids.",
        "-- Data files are COPY text format: tab separated, \\N for NULL.",
        "\\set ON_ERROR_STOP on",
        "BEGIN;",
    ]
    for name in sorted(carried):
        stat = stats[name]
        if not stat.file:
            continue
        target = stat.target or name
        cols = ", ".join(_quote_ident(c) for c in stat.columns)
        lines.append(
            f"\\copy {_quote_ident(target)} ({cols}) FROM 'data/{stat.file}' "
            "WITH (FORMAT text)"
        )
    lines.append("COMMIT;")
    return "\n".join(lines) + "\n"


def _manifest(stats: dict[str, TableStat], carried: list[str], emitted) -> dict:
    files: dict[str, str] = {
        "schema.sql": hashlib.sha256(emitted.sql().encode("utf-8")).hexdigest(),
        "schema_post_load.sql":
            hashlib.sha256(emitted.post_load_sql().encode("utf-8")).hexdigest(),
    }
    tables: dict[str, dict] = {}
    for name in sorted(carried):
        stat = stats[name]
        if not stat.file:
            continue
        files[f"data/{stat.file}"] = stat.sha256 or ""
        tables[name] = {
            "target": stat.target or name,
            "file": f"data/{stat.file}",
            "jsonl": f"jsonl/{stat.jsonl}" if stat.jsonl else None,
            "rows": stat.rows_out,
            "columns": stat.columns,
            "sha256": stat.sha256,
        }
    return {"contract_version": CONTRACT_VERSION, "files": files, "tables": tables}


def _extra_columns(rules, carried: list[str]) -> dict[str, dict[str, str]]:
    """{table: {column: definition}} for the policy's target-only columns."""
    out: dict[str, dict[str, str]] = {}
    for table, column, definition in rules.added_columns():
        if table in set(carried):
            out.setdefault(table, {})[column] = definition
    return out


def _compensation_report(rules, compensation, credit_applied, credits) -> dict:
    """What compensation did, per source, so a payout can be audited afterwards.

    Reported even when the answer is "nothing", because "nothing" is a decision
    (or a waiver) and the difference between the two has to be readable months
    later, when the only surviving record of beta night is this file.
    """
    decided = callable(getattr(rules, "COMPENSATION_POLICY", None))
    order = getattr(rules, "COMPENSATION_ORDER", None)
    doc = {
        "policy": "decided" if decided else "UNDECIDED",
        "order": None if not isinstance(order, str) else order,
        "credit_column": f"{rules.COMPENSATION_CREDIT_TABLE}."
                         f"{rules.COMPENSATION_CREDIT_COLUMN}",
        "sources": sorted(rules.compensation_tables()),
        "computed": compensation is not None,
    }
    if compensation is None:
        doc["note"] = ("no compensation was computed; property destroyed by the map "
                       "change was valued at nothing")
        return doc
    doc.update({
        "per_source": {k: str(v) for k, v in sorted(compensation.per_source.items())},
        "rows_seen": dict(sorted(compensation.rows_seen.items())),
        "rows_skipped_unowned": dict(sorted(compensation.rows_skipped_unowned.items())),
        "players_credited": len(compensation.credits),
        "total_credit": str(sum(compensation.credits.values())),
        "total_applied": str(sum(credit_applied.values())),
        "unmatched_players": sorted(credits),
    })
    return doc


def _build_report(plan, scan, stats, currency_in, currency_out, currency_dropped,
                  currency_scaled, issues, failures, status, undecided, carried,
                  rules, compensation, credit_applied, credits) -> dict:
    """Assemble report.json. Contains no timestamps — see the module docstring."""
    with localcontext() as ctx:
        ctx.prec = CURRENCY_PRECISION
        currency = {}
        for key in sorted(set(currency_in) | set(currency_out) | set(currency_dropped)):
            currency[f"{key[0]}.{key[1]}"] = {
                "in": format(currency_in.get(key, Decimal(0)), "f"),
                "out": format(currency_out.get(key, Decimal(0)), "f"),
                "dropped_with_rows": format(currency_dropped.get(key, Decimal(0)), "f"),
                "scaled_by_policy": key in currency_scaled,
            }
    open_questions = []
    if hasattr(rules, "open_questions"):
        open_questions = [{"table": t, "question": q} for t, q in rules.open_questions()]
    scale = getattr(rules, "BALANCE_SCALE", None)
    return {
        "tool": "pgmigrate",
        "contract_version": CONTRACT_VERSION,
        "status": status,
        "dump": {
            "file": os.path.basename(plan.dump_path),
            "sha256": dumpmod.dump_sha256(plan.dump_path),
            "tables": len(scan.tables),
            "skipped_routines": scan.routines,
        },
        "sampled_limit": plan.limit,
        "tables": {
            name: {
                "disposition": stats[name].disposition,
                "target": stats[name].target,
                "rows_in": stats[name].rows_in,
                "rows_out": stats[name].rows_out,
                "rows_dropped": stats[name].rows_dropped,
                "file": stats[name].file,
                "jsonl": stats[name].jsonl,
                "sha256": stats[name].sha256,
            }
            for name in sorted(stats)
        },
        "carried": sorted(carried),
        "unresolved": sorted(undecided),
        "waivers": {
            "allow_decide": plan.allow_decide,
            "allow_undecided_policy": plan.allow_undecided_policy,
        },
        "balance_scale": None if scale is None else str(scale),
        "open_questions": open_questions,
        "compensation": _compensation_report(rules, compensation, credit_applied,
                                             credits),
        # Columns the target has and this migration does not write: the policy
        # drops their VALUE (old-map coordinates, in-flight session state) while
        # the target keeps the column and fills it itself. Listed so that is a
        # stated fact rather than something discovered later.
        "unpopulated_target_columns": [
            f"{t}.{c}" for t, c in rules.unpopulated_columns() if t in set(carried)
        ],
        "currency": currency,
        "issues": [i.to_json() for i in issues],
        "reconciliation": {"ok": not failures, "failures": failures},
    }


def _write_text(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp = path + ".partial"
    with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    os.replace(tmp, path)


def _write_json(path: str, obj: dict) -> None:
    _write_text(path, json.dumps(obj, indent=2, ensure_ascii=False) + "\n")


# --------------------------------------------------------------------------
# Optional load step — the only place a third-party package is used
# --------------------------------------------------------------------------


def load_into_postgres(out_dir: str, dsn: str) -> None:
    """Apply the schema and COPY the data files into a PostgreSQL database.

    Imports `psycopg` lazily and nowhere else, so the transform above runs on
    a stock Python 3 with nothing installed. This is a convenience for the
    rehearsal loop; `psql -f schema.sql -f load.sql -f schema_post_load.sql`
    does the same thing.
    """
    psycopg = importlib.import_module("psycopg")  # third-party, optional
    with open(os.path.join(out_dir, "MANIFEST.json"), encoding="utf-8") as fh:
        manifest = json.load(fh)
    with open(os.path.join(out_dir, "schema.sql"), encoding="utf-8") as fh:
        schema_sql = fh.read()
    with open(os.path.join(out_dir, "schema_post_load.sql"), encoding="utf-8") as fh:
        post_sql = fh.read()
    with psycopg.connect(dsn) as conn:
        with conn.cursor() as cur:
            cur.execute(schema_sql)
            for source in sorted(manifest["tables"]):
                spec = manifest["tables"][source]
                cols = ", ".join(_quote_ident(c) for c in spec["columns"])
                stmt = (f"COPY {_quote_ident(spec['target'])} ({cols}) "
                        "FROM STDIN WITH (FORMAT text)")
                with open(os.path.join(out_dir, spec["file"]), "rb") as data, \
                        cur.copy(stmt) as copy:
                    while True:
                        block = data.read(1 << 20)
                        if not block:
                            break
                        copy.write(block)
            cur.execute(post_sql)     # identity seeds AFTER the explicit ids land
        conn.commit()


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="python3 -m pgmigrate.etl",
        description="One-time ETL: live MariaDB dump -> PostgreSQL COPY files.",
        epilog="Exit codes: 0 ok · 1 usage/IO · 2 transform or reconciliation "
               "failure · 3 unresolved tables without --allow-decide.",
    )
    ap.add_argument("--dump", required=True, help="mysqldump file (.sql or .sql.gz)")
    ap.add_argument("--out", required=True, help="output directory for schema + COPY data")
    ap.add_argument("--report", required=True, help="path for report.json")
    ap.add_argument("--allow-decide", action="store_true",
                    help="REHEARSAL ONLY: proceed despite tables whose carry-over "
                         "rule is still UNDECIDED (mode DECIDE). They are listed "
                         "loudly and their rows are NOT migrated. This waives "
                         "nothing else — a source table with no policy entry at "
                         "all remains an error, and the four global decisions are "
                         "waived only by --allow-undecided-policy")
    ap.add_argument("--allow-undecided-policy", action="store_true",
                    help="REHEARSAL ONLY: proceed with the four decisions in "
                         "DECISIONS.md unmade — compensation policy, compensation "
                         "order, balance-scale confirmation, freeze. Among other "
                         "things this pays out NO compensation for property the map "
                         "change destroys. The report is stamped 'rehearsal'")
    ap.add_argument("--limit", type=int, default=None,
                    help="rehearsal only: cap rows per table. Marks the report "
                         "'sample' — never use this for the real run")
    ap.add_argument("--encoding", default="utf-8", help="dump text encoding")
    ap.add_argument("--no-jsonl", action="store_true",
                    help="skip the jsonl/ tree that reconcile.py audits "
                         "(faster, but nothing independent checks the result)")
    ap.add_argument("--load", metavar="DSN", default=None,
                    help="after a successful run, load the output into this "
                         "PostgreSQL database (requires psycopg)")
    args = ap.parse_args(argv)

    if not os.path.isfile(args.dump):
        print(f"pgmigrate: no such dump file: {args.dump}", file=sys.stderr)
        return 1
    if args.limit is not None and args.limit <= 0:
        print("pgmigrate: --limit must be positive", file=sys.stderr)
        return 1

    plan = Plan(
        dump_path=args.dump,
        out_dir=args.out,
        report_path=args.report,
        allow_decide=args.allow_decide,
        allow_undecided_policy=args.allow_undecided_policy,
        limit=args.limit,
        encoding=args.encoding,
        jsonl=not args.no_jsonl,
    )

    backend = resolve_backend()
    if backend.missing:
        print("pgmigrate: cannot run, the transform is incomplete:", file=sys.stderr)
        for line in backend.missing:
            print(f"  - {line}", file=sys.stderr)
        return 2

    try:
        report = run(plan, backend)
    except TransformError as exc:
        print(f"pgmigrate: {exc.issue.format()}", file=sys.stderr)
        return 3 if "UNRESOLVED TABLES" in exc.issue.message else 2
    except ReconciliationError as exc:
        print(f"pgmigrate: {exc}", file=sys.stderr)
        print(f"pgmigrate: report written to {args.report}; output NOT promoted",
              file=sys.stderr)
        return 2

    total_in = sum(t["rows_in"] for t in report["tables"].values())
    total_out = sum(t["rows_out"] for t in report["tables"].values())
    print(f"pgmigrate: {len(report['carried'])} tables, {total_in} rows read, "
          f"{total_out} rows written -> {args.out}")
    if report["status"] == "sample":
        print("pgmigrate: SAMPLE RUN (--limit) — not a migration", file=sys.stderr)
    if report["status"] == "rehearsal":
        why = []
        if args.allow_undecided_policy:
            # Says which decisions are ACTUALLY unmade, read from the module. The
            # flag waives the gate; it does not uninstall an answer that exists.
            # A fixed string here read "no compensation was paid" and went on being
            # printed after a policy was installed and 220,000 had been paid, which
            # is the most misleading line a rehearsal report could carry.
            unmade = [name for name, value in (
                ("compensation policy", getattr(backend.rules, "COMPENSATION_POLICY", None)),
                ("compensation order", getattr(backend.rules, "COMPENSATION_ORDER", None)),
                ("balance scale confirmation", getattr(backend.rules, "BALANCE_SCALE_CONFIRMED", None)),
                ("freeze", getattr(backend.rules, "FREEZE", None)),
            ) if isinstance(value, backend.rules._Undecided)]
            why.append("--allow-undecided-policy: waived, unanswered — "
                       + (", ".join(unmade) if unmade else "nothing (the flag was not needed)"))
        if report["unresolved"]:
            why.append("tables left undecided and NOT migrated: "
                       + ", ".join(report["unresolved"]))
        print("pgmigrate: REHEARSAL, not a migration — " + "; ".join(why),
              file=sys.stderr)
    for issue in report["issues"]:
        if issue["severity"] == "warn":
            print(f"  warn: {issue['table']}: {issue['message']}", file=sys.stderr)

    if args.load:
        try:
            load_into_postgres(args.out, args.load)
        except ImportError:
            print("pgmigrate: --load needs psycopg installed. The transform "
                  f"output in {args.out} is complete; load it with: "
                  "psql -v ON_ERROR_STOP=1 -f schema.sql -f load.sql "
                  "-f schema_post_load.sql", file=sys.stderr)
            return 1
        print(f"pgmigrate: loaded {args.out} into the target database")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
