// Armapunk 2035: the Altis turf rotation is retired on this map -- AP_turf_list is empty and
// rodo/zaros/panagia_flag are objNull, so there is nothing to restore and the indexing below would
// walk off an empty array. See custom_p3ds/malden_cartels.sqf.
if (!(missionNamespace getVariable ["AP_turfSystem", true])) exitWith {};
 
private ["_query","_result","_ret","_rPos","_i","_pos","_conCount"]; 
 
_rPos = switch (worldName) do {
case "Altis": { [[[11208,8714,0],[8911,7477,0],[9229,8047,0],[12286,8895,0]],[[4853.02,21866.8,8.96136],[14246,13008,0],[22000,21068,0]],[[9622,15105,0],[23722, 16238, 0]],[[8133,22548,0],[11379,14186,0]]] }; 
case "Tanoa": { [[[4076,12562,0],[3141.6,11233,1],[2294,13208,0]],[[12433,14246,0]],[[2653,9313,0]],[[7195,12696,0],[7316,12822,0]]] }; 
case "Australia": { [[[33575,4600,0]],[[31900,15232,0]],[[35525,12957,0]],[[9624,23261,0],[23428,32778,0]]] }; 
case "Stratis": { [[[2629,596,0],[2717,958,0]],[[3287,2927,0],[3389,3002,0]],[],[]] };};
AP_capturePos = []; 
 
for "_i" from 1 to 4 do {_container = objNull;
if (count (_rPos select (_i - 1)) > 1) then {_capIndex = floor random (count (_rPos select (_i - 1)));
_pos = (_rPos select (_i - 1)) select _capIndex; 
private _capObj = missionNamespace getVariable [format["capture_%1",_i], objNull];
if (!isNull _capObj) then { _capObj setPos _pos; };
private _capFlag = missionNamespace getVariable [format["capture_flag_%1",_i], objNull];
if (!isNull _capFlag) then { _capFlag setPosATL _pos; };
private _capPole = missionNamespace getVariable [format["capture_pole_%1",_i], objNull];
if (!isNull _capPole) then { _capPole setPosATL _pos; };
(format["capture_label_%1",_i]) setMarkerPos _pos; 
(format["capture_area_%1",_i]) setMarkerPos _pos; 
AP_capturePos set [_i - 1, [_pos,_capIndex]];}
else {AP_capturePos set [_i - 1, []];};
 
if ((AP_capture_list select (_i-1)) select 5 != "") then {
_container = missionNamespace getVariable [format["capture_container_%1",_i], objNull];
if (!isNull _container && count (_rPos select (_i - 1)) > 1) then { _container setPosATL _pos; };};
AP_capture_containers set [_i-1, _container];};
 
_query = "SELECT id,gang,percent,container,level FROM captures ORDER BY id"; 
_ret = [_query,2,true] call DB_fnc_asyncQuery; 
 {_grown = false;
_id = parseNumber(_x select 0); 
_conCount = parseNumber(_x select 3); 
_gang = (_x select 1); 
_lvl = parseNumber(_x select 4); 
_percent = parseNumber(_x select 2) / 100; 
if (_lvl < 2 && _percent == 1) then { _lvl = _lvl + 1; _grown = true; }; 
_row = AP_capture_list select (_id - 1); 
_row set [1, _gang]; 
_row set [2, _percent]; 
_row set [6, _lvl]; 
AP_capture_list set [(_id - 1), _row]; 
if (_grown) then { AP_capture_changed set [(_id - 1), _row]; }; 
if (!isNull (AP_capture_containers select _forEachIndex)) then {
(AP_capture_containers select _forEachIndex) setVariable ["gangContainer", [_row select 5,_conCount], true];}} foreach _ret;
publicVariable "AP_capture_list"; {_lvl = (AP_capture_list select _forEachIndex) select 6;
if (_lvl > 0 && worldName == "Altis" && count _x > 0) then {[_forEachIndex, _x select 1, _lvl, true] spawn APS_fnc_spawnCaptures;};
} forEach AP_capturePos; 
publicVariable "AP_capturePos"; 
 
// QUOTE both varchar reads: DB_fnc_asyncQuery mode 2 `call compile`s the result, so the gang NAME (or the
// "Contested" default, or any name with spaces/apostrophes) came back as a BAREWORD -> undefined-variable compile
// failure -> the whole _ret was garbage -> turf ownership NEVER restored on restart (the root of "#501 turfs lost
// on restart"; the earlier string-coerce only papered over it). QUOTE makes both string literals.
_query = "SELECT turf.gang, coalesce(gangs.name,'Contested') AS gangs, turf.id FROM turf LEFT JOIN gangs ON gangs.id=turf.gang ORDER BY turf.id"; 
_ret = [_query,2,true] call DB_fnc_asyncQuery; 
 {_row = AP_turf_list select _forEachIndex;
// owner 2026-06-24 (#501 "turfs lost on restart"): force the restored owner gang id to a STRING. At capture
// AP_turf_list[i][1] = AP_turf_captor[2] (a STRING from `_x getVariable "gang"`), and every consumer (shop
// turf-benefit checks, the captor/owned tallies) compares it against AP_gang_data[0] / AP_turf_captor[2] which
// are STRINGS. A bare DB read could land a NUMBER -> "12345" == 12345 is a type mismatch -> the comparison silently
// fails -> the gang keeps the row but LOSES the benefit/recognition after a reboot = "turf lost on restart". Empty/
// unowned ("" / "0" / NULL) format harmlessly. format is idempotent if it's already a string.
_row set [1, format ["%1", (_x select 0)]];
_row set [2, (_x select 1)];
AP_turf_list set [_forEachIndex, _row];} foreach _ret;
publicVariable "AP_turf_list";
diag_log format ["[LooneyBin][turf] ownership RESTORED from DB: %1", AP_turf_list apply { [_x param [0, "?"], _x param [1, "-"], _x param [2, "Contested"]] }];   // owner 2026-06-24: verifiable boot proof that turf ownership persisted