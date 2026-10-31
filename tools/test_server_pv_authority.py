"""Server authority vs client publicVariable (audit 2026-09-26, cluster pveh).

A client `publicVariable "X"` reaches every machine, the server included, and overwrites X there
(BattlEye filters are log-only). So the server must never (1) register a publicVariable event
handler -- that is a client-triggered entry point with no identity and no CfgRE gate -- or (2) READ
a value it also publishes to clients. The published names below are display copies: the server
may assign and publish them, but reads the APS_ copy it keeps in localNamespace.
"""
import pathlib
import re
import unittest

SERVER = pathlib.Path(__file__).resolve().parent.parent / "server"

DISPLAY = ["AP_price_index", "AP_marketFloor", "AP_marketMaxPrem", "AP_marketItemOv", "AP_marketCrash",
           "AP_marketRise", "AP_marketGoods", "AP_drugBustGoods", "AP_drugBustUntil", "AP_stimmy",
           "AP_configuration"]
# dead-but-registered: its body still names AP_price_index, behind a leading `if (true) exitWith {}`
SKIP = {"fn_reduceMarket.sqf"}


def strip_comments(src):
    """SQF source with // and /* */ comments blanked; string literals ("" escapes) kept."""
    out, i, n = [], 0, len(src)
    while i < n:
        c, nxt = src[i], src[i + 1:i + 2]
        if c == "/" and nxt == "/":
            j = src.find("\n", i)
            i = n if j < 0 else j
        elif c == "/" and nxt == "*":
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
        elif c in "\"'":
            j = i + 1
            while j < n and not (src[j] == c and src[j + 1:j + 2] != c):
                j += 2 if src[j] == c else 1
            out.append(src[i:j + 1])
            i = j + 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def is_restore_only(code, at):
    """The one PVEH shape the server may use: ignore the payload and put the server's own
    localNamespace copy back (server_init.sqf). Anything else trusts client data."""
    i = code.find("{", at)
    if i < 0:
        return False
    depth, j = 0, i
    while j < len(code):
        depth += {"{": 1, "}": -1}.get(code[j], 0)
        if depth == 0:
            break
        j += 1
    body = code[i:j + 1]
    if not re.search(r"_this|params|_value", body):
        return True                     # never reads the payload at all (e.g. atmSkimSRV re-syncs its server copy)
    return ("localNamespace getVariable _name" in body and "setVariable [_name" in body
            and not re.search(r"_value\b(?![^;]*logIt)", body.split("params", 1)[-1].split(";", 1)[-1]))


def violations(src):
    code = strip_comments(src)
    bad = []
    for m in re.finditer(r"addPublicVariableEventHandler", code, re.I):
        if not is_restore_only(code, m.end()):
            bad.append("addPublicVariableEventHandler")
    for name in DISPLAY:
        for m in re.finditer(r'(?<![\w"])%s(?![\w"])' % name, code):
            if not re.match(r"\s*=(?!=)", code[m.end():]):        # bare use that is not an assignment
                bad.append("reads %s" % name)
        if re.search(r'getVariable\s*\[?\s*"%s"' % name, code):
            bad.append("getVariable %s" % name)
    return bad


class ServerPvAuthority(unittest.TestCase):
    def test_server_tree(self):
        found = {}
        for f in sorted(SERVER.rglob("*.sqf")):
            if f.name in SKIP:
                continue
            v = violations(f.read_text(encoding="utf-8", errors="replace"))
            if v:
                found[str(f.relative_to(SERVER))] = sorted(set(v))
        self.assertEqual(found, {})

    def test_detector(self):
        self.assertTrue(violations('"x" addPublicVariableEventHandler { AP_y = _this select 1; };'))
        self.assertTrue(violations('if (AP_stimmy) then {};'))
        self.assertTrue(violations('_m = missionNamespace getVariable ["AP_marketMaxPrem", 1.3];'))
        self.assertTrue(violations('{ } forEach AP_price_index;'))
        self.assertFalse(violations('AP_stimmy = _on; publicVariable "AP_stimmy"; // if (AP_stimmy)'))
        self.assertFalse(violations('AP_configuration = +_cfg; APS_configuration = 1;'))
        restore = ('{ _x addPublicVariableEventHandler { params ["_name", ["_value", "nil"]]; '
                   '["-SEC-", objNull, format ["%1 %2", _name, _value]] call APS_fnc_logIt; '
                   'missionNamespace setVariable [_name, localNamespace getVariable _name]; publicVariable _name; }; } forEach ["AP_x"];')
        self.assertFalse(violations(restore))
        self.assertTrue(violations('"AP_x" addPublicVariableEventHandler { params ["_n","_value"]; AP_y = _value; };'))
        self.assertFalse(violations('"AP_x" addPublicVariableEventHandler { ["sync"] call APS_fnc_x; };'))
        self.assertTrue(violations('"AP_x" addPublicVariableEventHandler { AP_y = _this select 1; };'))


if __name__ == "__main__":
    unittest.main()
