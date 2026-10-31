// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_talLog.sqf  (AP_fnc_talLog)
    LooneyBin 2026-07-20: TAL OS audit trail. Every officer action on the ring is logged -- TAL is the
    LAWFUL counterpart to the illegal civilian deck, so it leaves a paper trail by design. Client-side
    raw remoteExec of diag_log is blocked under CfgRE, so route through the server logger.
*/
params [["_tag", "-TALOS-", [""]], ["_unit", objNull, [objNull]], ["_name", "", [""]], ["_msg", "", [""]]];
[[_tag, _unit, _name, _msg], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
