/*
    File: fn_territoryLoad.sqf  (APS_fnc_territoryLoad)
    Read the fixer polygons from faction_territory (PostGIS, deploy/postgis.sql) and publish them
    as AP_factionPolys = [[id, [[x,y],...]], ...]. fn_factionCfg overlays them over its literals;
    clients flush their position->faction cache on the publicVariable. Called at boot and by the
    bot verb "territoryreload" (tools/bake_territory.py writes the table). Scheduled (mode-2 read).
    Server-only, no CfgRE entry.
*/
if (!isServer) exitWith {};
private _rows = ["SELECT faction_id, points FROM faction_territory ORDER BY faction_id", 2, true] call DB_fnc_asyncQuery;
private _out = [];
{
    _x params ["_id", "_pts"];
    private _p = parseSimpleArray format ["%1", _pts];
    if (_p isEqualType [] && {count _p >= 3}) then { _out pushBack [format ["%1", _id], _p]; };
} forEach _rows;
if (_out isEqualTo []) exitWith { diag_log "[AP][territory] faction_territory is empty -- the shipped polygons stay"; };
AP_factionPolys = _out;
publicVariable "AP_factionPolys";
["flush"] call AP_fnc_factionTerritory;
diag_log format ["[AP][territory] published %1 polygon(s): %2", count _out, _out apply { format ["%1(%2)", _x select 0, count (_x select 1)] }];
