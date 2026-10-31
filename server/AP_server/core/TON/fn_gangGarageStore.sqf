/*
    APS_fnc_gangGarageStore  (LooneyBin)
    client args: [gangID, vehicle, player, uid]
    Move a live vehicle into the gang garage: insert gang_vehicles row, drop the
    personal vehicles row + the world object.
*/
params [["_gangID",-1,[0]],["_veh",objNull,[objNull]],["_player",objNull,[objNull]],["_uid","",[""]]];
// owner 2026-06-23 SECURITY (security.md §2.2 HIGH + §2.3): CfgRE-whitelisted -> a client could remoteExec
// [rivalGangID, anyVeh, player, uid] to store another player's LIVE vehicle into a gang garage it doesn't
// belong to. Derive the actor from the non-spoofable remoteExecutedOwner (model fn_seizeLock:22) and verify
// they're a MEMBER of _gangID (server-side gang_data, mirror of fn_removeGang/fn_cartelSRV). Also derive the
// stored-owner uid + escape ids for SQL rather than trusting the client _uid string.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0) then { _player = _caller; _uid = getPlayerUID _caller; };   // actor IS the caller; stored-owner uid = real caller (no raw client UID into SQL)
// membership gate -- FLAT top-level exitWith (the jailSys/seizeLock idiom; an exitWith nested in `then{}` only
// leaves the block and falls through). server-internal (_src==0) is always trusted.
if (_src isNotEqualTo 0 && {isNull _caller || {(format ["%1", (_caller getVariable ["gang_data", [-1]]) param [0, -1]]) isNotEqualTo (format ["%1", _gangID])} || {_gangID < 0}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED gangGarageStore (not a member of gang %1) by %2", _gangID, getPlayerUID _caller]] call APS_fnc_logIt;
    if (!isNull _caller) then { AP_garage_store = false; (owner _caller) publicVariableClient "AP_garage_store"; AP_impound_inuse = false; (owner _caller) publicVariableClient "AP_impound_inuse"; };
};
private _gangIDsql = (format ["%1", _gangID]) splitString "'" joinString "";   // SQL-escape (security.md §2.3)
private _uidSql    = (format ["%1", _uid])    splitString "'" joinString "";
// owner 2026-06-17 (#323 store-lockup): the client sets AP_garage_store=true before calling this, to gate the
// "Store Vehicle in Garage" action during the store round-trip. fn_vehicleStore (personal path) clears it back
// on every exit -- but this GANG path never did, so after any gang-garage store AP_garage_store stayed true
// and the store action vanished server-wide for that player ("can't store any car"; a relog reset it via
// configuration.sqf, hence "until restart"). Release it (+ AP_impound_inuse) on the player's client on EVERY
// exit path below.
private _fnc_release = {if (!isNull _player) then {AP_garage_store = false;  (owner _player) publicVariableClient "AP_garage_store";
        AP_impound_inuse = false; (owner _player) publicVariableClient "AP_impound_inuse";};};
if (_gangID < 0 || isNull _veh) exitWith { call _fnc_release; };
private _db = _veh getVariable ["AP_dbInfo", ["", 0]];
private _plate = _db param [1, 0];
if (_plate isEqualTo 0) exitWith { call _fnc_release; };
// owner 2026-06-18 (CLANKR dupe): ANTI-DUPE trunk settle -- twin of fn_vehicleStore. AP_vinv is mutated client-
// side via an async public setVariable; a store fired mid-take would persist the PRE-take trunk into the
// gang_vehicles row -> re-pull dupes it. Raise AP_trunkLock (fn_openInventory monitor force-closes/blocks the
// dialog) then settle out the propagation window before snapshotting AP_vinv below. Vehicle is deleteVehicle'd
// at the end of the one path that reaches the read, so the lock dies with the object (no stuck-lock).
_veh setVariable ["AP_trunkLock", true, true];
uiSleep 1.25;
if (isNull _veh) exitWith { call _fnc_release; };
private _class = typeOf _veh;
private _type = "Car";
if (_veh isKindOf "Air") then { _type = "Air"; } else { if (_veh isKindOf "Ship") then { _type = "Ship"; }; };
private _color = (_veh getVariable ["dbInfo", [0,0,0]]) param [2, 0];  // AP_vehColor doesn't exist; color rides in dbInfo[2] (set by vehicleCreate)
// owner 2026-06-17 (#334): serialize the REAL trunk. The old `Trunk` var was never set (the live trunk is
// AP_vinv), so gang vehicles silently lost ALL cargo on store. Mirror the personal garage EXACTLY: strip
// illegal items server-side (#332 set = getIllegalItems), recompute weight from the kept legal items, and
// store [[kept,weight],cargo] in the SAME str-format fn_updateVehicle uses so APS_fnc_gangGarageSetActive
// restores it identically. (Twin of the fn_updateVehicle active=0 block -- keep them in sync.)
private _vinv  = _veh getVariable ["AP_vinv", [[], 0]];
private _items = _vinv param [0, []];
private _haveCfg = !isNil "AP_fnc_virtItemCfg";
private _illegalSet = [];
if (_haveCfg) then {private _ill = ["getIllegalItems"] call AP_fnc_virtItemCfg;
    if (_ill isEqualType []) then { _illegalSet = _ill apply { _x param [0, ""] }; };};
private _kept = [];
if (_haveCfg) then {_kept = _items select { _x isEqualType [] && {count _x >= 2} && {!((_x param [0, ""]) in _illegalSet)} };};
private _wt = 0;
if (_haveCfg) then {
    { private _iw = ["getItemWeight", (_x select 0)] call AP_fnc_virtItemCfg; if (_iw isEqualType 0) then { _wt = _wt + (_iw * (_x select 1)); }; } forEach _kept;
};
private _cargo = [getItemCargo _veh, getWeaponCargo _veh, getMagazineCargo _veh, getBackpackCargo _veh];
private _inv = str [[_kept, _wt], _cargo];
_inv = (_inv splitString "'") joinString "";   // SQL-safe: strip single-quotes
private _fuel = round ((fuel _veh) * 100);
private _dmg  = round ((damage _veh) * 100);

private _plateSql = (format ["%1", _plate]) splitString "'" joinString "";   // SQL-escape the plate (security.md §2.3)
// owner 2026-07-24 SECURITY (audit): the 2026-06-23 hardening proved the caller is a MEMBER of _gangID, but
// nothing ever checked the VEHICLE belonged to them -- so a member could drive up to anyone's parked car and
// store it into the gang garage, and the pid-less DELETE below would strip the real owner's row. Ownership
// cannot be taken from AP_dbInfo: both pull paths set it CLIENT-side with public=true
// (fn_vehicleGaragePull:241, fn_gangGaragePull:215), so it is forgeable. Ask the DB instead.
// Deliberately a NEGATIVE test -- block only when the plate provably belongs to ANOTHER player or ANOTHER
// gang. (An unknown plate used to still store; since 2026-09-26 the positive test below refuses it.)
// Must run BEFORE the DELETE below.
if (_src isNotEqualTo 0) then {
    private _otherOwner = [format ["SELECT pid FROM vehicles WHERE plate='%1' AND pid<>'%2'", _plateSql, _uidSql], 2] call DB_fnc_asyncQuery;
    private _otherGang  = [format ["SELECT gang_id FROM gang_vehicles WHERE plate='%1' AND gang_id<>'%2'", _plateSql, _gangIDsql], 2] call DB_fnc_asyncQuery;
    if (!(_otherOwner isEqualTo []) || {!(_otherGang isEqualTo [])}) exitWith {
        ["-SEC-", _caller, format ["BLOCKED gangGarageStore of plate %1 into gang %2 -- vehicle belongs to another player/gang", _plate, _gangID]] call APS_fnc_logIt;
        call _fnc_release;
        _plate = 0;   // signal; the top-level guard below exits the function
    };
    // Audit 2026-09-26 (mints2): the negative test above let an UNKNOWN plate store, and a store writes a gang_vehicles
    // row as typeOf -- so a client-spawned Nyx stamped [gangId, fresh plate] became a real gang vehicle that chops back
    // for New Drachma, without limit. A client store now needs the vehicle's row already on file, as THIS class: the
    // gang's own (a pulled gang vehicle keeps its row, #335) or the caller's personal one. The client callers only
    // store pulled gang vehicles: fn_storeVehicle (garage NPC), and fn_impoundAction's gang impound, which the
    // membership gate above already refuses (a cop is not in the gang). Wild / admin-spawned vehicles no longer store.
    private _onFile = ["SELECT 1 FROM gang_vehicles WHERE gang_id = %s::integer AND plate = %s::integer AND lower(classname) = lower(%s) UNION ALL SELECT 1 FROM vehicles WHERE pid = %s AND plate = %s::integer AND lower(classname) = lower(%s)",
        2, false, [_gangID, _plate, _class, _uid, _plate, _class]] call DB_fnc_asyncQuery;
    if (!(_onFile isEqualType []) || {_onFile isEqualTo []}) then {
        ["-SEC-", _caller, format ["BLOCKED gangGarageStore of %1 plate %2 into gang %3 -- no %1 row on file for that gang/caller", _class, _plate, _gangID]] call APS_fnc_logIt;
        _plate = 0;
    };};
if (_plate isEqualTo 0) exitWith { call _fnc_release; };
[format ["DELETE FROM vehicles WHERE plate='%1'", _plateSql]] call DB_fnc_asyncQuery;
// owner 2026-06-18 (#335): UPSERT, not blind INSERT. Storing a vehicle that was PULLED leaves an active='1' row
// for this (gang_id, plate); the old INSERT added a SECOND row instead of folding into it -> zombie duplicates
// piled up (one plate had 4 rows) + fed the restart "poof". With the uq_gang_plate UNIQUE key (added at boot),
// ON DUPLICATE KEY UPDATE folds the store back into the SAME row (active->0 + fresh trunk/fuel/damage). A brand
// new gang vehicle (personal->gang, no existing row) still INSERTs normally.
[format ["INSERT INTO gang_vehicles (pid,classname,type,gang_id,inventory,active,plate,color,fuel,damage) VALUES ('%1','%2','%3','%4','%5','0','%6','%7','%8','%9') ON CONFLICT (gang_id, plate) DO UPDATE SET pid='%1', classname='%2', type='%3', inventory='%5', active = false, color='%7', fuel='%8', damage='%9'",
    _uidSql, _class, _type, _gangIDsql, _inv, _plateSql, _color, _fuel, _dmg]] call DB_fnc_asyncQuery;
// owner 2026-06-19 (WHOLE-VEHICLE DUPE): release the active-pull lock claimed in APS_fnc_gangGarageSetActive -- the
// plate is back in the gang garage (active=0), so a future pull must be allowed again.
if (!isNil "AP_activeVehKeys") then { AP_activeVehKeys = AP_activeVehKeys - [format ["%1:%2", _gangID, _plate]]; };
deleteVehicle _veh;
call _fnc_release;
