if ((player getVariable["AP_restrained", false]) || (player getVariable["AP_downed", false])) exitWith {};
if ((!alive player) || ((player distance(getMarkerPos "respawn_civilian"))) <= 500) exitWith {};
params[["_target", player], ["_caller", player], ["_actionID", 0], ["_unit", objNull, [objNull]]];
private _unit =
if (isNull _unit) then {cursorTarget} else {_unit};
if ((isNull _unit) || (!isPlayer _unit) || (!alive _unit)) exitWith {};
private _useAdrenaline =
switch (true) do {case (AP_copRole in ["all", "medic"] && 21 in AP_cop_talents && (call AP_copLevel >= 4)): {false};
    case (AP_copRole in ["all", "scd"] && {32 in AP_cop_talents}): {(random 10) < 7.5};
    case (116 in AP_side_talents && call(AP_medicLevel) >= 4 && floor(random 3) isEqualTo 0): {false};
    case (804 in AP_completedLifetimeQuests && AP_effSide isEqualTo independent): {(random 10) < 5};
    case (456 in AP_completedLifetimeQuests && AP_effSide isEqualTo civilian): {(random 10) <= 2};
    default {true};}; if (_useAdrenaline && {!([false, "adrenalineShot", 1] call AP_fnc_handleInv)}) exitWith {
    ["You don't have a adrenaline shot to give!", "basic"] spawn AP_fnc_handleMessage;};
AP_action_in_use = true;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNamespace getVariable["AP_progress", displayNull];
if (isNull _display) exitWith {};
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
private _unitText =
if (_unit isEqualTo player) then {"yourself"} else {name _unit};
private _text = format["Injecting %1 with adrenaline", _unitText];
_progressText ctrlSetText format["%2 (0%1)...", "%", _text];
_progressBar progressSetPosition 0.00;
private _counter = progressPosition _progressBar;
private _animationState = animationState player;
if (_unit isEqualTo player) then {player playActionNow "Medic"} else {player playActionNow "MedicOther"};
private _isSuccess =
for "_i"
from 0 to 1 step 0 do {uiSleep 0.20;
    _counter = _counter + 0.10;
    _progressBar progressSetPosition _counter;
    _progressText ctrlSetText format["%3 (%1%2)...", round(_counter * 100), "%", _text];
    if (_counter >= 1) exitWith {true};
    if (!AP_action_in_use) exitWith {false};
    if (isWeaponDeployed player) exitWith {false};
    if (player getVariable["AP_restrained", false]) exitWith {false};
    if (player getVariable["AP_downed", false]) exitWith {false};
    if (!alive player) exitWith {false};
    false;}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
player switchMove "stop";
if !(_isSuccess) exitWith {["Adrenaline shot failed.", "basic"] spawn AP_fnc_handleMessage;
    if (_useAdrenaline) then {[true, "adrenalineShot", 1] call AP_fnc_handleInv;};};
if (_unit isEqualTo player) then {[] call AP_fnc_adrenalineShotEffect} else {[
        [player], "AP_fnc_adrenalineShotEffect", _unit, false, false] spawn AP_fnc_MP;};
AP_side_exp = AP_side_exp + 15;
// owner 2026-06-13 (#158): TT medics earn prestige for adrenaline-shotting ("narcan") ANOTHER player awake
// -- this path only gave side_exp, so medics got no TT prestige from it (revive/medkit/bloodbag already do).
if (_unit isNotEqualTo player) then { 25 call AP_fnc_medicEarn; };   // medicEarn is independent-gated internally
["adrenaline", 1] call AP_fnc_statArrUpdate;
["action", "adrenaline", 1] spawn AP_fnc_handleQuest;
player switchMove "stop";