"""Tests for the orchestrator: reconciliation, refusals and idempotency.

Purpose:
    Prove that `etl.run` refuses to finish when it cannot account for what it
    moved, and that two runs over the same dump produce identical bytes.

WHY THIS EXISTS:
    The orchestrator's value is entirely in its refusals. A version of it that
    quietly wrote 96% of the rows would pass any "does it produce output" test
    and would be discovered by players, weeks later, with no way back. So the
    tests below are mostly negative: a row miscounted, a balance that does not
    add up, a table nobody decided the rule for, a currency value that reached
    a float, an inventory that would not decode. Each must stop the run and
    leave the output unpromoted.

    `ddl`, `rules` and `mres` are supplied here as in-test stand-ins with the
    same interface as the real modules, so these tests exercise the
    orchestrator alone and cannot fail for reasons belonging to another
    module's policy. The real modules are exercised together by the rehearsal
    script.

Usage:
    python3 tools/pgmigrate/test_etl.py
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import types
import unittest
from dataclasses import dataclass, field
from decimal import Decimal

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pgmigrate import etl                                       # noqa: E402
from pgmigrate.model import Issue, Money, TransformError, error  # noqa: E402

DUMP = r"""
CREATE TABLE `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` varchar(64) NOT NULL,
  `name` varchar(32) DEFAULT NULL,
  `cash` bigint(20) NOT NULL DEFAULT '0',
  `bank` decimal(14,4) NOT NULL DEFAULT 0.0000,
  `position` text,
  `isswat` tinyint(1) NOT NULL DEFAULT 0,
  `licences` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uid_uq` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `players` VALUES
 (1,'7656119800000001','O\'Brien',9007199254740993,1234567890.1234,'[100,200,0]',1,'`[[`cop`,1],[`med`,0]]`'),
 (2,'7656119800000002','Ada',25,0.5000,'[1,2,3]',0,'`[[`cop`,0]]`'),
 (3,'7656119800000003','Ghost',0,0.0000,NULL,0,NULL);
CREATE TABLE `houses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `pid` varchar(64) NOT NULL,
  `worldspace` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
INSERT INTO `houses` VALUES (1,'7656119800000001','[[1,2,3],0]');
CREATE TABLE `mystery` (
  `id` int(11) NOT NULL,
  `v` text
) ENGINE=InnoDB;
INSERT INTO `mystery` VALUES (1,'?');
"""


# --------------------------------------------------------------------------
# Stand-ins with the real modules' interface
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class StubCarry:
    mode: str
    natural_key: tuple = ()
    drop: tuple = ()
    transcode: dict = field(default_factory=dict)
    booleans: tuple = ()
    currency: tuple = ()
    scaled: tuple = ()
    rename: dict = field(default_factory=dict)
    add_columns: dict = field(default_factory=dict)
    defaults: dict = field(default_factory=dict)
    force: dict = field(default_factory=dict)
    compensate: str | None = None
    rewrite: str | None = None
    target_table: str | None = None

    @property
    def carries(self) -> bool:
        return self.mode in ("carry_as_is", "carry_transform")


class TestTheStubMatchesTheRealPolicyObject(unittest.TestCase):
    """StubCarry must declare every field Carry does.

    It has silently fallen behind twice (2026-08-15: `rewrite`, then
    `target_table`), and the symptom both times was ~35 AttributeErrors across
    unrelated ETL tests rather than anything pointing at the stub. A new Carry
    field is a real change to the object the ETL reads; the stub has to keep up,
    and this is cheaper than finding out from a traceback.
    """

    def test_every_field_the_etl_reads_exists_on_the_stub(self):
        """Not every Carry field — only the ones `etl.py` actually touches.

        Read out of the source rather than listed here, so a new `entry.<field>`
        in the ETL fails this test on the day it is written instead of on the day
        somebody runs the suite and gets 35 AttributeErrors in other files.
        `notes`, `reason` and `question` are documentation the ETL never reads,
        and the stub is right not to carry them.
        """
        import dataclasses, re                               # noqa: PLC0415
        here = os.path.dirname(os.path.abspath(__file__))
        source = open(os.path.join(here, "etl.py"), encoding="utf-8").read()
        used = set(re.findall(r"\bentry\.([a-z_]+)", source))
        stub = {f.name for f in dataclasses.fields(StubCarry)}
        sys.path.insert(0, here)
        import rules                                         # noqa: PLC0415
        real = {f.name for f in dataclasses.fields(rules.Carry)}
        used &= real          # entry.carries etc. are properties, not fields
        self.assertEqual(used - stub, set(),
                         "the ETL reads these Carry fields and StubCarry lacks them")


@dataclass
class StubColumn:
    """Mirrors ddl.EmittedColumn: what the target will really have."""

    table: str
    name: str
    pg_type: str = "text"
    nullable: bool = True
    has_default: bool = False
    identity: bool = False
    added_by_policy: bool = False


class StubEmitted:
    def __init__(self, tables, extra_columns=None, not_null=()):
        self._tables = tables
        self.column_renames: dict[str, dict[str, str]] = {}
        self.columns: dict[str, list[StubColumn]] = {}
        for name, cols in tables.items():
            self.columns[name] = [
                StubColumn(table=name, name=c, nullable=(name, c) not in set(not_null))
                for c in cols
            ]
            for c, definition in (extra_columns or {}).get(name, {}).items():
                self._tables[name].append(c)
                self.columns[name].append(
                    StubColumn(table=name, name=c, pg_type=definition.split()[0],
                               added_by_policy=True))

    def column_names(self, table):
        if table not in self.columns:
            raise error(table, None, None, "no CREATE TABLE emitted")
        return [c.name for c in self.columns[table]]

    def column(self, table, name):
        for c in self.columns.get(table, ()):
            if c.name == name:
                return c
        return None

    def sql(self):
        parts = []
        for name in sorted(self._tables):
            cols = ",\n  ".join(f'"{c}" text' for c in self._tables[name])
            parts.append(f'CREATE TABLE "{name}" (\n  {cols}\n);')
        return "\n".join(parts) + "\n"

    def post_load_sql(self):
        return "-- nothing to run after the load.\n"

    def report_text(self):
        return "stub ddl report\n"

    def errors(self):
        return []

    def guesses(self):
        return []


@dataclass
class StubCompensation:
    credits: dict = field(default_factory=dict)
    per_source: dict = field(default_factory=dict)
    rows_seen: dict = field(default_factory=dict)
    rows_skipped_unowned: dict = field(default_factory=dict)


def make_backend(*, carry=None, to_json=None, scale=None, exclude_row=None,
                 missing=None, compensation_policy=None, extra_columns=None,
                 not_null=()):
    policy = {
        "players": StubCarry(
            mode="carry_transform",
            natural_key=("uid",),
            drop=("position",),          # MAP-ANCHORED: old-map coordinates
            transcode={"licences": "jsonb"},
            booleans=("isswat",),
            currency=("cash", "bank"),
            scaled=("cash", "bank"),
        ),
        "houses": StubCarry(mode="drop"),
        "mystery": StubCarry(mode="decide"),
    }
    if carry:
        policy.update(carry)

    def validate(tables, *, allow_unresolved_tables=False,
                 allow_undecided_policy=False):
        out = []
        for name in tables:
            if name not in policy:
                raise error(name, None, None, "no CARRY entry")
        return out

    def columns_of(kind):
        out = []
        for name, entry in sorted(policy.items()):
            if entry.carries:
                out.extend((name, c) for c in getattr(entry, kind))
        return out

    def default_scale(table, column, pk, value, *, scale=None):
        return value

    def apply_compensation(*, table, column, pk, balance, credit):
        return Decimal(str(balance)) + credit

    def compute_compensation(rows):
        """Stand-in for the real valuer: one credit per row, to its owner."""
        result = StubCompensation()
        for row in rows:
            source = f"{row.table}.compensation"
            result.rows_seen[source] = result.rows_seen.get(source, 0) + 1
            uid = row.values.get("pid")
            if uid is None:
                result.rows_skipped_unowned[source] = (
                    result.rows_skipped_unowned.get(source, 0) + 1)
                continue
            credit = compensation_policy(source, row.values)
            result.credits[str(uid)] = result.credits.get(str(uid), 0) + credit
            result.per_source[source] = result.per_source.get(source, 0) + credit
        return result

    rules = types.SimpleNamespace(
        CARRY=policy,
        CARRY_AS_IS="carry_as_is",
        CARRY_TRANSFORM="carry_transform",
        DROP="drop",
        DECIDE="decide",
        BALANCE_SCALE=1,
        validate=validate,
        tables_by_mode=lambda mode: sorted(t for t, c in policy.items() if c.mode == mode),
        currency_columns=lambda: columns_of("currency"),
        scaled_columns=lambda: columns_of("scaled"),
        transcoded_columns=lambda: [(t, c) for t, e in sorted(policy.items())
                                    if e.carries for c in sorted(e.transcode)],
        boolean_columns=lambda: columns_of("booleans"),
        added_columns=lambda: [(t, c, d) for t, e in sorted(policy.items())
                               if e.carries for c, d in sorted(e.add_columns.items())],
        unpopulated_columns=lambda: [(t, c) for t, e in sorted(policy.items())
                                     if e.carries for c in e.drop],
        compensation_tables=lambda: sorted(t for t, e in policy.items() if e.compensate),
        compute_compensation=compute_compensation,
        apply_compensation=apply_compensation,
        COMPENSATION_POLICY=compensation_policy,
        COMPENSATION_ORDER="after_scaling",
        COMPENSATION_CREDIT_TABLE="players",
        COMPENSATION_CREDIT_COLUMN="bank",
        COMPENSATION_CREDIT_OWNER_COLUMN="uid",
        scale_currency=scale or default_scale,
    )
    if exclude_row is not None:
        rules.exclude_row = exclude_row

    def stub_to_json(text, *, table="?", column=None, pk=None):
        body = text.replace("`", '"')
        if body.startswith('"') and body.endswith('"'):
            body = body[1:-1]
        body = body.replace('""', '"')
        try:
            return json.loads(body)
        except ValueError:
            raise error(table, column, pk, "value did not decode")

    def translate(sql, opts, source="<dump>"):
        tables: dict[str, list[str]] = {}
        for chunk in sql.split("CREATE TABLE ")[1:]:
            name = chunk.split("`")[1]
            tables[name] = [line.strip().split("`")[1]
                            for line in chunk.splitlines()[1:]
                            if line.strip().startswith("`")]
        return StubEmitted(tables, extra_columns=opts.extra_columns,
                           not_null=not_null)

    def options(**kw):
        """Stand-in for ddl.Options: records what the policy channel carried."""
        return types.SimpleNamespace(
            tinyint1_as_boolean=kw.get("tinyint1_as_boolean", True),
            boolean_columns=kw.get("boolean_columns"),
            jsonb_columns=kw.get("jsonb_columns"),
            extra_columns=kw.get("extra_columns", {}),
        )

    return etl.Backend(
        ddl=types.SimpleNamespace(translate=translate, Options=options),
        rules=rules,
        mres=types.SimpleNamespace(to_json=to_json or stub_to_json),
        missing=list(missing or []),
    )


class EtlTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp(prefix="pgmigrate-test-")
        self.dump_path = os.path.join(self.tmp, "live.sql")
        with open(self.dump_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(DUMP)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write_dump(self, text: str) -> None:
        with open(self.dump_path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)

    def plan(self, out="out", **kw) -> etl.Plan:
        kw.setdefault("allow_decide", True)
        return etl.Plan(
            dump_path=self.dump_path,
            out_dir=os.path.join(self.tmp, out),
            report_path=os.path.join(self.tmp, f"{out}-report.json"),
            **kw,
        )

    def data_file(self, plan, table="players") -> str:
        with open(os.path.join(plan.out_dir, "data", f"{table}.copy"),
                  encoding="utf-8") as fh:
            return fh.read()


class TestHappyPath(EtlTestCase):
    def test_carries_rows_and_reconciles(self):
        report = etl.run(self.plan(), make_backend())
        # "rehearsal", not "ok": `mystery` is still DECIDE and was skipped under
        # --allow-decide, and a run that left a table behind must say so in the
        # artefact rather than only on the operator's terminal.
        self.assertEqual(report["status"], "rehearsal")
        self.assertTrue(report["reconciliation"]["ok"])
        self.assertEqual(report["waivers"],
                         {"allow_decide": True, "allow_undecided_policy": False})
        self.assertEqual(report["tables"]["players"]["rows_in"], 3)
        self.assertEqual(report["tables"]["players"]["rows_out"], 3)

    def test_dropped_table_is_not_emitted(self):
        plan = self.plan()
        report = etl.run(plan, make_backend())
        self.assertFalse(os.path.exists(
            os.path.join(plan.out_dir, "data", "houses.copy")))
        self.assertEqual(report["carried"], ["players"])

    def test_map_anchored_column_is_gone(self):
        plan = self.plan()
        report = etl.run(plan, make_backend())
        self.assertNotIn("position", report["output"]["tables"]["players"]["columns"])
        self.assertNotIn("[100,200,0]", self.data_file(plan))

    def test_bigint_beyond_double_exactness_is_carried_verbatim(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        self.assertIn("9007199254740993", self.data_file(plan))

    def test_exact_decimal_keeps_its_fourth_place(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        self.assertIn("1234567890.1234", self.data_file(plan))

    def test_currency_totals_balance_in_the_report(self):
        report = etl.run(self.plan(), make_backend())
        cash = report["currency"]["players.cash"]
        self.assertEqual(cash["in"], cash["out"])
        self.assertEqual(cash["in"], str(9007199254740993 + 25 + 0))
        self.assertFalse(cash["scaled_by_policy"])

    def test_encoded_column_becomes_json_not_the_old_codec(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        text = self.data_file(plan)
        self.assertIn('[["cop",1],["med",0]]', text)
        self.assertNotIn("`", text)

    def test_tinyint_flag_becomes_a_boolean(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        self.assertEqual(self.data_file(plan).splitlines()[0].split("\t")[5], "t")

    def test_apostrophe_survives_unescaped(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        self.assertIn("O'Brien", self.data_file(plan))

    def test_null_becomes_copy_null_marker(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        self.assertIn("\\N", self.data_file(plan).splitlines()[-1])

    def test_all_output_files_are_written(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        for name in ("schema.sql", "schema_post_load.sql", "ddl_report.txt",
                     "load.sql", "MANIFEST.json", "SHA256SUMS",
                     os.path.join("data", "players.copy"),
                     os.path.join("jsonl", "players.jsonl")):
            self.assertTrue(os.path.exists(os.path.join(plan.out_dir, name)), name)

    def test_jsonl_keeps_money_exact_and_never_as_a_float(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        with open(os.path.join(plan.out_dir, "jsonl", "players.jsonl"),
                  encoding="utf-8") as fh:
            first = json.loads(fh.readline())
        self.assertEqual(first["cash"], 9007199254740993)
        self.assertNotIsInstance(first["cash"], float)
        self.assertEqual(first["bank"], "1234567890.1234")

    def test_load_script_names_columns_explicitly(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        with open(os.path.join(plan.out_dir, "load.sql"), encoding="utf-8") as fh:
            body = fh.read()
        self.assertIn('\\copy "players" ("id", "uid", "name"', body)


class TestIdempotency(EtlTestCase):
    def test_two_runs_produce_identical_bytes(self):
        first, second = self.plan("a"), self.plan("b")
        etl.run(first, make_backend())
        etl.run(second, make_backend())
        for name in ("schema.sql", "load.sql", "MANIFEST.json",
                     os.path.join("data", "players.copy"),
                     os.path.join("jsonl", "players.jsonl")):
            with open(os.path.join(first.out_dir, name), "rb") as fh:
                a = fh.read()
            with open(os.path.join(second.out_dir, name), "rb") as fh:
                b = fh.read()
            self.assertEqual(a, b, f"{name} differs between runs")

    def test_report_has_no_timestamp(self):
        plan = self.plan()
        etl.run(plan, make_backend())
        with open(plan.report_path, encoding="utf-8") as fh:
            body = fh.read()
        for word in ("timestamp", "generated_at", "started", "finished"):
            self.assertNotIn(word, body)


class TestRefusals(EtlTestCase):
    def test_unresolved_table_stops_the_run(self):
        with self.assertRaises(TransformError) as ctx:
            etl.run(self.plan(allow_decide=False), make_backend())
        self.assertIn("UNRESOLVED TABLES", ctx.exception.issue.message)
        self.assertIn("mystery", ctx.exception.issue.message)

    def test_unresolved_table_is_listed_even_when_allowed(self):
        report = etl.run(self.plan(), make_backend())
        self.assertEqual(report["unresolved"], ["mystery"])

    def test_table_with_no_policy_entry_is_an_error(self):
        backend = make_backend()
        del backend.rules.CARRY["houses"]
        with self.assertRaises(TransformError):
            etl.run(self.plan(), backend)

    def test_row_count_mismatch_refuses_and_leaves_output_unpromoted(self):
        """A writer that loses a line must not be able to report success."""
        real_write = etl.CopyWriter.write

        def lossy(self, cells, record=None):
            if self.rows == 1:
                self.rows += 1          # count a row that was never written
                return
            return real_write(self, cells, record)

        plan = self.plan()
        etl.CopyWriter.write = lossy
        try:
            with self.assertRaises(etl.ReconciliationError) as ctx:
                etl.run(plan, make_backend())
        finally:
            etl.CopyWriter.write = real_write
        self.assertIn("data file", str(ctx.exception))
        self.assertFalse(os.path.exists(
            os.path.join(plan.out_dir, "data", "players.copy")))
        self.assertFalse(os.path.exists(os.path.join(plan.out_dir, "schema.sql")))

    def test_report_is_written_even_when_the_run_is_refused(self):
        def explode(text, **kw):
            raise error("players", "licences", kw.get("pk"), "deliberate")

        plan = self.plan()
        with self.assertRaises(etl.ReconciliationError):
            etl.run(plan, make_backend(to_json=explode))
        with open(plan.report_path, encoding="utf-8") as fh:
            report = json.load(fh)
        self.assertEqual(report["status"], "failed")
        self.assertIn("deliberate", report["reconciliation"]["failures"][0])

    def test_currency_as_a_float_is_rejected(self):
        def float_scale(table, column, pk, value, *, scale=None):
            return float(value)

        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), make_backend(scale=float_scale))
        self.assertIn("float", str(ctx.exception))

    def test_a_scale_that_moves_money_is_reported_not_hidden(self):
        def halve(table, column, pk, value, *, scale=None):
            return int(Decimal(str(value)) / 2) if "." not in str(value) else value

        report = etl.run(self.plan(), make_backend(scale=halve))
        self.assertTrue(report["currency"]["players.cash"]["scaled_by_policy"])
        self.assertNotEqual(report["currency"]["players.cash"]["in"],
                            report["currency"]["players.cash"]["out"])

    def test_unreadable_encoded_value_stops_the_run(self):
        self.write_dump(DUMP.replace("`[[`cop`,0]]`", "not-an-array"))
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), make_backend())
        self.assertIn("did not decode", str(ctx.exception))

    def test_rows_with_different_column_sets_are_an_error(self):
        self.write_dump(DUMP + (
            "INSERT INTO `players` (`id`,`uid`,`cash`) VALUES (4,'765',1);\n"))
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), make_backend())
        # Caught at the first rule that needs a column the short row lacks —
        # which is the point: nothing downstream gets to line values up by
        # ordinal and carry on.
        self.assertIn("the row does not have it", str(ctx.exception))

    def test_tinyint_holding_a_non_flag_is_an_error(self):
        self.write_dump(DUMP.replace(",'[1,2,3]',0,", ",'[1,2,3]',9,"))
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), make_backend())
        self.assertIn("not a boolean", str(ctx.exception))

    def test_an_empty_string_in_a_flag_column_is_an_error_not_false(self):
        """An empty value is a value nobody decided the rule for.

        It used to coerce to `False`, silently — and `false` is a guess with a
        player-visible consequence (an empty `casino_banned` reads as "not
        banned"). This file's whole job is that a value is never defaulted
        without an Issue.
        """
        self.write_dump(DUMP.replace(",'[1,2,3]',0,", ",'[1,2,3]','',"))
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), make_backend())
        self.assertIn("not a boolean", str(ctx.exception))

    def test_dropped_tables_are_counted_not_reported_as_empty(self):
        """`rows_in: 0` for a dropped table hides three different situations."""
        report = etl.run(self.plan(), make_backend())
        houses = report["tables"]["houses"]
        self.assertEqual((houses["rows_in"], houses["rows_dropped"],
                          houses["rows_out"]), (1, 1, 0))
        mystery = report["tables"]["mystery"]      # undecided, also not carried
        self.assertEqual((mystery["rows_in"], mystery["rows_dropped"]), (1, 1))

    def test_nul_byte_in_a_value_is_an_error_not_a_silent_strip(self):
        self.write_dump(DUMP.replace("'Ada'", r"'A\0da'"))
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), make_backend())
        self.assertIn("NUL", str(ctx.exception))

    def test_a_target_column_nothing_supplies_is_an_error(self):
        """Checked against the schema that was EMITTED, not against the source.

        The column the target insists on and the carry-over does not write is a
        load that fails on its first row — late, after the slow part, and only
        visible at `psql` time unless something compares the two here.
        """
        backend = make_backend(
            carry={"players": StubCarry(
                mode="carry_transform", natural_key=("uid",),
                drop=("position", "uid"),   # uid is NOT NULL in the target
                transcode={"licences": "jsonb"}, booleans=("isswat",),
                currency=("cash", "bank"),
            )},
            not_null=[("players", "uid")],
        )
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), backend)
        self.assertIn("nothing in the carry-over supplies it", str(ctx.exception))

    def test_a_copy_column_the_target_lacks_is_an_error(self):
        """The bug this check exists for: the policy adds a column, the schema does not.

        Every internal check passed on output whose very first `\\copy` line
        PostgreSQL refuses, because `ddl` was only ever handed the SOURCE DDL.
        """
        backend = make_backend(carry={"players": StubCarry(
            mode="carry_transform", natural_key=("uid",),
            drop=("position",), transcode={"licences": "jsonb"},
            booleans=("isswat",), currency=("cash", "bank"),
            # declared as an added column, but the stub DDL is told nothing:
            add_columns={}, defaults={"cyberdeck_modules": "[]"},
        )})
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), backend)
        self.assertIn("translated schema has no such column", str(ctx.exception))

    def test_an_added_column_reaches_the_schema_and_the_copy_header(self):
        backend = make_backend(carry={"players": StubCarry(
            mode="carry_transform", natural_key=("uid",),
            drop=("position",), transcode={"licences": "jsonb"},
            booleans=("isswat",), currency=("cash", "bank"),
            add_columns={"cyberdeck_modules": "jsonb NOT NULL DEFAULT '[]'::jsonb"},
            defaults={"cyberdeck_modules": "[]"},
        )})
        plan = self.plan()
        report = etl.run(plan, backend)
        self.assertTrue(report["reconciliation"]["ok"])
        self.assertIn("cyberdeck_modules",
                      report["output"]["tables"]["players"]["columns"])
        with open(os.path.join(plan.out_dir, "schema.sql"), encoding="utf-8") as fh:
            self.assertIn("cyberdeck_modules", fh.read())

    def test_missing_backend_module_refuses_before_reading_anything(self):
        backend = make_backend(missing=["rules.py could not be imported"])
        with self.assertRaises(TransformError) as ctx:
            etl.run(self.plan(), backend)
        self.assertIn("cannot run", ctx.exception.issue.message)


class TestDroppedRows(EtlTestCase):
    def test_excluded_rows_and_their_money_are_accounted_for(self):
        def exclude(row, table):
            return row.values["name"] == "Ada"

        report = etl.run(self.plan(), make_backend(exclude_row=exclude))
        self.assertEqual(report["status"], "rehearsal")
        self.assertEqual(report["tables"]["players"]["rows_out"], 2)
        self.assertEqual(report["tables"]["players"]["rows_dropped"], 1)
        cash = report["currency"]["players.cash"]
        self.assertEqual(cash["dropped_with_rows"], "25")
        self.assertEqual(Decimal(cash["in"]),
                         Decimal(cash["out"]) + Decimal(cash["dropped_with_rows"]))


class TestCompensation(EtlTestCase):
    """Property that cannot carry is valued, credited, and accounted for.

    The orchestrator's half of it: the rows of a DROPPED table have to be read
    at all (they are not in the carried stream), the credit has to reach the
    right player's balance, and every unit valued has to be either applied or
    reported. A credit that quietly evaporates is the same class of failure as
    a lost row, and harder to notice.
    """

    def backend(self, valuer):
        return make_backend(
            carry={"houses": StubCarry(mode="drop", natural_key=("id",),
                                       compensate="houses.compensation")},
            compensation_policy=valuer)

    def test_a_dropped_tables_rows_are_valued_and_credited(self):
        plan = self.plan()
        report = etl.run(plan, self.backend(lambda source, row: 5000))
        comp = report["compensation"]
        self.assertTrue(comp["computed"])
        self.assertEqual(comp["per_source"], {"houses.compensation": "5000"})
        self.assertEqual(comp["total_applied"], "5000")
        self.assertEqual(comp["unmatched_players"], [])
        self.assertTrue(report["reconciliation"]["ok"])
        # 1234567890.1234 + 5000, exactly, in the owner's row.
        self.assertIn("1234572890.1234", self.data_file(plan))

    def test_the_credit_is_counted_as_money_in_not_waved_through(self):
        report = etl.run(self.plan(), self.backend(lambda source, row: 5000))
        bank = report["currency"]["players.bank"]
        self.assertEqual(Decimal(bank["out"]) - Decimal(bank["in"]), Decimal(5000))
        self.assertFalse(bank["scaled_by_policy"])

    def test_a_credit_with_nobody_to_pay_it_to_fails_the_run(self):
        self.write_dump(DUMP.replace(
            "INSERT INTO `houses` VALUES (1,'7656119800000001'",
            "INSERT INTO `houses` VALUES (1,'7656119800000099'"))
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(self.plan(), self.backend(lambda source, row: 5000))
        self.assertIn("no row in players", str(ctx.exception))

    def test_without_a_policy_nothing_is_paid_and_the_report_says_so(self):
        report = etl.run(self.plan(), make_backend(
            carry={"houses": StubCarry(mode="drop", natural_key=("id",),
                                       compensate="houses.compensation")}))
        self.assertFalse(report["compensation"]["computed"])
        self.assertIn("valued at nothing", report["compensation"]["note"])
        self.assertTrue(any("valued at NOTHING" in i["message"]
                            for i in report["issues"]))


class TestCopyEscaping(EtlTestCase):
    def test_tab_and_newline_are_escaped_so_columns_cannot_shift(self):
        self.write_dump(DUMP.replace("'Ada'", r"'a\tb\nc\\d'"))
        plan = self.plan()
        etl.run(plan, make_backend())
        lines = self.data_file(plan).splitlines()
        self.assertEqual(len(lines), 3)
        self.assertIn("a\\tb\\nc\\\\d", lines[1])

    def test_money_renders_as_its_exact_text(self):
        cell = etl.render_cell(
            Money.parse("9007199254740993", table="players", column="cash", pk=1),
            table="players", column="cash", pk=1, issues=[],
        )
        self.assertEqual(cell, "9007199254740993")

    def test_a_float_in_a_non_currency_column_warns(self):
        issues: list[Issue] = []
        etl.render_cell(1.5, table="t", column="c", pk=1, issues=issues)
        self.assertEqual(issues[0].severity, "warn")


if __name__ == "__main__":
    unittest.main(verbosity=2)
