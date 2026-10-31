 
private["_unit","_index"]; 
_unit = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
if(isNull _unit) exitWith {[]}; 
private _wl = localNamespace getVariable ["APS_wantedList", []];
_index = [getPlayerUID _unit,_wl] call AP_fnc_index; 
if(_index != -1) then{_wl select _index;} else {[];};
