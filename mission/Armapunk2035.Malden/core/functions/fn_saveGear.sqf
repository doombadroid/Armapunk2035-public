params[["_save", false, [false]]];
// LooneyBin: respawn_west marker is ABSENT from mission.sqm -> getMarkerPos returns [0,0,0]. The
// "don't save gear at the MaxSec base" guard then became "don't save within 1000m of map origin", which
// fires during spawn-in (player sits ~229m from [0,0,0] in the holding spot before teleporting to
// town) -> EVERY spawn gear save aborted -> civ_gear never saved -> permanent default/naked. Only
// apply the proximity guard when respawn_west actually exists.
private _rwPos = getMarkerPos "respawn_west";
// Armapunk 2035 (PR6 fix round 2): respawn_west now sits AT the MaxSec HQ terminal (fn_dutyFlushBlock.sqf's
// header has the full trace), so a duty swap's own civ-gear flush -- called from right on top of the anchor
// -- would otherwise always land inside this ring. AP_dutyFlushBypass is set true by fn_dutyClient.sqf only
// for the instant of its own flush calls (both directions) and false the rest of the time, so it exempts
// THIS clause alone; the arrested/dead/gunBroken conditions it is OR'd with below are untouched, and every
// organic call site (periodic PFH, spawn-in, fn_ClupdateRequest.sqf's own save) reads the flag's false
// default and stays ring-blocked.
// THE RING'S PURPOSE AND ITS KNOB. The ring exists to stop gear being saved at the MaxSec base -- kit
// taken from the armoury there is meant to be a shift's issue, not something a save bakes into a
// persisted loadout. It is NOT a persistence policy for the surrounding map, and at its old hardcoded
// 1000 m it had become one: respawn_west sits at the HQ terminal now, and a 1000 m ring from there
// covers fed_reserve (808 m) and jail_marker2 (751 m), so no gear save persisted at either heist --
// a dupe going in (spend inside the ring, disconnect, the DB rolls it back) and a loss coming out.
// The radius is now SRV_baseNoSaveRadius, published by server_init.sqf (see its comment for the
// derivation of 75). The default in the getVariable is the same 75, so a client reading it before the
// publish lands behaves identically. The two sibling clauses -- fn_ClupdatePartial.sqf's case 3 and
// fn_ClupdateRequest.sqf's own save gate -- read the same variable; change it in server_init, not here.
private _nearRespawnWest = (_rwPos isNotEqualTo [0,0,0]) && {(player distance _rwPos) < (missionNamespace getVariable ["SRV_baseNoSaveRadius", 75])} && {!(missionNamespace getVariable ["AP_dutyFlushBypass", false])};
// owner 2026-06-21 (#440 "can't use guns after restart"): do NOT save gear while the gun is in the cop
// "firing pin removed" broken state. fn_breakGuns empties the loaded mag in-place (setAmmo 0) + a while-loop
// keeps it dry; getUnitLoadout captures that EMPTY-mag gun, so a periodic/restart save baked a permanently-
// unfireable weapon into civ_gear that reloaded broken EVERY restart (the AP_gunBroken FLAG isn't persisted,
// but the damaged loadout WAS). Skipping the save while broken keeps the last GOOD loadout; fixFiringPin
// reloads on repair so post-repair saves are clean too. Relog/restart-while-broken now restore a full gun.
if (((AP_is_arrested param [0,0]) isEqualTo 1) || _nearRespawnWest || AP_isDead || (player getVariable ["AP_gunBroken", false])) exitWith {};
private _loadout = getUnitLoadout player;
private _formatedInv = [];
private _formatedWeight = 0; {private _val = missionNameSpace getVariable [format["AP_inv_%1", _x], 0];
    if (_val > 0) then {private _itemWeight = (["getItemWeight", _x] call AP_fnc_virtItemCfg) * _val;
        _formatedInv pushBack[_x, _val];
        _formatedWeight = _formatedWeight + _itemWeight;};}
forEach([2] call AP_fnc_virtItemCfg);
// LooneyBin: AP_uniformBackpack_skins (clothing texture indices) is never globally initialized and
// the side-specific setter (requestReceived) doesn't always run -> it was nil -> serialized into the
// saved gear as `any`, corrupting civ_gear so the reload couldn't parse it (player got default
// clothes). Default it before building the save packet.
if (isNil "AP_uniformBackpack_skins") then { AP_uniformBackpack_skins = [-1, -1]; };
private _return = [_loadout, [_formatedInv, _formatedWeight], AP_uniformBackpack_skins];
AP_gear = _return;
// Armapunk 2035 (faction rework PR5): ON DUTY COUNTS AS "has a character worth persisting". The civilian-only
// test dates from when the only non-civilians were login-side cops and medics, who are re-kitted at HQ on every
// connect and have no periodic gear save of their own to want. A duty officer is the opposite case: their kit
// comes out of cop_gear/med_gear and goes back into it, and every one of this function's ~20 [true] call sites
// is an inventory or shop event that has just changed it. Without this the 240s loop (fn_initCiv.sqf:186) and
// every buy/sell/store/give rebuilt AP_gear and persisted NOTHING for the whole shift, so a crash or a timeout
// on duty reverted the officer to whatever cop_gear held at sign-on. The column it lands in is the SERVER's
// choice, not this side test's -- DB_fnc_updatePartial routes mode 3 by the duty roster.
// AP_onDuty is only ever true after APS_fnc_dutySRV has granted a shift, so on a flag-false server this reads
// exactly as it did before: civilians save, nobody else does.
if (_save && {(AP_effSide isEqualTo civilian) || {missionNamespace getVariable ["AP_onDuty", false]}}) then {[3] call AP_fnc_ClupdatePartial;};