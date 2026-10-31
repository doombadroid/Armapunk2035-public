private _vehicle = cursorObject;
if (isNull AP_holding_barrel) exitWith {};
if !((typeOf _vehicle) in IL_Supported_Vehicles_BOAT) exitWith {};
if (count nearestObjects[player, ["Land_MetalBarrel_F"], 5] > 1) exitWith {
    ["Too many barrels are nearby. You can only store 1 barrel in your boat at a time.", "basic"] spawn AP_fnc_handleMessage};
private _barrel = AP_holding_barrel;
[] call AP_fnc_dropOil;
private _plb_pos = [0, 0, 0];
_barrel setPos _plb_pos;
_plb_pos =
if (typeOf _vehicle == "C_Boat_Transport_02_F") then {[0, 1, -0.4]} else {[0, -1, -0.4]};
_barrel attachTo[_vehicle, _plb_pos];
_vehicle setVariable["AP_oil_barrel", _barrel, true];