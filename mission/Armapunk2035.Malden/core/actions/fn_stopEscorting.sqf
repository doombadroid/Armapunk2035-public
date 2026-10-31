private _escortee = AP_escort;
if (isNull _escortee) exitWith {};
if !(_escortee getVariable["AP_escorting", false]) exitWith {};
_escortee setVariable["AP_escorting", nil, true];
player setVariable["AP_escortObj", nil];
detach _escortee;
AP_escort = objNull;