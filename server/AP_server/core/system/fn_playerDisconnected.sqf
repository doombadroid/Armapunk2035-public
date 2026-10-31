 
_name = _this select 0;
_uid = _this select 1;
_unit = _this select 2;

// Drop this player from the server's uid -> gang map (seeded in fn_queryRequest,
// maintained in fn_updateGangMem). It is a live-players cache, not a record: a
// stale entry would answer "aligned" for somebody who is not on the server, and
// the map is rebuilt for them from the database the moment they log back in.
(localNamespace getVariable ["APS_gangOfUid", createHashMap]) deleteAt _uid;
// LooneyBin: capture EXACT logout/crash position so the player reconnects where they left
// (anti-combat-log + crash recovery), not a stale spawn from minutes ago. The server still holds
// the live unit here -> exact on a clean disconnect, within timeout-drift ("walking distance") on a
// crash. ALIVE-only (a dead player should reconnect to the spawn menu, not their corpse spot).
// queryRequest already loads the `position` column and spawns there if valid, so wiring this save
// side is all that was missing. Mode 10 = position, encoded identically to the normal periodic save.
// owner 2026-06-19 ("softlog gives the respawn screen"): `alive _unit` is UNRELIABLE in HandleDisconnect -- the
// engine flags a cleanly-disconnecting (Esc->Abort) ALIVE player's body as not-alive, so an alive softlog hit the
// old `!alive` clear and WIPED the just-saved position -> reconnect landed on the spawn-select menu instead of
// teleporting back. The respawn screen must only appear on DEATH/BLEEDOUT. Decide off the persistent markers
// instead: Revive (set true by fn_onPlayerKilled on death) / AP_downed (set by fn_handleDowned on bleedout).
// died/bleedout -> clear position (-> spawn menu); otherwise save the exact logout spot (-> reconnect teleports back).
// #260 (suicide -> alt-F4) still works: a suicide sets Revive=true, so it clears as before.
// owner 2026-06-20 (REVERTED the dead/downed-DC gear strip -- it mass-FALSE-STRIPPED live players): the prior version
// NULL'd <side>_gear whenever Revive/AP_downed read true at disconnect, but those unit vars are UNRELIABLE in
// HandleDisconnect (AP_downed/Revive get stuck-true after a botched revive or cross-side switch, and `side _unit`
// can read wrong) -> 38 strips across 16+ LIVE players, legit kits wiped on ordinary softlogs (#443/#446). A false
// strip = the player loses their WHOLE kit, far worse than a combat-logger keeping gear. So NO gear strip here.
// Position only (low-stakes -- a wrong call is just spawn-menu vs teleport, never item loss), and ONLY for a CIVILIAN:
// cops/medics spawn at HQ and never restore `position`, and writing it for them bled their cop/medic logoff spot into
// the shared `position` column so a later login on the same account spawned there (#439).
// owner 2026-06-20: gate on the side recorded at CONNECT (`AP_connected` at the time -- see the note below on
// what became of it), NOT `side _unit` -- the
// engine can report `side _unit` as civilian for a disconnecting COP, so the old gate SAVED a cop's PD logoff spot and
// a later CIV login on that account then spawned INSIDE the PD with a full civ loadout (free "raid the police"). Cops
// must ALWAYS reconnect to respawn (HQ/spawn-select); only a real civilian's exact spot is ever saved.
// A ROSTERED PLAYER'S POSITION IS NEVER WRITTEN HERE. `position` is the civilian character's reconnect spot,
// and an on-duty officer's is already in the row: AP_fnc_dutyClient flushes mode 10 while AP_effSide still
// says civilian, immediately before the flip (fn_dutyClient.sqf, the clock-on civ flush), precisely so the
// player reconnects where they were standing when they signed on rather than at the HQ they logged off from.
// Saving the logoff spot on top of it is #439 by a different door -- and worse than the original, because the
// stash it overwrites is the only copy. Unrostered players (everyone, on a flag-false server) are untouched.
//
// REVIVED (PR10). This block was inert from the day queryRequest landed: its side source was
// `AP_connected`, written only by the deleted legacy join path, so `_connSide` was permanently east and
// no player's logout spot was ever saved -- the owner-reported "spawn screen despite logging out alive"
// is (in part) this save never running while the client-side periodic savers wiped position to [] inside
// the old respawn_civilian ring. Post-flip the ROSTER is the side source, exactly as the old note here
// prescribed: `_dutyRow isEqualTo []` reads "an UNROSTERED player", i.e. a civilian -- a modified client
// cannot forge it, and an on-shift officer's disconnect never touches the shared civilian `position`
// column (#439, and the owner's faction-swap requirement).
// Guards, in order:
//   - dead / bleeding out -> [] (the death sentinel: reconnect gets the spawn menu, never a restore
//     alive at the death spot);
//   - held pre-spawn (the 50 km mission.sqm slot; anything > 400 m ATL is not a place a civilian on
//     foot can be) -> write NOTHING, the stored position is still their real one;
//   - robbery no-sync rings (bank / fed / armory) and the cartel + mental-hospital relocate zones ->
//     write NOTHING, matching the periodic savers: a combat-log out of a robbery must not reconnect
//     inside the vault, so the DB keeps their last out-of-zone save;
//   - origin junk (< 100 m of [0,0,0], the debug island) -> [] (spawn menu, never a debug-island
//     teleport);
//   - otherwise -> the EXACT logoff spot, aircraft clamped to z=1 like the periodic savers.
private _dutyRow = _uid call APS_fnc_dutyLookup;
// Raw roster row, read BEFORE the release call below empties it: slot 3 is the clock-on position
// (dutyLookup deliberately does not return it -- its own header says to read the roster directly).
// Consumed by the rostered write-back after the release, where the save routes as civilian again.
private _dutyRowRaw = if (isNil {localNamespace getVariable "AP_dutyRoster"}) then { [] } else { (localNamespace getVariable "AP_dutyRoster") getOrDefault [_uid, []] };
if (!isNull _unit && {_uid != ""} && {_dutyRow isEqualTo []}) then {
    // Dead test is ENGINE-authoritative (alive / lifeState), not the Revive/AP_downed unit vars -- the
    // bodybag block below documents those exact vars going stuck-true, and a stuck-true here would wipe
    // a living player's position to [] on every later clean logout.
    if ((!alive _unit) || {(lifeState _unit) isEqualTo "INCAPACITATED"}) then {
        [_unit, civilian, _uid, 10, []] call DB_fnc_updatePartial;
    } else {
        private _lp = getPosATL _unit;
        private _held = (_lp select 2) > 400;
        private _inNoSync = ([["AP_bank_door", 55], ["fed_reserve", 185], ["armory_marker", 220],
            ["arms_cartel", 200], ["drug_cartel", 200], ["oil_cartel", 200], ["wongs_cartel", 200],
            ["AP_mentalHospital", 200]] findIf {(_unit distance (getMarkerPos (_x select 0))) <= (_x select 1)}) > -1;
        if (!_held && {!_inNoSync}) then {
            if ((_lp distance [0,0,0]) > 100) then {
                if (!isNull objectParent _unit && {(objectParent _unit) isKindOf "Air"}) then {_lp set [2, 1];};
                [_unit, civilian, _uid, 10, _lp] call DB_fnc_updatePartial;   // alive softlog -> save exact spot -> teleport back
            } else {
                [_unit, civilian, _uid, 10, []] call DB_fnc_updatePartial;
            };
        };
    };
}; {if (typeName _x == "OBJECT") then {
_changed = _x getVariable["lootModified", false]; 
if (_changed) then {[_x] spawn DB_fnc_updateStorage;
sleep 2;};};} forEach AP_storage_array;
 
// owner 2026-06-13: free the leaver's phone-call LINE so the pool doesn't leak. The old managePhone(objNull)
// call had no player ref so it freed nothing -> a disconnect mid-call pinned a channel forever -> the pool
// drained -> "too many people making phone calls" for everyone. End their active call by their unit ref.
if (!isNil "AP_phoneCalls" && {!isNull _unit}) then {
    private _pi = AP_phoneCalls findIf { ((_x select 1) isEqualTo _unit) || {(_x select 2) isEqualTo _unit} };
    if (_pi > -1) then {["endPhoneCall", [(AP_phoneCalls select _pi) select 0, _unit]] call APS_fnc_handlePhoneCallSRV;};};
// owner 2026-06-16 (DISCONNECT-DUPE, CLANKR HIGH): if the leaver alt+F4'd with a HOUSE storage open, the
// normal close-save (APS_fnc_updateHouseTrunk) never fired -> the house DB row still holds the items they
// pulled AND their gear flushes WITH those items = DUPE. The house object already carries the CURRENT
// (post-take) AP_vinv (set global by fn_storeInventory/fn_takeInventory) and AP_activeTrunk == the leaver
// while open. Force-persist that house here, BEFORE flushPlayer saves their gear, so the removal is recorded.
// owner 2026-09-26 SECURITY (houses review): AP_activeTrunk, AP_houseID and the house's AP_vinv/AP_pinv are all
// client-writable, so this save let a leaver overwrite ANY house row. Persist only the session
// APS_fnc_initHouseInventory recorded server-side for this uid, to the row it authorised (updateHouseTrunk sanitises).
private _hSes = localNamespace getVariable ["APS_houseSessions", createHashMap];
private _hs = _hSes getOrDefault [_uid, []];
_hSes deleteAt _uid;
if (!isNull (_hs param [0, objNull])) then { [objNull, _hs select 0, [], [], -1, _hs select 1] call APS_fnc_updateHouseTrunk; };
if (!isNull _unit) then {{if ((_x getVariable ["AP_activeTrunk", objNull]) isEqualTo _unit) then {
			_x setVariable ["AP_activeTrunk", nil, true];};} forEach (nearestObjects [getPosATL _unit, ["House_F", "Car", "Air", "Ship"], 50]);};
// owner 2026-07-08 (casino): a hard disconnect never fires the hilo/blackjack "quit" teardown, so the server-side
// run state (AP_casinoHiLo / AP_bjGames, keyed by uid) was orphaned -- it leaked the HashMap entry AND left the
// client-debited wager with no matching result row, so CLANKR's casino mass-balance drifted (the forfeited loss
// was never booked). Clear both here and BOOK the forfeited bet as a house win so the ledger closes. deleteAt is
// idempotent, so a late-arriving client "quit" can't double-log. Also drop the per-uid cooldown / free-claim vars.
// pass the UNIT to logIt when it's still valid so the row is attributed to the player's NAME (APS_fnc_logIt only
// derives name from a unit arg -- a bare uid string leaves name='SERVER', which mis-groups the forfeit in the econ
// digest); fall back to the uid string on a crash where the unit is null (playerid still correct either way).
private _logWho = if (isNull _unit) then { _uid } else { _unit };
if (!isNil "AP_casinoHiLo") then {private _run = AP_casinoHiLo getOrDefault [_uid, []];
    if (_run isNotEqualTo []) then {
        ["-CASINOHL-", _logWho, format ["net $-%1 (hilo forfeited on disconnect at mult %2)", _run param [2, 0], _run param [1, 1]]] call APS_fnc_logIt;
    };
    AP_casinoHiLo deleteAt _uid;};
if (!isNil "AP_bjGames") then {private _bg = AP_bjGames getOrDefault [_uid, []];
    if (_bg isNotEqualTo []) then {
        ["-CASINOBJ-", _logWho, format ["net $-%1 (blackjack forfeited on disconnect)", _bg param [5, 0]]] call APS_fnc_logIt;};
    AP_bjGames deleteAt _uid;};
// owner 2026-08-20 (hold'em): a hard disconnect never fires the dialog's "close", so the seat would sit
// there holding five other players on a 20 s clock every orbit AND holding a stack that is now
// unreachable. APS_fnc_holdemSRV's "disconnect" case folds the hand (the chips already committed stay in
// the pot, which is what folding means), banks the REMAINING stack straight to the players row -- the
// client cache is about to stop existing -- and frees the seat. A plain local `call`, never a remoteExec:
// the case asserts remoteExecutedOwner == 0 because allowedTargets = 2 restricts the TARGET and not the
// sender, so a wire-reachable "disconnect" would let any client stand any player up and bank their chips.
// This handler is spawned from server_init.sqf's HandleDisconnect on the server, so the assertion holds.
if (!isNil "AP_holdemTable") then { ["disconnect", [_uid]] call APS_fnc_holdemSRV; };
missionNamespace setVariable [format ["AP_casinoCD_%1", _uid], nil];
missionNamespace setVariable [format ["AP_bjCD_%1", _uid], nil];
if (!isNil "AP_casinoWheelFreeMem") then { AP_casinoWheelFreeMem deleteAt _uid; };
if (!isNil "AP_casinoVehDay") then { AP_casinoVehDay deleteAt _uid; };

[_uid] spawn APS_fnc_cleanupStorage;
[_uid] spawn APS_fnc_cleanupHouses; 
[[_uid],"AP_fnc_removeBounty",true,false] spawn AP_fnc_MP;
["-DISCONNECT-", _uid, format ["%1 disconnected", _name]] call APS_fnc_logIt;
// DUTY ROSTER LAST, AFTER EVERY SAVE AND FLUSH ABOVE. Dropping the entry stamps a cooldown, republishes the
// headcounts and frees the uid to sign on again, so it must not happen while anything that reads the roster
// is still deciding where to write. It is a plain local `call`, never a remoteExec: APS_fnc_dutySRV's
// "disconnect" case asserts remoteExecutedOwner == 0 because allowedTargets = 2 restricts the TARGET and not
// the sender, so a wire-reachable "disconnect" would let any client drop any player off the roster. This
// handler is spawned from server_init.sqf's HandleDisconnect on the server, so the assertion holds.
// Source order is the achievable ordering, and it is now sufficient outright rather than nearly: every save
// above is synchronous or self-contained. The one asynchronous drain that used to sit here -- `[_uid] spawn
// DB_fnc_flushPlayer`, draining AP_update_buffer through DB_fnc_update -- was dead code and is deleted with
// the rest of that path in this PR. The buffer had exactly two writers, APS_fnc_update (zero callers
// anywhere) and DB_fnc_setDeadState (whose only call site was an MPKilled handler registered by the equally
// dead APS_fnc_query), so it was permanently [] and the drain drained nothing.
// Nothing above routes by roster except the position save, which is gated on it and runs first.
// The call is a no-op for an unrostered player and for the entire server while AP_dutyEnabled is false (the
// function's own first line), so this changes nothing until the flip. It replaces the 60s sweep as the
// PRIMARY path -- the sweep stays as the backstop for a crash that never fires this handler at all.
["disconnect", _uid] call APS_fnc_dutySRV;
// MID-SHIFT DISCONNECT: restore the civilian's position column to the CLOCK-ON spot (roster slot 3,
// captured above before the release emptied the row). The civilian character's last real location is
// where they stood when the shift began; without this, a shift begun soon after a death or a spawn
// leaves the column holding the death sentinel and the returning civilian gets the spawn menu despite
// having been alive in the world (owner playtest, 2026-08-20). Runs AFTER the release on purpose:
// DB_fnc_updatePartial routes a CONFIRMED rostered uid's writes to the duty side and would refuse the
// civ position; with the row gone it routes civilian again. The write is skipped -- keeping whatever
// the column already holds -- when the clock-on spot is not a place a civilian stands: the 50 km
// landing-deploy hold (z > 400), origin junk, or inside the robbery no-sync rings.
if (!isNull _unit && {_uid != ""} && {_dutyRowRaw isNotEqualTo []}) then {
    private _sp = _dutyRowRaw param [3, []];
    if ((_sp isEqualType []) && {count _sp >= 3} && {(_sp select 2) <= 400} && {(_sp distance [0,0,0]) > 100}) then {
        private _inNoSync = ([["AP_bank_door", 55], ["fed_reserve", 185], ["armory_marker", 220],
            ["arms_cartel", 200], ["drug_cartel", 200], ["oil_cartel", 200], ["wongs_cartel", 200],
            ["AP_mentalHospital", 200]] findIf {(_sp distance (getMarkerPos (_x select 0))) <= (_x select 1)}) > -1;
        if (!_inNoSync) then {
            [_unit, civilian, _uid, 10, _sp] call DB_fnc_updatePartial;
            diag_log format ["[AP-DUTY] disconnect mid-shift: civilian position restored to clock-on spot %1 for %2", _sp, _uid];
        };
    };
};
// owner 2026-06-27 (combat-log fugitive bodybag): a WANTED/bountied player who logs out drops a tagged "Fugitive
// Bodybag" object at their exact spot. MaxSec (any rank) OR the bounty hunter tracking their bounty can scroll-wheel it
// (fn_setupActions -> APS_fnc_claimBodybagSRV) to JAIL them on their next login (persisted to players.arrested,
// survives a restart) + collect the full bounty + a combat-log bonus. Replaces the old cop-within-150m auto-jail
// (no interaction / no payout). The bounty stays in the wanted list (localNamespace APS_wantedList) until the bag is claimed. Server-authoritative
// wanted gate, so an innocent/AFK disconnect drops nothing. `owner` is tagged so fn_cleanup's ownerless-reap
// (core/.../fn_cleanup.sqf -- instant-deletes spawned objects with no owner var) doesn't vaporize the bag.
// owner 2026-06-29: only drop the bag if the fugitive logged while DOWNED or RESTRAINED (i.e. escaping arrest),
// not on a clean disconnect while free. lifeState "INCAPACITATED" is the engine-authoritative downed signal
// (setUnconscious in fn_handleDowned:143), so it's immune to the stuck-true AP_downed/Revive vars this file warns
// about above; AP_restrained is cleared to nil on un-restrain (fn_unrestrain), so it's reliable at disconnect.
if (!isNull _unit
    && {((lifeState _unit) isEqualTo "INCAPACITATED") || {_unit getVariable ["AP_restrained", false]}}
    && {((localNamespace getVariable "APS_wantedList") findIf { _uid in _x }) != -1}) then {
    private _wl   = localNamespace getVariable "APS_wantedList";
    private _we   = _wl select (_wl findIf { _uid in _x });
    private _bpos = getPosATL _unit;
    // owner 2026-06-28: use the real body-bag model (matches the loony-bin "patient remains" -- fn_loonyBinSRV).
    // It's flat + un-targetable by cursorObject, which is WHY the loony bin abandoned it; the radius addAction
    // below (not cursorObject) makes it claimable anyway.
    private _bag  = createVehicle ["Land_Bodybag_01_black_F", _bpos, [], 0, "CAN_COLLIDE"];
    _bag setPosATL _bpos;
    _bag setVariable ["owner", _bag, true];
    // WHO is in the bag lives in a server-only registry, never on the object: object vars are client-writable,
    // and APS_fnc_claimBodybagSRV used to jail whatever UID a client wrote onto any object (srvmisc-0-1).
    private _bbReg = localNamespace getVariable "APS_bodybags";   // created in vars.sqf (a lazy create here could race)
    _bbReg set [netId _bag, [_uid, _name, _we param [3, 0], _we param [4, 0]]];
    _bag allowDamage false;
    // owner 2026-06-28 (bodybag had NO usable scroll-wheel): put the claim action ON THE BAG (global + JIP) instead
    // of the old player+cursorObject scroll. A small flat body bag is near-impossible to land cursorObject on,
    // and the old client gate ALSO required the BH to be actively TRACKING this fugitive (AP_bounty_list) -- stricter
    // than the server's "any cop/BH" gate. Radius action shows for any cop / licensed BH within 6m; the real auth is
    // APS_fnc_claimBodybagSRV. Sim stays ON so the bag presents its own addAction (sim-off objects hide theirs).
    private _act = ["<t color='#FF8000'>Send Fugitive to Jail</t>", { [[_this select 0, AP_side_talents], "APS_fnc_claimBodybagSRV", 2] spawn AP_fnc_MP; }, nil, 6, true, true, "", "((side _this) isEqualTo west || {license_civ_bounty}) && {(_this distance _target) < 6} && {!(_target getVariable ['AP_bbClaimed', false])}", 6];
    [_bag, _act] remoteExec ["addAction", 0, _bag];
    // ping the drop location to MaxSec + bounty hunters (existing client marker fn, self-expires 60s)
    { [[_bpos, _name], "AP_fnc_bodybagMarker", _x, false] spawn AP_fnc_MP; } forEach (allPlayers select { (_x call APS_fnc_isDutyCop) || {_x getVariable ["AP_isBountyHunter", false]} });
    ["-COMBATLOG-", _uid, format ["%1 combat-logged WANTED -> fugitive bodybag at %2 (bounty $%3, %4s)", _name, _bpos, (_we param [3, 0]), (_we param [4, 0])]] call APS_fnc_logIt;
    // auto-despawn the bag after 30 min if nobody claims it
    [_bag, netId _bag] spawn { params ["_b", "_k"]; uiSleep 1800; (localNamespace getVariable ["APS_bodybags", createHashMap]) deleteAt _k; if (!isNull _b) then { deleteVehicle _b; }; };
};
// The AP_connected/AP_disconnects bookkeeping that stood here is gone with the arrays. It maintained a
// side-switch cooldown list that only APS_fnc_query ever read, so it wrote to nothing for as long as
// DB_fnc_queryRequest has been the login path -- and post-flip there are no sides to switch between.
 
_query = format["DELETE FROM online WHERE playerid='%1' AND instance=%2", _uid, (localNamespace getVariable "APS_serverInstance")]; 
[_query,1] call DB_fnc_asyncQuery; 
sleep 3; {
// LooneyBin: the 2020 client tags its unit with "AP_steamid" (core/init.sqf), but this 2017
// cleanup looked up "steam64ID" -> never matched -> the disconnected body was never deleted,
// leaving a corpse holding the player's gear and forcing a fresh naked body each relog. Check
// AP_steamid first, fall back to the old name.
_pid = _x getVariable["AP_steamid", _x getVariable["steam64ID","0"]];
if (_uid == _pid) then {if (!isNull (_x getVariable["blindfold", objNull])) then { deleteVehicle (_x getVariable["blindfold"]); };
_containers = nearestObjects [_x,["WeaponHolderSimulated"],5];  
{deleteVehicle _x;} foreach _containers;  
deleteVehicle _x;};} foreach allDeadMen;

// LooneyBin: the allDeadMen sweep only catches DEAD bodies. A disconnected player's unit is often
// still ALIVE (frozen AI) -> never in allDeadMen -> left standing as a "body" wearing the player's
// gear. We already have the unit directly (HandleDisconnect _this select 2), so delete it outright.
if (!isNull _unit) then {{ deleteVehicle _x; } forEach (nearestObjects [_unit, ["WeaponHolderSimulated"], 6]);
    deleteVehicle _unit;};
// owner 2026-06-20: the post-flush dead/downed-DC gear strip was REMOVED here (see the top of this file) -- it was
// false-stripping live players' kits via unreliable HandleDisconnect state. Re-add anti-combat-log ONLY with a
// reliable signal (a DB death/down marker stamped by onPlayerKilled/handleDowned + checked here), never volatile unit vars.
