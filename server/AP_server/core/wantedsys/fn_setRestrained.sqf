 
private["_unit","_restrained","_uid","_index"]; 
 
_unit = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
_restrained = [_this,1,false,[false]] call BIS_fnc_param; 
if(isNull _unit) exitWith {[]}; if (_restrained) then { if (!isNil "AP_fnc_telemetryEvent") then { ["restrain"] call AP_fnc_telemetryEvent; }; };   // telemetry event counter 
 
_index = -1; 
private _rp = localNamespace getVariable "APS_restrainedPlayers";
_uid = getPlayerUID _unit; {if (_uid == _x) exitWith { _index = _forEachIndex };} forEach _rp;
 
if (_index < 0 && _restrained) then { _rp pushBack _uid }; 
if (_index > -1 && !_restrained) then { _rp deleteAt _index; };