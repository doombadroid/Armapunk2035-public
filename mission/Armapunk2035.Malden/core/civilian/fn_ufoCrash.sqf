if !(SRV_ufoCrash select 0) exitWith {};
params[["_ufoLocation", [], [[]]]];
private _createUfo = {params[["_serverBaseObject", objNull, [objNull]], ["_ufoLocation", [], [[]]]];
    _baseLightObject = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject lightAttachObject[_serverBaseObject, [0, 0, 0]];
    _baseLightObject setLightDayLight true;
    _baseLightObject setLightUseFlare true;
    _baseLightObject setLightFlareSize 5;
    _baseLightObject setLightFlareMaxDistance 6000;
    _baseLightObject setLightAmbient[0.5, 0.5, 1];
    _baseLightObject setLightColor[0.5, 0.7, 0.9];
    _baseLightObject setLightAttenuation[0, 0, 0, 0, 0, 4000];
    _baseLightObject setLightBrightness 10;
    _baseLightObject1 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject2 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject3 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject4 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject5 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject6 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject7 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject8 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject9 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    _baseLightObject10 = "#lightpoint"
    createVehicleLocal[0, 0, 0];
    private _lightObjects = [_baseLightObject, _baseLightObject1, _baseLightObject2, _baseLightObject3, _baseLightObject4, _baseLightObject5, _baseLightObject6, _baseLightObject7, _baseLightObject8, _baseLightObject9, _baseLightObject10]; {
        _x params["_xLightObj", "_xAttach"];
        _xLightObj lightAttachObject[_baseLightObject, _xAttach];
        _xLightObj setLightDayLight true;
        _xLightObj setLightUseFlare true;
        _xLightObj setLightFlareSize 2;
        _xLightObj setLightFlareMaxDistance 6000;
        _xLightObj setLightAmbient[0.5, 0.5, 1];
        _xLightObj setLightColor[0.5, 0.7, 0.9];
        _xLightObj setLightAttenuation[0, 0, 0, 0, 0, 4000];
        _xLightObj setLightBrightness 10;}
    forEach[[_baseLightObject1, [-4.837, 1.807, -1.531]], [_baseLightObject2, [-4.967, -1.388, -1.531]], [_baseLightObject3, [-3.276, -4.254, -1.531]], [_baseLightObject4, [0.007, -5.282, -1.531]], [_baseLightObject5, [3.317, -4.407, -1.531]], [_baseLightObject6, [5.426, -1.62, -1.531]], [_baseLightObject7, [5.214, 1.851, -1.531]], [_baseLightObject8, [3.312, 4.358, -1.531]], [_baseLightObject9, [0.161, 5.64, -1.531]], [_baseLightObject10, [-2.751, 4.497, -1.531]]];
    [_baseLightObject] spawn {params["_baseLightObject"];
        while {alive _baseLightObject}
        do {private _waveEffect = "#particlesource"
            createVehicleLocal(getPos _baseLightObject);
            _waveEffect setParticleCircle[3, [0, 0, 0]];
            _waveEffect setParticleRandom[0.1, [3, 3, 1], [100, 100, 0], 0, 2, [0, 0, 0, 0.5], 1, 0];
            _waveEffect setParticleParams[["\A3\data_f\cl_basic", 1, 0, 1], "", "Billboard", 1, 3, [1, 1, 2], [0, 0, -5], 0, 20, 1, 1, [5, 10], [
                [0.05, 0.04, 0.03, 0.5], [0.05, 0.04, 0.03, 0]], [1], 1, 0, "", "", _baseLightObject];
            _waveEffect setDropInterval 0.002;
            [_waveEffect] spawn {uiSleep 0.1;
                deleteVehicle(_this select 0);};
            drop[["\A3\data_f\kouleSvetlo", 1, 0, 6], "", "Billboard", 1, 7, [0, 0, 0], [0, 0, 0], 0, 9.999, 7, 0, [1, 5], [
                [0.443, 0.706, 0.81, 0.2], [0.443, 0.706, 0.81, 0]], [1], 0, 0, "", "", _baseLightObject];
            drop[["\A3\data_f\ParticleEffects\Universal\Refract.p3d", 1, 0, 6], "", "Billboard", .2, 0.5, [1, 1, 0], [0, 0, 0], 0, 9, 7, 0, [1, 10, .5], [
                [0, 0, 0, 0], [0, 0, 0, 1], [0, 0, 0, 0]], [1], 0, 0, "", "", _baseLightObject];
            drop[["\A3\data_f\ParticleEffects\Universal\Refract.p3d", 1, 0, 1], "", "Billboard", .5, 1, [0, 0, 0], [0, 0, 0], 0, 9, 7, 0, [1, 10, .5], [
                [0, 0, 0, 0], [0, 0, 0, 1], [0, 0, 0, 0]], [1], 0, 0, "", "", _baseLightObject];
            uiSleep 10;};};
    [_baseLightObject] spawn {params["_baseLightObject"];
        while {alive _baseLightObject}
        do {_baseLightObject say3D["ufoHover", 2000];
            uiSleep 15;};};
    uiSleep 28;
    _baseLightObject say3D["ufoLeave", 2000];
    drop[["\A3\data_f\kouleSvetlo", 1, 0, 1], "", "Billboard", 1, 2.5, [0, 0, 0], [0, 0, 200], 0, 9, 7, 0, [10, 1], [[1, 1, 1, 1],
        [0.9, .9, 1, 1]], [1], 0, 0, "", "", _baseLightObject];
    uiSleep 1; {deleteVehicle _x}
    forEach _lightObjects;};
private _vectorDiff = _ufoLocation vectorDiff(getPosASL player);
private _direction = (_vectorDiff select 0) atan2(_vectorDiff select 1);
if (_direction < 0) then {_direction = 360 + _direction};
private _compass = ["north", "north east", "east", "south east", "south", "south west", "west", "north west", "north"];
private _bearing = _compass select(round(_direction / 45));
[_bearing] spawn {params["_bearing"];
    uiSleep 4; [[0, 1, 2], format["You hear and see strange lights of unknown origin, towards the %1 of %2", _bearing, worldName]
    ] spawn AP_fnc_broadcast;};
[_createUfo, _ufoLocation] spawn {params["_createUfo", "_ufoLocation"];
    waitUntil {uiSleep 10;
        (player distance2D _ufoLocation <= 1000)};
    while {SRV_ufoCrash select 0}
    do {if !(SRV_ufoCrash select 0) exitWith {}; {[_x, _ufoLocation] spawn _createUfo;}
        forEach(nearestObjects[_ufoLocation, ["Sign_Sphere200cm_Geometry_F"], 550]);
        uiSleep 45;};};
waitUntil {uiSleep 10;
    (SRV_ufoCrash select 1)};
private _ufoTrigger = createTrigger["EmptyDetector", _ufoLocation, false];
_ufoTrigger setTriggerArea[300, 300, 0, false];
_ufoTrigger setTriggerActivation["ANYPLAYER", "PRESENT", true];
_ufoTrigger setTriggerStatements["((this && ((vehicle player) in thisList)) || (player in thisList))", "[thisList, thisTrigger] call AP_fnc_radiationZone", ""];
_ufoTrigger setSoundEffect["$NONE$", "", "", "Owl"];
private _ufoObject = nearestObject[_ufoLocation, "Land_SM_01_reservoirTower_F"];
[_ufoObject] spawn {params["_ufoObject"];
    while {SRV_ufoCrash select 1}
    do {_ufoObject say3D["ufoCrash", 300];
        uiSleep 12;};};
waitUntil {uiSleep 15;
    !(SRV_ufoCrash select 1)};
deleteVehicle _ufoTrigger;