params[["_shopType", "", [""]], ["_controlData", [], [[]]]];
if (_shopType isEqualTo "") exitWith {};
if (_controlData isEqualTo[]) exitWith {};
_controlData params["_control", "_selectedIndex"];
if (_selectedIndex isEqualTo - 1) exitWith {};
private _display = findDisplay 39400;
if (isNull _display) exitWith {};
private _itemPreview = _display displayCtrl 39403;
private _mainListGroup = _display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListButton = _mainListGroup controlsGroupCtrl 1001;
private _sideListGroup = _display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _filterType = _control lbData _selectedIndex;
private _allItems = ([_shopType] call AP_fnc_weaponShopCfg) select 1;
private _listItems = _allItems select {(toLower _filterType) isEqualTo(toLower(([_x select 0] call BIS_fnc_itemType) select 0))};
private _discount = [_shopType, true] call AP_fnc_getDiscount;
_mainItemList ctrlSetFade 1.00;
_mainItemList ctrlCommit 0.00; {_x lbSetCurSel - 1}
forEach[_mainItemList, _sideItemList]; {lbClear _x}
forEach[_mainItemList, _sideItemList]; {_x ctrlEnable false}
forEach[_mainItemListButton, _sideItemListButton];
{
    _x params[["_class", ""], ["_name", ""], ["_price", 0]];
    if !(_class isEqualTo "") then {([_class] call AP_fnc_fetchCfgDetails) params["_class", "_displayName", "_picture"];
        _displayName =
        if !(_name isEqualTo "") then {_name} else {_displayName};
        if (_displayName isEqualTo "") exitWith {};
        private _color = [1, 1, 1, 0.3];
        _price =
        if (AP_ndShop) then {_price} else {_price * _discount};
        _price =
        if (AP_ndShop || (_shopType in ["rebelwep", "turf"])) then {_price} else {_price + (_price * (call AP_fnc_getGovTax))};
        _price =
        _price;
        _price =
        _price;
        // NEW DRACHMA: show the independent ND price + gate afford on the exact ND balance in the wallet shop.
        private _ndRow = "";
        if (AP_ndShop) then {_ndRow = [_class] call AP_fnc_ndPriceCfg;
            if (_ndRow isEqualTo "") then { _ndRow = [_price] call AP_fnc_ndFromLegacy; };};
        private _formatText =
        if !(AP_ndShop) then {format["$%1", [round _price] call AP_fnc_numberText]} else {format["%1 ND", [_ndRow] call AP_fnc_ndText]
        };
        private _rowIndex = _mainItemList lnbAddRow[_displayName, _formatText];
        _mainItemList lnbSetPicture[[_rowIndex, 0], _picture];
        _mainItemList lnbSetValue[[_rowIndex, 1], round _price];
        _mainItemList lnbSetData[[_rowIndex, 0], _class];
                    if (_shopType in ["rebelwep", "turf"]) then {if !(AP_ndShop) then {if (AP_cash >= _price) then {_color set[3, 1]};
                } else {if ([_ndRow] call AP_fnc_ndAfford) then {_color set[3, 1]};};};
            if (((AP_cash >= _price) || (AP_atmcash >= _price)) && !(_shopType in ["rebelwep", "turf"])) then {
                _color set[3, 1]};
        _mainItemList lnbSetColor[[_rowIndex, 0], _color];
        _mainItemList lnbSetColor[[_rowIndex, 1], [0.361, 0.722, 0.467, _color select 3]];};}
forEach _listItems; {private _itemListGroup = _x;
    private _itemList = _itemListGroup controlsGroupCtrl 1000;
    private _headerButtons = (allControls(ctrlParent _itemListGroup)) select {
        ((ctrlClassName _x) isEqualTo "AP_RscListNBoxHeaderButton") && ((ctrlParentControlsGroup _x) isEqualTo _itemListGroup)}; {
        _x ctrlEnable((lbSize _itemList) >= 1)}
    forEach _headerButtons;}
forEach[_mainListGroup, _sideListGroup];
ctrlSetFocus _mainItemList;
[_mainItemList, 0, false, false] call AP_fnc_listNBoxSort;
_mainItemList ctrlSetFade 0.00;
_mainItemList ctrlCommit 0.00;