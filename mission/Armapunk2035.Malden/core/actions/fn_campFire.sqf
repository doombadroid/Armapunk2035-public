if !(isNull objectParent player) exitWith {
    ["Starting a fire in a vehicle is hazardous to your health!", "basic"] spawn AP_fnc_handleMessage;};
if ((count(nearestObjects[player, ["Land_Campfire_F"], 25]) > 0) || (count(nearestObjects[player, ["MetalBarrel_burning_F"], 25]) > 0)) exitWith {
    ["There's already a campfire nearby!", "basic"] spawn AP_fnc_handleMessage};
private _plb_pos = [(getPos player), 1, 5, 1, 0, 0, 0, [], [0, 0, 50]] call BIS_fnc_findSafePos;
if (isOnRoad _plb_pos || _plb_pos isEqualTo[0, 0, 50]) exitWith {
    ["The fire would be too close to a road or building to setup safely!", "basic"] spawn AP_fnc_handleMessage;};
private _barrel =
// Larche keeps its own 1100 m ring: the town sits on a hill and the old chain gave it more room.
if (([500] call AP_fnc_nearTown) || {(player distance2D (getMarkerPos "civ_spawn_2")) < 1100}) then {
    true} else {false};
if ([false, "campfire", 1] call AP_fnc_handleInv) then {private _obj_main =
    if !(_barrel) then {
        "Land_Campfire_F"
        createVehicle _plb_pos;} else {
        "MetalBarrel_burning_F"
        createVehicle _plb_pos;};
    ["You build youself a little fire nearby to cook with.", "basic"] spawn AP_fnc_handleMessage;
    _obj_main setVariable["AP_owner", player, true]; [[_obj_main, 900], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;};