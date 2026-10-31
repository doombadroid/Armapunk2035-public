/*
    fedtest.sqf -- Federal Reserve test harness. DEV ONLY.

    Lives at the repo root ON PURPOSE: it is NOT inside mission/, so it is never packed into the PBO
    and never reaches a client. Nothing here is shipped.

    HOW TO RUN
      Log in as admin, open the debug console, and set the execution target to SERVER.
      Paste ONE block at a time. Everything below needs to run server-side, because the transitions
      it drives are keyed on AP_fedInternalKey, which is generated at boot, is server-only and is
      deliberately never publicVariable'd -- a client cannot reach these paths, which is the point.

    WHAT IT SKIPS
      the perimeter gate's Sequence minigame, the dome terminal, the 10:00 dome timer, the centre
      terminal, the 20:00 Alamo timer, the 5-minute HIGH SECURITY lockout and the 15-minute
      cross-heist lockout. It does NOT skip the real spawn code: every case, the boat and every door
      is placed by exactly the same functions a real robbery uses, so what you see is what a player
      would see.

    STATE, for reading the log
      SRV_maldenFed = [domePhase, _, alamoPhase, _, highSecurityUntil]
        domePhase   0 idle | 1 gate breached | 2 dome cracked | 3 dome open + gold spawned
        alamoPhase  0 idle | 1 started       | 2 centre open + gold + boat
*/


// ==== BLOCK 1 -- OPEN THE DOME AND SPAWN THE TEN RING CASES ==========================
// Jumps straight to "the dome timer just expired". Opens the dome and runs the real gold spawn.

private _k = missionNamespace getVariable ["AP_fedInternalKey", ""];
if (_k isEqualTo "") exitWith { systemChat "FEDTEST: no internal key -- did boot run?"; };
SRV_lastRobbery = -99999; publicVariable "SRV_lastRobbery";        // clear the cross-heist lockout
SRV_maldenFed = [2, -1, 0, -1, -1];                                // phase 2 = dome cracked, no cooldown
publicVariable "SRV_maldenFed";
AP_fed_robbed = [true, serverTime]; publicVariable "AP_fed_robbed";
["domeOpen", _k] call APS_fnc_maldenFedSRV;
systemChat "FEDTEST: dome opened, ten ring cases spawned";


// ==== BLOCK 2 -- OPEN THE CENTRE AND SPAWN THE ALAMO CASES + THE BOAT ================
// Run AFTER block 1. Jumps to "the Alamo timer just expired".

private _k = missionNamespace getVariable ["AP_fedInternalKey", ""];
if (_k isEqualTo "") exitWith { systemChat "FEDTEST: no internal key"; };
private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
_s set [2, 1];                                                     // alamo phase 1 = started
SRV_maldenFed = _s; publicVariable "SRV_maldenFed";
["alamoOpen", _k] call APS_fnc_maldenFedSRV;
systemChat "FEDTEST: centre opened, alamo cases + getaway boat spawned";


// ==== BLOCK 3 -- THE ACCEPTANCE TEST ================================================
// The one that matters. Measures every case against ITS OWN BUILDING, which is the check the
// original settle log could not do -- it compared a height against the value it had just written,
// so it reported everything healthy while the cases sat under the deck.
//
// PASS  = every "vs bldg" is roughly the SAME number, about +0.6 to +1.0.
// FAIL  = the numbers vary with "terrain". That variance IS the bug: a case sinks by exactly the
//         depth of the seabed beneath it, so the ones furthest out over the water sink furthest.

private _c = [11198, 4459.21, 0];
private _cases = nearestObjects [_c, ["Land_Suitcase_F"], 400];
private _blds  = nearestObjects [_c, ["Land_Medevac_house_V1_F", "Land_Medevac_HQ_V1_F"], 400];
diag_log format ["FEDTEST ---- %1 case(s) ----", count _cases];
private _spread = [];
{
    private _asl = getPosASL _x;
    private _b = _blds select { (_x distance2D _asl) < 12 };
    private _bz = if (_b isEqualTo []) then { -9999 } else { ((getPosASL (_b select 0)) select 2) };
    private _above = if (_bz isEqualTo -9999) then { -9999 } else { (_asl select 2) - _bz };
    if (_above > -9998) then { _spread pushBack _above; };
    diag_log format ["FEDTEST %1 aslZ=%2 terrain=%3 bldgZ=%4  vs bldg=%5  sim=%6",
        _forEachIndex,
        ((_asl select 2) toFixed 3),
        ((getTerrainHeightASL [(_asl select 0), (_asl select 1)]) toFixed 3),
        (_bz toFixed 3), (_above toFixed 3), simulationEnabled _x];
} forEach _cases;
if (count _spread > 1) then {
    _spread sort true;
    private _range = (_spread select (count _spread - 1)) - (_spread select 0);
    diag_log format ["FEDTEST spread across all cases = %1 m  -- %2",
        (_range toFixed 3),
        if (_range < 0.5) then { "PASS (uniform, frame is right)" } else { "FAIL (varies with terrain -- frame is wrong)" }];
};
systemChat "FEDTEST: probe written to the server RPT -- grep FEDTEST";


// ==== BLOCK 4 -- RESET, so you can run it again ======================================
// Re-locks everything, bins the un-looted loot, then clears the HIGH SECURITY window that the
// reset itself arms, plus the cross-heist lockout, so you can go straight round again.

private _k = missionNamespace getVariable ["AP_fedInternalKey", ""];
["reset", _k, "fedtest"] call APS_fnc_maldenFedSRV;
uiSleep 1;
private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
_s set [4, -1];                                                    // drop HIGH SECURITY
SRV_maldenFed = _s; publicVariable "SRV_maldenFed";
SRV_lastRobbery = -99999; publicVariable "SRV_lastRobbery";        // drop the cross-heist lockout
systemChat "FEDTEST: reset, cooldowns cleared -- ready for another run";


// ==== BLOCK 5 -- just the gate, if you want to test the seal ========================
// Opens the three perimeter gates without running the heist. Use BLOCK 4 to shut them again.
// Remember: the vanilla "Open Door" option is ALWAYS offered even on a sealed gate -- it just
// plays the locked jiggle. Judge by whether the gate MOVES, never by whether the option appears.

private _k = missionNamespace getVariable ["AP_fedInternalKey", ""];
SRV_maldenFed = [0, -1, 0, -1, -1]; publicVariable "SRV_maldenFed";
{
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "numberOfDoors");
    for "_i" from 1 to (_n max 1) do { _x setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
    { _x animate [_y, 1, true]; } forEach (animationNames _x);
    { _x animateSource [_y, 1]; } forEach ["door_1_sound_source", "door_1_noSound_source"];
} forEach (missionNamespace getVariable ["AP_fedGates", []]);
systemChat "FEDTEST: perimeter gates thrown open";
