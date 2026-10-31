 
private ["_uid","_guid","_i"]; 
 
_uid = [_this,0,"",[""]] call BIS_fnc_param; 
_guid = ""; 
 
for [{_i=0}, {_i<5}, {_i=_i+1}] do {if (_i > 0) then { sleep 0.5; };
_guid = _uid; // TODO[extDB3 migration]: real BattlEye GUID needs a3 extension or SQF impl; UID placeholder 
if (_guid != "") exitWith {};};
 
_guid;