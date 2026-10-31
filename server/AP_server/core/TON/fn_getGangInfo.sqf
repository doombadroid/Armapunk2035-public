/*
    APS_fnc_getGangInfo  (LooneyBin)  -- client args: [gangID, player]
    Fetch this gang's member rows and push them to the caller via AP_fnc_gangMembersReceive.
    WAS mis-wired to APS_fnc_queryGangs (the all-gangs leaderboard loop) -> members never arrived,
    gang menu hung on "Loading...".
*/
params [["_gangID", "0", ["", 0]], ["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was ANY client could dump ANY gang's full member roster
// (UID recon), with _gangID raw into DB_fnc_queryGangMembers' WHERE gang0="%1". Escape the id and require the
// caller be a MEMBER of that gang (the menu only ever requests its own gang). Gov treasury readable by governor.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _ok = true;
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _isGov = (_idStr isEqualTo "50000") && {(_callerUID isEqualTo (localNamespace getVariable ["SRV_governorData", ["", ""]] param [0, ""])) && {_callerUID isNotEqualTo ""}};
    private _crow = [format ["SELECT COUNT(*) AS n FROM %3 WHERE playerid='%1' AND gang0='%2'", _callerUID, _idStr, "players"], 2] call DB_fnc_asyncQuery;
    private _isMember = (_crow isEqualType []) && {count _crow >= 1} && {(parseNumber (format ["%1", _crow select 0])) > 0};
    if (!_isMember && {!_isGov}) then {
        ["-SEC-", _caller, format ["BLOCKED getGangInfo gang=%1 by %2", _idStr, _callerUID]] call APS_fnc_logIt;
        _ok = false;};};
if (!_ok) exitWith {};   // top-level -> exits the function
private _ret = [_idStr] call DB_fnc_queryGangMembers;
if (isNil "_ret" || {!(_ret isEqualType [])}) then { _ret = []; };
[_ret, "AP_fnc_gangMembersReceive", _unit, false] spawn AP_fnc_MP;
