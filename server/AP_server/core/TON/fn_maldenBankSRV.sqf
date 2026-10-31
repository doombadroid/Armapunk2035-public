/*
    APS_fnc_maldenBankSRV -- the Malden bank's door.

    The 15-minute drill, the payout, the MaxTac call and the cop's Disable Drill are all unchanged in
    fn_bankDrillVault; what did not exist on this map were the three names that code addresses:
    the AP_bank_door / _2 markers and the AP_bank_building object. This binds them.

    THE DOOR IS A BACK-ALLEY GATE, not Altis's vault. The Altis code animates "door_4_rot", which this
    class does not have, so the animation names are ENUMERATED at boot and logged rather than assumed,
    and everything door-ish is driven. The class is NOT unique on this map -- there are more of them at
    the Federal Reserve -- so the gate is resolved by proximity to the owner's coordinate, never by a
    class scan. (Measured from mission.sqm: the match is 0.66 m away and the next Land_BackAlley_01_l_gate_F
    on this map is 1510 m away, so the 10 m radius cannot pick the wrong one.)

    NOT REMOTE-EXECUTABLE. Unlike APS_fnc_maldenFedSRV this function has NO CfgRE.hpp entry and nothing
    client-side calls it, so a client cannot reach any mode here and the modes are not caller-guarded.
    Do NOT "harden" ["open"] with a remoteExecutedOwner check: the drill calls it from inside a spawned
    loop, and whether a spawned child inherits its parent's remoteExecutedOwner is undocumented -- the
    BIKI only says the value holds "in this scope". A guard that is wrong about that would make the mode
    refuse ITSELF and the gate would silently never open, which is the exact failure the Fed's internal
    modes are keyed to avoid. If this function is ever whitelisted, guard it the way the Fed does
    (a server-only key generated at boot and never publicVariable'd), not with a caller check.

    MODES
      ["boot"]   resolve, bind, log, lock
      ["open"]   drill succeeded: unlock and swing
      ["seal"]   grab window over (or boot): lock and shut
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]]];
if (_mode isEqualTo "open") then { if (!isNil "AP_fnc_telemetryEvent") then { ["robbery_bank"] call AP_fnc_telemetryEvent; }; };   // telemetry event counter

AP_BANK_GATEPOS  = [6234.72, 2863.93, 0.34];
AP_BANK_CASESPOS = [6228.43, 2864.01, 0.38];

// ---- the animations worth driving. Land_BackAlley_01_l_gate_F carries door_1_rot, door_1_locked_rot,
//      door_1_handle_rot_1/2 and door_1_handle_locked_rot; the _locked_ pair belongs to the engine's
//      "it's locked" handle jiggle (BIS_fnc_Door drives Door_1_locked_source when bis_disabled_Door_1
//      is 1), so driving those ourselves would fight it. Everything door-ish EXCEPT the locked variants.
private _fnc_doorAnims = {
    params ["_obj"];
    (animationNames _obj) select {
        private _a = toLower _x;
        ((_a find "door") >= 0 || {(_a find "gate") >= 0}) && {(_a find "locked") isEqualTo -1}
    }
};

// ---- the ANIMATION SOURCES behind those same animations. animate alone is not enough: a source is a
//      controller that keeps driving its animation, so one left at the wrong phase overrides whatever
//      animate set and the gate stays that way until a restart. That is reachable in normal play --
//      during the 3-minute grab window bis_disabled_Door_1 is 0, so the class's own "Open Door" scroll
//      action runs, and BIS_fnc_Door (a3\structures_f\scripts\fn_Door.sqf) drives BOTH
//      Door_1_sound_source and Door_1_noSound_source; the later seal's animate would not undo it.
//      Read out of the game's own data, not assumed: CfgVehicles >> Land_BackAlley_01_l_gate_F >>
//      AnimationSources declares Door_1_sound_source, Door_1_noSound_source and Door_1_locked_source,
//      and BackAlley_01_l_gate_F.p3d binds door_1_rot (the leaf) to the sound source and
//      door_1_handle_rot_1/2 (the handles) to the noSound one -- exactly the three _fnc_doorAnims
//      returns. The _locked_ source is deliberately NOT driven: that is the engine's locked-handle
//      jiggle (fn_Door's else branch), and fighting it is what the header warns about.
//      Same shape as the Fed's gate -- APS_fnc_fedLockdown and APS_fnc_maldenFedSRV case "gate".
private _fnc_doorSources = {
    params ["_obj", "_phase"];
    { _obj animateSource [_x, _phase]; } forEach ["door_1_sound_source", "door_1_noSound_source"];
};

switch (toLower _mode) do {

    case "boot": {
        private _g = (nearestObjects [AP_BANK_GATEPOS, ["Land_BackAlley_01_l_gate_F"], 10]) param [0, objNull];
        AP_bankGate = _g;
        publicVariable "AP_bankGate";
        if (isNull _g) exitWith {
            diag_log format ["[maldenBank] NO GATE within 10 m of %1 -- the bank is unwired", AP_BANK_GATEPOS]; };

        AP_bank_building = _g;      // dispatch position, alarm source, crew-holding radius
        publicVariable "AP_bank_building";

        diag_log format ["[maldenBank] gate = %1 at %2, %3 m from the brief",
            typeOf _g, getPosATL _g, ((getPosATL _g) distance AP_BANK_GATEPOS) toFixed 1];
        diag_log format ["[maldenBank] gate animations = %1", animationNames _g];
        diag_log format ["[maldenBank] gate DOOR animations = %1 (these are the ones driven)", [_g] call _fnc_doorAnims];
        diag_log format ["[maldenBank] gate numberOfDoors = %1",
            getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors")];

        ["seal"] call APS_fnc_maldenBankSRV;
    };

    case "seal": {
        private _g = missionNamespace getVariable ["AP_bankGate", objNull];
        if (isNull _g) exitWith {};
        private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors");
        for "_i" from 1 to _n do { _g setVariable [format ["bis_disabled_Door_%1", _i], 1, true]; };
        { _g animate [_x, 0, true]; } forEach ([_g] call _fnc_doorAnims);
        [_g, 0] call _fnc_doorSources;
        _g setVariable ["gate_max", 0, true];
        diag_log "[maldenBank] gate SEALED";
    };

    case "open": {
        private _g = missionNamespace getVariable ["AP_bankGate", objNull];
        if (isNull _g) exitWith {};
        private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _g) >> "numberOfDoors");
        for "_i" from 1 to _n do { _g setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
        { _g animate [_x, 1, true]; } forEach ([_g] call _fnc_doorAnims);
        [_g, 1] call _fnc_doorSources;
        _g setVariable ["gate_max", 1, true];
        diag_log "[maldenBank] gate OPEN";
    };

    default { diag_log format ["[maldenBank] unknown mode '%1'", _mode]; };
};
true
