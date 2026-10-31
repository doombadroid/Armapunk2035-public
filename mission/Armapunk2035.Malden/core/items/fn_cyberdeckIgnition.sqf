// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckIgnition.sqf  (AP_fnc_cyberdeckIgnition)
    LooneyBin 2026-07-19 (cdfeatures.md #3): Cyberdeck "Hack Ignition" -- a quick 4-symbol Sequence Breach on any
    vehicle in range temporarily fries its engine (~22s) so it can't move or restart. Folds in the old remote
    engine kill switch. Server-authoritative kill/restore (APS_fnc_cyberdeckSRV "ignition"); client just gates + runs
    the minigame + eats the Cyber Crime charge.
*/
params [["_veh", objNull, [objNull]]];
if (isNull _veh) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith { ["You need a Cyberdeck for that.", "basic"] spawn AP_fnc_handleMessage; };
if (diag_tickTime < (missionNamespace getVariable ["AP_ignHackCd", 0])) exitWith {
    ["Your deck's ignition exploit is still cooling down.", "basic"] spawn AP_fnc_handleMessage;};
AP_ignHackCd = diag_tickTime + 90;   // owner 2026-07-21: spec cooldown 90s (was 50). Server also rate-limits per vehicle.

private _r = [4] call AP_fnc_cyberdeckSeq;   // quick breach
if !(_r isEqualTo 1) exitWith {};
if (isNull _veh || {(_veh distance player) > 30} || {!alive _veh}) exitWith {
    ["Target slipped out of range.", "basic"] spawn AP_fnc_handleMessage;};

[["ignition", _veh, player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;   // server fries + auto-restores the engine
[[112, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;                    // Cyber Crime
["<t color='#00e5ff'>KILLSWITCH DEPLOYED</t> -- engine fried for ~20 seconds.", "info"] spawn AP_fnc_handleMessage;
