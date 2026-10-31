params[["_veh", objNull, [objNull]]];
if (isNull _veh || AP_action_in_use) exitWith {};
if !(_veh isKindOf "Car" || _veh isKindOf "Ship" || _veh isKindOf "Air") exitWith {};
AP_action_in_use = true;
private _success = false;
private _startPos = getPosATL player;   // anchor on the player, not the vehicle (a damaged veh rolls/settles)
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _displayName = getText(configFile >> "CfgVehicles" >> (typeOf _veh) >> "displayName");
private _text = format["Repairing %1", _displayName];
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _delay = 0.27;
if (!("ToolKit" in (items player)) && !(87 in AP_side_talents) && !(111 in AP_side_talents)) then {_delay = _delay * 3.75;};
if (67 in AP_side_talents || 88 in AP_side_talents || 111 in AP_side_talents) then {_delay = _delay - 0.1};
["Acts_carFixingWheel", 100 * _delay] spawn AP_fnc_handleAnim;
for "_i"
from 0 to 1 step 0 do {uiSleep _delay;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if !(alive player) exitWith {};
    if (player getVariable ["AP_surrendered", false]) exitWith {};   // #361: hands-up (TAB) cancels the repair so you can comply
    if !(isNull objectParent player) exitWith {};
    if ((player distance2D _startPos) > 5) exitWith {};   // cancel only if the PLAYER walks off, not if the veh drifts
    if !(AP_action_in_use) exitWith {};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
[] spawn AP_fnc_handleAnim;
if !(_success) exitWith {["Your repair has been interrupted and failed.", "basic"] spawn AP_fnc_handleMessage;
    // #361: don't override the hands-up pose with the get-up recovery anim when the interrupt WAS the surrender
    if !(player getVariable ["AP_surrendered", false]) then { ["AinvPknlMstpSnonWnonDnon_medic_1", 0, "switchMove"] spawn AP_fnc_handleAnim; };
};
private _consume = true;
if (68 in AP_side_talents) then {private _rand = floor(random 4);
    if (_rand isEqualTo 0) then {_consume = false;};};
if (_consume && !(AP_effSide isEqualTo west)) then {player removeItem "ToolKit";
    titleText["You have repaired the vehicle.", "PLAIN"];} else {
    titleText["You have repaired the vehicle without even scratching your tools.", "PLAIN"];};
if !(_veh isKindOf "Car" || _veh isKindOf "Ship" || _veh isKindOf "Air") exitWith {};
private _plb_dmg = _veh;
_plb_dmg setDamage 0;
AP_side_exp = AP_side_exp + 5;