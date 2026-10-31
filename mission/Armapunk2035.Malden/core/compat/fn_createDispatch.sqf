// AP_fnc_createDispatch (LooneyBin compat) -- MIRROR of server/AP_server/core/wantedsys/fn_createDispatch.sqf
// FIX 2026-07-18 (compat-stub shadow): this file shipped as a reverse-drift no-op stub
// (`if (true) exitWith {};`). Because the mission ALSO registers AP_fnc_createDispatch, the no-op
// SHADOWED the real @AP_server impl on the server (mission CfgFunctions wins) -> every
// server-internal call silently did nothing -> cops got NO MaxSec dispatch alerts/pings for prison-break, bank vault drill, federal reserve, or store robberies (AP_dispatchTasks never populated).
// Restored to the real impl. The isServer guard makes it a safe no-op on clients (which lack
// the server-authoritative vars); all real callers are server-internal. Keep in sync w/ the twin.
if (!isServer) exitWith {};
 
private["_id","_desc","_value","_chance"]; 
 
_id = [_this,0,0,[0]] call BIS_fnc_param; 
_desc = [_this,1,"",[""]] call BIS_fnc_param; 
_value = [_this,2,0,[0]] call BIS_fnc_param; 
_chance = [_this,3,0,[0]] call BIS_fnc_param; 
_maxCops = [_this,4,4,[0]] call BIS_fnc_param; 
_position = [_this,5,[0,0,0],[[]]] call BIS_fnc_param; 
_unitUID = [_this,6,"",[""]] call BIS_fnc_param; 
 
if (isNull AP_dispatcher && _unitUID == "") then {{if (side _x == west) then {
[[_id,_desc,_value,_position], "AP_fnc_newDispatch", _x, false] spawn AP_fnc_MP;};} forEach allPlayers;};
 
AP_dispatchTasks pushBack [_id,_desc,_value,_maxCops,[],_position,_unitUID]; 
if (!isNull AP_dispatcher) then { (AP_dispatcher getVariable ["ownerID", -1]) publicVariableClient "AP_dispatchTasks" };