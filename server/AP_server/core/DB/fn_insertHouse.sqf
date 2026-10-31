 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_uid","_oid","_locked","_worldspace","_query","_sql"]; 
_oid = [_this,0,"",[""]] call BIS_fnc_param; 
_uid = [_this,1,"",["",false]] call BIS_fnc_param; 
_locked = [_this,2,-1,[0]] call BIS_fnc_param; 
_worldspace = [_this,3,[],[[],false]] call BIS_fnc_param; 
 
 
AP_house_owners pushBack [_oid, _uid, _worldspace]; 
 
_query = format["DELETE FROM houses WHERE worldspace='%1'", _worldspace, AP_server_instance]; 
[_query,2] call DB_fnc_asyncQuery; 
_query = format["INSERT INTO houses (oid, owners, locked, worldspace) VALUES ('%1', '%2', '%3', '%4')",_oid,_uid,_locked,_worldspace,AP_server_instance]; 
[_query,2] call DB_fnc_asyncQuery; 
 
sleep 5; 
 
_query = format["SELECT id FROM houses WHERE worldspace='%1'", _worldspace, AP_server_instance]; 
_ret = [_query,2,true] call DB_fnc_asyncQuery; 
_ret = _ret select 0; 
 
_house = _worldspace nearestObject "House_F"; 
_house setVariable ["houseId", _ret select 0, true];