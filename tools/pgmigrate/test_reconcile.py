"""Tests for pgmigrate.reconcile.

PURPOSE
    Prove that each of the six checks actually catches the loss it is there to
    catch, by deliberately corrupting a known-good output one way at a time and
    asserting the specific finding comes back.

WHY THIS EXISTS
    A reconciliation that passes is indistinguishable from a reconciliation that
    is not looking. Every check below is therefore tested twice: once against a
    clean carry-over, where it must stay silent, and once against an output
    damaged in exactly the way that check exists to notice, where it must fail
    loud and name the row. Without the second half, this whole module could be
    `return Report()` and every rehearsal would still be green.

    The corruptions are chosen to be the ones a real ETL bug produces, not
    obvious ones: a player lost and another duplicated so the count still
    balances; money moved between two players so the total still balances; an
    integer emitted as 1.0; a decimal truncated in its fourth place.

SCOPE
    These fixtures are synthetic. They exercise the checks, NOT the schema —
    no dump of the live database exists in this workspace, so nothing here
    validates that the checks are pointed at the right tables and columns. That
    remains unproven until the first rehearsal against a real dump.

Usage:
    python3 -m unittest test_reconcile -v
    python3 test_reconcile.py
"""

from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import reconcile as R  # noqa: E402


# --------------------------------------------------------------------------
# Fixture: a small but realistic carry-over
# --------------------------------------------------------------------------

P1 = "76500000000000001"
P2 = "76500000000000002"
BANNED = "76500000000000009"

GEAR_TEXT = '"[[``item_a``,3],[``item_b``,1]]"'
GEAR_JSON = [["item_a", 3], ["item_b", 1]]


def source_data() -> dict:
    return {
        "players": [
            {
                "playerid": P1,
                "name": "O'Brien",
                "instance": 1,
                "cash": 1000,
                "new_drachma": R.NumericText("1000.5000"),
                "civ_gear": GEAR_TEXT,
                "position": '"[1,2,3]"',
                "gang0": 1,
            },
            {
                "playerid": P2,
                "name": "Second",
                "instance": 1,
                # deliberately above the float-exact range: 2**24 + 1
                "cash": 16777217,
                "new_drachma": R.NumericText("0.0001"),
                "civ_gear": "",
                "position": None,
                "gang0": None,
            },
            {
                "playerid": BANNED,
                "name": "Excluded",
                "instance": 1,
                "cash": 999,
                "new_drachma": R.NumericText("5.0000"),
                "civ_gear": '"[]"',
                "position": None,
                "gang0": None,
            },
        ],
        "gangs": [{"id": 1, "name": "Gang One"}],
        "vehicles": [
            {"id": 1, "pid": P1, "gang_id": 1, "house_id": None, "active": 1},
            {"id": 2, "pid": P2, "gang_id": None, "house_id": None, "active": 1},
            {"id": 3, "pid": BANNED, "gang_id": None, "house_id": None, "active": 0},
        ],
        "houses": [{"id": 5, "pid": P1}, {"id": 6, "pid": P2}],
        "log": [{"id": n} for n in range(5)],
    }


def output_data() -> dict:
    return {
        "players": [
            {
                "playerid": P1,
                "name": "O'Brien",
                "cash": 1000,
                "new_drachma": "1000.5000",
                "civ_gear": GEAR_JSON,
                "position": None,
                "gang0": 1,
            },
            {
                "playerid": P2,
                "name": "Second",
                "cash": 16777217,
                "new_drachma": "0.0001",
                "civ_gear": [],
                "position": None,
                "gang0": None,
            },
        ],
        "gangs": [{"id": 1, "name": "Gang One"}],
        "vehicles": [
            {"id": 1, "pid": P1, "gang_id": 1, "house_id": None, "active": 0},
            {"id": 2, "pid": P2, "gang_id": None, "house_id": None, "active": 0},
        ],
        "houses": [],
        "log": [],
    }


def make_spec(**over) -> R.ReconcileSpec:
    base = dict(
        tables=(
            R.TableRule("players", R.DISP_CARRY, primary_key=("playerid",),
                        player_id_column="playerid"),
            R.TableRule("gangs", R.DISP_CARRY, primary_key=("id",)),
            R.TableRule("vehicles", R.DISP_CARRY, primary_key=("id",),
                        player_id_column="pid"),
            R.TableRule("houses", R.DISP_DROP,
                        reason="worldspace is anchored to the old map"),
            R.TableRule("log", R.DISP_DROP, reason="append-only history, not carried"),
        ),
        identity=R.IdentityRule(
            table="players",
            column="playerid",
            exclusions={BANNED: "permanently banned before the carry-over"},
        ),
        currency=(
            R.CurrencyColumn("players", "cash", kind="integer"),
            R.CurrencyColumn("players", "new_drachma", kind="decimal", scale=4),
        ),
        encoded=(
            R.EncodingColumn("players", "civ_gear", exhaustive=True,
                             empty_policy="empty_array"),
        ),
        foreign_keys=(
            R.FKCheck("vehicles", "gang_id", "gangs", "id", nullable=True),
            R.FKCheck("vehicles", "house_id", "houses", "id", nullable=True),
        ),
        dropped_columns={("players", "instance"): "single-instance deployment"},
        allowed_null_columns={
            ("players", "position"): "spawn position is reset by the map change"
        },
        cross_check_decoder=False,
    )
    base.update(over)
    return R.ReconcileSpec(**base)


def run(src: dict, out: dict, spec: R.ReconcileSpec | None = None) -> R.Report:
    return R.reconcile(
        R.MappingSource(src, "test-source"),
        R.MappingSource(out, "test-output"),
        spec or make_spec(),
    )


def errors(rep: R.Report, check: str | None = None) -> list[R.Finding]:
    return [
        f
        for f in rep.sorted_findings()
        if f.issue.severity == R.ERROR and (check is None or f.check == check)
    ]


def messages(rep: R.Report, check: str | None = None) -> str:
    return "\n".join(f.issue.message for f in errors(rep, check))


# --------------------------------------------------------------------------


class TestCleanRun(unittest.TestCase):
    """The baseline every corruption test is measured against."""

    def test_clean_carry_over_produces_no_errors(self):
        rep = run(source_data(), output_data())
        self.assertEqual(
            rep.error_count,
            0,
            "\n".join(f.issue.format() for f in rep.sorted_findings()),
        )
        self.assertTrue(rep.ok)

    def test_every_check_actually_ran(self):
        rep = run(source_data(), output_data())
        for name in R.CHECK_NAMES:
            self.assertIn(name, rep.checks, f"{name} produced no section")
        self.assertEqual(len(rep.checks["currency"]["columns"]), 2)
        self.assertEqual(rep.checks["encoding"]["columns"][0]["checked"], 2)

    def test_excluded_player_is_expected_to_be_absent(self):
        rep = run(source_data(), output_data())
        table = {t["table"]: t for t in rep.checks["row_counts"]["tables"]}
        self.assertEqual(table["players"]["source"], 3)
        self.assertEqual(table["players"]["output"], 2)
        self.assertEqual(table["players"]["expected"], 2)


class TestRowCounts(unittest.TestCase):
    def test_a_table_the_spec_needs_and_the_dump_lacks_is_reported(self):
        # A warning, matching rules.check: the policy knows more tables than any
        # one box has. What must not happen is silence.
        src = source_data()
        del src["gangs"]
        out = output_data()
        out["gangs"] = []
        rep = run(src, out)
        warns = [f.issue.message for f in rep.sorted_findings()
                 if f.issue.severity == R.WARN and f.issue.table == "gangs"]
        self.assertTrue(any("no such table" in m for m in warns), warns)
        self.assertFalse(errors(rep, "row_counts"))

    def test_rows_for_a_table_the_source_never_had_are_an_error(self):
        src = source_data()
        del src["gangs"]
        rep = run(src, output_data())      # output still holds a gangs row
        self.assertIn("exist on no source side", messages(rep, "row_counts"))

    def test_missing_row_is_caught(self):
        out = output_data()
        out["vehicles"].pop()
        rep = run(source_data(), out)
        self.assertTrue(errors(rep, "row_counts"))
        self.assertIn("expects 2", messages(rep, "row_counts"))

    def test_dropped_table_that_still_has_rows_is_caught(self):
        out = output_data()
        out["houses"] = [{"id": 5, "pid": P1}]
        rep = run(source_data(), out)
        self.assertIn(
            "houses", [f.issue.table for f in errors(rep, "row_counts")]
        )

    def test_dropped_table_zero_is_expected_not_merely_observed(self):
        rep = run(source_data(), output_data())
        rows = {t["table"]: t for t in rep.checks["row_counts"]["tables"]}
        self.assertEqual(rows["houses"]["expected"], 0)
        self.assertEqual(rows["houses"]["disposition"], R.DISP_DROP)
        self.assertTrue(rows["houses"]["reason"])

    def test_a_drop_rule_without_a_reason_is_refused(self):
        with self.assertRaises(R.ReconcileConfigError):
            R.TableRule("houses", R.DISP_DROP)

    def test_undeclared_table_is_an_error(self):
        out = output_data()
        out["surprise"] = [{"id": 1}]
        rep = run(source_data(), out)
        self.assertIn("surprise", messages(rep, "row_counts"))

    def test_filter_expectation_is_derived_from_the_source(self):
        spec = make_spec(
            tables=(
                R.TableRule("players", R.DISP_CARRY, primary_key=("playerid",),
                            player_id_column="playerid"),
                R.TableRule("gangs", R.DISP_CARRY, primary_key=("id",)),
                R.TableRule(
                    "vehicles",
                    R.DISP_FILTER,
                    primary_key=("id",),
                    player_id_column="pid",
                    keep=lambda r: r["gang_id"] is not None,
                    reason="only gang vehicles carry",
                ),
                R.TableRule("houses", R.DISP_DROP, reason="map change"),
                R.TableRule("log", R.DISP_DROP, reason="history"),
            ),
        )
        rep = run(source_data(), output_data(), spec)
        rows = {t["table"]: t for t in rep.checks["row_counts"]["tables"]}
        self.assertEqual(rows["vehicles"]["expected"], 1)
        self.assertTrue(errors(rep, "row_counts"))

    def test_filter_rule_requires_a_predicate(self):
        with self.assertRaises(R.ReconcileConfigError):
            R.TableRule("vehicles", R.DISP_FILTER, primary_key=("id",))


class TestPlayerIdentity(unittest.TestCase):
    def test_lost_player_is_named_individually(self):
        out = output_data()
        out["players"] = [out["players"][0]]
        rep = run(source_data(), out)
        found = [f for f in errors(rep, "player_identity") if f.issue.pk == P2]
        self.assertEqual(len(found), 1, messages(rep, "player_identity"))
        self.assertIn("absent from the output", found[0].issue.message)

    def test_one_lost_and_one_duplicated_still_fails(self):
        """The count balances. Only a per-id check sees this."""
        out = output_data()
        out["players"] = [out["players"][0], copy.deepcopy(out["players"][0])]
        rep = run(source_data(), out)
        self.assertEqual(len(out["players"]), 2)  # count matches expectation
        self.assertFalse(errors(rep, "row_counts"), "row counts should balance here")
        pks = {f.issue.pk for f in errors(rep, "player_identity")}
        self.assertEqual(pks, {P1, P2})
        self.assertEqual(rep.checks["player_identity"]["lost"], [P2])
        self.assertEqual(rep.checks["player_identity"]["duplicated"], [P1])

    def test_invented_player_is_caught(self):
        out = output_data()
        ghost = copy.deepcopy(out["players"][0])
        ghost["playerid"] = "76500000000000777"
        out["players"].append(ghost)
        rep = run(source_data(), out)
        self.assertIn(
            "exists nowhere in the source", messages(rep, "player_identity")
        )

    def test_excluded_player_appearing_anyway_is_caught(self):
        out = output_data()
        revenant = copy.deepcopy(out["players"][0])
        revenant["playerid"] = BANNED
        out["players"].append(revenant)
        rep = run(source_data(), out)
        found = [f for f in errors(rep, "player_identity") if f.issue.pk == BANNED]
        self.assertTrue(found)
        self.assertIn("exclusion list", found[0].issue.message)

    def test_exclusion_without_a_reason_is_refused(self):
        with self.assertRaises(R.ReconcileConfigError):
            R.IdentityRule("players", "playerid", exclusions={P1: ""})


class TestCurrency(unittest.TestCase):
    def test_total_shortfall_is_caught(self):
        out = output_data()
        out["players"][0]["cash"] = 900
        rep = run(source_data(), out)
        msg = messages(rep, "currency")
        self.assertIn("delta -100", msg)
        self.assertIn("total is", msg)

    def test_money_moved_between_players_is_caught_despite_equal_total(self):
        """The classic keying bug. Totals conserve it perfectly."""
        out = output_data()
        out["players"][0]["cash"] = 0
        out["players"][1]["cash"] = 16777217 + 1000
        rep = run(source_data(), out)
        errs = errors(rep, "currency")
        self.assertTrue(errs)
        self.assertFalse(
            any("total is" in f.issue.message for f in errs),
            "the total is conserved; only the per-row check should fire",
        )
        self.assertEqual({f.issue.pk for f in errs}, {P1, P2})

    def test_exact_decimal_fourth_place_is_not_lost(self):
        out = output_data()
        out["players"][1]["new_drachma"] = "0.0000"
        rep = run(source_data(), out)
        self.assertIn("delta -0.0001", messages(rep, "currency"))

    def test_a_python_float_in_a_currency_column_is_refused(self):
        out = output_data()
        out["players"][0]["cash"] = 1000.0
        rep = run(source_data(), out)
        self.assertIn("float", messages(rep, "currency"))

    def test_a_json_float_literal_in_money_is_refused(self):
        out = output_data()
        out["players"][0]["cash"] = R.JsonFloat("1000.0")
        rep = run(source_data(), out)
        self.assertIn("JSON float literal", messages(rep, "currency"))

    def test_scientific_notation_is_refused_not_parsed(self):
        out = output_data()
        out["players"][1]["cash"] = "1.6777217e7"
        rep = run(source_data(), out)
        self.assertIn("scientific notation", messages(rep, "currency"))

    def test_large_balance_survives_exactly(self):
        rep = run(source_data(), output_data())
        col = [c for c in rep.checks["currency"]["columns"] if c["column"] == "cash"][0]
        self.assertEqual(col["output_total"], str(1000 + 16777217))
        self.assertEqual(col["source_total"], str(1000 + 16777217 + 999))
        self.assertEqual(col["expected_total"], str(1000 + 16777217))

    def test_scaling_is_applied_per_row_with_exact_integer_rounding(self):
        spec = make_spec(
            currency=(
                R.CurrencyColumn(
                    "players", "cash", kind="integer",
                    scaling=R.Scaling(1, 2, "half_up"),
                ),
                R.CurrencyColumn("players", "new_drachma", kind="decimal", scale=4),
            )
        )
        out = output_data()
        out["players"][0]["cash"] = 500
        out["players"][1]["cash"] = 8388609  # (2**24+1+1)//2, half-up
        rep = run(source_data(), out, spec)
        self.assertEqual(errors(rep, "currency"), [], messages(rep, "currency"))

    def test_scaling_rounding_modes_are_exact(self):
        self.assertEqual(R.Scaling(1, 2, "half_up").apply(5), 3)
        self.assertEqual(R.Scaling(1, 2, "half_even").apply(5), 2)
        self.assertEqual(R.Scaling(1, 2, "half_even").apply(7), 4)
        self.assertEqual(R.Scaling(1, 2, "floor").apply(5), 2)
        self.assertEqual(R.Scaling(1, 2, "half_up").apply(-5), -3)
        self.assertEqual(R.Scaling(1, 2, "floor").apply(-5), -3)
        self.assertEqual(R.Scaling(3, 1).apply(7), 21)

    def test_decimal_precision_beyond_the_column_scale_is_refused(self):
        with self.assertRaises(ValueError):
            R.decimal_to_units("1.00005", 4, table="players", column="new_drachma", pk=P1)
        # trailing zeros are not extra precision
        self.assertEqual(
            R.decimal_to_units("1.500000", 4, table="t", column="c", pk=1), 15000
        )

    def test_null_money_is_an_error(self):
        out = output_data()
        out["players"][0]["cash"] = None
        rep = run(source_data(), out)
        self.assertIn("NULL in a currency column", messages(rep, "currency"))


class TestEncoding(unittest.TestCase):
    def test_mangled_value_is_caught(self):
        out = output_data()
        out["players"][0]["civ_gear"] = [["item_a", 3]]
        rep = run(source_data(), out)
        errs = errors(rep, "encoding")
        self.assertTrue(errs)
        self.assertEqual(errs[0].issue.pk, P1)
        self.assertIn("length 2 vs 1", errs[0].issue.message)

    def test_quantity_change_inside_the_structure_is_caught(self):
        out = output_data()
        out["players"][0]["civ_gear"] = [["item_a", 30], ["item_b", 1]]
        rep = run(source_data(), out)
        self.assertIn("$[0][1]", messages(rep, "encoding"))

    def test_null_becoming_a_structure_is_caught(self):
        src = source_data()
        src["players"][0]["civ_gear"] = None
        out = output_data()
        rep = run(src, out)
        self.assertIn("source is NULL", messages(rep, "encoding"))

    def test_structure_becoming_null_is_caught(self):
        out = output_data()
        out["players"][0]["civ_gear"] = None
        rep = run(source_data(), out)
        self.assertIn("null mismatch", messages(rep, "encoding"))

    def test_empty_value_without_a_declared_policy_is_an_error(self):
        spec = make_spec(
            encoded=(R.EncodingColumn("players", "civ_gear", empty_policy=None),)
        )
        rep = run(source_data(), output_data(), spec)
        self.assertIn("no empty_policy", messages(rep, "encoding"))

    def test_empty_value_must_match_the_declared_policy(self):
        spec = make_spec(
            encoded=(R.EncodingColumn("players", "civ_gear", empty_policy="null"),)
        )
        rep = run(source_data(), output_data(), spec)
        self.assertIn("empty_policy", messages(rep, "encoding"))

    def test_property_columns_are_checked_exhaustively_not_sampled(self):
        """The one row a sample skips is the row that loses a player's property."""
        src = source_data()
        out = output_data()
        for n in range(20):
            pid = f"7650000000000{n:04d}"
            src["players"].append(
                {
                    "playerid": pid, "name": "x", "instance": 1, "cash": 0,
                    "new_drachma": R.NumericText("0.0000"),
                    "civ_gear": GEAR_TEXT, "position": None, "gang0": None,
                }
            )
            out["players"].append(
                {
                    "playerid": pid, "name": "x", "cash": 0,
                    "new_drachma": "0.0000",
                    "civ_gear": copy.deepcopy(GEAR_JSON),
                    "position": None, "gang0": None,
                }
            )
        # damage exactly one row that stride sampling would step over
        out["players"][4]["civ_gear"] = []
        rep = run(src, out)
        self.assertTrue(errors(rep, "encoding"))
        self.assertEqual(rep.checks["encoding"]["columns"][0]["skipped"], 0)

    def test_undecodable_source_value_is_reported_not_guessed(self):
        src = source_data()
        src["players"][0]["civ_gear"] = '"[[``item_a``,3]'
        rep = run(src, output_data())
        self.assertIn("cannot be decoded", messages(rep, "encoding"))

    def test_integer_emitted_as_a_float_literal_warns(self):
        out = output_data()
        out["players"][0]["civ_gear"] = [["item_a", R.JsonFloat("3.0")], ["item_b", 1]]
        rep = run(source_data(), out)
        self.assertEqual(errors(rep, "encoding"), [])
        warns = [f for f in rep.sorted_findings() if f.issue.severity == R.WARN]
        self.assertTrue(any("float literal" in f.issue.message for f in warns))

    def test_apostrophes_and_unicode_survive_the_decoder(self):
        value = ["O'Brien", "café", ""]
        text = '"' + json.dumps(value).replace('"', "``") + '"'
        self.assertEqual(R.decode_legacy_array(text), value)

    def test_decoder_agrees_with_the_transforms_own(self):
        """Cross-check: two independent decoders must not disagree."""
        if R.reference_decoder() is None:
            self.skipTest("the transform's decoder is not importable here")
        spec = make_spec(cross_check_decoder=True)
        rep = run(source_data(), output_data(), spec)
        divergences = [
            f for f in errors(rep, "encoding") if "divergence" in f.issue.message
        ]
        self.assertEqual(
            divergences, [], "\n".join(f.issue.message for f in divergences)
        )


class TestReferentialIntegrity(unittest.TestCase):
    def test_orphan_pointing_at_a_dropped_parent_is_caught(self):
        out = output_data()
        out["vehicles"][0]["house_id"] = 5
        rep = run(source_data(), out)
        msg = messages(rep, "referential_integrity")
        self.assertIn("houses was dropped", msg)
        self.assertIn("map", msg)

    def test_orphan_pointing_at_a_missing_row_is_caught(self):
        out = output_data()
        out["vehicles"][1]["gang_id"] = 99
        rep = run(source_data(), out)
        self.assertIn("does not exist in the output", messages(rep, "referential_integrity"))

    def test_clean_references_produce_no_findings(self):
        rep = run(source_data(), output_data())
        self.assertEqual(errors(rep, "referential_integrity"), [])

    def test_null_reference_in_a_not_null_relation_is_caught(self):
        spec = make_spec(
            foreign_keys=(
                R.FKCheck("vehicles", "gang_id", "gangs", "id", nullable=False),
            )
        )
        rep = run(source_data(), output_data(), spec)
        self.assertIn("NULL reference", messages(rep, "referential_integrity"))


class TestSkippedChecks(unittest.TestCase):
    """A check that did not run must be visible, not absent."""

    def test_a_carried_table_without_a_primary_key_says_so(self):
        spec = make_spec(tables=(
            R.TableRule("players", R.DISP_CARRY, primary_key=("playerid",),
                        player_id_column="playerid"),
            R.TableRule("gangs", R.DISP_CARRY, primary_key=("id",)),
            # no primary_key: nothing can pair its rows
            R.TableRule("vehicles", R.DISP_CARRY),
            R.TableRule("houses", R.DISP_DROP, reason="map change"),
            R.TableRule("log", R.DISP_DROP, reason="history"),
        ), foreign_keys=())
        rep = run(source_data(), output_data(), spec)
        warns = [f for f in rep.sorted_findings()
                 if f.issue.severity == R.WARN and f.check == "type_sanity"]
        self.assertTrue(any("SKIPPED" in f.issue.message and f.issue.table == "vehicles"
                            for f in warns), [f.issue.message for f in warns])
        self.assertIn({"table": "vehicles", "reason": "no primary_key in the rule"},
                      rep.checks["type_sanity"]["skipped"])

    def test_a_carried_table_with_a_key_is_retained_and_checked(self):
        # `gangs` names no currency and no encoded column: under the old rule it
        # was counted and never looked at.
        self.assertIn("gangs", make_spec().retained_tables())
        out = output_data()
        out["gangs"][0]["name"] = None
        rep = run(source_data(), out)
        self.assertIn("became NULL", messages(rep, "type_sanity"))


class TestTypeSanity(unittest.TestCase):
    def test_integer_becoming_a_float_is_caught(self):
        out = output_data()
        out["players"][0]["gang0"] = R.JsonFloat("1.0")
        rep = run(source_data(), out)
        self.assertIn("float literal", messages(rep, "type_sanity"))

    def test_python_float_where_an_integer_was_is_caught(self):
        out = output_data()
        out["vehicles"][0]["active"] = 0.0
        rep = run(source_data(), out)
        self.assertIn("Python float", messages(rep, "type_sanity"))

    def test_non_null_becoming_null_is_caught(self):
        out = output_data()
        out["players"][0]["name"] = None
        rep = run(source_data(), out)
        self.assertIn("became NULL", messages(rep, "type_sanity"))

    def test_declared_null_reset_is_allowed(self):
        rep = run(source_data(), output_data())
        self.assertEqual(errors(rep, "type_sanity"), [], messages(rep, "type_sanity"))

    def test_undeclared_dropped_column_is_caught(self):
        out = output_data()
        for row in out["players"]:
            del row["name"]
        rep = run(source_data(), out)
        self.assertIn("does not declare it dropped", messages(rep, "type_sanity"))

    def test_declared_dropped_column_is_silent(self):
        rep = run(source_data(), output_data())
        self.assertNotIn("instance", messages(rep, "type_sanity"))

    def test_null_becoming_a_value_warns(self):
        out = output_data()
        out["players"][1]["position"] = [0, 0, 0]
        rep = run(source_data(), out)
        warns = [f for f in rep.sorted_findings() if f.issue.severity == R.WARN]
        self.assertTrue(any(f.check == "type_sanity" for f in warns))


class TestStructureDiff(unittest.TestCase):
    def test_true_is_not_one(self):
        self.assertEqual(R.structure_diff(True, 1)[0], R.ERROR)
        self.assertEqual(R.structure_diff(1, True)[0], R.ERROR)

    def test_nested_dicts_compare_by_key(self):
        self.assertIsNone(R.structure_diff({"a": [1, 2]}, {"a": [1, 2]})[0])
        self.assertEqual(R.structure_diff({"a": 1}, {"b": 1})[0], R.ERROR)

    def test_exponent_form_of_a_whole_number_is_an_integer(self):
        self.assertEqual(R.decode_legacy_array('"[1e+015]"'), [1000000000000000])

    def test_genuine_fractions_compare_exactly(self):
        self.assertIsNone(R.structure_diff([R.NumericText("0.5")], [R.JsonFloat("0.5")])[0])
        self.assertEqual(
            R.structure_diff([R.NumericText("0.5")], [R.JsonFloat("0.6")])[0], R.ERROR
        )


# --------------------------------------------------------------------------
# The source reader
# --------------------------------------------------------------------------

DUMP = r"""
-- a dump fragment
/*!40101 SET NAMES utf8mb4 */;

DROP TABLE IF EXISTS `players`;
CREATE TABLE `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `playerid` varchar(17) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT 'Error',
  `cash` bigint(20) NOT NULL DEFAULT 0,
  `new_drachma` decimal(20,4) NOT NULL DEFAULT 0,
  `civ_gear` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `playerid` (`playerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

LOCK TABLES `players` WRITE;
INSERT INTO `players` VALUES (1,'76500000000000001','O\'Brien; the first',1000,1000.5000,'"[[``item_a``,3]]"'),(2,'76500000000000002','Second',16777217,0.0001,NULL);
UNLOCK TABLES;

DROP TABLE IF EXISTS `log`;
CREATE TABLE `log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `msg` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO `log` (`id`, `msg`) VALUES (1,'line one'),(2,'a ) and a ( and a ; inside');
"""


#: HOSTILE LITERALS — the contract between the two independent dump parsers.
#:
#: `reconcile` re-reads the source with its OWN parser so that a bug in the
#: transform's parser cannot cancel itself out. That independence is only worth
#: having if the two agree on what the bytes MEAN, and every disagreement here
#: surfaces as a false finding against real player data:
#:   * a doubled quote — a dump taken with NO_BACKSLASH_ESCAPES writes every
#:     apostrophe this way, and those are the names the source's sanitizers have
#:     been mangling for years, i.e. exactly the rows a human is then asked to
#:     adjudicate;
#:   * a hex literal — `mysqldump --hex-blob` is routine, and one parser keeping
#:     `0x…` while the other decodes it makes every such column mismatch;
#:   * `\%` / `\_` — MySQL keeps the backslash so LIKE patterns survive a
#:     dump/restore, and the transcoder REFUSES any value containing a backslash,
#:     so a parser that drops it decodes a value the ETL refused and the report
#:     blames the decoder for a parser bug.
#: Same fixture, two implementations, no shared code.
HOSTILE_LITERALS = [
    (r"O\'Brien", "O'Brien"),
    ("O''Brien", "O'Brien"),
    (r"tab\there", "tab\there"),
    (r"back\\slash", "back\\slash"),
    (r"like\%pattern", r"like\%pattern"),
    (r"like\_pattern", r"like\_pattern"),
    (r"quote\"inside", 'quote"inside'),
]


class TestParserAgreement(unittest.TestCase):
    """Two parsers, one meaning. Pinned by fixture, never by shared code."""

    def _dump_unescape(self, text: str) -> str:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import dump as D  # noqa: PLC0415 - imported here to keep the modules independent

        return D.unescape_mysql_string(text)

    def test_string_escapes_decode_identically(self):
        for raw, expected in HOSTILE_LITERALS:
            with self.subTest(raw=raw):
                self.assertEqual(R._unescape(raw), expected)
                self.assertEqual(self._dump_unescape(raw), expected)

    def test_hex_literals_decode_identically(self):
        path = os.path.join(tempfile.mkdtemp(prefix="pgmigrate-test-"), "hex.sql")
        with open(path, "wt", encoding="utf-8") as fh:
            fh.write(
                "CREATE TABLE `log` (\n  `id` int(11) NOT NULL,\n"
                "  `msg` text DEFAULT NULL,\n  PRIMARY KEY (`id`)\n);\n"
                "INSERT INTO `log` VALUES (1,0x48656C6C6F),(2,X'776F726C64');\n"
            )
        snap = R.DumpSource(path).snapshot({"log"})
        self.assertEqual([r["msg"] for r in snap.rows["log"]], ["Hello", "world"])

        import dump as D  # noqa: PLC0415

        self.assertEqual([r.values["msg"] for r in D.iter_rows(path)],
                         ["Hello", "world"])

    def test_a_non_utf8_hex_literal_is_refused_not_mojibaked(self):
        path = os.path.join(tempfile.mkdtemp(prefix="pgmigrate-test-"), "bin.sql")
        with open(path, "wt", encoding="utf-8") as fh:
            fh.write(
                "CREATE TABLE `log` (\n  `id` int(11) NOT NULL,\n"
                "  `msg` text DEFAULT NULL,\n  PRIMARY KEY (`id`)\n);\n"
                "INSERT INTO `log` VALUES (1,0xFFFE);\n"
            )
        with self.assertRaises(R.DumpParseError) as ctx:
            R.DumpSource(path).snapshot({"log"})
        self.assertIn("not valid UTF-8", str(ctx.exception))


class TestDumpReader(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="pgmigrate-test-")
        self.path = os.path.join(self.dir, "dump.sql")
        with open(self.path, "wt", encoding="utf-8") as fh:
            fh.write(DUMP)

    def test_counts_and_column_names(self):
        snap = R.DumpSource(self.path).snapshot({"players", "log"})
        self.assertEqual(snap.counts["players"], 2)
        self.assertEqual(snap.counts["log"], 2)
        self.assertEqual(
            snap.columns["players"],
            ["id", "playerid", "name", "cash", "new_drachma", "civ_gear"],
        )

    def test_values_are_keyed_by_name_and_never_floated(self):
        snap = R.DumpSource(self.path).snapshot({"players"})
        first = snap.rows["players"][0]
        self.assertEqual(first["playerid"], "76500000000000001")
        self.assertEqual(first["cash"], 1000)
        self.assertIsInstance(first["cash"], int)
        # above the float-exact range, and still exact
        self.assertEqual(snap.rows["players"][1]["cash"], 16777217)
        self.assertIsInstance(first["new_drachma"], R.NumericText)
        self.assertNotIsInstance(first["new_drachma"], float)
        self.assertEqual(
            R.decimal_to_units(first["new_drachma"], 4, table="players",
                               column="new_drachma", pk=1),
            10005000,
        )

    def test_escaped_quote_and_semicolon_inside_a_string(self):
        snap = R.DumpSource(self.path).snapshot({"players", "log"})
        self.assertEqual(snap.rows["players"][0]["name"], "O'Brien; the first")
        self.assertEqual(snap.rows["log"][1]["msg"], "a ) and a ( and a ; inside")

    def test_null_survives_as_null(self):
        snap = R.DumpSource(self.path).snapshot({"players"})
        self.assertIsNone(snap.rows["players"][1]["civ_gear"])

    def test_encoded_column_round_trips_out_of_the_dump(self):
        snap = R.DumpSource(self.path).snapshot({"players"})
        self.assertEqual(
            R.decode_legacy_array(snap.rows["players"][0]["civ_gear"]),
            [["item_a", 3]],
        )

    def test_explicit_column_list_is_honoured(self):
        snap = R.DumpSource(self.path).snapshot({"log"})
        self.assertEqual(snap.rows["log"][0], {"id": 1, "msg": "line one"})

    def test_arity_mismatch_refuses_to_align_by_position(self):
        path = os.path.join(self.dir, "bad.sql")
        with open(path, "wt", encoding="utf-8") as fh:
            fh.write(DUMP + "\nINSERT INTO `players` VALUES (3,'x');\n")
        with self.assertRaises(R.DumpParseError) as ctx:
            R.DumpSource(path).snapshot({"players"})
        self.assertIn("refusing to align by position", str(ctx.exception))

    def test_a_required_table_missing_from_the_dump_is_recorded(self):
        """Recorded, then reported as an error finding — not raised.

        A spec generated from the whole carry-over policy legitimately names
        tables a given source box has never had, and aborting the entire audit
        for one of them buys nothing. It still fails the run: see
        `TestRowCounts.test_a_table_the_spec_needs_and_the_dump_lacks_is_an_error`.
        """
        snap = R.DumpSource(self.path).snapshot({"players", "gangs"})
        self.assertEqual(snap.missing_tables, {"gangs"})
        self.assertEqual(snap.rows["gangs"], [])

    def test_gzip_dump_is_read(self):
        import gzip

        gz = os.path.join(self.dir, "dump.sql.gz")
        with gzip.open(gz, "wt", encoding="utf-8") as fh:
            fh.write(DUMP)
        self.assertEqual(R.DumpSource(gz).snapshot(set()).counts["players"], 2)


class TestJsonlOutput(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="pgmigrate-out-")

    def write(self, table: str, rows: list[dict]) -> None:
        with open(os.path.join(self.dir, f"{table}.jsonl"), "wt", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")

    def test_float_literals_are_labelled_not_silently_floated(self):
        self.write("players", [{"playerid": P1, "cash": 1000.0}])
        snap = R.JsonlDirSource(self.dir).snapshot({"players"})
        value = snap.rows["players"][0]["cash"]
        self.assertIsInstance(value, R.JsonFloat)
        self.assertNotIsInstance(value, float)

    def test_end_to_end_json_output_catches_float_money(self):
        rows = output_data()["players"]
        rows[0]["cash"] = 1000.0
        self.write("players", rows)
        self.write("gangs", output_data()["gangs"])
        self.write("vehicles", output_data()["vehicles"])
        rep = R.reconcile(
            R.MappingSource(source_data(), "src"),
            R.JsonlDirSource(self.dir),
            make_spec(),
        )
        self.assertIn("JSON float literal", messages(rep, "currency"))

    def test_malformed_output_line_is_fatal(self):
        with open(os.path.join(self.dir, "players.jsonl"), "wt", encoding="utf-8") as fh:
            fh.write("{not json}\n")
        with self.assertRaises(R.DumpParseError):
            R.JsonlDirSource(self.dir).snapshot({"players"})


class TestReport(unittest.TestCase):
    def test_report_is_byte_identical_across_runs(self):
        a = R.render_json(run(source_data(), output_data()), omit_run_meta=True)
        b = R.render_json(run(source_data(), output_data()), omit_run_meta=True)
        self.assertEqual(a, b)

    def test_report_is_valid_json_and_holds_no_floats(self):
        doc = R.render_json(run(source_data(), output_data()))
        parsed = json.loads(doc, parse_float=lambda s: (_ for _ in ()).throw(
            AssertionError(f"float in report: {s}")
        ))
        self.assertEqual(parsed["result"], "pass")
        self.assertEqual(parsed["counts"]["errors"], 0)

    def test_volatile_provenance_is_isolated(self):
        rep = run(source_data(), output_data())
        with_meta = json.loads(R.render_json(rep))
        without = json.loads(R.render_json(rep, omit_run_meta=True))
        self.assertIn("run", with_meta)
        self.assertNotIn("run", without)
        del with_meta["run"]
        self.assertEqual(with_meta, without)

    def test_two_rehearsals_differ_only_where_the_data_did(self):
        clean = json.loads(R.render_json(run(source_data(), output_data()),
                                         omit_run_meta=True))
        out = output_data()
        out["players"][0]["cash"] = 900
        dirty = json.loads(R.render_json(run(source_data(), out), omit_run_meta=True))
        self.assertEqual(clean["checks"]["encoding"], dirty["checks"]["encoding"])
        self.assertEqual(
            clean["checks"]["referential_integrity"],
            dirty["checks"]["referential_integrity"],
        )
        self.assertNotEqual(clean["checks"]["currency"], dirty["checks"]["currency"])

    def test_findings_are_sorted_stably(self):
        out = output_data()
        out["players"][0]["cash"] = 900
        out["players"][1]["name"] = None
        rep = run(source_data(), out)
        keys = [f.sort_key() for f in rep.sorted_findings()]
        self.assertEqual(keys, sorted(keys))

    def test_human_summary_names_the_result(self):
        out = output_data()
        out["players"][0]["cash"] = 900
        text = R.render_human(run(source_data(), out))
        self.assertIn("RESULT: FAIL", text)
        self.assertIn("currency", text)


class TestCli(unittest.TestCase):
    """The gate: reconcile must exit non-zero so a rehearsal script can stop."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="pgmigrate-cli-")
        self.dump = os.path.join(self.dir, "dump.sql")
        with open(self.dump, "wt", encoding="utf-8") as fh:
            fh.write(DUMP)
        self.out = os.path.join(self.dir, "out")
        os.makedirs(self.out)
        self.spec = os.path.join(self.dir, "spec.py")
        with open(self.spec, "wt", encoding="utf-8") as fh:
            fh.write(
                "from reconcile import (ReconcileSpec, TableRule, IdentityRule,\n"
                "                       CurrencyColumn, DISP_CARRY, DISP_DROP)\n"
                "RECONCILE_SPEC = ReconcileSpec(\n"
                "    tables=(TableRule('players', DISP_CARRY, primary_key=('playerid',)),\n"
                "            TableRule('log', DISP_DROP, reason='history is not carried')),\n"
                "    identity=IdentityRule('players', 'playerid'),\n"
                "    currency=(CurrencyColumn('players', 'cash'),),\n"
                "    dropped_columns={('players', 'id'): 'identity is regenerated',\n"
                "                     ('players', 'name'): 'names refreshed at login',\n"
                "                     ('players', 'new_drachma'): 'checked separately',\n"
                "                     ('players', 'civ_gear'): 'checked separately'},\n"
                "    cross_check_decoder=False,\n"
                ")\n"
            )

    def write_players(self, rows: list[dict]) -> None:
        with open(os.path.join(self.out, "players.jsonl"), "wt", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")

    def invoke(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [
                sys.executable,
                os.path.join(os.path.dirname(os.path.abspath(__file__)), "reconcile.py"),
                "--dump", self.dump,
                "--output", self.out,
                "--spec", self.spec,
                "--report", os.path.join(self.dir, "report.json"),
                "--omit-run-meta",
            ],
            capture_output=True,
            text=True,
        )

    def test_clean_run_exits_zero(self):
        self.write_players(
            [
                {"playerid": "76500000000000001", "cash": 1000},
                {"playerid": "76500000000000002", "cash": 16777217},
            ]
        )
        proc = self.invoke()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("RESULT: PASS", proc.stderr)

    def test_lost_player_exits_non_zero(self):
        self.write_players([{"playerid": "76500000000000001", "cash": 1000}])
        proc = self.invoke()
        self.assertEqual(proc.returncode, 1)
        with open(os.path.join(self.dir, "report.json"), encoding="utf-8") as fh:
            doc = json.load(fh)
        self.assertEqual(doc["result"], "fail")
        self.assertTrue(
            any(f["check"] == "player_identity" for f in doc["findings"])
        )

    def test_a_broken_spec_exits_two_not_one(self):
        """A setup failure must never be mistaken for a data finding."""
        with open(self.spec, "wt", encoding="utf-8") as fh:
            fh.write("SOMETHING_ELSE = 1\n")
        self.write_players([{"playerid": "76500000000000001", "cash": 1000}])
        proc = self.invoke()
        self.assertEqual(proc.returncode, 2)
        self.assertIn("RECONCILE_SPEC", proc.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
