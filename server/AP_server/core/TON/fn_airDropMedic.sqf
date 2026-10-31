/*
    APS_fnc_airDropMedic  (LooneyBin -- implemented from stub 2026-06-09)
    Random medic revive reward (1-in-3 on revive, core/medical/fn_revivePlayer.sqf sends [player]).
    Parachutes a small medical resupply crate near the medic.
*/
params [["_medic", objNull, [objNull]]];
if (isNull _medic) exitWith {};
private _pos = [getPosATL _medic, 10, 40, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
private _chute = "B_Parachute_02_F" createVehicle [_pos select 0, _pos select 1, 90];
private _crate = "B_CargoNet_01_ammo_F" createVehicle [_pos select 0, _pos select 1, 88];
_crate attachTo [_chute, [0, 0, -1.3]];
_crate setVariable ["owner", "med_drop", true];
clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
{ _crate addItemCargoGlobal _x; } forEach [["FirstAidKit", 10], ["Medikit", 1], ["ToolKit", 1]];
[_chute, _crate] spawn {params ["_chute", "_crate"];
    waitUntil { uiSleep 1; isNull _chute || {(getPosATL _crate) select 2 < 2} };
    detach _crate;
    private _smoke = "SmokeShellBlue" createVehicle (getPosATL _crate);
    uiSleep 900; { if (!isNull _x) then { deleteVehicle _x; }; } forEach [_crate, _smoke];};
[["A medical resupply drop is inbound on your position!", "basic"], "AP_fnc_handleMessage", _medic, false, false] spawn AP_fnc_MP;
