/*
    APS_fnc_fedAirDefenseSRV -- the Federal Reserve platform's anti-air umbrella.

    THE WHOLE ISLAND, not just the Fed. The first cut of this covered a 260 m bubble around the Fed
    platform's dome and the owner promptly landed 1.45 km away, unopposed. Flood-filling the land
    under that landing spot with the engine's own water test gives the real thing: an island
    x 9184..12059, y 2680..4880 -- 2.9 x 2.2 km, separated from the mainland by a channel to the
    west -- carrying the prison, the Response Police HQ, the designer's "Defense Systems" marker and,
    at its eastern edge, the Fed platform. All of it is defended.

    The zone is a RECTANGLE, not a radius: a circle big enough to hold a 2.9 km island spills across
    the channel and would engage aircraft over the mainland shore.

    WHY IT IS SERVER-SIDE. Altis's evidence lockup does the same job in fn_evidenceDefense.sqf, which
    runs on the PILOT'S OWN CLIENT -- a modified client simply never runs it, and the whole defence
    evaporates. This one runs on the server, so the aircraft is engaged whether or not the pilot's
    machine cooperates. The only client-side part is the warning on his screen.

    WHAT IT ENGAGES (owner 2026-07-27): civilian-flown aircraft, matching the evidence lockup -- cops
    and medics pass. Inside the ring, below the ceiling, and either LOW or SLOW: a fast high transit
    is left alone, anything that could put wheels down is not. Four seconds of siren, then a salvo
    from three points around the platform.

    IT CRIPPLES, IT DOES NOT KILL. Engine and rotors are destroyed and the fuel is gone; the airframe
    is left at 0.8 so the pilot gets an autorotation and a chance at the water. Aircraft that stay in
    the ring get engaged again after the cooldown.

    Disabling the system is a later job -- it reads AP_fedAirDefense every pass, so the future hack
    only has to set that false (and publicVariable it) for the umbrella to go down.
*/
if (!isServer) exitWith {};

AP_fedAD_centre  = [10622.0, 3780.6];      // island bbox centre (flood fill, 25 m grid)
AP_fedAD_area    = [[10622.0, 3780.6], 1520, 1180, 0, true];   // inArea rectangle: island + ~80 m of shore
AP_fedAirDefense = true;                   // the future hack flips this
publicVariable "AP_fedAD_centre";
publicVariable "AP_fedAD_area";
publicVariable "AP_fedAirDefense";

private _ceiling  = 400;                    // above this it is a transit, not an approach -- ignored
private _lowAGL   = 120;                    // below this you could be lining up
private _slowKPH  = 90;                     // or slow enough to be lining up
private _warnTime = 4;                      // siren before the salvo (Altis took ~11 s to launch)
private _cooldown = 25;                     // per airframe, so a falling wreck is not re-engaged
private _mSpeed   = 400;                    // m/s (Altis: 105)
// Batteries spread over the island so the missiles come from somewhere near you rather than always
// from the Fed. Each was confirmed to sit on THIS landmass by the flood fill.
private _sites = [[9643.8, 3319.9, 30],     // the designer's "Defense Systems" marker
                  [9765.1, 3895.3, 30],     // by the prison
                  [10494.1, 4055.6, 30],    // by the Response Police HQ
                  [11197.8, 4459.3, 30],    // the Fed platform
                  [10622.0, 3780.6, 40]];   // island centre

// ---- cripple: kill what makes it fly, leave the airframe flyable-ish on the way down
AP_fnc_fedADCripple = compileFinal {
    params ["_veh"];
    // enumerate the hitpoints this airframe ACTUALLY has -- setHitPointDamage on a name a vehicle
    // does not carry is an error, and helicopters, planes and VTOLs each name theirs differently
    // PROPULSION ONLY, and never to 1. HitFuel ruptures the tank and takes the airframe with it, and
    // a hitpoint pinned at exactly 1 can tip a vehicle into catastrophic failure -- both turn "cripple"
    // into "kill", which is not what was asked for. 0.9 stops the rotor without detonating anything.
    // ORDER MATTERS: setDamage REDISTRIBUTES across every hitpoint, so it has to come first -- doing
    // it last wiped the propulsion damage and left the whole airframe evenly at 0.7 (measured).
    if (damage _veh < 0.7) then { _veh setDamage 0.7 };
    // getAllHitPointsDamage hands back LOWERCASE names and `in` compares strings CASE-SENSITIVELY
    // (BIKI, in: "String comparison is case-sensitive"). Matching against CamelCase config names
    // therefore never fired once, and the airframe was only ever taking the setDamage above.
    private _hits = (getAllHitPointsDamage _veh) param [0, []];
    {
        if ((toLower _x) in ["hitengine", "hitengine1", "hitengine2", "hitengine3",
                             "hithrotor", "hitvrotor", "hittransmission", "hitlwing", "hitrwing"]) then {
            _veh setHitPointDamage [_x, 0.95];
        };
    } forEach _hits;
    _veh setFuel 0;
    _veh setVelocity ((velocity _veh) vectorAdd [0, 0, -4]);      // the hit should be felt, not just seen
};

// ---- one missile, steered by the server so every client sees the same thing
AP_fnc_fedADMissile = compileFinal {
    params ["_from", "_target", "_speed"];
    if (isNull _target) exitWith {};
    private _m = "M_Titan_AA_static" createVehicle _from;
    _m setPos _from;
    private _deadline = time + 12;
    while {alive _m && {!isNull _target} && {alive _target} && {time < _deadline}} do {
        private _tp = getPosASL _target;
        private _mp = getPosASL _m;
        private _dist = _mp distance _tp;
        if (_dist < 14) exitWith {
            [_target] call AP_fnc_fedADCripple;
            deleteVehicle _m;
        };
        private _travel = _dist / _speed;
        _m setDir (_mp getDir _tp);
        private _pitch = -(asin (((_mp select 2) - (_tp select 2)) / (_dist max 1)));
        [_m, _pitch, 0] call BIS_fnc_setPitchBank;
        _m setVelocity [((_tp select 0) - (_mp select 0)) / _travel,
                        ((_tp select 1) - (_mp select 1)) / _travel,
                        ((_tp select 2) - (_mp select 2)) / _travel];
        uiSleep 0.05;
    };
    if (!isNull _m) then { deleteVehicle _m };
};

// ---- warn, wait, re-check, salvo
AP_fnc_fedADEngage = compileFinal {
    params ["_veh", "_pilot", "_cfg"];
    _cfg params ["_launchers", "_speed", "_warnTime", "_radius", "_lowAGL", "_slowKPH", "_ceiling"];
    [[], "AP_fnc_fedAirLock", _pilot, false] spawn AP_fnc_MP;
    uiSleep _warnTime;
    if (isNull _veh || {!alive _veh} || {!AP_fedAirDefense}) exitWith {};
    // climbing out or running for it BREAKS the lock -- that is the counterplay the 4 s buys
    private _agl = (getPosATL _veh) select 2;
    private _still = (_veh inArea AP_fedAD_area)
                     && {_agl <= _ceiling}
                     && {_agl < _lowAGL || {(abs speed _veh) < _slowKPH}};
    if (!_still) exitWith {
        if (!isNull _pilot) then { [["Lock broken -- the Fed battery has lost you.", "basic"], "AP_fnc_handleMessage", _pilot, false] spawn AP_fnc_MP; };
    };
    // the three batteries nearest the target, so an intruder over the prison is not shot at by the Fed
    // keyed sort, not BIS_fnc_sortBy: its algorithm block runs in its own scope and cannot see _veh
    // (parameters arrive as _input0..9), so the distance would never have been computed against it
    private _ranked = _launchers apply { [_x distance2D _veh, _x] };
    _ranked sort true;
    private _near = (_ranked select [0, 3]) apply { _x select 1 };
    {
        [_x, _veh, _speed] spawn AP_fnc_fedADMissile;
        uiSleep 0.35;
    } forEach _near;
    diag_log format ["-FEDAA- engaged %1 flown by %2 at %3 (agl %4, %5 km/h)",
        typeOf _veh, name _pilot, getPosATL _veh, _agl toFixed 0, (abs speed _veh) toFixed 0];
};

diag_log format ["::LooneyBin:: FED AIR DEFENCE online -- island rect %1, %2 batteries, ceiling %3 m",
    AP_fedAD_area, count _sites, _ceiling];

private _cfg = [_sites, _mSpeed, _warnTime, 0, _lowAGL, _slowKPH, _ceiling];
while {true} do {
    if (AP_fedAirDefense) then {
        {
            private _veh = objectParent _x;
            if (isNull _veh) then { continue };
            if !(_veh isKindOf "Air") then { continue };
            if !((currentPilot _veh) isEqualTo _x) then { continue };
            if !(_veh inArea AP_fedAD_area) then { continue };
            private _agl = (getPosATL _veh) select 2;
            if (_agl > _ceiling) then { continue };                       // high transit, not our business
            if !(_agl < _lowAGL || {(abs speed _veh) < _slowKPH}) then { continue };
            if ((time - (_veh getVariable ["AP_fedADlast", -100000])) < _cooldown) then { continue };
            _veh setVariable ["AP_fedADlast", time];
            [_veh, _x, _cfg] spawn AP_fnc_fedADEngage;
        } forEach (allPlayers select { alive _x && {side _x isEqualTo civilian} });
    };
    uiSleep 1;
};
