/*
    File: fn_suiteReceive.sqf  (AP_fnc_suiteReceive)
    Luxe Suites 2026-08-06 -- server -> client push. CfgRE allowedTargets = 1.

    Three shapes, distinguished by the payload:
        [_rows, "<towerKey>", "list"]   full directory for one tower
        [_row]                          one row changed (lease/end/pay)
        ["taken"|"poor", "<oid>"]       a refusal, with the reason

    The client keeps ONE cache, AP_suiteRows (oid -> row), and the dialog reads
    only from it. Rows the server never sent are vacant by definition -- the table
    only holds floors that have ever been leased, so absence IS the vacant state.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_p0", [], [[], ""]], ["_p1", "", [""]], ["_p2", "", [""]]];
if (isNil "AP_suiteRows") then { AP_suiteRows = createHashMap; };

// Rows arrive straight off apdb, which types an integer by its MAGNITUDE: a
// column is a Number until the value passes 16,777,216 and a STRING after
// (apdb.py _to_sqf -- the rule that stops a balance rounding on read). next_due
// and overdue_since are unix epochs, so they are Numbers only while they are 0.
// Every consumer then does arithmetic on them (`_over > 0`, `(_due - _now)`)
// and throws "Type String, expected Number" for exactly the leased/overdue rows
// the screens exist to show. Normalise ONCE, here, where rows enter the cache:
// every reader of AP_suiteRows gets Numbers, including the ones not written yet.
private _fnNorm = {
    params ["_r"];
    if !(_r isEqualType []) exitWith { _r };
    if (count _r > 3) then { _r set [3, [_r param [3, 0]] call AP_fnc_dbNum]; };
    if (count _r > 4) then { _r set [4, [_r param [4, 0]] call AP_fnc_dbNum]; };
    _r
};

// ---- refusals -------------------------------------------------------------
if (_p0 isEqualType "") exitWith {
    private _msg = switch (_p0) do {
        case "taken": { "That suite was leased by someone else a moment ago." };
        case "poor":  { format ["You need %1 New Drachma for the first month.", AP_suiteRentND] };
        default { "" };
    };
    if (_msg isNotEqualTo "") then { [_msg, "basic"] spawn AP_fnc_handleMessage; };
    AP_suiteBusy = false;
    if (!isNull (findDisplay 941600)) then { [] call AP_fnc_suiteKioskRefresh; };
};

// ---- full directory -------------------------------------------------------
if (_p2 isEqualTo "list") exitWith {
    { AP_suiteRows set [(_x param [0, ""]), ([_x] call _fnNorm)]; } forEach _p0;
    AP_suiteTowerKey = _p1;
    AP_suiteBusy = false;
    if (!isNull (findDisplay 941600)) then { [] call AP_fnc_suiteKioskRefresh; };
};

// ---- single row -----------------------------------------------------------
private _row = _p0;
if (count _row < 3) exitWith { AP_suiteBusy = false; };
AP_suiteRows set [(_row param [0, ""]), ([_row] call _fnNorm)];
AP_suiteBusy = false;
if (!isNull (findDisplay 941600)) then { [] call AP_fnc_suiteKioskRefresh; };
