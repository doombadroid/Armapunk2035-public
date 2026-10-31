/*
    APS_fnc_removeGang  (LooneyBin)  -- gang disband.  client args: [player, gangName, gangID]
    Old passthrough handed the player OBJECT to DB_fnc_deleteGang (wants gang id @0) -> wrong row.
    Pull the id, delete + clear members in DB, then clear every ONLINE member's client gang state.
*/
params [["_unit", objNull, [objNull]], ["_gangName", "", [""]], ["_gangID", 0, [0, ""]]];
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was [player,"",rivalGangID] -> DISBAND ANY GANG (no rank
// check), and _gangID flowed RAW into DB_fnc_deleteGang's DELETE/UPDATE. Derive the NON-SPOOFABLE caller and
// require they be the rank-1 LEADER of THIS gang (client gate = AP_gang_data[2]==1); escape the id for SQL.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _idStr = (format ["%1", _gangID]) call _san;   // SQLi-safe (reaches deleteGang's raw format[] queries)
if (_idStr in ["", "0", "-1"]) exitWith {};
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src != 0) then {private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    private _callerUID = getPlayerUID _caller;
    private _row = [format ["SELECT gangrank0 FROM %2 WHERE playerid='%1' AND gang0='%3'", _callerUID, "players", _idStr], 2] call DB_fnc_asyncQuery;
    private _rank = if ((_row isEqualType []) && {count _row >= 1} && {!isNil { _row select 0 }}) then { parseNumber (format ["%1", _row select 0]) } else { 99 };
    if (_rank != 1) then {
        ["-SEC-", _caller, format ["BLOCKED removeGang gang=%1 by %2 (rank %3)", _idStr, _callerUID, _rank]] call APS_fnc_logIt;
        _idStr = "";   // flag the failure; the top-level guard below exits the FUNCTION
    };};
if (_idStr isEqualTo "") exitWith {};   // top-level -> exits the function (blocked caller or invalid id)
[_idStr] call DB_fnc_deleteGang;
private _idNum = parseNumber _idStr; {[[_idNum], "AP_fnc_gangDisbanded", _x, false] spawn AP_fnc_MP;} forEach (allPlayers select {
    (format ["%1", (_x getVariable ["gang_data", []]) param [0, ""]]) isEqualTo _idStr});
