/*
    File: fn_ndDebitSrv.sqf  (APS_fnc_ndDebitSrv)
    LooneyBin 2026-08-06: SERVER-INITIATED New Drachma debit. Until now every ND
    debit in the codebase was a player clicking Buy (AP_fnc_ndBuySync ->
    APS_fnc_ndSRV "debit"); suite rent is the first charge the SERVER raises on
    its own, against players who may be offline.

        ["<uid>", "<amt>", "<reason>"] call APS_fnc_ndDebitSrv   ->  [_ok, "<newBalance>"]

    NOT IN CfgRE.hpp -- deliberately. That absence is the entire security model:
    a client cannot remoteExec this, so it needs no caller check and can charge a
    uid that isn't connected. (Same reasoning as APS_fnc_ndCreditSrv, whose
    header explains why a trusted mode cannot live inside the whitelisted
    APS_fnc_ndSRV: during a client-initiated RE chain remoteExecutedOwner stays
    the client's id, so an owner-based guard there cannot tell an internal call
    from a client forging the mode.)

    MUST be called from a SCHEDULED context -- the lock uses waitUntil. The rent
    sweep runs as a scheduler job, which satisfies that.

    Conventions inherited from fn_ndSRV.sqf, all load-bearing:
      * ALL arithmetic is SQL on DECIMAL(20,4). SQF 32-bit floats never touch the
        ledger -- exact 4dp money beyond the 2^24 float ceiling is why ND exists.
      * The amount's strict format check IS the SQL-injection guard; a validated
        amount is safe to interpolate.
      * The UPDATE's own `AND new_drachma >= amt` is the atomic authority. extDB3
        reports no row count through this pipe, so success is detected by an
        old/new string compare taken under the shared AP_ndLocks lock -- shared
        with APS_fnc_ndSRV, so rent can never interleave with the player's own
        purchase and fool the compare.
      * FAIL-CLOSED: a proof read that comes back empty is reported as FAILURE,
        never as success. The caller must not advance a due date on a false _ok.
*/
params [["_uid", "", [""]], ["_amt", "", [""]], ["_reason", "srv", [""]]];

private _ndValid = { params ["_s"];
    (_s isEqualType "") && {_s regexMatch "\d{1,14}(\.\d{1,4})?"} && {_s isNotEqualTo "0"} && {!(_s regexMatch "0+(\.0{1,4})?")} };
private _ndPad = { params ["_s"];
    private _p = _s splitString ".";
    private _i = _p param [0, "0"];
    private _f = _p param [1, ""];
    while { count _f < 4 } do { _f = _f + "0" };
    while { count _i < 14 } do { _i = "0" + _i };
    _i + _f };
private _ndGE = { params ["_pa", "_pb"];
    private _aa = toArray _pa; private _bb = toArray _pb;
    private _r = true;
    for "_i" from 0 to ((count _aa) - 1) do {
        private _ca = _aa select _i; private _cb = _bb select _i;
        if (_ca != _cb) exitWith { _r = _ca > _cb };};
    _r };
private _ndSelect = { params ["_u"];
    private _row = [format ["SELECT new_drachma FROM players WHERE playerid='%1'", _u], 2] call DB_fnc_asyncQuery;
    if !(_row isEqualType []) exitWith { "" };
    private _v = _row param [0, ""];
    if !(_v isEqualType "") exitWith { "" };
    _v };

if !(_uid regexMatch "\d{17}") exitWith {
    diag_log format ["[SUITE][ND] debit refused: bad uid '%1'", _uid];
    [false, ""] };
if !([_amt] call _ndValid) exitWith {
    diag_log format ["[SUITE][ND] debit refused: bad amount '%1' for %2", _amt, _uid];
    [false, ""] };

// localNamespace (mints audit 2026-09-26): as a mission global a client publicVariable could clear the lock and
// interleave a credit with a debit, which reads as a successful debit that never happened.
private _ndLocks = localNamespace getVariable "AP_ndLocks";
if (isNil "_ndLocks") then { _ndLocks = createHashMap; localNamespace setVariable ["AP_ndLocks", _ndLocks]; };
private _t0 = diag_tickTime;
waitUntil { !(_ndLocks getOrDefault [_uid, false]) || {diag_tickTime - _t0 > 8} };
if (_ndLocks getOrDefault [_uid, false]) exitWith {
    diag_log format ["[SUITE][ND] debit refused: lock busy for %1 (db wedged?)", _uid];
    [false, ""] };
_ndLocks set [_uid, true];

private _old = [_uid] call _ndSelect;
private _ok = false;
private _new = _old;

if (_old isNotEqualTo "" && { [[_old] call _ndPad, [_amt] call _ndPad] call _ndGE }) then {
    [format ["UPDATE players SET new_drachma = new_drachma - %1 WHERE playerid='%2' AND new_drachma >= %1", _amt, _uid], 2] call DB_fnc_asyncQuery;
    _new = [_uid] call _ndSelect;
    _ok = (_new isNotEqualTo "") && { _new isNotEqualTo _old };
};

_ndLocks set [_uid, false];
if (_new isEqualTo "") then { _new = _old; };

diag_log format ["[SUITE][ND] debit -%1 (%2) %3 -> %4 = %5",
    _amt, _reason, _uid, ["DENIED", "OK"] select _ok, _new];

// keep an online payer's HUD honest
if (_ok) then {
    private _pl = (allPlayers select { getPlayerUID _x isEqualTo _uid }) param [0, objNull];
    if (!isNull _pl) then {
        [[_new, _reason, _amt], "AP_fnc_ndSync", _pl, false] spawn AP_fnc_MP;
    };
};

[_ok, _new]
