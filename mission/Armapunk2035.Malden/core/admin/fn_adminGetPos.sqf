// owner 2026-06-14: GET POS -- the read-side counterpart to fn_adminSetPos. Reads the current position of
// the SELF (arg true) or the SELECTED player in the admin list (arg false), writes it into the SET POS edit
// box (idc 12929) so you can teleport to / tweak it, copies it to the clipboard, and prints the coords +
// map grid to systemChat. Mirrors the "!pos" command.  Call:  [true] spawn AP_fnc_adminGetPos;
params [["_self", true, [true]]];
if ((call AP_adminLevel) <= 1) exitWith {};
private _u = player;
if (!_self) then {private _sel = lbCurSel 12901;
    _u = if (_sel isEqualTo -1) then { objNull } else { missionNamespace getVariable (lbData [12901, _sel]) };};
if (isNull _u) exitWith {["You did not select a player.", "basic"] spawn AP_fnc_handleMessage;};
private _p = (getPosATL _u) apply { (round (_x * 100)) / 100 };
private _box = (findDisplay 12900) displayCtrl 12929;
if (!isNull _box) then { _box ctrlSetText (str _p); };
copyToClipboard (str _p);
private _who = if (_self) then { "You" } else { name _u };
systemChat format ["GET POS -- %1: %2  (grid %3). Copied to clipboard + filled the SET POS box.", _who, _p, mapGridPosition _u];
