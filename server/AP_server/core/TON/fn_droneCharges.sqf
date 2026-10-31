/*
    APS_fnc_droneCharges  (LooneyBin NEW 2026-06-09)
    Persists revive-drone battery state (was session-only -> relog refilled it, features.md item).
    Client (core/medical/fn_reviveDrone.sqf) sends [uid, revives, support, rechargeRemainingSecs]
    after every charge change. Stored as an absolute unix deadline so it survives reboots; the load
    push (DB_fnc_queryRequest, medics only) sends the REMAINING seconds back.
*/
params [["_uid", "", [""]], ["_rev", 5, [0]], ["_sup", 10, [0]], ["_remaining", 0, [0]]];
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): the client _uid was used raw to
// UPDATE drone state, so a scripter could write to ANY account / inject SQL. Force the actor to the
// NON-SPOOFABLE caller's OWN account (fn_reviveDrone always passes the local player's uid). Server-internal
// (_src==0) keeps the passed _uid. (Values already clamped below.)
private _src = remoteExecutedOwner;
if (_src != 0) then { _uid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]); };
if (_uid isEqualTo "") exitWith {};
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;
_remaining = (_remaining max 0) min 7200;
[format ["UPDATE players SET drone_revives='%2', drone_support='%3', drone_recharge_until=extract(epoch from now())::bigint+%4 WHERE playerid='%1'", _uid, (_rev max 0) min 5, (_sup max 0) min 10, round _remaining]] call DB_fnc_asyncQuery;
