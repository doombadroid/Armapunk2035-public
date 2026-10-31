/*
    APS_fnc_gangGarageAddSRV  (LooneyBin)
    client args: [gangID, player, uid, plate, dispName, ...]
    Move a garaged PERSONAL vehicle (vehicles table) into the gang garage.
*/
params [["_gangID",-1,[0]],["_player",objNull,[objNull]],["_uid","",[""]],["_plate",-1,[0]]];
if (_gangID < 0 || _plate < 0) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.2 CRIT + §2.3): CfgRE-whitelisted -> a client could remoteExec
// [myGangID, player, VICTIM_UID, VICTIM_PLATE] to MOVE another player's garaged vehicle into its own gang
// garage (theft). Derive the actor from the non-spoofable remoteExecutedOwner (model fn_seizeLock:22),
// require gang membership, and -- crucially -- use the CALLER's own UID as the source `pid` so you can only
// add a vehicle YOU own (the SELECT/DELETE are scoped `WHERE pid='<callerUID>'`). FLAT top-level exitWith.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller || {(format ["%1", (_caller getVariable ["gang_data", [-1]]) param [0, -1]]) isNotEqualTo (format ["%1", _gangID])}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED gangGarageAddSRV (not a member of gang %1) by %2", _gangID, getPlayerUID _caller]] call APS_fnc_logIt;
};
if (_src isNotEqualTo 0) then { _player = _caller; _uid = getPlayerUID _caller; };   // source pid = caller -> can only add a vehicle the CALLER owns (no rival-UID theft, no raw client UID in SQL)
private _uidSql    = (format ["%1", _uid])    splitString "'" joinString "";   // SQL-escape (security.md §2.3)
private _gangIDsql = (format ["%1", _gangID]) splitString "'" joinString "";
private _plateSql  = (format ["%1", _plate])  splitString "'" joinString "";
// QUOTE the varchar/text cols: asyncQuery call-compiles the result, so raw classname/type/inventory
// would die on the bare token. color/fuel/damage are numeric (raw). _r select 2 stays a backtick
// string -> re-inserted as-is below.
private _r = [format ["SELECT classname,type,inventory,color,fuel,damage FROM vehicles WHERE pid='%1' AND plate='%2'", _uidSql, _plateSql], 2] call DB_fnc_asyncQuery;
if (_r isEqualTo []) exitWith {};
// owner 2026-06-18 (#335): UPSERT (see fn_gangGarageStore) -- a re-add can't create a duplicate (gang_id, plate).
[format ["INSERT INTO gang_vehicles (pid,classname,type,gang_id,inventory,active,plate,color,fuel,damage) VALUES ('%1','%2','%3','%4','%5','0','%6','%7','%8','%9') ON CONFLICT (gang_id, plate) DO UPDATE SET pid='%1', classname='%2', type='%3', inventory='%5', active = false, color='%7', fuel='%8', damage='%9'",
    _uidSql, _r select 0, _r select 1, _gangIDsql, _r select 2, _plateSql, _r select 3, _r select 4, _r select 5]] call DB_fnc_asyncQuery;
[format ["DELETE FROM vehicles WHERE pid='%1' AND plate='%2'", _uidSql, _plateSql]] call DB_fnc_asyncQuery;
