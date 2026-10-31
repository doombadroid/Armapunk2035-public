 
private["_session", "_building", "_array", "_owners", "_worldspace", "_numDoors","_uniqueId"]; 
_session = _this select 0; 
 
if(isNil "_session") exitWith {}; 
 
 {_worldspace = parseSimpleArray (format ["%1", _x select 2]);
AP_house_owners pushBack [(_x select 0), (_x select 1), _worldspace];

// LooneyBin: restore the map house object's state (global) so it's recognized as owned after a server
// restart -- ownership, lock, storage caps, upgrade flags, keyholders, stored inventory. Text cols
// (keyholders/vinv/pinv) are mres-encoded; decode like queryRequest's _dec. NULL inv -> empty [[],0].
// owner 2026-07-09: was ["House_F"], which NEVER matches Land_i_Shed_Ind_F (industrial shed is not
// isKindOf House_F, per the gang-tagger #208 + init.sqf shed notes). So EVERY shed row failed to tag at
// early boot -> the intact shed carried no AP_homeOwner/caps/inventory until the +30s init.sqf re-tag,
// and a legit owner opening in that window logged -HOUSEINV- with Owner:NoPidVar -> CLANKR false-ban.
// Mirror fn_CLinitHouses (proven client-side): broad ["House"] sweep filtered to the real house-type list
// so a buyable shed resolves to the INTACT Land_i_Shed_Ind_F, not the coincident derelict.
private _htypes = ["getHouses"] call AP_fnc_houseConfig;
private _cands = nearestObjects [_worldspace, ["House"], 15, true];
private _bldg = (_cands select { (typeOf _x) in _htypes }) param [0, (_cands param [0, objNull])];
if (!isNull _bldg) then {private _dec = {params [["_v", "", [""]]];
        if (isNil "_v" || {_v isEqualTo ""} || {_v isEqualTo "NULL"}) exitWith {[]};
        private _a = [_v] call DB_fnc_mresToArray;
        if (typeName _a == "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
        if (isNil "_a") then { _a = []; };
        _a};
    private _vinvR = [_x select 12] call _dec; if (_vinvR isEqualTo []) then { _vinvR = [[], 0]; };
    private _pinvR = [_x select 13] call _dec; if (_pinvR isEqualTo []) then { _pinvR = [[], 0]; };
    _bldg setVariable ["AP_homeOwner", (_x select 1), true];
    _bldg setVariable ["AP_houseID", (_x select 0), true];
    _bldg setVariable ["AP_buildID", (_x select 0), true];
    _bldg setVariable ["houseId", (_x select 0), true];
    _bldg setVariable ["AP_buildingLocked", ((_x select 3) isEqualTo 1), true];
    _bldg setVariable ["AP_vcap", (_x select 5), true];
    _bldg setVariable ["AP_phys_cap", (_x select 6), true];
    _bldg setVariable ["AP_keycap", (_x select 7), true];
    _bldg setVariable ["AP_barrel_unaged", ((_x select 8) isEqualTo 1), true];
    _bldg setVariable ["AP_greenhouse_unaged", ((_x select 9) isEqualTo 1), true];
    _bldg setVariable ["AP_leadcontainer_unaged", ((_x select 10) isEqualTo 1), true];
    _bldg setVariable ["AP_house_keys", ([_x select 11] call _dec), true];
    // owner 2026-07-10: player-set house name (houses.custom_name, col 14). GLOBAL so the map marker
    // (fn_CLinitHouses) + spawn list (fn_spawnPointCfg) show it for everyone; "" / NULL = the type name.
    private _cn = _x param [14, ""]; if (isNil "_cn" || {_cn isEqualTo "NULL"}) then { _cn = ""; };
    _bldg setVariable ["AP_houseName", _cn, true];
    // owner 2026-06-23 SECURITY (option B, "free house keys"): house storage is SERVER-LOCAL at rest (NO `true`)
    // so clients can't read another player's stash off the object. It's broadcast to a client ONLY during a gated
    // open (APS_fnc_initHouseInventory hydrate) and re-emptied on close (APS_fnc_updateHouseTrunk dehydrate). The
    // server keeps this cache for the disconnect-path save; the DB row stays authoritative.
    _bldg setVariable ["AP_vinv", _vinvR];
    _bldg setVariable ["AP_pinv", _pinvR];
    // owner 2026-06-19 (#blotter): ACTUALLY lock the doors on boot. This restored the AP_buildingLocked VARIABLE but
    // never disabled the native engine door action (bis_disabled_Door_N) the way fn_lockHouse does -> after
    // EVERY restart owned-house doors had the "Open Door" action ENABLED, so anyone walked in ("owned house
    // doors unlocked after restart / randomly"). AP_buildingLocked alone only gates the custom storage-open, not the
    // physical door. Mirror fn_lockHouse: disable + close each door (global) when the DB row says locked=1.
    if ((_x select 3) isEqualTo 1) then {private _nd = getNumber (configFile >> "CfgVehicles" >> typeOf _bldg >> "numberOfDoors");
        for "_i" from 1 to _nd do {
            if !((typeOf _bldg in ["Land_i_Shop_01_V1_F","Land_i_Shop_01_V2_F","Land_i_Shop_01_V3_F"]) && {_i == 1 || _i == 3}) then {
                _bldg setVariable [format ["bis_disabled_Door_%1", _i], 1, true];
                // owner 2026-06-19: dropped the `animateGlobal` visual-close call -- it failed to compile here
                // ("Missing ;") and isn't needed: bis_disabled_Door (above, global) IS the lock, and houses
                // load with doors at config-default (closed) on a fresh restart, so they come up closed + locked.
            };};};};

// LooneyBin: guard the rebuild-mode check. AP_configuration is junk on the server (raw `select 10`
// threw "Zero divisor" and aborted the forEach -> only the first house restored). Only enter rebuild
// mode if it is a real array with index 10 explicitly set to 1.
if (((localNamespace getVariable ["APS_configuration", []]) param [10, 0]) isEqualTo 1) then   // server-only copy (fn_queryConfig), not the client-overwritable AP_configuration
{ 
 
diag_log "HOUSE RESYNC INITIALIZED (REBUILD MODE)"; 
_worldspace = [(_x select 2)] call DB_fnc_mresToArray; 
_worldspace = parseSimpleArray (format["%1", _worldspace]); 
_building = _worldspace nearestObject "House_F"; 
_oldId = (_x select 0); 
_uniqueId = (_x select 4); 
_newId = [_building] call AP_fnc_getBuildID; 
 
if (_oldId != _newId) then {diag_log format["HOUSE: oldId = %1, newId = %2", _oldId, _newId];
_query = format["UPDATE houses SET oid='%1' WHERE oid='%2'", _newId, _oldId, AP_server_instance]; 
diag_log _query; 
[_query] call DB_fnc_asyncQuery; 
_query = format["UPDATE gangs SET id='%1' WHERE id='%2'", _newId, _oldId, AP_server_instance]; 
diag_log _query; 
[_query] call DB_fnc_asyncQuery; 
_query = format["UPDATE %4 SET gang%3='%1' WHERE gang%3='%2'", _newId, _oldId, (localNamespace getVariable "APS_serverInstance"), "players"]; 
diag_log _query; 
[_query] call DB_fnc_asyncQuery; 
_query = format["UPDATE captures SET gang='%1' WHERE gang='%2'", _newId, _oldId, AP_server_instance]; 
[_query] call DB_fnc_asyncQuery; 
_query = format["UPDATE turf SET gang='%1' WHERE gang='%2'", _newId, _oldId, AP_server_instance]; 
[_query] call DB_fnc_asyncQuery;};};} foreach (_session);