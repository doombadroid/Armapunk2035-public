/*
    File: fn_suiteFurnitureDespawn.sqf  (APS_fnc_suiteFurnitureDespawn)
    Luxe Suites 2026-08-06 -- remove a suite's spawned furniture from the world.

        ["<oid>"] call APS_fnc_suiteFurnitureDespawn

    Deliberately a REAL implementation rather than a stub even though placement
    lands in phase 4: a no-op stub here would shadow the real behaviour later and
    silently leave furniture standing in a repossessed suite. It is safe to call
    when nothing has ever been spawned -- the cache lookup simply misses.

    localNamespace APS_suiteFurnCache: oid -> [ownerUid, [spawnedObjects]]
*/
params [["_oid", "", [""]]];
if (_oid isEqualTo "") exitWith { 0 };
if (isNil {localNamespace getVariable "APS_suiteFurnCache"}) then { localNamespace setVariable ["APS_suiteFurnCache", createHashMap]; };
private _cache = localNamespace getVariable "APS_suiteFurnCache";   // localNamespace: a published AP_suiteFurnCache made the prune deleteVehicle any object

private _entry = _cache getOrDefault [_oid, []];
private _objs  = _entry param [1, []];
private _n = 0;
{ if (!isNull _x) then { deleteVehicle _x; _n = _n + 1; }; } forEach _objs;
_cache deleteAt _oid;
if (_n > 0) then { diag_log format ["[SUITE] despawned %1 furniture piece(s) in %2", _n, _oid]; };
_n
