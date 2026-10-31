 
private["_vehicle","_impound","_vInfo","_vInfo","_plate","_uid","_query","_sql","_unit","_ammo","_maxAmmo"]; 
_vehicle = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
_impound = [_this,1,false,[true]] call BIS_fnc_param; 
_unit = [_this,2,ObjNull,[ObjNull]] call BIS_fnc_param; 
 
if(isNull _vehicle OR isNull _unit) exitWith {AP_impound_inuse = false; (owner _unit) publicVariableClient "AP_impound_inuse";AP_garage_store = false;(owner _unit) publicVariableClient "AP_garage_store";};
// owner 2026-07-24 SECURITY (audit): _impound is argument #1 straight off the wire, and the impound branch
// below skips EVERY ownership check the normal store branch performs (that one rejects with "This vehicle
// doesn't belong to you"). So any client could remoteExec with _impound = true and force-impound or
// outright deleteVehicle ANY vehicle in the world -- no side, cop, distance or ownership test at all.
// Impounding is a cop action: the only legitimate _impound = true caller is fn_impoundAction.sqf:175,
// which passes `player` as _unit. Require the same for a client call -- a resolvable caller who IS _unit
// and is side west. Personal stores (_impound = false, fn_storeVehicle:111/132) are untouched and keep
// their existing owner check. server-internal (_src == 0) passes.
// audit 2026-09-26: that owner check compares dbInfo's uid with getPlayerUID _unit -- and _unit is ALSO off the wire, so
// passing the victim as _unit force-garaged their car. Both legit callers (fn_storeVehicle, fn_impoundAction) pass
// the caller's own `player`, so require caller == _unit on the STORE path too; the cop test stays impound-only.
private _srcVS = remoteExecutedOwner;   // 0 == server-internal = trusted
private _vsBlock = false;
if (_srcVS isNotEqualTo 0) then {private _vsCaller = (allPlayers select { owner _x isEqualTo _srcVS }) param [0, objNull];
    if (isNull _vsCaller || {_vsCaller isNotEqualTo _unit} || {_impound && {!(_vsCaller call APS_fnc_isDutyCop)}}) then {
        ["-SEC-", _vsCaller, format ["BLOCKED vehicleStore %1 of %2 (caller not the passed unit, or not a duty cop for impound)", ["STORE", "IMPOUND"] select _impound, typeOf _vehicle]] call APS_fnc_logIt;
        _vsBlock = true;   // signal; nested exitWith would only leave this then-block
    };};
if (_vsBlock) exitWith {AP_impound_inuse = false; (owner _unit) publicVariableClient "AP_impound_inuse";
    AP_garage_store  = false; (owner _unit) publicVariableClient "AP_garage_store";};
 
// owner 2026-06-18 (CLANKR dupe -- player099/player100): ANTI-DUPE trunk settle. AP_vinv is mutated CLIENT-side via a
// public setVariable that reaches the server ASYNC; a store/impound fired mid-take read the PRE-take trunk, so
// DB_fnc_updateVehicle (below) persisted an item the player had already pocketed -> re-pull DUPED it. (Proven:
// -VEHINV- close logs show "Owner: NoVehData" = vehicle deleted DURING the take.) Raise AP_trunkLock so the
// fn_openInventory monitor force-closes any open dialog + blocks reopen, then settle out the propagation window
// so every in-flight take has landed before we snapshot AP_vinv + cargo. Cleared on the two store validation-
// fail exits below (vehicle not deleted there); deleteVehicle handles every other path (lock dies with object).
_vehicle setVariable ["AP_trunkLock", true, true];
uiSleep 1.25;
if (isNull _vehicle) exitWith { AP_impound_inuse = false; (owner _unit) publicVariableClient "AP_impound_inuse"; AP_garage_store = false; (owner _unit) publicVariableClient "AP_garage_store"; };

// delete vehicle objects
private _objects = attachedObjects _vehicle; {
	// delete those objects
	deleteVehicle _x;} forEach _objects;

_vInfo = _vehicle getVariable["dbInfo",[]];
// owner 2026-06-22 (#500 "This vehicle isn't a persistent vehicle"): some pulled/restored vehicles carry ONLY
// AP_dbInfo, not the legacy dbInfo this store reads -> _vInfo empty -> store rejected (and IMPOUND DELETED it =
// vehicle loss). Reconstruct a store-valid 4-field dbInfo from AP_dbInfo [uid,plate], exactly like fn_saveVehicles
// (#406): index 2 = "objNull" string, alarm off. Additive -- only fires when dbInfo is missing, so working stores
// are untouched; a truly wild vehicle (no AP_dbInfo either) still correctly fails as non-persistent.
if (count _vInfo == 0) then {private _pdb = _vehicle getVariable ["AP_dbInfo", []];
    if (count _pdb >= 2) then { _vInfo = [_pdb select 0, _pdb select 1, "objNull", false]; };};
_plate = _vInfo select 1;
_uid = _vInfo select 0;
 
_ammo = 0; 
if ((typeOf _vehicle) == "B_G_Offroad_01_armed_F") then {_maxAmmo = 400; {_ammo = _ammo + (_x select 1);
} forEach (magazinesAmmoFull _vehicle); 
_ammo = _ammo / _maxAmmo;};
 
if(_impound) then {if(count _vInfo == 0) then {AP_impound_inuse = false;
(owner _unit) publicVariableClient "AP_impound_inuse"; 
deleteVehicle _vehicle;}
else {_alarm = 0;
if ((_vInfo select 3)) then { _alarm = 1; };  
[_plate,_uid,_vehicle,0,_alarm,_ammo,true] call DB_fnc_updateVehicle;
_vehicle spawn {sleep 1; deleteVehicle _this};  
AP_impound_inuse = false; 
(owner _unit) publicVariableClient "AP_impound_inuse";};}
else {if(count _vInfo == 0) exitWith {[[1,"This vehicle isn't a persistent vehicle."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;
_vehicle setVariable ["AP_trunkLock", false, true];   // anti-dupe lock: release (vehicle kept, not stored)
AP_garage_store = false;
(owner _unit) publicVariableClient "AP_garage_store";};
 
if(_uid != getPlayerUID _unit) exitWith {
[[1,"This vehicle doesn't belong to you therefore you cannot store it."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;
_vehicle setVariable ["AP_trunkLock", false, true];   // anti-dupe lock: release (vehicle kept, not stored)
AP_garage_store = false;
(owner _unit) publicVariableClient "AP_garage_store";};
_alarm = 0; 
if ((_vInfo select 3)) then { _alarm = 1; };  
[_plate,_uid,_vehicle,0,_alarm,_ammo,true] call DB_fnc_updateVehicle;
_vehicle spawn {sleep 1; deleteVehicle _this};  
AP_garage_store = false; 
(owner _unit) publicVariableClient "AP_garage_store"; 
[[1,"The vehicle has been stored in your garage."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;};