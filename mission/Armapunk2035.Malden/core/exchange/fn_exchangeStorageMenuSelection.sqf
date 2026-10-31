params[["_selectedType", "", [""]], ["_controlData", [], [[]]]];
if (_selectedType isEqualTo "" || _controlData isEqualTo[]) exitWith {};
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 876000;
private _menuTitle = _plb_display displayCtrl 876002;
private _itemPreview = _plb_display displayCtrl 876001;
private _mainFilterList = _plb_display displayCtrl 876003;
private _mainListGroup = _plb_display displayCtrl 876005;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _rightListGroup = _plb_display displayCtrl 876007;
private _rightInfoList = _rightListGroup controlsGroupCtrl 1000;
private _retrieveButton = _mainListGroup controlsGroupCtrl 1001;
private _relistButton = _rightListGroup controlsGroupCtrl 1001;
private _mainFilterListSelect = lbCurSel _mainFilterList;
private _mainItemListSelect = lbCurSel _mainItemList;
_rightInfoList ctrlSetText "";
_itemPreview ctrlSetText "";
if ((_control isEqualTo _mainItemList) && (_selectedIndex isEqualTo - 1)) exitWith {{_x ctrlEnable false}
    forEach[_retrieveButton, _relistButton];}; {_x ctrlEnable false;}
forEach[_retrieveButton, _relistButton];
private _filterType = _mainFilterList lbData _mainFilterListSelect;
switch (_filterType) do {case "Failed/Retracted Listings": {private _listingData = parseSimpleArray(_control lnbData[_selectedIndex, 0]);
            _listingData params["_storageID", "_purchaserUID", "_boughtFromUID", "_itemClassname", "_itemQuantity", "_sellingPrice", "_isVirtual", "_isPhysical", "_expiresTimeSeconds", "_boughtTimeSeconds"];
            ([(_expiresTimeSeconds / 3600), ((_expiresTimeSeconds % 3600) / 60), (_expiresTimeSeconds % 60)]) params["_crHours", "_crMinutes", "_crSeconds"];
            _createdServerTimeString = format["%1 Hours and %2 Minutes", round _crHours, round _crMinutes, round _crSeconds];
            ([(_boughtTimeSeconds / 3600), ((_boughtTimeSeconds % 3600) / 60), (_boughtTimeSeconds % 60)]) params["_exHours", "_exMinutes", "_exSeconds"];
            _createdServerTimeStringExpires = format["%1 Hours and %2 Minutes", round _exHours, round _exMinutes, round _exSeconds];
            switch (true) do {case (_isVirtual isEqualTo 1): {_resourceDisplayName = ["getName", _itemClassname] call AP_fnc_virtItemCfg;
                        _resourceImage = ["getIcon", _itemClassname] call AP_fnc_virtItemCfg;
                        _isIllegalItem = ["getIllegalPrice", _itemString] call AP_fnc_virtItemCfg;
                        _isIllegalItem =
                        if (_isIllegalItem isEqualTo - 1) then {"Legal"} else {"Illegal"};
                        _structuredString1 = format["<t align='left' size='1.0'>Storage Type: Failed/Retracted Listing</t><br/><t align='left' size='1.0'>Item: %1 | Virtual Item</t><br/><t align='left' size='1.0'>Legality: %2</t>", _resourceDisplayName, _isIllegalItem];
                        _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit(s)</t><br/><t align='left' size='1.0'>Failed/Retracted: %2 ago</t><br/><t align='left' size='1.0'>Expires In: %3</t><br/>", _itemQuantity, _createdServerTimeString, _createdServerTimeStringExpires];
                        _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                        _itemPreview ctrlSetText _resourceImage;};
                case (_isPhysical isEqualTo 1): {
                        ([_itemClassname] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_physImage"];
                        _structuredString1 = format["<t align='left' size='1.0'>Storage Type: Failed/Retracted Listing</t><br/><t align='left' size='1.0'>Item: %1 | %2</t>", _resourceDisplayName, ([_itemClassname] call BIS_fnc_itemType select 1)];
                        _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit</t><br/><t align='left' size='1.0'>Failed/Retracted: %2 ago</t><br/><t align='left' size='1.0'>Expires In: %3</t><br/>", _itemQuantity, _createdServerTimeString, _createdServerTimeStringExpires];
                        _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                        _itemPreview ctrlSetText _physImage;};}; _itemPreview ctrlSetTextColor[1, 1, 1, 1];
            _retrieveButton ctrlEnable true;
            _relistButton ctrlEnable true;}; case "Purchased Listings": {
                private _listingData = parseSimpleArray(_control lnbData[_selectedIndex, 0]);
                _listingData params["_storageID", "_purchaserUID", "_boughtFromUID", "_itemClassname", "_itemQuantity", "_sellingPrice", "_isVirtual", "_isPhysical", "_expiresTimeSeconds", "_boughtTimeSeconds"];
                ([(_expiresTimeSeconds / 3600), ((_expiresTimeSeconds % 3600) / 60), (_expiresTimeSeconds % 60)]) params["_crHours", "_crMinutes", "_crSeconds"];
                _createdServerTimeString = format["%1 Hours and %2 Minutes", round _crHours, round _crMinutes, round _crSeconds];
                ([(_boughtTimeSeconds / 3600), ((_boughtTimeSeconds % 3600) / 60), (_boughtTimeSeconds % 60)]) params["_exHours", "_exMinutes", "_exSeconds"];
                _createdServerTimeStringExpires = format["%1 Hours and %2 Minutes", round _exHours, round _exMinutes, round _exSeconds];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _resourceDisplayName = ["getName", _itemClassname] call AP_fnc_virtItemCfg;
                            _resourceImage = ["getIcon", _itemClassname] call AP_fnc_virtItemCfg;
                            _isIllegalItem = ["getIllegalPrice", _itemString] call AP_fnc_virtItemCfg;
                            _isIllegalItem =
                            if (_isIllegalItem isEqualTo - 1) then {"Legal"} else {"Illegal"};
                            _structuredString1 = format["<t align='left' size='1.0'>Storage Type: Purchased Listing</t><br/><t align='left' size='1.0'>Item: %1 | Virtual Item</t><br/><t align='left' size='1.0'>Legality: %2</t>", _resourceDisplayName, _isIllegalItem];
                            _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit(s)</t><br/><t align='left' size='1.0'>Bought: %2 ago</t><br/><t align='left' size='1.0'>Expires In: %3</t><br/>", _itemQuantity, _createdServerTimeString, _createdServerTimeStringExpires];
                            _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                            _itemPreview ctrlSetText _resourceImage;};
                    case (_isPhysical isEqualTo 1): {
                            ([_itemClassname] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_physImage"];
                            _structuredString1 = format["<t align='left' size='1.0'>Storage Type: Purchased Listing</t><br/><t align='left' size='1.0'>Item: %1 | %2</t>", _resourceDisplayName, ([_itemClassname] call BIS_fnc_itemType select 1)];
                            _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit</t><br/><t align='left' size='1.0'>Bought: %2 ago</t><br/><t align='left' size='1.0'>Expires In: %3</t><br/>", _itemQuantity, _createdServerTimeString, _createdServerTimeStringExpires];
                            _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                            _itemPreview ctrlSetText _physImage;};}; _itemPreview ctrlSetTextColor[1, 1, 1, 1];
                _retrieveButton ctrlEnable true;
                _relistButton ctrlEnable false;};};