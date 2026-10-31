/*
    File: fn_mapFocus.sqf  (AP_fnc_mapFocus)
    Where the streamer measures distance from: AP_mapFocus when set (the self-test, and
    AP_fnc_mapWaitLoaded pre-loading a spawn target), else the suspect-ESP camera's target, else
    the player. Returns [] when there is no focus.
    The old loop also swapped in AP_ses_last_pos for a civilian near respawn_civilian; on Malden
    that marker is in the middle of town, so the swap pointed the streamer at wherever the player
    last logged out while they stood in an empty plaza (2026-09-04). Pre-loading a spawn target is
    now explicit: fn_initCiv asks for it through AP_fnc_mapWaitLoaded.
*/
if (!isNil "AP_mapFocus") exitWith { AP_mapFocus };
if (!alive player) exitWith { [] };
private _pos = getPosWorld player;
if (!isNil "suspectESP_suspectObj" && {!isNull suspectESP_suspectObj}) then { _pos = getPosWorld suspectESP_suspectObj; };
if (!(_pos isEqualType []) || {count _pos < 2}) then { _pos = getPosWorld player; };
_pos
