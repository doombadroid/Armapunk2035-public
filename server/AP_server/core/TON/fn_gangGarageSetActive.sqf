/*
    APS_fnc_gangGarageSetActive  (LooneyBin: gang-garage PULL adapter)
    client args: [gangID, player, uid, plate, vehicle]   (fn_gangGaragePull:147)
    Flip the gang vehicle's stored row to active=1 (pulled OUT), load its stored trunk into the freshly
    created object, then CLEAR the DB copy in the SAME activate UPDATE -> the trunk lives in exactly one
    place at a time (DB when stored, live vehicle when out) = single-place anti-dupe. Mirror of the personal
    APS_fnc_vehicleSetActive. This adapter is ONLY ever called on PULL (the gang RETURN path is the separate
    APS_fnc_gangGarageStore INSERT), so active is hardcoded 1 and we target the active='0' (stored) row.
    NOTE (owner 2026-06-17 #334): the 5th client arg is the VEHICLE OBJECT (was previously typed as a Number
    `_active` -> the object was type-rejected and lost, which is why a gang trunk could never be restored).
*/
params [["_gangID",-1,[0]], ["_player",objNull,[objNull]], ["_uid","",[""]], ["_plate",-1,[0]], ["_vehicle",objNull,[objNull]]];
if (_gangID < 0 || _plate < 0) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.2 HIGH + §2.3): CfgRE-whitelisted -> a client could remoteExec
// this to PULL a RIVAL gang's stored vehicle out of their garage. Derive the actor from the non-spoofable
// remoteExecutedOwner (model fn_seizeLock:22) and require gang membership before flipping any row active.
// FLAT top-level exitWith (an exitWith nested in `then{}` only leaves the block). server-internal passes.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller || {(format ["%1", (_caller getVariable ["gang_data", [-1]]) param [0, -1]]) isNotEqualTo (format ["%1", _gangID])}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED gangGarageSetActive (not a member of gang %1) by %2", _gangID, getPlayerUID _caller]] call APS_fnc_logIt;
    if (!isNull _vehicle) then { deleteVehicle _vehicle; };   // remove the physical the client already spawned on the (now-rejected) pull
};
private _gangIDsql = (format ["%1", _gangID]) splitString "'" joinString "";   // SQL-escape (security.md §2.3)
private _plateSql  = (format ["%1", _plate])  splitString "'" joinString "";

// owner 2026-06-19 (WHOLE-VEHICLE DUPE): same in-memory active-pull claim as the personal APS_fnc_vehicleSetActive.
// The `AND active='0'` UPDATE below no-ops a duplicate DB-wise but the client already SPAWNED a 2nd physical, so
// guard it here: if this gang plate is already OUT, delete the extra physical. Suspension-free check+add = atomic.
// Key is "gangID:plate" (distinct from the personal "uid:plate" namespace). Released in APS_fnc_gangGarageStore.
private _pullKey = format ["%1:%2", _gangID, _plate];
if (isNil "AP_activeVehKeys") then { AP_activeVehKeys = []; };
private _dupe = false;   // the exitWith below only leaves its then-block; the flat exit after it stops the pull
if (_pullKey in AP_activeVehKeys) then {
    // owner 2026-06-21 (stale-key self-heal, mirror of APS_fnc_vehicleSetActive -- player107 HEMTT despawn-on-pull):
    // the key is released only via the store path (APS_fnc_gangGarageStore). An admin-delete / crash removes the
    // physical vehicle WITHOUT storing -> key stuck OUT -> every pull instantly deleted as a dupe. Only block if a
    // LIVE vehicle with this plate actually exists; otherwise the key is STALE -> drop it and let the pull proceed.
    private _liveDupe = (vehicles select {!isNull _x && {_x != _vehicle} && {alive _x}
        && {((_x getVariable ["AP_dbInfo", ["", -1]]) param [1, -1]) isEqualTo _plate}}) param [0, objNull];
    if (!isNull _liveDupe) exitWith {_dupe = true; deleteVehicle _vehicle;
        [[998, objNull, format ["VEH-DUPE BLOCKED: gang %1 re-pulled plate %2 while already OUT -> extra physical deleted.", _gangID, _plate]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
    };
    AP_activeVehKeys = AP_activeVehKeys - [_pullKey];
    [[997, objNull, format ["STALE VEH-KEY healed: gang %1 plate %2 was stuck OUT with no live vehicle (admin-delete/crash) -> key released, pull allowed.", _gangID, _plate]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
};
if (_dupe) exitWith {};
AP_activeVehKeys pushBackUnique _pullKey;

// read the stored trunk (target the active='0' stored row precisely, in case a re-store left an active='1'
// zombie row for the same plate), then clear it in the activate UPDATE so it can't be re-pulled.
private _r = [format ["SELECT COALESCE(inventory,'[]') AS inventory FROM gang_vehicles WHERE gang_id='%1' AND plate='%2' AND active = false", _gangIDsql, _plateSql], 2] call DB_fnc_asyncQuery;
private _invStr = "[]";
if (_r isEqualType [] && {count _r > 0}) then {private _v = _r select 0;
    _invStr = if (_v isEqualType "") then { _v } else { _v param [0, "[]"] };};
[format ["UPDATE gang_vehicles SET active = true, inventory='[]' WHERE gang_id='%1' AND plate='%2' AND active = false", _gangIDsql, _plateSql]] call DB_fnc_asyncQuery;

private _inv = []; if (_invStr isEqualType "") then { _inv = parseSimpleArray _invStr; };   // SECURITY: parse trunk inventory, never call compile (Lystic compile-RCE class)
if (isNull _vehicle) exitWith {};
// only restore a well-formed [[items,weight], cargo] payload; old rows (empty Trunk-typo serialization or
// NULL/'[]') don't match -> trunk just restores empty, exactly as it was. (backward compatible)
if (_inv isEqualType [] && {count _inv >= 2}) then {[_vehicle, _inv] spawn {params ["_vehicle", "_inv"];
        // same deterministic anti-race as the personal path: the client pull (fn_gangGaragePull) clears cargo,
        // sleeps 1s, then spawns fn_prepareVehicle which clears again and sets AP_vinv=[[],0] (last clobber,
        // broadcast global). Wait until AP_vinv EXISTS (client init finished), +1s grace, then restore over it.
        private _t0 = serverTime;
        waitUntil { uiSleep 0.5; isNull _vehicle || {!isNil {_vehicle getVariable "AP_vinv"}} || {serverTime - _t0 > 15} };
        uiSleep 1;
        if (isNull _vehicle) exitWith {};
        private _vinv  = _inv select 0;
        private _cargo = _inv select 1;
        if (_vinv isEqualType []) then {
            // re-derive weight from the actual item list (mirror fn_vehicleSetActive #200 self-heal).
            private _items = _vinv param [0, []];
            private _wt = if (!isNil "AP_fnc_virtItemCfg") then {private _w = 0;
                { if (_x isEqualType [] && {count _x >= 2}) then { private _iw = ["getItemWeight", (_x select 0)] call AP_fnc_virtItemCfg; if (_iw isEqualType 0) then { _w = _w + (_iw * (_x select 1)); }; }; } forEach _items;
                _w} else { if (_items isEqualTo []) then { 0 } else { _vinv param [1, 0] }; };
            _vinv = [_items, _wt];
            _vehicle setVariable ["AP_vinv", _vinv, true];};
        clearItemCargoGlobal _vehicle; clearWeaponCargoGlobal _vehicle; clearMagazineCargoGlobal _vehicle; clearBackpackCargoGlobal _vehicle;
        _cargo params [["_ic",[[],[]]],["_wc",[[],[]]],["_mc",[[],[]]],["_bc",[[],[]]]];
        { _vehicle addItemCargoGlobal     [_x, (_ic select 1) param [_forEachIndex, 1]]; } forEach (_ic param [0, []]);
        { _vehicle addWeaponCargoGlobal   [_x, (_wc select 1) param [_forEachIndex, 1]]; } forEach (_wc param [0, []]);
        { _vehicle addMagazineCargoGlobal [_x, (_mc select 1) param [_forEachIndex, 1]]; } forEach (_mc param [0, []]);
        { _vehicle addBackpackCargoGlobal [_x, (_bc select 1) param [_forEachIndex, 1]]; } forEach (_bc param [0, []]);
        diag_log format ["[LooneyBin][gangtrunk] restored trunk into %1 (vinv %2 items)", typeOf _vehicle, count (_vinv param [0, []])];};
};
