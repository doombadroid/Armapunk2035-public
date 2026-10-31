disableSerialization;
private _display = findDisplay 1520;
private _itemList = _display displayCtrl 1521;
private _pickupButton = _display displayCtrl 1522;
private _itemSelection = lbSelection _itemList;
private _initialLbSize = lbSize _itemList;
private _obj =
switch (typeOf cursorObject) do {case "Land_Suitcase_F": {cursorObject}; case "Box_Syndicate_WpsLaunch_F": {cursorObject};
        default {nearestObject[player, "Land_Suitcase_F"]};}; if (_itemSelection isEqualTo[]) exitWith {};
if (isPlayer _obj) exitWith {closeDialog 0};
if (player distance _obj > 5) exitWith {closeDialog 0};
if (_obj getVariable["AP_inUse", objNull] isNotEqualTo player) exitWith {closeDialog 0};
AP_pickingUpItems = true;
_pickupButton ctrlEnable false; {private _lbSize = lbSize _itemList;
    private _lbSizeChange = _initialLbSize - _lbSize;
    private _selectedIndex =
    if (_forEachIndex isEqualTo 0) then {_x} else {_x - _lbSizeChange};
    private _itemData = parseSimpleArray(_itemList lbData _selectedIndex);
    if (_lbSize isEqualTo 0) exitWith {closeDialog 0};
    if !(_itemData params[["_itemShortName", "", [""]], ["_itemAmount", -1, [0]]]) exitWith {};
    if (AP_pickMenuItems isNotEqualTo[]) then {[_obj, _itemShortName, _itemAmount] call AP_fnc_pickupItem;};}
forEach _itemSelection;
AP_pickingUpItems = false;
_pickupButton ctrlEnable true;