/*
    APS_fnc_varPersist  (LooneyBin -- implemented 2026-06-09; the passthrough fed [uid, varName, value]
    into the 2017 buffered player-save -> bank-money TRACING never armed (cops' dirty-cash detection
    in fn_searchClient / fn_receiveItem reads the OBJECT var AP_banktrace).)
    Sets the named whitelisted variable on the player's object, broadcast.
*/
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account var write): this trusted a client _uid and set
// the named var on WHOEVER's object matched it. Force the target to the NON-SPOOFABLE caller's OWN account
// (every legit call site passes getPlayerUID player = the caller's own uid -- fn_searchClient runs on the
// SEARCHED player's client, fn_pickupItem/receiveItem/etc all self-target), so a client can no longer set or
// clear someone ELSE's trace (e.g. plant a fake bank trace on a victim). NB: also widened the var whitelist --
// the old list only allowed AP_banktrace, so the legit AP_drugtrace / AP_choptrace persists were SILENTLY
// dropped. RESIDUAL (inherent client-trust, see security.md §1): a player can still clear their OWN trace to
// evade the dirty-cash search; the durable fix is server-side cash tracing (out of scope for this fn).
params [["_uid", "", [""]], ["_var", "", [""]], ["_val", 0]];
if (!(_var in ["AP_banktrace", "AP_drugtrace", "AP_choptrace"])) exitWith {};   // whitelist -- only known persist-vars
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
// server-internal (_src==0) has no player object -> fall back to matching the passed uid (trusted origin)
private _unit = if (_src isEqualTo 0) then {allPlayers param [allPlayers findIf { (getPlayerUID _x) isEqualTo _uid }, objNull]
} else { _caller };
if (isNull _unit) exitWith {};
_unit setVariable [_var, _val, true];
