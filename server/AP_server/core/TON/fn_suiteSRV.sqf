/*
    File: fn_suiteSRV.sqf  (APS_fnc_suiteSRV)
    Luxe Suites 2026-08-06 -- lease authority. See suites.md.

        ["list", "<towerKey>"]          -> pushes the tower's 29 rows to the caller
        ["lease", "<oid>", _floor]      -> claim + charge, or refuse
        ["end", "<oid>"]                -> tenant ends their own lease (contents forfeit)
        ["payNow", "<oid>"]             -> clear an overdue state early
        ["lock", "<oid>", _state]       -> tenant toggles their front door

    CfgRE: allowedTargets = 2 (clients call it). Caller identity ALWAYS comes from
    remoteExecutedOwner -- a client-passed oid is only ever used to LOOK UP a row
    AFTER the caller has been resolved, never to decide who they are. (-SEC- logs
    take the subject from remoteExecutedOwner, never from the payload.)

    CLAIM-THEN-CHARGE, in that order, with rollback. The reverse (charge first,
    then claim) can take a player's money for a floor somebody else won a
    millisecond earlier. The claim itself is a conditional UPDATE whose
    `AND owner IS NULL` is the atomic authority, exactly like the ND debit's
    `AND new_drachma >= amt` -- extDB3 reports no row count through this pipe, so
    the claim is proven by re-reading the row and checking WE hold it.
*/
params [["_mode", "", [""]], ["_a", "", ["", 0]], ["_b", 0, [0, ""]]];
if (_mode isEqualTo "") exitWith {};

private _ro = remoteExecutedOwner;
if (_ro <= 2) exitWith {};                       // 0 = local, 2 = server: these modes need a real client
private _pl = (allPlayers select { owner _x == _ro }) param [0, objNull];
if (isNull _pl) exitWith {};
private _uid = getPlayerUID _pl;
if !(_uid regexMatch "\d{17}") exitWith {};

// oid/tower keys are interpolated into SQL, so they are format-validated. This
// check IS the injection guard (same doctrine as the ND amount regex).
private _oidOk  = { params ["_s"]; (_s isEqualType "") && {_s regexMatch "LUX\d{1,12}F\d{1,2}"} };
private _twOk   = { params ["_s"]; (_s isEqualType "") && {_s regexMatch "\d{1,12}"} };

private _rowOf = {
    params ["_oid"];
    private _r = [format ["SELECT oid, floor, COALESCE(owner,'') AS owner, next_due, overdue_since, locked FROM suites WHERE oid='%1'", _oid], 2, true] call DB_fnc_asyncQuery;
    if !(_r isEqualType []) exitWith { [] };
    _r param [0, []]
};

private _pushOne = {
    params ["_target", "_oid"];
    private _row = [_oid] call _rowOf;
    [[_row], "AP_fnc_suiteReceive", _target, false] spawn AP_fnc_MP;
};

switch (_mode) do {

    // ---------------------------------------------------------------- list
    case "list": {
        if !([_a] call _twOk) exitWith {};
        private _rows = [format ["SELECT oid, floor, COALESCE(owner,'') AS owner, next_due, overdue_since, locked FROM suites WHERE tower='%1'", _a], 2, true] call DB_fnc_asyncQuery;
        if !(_rows isEqualType []) then { _rows = []; };
        // Rows exist only for floors that have EVER been leased; the client fills
        // the gaps as vacant. That keeps the table free of 29 dead rows per tower
        // the moment anyone drops a new one.
        [[_rows, _a, "list"], "AP_fnc_suiteReceive", _pl, false] spawn AP_fnc_MP;
    };

    // --------------------------------------------------------------- lease
    case "lease": {
        private _oid = _a; private _floor = _b;
        if !([_oid] call _oidOk) exitWith { diag_log format ["[SUITE][SEC] bad oid '%1' from %2", _oid, _uid]; };
        if (!(_floor isEqualType 0) || {_floor < 2} || {_floor > 30}) exitWith {
            diag_log format ["[SUITE][SEC] bad floor %1 from %2", _floor, _uid]; };
        private _tower = (_oid select [3, (_oid find "F") - 3]);

        // ensure a row exists (first lease of this floor, ever)
        [format ["INSERT INTO suites (oid, tower, floor) VALUES ('%1','%2',%3) ON CONFLICT DO NOTHING", _oid, _tower, _floor], 2] call DB_fnc_asyncQuery;

        // CLAIM -- conditional, atomic. Losing a race here is indistinguishable
        // from the floor already being taken, which is exactly right.
        [format ["UPDATE suites SET owner='%1', leased_at=extract(epoch from now())::bigint, next_due=extract(epoch from now())::bigint+%2, overdue_since=0, locked=1 WHERE oid='%3' AND owner IS NULL", _uid, (localNamespace getVariable "APS_suiteTermS"), _oid], 2] call DB_fnc_asyncQuery;
        private _row = [_oid] call _rowOf;
        private _holder = _row param [2, ""];
        if !(_holder isEqualTo _uid) exitWith {
            diag_log format ["[SUITE] lease REFUSED %1 to %2 (already held by '%3')", _oid, _uid, _holder];
            [["taken", _oid], "AP_fnc_suiteReceive", _pl, false] spawn AP_fnc_MP;
        };

        // CHARGE -- and roll the claim back if the wallet can't cover it.
        private _pay = [_uid, (localNamespace getVariable "APS_suiteRentND"), "suiteRent"] call APS_fnc_ndDebitSrv;
        if !(_pay param [0, false]) exitWith {
            [format ["UPDATE suites SET owner=NULL, leased_at=0, next_due=0 WHERE oid='%1' AND owner='%2'", _oid, _uid], 2] call DB_fnc_asyncQuery;
            diag_log format ["[SUITE] lease ROLLED BACK %1 for %2 (insufficient ND)", _oid, _uid];
            [["poor", _oid], "AP_fnc_suiteReceive", _pl, false] spawn AP_fnc_MP;
        };

        diag_log format ["[SUITE] leased %1 to %2 for %3 ND", _oid, _uid, (localNamespace getVariable "APS_suiteRentND")];
        [_pl, _oid] call _pushOne;
        [[_oid, _floor, true, _uid], "AP_fnc_suiteDoorSync", -2, false] spawn AP_fnc_MP;   // locked, tenant may open
    };

    // ----------------------------------------------------------------- end
    case "end": {
        private _oid = _a;
        if !([_oid] call _oidOk) exitWith {};
        private _row = [_oid] call _rowOf;
        if !((_row param [2, ""]) isEqualTo _uid) exitWith {
            diag_log format ["[SUITE][SEC] %1 tried to end a lease they do not hold (%2)", _uid, _oid]; };
        private _floor = _row param [1, 0];
        [_oid, _uid, "tenant"] call APS_fnc_suiteRelease;
        [_pl, _oid] call _pushOne;
        [[_oid, _floor, false, ""], "AP_fnc_suiteDoorSync", -2, false] spawn AP_fnc_MP;
    };

    // -------------------------------------------------------------- payNow
    case "payNow": {
        private _oid = _a;
        if !([_oid] call _oidOk) exitWith {};
        private _row = [_oid] call _rowOf;
        if !((_row param [2, ""]) isEqualTo _uid) exitWith {};
        if ((_row param [4, 0]) isEqualTo 0) exitWith {};             // not overdue
        private _pay = [_uid, (localNamespace getVariable "APS_suiteRentND"), "suiteRent"] call APS_fnc_ndDebitSrv;
        if !(_pay param [0, false]) exitWith {
            [["poor", _oid], "AP_fnc_suiteReceive", _pl, false] spawn AP_fnc_MP; };
        // next_due advances from the OLD deadline, not from now -- paying late
        // must not silently buy you a fresh 30 days from the moment you paid.
        [format ["UPDATE suites SET next_due = next_due + %1, overdue_since = 0 WHERE oid='%2' AND owner='%3'", (localNamespace getVariable "APS_suiteTermS"), _oid, _uid], 2] call DB_fnc_asyncQuery;
        diag_log format ["[SUITE] %1 cleared arrears on %2", _uid, _oid];
        [_pl, _oid] call _pushOne;
    };

    // ----------------------------------------------------------- doorState
    // A client that joins (or relogs, or walks into a freshly streamed zone)
    // starts with every leaf unlocked and unowned. Its doors call this once they
    // are wired, and the server replays the truth for every leased suite.
    case "doorState": {
        private _rows = ["SELECT oid, floor, COALESCE(owner,'') AS owner, locked FROM suites WHERE owner IS NOT NULL", 2, true] call DB_fnc_asyncQuery;
        if !(_rows isEqualType []) exitWith {};
        {
            _x params [["_o", ""], ["_f", 0], ["_ow", ""], ["_lk", 1]];
            if (_o isNotEqualTo "") then {
                [[_o, _f, _lk isEqualTo 1, _ow], "AP_fnc_suiteDoorSync", _pl, false] spawn AP_fnc_MP;
            };
        } forEach _rows;
    };

    // ---------------------------------------------------------------- lock
    case "lock": {
        private _oid = _a; private _want = _b;
        if !([_oid] call _oidOk) exitWith {};
        private _row = [_oid] call _rowOf;
        if !((_row param [2, ""]) isEqualTo _uid) exitWith {};
        private _floor = _row param [1, 0];
        private _st = if (_want isEqualTo 0) then { 0 } else { 1 };
        [format ["UPDATE suites SET locked=%1 WHERE oid='%2' AND owner='%3'", _st, _oid, _uid], 2] call DB_fnc_asyncQuery;
        [[_oid, _floor, _st isEqualTo 1, _uid], "AP_fnc_suiteDoorSync", -2, false] spawn AP_fnc_MP;
    };
};
