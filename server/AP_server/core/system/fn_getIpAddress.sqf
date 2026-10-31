 
private ["_uid","_ip","_i"]; 
 
_uid = [_this,0,"",[""]] call BIS_fnc_param; 
_ip = ""; 
 
for [{_i=0}, {_i<5}, {_i=_i+1}] do {if (_i > 0) then { sleep 0.5; };
_ip = "0.0.0.0"; // TODO[extDB3 migration]: player IP not available without an extension 
if (_ip != "") exitWith {};};
 
_ip;