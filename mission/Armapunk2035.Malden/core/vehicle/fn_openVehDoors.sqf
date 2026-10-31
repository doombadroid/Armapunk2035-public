/*
    AP_fnc_openVehDoors  (LooneyBin, owner 2026-06-11)
    Toggle ALL doors/ramps open<->closed on a vehicle that has them (Ifrit, Hunter, trucks, transport helis).
    Keychain "Open All Doors" button. animateDoor/animateSource are local-argument / global-effect -> this
    MUST run where the vehicle is LOCAL, so the caller invokes it via AP_fnc_MP with the vehicle as target.

    Verified source naming (BI config + community):
      * Cars/MRAP doors  -> "Door_LF/RF/LB/RB", "Door_1..", controller source="door"  -> animateDoor
      * Heli doors       -> "Door_L/R", "Door_Back_L/R",      controller source="door"  -> animateDoor
      * Heli cargo ramps -> "CargoRamp_Open", "Ramp_*",        controller source="user"  -> animateSource
    So: enumerate AnimationSources whose name contains door/ramp, and drive each with the command that
    matches its `source` controller (animateDoor for "door", animateSource otherwise). 1 = open, 0 = closed.
    NOTE (BI engine limit): ARMED MRAP variants (Ifrit MG / Hunter HMG) can't have doors scripted -> no-op.
*/
params [["_veh", objNull, [objNull]]];
if (isNull _veh || {!alive _veh}) exitWith {};
private _src = configFile >> "CfgVehicles" >> (typeOf _veh) >> "AnimationSources";
private _doorClasses = ("isClass _x" configClasses _src) select {private _n = toLower (configName _x);
    (_n find "door" >= 0) || {_n find "ramp" >= 0}};
if (_doorClasses isEqualTo []) exitWith {};
private _anyOpen = (_doorClasses findIf { (_veh animationSourcePhase (configName _x)) > 0.5 }) > -1;
private _target = [1, 0] select _anyOpen;   // open all, or close all if any were already open
{private _name = configName _x;
    if ((toLower (getText (_x >> "source"))) isEqualTo "door") then {
        _veh animateDoor [_name, _target];      // proper door controller (slam behaviour, sound)
    } else {_veh animateSource [_name, _target];    // ramps/hatches etc. on a "user" controller
    };} forEach _doorClasses;
