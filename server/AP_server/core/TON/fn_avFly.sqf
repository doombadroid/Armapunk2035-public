/*
    APS_fnc_avFly  (Armapunk 2035, 2026-09-22) -- one LUXE AV flight, server side. Spawned by APS_fnc_avSRV
    "go" after it has validated the caller, the seat and the destination (and by the engine smoke directly).
        [_veh, _dest [x,y], _name] spawn APS_fnc_avFly;
    Door shuts, the four rotors spin up (model.cfg source rotorH follows the engine), AP_fnc_hcFly flies it with
    the landing pinned to the pad, any flight that ends in the air is settled to the ground, door opens.
    2026-09-23: the tilting engine pods (thrust_vector) are gone -- quad rotors since the r8 redesign.
    Reasons for the pad pin and the settle: see APS_fnc_avSRV's header.
*/
params ["_veh", "_dest", "_name"];
private _tell = { params ["_to", "_msg"]; [[_msg, "basic"], "AP_fnc_handleMessage", _to, false, false] spawn AP_fnc_MP; };
private _pax = { (crew _veh) select { isPlayer _x } };
// the hull must be local here for the core (an admin spawn is server-local already)
if (!local _veh) then { _veh setOwner 2; private _t = time + 5; waitUntil { sleep 0.1; local _veh || {time > _t} }; };
if (!local _veh) exitWith { _veh setVariable ["AP_avBusy", false, true]; { [_x, "The AV could not take control. Try again."] call _tell; } forEach (call _pax); };
_veh lockDriver true; _veh lockCargo true;           // nobody takes the controls; nobody steps out mid-air
{ [_x, format ["Departing for %1.", _name]] call _tell; } forEach (call _pax);
_veh animateSource ["doors_open", 0]; sleep 1.7;
_veh setFuel 1; _veh engineOn true; sleep 2.5;             // rotor spin-up before lift-off
_veh setVariable ["fly_phase", "climb", true];      // always a vertical lift-off from the pad
if !([_veh, _dest, 420] call AP_fnc_hcFly) exitWith {
    _veh engineOn false; _veh animateSource ["doors_open", 1];
    _veh lockCargo false; _veh setVariable ["AP_avBusy", false, true];
    { [_x, "The AV declined the flight."] call _tell; } forEach (call _pax);
};
// the landing is pinned to the pad the moment the core picks one
waitUntil {
    sleep 0.2;
    private _ph = _veh getVariable ["fly_phase", ""];
    if (_ph in ["approach", "descend"] && {((_veh getVariable ["fly_land", []]) param [0, -1]) isNotEqualTo (_dest select 0)}) then {
        _veh setVariable ["fly_land", [_dest select 0, _dest select 1]];   // non-empty -> approach ends in "descend", never "hover"
    };
    !(_veh getVariable ["hc_ap_driving", false]) || {!alive _veh}
};
private _why = _veh getVariable ["hc_ap_done", ""];
// final settle for any flight that ended in the air (see header)
if (alive _veh && {((getPosATL _veh) select 2) > 0.1}) then {
    private _fno = diag_frameNo; private _last = time;
    while { alive _veh && {((getPosATL _veh) select 2) > 0.05} } do {
        waitUntil { diag_frameNo != _fno }; _fno = diag_frameNo;
        private _dt = ((time - _last) max 0.005) min 0.2; _last = time;
        private _agl = (getPosATL _veh) select 2;
        private _vz = [-3, -0.6] select (_agl < 4);
        _veh setVectorUp [0, 0, 1];
        _veh setVelocity [0, 0, _vz];
        _veh setPosASL ((getPosASL _veh) vectorAdd [0, 0, (_vz * _dt) max (-_agl)]);
    };
};
if (alive _veh) then {
    _veh setVelocity [0, 0, 0]; _veh engineOn false;
    _veh lockCargo false;
    _veh animateSource ["doors_open", 1];
};
_veh setVariable ["AP_avBusy", false, true];
diag_log format ["[AV] flight to %1 ended: core=%2 alive=%3 at %4 (%5 m from pad)", _name, _why, alive _veh, (getPosATL _veh) apply { round _x }, round (_veh distance2D _dest)];
{ [_x, if (alive _veh) then { format ["Arrived: %1.", _name] } else { "The AV was lost." }] call _tell; } forEach (call _pax);
