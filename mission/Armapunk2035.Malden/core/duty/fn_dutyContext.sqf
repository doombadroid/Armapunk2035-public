/*
    AP_fnc_dutyContext -- apply the client-side consequences of the CURRENT duty state. No parameters:
    everything is derived from AP_onDuty / AP_dutyFaction / AP_copRole and the AP_fnc_dutyCfg row, so it is
    idempotent and safe to re-run. AP_fnc_dutyClient calls it on both edges; nothing else should.

    This is AP_effSide's ONLY real writer. Until PR2 it was `playerSide` frozen at login; from PR7 login is
    always civilian, so on duty AP_effSide is the faction's side and off duty it is civilian, and this file
    is the whole of that transition. Every gate PR2/PR3 moved onto AP_effSide follows it automatically --
    that is the whole point of the sweep.

    THINGS THIS DELIBERATELY DOES NOT DO
      * AP_paycheck. core\init.sqf:138 __SETCONST__'s it (compileFinal), so writing it throws at runtime, so
        the duty paycheck lands in AP_dutyPaycheck instead. THE FSM IS WIRED TO IT (PR6, commit a1d4c78d):
        core\fsm\client.fsm's paycheck state computes
            getVariable ["AP_onDuty", false] -> getVariable ["AP_dutyPaycheck", call AP_paycheck]
        and falls back to `call AP_paycheck` off duty, so an on-duty player is paid their FACTION's rate and
        not their login side's. What this file still must never do is WRITE AP_paycheck; that has not
        changed, and the __SETCONST__ is why.
      * AP_fnc_trackMarkers. Duty is only ever entered from civilian (APS_fnc_dutySRV enforces it), and
        fn_initCiv.sqf:222 already registered that Map handler for every civilian. Registering it again
        would stack a second mission EH that nothing can remove. Its body is fully AP_effSide-gated, so it
        follows the flip on its own.
*/
if (isNil "AP_onDuty") then { AP_onDuty = false; };
if (isNil "AP_dutyFaction") then { AP_dutyFaction = ""; };

private _row = if (AP_onDuty) then { [AP_dutyFaction] call AP_fnc_dutyCfg } else { [] };
private _on = !(_row isEqualTo []);
private _newSide = if (_on) then { _row select 1 } else { civilian };
private _wasSide = AP_effSide;

// SIDE CHAT, before the flip. AP_fnc_manageSidechat exits early on west/independent, so the only moment it
// can ever take the player OUT of the civ radio channel is while AP_effSide is still civilian.
if ((_wasSide isEqualTo civilian) && !(_newSide isEqualTo civilian)) then {
    [false, player] call AP_fnc_manageSidechat;
};

AP_effSide = _newSide;

if (_on) then {
    AP_dutyPaycheck = _row select 3;
    AP_maxWeight = _row select 4;
    AP_maxTalents = call (_row select 5);
} else {
    // configuration.sqf's civilian row. fn_survival.sqf:90 re-derives AP_maxWeight from the backpack every
    // pass for civilians, so 96 is only the value that stands until its next tick -- and 96 is exactly what
    // configuration.sqf seeds, so this restores the pre-duty state rather than inventing one.
    AP_dutyPaycheck = 350;
    AP_maxWeight = 96;
    AP_maxTalents = 20;
};

// RECOMPUTE THE SPENDABLE BUDGET, and it has to be AFTER the assignment above, not before.
// AP_maxTalents is only the CAP; AP_currentTalents is what the talent menu lets you spend, and
// fn_calTalents.sqf is the only thing that derives it. Nothing else on a duty swap called it, so a
// player kept whatever budget their last login computed: an Lt clocking on stayed on the civilian 20
// instead of their rank cap, and a TT medic clocking on stayed on 20 instead of 16.
// The ORDER is load-bearing in both directions. fn_calTalents.sqf:34 reads AP_maxTalents for the west
// branch, so calling it first would use the previous state's cap; and its :42 ratchet
// (`AP_maxTalents = AP_maxTalents max AP_currentTalents`) would, on a clock-off called first, keep the
// cop's widened cap alive past the assignment that was supposed to put it back to 20. Assign, then
// recompute: the ratchet then only ever raises the cap to the budget just derived from it, which is a
// no-op, and the bought-points top-up at :40-41 still stacks on both sides.
[] call AP_fnc_calTalents;

switch (true) do {
    case (_on && {(_row select 0) isEqualTo "maxsec"}): {
        player setVariable ["AP_unitCopLevel", call AP_copLevel, true];
        player setVariable ["AP_unitCopRetiredLevel", call AP_copRetiredLevel, true];
        player setVariable ["AP_unitCopRole", AP_copRole, true];
        player setVariable ["AP_showrank", !(AP_copRole in ["scd", "all"]), true];   // old cop init
        player setVariable ["AP_nonlethal", true, true];                             // old cop init
        player setVariable ["AP_medLevel", 0, true];
        // APB / bounty tracking radius, the old cop init's switch verbatim. Without it a duty cop keeps the
        // civilian 300 seeded by configuration.sqf and every cop tracking talent is silently inert.
        AP_track_radius = switch (true) do {
            case (8 in AP_cop_talents): {200};
            case (7 in AP_cop_talents): {300};
            case (6 in AP_cop_talents): {400};
            case (5 in AP_cop_talents): {500};
            case (4 in AP_cop_talents): {800};
            case (3 in AP_cop_talents): {900};
            case (2 in AP_cop_talents): {1000};
            default {1400};
        };
    };

    case (_on && {(_row select 0) isEqualTo "trauma"}): {
        player setVariable ["AP_medLevel", call AP_medicLevel, true];                // old medic init
        player setVariable ["AP_unitCopLevel", 0, true];
        player setVariable ["AP_unitCopRetiredLevel", 0, true];
        player setVariable ["AP_unitCopRole", "", true];
        player setVariable ["AP_showrank", true, true];
        player setVariable ["AP_nonlethal", false, true];
        AP_medPartners = [];
    };

    default {
        // Off duty. Clearing AP_nonlethal is HYGIENE, not the active gate: fn_handleDamage.sqf:61 does read
        // it off the SHOOTER with a default of TRUE, but :4 derives _copSource = `side _source isEqualTo
        // west` and :70 requires _copSource before AP_nonlethal is consulted at all, so a clocked-off
        // civilian's shots are already lethal on the side test alone. Cleared anyway so the variable never
        // outlives the state it describes -- the next reader of it may not have the side co-gate.
        // AP_track_radius goes back to configuration.sqf's civilian seed of 300, which is also what
        // fn_trackBounty.sqf:37-38 and fn_requestBounty.sqf:47-48 re-derive for a non-west player; leaving a
        // duty cop's talent-widened radius behind would widen the civilian bounty-track scroll actions in
        // fn_setupActions.sqf:1001-1013 until the next time one of those two ran.
        AP_copRole = "";
        AP_track_radius = 300;
        player setVariable ["AP_unitCopLevel", 0, true];
        player setVariable ["AP_unitCopRetiredLevel", 0, true];
        player setVariable ["AP_unitCopRole", "", true];
        player setVariable ["AP_showrank", false, true];
        player setVariable ["AP_nonlethal", false, true];
        player setVariable ["AP_medLevel", 0, true];
    };
};

// Marker handlers. These are addMissionEventHandler registrations with no captured handle, so they can be
// added but never removed -- register at most once per session and let the AP_effSide guards inside them
// decide whether to draw. fn_medicMarkers / fn_medicHexs had exactly one other caller, the medic lobby init
// that PR7 deleted, so a duty medic is now the only way anyone gets them at all.
if (_on && {(_row select 0) isEqualTo "trauma"} && {isNil "AP_dutyMedMarkersReg"}) then {
    AP_dutyMedMarkersReg = true;
    [] spawn AP_fnc_medicMarkers;
    [] spawn AP_fnc_medicHexs;
};

if (_newSide isEqualTo civilian) then {
    if (isNil "AP_sidechat") then { AP_sidechat = true; };
    [AP_sidechat, player] call AP_fnc_manageSidechat;
};

if (_on && !("ItemGPS" in assignedItems player)) then { player linkItem "ItemGPS"; };   // old cop init
