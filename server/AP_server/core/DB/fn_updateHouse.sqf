 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_oid","_locked","_query","_sql","_worldspace"]; 
_oid = [_this,0,"",[""]] call BIS_fnc_param; 
_locked = [_this,1,-1,[0]] call BIS_fnc_param; 
_worldspace = [_this,2,[],[[],false]] call BIS_fnc_param; 
 
 
_query = format["UPDATE houses SET locked='%1',worldspace='%3' WHERE oid='%2'",_locked,_oid,_worldspace,AP_server_instance]; 
[_query] call DB_fnc_asyncQuery;