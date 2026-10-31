 
private["_crate", "_position", "_posIndex", "_house", "_inventory", "_container", "_containers", "_virtual","_containerId","_houseId"]; 
_crate = [_this,0,"",[""]] call BIS_fnc_param; 
_position = [_this,1,[],[[]]] call BIS_fnc_param; 
_posIndex = [_this,2,-1,[-1]] call BIS_fnc_param; 
_house = [_this,3,objNull,[objNull]] call BIS_fnc_param; 
_inventory = [_this,4,[],[[]]] call BIS_fnc_param; 
_virtual = [_this,5,[],[[]]] call BIS_fnc_param; 
_ownerId = [_this,6,"",[""]] call BIS_fnc_param; 
_gangHouse = [_this,7,false,[false]] call BIS_fnc_param; 
_containerId = [_this,8,-1,[-1]] call BIS_fnc_param; 
_houseId = [_this,9,"0",["0"]] call BIS_fnc_param; 
 
if (count _position == 0) exitWith {};  
 
_nObject = _position nearestObject _crate; 
_found = false; 
if (!isNull _nObject) then {if ((_nObject getVariable["containerId", -1]) == _posIndex) then { _found = true; };};
if (_found) exitWith {}; 
 
_position = [_position select 0, _position select 1, (_position select 2) + 0.15]; 
_container = createVehicle [_crate, _position, [], 0, "CAN_COLLIDE"]; 
 
_container setVectorUp [0,0,1]; 
_container setDamage 0; 
 
clearWeaponCargoGlobal _container; 
clearMagazineCargoGlobal _container; 
clearBackpackCargoGlobal _container; 
clearItemCargoGlobal _container; 
 
_modified = false; 
_vItems = _virtual select 0; 
 
// owner 2026-06-21: the per-restart spirit aging that used to live here (Land_WaterBarrel_F stage-bump,
// scotch_0->scotch_1 etc. once per restart) is REMOVED. Spirits now age in REAL TIME in the house
// barrel_crop via APS_fnc_barrelSRV (6h/stage, restart-proof -- like the weed greenhouse). This
// storage container no longer ages its contents.
_container setVariable["house", _house, true]; 
_container setVariable["containerId", _posIndex, true]; 
_container setVariable["Trunk", _virtual, true]; 
_container enableRopeAttach false; 
if (_gangHouse) then { _container setVariable["crateOwner", "0"]; } 
else { _container setVariable["crateOwner", _ownerId]; }; 
_house setVariable["containerCount", (_house getVariable["containerCount", 0])+1, true]; 
_containers = _house getVariable ["containers", []]; 
_containers set [count _containers, _container]; 
_house setVariable["containers", _containers]; 
_house setVariable["conUniqueId", _containerId]; 
 
if ((count _inventory) > 0) then {_x = _inventory select 0;
for "_i" from 0 to ((count (_x select 0)) - 1) do {_container addWeaponCargoGlobal [(_x select 0) select _i,(_x select 1) select _i];};
_x = _inventory select 1; 
for "_i" from 0 to ((count (_x select 0)) - 1) do {_container addMagazineCargoGlobal [(_x select 0) select _i,(_x select 1) select _i];};
_x = _inventory select 2; 
for "_i" from 0 to ((count (_x select 0)) - 1) do {_container addBackpackCargo [(_x select 0) select _i,(_x select 1) select _i];};
_x = _inventory select 3; 
for "_i" from 0 to ((count (_x select 0)) - 1) do {_container addItemCargoGlobal [(_x select 0) select _i,(_x select 1) select _i];};};
 
AP_storage_array pushBack _container; 
 
_container;