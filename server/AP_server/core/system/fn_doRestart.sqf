 
_endType = [_this,0,"end1",[""]] call BIS_fnc_param; 
 
if (AP_UsingHeadless) then {diag_log format["Attempting to kill headless by executing '%1'...", "ExecProcess LoonybinHCRestart.bat"];
_shell = ""; diag_log "[LooneyBin] server restart requested (LoonybinHCRestart.bat) -- handle via host watchdog/systemd"; // TODO[extDB3 migration] 
}; 
 
// owner 2026-06-13: end the mission so the dedicated-server mission cycle reloads it IN PLACE (players stay
// CONNECTED, re-slot from the role-select lobby). The old `serverCommand "#restart"` needed a logged-in
// admin (none on a headless box). First attempt used ONLY `BIS_fnc_endMission` MP'd to all -- that did NOT
// reload here (no `end1` ending in CfgDebriefing + BIS wrapper is player-oriented). The reliable driver is
// the RAW `endMission` command on the SERVER, which triggers the mission cycle; the MP broadcast then pulls
// clients through the transition. (persistent=1 + the single `class Missions` entry = reload the same one.)
if (isServer) then { endMission _endType; };
[[_endType],"BIS_fnc_endMission", true, false] spawn BIS_fnc_MP;