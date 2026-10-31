 
private["_object"]; 
_object = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
if (isNull _object) exitWith {}; 
PLBObjectWhitelist set[count PLBObjectWhitelist,_object];