if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
private["_query","_sql","_uid","_plate","_vehicle","_active","_ammo"]; 
_plate = [_this,0,-1,[0]] call BIS_fnc_param; 
_uid = [_this,1,"",[""]] call BIS_fnc_param; 
_vehicle = [_this,2,objNull,[objNull]] call BIS_fnc_param; 
_active = [_this,3,1,[1]] call BIS_fnc_param; 
_alarm = [_this,4,0,[0]] call BIS_fnc_param; 
_ammo = [_this,5,0,[0]] call BIS_fnc_param;
// owner 2026-06-22 (#484/#488/#494 vehicle cluster): optional BLOCKING commit. The STORE/impound path passes
// true so active='0' + the trunk are COMMITTED before fn_vehicleStore replies "stored in your garage" -> the
// player reopening the garage reliably sees it. The old async write could lag past the reopen = "I stored it but
// it's gone" (no data lost -- it committed a beat later + the boot reset recovers any stuck row -- just confusing).
// Restore / idle-cleanup stay async (default false) so boot restore of many vehicles isn't serialized/slowed.
private _blocking = [_this,6,false,[false]] call BIS_fnc_param;
// LooneyBin owner 2026-07-04 (QoL): keepIllegal -- the idle-reaper (fn_cleanup) is the ONLY caller that
// passes true, so an AUTO-REAPED car keeps its trunk contraband (drugs) in the garage. The player didn't
// choose to store, so don't void their illegal Y-inv as a side effect of the cleanup. Every other store /
// impound path leaves it false -> illegal items stripped as normal (#332). Never trust a client to set it.
private _keepIllegal = [_this,7,false,[false]] call BIS_fnc_param;

if(_plate == -1 OR _uid == "" OR isNull _vehicle) exitWith {[]};
// SECURITY (audit 2026-09-26): _uid comes from the vehicle's PUBLIC dbInfo/AP_dbInfo (client-rewritable) on the store,
// impound, reaper and restore paths, and is formatted into the UPDATE below -- a forged pid of x' OR '1'='1 rewrote
// every vehicle's active flag + trunk. A real pid is a Steam64 UID: digits only. Refuse anything else.
if ((toArray _uid) findIf {_x < 48 || _x > 57} isNotEqualTo -1) exitWith {diag_log format ["[DBGUARD] updateVehicle REFUSED non-numeric pid %1 (plate %2)", _uid select [0, 40], _plate]; []};
 
 
// LooneyBin (persistent trunk): on STORE (active=0) serialize the trunk into the `inventory` column --
// virtual AP_vinv (ILLEGAL items dropped) + physical cargo ("kits"). Read server-side from the real
// object (authoritative -- never trust client). The pull path (APS_fnc_vehicleSetActive) loads this then
// CLEARS the column, so the trunk exists in exactly ONE place at a time (DB when stored, live vehicle when
// out) -> no dupe. Only written when active=0 so a live/out vehicle is never re-saved (which would re-arm
// the re-pull dupe). Old rows store '[]' -> loaded as empty (backward compatible).
private _invSet = "";
if (_active == 0) then {
    // owner 2026-06-19 (WHOLE-VEHICLE DUPE): release the in-memory active-pull lock claimed in
    // APS_fnc_vehicleSetActive -- the plate is back in the garage, so a future pull must be allowed. (active=0 is
    // the single chokepoint for store / impound / idle cleanup, so every "put away" path releases the claim.)
    if (!isNil "AP_activeVehKeys") then { AP_activeVehKeys = AP_activeVehKeys - [format ["%1:%2", _uid, _plate]]; };
    private _vinv   = _vehicle getVariable ["AP_vinv", [[], 0]];
    private _items  = _vinv param [0, []];
    // owner 2026-06-17 (#332): STRIP illegal items (drugs/contraband) from the trunk whenever a vehicle is
    // put away (garage store / cop impound / idle cleanup -- every active=0 serialize). Re-adds the filter
    // removed 2026-06-14: garaging no longer keeps contraband, so you can't stash drugs cop-proof in a garaged
    // vehicle or teleport them across the map between garages. SERVER-AUTHORITATIVE -- read from the live
    // object + filtered here, so a hacked client can't keep illegal cargo. (World persistence is a SEPARATE
    // path: fn_saveVehicles -> vehicle_mem, so contraband still survives in an OUT vehicle across a restart,
    // as intended.) AP_fnc_virtItemCfg is available server-side at store time (the pull path's #200 weight
    // self-heal already calls it). If it's somehow nil, fail SAFE: drop ALL virtual items, never keep contraband.
    private _haveCfg = !isNil "AP_fnc_virtItemCfg";
    private _illegalSet = [];
    if (_haveCfg) then {private _ill = ["getIllegalItems"] call AP_fnc_virtItemCfg;   // [[class, illegalPrice], ...]
        if (_ill isEqualType []) then { _illegalSet = _ill apply { _x param [0, ""] }; };};
    private _kept = [];
    if (_keepIllegal) then {
        // reaper QoL path: keep EVERYTHING (contraband included), valid entries only
        _kept = _items select { _x isEqualType [] && {count _x >= 2} };} else {if (_haveCfg) then {
            _kept = _items select { _x isEqualType [] && {count _x >= 2} && {!((_x param [0, ""]) in _illegalSet)} };} else {
            diag_log "[LooneyBin][trunk] virtItemCfg nil at store -> stripping ALL virtual items (fail-safe; never keep contraband)";};};
    // recompute trunk weight from the KEPT (legal) items only -- the 6/14 filter's bug (#200) was dropping
    // items but keeping the STALE weight, so a pulled vehicle read over-capacity. (Pull self-heals weight too.)
    private _weight = 0;
    if (_haveCfg) then {{private _iw = ["getItemWeight", (_x select 0)] call AP_fnc_virtItemCfg;
            if (_iw isEqualType 0) then { _weight = _weight + (_iw * (_x select 1)); };} forEach _kept;};
    private _cargo  = [getItemCargo _vehicle, getWeaponCargo _vehicle, getMagazineCargo _vehicle, getBackpackCargo _vehicle];
    private _invData = str [[_kept, _weight], _cargo];
    _invData = (_invData splitString "'") joinString "";   // defensive: strip stray single-quotes (SQL safety)
    _invSet = format [", inventory='%1'", _invData];};
_query = format["UPDATE %7 SET active='%5', fuel='%3', damage='%4', alarm='%6', ammo='%8'%9 WHERE pid='%1' AND plate='%2'",_uid,_plate,((fuel _vehicle) * 100),((damage _vehicle) * 100),_active,_alarm,"vehicles",_ammo * 100,_invSet];
if (_blocking) then { [_query, 2] call DB_fnc_asyncQuery; } else { [_query] call DB_fnc_asyncQuery; };