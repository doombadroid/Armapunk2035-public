/*
    AP_fnc_hcFlyAI  (Armapunk 2035, 2026-09-02) -- HEADLESS ROTORCRAFT AUTOPILOT, ENGINE-AI FLAVOUR.

    The aircraft carries a real (captive, invisible) AI pilot whose group is local HERE; the engine's own
    helicopter AI flies it (doMove + flyInHeight) and lands it on an invisible helipad dropped at the
    destination (`land` picks the nearest H, and the fabricator anchors are helipads too, so ours must be
    the nearest). Real physics -> real velocity -> every observer sees a helicopter fly, where the scripted
    core (AP_fnc_hcFly) is kinematic: an unmanned airframe ignores setVelocity and a piloted one accepts
    the value but hover-holds anyway (measured b0838-b0847, see arma-unmanned-rotorcraft-kinematic).

    In:  [_veh, _dest]   Out: true if started.  Same contract as AP_fnc_hcFly: hc_ap_driving while en
    route, hc_ap_done at the end ("landed" | "wrecked" | "timeout" | "lostlocality" | "aborted" |
    "vanished"), re-reads hc_ap_dest (a walking summoner: the pad and the move order follow).
*/
params [["_veh", objNull, [objNull]], ["_dest", [0, 0, 0], [[]]]];
if (isNull _veh || {!local _veh}) exitWith { false };
if !([_veh] call AP_fnc_isRotorcraft) exitWith { false };
private _pilot = driver _veh;
if (isNull _pilot || {!local _pilot}) exitWith { false };
if (_veh getVariable ["hc_ap_driving", false]) exitWith { false };

if (_veh getVariable ["hc_ap_lock", false]) then { _veh lock 2; };
_veh setVariable ["hc_ap_abort", false, true];
_veh setVariable ["hc_ap_driving", true, true];
_veh setVariable ["hc_ap_done", "", true];
[_veh] call AP_fnc_hcShield;

[_veh, _pilot, _dest] spawn {
    params ["_veh", "_pilot", "_dest"];
    private _grp = group _pilot;
    _grp setBehaviour "CARELESS"; _grp setCombatMode "BLUE"; _grp setSpeedMode "FULL";
    _pilot allowFleeing 0;
    _veh engineOn true;
    _pilot enableAI "ALL";   // seated with AI off on the server; it flies from HERE
    _pilot allowDamage false; _pilot setCaptive true;   // local-effect on the server; re-applied where he now lives
    // A VTOL is flown by the AI as a plane: 245 km/h cruise, then it tried to land at that speed and hit the
    // ground 500 m short (b0853). Cap it, and slow it to hover speed before the landing order.
    private _isVtol = _veh isKindOf "Plane";
    if (_isVtol) then { _veh limitSpeed 150; };
    // this machine streams the designer's map around its jobs (init.sqf, 2026-09-07): the cruise sampler and
    // the landing picker below ray-cast and search LOCAL objects, so wait (<= 12 s) for the destination's cell
    private _cells = localNamespace getVariable "AP_mapCells";   // streamer stores: localNamespace (AP_fnc_mapStreamInit)
    if (!isNil "_cells") then {
        private _k = [_dest, -1] call AP_fnc_mapCellFor;
        private _tW = time + 20;
        waitUntil { uiSleep 0.5; (_cells getOrDefault [_k, "none"]) isEqualTo "loaded" || {time > _tW} };
        // "loaded" is the blob in hand; the objects come from the streamer's next create pass. Two full ticks
        // (b1010: picked 3 s before the pass that made 1686 objects, mapLive=0)
        private _n0 = missionNamespace getVariable ["AP_mapTickN", 0];
        waitUntil { uiSleep 0.5; (missionNamespace getVariable ["AP_mapTickN", 0]) >= _n0 + 2 || {time > _tW} };
        diag_log format ["HCFLYAI map: cell %1 %2, %3 live objects here, far %4", _k, _cells getOrDefault [_k, "none"], count (localNamespace getVariable "AP_mapLive"), _cells getOrDefault ["far", "none"]];
    };
    // cruise from the object-aware sampler, expressed AGL over the start (flyInHeight is ground-relative)
    private _alt = (([getPosASL _veh, _dest, _veh] call AP_fnc_flyCruiseAlt) - (getTerrainHeightASL (getPosASL _veh))) max 100;
    _veh flyInHeight _alt;
    // The pad -- and the move order -- go on the CLEAR spot nearest the summoner (AP_fnc_flyLandSpot), never
    // on the summoner's own feet: `land` sets the aircraft down ON the pad wherever it is, and a pad in a town
    // plaza put three Orcas down among the vending rows (2026-09-07). No spot within 150 m: the AI still flies
    // to the summoner but the landing goes to the scripted core, which hovers beside them for boarding.
    private _destSeen = [_dest select 0, _dest select 1, 0];   // the summoner's position the pad was picked for
    private _spot = [_destSeen, _veh] call AP_fnc_flyLandSpot;
    private _cur = if (_spot isEqualTo []) then { _destSeen } else { [_spot select 0, _spot select 1, 0] };
    private _pad = createVehicle ["Land_HelipadEmpty_F", _cur, [], 0, "CAN_COLLIDE"];
    // Steering: the group-level `move` (an internal waypoint -- addWaypoint is a disabled command on this
    // machine, b0851) plus the low-level doMove, RE-ISSUED every 8 s: a single doMove at engage left the
    // aircraft hovering at cruise height for the whole budget (b0850), the take-off routine ate it.
    private _steer = { params ["_g", "_p", "_to"]; _g move _to; _p doMove _to; };
    [_grp, _pilot, _cur] call _steer;
    private _steerT = time + 8;
    private _end = time + 280; private _reason = ""; private _landing = false; private _probeT = 0; private _landT = 0; private _landT0 = 0; private _nearT0 = -1; private _gearDown = false;
    diag_log format ["HCFLYAI start: veh=%1 pilot=%2 dest=%3 pad=%4 (%5 m from the summoner) alt=%6", _veh, typeOf _pilot, _destSeen apply { round _x }, _cur apply { round _x }, round (_cur distance2D _destSeen), round _alt];
    while { !isNull _veh && {alive _veh} && {local _veh} && {alive _pilot} && {time < _end} && {!(_veh getVariable ["hc_ap_abort", false])} } do {
        uiSleep 1;
        if (_reason isNotEqualTo "") exitWith {};
        // the summoner walked > 25 m: pick again around where they are now; the pad and the move order follow
        // only if the spot itself moved (a walk within the same open field keeps the pad)
        private _d = _veh getVariable ["hc_ap_dest", _destSeen];
        if (_d isEqualType [] && {count _d >= 2} && {(_d distance2D _destSeen) > 25} && {!_landing}) then {
            _destSeen = [_d select 0, _d select 1, 0];
            _spot = [_destSeen, _veh] call AP_fnc_flyLandSpot;
            private _new = if (_spot isEqualTo []) then { _destSeen } else { [_spot select 0, _spot select 1, 0] };
            if ((_new distance2D _cur) > 5) then { _cur = _new; _pad setPos _cur; [_grp, _pilot, _cur] call _steer; };
        };
        if (!_landing && {time >= _steerT}) then { _steerT = time + 8; [_grp, _pilot, _cur] call _steer; };
        private _dist = _veh distance2D _cur;
        // descend early, but order the landing only once it has ARRIVED over the pad (moving or stopped):
        // a `land` issued 209 m out broke off the move and left it hovering at 49 m with no pad below (b0852).
        // Re-issued every 12 s until it commits.
        // VTOL: the engine AI cannot land one at a spot (it ignores the speed cap, overshoots at 190 km/h and
        // flies into the ground -- b0856; the wiki: "a VTOL will just land somewhere"). Hand the last 300 m to
        // the scripted core: pilot out, kinematic descent and touchdown over the isFlatEmpty spot.
        // VTOL: the engine AI flies it as a plane and cannot be slowed (limitSpeed and forceSpeed both ignored,
        // 138 km/h over the pad at 49 m, b0867) or spot-landed, so it comes down to 40 m early and the last
        // 200 m are handed to the scripted core. That segment is the only kinematic flight left.
        // gear down EARLY, by the pilot: the animation only runs with crew aboard (it froze half-way when he
        // left at the hand-over, b0872) -- ordered once, 700 m out, it is fully down by 200 m
        if (_isVtol && {!_landing} && {_dist < 700}) then {
            _veh flyInHeight 40;
            if (!_gearDown) then { _gearDown = true; _pilot action ["landGear", _veh]; };
        };
        if (_isVtol && {_dist < 200}) exitWith { _reason = "handover"; };
        if (!_landing && {_dist < 250}) then { _veh flyInHeight 40; };
        // the AI's move completes at a radius it picks (84 m one run, 12 m another -- b0858/b0853), so the
        // landing is ordered as soon as it is near AND slow; the pad at the exact destination draws it in
        if (_dist < 150 && {(speed _veh) < 40} && {time >= _landT}) then {
            // `land` picks the NEAREST invisible H: a fabricator anchor or another summon's pad within 80 m
            // would win over ours -- let the scripted core land it over the exact spot instead. No proven spot
            // (a town with nothing clear within 150 m): the core hovers beside the summoner rather than the AI
            // setting down on an untested pad.
            if (_spot isEqualTo [] || {count (nearestObjects [_cur, ["Land_HelipadEmpty_F"], 80]) > 1}) then { _reason = "handover"; } else {
            if (!_landing) then { _landT0 = time; };
            _landing = true; _landT = time + 12;
            _veh land "LAND";
            };
        };
        // a helicopter the AI has not set down 60 s after the first order (a town square with no spot it
        // likes) goes to the scripted core, which lands it or hovers at 2 m for boarding
        if (_landing && {time - _landT0 > 60}) exitWith { _reason = "handover"; };
        // stalled near the target without ever getting a landing order (hovering out of the 150 m ring)
        if (!_landing && {_dist < 300} && {(speed _veh) < 10}) then { if (_nearT0 < 0) then { _nearT0 = time; }; } else { _nearT0 = -1; };
        if (_nearT0 > 0 && {time - _nearT0 > 30}) exitWith { _reason = "handover"; };
        if (_landing && {(isTouchingGround _veh || {((getPos _veh) select 2) < 1.2})} && {(speed _veh) < 3}) exitWith { _reason = "landed"; };
        if ((_veh getVariable ["hc_ap_probe", false]) && {time >= _probeT}) then {
            _probeT = time + 2;
            diag_log format ["[HCFLYAI-PROBE] dist=%1 spd=%2 vel=%3 agl=%4 ground=%5 landing=%6 pos=%7", round _dist, round (speed _veh),
                (velocity _veh) apply { round _x }, round ((getPos _veh) select 2), isTouchingGround _veh, _landing, (getPosATL _veh) apply { round _x }];
        };
    };
    if (_reason isEqualTo "") then {
        _reason = call {
            if (isNull _veh) exitWith { "vanished" };
            if (!alive _veh) exitWith { "wrecked" };
            if (isNull _pilot || {!alive _pilot}) exitWith { "handover" };   // the airframe is intact: the scripted core lands it
            if (!(local _veh)) exitWith { "lostlocality" };
            if (_veh getVariable ["hc_ap_abort", false]) exitWith { "aborted" };
            if (time >= _end) exitWith { "timeout" };
            "interrupted"
        };
    };
    diag_log format ["HCFLYAI end: veh=%1 reason=%2 alive=%3 pos=%4 padDist=%5 ground=%6", _veh, _reason, alive _veh,
        (if (isNull _veh) then { [] } else { (getPosATL _veh) apply { round _x } }), (if (isNull _veh) then { -1 } else { round (_veh distance2D _cur) }), (!isNull _veh && {isTouchingGround _veh})];
    if (!isNull _pad) then { deleteVehicle _pad; };
    if (!isNull _veh) then {
        private _eh = _veh getVariable ["hc_ap_dmgEH", -1];
        if (_eh >= 0) then { _veh removeEventHandler ["HandleDamage", _eh]; _veh setVariable ["hc_ap_dmgEH", nil]; };
        if (!isNull _pilot && {local _pilot}) then { doStop _pilot; };
        // LANDED: the pilot's AI off and the engine off BEFORE the server hears of it. The hull goes back to the
        // server with him aboard, and an AI pilot with a running engine and no orders lifts off the moment his
        // locality changes; the server then pulls him out a few metres up -- "it lands, goes up a bit and drops"
        // (owner, b1010). Both commands need locality, which this machine still has here.
        if (_reason isEqualTo "landed") then {
            if (!isNull _pilot && {local _pilot}) then { _pilot disableAI "ALL"; };
            _veh engineOn false;
        };
        _veh setVariable ["hc_ap_driving", false, true];
        if (_reason isEqualTo "handover") then {
            // pilot out and gone (the airframe stays local here), then the scripted core finishes the flight
            // and publishes hc_ap_done itself
            // gear down BY THE PILOT before he leaves: the engine honours the action for a unit acting from the
            // seat, and ignores it on an empty hull (gear phase stayed 1 through two landings, b0870/b0871)
            // The pilot STAYS for the scripted descent, AI off: the engine's AI owns the gear while it flies
            // (lowered it one run, re-retracted it the next) and the gear animation freezes the moment the crew
            // leaves. AI off, he lowers it and sits still; the core moves the airframe kinematically with him
            // aboard (fly_forceKinematic); the server removes him on arrival like any pilot.
            if (!isNull _pilot) then {
                _pilot disableAI "ALL";
                if (_isVtol) then { _veh land "LAND"; _pilot action ["landGear", _veh]; };   // landing mode: the engine itself extends gear in it
                _veh setVariable ["fly_forceKinematic", true];
                diag_log format ["HCFLYAI hand-over: pilot stays (AI off), gear phase %1", _veh animationSourcePhase "gear"];
            };
            _veh setVariable ["hc_ap_ai", false, true];
            _veh setVariable ["fly_phase", "", true];
            _veh setVariable ["fly_alt", nil];
            // cap the core's cruise: clear the objects on the last stretch by 20 m, never climb back to 250 m
            // (the long kinematic descent is what the summoner watched "teleport", 2026-09-03)
            _veh setVariable ["fly_altCap", ((getPosASL _veh) select 2) max ([getPosASL _veh, _cur, _veh, 20, 30] call AP_fnc_flyCruiseAlt)];
            // the core is given the SUMMONER's position: it runs the same picker and lands on the same spot (the
            // aircraft and its pilot are ignored by the search), and hc_ap_dest keeps following them
            if !([_veh, _destSeen, ((_end - time) max 60)] call AP_fnc_hcFly) then {
                _veh setVariable ["hc_ap_want", false, true];
                _veh setVariable ["hc_ap_done", (["interrupted", "lostlocality"] select (!isNull _veh && {!(local _veh)})), true];
            };
        } else {
            _veh setVariable ["hc_ap_want", false, true];
            _veh setVariable ["hc_ap_done", _reason, true];
        };
    };
};
true
