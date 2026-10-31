/*
    APS_fnc_stimmySRV  (owner 2026-06-18 -- "Stimmy Checks")
    OWNER-ONLY economy stimulus toggle. When ON, fn_cartelSRV credits the cartel-OWNING gang 10x the normal
    cut for Arms(0)/Drug(1)/Wongs(3) -- money conjured from nothing -- to re-float the economy at low pop.
    The player's tax cut is UNCHANGED (it's set client-side in fn_processAction); only the gang-bank credit
    grows. Persisted in server_control.stimmy so it survives reboots (init.sqf restores AP_stimmy at boot).
    CLANKR reads the same server_control.stimmy flag so the resulting bank growth/withdrawals don't ping the
    owner while it's on.

    Client (admin menu ON/OFF button): [_on, _pObj]   _on = bool.
*/
params [["_on", false, [false]], ["_pObj", objNull, [objNull]]];
if (isNull _pObj) exitWith {};

// owner 2026-07-24 SECURITY: the owner check below read getPlayerUID off _pObj -- a CLIENT-SUPPLIED object.
// Any client could pass the OWNER's player object (trivially obtainable from allPlayers) and satisfy it.
// That was latent while this fn had no CfgRE entry, but it is being whitelisted now so the owner's dead
// "Stimmy Checks" button works, which would have made it live. Derive the identity from the non-spoofable
// remoteExecutedOwner instead, and reply to that caller rather than the passed object.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { _pObj } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
// owner-only (sole enableDebugConsole UID). A non-owner admin cannot conjure money.
if !((getPlayerUID _caller) isEqualTo "76561190000000001") exitWith {
    [["Stimmy Checks is owner-only.", "basic"], "AP_fnc_handleMessage", _caller, false] spawn AP_fnc_MP;
    if (_src isNotEqualTo 0) then { ["-SEC-", _caller, format ["BLOCKED stimmySRV (not the owner; claimed %1)", getPlayerUID _pObj]] call APS_fnc_logIt; };
};
_pObj = _caller;   // downstream logging/messaging uses the verified actor

localNamespace setVariable ["APS_stimmy", _on];   // what fn_cartelSRV reads; AP_stimmy is the client display copy
AP_stimmy = _on;
publicVariable "AP_stimmy";

[format ["UPDATE server_control SET stimmy=%1 WHERE id=1", [0, 1] select _on]] call DB_fnc_asyncQuery;

["-STIMMY-", _pObj, format ["Stimmy Checks turned %1 (10x cartel payouts: Arms/Drug/Wongs; player tax unchanged)", ["OFF", "ON"] select _on]] call APS_fnc_logIt;

[[format ["Stimmy Checks are now %1. Cartel payouts (Arms/Drug/Wongs) %2.", ["OFF", "ON"] select _on, ["pay the normal rate", "pay 10x (economy stimulus)"] select _on], "basic"], "AP_fnc_handleMessage", _pObj, false] spawn AP_fnc_MP;
