 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_oid","_query","_sql","_worldspace"]; 
_uid = [_this,0,"",[""]] call BIS_fnc_param;
// owner 2026-06-23 SECURITY (security.md §2.3): _uid (client-originated upstream) flowed raw into the DELETE
// below -> `' OR '1'='1` would wipe the wanted table. Escape it with the in-repo _san strip before the query.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
 
 
_query = "DELETE FROM wanted WHERE playerid = %s"; 
[_query, 1, false, [_uid]] call DB_fnc_asyncQuery;