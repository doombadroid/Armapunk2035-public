#!/usr/bin/env python3
"""No plain code-typed global may be defined in mission/ or server/ (security, 2026-09-26).

A client's publicVariable overwrites a missionNamespace global on EVERY machine, server included, so
`AP_fnc_x = {...}` is remote code execution the next time anything calls it. Every such definition
must be `AP_fnc_x = compileFinal {...}` (guarded with `if !(isFinal "AP_fnc_x")` where the defining
function runs more than once). This is the static half; the engine half is the -SEC- BOOT ASSERT in
server/AP_server/init.sqf and core/init.sqf, which also catches definitions this regex cannot see.

Run: python3 -m unittest tools/test_compilefinal.py
"""
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Never loaded in the shipped session, or a tool that must swap its code at runtime:
ALLOW = (
    "/debug/client_probe.sqf",           # dev probes, never loaded by the shipped mission (other debug/
    "/debug/npcprobe.sqf",               # files ARE execVM'd by initPlayerLocal/initServer, so they are scanned)
    "/edenDraw.sqf",                     # 3DEN-only tool, re-execs itself to hot-reload
    "/webui/diagnostics/fn_selfTest.sqf",  # swaps the fetcher for a fake one, then restores it
)
DEF = re.compile(r"(?<![A-Za-z0-9_])([A-Za-z][A-Za-z0-9_]*)\s*=\s*\{")


def code_mask(src):
    """True where src[i] is SQF code: not in a comment, a string ("" / '' doubled) or a # line."""
    n = len(src)
    mask = [True] * n
    i = 0
    while i < n:
        if src.startswith("//", i) or (src[i] == "#" and (i == 0 or src[i - 1] == "\n")):
            j = src.find("\n", i)
        elif src.startswith("/*", i):
            j = src.find("*/", i)
            j = -1 if j < 0 else j + 2
        elif src[i] in "\"'":
            q, j = src[i], i + 1
            while j < n:
                if src[j] == q:
                    if not src.startswith(q + q, j):
                        break
                    j += 1
                j += 1
            j += 1
        else:
            i += 1
            continue
        j = n if j < 0 else min(j, n)
        for k in range(i, j):
            mask[k] = False
        i = j
    return mask


def plain_code_globals(src):
    """Names assigned a code literal at statement level, `_locals` excluded."""
    mask = code_mask(src)
    out = []
    for m in DEF.finditer(src):
        if not mask[m.start()]:
            continue
        k = m.start() - 1
        while k >= 0 and (src[k] in " \t\r\n" or not mask[k]):
            k -= 1
        if k < 0 or src[k] in ";{}":
            out.append(m.group(1))
    return out


class CompileFinal(unittest.TestCase):
    def test_detector(self):
        self.assertEqual(plain_code_globals("AP_fnc_a = {1};\nif (x) then {AP_fnc_b={2}};"), ["AP_fnc_a", "AP_fnc_b"])
        self.assertEqual(plain_code_globals('private _l = {1}; AP_fnc_c = compileFinal {1};'), [])
        self.assertEqual(plain_code_globals('// AP_fnc_d = {1};\nx = "AP_fnc_e = {1}"; y = "a""b"; AP_fnc_f = {2};'), ["AP_fnc_f"])
        self.assertEqual(plain_code_globals("#define X 1\nAP_fnc_g = {1};"), ["AP_fnc_g"])
        self.assertEqual(plain_code_globals("_arr = [a, {1}]; f = x == {1};"), [])

    def test_repo_has_no_plain_code_globals(self):
        bad = []
        for top in ("mission", "server"):
            for root, _, files in os.walk(os.path.join(REPO, top)):
                for fn in files:
                    path = os.path.join(root, fn)
                    if not fn.endswith(".sqf") or any(a in path.replace(os.sep, "/") for a in ALLOW):
                        continue
                    with open(path, encoding="utf-8", errors="replace") as f:
                        names = plain_code_globals(f.read())
                    bad += ["%s: %s" % (os.path.relpath(path, REPO), n) for n in names]
        self.assertEqual(bad, [], "define these with compileFinal (see this file's docstring)")

    def test_lazy_client_definers_are_booted(self):
        """A mission fn that defines helpers behind `if !(isFinal ...)` runs more than once, i.e. on use.
        Until its first use another client can publicVariable a final copy that then sticks, so
        core/init.sqf must call it at client init ("boot"). ArmaQuest's run at preInit."""
        mission = os.path.join(REPO, "mission", "Armapunk2035.Malden")
        with open(os.path.join(mission, "core", "init.sqf"), encoding="utf-8") as f:
            boot = f.read().lower()
        missing = []
        for root, _, files in os.walk(mission):
            if "ArmaQuest" in root:
                continue
            for fn in files:
                if not (fn.startswith("fn_") and fn.endswith(".sqf")):
                    continue
                with open(os.path.join(root, fn), encoding="utf-8", errors="replace") as f:
                    if 'isFinal "' not in f.read():
                        continue
                tag = "NPC" if os.path.basename(root) == "npcs" else "AP"
                name = "%s_fnc_%s" % (tag, fn[3:-4])
                if name.lower() not in boot:
                    missing.append(name)
        self.assertEqual(missing, [], "call these with \"boot\" from core/init.sqf (see its SECURITY block)")


if __name__ == "__main__":
    unittest.main()
