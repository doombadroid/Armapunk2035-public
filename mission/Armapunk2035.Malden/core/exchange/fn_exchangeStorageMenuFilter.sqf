params[["_selectedType", "", [""]], ["_controlData", [], [[]]]];
if (_selectedType isEqualTo "" || _controlData isEqualTo[]) exitWith {};
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 876000;
private _menuTitle = _plb_display displayCtrl 876002;
private _mainFilterList = _plb_display displayCtrl 876003;
private _mainListGroup = _plb_display displayCtrl 876005;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _rightListGroup = _plb_display displayCtrl 876007;
private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
private _retrieveButton = _mainListGroup controlsGroupCtrl 1001;
private _relistButton = _rightListGroup controlsGroupCtrl 1001;
private _filterType = _control lbData _selectedIndex; {_x ctrlSetFade 1.00;
    _x ctrlCommit 0.00;}
forEach[_mainItemList]; {_x lbSetCurSel - 1}
forEach[_mainItemList]; {_x ctrlEnable false}
forEach[_retrieveButton, _relistButton];
switch (_filterType) do {case "Purchased Listings": {lbClear _mainItemList; {
                _x params["_storageID", "_purchaserUID", "_boughtFromUID", "_itemClassname", "_itemQuantity", "_sellingPrice", "_isVirtual", "_isPhysical", "_expiresTimeSeconds", "_boughtTimeSeconds"];
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _formatText =
                switch (true) do {case (_isVirtual isEqualTo 1): {"Virtual Item"};
                    case (_isPhysical isEqualTo 1): {"Physical Item"};}; private _itemValue =
                switch (_formatText) do {case "Virtual Item": {1}; case "Weapon": {2};
                        case "Physical Item": {3};
                        default {0};}; private _color = [0, 0.2, 0, 1];
                private _rowIndex = _mainItemList lnbAddRow[format["%1 x %2", _resourceDisplayName, _itemQuantity], _formatText];
                _mainItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _mainItemList lnbSetValue[[_rowIndex, 1], _itemValue];
                _mainItemList lnbSetData[[_rowIndex, 0], (str _x)];}
            forEach AP_exchangeStorage;}; case "Failed/Retracted Listings": {lbClear _mainItemList; {
                    _x params["_storageID", "_purchaserUID", "_boughtFromUID", "_itemClassname", "_itemQuantity", "_sellingPrice", "_isVirtual", "_isPhysical", "_expiresTimeSeconds", "_boughtTimeSeconds"];
                    private _listingItemData = [];
                    switch (true) do {case (_isVirtual isEqualTo 1): {
                                _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                            };
                        default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                    }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                    private _formatText =
                    switch (true) do {case (_isVirtual isEqualTo 1): {"Virtual Item"};
                        case (_isPhysical isEqualTo 1): {"Physical Item"};}; private _itemValue =
                    switch (_formatText) do {case "Virtual Item": {1}; case "Weapon": {2};
                            case "Physical Item": {3};
                            default {0};}; private _color = [0, 0.2, 0, 1];
                    private _rowIndex = _mainItemList lnbAddRow[format["%1 x %2", _resourceDisplayName, _itemQuantity], _formatText];
                    _mainItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                    _mainItemList lnbSetValue[[_rowIndex, 1], _itemValue];
                    _mainItemList lnbSetData[[_rowIndex, 0], (str _x)];}
                forEach AP_exchangeFailedListings;};}; { private _itemListGroupX = _x;
    private _itemListX = _itemListGroupX controlsGroupCtrl 1000;
    private _headerButtons = (allControls(ctrlParent _itemListGroupX)) select {
        ((ctrlClassName _x) isEqualTo "AP_RscListNBoxHeaderButton") && ((ctrlParentControlsGroup _x) isEqualTo _itemListGroupX)}; {
        _x ctrlEnable((lbSize _itemListX) >= 1)}
    forEach _headerButtons;}
forEach[_mainListGroup]; {private _itemListX = _x;
    ctrlSetFocus _itemListX;
    [_itemListX, 0, false, false] call AP_fnc_listNBoxSort;
    _itemListX ctrlSetFade 0.00;
    _itemListX ctrlCommit 0.00;}
forEach[_mainItemList];