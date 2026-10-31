private _isAthira = param[3, false];
private _object =
if (_isAthira) then[{AP_bank_lighthouse_2}, {AP_bank_lighthouse}];
private _lights = ["Cabin_illumination_hitpoint", "Light_1_hitpoint", "Light_2_hitpoint", "Light_3_hitpoint"];
private _doShutDown = ({(_object getHit _x) < 0.90}
count _lights) >= 1;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable["AP_progress", displayNull];
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
AP_action_in_use = true;
private _increment = 1;
private _totalTime = 12;
private _currentPoint = 0;
private _loopDelay = _totalTime / floor(100 / _increment);
private _text =
if (_doShutDown) then {"Shutting off lighthouse power";} else {"Activating lighthouse power";};
private _startCount = 0;
_progressBar progressSetPosition _startCount;
_progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
["AinvPknlMstpSnonWnonDnon_medic_1", 21] spawn AP_fnc_handleAnim;
private _isSuccess =
for "_i"
from 0 to 1 step 0 do {uiSleep _loopDelay;
    if (isNull _progressBar) exitWith {["The process has failed", "basic"] spawn AP_fnc_handleMessage;
        false;};
    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
    _progressBar progressSetPosition _currentPoint;
    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
    if (_currentPoint >= 1) exitWith {true};
    if !((vehicle player) isEqualTo player) exitWith {["The process has failed", "basic"] spawn AP_fnc_handleMessage;
        false;};
    if ((!AP_action_in_use) || (!alive player) || ((player distance AP_bank_generator) >= 6)) exitWith {
        ["The process has failed", "basic"] spawn AP_fnc_handleMessage;
        false;};
    false;};
[] spawn AP_fnc_handleAnim;
player switchMove "";
5 cutText["", "PLAIN"];
AP_action_in_use = false;
if (_isSuccess) then {[[_doShutDown, _object], "APS_fnc_bankLightHouseToggle", 2] spawn AP_fnc_MP;};