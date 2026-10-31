 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_crate", "_worldspace", "_posIndex", "_house", "_query", "_sql"]; 
 
_crate = [_this,0,"",[""]] call BIS_fnc_param; 
_worldspace = [_this,1,[],[[],false]] call BIS_fnc_param; 
_posIndex = [_this,2,-1,[-1]] call BIS_fnc_param; 
_house = [_this,3,objNull,[objNull]] call BIS_fnc_param; 
_houseWorldspace = position _house; 
 
_buildingID = [_house] call AP_fnc_getBuildID; 
 
_worldspace = [_worldspace] call DB_fnc_mresArray; 
_houseWorldspace = [_houseWorldspace] call DB_fnc_mresArray; 
 
 
_query = format["INSERT INTO storage (houseid, worldspace, container, classname, contents,virtual,houseworldspace) VALUES ('%1', '%2', '%3', '%4', '""[]""', '""[[],0]""','%5')",_buildingID,_worldspace,_posIndex,_crate,_houseWorldspace]; 
[_query] call DB_fnc_asyncQuery;