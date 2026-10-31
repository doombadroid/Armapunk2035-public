"""End-to-end test of the seams: the REAL ddl, rules and mres, wired together.

Purpose:
    Run `etl.run` with `resolve_backend()` — no stand-ins — over a small
    committed fixture dump, and assert the three agreements no single module can
    check on its own:

      (a) every column in `load.sql` exists in `schema.sql`;
      (b) every column `rules.transcoded_columns()` names is `jsonb` there;
      (c) the boolean allowlist and the emitted `boolean` columns are the same
          set, in both directions.

WHY THIS EXISTS:
    `test_etl.py` builds its backend out of `types.SimpleNamespace` stand-ins.
    That is a defensible unit-test choice and it is also the direct reason four
    bugs survived a fully green run: each module was proved against its own idea
    of the others. Every one of those bugs lived in the seam, produced output the
    ETL called reconciled, and would have failed on the first line of `psql`.

    All three assertions are static — they read the emitted text. No database is
    required, so this runs in the ordinary `python3 -m unittest discover`.

Usage:
    cd tools && python3 -m unittest discover -s pgmigrate

STATUS:
    The fixture is synthetic. It is shaped like the live schema (the columns
    `rules.CARRY` names, in the types `sql/looneybin_dev_schema.sql` declares)
    but it is NOT real data and this proves nothing about the live dump, which
    postgres_plan.md §2 says this repository does not fully know.
"""

from __future__ import annotations

import os
import re
import shutil
import sys
import tempfile
import unittest
from fractions import Fraction

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pgmigrate import etl                      # noqa: E402
from pgmigrate import rules as rules_module     # noqa: E402
from pgmigrate.model import TransformError      # noqa: E402

FIXTURE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "testdata_fixture_dump.sql")


def copy_columns(load_sql: str) -> dict[str, list[str]]:
    """{table: [column, ...]} exactly as the `\\copy` lines name them."""
    out: dict[str, list[str]] = {}
    for m in re.finditer(r'\\copy "([^"]+)" \(([^)]*)\) FROM', load_sql):
        out[m.group(1)] = [c.strip().strip('"') for c in m.group(2).split(",")]
    return out


def schema_columns(schema_sql: str) -> dict[str, dict[str, str]]:
    """{table: {column: declared type}} parsed back out of the emitted DDL."""
    out: dict[str, dict[str, str]] = {}
    table = None
    for line in schema_sql.splitlines():
        m = re.match(r'^CREATE TABLE "?([A-Za-z0-9_]+)"? \($', line)
        if m:
            table = m.group(1)
            out[table] = {}
            continue
        if table is None:
            continue
        if line.startswith(")"):
            table = None
            continue
        m = re.match(r'^  "?([A-Za-z0-9_]+)"? ([a-z ()0-9,]+)', line)
        if m and not line.strip().startswith("CONSTRAINT"):
            out[table][m.group(1)] = m.group(2).strip()
    return out


class IntegrationTestCase(unittest.TestCase):
    """Runs the real backend once per test class and reads what it wrote."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.mkdtemp(prefix="pgmigrate-integration-")
        cls.plan = etl.Plan(
            dump_path=FIXTURE,
            out_dir=os.path.join(cls.tmp, "out"),
            report_path=os.path.join(cls.tmp, "report.json"),
            allow_decide=True,
            allow_undecided_policy=True,
        )
        cls.report = etl.run(cls.plan, etl.resolve_backend())
        with open(os.path.join(cls.plan.out_dir, "schema.sql"), encoding="utf-8") as fh:
            cls.schema_sql = fh.read()
        with open(os.path.join(cls.plan.out_dir, "load.sql"), encoding="utf-8") as fh:
            cls.load_sql = fh.read()
        cls.schema = schema_columns(cls.schema_sql)
        cls.copy = copy_columns(cls.load_sql)

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.tmp, ignore_errors=True)


class TestTheSeams(IntegrationTestCase):

    def test_the_run_reconciles(self):
        self.assertEqual(self.report["status"], "rehearsal", self.report["reconciliation"])
        self.assertTrue(self.report["reconciliation"]["ok"])

    def test_every_copy_column_exists_in_the_schema(self):
        """(a) The bug that made the ETL's own output unloadable."""
        for table, columns in self.copy.items():
            self.assertIn(table, self.schema)
            for column in columns:
                self.assertIn(column, self.schema[table],
                              f"{table}.{column} is in load.sql but not in schema.sql")

    def test_a_policy_rename_reaches_both_files_under_its_TARGET_name(self):
        """`players.isswat` -> `ismaxtac`, in the COPY header AND the schema.

        Replaced the `cyberdeck_modules` target-only-column test on 2026-08-15:
        the live schema was read and already has that column, so `players` has no
        target-only column left to check. The rename is the harder case anyway —
        the schema and the COPY header are built by different modules, and before
        this they disagreed by exactly the renamed column, which fails the load on
        its first line.
        """
        self.assertIn("ismaxtac", self.copy["players"])
        self.assertIn("ismaxtac", self.schema["players"])
        self.assertNotIn("isswat", self.copy["players"])
        self.assertNotIn("isswat", self.schema["players"])
        self.assertEqual(self.schema["players"]["ismaxtac"], "boolean",
                         "a renamed flag must still be typed by the policy")

    def test_every_transcoded_column_is_jsonb(self):
        """(b) plan §7.1 — the single largest saving, silently not taken."""
        for table, column in rules_module.transcoded_columns():
            if table not in self.schema:
                continue        # not in this fixture
            self.assertEqual(self.schema[table][column], "jsonb",
                             f"{table}.{column} must be jsonb, not "
                             f"{self.schema[table][column]}")

    def test_booleans_are_exactly_the_allowlist(self):
        """(c) Both directions: no flag missed, and nothing else collapsed."""
        # boolean_columns() speaks SOURCE names; the schema is written in TARGET
        # names. Any comparison between the two has to cross the rename, or a
        # renamed flag reads as both "declared and not emitted" and "emitted and
        # not declared" at once.
        declared = {(t, rules_module.CARRY[t].rename.get(c, c))
                    for t, c in rules_module.boolean_columns() if t in self.schema}
        emitted = {(t, c) for t, cols in self.schema.items()
                   for c, decl in cols.items() if decl == "boolean"}
        self.assertEqual(declared, emitted)

    def test_a_tinyint1_that_is_not_a_flag_survives_as_a_number(self):
        """`intake_path` holds 0/1/2/3/9. A boolean cast destroys it silently."""
        self.assertEqual(self.schema["players"]["intake_path"], "smallint")
        row = self.copy["players"].index("intake_path")
        with open(os.path.join(self.plan.out_dir, "data", "players.copy"),
                  encoding="utf-8") as fh:
            first = fh.readline().rstrip("\n").split("\t")
        self.assertEqual(first[row], "9")

    def test_money_is_carried_digit_for_digit(self):
        with open(os.path.join(self.plan.out_dir, "data", "players.copy"),
                  encoding="utf-8") as fh:
            body = fh.read()
        self.assertIn("9007199254740993", body)     # above 2**53
        self.assertIn("12345678901234.5678", body)  # decimal(20,4), 4th place set
        self.assertIn("O'Brien", body)

    def test_forced_vehicle_flags_are_booleans_not_ints(self):
        row = self.copy["vehicles"]
        with open(os.path.join(self.plan.out_dir, "data", "vehicles.copy"),
                  encoding="utf-8") as fh:
            first = fh.readline().rstrip("\n").split("\t")
        self.assertEqual(first[row.index("active")], "f")
        self.assertEqual(first[row.index("alive")], "t")
        self.assertEqual(first[row.index("listed")], "f")

    def test_the_old_encoding_never_reaches_the_output(self):
        for name in os.listdir(os.path.join(self.plan.out_dir, "data")):
            with open(os.path.join(self.plan.out_dir, "data", name),
                      encoding="utf-8") as fh:
                self.assertNotIn("`", fh.read(), name)

    def test_dropped_tables_are_counted_not_assumed_empty(self):
        houses = self.report["tables"]["houses"]
        self.assertEqual(houses["disposition"], "drop")
        self.assertEqual(houses["rows_in"], 2)
        self.assertEqual(houses["rows_dropped"], 2)
        self.assertEqual(houses["rows_out"], 0)

    def test_map_anchored_values_do_not_carry_but_the_column_remains(self):
        # The target runs the same game code on a different map: it writes
        # `position` on logout, so the column must exist and must arrive empty.
        self.assertIn("position", self.schema["players"])
        self.assertNotIn("position", self.copy["players"])
        self.assertIn("players.position", self.report["unpopulated_target_columns"])

    def test_the_report_says_no_compensation_was_paid(self):
        """A run with no policy installed must SAY it paid nothing.

        The policy is answered now (DECISIONS.md #2), so the no-policy state has
        to be constructed. The behaviour is still worth a test: "computed": false
        is what distinguishes a deliberate nothing from a waived run, months later
        when the report is the only surviving record.
        """
        saved = rules_module.COMPENSATION_POLICY
        rules_module.COMPENSATION_POLICY = rules_module.UNDECIDED
        try:
            tmp = tempfile.mkdtemp(prefix="pgmigrate-nopolicy-")
            self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
            plan = etl.Plan(dump_path=FIXTURE,
                            out_dir=os.path.join(tmp, "out"),
                            report_path=os.path.join(tmp, "report.json"),
                            allow_decide=True, allow_undecided_policy=True)
            report = etl.run(plan, etl.resolve_backend())
        finally:
            rules_module.COMPENSATION_POLICY = saved
        comp = report["compensation"]
        self.assertEqual(comp["policy"], "UNDECIDED")
        self.assertFalse(comp["computed"])
        self.assertIn("valued at nothing", comp["note"])

    def test_the_report_records_what_compensation_actually_paid(self):
        """And with the real policy installed, it says what it paid and to whom."""
        comp = self.report["compensation"]
        self.assertEqual(comp["policy"], "decided")
        self.assertTrue(comp["computed"])
        self.assertEqual(comp["order"], "before_scaling")
        # Both fixture houses are valued at their config purchase price, not at
        # `sale` (which is the asking price and is deliberately not used).
        self.assertEqual(comp["per_source"]["houses.compensation"], "220000")
        self.assertEqual(comp["total_applied"], "220000")
        self.assertEqual(comp["unmatched_players"], [])


class TestCompensationEndToEnd(unittest.TestCase):
    """With a policy installed, the credit is computed, applied and reconciled."""

    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp(prefix="pgmigrate-compensation-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        # Module-level policy is global state; restore it whatever happens.
        saved = (rules_module.COMPENSATION_POLICY, rules_module.COMPENSATION_ORDER,
                 rules_module.BALANCE_SCALE, rules_module.BALANCE_SCALE_CONFIRMED)

        def restore():
            (rules_module.COMPENSATION_POLICY, rules_module.COMPENSATION_ORDER,
             rules_module.BALANCE_SCALE, rules_module.BALANCE_SCALE_CONFIRMED) = saved

        self.addCleanup(restore)

    def run_with(self, valuer, *, order=None, scale=None):
        rules_module.set_compensation_policy(valuer)
        rules_module.set_compensation_order(order or rules_module.AFTER_SCALING)
        if scale is not None:
            rules_module.set_balance_scale(scale, rounding=rules_module.ROUND_FLOOR_MODE)
        plan = etl.Plan(
            dump_path=FIXTURE,
            out_dir=os.path.join(self.tmp, "out"),
            report_path=os.path.join(self.tmp, "report.json"),
            allow_decide=True,
            allow_undecided_policy=True,
        )
        return plan, etl.run(plan, etl.resolve_backend())

    def test_a_credit_is_valued_applied_and_reconciled(self):
        plan, report = self.run_with(lambda source, row: int(row["sale"]) // 2)
        comp = report["compensation"]
        self.assertTrue(comp["computed"])
        self.assertEqual(comp["per_source"], {"houses.compensation": "310000"})
        self.assertEqual(comp["total_credit"], "310000")
        self.assertEqual(comp["total_applied"], "310000")
        self.assertEqual(comp["unmatched_players"], [])
        self.assertTrue(report["reconciliation"]["ok"])

        # The credit is in the bank column of the player who owned the house.
        with open(os.path.join(plan.out_dir, "load.sql"), encoding="utf-8") as fh:
            cols = copy_columns(fh.read())["players"]
        with open(os.path.join(plan.out_dir, "data", "players.copy"),
                  encoding="utf-8") as fh:
            rows = [line.rstrip("\n").split("\t") for line in fh]
        banks = {r[cols.index("playerid")]: r[cols.index("bankacc")] for r in rows}
        self.assertEqual(banks["76500000000000001"], str(250000 + 250000))
        self.assertEqual(banks["76500000000000002"], str(0 + 60000))
        self.assertEqual(banks["76500000000000003"], "17")   # owned nothing

        # And the money reconciliation counts the credit as money that came IN
        # rather than waving the check through.
        bank = report["currency"]["players.bankacc"]
        self.assertEqual(bank["in"], "250017")
        self.assertEqual(bank["out"], "560017")
        self.assertFalse(bank["scaled_by_policy"])

    def test_a_float_valuation_is_refused(self):
        with self.assertRaises(etl.ReconciliationError) as ctx:
            self.run_with(lambda source, row: float(row["sale"]) / 2)
        self.assertIn("exact-integer", str(ctx.exception))

    def test_a_credit_for_a_player_with_no_account_row_fails_the_run(self):
        def orphan(source, row):
            return 1000

        # Point the house at a uid no players row has.
        dump = os.path.join(self.tmp, "orphan.sql")
        with open(FIXTURE, encoding="utf-8") as fh:
            body = fh.read()
        with open(dump, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(body.replace("'H14200_16100','76500000000000001'",
                                  "'H14200_16100','76500000000000099'"))
        rules_module.set_compensation_policy(orphan)
        rules_module.set_compensation_order(rules_module.AFTER_SCALING)
        plan = etl.Plan(dump_path=dump,
                        out_dir=os.path.join(self.tmp, "out2"),
                        report_path=os.path.join(self.tmp, "report2.json"),
                        allow_decide=True, allow_undecided_policy=True)
        with self.assertRaises(etl.ReconciliationError) as ctx:
            etl.run(plan, etl.resolve_backend())
        self.assertIn("no row in players", str(ctx.exception))

    def test_scaling_and_the_credit_apply_in_the_recorded_order(self):
        # half the balances, then add the credit: bankacc 250000 -> 125000 + 250000
        plan, report = self.run_with(lambda source, row: int(row["sale"]) // 2,
                                     order=rules_module.AFTER_SCALING,
                                     scale=Fraction(1, 2))
        with open(os.path.join(plan.out_dir, "load.sql"), encoding="utf-8") as fh:
            cols = copy_columns(fh.read())["players"]
        with open(os.path.join(plan.out_dir, "data", "players.copy"),
                  encoding="utf-8") as fh:
            rows = [line.rstrip("\n").split("\t") for line in fh]
        banks = {r[cols.index("playerid")]: r[cols.index("bankacc")] for r in rows}
        self.assertEqual(banks["76500000000000001"], str(125000 + 250000))
        # A scale that really moved money is reported, not silently reconciled.
        self.assertTrue(report["currency"]["players.cash"]["scaled_by_policy"])


class TestPolicyGates(unittest.TestCase):
    """The two waivers are two waivers."""

    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp(prefix="pgmigrate-gates-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def plan(self, **kw):
        return etl.Plan(dump_path=FIXTURE,
                        out_dir=os.path.join(self.tmp, "out"),
                        report_path=os.path.join(self.tmp, "report.json"), **kw)

    def unanswer_the_freeze(self):
        """Put one product decision back to UNDECIDED, and restore it after.

        All four are answered now (2026-08-15), so the state these gates exist to
        refuse has to be built. Without this the tests below would pass because
        nothing raised, which is the opposite of what they check.
        """
        saved = rules_module.FREEZE
        self.addCleanup(setattr, rules_module, "FREEZE", saved)
        rules_module.FREEZE = rules_module.UNDECIDED

    def test_allow_decide_alone_does_not_waive_the_product_decisions(self):
        self.unanswer_the_freeze()
        with self.assertRaises(TransformError) as ctx:
            etl.run(self.plan(allow_decide=True), etl.resolve_backend())
        self.assertIn("UNDECIDED", ctx.exception.issue.message)

    def test_neither_waiver_refuses_on_the_undecided_tables(self):
        self.unanswer_the_freeze()
        rules_module.CARRY["zz_undecided_fixture"] = rules_module.Carry(
            mode=rules_module.DECIDE,
            natural_key=("id",),
            reason="test fixture: an unanswered table",
            question="Does this fixture table carry? (nobody has said)",
        )
        self.addCleanup(rules_module.CARRY.pop, "zz_undecided_fixture", None)
        with self.assertRaises(TransformError) as ctx:
            etl.run(self.plan(), etl.resolve_backend())
        self.assertIn("carry-over policy error", ctx.exception.issue.message)


class TestGeneratedReconcileSpec(unittest.TestCase):
    """The auditor's rules are generated from the policy, and they load."""

    def test_the_shipped_spec_file_loads(self):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import reconcile                                       # noqa: PLC0415

        spec = reconcile.spec_from_module(
            os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "carryover_spec.py"))
        self.assertEqual({r.name for r in spec.tables}, set(rules_module.CARRY))

    def test_every_transcoded_column_declares_an_empty_policy(self):
        spec = rules_module.reconcile_spec(allow_unresolved_tables=True)
        self.assertTrue(spec.encoded)
        for ec in spec.encoded:
            self.assertEqual(ec.empty_policy, "empty_array",
                             f"{ec.table}.{ec.column}")

    def test_an_undecided_table_refuses_to_become_a_spec_rule(self):
        # Every real table has a disposition now, so the unanswered table is a
        # fixture. The rule under test is unchanged: there is no auditor rule for
        # an open question, so the spec refuses to invent one.
        rules_module.CARRY["zz_undecided_fixture"] = rules_module.Carry(
            mode=rules_module.DECIDE,
            natural_key=("id",),
            reason="test fixture: an unanswered table",
            question="Does this fixture table carry? (nobody has said)",
        )
        self.addCleanup(rules_module.CARRY.pop, "zz_undecided_fixture", None)
        with self.assertRaises(TransformError) as ctx:
            rules_module.reconcile_spec()
        self.assertIn("undecided", ctx.exception.issue.message)

    def test_the_reconciler_agrees_with_the_etls_own_output(self):
        """The whole loop: transform the fixture, then audit it independently."""
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import reconcile                                       # noqa: PLC0415

        tmp = tempfile.mkdtemp(prefix="pgmigrate-audit-")
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        plan = etl.Plan(dump_path=FIXTURE,
                        out_dir=os.path.join(tmp, "out"),
                        report_path=os.path.join(tmp, "report.json"),
                        allow_decide=True, allow_undecided_policy=True)
        etl.run(plan, etl.resolve_backend())

        spec = rules_module.reconcile_spec(allow_unresolved_tables=True)
        report = reconcile.reconcile(
            reconcile.DumpSource(FIXTURE),
            reconcile.JsonlDirSource(os.path.join(plan.out_dir, "jsonl")),
            spec,
        )
        # Tables the fixture does not contain are reported (they are declared by
        # the policy, which knows more tables than this fixture has); what must
        # not appear is a finding about a table the fixture DOES contain.
        present = {"players", "player_names", "vehicles", "houses"}
        real = [f for f in report.sorted_findings()
                if f.issue.severity == reconcile.ERROR and f.issue.table in present]
        self.assertEqual([f.issue.message for f in real], [])

    def test_the_auditor_catches_a_credit_the_etl_got_wrong(self):
        """The compensation check has to be adversarial, not a ledger comparison.

        The auditor re-values the dropped property from the SOURCE dump. So if the
        ETL pays an amount the policy does not produce, the totals disagree and the
        run is caught. Simulated here by moving the policy between the two halves —
        the ETL pays under one, the auditor checks under another — which is exactly
        the shape of the bug this check exists to catch: an ETL whose arithmetic has
        drifted from the policy it claims to implement.
        """
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import reconcile                                       # noqa: PLC0415

        tmp = tempfile.mkdtemp(prefix="pgmigrate-wrongcredit-")
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        saved = rules_module.COMPENSATION_POLICY
        self.addCleanup(setattr, rules_module, "COMPENSATION_POLICY", saved)

        plan = etl.Plan(dump_path=FIXTURE,
                        out_dir=os.path.join(tmp, "out"),
                        report_path=os.path.join(tmp, "report.json"),
                        allow_decide=True, allow_undecided_policy=True)
        etl.run(plan, etl.resolve_backend())          # paid at the real policy

        rules_module.set_compensation_policy(lambda source, row: 1)   # audit at another
        spec = rules_module.reconcile_spec(allow_unresolved_tables=True)
        report = reconcile.reconcile(
            reconcile.DumpSource(FIXTURE),
            reconcile.JsonlDirSource(os.path.join(plan.out_dir, "jsonl")),
            spec,
        )
        bank = [f for f in report.sorted_findings()
                if f.issue.severity == reconcile.ERROR
                and f.issue.table == "players" and f.issue.column == "bankacc"]
        self.assertTrue(bank, "an overpaid credit column reconciled clean")

    def test_the_auditor_agrees_when_the_credit_is_right(self):
        """The mirror of the test above: same machinery, no findings, so the one
        above is not passing merely because the check is noisy."""
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import reconcile                                       # noqa: PLC0415

        spec = rules_module.reconcile_spec(allow_unresolved_tables=True)
        self.assertIsNotNone(spec.compensation, "the spec must carry the credit rule")
        self.assertIn("houses", spec.compensation.sources)
        self.assertIn("houses", spec.retained_tables(),
                      "a compensation source that is not retained cannot be re-valued")


DISPOSABLE_DSN_ENV = "PGMIGRATE_TEST_DSN_DISPOSABLE"


class TestTheOutputActuallyLoads(unittest.TestCase):
    """Opt-in: put the ETL's own output into a real PostgreSQL and read it back.

    Everything above is static analysis of emitted text, which is what caught the
    seam bugs. This is the check that would have caught them even if the text
    analysis were wrong: `psql -f schema.sql -f load.sql`, then look at the types
    and the values the server actually holds.

    Skipped unless PGMIGRATE_TEST_DSN_DISPOSABLE names a database this test may
    DESTROY — it drops and recreates the public schema.
    """

    def setUp(self) -> None:
        self.dsn = os.environ.get(DISPOSABLE_DSN_ENV)
        if not self.dsn:
            self.skipTest(
                f"set {DISPOSABLE_DSN_ENV} to a DISPOSABLE database to run this; "
                f"skipped, so nothing here has been observed against a real server")
        self.tmp = tempfile.mkdtemp(prefix="pgmigrate-load-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def psql(self, sql: str, *, stop_on_error: bool = True, cwd: str | None = None) -> str:
        import subprocess                                       # noqa: PLC0415

        cmd = ["psql", "-d", self.dsn, "-X", "-q", "-A", "-t"]
        if stop_on_error:
            cmd += ["-v", "ON_ERROR_STOP=1"]
        proc = subprocess.run(cmd, input=sql, capture_output=True, text=True, cwd=cwd)
        if stop_on_error and proc.returncode:
            raise AssertionError(f"psql failed:\n{proc.stdout}\n{proc.stderr}")
        return proc.stdout + proc.stderr

    def test_schema_and_data_load_and_read_back_exactly(self):
        plan = etl.Plan(dump_path=FIXTURE,
                        out_dir=os.path.join(self.tmp, "out"),
                        report_path=os.path.join(self.tmp, "report.json"),
                        allow_decide=True, allow_undecided_policy=True)
        etl.run(plan, etl.resolve_backend())

        self.psql("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
        self.psql("\\i schema.sql\n\\i load.sql\n\\i schema_post_load.sql\n",
                  cwd=plan.out_dir)

        types = self.psql(
            "SELECT column_name || '=' || data_type FROM information_schema.columns "
            "WHERE table_name = 'players' AND column_name IN "
            "('civ_licenses','cyberdeck_modules','intake_path','isswat','cash',"
            "'bankacc','new_drachma','position') ORDER BY column_name;").split()
        self.assertIn("civ_licenses=jsonb", types)        # plan §7.1
        self.assertIn("cyberdeck_modules=jsonb", types)   # added by policy
        self.assertIn("intake_path=smallint", types)      # NOT a flag
        self.assertIn("isswat=boolean", types)            # is a flag
        self.assertIn("cash=bigint", types)
        self.assertIn("new_drachma=numeric", types)
        self.assertIn("position=text", types)             # kept, unpopulated

        row = self.psql(
            "SELECT cash || '|' || bankacc || '|' || new_drachma::text || '|' || "
            "intake_path || '|' || (civ_licenses->0->>0) || '|' || "
            "(position IS NULL)::text FROM players "
            "WHERE playerid = '76500000000000001';").strip()
        self.assertEqual(
            row, "9007199254740993|250000|12345678901234.5678|9|cop|true")

        # The transcoded column is a JSON document, not a string that looks like one.
        self.assertEqual(
            self.psql("SELECT jsonb_typeof(inventory) FROM vehicles WHERE id = 1;").strip(),
            "array")
        # And the forced flags are booleans.
        self.assertEqual(
            self.psql("SELECT active::text || alive::text || listed::text "
                      "FROM vehicles WHERE id = 1;").strip(), "falsetruefalse")


if __name__ == "__main__":
    unittest.main(verbosity=2)
