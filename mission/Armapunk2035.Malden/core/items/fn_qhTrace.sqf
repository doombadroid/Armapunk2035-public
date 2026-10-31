// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhTrace.sqf  (AP_fnc_qhTrace)
    LooneyBin 2026-07-21: the victim's answer to being hacked. Inside the 10s trace window this pings
    the hacker's position back -- the risk half of every quickhack's risk/reward.
*/
if (diag_tickTime > (missionNamespace getVariable ["AP_qhTraceUntil", 0])) exitWith {
    ["The trace window has closed.", "basic"] spawn AP_fnc_handleMessage;};
private _h = missionNamespace getVariable ["AP_qhLastHacker", objNull];
if (isNull _h) exitWith { ["Nothing to trace.", "basic"] spawn AP_fnc_handleMessage; };
AP_qhTraceUntil = 0;
["action", "qhtraced", 1] spawn AP_fnc_handleQuest;   // quest hook: you traced someone back
[["trace", _h, player], "APS_fnc_qhSRV", 2] spawn AP_fnc_MP;
["<t color='#c9e21a'>TRACING</t> -- following the signal back...", "basic"] spawn AP_fnc_handleMessage;
