/*
    fn_asyncExec.sqf  (DB_fnc_asyncExec) -- one WRITE, with an answer.

        [_sql, _params] call DB_fnc_asyncExec
            -> [1, rowcount, rows]   the write ran; rowcount says what it hit
                                     (0 = a WHERE guard refused; -1 = DDL);
                                     rows = a RETURNING clause's rows, else []
            -> [0, "<message>"]      the write FAILED (connection, SQL error)

    This ends the [] ambiguity for writes: DB_fnc_asyncQuery mode 1 returns
    true whether the UPDATE hit one row or none, and failure was invisible, so
    every dupe-critical writer had to prove its write with a re-SELECT. Here
    the three outcomes are distinguishable at the call site. The re-SELECT
    proof stays warranted where money is minted (belt and braces); everywhere
    else this is the honest primitive.

    _params is the PARAMETERISED path: %s / %(name)s placeholders in the SQL,
    values in the array -- never format a player-controlled string into SQL.
    The layer below refuses interpolated statements when params are supplied.

    PostgreSQL only, scheduled-only (same rule and guard as asyncQuery: an
    unscheduled caller cannot wait on the transport).
*/
if (!canSuspend) exitWith {
    diag_log format ["[DBGUARD] UNSCHEDULED asyncExec REFUSED (fix the caller: spawn it): %1",
        ([_this, 0, "", [""]] call BIS_fnc_param) select [0, 200]];
    [0, "unscheduled caller"]
};
params [["_sql", "", [""]], ["_params", [], [[]]]];
if (_sql isEqualTo "") exitWith { [0, "empty statement"] };
waitUntil { "AP_db_engineDecided" call DB_fnc_flag };
if !("AP_db_postgres" call DB_fnc_flag) exitWith {
    diag_log format ["[apdb] asyncExec needs PostgreSQL and the engine is not it: %1", _sql select [0, 120]];
    [0, "not on postgres"]
};
waitUntil { !("DB_Async_Active" call DB_fnc_flag) };
localNamespace setVariable ["DB_Async_Active", true];
diag_log format ["SQL Exec: %1", _sql];
private _reply = ["apdb.execp", [_sql, _params]] call APS_fnc_pysqfCall;
localNamespace setVariable ["DB_Async_Active", false];
_reply params [["_ok", false], ["_payload", []]];
if (!_ok) exitWith {
    diag_log format ["[apdb] EXEC FAILED: %1 -- statement: %2", _payload, _sql];
    [0, format ["%1", _payload]]
};
// _payload = [1, rowcount, rows] from the bridge
_payload
