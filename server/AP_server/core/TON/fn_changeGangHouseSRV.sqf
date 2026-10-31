/*
    APS_fnc_changeGangHouseSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Client (core/gangs/fn_changeGangHouse.sqf) sends [_oldHouse, _newHouse, _gangID].
    Untag the old building, tag + persist the new one.
*/
params [["_old", objNull, [objNull]], ["_new", objNull, [objNull]], ["_gangID", -1, ["", 0]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was ANY client could move/clear ANY gang's house_pos,
// _gangID raw in the UPDATE. Escape the id and require the NON-SPOOFABLE caller be the rank-1 LEADER of
// _gangID (client gate fn_changeGangHouse = AP_gang_data[2]==1).
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _ok = true;
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _crow = [format ["SELECT gangrank0 FROM %2 WHERE playerid='%1' AND gang0='%3'", _callerUID, "players", _idStr], 2] call DB_fnc_asyncQuery;
    private _rank = if ((_crow isEqualType []) && {count _crow >= 1} && {!isNil { _crow select 0 }}) then { parseNumber (format ["%1", _crow select 0]) } else { 99 };
    if (_rank != 1) then {
        ["-SEC-", _caller, format ["BLOCKED changeGangHouseSRV gang=%1 by %2 (rank %3)", _idStr, _callerUID, _rank]] call APS_fnc_logIt;
        _ok = false;};};
if (!_ok) exitWith {};   // top-level -> exits the function

// owner 2026-09-26 SECURITY (houses audit): the NEW building was never checked server-side, so a leader could move the
// gang HQ onto ANY house -- and gangs.house_pos is what grants gang members storage access (APS_fnc_houseRights). The
// caller must own it on its houses row (the client's Change Gang House button is owner-only, fn_houseMenu).
private _hqCaller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
private _hqRights = if (_src isEqualTo 0 || {isNull _new}) then { [] } else { [_new] call APS_fnc_houseRights };
private _hqOwner = _hqRights param [1, ""];
if (_src isNotEqualTo 0 && {!isNull _new} && {isNull _hqCaller || {_hqOwner isEqualTo ""} || {_hqOwner isNotEqualTo (getPlayerUID _hqCaller)}}) exitWith {
    ["-SEC-", _hqCaller, format ["BLOCKED changeGangHouseSRV gang=%1: new building not owned by the caller (owner %2)", _idStr, _hqOwner]] call APS_fnc_logIt;};
if (!isNull _old) then { _old setVariable ["AP_house_gang", -1, true]; };
if (isNull _new) exitWith {[format ["UPDATE gangs SET house_pos=NULL WHERE id='%1'", _idStr]] call DB_fnc_asyncQuery;};
_new setVariable ["AP_house_gang", _gangID, true];
// the HQ is the authorised ROW's building (houses.worldspace = its getPosATL at buy), never wherever the passed object stands
private _pos = _hqRights param [4, []];
if (count _pos < 3) then { _pos = getPosATL _new; };
[format ["UPDATE gangs SET house_pos='[%2,%3,%4]' WHERE id='%1'", _idStr, _pos select 0, _pos select 1, _pos select 2]] call DB_fnc_asyncQuery;
diag_log format ["[LooneyBin][gangHouse] gang %1 moved house to %2", _idStr, _pos];
