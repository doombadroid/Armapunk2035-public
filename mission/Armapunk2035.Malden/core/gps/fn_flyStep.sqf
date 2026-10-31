/*
    AP_fnc_flyStep  (Armapunk 2035, 2026-09-02) -- ONE FRAME of rotorcraft autopilot.

    Pure step: every bit of state lives on the vehicle, so the same code flies a
    heli with the owner in the seat (fn_gpsAutopilot's EachFrame handler) and a
    driverless one on the headless client (AP_fnc_hcFly). No globals.

        [_veh, _dt] call AP_fnc_flyStep;      -> phase (String)

    Host contract: set `fly_dest` ([x, y, z], z ignored) before the first call and
    keep it current (a moving summoner). Clear `fly_alt` (setVariable nil) when engaging;
    optionally pre-set `fly_phase` "climb" to force a lift-off, otherwise a vehicle already > 30 m up starts in "cruise".

    Phases  climb -> cruise -> approach -> descend -> landed
            "hover"   no flat spot within 40 m: holding 3 m over the target
            "aborted" progress watchdog fired (no closing on the target for 6 s)

    Movement: a velocity is blended toward a carrot each frame (never
    setVelocityModelSpace -- model Y is not "forward" for a banked rotorcraft)
    and setVectorDirAndUp sets the attitude. With a pilot aboard, setVelocity
    drives the flight model; with the seat EMPTY the model ignores setVelocity
    (it hover-holds), so the core integrates the position itself and keeps its
    own velocity state (fly_vel). Measured on the HC, 2026-09-02. Helicopters and VTOLs fly the identical model: a VTOL is flown as
    a rotorcraft, no transition. Planes are never accepted.
*/
params [["_veh", objNull, [objNull]], ["_dt", 0.016, [0]]];
if (isNull _veh || {!alive _veh}) exitWith { "aborted" };
if !([_veh] call AP_fnc_isRotorcraft) exitWith { "aborted" };
_dt = (_dt max 0.005) min 0.2;

private _dest = _veh getVariable ["fly_dest", []];
if (!(_dest isEqualType []) || {count _dest < 2}) exitWith { "aborted" };
private _dest2 = [_dest select 0, _dest select 1];

// cruise altitude: AP_fnc_flyCruiseAlt (registered; object-aware sampler)

private _pos = getPosASL _veh;
private _phase = _veh getVariable ["fly_phase", ""];

// ---------------------------------------------------------------- first call
// Initialise when nothing is set up yet, detected by the ABSENCE of fly_alt rather than by an
// empty phase: a host may pre-set fly_phase "climb" to force a lift-off and still gets the
// altitude sample, the landing slot and the engine. Hosts clear fly_alt (setVariable nil) when
// they engage, so a second flight on the same airframe never inherits the last one's altitude.
if (isNil {_veh getVariable "fly_alt"}) then {
    if (_phase isEqualTo "") then {
        private _agl = (_pos select 2) - (getTerrainHeightASL _pos);
        _phase = if (_agl > 30) then { "cruise" } else { "climb" };
    };
    _veh setVariable ["fly_phase", _phase, true];
    _veh setVariable ["fly_alt", [_pos, _dest, _veh] call AP_fnc_flyCruiseAlt];
    _veh setVariable ["fly_land", []];
    _veh setVariable ["fly_hover", nil];
    _veh setVariable ["fly_chk", [time, _pos distance2D _dest2]];
    _veh setVariable ["fly_destSeen", _dest2];
    _veh setVariable ["fly_vel", velocity _veh];
    _veh engineOn true;
};
// The core's OWN velocity state, not the engine's: an unmanned rotorcraft's model zeroes `velocity` every
// physics step (b0838 self-test: read 0 each frame, so the blend below restarted from 0 and the aircraft
// climbed at 0.4 m/s). Read AFTER the init block so a re-engage seeds from the engine, not from the last
// flight's terminal value.
private _vel = _veh getVariable ["fly_vel", velocity _veh];
// destination moved (a walking summoner): re-sample the altitude, drop the landing spot
if ((_veh getVariable ["fly_destSeen",_dest2]) distance2D _dest2 > 25) then {
    _veh setVariable ["fly_destSeen", _dest2];
    _veh setVariable ["fly_alt", [_pos, _dest, _veh] call AP_fnc_flyCruiseAlt];
    _veh setVariable ["fly_land", []];
    if (_phase in ["approach", "descend"]) then { _phase = "cruise"; _veh setVariable ["fly_phase", _phase, true]; };
    _veh setVariable ["fly_chk", [time, _pos distance2D _dest2]];   // fresh watchdog baseline for the new target
};

private _alt = _veh getVariable ["fly_alt", (_pos select 2) + 120];
// a host may cap the cruise (the AI hand-over: the last 200 m need not climb back to cruise height)
private _altCap = _veh getVariable ["fly_altCap", -1];
if (_altCap > 0) then { _alt = _alt min _altCap; };
// the airframe's own size: half the footprint (a Blackfish is ~9 m, an MH-9 ~4 m) and how far its belly
// hangs below its centre -- the landing spot clearance, the hover height and the hover offset use them
private _bb = boundingBoxReal _veh;
private _half = ((((_bb select 1) select 0) max ((_bb select 1) select 1)) max 3) min 14;
private _belly = ((-((_bb select 0) select 2)) max 0) min 10;
private _dist = _pos distance2D _dest2;
private _spdH = sqrt ((_vel select 0) ^ 2 + (_vel select 1) ^ 2);

// ---------------------------------------------------------------- landing spot
// AP_fnc_flyLandSpot (registered, shared with the HC's AI flight): the clear spot NEAREST the destination
// where the aircraft can take off again -- rotor radius + 2 m from static objects, nothing alive or parked on
// the disc (so never on the summoner), a clear 60 m column above it, gradient <= 0.3, land only, 150 m out.
// Picked once per flight at the cruise->approach hand-over and again when the destination moves; none ->
// [] and the host gets "hover". (Until 2026-09-07 a private spiral here cleared 70% of half a hull, saw no
// person, vehicle or canopy and stopped at 60 m.)

// ---------------------------------------------------------------- targets per phase
private _want = [0, 0, 0];      // wanted velocity, world frame
private _levelOut = false;
switch (_phase) do {
    case "climb": {
        // straight up, nose already toward the destination
        _want = [0, 0, 8];
        if ((_pos select 2) >= _alt - 2) then {
            _phase = "cruise"; _veh setVariable ["fly_phase", _phase, true];
            // the progress watchdog below measures 2D closure; a climb makes none, so its baseline is
            // stamped HERE, not at engage (b0839 self-test: aborted on the first cruise frame, 25 s in)
            _veh setVariable ["fly_chk", [time, _pos distance2D _dest2]];
        };
    };
    case "cruise": {
        private _dir = [(_dest2 select 0) - (_pos select 0), (_dest2 select 1) - (_pos select 1), 0];
        private _len = vectorMagnitude _dir;
        if (_len > 0.1) then { _dir = _dir vectorMultiply (1 / _len); };
        // ramp toward 60 m/s at 6 m/s^2, hold cruise altitude
        private _target = ((_spdH + 6 * _dt) min 60) min (_dist / 4 max 15);
        private _vz = (((_alt - (_pos select 2)) * 0.6) max -6) min 6;
        _want = [(_dir select 0) * _target, (_dir select 1) * _target, _vz];
        if (_dist < 250) then {
            _phase = "approach"; _veh setVariable ["fly_phase", _phase, true];
            private _ls = [_dest2, _veh] call AP_fnc_flyLandSpot;
            // wheels down for anything that retracts them (the AI flies a VTOL gear-up; it belly-landed and
            // exploded, 2026-09-03). The action needs the vehicle local, which every host guarantees.
            // the landGear action is ignored on an empty airframe (gear phase stayed 1 at touchdown, b0870): drive
            // the animation source; 0 = extended
            if (_veh isKindOf "Plane") then { _veh action ["landGear", _veh]; _veh animateSource ["gear", 0]; };
            // a VTOL never hovers: nothing holds a pilotless one in the air once the core stops (a Blackfish
            // parked in "hover" beside the summoner dropped from 8 m and exploded, 2026-09-03), so with no
            // proven spot it lands beside the summoner anyway -- half a hull plus 6 m out along the line it
            // came in on, gentle descent, shield on
            if (_ls isEqualTo [] && {_veh isKindOf "Plane"}) then {
                private _dx = (_pos select 0) - (_dest2 select 0); private _dy = (_pos select 1) - (_dest2 select 1);
                private _n = (sqrt (_dx * _dx + _dy * _dy)) max 1;
                _ls = [(_dest2 select 0) + _dx / _n * (_half + 6), (_dest2 select 1) + _dy / _n * (_half + 6)];
            };
            _veh setVariable ["fly_land", _ls];
        };
    };
    case "approach": {
        _levelOut = true;
        private _land = _veh getVariable ["fly_land", []];
        if (_land isEqualTo []) then { _land = _dest2; };
        private _dl = _pos distance2D _land;
        private _dir = [(_land select 0) - (_pos select 0), (_land select 1) - (_pos select 1), 0];
        if (_dl > 0.1) then { _dir = _dir vectorMultiply (1 / _dl); };
        // 15 m/s, scaled down by remaining distance, floor 3 m/s. HOLD cruise altitude all the way to the
        // landing spot: the descent is vertical, over a spot isFlatEmpty proved clear, so nothing standing
        // on the approach line can be hit (the old 25 m AGL slide from 250 m out met the Lux tower).
        private _target = ((_dl / 6) max 3) min 15;
        private _vz = (((_alt - (_pos select 2)) * 0.6) max -6) min 6;
        _want = [(_dir select 0) * _target, (_dir select 1) * _target, _vz];
        if (_dl < 8 && {_spdH < 4}) then {
            _phase = if ((_veh getVariable ["fly_land", []]) isEqualTo []) then { "hover" } else { "descend" };
            _veh setVariable ["fly_phase", _phase, true];
        };
    };
    case "descend": {
        _levelOut = true;
        private _land = _veh getVariable ["fly_land", _dest2];
        private _dir = [(_land select 0) - (_pos select 0), (_land select 1) - (_pos select 1), 0];
        private _dl = _pos distance2D _land;
        if (_dl > 0.1) then { _dir = _dir vectorMultiply (1 / _dl); };
        // height of the BELLY, not the hull centre (a Blackfish's belly hangs 6 m under its centre: measured at
        // the centre it was still sinking at 3 m/s when the wheels met the ground -- gear damage, 2026-09-03)
        private _agl = (_pos select 2) - (getTerrainHeightASL _pos) - _belly;
        // an AI-crewed aircraft auto-retracts its gear in flight (the order reverted within a second, b0875):
        // re-issue gear-down from the seat every frame of the descent, so the auto-retract loses
        if (_veh isKindOf "Plane" && {!isNull (driver _veh)}) then { (driver _veh) action ["landGear", _veh]; };
        // fast while high, then 3, 1, and a 0.4 m/s touchdown
        private _vz = if (_agl > 40) then { -8 } else { if (_agl > 8) then { -3 } else { if (_agl > 2) then { -1 } else { -0.4 } } };
        _want = [(_dir select 0) * (_dl min 2), (_dir select 1) * (_dl min 2), _vz];
        if (isTouchingGround _veh || {_agl < 0.05}) then {   // wheels on the ground before the core lets go: no drop
            _phase = "landed"; _veh setVariable ["fly_phase", _phase, true];
            _veh setVelocity [0, 0, 0];
            _veh setVariable ["fly_vel", [0, 0, 0]];
            _veh engineOn false;
        };
    };
    case "hover": {
        _levelOut = true;
        // hover BESIDE the summoner, not over them: half a hull plus 6 m out along the line it came in on,
        // fixed on entry; belly 2 m off the ground (the height is the centre's, and a Blackfish's belly hangs
        // ~4 m under it)
        private _hp = _veh getVariable ["fly_hover", []];
        if (_hp isEqualTo []) then {
            private _dx = (_pos select 0) - (_dest2 select 0); private _dy = (_pos select 1) - (_dest2 select 1);
            private _n = (sqrt (_dx * _dx + _dy * _dy)) max 1;
            _hp = [(_dest2 select 0) + _dx / _n * (_half + 6), (_dest2 select 1) + _dy / _n * (_half + 6)];
            _veh setVariable ["fly_hover", _hp];
        };
        private _aglHold = ((getTerrainHeightASL _hp) max 0) + 2 + _belly;   // belly 2 m up; over water, over the sea
        private _vz = (((_aglHold - (_pos select 2)) * 0.6) max -8) min 3;
        private _dir = [(_hp select 0) - (_pos select 0), (_hp select 1) - (_pos select 1), 0];
        _want = [(_dir select 0) * 0.5, (_dir select 1) * 0.5, _vz];
    };
    default {};   // landed / aborted: nothing to drive
};

if (_phase in ["landed", "aborted"]) exitWith { _phase };

// ---------------------------------------------------------------- progress watchdog
// Cruise only: approach steers to fly_land (up to 40 m off the destination axis), so 2D closure on the
// destination can legitimately stall on a perpendicular final leg; approach is bounded by the host cap.
if (_phase isEqualTo "cruise") then {
    (_veh getVariable ["fly_chk", [time, _dist]]) params ["_t", "_d"];
    if (time - _t > 6) then {
        if (_d - _dist < 5) exitWith {
            _phase = "aborted"; _veh setVariable ["fly_phase", _phase, true];
        };
        _veh setVariable ["fly_chk", [time, _dist]];
    };
};
if (_phase isEqualTo "aborted") exitWith { _phase };

// ---------------------------------------------------------------- apply: velocity, then attitude
// Blend toward the wanted velocity (aircraft, not a car: the blend IS the inertia)
private _k = (_dt * 2.5) min 1;
private _new = [(_vel select 0) + ((_want select 0) - (_vel select 0)) * _k,
                (_vel select 1) + ((_want select 1) - (_vel select 1)) * _k,
                (_vel select 2) + ((_want select 2) - (_vel select 2)) * _k];
_veh setVelocity _new;
_veh setVariable ["fly_vel", _new];
// UNMANNED ONLY. A rotorcraft with nobody at the controls is flown by the engine's own model -- hover-hold with the engine
// on, autorotation with it off -- which re-integrates velocity every physics step, so setVelocity alone
// never moves it: measured on the HC (b0837 self-test) pinned at 0.4 m/s both on the ground and hanging at
// 4 m AGL, engine on, phase climb. Cars are PhysX and obey setVelocity; a helicopter does not. So the
// position is integrated HERE from the blended velocity when the seat is empty; with a pilot aboard the model
// integrates setVelocity itself and a second integration would double the speed. setVelocity stays for interpolation and sound,
// and the engine stays on for the rotors. Landing still ends the flight physically: once "landed" nothing
// below runs and the airframe settles on its own.
// With a pilot aboard the model accepts setVelocity (b0846 probe: velocity reads the command) but ground
// contact cancels a climb with no collective, so the first 4 m are kinematic for everyone; after that a
// piloted airframe flies on the velocity the model integrates, an unmanned one keeps being integrated here.
if (isNull (driver _veh) || {_veh getVariable ["fly_forceKinematic", false]} || {((_pos select 2) - (getTerrainHeightASL _pos)) < 4}) then { _veh setPosASL (_pos vectorAdd (_new vectorMultiply _dt)); };

// Attitude: heading = travel direction (or the destination when slow), pitch down with speed,
// bank into the lateral acceleration. Level in approach/descend/hover.
private _hx = _new select 0; private _hy = _new select 1;
if (sqrt (_hx ^ 2 + _hy ^ 2) < 3) then { _hx = (_dest2 select 0) - (_pos select 0); _hy = (_dest2 select 1) - (_pos select 1); };
private _hl = sqrt (_hx ^ 2 + _hy ^ 2);
if (_hl < 0.1) then { _hx = 0; _hy = 1; _hl = 1; };
_hx = _hx / _hl; _hy = _hy / _hl;
private _spdNew = sqrt ((_new select 0) ^ 2 + (_new select 1) ^ 2);
private _pitch = if (_levelOut) then { 0 } else { ((-((_spdNew / 60) * 10)) max -10) min 0 };   // degrees, nose down, never past 10
private _latA = ((_want select 0) - (_vel select 0)) * _hy - ((_want select 1) - (_vel select 1)) * _hx;
private _bank = if (_levelOut) then { 0 } else { ((_latA / _dt / 9.81 * 25) max -25) min 25 };
private _dirV = [_hx * cos _pitch, _hy * cos _pitch, sin _pitch];
private _right = [_hy, -_hx, 0];
private _upV = [(_right select 0) * sin _bank, (_right select 1) * sin _bank, cos _bank];
_veh setVectorDirAndUp [_dirV, _upV];

_phase
