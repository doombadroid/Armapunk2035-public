 
private["_query","_sql"]; 
 
if ("AP_server_training" call DB_fnc_flag) exitWith {}; 
 
 {if (!isNil "_x") then {_contents = 0;
if (!isNil "AP_capture_containers select _forEachIndex") then {
_contents = ((AP_capture_containers select _forEachIndex) getVariable "gangContainer") select 1;};
// owner 2026-06-13: REPLACE not UPDATE -- the captures table started EMPTY (no id 1-4 rows), so the old
// UPDATE matched nothing and cartel ownership NEVER persisted (reset to neutral every reboot). REPLACE
// self-seeds the row by its primary key, so capture state now saves + reloads across restarts.
// AP_capture_changed and the container's gangContainer var are client-writable (publicVariable / public setVariable): strip ' from the text fields
private _q = { (format ["%1", _this]) splitString "'" joinString "" };
_query = format["INSERT INTO captures (id,gang,percent,container,level) VALUES ('%3','%1','%2','%4','%5') ON CONFLICT (id) DO UPDATE SET gang = EXCLUDED.gang, percent = EXCLUDED.percent, container = EXCLUDED.container, level = EXCLUDED.level", (_x select 1) call _q, ((_x select 2) * 100), _forEachIndex + 1, _contents call _q, (_x select 6) call _q];
[_query] call DB_fnc_asyncQuery;};} foreach AP_capture_changed;
 
AP_capture_changed = [];