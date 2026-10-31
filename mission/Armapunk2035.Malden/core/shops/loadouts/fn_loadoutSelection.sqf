params[["_controlData", [], [[]]]];
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 39400;
if (isNull _plb_display) exitWith {};
private _filterList = _plb_display displayCtrl 39402;
private _itemPreview = _plb_display displayCtrl 39403;
private _mainListGroup = _plb_display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _sideListGroup = _plb_display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _deleteButton = _sideListGroup controlsGroupCtrl 1005;
private _saveButton = _sideListGroup controlsGroupCtrl 1004;
private _dollarsButton = _sideListGroup controlsGroupCtrl 1006;
private _ndButton = _sideListGroup controlsGroupCtrl 1007; {_x ctrlEnable false;}
forEach[_deleteButton, _saveButton, _sideItemListButton, _dollarsButton, _ndButton]; {_x ctrlShow false}
forEach[_dollarsButton, _ndButton];
lbClear _mainItemList;
_itemPreview ctrlSetText _picture;
_mainItemList lbSetCurSel - 1;
private _val = (_control lnbValue[lnbCurSelRow _control, 0]);
private _price = (_control lnbValue[lnbCurSelRow _control, 1]);
if (_val >= 0 || _price >= 10) then {{_x ctrlEnable true;
        _x ctrlShow true}
    forEach[_deleteButton, _saveButton, _sideItemListButton];};
if (_val isEqualTo - 4) then {_saveButton ctrlEnable true;};
if (_val in [-5, -3]) then {_deleteButton ctrlEnable true;};
if (_val isEqualTo - 2) exitWith {
    ["To utilize this loadout slot you need to be an LoonyBin Plus Subscriber. Visit https://discord.gg/TdNVfcFcx6 to learn more!", "basic"] spawn AP_fnc_handleMessage;
};
if (_val isEqualTo - 3) exitWith {
    ["You cannot utilize this loadout slot at this location. Try the location you made the loadout at or delete this loadout!", "basic"] spawn AP_fnc_handleMessage;
};
if (_val isEqualTo - 4) exitWith {["This slot is empty. Click save to save your loadout!", "basic"] spawn AP_fnc_handleMessage;};
if (_val isEqualTo - 5) then {
    ["You cannot utilize this loadout since it has items that you cannot own.", "basic"] spawn AP_fnc_handleMessage;};
private _items = [((AP_loadoutHolder select _selectedIndex) select 3)] call AP_fnc_getLoadoutItems; {
    _x params[["_classname", ""], ["_qty", 0]];
    ([_className] call AP_fnc_fetchCfgDetails) params["_class", "_displayName", "_picture"];
    private _rowIndex = _mainItemList lnbAddRow[_displayName, format["%1", _qty]];
    _mainItemList lnbSetData[[_rowIndex, 0], _class];
    _mainItemList lnbSetData[[_rowIndex, 1], _qty];
    _mainItemList lnbSetValue[[_rowIndex, 1], _qty];
    _mainItemList lnbSetPicture[[_rowIndex, 0], _picture];}
forEach _items; {_x params[["_virtName", ""], ["_virtQty", 0]];
    private _displayName = ["getName", _virtName] call AP_fnc_virtItemCfg;
    private _picture = ["getIcon", _virtName] call AP_fnc_virtItemCfg;
    private _rowIndex = _mainItemList lnbAddRow[_displayName, format["%1", _virtQty]];
    _mainItemList lnbSetData[[_rowIndex, 0], _virtName];
    _mainItemList lnbSetData[[_rowIndex, 1], _virtQty];
    _mainItemList lnbSetValue[[_rowIndex, 1], _virtQty];
    _mainItemList lnbSetPicture[[_rowIndex, 0], _picture];}
forEach((AP_loadoutHolder select _selectedIndex) select 4);