/*
    File: fn_telemetry.sqf  (APS_fnc_telemetry)
    Telemetry collector (TELEMETRY_SPEC.md, § Phase 2). Registers two scheduler-wheel jobs, the
    mission event handlers that feed the event counters, and the helpers the receivers use.

    Everything here is fire-and-forget toward the game. A tick builds a list of
    [name, labels, value] samples and hands it to the daemon's `telemetry` module through pysqf
    (chunked under the extension's 8000-char argument cap); the module stamps the samples and
    ships them to VictoriaMetrics on its own thread. The daemon stamps because SQF numbers are
    32-bit floats and an epoch in milliseconds does not survive the boundary -- nothing in this
    file ever sends a timestamp.

      telemetryServer   every 5 s   engine: fps / frame time / units / vehicles / dead / groups /
                                    markers / effects / scripts / weather; per-player network
                                    (getUserInfo: ping, bandwidth, desync) and session age;
                                    scheduler per-job ms / errors; pysqf core stats; a SELECT 1
                                    round trip; game state (duty roster, wanted, bank, events);
                                    the event counters; every client beat younger than 30 s
      telemetryCensus   every 60 s  typeOf histogram over allMissionObjects "All" (top 40 classes,
                                    rest "_other") and diag_activeSQFScripts by name (top 20)

    Event counters: AP_fnc_telemetryEvent ["type"] -- called by the mission EHs installed below
    (connect / disconnect / death_player / death_ai / vehicle_destroyed / pvp_kill) and by one-line
    hooks in fn_wantedAdd, fn_setRestrained, fn_maldenBankSRV, fn_maldenFedSRV and
    fn_jewelryEmporiumSRV. Counters only ever go up; Grafana turns them into rates.

    Client identity (APS_fnc_telemetryBeat / APS_fnc_telemetryProfile): AP_fnc_telemetryCaller
    resolves remoteExecutedOwner to [uid, name, machine] from the server's own objects. The
    headless client is the one caller the engine reports as owner 0 (and isRemoteExecuted false,
    measured 2026-09-09), so owner 0 while AP_hcOwner > 0 is the HC.

    Labels are arrays of [key, value] pairs. Metric and label names must match
    ^[a-zA-Z_:][a-zA-Z0-9_:]*$ -- a sample that does not is counted as bad on the daemon side and
    dropped, never raised.

    Server-only. No CfgRE entry: nothing may call this remotely. Called once from init.sqf after
    the scheduler is installed.
*/
if (!isServer) exitWith {};

if (isNil "AP_telemetry_clients")  then { AP_telemetry_clients  = createHashMap; };   // uid -> hashMap (name, machine, t, fps, ...)
if (isNil "AP_telemetry_events")   then { AP_telemetry_events   = createHashMap; };   // type -> count since boot
if (isNil "AP_telemetry_sessions") then { AP_telemetry_sessions = createHashMap; };   // uid -> diag_tickTime at connect
AP_telemetry_censusTop   = 40;    // object classes reported by name; the rest sum into "_other"
AP_telemetry_scriptsTop  = 20;    // script names reported; the rest sum into "_other"
AP_telemetry_clientFresh = 30;    // seconds; a beat older than this is not reported ...
AP_telemetry_clientDead  = 60;    // ... and older than this is forgotten
#define AP_TELEMETRY_CHUNK_CHARS 6500   // stay under fn_pysqfRaw's PYSQF_MAX_ARG_JSON (8000) with headroom

// Numeric client-entry keys -> metric names (fn_telemetryBeat + fn_telemetryProfile write the keys).
AP_telemetry_clientMetrics = [
    ["fps", "ap_client_fps"], ["fps_min", "ap_client_fps_min"], ["frame_ms", "ap_client_frame_ms"],
    ["vd", "ap_client_view_distance"], ["ovd", "ap_client_object_view_distance"],
    ["tg", "ap_client_terrain_grid"], ["shadow", "ap_client_shadow_distance"],
    ["near", "ap_client_near_objects"], ["near_players", "ap_client_near_players"],
    ["near_vehicles", "ap_client_near_vehicles"], ["in_veh", "ap_client_in_vehicle"],
    ["speed", "ap_client_speed"], ["pos_x", "ap_client_pos_x"], ["pos_y", "ap_client_pos_y"],
    ["displays", "ap_client_displays"], ["scr_spawn", "ap_client_scripts_spawn"],
    ["scr_execvm", "ap_client_scripts_execvm"], ["in_menu", "ap_client_in_menu"], ["alive", "ap_client_alive"],
    ["res_w", "ap_client_res_w"], ["res_h", "ap_client_res_h"], ["fov", "ap_client_fov"], ["build", "ap_client_build"]
];

// ---- helpers ---------------------------------------------------------------------------------

// [samples] call AP_fnc_telemetryPush -- ships a sample list, chunked to the extension's arg cap.
// Scheduled context only (APS_fnc_pysqfCall polls with uiSleep); the wheel runs jobs in a spawn.
AP_fnc_telemetryPush = compileFinal {
    params [["_samples", [], [[]]]];
    if (_samples isEqualTo []) exitWith {};
    private _chunk = [];
    private _send = {
        params ["_c"];
        if (_c isEqualTo []) exitWith {};
        private _r = ["telemetry.push", [_c], 5] call APS_fnc_pysqfCall;
        if !(_r param [0, false, [false]]) then {
            // Rate-limited: a daemon without the module would otherwise log every 5 s forever.
            private _now = diag_tickTime;
            if (_now - (missionNamespace getVariable ["AP_telemetry_lastErr", -1e9]) > 60) then {
                AP_telemetry_lastErr = _now;
                diag_log format ["[AP-telemetry] push refused: %1", _r param [1, "no reason"]];
            };
        };
    };
    {
        _chunk pushBack _x;
        // toJSON per sample is O(n^2) in the chunk, but a chunk is at most a few dozen samples.
        if (count (toJSON _chunk) > AP_TELEMETRY_CHUNK_CHARS) then {
            _chunk deleteAt (count _chunk - 1);
            [_chunk] call _send;
            _chunk = [_x];
        };
    } forEach _samples;
    [_chunk] call _send;
};

// ["type"] call AP_fnc_telemetryEvent -- bump a since-boot counter. Safe from any context.
AP_fnc_telemetryEvent = compileFinal {
    params [["_t", "", [""]]];
    if (_t isEqualTo "") exitWith {};
    AP_telemetry_events set [_t, (AP_telemetry_events getOrDefault [_t, 0]) + 1];
};

// [string] call AP_fnc_telemetrySanitize -> the string reduced to [A-Za-z0-9_.-], at most 32 chars.
// Client-supplied text that becomes a label value goes through here and nowhere else.
AP_fnc_telemetrySanitize = compileFinal {
    params [["_str", "", [""]]];
    private _out = [];
    {
        if ((_x >= 48 && _x <= 57) || (_x >= 65 && _x <= 90) || (_x >= 97 && _x <= 122) || _x in [45, 46, 95]) then {
            _out pushBack _x;
        };
    } forEach (toArray (_str select [0, 32]));
    toString _out
};

// call AP_fnc_telemetryCaller -> [uid, name, machine] for the remote caller, or [] when it matches
// nothing. remoteExecutedOwner is 0 BY DESIGN for the headless client (BIKI; fn_mapFetch resolves
// the HC the same way) and a player's call always carries its real owner id, so owner 0 while an
// HC is connected IS the HC. Nothing local calls the receivers; owner 0 without an HC is dropped.
AP_fnc_telemetryCaller = compileFinal {
    private _o = remoteExecutedOwner;
    if (_o < 0) exitWith { [] };
    private _hcOwner = localNamespace getVariable ["AP_hcOwner", 0];
    if (_hcOwner > 0 && { _o isEqualTo 0 || { _o == _hcOwner } }) exitWith { ["hc", "HC", "hc"] };
    private _i = allPlayers findIf { owner _x == _o };
    if (_i < 0) exitWith { [] };
    private _p = allPlayers select _i;
    [getPlayerUID _p, name _p, "client"]
};

// ---- mission event handlers (mission-scoped: re-added on every mission init) --------------------
if (isNil "AP_telemetry_ehs") then {
    AP_telemetry_ehs = [
        addMissionEventHandler ["PlayerConnected", {
            params ["_id", "_uid", "_name", "_jip", "_owner"];
            ["connect"] call AP_fnc_telemetryEvent;
            if (_uid isNotEqualTo "") then { AP_telemetry_sessions set [_uid, diag_tickTime]; };
        }],
        addMissionEventHandler ["PlayerDisconnected", {
            params ["_id", "_uid"];
            ["disconnect"] call AP_fnc_telemetryEvent;
            AP_telemetry_sessions deleteAt _uid;
        }],
        addMissionEventHandler ["EntityKilled", {
            params ["_unit", "_killer", "_instigator"];
            private _k = if (isNull _instigator) then { _killer } else { _instigator };
            if (isPlayer _unit) then {
                ["death_player"] call AP_fnc_telemetryEvent;
                if (isPlayer _k && { _k != _unit }) then { ["pvp_kill"] call AP_fnc_telemetryEvent; };
            } else {
                if (_unit isKindOf "CAManBase") then { ["death_ai"] call AP_fnc_telemetryEvent; }
                else { ["vehicle_destroyed"] call AP_fnc_telemetryEvent; };
            };
        }]
    ];
};

// ---- 5 s: server state + network + client beats ---------------------------------------------
["telemetryServer", {
    private _t0 = diag_tickTime;
    private _s = [];
    private _srv = [["machine", "server"]];
    private _hcOwner = localNamespace getVariable ["AP_hcOwner", 0];

    // engine
    _s pushBack ["ap_server_fps",     _srv, diag_fps];
    _s pushBack ["ap_server_fps_min", _srv, diag_fpsMin];
    _s pushBack ["ap_frame_ms",       _srv, diag_deltaTime * 1000];
    _s pushBack ["ap_frame_no",       _srv, diag_frameNo];
    _s pushBack ["ap_mission_fsms",   [],   count diag_activeMissionFSMs];

    // people
    private _humans = allPlayers - entities "HeadlessClient_F";
    private _west = 0; private _civ = 0; private _guer = 0;
    {
        switch (side _x) do {
            case west:        { _west = _west + 1 };
            case civilian:    { _civ  = _civ  + 1 };
            case independent: { _guer = _guer + 1 };
        };
    } forEach _humans;
    _s pushBack ["ap_players", [["side", "west"]], _west];
    _s pushBack ["ap_players", [["side", "civ"]],  _civ];
    _s pushBack ["ap_players", [["side", "guer"]], _guer];
    _s pushBack ["ap_players_total", [], count _humans];
    _s pushBack ["ap_hc_online", [], parseNumber (_hcOwner > 0)];
    private _restrained = count (localNamespace getVariable ["APS_restrainedPlayers", []]);
    _s pushBack ["ap_players_state", [["state", "downed"]],     { (_x getVariable ["AP_downed", false]) isEqualTo true } count _humans];
    _s pushBack ["ap_players_state", [["state", "restrained"]], _restrained];
    _s pushBack ["ap_players_state", [["state", "in_vehicle"]], { vehicle _x != _x } count _humans];
    _s pushBack ["ap_players_state", [["state", "dead"]],       { !alive _x } count _humans];

    // units / dead
    private _ai = allUnits select { !isPlayer _x };
    _s pushBack ["ap_units", [["kind", "player"]], (count allUnits) - (count _ai)];
    _s pushBack ["ap_units", [["kind", "ai"]],     count _ai];
    {
        private _sd = _x select 1;
        _s pushBack ["ap_units_ai", [["side", _x select 0]], { side _x == _sd } count _ai];
    } forEach [["west", west], ["east", east], ["guer", independent], ["civ", civilian]];
    private _deadMen = count allDeadMen;
    _s pushBack ["ap_dead", [["kind", "men"]],      _deadMen];
    _s pushBack ["ap_dead", [["kind", "vehicles"]], (count allDead) - _deadMen];

    // vehicles: one pass
    private _fam = createHashMapFromArray [["tank", 0], ["car", 0], ["air", 0], ["ship", 0], ["static", 0], ["motorcycle", 0], ["land_other", 0], ["thing", 0], ["other", 0]];
    private _own = createHashMapFromArray [["server", 0], ["hc", 0], ["player", 0]];
    private _empty = 0; private _damaged = 0; private _destroyed = 0;
    {
        private _k = switch (true) do {
            case (_x isKindOf "Tank"):         { "tank" };
            case (_x isKindOf "Car"):          { "car" };
            case (_x isKindOf "Air"):          { "air" };
            case (_x isKindOf "Ship"):         { "ship" };
            case (_x isKindOf "StaticWeapon"): { "static" };
            case (_x isKindOf "Motorcycle"):   { "motorcycle" };
            case (_x isKindOf "LandVehicle"):  { "land_other" };   // slingload cargo, wheeled statics
            case (_x isKindOf "Thing"):        { "thing" };        // physics props the engine lists as vehicles
            default { "other" };
        };
        _fam set [_k, (_fam get _k) + 1];
        private _o = owner _x;
        private _ok = if (local _x || { _o <= 2 }) then { "server" } else { if (_o == _hcOwner) then { "hc" } else { "player" } };
        _own set [_ok, (_own get _ok) + 1];
        if (!alive _x) then { _destroyed = _destroyed + 1; } else {
            if (crew _x isEqualTo []) then { _empty = _empty + 1; };
            if (damage _x > 0.5) then { _damaged = _damaged + 1; };
        };
    } forEach vehicles;
    { _s pushBack ["ap_vehicles",       [["family", _x]], _y]; } forEach _fam;
    { _s pushBack ["ap_vehicles_owner", [["owner", _x]],  _y]; } forEach _own;
    _s pushBack ["ap_vehicles_state", [["state", "empty"]],     _empty];
    _s pushBack ["ap_vehicles_state", [["state", "damaged"]],   _damaged];
    _s pushBack ["ap_vehicles_state", [["state", "destroyed"]], _destroyed];

    // entity counts + leak detectors
    {
        _s pushBack ["ap_entities", [["kind", _x select 0]], _x select 1];
    } forEach [
        ["units",           count allUnits],
        ["vehicles",        count vehicles],
        ["dead",            count allDead],
        ["groups",          count allGroups],
        ["simple",          count (allSimpleObjects [])],
        ["mission_objects", count (allMissionObjects "All")],
        ["weapon_holders",  count (allMissionObjects "WeaponHolder")],
        ["mines",           count allMines]
    ];
    _s pushBack ["ap_groups_empty", [], { units _x isEqualTo [] } count allGroups];
    _s pushBack ["ap_markers", [], count allMapMarkers];
    _s pushBack ["ap_effects", [["kind", "particle"]], count (allMissionObjects "#particlesource")];
    _s pushBack ["ap_effects", [["kind", "light"]],    count (allMissionObjects "#lightpoint")];
    _s pushBack ["ap_effects", [["kind", "sound"]],    count (allMissionObjects "#soundonvehicle")];
    _s pushBack ["ap_weapon_holders", [["kind", "ground"]],    count (allMissionObjects "GroundWeaponHolder")];
    _s pushBack ["ap_weapon_holders", [["kind", "simulated"]], count (allMissionObjects "WeaponHolderSimulated")];

    // scripts
    (diag_activeScripts) params [["_sp", 0], ["_ev", 0], ["_ex", 0], ["_fsm", 0]];
    {
        _s pushBack ["ap_scripts", [["kind", _x select 0]], _x select 1];
    } forEach [["spawn", _sp], ["execvm", _ev], ["exec", _ex], ["fsm", _fsm]];
    _s pushBack ["ap_sqf_scripts_active", [], count diag_activeSQFScripts];

    // weather / time
    _s pushBack ["ap_env_daytime",         [], daytime];
    _s pushBack ["ap_env_overcast",        [], overcast];
    _s pushBack ["ap_env_rain",            [], rain];
    _s pushBack ["ap_env_fog",             [], fog];
    _s pushBack ["ap_env_wind",            [], vectorMagnitude wind];
    _s pushBack ["ap_env_sun",             [], sunOrMoon];
    _s pushBack ["ap_env_time_multiplier", [], timeMultiplier];

    // per-user network (ping / bandwidth / desync) and session age, from the engine's own table
    {
        private _ui = getUserInfo _x;
        if (count _ui >= 11) then {
            _ui params ["_pid", "_own", "_uid", "_sname", "_dname", "_steam", "_cstate", "_isHC", "_admin", "_net", "_unit"];
            if (_isHC || { _uid isNotEqualTo "" }) then {
                private _l = if (_isHC) then { [["machine", "hc"], ["uid", "hc"], ["name", "HC"]] }
                                        else { [["machine", "client"], ["uid", _uid], ["name", _sname]] };
                _net params [["_ping", 0, [0]], ["_bw", 0, [0]], ["_desync", 0, [0]]];
                _s pushBack ["ap_player_ping_ms",   _l, _ping];
                _s pushBack ["ap_player_bandwidth", _l, _bw];
                _s pushBack ["ap_player_desync",    _l, _desync];
                _s pushBack ["ap_player_client_state", _l, if (_cstate isEqualType "") then { parseNumber _cstate } else { _cstate }];
                _s pushBack ["ap_player_admin", _l, _admin];
                private _t = AP_telemetry_sessions getOrDefault [_uid, -1];
                if (_t >= 0) then { _s pushBack ["ap_player_session_s", _l, round (diag_tickTime - _t)]; };
            };
        };
    } forEach allUsers;

    // scheduler wheel: tuple slots 5 = consecutive errors, 6 = last run ms, 4 = enabled (fn_scheduler.sqf header)
    private _enabled = 0;
    {
        private _job = _y;
        if (_job select 4) then { _enabled = _enabled + 1; };
        _s pushBack ["ap_sched_last_ms", [["job", _x]], _job select 6];
        _s pushBack ["ap_sched_errors",  [["job", _x]], _job select 5];
    } forEach (localNamespace getVariable ["AP_scheduler_jobs", createHashMap]);
    _s pushBack ["ap_sched_jobs_enabled", [], _enabled];

    // pysqf core counters. The stats verb answers {"version","backend","ready","store":{...},"health"}
    // (pysqf.c verb_stats); the ticket counters live under "store" (results.c). A refused call = no rows.
    private _ps = ["stats"] call APS_fnc_pysqfRaw;
    if ((_ps param [0, "err", [""]]) isEqualTo "ok") then {
        private _j = fromJSON (_ps param [1, "{}", [""]]);
        if (_j isEqualType createHashMap) then {
            private _store = _j getOrDefault ["store", createHashMap];
            if (_store isEqualType createHashMap) then {
                {
                    private _v = _store getOrDefault [_x, -1];
                    if (_v isEqualType 0 && { _v >= 0 }) then { _s pushBack ["ap_pysqf", [["stat", _x]], _v]; };
                } forEach ["issued", "completed_ok", "completed_err", "pending", "refused", "dropped_late", "evicted_pending", "evicted_complete"];
            };
            _s pushBack ["ap_pysqf_ready", [], parseNumber (_j getOrDefault ["ready", false])];
        };
    };

    // the whole DB path, measured: SQF -> extension -> daemon -> PostgreSQL -> back
    private _d0 = diag_tickTime;
    ["SELECT 1", 2] call DB_fnc_asyncQuery;
    _s pushBack ["ap_db_rtt_ms", [], round ((diag_tickTime - _d0) * 1000)];

    _s pushBack ["ap_mission_time_s",   [], time];
    _s pushBack ["ap_server_time_s",    [], serverTime];
    _s pushBack ["ap_process_uptime_s", [], diag_tickTime];

    // game state
    if (!isNil {localNamespace getVariable "AP_dutyRoster"} && { (localNamespace getVariable "AP_dutyRoster") isEqualType createHashMap }) then {
        private _maxsec = 0; private _trauma = 0;
        {
            if (_y isEqualType []) then {
                switch (_y param [0, ""]) do {
                    case "maxsec": { _maxsec = _maxsec + 1 };
                    case "trauma": { _trauma = _trauma + 1 };
                };
            };
        } forEach (localNamespace getVariable "AP_dutyRoster");
        _s pushBack ["ap_duty", [["faction", "maxsec"]], _maxsec];
        _s pushBack ["ap_duty", [["faction", "trauma"]], _trauma];
    };
    private _wl = localNamespace getVariable ["APS_wantedList", []];
    if (_wl isEqualType []) then {
        private _bounty = 0;
        { if (_x isEqualType []) then { private _b = _x param [3, 0]; if (_b isEqualType 0) then { _bounty = _bounty + _b; }; }; } forEach _wl;
        _s pushBack ["ap_wanted", [], count _wl];
        _s pushBack ["ap_wanted_bounty_total", [], _bounty];
    };
    if (!isNil "AP_bank_funds" && { AP_bank_funds isEqualType 0 }) then { _s pushBack ["ap_bank_funds", [], AP_bank_funds]; };
    if (!isNil "AP_event_queue" && { AP_event_queue isEqualType [] }) then { _s pushBack ["ap_event_queue", [], count AP_event_queue]; };

    // event counters (since boot)
    { _s pushBack ["ap_events_total", [["type", _x]], _y]; } forEach AP_telemetry_events;

    // client beats: report the fresh ones, forget the dead ones. Keys are collected first because
    // deleting from a hashMap while forEach walks it is undefined.
    private _now = diag_tickTime;
    private _dead = [];
    {
        private _e = _y;
        private _age = _now - (_e getOrDefault ["t", -1e9]);
        if (_age > AP_telemetry_clientDead) then { _dead pushBack _x; } else {
            if (_age <= AP_telemetry_clientFresh) then {
                private _l = [["machine", _e getOrDefault ["machine", "client"]], ["uid", _x], ["name", _e getOrDefault ["name", ""]]];
                {
                    _x params ["_key", "_metric"];
                    if (_key in _e) then { _s pushBack [_metric, _l, _e get _key]; };
                } forEach AP_telemetry_clientMetrics;
                if ("branch" in _e) then {
                    _s pushBack ["ap_client_info", _l + [["branch", _e get "branch"], ["lang", _e getOrDefault ["lang", ""]]], 1];
                };
            };
        };
    } forEach AP_telemetry_clients;
    { AP_telemetry_clients deleteAt _x; } forEach _dead;

    // beats received since boot (APS_fnc_telemetryBeat). Zero while clients are connected means the
    // beats never reach the server; non-zero with no ap_client_* rows means the receiver dropped them.
    _s pushBack ["ap_telemetry_beats_total", [], missionNamespace getVariable ["AP_telemetry_beatsTotal", 0]];
    _s pushBack ["ap_telemetry_beats_unmatched_total", [], missionNamespace getVariable ["AP_telemetry_beatsUnmatched", 0]];
    _s pushBack ["ap_telemetry_tick_ms", [], round ((diag_tickTime - _t0) * 1000)];
    [_s] call AP_fnc_telemetryPush;
}, 5, false, true] call AP_fnc_schedule;

// ---- 60 s: object census by class + scripts by name ---------------------------------------------
["telemetryCensus", {
    params ["_st"];
    private _t0 = diag_tickTime;
    private _s = [];

    // objects by class
    private _h = createHashMap;
    {
        private _c = typeOf _x;
        if (_c isEqualTo "") then { _c = "_untyped"; };
        _h set [_c, (_h getOrDefault [_c, 0]) + 1];
    } forEach (allMissionObjects "All");
    private _rows = [];
    private _total = 0;
    { _rows pushBack [_y, _x]; _total = _total + _y; } forEach _h;   // [count, class] so sort orders by count
    _rows sort false;                                                  // descending
    private _other = 0;
    {
        if (_forEachIndex < AP_telemetry_censusTop) then {
            _s pushBack ["ap_objects", [["class", _x select 1]], _x select 0];
        } else {
            _other = _other + (_x select 0);
        };
    } forEach _rows;
    _s pushBack ["ap_objects", [["class", "_other"]], _other];
    _s pushBack ["ap_objects_total", [], _total];

    // scripts by name (element 0 of each diag_activeSQFScripts row, reduced to its basename)
    private _scripts = diag_activeSQFScripts;
    if !(_st getOrDefault ["logged", false]) then {
        _st set ["logged", true];
        diag_log format ["[AP-telemetry] diag_activeSQFScripts sample (%1 rows): %2", count _scripts, str (_scripts select [0, 2])];
    };
    private _sh = createHashMap;
    {
        private _n = if (_x isEqualType []) then { _x param [0, "?"] } else { _x };
        if !(_n isEqualType "") then { _n = str _n; };
        // An anonymous spawn's "name" is its CODE (measured live: "<spawn>\nparams [...]..."), so keep
        // only its first line, trimmed -- enough to recognise it, bounded so it cannot explode labels.
        private _first = (_n splitString (toString [10, 13])) param [0, _n];
        if (_first isEqualTo "<spawn>") then { _first = "<spawn> " + ((_n splitString (toString [10, 13])) param [1, ""]); };
        _n = _first;
        private _parts = _n splitString "\/";
        _n = (_parts param [(count _parts) - 1, _n]) select [0, 48];
        if (_n isEqualTo "") then { _n = "_unnamed"; };
        _sh set [_n, (_sh getOrDefault [_n, 0]) + 1];
    } forEach _scripts;
    private _srows = [];
    { _srows pushBack [_y, _x]; } forEach _sh;
    _srows sort false;
    private _sother = 0;
    {
        if (_forEachIndex < AP_telemetry_scriptsTop) then {
            _s pushBack ["ap_sqf_scripts", [["name", _x select 1]], _x select 0];
        } else {
            _sother = _sother + (_x select 0);
        };
    } forEach _srows;
    _s pushBack ["ap_sqf_scripts", [["name", "_other"]], _sother];

    _s pushBack ["ap_census_ms", [], round ((diag_tickTime - _t0) * 1000)];
    [_s] call AP_fnc_telemetryPush;
}, 60, false, true] call AP_fnc_schedule;

diag_log format ["[AP-telemetry] collector registered (5 s server tick, 60 s census, top %1 classes / %2 scripts, %3 event handlers)", AP_telemetry_censusTop, AP_telemetry_scriptsTop, count AP_telemetry_ehs];
