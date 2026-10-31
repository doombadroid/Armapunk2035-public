if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
params[["_toMe", false, [false]], ["_toThem", false, [false]]];
if (_toMe || _toThem) exitWith {private _unit = missionNamespace getVariable(lbData[12901, lbCursel 12901]);
    if (isNil "_unit") exitWith {};
    if (isNull _unit || {_unit isEqualTo player}) exitWith {};
    if (_toMe) then {(vehicle _unit) setPosATL(getPosATL player);
        if (_unit getVariable["AP_timeTrialActive", false]) then {_unit setVariable['AP_timeTrialActive', false, true];}; [
            ["-ADMINACTION-", player, profileName, format["TPed %1 (%2) to self. Nearby players: %3.", name _unit, getPlayerUID _unit, (allPlayers select {
                _x distance player < 100}) apply {name _x}]], 'APS_fnc_logIt', 2, false, false] spawn AP_fnc_MP;} else {
        player setPosATL(getPosATL vehicle _unit); [
            ["-ADMINACTION-", player, profileName, format["TPed to %1 (%2). Nearby players: %3.", name _unit, getPlayerUID _unit, (allPlayers select {
                _x distance player < 100}) apply {name _x}]], 'APS_fnc_logIt', 2, false, false] spawn AP_fnc_MP;};};
[] spawn {
    while { dialog } do { closeDialog 0; uiSleep 0.05; };
    // owner 2026-08-13: map-click teleport moved to MALDEN GRID. The grid arms
    // its TP mode (page reads AP_mapTpArm on open), the next map click asks to
    // confirm, AP_fnc_mapOpen's mapTeleport verb moves and logs. The old
    // paper-map path below it is gone with the paper map.
    uiNamespace setVariable ["AP_mapTpArm", true];
    [] call AP_fnc_webMap;
};
