 
_unit = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
_add = [_this,1,true,[true]] call BIS_fnc_param; 
 
if (isNull _unit) exitWith {}; 
 
if (_add) then {if (!(_unit in AP_event_queue)) then {AP_event_queue pushBack _unit;};}
else {AP_event_queue = AP_event_queue - [_unit];};