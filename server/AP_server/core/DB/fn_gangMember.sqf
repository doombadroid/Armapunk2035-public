 
private["_uid","_gang","_rank"]; 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
_uid = [_this,0,"0",["0"]] call BIS_fnc_param; 
_gang = [_this,1,"0",["0"]] call BIS_fnc_param; 
_rank = [_this,2,3,[3]] call BIS_fnc_param; 
 
if (_rank < 0) exitWith {}; 
 
 
_query = format["UPDATE %5 SET gang0='%2',gangrank0='%3' WHERE playerid='%1'",_uid,_gang,_rank,AP_server_instance,"players"]; 
[_query] call DB_fnc_asyncQuery;