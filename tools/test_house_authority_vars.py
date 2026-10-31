#!/usr/bin/env python3
"""No new server-side reads of client-writable house/machine ownership object vars.

    python3 -m unittest tools/test_house_authority_vars.py

Any client can `setVariable [..., true]` on any object (verifySignatures=0, BattlEye off), so a
server gate that reads who owns / holds keys to / is gang HQ of a house, printer or rig off the
OBJECT authorises the forger (houses audit 2026-09-26, TONd-0-0 class -- it kept reappearing in
sibling files: miningSRV, fabSRV, maldenSRV, medicFireSRV). Authority comes from the DB row
(APS_fnc_houseRights, house_rigs / house_printers rows) or server-private localNamespace state.

The reads below are the reviewed remainder (display, logs, or owned by another fix). A file may
drop reads freely; a new read anywhere fails here until it is reviewed and listed.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
VARS = ("AP_homeOwner", "AP_house_keys", "AP_house_gang", "AP_fabOwner", "AP_fabHomeOwner",
        "AP_rigHomeOwner", "AP_rigOwner", "AP_maldenOid", "AP_maldenDmg", "AP_maldenDead",
        # rig truck identity: the server's copy is localNamespace APS_rigKind_<netId> (APS_fnc_rigAdopt, r2rig)
        "AP_rigKind", "AP_rigKindSrv")
PAT = re.compile(r'getVariable\s*\[\s*"(%s)"' % "|".join(VARS))

# (file name, var) -> max reads. Reason per line.
ALLOWED = {
    ("fn_bldgUpdateKeys.sqf", "AP_homeOwner"): 1,     # -HOUSEKEY- log text only
    ("fn_bldgUpdateKeys.sqf", "AP_house_keys"): 1,    # old-vs-new diff for the log, after the row gate
    ("fn_cyberdeckSRV.sqf", "AP_homeOwner"): 2,       # breach toast recipient; cryptoTakeover _insider (cdsql TONa-0-14)
    ("fn_cyberdeckSRV.sqf", "AP_house_keys"): 1,      # cryptoTakeover _insider (cdsql TONa-0-14)
    ("fn_cyberdeckSRV.sqf", "AP_rigOwner"): 1,        # hijack notice recipient
    ("fn_medicFireSRV.sqf", "AP_homeOwner"): 1,       # firefighter payment hint to the client (callbacks/coppay)
    ("fn_repairBuildingSRV.sqf", "AP_homeOwner"): 1,  # re-stamp of display vars after a repair
    ("fn_repairBuildingSRV.sqf", "AP_house_gang"): 1, # re-stamp of display vars after a repair
    ("fn_sendKeyHouses.sqf", "AP_house_keys"): 1,     # key list display
    ("fn_setCleanTime.sqf", "AP_homeOwner"): 1,       # cleanup-reap exemption, not an authority
}


def reads():
    out = {}
    for f in (ROOT / "server").rglob("*.sqf"):
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.lstrip().startswith("//"):
                continue
            for v in PAT.findall(line):
                out[(f.name, v)] = out.get((f.name, v), 0) + 1
    return out


class HouseAuthorityVars(unittest.TestCase):
    def test_no_new_reads(self):
        extra = {k: n for k, n in reads().items() if n > ALLOWED.get(k, 0)}
        self.assertEqual(extra, {}, "server reads a client-writable ownership var -- authorise from the DB row "
                                    "(APS_fnc_houseRights) instead, or review and list it in ALLOWED")

    def test_scanner_sees_a_read(self):
        self.assertEqual(PAT.findall('_h getVariable ["AP_homeOwner", ""]'), ["AP_homeOwner"])


if __name__ == "__main__":
    unittest.main()
