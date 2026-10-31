// AP_fnc_localChatMessage (LooneyBin, owner 2026-07-17: was a no-op stub -- restart/patch warnings were silently
// dropped). Show a server-wide notice to the player. Callers: fn_hardRestart(1M), fn_patchServer(1M),
// fn_rebootMonitor -- "Server Restarting / Patch / Maintenance ... press Y + SYNC DATA" warnings. Runs client-side.
params [["_msg", "", [""]]];
if (!hasInterface || {_msg isEqualTo ""}) exitWith {};
systemChat _msg;
[_msg, "servernotice"] spawn AP_fnc_handleMessage;
