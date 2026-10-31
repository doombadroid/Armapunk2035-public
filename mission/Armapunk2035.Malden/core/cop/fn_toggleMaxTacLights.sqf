#include "..\..\macro.h"
if (scriptAvailable(2.5)) exitWith {["Slow it down buddy!"] spawn AP_fnc_handleMessage;};
params[["_veh", objNull, [objNull]]];
_veh = vehicle player;
if (isNull _veh) exitWith {};

if !((driver _veh) isEqualTo player) exitWith {["You must be the driver to toggle MaxTac Lights!"] spawn AP_fnc_handleMessage};
if (_veh isEqualTo player) exitWith {["You must be in a vehicle to toggle MaxTac Lights!"] spawn AP_fnc_handleMessage};
if ((typeOf _veh) == "Steerable_Parachute_F") exitWith {};
private _MAXTAClightState = _veh getVariable["AP_MAXTACLights", false];
if (_MAXTAClightState) then {_veh setVariable["AP_MAXTACLights", false, true];
    if (_veh getVariable "AP_lights") then {_veh setVariable["AP_lights", false, true];
        uiSleep 0.2;
        [_veh] call AP_fnc_sirenLights;};} else {_veh setVariable["AP_MAXTACLights", true, true];
    if (_veh getVariable "AP_lights") then {_veh setVariable["AP_lights", false, true];
        uiSleep 0.2;
        [_veh] call AP_fnc_sirenLights;} else {[_veh] call AP_fnc_sirenLights;}};