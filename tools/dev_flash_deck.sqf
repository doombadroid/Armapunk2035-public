/*
    tools/dev_flash_deck.sqf -- DEV ONLY. Flash the cyberdeck firmware onto YOUR
    character, put the VR goggles on, and optionally install deck modules and
    firewall chips.

    HOW TO RUN. Paste the whole file into the in-game debug console (Esc ->
    DEBUG CONSOLE on the dev server, where AP_devAutoAdmin makes every player
    admin level 4) and hit LOCAL EXEC. It is a client-side script; the grants
    themselves go to the server.

    WHY YOU NEED IT. The visor (SHIFT+Y) and the whole quickhack layer gate on
    two things, and both are easy to miss when testing:

        goggles player isEqualTo "G_Goggles_VR"     the overlay needs them on
        0 in (player getVariable "AP_cdMods")        the ILLEGAL FIRMWARE

    Firmware is id 0 in AP_cdMods -- the deck stopped being an item on
    2026-07-20 and became a flash on your phone, stored in the same persisted
    array as the modules so a cop Factory Reset can strip 0 and leave 1-4.

    AP_fnc_hasDeck ALSO requires playerSide isEqualTo civilian. Flashing as a
    cop persists fine and does nothing visible, which looks like a broken
    flash; this script says so rather than letting you chase it.

    NOTHING NEW DECIDES ANYTHING. Both grants go through the same whitelisted
    server functions the shops use, so the ids are validated, persisted to
    players.cyberdeck_modules and broadcast exactly as a real purchase would be:

        ["buyModule",  0,   player]   firmware ONLY -- it refuses every other id
        ["installHack", id, player]   modules 1-3, chips 101-112, hack chips

    Those two split on purpose: firmware installs only via the flash path, so a
    crafted client cannot reinstall the firmware a Factory Reset just stripped.
    This script does not work around that, it uses it.

    The money side is skipped, which is the only thing here a real purchase does
    differently -- price is deducted client-side before the call (the existing
    client-authoritative money boundary), and this simply does not deduct.
*/

if (!hasInterface) exitWith {};

// EVERYTHING BELOW RUNS IN A SPAWN. The debug console executes unscheduled, and
// uiSleep/waitUntil throw "cannot suspend in unscheduled environment" there --
// which aborts the script partway, after the goggles and before the verify, and
// looks like the grant silently failed. Scheduling it once here is the fix.
[] spawn {

// ---------------------------------------------------------------- what to grant
// Firmware is always flashed. Add ids here to install alongside it:
//   1 Overclock · 2 Cooling Rig · 3 Signal Amp
//   101 Scrambler · 102 Optic Filter · 103 Audio Limiter · 104 Hardened Firmware
//   105 Deadbolt · 106 Freq-Hop Radio · 107 Encrypted SIM · 108 ICE Firewall
//   109 Surge Protector · 110 Dead Man's Clutch · 111 Co-Pilot Guardian · 112 Sealed Tank
// Empty [] = firmware and goggles only.
private _extraIds = [1, 2, 3, 101, 102, 103, 104];

private _say = { diag_log ("[dev-deck] " + _this); systemChat _this };

// ---------------------------------------------------------------- preconditions
if (playerSide isNotEqualTo civilian) then {
    "WARNING: you are not CIVILIAN. AP_fnc_hasDeck is side-gated, so the firmware will persist but the deck stays inert until you spawn civ." call _say;
};

private _owned = player getVariable ["AP_cdMods", []];
format ["before: AP_cdMods = %1", _owned] call _say;

// ---------------------------------------------------------------- goggles
// The visor refuses without these, with a message that reads like the firmware
// failed. addGoggles replaces whatever is worn.
if !((goggles player) isEqualTo "G_Goggles_VR") then {
    player addGoggles "G_Goggles_VR";
    "VR goggles on." call _say;
};

// ---------------------------------------------------------------- flash + install
if (0 in _owned) then {
    "firmware already flashed -- skipping." call _say;
} else {
    [["buyModule", 0, player], "APS_fnc_cyberdeckSRV", 2, false, false] spawn AP_fnc_MP;
    "firmware flash requested." call _say;
};

{
    if (_x in _owned) then {
        format ["id %1 already owned -- skipping.", _x] call _say;
    } else {
        [["installHack", _x, player], "APS_fnc_cyberdeckSRV", 2, false, false] spawn AP_fnc_MP;
        uiSleep 0.2;   // one round trip each; the server re-reads AP_cdMods per call
    };
} forEach _extraIds;

// ---------------------------------------------------------------- verify
// The grants are server round trips, so read the result rather than assuming it.
// Each one publishes AP_cdMods back onto the player object.
[_extraIds] spawn {
    params ["_want"];
    private _deadline = time + 15;
    waitUntil {
        uiSleep 0.5;
        (0 in (player getVariable ["AP_cdMods", []])) || {time > _deadline}
    };
    private _now = player getVariable ["AP_cdMods", []];
    private _missing = (_want + [0]) select { !(_x in _now) };
    diag_log format ["[dev-deck] after: AP_cdMods = %1", _now];
    systemChat format ["[dev-deck] after: AP_cdMods = %1", _now];
    if (_missing isEqualTo []) then {
        systemChat "[dev-deck] all requested ids present. SHIFT+Y should open the visor.";
    } else {
        systemChat format ["[dev-deck] NOT granted: %1 -- check the server RPT for a refusal.", _missing];
    };
    if (!(call AP_fnc_hasDeck)) then {
        systemChat "[dev-deck] AP_fnc_hasDeck is still false -- you are almost certainly not civilian.";
    };
};
};
