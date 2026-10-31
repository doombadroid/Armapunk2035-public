 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_trunk","_query","_sql","_worldspace"]; 
 
// owner 2026-06-19 (persistence cluster): _vehiclesOnly=true -> save ONLY vehicle_mem (the periodic loop in
// server init uses it), skipping the heavy player/storage/gang flush below. Default false = full graceful save.
params [["_vehiclesOnly", false, [false]]];
_query = "DELETE FROM vehicle_mem"; 
[_query] call DB_fnc_asyncQuery; {_vInfo = _x getVariable["dbInfo",[]];
// owner 2026-06-20 (GHOST twin -- see fn_cleanup / #406): garage-pulled vehicles (fn_vehicleGaragePull /
// fn_gangGaragePull) set only AP_dbInfo, not dbInfo. With empty dbInfo this loop SKIPPED them -> the spawned
// vehicle was never written to vehicle_mem -> LOST/ghosted on the next reboot (not restored, but the vehicles row
// stays active=1). Reconstruct a restore-VALID 4-field dbInfo from AP_dbInfo [uid,plate]: index 2 = "objNull"
// string (fn_restoreVehicles:85 reads select 2 -> normalizes a string to objNull, so a 2-field array would throw);
// alarm defaults off (re-arms on use). Mods/color are re-applied from the vehicles row by plate on restore.
if (count _vInfo == 0) then {private _pdb = _x getVariable["AP_dbInfo",[]];
    if (count _pdb >= 2) then { _vInfo = [_pdb select 0, _pdb select 1, "objNull", false]; };};
if (count _vInfo > 0) then {
// owner 2026-06-13: type-guard before isNull. dbInfo[2] is sometimes a NUMBER, and `isNull <Number>` THREW
// ("Type Number, expected Object...") which aborted the whole forEach -- AFTER the `DELETE FROM vehicle_mem`
// above ran -> the save bailed with an EMPTY table (every spawned vehicle lost on the next restore). This was
// dormant because the old pkill restart never called saveVehicles; the new soft-restart path does.
if (!((_vInfo select 2) isEqualType objNull) || {isNull (_vInfo select 2)}) then {_vInfo set[2,"objNull"]};
// owner 2026-06-13: read AP_vinv (LooneyBin's live trunk var), NOT the legacy "Trunk" -- saveVehicles
// was snapshotting an always-empty "Trunk" so vehicle Y-inventory NEVER survived a restart. Pairs with the
// matching AP_vinv restore in fn_restoreVehicles.
_inventory = _x getVariable ["AP_vinv",[[],0]];
_inventory = [_inventory] call DB_fnc_mresArray;
_worldspace = getPos _x; 
_worldspace = [_worldspace] call DB_fnc_mresArray; 
_dir = direction _x; 
_plate = (format ["%1", _vInfo select 1]) splitString "'" joinString "";   // dbInfo/AP_dbInfo are PUBLIC vehicle vars a client can set -> strip quotes before the plate lands in '%1' below
_vInfo = [_vInfo] call DB_fnc_mresArray; 
// owner 2026-06-13: save AP_vehOwners (the KEYS -- who can access the vehicle), NOT the dead legacy
// "vehicle_info_owners" var (never set anywhere -> always empty -> restored vehicles came back with NO
// keys = "NoVehData", owner locked out). AP_vehOwners = [[uid,name],...]. Restored into AP_vehOwners.
_owners = _x getVariable["AP_vehOwners",[]];
_owners = [_owners] call DB_fnc_mresArray;
_insured = [_x getVariable ["insured",false],0] call DB_fnc_bool; 
_query = format["INSERT INTO vehicle_mem (plate,worldspace,dir,inventory,info_owners,dbInfo,fuel,damage,class,insured) VALUES ('%1','%2','%3','%4','%5','%6','%7','%8','%9','%10')", _plate, _worldspace, _dir, _inventory, _owners, _vInfo, round((fuel _x) * 100), round((damage _x) * 100), typeOf _x, _insured]; 
[_query] call DB_fnc_asyncQuery; 
diag_log format["Inserted %1.", _x];};} foreach vehicles;

// owner 2026-06-19: the periodic loop saves vehicles ONLY -- the full player/storage/gang flush below is
// heavy and only needed on an actual restart. Bail here for the lightweight 8-min snapshot.
if (_vehiclesOnly) exitWith { diag_log "[LooneyBin][veh-save] periodic vehicle-only snapshot queued"; }; 
 
[] call DB_fnc_updateCaptures; 
 
 {_changed = _x getVariable["lootModified", false];
if (_changed) then {[_x] call DB_fnc_updateStorage;};} forEach AP_storage_array;
 
diag_log format["Doing vendor stock!"]; {
// Economy 2026-06-16 (neglect-premium): persist each good's [class, prem, sales]. REPLACE self-seeds the row
// by its className PK (the table starts empty), so the old UPDATE-matches-nothing bug can't drop state. quantity
// = premium (>=1 float), sales = cumulative sale count toward the next crash.
// 2026-09-26: reads the SERVER-ONLY index (localNamespace; AP_price_index is a display copy any client can
// publicVariable over), writes only goods in the server's own goods list, and binds values as parameters.
if (_x isEqualType [] && {count _x >= 2} && {(_x select 0) in (localNamespace getVariable ["APS_marketGoods", []])}) then {
    private _prem  = _x param [1, 1]; if (!(_prem isEqualType 0)  || {_prem < 1}) then { _prem = 1 };
    private _sales = _x param [2, 0]; if (!(_sales isEqualType 0) || {_sales < 0}) then { _sales = 0 };
    _query = "INSERT INTO itemstock (className,quantity,sales) VALUES (%s,%s,%s) ON CONFLICT (classname) DO UPDATE SET quantity = EXCLUDED.quantity, sales = EXCLUDED.sales";
    [_query, 1, false, [_x select 0, _prem, _sales]] call DB_fnc_asyncQuery;};} forEach (localNamespace getVariable ["APS_priceIndex", []]);
 
// (AP_server_gangs_queue flush removed: nothing server-side ever queues into it, so its only contents were client publicVariable -> raw SQL.)
 
saveProfileNamespace; 
 
systemChat "Save complete, ready to die!"; 
diag_log "Save complete, ready to die!";