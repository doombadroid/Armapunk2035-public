#!/usr/bin/env python3
"""Tests for tools/sqf_balance.py.  Run: python3 tools/test_sqf_balance.py

Two things must stay true and they pull against each other:
  CATCH  -- a bracket fault inside a quoted scroll-menu condition must FAIL (that fault is silent in
            Arma: the condition does not compile, the whole scroll menu vanishes, nothing is logged).
  DO NOT CRY WOLF -- every legitimately unbalanced string in this tree must stay quiet. Each NOFLAG
            case below is a real string copied out of the repo; if one starts failing, the checker
            has become the thing nobody trusts, which is worse than the hole it closed.
"""
import os
import subprocess
import sys
import tempfile

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sqf_balance.py")


def run(src, *flags):
    fd, path = tempfile.mkstemp(suffix=".sqf")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(src)
        p = subprocess.run([sys.executable, TOOL, path] + list(flags),
                           capture_output=True, text=True)
        return p.returncode, p.stdout.replace(path, "F")
    finally:
        os.unlink(path)


CASES = []


def flag(name, src, expect_line=None):
    CASES.append(("FLAG", name, src, expect_line))


def noflag(name, src):
    CASES.append(("NOFLAG", name, src, None))


# ---------------------------------------------------------------------------------------------
# THE FAULT THIS EXISTS FOR -- the real jewelry-emporium drill condition from
# mission/Armapunk2035.Malden/core/fn_setupActions.sqf, with one paren deleted.
# ---------------------------------------------------------------------------------------------
_JEWEL = ("AP_actions pushBack(_plb_obj addAction [\"Start Drilling Door\", {[] "
          "spawn AP_fnc_jewelryEmporium},nil,0,false,false,\"\",'%s',6]);")
_COND_OK = ("!(SRV_jewelryEmporiumSRV param [ 1, false ] ) && (playerSide isEqualTo civilian) && "
            "(!isNull (missionNamespace getVariable [ \"AP_jewelGate\", objNull ] )) && "
            "((player distance (missionNamespace getVariable [ \"AP_jewelGate\", objNull ] )) <= 6)")

noflag("real condition, intact", _JEWEL % _COND_OK)
flag("real condition, one paren deleted", _JEWEL % _COND_OK[:-1], 1)
flag("real condition, extra paren", _JEWEL % (_COND_OK + ")"), 1)
flag("condition with a ] closing a (", _JEWEL % "!isNull cursorObject && (player distance cursorObject] < 5", 1)

# a fault on a later line of a multi-line file must report THAT line
flag("line number is the condition's own line",
     "a = 1;\nb = 2;\n" + (_JEWEL % _COND_OK[:-1]), 3)

# ---------------------------------------------------------------------------------------------
# Arma tokenizer facts
# ---------------------------------------------------------------------------------------------
noflag('"" is an escaped quote, not a terminator',
       'x = "he said ""(hi)"" and left"; y = (1 + 2);')
noflag("'' is an escaped quote inside a '-string",
       "x = 'it''s (fine)'; y = [1,2];")
noflag('a " inside a \'-string is content', "x = 'say \"hello\" (ok)';")
noflag("a ' inside a \"-string is content", 'x = "don\'t (worry)";')
noflag("brackets in // comments do not count", "// ) ] }\nx = (1);")
noflag("brackets in /* */ comments do not count", "/* ) ] }\n   ( [ { */\nx = (1);")
noflag("empty '' string then more code", "_c = 'alive _this && {(_x param [0, '''', 0]) isEqualTo 1}';")

# ---------------------------------------------------------------------------------------------
# Nested literals inside a condition are OPAQUE -- a classname is not code
# ---------------------------------------------------------------------------------------------
noflag("bracket inside a nested classname does not count",
       "_c = '(typeOf cursorObject isEqualTo \"Weird_)_Class\") && !isNull cursorObject';")
flag("but a real fault around that nested literal still fails",
     "_c = '((typeOf cursorObject isEqualTo \"Weird_)_Class\") && !isNull cursorObject';", 1)

# ---------------------------------------------------------------------------------------------
# NOT CODE -- every one of these is a real unbalanced string from this repo
# ---------------------------------------------------------------------------------------------
noflag("SQL built with a non-literal operand (server/AP_server/init.sqf:547)",
       '["UPDATE houses SET tax_playtime = tax_playtime + 5 WHERE owners IN (" '
       '+ (_uids joinString ",") + ")"] call DB_fnc_asyncQuery;')
noflag("SQL built from a pure literal chain (fn_storageVaultSRV.sqf:44)",
       '[format ["CREATE TABLE IF NOT EXISTS storage_vault ("\n'
       '    + "uid VARCHAR(17) NOT NULL,"\n'
       '    + "INDEX idx_uid (uid))", VAULT_LABEL_MAX], 2] call DB_fnc_asyncQuery;')
noflag("SQL fragment with an open paren and a quote (fn_gangBHistory.sqf:31)",
       '_q = "SELECT QUOTE(name), QUOTE(DATE_FORMAT(ts, \'" + "%b %e %H:%i" '
       '+ "\')), type, amount FROM gang_bank_log WHERE gangid=\'" + _gid + "\'";')
noflag("format template that emits half a file (tools/compExport.sqf:63)",
       'private _out = format ["%1 compositions%2zone_%3.sqf -- exported from 3DEN (%4 objects)'
       '%5[%6    %7%3%7, [%8, %9], %10, %11, %12,%13    [", _a, _b, _c, _d, _e, _f, _g, _h, _i, _j, _k, _l, _m];')
noflag("structured-text markup drawing a glyph (core/gps/fn_gpsHud.sqf:144)",
       '_line = "<t size=\'1.2\' color=\'#00d4ff\'>((</t>  <t size=\'1.1\'>MAKE A U-TURN</t>";')
noflag("a single bracket character as a value (core/functions/fn_handleItem.sqf:9)",
       'if (_left == "[") then {_ok = true;};')
noflag("prose with an English apostrophe (core/shops/fn_chopShopClaim.sqf:1)",
       'if ((lbCurSel 39402) isEqualTo - 1) exitWith '
       '{["You didn\'t select a vehicle to claim.", "basic"] spawn AP_fnc_handleMessage;};')
noflag("long rules prose that mentions player and vehicle (fn_welcomeUIConfig.sqf:6)",
       '_t = "<t size=\'1.4\'>Server Rules</t><br/>Exiting any vehicle while downed. '
       'Entering a player\'s house by any means other than an unlocked door. (Including sheds";')
noflag("chat/display text with a stray bracket",
       '["Mag Repack [" + outlw_MR_version, "basic"] spawn AP_fnc_handleMessage;')
noflag("procedural texture string (core/vehicle/fn_colorVehicle.sqf)",
       "_v setObjectTextureGlobal [0, '#(argb,8,8,3)color(0,0.7,0.7,0.01)'];")

# ---------------------------------------------------------------------------------------------
# CONCATENATED CONDITIONS -- the cartel entry in custom_p3ds/malden_cartel_actions.sqf is a
# real condition split over five literals. Joined it is balanced; each fragment alone is not.
# ---------------------------------------------------------------------------------------------
_CARTEL = ('_flag addAction [format ["Collect from %1", _name], {}, [_id], 6, false, true, "",\n'
           '    "alive _this"\n'
           '    + " && {(_this distance2D _target) < 8}"\n'
           '    + " && {((_target getVariable [\'AP_capData\', [0, \'\', 0]]) param [2, 0]) >= 1}"\n'
           '    + " && {((_this getVariable [\'gang_data\', [0]]) param [0, 0])"\n'
           '    + "      isEqualTo ((_target getVariable [\'AP_capData\', [0, \'\', 0]]) param [0, -1])}"\n'
           '];')
noflag("5-part concatenated condition, joined and balanced", _CARTEL)
flag("5-part concatenated condition with a paren deleted from the middle fragment",
     _CARTEL.replace("param [2, 0]) >= 1}", "param [2, 0] >= 1}"), 4)

# ---------------------------------------------------------------------------------------------
# Level-0 parity -- the checks that existed before must behave exactly as before
# ---------------------------------------------------------------------------------------------
flag("mispaired bracket", "if (a) then {\n  b = [1,2);\n};\n", 2)
flag("unclosed brace", "if (a) then {\n  b = 1;\n", 1)
flag("unterminated string", 'x = "abc;\ny = 1;\n', 1)
flag("unterminated block comment", "/* open\nx=1;\n", 1)
flag("closing with nothing open", "x = 1);\n", 1)


def main():
    fails = []
    for kind, name, src, want_line in CASES:
        rc, out = run(src)
        if kind == "FLAG":
            if rc == 0:
                fails.append("MISSED  %s\n        got: %s" % (name, out.strip()))
            elif want_line is not None and (":%d:" % want_line) not in out:
                fails.append("WRONG LINE (want %d)  %s\n        got: %s" % (want_line, name, out.strip()))
        else:
            if rc != 0:
                fails.append("CRIED WOLF  %s\n        got: %s" % (name, out.strip()))

    # the escape hatch must still disable the whole string layer
    rc, _ = run(_JEWEL % _COND_OK[:-1], "--no-strings")
    if rc != 0:
        fails.append("--no-strings should not look inside strings")
    # multiple paths and the ok line format are part of the published interface
    rc, out = run("x = (1);\n")
    if rc != 0 or not out.startswith("ok   "):
        fails.append("clean file must print 'ok   <path>' and exit 0, got %r / rc=%d" % (out, rc))

    for f in fails:
        print("FAIL " + f)
    print("\n%d/%d passed" % (len(CASES) + 2 - len(fails), len(CASES) + 2))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
