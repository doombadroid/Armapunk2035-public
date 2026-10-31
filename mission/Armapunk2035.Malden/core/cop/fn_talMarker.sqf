// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_talMarker.sqf  (AP_fnc_talMarker)
    LooneyBin 2026-07-20: TAL OS shared marker -- a dispatch pin or a backup beacon dropped onto every
    receiving client's map locally (no global marker churn). Auto-expires.
*/
params [["_pos", [0,0,0], [[]]], ["_label", "", [""]], ["_col", "ColorBlue", [""]], ["_urgent", false, [false]]];
if (_pos isEqualTo [0,0,0]) exitWith {};
private _m = createMarkerLocal [format ["tal_pin_%1_%2", round diag_tickTime, floor random 9999], _pos];
_m setMarkerTypeLocal (if (_urgent) then { "hd_destroy" } else { "hd_dot" });
_m setMarkerColorLocal _col;
_m setMarkerTextLocal _label;
if (_urgent) then { _m setMarkerSizeLocal [1.3, 1.3]; };
[_m, _urgent] spawn {params ["_m", "_urgent"];
    uiSleep (if (_urgent) then { 120 } else { 60 });
    deleteMarkerLocal _m;};
