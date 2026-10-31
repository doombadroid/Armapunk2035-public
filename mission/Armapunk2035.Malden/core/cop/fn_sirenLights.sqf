params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {};
if ((typeOf _vehicle) == "Steerable_Parachute_F") exitWith {};
private _lightState = _vehicle getVariable["AP_lights", false];
if (_lightState) then {_vehicle setVariable["AP_lights", false, true];} else {_vehicle setVariable["AP_lights", true, true]; [
        [_vehicle, 0.22], "AP_fnc_copLights", -2, false, false] call AP_fnc_MP;};
// SKIN SWAP (owner 2026-09-06): a vehicle carrying AP_htmlSkinAlert [base, alert, glow] (set by
// fn_colorVehicle for the MaxSec Hatchback) switches to its LIVE alert page while the lights run --
// a red STAY BACK ticker -- and back to the static base when they stop. _lightState is the state
// BEFORE this toggle. The driver's machine owns the vehicle, so the broadcast is one and JIP-safe.
private _alt = _vehicle getVariable ["AP_htmlSkinAlert", []];
if (_alt isNotEqualTo []) then {
    _alt params [["_base", "", [""]], ["_alert", "", [""]], ["_glow", 0, [0]], ["_glowOn", -1, [0]]];
    if (_glowOn < 0) then { _glowOn = _glow; };   // 3-element pair from before the split: same glow both ways
    if (_lightState) then { [_vehicle, _base, false, 0, _glow] call AP_fnc_htmlSkin; }
    else { [_vehicle, _alert, true, 2048, _glowOn] call AP_fnc_htmlSkin; };
};
