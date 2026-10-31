/*
    selfjail.sqf -- put YOURSELF in Malden prison from the debug console, to test the prison work
    without a second player.

    Paste a block into the debug console and hit LOCAL EXEC. The console is enabled for your UID only
    (description.ext `enableDebugConsole[]={"76561190000000001"}`), and BIS_fnc_debugConsoleExec is
    deliberately NOT in the CfgRE whitelist, so there is no server exec -- everything here is either
    client-local or a whitelisted client->server call.

    ⚠ JAIL TAKES YOUR GEAR. fn_jailMe removes your vest, headgear and backpack, force-adds
    U_C_Scientist, sets damage to 0, and strips weapons every tick of the sentence (:88). On release it
    runs AP_fnc_loadGear. Do not do this holding anything you care about.

    Two facts that make a naive self-jail look broken, both worth knowing before you tweak the numbers:
      * fn_jailMe:93 `if ((A_stats_crimes select 0) isEqualTo 0) exitWith {}` -- a jail with NO wanted
        money ends the same tick it starts. That is why block 1 gives you a charge first rather than
        just calling jailMe.
      * fn_jailMe:60 `_toServeTime = selectMin[AP_is_arrested select 2, 1500]` -- the sentence is
        CAPPED at 1500 s (25 min) no matter what you ask for.
*/


// ============================================================================================
// 1. SEND ME TO JAIL
// ============================================================================================
// Sentence is whatever you set here, capped at 1500. Pre-setting slot 2 is the reliable knob:
// fn_jailMe:10 only derives the sentence from your charge counts when slot 2 is still 0, so setting
// it first gives you an exact number instead of one that depends on charge-index alignment.

private _seconds = 300;                       // 5 minutes -- long enough to test containment

// Give yourself a real charge through the game's own path, so A_stats_crimes stays the right length
// and the server's wanted list is synced (fn_wantedListAdd does both). 12 = Manslaughter, $5,000.
// Without this, A_stats_crimes select 0 is 0 and you are released instantly.
[12, getPlayerUID player] call AP_fnc_wantedListAdd;

AP_is_arrested = [0, 0, _seconds];

// Exactly how the server does it -- APS_fnc_handleJail:33 is
// `[[_ret], "AP_fnc_jailMe", _unit, false] spawn AP_fnc_MP`, i.e. jailMe's arg 0 is _ret and the
// markers default to jail_marker2 / jail_release2.
[[profileName, getPlayerUID player, [], 5000]] spawn AP_fnc_jailMe;

systemChat format ["SELF-JAIL: %1s, intake %2", _seconds, getMarkerPos "jail_marker2"];


// ============================================================================================
// 2. LET ME OUT (escape hatch -- run this if anything wedges)
// ============================================================================================
/*
// Ends the jail loop the same way serving the sentence does, then puts your state back by hand.
// fn_jailMe:110-117 is load-bearing: leaving AP_arrested true locks you out of ~30 systems.
AP_is_arrested = [0, 0, 0];
AP_jailReleaseTime = 0;
AP_breakout = false;
AP_bail_paid = false;
player setVariable ["AP_arrested", false, true];
[999, getPlayerUID player] call AP_fnc_wantedListAdd;     // clear the charges you gave yourself
[[getPlayerUID player], "APS_fnc_wantedRemove", 2] spawn AP_fnc_MP;
[5] call AP_fnc_ClupdatePartial;
AP_action_in_use = false;
[true] spawn AP_fnc_loadGear;
4 cutText ["", "PLAIN"];
player setPosATL (getMarkerPos "jail_release2");
systemChat "SELF-JAIL: released";
*/


// ============================================================================================
// 3. SOLO TEST SETUP -- waive the cop requirement and clear cooldowns
// ============================================================================================
/*
// The gate hack goes through APS_fnc_handlePrisonBreak mode 1, which needs tenured cops online, a
// 30-minute re-run cooldown and a 15-minute cross-heist lockout. fedOverride waives the cop count
// (AP_betaZeroCops) and runs a loop that keeps zeroing the cooldown timestamps, which is exactly the
// solo-testing switch. It is whitelisted (CfgRE.hpp:367) and gated to your UID server-side, so this
// works from your console and nobody else's.
[["on", player], "APS_fnc_fedOverrideSRV", 2] spawn AP_fnc_MP;
// ... and to put it back:
// [["off", player], "APS_fnc_fedOverrideSRV", 2] spawn AP_fnc_MP;
*/


// ============================================================================================
// 4. TEST THE ESCAPE SOLO
// ============================================================================================
/*
// Run 3 first. Then, as a CIVILIAN standing within 8 m of the inner gate, either use the scroll
// action normally (Breach Prison Gate, needs ICEBREAKER firmware) or fire the server mode directly:
[["gatehack"], "APS_fnc_prisonGateSRV", 2] spawn AP_fnc_MP;
// The server re-derives you from remoteExecutedOwner and re-checks civilian / alive / not restrained /
// not downed / not in a vehicle / within 8 m of AP_prisonGateIn, so you do have to be standing there.
// Gate position:
player setPosATL (getPosATL (missionNamespace getVariable ["AP_prisonGateIn", objNull]));

// Then jail yourself with block 1 and wait out the 600 s window for the escape dialog. To confirm the
// window is live without waiting:
systemChat format ["break active=%1  disarmed=%2  started=%3s ago",
    SRV_prisonData param [1, false],
    missionNamespace getVariable ["AP_prisonDisarmed", false],
    round (serverTime - (SRV_prisonData param [0, 0]))];
*/


// ============================================================================================
// 5. CHECK CONTAINMENT WITHOUT SERVING A SENTENCE
// ============================================================================================
/*
// Feature 3 is one test at fn_jailMe:94. This reads it directly, so you can confirm the polygon is
// right by walking around -- no jail required. Prints every second; run again to stop.
if (isNil "AP_polyProbe") then {
    AP_polyProbe = true;
    [] spawn {
        while { AP_polyProbe } do {
            hintSilent format ["inPolygon: %1\npos: %2\nyard: %3",
                (getPosATL player) inPolygon AP_jailPoly,
                (getPosATL player) apply { round _x },
                getMarkerPos "jail_marker_loonybin"];
            uiSleep 1;
        };
        hintSilent "";
    };
} else { AP_polyProbe = nil; };
*/
