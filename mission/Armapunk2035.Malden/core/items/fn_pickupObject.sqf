private _item = cursorObject;
if (isNull _item) exitWith {};
private _index = [typeOf _item, AP_placeable] call AP_fnc_index;
if (_index isEqualTo - 1) exitWith {["This item cannot be picked up.", "basic"] spawn AP_fnc_handleMessage};
if (!(_item getVariable['AP_placedItem', false])) exitWith {
    ["This item was not placed by a player and cannot be picked up.", "basic"] spawn AP_fnc_handleMessage};
(AP_placeable select _index) params["_itemCfgName", "_className", "_itemLongName", "_rotation", "_distance", "_damagable"];
if !([true, _itemCfgName, 1] call AP_fnc_handleInv) exitWith {
    [format["You don't have room in your inventory for a %1.", _itemLongName], "basic"] spawn AP_fnc_handleMessage};
[format["You picked up a %1.", _itemLongName], "basic"] spawn AP_fnc_handleMessage;
// LooneyBin furniture: also remove from the house's persisted furniture row (matched by position)
if (_itemCfgName in AP_furnitureItems) then {[["remove", getPosATL _item], "APS_fnc_houseFurnitureSRV", 2] spawn AP_fnc_MP;};
deleteVehicle _item;