/*
    File: fn_suiteFurnitureSRV.sqf  (APS_fnc_suiteFurnitureSRV)
    Luxe Suites 2026-08-07 -- furniture authority for leased floors. suites.md §8.

        ["add",   "<oid>", [_class, _posASL, _dir]]   -> validate, persist, spawn
        ["load",  "<oid>", []]                        -> spawn this suite's pieces
        ["clear", "<oid>", []]                        -> despawn + wipe (lease end)

    CfgRE: allowedTargets = 2.

    NOT an extension of the house furniture path. That one gates on
    nearestObjects [player, ["House"], 20] and would never see the tower (a
    simple object is not a House), and its "add" has no ownership check and
    interpolates raw client strings into SQL -- neither is worth inheriting.

    WHAT IS TRUSTED
      * The caller comes from remoteExecutedOwner and is matched against
        suites.owner. A client-supplied oid only ever selects a row after that.
      * The FLOOR IS RE-DERIVED SERVER-SIDE. initServer.sqf loads
        core\suites\fn_suiteData.sqf, and the server holds the tower objects
        (the door sweep wires them there too), so AP_fnc_suiteAt runs here
        against the caller's real position -- the client's claim about which
        floor it is on is never taken as fact.
      * The classname must be in the server's furniture list (localNamespace
        APS_furnClasses, set by APS_fnc_houseFurnitureSRV). That is the SQL-injection
        guard as well as the anti-"spawn me a tank" guard: nothing reaches the
        query that is not already a member of a server-defined list. It used to be
        the client global AP_furnitureClasses, which is nil on the server and set by
        any client's publicVariableServer (audit r2furn). "load" filters the stored
        pieces through the same list, so a class planted earlier cannot respawn.
      * Cap 20 per suite, counted from the stored row, not from the client.

    PRESENCE. Pieces exist only while the tenant is online. They are spawned on
    request and pruned by APS_fnc_suiteRentSweep, which already runs every 300 s
    and is the natural place to notice that an owner has gone. That avoids adding
    another disconnect hook to a codebase where the disconnect path is already
    carrying the house-inventory save.
*/
params [["_mode", "", [""]], ["_oid", "", [""]], ["_arg", [], [[]]]];
if (_mode isEqualTo "" || {_oid isEqualTo ""}) exitWith {};

#define SUITE_FURN_CAP 20

// ONE registry. APS_fnc_suiteFurnitureDespawn already owns this cache and
// APS_fnc_suiteRelease already calls it on eviction, so a second registry here
// would mean furniture that survives a repossession -- the despawn would look in
// a cache that never heard of it. Shape is theirs: oid -> [ownerUid, [objects]].
if (isNil {localNamespace getVariable "APS_suiteFurnCache"}) then { localNamespace setVariable ["APS_suiteFurnCache", createHashMap]; };
private _cache = localNamespace getVariable "APS_suiteFurnCache";   // localNamespace: a published AP_suiteFurnCache made the prune deleteVehicle any object

// + the fabricator stand-in: a printer placed in a suite arrives as this stock prop (AP_furnitureClasses has it)
private _okCls = (localNamespace getVariable ["APS_furnClasses", []]) + ["Land_Workbench_01_F"];

private _ro = remoteExecutedOwner;
if (_ro <= 2) exitWith {};
private _pl = (allPlayers select { owner _x == _ro }) param [0, objNull];
if (isNull _pl) exitWith {};
private _uid = getPlayerUID _pl;
if !(_uid regexMatch "\d{17}") exitWith {};
if !(_oid regexMatch "LUX\d{1,12}F\d{1,2}") exitWith {
    diag_log format ["[SUITE][FURN][SEC] bad oid '%1' from %2", _oid, _uid]; };

// ---- ownership, from the row -------------------------------------------------
private _row = [format ["SELECT COALESCE(owner,'') AS owner, COALESCE(NULLIF(furniture,''),'""[]""') AS furniture FROM suites WHERE oid='%1'", _oid], 2, true] call DB_fnc_asyncQuery;
private _r0 = if (_row isEqualType []) then { _row param [0, []] } else { [] };
if !((_r0 param [0, ""]) isEqualTo _uid) exitWith {
    diag_log format ["[SUITE][FURN][SEC] %1 touched furniture they do not hold (%2)", _uid, _oid]; };

// furniture is an mres blob, so it is read BARE (see fn_suiteStorageSRV -- a
// QUOTE() here is the bug that destroyed a tenant's inventory on 2026-08-07).
// A decode that fails is REFUSED, never silently treated as "no furniture":
// treating unreadable as empty is what lets a later write erase the real row.
private _enc = _r0 param [1, ""];
private _list = [];
private _bad = false;
if (_enc isNotEqualTo "" && {_enc isNotEqualTo "NULL"}) then {
    private _d = [_enc] call DB_fnc_mresToArray;
    if (typeName _d isEqualTo "STRING") then { _d = parseSimpleArray (format ["%1", _d]); };
    if (isNil "_d" || {!(_d isEqualType [])}) then { _bad = true } else { _list = _d };
};
if (_bad) exitWith {
    diag_log format ["[SUITE][FURN][ABORT] %1 %2: furniture did not decode, refusing (raw=%3)", _uid, _oid, _enc]; };

private _fnc_encode = {
    params ["_l"];
    (([_l] call DB_fnc_mresArray) splitString "'") joinString "''"
};

private _fnc_spawn = {
    params ["_key", "_l"];
    private _made = [];
    {
        _x params ["_cls", "_pos", "_dir"];
        private _o = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _o setDir _dir;
        _o setPosASL _pos;
        _o enableSimulationGlobal false;
        _o allowDamage false;
        _o setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup's sweep
        _o setVariable ["AP_suiteOid", _key, true];
        _made pushBack _o;
    } forEach (_l select { (_x param [0, ""]) in _okCls });
    _cache set [_key, [_uid, _made]];
    _made
};

switch (_mode) do {

    case "add": {
        _arg params [["_cls", "", [""]], ["_pos", [], [[]]], ["_dir", 0, [0]]];
        // Whitelist membership is the injection guard too -- only a string that
        // is already a member of the server's list can reach the query.
        if !(_cls in _okCls) exitWith {
            ["-SEC-", _pl, format ["BLOCKED suite furniture add '%1' in %2 by %3", _cls, _oid, _uid]] call APS_fnc_logIt; };
        if (count _pos < 3) exitWith {};
        if (count _list >= SUITE_FURN_CAP) exitWith {
            ["Your suite is full -- 20 pieces is the limit.", "basic"] remoteExec ["AP_fnc_handleMessage", _ro]; };

        // Re-derive the floor from the CALLER'S OWN position and from where the
        // piece is going. Both must be the suite that owns this oid: standing in
        // your suite and placing through the wall into your neighbour's is the
        // obvious attack, and the client's claim is not evidence.
        private _herePl = [_pl] call AP_fnc_suiteAt;
        if (_herePl isEqualTo [] || {(_herePl param [2, ""]) isNotEqualTo _oid}) exitWith {
            diag_log format ["[SUITE][FURN][SEC] %1 placed into %2 from outside it", _uid, _oid];
            ["You can only place furniture inside your own suite.", "basic"] remoteExec ["AP_fnc_handleMessage", _ro]; };
        private _tower = _herePl param [0, objNull];
        private _fObj = [_tower, _pos] call AP_fnc_suiteFloorAt;
        if (_fObj isNotEqualTo (_herePl param [1, -1])) exitWith {
            ["That is outside your suite.", "basic"] remoteExec ["AP_fnc_handleMessage", _ro]; };

        _list pushBack [_cls, _pos, _dir];
        [format ["UPDATE suites SET furniture='%1' WHERE oid='%2' AND owner='%3'",
            [_list] call _fnc_encode, _oid, _uid], 2] call DB_fnc_asyncQuery;

        // spawn just the new piece onto the tracked list
        private _cur = (_cache getOrDefault [_oid, []]) param [1, []];
        private _new = ([_oid, [[_cls, _pos, _dir]]] call _fnc_spawn) select 0;
        _cache set [_oid, [_uid, _cur + [_new]]];
        diag_log format ["[SUITE][FURN] %1 placed %2 in %3 (%4/%5)", _uid, _cls, _oid, count _list, SUITE_FURN_CAP];
    };

    case "load": {
        if (!isNil { _cache get _oid }) exitWith {};   // already out
        private _made = [_oid, _list] call _fnc_spawn;
        diag_log format ["[SUITE][FURN] spawned %1 of %2 piece(s) for %3", count _made, count _list, _oid];
    };

    case "clear": {
        [_oid] call APS_fnc_suiteFurnitureDespawn;
        [format ["UPDATE suites SET furniture=NULL WHERE oid='%1' AND owner='%2'", _oid, _uid], 2] call DB_fnc_asyncQuery;
        diag_log format ["[SUITE][FURN] %1 cleared %2", _uid, _oid];
    };
};
