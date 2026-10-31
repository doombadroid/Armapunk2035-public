/*
    APS_fnc_removeGangHouseSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Client (core/housing/fn_houseMenu.sqf "remove gang building" / fn_gangTransferOwner.sqf) sends
    [building, gangID]. Untag + clear the persisted position.
*/
params [["_building", objNull, [objNull]], ["_gangID", -1, ["", 0]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was ANY client could clear ANY gang's house_pos,
// _gangID raw in the UPDATE. Escape the id and require the NON-SPOOFABLE caller be the rank-1 LEADER of
// _gangID (remove-house + transfer-owner are both leader-only client paths).
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _ok = true;
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _crow = [format ["SELECT gangrank0 FROM %2 WHERE playerid='%1' AND gang0='%3'", _callerUID, "players", _idStr], 2] call DB_fnc_asyncQuery;
    private _rank = if ((_crow isEqualType []) && {count _crow >= 1} && {!isNil { _crow select 0 }}) then { parseNumber (format ["%1", _crow select 0]) } else { 99 };
    if (_rank != 1) then {
        ["-SEC-", _caller, format ["BLOCKED removeGangHouseSRV gang=%1 by %2 (rank %3)", _idStr, _callerUID, _rank]] call APS_fnc_logIt;
        _ok = false;};};
if (!_ok) exitWith {};   // top-level -> exits the function
if (!isNull _building) then { _building setVariable ["AP_house_gang", -1, true]; };
[format ["UPDATE gangs SET house_pos=NULL WHERE id='%1'", _idStr]] call DB_fnc_asyncQuery;
diag_log format ["[LooneyBin][gangHouse] gang %1 removed its house", _idStr];
