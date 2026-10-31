/*
    File: fn_mapSelfTest.sqf  (AP_fnc_mapSelfTest)
    Client-side self-test of the map runtime (mapdb). Written for a HEADLESS client.

    A headless client never runs initPlayerLocal.sqf (it exits on !hasInterface), so it has no
    streamer loop -- but it DOES compile the mission's functions and it DOES receive remoteExec
    replies. So this drives the streamer by hand: AP_fnc_mapStreamInit, then AP_fnc_mapTick with
    AP_mapFocus set to wherever the step needs the player to "be". The server dispatches it
    through the bot_commands verb "mapselftest"; every line reports through APS_fnc_logIt
    (tag -MAPTEST-) and the result is read from the log table.

    Phase "core" (no privileges needed), each step says PASS or FAIL:
      1. far bucket arrives (AP_mapReady)
      2. every non-empty cell fetched via "index"; client row count == server row count
      3. stream in at La Trinite (live > 500) / stream out at sea (live == always-loaded rows)
      4. synthetic upsert -> object at the right place -> del -> gone
      5. an edit that raced a fetch is buffered and replayed when the blob lands
      6. detail tier 0 leaves only tier-0 objects live
      7. the production focus path (no override) streams around the player object
      8. an unprivileged "add" to the authority must be REFUSED server-side
    Phase "authority" (after the HC's uid has level 5 on dev): add -> lands -> move -> lands -> del -> gone.
    Phase "terrain": terrain under every pavement tile, one [AP-TERRAIN] line each (this RPT only).
    Phase "cargo": which classes carry backpack cargo (the "local-only container" engine warning).
    Phase "territory": faction polygons resolve their own centroid through both lookups.

    Known HC noise: row inits that call helpers defined by core/configuration.sqf (AP_fnc_boostLamp
    on lamps) error on a headless client, which never runs core/init.sqf. Real clients have them.

    params: 0 = phase ("core" | "authority" | "terrain" | "territory" | "cargo"),
            1 = an NPC-anchor row id for the authority phase (optional)
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // dispatched by the server only (NOT in CfgRE)
params [["_phase", "core", [""]], ["_npcId", -1, [0]]];
if (isDedicated) exitWith {};
// HEADLESS ONLY. The bot verb targets every client; on a real client this moves the streamer's
// focus, drops the detail tier and -- on a level-5 admin -- the "unprivileged add" step is not
// unprivileged at all and inserts a row (it did, 2026-09-04: row 9470, soft-deleted by hand).
if (hasInterface) exitWith { diag_log format ["[AP-MAPTEST] phase=%1 skipped on a real client", _phase]; };

_this spawn {
    params [["_phase", "core", [""]], ["_npcId", -1, [0]]];
    // The streamer's stores live in localNamespace (AP_fnc_mapStreamInit). Bind them once: they are
    // references, so these locals see every edit the tick and the receivers make afterwards.
    if (isNil {localNamespace getVariable "AP_mapRows"}) then { [] call AP_fnc_mapStreamInit; };
    private _mapRows = localNamespace getVariable "AP_mapRows";
    private _mapCellRows = localNamespace getVariable "AP_mapCellRows";
    private _mapCells = localNamespace getVariable "AP_mapCells";
    private _mapAsked = localNamespace getVariable "AP_mapCellAsked";
    private _mapPending = localNamespace getVariable "AP_mapPending";
    private _mapLive = localNamespace getVariable "AP_mapLive";
    private _say = {
        diag_log format ["[AP-MAPTEST] %1", _this];
        [["-MAPTEST-", player, "HC", format ["%1", _this]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };
    private _pf = { ["FAIL", "PASS"] select _this };
    // Far bucket in (the streamer was started above). Returns seconds waited.
    private _init = {
        private _t = diag_tickTime;
        waitUntil { uiSleep 0.5; AP_mapReady || {diag_tickTime - _t > 30} };
        diag_tickTime - _t
    };
    // Every non-empty cell, in batches under the fetch rate limit. Returns [keys, serverRows, seconds].
    private _fetchAll = {
        AP_mapIndex = nil;
        private _t = diag_tickTime;
        [["index", [], player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
        waitUntil { uiSleep 0.5; !isNil "AP_mapIndex" || {diag_tickTime - _t > 10} };
        if (isNil "AP_mapIndex") exitWith { [[], -1, diag_tickTime - _t] };
        AP_mapIndex params ["_keys", "_srvRows", "_rev"];
        private _todo = _keys select { !((_mapCells getOrDefault [_x, "none"]) isEqualTo "loaded") };
        private _i = 0;
        while { _i < count _todo } do {
            private _batch = _todo select [_i, 64];
            { _mapCells set [_x, "wanted"]; _mapAsked set [_x, diag_tickTime]; } forEach _batch;
            [["cells", _batch, player], "APS_fnc_mapFetch", 2, false] call AP_fnc_MP;
            _i = _i + 64;
            uiSleep 3;
        };
        waitUntil { uiSleep 0.5; ((_keys findIf { !((_mapCells getOrDefault [_x, "none"]) isEqualTo "loaded") }) isEqualTo -1) || {diag_tickTime - _t > 90} };
        [_keys, _srvRows, diag_tickTime - _t]
    };
    private _alwaysRows = {
        private _n = 0;
        { if (((_x select 10) isEqualTo 0) && {!(_x select 4)} && {(_x select 9) <= AP_mapDetail}) then { _n = _n + 1; }; } forEach (values _mapRows);
        _n
    };
    private _cellsLoaded = { count ((keys _mapCells) select { (_mapCells get _x) isEqualTo "loaded" }) };

    format ["BEGIN phase=%1 hasInterface=%2 uid=%3", _phase, hasInterface, getPlayerUID player] call _say;

    if (_phase isEqualTo "core") then {
        // 1. far bucket
        private _s = call _init;
        format ["1 far: ready=%1 farRows=%2 in %3 s %4", AP_mapReady, count (_mapCellRows getOrDefault ["far", []]), _s toFixed 1, AP_mapReady call _pf] call _say;

        // 2. every cell
        (call _fetchAll) params ["_keys", "_srvRows", "_s2"];
        private _ok2 = (count _mapRows) isEqualTo _srvRows && {_srvRows > 0};
        format ["2 fetchAll: keys=%1 loaded=%2 rows=%3 serverRows=%4 in %5 s %6", count _keys, call _cellsLoaded, count _mapRows, _srvRows, _s2 toFixed 1, _ok2 call _pf] call _say;

        // 3. stream in / out
        AP_mapFocus = [7500, 10500, 0];
        [] call AP_fnc_mapTick;
        private _in = count _mapLive;
        // the exact expectation: every non-server row within its own radius of the focus, at or under the tier
        private _want = 0;
        {
            private _r = _x select 10; if (_r < 0) then { _r = (call AP_fnc_mapCfg) get "defaultR"; };
            if (!(_x select 4) && {(_x select 9) <= AP_mapDetail} && {_r isEqualTo 0 || {(AP_mapFocus distance2D (_x select 1)) < _r}}) then { _want = _want + 1; };
        } forEach (values _mapRows);
        format ["3a stream in at La Trinite: live=%1 expected=%2 %3", _in, _want, (_in isEqualTo _want && {_in > 0}) call _pf] call _say;
        AP_mapFocus = [300, 12500, 0];   // open sea, far from every marker
        [] call AP_fnc_mapTick;
        private _out = count _mapLive; private _always = call _alwaysRows;
        format ["3b stream out at sea: live=%1 alwaysRows=%2 %3", _out, _always, (_out isEqualTo _always) call _pf] call _say;

        // 4. synthetic upsert / del in a loaded cell
        AP_mapFocus = [7500, 10500, 0];
        private _row = ["Land_Bucket_F", [7500, 10500, 60], [[0,1,0],[0,0,1]], "", false, [], 999001, "", 1, 1, -1, false];
        ["upsert", [_row], 1] call AP_fnc_mapEditApply;
        [] call AP_fnc_mapTick;
        private _o = _mapLive getOrDefault [999001, objNull];
        private _pos = if (isNull _o) then { [] } else { getPosWorld _o };
        private _ok4a = !isNull _o && {_pos distance [7500, 10500, 60] < 0.05};
        format ["4a upsert: live=%1 pos=%2 %3", !isNull _o, _pos, _ok4a call _pf] call _say;
        ["del", [999001], 2] call AP_fnc_mapEditApply;
        [] call AP_fnc_mapTick;
        private _ok4b = !(999001 in _mapLive) && {isNil { _mapRows get 999001 }};
        format ["4b del: live=%1 inRows=%2 %3", 999001 in _mapLive, !isNil { _mapRows get 999001 }, _ok4b call _pf] call _say;

        // 5. the fetch/edit race: a cell marked wanted, an edit newer than the blob, the blob lands
        private _k = "0_0";
        _mapCells set [_k, "wanted"]; _mapAsked set [_k, diag_tickTime];
        private _row5 = ["Land_Bucket_F", [500, 500, 5], [[0,1,0],[0,0,1]], "", false, [], 999002, "", 1, 1, -1, false];
        ["upsert", [_row5], 999999999] call AP_fnc_mapEditApply;
        private _buffered = count (_mapPending getOrDefault [_k, []]);
        [_k, 1, "", 0] call AP_fnc_mapCellRecv;
        private _ok5 = !isNil { _mapRows get 999002 } && {(_mapCells getOrDefault [_k, "none"]) isEqualTo "loaded"};
        format ["5 race: buffered=%1 replayed=%2 %3", _buffered, !isNil { _mapRows get 999002 }, _ok5 call _pf] call _say;
        ["del", [999002], 999999999] call AP_fnc_mapEditApply;
        [] call AP_fnc_mapTick;

        // 6. detail tier
        private _saved = AP_mapDetail;
        AP_mapDetail = 0;
        [] call AP_fnc_mapTick;
        private _above = (keys _mapLive) select { ((_mapRows get _x) select 9) > 0 };
        format ["6 tier 0: live=%1 aboveTier=%2 %3", count _mapLive, count _above, (_above isEqualTo []) call _pf] call _say;
        AP_mapDetail = _saved;
        [] call AP_fnc_mapTick;

        // 7. the PRODUCTION focus path: no override, the tick must stream around wherever the
        //    player object is (a headless client's logic sits near respawn_civilian, in town --
        //    the exact spot the old spawn gate emptied on 2026-09-04)
        AP_mapFocus = nil;
        private _f = call AP_fnc_mapFocus;
        [] call AP_fnc_mapTick;
        private _want7 = 0;
        {
            private _r = _x select 10; if (_r < 0) then { _r = (call AP_fnc_mapCfg) get "defaultR"; };
            if (!(_x select 4) && {(_x select 9) <= AP_mapDetail} && {_r isEqualTo 0 || {(_f distance2D (_x select 1)) < _r}}) then { _want7 = _want7 + 1; };
        } forEach (values _mapRows);
        format ["7 production focus %1: live=%2 expected=%3 %4", _f apply { round _x }, count _mapLive, _want7, ((count _mapLive) isEqualTo _want7 && {_want7 > count (_mapCellRows getOrDefault ["far", []])}) call _pf] call _say;

        // 8. authority, unprivileged -> must be refused server-side
        private _before = count _mapRows;
        [["add", ["Land_Cargo20_blue_F", [8105, 7700, 20], [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
        uiSleep 4;
        format ["8 unprivileged add sent; rows before=%1 after=%2 (server log must say REFUSED) %3", _before, count _mapRows, (_before isEqualTo count _mapRows) call _pf] call _say;
        AP_mapFocus = nil;
    };

    if (_phase isEqualTo "authority") then {
        call _init;
        AP_mapFocus = [8120, 7700, 0];
        [] call AP_fnc_mapTick;                            // requests the cell under the focus
        [[8120, 7700, 0], 20] call AP_fnc_mapWaitLoaded;
        [] call AP_fnc_mapTick;
        private _ids0 = keys _mapRows;
        [["add", ["Land_Cargo20_blue_F", [8120, 7700, 20], [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
        uiSleep 5;
        [] call AP_fnc_mapTick;
        private _new = (keys _mapRows) - _ids0;
        private _id = _new param [0, -1];
        format ["5a add: new ids=%1 live=%2 %3", _new, _id in _mapLive, (_id > 0 && {_id in _mapLive}) call _pf] call _say;
        if (_id > 0) then {
            [["move", [_id, [8122, 7700, 20], [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
            uiSleep 5;
            [] call AP_fnc_mapTick;
            private _o = _mapLive getOrDefault [_id, objNull];
            private _okm = !isNull _o && {(getPosWorld _o) distance [8122, 7700, 20] < 0.05};
            format ["5b move: live=%1 pos=%2 %3", !isNull _o, if (isNull _o) then {[]} else {getPosWorld _o}, _okm call _pf] call _say;
            [["del", [_id]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
            uiSleep 5;
            [] call AP_fnc_mapTick;
            format ["5c del: live=%1 inRows=%2 %3", _id in _mapLive, !isNil { _mapRows get _id }, (!(_id in _mapLive) && {isNil { _mapRows get _id }}) call _pf] call _say;
        };
        if (_npcId > 0) then {
            [["move", [_npcId, [8130, 7700, 20], [[0,1,0],[0,0,1]]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
            uiSleep 5;
            format ["6 npc move sent for id %1; check init from psql", _npcId] call _say;
        };
        AP_mapFocus = nil;
    };
    if (_phase isEqualTo "terrain") then {
        // Terrain under every pavement tile. For each pavement-class row: create the tile
        // locally at its exact transform, take its real bounding box, sample the terrain at
        // the centre and the four footprint corners, log one line, delete it. The line is
        // diag_log ONLY (this client's RPT), not logIt -- 3000 rows must not become 3000
        // inserts into the log table.
        //   [AP-TERRAIN] id|class|zCentre|zTop|tCentre|tMin|tMax|tiltDeg
        call _init; call _fetchAll;
        private _n = 0;
        {
            _x params ["_cls", "_pos", "_vdu", "", "", "", ["_id", -1]];
            private _lc = toLower _cls;
            if (((_lc find "pavement") > -1) || {(_lc find "sidewalk") > -1} || {(_lc find "cobble") > -1}) then {
                private _o = createSimpleObject [_cls, _pos, true];
                if (!isNull _o) then {
                    _o setVectorDirAndUp _vdu;
                    private _bb = boundingBoxReal _o;
                    _bb params ["_mn", "_mx"];
                    private _corners = [[_mn select 0, _mn select 1, 0], [_mx select 0, _mn select 1, 0],
                                        [_mx select 0, _mx select 1, 0], [_mn select 0, _mx select 1, 0]] apply { _o modelToWorld _x };
                    private _ts = _corners apply { getTerrainHeightASL [_x select 0, _x select 1] };
                    private _tc = getTerrainHeightASL [_pos select 0, _pos select 1];
                    private _top = (_pos select 2) + (_mx select 2);
                    private _tilt = acos ((_vdu select 1) select 2);
                    diag_log format ["[AP-TERRAIN] %1|%2|%3|%4|%5|%6|%7|%8", _id, _cls, _pos select 2, _top, _tc, selectMin _ts, selectMax _ts, _tilt];
                    deleteVehicle _o;
                    _n = _n + 1;
                };
                if (_n mod 25 isEqualTo 0) then { uiSleep 0.01; };
            };
        } forEach (values _mapRows);
        format ["terrain: sampled %1 pavement tiles (see [AP-TERRAIN] in this client's RPT)", _n] call _say;
    };
    if (_phase isEqualTo "cargo") then {
        call _init; call _fetchAll;
        private _seen = createHashMap;
        {
            _x params ["_cls", "", "", ["_code", ""], "", "", ["_id", -1]];
            private _e = _seen getOrDefault [_cls, [0, false]];
            _seen set [_cls, [(_e select 0) + 1, (_e select 1) || {_code isNotEqualTo ""}]];
        } forEach (values _mapRows);
        private _hits = 0; private _rows = 0;
        {
            private _cls = _x; private _v = _seen get _x;
            private _cfg = configFile >> "CfgVehicles" >> _cls;
            // The engine's complaint is about backpacks in the container's CARGO, so ask for both
            // the count and the class list -- a class can declare one without the other.
            private _maxBp = getNumber (_cfg >> "transportMaxBackpacks");
            private _bpList = if (isClass (_cfg >> "TransportBackpacks")) then { count (configProperties [_cfg >> "TransportBackpacks", "isClass _x", true]) } else { 0 };
            if (_maxBp > 0 || {_bpList > 0}) then {
                private _needSim = (getNumber (_cfg >> "numberOfDoors")) > 0 || {_cls isKindOf "FlagCarrier"};
                _hits = _hits + 1; _rows = _rows + (_v select 0);
                format ["[AP-CARGO] %1|rows=%2|maxBackpacks=%3|bpClasses=%4|needSim=%5|hasCode=%6",
                    _cls, _v select 0, _maxBp, _bpList, _needSim, _v select 1] call _say;
            };
        } forEach (keys _seen);
        format ["cargo: %1 class(es) with backpack cargo across %2 row(s); %3 distinct classes total", _hits, _rows, count _seen] call _say;
    };
    if (_phase isEqualTo "territory") then {
        ["flush"] call AP_fnc_factionTerritory;   // rebuild the cache from config, not from a stale run
        private _fail = 0;
        {
            private _id   = _x select 0;
            private _poly = _x param [5, []];
            if (_poly isNotEqualTo []) then {
                private _cx = 0; private _cy = 0;
                { _cx = _cx + (_x select 0); _cy = _cy + (_x select 1); } forEach _poly;
                _cx = _cx / count _poly; _cy = _cy / count _poly;
                private _got = [
                    [[_cx, _cy]]    call AP_fnc_factionTerritory,
                    [[_cx, _cy, 0]] call AP_fnc_factionTerritory,
                    ["territoryOf", [_cx, _cy]]    call AP_fnc_factionCfg,
                    ["territoryOf", [_cx, _cy, 0]] call AP_fnc_factionCfg
                ];
                private _ok = (_got findIf { !(_x isEqualTo _id) }) isEqualTo -1;
                if (!_ok) then { _fail = _fail + 1; };
                format ["territory %1 centroid [%2,%3] -> %4 %5", _id, round _cx, round _cy, _got, ["FAIL", "OK"] select _ok] call _say;
            };
        } forEach (["all"] call AP_fnc_factionCfg);
        private _sea = [[[100, 100]] call AP_fnc_factionTerritory, ["territoryOf", [100, 100, 0]] call AP_fnc_factionCfg];
        private _seaOk = _sea isEqualTo ["", ""];
        if (!_seaOk) then { _fail = _fail + 1; };
        format ["territory neutral [100,100] -> %1 %2", _sea, ["FAIL", "OK"] select _seaOk] call _say;
        format ["territory: %1 failure(s); an engine script error in this client's RPT also counts as one", _fail] call _say;
    };
    "END" call _say;
};
