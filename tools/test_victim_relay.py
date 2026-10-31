#!/usr/bin/env python3
"""Guard for the player-on-player server hop.  Run: python3 -m unittest tools/test_victim_relay.py

Every function APS_fnc_victimSRV forwards to runs on a VICTIM's client and trusts its caller, so:
  * each must open with the server-origin guard (a client-origin remoteExec is dropped);
  * no mission .sqf may name it as a string any more -- a direct client -> client call would be
    silently dropped by that guard, i.e. the feature would break without an error;
  * the relay itself must stay whitelisted server-only and registered in config.cpp.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MISSION = ROOT / "mission" / "Armapunk2035.Malden"
RELAY = ROOT / "server" / "AP_server" / "core" / "TON" / "fn_victimSRV.sqf"
# either idiom drops a client sender; the second also lets a spawned re-entry (owner 0) through
GUARDS = ("if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};",
          "if !(remoteExecutedOwner in [0, 2]) exitWith {};")


def first_statement(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    lines = [l.split("//")[0].strip() for l in src.splitlines()]
    return next(l for l in lines if l and not l.startswith("#include"))


class VictimRelay(unittest.TestCase):
    def setUp(self):
        self.victims = sorted(set(re.findall(r'"(AP_fnc_\w+)"', RELAY.read_text())))

    def test_relay_forwards_something(self):
        self.assertGreaterEqual(len(self.victims), 13, self.victims)

    def test_victims_are_server_origin_only(self):
        for fn in self.victims:
            files = list(MISSION.rglob("fn_%s.sqf" % fn[len("AP_fnc_"):]))
            self.assertEqual(len(files), 1, fn)
            self.assertTrue(first_statement(files[0].read_text()).startswith(GUARDS), fn)

    def test_no_direct_client_calls(self):
        for f in MISSION.rglob("*.sqf"):
            text = f.read_text(errors="replace")
            for fn in self.victims:
                self.assertNotIn('"%s"' % fn, text, "%s calls %s directly" % (f, fn))

    def test_relay_registered(self):
        self.assertRegex((MISSION / "CfgRE.hpp").read_text(), r"class APS_fnc_victimSRV \{allowedTargets = 2;\};")
        self.assertRegex((ROOT / "server" / "AP_server" / "config.cpp").read_text(), r"\bclass victimSRV \{\};")


if __name__ == "__main__":
    unittest.main()
