/*
    APS_fnc_gangBHistory  (LooneyBin -- implemented from stub 2026-06-09)
    Client (dialog/function/fn_gangBankHist.sqf) sends: [(AP_gang_data select 0), player]
    and then waits on AP_gangHistory_Ready + AP_gangBank_History.
    Row shape the client renders: [name@0, dateStr@1, type@2 (1=Deposited 2=Withdrew 3=Transferred), amount@3].
    Source = gang_bank_log table, written by APS_fnc_gangBank on every deposit/withdraw/transfer.
    Reply transport = AP_fnc_netSetVar (both vars are on its approved list; server-origin passes its gate).
*/
params [["_gangID", "", ["", 0]], ["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was _gangID RAW into the SELECT (UNION-exfil any column,
// reply goes back to the caller) + ANY client could dump ANY gang's bank history. Escape the id and require
// the caller be a MEMBER of that gang (client opens history only from its own gang ATM menu). Gov treasury
// (50000) history is readable by the seated governor.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;
if (_idStr isEqualTo "") exitWith {};
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _isGov = (_idStr isEqualTo "50000") && {(_callerUID isEqualTo (localNamespace getVariable ["SRV_governorData", ["", ""]] param [0, ""])) && {_callerUID isNotEqualTo ""}};
    private _crow = [format ["SELECT COUNT(*) AS c0 FROM %3 WHERE playerid='%1' AND gang0='%2'", _callerUID, _idStr, "players"], 2] call DB_fnc_asyncQuery;
    private _isMember = (_crow isEqualType []) && {count _crow >= 1} && {(parseNumber (format ["%1", _crow select 0])) > 0};
    if (!_isMember && {!_isGov}) then {
        ["-SEC-", _caller, format ["BLOCKED gangBHistory gang=%1 by %2", _idStr, _callerUID]] call APS_fnc_logIt;
        _idStr = "";   // flag failure -> the top-level guard below exits the FUNCTION
    };};
if (_idStr isEqualTo "") exitWith {};   // top-level -> exits the function

// DATE_FORMAT would need % chars (eaten by SQF format) -> build the query by concatenation
private _q = "SELECT QUOTE(name), QUOTE(DATE_FORMAT(ts, '" + "%b %e %H:%i" + "')), type, amount FROM gang_bank_log WHERE gangid='" + _idStr + "' ORDER BY id DESC LIMIT 30";
private _rows = [_q, 2, true] call DB_fnc_asyncQuery;
private _hist = [];
if (_rows isEqualType []) then {
    _hist = _rows apply { [format ["%1", _x param [0, "?"]], format ["%1", _x param [1, ""]], _x param [2, 0], _x param [3, 0]] };};
[["AP_gangBank_History", _hist], "AP_fnc_netSetVar", _unit, false, false] spawn AP_fnc_MP;
[["AP_gangHistory_Ready", true], "AP_fnc_netSetVar", _unit, false, false] spawn AP_fnc_MP;
