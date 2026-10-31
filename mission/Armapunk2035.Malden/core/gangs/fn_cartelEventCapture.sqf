params[["_flag", objNull, [objNull]]];
if (AP_gang_data isEqualTo[]) exitWith {};
if (isNil "SRV_cartelEvent") exitWith {};
if (isNull _flag) exitWith {};
if !(SRV_cartelEvent select 0) exitWith {["The capture point cannot be capped yet!", "basic"] spawn AP_fnc_handleMessage;};
if (AP_cartelEventCapturingFlag) exitWith {};
(_flag getVariable["AP_cartelevent_data", [-1, "Unknown"]]) params[["_gangID", -1, [0]], ["_gangName", "Unknown", [""]]];
AP_gang_data params[["_playerGangID", 0, [0]], ["_playerGangName", "Unknown", [""]]];
if (_gangID isEqualTo _playerGangID) exitWith {
    ["Your gang is already in control of the capture point.", "basic"] spawn AP_fnc_handleMessage;};
if ((currentWeapon player) in ["", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F"]) exitWith {
    ["You can't take this capture point without a weapon.", "basic"] spawn AP_fnc_handleMessage;};
AP_cartelEventCapturingFlag = true;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable["AP_progress", displayNull];
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
private _increment = 1;
private _totalTime = 7;
private _currentPoint = 0;
private _loopDelay = _totalTime / floor(100 / _increment);
private _defaultFlagName = "Capture Point";
private _text = format["Capturing %1", _defaultFlagName];
private _startCount = 0;
_progressBar progressSetPosition _startCount;
_progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
private _isSuccess =
for "_i"
from 0 to 1 step 0 do {uiSleep _loopDelay;
    if (isNull _progressBar) exitWith {["You have failed to cap!", "basic"] spawn AP_fnc_handleMessage;
        false};
    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
    _progressBar progressSetPosition _currentPoint;
    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
    private _pos = getPosATL _flag;
    if (isNil "SRV_cartelEvent") exitWith {false};
    if (player distance _pos > 12 || AP_isDowned || player getVariable["AP_restrained", false] || !alive player) exitWith {false};
    if !(isNull objectParent player) exitWith {false};
    if (_currentPoint >= 1) exitWith {true};
    false;}; AP_cartelEventCapturingFlag = false;
5 cutText["", "PLAIN"];
if !(_isSuccess) exitWith {};
// owner 2026-06-14 (#176): civ-only. The "captured by" broadcast below went to EVERY player inside the
// warzone/drug-pen polygon with no side check, so any MaxSec officer standing in the area got cartel-cap
// notifications meant for gangs/civs. Exclude west (and independent) so only civilians are notified.
private _warzonePlayers = allPlayers select {
    (side _x isEqualTo civilian) && {((getPosATL _x) inPolygon AP_warzonePoly) || ((getPosATL _x) inPolygon AP_drugPenPoly)}};
private _allGangMembers = _warzonePlayers select {(_x getVariable["gang_data", [-1]] select 0) isEqualTo(AP_gang_data select 0)};
_flag setVariable["AP_cartelevent_data", [_playerGangID, _playerGangName, group player], true];
"CartelEvent1"
setMarkerText format["%1 - %2", _defaultFlagName, _playerGangName]; [
    [5, format["%1 has been captured by %2!", _defaultFlagName, _playerGangName]], "AP_fnc_broadcast", _warzonePlayers] spawn AP_fnc_MP;
[
    [format["%1 has captured %2 for your gang. Your gang will be given 1 point every 20 seconds if this flag is under your control.", name player, _defaultFlagName], "shortwarning"], "AP_fnc_handleMessage", _allGangMembers] spawn AP_fnc_MP;