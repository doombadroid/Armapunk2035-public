 
private["_query","_sql"]; 
 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
 {if (!isNil "_x") then {
// owner 2026-06-13: REPLACE not UPDATE -- the turf table started EMPTY, so UPDATE matched nothing and turf
// ownership NEVER persisted (reset every reboot, same bug as captures). REPLACE self-seeds the row by id.
_query = format["INSERT INTO turf (id,gang) VALUES ('%2','%1') ON CONFLICT (id) DO UPDATE SET gang = EXCLUDED.gang", (format ["%1", _x select 1]) splitString "'" joinString "", _forEachIndex + 1];   // AP_turf_list is publicVariable'd by clients (fn_captureTurf) -> strip '
[_query] call DB_fnc_asyncQuery;};} foreach AP_turf_list;