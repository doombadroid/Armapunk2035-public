/*
    File: fn_mapWaitLoaded.sqf  (AP_fnc_mapWaitLoaded)
    Pre-load the world around _pos and block until the cell under it has been received and one
    create pass has run there, or _timeout seconds pass. fn_initCiv calls this before moving the
    player to their saved position, so they arrive in a built town (the old streamer got that by
    pointing itself at AP_ses_last_pos while the player stood at respawn; this does it on request).
    While waiting, AP_mapFocus is set to _pos so the tick fetches and creates around it; the
    override is cleared afterwards unless something else had set it.
    params: 0 = position, 1 = timeout (s)     returns: true when loaded
*/
params [["_pos", [], [[]]], ["_timeout", 20, [0]]];
private _cells = localNamespace getVariable "AP_mapCells";   // the stores: localNamespace, see AP_fnc_mapStreamInit
if (isNil "_cells" || {_pos isEqualTo []} || {count _pos < 2}) exitWith { false };
private _k = [_pos, -1] call AP_fnc_mapCellFor;
private _mine = isNil "AP_mapFocus";
if (_mine) then { AP_mapFocus = [_pos select 0, _pos select 1, 0]; };
private _t = diag_tickTime;
private _passes = 0;
while { !((_cells getOrDefault [_k, "none"]) isEqualTo "loaded" && {_passes > 0}) && {diag_tickTime - _t < _timeout} } do {
    [] call AP_fnc_mapTick;
    if ((_cells getOrDefault [_k, "none"]) isEqualTo "loaded") then { _passes = _passes + 1; };
    uiSleep 1;
};
if (_mine) then { AP_mapFocus = nil; };
(_cells getOrDefault [_k, "none"]) isEqualTo "loaded"
