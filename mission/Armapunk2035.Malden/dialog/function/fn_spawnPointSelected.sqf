disableSerialization;
params[["_control", controlNull, [controlNull]], ["_selection", 0, [0]]];
private _spCfg = [AP_effSide] call AP_fnc_spawnPointCfg;
private _sp = _spCfg select _selection;
if ((_sp select 1) isEqualTo "Mobile HQ") then {
    [((findDisplay 38500) displayCtrl 38502), 1, 0.1, (_sp select 0)] call AP_fnc_setMapPosition;} else {
    [((findDisplay 38500) displayCtrl 38502), 1, 0.1, getMarkerPos(_sp select 0)] call AP_fnc_setMapPosition;};
AP_spawn_point = _sp;