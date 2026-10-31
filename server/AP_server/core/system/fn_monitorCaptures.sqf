 
private ["_id","_point","_players","_totals","_new","_gang","_updated","_percent","_value","_lastUpdate","_row"]; 
 
// singleevh.md: cartel capture scan migrated onto the single-wheel scheduler (id "monitorCaptures", 60s).
// Self-contained per-tick body (locals re-declared + assigned from globals each run; _lastUpdate vestigial);
// runs in the wheel's transient spawn so its DB touch (DB_fnc_updateCaptures on a flip) may suspend.
// Flag OFF => original loop runs byte-for-byte (else branch) = ZERO behavior change.
["monitorCaptures", {params ["_st"];
private ["_id","_point","_players","_totals","_new","_gang","_updated","_percent","_value","_lastUpdate","_row"]; 
_lastUpdate = time; 
_updated = false; {if (!(worldName == "Stratis" && !(_x select 4))) then {_id = _forEachIndex + 1;
_point = missionNamespace getVariable [format["capture_%1", _id], objNull];   // LooneyBin: capture_N objects aren't in this mission -> was `call compile` of an undefined var -> nil -> `list nil` spammed errors every 60s. Guard it.
_players = if (isNull _point) then { [] } else { list _point };
if (time - (_x select 3) > 900) then {_totals = [];
_rowUpdated = false; {_pointPos = getPosATL(_point);
if (_x in playableUnits && ((getPosATL _x) distance _pointPos) < 50) then {_gang = _x getVariable ["gang", "0"];
if (_gang != "0" && (!(surfaceIsWater (position _x)) || _id == 3) && !(primaryWeapon _x in ["","Binocular","SMG_02_F","hgun_PDW2000_F","arifle_sdar_F"]) && !(_x getVariable ["isBountyHunter", false])) then 
{if (!(_gang in _totals)) then { _totals set [count _totals, _gang]; };};};} foreach _players;
 
if (count _totals == 1) then {
 
if ((_x select 2) == 0) then {_value = _x;
_value set [1, (_totals select 0)]; 
AP_capture_list set [_forEachIndex, _value]; 
_updated = true; 
_rowUpdated = true; 
_x = _value;};
 
if ((_totals select 0) == (_x select 1)) then {if ((_x select 2) < 1) then {
_new = (_x select 2) + (1/15);   // owner 2026-06-24: cartel cap = 15 MINUTES. 60s tick * (1/15 per tick) = 15 ticks to 100%. (was +0.1 = 10 min.) Progress only advances while ONE gang holds the lead, so a contested cap still takes longer.
if (_new > 1) then { _new = 1; };
_value = _x; 
_value set [2, _new]; 
 
if (_new == 1) then {_value set [3, time];
_value set [6, -1];  
if (worldName == "Altis") then { [_forEachIndex, (AP_capturePos select _forEachIndex) select 1, 2, false] spawn APS_fnc_spawnCaptures; }; 
_row = _x; {if (_x getVariable ["gang","0"] == _row select 1) then {[[2,5],"AP_fnc_addStatistic",_x,false] spawn AP_fnc_MP;};
} forEach _players;
// owner 2026-06-22 (#486 cartels reset on restart): a cartel JUST flipped owner -- persist it to the DB NOW. The
// only other save was the 8-min periodic updateCaptures, so a restart inside that window dropped the new ownership
// (the gang lost the cartel AND its income stream after the reboot -- also read as "gang bank emptied", #489).
// Mark this row changed + flush immediately; updateCaptures only writes the changed rows, so this is cheap.
AP_capture_changed set [_forEachIndex, _value];
[] call DB_fnc_updateCaptures;};

AP_capture_list set [_forEachIndex, _value];
_updated = true; 
_rowUpdated = true; 
_x = _value;};}
 
else {if ((_x select 2) > 0) then {_new = (_x select 2) - 0.1;
if (_new < 0) then { _new = 0; }; 
_value = _x; 
_value set [2, _new]; 
AP_capture_list set [_forEachIndex, _value]; 
_updated = true; 
_rowUpdated = true; 
_x = _value; 
 
[[_id],"AP_fnc_capNotice",civilian,false] spawn AP_fnc_MP;};};
 
if (_rowUpdated) then {AP_capture_changed set [_forEachIndex, _x];};};}
else {_row = _x; {
[[2,format["This area was recently captured and cannot be again for another %1 + minutes.", floor ((900 - (time - (_row select 3))) / 60)]],"AP_fnc_broadcast",_x,false] spawn AP_fnc_MP; 
} forEach _players;};
 
_marker = format["capture_label_%1", _id]; 
_currentText = markerText _marker; 
_newText = _currentText; 
switch (true) do {case ((_x select 2) == 1): {_point = _x;
_gangRow = []; 
{ if ((_x select 0) == (_point select 1)) then { _gangRow = _x; }; } foreach AP_server_gangs; 
if (count _gangRow == 0) exitWith {}; 
_newText = format["%1 - %2", (_point select 0), _gangRow select 1];};
default { _newText = format["%1 - Contested", (_x select 0)]; };};
if (_newText != _currentText) then { _marker setMarkerText _newText; };};} forEach AP_capture_list;
if (_updated) then { AP_capture_old = AP_capture_list; publicVariable "AP_capture_list"; };}, 60, false, true] call AP_fnc_schedule;
