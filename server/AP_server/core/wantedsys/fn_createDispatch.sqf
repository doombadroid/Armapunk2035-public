 
private["_id","_desc","_value","_chance"]; 
 
_id = [_this,0,0,[0]] call BIS_fnc_param; 
_desc = [_this,1,"",[""]] call BIS_fnc_param; 
_value = [_this,2,0,[0]] call BIS_fnc_param; 
_chance = [_this,3,0,[0]] call BIS_fnc_param; 
_maxCops = [_this,4,4,[0]] call BIS_fnc_param; 
_position = [_this,5,[0,0,0],[[]]] call BIS_fnc_param; 
_unitUID = [_this,6,"",[""]] call BIS_fnc_param; 
 
if (isNull AP_dispatcher && _unitUID == "") then {{if (_x call APS_fnc_isDutyCop) then {
[[_id,_desc,_value,_position], "AP_fnc_newDispatch", _x, false] spawn AP_fnc_MP;};} forEach allPlayers;};
 
AP_dispatchTasks pushBack [_id,_desc,_value,_maxCops,[],_position,_unitUID]; 
if (!isNull AP_dispatcher) then { (AP_dispatcher getVariable ["ownerID", -1]) publicVariableClient "AP_dispatchTasks" };