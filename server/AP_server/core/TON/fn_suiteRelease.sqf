/*
    File: fn_suiteRelease.sqf  (APS_fnc_suiteRelease)
    Luxe Suites 2026-08-06 -- the ONE wipe path. See suites.md §5.

        ["<oid>", "<uid>", "<why>"] call APS_fnc_suiteRelease

    Voluntary "End Lease" and 10-day repossession do exactly the same thing to a
    suite (owner's call: contents are forfeit either way), so they share this
    function rather than each implementing the wipe. Two implementations of one
    lifecycle drift, and half-restored state is how "stuck" bugs are born.

    NOT in CfgRE -- server-internal only. The caller has already established that
    the release is authorised (tenant-initiated, or the sweep's deadline).
*/
params [["_oid", "", [""]], ["_uid", "", [""]], ["_why", "tenant", [""]]];
if (_oid isEqualTo "") exitWith {};

// what is being destroyed -- logged BEFORE the wipe so a dispute is reconstructable
// mres blobs read BARE. These three are only measured for the eviction log, but
// QUOTE() on an mres column double-wraps it and can throw during the result
// compile -- which would take the whole read down with it, leaving _floor at 0
// and aborting the release. Same footgun that destroyed a tenant's inventory
// on 2026-08-07; the row is NULLed below either way, so this is the last copy.
private _pre = [format ["SELECT floor, COALESCE(NULLIF(vinv,''),'""[[],0]""') AS vinv, COALESCE(NULLIF(pinv,''),'""[[],0]""') AS pinv, COALESCE(NULLIF(furniture,''),'""[]""') AS furniture FROM suites WHERE oid='%1'", _oid], 2, true] call DB_fnc_asyncQuery;
private _r0 = if (_pre isEqualType []) then { _pre param [0, []] } else { [] };
private _floor = _r0 param [0, 0];

// kill anything live before the row goes: an open storage session must not be
// able to write its contents back into a suite that no longer has an owner.
private _gen = missionNamespace getVariable [format ["AP_suiteGen_%1", _oid], 0];
missionNamespace setVariable [format ["AP_suiteGen_%1", _oid], _gen + 1, true];
missionNamespace setVariable [format ["AP_suiteHydrated_%1", _oid], false, true];
[_oid] call APS_fnc_suiteFurnitureDespawn;

[format ["UPDATE suites SET owner=NULL, leased_at=0, next_due=0, overdue_since=0, locked=1, vinv=NULL, pinv=NULL, furniture=NULL WHERE oid='%1'", _oid], 2] call DB_fnc_asyncQuery;

// proof read: extDB3 gives no row count, and "the lease looked ended but the row
// still has an owner" is the worst possible half-state here
private _chk = [format ["SELECT COALESCE(owner,'') AS owner FROM suites WHERE oid='%1'", _oid], 2, true] call DB_fnc_asyncQuery;
private _still = if (_chk isEqualType []) then { (_chk param [0, []]) param [0, ""] } else { "?" };
private _clean = _still isEqualTo "";

diag_log format ["[SUITE] release %1 (floor %2) from %3 reason=%4 -> %5 | forfeited vinv=%6 pinv=%7 furn=%8",
    _oid, _floor, _uid, _why,
    ["WRITE FAILED (owner still set!)", "ok"] select _clean,
    count (_r0 param [1, ""]), count (_r0 param [2, ""]), count (_r0 param [3, ""])];

if (!_clean) exitWith { false };

// door back to locked-and-vacant on every machine
[[_oid, _floor, true, ""], "AP_fnc_suiteDoorSync", -2, false] spawn AP_fnc_MP;

// tell the ex-tenant if they are online
private _pl = (allPlayers select { getPlayerUID _x isEqualTo _uid }) param [0, objNull];
if (!isNull _pl) then {
    [[_oid, _why], "AP_fnc_suiteEvicted", _pl, false] spawn AP_fnc_MP;
};
true
