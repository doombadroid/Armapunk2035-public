params[["_selectedType", "", [""]], ["_controlData", [], [[]]]];
if (_selectedType isEqualTo "" || _controlData isEqualTo[]) exitWith {};
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 875000;
private _menuTitle = _plb_display displayCtrl 875002;
private _itemPreview = _plb_display displayCtrl 875001;
private _mainFilterList = _plb_display displayCtrl 875003;
private _leftFilterList = _plb_display displayCtrl 875004;
private _mainListGroup = _plb_display displayCtrl 875005;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _leftListGroup = _plb_display displayCtrl 875006;
private _leftItemList = _leftListGroup controlsGroupCtrl 1000;
private _leftItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _rightListGroup = _plb_display displayCtrl 875007;
private _rightInfoList = _rightListGroup controlsGroupCtrl 1000;
private _retractListingButton = _mainListGroup controlsGroupCtrl 1001;
private _purchaseListingButton = _rightListGroup controlsGroupCtrl 1001;
private _checkAvailButton = _leftListGroup controlsGroupCtrl 1001;
private _mainFilterListSelect = lbCurSel _mainFilterList;
private _leftFilterListSelect = lbCurSel _leftFilterList;
private _leftItemListSelect = lbCurSel _leftItemList;
private _mainItemListSelect = lbCurSel _mainItemList;
_rightInfoList ctrlSetText "";
_itemPreview ctrlSetText "";
if ((_control isEqualTo _leftItemList) && !(_selectedIndex isEqualTo - 1)) then {_purchaseListingButton ctrlEnable false};
if ((_control isEqualTo _mainItemList) && (_selectedIndex isEqualTo - 1)) exitWith {_purchaseListingButton ctrlEnable false}; {
    _x ctrlEnable false;}
forEach[_retractListingButton, _purchaseListingButton, _checkAvailButton];
switch (_selectedType) do {case "selectedListing": {private _listingData = parseSimpleArray(_control lnbData[_selectedIndex, 0]);
            _listingData params["_exchangeID", "_playerUID", "_playerName", "_itemClassname", "_vehicleID", "_sellingPrice", "_itemQuantity", "_isVirtual", "_isPhysical", "_isVehicle", "_expiresTimeArray", "_boughtTimeArray"];
            // owner 2026-06-23 (bug A -- the 29x/7d crash): the server packs these as [days,hours] ARRAYS (field 11
            // _expiresTimeArray = time-LEFT via _hoursLeft; field 12 _boughtTimeArray = created-AGO via _elapsed) --
            // NOT a seconds scalar. The old code divided the ARRAY by 3600 -> "/: Type Array, expected Number" on
            // every listing click, killing the detail panel + the buy/retract buttons. Use them directly, no division.
            _boughtTimeArray params[["_crDays", 0], ["_crHours", 0]];     // created-ago [days, hours]
            _expiresTimeArray params[["_exDays", 0], ["_exHours", 0]];    // time-left  [days, hours]
            _createdServerTimeString = format["%1 day(s) %2 hour(s)", _crDays, _crHours];
            _createdServerTimeStringExpires = format["%1 day(s) %2 hour(s)", _exDays, _exHours];
            switch (true) do {case (_isVirtual isEqualTo 1): {_resourceDisplayName = ["getName", _itemClassname] call AP_fnc_virtItemCfg;
                        _resourceImage = ["getIcon", _itemClassname] call AP_fnc_virtItemCfg;
                        _isIllegalItem = ["getIllegalPrice", _itemString] call AP_fnc_virtItemCfg;
                        _isIllegalItem =
                        if (_isIllegalItem isEqualTo - 1) then {"Legal"} else {"Illegal"};
                        _structuredString1 = format["<t align='left' size='1.0'>Listing Owner: %1</t><br/><t align='left' size='1.0'>Virtual Item: %3</t><br/><t align='left' size='1.0'>Legality: %4", _playerName, _playerUID, _resourceDisplayName, _isIllegalItem];
                        _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit(s)</t><br/><t align='left' size='1.0'>Listed Price: $%2 x 1 Per Unit</t><br/><t align='left' size='1.0'>Created: %3 ago</t><br/><t align='left' size='1.0'>Expires In: %4</t><br/>", _itemQuantity, [_sellingPrice] call AP_fnc_numberText, _createdServerTimeString, _createdServerTimeStringExpires];
                        _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                        _itemPreview ctrlSetText _resourceImage;};
                case (_isVehicle isEqualTo 1): {
                        ([_itemClassname] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_vehicleImage"];
                        _structuredString1 = format["<t align='left' size='1.0'>Listing Owner: %1</t><br/><t align='left' size='1.0'>Vehicle: %3 | %4 </t><br/><t align='left' size='1.0'>License Plate: %5</t>", _playerName, _playerUID, _resourceDisplayName, ([_itemClassname] call BIS_fnc_objectType select 1), _vehicleID];
                        _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit</t><br/><t align='left' size='1.0'>Listed Price: $%2 x 1 Per Unit</t><br/><t align='left' size='1.0'>Created: %3 ago</t><br/><t align='left' size='1.0'>Expires In: %4</t><br/>", _itemQuantity, [_sellingPrice] call AP_fnc_numberText, _createdServerTimeString, _createdServerTimeStringExpires];
                        _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                        _itemPreview ctrlSetText _vehicleImage;};
                case (_isPhysical isEqualTo 1): {
                        ([_itemClassname] call AP_fnc_fetchCfgDetails) params["_resourceString", "_resourceDisplayName", "_vehicleImage"];
                        _structuredString1 = format["<t align='left' size='1.0'>Listing Owner: %1</t><br/><t align='left' size='1.0'>Item: %3 | %4</t>", _playerName, _playerUID, _resourceDisplayName, ([_itemClassname] call BIS_fnc_itemType select 1)];
                        _structuredString2 = format["<br/><t align='left' size='1.0' >Quantity: %1 Unit</t><br/><t align='left' size='1.0'>Listed Price: $%2 x 1 Per Unit</t><br/><t align='left' size='1.0'>Created: %3 ago</t><br/><t align='left' size='1.0'>Expires In: %4</t><br/>", _itemQuantity, [_sellingPrice] call AP_fnc_numberText, _createdServerTimeString, _createdServerTimeStringExpires];
                        _rightInfoList ctrlSetStructuredText parseText format["%1%2", _structuredString1, _structuredString2];
                        _itemPreview ctrlSetText _vehicleImage;};}; _itemPreview ctrlSetTextColor[1, 1, 1, 1];
            if (_mainFilterListSelect isEqualTo 0) then {_retractListingButton ctrlEnable true;} else {
                _purchaseListingButton ctrlEnable true;};}; case "selectedResource": {
                private _resourceString = _control lnbData[_selectedIndex, 0];
                private _filterType = _leftFilterList lbData _leftFilterListSelect;
                private _listingItemData = [];
                switch (_filterType) do {case "Virtual Items": {
                            _listingItemData = [_resourceString, (["getShortName", _resourceString] call AP_fnc_virtItemCfg), (["getIcon", _resourceString] call AP_fnc_virtItemCfg)];
                        }; default {_listingItemData = [_resourceString] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                _itemPreview ctrlSetText _resourceImage;
                _itemPreview ctrlSetTextColor[1, 1, 1, 1];
                if ((_filterType in ["Virtual Items", "Weapons", "Vehicles", "Ammo", "Attachments", "Headgear", "Glasses", "Vests", "Uniforms", "Backpacks"]) && !(_leftItemListSelect isEqualTo - 1)) then {
                    _checkAvailButton ctrlEnable true};};};