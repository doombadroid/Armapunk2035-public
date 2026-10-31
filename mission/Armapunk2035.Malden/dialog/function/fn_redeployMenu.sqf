private _radius = 500;
if ((AP_effSide isEqualTo civilian)) exitWith {};
if !(isNull objectParent player) exitWith {};
if (AP_inCombat) exitWith {["You were recently near or in combat. Leave combat and try again.", "basic"] spawn AP_fnc_handleMessage;};
disableSerialization;
// owner 2026-09-11: the 3D spawn screen first, same contract as fn_spawnMenu -- true means it took
// the screen and has already finished; anything else falls through to the native dialog below. The
// redeploy flag rides through to AP_fnc_spawnConfirm, which is what arms the 15 s abort countdown.
if ([true] call AP_fnc_spawnWebOpen) exitWith {};
["redeploy_selection"] call AP_fnc_createDialog;
private _spCfg = [AP_effSide] call AP_fnc_spawnPointCfg; {private _markerName = (_spCfg select _forEachIndex) select 1;
    if (!("phouse_" in ((_spCfg select _forEachIndex) select 0))) then {
        _markerName = _markerName + format[" [%1]", count(allplayers select {
            (_x distance2d(getMarkerPos((_spCfg select _forEachIndex) select 0))) < _radius})];};
    lbAdd[38510, _markerName];}
forEach _spCfg;
if !(AP_disabled_spawns isEqualTo[]) then {[] spawn {while {uiSleep 2;
            !(AP_disabled_spawns isEqualTo[])}
        do {private _disabledSpawns = count(AP_disabled_spawns);
            waitUntil {uiSleep 2;
                _disabledSpawns != (count AP_disabled_spawns)};
            lbClear 38510;
            private _spCfg = [AP_effSide] call AP_fnc_spawnPointCfg; {private _markerName = (_spCfg select _forEachIndex) select 1;
                if (!("phouse_" in ((_spCfg select _forEachIndex) select 0))) then {
                    _markerName = _markerName + format[" [%1]", count(allplayers select {
                        (_x distance2d(getMarkerPos((_spCfg select _forEachIndex) select 0))) < _radius})];};
                lbAdd[38510, _markerName];}
            forEach _spCfg;};};};
private _sp = _spCfg select 0;
[(findDisplay 38500) displayCtrl 38502, 1, 0.1, getMarkerPos(_sp select 0)] call AP_fnc_setMapPosition;
AP_spawn_point = _sp;