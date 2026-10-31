params[["_selectedType", "", [""]], ["_controlData", [], [[]]]];
if (_selectedType isEqualTo "" || _controlData isEqualTo[]) exitWith {};
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 875000;
private _menuTitle = _plb_display displayCtrl 875002;
private _mainFilterList = _plb_display displayCtrl 875003;
private _leftFilterList = _plb_display displayCtrl 875004;
private _mainListGroup = _plb_display displayCtrl 875005;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _leftListGroup = _plb_display displayCtrl 875006;
private _leftItemList = _leftListGroup controlsGroupCtrl 1000;
private _leftItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _rightListGroup = _plb_display displayCtrl 875007;
private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
private _retractListingButton = _mainListGroup controlsGroupCtrl 1001;
private _purchaseListingButton = _rightListGroup controlsGroupCtrl 1001;
private _checkAvailButton = _leftListGroup controlsGroupCtrl 1001;
private _filterType = _control lbData _selectedIndex; {_x ctrlSetFade 1.00;
    _x ctrlCommit 0.00;}
forEach[_mainItemList, _leftItemList]; {_x lbSetCurSel - 1}
forEach[_mainItemList]; {_x ctrlEnable false}
forEach[_retractListingButton, _purchaseListingButton, _checkAvailButton];
switch (true) do {case (_filterType == "Virtual Items"): {lbClear _leftItemList; {_x params["_itemType", "_itemString"];
                if !(_itemType isEqualTo "virtualItem") exitWith {};
                _resourceString = ["getName", _itemString] call AP_fnc_virtItemCfg;
                _resourceDisplayName = ["getShortName", _itemString] call AP_fnc_virtItemCfg;
                _resourceImage = ["getIcon", _itemString] call AP_fnc_virtItemCfg;
                _isIllegalItem = ["getIllegalPrice", _itemString] call AP_fnc_virtItemCfg;
                _isIllegalItem =
                if (_isIllegalItem isEqualTo - 1) then {"Legal"} else {"Illegal"};
                private _itemValue =
                switch (_isIllegalItem) do {case "Illegal": {1}; case "Legal": {0};
                        default {0};}; private _formatText = format["%1", _isIllegalItem];
                private _rowIndex = _leftItemList lnbAddRow[(_resourceString select[0, 31]), _formatText];
                _leftItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _leftItemList lnbSetValue[[_rowIndex, 0], _resourceString];
                _leftItemList lnbSetData[[_rowIndex, 0], _itemString];
                _leftItemList lnbSetValue[[_rowIndex, 1], _itemValue];}
            forEach([2, "virtualItem"] call AP_fnc_exchangeCfg);};
    case (_filterType == "Weapons"): {lbClear _leftItemList; {_x params["_itemType", "_itemString"];
                if (_itemString isEqualTo "") exitWith {};
                ([_itemString] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _formatText = format["%1", ([_resourceString] call BIS_fnc_itemType select 1)];
                private _rowIndex = _leftItemList lnbAddRow[(_resourceDisplayName select[0, 31]), _formatText];
                private _itemValue =
                switch ([_resourceString] call BIS_fnc_itemType select 1) do {case "Handgun": {6}; case "Shotgun": {5};
                        case "SubmachineGun": {4};
                        case "AssualtRifle": {3};
                        case "MachineGun": {2};
                        case "SniperRifle": {1};
                        default {0};}; _leftItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _leftItemList lnbSetValue[[_rowIndex, 0], _resourceString];
                _leftItemList lnbSetData[[_rowIndex, 0], _itemString];
                _leftItemList lnbSetValue[[_rowIndex, 1], _itemValue];}
            forEach([2, "Weapons"] call AP_fnc_exchangeCfg);};
    case (_filterType == "Vehicles"): {lbClear _leftItemList; {_x params["_itemType", "_itemString"];
                if (_itemString isEqualTo "") exitWith {};
                ([_itemString] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _formatText = format["%1", ([_resourceString] call BIS_fnc_objectType select 1)];
                private _rowIndex = _leftItemList lnbAddRow[(_resourceDisplayName select[0, 31]), _formatText];
                private _itemValue =
                switch ([_resourceString] call BIS_fnc_objectType select 1) do {case "Plane": {3}; case "Helicopter": {4};
                        case "Car": {5};
                        case "Ship": {2};
                        case "Submarine": {1};
                        default {1};}; _leftItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _leftItemList lnbSetValue[[_rowIndex, 0], _resourceString];
                _leftItemList lnbSetData[[_rowIndex, 0], _itemString];
                _leftItemList lnbSetValue[[_rowIndex, 1], _itemValue];}
            forEach([2, "vehicle"] call AP_fnc_exchangeCfg);};
    case (_filterType in ["Ammo", "Attachments", "Headgear", "Glasses", "Vests", "Uniforms", "Backpacks"]): {lbClear _leftItemList; {
                _x params["_itemType", "_itemString"];
                if (_itemString isEqualTo "") exitWith {};
                ([_itemString] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _formatText = format["%1", ([_resourceString] call BIS_fnc_itemType select 1)];
                private _rowIndex = _leftItemList lnbAddRow[(_resourceDisplayName select[0, 31]), _formatText];
                private _itemValue = 0;
                _leftItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _leftItemList lnbSetValue[[_rowIndex, 0], _resourceString];
                _leftItemList lnbSetData[[_rowIndex, 0], _itemString];
                _leftItemList lnbSetValue[[_rowIndex, 1], _itemValue];}
            forEach([2, _filterType] call AP_fnc_exchangeCfg);};
    case (_filterType == "All Listings"): {lbClear _mainItemList; {
                _x params["_exchangeID", "_playerUID", "_playerName", "_itemClassname", "_vehicleID", "_sellingPrice", "_itemQuantity", "_isVirtual", "_isPhysical", "_isVehicle", "_expiresTimeArray", "_boughtTimeArray"];
                if ((getPlayerUID player) isEqualTo _playerUID) exitWith {};
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _color = [0, 0.2, 0, 1];
                private _formatText = format["$%1 x 1", [_sellingPrice] call AP_fnc_numberText];
                private _rowIndex = _mainItemList lnbAddRow[format["%1 x %2", (_resourceDisplayName select[0, 31]), _itemQuantity], _formatText];
                _mainItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _mainItemList lnbSetValue[[_rowIndex, 0], _resourceDisplayName];
                _mainItemList lnbSetData[[_rowIndex, 0], (str _x)];
                _mainItemList lnbSetValue[[_rowIndex, 1], round _sellingPrice];}
            forEach AP_exchangeAllListings;};
    case (_filterType == "My Listings"): {lbClear _mainItemList; {
                _x params["_exchangeID", "_playerUID", "_playerName", "_itemClassname", "_vehicleID", "_sellingPrice", "_itemQuantity", "_isVirtual", "_isPhysical", "_isVehicle", "_expiresTimeArray", "_boughtTimeArray"];
                if !((getPlayerUID player) isEqualTo _playerUID) exitWith {};
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _color = [0, 0.2, 0, 1];
                private _formatText = format["$%1 x 1", [_sellingPrice] call AP_fnc_numberText];
                private _rowIndex = _mainItemList lnbAddRow[format["%1 x %2", (_resourceDisplayName select[0, 31]), _itemQuantity], _formatText];
                _mainItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _mainItemList lnbSetValue[[_rowIndex, 0], _resourceDisplayName];
                _mainItemList lnbSetData[[_rowIndex, 0], (str _x)];
                _mainItemList lnbSetValue[[_rowIndex, 1], round _sellingPrice];}
            forEach AP_exchangePlayerOwnedListings;};
    case (_filterType == AP_exchangeSelectedResource): {lbClear _mainItemList; {
                _x params["_exchangeID", "_playerUID", "_playerName", "_itemClassname", "_vehicleID", "_sellingPrice", "_itemQuantity", "_isVirtual", "_isPhysical", "_isVehicle", "_expiresTimeArray", "_boughtTimeArray"];
                if ((getPlayerUID player) isEqualTo _playerUID) exitWith {};
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _color = [0, 0.2, 0, 1];
                private _formatText = format["$%1 x 1", [_sellingPrice] call AP_fnc_numberText];
                private _rowIndex = _mainItemList lnbAddRow[format["%1 x %2", (_resourceDisplayName select[0, 31]), _itemQuantity], _formatText];
                _mainItemList lnbSetPicture[[_rowIndex, 0], _resourceImage];
                _mainItemList lnbSetValue[[_rowIndex, 0], _resourceDisplayName];
                _mainItemList lnbSetData[[_rowIndex, 0], (str _x)];
                _mainItemList lnbSetValue[[_rowIndex, 1], round _sellingPrice];}
            forEach AP_exchangeSpecificedListing;};}; { private _itemListGroupX = _x;
    private _itemListX = _itemListGroupX controlsGroupCtrl 1000;
    private _headerButtons = (allControls(ctrlParent _itemListGroupX)) select {
        ((ctrlClassName _x) isEqualTo "AP_RscListNBoxHeaderButton") && ((ctrlParentControlsGroup _x) isEqualTo _itemListGroupX)}; {
        _x ctrlEnable((lbSize _itemListX) >= 1)}
    forEach _headerButtons;}
forEach[_mainListGroup, _leftListGroup]; {private _itemListX = _x;
    ctrlSetFocus _itemListX;
    [_itemListX, 0, false, false] call AP_fnc_listNBoxSort;
    _itemListX ctrlSetFade 0.00;
    _itemListX ctrlCommit 0.00;}
forEach[_mainItemList, _leftItemList];