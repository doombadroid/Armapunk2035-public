/*
    fn_invCargoRecv.sqf -- the server's answer to one APS_fnc_invCargo ticket.
    CfgRE.hpp: allowedTargets = 1 (server -> client only).

        [_ticket, _ok, _msg, _extra]   remoteExec'd by the server at the asking client

    Only the server may answer: anything else is a client trying to forge a verdict, and is dropped.
    The bridge's asker (AP_fnc_invCargoAsk in fn_invBridge.sqf) waits on AP_invTickets.
*/
if (remoteExecutedOwner != 2) exitWith {};
params [["_ticket", 0, [0]], ["_ok", false, [false]], ["_msg", "", [""]], ["_extra", [], [[]]]];
if (isNil "AP_invTickets") then { AP_invTickets = createHashMap; };
AP_invTickets set [_ticket, [_ok, _msg, _extra]];
