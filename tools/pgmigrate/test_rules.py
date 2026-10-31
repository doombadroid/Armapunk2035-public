"""Tests for the carry-over policy in rules.py.

WHY THIS EXISTS
    rules.py is the file that decides what happens to every player's money,
    property and progression at the one irreversible moment in this project. Its
    failure mode is silence: a table nobody listed, a credit nobody computed, a
    balance that became a float on the way past. None of those raise on their
    own, and all of them are invisible in the output.

    So these tests assert the *refusals* as hard as the transformations — that an
    unlisted table is an error rather than a skip, that an unmade decision stops
    the run rather than defaulting, that money never becomes a float, and that at
    1:1 the scaling hook is exactly the identity function.

Usage:
    python3 tools/pgmigrate/test_rules.py            # stdlib only, no database
    python3 -m unittest discover -s tools/pgmigrate  # or via discovery

STATUS
    These test the policy mechanism, not the policy's correctness against real
    data — no live dump exists in this repo. A green run means the rules behave
    as written; it does not mean the rules match the live schema.
"""

from __future__ import annotations

import os
import sys
import unittest
from decimal import Decimal
from fractions import Fraction

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rules  # noqa: E402
import prices  # noqa: E402
from model import Issue, Row, TransformError  # noqa: E402


ALL_SOURCE_TABLES = sorted(rules.CARRY)


class DecisionStateMixin(unittest.TestCase):
    """Every test starts from "nothing decided" and leaves it that way.

    The decisions are module globals on purpose — there is exactly one carry-over
    and one set of answers — so a test that sets one must put it back, or the
    next test passes for the wrong reason.
    """

    def setUp(self) -> None:
        self._saved = (
            rules.COMPENSATION_POLICY,
            rules.COMPENSATION_ORDER,
            rules.BALANCE_SCALE,
            rules.BALANCE_SCALE_CONFIRMED,
            rules.BALANCE_ROUNDING,
            rules.FREEZE,
        )

    def tearDown(self) -> None:
        (rules.COMPENSATION_POLICY, rules.COMPENSATION_ORDER, rules.BALANCE_SCALE,
         rules.BALANCE_SCALE_CONFIRMED, rules.BALANCE_ROUNDING, rules.FREEZE) = self._saved

    def decide_everything(self, *, credit: int = 0, scale: str = "1") -> None:
        """Answer all four decisions so a test can look at something else."""
        rules.set_compensation_policy(lambda source, row: credit)
        rules.set_compensation_order(rules.AFTER_SCALING)
        rules.set_balance_scale(scale, rounding=rules.ROUND_HALF_UP_MODE)
        rules.set_freeze(rules.Freeze("2026-09-01T00:00:00Z", True, "2026-08-20"))

    def undecide_everything(self) -> None:
        """Put the module back to "nobody has answered anything".

        Needed since 2026-08-15, when the real answers were encoded in `rules`.
        Before that these tests could read the module's own state and find it
        blank; now the blank state has to be constructed, or the tests that prove
        the GATES work would silently stop testing anything — which is worse than
        them failing, because the gates are the whole reason the file has a
        sentinel instead of defaults.
        """
        rules.COMPENSATION_POLICY = rules.UNDECIDED
        rules.COMPENSATION_ORDER = rules.UNDECIDED
        rules.BALANCE_SCALE_CONFIRMED = rules.UNDECIDED
        rules.BALANCE_ROUNDING = rules.UNDECIDED
        rules.FREEZE = rules.UNDECIDED

    def with_decide_table(self, name: str = "zz_undecided_fixture") -> str:
        """Register a temporary DECIDE table, removed again on teardown.

        Every real table has an answer now, so a test about unanswered tables has
        to bring its own. Named with a `zz_` prefix so it sorts last and is
        obvious in any report that leaks it.
        """
        rules.CARRY[name] = rules.Carry(
            mode=rules.DECIDE,
            natural_key=("id",),
            reason="test fixture: an unanswered table",
            question="Does this fixture table carry? (nobody has said)",
        )
        self.addCleanup(rules.CARRY.pop, name, None)
        return name


class TestUnlistedTable(DecisionStateMixin):
    """The guard this module exists for: a table nobody dispositioned."""

    def test_table_missing_from_CARRY_is_an_error(self) -> None:
        issues = rules.check(["players", "brand_new_table"], allow_unresolved_tables=True,
                             allow_undecided_policy=True)
        errors = [i for i in issues if i.severity == "error"]
        self.assertEqual([i.table for i in errors], ["brand_new_table"])
        self.assertIn("no entry in CARRY", errors[0].message)

    def test_unlisted_table_raises_from_validate(self) -> None:
        self.decide_everything()
        with self.assertRaises(TransformError) as caught:
            rules.validate(ALL_SOURCE_TABLES + ["brand_new_table"])
        self.assertIn("brand_new_table", str(caught.exception))

    def test_rehearsal_mode_does_not_excuse_an_unlisted_table(self) -> None:
        # the waivers are for unmade product decisions, not for a hole in the
        # policy. A dump with an unknown table must fail even in rehearsal.
        with self.assertRaises(TransformError):
            rules.validate(["players", "brand_new_table"], allow_unresolved_tables=True,
                           allow_undecided_policy=True)

    def test_every_known_table_passes_in_rehearsal_mode(self) -> None:
        warnings = rules.validate(ALL_SOURCE_TABLES, allow_unresolved_tables=True,
                                  allow_undecided_policy=True)
        self.assertEqual(warnings, [])

    def test_carry_entry_absent_from_the_dump_is_a_warning_not_an_error(self) -> None:
        issues = rules.check(["players"], allow_unresolved_tables=True,
                            allow_undecided_policy=True)
        self.assertTrue(all(i.severity == "warn" for i in issues), [str(i) for i in issues])
        self.assertIn("houses", [i.table for i in issues])


class TestUnmadeDecisionsBlockTheRun(DecisionStateMixin):

    def test_a_DECIDE_table_stops_validate(self) -> None:
        self.decide_everything()
        table = self.with_decide_table()
        with self.assertRaises(TransformError) as caught:
            rules.validate(list(ALL_SOURCE_TABLES) + [table])
        self.assertIn("unresolved product decision", str(caught.exception))

    def test_there_are_open_questions_and_each_has_one(self) -> None:
        self.with_decide_table()
        questions = rules.open_questions()
        self.assertTrue(questions, "DECIDE is only useful if it is actually used")
        for table, question in questions:
            self.assertTrue(question.strip(), "%s is DECIDE with no question" % table)

    def test_undecided_compensation_policy_blocks_a_dump_containing_property(self) -> None:
        self.undecide_everything()
        rules.set_compensation_order(rules.AFTER_SCALING)
        rules.set_balance_scale("1", rounding=rules.ROUND_HALF_UP_MODE)
        rules.set_freeze(rules.Freeze("2026-09-01T00:00:00Z", True, "2026-08-20"))
        issues = rules.check(["players", "houses"])
        self.assertIn("COMPENSATION_POLICY is UNDECIDED",
                      " ".join(i.message for i in issues if i.severity == "error"))

    def test_undecided_balance_scale_confirmation_blocks(self) -> None:
        self.undecide_everything()
        issues = rules.check(["players"])
        joined = " ".join(i.message for i in issues if i.severity == "error")
        self.assertIn("BALANCE_SCALE", joined)
        self.assertIn("decision, not an omission", joined)

    def test_undecided_freeze_blocks(self) -> None:
        self.undecide_everything()
        issues = rules.check(["players"])
        self.assertIn("<freeze>", [i.table for i in issues if i.severity == "error"])


class TestMapAnchoredRows(DecisionStateMixin):
    """Nothing anchored to the old map may reach the new one."""

    MAP_ANCHORED = (
        "houses", "storage", "suites", "house_rigs", "atm_skimmers",
        "vehicle_mem", "turf", "turf_state", "cartel_state", "captures",
    )

    def test_map_anchored_tables_do_not_carry(self) -> None:
        for table in self.MAP_ANCHORED:
            with self.subTest(table=table):
                self.assertFalse(rules.CARRY[table].carries)
                self.assertTrue(rules.CARRY[table].reason)

    def test_player_position_is_dropped_not_translated(self) -> None:
        self.assertIn("position", rules.CARRY["players"].drop)

    def test_gang_plot_is_dropped_but_the_gang_carries(self) -> None:
        gangs = rules.CARRY["gangs"]
        self.assertTrue(gangs.carries)
        self.assertIn("house_pos", gangs.drop)
        self.assertIn("bank", gangs.currency)

    def test_vehicles_carry_but_are_forced_out_of_the_world(self) -> None:
        for table in ("vehicles", "gang_vehicles"):
            with self.subTest(table=table):
                entry = rules.CARRY[table]
                self.assertTrue(entry.carries)
                self.assertIs(entry.force["active"], False)

    def test_a_forced_flag_must_be_a_bool_not_a_zero(self) -> None:
        # `assertEqual(0, False)` passes, which is exactly why this is `assertIs`
        # above and a construction-time refusal here: force runs AFTER the
        # boolean coercion, so an int survives it and reaches the output as `0`
        # where every other flag is `false`.
        with self.assertRaises(ValueError) as caught:
            rules.Carry(mode=rules.CARRY_TRANSFORM, booleans=("active",),
                        force={"active": 0})
        self.assertIn("forced flags must be True/False", str(caught.exception))

    def test_the_one_container_that_carries_is_the_non_spatial_one(self) -> None:
        vault = rules.CARRY["storage_vault"]
        self.assertTrue(vault.carries)
        self.assertEqual(vault.transcode["vinv"], rules.JSONB)
        self.assertEqual(vault.transcode["pinv"], rules.JSONB)


class TestTargetOnlyColumns(DecisionStateMixin):
    """A column the source has no counterpart for has to exist in the target."""

    def test_the_forks_own_column_is_added_and_the_sources_is_not(self) -> None:
        """Both halves of the same rule, checked against the LIVE schema.

        `cyberdeck_modules` is NOT added: live already has it, and adding a column
        the source declares is an error ddl reports. `qh_detonate_cd` IS added:
        live has never had it, nothing carries into it, and `APS_fnc_qhSRV` writes
        it on every detonate — a column the game writes and the schema lacks is an
        error per write, forever.
        """
        players = rules.CARRY["players"]
        self.assertNotIn("cyberdeck_modules", players.add_columns)
        self.assertIn("qh_detonate_cd", players.add_columns)
        self.assertNotIn("qh_detonate_cd", players.drop,
                         "it cannot be dropped and added at once, and there is no "
                         "value to drop: the source has never had the column")
        self.assertIn(("players", "qh_detonate_cd", players.add_columns["qh_detonate_cd"]),
                      rules.added_columns())

    def test_the_faction_rename_maps_live_names_to_fork_names(self) -> None:
        """Live has isswat/isdetective; the fork's SQF reads ismaxtac/isscd.

        Without the rename the new server queries columns the carried table does
        not have, and every MaxTac operator and SCD detective loses their role
        with no error anywhere.
        """
        rename = rules.CARRY["players"].rename
        self.assertEqual(rename.get("isswat"), "ismaxtac")
        self.assertEqual(rename.get("isdetective"), "isscd")
        # booleans name SOURCE columns: the transform types them before renaming
        self.assertIn("isswat", rules.CARRY["players"].booleans)
        self.assertIn("isdetective", rules.CARRY["players"].booleans)

    def test_a_default_for_a_column_with_no_declared_type_is_refused(self) -> None:
        # Without the type, `ddl` cannot emit the column — and the ETL then
        # writes a COPY header naming a column the schema does not have, which
        # every internal check passes and `psql` refuses on its first line.
        with self.assertRaises(ValueError) as caught:
            rules.Carry(mode=rules.CARRY_TRANSFORM, defaults={"new_col": "[]"})
        self.assertIn("no add_columns type declaration", str(caught.exception))

    def test_dropped_columns_are_reported_as_unpopulated_not_removed(self) -> None:
        # `drop` drops the VALUE, not the column: the target runs the same game
        # code on a different map and writes `position` itself.
        self.assertIn(("players", "position"), rules.unpopulated_columns())


class TestEncoding(DecisionStateMixin):

    def test_the_only_target_encoding_is_jsonb(self) -> None:
        for table, column in rules.transcoded_columns():
            with self.subTest(table=table, column=column):
                self.assertEqual(rules.CARRY[table].transcode[column], rules.JSONB)

    def test_the_property_destroying_columns_are_transcoded_or_dropped(self) -> None:
        # vinv/pinv/keyholders and their equivalents are the columns whose decode
        # failures have destroyed player property before. Every one of them either
        # leaves as JSONB or does not leave at all.
        for table, column in (("storage_vault", "vinv"), ("storage_vault", "pinv"),
                              ("houses", "vinv"), ("houses", "pinv"), ("houses", "keyholders"),
                              ("suites", "vinv"), ("suites", "pinv")):
            with self.subTest(table=table, column=column):
                entry = rules.CARRY[table]
                if entry.carries:
                    self.assertEqual(entry.transcode.get(column), rules.JSONB)
                else:
                    self.assertFalse(entry.carries)

    def test_a_non_jsonb_transcode_target_is_rejected_at_construction(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode=rules.CARRY_TRANSFORM, transcode={"gear": "text"})


class TestBooleanTyping(DecisionStateMixin):
    """§11.3: `1` vs `true` is the trap that produces a silently wrong UI."""

    def test_tinyint1_columns_that_are_not_flags_are_not_booleans(self) -> None:
        players = rules.CARRY["players"]
        # declared tinyint(1) but holds 0/1/2/3/9 — a boolean cast destroys it
        self.assertNotIn("intake_path", players.booleans)
        self.assertNotIn("intake_step", players.booleans)
        # a pending reward turning into `true` is a payout, not a type change
        self.assertNotIn("reward_pending", rules.CARRY["discord_links"].booleans)

    def test_real_flags_are_listed(self) -> None:
        self.assertIn("isswat", rules.CARRY["players"].booleans)


class TestCompensationMechanism(DecisionStateMixin):

    def house(self, uid: str, sale: int, oid: str = "H1") -> Row:
        return Row("houses", {"id": 7, "oid": oid, "owners": uid, "sale": sale, "classname": "shed"})

    def test_no_policy_is_a_refusal_not_a_zero(self) -> None:
        self.undecide_everything()
        with self.assertRaises(TransformError) as caught:
            rules.compute_compensation([self.house("76561190000000002", 100)])
        self.assertIn("UNDECIDED", str(caught.exception))

    def test_credits_are_summed_per_player_and_per_source(self) -> None:
        rules.set_compensation_policy(lambda source, row: int(row["sale"]))
        result = rules.compute_compensation([
            self.house("76561190000000002", 250_000, "H1"),
            self.house("76561190000000002", 750_000, "H2"),
            self.house("76561190000000042", 5, "H3"),
        ])
        self.assertEqual(result.credits, {"76561190000000002": 1_000_000, "76561190000000042": 5})
        self.assertEqual(result.per_source["houses.compensation"], 1_000_005)
        self.assertEqual(result.rows_seen["houses.compensation"], 3)

    def test_a_zero_policy_is_valid_and_explicit(self) -> None:
        rules.set_compensation_policy(lambda source, row: 0)
        result = rules.compute_compensation([self.house("76561190000000002", 250_000)])
        self.assertEqual(result.credits, {"76561190000000002": 0})

    def test_a_float_credit_is_an_error(self) -> None:
        rules.set_compensation_policy(lambda source, row: float(row["sale"]) * 0.5)
        with self.assertRaises(TransformError) as caught:
            rules.compute_compensation([self.house("76561190000000002", 250_000)])
        self.assertIn("exact-integer", str(caught.exception))
        self.assertIn("houses", str(caught.exception))

    def test_a_negative_credit_is_an_error(self) -> None:
        rules.set_compensation_policy(lambda source, row: -1)
        with self.assertRaises(TransformError):
            rules.compute_compensation([self.house("76561190000000002", 1)])

    def test_a_row_from_an_uncompensated_table_is_an_error(self) -> None:
        rules.set_compensation_policy(lambda source, row: 0)
        with self.assertRaises(TransformError) as caught:
            rules.compute_compensation([Row("log", {"id": 1})])
        self.assertIn("not registered as a compensation source", str(caught.exception))

    def test_a_row_from_a_table_with_no_disposition_is_an_error(self) -> None:
        rules.set_compensation_policy(lambda source, row: 0)
        with self.assertRaises(TransformError) as caught:
            rules.compute_compensation([Row("brand_new_table", {"id": 1})])
        self.assertIn("no CARRY entry", str(caught.exception))

    def test_an_unowned_row_is_counted_and_credited_to_nobody(self) -> None:
        rules.set_compensation_policy(lambda source, row: 999)
        result = rules.compute_compensation([
            Row("suites", {"id": 3, "oid": "LUX1F2", "owner": None, "floor": 2}),
        ])
        self.assertEqual(result.credits, {})
        self.assertEqual(result.rows_skipped_unowned["suites.compensation"], 1)
        self.assertEqual(result.rows_seen["suites.compensation"], 1)

    def test_an_owner_value_that_is_not_a_uid_fails_loud_naming_the_row(self) -> None:
        # houses.owners is declared varchar(17) but the repo's own migration notes
        # describe it as a nested-array string. Guessing would credit the wrong
        # player; the error names the table, column and pk instead.
        rules.set_compensation_policy(lambda source, row: 1)
        bad = Row("houses", {"id": 41, "oid": "H9", "owners": '[["76561190000000002",1]]', "sale": 1})
        with self.assertRaises(TransformError) as caught:
            rules.compute_compensation([bad])
        issue = caught.exception.issue
        self.assertEqual((issue.table, issue.column), ("houses", "owners"))
        self.assertEqual(issue.pk, (41, "H9"))
        self.assertIn("owner_parser", issue.message)

    def test_an_owner_parser_resolves_the_nested_form(self) -> None:
        import json

        source = rules.COMPENSATION_SOURCES["houses.compensation"]
        parsed = rules.CompensationSource(
            name=source.name, table=source.table, owner_column=source.owner_column,
            basis_columns=source.basis_columns, notes=source.notes,
            owner_parser=lambda raw: json.loads(raw)[0][0],
        )
        saved = rules.COMPENSATION_SOURCES["houses.compensation"]
        rules.COMPENSATION_SOURCES["houses.compensation"] = parsed
        try:
            rules.set_compensation_policy(lambda s, row: 42)
            result = rules.compute_compensation([
                Row("houses", {"id": 41, "oid": "H9", "owners": '[["76561190000000002",1]]', "sale": 1}),
            ])
            self.assertEqual(result.credits, {"76561190000000002": 42})
        finally:
            rules.COMPENSATION_SOURCES["houses.compensation"] = saved

    def test_storage_cannot_be_compensated_without_the_house_owner_map(self) -> None:
        # storage rows have no owner column at all — they are keyed to houseid,
        # and houses is dropped too. The mechanism refuses rather than crediting
        # a house id to a player, which is the shape of bug that pays the wrong
        # person and is only noticed by whoever did not get paid.
        rules.set_compensation_policy(lambda source, row: 1)
        with self.assertRaises(TransformError) as caught:
            rules.compute_compensation([
                Row("storage", {"id": 8, "houseid": 41, "classname": "box", "contents": "[]"}),
            ])
        self.assertIn("owner_parser", str(caught.exception))
        self.assertEqual(caught.exception.issue.column, "houseid")

    def test_every_registered_source_points_at_a_dropped_table(self) -> None:
        for name, source in rules.COMPENSATION_SOURCES.items():
            with self.subTest(source=name):
                entry = rules.CARRY[source.table]
                self.assertFalse(entry.carries)
                self.assertEqual(entry.compensate, name)


class TestBalanceScaling(DecisionStateMixin):

    def test_the_default_is_one_to_one(self) -> None:
        self.assertEqual(rules.BALANCE_SCALE, Fraction(1, 1))

    def test_at_one_to_one_an_integer_balance_is_untouched(self) -> None:
        # including above the 16,777,216 float-exact range, where a float path
        # would silently round and nothing would complain
        for value in (0, 1, 16_777_217, 9_223_372_036_854_775_807):
            with self.subTest(value=value):
                out = rules.scale_currency("players", "bankacc", "pid", value)
                self.assertEqual(out, value)
                self.assertIsInstance(out, int)

    def test_at_one_to_one_an_exact_decimal_round_trips_digit_for_digit(self) -> None:
        # plan §7.4: a 14-digit value with a non-zero fourth decimal
        value = Decimal("1234567890.1234")
        out = rules.scale_currency("players", "new_drachma", "pid", value)
        self.assertIsInstance(out, Decimal)
        self.assertEqual(str(out), "1234567890.1234")

    def test_exact_decimal_text_from_a_dump_round_trips_too(self) -> None:
        out = rules.scale_currency("players", "new_drachma", "pid", "1234567890.1234")
        self.assertEqual(str(out), "1234567890.1234")

    def test_a_float_balance_is_an_error_not_a_conversion(self) -> None:
        with self.assertRaises(TransformError) as caught:
            rules.scale_currency("players", "cash", "76561190000000002", 12345.0)
        issue = caught.exception.issue
        self.assertEqual((issue.table, issue.column, issue.pk),
                         ("players", "cash", "76561190000000002"))

    def test_a_bool_is_not_a_balance(self) -> None:
        with self.assertRaises(TransformError):
            rules.scale_currency("players", "cash", "pid", True)

    def test_a_float_scaling_factor_is_refused(self) -> None:
        with self.assertRaises(TypeError):
            rules.set_balance_scale(0.1)

    def test_a_scale_can_be_given_as_exact_text_or_a_ratio(self) -> None:
        rules.set_balance_scale("0.1", rounding=rules.ROUND_FLOOR_MODE)
        self.assertEqual(rules.BALANCE_SCALE, Fraction(1, 10))
        rules.set_balance_scale(Fraction(9, 10), rounding=rules.ROUND_FLOOR_MODE)
        self.assertEqual(rules.BALANCE_SCALE, Fraction(9, 10))

    def test_half_up_and_floor_disagree_where_it_matters(self) -> None:
        rules.set_balance_scale(Fraction(1, 2), rounding=rules.ROUND_HALF_UP_MODE)
        self.assertEqual(rules.scale_currency("players", "cash", "pid", 12_345), 6_173)
        rules.set_balance_scale(Fraction(1, 2), rounding=rules.ROUND_FLOOR_MODE)
        self.assertEqual(rules.scale_currency("players", "cash", "pid", 12_345), 6_172)

    def test_scaling_without_a_rounding_direction_is_refused(self) -> None:
        rules.BALANCE_SCALE = Fraction(1, 3)
        rules.BALANCE_ROUNDING = rules.UNDECIDED
        with self.assertRaises(TransformError) as caught:
            rules.scale_currency("players", "cash", "pid", 100)
        self.assertIn("BALANCE_ROUNDING is UNDECIDED", str(caught.exception))

    def test_scaling_a_decimal_quantizes_to_the_declared_column_scale(self) -> None:
        rules.set_balance_scale(Fraction(1, 3), rounding=rules.ROUND_FLOOR_MODE)
        out = rules.scale_currency("players", "new_drachma", "pid", Decimal("1.0000"))
        self.assertEqual(str(out), "0.3333")

    def test_an_exact_decimal_with_no_declared_scale_is_refused(self) -> None:
        with self.assertRaises(TransformError) as caught:
            rules.scale_currency("gangs", "bank", "1", Decimal("1.5"))
        self.assertIn("DECIMAL_SCALES", str(caught.exception))

    def test_scaled_columns_are_a_subset_of_currency_columns(self) -> None:
        currency = set(rules.currency_columns())
        for pair in rules.scaled_columns():
            self.assertIn(pair, currency)

    def test_currency_columns_only_come_from_tables_that_carry(self) -> None:
        for table, _column in rules.currency_columns():
            self.assertTrue(rules.CARRY[table].carries)


class TestCompensationOrder(DecisionStateMixin):

    def test_the_order_must_be_recorded(self) -> None:
        self.undecide_everything()
        rules.set_balance_scale(Fraction(1, 2), rounding=rules.ROUND_HALF_UP_MODE)
        with self.assertRaises(TransformError) as caught:
            rules.apply_compensation(table="players", column="bankacc", pk="pid",
                                     balance=1000, credit=100)
        self.assertIn("COMPENSATION_ORDER is UNDECIDED", str(caught.exception))

    def test_before_and_after_scaling_give_different_answers(self) -> None:
        rules.set_balance_scale(Fraction(1, 2), rounding=rules.ROUND_HALF_UP_MODE)
        rules.set_compensation_order(rules.BEFORE_SCALING)
        before = rules.apply_compensation(table="players", column="bankacc", pk="p",
                                          balance=1000, credit=100)
        rules.set_compensation_order(rules.AFTER_SCALING)
        after = rules.apply_compensation(table="players", column="bankacc", pk="p",
                                         balance=1000, credit=100)
        self.assertEqual(before, 550)
        self.assertEqual(after, 600)

    def test_a_float_credit_never_reaches_a_balance(self) -> None:
        rules.set_compensation_order(rules.AFTER_SCALING)
        with self.assertRaises(TransformError):
            rules.apply_compensation(table="players", column="bankacc", pk="p",
                                     balance=1000, credit=100.0)


class TestPolicyTableInvariants(DecisionStateMixin):
    """The policy file has to be internally consistent to be reviewable."""

    def test_every_entry_states_a_mode_and_a_key(self) -> None:
        for table, entry in rules.CARRY.items():
            with self.subTest(table=table):
                self.assertIn(entry.mode, rules.MODES)
                self.assertTrue(entry.natural_key, "%s has no natural key" % table)

    def test_every_drop_and_decide_says_why(self) -> None:
        for table in rules.tables_by_mode(rules.DROP) + rules.tables_by_mode(rules.DECIDE):
            with self.subTest(table=table):
                self.assertTrue(rules.CARRY[table].reason.strip())

    def test_a_drop_without_a_reason_cannot_be_constructed(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode=rules.DROP, natural_key=("id",))

    def test_a_decide_without_a_question_cannot_be_constructed(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode=rules.DECIDE, natural_key=("id",), reason="unresolved")

    def test_an_unknown_mode_cannot_be_constructed(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode="maybe")

    def test_carry_as_is_cannot_hide_a_transform(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode=rules.CARRY_AS_IS, drop=("position",))

    def test_a_column_cannot_be_both_dropped_and_transcoded(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode=rules.CARRY_TRANSFORM, drop=("gear",), transcode={"gear": rules.JSONB})

    def test_a_dropped_column_cannot_be_reconciled_as_currency(self) -> None:
        with self.assertRaises(ValueError):
            rules.Carry(mode=rules.CARRY_TRANSFORM, drop=("cash",), currency=("cash",))

    def test_compensation_names_resolve(self) -> None:
        for table, entry in rules.CARRY.items():
            if entry.compensate:
                with self.subTest(table=table):
                    self.assertIn(entry.compensate, rules.COMPENSATION_SOURCES)

    def test_the_two_social_tables_share_one_disposition(self) -> None:
        # looner_likes references looner_posts.post_id; carrying one without the
        # other leaves dangling likes or orphans a player's history.
        self.assertEqual(rules.CARRY["looner_posts"].mode, rules.CARRY["looner_likes"].mode)

    def test_tables_by_mode_rejects_an_unknown_mode(self) -> None:
        with self.assertRaises(ValueError):
            rules.tables_by_mode("carry_probably")

    def test_the_reconciliation_plan_covers_every_table_exactly_once(self) -> None:
        plan = rules.reconciliation_plan()
        self.assertEqual(sorted(p["table"] for p in plan), sorted(rules.CARRY))
        for entry in plan:
            with self.subTest(table=entry["table"]):
                self.assertIn(entry["disposition"], ("carry", "drop", "decide"))
                if entry["disposition"] == "drop":
                    # an empty output table must be expected on purpose, never
                    # merely observed
                    self.assertTrue(entry["reason"])

    def test_issues_are_model_Issues(self) -> None:
        for issue in rules.check(["players", "unknown_thing"]):
            self.assertIsInstance(issue, Issue)
            self.assertIn(issue.severity, ("error", "warn"))


class TestTheAnsweredDecisions(unittest.TestCase):
    """The six answers recorded in DECISIONS.md on 2026-08-15, as encoded.

    Deliberately NOT a DecisionStateMixin subclass: these read the module's real
    state, because the point is that the answers are actually installed. A test
    that set them up itself would pass against an empty rules.py.
    """

    def test_every_table_has_a_disposition(self) -> None:
        self.assertEqual(rules.open_questions(), [])

    def test_wanted_and_bounties_carry(self) -> None:
        self.assertTrue(rules.CARRY["wanted"].carries)
        self.assertTrue(rules.CARRY["bounties"].carries)
        self.assertIn("bounty", rules.CARRY["wanted"].currency)
        self.assertIn("amount", rules.CARRY["bounties"].currency)

    def test_sportsbook_bets_are_void_and_say_why(self) -> None:
        entry = rules.CARRY["sportsbook_bets"]
        self.assertFalse(entry.carries)
        self.assertIn("no refund", entry.reason)
        # the one answer that takes money without compensating it
        self.assertIsNone(entry.compensate)

    def test_the_money_decisions_are_installed(self) -> None:
        self.assertTrue(callable(rules.COMPENSATION_POLICY))
        self.assertEqual(rules.COMPENSATION_ORDER, rules.BEFORE_SCALING)
        self.assertEqual(rules.BALANCE_SCALE, Fraction(1, 1))
        self.assertIs(rules.BALANCE_SCALE_CONFIRMED, True)

    def test_rounding_stays_open_because_nothing_rounds_at_1_to_1(self) -> None:
        """Not an oversight. A factor change must hit the gate, not inherit this."""
        self.assertIs(rules.BALANCE_ROUNDING, rules.UNDECIDED)

    def test_the_freeze_is_answered_and_nothing_else_is_open(self) -> None:
        """Answered 2026-08-15: switchover 2026-09-11, maintenance window, told
        the day before. Pinned here because the date is the one answer players
        experience directly, and a silent change to it is a broken promise."""
        self.assertIsInstance(rules.FREEZE, rules.Freeze)
        self.assertEqual(rules.FREEZE.dump_taken_utc, "2026-09-11T14:00:00Z")
        self.assertTrue(rules.FREEZE.maintenance_window)
        self.assertEqual(rules.FREEZE.announced_on, "2026-09-10")
        self.assertLess(rules.FREEZE.announced_on, rules.FREEZE.dump_taken_utc[:10],
                        "players must be told BEFORE the freeze, not on it")
        errors = [i for i in rules.check(sorted(rules.CARRY)) if i.severity == "error"]
        self.assertEqual([str(i) for i in errors], [], "no gate should remain")

    def test_the_dev_dump_tables_all_have_a_disposition(self) -> None:
        """The eight tables the 2026-08-15 dev dump had and the policy did not.

        Pinned so a later edit cannot quietly drop one back out of the policy —
        an unlisted table is an error at run time, but only if somebody runs it.
        """
        for table in ("casino_chips", "casino_chip_pity", "maxsec_applications",
                      "offline_msgs", "houses_malden", "radio_schedule",
                      "enrique_log", "_backup_stats_declobber_462"):
            self.assertIn(table, rules.CARRY)
        self.assertTrue(rules.CARRY["casino_chips"].carries)
        self.assertFalse(rules.CARRY["_backup_stats_declobber_462"].carries)
        self.assertNotIn("qty", rules.CARRY["casino_chips"].currency,
                         "chips are counted items, not a denomination")


class TestPurchasePricePolicy(unittest.TestCase):
    """Decision 2: refund what the player paid, from the game's own config."""

    def test_a_house_refunds_its_config_price(self) -> None:
        credit = rules.purchase_price(
            "houses.compensation",
            {"oid": "H1", "classname": "Land_i_House_Big_01_V1_F"})
        self.assertEqual(credit, prices.HOUSE_BUY["Land_i_House_Big_01_V1_F"])

    def test_storage_upgrades_are_added_but_the_free_base_tier_is_not(self) -> None:
        cls = "Land_i_House_Big_01_V1_F"
        tiers = prices.HOUSE_PHYS_TIERS[cls]
        base_cap, tier1_cap, tier1_price = tiers[0][0], tiers[1][0], tiers[1][1]
        at_base = rules.purchase_price("houses.compensation",
                                       {"oid": "H1", "classname": cls, "phys_cap": base_cap})
        at_tier1 = rules.purchase_price("houses.compensation",
                                        {"oid": "H1", "classname": cls, "phys_cap": tier1_cap})
        self.assertEqual(at_base, prices.HOUSE_BUY[cls],
                         "the base cap is seeded free on purchase and must not be refunded")
        self.assertEqual(at_tier1 - at_base, tier1_price)

    def test_upgrades_and_key_slots_are_refunded(self) -> None:
        cls = "Land_i_House_Big_01_V1_F"
        row = {"oid": "H1", "classname": cls, "barrel": 1, "greenhouse": 1,
               "leadcontainer": 1, "keycap": 2}
        expected = (prices.HOUSE_BUY[cls]
                    + sum(prices.HOUSE_UPGRADES.values())
                    + sum(prices.KEY_SLOT_COSTS[:2]))
        self.assertEqual(rules.purchase_price("houses.compensation", row), expected)

    def test_the_asking_price_is_not_the_purchase_price(self) -> None:
        """`sale` is what the owner listed it for, not what they paid."""
        row = {"oid": "H1", "classname": "Land_i_House_Small_02_V1_F", "sale": 9_999_999}
        self.assertEqual(rules.purchase_price("houses.compensation", row),
                         prices.HOUSE_BUY["Land_i_House_Small_02_V1_F"])

    def test_an_unknown_house_raises_rather_than_refunding_nothing(self) -> None:
        with self.assertRaises(TransformError) as caught:
            rules.purchase_price("houses.compensation",
                                 {"oid": "H1", "classname": "Land_Not_A_House_F"})
        self.assertIn("no price in prices.py", str(caught.exception))

    def test_storage_crates_rigs_and_skimmers(self) -> None:
        self.assertEqual(
            rules.purchase_price("storage.compensation", {"classname": "Box_East_Support_F"}),
            prices.STORAGE_CRATE_BUY["Box_East_Support_F"])
        self.assertEqual(rules.purchase_price("house_rigs.compensation", {}), prices.RIG_BUY)
        self.assertEqual(rules.purchase_price("atm_skimmers.compensation", {}), prices.SKIMMER_BUY)

    def test_a_suite_lease_refunds_nothing_by_the_games_own_rule(self) -> None:
        self.assertEqual(rules.purchase_price("suites.compensation", {"floor": 3}), 0)

    def test_an_unpriced_source_raises_instead_of_paying_zero(self) -> None:
        with self.assertRaises(TransformError) as caught:
            rules.purchase_price("something_new.compensation", {})
        self.assertIn("no purchase price is defined", str(caught.exception))

    def test_every_registered_source_is_priced(self) -> None:
        """A source added without a price would fall through to the raise above —
        loudly, but on beta night. Catch it here instead."""
        for name in rules.COMPENSATION_SOURCES:
            try:
                rules.purchase_price(name, {"classname": "Land_i_House_Big_01_V1_F"})
            except TransformError as exc:      # a priced source may still reject a row
                self.assertNotIn("no purchase price is defined", str(exc), name)

    def test_the_price_table_is_not_stale(self) -> None:
        """prices.py is generated; a config price change must not go unnoticed."""
        import subprocess                                       # noqa: PLC0415
        here = os.path.dirname(os.path.abspath(__file__))
        result = subprocess.run(
            [sys.executable, os.path.join(here, "gen_prices.py"), "--check"],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0,
                         "prices.py is stale -- rerun tools/pgmigrate/gen_prices.py\n"
                         + result.stderr)


class TestExchangeReturnedToSellers(unittest.TestCase):
    """Decision 4: every open listing goes back to the player who listed it."""

    def rewrite(self, row):
        return rules.ROW_REWRITES["exchange.return_to_seller"](dict(row))

    def test_an_open_item_listing_becomes_exchange_storage(self) -> None:
        out = self.rewrite({"ID": 1, "active": 1, "isVehicle": 0, "BuyorSell": 0,
                            "pid": "7656119800000001", "ClassName": "pickaxe"})
        self.assertEqual(out["active"], 2)
        self.assertEqual(out["BuyorSell"], 2)
        self.assertEqual(out["pid"], "7656119800000001", "the seller must not change")

    def test_an_open_vehicle_listing_drops_because_the_car_carries(self) -> None:
        out = self.rewrite({"ID": 2, "active": 1, "isVehicle": 1, "VehicleID": 44})
        self.assertIsNone(out)
        self.assertIs(rules.CARRY["vehicles"].force["listed"], False,
                      "the vehicle only comes back if `listed` is forced off")

    def test_goods_already_bought_or_retracted_are_untouched(self) -> None:
        """active=2 rows are somebody's paid-for property awaiting collection."""
        row = {"ID": 3, "active": 2, "isVehicle": 0, "BuyorSell": 1, "pid": "765611980000002"}
        self.assertEqual(self.rewrite(row), row)

    def test_flags_are_read_loosely_because_dumps_vary(self) -> None:
        for active in (1, "1", True):
            out = self.rewrite({"ID": 4, "active": active, "isVehicle": "0"})
            self.assertEqual(out["active"], 2, "active=%r" % (active,))


if __name__ == "__main__":
    unittest.main(verbosity=2)


def test_altis_house_classnames_have_prices():
    """The refund route prices ALTIS houses (the source map). The first real dump
    (2026-09-07) carried `Land_u_Addon_02_V1_F`, absent from the Malden config;
    gen_prices now folds the vendored Altis house config in for such classnames."""
    from pgmigrate import prices
    assert prices.HOUSE_BUY.get("Land_u_Addon_02_V1_F", 0) == prices.HOUSE_BUY["Land_i_Addon_02_V1_F"] > 0
    assert prices.HOUSE_BUY["Land_i_House_Big_01_V1_F"] == 150000   # Malden row still wins
