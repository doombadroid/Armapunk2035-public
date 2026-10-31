/*
    AP_fnc_mapLightAttach -- a scripted, tunable light on a placed fixture (the plaza floodlights).

    The fixture itself stays a simple object (no reflector); the light is a local #lightpoint sat at
    the fixture's head and attached to it. Every parameter comes from ONE global so it can be dialled
    in-game without a repack:

        AP_floodLight = [brightness, colour, attenuation, daylight]
                        default [0.35, [1, 0.95, 0.85], [2, 0, 0.5, 1.5], true]

        [0.2] call AP_fnc_floodTune;      re-applies a new brightness to every live light

    Registry AP_mapLights = [[fixture, light], ...]; a 10 s sweep deletes a light whose fixture is
    gone (zone unload, editor delete) so no orphan light is ever left glowing in the world.
*/
params [["_obj", objNull, [objNull]]];
if (isNull _obj || {!hasInterface}) exitWith {};
if (!isNull (_obj getVariable ["AP_mapLight", objNull])) exitWith {};

(missionNamespace getVariable ["AP_floodLight", [0.35, [1, 0.95, 0.85], [2, 0, 0.5, 1.5], true]])
    params [["_bri", 0.35, [0]], ["_col", [1, 0.95, 0.85], [[]]], ["_att", [2, 0, 0.5, 1.5], [[]]], ["_day", true, [true]]];

private _top = (((boundingBoxReal _obj) select 1) select 2) max 0.4;
private _l = createVehicleLocal ["#lightpoint", getPosATL _obj];
_l setLightBrightness _bri;
_l setLightColor _col;
_l setLightAmbient [0, 0, 0];
_l setLightAttenuation _att;
_l setLightUseFlare false;
_l setLightDayLight _day;
_l attachTo [_obj, [0, 0, _top]];
_obj setVariable ["AP_mapLight", _l];

if (isNil "AP_mapLights") then {
    AP_mapLights = [];
    // one sweep for all lights: a fixture deleted under its light leaves the light behind otherwise
    [] spawn {
        while {true} do {
            uiSleep 10;
            AP_mapLights = AP_mapLights select {
                _x params ["_o", "_li"];
                if (isNull _o || {!alive _o}) then { if (!isNull _li) then { deleteVehicle _li; }; false } else { !isNull _li }
            };
        };
    };
};
AP_mapLights pushBack [_obj, _l];
