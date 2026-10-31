params[["_vehicle", objNull, [objNull]], ["_lightTime", 0.22, [0]]];
if (isNil "_vehicle" || {isNull _vehicle || {!(_vehicle getVariable "AP_lights")}}) exitWith {};
private _lightRed = [20, 0.1, 0.1];
private _lightBlue = [0.1, 0.1, 20];
private _undefined = false;
private _maxtacLights = _vehicle getVariable["AP_MAXTACLights", false];
private _lightPositions =
switch (true) do {case ("Quadbike" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, 0.9, -0.6], [0.37, 0.9, -0.6]];} else {[
                    [-0.37, 0.9, -0.6], [0.37, 0.9, -0.6], [0.07, 1, -0.7], [-0.07, 1, -0.7]];}};
    case ("Offroad_01" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, 0.0, 0.56], [0.37, 0.0, 0.56]];} else {[[-0.37, 0.0, 0.56],
                    [0.37, 0.0, 0.56], [0.3, 2.4, -0.44], [-0.3, 2.4, -0.44], [-0.85, -2.9, -0.38], [0.85, -2.9, -0.38], [0.2, 2.5, -0.7],
                    [-0.2, 2.5, -0.7]];}};
    case ("Offroad_02" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, -0.6, 0.4], [0.37, -0.6, 0.4]];} else {[[-0.37, -0.6, 0.4],
                    [0.37, -0.6, 0.4], [0.5, 1.25, -0.16], [-0.5, 1.25, -0.16]];}};
    case ("MRAP_01" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, -1.9, 0.7], [0.37, -1.9, 0.7]];} else {[[-0.37, -1.9, 0.7],
                    [0.37, -1.9, 0.7], [-0.95, -4.25, -0.75], [0.95, -4.25, -0.75], [-0.8, -0.6, -1.3], [0.8, -0.6, -1.3],
                    [0.4, -1.2, 0.55], [-0.4, -1.2, 0.55]];}};
    case ("MRAP_03" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.6, 0.5, 0.45], [0.6, 0.5, 0.45]];} else {[[-0.6, 0.5, 0.45],
                    [0.6, 0.5, 0.45], [-0.75, -3.2, 0.03], [0.75, -3.2, 0.03], [0.8, -2.7, -0.9], [-0.8, -2.7, -0.9], [0.87, 2.2, -0.75],
                    [-0.87, 2.2, -0.75]];}};
    case ("MRAP_02" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, -2.1, 0.45], [0.37, -2.1, 0.45]];} else {[[-0.37, -2.1, 0.45],
                    [0.37, -2.1, 0.45], [-0.95, -4.25, -0.75], [0.95, -4.25, -0.75], [-0.8, -0.6, -1.3], [0.8, -0.6, -1.3],
                    [0.4, -1.2, 0.55], [-0.4, -1.2, 0.55]];}};
    case ("SUV_01" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, -1.2, 0.42], [0.37, -1.2, 0.42]];} else {[[-0.37, -1.2, 0.42],
                    [0.37, -1.2, 0.42], [-0.55, .78, -0.12], [0.55, .78, -0.12], [0.45, 2.15, -1], [-0.45, 2.15, -1], [0.4, -1.8, 0.25],
                    [-0.4, -1.8, 0.25]];}};
    case ("Hatchback" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.35, -0.2, 0.25], [0.35, -0.2, 0.25]];} else {[
                    [-0.35, -0.2, 0.25], [0.35, -0.2, 0.25], [0.45, 0.9, -0.2], [-0.45, 0.9, -0.2], [-0.8, -2.3, -0.3], [0.8, -2.3, -0.3],
                    [0.5, -2.3, -1], [-0.5, -2.3, -1]];}};
    case ("Van_02" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.4, 1, 1.1], [0.4, 1, 1.1]];} else {[[-0.4, 1, 1.1], [0.4, 1, 1.1],
                    [-1.065, -0.725, -1.165], [1.065, -0.725, -1.165], [0.9, -3, 1.0], [-0.9, -3, 1.0], [-1, -3.2, -0.3], [1, -3.2, -0.3]];
            }};
    case ("LSV_01" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.4, 0.5, -0.15], [0.4, 0.5, -0.15]];} else {[[-0.4, 0.5, -0.15],
                    [0.4, 0.5, -0.15], [0.975, 0.49, -1.5], [-0.975, 0.49, -1.5], [-1.005, -1.025, -0.815], [1.005, -1.025, -0.815],
                    [-0.91, -0.4, -1.5], [0.91, -0.4, -1.5]];}};
    case ("LSV_02" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.4, 0.5, -0.15], [0.4, 0.5, -0.15]];} else {[[-0.4, 0.5, -0.15],
                    [0.4, 0.5, -0.15], [0.975, 0.49, -1.5], [-0.975, 0.49, -1.5], [-1.005, -1.025, -0.815], [1.005, -1.025, -0.815],
                    [-0.91, -0.4, -1.5], [0.91, -0.4, -1.5]];}};
    case ("Heli_Light_01" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.37, 0.0, -0.80], [0.37, 0.0, -0.80]];} else {[
                    [-0.37, 0.0, -0.80], [0.37, 0.0, -0.80], [0.14, -4.55, 1.25], [-0.14, -4.55, 1.25], [-0.8, -0.2, -1], [0.8, -0.2, -1],
                    [0.3, 1.82, -0.6], [-0.3, 1.82, -0.6]];}};
    case ("Heli_Transport_01" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.5, 0.0, 0.81], [0.5, 0.0, 0.81]];} else {[
                    [-0.5, 0.0, 0.81], [0.5, 0.0, 0.81], [0.04, -7.1, 0.7], [-0.04, -7.1, 0.7], [-0.25, -6, -0.85], [0.25, -6, -0.85],
                    [1.2, 2.9, -1.56], [-1.2, 2.9, -1.56]];}};
    case ("Heli_Light_02" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.8, 3, -1.5], [0.8, 3, -1.5]];} else {[[-0.8, 3, -1.5],
                    [0.8, 3, -1.5], [1.35, -4.9, 0], [-1.35, -4.9, 0], [-0.37, 5.2, -1.7], [0.37, 5.2, -1.7], [0.9, 3, -1.5],
                    [-0.9, 3, -1.5]];}};
    case ("Heli_light_03" in (typeOf _vehicle)): {if (!_maxtacLights) then {[[-0.8, 3, -1.2], [0.8, 3, -1.2]];} else {[[-0.8, 3, -1.2],
                    [0.8, 3, -1.2], [-1.26, -4.35, -0.05], [1.26, -4.35, -0.05], [0.37, 6.25, -0.93], [-0.37, 6.25, -0.93],
                    [1.26, -3.95, -0.64], [-1.26, -3.95, -0.64]];}};
    case ("O_Truck_03" in (typeOf _vehicle)): {[[-0.4, 1.5, 1.1], [0.4, 1.5, 1.1]];};
    case ("O_Heli_Transport_04" in (typeOf _vehicle)): {[[-0.4, 1.5, 1.1], [0.4, 1.5, 1.1]];};
    default {_undefined = true; [[-0.37, -0.6, 0.4], [0.37, -0.6, 0.4]];};}; if (_undefined) then {
    diag_log format["Vehicle emergency lights not set for: %1", typeOf _vehicle];};
private _redLights = [];
private _blueLights = []; {private _red =
    if (_forEachIndex % 2 == 0) then {true} else {false};
    private _color =
    if (_red) then {_lightRed} else {_lightBlue};
    private _light = "#lightpoint"
    createVehicleLocal getPos _vehicle;
    uiSleep 0.02;
    _light setLightColor _color;
    _light setLightBrightness 0.2;
    _light setLightAmbient[0.1, 0.1, 1];
    _light lightAttachObject[_vehicle, _x];
    _light setLightAttenuation[0.14, 0, 1000, 20];
    _light setLightIntensity 2;
    _light setLightFlareSize 0.3;
    _light setLightFlareMaxDistance 200;
    _light setLightUseFlare true;
    _light setLightDayLight true;
    if (_red) then {_redLights pushBack _light;} else {_blueLights pushBack _light;};}
forEach _lightPositions;
private _brightness = 0;
private _leftRed = true;
while {alive _vehicle}
do {if !(_vehicle getVariable "AP_lights") exitWith {};
    _brightness =
    switch (true) do {case (dayTime > 6 && dayTime <= 17.5): {35};
        case (dayTime >= 5.25 && dayTime <= 6): {5};
        case (dayTime > 17.5 && dayTime <= 18.5): {10};
        default {2.5};}; if (_leftRed) then {{_x setLightBrightness _brightness;}
        forEach _redLights; {_x setLightBrightness 0.0;}
        forEach _blueLights;} else {{_x setLightBrightness 0.0;}
        forEach _redLights; {_x setLightBrightness _brightness;}
        forEach _blueLights;};
    _leftRed = !_leftRed;
    uiSleep _lightTime;}; private _allLights = _redLights + _blueLights; {deleteVehicle _x;}
forEach _allLights;