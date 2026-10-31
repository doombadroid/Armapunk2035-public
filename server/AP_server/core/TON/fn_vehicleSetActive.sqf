/*
    APS_fnc_vehicleSetActive  (LooneyBin: 2020 garage-pull adapter)
    2020 client args : [player, _plate, _vehicle]   (fn_vehicleGaragePull :156)
    Flips the stored row to active=1 (vehicle pulled OUT) and re-stamps ownership vars on the
    freshly created object so it can be stored again. Targeted UPDATE (active only) so the stored
    fuel/damage/alarm are not clobbered by the full-fuel just-spawned vehicle.
    Replaces the old passthrough stub to DB_fnc_updateVehicle (got _plate=player -> -1 -> no-op).
*/
params [["_player",objNull,[objNull]], ["_plate",-1,[0]], ["_vehicle",objNull,[objNull]]];
if (isNull _player || _plate < 0 || isNull _vehicle) exitWith {};

// owner 2026-07-24 SECURITY (audit: copy-paste divergence). The GANG twin
// (APS_fnc_gangGarageSetActive) was hardened on 2026-06-23 with a remoteExecutedOwner gate, but this
// personal-garage adapter -- same feature, same author, also CfgRE allowedTargets=2 -- never got it. It
// derived the owner uid from the client-supplied _player object, so a modified client could pass ANOTHER
// player's object and pull that player's stored vehicle by plate: the row flips active=1, their stored
// trunk is loaded into the attacker's spawned vehicle, and the DB copy is CLEARED (the anti-dupe step) --
// stealing the trunk and destroying the victim's stored inventory in one call.
// Same shape as the twin, including deleting the physical the client already spawned on a rejected pull.
// FLAT top-level exitWith (an exitWith nested in then{} would only leave the block). server-internal passes.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller || {_caller isNotEqualTo _player}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED vehicleSetActive for another player (target=%1, plate %2)", getPlayerUID _player, _plate]] call APS_fnc_logIt;
    if (!isNull _vehicle) then { deleteVehicle _vehicle; };};

private _uid = getPlayerUID _player;
if (_uid == "") exitWith {};

// owner 2026-06-19 (WHOLE-VEHICLE DUPE -- player100, store<->repull): the pull is CLIENT-spawned (createVehicle) and this
// adapter then async-flips active=1 with NO `active=0` guard, so the comment's "a vehicle can't be pulled while
// active=1" invariant was never actually enforced -- a second pull of the same garage entry (the DB flip is async,
// and a store leaves a ~1s window where the row is active=0 but the physical still exists) spawned a SECOND
// physical vehicle backed by ONE row = a duped vehicle. Enforce the invariant server-authoritatively with an
// in-memory claim. CRITICAL: check+add with NO suspension between them (no uiSleep/asyncQuery), so it's atomic vs a
// concurrent pull. If the plate is already OUT, THIS createVehicle is the duplicate -> delete it. Released on store
// (DB_fnc_updateVehicle active=0); the set resets on restart (out vehicles aren't garage-listed, so no dupe window).
private _pullKey = format ["%1:%2", _uid, _plate];
if (isNil "AP_activeVehKeys") then { AP_activeVehKeys = []; };
private _dupe = false;   // the exitWith below only leaves its then-block; the flat exit after it stops the pull
if (_pullKey in AP_activeVehKeys) then {
    // owner 2026-06-21 (player107 HEMTT "despawns instantly on pull"): the key is released ONLY via the store path
    // (DB_fnc_updateVehicle active=0). An ADMIN-DELETE (or a crash) removes the physical vehicle WITHOUT storing,
    // so the key is never released -> the plate is stuck "OUT" -> every future pull is flagged a dupe and the
    // fresh spawn is instantly deleted = "despawns on pull", un-fixable until a restart resets the set. Self-heal:
    // only treat this as a REAL dupe if a LIVE vehicle with this plate actually exists in the world; if none does,
    // the key is STALE -> drop it and let this pull proceed (re-claimed below). Plates are globally unique, so a
    // plate match identifies the same vehicle.
    private _liveDupe = (vehicles select {!isNull _x && {_x != _vehicle} && {alive _x}
        && {((_x getVariable ["AP_dbInfo", ["", -1]]) param [1, -1]) isEqualTo _plate}}) param [0, objNull];
    if (!isNull _liveDupe) exitWith {_dupe = true; deleteVehicle _vehicle;
        [[998, objNull, format ["VEH-DUPE BLOCKED: %1 re-pulled plate %2 while it was already OUT -> extra physical deleted (store<->repull whole-vehicle dupe).", _uid, _plate]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
    };
    AP_activeVehKeys = AP_activeVehKeys - [_pullKey];
    [[997, objNull, format ["STALE VEH-KEY healed: %1 plate %2 was stuck OUT with no live vehicle (admin-delete/crash) -> key released, pull allowed.", _uid, _plate]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
};
if (_dupe) exitWith {};
AP_activeVehKeys pushBackUnique _pullKey;

// LooneyBin (persistent trunk): load the stored trunk into the pulled vehicle, then CLEAR the DB copy in
// the same activate UPDATE -> the trunk now lives only in the live vehicle (re-saved on next store). This
// single-place invariant is the anti-dupe: a vehicle can't be pulled while active=1, and the DB no longer
// holds the trunk once pulled, so you can't re-pull the same trunk after extracting from it.
private _r = [format ["SELECT COALESCE(inventory,'[]') AS inventory, COALESCE(rig_kind,'') AS rig_kind FROM %1 WHERE pid='%2' AND plate='%3'", "vehicles", _uid, _plate], 2] call DB_fnc_asyncQuery;
private _invStr = "[]";
private _rigKind = "";
// ROW SHAPE (bug 2026-08-27, "flatbed with no mining gear"): mode 2 without _multiarr returns THE
// ROW ITSELF (fn_asyncQuery: `_return = _return select 0`), so for this 2-column SELECT _r is
// ["<invJson>","extractor"] -- `_r select 0` is the inventory STRING, and the old string-branch ate
// it and never read rig_kind, so adopt never fired on garage pulls (script spawn worked: it calls
// adopt directly). Treat _r as the row; tolerate a wrapped [[...]] shape defensively.
if (_r isEqualType [] && {count _r > 0}) then {
    private _row = if ((_r select 0) isEqualType []) then { _r select 0 } else { _r };
    _invStr = format ["%1", _row param [0, "[]"]];
    _rigKind = format ["%1", _row param [1, ""]];
};
// RESOURCE RIG: a garage pull re-adopts the truck's identity from its own DB
// row -- textures, published vars, client visuals, the works. One copy of the
// adoption (APS_fnc_rigAdopt, not whitelisted), whatever door the truck came through.
if (_rigKind in ["extractor", "processor"]) then {
    [_vehicle, _rigKind] call APS_fnc_rigAdopt;
};
// DB copy cleared IMMEDIATELY (anti-dupe unchanged); the in-vehicle restore is DELAYED 3s because the
// client's post-spawn init (fn_vehicleGaragePull:175 clearItemCargoGlobal + fn_prepareVehicle:10/43
// cargo clears & AP_vinv=[[],0]) runs right after spawn and was WIPING an instant restore (live-test
// steamuser 2026-06-12: DB row saved fine, vehicle came back empty).
[format ["UPDATE %1 SET active = true, inventory='[]' WHERE pid='%2' AND plate='%3'", "vehicles", _uid, _plate]] call DB_fnc_asyncQuery;
private _inv = []; if (_invStr isEqualType "") then { _inv = parseSimpleArray _invStr; };   // SECURITY: parse trunk inventory, never call compile (an item-class string with a quote/backtick would execute; Lystic class)
if (_inv isEqualType [] && {count _inv >= 2}) then {[_vehicle, _inv] spawn {params ["_vehicle", "_inv"];
        // Deterministic anti-race (flat 3s still lost to the scheduler): the client's pull path wipes
        // cargo, sleeps 1s, THEN spawns fn_prepareVehicle which wipes again and sets AP_vinv=[[],0]
        // (its last clobber, broadcast global). So wait until AP_vinv EXISTS on the vehicle (= the
        // client init finished), +1s grace, then restore over it. 15s timeout = restore anyway.
        private _t0 = serverTime;
        waitUntil { uiSleep 0.5; isNull _vehicle || {!isNil {_vehicle getVariable "AP_vinv"}} || {serverTime - _t0 > 15} };
        uiSleep 1;
        if (isNull _vehicle) exitWith {};
        private _vinv  = _inv select 0;
        private _cargo = _inv select 1;
        if (_vinv isEqualType []) then {
            // owner 2026-06-14 (#200): RE-DERIVE the trunk weight from the actual item list before applying.
            // Rows stored under the old illegal-item filter saved [[], <stale weight>] -- the filter dropped
            // illegal items (e.g. 208 bluemeth = 416 wt) from the list but never decremented the weight, so a
            // pulled tempest read ~419/1250 used with an EMPTY trunk. Recomputing here self-heals every
            // desynced row on pull and reproduces the identical number for correct rows (harmless).
            private _items = _vinv param [0, []];
            private _wt = if (!isNil "AP_fnc_virtItemCfg") then {private _w = 0; {if (_x isEqualType [] && {count _x >= 2}) then {
                        private _iw = ["getItemWeight", (_x select 0)] call AP_fnc_virtItemCfg;
                        if (_iw isEqualType 0) then { _w = _w + (_iw * (_x select 1)); };};} forEach _items;
                _w} else {if (_items isEqualTo []) then { 0 } else { _vinv param [1, 0] };};
            _vinv = [_items, _wt];
            _vehicle setVariable ["AP_vinv", _vinv, true];};
        // owner 2026-06-26 reconcile: DISABLED infamous's toolkit re-add -- it ERRORED every trunk restore (undefined
        // _repairKits at the `if (_repairKits)` below -- declared in this inner block's scope) AND its condition is always
        // false (`"ToolKit" in _cargo` -- ToolKit is nested in the item-cargo sub-array, not a top-level element). Also
        // redundant: the cargo loops below already restore whatever (incl. ToolKits) was in the trunk; re-adding would
        // DUPE the toolkit/pack + grant 2 free FAKs. If toolkits are genuinely lost, fix the trunk SAVE, not here.
        // if ("ToolKit" in _cargo && "B_AssaultPack_cbr" in _cargo) then { private _repairKits = true; };
        clearItemCargoGlobal _vehicle; clearWeaponCargoGlobal _vehicle; clearMagazineCargoGlobal _vehicle; clearBackpackCargoGlobal _vehicle;
        _cargo params [["_ic",[[],[]]],["_wc",[[],[]]],["_mc",[[],[]]],["_bc",[[],[]]]];
        { _vehicle addItemCargoGlobal     [_x, (_ic select 1) param [_forEachIndex, 1]]; } forEach (_ic param [0, []]);
        { _vehicle addWeaponCargoGlobal   [_x, (_wc select 1) param [_forEachIndex, 1]]; } forEach (_wc param [0, []]);
        { _vehicle addMagazineCargoGlobal [_x, (_mc select 1) param [_forEachIndex, 1]]; } forEach (_mc param [0, []]);
        { _vehicle addBackpackCargoGlobal [_x, (_bc select 1) param [_forEachIndex, 1]]; } forEach (_bc param [0, []]);
        // if (_repairKits) then { _vehicle addItemCargoGlobal ["ToolKit", 1]; _vehicle addItemCargoGlobal ["FirstAidKit", 2]; _vehicle addBackpackCargoGlobal ["B_AssaultPack_cbr", 1]; };  // owner 2026-06-26: disabled (see note above)
        diag_log format ["[LooneyBin][trunk] restored trunk into %1 (vinv %2 items)", typeOf _vehicle, count (_vinv param [0, []])];};};

// Client already set AP_dbInfo on the pulled vehicle; reinforce + add dbInfo for 2017 server readers.
_vehicle setVariable ["AP_dbInfo", [_uid, _plate], true];
_vehicle setVariable ["dbInfo", [_uid, _plate, 0, false], true];
