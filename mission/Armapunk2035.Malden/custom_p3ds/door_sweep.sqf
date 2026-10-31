/*
    custom_p3ds\door_sweep.sqf -- wire the tower door systems by MODEL SWEEP, on every machine.

    The towers are map rows now (mapdb, 2026-09-04: model + on_server in map_objects), created
    by the streamer on clients and by APS_fnc_mapLoad on the server. Both set AP_mapFarDone once
    the always-loaded rows exist, so this waits for that instead of a fixed delay after a
    placement file. Everything below is the sweep block that lived at the end of
    malden_buildings.sqf: every instance of a model gets wired, serialized per instance because
    the spawners append into shared flat state arrays at a per-instance base (concurrent bodies
    would interleave their pushBacks and scramble the flat door indices).
    Runs on the server (initServer.sqf, after fn_suiteData) AND every client (initPlayerLocal.sqf).
*/
[] spawn {
    waitUntil { uiSleep 1; missionNamespace getVariable ["AP_mapFarDone", false] };
    sleep 2;   // leaves settle (do not name the spawn command in this comment)
    {
        _x params ["_m", "_fns"];
        private _t = (allSimpleObjects []) select { _m in toLower ((getModelInfo _x) select 0) };
        {
            private _b = _x;
            {
                private _h = [_b] execVM _x;
                waitUntil { scriptDone _h };
            } forEach _fns;
        } forEach _t;
        if (count _t > 0) then {
            diag_log format ["[APDOORS] %1: wired %2 instance(s)", _m, count _t];
        };
    } forEach [
        // v18 removed the hologram layer from the tower (no HOLO_*, no ad wall, no TICKER_screen_*),
        // so lux_ticker.sqf is UNWIRED; the script and its generated point data stay in the repo.
        // Skyscraper20 was dropped from the PBO on 2026-09-04 (owner: unplaced, not coming back soon).
        ["skyscraper30_r17",  ["custom_p3ds\lux_doors.sqf",
                              "custom_p3ds\lux_fixtures.sqf",
                              "custom_p3ds\lux_freefall.sqf"]]
    ];
};
