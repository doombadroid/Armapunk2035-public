/*
    APS_fnc_flipVehicle  (LooneyBin: unflip a vehicle, server-side)
    2020 client args: [_car]   (fn_flip -> [[_car],"APS_fnc_flipVehicle",2] spawn AP_fnc_MP)
    Was `_car = _this` -> _this is the ARGS ARRAY [_car], so setVectorUp ran on the array, not the
    vehicle -> the 5s message played but nothing flipped. Pull the vehicle out of the array.
*/
params [["_car", objNull, [objNull]]];
if (isNull _car) exitWith {};
_car setVectorUp (surfaceNormal (position _car));
_car setPosASL [(getPosASL _car) select 0, (getPosASL _car) select 1, ((getPosASL _car) select 2) + 2.2];
