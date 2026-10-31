/*
    fn_deckPing.sqf — drop a short-lived local map ping.

    Used by the web deck's MARK and LOCATE actions. This is NOT map content: the
    standing rule that markers belong in the map layer rather than in script is
    about the world's fixed markers, which have to stay editable in Eden. A ping
    is transient, client-only, and deletes itself, so it never reaches mission.sqm.

    Usage:  [getPosATL _obj, "Marcus Kade"] call AP_fnc_deckPing;
*/

params [["_pos", [0,0,0], [[]], [2,3]], ["_text", "", [""]], ["_life", 45, [0]]];
if (_pos isEqualTo [0,0,0]) exitWith { false };

private _name = format ["AP_deckPing_%1", round (diag_tickTime * 1000)];
private _m = createMarkerLocal [_name, _pos];
_m setMarkerTypeLocal  "hd_dot";
_m setMarkerColorLocal "ColorYellow";
_m setMarkerTextLocal  _text;

[_name, _life] spawn {
    params ["_name", "_life"];
    uiSleep _life;
    deleteMarkerLocal _name;
};

true
