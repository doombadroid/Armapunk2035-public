 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_container","_containerId","_house","_buildingID","_housePos","_contents","_vContents","_query","_sql"]; 
 
_container = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
if (isNull _container) exitWith {}; 
 
_containerId = _container getVariable["containerId", -1]; 
if !(_containerId isEqualType 0) exitWith {};   // PUBLIC var: a string would break out of container='%2' below (same guard as DB_fnc_updateStorage)
_house = _container getVariable["house", objNull]; 
if (isNull _house) exitWith {}; 
_housePos = getPos _house; 
 
_containers = _house getVariable ["containers", []]; 
_containers = _containers - [_container]; 
_house setVariable ["containerCount", (_house getVariable["containerCount", 1])-1, true]; 
_house setVariable ["containers", _containers]; 
 
 
_query = format["DELETE FROM storage WHERE houseworldspace='""%1""' AND container='%2'",_housePos,_containerId]; 
[_query] call DB_fnc_asyncQuery; 
 
deleteVehicle _container;