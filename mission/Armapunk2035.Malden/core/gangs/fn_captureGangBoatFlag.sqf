params[["_flag", objNull, [objNull]]];
_flag getVariable["AP_boatflag_data", ["", -1, "Uncontrolled"]] params[["_captureTarget", "", [""]], ["_gangID", -1, [0]], ["_gangName", "Uncontrolled", [""]]];
if !(SRV_gangBoatFortressData select 0) exitWith {};
if ((currentWeapon player) in ["", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F"]) exitWith {
    ["You can't take a flag without a weapon.", "basic"] spawn AP_fnc_handleMessage;};
if (_gangID isEqualTo(AP_gang_data select 0)) exitWith {["Your gang already owns this flag.", "basic"] spawn AP_fnc_handleMessage;};
AP_action_in_use = true;
private _text = "Capturing a Gang Boat Flag...";
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNameSpace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.3;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (player distance _flag > 6 || AP_isDowned || player getVariable["AP_restrained", false] || !alive player) exitWith {
        ["You failed to capture the boat flag.", "basic"] spawn AP_fnc_handleMessage;};
    if !(SRV_gangBoatFortressData select 0) exitWith {["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    if !(AP_action_in_use) exitWith {["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    if !(isNull objectParent player) exitWith {["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    if (_cP >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {};
["You have claimed this boat flag for your gang. If your gang ends up having the most of the points you win the boat!", "basic"] spawn AP_fnc_handleMessage;
_flag setVariable["AP_boatflag_data", [_captureTarget, AP_gang_data select 0, AP_gang_data select 1], true];