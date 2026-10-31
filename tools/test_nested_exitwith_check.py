#!/usr/bin/env python3
"""Tests for tools/nested_exitwith_check.py.  Run: python3 -m unittest tools/test_nested_exitwith_check.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nested_exitwith_check import scan  # noqa: E402


def hits(src, strict=False):
    return [line for line, _ in scan(src, strict)]


# the shape both 2026-09-26 bugs had: the refusal sits in the then-block, the privileged work after it
BROKEN = """
if (_src isNotEqualTo 0) then {
    if (isNull _caller) exitWith {};
    if (_lvl < 3) exitWith {
        ["-SEC-", _caller, "BLOCKED x"] call APS_fnc_logIt;
    };
};
AP_fabFreeBuild = true;
"""


class NestedExitWith(unittest.TestCase):
    def test_broken_gate_flagged(self):
        self.assertEqual(hits(BROKEN), [4])

    def test_flag_idiom_passes(self):
        src = BROKEN.replace("if (_lvl < 3) exitWith {", "if (_lvl < 3) exitWith { _blocked = true;")
        self.assertEqual(hits(src), [])

    def test_flat_recheck_passes(self):
        self.assertEqual(hits(BROKEN.replace("};\nAP_fab", "};\nif (_blocked) exitWith {};\nAP_fab")), [])

    def test_nothing_after_owning_if_passes(self):
        # the exit skips the rest of its block and nothing follows the block: correct as written
        src = """case 1: { if (_u) then {
            if (!_ok) exitWith { ["-SEC-", _c, "BLOCKED k"] call APS_fnc_logIt; };
            _owners pushBack _u; }; };"""
        self.assertEqual(hits(src), [])

    def test_refusal_not_last_flagged(self):
        src = """if (_src != 0) then {
            if (!_ok) exitWith { ["-SEC-", _c, "BLOCKED"] call APS_fnc_logIt; };
            _x = 1;
        };
        doWork;"""
        self.assertEqual(hits(src), [2])

    def test_plain_last_exit_is_strict_only(self):
        src = """if (_a) then { if (_b) exitWith { [_p, "no"] call _say }; };
        doWork;"""
        self.assertEqual(hits(src, strict=True), [1])
        self.assertEqual(hits(src), [])

    def test_else_block(self):
        src = """if (_h) then { _x = 1 } else {
            if (_far) exitWith { [false, "OUT OF REACH"] call _reply };
        };
        doWork;"""
        self.assertEqual(hits(src, strict=True), [2])

    def test_strings_and_comments_ignored(self):
        src = """// if (a) then { if (b) exitWith {"-SEC-"}; };
        private _s = "if (a) then { if (b) exitWith { '-SEC-' }; }; x";
        doWork;"""
        self.assertEqual(hits(src, strict=True), [])

    def test_lowercase_blocked_is_not_a_marker(self):
        src = """if (_t) then { if (_stuck) exitWith { ["stop", "blocked -- take the wheel"] call f }; };
        doWork;"""
        self.assertEqual(hits(src), [])


if __name__ == "__main__":
    unittest.main()
