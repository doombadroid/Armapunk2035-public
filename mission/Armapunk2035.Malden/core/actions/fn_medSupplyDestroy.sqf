params[["_supplyCrate", objNull, [objNull]]];
if (isNull _supplyCrate) exitWith {};
if !((typeOf _supplyCrate) isEqualTo "C_IDAP_supplyCrate_F" && _supplyCrate getVariable["AP_medSupply", false]) exitWith {};
if ((currentWeapon player) in ["", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F"]) exitWith {
    ["How do you expect to destroy this without a weapon?", "basic"] spawn AP_fnc_handleMessage;};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable["AP_progress", displayNull];
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
AP_action_in_use = true;
private _increment = 1;
private _totalTime = 30;
private _currentPoint = 0;
private _loopDelay = _totalTime / floor(100 / _increment);
private _text = "Destroying medical supplies";
private _startCount = 0;
_progressBar progressSetPosition _startCount;
_progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
private _duration = 20;
private _animation = "AinvPknlMstpSnonWnonDnon_medic_1";
[_animation, _duration] spawn AP_fnc_handleAnim;
private _isSuccess =
for "_i"
from 0 to 1 step 0 do {uiSleep _loopDelay;
    if (isNull _progressBar) exitWith {[2, "You have failed to destroy the supplies."] call AP_fnc_broadcast;
        false};
    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
    _progressBar progressSetPosition _currentPoint;
    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
    if (_currentPoint >= 1) exitWith {true};
    if ((speed player) >= 2) exitWith {[2, "You have failed to destroy the supplies."] call AP_fnc_broadcast;
        false};
    if !((vehicle player) isEqualTo player) exitWith {[2, "You have failed to destroy the supplies."] call AP_fnc_broadcast;
        false};
    if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {
        [2, "You have failed to destroy the supplies."] call AP_fnc_broadcast;
        false};
    if ((!AP_action_in_use) || (!alive player) || ((player distance _supplyCrate) >= 3)) exitWith {
        [2, "You have failed to destroy the supplies."] call AP_fnc_broadcast;
        false};
    false;}; AP_action_in_use = false;
[] spawn AP_fnc_handleAnim;
5 cutText["", "PLAIN"];
if (_isSuccess) then {deleteVehicle _supplyCrate;
    ["You have successfully destroyed the medical supplies.", "basic"] spawn AP_fnc_handleMessage; [
        [0, format["%1 has destroyed your medical supplies!", profileName]], "AP_fnc_broadcast", _supplyCrate getVariable["AP_owner", player], false, false] spawn AP_fnc_MP;
};