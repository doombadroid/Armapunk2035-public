/*
    APS_fnc_loveBombSRV -- LooneyBin (owner 2026-06-11): Ultimate Healing Sunshine Love Bomb detonation.
    Client armed it (10s). Here: heal/revive EVERY player within 1km, then a big (cosmetic) explosion. The
    blast is pure spectacle -- players are made invincible + full-health by loveBombHeal first, so it can't
    hurt them. Not a literal "destroy every building" (that'd permanently grief the map) -- a dramatic boom.
*/
params [["_pos", [0,0,0], [[]]]];
if (_pos isEqualTo [0,0,0]) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.1 -- grief/availability): CfgRE-whitelisted -> a client could
// remoteExec [anyPos] and PERMANENTLY level every building within 1km of an arbitrary point (towns, banks,
// shops) = server-wide grief. Derive the caller from the non-spoofable remoteExecutedOwner (model
// fn_seizeLock:22) and gate ONLY the building-destruction step to admin/owner (DB admin level, model
// fn_adminDelVeh) -- the heal/revive + cosmetic explosion stay available to any legit item holder so the
// fun item isn't broken, but a non-admin can no longer flatten the map. server-internal (_src==0) passes.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _mayLevel = if (_src isEqualTo 0) then { true } else {private _cUID = getPlayerUID _caller;
    if (_cUID isEqualTo "76561190000000001") then { true } else {
        private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _cUID], 2, true] call DB_fnc_asyncQuery;
        (parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]) >= 3};};

// 1) heal + revive everyone within 1km (loveBombHeal also flips allowDamage off for the blast window)
{if (_x distance _pos < 1000) then {[[], "AP_fnc_loveBombHeal", _x, false, false] spawn AP_fnc_MP;};} forEach allPlayers;

// 2) let the invincibility land, then set off the spectacle (central GBU + a mortar ring)
uiSleep 0.6;
"Bo_GBU12_LGB" createVehicle (_pos vectorAdd [0, 0, 2]); {"M_Mo_82mm_AT_LG" createVehicle (_pos vectorAdd [_x select 0, _x select 1, 1]);
} forEach [[45,0],[-45,0],[0,45],[0,-45],[32,32],[-32,32],[32,-32],[-32,-32]];

// 3) OWNER REQUEST (retirement parties): TOTAL building destruction within 1km. PERMANENT until the next
// server restart -- levels the whole area (houses/shops/bank included). Players are invincible via
// loveBombHeal so the collapse can't kill them. Spread the global setDamage volley so it doesn't hard-freeze.
// owner 2026-06-23 SECURITY: ADMIN/OWNER-ONLY (see header) -- a non-admin item holder gets the heal+spectacle
// but NOT the map-flattening. A forged remote call by a non-admin reaches here with _mayLevel=false and skips it.
private _buildings = [];
if (_mayLevel) then {
    _buildings = (nearestObjects [_pos, ["House", "Building"], 1000]) + (nearestTerrainObjects [_pos, ["HOUSE", "BUILDING"], 1000]);
    _buildings = _buildings arrayIntersect _buildings; {if (!isNull _x && {alive _x}) then { _x setDamage 1; };
        if ((_forEachIndex mod 50) isEqualTo 0) then { uiSleep 0.05; };} forEach _buildings;} else {
    ["-SEC-", _caller, format ["loveBombSRV: non-admin %1 detonated -- heal+spectacle ALLOWED, building-leveling BLOCKED", getPlayerUID _caller]] call APS_fnc_logIt;
};

// 4) announce + log
private _msg = if (_mayLevel) then {
    "An Ultimate Healing Sunshine Love Bomb just detonated -- everyone within 1km was healed and revived to full, and the entire area was LEVELED. Happy retirement!"
} else {"An Ultimate Healing Sunshine Love Bomb just detonated -- everyone within 1km was healed and revived to full!"};
[[[0,1,2], _msg], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
[777, objNull, format ["Ultimate Healing Sunshine Love Bomb detonated @ %1 -- leveled %2 building(s) (mayLevel %3)", _pos, count _buildings, _mayLevel]] call APS_fnc_logIt;
