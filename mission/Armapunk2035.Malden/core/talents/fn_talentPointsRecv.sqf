/*
    AP_fnc_talentPointsRecv  (LooneyBin, owner 2026-07-16) -- server pushes the player's PURCHASED talent-point
    count (login load + after each buy). Stores it and recalculates the available-points pool.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
if (!hasInterface) exitWith {};
params [["_pts", 0, [0]]];
AP_boughtTalents = _pts max 0;
[] call AP_fnc_calTalents;
