/*
    File: fn_telemetryBeat.sqf  (AP_fnc_telemetryBeat)
    Client / headless-client telemetry beat (TELEMETRY_SPEC.md § Phase 2 D). Spawned once from
    init.sqf on every machine that is not the server -- BEFORE the headless-client branch, so the
    HC reports too.

    Every 10 s, nineteen numbers -> APS_fnc_telemetryBeat on the server (CfgRE.hpp
    allowedTargets = 2):

        fps, fpsMin, frameMs, viewDistance, objectViewDistance, terrainGrid, shadowDistance,
        nearObjects, nearPlayers, nearVehicles, inVehicle, speed, posX, posY, displays,
        scriptsSpawn, scriptsExecVM, inMenu, alive

    Once per session, after the first beat, a profile -> APS_fnc_telemetryProfile:

        resW, resH, fovTop, buildNumber, steamBranch, language

    The server takes the identity from remoteExecutedOwner and clamps every value (and
    sanitises the two strings), so these payloads grant nothing.

    For a player, nearObjects is `count (player nearObjects 300)` -- the crowd-around-you number
    that explains a client's FPS better than anything global -- nearPlayers and nearVehicles are
    the human and vehicle share of it, and posX/posY make an FPS heatmap possible. For the HC the
    three "near" slots carry its local units, local groups and owned vehicles (the autopilot
    fleet). Reads only; nothing here touches game state.
*/
if (isServer) exitWith {};
private _hc = !hasInterface;
private _profiled = false;
while { true } do {
    uiSleep 10;
    private _near = 0; private _nearP = 0; private _nearV = 0;
    private _inVeh = 0; private _speed = 0; private _px = 0; private _py = 0;
    private _inMenu = 0; private _alive = 0;
    if (_hc) then {
        _near  = { local _x } count allUnits;
        _nearP = { local _x } count allGroups;
        _nearV = { local _x } count vehicles;
    } else {
        if (!isNull player) then {
            private _p = getPos player;
            _px = round (_p select 0);
            _py = round (_p select 1);
            _alive = parseNumber (alive player);
            _inVeh = parseNumber (vehicle player != player);
            _speed = round (speed (vehicle player));
            _near  = count (player nearObjects 300);
            _nearP = { isPlayer _x && { _x != player } } count (player nearEntities ["CAManBase", 300]);
            _nearV = count (player nearEntities [["Car", "Air", "Ship", "Tank"], 300]);
            _inMenu = parseNumber (dialog || { !isNull (findDisplay 49) });
        };
    };
    (diag_activeScripts) params [["_sp", 0], ["_ev", 0]];
    [[
        round diag_fps, round diag_fpsMin, diag_deltaTime * 1000,
        round viewDistance, round (getObjectViewDistance select 0), getTerrainGrid, round getShadowDistance,
        _near, _nearP, _nearV, _inVeh, _speed, _px, _py,
        count allDisplays, _sp, _ev, _inMenu, _alive
    ], "APS_fnc_telemetryBeat", 2, false, true] spawn AP_fnc_MP;

    if (!_profiled && !_hc) then {
        _profiled = true;
        private _r = getResolution;
        private _pv = productVersion;
        [[_r param [0, 0], _r param [1, 0], _r param [6, 0], _pv param [3, 0], _pv param [8, ""], language],
            "APS_fnc_telemetryProfile", 2, false, true] spawn AP_fnc_MP;
    };
};
