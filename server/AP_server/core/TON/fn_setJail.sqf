/*
    APS_fnc_setJail  (LooneyBin: flag a player as jailed for combat-log re-jail) -- runs on the SERVER.
    2020 callers (all pass [_uid]): fn_arrestAction, fn_turnedIn, fn_jailCL.
    The old passthrough fed [_uid] into 2017 AP_fnc_setRestrained, which expects [_unit(object),
    _restrained(bool)] -- the uid string failed the object filter so it no-opped. All this needs to do is
    record the uid in the re-jail list (localNamespace APS_restrainedPlayers). APS_fnc_wantedRemove clears it again on release.
    2026-09-26: its reconnect consumer (server fn_query -> client AP_fnc_jail) was retired in f769100d, and
    the orphaned AP_fnc_jail receiver (whitelisted, unguarded: any client could jail + strip any player) was
    deleted. Login re-jail now comes from the persisted arrest state (AP_is_arrested -> fn_initCiv). If a
    reconnect re-jail is ever re-added, its client receiver must require remoteExecutedOwner == 2.
*/
params [["_uid", "", [""]]];
// owner 2026-06-23 SECURITY (security.md §2.2): cop-only. Caller = fn_arrestAction (passes the VICTIM's uid).
// Ungated, any civ could remoteExec [victimUID] to trap a player in jail across relogs. Require the real
// caller (remoteExecutedOwner, non-spoofable) be a west cop; server-internal passes. _uid is a bare string
// (used as a list key + later in SQL by other fns) -- strip quotes defensively.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
// owner 2026-06-24: civ BOUNTY HUNTERS legitimately jail their bounty targets (fn_arrestAction calls this for them
// too) -- requiring side==west was a FALSE POSITIVE that blocked every BH arrest + spammed -SEC-. Allow west cops OR
// a bounty hunter (AP_isBountyHunter, server-set in fn_initCiv/fn_buyLicense); block everyone else.
// ...OR self-jail: fn_turnedIn (a civ turning THEMSELVES in) also calls this with their own uid -- harmless (you
// can only jail yourself), and the cop-gate was a -SEC- false positive on it. Block only a non-cop, non-BH client
// jailing SOMEONE ELSE.
if (_src isNotEqualTo 0 && {!(_caller call APS_fnc_isDutyCop)} && {!(_caller getVariable ["AP_isBountyHunter", false])} && {!(_callerUID isEqualTo _uid)}) exitWith { ["-SEC-", _caller, format ["BLOCKED setJail by %1", _callerUID]] call APS_fnc_logIt; };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
if (_uid isEqualTo "") exitWith {};
private _rp = localNamespace getVariable "APS_restrainedPlayers";
if !(_uid in _rp) then { _rp pushBack _uid; };
