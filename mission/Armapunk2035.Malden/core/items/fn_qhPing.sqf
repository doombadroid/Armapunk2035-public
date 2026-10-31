// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhPing.sqf  (AP_fnc_qhPing)
    Ping.exe / Pursuit Tag readout. The SERVER feeds the samples so a Scrambler Chip can lie to the
    hacker -- if the position came from the hacker's own client no counter-chip could ever work.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_pos", [], [[]]], ["_label", "TARGET", [""]], ["_last", false, [false]]];
if (_pos isEqualTo []) exitWith {};
if (isNil "AP_qhPingMarker") then {AP_qhPingMarker = createMarkerLocal [format ["qh_ping_%1", round diag_tickTime], _pos];
    AP_qhPingMarker setMarkerTypeLocal "hd_dot";
    AP_qhPingMarker setMarkerColorLocal "ColorOrange";};
AP_qhPingMarker setMarkerPosLocal _pos;
AP_qhPingMarker setMarkerTextLocal _label;
if (_last) then {
    [] spawn { uiSleep 1; if (!isNil "AP_qhPingMarker") then { deleteMarkerLocal AP_qhPingMarker; AP_qhPingMarker = nil; }; };};
