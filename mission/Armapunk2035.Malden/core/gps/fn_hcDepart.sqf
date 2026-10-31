/*
    AP_fnc_hcDepart  (LooneyBin, owner 2026-07-16) -- clean autopilot DEPARTURE for a vehicle nosed into a spot
    it can't drive straight out of (a delivery van stopped at a player, a car in a dead-end). Reverses off the
    spot, 3-point-turns to face the way out, then hands back to the normal forward autopilot (AP_fnc_hcDrive)
    to reach a road and leave. Runs on the machine that owns the vehicle (the HC). Triggered by the HC driver
    pump when hc_ap_departWant is set.
    [_veh]
*/
params [["_veh", objNull, [objNull]]];
if (isNull _veh || {!local _veh}) exitWith {};
if (_veh getVariable ["hc_ap_departing", false]) exitWith {};
_veh setVariable ["hc_ap_departing", true, true];
_veh setVariable ["hc_ap_want", false, true];        // drop any leftover arrival-drive intent
_veh setVariable ["hc_ap_departWant", false, true];  // consume the trigger so the pump won't re-fire us

private _faceAway = (getDir _veh) + 180;
[_veh, 13, 4.0] call AP_fnc_hcReverse;             // peel straight back off the drop (away from the player/box)
[_veh, _faceAway] call AP_fnc_hcTurnAround;        // 3-point turn to face the way out

if (!isNull _veh && {alive _veh} && {local _veh}) then {
    // pointed away now -> normal forward drive to a road ~250m ahead, then the caller despawns it
    private _fp = (getPosATL _veh) getPos [250, getDir _veh];
    private _fr = (_fp nearRoads 350) param [0, objNull];
    _veh setVariable ["hc_ap_mode", "normal", true];
    _veh setVariable ["hc_ap_arrive", 12, true];
    _veh setVariable ["hc_ap_dest", (if (isNull _fr) then { _fp } else { getPosATL _fr }), true];
    _veh setVariable ["hc_ap_done", "", true];
    _veh setVariable ["hc_ap_want", true, true];     // pump's normal branch drives it forward + away
};
_veh setVariable ["hc_ap_departDone", true, true];
