 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
diag_log "[updateStorage]"; 
private["_container","_containerId","_house","_buildingID","_housePos","_contents","_vContents","_query","_sql","_uniqueId"]; 
 
_container = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
if (isNull _container) exitWith {}; 
 
_contents = [(getWeaponCargo _container),(getMagazineCargo _container),(getBackpackCargo _container),(getItemCargo _container)]; 
_contents = [_contents] call DB_fnc_mresArray; 
_vContents = _container getVariable["Trunk", [[],0]]; 
_vContents = [_vContents] call DB_fnc_mresArray; 
 
_container setVariable["lootModified", false, true]; 
_containerId = _container getVariable["containerId", -1];
if !(_containerId isEqualType 0) exitWith {};   // PUBLIC var (fn_addStorage), so a client can set it to a string that breaks out of container='%3' below; server only ever writes a number
_uniqueId = _container getVariable["conUniqueId", -1]; 
_house = _container getVariable["house", objNull]; 
_buildingID = [_house] call AP_fnc_getBuildID; 
_housePos = getPos _house; 
 
 
_query = if (_uniqueId > -1) then {
format["UPDATE storage SET contents='%1', virtual='%2' WHERE id='%3'",_contents,_vContents,_uniqueId];}
else {
format["UPDATE storage SET contents='%1', virtual='%4' WHERE houseid='%2' AND container='%3'",_contents,_buildingID,_containerId,_vContents]; 
}; 
diag_log format["[updateStorage] _query = %1",_query]; 
[_query] call DB_fnc_asyncQuery;