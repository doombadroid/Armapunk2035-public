// DEV INSTRUMENTATION -- 2026-07-27. Delete this file and its execVM in initServer.sqf before any live pack.
//
// Server-side half of the 50 km slot-hold diagnosis. simulationEnabled is a LOCAL query, so the server's
// answer and the joining client's answer are different facts:
//   server says OFF + client falls  -> the sqm attribute applied here but not on the client that took the slot
//   server says ON                  -> mission.sqm's disableSimulation never took effect anywhere
//
// NOTE: description.ext has disabledAI=1, so UNOCCUPIED playable slots are not live entities --
// playableUnits is 0 until somebody joins. The engine builds the unit from the sqm entry at join time,
// which is exactly the path under test. So this watches joins rather than sampling idle slots.
if (!isServer) exitWith {};

[] spawn {
    uiSleep 10;
    diag_log format ["[SIMPROBE-SRV] armed. playableUnits=%1 allPlayers=%2 (disabledAI=1 -> 0 until a join)",
        count playableUnits, count allPlayers];

    private _seen = [];
    private _t0 = diag_tickTime;

    // watch for an hour -- a dev test session can start whenever
    while { (diag_tickTime - _t0) < 3600 } do {
        {
            private _u = _x;
            if (!(_u in _seen) && {!isNull _u}) then {
                _seen pushBack _u;
                diag_log format ["[SIMPROBE-SRV] JOIN %1 (%2) sim=%3 posASL=%4 local=%5 owner=%6 t=%7",
                    name _u, typeOf _u, simulationEnabled _u, getPosASL _u, local _u, owner _u,
                    (diag_tickTime - _t0) toFixed 1];
                [_u] spawn {
                    params ["_u"];
                    for "_k" from 1 to 45 do {
                        if (isNull _u) exitWith { diag_log "[SIMPROBE-SRV]   unit went null"; };
                        diag_log format ["[SIMPROBE-SRV]   %1 t+%2s sim=%3 z=%4 velZ=%5 local=%6",
                            name _u, _k * 2, simulationEnabled _u,
                            ((getPosASL _u) select 2) toFixed 1, (velocity _u) select 2, local _u];
                        uiSleep 2;
                    };
                };
            };
        } forEach allPlayers;
        uiSleep 2;
    };
    diag_log "[SIMPROBE-SRV] watch window closed";
};
