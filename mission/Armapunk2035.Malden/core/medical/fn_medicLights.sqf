params[["_vehicle", objNull, [objNull]], ["_lightTime", 0.22, [0]]];
if (isNil "_vehicle" || {isNull _vehicle || {!(_vehicle getVariable "AP_lights")}}) exitWith {};
// AL-6 Pelican revive drone: one strobe per rotor (4 lights), red/white diagonal pairs. Quadcopter has no left/right pair like the ground/heli cases.
if ((typeOf _vehicle) in ["I_UAV_06_medical_F", "C_IDAP_UAV_06_medical_F"]) exitWith {private _red   = [25, 0.1, 0.1];
    private _white = [25, 25, 25];
    private _offs  = [[-0.55, 0.55, 0.15], [0.55, 0.55, 0.15], [-0.55, -0.55, 0.15], [0.55, -0.55, 0.15]];   // FL FR RL RR rotor arms (pulled ~1.3 ft inward)
    private _lights = []; {private _l = "#lightpoint" createVehicleLocal (getPos _vehicle);
        _l setLightColor (if (_forEachIndex in [0, 3]) then { _red } else { _white });   // diagonal pairs alternate colour
        _l setLightBrightness 0.2;
        _l setLightAmbient [0.1, 0.1, 1];
        _l lightAttachObject [_vehicle, _x];
        _l setLightAttenuation [0.14, 0, 1000, 20];
        _l setLightIntensity 2;
        _l setLightFlareSize 0.25;
        _l setLightFlareMaxDistance 200;
        _l setLightUseFlare true;
        _l setLightDayLight true;
        _lights pushBack _l;} forEach _offs;
    _lights params ["_fl", "_fr", "_rl", "_rr"];
    private _phase = true;
    // exits when AP_lights toggled off OR the drone is gone (disassembled -> deleted -> isNull / typeOf "") so the lights never orphan on the ground
    while { !isNull _vehicle && {alive _vehicle} && {!((typeOf _vehicle) isEqualTo "")} && {_vehicle getVariable ["AP_lights", false]} } do {
        private _b = switch (true) do {case (dayTime > 6 && dayTime <= 17.5): { 35 };
            case (dayTime >= 5.25 && dayTime <= 6): { 5 };
            case (dayTime > 17.5 && dayTime <= 18.5): { 10 };
            default { 2.5 };};
        if (_phase) then {_fl setLightBrightness _b; _rr setLightBrightness _b;
            _fr setLightBrightness 0;  _rl setLightBrightness 0;} else {_fl setLightBrightness 0;  _rr setLightBrightness 0;
            _fr setLightBrightness _b; _rl setLightBrightness _b;};
        _phase = !_phase;
        uiSleep _lightTime;};
    { deleteVehicle _x } forEach _lights;};
private _lightRed = [25, 0.1, 0.1];
private _lightWhite = [25, 25, 25];
private _lightPositions =
switch (true) do {case ("Quadbike" in (typeOf _vehicle)): {[[-0.37, 0.9, -0.6], [0.37, 0.9, -0.6]];};
    case ("Offroad_01" in (typeOf _vehicle)): {[[-0.37, 0.0, 0.56], [0.37, 0.0, 0.56]];};
    case ("Offroad_02" in (typeOf _vehicle)): {[[-0.37, -0.6, 0.4], [0.37, -0.6, 0.4]];};
    case ("MRAP_01" in (typeOf _vehicle)): {[[-0.37, -1.9, 0.7], [0.37, -1.9, 0.7]];};
    case ("MRAP_03" in (typeOf _vehicle)): {[[-0.6, 0.5, 0.45], [0.6, 0.5, 0.45]];};
    case ("SUV_01" in (typeOf _vehicle)): {[[-0.37, -1.2, 0.42], [0.37, -1.2, 0.42]];};
    case ("Hatchback" in (typeOf _vehicle)): {[[-0.35, -0.2, 0.25], [0.35, -0.2, 0.25]];};
    case ("Van_02" in (typeOf _vehicle)): {[[-0.4, 1, 1.1], [0.4, 1, 1.1]];};
    case ("LSV_01" in (typeOf _vehicle)): {[[-0.4, 0.5, -0.15], [0.4, 0.5, -0.15]];};
    case ("Heli_Light_01" in (typeOf _vehicle)): {[[-0.37, 0.0, -0.80], [0.37, 0.0, -0.80]];};
    case ("Heli_Transport_01" in (typeOf _vehicle)): {[[-0.5, 0.0, 0.81], [0.5, 0.0, 0.81]];};
    case ("Heli_Light_02" in (typeOf _vehicle)): {[[-0.8, 3, -1.5], [0.8, 3, -1.5]];};
    case ("Heli_light_03" in (typeOf _vehicle)): {[[-0.8, 3, -1.2], [0.8, 3, -1.2]];};
    case ("O_Truck_03" in (typeOf _vehicle)): {[[-0.4, 1.5, 1.1], [0.4, 1.5, 1.1]];};
    case ("O_Heli_Transport_04" in (typeOf _vehicle)): {[[-0.4, 1.5, 1.1], [0.4, 1.5, 1.1]];};
    default {[[-1], [-1]];};}; _lightPositions params["_leftOffset", "_rightOffset"];
if (_leftOffset isEqualTo[-1]) exitWith {diag_log format["Vehicle emergency lights not set for: %1", _vehicle];};
private _lightLeft = "#lightpoint"
createVehicleLocal getPos _vehicle;
uiSleep 0.2;
_lightLeft setLightColor _lightRed;
_lightLeft setLightBrightness 0.2;
_lightLeft setLightAmbient[0.1, 0.1, 1];
_lightLeft lightAttachObject[_vehicle, _leftOffset];
_lightLeft setLightAttenuation[0.14, 0, 1000, 20];
_lightLeft setLightIntensity 2;
_lightLeft setLightFlareSize 0.3;
_lightLeft setLightFlareMaxDistance 200;
_lightLeft setLightUseFlare true;
private _lightRight = "#lightpoint"
createVehicleLocal getPos _vehicle;
uiSleep 0.2;
_lightRight setLightColor _lightWhite;
_lightRight setLightBrightness 0.2;
_lightRight setLightAmbient[0.1, 0.1, 1];
_lightRight lightAttachObject[_vehicle, _rightOffset];
_lightRight setLightAttenuation[0.14, 0, 1000, 20];
_lightRight setLightIntensity 2;
_lightRight setLightFlareSize 0.3;
_lightRight setLightFlareMaxDistance 200;
_lightRight setLightUseFlare true;
_lightLeft setLightDayLight true;
_lightRight setLightDayLight true;
private _brightness = 0;
private _leftRed = true;
while {alive _vehicle}
do {if !(_vehicle getVariable "AP_lights") exitWith {};
    _brightness =
    switch (true) do {case (dayTime > 6 && dayTime <= 17.5): {35};
        case (dayTime >= 5.25 && dayTime <= 6): {5};
        case (dayTime > 17.5 && dayTime <= 18.5): {10};
        default {2.5};}; if (_leftRed) then {_lightRight setLightBrightness 0.0;
        _lightLeft setLightBrightness _brightness;} else {_lightLeft setLightBrightness 0.0;
        _lightRight setLightBrightness _brightness;};
    _leftRed = !_leftRed;
    uiSleep _lightTime;}; deleteVehicle _lightLeft;
deleteVehicle _lightRight;