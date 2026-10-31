/*
    AP_fnc_botKick  (LooneyBin) -- remote kick from the loonybot admin bridge.
    The server remoteExecs this onto the target's client (via the bot_commands poller in
    server init.sqf). Show the reason, then drop them to debriefing with "loser" -- the
    established kick ending used by init.sqf's fnc_serv_kick.
    2026-09-26 SECURITY (audit registry-0-2): CfgRE allowedTargets was 2, so any client could remoteExec
    this at the SERVER (which compiles mission fns too) and its endMission cycled the mission for everyone.
    Now 1 (clients), and because a client can still aim a target-1 call at OTHER clients, only the server
    may send it. Every caller is server-side (adminKickBan, insertRequest/queryRequest ban gate, bot poller).
*/
if (!hasInterface) exitWith {};
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};
params [["_reason", "Removed by an admin.", [""]]];
[format ["You have been removed from the server.\nReason: %1", _reason], "basic"] spawn AP_fnc_handleMessage;
uiSleep 3;
endMission "loser";
