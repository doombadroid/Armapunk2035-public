// owner 2026-06-24 (#493 "RV does not emit smoke during cooking"): optional _isLab flag. The glitter/moonshine
// RV cooking path (fn_glitterLab/fn_moonshineLab) broadcasts this with _isLab=true; default false preserves the
// EXACT old behaviour for the cannabis-smoking caller (fn_cannabisItems passes only [player]). When _isLab:
//  - the smoke is attached higher/over the cargo box ([0,0,2.7]) so it reads as venting from the lab, not the floor;
//  - the smoke ALSO terminates the moment the lab is shut down (AP_labMode->false, e.g. broken down or moved),
//    not just on the fixed timeout -- so it doesn't keep billowing for 5 min after the lab is packed up. The lab
//    runs longer than 300s, so the timer is also extended for labs.
params[["_unit", objNull, [objNull]], ["_isLab", false, [false]]];
if (isNull _unit) exitWith {};
private _smoke = "#particlesource"
createVehicleLocal[0, 0, 100000];
_smoke setParticleCircle[0, [0, 0, 0]];
_smoke setParticleRandom[2, [0.1, 0.1, 0], [0.05, 0.05, 0.3], 0.3, 0.25, [1, 1, 1, 1], 0, 0];
_smoke setParticleParams[["\A3\data_f\ParticleEffects\Universal\Universal", 1, 2, 8, 0], "", "Billboard", 1, 3, [0, 0, 0], [0, 0, 0.5], 0, 10.1, 7.9, 0.01, [0.1, 0.1, 0.2], [
    [1, 1, 1, 1], [1, 1, 1, 1]], [0.3, 0.2], 1, 0, "", "", nil];
_smoke setDropInterval 0.015;
_smoke attachTo[_unit, [0, 0, ([2, 2.7] select _isLab)]];
private _endTime = time + ([300, 7200] select _isLab);
waitUntil {uiSleep 2.5;
    (isNull _unit || !(alive _unit) || time > _endTime || (_isLab && {!(_unit getVariable ["AP_labMode", false])}))};
deleteVehicle _smoke;