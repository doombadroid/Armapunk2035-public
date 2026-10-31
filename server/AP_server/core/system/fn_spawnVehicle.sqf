 
private["_vid","_sp","_pid","_query","_sql","_vehicle","_nearVehicles","_name","_player","_price","_insured","_ammo","_maxAmmo","_scd","_color","_colors","_copColors","_side","_exit"]; 
_vid = [_this,0,-1,[0]] call BIS_fnc_param; 
_pid = [_this,1,"",[""]] call BIS_fnc_param; 
_sp = [_this,2,"",["",objNull]] call BIS_fnc_param; 
_unit = [_this,3,objNull,[objNull]] call BIS_fnc_param; 
_price = [_this,4,-1,[0]] call BIS_fnc_param; 
_talents = [_this,5,[],[[]]] call BIS_fnc_param; 
_insured = [_this,6,false,[false]] call BIS_fnc_param; 
_scd = [_this,7,false,[false]] call BIS_fnc_param; 
 
_name = name _unit; 
_player = _unit; 
 
_pos = []; 
_dir = 0; 
_garage = 0; 
 
_vInfo = [_vid,_pid] call DB_fnc_queryVehicle; 
 
if(isNil "_vInfo") exitWith {serv_sv_use = serv_sv_use - [_vid];}; 
if(count _vInfo == 0) exitWith {serv_sv_use = serv_sv_use - [_vid];}; 
 
_color = _vInfo select 8; 
_copColors = []; 
_colors = [(_vInfo select 2)] call AP_fnc_vehicleColorCfg; {
if ((_x select 1) in ["cop","fed"]) then { _copColors pushBack _forEachIndex };} forEach _colors;
 
if (!_scd && (side _unit isEqualTo west) && !((_color in _copColors) || (count _colors == 0))) exitWith { [[1,"This vehicle can only be used when you are in the undercover role."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP; }; // cosmetic, side is the right key
_exit = false; 
if (typeName _sp == "OBJECT") then {_pos = getPosATL _sp;
_dir = getDir _sp;}
else {_pos = getMarkerPos _sp;
_dir = markerDir _sp; 
if (parseNumber _sp > 0) then {
_garage = 1;   // owner 2026-06-16 (#254): real HOUSE/shed garage -- spawn is deliberately against the building, do NOT nudge it
_gObj = nearestObject [_pos, "House"];
if (typeOf _gObj == "Land_i_Shed_Ind_F") then {_pos set[2, ((getPosATL _gObj) select 2) + 0.374989];}
else {_pos set[2, ((getPosATL _gObj) select 2) + 0.155541];
if((_vInfo select 2) in ["C_Van_01_box_F","C_Van_01_fuel_F","C_Van_01_transport_F","B_Truck_01_box_F","B_Truck_01_transport_F","I_Truck_02_covered_F","I_Truck_02_transport_F"]) exitWith 
{_exit = true;
serv_sv_use = serv_sv_use - [_vid]; 
[[1,format["%1 is too large for this garage.",_vInfo select 2]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;};};};};
if(_exit) exitWith {}; 
if(_vid == -1 OR _pid == "" OR count _pos == 0) exitWith {}; 
// owner 2026-06-15 (#237/#243): the DRUG CARTEL garage spawn marker sits on the flag POLE -> cars spawned
// intersecting the pole (and players on the cap point) -> violent physics desync that KILLED players. Nudge
// _pos to a flat spot >=3m off any object so a car never spawns on the pole/structure.
// owner 2026-06-16 (#254): the old guard skipped the nudge whenever a House_F was within 8m -- but the drug
// cartel sits next to a CHURCH (House_F), so the nudge was skipped there and cars STILL hit the pole. Gate on
// the actual garage TYPE instead: nudge every open/marker garage, only leave true house/shed garages alone.
if (_garage == 0) then {private _safe = [_pos, 0, 10, 3.2, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_safe isEqualType [] && {count _safe >= 2} && {(_safe distance2D _pos) < 20}) then {
        _pos set [0, _safe select 0]; _pos set [1, _safe select 1];};};
if(_vid in serv_sv_use) exitWith {diag_log "[spawnVehicle] Already in serv_sv_use"}; 
serv_sv_use pushBack _vid; 
 
if((_vInfo select 5) == 0) exitWith {serv_sv_use = serv_sv_use - [_vid];
[[1,format["Sorry but %1 was classified as a destroyed vehicle and was sent to the scrap yard.",_vInfo select 2]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP; 
}; 
if((_vInfo select 6) == 1) exitWith {serv_sv_use = serv_sv_use - [_vid];
[[1,format["Sorry but %1 is already active somewhere in the map and cannot be spawned.",_vInfo select 2]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP; 
}; 
_nearVehicles = nearestObjects[_pos,["Car","Air","Ship"],4]; 
if(count _nearVehicles > 0) exitWith {serv_sv_use = serv_sv_use - [_vid];
[[1,"There is a vehicle on the spawn point."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;};
 
_side = _vInfo select 1; 
_plate = _vInfo select 7; 
_alarm = ((_vInfo select 12) == 1); 
 
serv_sv_use = serv_sv_use - [_vid]; 
 
_vehicle = [(_vInfo select 2),_color,_pos,_dir,_plate,_player,_alarm] call AP_fnc_createVehicle;
// owner 2026-06-16: kill jet RADAR on a civ life server. setVehicleRadar 0 = active radar/target HUD off;
// the datalink toggles stop the jet receiving/sharing radar targets. (The PASSIVE-radar SENSOR component
// itself is CfgVehicles-only -- no runtime command removes it; that needs a config patch, see chat.)
if (_vehicle isKindOf "Plane") then {_vehicle setVehicleRadar 0;
_vehicle setVehicleReceiveRemoteTargets false;
_vehicle setVehicleReportRemoteTargets false;
_vehicle setVehicleReportOwnPosition false;};

[[_vehicle],"APS_fnc_addVehicle2Chain",_unit,false] spawn AP_fnc_MP;
 
if (typeOf _vehicle == "B_G_Offroad_01_armed_F" && (_color in _copColors)) then { _vehicle setVariable ["digiLock", true, true]; }; 
 
if (_insured) then { [_vehicle, true] call APS_fnc_insured; }; 
 
[_vehicle, _vInfo select 11, _vInfo select 13, _vInfo select 10] spawn {_vehicle = _this select 0;
_damage = _this select 1; 
_ammo = _this select 2; 
_fuel = _this select 3; 
sleep 10; 
_vehicle allowDamage true; 
_vehicle setDamage (_damage / 100); 
_vehicle setFuel (_fuel / 100); 
_vehicle setVehicleAmmo (_ammo / 100);};
 
_ammo = 0; 
if ((typeOf _vehicle) == "B_G_Offroad_01_armed_F") then {_maxAmmo = 400; {_ammo = _ammo + (_x select 1);
} forEach (magazinesAmmoFull _vehicle); 
_ammo = _ammo / _maxAmmo;};
 
[_plate,_pid,_vehicle,1,_alarm,_ammo] call DB_fnc_updateVehicle;