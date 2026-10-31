 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_oid","_query","_sql","_worldspace"]; 
_oid = [_this,0,"",[""]] call BIS_fnc_param; 
_house = [_this,1,objNull,[objNull]] call BIS_fnc_param; 
_worldspace = getPos _house; 
_worldspacestr = [_worldspace] call DB_fnc_mresArray; 
_houseId = [_house] call AP_fnc_getBuildID; 
 
 {[_x, player] call APS_fnc_removeStorage;} forEach (_house getVariable["containers", []]);
 
_query = format["DELETE FROM houses WHERE ctid IN (SELECT ctid FROM houses WHERE worldspace='%1' OR oid='%2' LIMIT 1)",_worldspacestr,_houseId]; 
[_query] call DB_fnc_asyncQuery; 
 
[_oid] call DB_fnc_deleteGang; 
 
_index = -1; 
{ if (str _worldspace == str (_x select 2)) then { _index = _forEachIndex; }; } forEach AP_house_owners; 
AP_house_owners set[_index, -1]; 
AP_house_owners = AP_house_owners - [-1];