/*
    File: fn_telemetryBeat.sqf  (APS_fnc_telemetryBeat)
    Receives one client's telemetry beat (TELEMETRY_SPEC.md § Phase 2 D). Client side:
    AP_fnc_telemetryBeat, every 10 s, via AP_fnc_MP -> remoteExecCall (CfgRE.hpp allowedTargets = 2).

        [fps, fpsMin, frameMs, viewDistance, objectViewDistance, terrainGrid, shadowDistance,
         nearObjects, nearPlayers, nearVehicles, inVehicle, speed, posX, posY, displays,
         scriptsSpawn, scriptsExecVM, inMenu, alive]        -- nineteen numbers, nothing else

    Identity is NEVER read from the payload (sec-log-attribution-rule): AP_fnc_telemetryCaller
    resolves remoteExecutedOwner to the server's own player object, or to the headless client
    (the one caller the engine reports as owner 0, by design -- and isRemoteExecuted false,
    measured 2026-09-09). An owner that matches nothing is dropped. Every number is clamped, so
    a modified client can at worst lie about its own FPS. The 5 s collector job
    (fn_telemetry.sqf) reports entries younger than 30 s and forgets entries older than 60 s;
    APS_fnc_telemetryProfile adds the once-per-session keys to the same entry.

    Runs unscheduled (remoteExecCall) and does no I/O: one hashMap write.
*/
if (!isServer) exitWith {};
params [
    ["_fps", 0, [0]], ["_fpsMin", 0, [0]], ["_frameMs", 0, [0]], ["_vd", 0, [0]], ["_ovd", 0, [0]],
    ["_tg", 0, [0]], ["_shadow", 0, [0]], ["_near", 0, [0]], ["_nearP", 0, [0]], ["_nearV", 0, [0]],
    ["_inVeh", 0, [0]], ["_speed", 0, [0]], ["_px", 0, [0]], ["_py", 0, [0]], ["_displays", 0, [0]],
    ["_scrSpawn", 0, [0]], ["_scrExecVM", 0, [0]], ["_inMenu", 0, [0]], ["_alive", 0, [0]]
];

AP_telemetry_beatsTotal = (missionNamespace getVariable ["AP_telemetry_beatsTotal", 0]) + 1;
if (isNil "AP_fnc_telemetryCaller") exitWith {};   // collector not installed yet (boot order)

private _who = call AP_fnc_telemetryCaller;
if (_who isEqualTo []) exitWith {
    AP_telemetry_beatsUnmatched = (missionNamespace getVariable ["AP_telemetry_beatsUnmatched", 0]) + 1;
    if (AP_telemetry_beatsUnmatched <= 3) then {
        diag_log format ["[AP-telemetry] beat from owner %1 matched no player (hcOwner %2, %3 players)", remoteExecutedOwner, localNamespace getVariable ["AP_hcOwner", 0], count allPlayers];
    };
};
_who params ["_uid", "_name", "_machine"];

if (isNil "AP_telemetry_clients") then { AP_telemetry_clients = createHashMap; };
if !(_uid in AP_telemetry_clients) then {
    diag_log format ["[AP-telemetry] first beat from %1 (%2, owner %3, isRemoteExecuted %4)", _name, _machine, remoteExecutedOwner, isRemoteExecuted];
};
private _e = AP_telemetry_clients getOrDefault [_uid, createHashMap];   // keeps the profile keys across beats
_e set ["name", _name];
_e set ["machine", _machine];
_e set ["t", diag_tickTime];
_e set ["fps",           (_fps       max 0) min 1000];
_e set ["fps_min",       (_fpsMin    max 0) min 1000];
_e set ["frame_ms",      (_frameMs   max 0) min 10000];
_e set ["vd",            (_vd        max 0) min 40000];
_e set ["ovd",           (_ovd       max 0) min 40000];
_e set ["tg",            (_tg        max 0) min 100];
_e set ["shadow",        (_shadow    max 0) min 1000];
_e set ["near",          (_near      max 0) min 100000];
_e set ["near_players",  (_nearP     max 0) min 200];
_e set ["near_vehicles", (_nearV     max 0) min 10000];
_e set ["in_veh",        (_inVeh     max 0) min 1];
_e set ["speed",         (_speed     max -1000) min 5000];
_e set ["pos_x",         (_px        max -100000) min 100000];
_e set ["pos_y",         (_py        max -100000) min 100000];
_e set ["displays",      (_displays  max 0) min 1000];
_e set ["scr_spawn",     (_scrSpawn  max 0) min 100000];
_e set ["scr_execvm",    (_scrExecVM max 0) min 100000];
_e set ["in_menu",       (_inMenu    max 0) min 1];
_e set ["alive",         (_alive     max 0) min 1];
AP_telemetry_clients set [_uid, _e];
