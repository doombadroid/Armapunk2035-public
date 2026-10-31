/*
    APS_fnc_medSupplySpawn  (LooneyBin -- implemented from stub 2026-06-09)
    The medDrop ITEM (core/pmenu/fn_useItem.sqf): client checked SRV_lastMedSupply (15-min global
    cooldown) + one-active-crate + consumed the item, then sends [player]. Server drops the supply
    crate by parachute, tags it with the caller's uid (the client's one-active-crate check reads
    AP_medCrateOwners), and stamps + publishes SRV_lastMedSupply.
*/
params [["_caller", objNull, [objNull]]];
if (isNull _caller) exitWith {};
SRV_lastMedSupply = serverTime;
publicVariable "SRV_lastMedSupply";
private _pos = [getPosATL _caller, 10, 40, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
private _chute = "B_Parachute_02_F" createVehicle [_pos select 0, _pos select 1, 100];
private _crate = "B_supplyCrate_F" createVehicle [_pos select 0, _pos select 1, 98];
_crate attachTo [_chute, [0, 0, -1.2]];
_crate setVariable ["owner", getPlayerUID _caller, true];
_crate setVariable ["AP_medCrateOwners", [[getPlayerUID _caller, name _caller]], true];
clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
{ _crate addItemCargoGlobal _x; } forEach [["FirstAidKit", 15], ["Medikit", 2]];
[_chute, _crate] spawn {params ["_chute", "_crate"];
    waitUntil { uiSleep 1; isNull _chute || {(getPosATL _crate) select 2 < 2} };
    detach _crate;
    private _smoke = "SmokeShellBlue" createVehicle (getPosATL _crate);
    uiSleep 1800; { if (!isNull _x) then { deleteVehicle _x; }; } forEach [_crate, _smoke];   // 30-min despawn
};
[["Your supply crate is inbound!", "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
diag_log format ["[LooneyBin][medSupply] crate for %1 at %2", getPlayerUID _caller, _pos];
