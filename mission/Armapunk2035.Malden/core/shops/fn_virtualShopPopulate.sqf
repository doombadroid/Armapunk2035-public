params[["_shopType", "", [""]]];
if (_shopType isEqualTo "") exitWith {};
private _plb_display = findDisplay 39500;
if (isNull _plb_display) exitWith {};
private _topTitle = _plb_display displayCtrl 39501;
private _subTitle = _plb_display displayCtrl 39502;
private _mainListGroup = _plb_display displayCtrl 39503;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListEdit = _mainListGroup controlsGroupCtrl 1004;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _mainItemListBuyButton = _mainListGroup controlsGroupCtrl 1005;
private _mainItemListSellButton = _mainListGroup controlsGroupCtrl 1006;
private _shopInfo = [_shopType] call AP_fnc_virt_shops;
_shopInfo params[["_shopTitle", ""], ["_buyItems", []], ["_sellItems", []]];
_subTitle ctrlSetText(format["Player Weight: %2/%3", _shopTitle, AP_carryWeight, AP_maxWeight]);
_mainItemList ctrlSetFade 1.00;
_mainItemList ctrlCommit 0.00;
lbClear _mainItemList; {_x ctrlEnable false}
forEach[_mainItemListBuyButton, _mainItemListSellButton];
{_x params[["_item", ""]];
    if !(_item isEqualTo "") then {private _name = ["getName", _item] call AP_fnc_virtItemCfg;
        private _picture = ["getIcon", _item] call AP_fnc_virtItemCfg;
        private _qtyInInventory = missionNameSpace getVariable[format["AP_inv_%1", _item], 0];
        private _color = [1, 1, 1, 0.3];
        // owner 2026-08-12: the chain moved to AP_fnc_virtShopPrice so the web shop
        // reads the same number instead of becoming a third hand-synced copy.
        private _price = [_shopType, _item] call AP_fnc_virtShopPrice;
        // NEW DRACHMA: Kabuki ("tech") prices show in ND (6000:1 of the cash catalogue value).
        private _formatText = if (_shopType isEqualTo "tech") then {
            format["%1 ND", [[round _price] call AP_fnc_ndFromLegacy] call AP_fnc_ndText]} else {
            format["$%1", [round _price] call AP_fnc_numberText]};
        private _invText = format["%1", _qtyInInventory];
        private _rowIndex = _mainItemList lnbAddRow[_name, _formatText, _invText];
        _mainItemList lnbSetPicture[[_rowIndex, 0], _picture];
        _mainItemList lnbSetData[[_rowIndex, 0], _item];
        // owner 2026-07-20: hover hint explaining what the item does (AP_itemDesc; falls back to the item name).
        private _hint = if (isNil "AP_itemDesc") then { _name } else { AP_itemDesc getOrDefault [_item, _name] };
        { _mainItemList lnbSetTooltip [[_rowIndex, _x], _hint]; } forEach [0, 1, 2];
        _mainItemList lnbSetValue[[_rowIndex, 1], round _price];
        _mainItemList lnbSetValue[[_rowIndex, 2], _qtyInInventory];
        
            if (_shopType isEqualTo "tech") then {
                // ND-only: gate the affordability colour on the exact ND balance.
                if ([[round _price] call AP_fnc_ndFromLegacy] call AP_fnc_ndAfford) then { _color set[3, 1] };} else {
                if (_shopType in ["rebel"]) then {if (AP_cash >= _price) then {_color set[3, 1]};};
                if (((AP_cash >= _price) || (AP_atmcash >= _price)) && !(_shopType in ["rebel"])) then {
                    _color set[3, 1]};};
            _mainItemList lnbSetColor[[_rowIndex, 0], _color];
            _mainItemList lnbSetColor[[_rowIndex, 1], [0.325, 0.890, 0.612, _color select 3]];   // price: mint
            _mainItemList lnbSetColor[[_rowIndex, 2], [0.780, 0.635, 0.306, _color select 3]];   // owned: gold
        ;};}
forEach _buyItems; {_x params[["_item", ""]];
    if (!(_item isEqualTo "") && !(_item in _buyItems)) then {private _name = ["getName", _item] call AP_fnc_virtItemCfg;
        private _picture = ["getIcon", _item] call AP_fnc_virtItemCfg;
        private _qtyInInventory = missionNameSpace getVariable[format["AP_inv_%1", _item], 0];
        private _color = [1, 1, 1, 0.3];
        if (_qtyInInventory isEqualTo 0) exitWith {};
        private _price =
        if ((_item in _buyItems) && (_item in _sellItems)) then {private _buyPrice = ["getBasePrice", _item] call AP_fnc_virtItemCfg;
            _buyPrice = _buyPrice * ([_shopType, true] call AP_fnc_getDiscount);
            private _sellPrice = ["getLowestPrice", _item] call AP_fnc_virtItemCfg;
            _sellPrice = _sellPrice * ([_shopType, false] call AP_fnc_getDiscount);
            selectMin[_sellPrice, _buyPrice];} else {private _sellPrice = ["getLowestPrice", _item] call AP_fnc_virtItemCfg;
            if (_item == "goldbar" && (AP_gang_data select 0) isEqualTo(zaros_flag getVariable["AP_turf_data", []] select 0)) then {
                _sellPrice = _sellPrice * 1.1} else {_sellPrice};
            _sellPrice * ([_shopType, false] call AP_fnc_getDiscount);};
        private _buffPercent = ["questBuffs", false, _item] call AP_fnc_getDiscount;
        private _addBuff =
        if (_buffPercent isEqualTo 0) then {0} else {(_price * _buffPercent)};
        _price = round((_price + _addBuff) * 1);
        // NEW DRACHMA: Kabuki ("tech") prices show in ND (6000:1 of the cash catalogue value).
        private _formatText = if (_shopType isEqualTo "tech") then {
            format["%1 ND", [[round _price] call AP_fnc_ndFromLegacy] call AP_fnc_ndText]} else {
            format["$%1", [round _price] call AP_fnc_numberText]};
        private _invText = format["%1", _qtyInInventory];
        private _rowIndex = _mainItemList lnbAddRow[_name, _formatText, _invText];
        _mainItemList lnbSetPicture[[_rowIndex, 0], _picture];
        _mainItemList lnbSetData[[_rowIndex, 0], _item];
        // owner 2026-07-20: hover hint explaining what the item does (AP_itemDesc; falls back to the item name).
        private _hint = if (isNil "AP_itemDesc") then { _name } else { AP_itemDesc getOrDefault [_item, _name] };
        { _mainItemList lnbSetTooltip [[_rowIndex, _x], _hint]; } forEach [0, 1, 2];
        _mainItemList lnbSetValue[[_rowIndex, 1], round _price];
        _mainItemList lnbSetValue[[_rowIndex, 2], _qtyInInventory];
        _mainItemList lnbSetColor[[_rowIndex, 0], [1, 1, 1, 1]];
        _mainItemList lnbSetColor[[_rowIndex, 1], [0.325, 0.890, 0.612, 1]];   // sell price: mint
        _mainItemList lnbSetColor[[_rowIndex, 2], [0.780, 0.635, 0.306, 1]];   // carried: gold
    };}
forEach _sellItems; {private _itemListGroup = _x;
    private _itemList = _itemListGroup controlsGroupCtrl 1000;
    private _headerButtons = (allControls(ctrlParent _itemListGroup)) select {
        ((ctrlClassName _x) isEqualTo "AP_RscListNBoxHeaderButton") && ((ctrlParentControlsGroup _x) isEqualTo _itemListGroup)}; {
        _x ctrlEnable((lbSize _itemList) >= 1)}
    forEach _headerButtons;}
forEach[_mainListGroup];
ctrlSetFocus _mainItemList;
[_mainItemList, 0, true, true] call AP_fnc_listNBoxSort;
_mainItemList ctrlSetFade 0.00;
_mainItemList ctrlCommit 0.00;