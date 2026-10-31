#!/usr/bin/env python3
"""Tests for tools/aq_check.py.  Run: python3 -m unittest tools/test_aq_check.py

aq_check.py is a from-scratch Arma-config parser plus a from-scratch port of two SQF diagnostics
(aq_fnc_validate's requires[] grammar, aq_fnc_reachability's fixed point) and two bespoke SQF
side-file scans (fn_factionCfg.sqf's faction rows, fn_aqWorld.sqf's world: registry including its
one dynamic forEach/format pattern). None of that is obvious by inspection, and a validator that is
WRONG is worse than none, because it is trusted -- so this exercises the non-obvious parts directly,
against small fixture files, rather than only against the real (and currently clean) content tree.

The one exception is TestRealContent at the bottom: a smoke test against the actual mission files,
so a future regression in either the tool or the content itself is caught by this suite too.
"""
from __future__ import annotations

import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aq_check as X  # noqa: E402


# --------------------------------------------------------------------------------------------- #
# Fixtures. A "base" content file that validates clean on its own, plus small side-files, so each
# test only has to override the one piece it's actually exercising.
# --------------------------------------------------------------------------------------------- #

BASE_GIVERS = '''
class AQ_Givers {
    class fixer_1 { name = "Fixer One"; trigger = "addAction"; object = "C_man_1";
                    marker = "aq_giver_fixer_1"; boardSize = 3; };
    class fixer_2 { name = "Fixer Two"; trigger = "addAction"; object = "C_man_1";
                    marker = "aq_giver_fixer_2"; boardSize = 3; };
};
'''

DEFAULT_FACTIONS = '''
private _factions = [
    ["f_neon", "Neon Faction", "aq_terr_neon", "fixer_1", "blurb"],
    ["f_dock", "Dock Faction", "aq_terr_dock", "fixer_2", "blurb"]
];
switch (toLower _mode) do { case "all": { _factions }; default { [] }; };
'''

DEFAULT_WORLD = '''
if (!isServer) exitWith {};
["fed_robbed", { true }] call aq_fnc_registerWorld;
{
    private _cartel = _x;
    [format ["cartel_%1", _cartel], {
        true
    }] call aq_fnc_registerWorld;
} forEach ["wongs", "arms"];
'''

DEFAULT_SQM = '''
class Mission {
    class Entities {
        items=2;
        class Item0 {
            dataType="Marker";
            position[]={100,0,200};
            name="some_marker";
            type="Empty";
        };
        class Item1 {
            dataType="Object";
            class Attributes {
                init="hint ""hi"";";
                name="treetall_2";
            };
            side="Empty";
        };
    };
};
'''


@contextlib.contextmanager
def fixture(content, givers=BASE_GIVERS, factions=DEFAULT_FACTIONS, world=DEFAULT_WORLD, sqm=DEFAULT_SQM):
    with tempfile.TemporaryDirectory() as d:
        d = Path(d)
        cpath, fpath, wpath, spath = (d / "aq_content.hpp", d / "fn_factionCfg.sqf",
                                       d / "fn_aqWorld.sqf", d / "mission.sqm")
        cpath.write_text(givers + content, encoding="utf-8")
        fpath.write_text(factions, encoding="utf-8")
        wpath.write_text(world, encoding="utf-8")
        spath.write_text(sqm, encoding="utf-8")
        yield cpath, fpath, wpath, spath


def check(content, **kw):
    """Runs aq_check against `content` (appended to BASE_GIVERS unless overridden) and returns
    (exit_code, Report, captured_stdout)."""
    with fixture(content, **kw) as (cpath, fpath, wpath, spath):
        out = io.StringIO()
        code, rpt = X.run(content_file=cpath, faction_file=fpath, world_file=wpath, sqm_file=spath, out=out)
        return code, rpt, out.getvalue()


def has_problem(rpt, path_sub, msg_sub):
    return any(path_sub in p and msg_sub in m for p, m in rpt.problems)


def has_note(rpt, path_sub, msg_sub):
    return any(path_sub in p and msg_sub in m for p, m in rpt.notes)


# A minimal quest that validates clean against the DEFAULT_* side files above.
ONE_CLEAN_QUEST = '''
class AQ_Quests {
    class q1 {
        title = "Q1";
        giver = "fixer_1";
        requires[] = { };
        chain = "";
        class objectives {
            class o1 { type = "talk"; giver = "fixer_1"; };
        };
        class rewards { money = 100; };
    };
};
class AQ_Templates {};
'''


# --------------------------------------------------------------------------------------------- #
# Tokenizer / parser
# --------------------------------------------------------------------------------------------- #

class TestTokenizerAndParser(unittest.TestCase):
    def test_doubled_quote_is_an_escaped_quote(self):
        root = X.parse_config('key = "he said ""hi"" today";')
        self.assertEqual(root.props["key"], 'he said "hi" today')

    def test_apostrophe_inside_a_double_quoted_string_is_just_content(self):
        # Config strings are DOUBLE-quote delimited only. A ' here must not be read as a second
        # string delimiter, or every apostrophe in dialogue desyncs the rest of the file.
        root = X.parse_config('key = "\'Good. Now the part that actually matters.\'";')
        self.assertEqual(root.props["key"], "'Good. Now the part that actually matters.'")

    def test_negative_number_inside_a_nested_array(self):
        root = X.parse_config('rep[] = { {"f_neon", 150}, {"f_maxsec", -60} };')
        self.assertEqual(root.props["rep"], [["f_neon", 150], ["f_maxsec", -60]])

    def test_nested_class_path_and_declaration_order(self):
        root = X.parse_config('''
            class AQ_Quests {
                class q_b { giver = "g2"; };
                class q_a { giver = "g1"; };
            };
        ''')
        self.assertEqual(list(root.children["AQ_Quests"].children.keys()), ["q_b", "q_a"])
        self.assertEqual(root.children["AQ_Quests"].children["q_a"].props["giver"], "g1")

    def test_comments_are_stripped_including_around_code_that_looks_like_a_value(self):
        root = X.parse_config('''
            // key = "wrong";
            key = "right"; /* also
               not this */
        ''')
        self.assertEqual(root.props["key"], "right")

    def test_forward_declared_class_with_no_body_does_not_crash(self):
        root = X.parse_config('class Foo; key = "still parses";')
        self.assertIn("Foo", root.children)
        self.assertEqual(root.props["key"], "still parses")

    def test_malformed_value_raises_parse_error_with_a_line_number(self):
        with self.assertRaises(X.ParseError) as ctx:
            X.parse_config('a = 1;\nb = ;\n')
        self.assertEqual(ctx.exception.line, 2)

    def test_unterminated_string_raises_tokenize_error(self):
        with self.assertRaises(X.TokenizeError):
            X.tokenize('key = "unterminated;')


class TestNumberLiteral(unittest.TestCase):
    def test_negative_threshold_is_a_valid_number_literal(self):
        # The exact case the task calls out: a validator that rejects rep:f_dock:-500 is wrong.
        self.assertTrue(X.is_number_literal("-500"))

    def test_positive_and_zero(self):
        self.assertTrue(X.is_number_literal("250"))
        self.assertTrue(X.is_number_literal("0"))

    def test_decimal(self):
        self.assertTrue(X.is_number_literal("1.5"))
        self.assertTrue(X.is_number_literal("-1.5"))

    def test_garbage_is_not_a_number_literal(self):
        self.assertFalse(X.is_number_literal(""))
        self.assertFalse(X.is_number_literal("banana"))
        self.assertFalse(X.is_number_literal("1.2.3"))
        self.assertFalse(X.is_number_literal("--5"))
        self.assertFalse(X.is_number_literal("5-"))


# --------------------------------------------------------------------------------------------- #
# requires[] grammar
# --------------------------------------------------------------------------------------------- #

class TestRequiresGrammar(unittest.TestCase):
    def test_negative_rep_threshold_is_not_flagged(self):
        # rep: takes exactly three parts and n may be NEGATIVE (FACTION_REP_SPEC.md 6.1).
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1";
                requires[] = { "rep:f_dock:-500" };
                class objectives { class o1 { type="talk"; giver="fixer_1"; }; };
                class rewards { money = 0; };
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 0, rpt.problems)
        self.assertFalse(has_problem(rpt, "requires[0]", ""))

    def test_rep_with_only_two_parts_is_malformed(self):
        code, rpt, _ = check(_one_quest_requiring('"rep:f_dock"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "malformed"))

    def test_rep_threshold_must_be_numeric(self):
        code, rpt, _ = check(_one_quest_requiring('"rep:f_dock:banana"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "threshold 'banana' is not a number"))

    def test_rep_faction_must_exist(self):
        code, rpt, _ = check(_one_quest_requiring('"rep:f_nonexistent:100"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "not a faction id"))

    def test_item_with_quantity(self):
        code, rpt, _ = check(_one_quest_requiring('"item:copperore:5"'))
        self.assertEqual(code, 0, rpt.problems)

    def test_item_with_zero_quantity_is_malformed(self):
        code, rpt, _ = check(_one_quest_requiring('"item:copperore:0"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "not a positive number"))

    def test_item_with_negative_quantity_is_malformed(self):
        code, rpt, _ = check(_one_quest_requiring('"item:copperore:-5"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "not a positive number"))

    def test_license_with_a_third_part_is_malformed(self):
        code, rpt, _ = check(_one_quest_requiring('"license:drivers:extra"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "has a third part"))

    def test_world_key_with_a_value_is_allowed(self):
        code, rpt, _ = check(_one_quest_requiring('"world:fed_robbed:1"'))
        self.assertEqual(code, 0, rpt.problems)

    def test_unknown_kind_is_flagged(self):
        code, rpt, _ = check(_one_quest_requiring('"faction:f_neon"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "not a known requirement kind"))

    def test_single_word_token_is_malformed(self):
        code, rpt, _ = check(_one_quest_requiring('"fed_robbed"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "malformed"))

    def test_non_string_token_is_flagged(self):
        code, rpt, _ = check(_one_quest_requiring('1'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "is not a string"))

    def test_quest_requiring_itself_is_flagged(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1";
                requires[] = { "quest:q1" };
                class objectives { class o1 { type="talk"; giver="fixer_1"; }; };
                class rewards {};
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q1 >> requires[0]", "requires itself"))

    def test_quest_requiring_a_nonexistent_quest_is_flagged(self):
        code, rpt, _ = check(_one_quest_requiring('"quest:does_not_exist"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "requires quest 'does_not_exist', which does not exist"))


def _one_quest_requiring(token_literal):
    return '''
        class AQ_Quests { class q1 { title="Q"; giver="fixer_1";
            requires[] = { %s };
            class objectives { class o1 { type="talk"; giver="fixer_1"; }; };
            class rewards { money = 0; };
        }; };
        class AQ_Templates {};
    ''' % token_literal


# --------------------------------------------------------------------------------------------- #
# Prerequisite cycles
# --------------------------------------------------------------------------------------------- #

class TestCycles(unittest.TestCase):
    def test_two_quest_cycle_is_detected(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver="fixer_1"; requires[] = { "quest:q_b" };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
                class q_b { title="B"; giver="fixer_1"; requires[] = { "quest:q_a" };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q_a >> requires", "prerequisite cycle"))
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q_b >> requires", "prerequisite cycle"))

    def test_no_false_cycle_on_a_simple_chain_of_prerequisites(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver="fixer_1"; requires[] = { };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
                class q_b { title="B"; giver="fixer_1"; requires[] = { "quest:q_a" };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 0, rpt.problems)


# --------------------------------------------------------------------------------------------- #
# Reachability
# --------------------------------------------------------------------------------------------- #

class TestReachability(unittest.TestCase):
    def test_quest_with_valid_giver_is_reachable(self):
        code, rpt, _ = check(ONE_CLEAN_QUEST)
        self.assertEqual(code, 0, rpt.problems)

    def test_orphan_quest_no_giver_no_chain_is_unreachable(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver=""; requires[] = { };
                class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q1", "has no giver and no quest chains into it"))

    def test_quest_reachable_only_via_chain_from_a_reachable_quest(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver="fixer_1"; requires[] = { }; chain = "q_b";
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
                class q_b { title="B"; giver=""; requires[] = { };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 0, rpt.problems)

    def test_quest_chained_from_an_unreachable_quest_stays_unreachable(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver=""; requires[] = { }; chain = "q_b";
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
                class q_b { title="B"; giver=""; requires[] = { };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        # q_a: no giver, nothing chains INTO q_a -> unreachable.
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q_a", "has no giver and no quest chains into it"))
        # q_b is only ever chained into by q_a, and q_a is itself unreachable.
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q_b", "unreachable"))


# --------------------------------------------------------------------------------------------- #
# chain / giver agreement -- the check the in-game reachability graph does not make (see the
# module docstring's CHAIN note).
# --------------------------------------------------------------------------------------------- #

class TestChainSameGiver(unittest.TestCase):
    def test_chain_to_a_different_giver_is_flagged(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver="fixer_1"; requires[] = { }; chain = "q_b";
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
                class q_b { title="B"; giver="fixer_2"; requires[] = { };
                    class objectives { class o { type="talk"; giver="fixer_2"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q_a >> chain", "chain only ever hands off to the SAME giver"))

    def test_chain_to_the_same_giver_is_not_flagged(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver="fixer_1"; requires[] = { }; chain = "q_b";
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
                class q_b { title="B"; giver="fixer_1"; requires[] = { };
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 0, rpt.problems)

    def test_chain_to_a_nonexistent_quest_is_flagged_by_chain_targets_not_same_giver(self):
        code, rpt, _ = check('''
            class AQ_Quests {
                class q_a { title="A"; giver="fixer_1"; requires[] = { }; chain = "ghost";
                    class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q_a >> chain", "chains to 'ghost', which is not a quest"))
        self.assertFalse(has_problem(rpt, "AQ_Quests >> q_a >> chain", "SAME giver"))


# --------------------------------------------------------------------------------------------- #
# Giver references
# --------------------------------------------------------------------------------------------- #

class TestGiverRefs(unittest.TestCase):
    def test_quest_giver_must_exist(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="nonexistent"; requires[] = { };
                class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q1 >> giver", "not a class in AQ_Givers"))

    def test_template_givers_array_entry_must_exist(self):
        code, rpt, _ = check('''
            class AQ_Quests {};
            class AQ_Templates { class t1 { side="civ"; givers[] = { "fixer_1", "ghost_giver" }; weight=1;
                title="T"; class objectives { class o { type="talk"; giver="fixer_1"; }; }; class rewards {}; };
            };
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Templates >> t1 >> givers[1]", "not a class in AQ_Givers"))


# --------------------------------------------------------------------------------------------- #
# world: registration, including the dynamic forEach/format resolution.
# --------------------------------------------------------------------------------------------- #

class TestWorldKeys(unittest.TestCase):
    def test_unregistered_world_key_is_flagged(self):
        code, rpt, _ = check(_one_quest_requiring('"world:nonsense_key"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "nothing has registered"))

    def test_literal_world_key_passes(self):
        code, rpt, _ = check(_one_quest_requiring('"world:fed_robbed"'))
        self.assertEqual(code, 0, rpt.problems)

    def test_dynamic_foreach_format_key_is_fully_resolved(self):
        # fn_aqWorld.sqf's actual pattern: format ["cartel_%1", _cartel] forEach ["wongs","arms"].
        # "cartel_wongs" is a real, generated key; "cartel_gold" is not (typo/nonexistent cartel).
        code, rpt, _ = check(_one_quest_requiring('"world:cartel_wongs"'))
        self.assertEqual(code, 0, rpt.problems)

        code, rpt, _ = check(_one_quest_requiring('"world:cartel_gold"'))
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "requires[0]", "nothing has registered"))

    def test_unresolvable_dynamic_key_is_a_note_not_a_problem(self):
        # forEach over a non-literal (a variable, not an array literal) can't be resolved --
        # handled as "unverifiable", per the task's own instruction, not flagged as an error.
        world = '''
            private _list = someFunctionCall();
            {
                private _cartel = _x;
                [format ["cartel_%1", _cartel], { true }] call aq_fnc_registerWorld;
            } forEach _list;
        '''
        code, rpt, _ = check(_one_quest_requiring('"world:cartel_whatever"'), world=world)
        self.assertEqual(code, 0, rpt.problems)
        self.assertTrue(has_note(rpt, "requires[0]", "unverifiable"))


# --------------------------------------------------------------------------------------------- #
# rep: faction cross-check (fn_factionCfg.sqf)
# --------------------------------------------------------------------------------------------- #

class TestFactionIds(unittest.TestCase):
    def test_parses_ids_out_of_the_row_shape(self):
        ids = X.parse_faction_ids(Path(_write_tmp(DEFAULT_FACTIONS)))
        self.assertEqual(ids, {"f_neon", "f_dock"})


# --------------------------------------------------------------------------------------------- #
# Markers -- genuine Marker entities only, never an object's own name=.
# --------------------------------------------------------------------------------------------- #

class TestMarkers(unittest.TestCase):
    def test_genuine_marker_is_found(self):
        markers = X.parse_sqm_markers(Path(_write_tmp(DEFAULT_SQM)))
        self.assertIn("some_marker", markers)

    def test_an_objects_own_name_is_not_mistaken_for_a_marker(self):
        # The exact historical bug: an Object's name (nested under its own Attributes class, e.g.
        # a decorative tree named "treetall_2") must never satisfy a marker existence check.
        markers = X.parse_sqm_markers(Path(_write_tmp(DEFAULT_SQM)))
        self.assertNotIn("treetall_2", markers)

    def test_objective_referencing_a_real_marker_passes(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1"; requires[] = { };
                class objectives { class o { type="visit"; marker="some_marker"; radius=10; }; };
                class rewards {};
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 0, rpt.problems)

    def test_objective_referencing_the_objects_own_name_fails(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1"; requires[] = { };
                class objectives { class o { type="visit"; marker="treetall_2"; radius=10; }; };
                class rewards {};
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "AQ_Quests >> q1 >> objectives >> o >> marker", "does not exist"))

    def test_objective_referencing_a_missing_marker_fails(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1"; requires[] = { };
                class objectives { class o { type="visit"; marker="totally_absent"; radius=10; }; };
                class rewards {};
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "marker", "does not exist"))


def _write_tmp(text):
    fd, path = tempfile.mkstemp()
    with os.fdopen(fd, "w") as f:
        f.write(text)
    return path


# --------------------------------------------------------------------------------------------- #
# Objective types
# --------------------------------------------------------------------------------------------- #

class TestObjectiveTypes(unittest.TestCase):
    def test_all_nine_registered_types_are_accepted(self):
        for t in sorted(X.OBJECTIVE_TYPES):
            with self.subTest(type=t):
                code, rpt, _ = check('''
                    class AQ_Quests { class q1 { title="Q"; giver="fixer_1"; requires[] = { };
                        class objectives { class o { type="%s"; giver="fixer_1"; marker="some_marker";
                            item="copperore"; count=1; radius=10; seconds=10; }; };
                        class rewards {};
                    }; };
                    class AQ_Templates {};
                ''' % t)
                self.assertEqual(code, 0, (t, rpt.problems))

    def test_unknown_type_is_flagged(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1"; requires[] = { };
                class objectives { class o { type="teleport"; }; };
                class rewards {};
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "type", "not a registered objective type"))

    def test_missing_type_is_flagged(self):
        code, rpt, _ = check('''
            class AQ_Quests { class q1 { title="Q"; giver="fixer_1"; requires[] = { };
                class objectives { class o { marker="some_marker"; }; };
                class rewards {};
            }; };
            class AQ_Templates {};
        ''')
        self.assertEqual(code, 1)
        self.assertTrue(has_problem(rpt, "type", "declares no type"))


# --------------------------------------------------------------------------------------------- #
# End-to-end smoke test against the REAL mission content.
# --------------------------------------------------------------------------------------------- #

class TestRealContent(unittest.TestCase):
    def test_the_shipped_content_passes_clean(self):
        out = io.StringIO()
        code, rpt = X.run(out=out)
        self.assertEqual(code, 0, "%s\n%s" % (rpt.problems if rpt else "(parse failure)", out.getvalue()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
