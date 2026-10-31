/*
    APS_fnc_wantedAdd  (LooneyBin: add a charge to a player's wanted level) -- runs on the SERVER.
    Callers: [chargeID, unit]  or  [chargeID, unit, amount].
    Relay the charge to the OFFENDER's own client (AP_fnc_wantedListAdd) -> it updates A_stats_crimes
    (single source of truth) + republishes AP_wantedAmt, then pushes the authoritative state to
    APS_fnc_wantedSyncList which rebuilds the cop-facing wanted list (+ its index-3 bounty the payout
    reads). NO separate server accumulation here -- that desynced from A_stats_crimes and under-paid bounties
    (player wanted 93k while the list/payout sat on one stale 5k charge).
*/
params [["_chargeID", -1, [0]], ["_unit", objNull, [objNull]], ["_amount", 1, [0]]];
if (!isNil "AP_fnc_telemetryEvent") then { ["wanted"] call AP_fnc_telemetryEvent; };   // telemetry event counter
// owner 2026-06-23 SECURITY (security.md §2.2): this is NOT cop-only -- civs self-charge for their own crimes
// (robStore/lockpick/prisonBreak/etc pass [chargeID, player]) and the kill-attribution path charges another
// civ (the killer) at a fixed low charge, amount 1. So DON'T require side==west. Two real holes are closed:
//   1) AMOUNT INFLATION: the old `(round _amount) max 1` set only a FLOOR -> a client could remoteExec
//      [60, victim, 999999] and the victim's own fn_wantedListAdd (which keys on its own UID) would apply
//      crimeValue*999999. The legit cop UX (fn_applyCharge) hard-caps amount at 5, so clamp 1..5 here too.
//   2) Derive the REAL caller (remoteExecutedOwner, non-spoofable). Self-charge and server-internal (_src==0,
//      bank/fed/jewelry call this directly) always pass. A client charging a DIFFERENT player is allowed only
//      for west cops (applyCharge) OR civ-vs-civ (the kill path) -- but with the amount now capped, the worst a
//      civ can do is grief a low-value charge onto a UID. NEEDS OWNER REVIEW: tie civ-vs-civ charging to a
//      server-side recent-kill/witness record to fully close low-value griefing (kept open so kill charges work).
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (isNull _unit) exitWith {};
// owner 2026-06-24: THE PURGE -- crimes committed inside the active purge zone add NO wanted level (auto-zone,
// "all crime legal"). AP_purgeZone = [centerPos, radius] is published by APS_fnc_eventPurgeSRV (nil = no purge).
// Read from the server's localNamespace copy: the published global is one client publicVariable away from a
// map-wide zone and no charges for anyone (audit Lsec-0-1).
private _purge = localNamespace getVariable ["AP_purgeZone", []];
if (((_purge param [1, 0]) > 0) && {(getPosATL _unit) distance2D (_purge param [0, [0,0,0]]) < (_purge param [1, 0])}) exitWith {};
if (_chargeID < 1 || _chargeID > 150) exitWith {};
_amount = ((round _amount) max 1) min 5;
// admin-0-1: charge 57 ("Admin Jailed", $999,999 a count) belongs to the admin jail alone (fn_adminJail and
// fn_staffAct "jail", both staff level >= 2). The amount cap above does not help there: [57, anyone, 5] put
// ~$5M on a victim for a colluding arrester to collect. From a client it now needs that level, read from the
// DB for the real caller.
if (_chargeID isEqualTo 57 && {_src isNotEqualTo 0} && {(parseNumber format ["%1", (["SELECT adminlevel FROM players_global WHERE playerid = %s", 2, false, [getPlayerUID _caller]] call DB_fnc_asyncQuery) param [0, 0]]) < 2}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED wantedAdd charge 57 by %1 on %2", getPlayerUID _caller, getPlayerUID _unit]] call APS_fnc_logIt; };
private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {};
[[_chargeID, _uid, _amount], "AP_fnc_wantedListAdd", _unit, false, false] spawn AP_fnc_MP;
