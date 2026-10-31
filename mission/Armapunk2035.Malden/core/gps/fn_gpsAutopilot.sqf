/*
    AP_fnc_gpsAutopilot  (LooneyBin, owner 2026-07-12)
    TESLA MODE -- scroll-wheel autopilot along the active GPS route. Runs on the DRIVER'S
    client (vehicle local to its driver). No AI units -- Arma AI driving is a war crime.

    v9 -- PHYSICS DRIVE (the one that finally works, smooth for everyone). The long road here:
    setPos-based movement drove the car fine locally but NETWORKED as discrete teleports -> other
    players saw stutter and it was hard to shoot. setVelocityTransformation Generic-errors on physx
    cars. The fix (research + owner's Gemini tip): drive the car with REAL PHYSICS --
      * disableBrakes true at engage: kills the autobrake that had cancelled every setVelocity.
      * setVelocityModelSpace [0, speed, vz] each frame = throttle (forward at commanded speed,
        physics keeps Z -> gravity/suspension seat it on the road, up hills, over bridges free).
      * setAngularVelocity [0,0,yaw] = steering (PD pure-pursuit toward a lane-offset lookahead).
      * MUST run where the vehicle is LOCAL (the driver's client) or it rubberbands.
    Physics-driven motion networks smoothly by nature -> passengers/bystanders see it 1:1, no jitter.

    Cornering: scan the route ahead, read each bend's radius, cap speed at the SLOWER of the grip
    limit and the yaw-rate limit, and brake conservatively (early, with margin) + a hard clamp to
    the imminent corner speed so it physically makes the turn. Crashes are logged to the DB (-APCRASH-).

    Telemetry ([ap] lines to the RPT) is intentionally LEFT IN for tuning.

    Modes: ["toggle"] | ["start"] | ["stop", _reason] | ["drive"] (one unscheduled frame)
*/
if (!hasInterface) exitWith {};
params [["_mode", "", [""]], ["_a1", ""]];

switch (toLower _mode) do {case "toggle": {if (missionNamespace getVariable ["AP_gpsAP", false]) then {
            ["stop", "disengaged"] call AP_fnc_gpsAutopilot;} else {["start"] call AP_fnc_gpsAutopilot;};};

    case "start": {private _veh = vehicle player;
        private _mode = if (_a1 in ["madmax", "normal", "sloth"]) then { _a1 } else { "normal" };
        // CHAUFFEUR OVERRIDE (owner 2026-07-21): a hijacked car engages this SAME proven seated-drive path a
        // driverless-cab feature once used (that is the whole point -- the drive is already tested with a live
        // player in the seat and networks smoothly). A hijack is not consensual, so the driver-consent preconditions below
        // (on-road / undamaged / near-route) and the "touch the controls to take over" message are skipped for
        // it; the physics-critical setup (route, engineOn, disableBrakes, EachFrame) is identical.
        private _hijack = _veh getVariable ["AP_chauffeured", false];
        private _isAir = [_veh] call AP_fnc_isRotorcraft;
        if (_veh isEqualTo player || {!(_veh isKindOf "LandVehicle") && {!_isAir}} || {driver _veh isNotEqualTo player}) exitWith {};
        if !(_veh getVariable ["AP_autopilot", false]) exitWith {
            ["<t color='#00d4ff'>AUTOPILOT:</t> this vehicle has no autopilot module (garage upgrade, $300).", "basic"] spawn AP_fnc_handleMessage;
        };
        // ---------------------------------------------------------------- ROTORCRAFT
        // No road route, no on-road rule: fly straight to AP_gpsDest with AP_fnc_flyStep. The same
        // EachFrame handler drives it; the same "touch the controls" disengage applies (heli inputs).
        if (_isAir) exitWith {
            private _dest = missionNamespace getVariable ["AP_gpsDest", []];
            if (_dest isEqualTo []) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> set a GPS destination first.", "basic"] spawn AP_fnc_handleMessage;};
            if (_veh distance2D _dest < 100) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> destination is right here -- you can see it.", "basic"] spawn AP_fnc_handleMessage;};
            if (missionNamespace getVariable ["AP_gpsAP", false]) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> already flying.", "basic"] spawn AP_fnc_handleMessage;};
            private _dmgMax = damage _veh;
            { _dmgMax = _dmgMax max _x; } forEach ((getAllHitPointsDamage _veh) param [2, []]);
            if (_dmgMax >= 0.25) exitWith {
                ["<t color='#00d4ff'>AUTOPILOT:</t> the aircraft is damaged -- repair it before engaging.", "basic"] spawn AP_fnc_handleMessage;};
            _veh setVariable ["fly_phase", "", true];
            _veh setVariable ["fly_alt", nil];        // flyStep initialises on a missing fly_alt
            _veh setVariable ["fly_dest", [_dest select 0, _dest select 1, 0], true];
            _veh setVariable ["fly_t0", time];
            AP_gpsAP = true;
            AP_gpsAPAir = true;
            AP_gpsAPMode = "normal";
            AP_gpsAPLastT = time;
            _veh engineOn true;
            AP_gpsAPEF = addMissionEventHandler ["EachFrame", { ["drive"] call AP_fnc_gpsAutopilot; }];
            ["<t color='#00d4ff'>AUTOPILOT:</t> flying to your destination. Touch the controls to take over.", "basic"] spawn AP_fnc_handleMessage;
        };
        // per-mode law: [top speed m/s, cornering grip (max lateral accel m/s^2), braking m/s^2].
        // Corner speeds are computed from the road's actual RADIUS (v = sqrt(grip * R)), so hairpins
        // are taken slow in every mode -- Mad Max just has more grip + brakes + a higher top end.
        private _cfgMax = ((getNumber (configOf _veh >> "maxSpeed")) * 0.93 / 3.6) max 16.7 min 41.7;   // MAD MAX hard cap 150 km/h
        private _law = switch (_mode) do {case "madmax": { [_cfgMax, 7.5, 8] };
            case "sloth":  { [13.9, 4.0, 5] };     // 50 km/h
            default        { [22.2, 5.5, 6] };     // 80 km/h
        };
        // MOTORIST -- Chauffeur (202): +30% cornering grip, +12% top speed (capped just over Mad Max)
        if (202 in AP_side_talents) then {_law = [((_law select 0) * 1.12) min 44, (_law select 1) * 1.3, _law select 2];};
        AP_gpsAPMode = _mode;
        AP_gpsAPLaw = _law;
        if (missionNamespace getVariable ["AP_gpsAP", false]) exitWith {   // live mode switch
            [format ["<t color='#00d4ff'>AUTOPILOT:</t> %1 mode.", toUpper _mode], "basic"] spawn AP_fnc_handleMessage;};
        if ((missionNamespace getVariable ["AP_gpsRoutePts", []]) isEqualTo []) exitWith {
            ["<t color='#00d4ff'>AUTOPILOT:</t> set a GPS destination first.", "basic"] spawn AP_fnc_handleMessage;};
        if (count (missionNamespace getVariable ["AP_gpsRoutePts", []]) < 4) exitWith {
            ["<t color='#00d4ff'>AUTOPILOT:</t> destination is right here -- walk it.", "basic"] spawn AP_fnc_handleMessage;};
        // ANTI-TELEPORT (owner): engaging snaps the car onto the rail, so off-road engages were a
        // free teleport-to-road (combat escapes, river crossings). Must be on/beside a road AND
        // near the plotted route.
        if (!_hijack && !isOnRoad _veh && {((getPosATL _veh) nearRoads 1) isEqualTo []}) exitWith {
            ["<t color='#00d4ff'>AUTOPILOT:</t> you must be on a public road for this feature to work.", "basic"] spawn AP_fnc_handleMessage;
        };
        // owner 2026-07-12: no autopilot on a damaged vehicle -- any part into the yellow
        // (>=0.25) or overall hull damage blocks engage; a limping car can't be trusted to the rail
        private _dmgMax = damage _veh;
        { _dmgMax = _dmgMax max _x; } forEach ((getAllHitPointsDamage _veh) param [2, []]);
        if (!_hijack && _dmgMax >= 0.25) exitWith {
            ["<t color='#00d4ff'>AUTOPILOT:</t> the vehicle is damaged -- repair it before engaging.", "basic"] spawn AP_fnc_handleMessage;
        };
        private _ptsChk = missionNamespace getVariable ["AP_gpsRoutePts", []];
        private _vp2 = getPosASL _veh;
        private _near = 1e9;
        { _near = _near min (_vp2 distance2D _x); } forEach _ptsChk;
        if (!_hijack && _near > 35) exitWith {
            ["<t color='#00d4ff'>AUTOPILOT:</t> you're too far from the plotted route -- drive closer or replot.", "basic"] spawn AP_fnc_handleMessage;
        };
        AP_gpsAP = true;
        AP_gpsAPn = -1;                             // route sentinel: forces geometry rebuild in drive
        AP_gpsAPSpd = ((speed _veh) / 3.6) max 0;   // commanded speed state (ramped toward target)
        AP_gpsAPHdg = getDir _veh;
        AP_gpsAPChkT = time + 2.5;                  // stuck watchdog (grace on engage)
        AP_gpsAPChkP = getPosASL _veh;
        // PHYSICS DRIVE (owner 2026-07-12, after research): disableBrakes stops the autobrake that
        // cancelled every setVelocity attempt. With brakes off the car MOVES via real physics when
        // we set its velocity -- and physics motion networks SMOOTHLY to all clients (the setPos
        // teleport was the remote-jitter source). Physics also owns Z now: gravity + suspension seat
        // the car on the road, up hills, over bridges -- no more pinning/hover/float.
        _veh engineOn true;
        _veh disableBrakes true;
        AP_gpsAPEF = addMissionEventHandler ["EachFrame", { ["drive"] call AP_fnc_gpsAutopilot; }];
        // a chauffeured victim gets no "touch the controls to take over" message -- their input is gated and
        // fn_qhChauffeur already told them AUTOPILOT COMPROMISED.
        if (!_hijack) then {
            [format ["<t color='#00d4ff'>AUTOPILOT:</t> engaged -- %1 mode. Touch the controls to take over.", toUpper _mode], "basic"] spawn AP_fnc_handleMessage;
        };};

    case "stop": {if (!isNil "AP_gpsAPEF") then {removeMissionEventHandler ["EachFrame", AP_gpsAPEF];
            AP_gpsAPEF = nil;};
        AP_gpsAP = false;
        AP_gpsAPAir = false;
        private _v = vehicle player;
        if (_v isNotEqualTo player && {alive _v}) then { _v disableBrakes false; };   // restore autobrake
        if (_a1 isNotEqualTo "" && {alive player}) then {
            [format ["<t color='#00d4ff'>AUTOPILOT:</t> %1.", _a1], "basic"] spawn AP_fnc_handleMessage;};};

    case "drive": {if !(missionNamespace getVariable ["AP_gpsAP", false]) exitWith {};
        private _veh = vehicle player;
        if (missionNamespace getVariable ["AP_gpsAPAir", false]) exitWith {
            if (!alive player || {_veh isEqualTo player} || {driver _veh isNotEqualTo player}) exitWith { ["stop", ""] call AP_fnc_gpsAutopilot; };
            if (!alive _veh) exitWith { ["stop", "aircraft destroyed"] call AP_fnc_gpsAutopilot; };
            if (fuel _veh <= 0.005) exitWith { ["stop", "out of fuel"] call AP_fnc_gpsAutopilot; };
            if (inputAction "heliUp" > 0 || {inputAction "heliDown" > 0} || {inputAction "heliForward" > 0} || {inputAction "heliBack" > 0}
                || {inputAction "heliLeft" > 0} || {inputAction "heliRight" > 0} || {inputAction "heliRudderLeft" > 0} || {inputAction "heliRudderRight" > 0}
                || {inputAction "heliCollectiveRaise" > 0} || {inputAction "heliCollectiveLower" > 0}) exitWith {
                ["stop", "manual control"] call AP_fnc_gpsAutopilot; };
            private _dt = (time - (missionNamespace getVariable ["AP_gpsAPLastT", time])) min 0.2;
            AP_gpsAPLastT = time;
            private _phase = [_veh, _dt max 0.005] call AP_fnc_flyStep;
            if (_phase isEqualTo "landed") exitWith { ["stop", "landed at your destination"] call AP_fnc_gpsAutopilot; };
            if (_phase isEqualTo "hover") exitWith { ["stop", "no flat spot here -- hovering, take the controls"] call AP_fnc_gpsAutopilot; };
            if (_phase isEqualTo "aborted") exitWith { ["stop", "could not make progress -- take the controls"] call AP_fnc_gpsAutopilot; };
        };
        private _pts = missionNamespace getVariable ["AP_gpsRoutePts", []];
        if (!alive player) exitWith { ["stop", ""] call AP_fnc_gpsAutopilot; };
        if (_pts isEqualTo []) exitWith { ["stop", "route ended"] call AP_fnc_gpsAutopilot; };
        if (_veh isEqualTo player || {driver _veh isNotEqualTo player}) exitWith { ["stop", ""] call AP_fnc_gpsAutopilot; };
        // owner 2026-07-12: dropped the surfaceIsWater disengage -- it fired on bridges over water.
        // Physics drives the car onto/over bridges fine now; only bail if it's genuinely submerged.
        if (!alive _veh || {!canMove _veh} || {((getPosASL _veh) select 2) < -1.2}) exitWith { ["stop", "vehicle unable to continue"] call AP_fnc_gpsAutopilot; };
        if ((damage _veh) >= 0.25) exitWith { ["stop", "vehicle damaged -- take the wheel"] call AP_fnc_gpsAutopilot; };
        if (fuel _veh <= 0.005) exitWith { ["stop", "out of fuel"] call AP_fnc_gpsAutopilot; };
        // Tesla rule: any driving input hands control back instantly -- EXCEPT for a chauffeured (hijacked) ride,
        // where the victim is a captive passenger who can't drive; their keypresses must not disengage the ride,
        // and touching the controls can't take the wheel back either (their fighting drains the hijack battery
        // instead, handled in fn_qhChauffeur).
        if (!(_veh getVariable ["AP_chauffeured", false]) && {inputAction "carForward" > 0 || {inputAction "carBack" > 0} || {inputAction "carLeft" > 0}
            || {inputAction "carRight" > 0} || {inputAction "carFastForward" > 0}}) exitWith {
            ["stop", "manual control"] call AP_fnc_gpsAutopilot;};

        private _n = count _pts;
        if (_n < 4) exitWith { ["stop", "destination reached"] call AP_fnc_gpsAutopilot; };
        private _pos = getPosASL _veh;

        // route geometry (re)build: fresh engage OR mid-drive reroute. Sentinel = count AND first
        // point (two different routes can share a length)
        if ((missionNamespace getVariable ["AP_gpsAPn", -1]) isNotEqualTo _n
            || {(missionNamespace getVariable ["AP_gpsAPP0", [-1, -1]]) isNotEqualTo (_pts select 0)}) then {AP_gpsAPn = _n;
            AP_gpsAPP0 = _pts select 0;
            private _cum = [0];
            for "_i" from 0 to (_n - 2) do {_cum pushBack ((_cum select _i) + ((_pts select _i) distance2D (_pts select (_i + 1))));};
            AP_gpsAPCum = _cum;
            private _best0 = 0;
            private _bd0 = 1e12;
            for "_i" from 0 to (_n - 1) do {private _d = _pos distance2D (_pts select _i);
                if (_d < _bd0) then { _bd0 = _d; _best0 = _i; };};
            AP_gpsAPS = _cum select _best0;
            AP_gpsAPSeg = _best0 min (_n - 2);};
        private _cum = AP_gpsAPCum;
        private _total = _cum select (_n - 1);
        private _s = missionNamespace getVariable ["AP_gpsAPS", 0];
        private _seg = (missionNamespace getVariable ["AP_gpsAPSeg", 0]) min (_n - 2);
        private _spd = missionNamespace getVariable ["AP_gpsAPSpd", 0];
        while {_seg < _n - 2 && {(_cum select (_seg + 1)) <= _s}} do { _seg = _seg + 1; };
        AP_gpsAPSeg = _seg;

        // arc sampler -> [x, y, roadZ] (local walk from the current segment)
        private _fnSample = {params ["_sq"];
            _sq = (_sq max 0) min (_total - 0.01);
            private _g = _seg;
            while {_g > 0 && {(_cum select _g) > _sq}} do { _g = _g - 1; };
            while {_g < _n - 2 && {(_cum select (_g + 1)) <= _sq}} do { _g = _g + 1; };
            private _a = _pts select _g;
            private _b = _pts select (_g + 1);
            private _t = ((_sq - (_cum select _g)) / (((_cum select (_g + 1)) - (_cum select _g)) max 0.01)) min 1;
            [(_a select 0) + ((_b select 0) - (_a select 0)) * _t, (_a select 1) + ((_b select 1) - (_a select 1)) * _t]};

        // corner-chamfered position + 10m-baseline direction (no vertex snap)
        private _pA = [_s - 2.5] call _fnSample;
        private _pB = [_s + 2.5] call _fnSample;
        private _dA = [_s - 5] call _fnSample;
        private _dB = [_s + 5] call _fnSample;
        private _dirX = (_dB select 0) - (_dA select 0);
        private _dirY = (_dB select 1) - (_dA select 1);
        private _dn = sqrt (_dirX * _dirX + _dirY * _dirY) max 0.01;
        _dirX = _dirX / _dn; _dirY = _dirY / _dn;
        // right-hand lane: 2.2m along the route direction's right perpendicular
        private _wx = ((_pA select 0) + (_pB select 0)) / 2 + _dirY * 2.2;
        private _wy = ((_pA select 1) + (_pB select 1)) / 2 - _dirX * 2.2;

        // CURVATURE-LIMITED speed: scan the route ahead in 5m steps; at each point measure the turn
        // radius, derive its safe corner speed (v=sqrt(grip*R)), and require we can brake to it in
        // time (v_entry = sqrt(vc^2 + 2*brake*dist)). The MIN over all points is the target -> the
        // car slows BEFORE a hairpin instead of arriving too fast and understeering into a wall.
        (missionNamespace getVariable ["AP_gpsAPLaw", [22.2, 5.5, 6]]) params ["_vMax", "_grip", "_brake"];
        // owner 2026-07-14 (APCRASH tune): corner-speed grip MARGIN. Mad Max planned corners right at the grip
        // limit (v=sqrt(grip*R)) -> zero cushion, so any bump/yaw error slid it off (crash 1: on-limit into a
        // 25deg hairpin @5m). Plan corners at a FRACTION of grip while the car keeps full grip = a safety margin.
        // Mad Max (the mode BOTH logged crashes were in) gets the cushion; the slower modes were fine, left alone.
        private _cMargin = if ((missionNamespace getVariable ["AP_gpsAPMode", "normal"]) isEqualTo "madmax") then { 0.72 } else { 1.0 };
        private _target = _vMax;
        private _bendAhead = 0;   // sharpest bend in the near field -> drives the adaptive lookahead
        private _nearVc = _vMax;  // corner speed of the IMMINENT bend (<=22m) -> hard speed clamp
        private _dbgSharp = 0; private _dbgSharpD = 0;   // telemetry: sharpest bend the scan sees
        for "_k" from 1 to 18 do {private _d = _k * 5;                         // 5..90 m ahead (braking room for hairpins at speed)
            private _c0 = [_s + _d - 5] call _fnSample;
            private _c1 = [_s + _d] call _fnSample;
            private _c2 = [_s + _d + 5] call _fnSample;
            private _b1 = ((_c1 select 0) - (_c0 select 0)) atan2 ((_c1 select 1) - (_c0 select 1));
            private _b2 = ((_c2 select 0) - (_c1 select 0)) atan2 ((_c2 select 1) - (_c1 select 1));
            private _dth = abs (((_b2 - _b1 + 540) mod 360) - 180);   // deg turned over ~10m
            if (_dth > _dbgSharp) then { _dbgSharp = _dth; _dbgSharpD = _d; };
            if (_d <= 15) then { _bendAhead = _bendAhead max _dth; };
            if (_dth > 2) then {private _rad = ((10 / (_dth * 0.017453)) max 4) min 400;   // R = arc / angle
                // corner speed = min(grip limit, YAW-RATE limit v=w*R). A 5m hairpin at 9 m/s needs
                // ~1.8 rad/s which the chassis can't do, so the turn-rate cap is the real limiter.
                private _vc = (sqrt (_grip * _rad * _cMargin)) min (2.0 * _rad);
                // plan braking conservatively (~0.4x real) so it slows EARLY with margin
                private _vEntry = sqrt ((_vc * _vc) + (0.8 * _brake * _d));
                _target = _target min _vEntry;
                if (_d <= 22) then { _nearVc = _nearVc min _vc; };   // imminent corner -> hard clamp below
            };};
        private _left = _total - _s;
        if (_left < 60) then { _target = _target min (((_left - 8) max 0) / 2.5); };

        // obstacle brake: people/vehicles genuinely in front. The probe is sized from BRAKING
        // PHYSICS (v^2/2a), not linearly -- a linear probe saw ~70m at Mad Max speed while the
        // stop needs ~124m, so parked trucks were inside the point of no return before detection.
        // Speed law per obstacle: v_allowed = sqrt(2a * (dist - 7)) -> smooth approach, full stop
        // 7m short, never a binary slam.
        private _brakeD = 12 + (_spd * _spd) / 9;
        private _aheadC = (getPosATL _veh) vectorAdd [_dirX * _brakeD * 0.55, _dirY * _brakeD * 0.55, 0];
        private _obsMin = 1e9; {if (_x isNotEqualTo _veh && {!(_x in crew _veh)} && {alive _x}) then {
                private _ox = ((getPosATL _x) select 0) - (_pos select 0);
                private _oy = ((getPosATL _x) select 1) - (_pos select 1);
                private _rel = _ox * _dirX + _oy * _dirY;
                private _lat = _ox * _dirY - _oy * _dirX;
                // in front AND within our lane corridor -- without the lateral gate, parked cars
                // and oncoming traffic in the other lane parked us (and two APs deadlocked head-on)
                if (_rel > 2 && {abs _lat < 3.2}) then {
                    // 13m margin is ORIGIN-to-origin: a truck's half-length + our nose ate the old 7m
                    _target = _target min (sqrt ((11 * ((_rel - 13) max 0)) max 0));
                    _obsMin = _obsMin min _rel;};};
        } forEach (_aheadC nearEntities [["Car", "Tank", "Air", "Ship", "CAManBase"], _brakeD * 0.6]);

        // integrate commanded speed. Decel is FAR harder than accel -- a car brakes way faster than
        // it speeds up, and cmdSpd MUST track a falling corner-limit down or it arrives too fast
        // (the wall). -14 m/s^2 keeps cmdSpd pinned to the vEntry curve; +3.4 keeps speedups smooth.
        private _dt = diag_deltaTime min 0.1;
        private _accel = ((_target - _spd) max -14) min 3.4;
        private _newSpd = (_spd + _accel * _dt) max 0;
        _newSpd = _newSpd min _nearVc;   // HARD clamp to the imminent corner speed -- guarantees the
                                          // car is slow enough to physically make the turn at the apex
                                          // even if the ramp lagged the falling target
        if (_obsMin < 12) then { _newSpd = 0; };   // inside the bumper zone: full stop, no creep
        AP_gpsAPSpd = _newSpd;
        AP_gpsAPS = (_s + _newSpd * _dt) min _total;   // arc advances by commanded speed (known-good, smooth)

        // arrival: BRAKE TO A STOP, then disengage. Command 0 inside 14m; only cut autopilot once
        // the car is actually stopped (else it disengages mid-roll and coasts into the nearest thing).
        if (_left < 14) then { _newSpd = 0; AP_gpsAPSpd = 0; };
        if (_left < 14 && {(abs speed _veh) / 3.6 < 0.8}) exitWith {_veh setVelocity [0, 0, 0];
            ["stop", "destination reached"] call AP_fnc_gpsAutopilot;   // stop re-arms brakes -> holds
        };

        // Physics-legal drive (setVelocityModelSpace + setAngularVelocity) -- must run where the
        // vehicle is LOCAL or the owning client and this fight over position (rubberbanding). The
        // autopilot runs on the engaging driver's client, who owns the car; guard anyway.
        if (!local _veh) exitWith {};

        // STEER via PURE PURSUIT: aim at a lane-offset point a lookahead distance AHEAD (not just
        // align to the tangent -- that can't correct lateral drift, hence the weave). Bearing from
        // the CAR to the aim point self-corrects offset; longer lookahead = calmer. PD control (P +
        // damping on the current yaw rate) kills overshoot oscillation. A real physics turn -> smooth.
        private _La = 10 + _newSpd * 0.9;                       // lookahead grows with speed for stability
        _La = (_La * (1 - ((_bendAhead / 55) min 0.7))) max 4.5;   // shrink into sharp bends (aim IN, not past)
        private _lp = [_s + _La] call _fnSample;
        private _ld2 = [_s + _La + 4] call _fnSample;
        private _lx = (_ld2 select 0) - (_lp select 0);
        private _ly = (_ld2 select 1) - (_lp select 1);
        private _ln = sqrt (_lx * _lx + _ly * _ly) max 0.01;
        _lx = _lx / _ln; _ly = _ly / _ln;
        // lane offset straightens toward road-center on sharp bends so the aim isn't shoved to the
        // OUTSIDE of the turn (which widened the line into the outer building on hairpins)
        private _laneOff = 2.2 * (1 - ((_bendAhead / 45) min 0.9));
        private _aimX = (_lp select 0) + _ly * _laneOff;
        private _aimY = (_lp select 1) - _lx * _laneOff;
        private _want = ((_aimX - (_pos select 0)) atan2 ((_aimY - (_pos select 1))));
        private _yawErr = ((_want - getDir _veh + 540) mod 360) - 180;   // signed deg
        private _curYaw = (angularVelocity _veh) select 2;     // rad/s (what we set last frame ~ physical)
        private _yawCmd = ((_yawErr * 0.04) - (_curYaw * 0.26)) max -2.3 min 2.3;   // PD, higher cap for tight hairpins
        // steering is applied BELOW (after the yaw-scrub) so the low-speed setDir path can override the damped
        // setAngularVelocity -- see the crawl-fix block just before setVelocityModelSpace.
        if (time >= (missionNamespace getVariable ["AP_gpsAPTlog", 0])) then {AP_gpsAPTlog = time + 0.35;
            diag_log format ["[ap] s=%1 target=%2 cmdSpd=%3 realSpd=%4 | scanSharp=%5deg@%6m bendNear=%7 | La=%8 err=%9 laneOff=%10",
                round _s, _target toFixed 1, _newSpd toFixed 1, round ((speed _veh)/3.6),
                round _dbgSharp, round _dbgSharpD, round _bendAhead, _La toFixed 1, round _yawErr, _laneOff toFixed 1];};

        // CRASH LOGGER (owner 2026-07-12): a sudden hard deceleration while we're still commanding
        // speed = the car hit something. Identify what (ray ahead, then damage-source, then nearest
        // structure) and log it to the DB `log` table under -APCRASH- with full telemetry, so crash
        // spots can be pulled and tuned. Throttled to one entry per collision.
        private _realNow = (abs speed _veh) / 3.6;
        private _realPrev = missionNamespace getVariable ["AP_gpsAPRealPrev", _realNow];
        AP_gpsAPRealPrev = _realNow;
        if ((_realPrev - _realNow) > 6 && {_realNow < (_newSpd - 4)} && {time > (missionNamespace getVariable ["AP_gpsAPCrashT", 0])}) then {
            AP_gpsAPCrashT = time + 4;
            private _fwd = [sin (getDir _veh), cos (getDir _veh), 0];
            private _fp = (getPosASL _veh) vectorAdd [0, 0, 0.6];
            private _hitObjs = lineIntersectsObjs [_fp, (_fp vectorAdd (_fwd vectorMultiply 7)), _veh, objNull, true];
            private _hit = _hitObjs param [0, objNull];
            if (isNull _hit) then {
                _hit = ((nearestObjects [_veh, [], 7]) select { _x isNotEqualTo _veh && {!(_x isKindOf "CAManBase")} && {!(_x in [player, vehicle player])} }) param [0, objNull];
            };
            private _hitStr = if (isNull _hit) then { "terrain/unknown" } else { format ["%1 [%2]", typeOf _hit, getText (configOf _hit >> "displayName")] };
            private _msg = format ["AP CRASH mode=%1 hit=%2 grid=%3 pos=%4 | impactSpd=%5 cmdSpd=%6 target=%7 nearBend=%8 sharpBend=%9deg@%10m yawErr=%11 La=%12 route_s=%13/%14",
                missionNamespace getVariable ["AP_gpsAPMode", "?"], _hitStr, mapGridPosition _veh, (getPosATL _veh) apply { round _x },
                round _realPrev, _newSpd toFixed 1, _target toFixed 1, round _bendAhead, round _dbgSharp, round _dbgSharpD,
                round _yawErr, _La toFixed 1, round _s, round _total];
            [["-APCRASH-", player, _msg], "APS_fnc_logIt", 2] call AP_fnc_MP;
            diag_log format ["[ap] CRASH LOGGED: %1", _msg];};

        // owner 2026-07-14 (APCRASH tune): YAW-ERROR SPEED CUT. Both logged crashes were the car badly
        // off-heading (yawErr 34deg / 81deg) careening off while the steering PD saturated at its +/-2.3 cap.
        // When we're fighting the wheel, scrub forward speed so the chassis can rotate back onto line before it
        // understeers into terrain. Full speed under 22deg error, scaling down to 35% by ~70deg.
        // crawl-fix (ported from fn_hcDrive 2026-07-17): only scrub at SPEED. At low speed setAngularVelocity is
        // damped, so slowing doesn't help the car rotate -- it just deepens a yaw-error/speed death-spiral that pins
        // the autopilot at a crawl. Below 10 m/s keep the speed and force the turn with setDir instead.
        if (abs _yawErr > 22 && {_newSpd > 10}) then {_newSpd = _newSpd * ((1 - (((abs _yawErr) - 22) / 48)) max 0.5);};

        // LOW-SPEED STEERING (ported from hcDrive; NEEDS IN-SEAT TEST -- a player in the driver seat may change the
        // low-speed yaw damping vs an empty van). setAngularVelocity is damped on a grounded car at low speed, so a
        // slow car can't rotate onto a bend and crawls. Below 9 m/s force the heading with setDir (undampable, capped
        // per frame for smoothness); above that the physics-legal setAngularVelocity stays smooth in the seat.
        private _lowSpeedTurn = (_newSpd < 9) && {(abs _yawErr) > 8};
        if (_lowSpeedTurn) then { _veh setDir ((getDir _veh) + (_yawErr max -6 min 6)); } else { _veh setAngularVelocity [0, 0, _yawCmd]; };

        // THROTTLE via model-space velocity: forward (model Y) at commanded speed; keep the current
        // model-space vertical so gravity + suspension own Z (seat on road / climb / bridges, free).
        // Autobrake disabled at engage, so this actually moves the car; physics motion syncs smoothly.
        private _vzM = (velocityModelSpace _veh) select 2;
        _veh setVelocityModelSpace [0, _newSpd, _vzM];

        // stuck watchdog: the car now moves via real physics, so `speed` is truthful
        if (time >= (missionNamespace getVariable ["AP_gpsAPChkT", 0])) then {AP_gpsAPChkT = time + 1.5;
            if (_newSpd > 5 && {(abs speed _veh) / 3.6 < 1.5}) exitWith {AP_gpsAPSpd = 0;
                ["stop", "blocked -- take the wheel"] call AP_fnc_gpsAutopilot;};};};};
