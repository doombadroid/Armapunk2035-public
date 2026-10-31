 
private["_ret","_page","_building","_contents","_houseWorldspace","_houseId","_worldspace","_virtual"]; 
 
_query = "DROP INDEX IF EXISTS oid_unique";   // PG spells index maintenance without the table
[_query] call DB_fnc_asyncQuery; 
 
_page = 0; 
while {true} do {_ret = [_page] call DB_fnc_queryHouses;
_page = _page + 1; 
 
if(!isNil "_ret") then {[_ret] call APS_fnc_receiveHouses;}
else {[nil] call APS_fnc_receiveHouses;};
 
if ((count _ret) < 30) exitWith {};};
 
_query = "DELETE FROM houses n1 USING houses n2 WHERE n1.id > n2.id AND n1.oid = n2.oid";   // multi-table DELETE, the PG way (n1.id > n2.id already implies n1.id <> n2.id)
[_query,2] call DB_fnc_asyncQuery; 
_query = "CREATE UNIQUE INDEX IF NOT EXISTS oid_unique ON houses (oid)";
[_query] call DB_fnc_asyncQuery;

// LooneyBin: signal clients that houses are initialized. SRV_HousesSetup was READ by fn_houseMenu /
// fn_manageHouseTax / fn_commitArsonClient but never SET anywhere (setter lost in the 2017->2020
// merge) -> undefined on clients -> "Undefined variable: srv_housessetup" + house menu errors.
SRV_HousesSetup = true;
publicVariable "SRV_HousesSetup";
diag_log "LB_HOUSES_SETUP_DONE";
 
if (((localNamespace getVariable ["APS_configuration", []]) param [10, 0]) isEqualTo 1) then   // server-only copy (fn_queryConfig), not the client-overwritable AP_configuration. LooneyBin: AP_configuration is [] until the async config load fills it; `select 10` on a short/empty array -> nil -> the `== 1` threw "Zero divisor" at boot every restart. param defaults to 0 (skip the one-time storage migration) when config isn't loaded.
{ 
 
_page = 0; 
while {true} do {
_query = format["SELECT id, houseid, houseworldspace FROM storage ORDER BY id LIMIT 30 OFFSET %1", (_page * 30),AP_server_instance]; 
_ret = [_query,2,true] call DB_fnc_asyncQuery; 
if(!isNil "_ret") then {{_worldspace = [(_x select 2)] call DB_fnc_mresToArray;
_worldspace = parseSimpleArray (format["%1", _worldspace]); 
_building = _worldspace nearestObject "House_F"; 
_uniqueId = (_x select 0); 
_newId = [_building] call AP_fnc_getBuildID; 
_query = format["UPDATE storage SET houseid='%2' WHERE id=%3", AP_server_instance, _newId, _uniqueId]; 
[_query] call DB_fnc_asyncQuery;} forEach _ret;};
if ((count _ret) < 30) exitWith {}; 
_page = _page + 1;};
 
_query = format["UPDATE config SET value=0 WHERE index=10", AP_server_instance]; 
[_query] call DB_fnc_asyncQuery; 
sleep 2; 
[["end1"],"BIS_fnc_endMission", true, false] spawn AP_fnc_MP;};