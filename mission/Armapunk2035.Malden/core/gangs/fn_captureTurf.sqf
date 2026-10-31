if (AP_gang_data isEqualTo[]) exitWith {};
params[["_flag", objNull, [objNull]]];
_flag getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] params[["_gangID", -1, [0]], ["_gangName", "Unknown", [""]], ["_active", false, [false]], ["_playerCapturer", "Unknown", [""]]];
if !(_active) exitWith {};
if ((currentWeapon player) in ["", "Binocular", "Rangefinder", "hgun_Pistol_Signal_F"]) exitWith {
    ["You can't take a turf without a weapon.", "basic"] spawn AP_fnc_handleMessage;};
if (_gangID isEqualTo(AP_gang_data select 0)) exitWith {
    ["Your gang is already in line to control this turf.", "basic"] spawn AP_fnc_handleMessage;};
private _turfCount = 0; {
    _x getVariable["AP_turf_data", [-1, "Unknown", false, "Unknown"]] params[["_gangID", -1, [0]], ["_gangName", "Unknown", [""]], ["_active", false, [false]], ["_playerCapturer", "Unknown", [""]]];
    if (_gangID isEqualTo(AP_gang_data select 0)) then {_turfCount = _turfCount + 1};}
forEach[rodo_flag, zaros_flag, panagia_flag];
if (_turfCount >= 2) exitWith {["A gang cannot control more than two turfs at a time.", "basic"] spawn AP_fnc_handleMessage;};
private _friendlyInArea = allPlayers select {
    player distance _x < 750 && (_x getVariable["gang_data", [-1]] select 0) isEqualTo(AP_gang_data select 0)};
if (count _friendlyInArea > 5) exitWith {
    ["Turfs cannot be captured by a gang with more than 5 players nearby.", "basic"] spawn AP_fnc_handleMessage;};
["Capturing turf. No more than 5 gang members can be inside this turf during the contested time", "basic"] spawn AP_fnc_handleMessage;
AP_action_in_use = true;
private _text = "Capturing Turf...";
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNameSpace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
private _pos = getPos player;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.6;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (player distance _pos > 4 || AP_isDowned || player getVariable["AP_restrained", false] || !alive player || speed player > 2) exitWith {
        ["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    private _active = _flag getVariable["AP_turf_data", []] select 2;
    if !(_active) exitWith {["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    private _friendlyInArea = allPlayers select {
        player distance _x < 750 && (_x getVariable["gang_data", [-1]] select 0) isEqualTo(AP_gang_data select 0)};
    if (count _friendlyInArea > 5) exitWith {
        ["Turfs cannot be captured by a gang with more than 5 players nearby.", "basic"] spawn AP_fnc_handleMessage;};
    if !(AP_action_in_use) exitWith {["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    if !(isNull objectParent player) exitWith {["You failed to capture the turf.", "basic"] spawn AP_fnc_handleMessage;};
    if (_cP >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];
AP_action_in_use = false;
if !(_success) exitWith {};
["action", "capturf", 1] spawn AP_fnc_handleQuest;
["You have claimed this turf for your gang. If you're the last to do this when the capture time expires, it's yours!", "basic"] spawn AP_fnc_handleMessage;
_flag setVariable["AP_turf_data", [AP_gang_data select 0, AP_gang_data select 1, true, profileName], true];
// LooneyBin 2026-06-11: the server turf-window finalizer (init.sqf) assigns ownership from AP_turf_captor
// = [capturerName, gangName, gangID], but NOTHING ever wrote it (deobf casualty) -> captures never persisted
// to the gang (e.g. Panagia held but never transferred). Record the captor server-side; last capturer before
// the window expires wins, matching "if you're the last to do this when the capture time expires, it's yours".
AP_turf_captor = [profileName, AP_gang_data select 1, AP_gang_data select 0];
publicVariable "AP_turf_captor";