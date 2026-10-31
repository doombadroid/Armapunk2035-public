 
private["_presence","_total","_animals","_pos"]; 
 
_animals = ["Cock_random_F","Goat_random_F","Goat_random_F","Goat_random_F","Hen_random_F","Sheep_random_F","Sheep_random_F","Alsatian_Random_F"];  
_pos = getMarkerPos "hunting_ground_marker";   // owner 2026-06-21 (#451): was "hunting" -- no such marker -> getMarkerPos [0,0,0] -> presence check (hunters 26km away) never true -> animals (goats/sheep/hens/dogs) NEVER spawned, only engine ambient rabbits. Real marker is hunting_ground_marker @ [14254,21937].
 
_alive = 0; {if (!isNull _x) then {if (alive _x) then {_alive = _alive + 1;};};} forEach AP_animals_array;
 
_presence = false;  
{ if (isPlayer _x && alive _x && _x distance _pos < 650) exitWith { _presence = true; }; } forEach allPlayers; 
 
_total = 20 - _alive;  
 
if(_presence) then {if (time - AP_animals_spawned_time > 300) then {
// owner 2026-07-17: HC OFFLOAD -- one group per top-up batch, ownership handed to the headless client so the
// animal AI (goat/sheep/dog fsm + pathfinding) simulates on the HC, not the game server. If no HC is online
// (AP_hcOwner<=0) the group stays server-owned. Server-created -> group is server-local -> setGroupOwner is valid.
private _grp = createGroup civilian;
for "_i" from 1 to _total do {_type = _animals call BIS_fnc_selectRandom;
_animal = _grp createUnit [_type, _pos,[],500,"NONE"];
AP_animals_array set[count AP_animals_array,_animal];};
if ((localNamespace getVariable ["AP_hcOwner", 0]) > 0) then { _grp setGroupOwner (localNamespace getVariable ["AP_hcOwner", 0]); };
AP_animals_spawned_time = time;
AP_animals_spawned = true;};}
else {{if(!isNull _x) then {deleteVehicle _x;};} foreach AP_animals_array;
 
AP_animals_array = []; 
AP_animals_spawned = false;};