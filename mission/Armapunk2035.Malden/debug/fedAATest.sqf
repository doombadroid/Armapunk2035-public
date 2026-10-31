/*
    debug/fedAATest.sqf -- TEMP, DEV ONLY. Remove the call site after reading the log.

    Fires the real battery at a spawned helicopter, because "it parsed" and "it flies a missile into
    an aircraft and cripples it" are different claims. Exercises the parts that would fail silently:
    the M_Titan_AA_static spawn, the steering loop, and whether the hitpoint names the cripple sets
    exist on an actual airframe.
*/
if (!isServer) exitWith {};
[] spawn {
    uiSleep 25;                                   // let AP_server define the helpers
    if (isNil "AP_fnc_fedADMissile") exitWith { diag_log "-FEDAATEST- AP_fnc_fedADMissile undefined -- the battery never started"; };
    private _heli = createVehicle ["B_Heli_Light_01_F", [11197.8, 4459.3, 40], [], 0, "CAN_COLLIDE"];
    _heli setPosATL [11197.8, 4459.3, 40];
    diag_log format ["-FEDAATEST- target %1 at %2, fuel %3, damage %4",
        typeOf _heli, getPosATL _heli, fuel _heli, damage _heli];
    // hold it in a hover: an unmanned helicopter dropped from 40 m destroys itself on impact, which
    // is what the first run of this test actually measured
    private _hold = [_heli] spawn {
        params ["_h"];
        while {!isNull _h && {alive _h}} do { _h setPosATL [11197.8, 4459.3, 40]; _h setVelocity [0, 0, 0]; uiSleep 0.2; };
    };
    [[11120, 4300, 26], _heli, 400] spawn AP_fnc_fedADMissile;
    uiSleep 10;
    terminate _hold;
    if (isNull _heli) exitWith { diag_log "-FEDAATEST- target is gone (destroyed outright -- that is a KILL, not a cripple)"; };
    private _all = getAllHitPointsDamage _heli;
    private _names = _all param [0, []];
    private _dmg = _all param [2, []];
    diag_log format ["-FEDAATEST- after: alive %1, damage %2, fuel %3", alive _heli, damage _heli, fuel _heli];
    // assert the SHAPE we want, rather than dumping 35 identical numbers: propulsion wrecked, airframe not
    private _prop = ["hitengine", "hithrotor", "hitvrotor", "hittransmission"];
    private _propDmg = []; private _otherDmg = [];
    {
        private _d = _dmg param [_forEachIndex, 0];
        if (toLower _x in _prop) then { _propDmg pushBack [_x, _d] } else { _otherDmg pushBack _d };
    } forEach _names;
    diag_log format ["-FEDAATEST- propulsion: %1", _propDmg];
    diag_log format ["-FEDAATEST- airframe max %1 (want < 1 = still flying), fuel %2, alive %3",
        (selectMax _otherDmg) toFixed 2, fuel _heli, alive _heli];
    deleteVehicle _heli;
    diag_log "-FEDAATEST- DONE";
};
