/*
    File: fn_mapLoad.sqf  (APS_fnc_mapLoad)
    Boot: every live map row into memory, indexed by cell; the server's own rows spawned.
    Clients never touch the database -- they fetch from this cache (APS_fnc_mapFetch).
    mapdb.md D4. Scheduled (mode-2 reads). Server-only, no CfgRE entry.

    Pages of 1,000 rows (~200 KB each, ~25 PySQF chunks -- inside the envelope the web-serve
    pages exercise daily). map_meta.rev is read FIRST so anything written while we page lands
    in the first poll delta instead of being lost.
*/
if (!isServer) exitWith {};
private _t0 = diag_tickTime;
private _world = worldName;
// The one column order every SELECT that feeds APS_fnc_mapRowOp uses. COALESCE(stream_r,-1):
// a NULL through parseNumber would read as 0 = "always loaded".
// Both COALESCEs are aliased: apdb refuses a result with two columns named "coalesce".
// Every store below lives in localNamespace, which the network cannot write: as missionNamespace globals
// one client's publicVariableServer swapped a cached blob, a row text or this column list, and the server
// then served (or SELECTed, compiled and broadcast) the forgery (audit 2026-09-26). Do not move them back.
// The maps are references: readers bind them once per call and mutate in place, nothing reassigns one.
localNamespace setVariable ["APS_mapSelectCols", "id, classname, x, y, z, vdir_x, vdir_y, vdir_z, vup_x, vup_y, vup_z, init, is_server, COALESCE(loadout,'') AS loadout, deleted, rev, model, scale, lod, COALESCE(stream_r,-1) AS stream_r, on_server"];
private _mr = ["SELECT rev FROM map_meta WHERE world = %s", 2, false, [_world]] call DB_fnc_asyncQuery;
localNamespace setVariable ["APS_mapRev", parseNumber format ["%1", _mr param [0, 0]]];
private _mapRows = createHashMap;    // id -> wire row
private _mapCells = createHashMap;   // cell key -> [ids]
private _mapLive = createHashMap;    // id -> the server's own object (is_server / on_server rows)
localNamespace setVariable ["APS_mapRows", _mapRows];
localNamespace setVariable ["APS_mapText", createHashMap];        // id -> the row's literal (AP_fnc_mapRowText)
localNamespace setVariable ["APS_mapCells", _mapCells];
localNamespace setVariable ["APS_mapBlobs", createHashMap];       // cell key -> [rev, packed, rowCount]
localNamespace setVariable ["APS_mapLive", _mapLive];
localNamespace setVariable ["APS_mapFetchRate", createHashMap];   // owner id -> [requests, windowStart]
// Tombstones: the pack-time purge went with the pack. Anything soft-deleted more than a week
// ago has been broadcast to every session since; nothing reads it again.
["DELETE FROM map_objects WHERE world = %s AND deleted AND updated_at < now() - interval '7 days'", 1, false, [_world]] call DB_fnc_asyncQuery;
private _last = 0;
private _pages = 0;
private _n = 0;
while {true} do {
    private _rows = ["SELECT " + (localNamespace getVariable "APS_mapSelectCols") + " FROM map_objects WHERE world = %s AND NOT deleted AND id > %s ORDER BY id LIMIT 1000",
                     2, true, [_world, _last]] call DB_fnc_asyncQuery;
    if (_rows isEqualTo []) exitWith {};
    _pages = _pages + 1;
    {
        private _t = [_x] call APS_fnc_mapRowOp;
        if (_t isNotEqualTo []) then { [_t, false] call APS_fnc_mapRowUpdate; _last = _t select 0; _n = _n + 1; };
    } forEach _rows;
};
// Compatibility: fn_loonyBinSRV, fn_maldenJewelSRV, fn_cyberdeckSRV, fn_atmSkimSRV and fn_mapBake look rows up
// by class in this boot snapshot. Indices 0-6 of the wire row are the old row, so they keep working.
// localNamespace, never the old allLocalMapEntities global: one client publicVariable of that global replaced
// the server's copy, forging the ATM whitelist / skimmer ATM check and the heist prop lookups (audit r2heist).
private _all = values _mapRows;
localNamespace setVariable ["APS_mapEntities", _all];
// Was derived on every client from the baked array (core/init.sqf); the client has no array now.
AP_exchangeSpots = (_all select { ((_x param [3, ""]) find "civExchange") > -1 }) apply { _x param [1, [0,0,0]] };
publicVariable "AP_exchangeSpots";
diag_log format ["[AP-MAP] boot: %1 rows in %2 pages, rev %3, %4 cells, far %5, %6 s",
    _n, _pages, localNamespace getVariable "APS_mapRev", count _mapCells, count (_mapCells getOrDefault ["far", []]), (diag_tickTime - _t0) toFixed 1];
localNamespace setVariable ["APS_mapReady", true];
uiSleep 3;   // let the world finish loading before spawning (custom_p3ds/load.sqf precedent)
private _g = 0;
private _l = 0;
{
    if ((_x select 4) || {_x select 11}) then {
        private _o = _x call AP_fnc_createVehicleLocal;
        if (!isNull _o) then {
            _mapLive set [_x select 6, _o];
            if (_x select 4) then { _g = _g + 1; } else { _l = _l + 1; };
        };
        uiSleep 0.0005;
    };
} forEach _all;
AP_mapFarDone = true;
diag_log format ["[AP-MAP] boot: spawned %1 global + %2 local server rows", _g, _l];
