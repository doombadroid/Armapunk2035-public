// AP_fnc_maxtacDispatch (LooneyBin compat) -- MIRROR of server/AP_server/core/wantedsys/fn_maxtacDispatch.sqf
// FIX 2026-07-18 (compat-stub shadow): this file shipped as a reverse-drift no-op stub
// (`if (true) exitWith {};`). Because the mission ALSO registers AP_fnc_maxtacDispatch, the no-op
// SHADOWED the real @AP_server impl on the server (mission CfgFunctions wins) -> every
// server-internal call silently did nothing -> MaxTac was never summoned during fed reserve / bank vault / prison-break escalations (no Join MaxTac prompt, no MaxTac spawn).
// Restored to the real impl. The isServer guard makes it a safe no-op on clients (which lack
// the server-authoritative vars); all real callers are server-internal. Keep in sync w/ the twin.
if (!isServer) exitWith {};
 
private["_max","_locations","_officers","_i","_v","_center","_started"]; 
 
if (AP_activeMAXTAC) exitWith { diag_log "MaxTac requested but already activated!" }; 
 
_max = [_this,0,1,[1]] call BIS_fnc_param; 
_locations = [_this,1,[],[[]]] call BIS_fnc_param; 
_center = [_this,2,[],[[]]] call BIS_fnc_param; 
 
AP_maxtac_officers = []; 
AP_maxtac_active = []; 
AP_deployMAXTAC = []; 
publicVariable "AP_deployMAXTAC"; 
 
 {if (side _x == west && (_x getVariable ["maxtaclevel",0] > 0 || ((_x getVariable ["copLevel",0]) > 2))) then {
AP_maxtac_officers pushBack _x;};
if(count AP_maxtac_officers == _max) exitWith {};} forEach allPlayers;
 
if (count AP_maxtac_officers == 0) exitWith { diag_log "No MaxTac officers are available for dispatch." }; 
AP_summonedMAXTAC = true; 
AP_activeMAXTAC = false; 
AP_maxtacPosOptions = _locations; 
AP_maxtacPos = _center; 
{publicVariable _x} forEach ["AP_summonedMAXTAC","AP_activeMAXTAC","AP_maxtacPosOptions","AP_maxtacPos"]; 
[[_locations, _center], "AP_fnc_maxtacDispatched", AP_maxtac_officers, false] spawn AP_fnc_MP; 
 
AP_maxtac_deployed = true; 
AP_activeMAXTAC = true; 
 
_started = time; 
waitUntil {(((time - _started > 60) && (count AP_maxtac_active > 0)) || !AP_activeMAXTAC || ((count AP_maxtac_officers) == (count AP_maxtac_active)) || (time - _started > 90))}; 
 
if (AP_activeMAXTAC && count AP_maxtac_active > 0) then {_leader = 0;
{ if ((_x getVariable ["copLevel",0]) > ((AP_maxtac_active select _leader) getVariable ["copLevel",0])) then { _leader = _forEachIndex; }; } forEach AP_maxtac_active; 
{AP_roleMAXTAC = switch (true) do {case (_leader == _forEachIndex): { 2 };
case (_forEachIndex == 5 || (_forEachIndex == 6 && _leader == 5)): { 1 }; 
default { 0 };};
(_x getVariable ["ownerID", -1]) publicVariableClient "AP_roleMAXTAC";} forEach AP_maxtac_active;
 
_started = time; 
waitUntil { time - _started > 60 || count AP_deployMAXTAC > 0 }; 
if (count AP_deployMAXTAC == 0) then { AP_deployMAXTAC = (_locations select 0) select 1; publicVariable "AP_deployMAXTAC"; }; 
 
if (surfaceIsWater AP_deployMAXTAC) then {if(AP_deployMAXTAC select 2 > 100) exitWith {};
_v = "B_Boat_Transport_01_F" createVehicle (getMarkerPos "sky_dive"); 
_v lock 0;}
else {
 
_v = "I_MRAP_03_F" createVehicle (getMarkerPos "sky_dive"); 
_v lock 2;};
if(!isNil "_v") then {_v call APS_fnc_setIdletime;
clearMagazineCargoGlobal _v; 
clearWeaponCargoGlobal _v; 
clearItemCargoGlobal _v; 
 
_slot = 0; {if (_leader == _forEachIndex) then { _x action ["getInDriver", _v] }
else {if (surfaceIsWater AP_deployMAXTAC) then {if (_slot < 4) then {_x action ["GetInTurret", _v, [_slot]];
_slot = _slot + 1;};}
else {_x action ["getInCargo", _v];};};} forEach AP_maxtac_active;
 
_v setPos AP_deployMAXTAC;};
{ if (_x distance AP_deployMAXTAC > 20) then { _x setPos [(AP_deployMAXTAC select 0) + ((random 10) - 5), (AP_deployMAXTAC select 1) + ((random 10) - 5), AP_deployMAXTAC select 2] }; } forEach AP_maxtac_active; 
 
waitUntil { !AP_activeMAXTAC };};
 
AP_deployMAXTAC = []; 
publicVariable "AP_deployMAXTAC"; 
AP_maxtac_deployed = false; 
AP_maxtac_active = []; 
if (!isNil "_v") then {if (!isNull _v) then { deleteVehicle _v; };};