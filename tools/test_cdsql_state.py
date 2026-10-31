"""Server-only cyberdeck/mining/fab state must stay out of missionNamespace (audit TONa-0-14 review, r2fab).

A client's publicVariable overwrites a missionNamespace global on the server too, so a forged
AP_cryptoRigs record took over any rig, a zeroed AP_atmCd_<uid> reset the ATM cooldown, and so on.
The server keeps these in localNamespace under APS_ names; this fails if an AP_ form comes back.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVER_ONLY = re.compile(r"\bAP_(cryptoRigs|rigBusy|cryptoRigComp|deckJam|atmHoney|atmCd_|atmPts|wiretaps|gridBlackout|fabAnchors|fabBusy)\b")
# AP_atmDoneKeys stays public for the client pre-gate; the server may only PUBLISH it, never read it back.
DONE_KEYS = re.compile(r"\bAP_atmDoneKeys\b")
DONE_KEYS_OK = 'missionNamespace setVariable ["AP_atmDoneKeys", +_done, true]'


def code_lines(path):
    for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        yield n, line.split("//", 1)[0]


class ServerStateNotPublic(unittest.TestCase):
    def test_no_missionnamespace_server_state(self):
        bad = []
        for f in sorted((ROOT / "server").rglob("*.sqf")):
            for n, code in code_lines(f):
                if SERVER_ONLY.search(code) or (DONE_KEYS.search(code) and DONE_KEYS_OK not in code):
                    bad.append(f"{f.relative_to(ROOT)}:{n}: {code.strip()[:120]}")
        self.assertEqual(bad, [], "server state read/written through a client-writable global")


if __name__ == "__main__":
    unittest.main()
