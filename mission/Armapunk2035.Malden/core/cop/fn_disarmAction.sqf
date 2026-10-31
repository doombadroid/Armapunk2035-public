params[["_unit", objNull, [objNull]]];
if (isNull _unit || alive _unit || _unit getVariable["AP_disarmed", false] || !(_unit isKindOf "CAManBase")) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {
    ["Hands in the air like you just don't care?", "basic"] spawn AP_fnc_handleMessage;};
private _nearVehicles = (nearestObjects[_unit, ["Car", "Air", "Ship"], 30]) select {_x getVariable["AP_side", ""] isEqualTo "cop"};
private _vehicle = _nearVehicles param[_nearVehicles findIf {!isNull _x}, objNull];
private _nearStation = ({(position player) inPolygon(AP_police_hq_polys select _x)}
count[0, 1, 2, 3, 4, 5, 6] > 0);
if (isNull _vehicle && !(_nearStation)) exitWith {
    ["There aren't any nearby Police vehicles to seize this player's gear into!", "basic"] spawn AP_fnc_handleMessage;};
if (!alive _vehicle && !(_nearStation)) exitWith {
    ["You cannot store items in a vehicle which has been destroyed!", "basic"] spawn AP_fnc_handleMessage;};
private _targetName = _unit getVariable["AP_name", "Unknown"];
player playMoveNow "AinvPknlMstpSnonWnonDnon_medic1";
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
private _text = format["Disarming %1.", _targetName];
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
AP_action_in_use = true;
private _success = false;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.038;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (isNull _unit) exitWith {};
    if (alive _unit) exitWith {};
    if (player distance _unit > 3) exitWith {};
    if !(AP_action_in_use) exitWith {};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
player playActionNow "stop";
if !(_success) exitWith {};
[format["You removed all weapons from %1!", _targetName], "basic"] spawn AP_fnc_handleMessage;
private _vehicle =
if (_nearStation) then {"HQ"} else {_vehicle};
["action", "disarm", 1] call AP_fnc_handleQuest; [["disarm", _unit, [_vehicle]], "APS_fnc_victimSRV", 2, false, false] spawn AP_fnc_MP;