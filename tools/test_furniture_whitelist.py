#!/usr/bin/env python3
"""The server's house-furniture class whitelist must track the mission's furniture list.

    python3 -m unittest tools/test_furniture_whitelist.py

APS_fnc_houseFurnitureSRV "add" and APS_fnc_suiteFurnitureSRV "add"/"load" only accept a class in the
server-private list localNamespace APS_furnClasses (audit 2026-09-26: any class used to be accepted).
The source of truth is client-only (core/configuration.sqf: AP_placeable rows whose item key is in AP_furnitureItems, i.e.
AP_furnitureClasses), so the server keeps a copy. A new furniture item added only to the
mission would be refused and refunded on every placement; this test fails first instead.
The fabricator stand-ins (printer_*, gunsmith_bench) route to APS_fnc_fabSRV and are excluded.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
CFG = ROOT / "mission/Armapunk2035.Malden/core/configuration.sqf"
SRV = ROOT / "server/AP_server/core/TON/fn_houseFurnitureSRV.sqf"
FAB_ITEMS = {"printer_i3", "printer_corexy", "gunsmith_bench"}


def mission_classes():
    s = CFG.read_text(encoding="utf-8", errors="replace")
    items = re.findall(r'"([^"]+)"', re.search(r"AP_furnitureItems = \[(.*?)\];", s).group(1))
    cls = {}
    for key, c in re.findall(r'\[\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"[^"]*"\s*,', s):
        cls.setdefault(key, c)
    missing = [i for i in items if i not in cls]
    return {cls[i] for i in items if i in cls and i not in FAB_ITEMS}, missing


def server_classes():
    s = SRV.read_text(encoding="utf-8", errors="replace")
    return set(re.findall(r'"([^"]+)"', re.search(r'setVariable \["APS_furnClasses", \[(.*?)\]', s, re.S).group(1)))


class FurnitureWhitelist(unittest.TestCase):
    def test_server_list_matches_mission(self):
        want, missing = mission_classes()
        self.assertEqual(missing, [], "AP_furnitureItems keys with no AP_placeable row")
        got = server_classes()
        self.assertEqual(sorted(want - got), [], "furniture the server would refuse (add to APS_furnClasses)")
        self.assertEqual(sorted(got - want), [], "server whitelists a class the mission no longer places")


if __name__ == "__main__":
    unittest.main()
