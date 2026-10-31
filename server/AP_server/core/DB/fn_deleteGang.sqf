 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_id","_query","_sql"]; 
_id = [_this,0,"",[""]] call BIS_fnc_param; 
 
_query = format["DELETE FROM gangs WHERE ctid IN (SELECT ctid FROM gangs WHERE id='%1' LIMIT 1)",_id]; 
[_query] call DB_fnc_asyncQuery; 
 
_query = format["UPDATE %3 SET gang0='0', gangrank0='3' WHERE gang0='%1'",_id, AP_server_instance, "players"]; 
[_query] call DB_fnc_asyncQuery;
// ...and the server's uid -> gang map (vars.sqf), or ex-members keep this id until they relog -- while fn_insertGang's
// MAX(id)+1 can hand the same id to the next new gang, with its HQ storage and alignment (audit 2026-09-26, r2gangmap).
private _gangOf = localNamespace getVariable "APS_gangOfUid";
private _gid = parseNumber _id;
{ _gangOf deleteAt _x } forEach ((keys _gangOf) select { (_gangOf get _x) isEqualTo _gid });