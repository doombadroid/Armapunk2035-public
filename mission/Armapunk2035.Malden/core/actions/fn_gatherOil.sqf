params[["_gen", objNull, [objNull]]];
if !(isNull AP_pumped_barrel) exitWith {
    ["You already have a barrel of oil. Process that one first.", "basic"] spawn AP_fnc_handleMessage};
if !(isNil "AP_pumpingOil") exitWith {};
AP_pumpingOil = true;
titleText["Pumping oil and filling barrel...", "PLAIN"];
private _delay =
if (70 in AP_side_talents) then {3} else {5};
uiSleep _delay;
private _obj_main = "Land_MetalBarrel_F"
createVehicle[0, 0, 0];
_obj_main allowDamage false;
_obj_main setPosASL[((getPosASL _gen) select 0) + 3, (getPosASL _gen) select 1, (getPosASL _gen) select 2];
_obj_main setVariable["AP_owner", player, true];
_obj_main enableRopeAttach false;
player reveal _obj_main;
AP_pumped_barrel = _obj_main;
_obj_main addAction["Pickup Barrel", AP_fnc_pickupOil, cursorTarget, -1, false, true, "", 'isNull AP_holding_barrel && _target distance player < 4', 6];
titleText["Barrel filled. It may take a minute before you can pick it up.", "PLAIN"];
AP_pumpingOil = nil;