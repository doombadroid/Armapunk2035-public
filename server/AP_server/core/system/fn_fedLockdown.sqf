/*
    APS_fnc_fedLockdown -- put the Malden Federal Reserve back to a clean, robbable state.

    Was Altis-shaped: it searched 400 m of the fed marker for Land_Dome_Big_F domes,
    Land_Research_house_V1_F safes and Land_BarGate_F gates. Malden has NONE of those classes, so on
    this map it locked nothing at all and silently reported three zeroes. It now works off the anchors
    APS_fnc_maldenFedSRV resolves at boot: the perimeter gates and the ten Land_Medevac_house_V1_F
    safes from mission.sqm's FEDERAL RESERVE layer, and the dome (Land_Dome_Big_F) and the centre
    (Land_Medevac_HQ_V1_F), which are fn_mapData entries promoted to server-spawned objects -- so
    every anchor here is a real object with a real class, and none of them belongs to the terrain.

    EVERY PERIMETER GATE, NOT ONE (2026-07-29). This used to seal AP_fedGate singular, because the
    boot resolver only ever found one: it searched a 15 m bubble around the owner's breach anchor and
    the compound's other two Land_ConcreteWall_01_l_gate_F sit 65.27 m and 70.16 m away. Both were
    real vehicle entrances and neither had ever had a lock variable written to it by anything in this
    build. The resolver now publishes the whole set as AP_fedGates and this file seals all of it.
    AP_fedGate is untouched and still means the ONE breachable gate -- the client's breach path binds
    to it by name and must not be handed an array.
    The two Land_BackAlley_01_l_gate_F pedestrian gates in the same Eden layer are deliberately NOT in
    that list; the reasoning, and the boot log line that records the decision, are in case "boot" of
    APS_fnc_maldenFedSRV.

    "THE OPEN DOOR OPTION IS STILL THERE" IS NOT A FAILED LOCK. Read out of the game's own data for
    both gate classes: OpenDoor_1's condition is
        ((this animationSourcePhase 'Door_1_sound_source') < 0.5) && (cameraOn isKindOf 'CAManBase')
    -- it does NOT test bis_disabled_Door_1. Only CloseDoor_1 tests it. So the vanilla scroll entry is
    offered on a perfectly sealed gate, and using it drives BIS_fnc_Door, which DOES test the flag and
    plays the locked jiggle on Door_1_locked_source instead of opening. The same is true of
    Land_Dome_Big_F, Cargo_House_base_F (the ring safes) and Cargo_HQ_base_F (the centre). Judge the
    lock by the flag and the animationSourcePhase, never by the presence of the action.

    Idempotent by design -- boot, every reset and the admin's !srv resetfed all call it.
*/
private _fnc_seal = {
    params ["_obj"];
    if (isNull _obj) exitWith { false };
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _obj) >> "numberOfDoors");
    // CAPITAL D, FOR CONSISTENCY ONLY -- THE CASING WAS NEVER A BUG, AND THE NOTE THAT USED TO SIT
    // HERE WAS WRONG. Corrected 2026-07-29. It claimed setVariable keys are case-sensitive strings,
    // that the LOWERCASE "bis_disabled_door_%1" this line wrote until 4633e92 was therefore a key the
    // engine never read, and that the dome, the centre and all ten safes had consequently been
    // hand-openable at every phase since the fork. That explanation is FALSE in every part.
    // SQF variable names are CASE-INSENSITIVE. BIKI Identifier states it outright -- "Identifiers are
    // case-insensitive" -- and BIKI allVariables demonstrates the mechanism: its return value is
    // documented as "array of variable names. All names are in lower case (see toLower)", i.e. the
    // variable store folds case on the way in, for object namespaces as much as for missionNamespace.
    // "bis_disabled_door_1" and "bis_disabled_Door_1" are therefore THE SAME VARIABLE. The lowercase
    // spelling worked. The dome, the centre and the ten ring safes were locking correctly all along --
    // which is exactly what the owner reported ("the dome is fine").
    // The capital D is kept, and is worth keeping, purely because it matches the engine's own spelling
    // -- BIS_fnc_Door documents the key as "bis_disabled_Door_%1", and a3\structures_f\scripts\fn_Door.sqf
    // tests (_structure getVariable [format ["bis_disabled_Door_%1", _door], 0]) != 1 before driving
    // the sound + noSound sources -- and the other 25 write sites in this build. No behaviour rides on
    // it: writing it either way is correct, so do not "fix" it in either direction.
    // DO NOT RE-DERIVE A BUG FROM THIS LINE. The owner's "both gates are unlocked and can be manually
    // opened" had an entirely separate cause, fixed in e7e7c01 and described in this file's header:
    // two of the compound's three Land_ConcreteWall_01_l_gate_F sat 65.27 m and 70.16 m from the breach
    // anchor, outside the boot resolver's 15 m nearestObjects radius, so they were never resolved,
    // never published and never sealed by anything.
    for "_i" from 1 to _n do { _obj setVariable [format ["bis_disabled_Door_%1", _i], 1, true]; };
    // Corrected 2026-07-27: the dome and the centre turned out to be a real Land_Dome_Big_F and a
    // Land_Medevac_HQ_V1_F (fn_mapData entries, promoted to server-spawned in Task 3b), so both DO
    // report numberOfDoors and the loop above is live for them. Shutting every animation source on
    // top of that is what the Altis lockdown did, and it is what closes anything the door indices
    // miss -- the concrete gate in particular drives an animationSource, not a door.
    { _obj animate [_x, 0, true]; } forEach (animationNames _obj);
    _obj setVariable ["AP_vaultlocked", 1, true];
    _obj setVariable ["AP_goldSpawned", false, true];
    true
};

// The gate list, with the old single-gate shape as its fallback. Read through getVariable rather than
// named bare, which is what the three anchors below used to be: an undefined variable in an expression
// HALTS the thread that evaluates it, and this file is reachable from !srv resetfed, which an admin can
// run before or instead of a successful boot.
private _gates = missionNamespace getVariable ["AP_fedGates", []];
if (_gates isEqualTo []) then { _gates = [missionNamespace getVariable ["AP_fedGate", objNull]]; };

private _sealed = 0;
{ if ([_x] call _fnc_seal) then { _sealed = _sealed + 1; }; }
    forEach (_gates
        + [missionNamespace getVariable ["AP_fedDome", objNull],
           missionNamespace getVariable ["AP_fedCentre", objNull]]
        + (missionNamespace getVariable ["AP_fedSafes", []]));

// the gate carries the bar-gate contract too: gate_max 0 = fully shut, door action disabled.
// BOTH animation sources go back, not just the sound one. A source is a controller that keeps driving
// its animation, so one left at the wrong phase survives whatever animate set. That is reachable in
// normal play: from phase 1 on, case "gate" has cleared bis_disabled_Door_1, so the class's own
// "Open Door" scroll action runs and BIS_fnc_Door (a3\structures_f\scripts\fn_Door.sqf) drives
// Door_1_sound_source AND Door_1_noSound_source together -- sealing only one leaves the pair split.
// The names were read out of the game's own data for THIS class rather than copied from the bank's:
// CfgVehicles >> Land_ConcreteWall_01_l_gate_F >> AnimationSources (structures_f_exp,
// Walls\Concrete\config.bin) declares Door_1_sound_source, Door_1_noSound_source and
// Door_1_locked_source -- the same three names Land_BackAlley_01_l_gate_F declares, even though the
// models are nothing alike: this gate SLIDES (ConcreteWall_01_l_gate_F.p3d binds door_1_move to the
// sound source and door_1_locked_move to the locked one, and has no handles at all), where the bank's
// swings and puts its handles on the noSound source. The locked source is deliberately NOT driven:
// that one is the engine's locked-gate jiggle (fn_Door's else branch) and fighting it is what
// APS_fnc_maldenBankSRV's header warns about.
// Door index 1 is hardcoded on purpose and is right for every gate in the list. Read out of the game's
// own data (structures_f_exp, Walls\Concrete\config.bin) rather than assumed:
// Land_ConcreteWall_01_l_gate_F declares numberOfDoors = 1 and exactly the three sources named above.
// The bis_disabled_Door_1 write below therefore DUPLICATES what _fnc_seal's numberOfDoors loop already
// did for these objects -- harmless, idempotent, and left in place because this block is the one a
// reader looking for the gate contract will find. What is NOT duplicated, and is why this block has to
// exist, is gate_max and the two animateSource calls: _fnc_seal drives `animate`, not `animateSource`.
// If a gate class with more than one door ever joins the list, this loop has to grow with it.
// _g IS NOT DECORATION: the inner forEach over the source names rebinds _x, so the gate has to be
// captured before it or animateSource lands on a string.
private _gatesSealed = 0;
{
    private _g = _x;
    if (!isNull _g) then {
        _g setVariable ["gate_max", 0, true];
        _g setVariable ["bis_disabled_Door_1", 1, true];
        { _g animateSource [_x, 0]; } forEach ["door_1_sound_source", "door_1_noSound_source"];
        _gatesSealed = _gatesSealed + 1;
    };
} forEach _gates;
missionNamespace setVariable ["AP_fedComponentSpawned", false, true];   // re-arm the mining-component drop

// THE ACCEPTANCE NUMBER IS 15, NOT 13. _sealed counts every non-null object _fnc_seal returned true
// for, and that forEach is (gates) + dome + centre + safes: 3 + 1 + 1 + 10 = 15. e7e7c01's commit body
// and the older test-pass notes both said 13, which was the pre-e7e7c01 arithmetic (ONE gate) left
// unrevised when the list grew to three. Corrected here and in maldenfed_plan.md / maldenfed_testpass.md
// on 2026-07-29.
// READ %2, NOT %1. The total is the least useful field on this line: it moves whenever a safe fails to
// resolve, so 13 could equally mean "three gates and eight safes". The gate count is the discriminating
// one -- "3 perimeter gate(s)" is what proves the resolver found the whole perimeter rather than just
// the breach anchor, which is the regression e7e7c01 actually fixed. A line reading "1 perimeter
// gate(s)" is the failure, whatever the total says.
diag_log format ["[maldenFed] fedLockdown: locked %1 object(s) -- %2 perimeter gate(s), dome, centre and %3 safe(s)",
    _sealed, _gatesSealed, count (missionNamespace getVariable ["AP_fedSafes", []])];
true
