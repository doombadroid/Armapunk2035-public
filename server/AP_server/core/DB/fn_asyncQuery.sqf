/*
    fn_asyncQuery.sqf  —  extDB3 (LooneyBin migration of the 2017 extDB2 version)

    Single chokepoint for all server SQL. Migrated extDB2 (DB_RAW_V2) -> extDB3 (SQL protocol).
    Caller contract is UNCHANGED so all existing callers keep working:
      params: 0=query string, 1=mode (1=async no-return, 2=async return), 2=multiarr (true=all rows)
      returns: mode 1 -> true ; mode 2 -> first row, or all rows if _multiarr

    extDB3 differences vs extDB2 handled here:
      - extension name "extDB" -> "extDB3"
      - result read via "4:<key>" ("[3]" = not ready), multi-part drained via "5:<key>"
      - result rows live at (result select 1) (one level, not two as in DB_RAW_V2)
      - (result select 0)==0 means protocol error
*/
// Which ENGINE is still being decided at boot (init.sqf probes PySQF). Wait for
// it: a query that runs before the answer lands on whichever engine happens to
// be selected at that instant, and a boot split across two databases writes half
// its rows where nobody will look for them.
// pg-native U2: the class guard. This function has ALWAYS been scheduled-only
// (the two waitUntils below suspend), but an unscheduled caller used to die
// with a suspension error extDB3 sometimes survived; under apdb it becomes a
// refused call and a silently lost write. Make the contract structural:
//   mode 1 (fire-and-forget) re-spawns itself -- the semantics mode 1 always
//   had -- and returns true to the caller exactly as before;
//   mode 2 NEEDS a synchronous answer an unscheduled frame cannot wait for:
//   refuse loudly, naming the statement, so the broken caller is findable in
//   the RPT instead of reading [] as "no rows".
if (!canSuspend) exitWith {
    private _mode = [_this,1,1,[0]] call BIS_fnc_param;
    if (_mode == 1) then {
        _this spawn DB_fnc_asyncQuery;
        true
    } else {
        diag_log format ["[DBGUARD] UNSCHEDULED mode-2 query REFUSED (fix the caller: spawn it): %1",
            ([_this,0,"",[""]] call BIS_fnc_param) select [0, 200]];
        []
    }
};
waitUntil { "AP_db_engineDecided" call DB_fnc_flag };
waitUntil {!("DB_Async_Active" call DB_fnc_flag)};
private["_queryStmt","_mode","_multiarr","_key","_queryResult","_pipe","_return"];
_queryStmt = [_this,0,"",[""]]       call BIS_fnc_param;
_mode      = [_this,1,1,[0]]          call BIS_fnc_param;
_multiarr  = [_this,2,false,[false]] call BIS_fnc_param;
// Optional 4th argument: parameter values for %s / %(name)s placeholders. The
// injection-proof path -- values travel beside the SQL, never inside it. Only
// meaningful on the PostgreSQL engine; the extDB3 path below cannot carry them
// and refuses rather than silently running a statement full of bare %s.
private _sqlParams = [_this,3,[],[[]]] call BIS_fnc_param;

if(_queryStmt == "") exitWith {"_INVALID_SQL_STMT"};
diag_log format["SQL Query: %1", _queryStmt];

// ---------------------------------------------------------------------------
// ENGINE SELECT -- PostgreSQL over PySQF, or extDB3 over MariaDB.
//
// AP_db_postgres is set once, in init.sqf, from a single flag (localNamespace, read via DB_fnc_flag). Everything below
// this block is the extDB3 path, untouched, and it stays that way: the point of
// putting the switch HERE, at the one chokepoint all 1478 call sites already go
// through, is that going back is one variable rather than a revert.
//
// The SQL is NOT rewritten on this side. It stays MariaDB-flavoured and the
// translation happens in `apdb_sql.py`, in one file, with a test that runs the
// whole 400-statement corpus through it -- rather than in 400 hand edits nobody
// can test the 3am ones of.
//
// The contract is identical on both paths, deliberately:
//   mode 1  -> true
//   mode 2  -> the first row, or every row when _multiarr
//   no rows -> []
// A FAILURE is the one thing that cannot look like "no rows": PySQF answers
// [false, "..."], and this logs it and returns [] only after saying so. The
// blocking helper this codebase replaced returned [] for both and every caller
// downstream guessed wrong in the same direction.
// ---------------------------------------------------------------------------
if ("AP_db_postgres" call DB_fnc_flag) exitWith {
    localNamespace setVariable ["DB_Async_Active", true];
    private _reply = if (_sqlParams isEqualTo []) then {
        ["apdb.query", [_queryStmt, _mode, _multiarr]] call APS_fnc_pysqfCall
    } else {
        ["apdb.queryp", [_queryStmt, _sqlParams, _mode, _multiarr]] call APS_fnc_pysqfCall
    };
    localNamespace setVariable ["DB_Async_Active", false];
    _reply params [["_ok", false], ["_payload", []]];
    if (!_ok) exitWith {
        diag_log format ["[apdb] QUERY FAILED: %1 -- query: %2", _payload, _queryStmt];
        if (_mode isEqualTo 1) then { false } else { [] };
    };
    _payload
};

if (_sqlParams isNotEqualTo []) exitWith {
    diag_log format ["[DBGUARD] parameterised query REFUSED on the extDB3 engine: %1", _queryStmt select [0, 120]];
    if (_mode isEqualTo 1) then { false } else { [] };
};
localNamespace setVariable ["DB_Async_Active", true];
_key = "extDB3" callExtension format["%1:%2:%3",_mode,uiNamespace getVariable ["AP_sql_id", 0],_queryStmt];

// mode 1 = fire & forget (INSERT/UPDATE/DELETE), no result wanted
if(_mode == 1) exitWith {localNamespace setVariable ["DB_Async_Active", false]; true};

_key = call compile format["%1",_key];
_key = _key select 1;

_queryResult = "extDB3" callExtension format["4:%1",_key];

// "[3]" = result not ready yet -> spin until ready
if(_queryResult isEqualTo "[3]") then {while {true} do {if !(_queryResult isEqualTo "[3]") exitWith {};
        uiSleep 0.005;   // LooneyBin [PERF step 4]: the not-ready spin had NO yield -> starved the whole scheduler under load (asyncQuery always runs scheduled: the waitUntil above guarantees it)
        _queryResult = "extDB3" callExtension format["4:%1",_key];};};

// "[5]" = multi-part message -> drain via 5:<key> until empty
if(_queryResult isEqualTo "[5]") then {_queryResult = "";
    while {true} do {_pipe = "extDB3" callExtension format["5:%1",_key];
        if(_pipe isEqualTo "") exitWith {};
        _queryResult = _queryResult + _pipe;};};

localNamespace setVariable ["DB_Async_Active", false];

_queryResult = call compile _queryResult;
if((_queryResult select 0) isEqualTo 0) exitWith {diag_log format["extDB3: Protocol Error: %1 (query: %2)",_queryResult,_queryStmt]; []};

_return = (_queryResult select 1);
if(count _return == 0) exitWith {[]};
if(!_multiarr) then { _return = _return select 0; };

_return;
