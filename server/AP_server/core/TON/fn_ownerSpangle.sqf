/*
    APS_fnc_ownerSpangle  (owner 2026-07-06) -- server-validated NON-LETHAL ragdoll-launch ("Super Spangle").
    Owner-only moderation tool to punish safezone/town vehicle abusers: flings the target player (NO death --
    AP_fnc_forceRagdoll disables the target's damage during the launch). Routes owner client -> here (validate the
    NON-SPOOFABLE caller == owner UID, same pattern as APS_fnc_toggleNewbieRoles) -> forceRagdoll on the TARGET's
    client (server -> client, exempt from the CfgRemoteExec whitelist -- so clients can NOT fire the launch directly).
    Whitelisted CfgRE allowedTargets = 2 (client -> server).
    client args: [_target, _sourcePlayer]
*/
params [["_target", objNull, [objNull]], ["_source", objNull, [objNull]]];
if (isNull _target) exitWith {};

// gate to the OWNER via the engine-set, non-spoofable sender (mirrors fn_toggleNewbieRoles). The passed _source
// object is attacker-controllable, so identity comes from remoteExecutedOwner, not from _source.
private _src = remoteExecutedOwner;
private _realCaller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src != 0 && {getPlayerUID _realCaller isNotEqualTo "76561190000000001"}) exitWith {
    ["-SEC-", _realCaller, format ["BLOCKED ownerSpangle by non-owner %1", getPlayerUID _realCaller]] call APS_fnc_logIt;};
if !(_target isKindOf "Man") exitWith {};

// launch the target away from the owner; forceRagdoll runs on the target's client and is non-lethal (allowDamage false)
private _dirSource = if (_src isEqualTo 0) then { _source } else { _realCaller };
[[_target, "body", 0, _dirSource, objNull], "AP_fnc_forceRagdoll", _target] spawn AP_fnc_MP;
diag_log format ["LB_OWNER_SPANGLE: %1 launched %2", getPlayerUID _dirSource, getPlayerUID _target];
