 
private["_unit","_pos","_i"]; 
_unit = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
_pos = [_this,1,[0,0,0],[[]]] call BIS_fnc_param; 
_remove = [_this,2,false,[false]] call BIS_fnc_param; 
 
_toRemove = []; {if (isNull (_x select 0)) then {_toRemove pushBack _forEachIndex;};} forEach AP_dispatchWaypoints; {
AP_dispatchWaypoints set [_x, "DIE"]; 
AP_dispatchWaypoints = AP_dispatchWaypoints - ["DIE"];} forEach _toRemove;
 
_i = -1; {if (_x select 0 == _unit) exitWith { _i = _forEachIndex; };} forEach AP_dispatchWaypoints;
 
if (_i > -1) then {AP_dispatchWaypoints set [_i, "DIE"];
AP_dispatchWaypoints = AP_dispatchWaypoints - ["DIE"];};
 
if (!_remove) then { AP_dispatchWaypoints pushBack [_unit, _pos] }; 
 
(AP_dispatcher getVariable ["ownerID", -1]) publicVariableClient "AP_dispatchWaypoints"; 
 
[[_pos, _remove], "AP_fnc_newWaypoint", _unit, false] spawn AP_fnc_MP;