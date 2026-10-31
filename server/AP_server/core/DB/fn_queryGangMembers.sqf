 
private["_query","_result","_ret","_id"]; 
 
_id = [_this,0,"0",["0"]] call BIS_fnc_param; 
 
_query = format["SELECT playerid,name,gangrank0 FROM %3 WHERE gang0= '%1' ORDER BY gangrank0, name DESC", _id, AP_server_instance, "players"]; 
_ret = [_query,2,true] call DB_fnc_asyncQuery; 
 
_ret;