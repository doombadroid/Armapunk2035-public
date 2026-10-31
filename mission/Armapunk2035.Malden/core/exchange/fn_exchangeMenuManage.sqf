#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {
    ["You can only attempt to manage a listing every couple seconds in the LoonyBin Exchange!", "basic"] spawn AP_fnc_handleMessage;};
AP_exchangeStorageMaxListings params["_maxVirtualListing", "_maxPhysicalListing"];
params[["_selectedType", "", [""]], ["_control", controlNull]];
if (isNull _control) exitWith {};
if (_selectedType isEqualTo "") exitWith {};
if !(ctrlEnabled _control) exitWith {};
if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
    ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
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
private _mainFilterListSelect = lbCurSel _mainFilterList;
private _leftFilterListSelect = lbCurSel _leftFilterList;
private _leftItemListSelect = lbCurSel _leftItemList;
private _mainItemListSelect = lbCurSel _mainItemList;
if ((_control isEqualTo _retractListingButton) && (_mainItemListSelect isEqualTo - 1)) exitWith {
    ["You need to select your listing to retract it!", "basic"] spawn AP_fnc_handleMessage;};
if ((_control isEqualTo _purchaseListingButton) && (_mainItemListSelect isEqualTo - 1)) exitWith {
    ["You need to select a listing to buy!", "basic"] spawn AP_fnc_handleMessage;};
if ((_control isEqualTo _checkAvailButton) && (_leftItemListSelect isEqualTo - 1)) exitWith {
    ["You need to select a resource to search for one!", "basic"] spawn AP_fnc_handleMessage;};
private _listingInfo =
switch (_control) do {case _retractListingButton: {[_mainItemList lnbData[_mainItemListSelect, 0]]};
    case _purchaseListingButton: {[_mainItemList lnbData[_mainItemListSelect, 0]]};
    case _checkAvailButton: {[_leftItemList lnbData[_leftItemListSelect, 0]]};
    default {[]};}; switch (_selectedType) do {case "checkListing": {_listingInfo params["_resourceSearchTerm"];
            private _filterType = _leftFilterList lbData _leftFilterListSelect;
            private _listingItemData = [];
            switch (_filterType) do {case "Virtual Items": {
                        _listingItemData = [_resourceSearchTerm, (["getName", _resourceSearchTerm] call AP_fnc_virtItemCfg), (["getIcon", _resourceSearchTerm] call AP_fnc_virtItemCfg)];
                    }; default {_listingItemData = [_resourceSearchTerm] call AP_fnc_fetchCfgDetails};
            }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
            private _dialogQuestion = [format["Would you like to search for selected item: %1 on the LoonyBin Exchange?", _resourceDisplayName], format["LoonyBin Exchange Search: %1", _resourceDisplayName], "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_dialogQuestion) exitWith {};
            [format["Searching for %1 on the LoonyBin Exchange...", _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
            if (AP_exchangeSpecificedListing isEqualTo[] || !(AP_exchangeRequested)) then {AP_exchangeRequested = false; [
                    [5, [1, getPlayerUID player, player, _resourceSearchTerm]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
                waitUntil {uiSleep 0.1;
                    AP_exchangeRequested};};
            AP_exchangeRequested = false;
            AP_exchangeSelectedResource = "";
            _mainFilterList lbDelete 2;
            private _titleText = format["Searched: %1", _resourceDisplayName];
            private _index = _mainFilterList lbAdd _titleText;
            _mainFilterList lbSetData[_index, _titleText];
            AP_exchangeSelectedResource = _titleText;
            lbClear _mainItemList;
            _mainFilterList lbSetCurSel 2;
            if (AP_exchangeSpecificedListing isEqualTo[]) then {
                [format["It appears there are no listings for %1 on the LoonyBin Exchange", _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
            } else {
                [format["The %1 cheapest listing(s) on the entire LoonyBin Exchange for %2 have been fetched.", count AP_exchangeSpecificedListing, _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
            };}; case "purchaseListing": {_listingInfo = parseSimpleArray(_listingInfo select 0);
                _listingInfo params["_exchangeID", "_playerUID", "_playerName", "_itemClassname", "_vehicleID", "_sellingPrice", "_itemQuantity", "_isVirtual", "_isPhysical", "_isVehicle", "_expiresTimeArray", "_boughtTimeArray"];
                if (_isVirtual isEqualTo 1 && _maxVirtualListing >= 5) exitWith {
                    [format["You can only have 5 listings of virtual items in your Exchange Storage, clear out your Exchange Storage to retrieve more. You currently have %1 virtual item listings in storage.", _maxVirtualListing], "basic"] spawn AP_fnc_handleMessage;
                };
                if (_isPhysical isEqualTo 1 && _maxPhysicalListing >= 5) exitWith {
                    [format["You can only have 5 listings of physical items in your Exchange Storage, clear out your Exchange Storage to retrieve more. You currently have %1 physical item listings in storage.", _maxPhysicalListing], "basic"] spawn AP_fnc_handleMessage;
                };
                if (_playerUID isEqualTo(getPlayerUID player)) exitWith {};
                AP_lagRandomID = round(random(800));
                if (_isVehicle isEqualTo 1) then {AP_garageCount = -1; [
                        [getPlayerUID player, AP_effSide, player], "APS_fnc_garageCount", 2] spawn AP_fnc_MP;};
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                if (_isPhysical isEqualTo 1) exitWith {
                    private _dialogQuestion = [format["Would you like to purchase %1 which has a stock of %3 and sells for $%2 x 1?", _resourceDisplayName, [_sellingPrice] call AP_fnc_numberText, _itemQuantity], "LoonyBin Exchange Purchase Listing", "Yes", "No"] call BIS_fnc_guiMessage;
                    if !(_dialogQuestion) exitWith {};
                    ["Enter the amount you want to purchase!", "basic"] spawn AP_fnc_handleMessage;
                    ["asy_exchange_input"] call AP_fnc_createDialog;
                    ((findDisplay 781000) displayCtrl 781001) ctrlSetText(format["Enter the amount of %1 you want to purchase", _resourceDisplayName]);
                    waitUntil {!(isNull(findDisplay 781000))};
                    waitUntil {(isNull(findDisplay 781000) || AP_exchangeInput)};
                    if !(AP_exchangeInput) exitWith {["You chose not to purchase the selected listing!"] spawn AP_fnc_handleMessage};
                    AP_exchangeInput = false;
                    private _inputedWantedAmountString = ctrlText 781002;
                    private _inputedWantedAmount = parseNumber _inputedWantedAmountString;
                    if (_inputedWantedAmount isEqualTo - 1) exitWith {
                        [format["You've entered %1, which isn't a real number!", _inputedWantedAmountString], "basic"] spawn AP_fnc_handleMessage;
                        closeDialog 0;};
                    if (_inputedWantedAmount > _itemQuantity) exitWith {
                        [format["You can't purchase more than what is currently available! You requested %1 while the stock was only %2!", _inputedWantedAmount, _itemQuantity]] spawn AP_fnc_handleMessage;
                        closeDialog 0;};
                    if (_inputedWantedAmount < 1) exitWith {
                        [format["You can't purchase less than what is currently available! You requested less than 1 while the stock was only %1!", _itemQuantity]] spawn AP_fnc_handleMessage;
                        closeDialog 0;};
                    private _totalCashAmount = (_inputedWantedAmount * _sellingPrice);
                    if (AP_atmcash < _totalCashAmount) exitWith {
                        [format["You do not have $%1 in your bank account, To afford a listing of %2(s)!", [_listingFee] call AP_fnc_numberText, _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
                    };
                    if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                        ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                    private _randID = AP_lagRandomID;
                    AP_didServerRespond = false;
                    private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
                    waitUntil {time > _maxDelayTime || AP_didServerRespond};
                    if (time > _maxDelayTime) exitWith {["Exchange failed, try again.", "basic"] spawn AP_fnc_handleMessage;};
                    if !(_randID isEqualTo AP_lagRandomID) exitWith {
                        ["Please wait for the exchange...", "basic"] spawn AP_fnc_handleMessage;};
                    AP_atmcash = AP_atmcash - _totalCashAmount;
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                    [1] call AP_fnc_ClupdatePartial;
                    [format["Purchase request sent for listing: %1 with a requested amount of %2 for a total price of $%3...", _resourceDisplayName, round _inputedWantedAmount, [_totalCashAmount] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                    [
                        ["-EXCHANGEPURCHASE-", player, (profileName), format["ID: %7, Purchased a physical item listing from seller: (%1)(%2), Item: %3, Quantity Bought: %4, Quantity Left: %5, Total Purchase Price: $%6", _playerUID, _playerName, _resourceDisplayName, round _inputedWantedAmount, round(_itemQuantity - _inputedWantedAmount), [_totalCashAmount] call AP_fnc_numberText, _exchangeID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                    [
                        [3, [2, _exchangeID, player, _itemClassname, _sellingPrice, round _inputedWantedAmount]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
                    closeDialog 0;};
                if (_isVirtual isEqualTo 1) exitWith {
                    private _dialogQuestion = [format["Would you like to purchase %1 which has a stock of %3 and sells for $%2 x 1?", _resourceDisplayName, [_sellingPrice] call AP_fnc_numberText, _itemQuantity], "LoonyBin Exchange Purchase Listing", "Yes", "No"] call BIS_fnc_guiMessage;
                    if !(_dialogQuestion) exitWith {};
                    ["Enter the amount you want to purchase!", "basic"] spawn AP_fnc_handleMessage;
                    ["asy_exchange_input"] call AP_fnc_createDialog;
                    ((findDisplay 781000) displayCtrl 781001) ctrlSetText(format["Enter the amount of %1 you want to purchase", _resourceDisplayName]);
                    waitUntil {!(isNull(findDisplay 781000))};
                    waitUntil {(isNull(findDisplay 781000) || AP_exchangeInput)};
                    if !(AP_exchangeInput) exitWith {["You chose not to purchase the selected listing!"] spawn AP_fnc_handleMessage};
                    AP_exchangeInput = false;
                    private _inputedWantedAmountString = ctrlText 781002;
                    private _inputedWantedAmount = parseNumber _inputedWantedAmountString;
                    if (_inputedWantedAmount isEqualTo - 1) exitWith {
                        [format["You've entered %1, which isn't a real number!", _inputedWantedAmountString], "basic"] spawn AP_fnc_handleMessage;
                        closeDialog 0;};
                    if (_inputedWantedAmount > _itemQuantity) exitWith {
                        [format["You can't purchase more than what is currently available! You requested %1 while the stock was only %2!", _inputedWantedAmount, _itemQuantity]] spawn AP_fnc_handleMessage;
                        closeDialog 0;};
                    if (_inputedWantedAmount < 1) exitWith {
                        [format["You can't purchase less than what is currently available! You requested less than 1 while the stock was only %1!", _itemQuantity]] spawn AP_fnc_handleMessage;
                        closeDialog 0;};
                    private _totalCashAmount = (_inputedWantedAmount * _sellingPrice);
                    if (AP_atmcash < _totalCashAmount) exitWith {
                        [format["You do not have $%1 in your bank account, To afford a listing of %2(s)!", [_listingFee] call AP_fnc_numberText, _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
                    };
                    if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                        ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                    private _randID = AP_lagRandomID;
                    AP_didServerRespond = false;
                    private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
                    waitUntil {time > _maxDelayTime || AP_didServerRespond};
                    if (time > _maxDelayTime) exitWith {["Exchange failed, try again.", "basic"] spawn AP_fnc_handleMessage;};
                    if !(_randID isEqualTo AP_lagRandomID) exitWith {
                        ["Please wait for the exchange...", "basic"] spawn AP_fnc_handleMessage;};
                    AP_atmcash = AP_atmcash - _totalCashAmount;
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                    [1] call AP_fnc_ClupdatePartial;
                    [format["Purchase request sent for listing: %1 with a requested amount of %2 for a total price of $%3...", _resourceDisplayName, round _inputedWantedAmount, [_totalCashAmount] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                    [
                        ["-EXCHANGEPURCHASE-", player, (profileName), format["ID: %7, Purchased a virtual item listing from seller: (%1)(%2), Item: %3, Quantity Bought: %4, Quantity Left: %5, Total Purchase Price: $%6", _playerUID, _playerName, _resourceDisplayName, round _inputedWantedAmount, round(_itemQuantity - _inputedWantedAmount), [_totalCashAmount] call AP_fnc_numberText, _exchangeID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                    [
                        [1, [2, _exchangeID, player, _itemClassname, _sellingPrice, round _inputedWantedAmount]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
                    closeDialog 0;};
                private _dialogQuestion = [format["Would you like to purchase %1 for $%2?", _resourceDisplayName, [_sellingPrice] call AP_fnc_numberText], "LoonyBin Exchange Purchase Listing", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_dialogQuestion) exitWith {};
                if ((_isVehicle isEqualTo 1) && {AP_garageCount >= call AP_maxGarageVeh}) exitWith {
                    [format["You have %1 out of %2 max vehicles allowed in your garage, You must sell/destroy in order to purchase a vehicle on the LoonyBin Exchange!", AP_garageCount, (call AP_maxGarageVeh)], "basic"] spawn AP_fnc_handleMessage;
                };
                private _totalCashAmount = (1 * _sellingPrice);
                if (AP_atmcash < _totalCashAmount) exitWith {
                    [format["You do not have $%1 in your bank account, To afford the listing of a %2!", [_totalCashAmount] call AP_fnc_numberText, _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
                };
                if (_isVehicle isEqualTo 1) then {private _action = false;
                    private _dlcInfo = getAssetDLCInfo[_itemClassname, configFile >> "CfgVehicles"];
                    if (_dlcInfo select 0 && !(_dlcInfo select 1)) then {
                        _action = [format["<t align='center'>You need the %1 DLC in order to use this vehicle. Purchase anyway?</t>", _dlcInfo select 5], "DLC Vehicle Confirmation", "Yes", "No"] call BIS_fnc_guiMessage;
                    } else {_action = true;};
                    if !(_action) exitWith {};};
                if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                    ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                private _randID = AP_lagRandomID;
                AP_didServerRespond = false;
                private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
                waitUntil {time > _maxDelayTime || AP_didServerRespond};
                if (time > _maxDelayTime) exitWith {["Exchange failed, try again.", "basic"] spawn AP_fnc_handleMessage;};
                if !(_randID isEqualTo AP_lagRandomID) exitWith {
                    ["Please wait for the exchange...", "basic"] spawn AP_fnc_handleMessage;};
                AP_atmcash = AP_atmcash - _totalCashAmount;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                [1] call AP_fnc_ClupdatePartial;
                [format["Purchase request sent for listing: %1 with a requested amount of %2 for a total price of $%3...", _resourceDisplayName, 1, [_totalCashAmount] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                [
                    ["-EXCHANGEPURCHASE-", player, (profileName), format["ID: %6, Purchased a listing from seller: (%1)(%2), Item: %3, Quantity Bought: %4, Total Purchase Price: $%5", _playerUID, _playerName, _resourceDisplayName, 1, [_totalCashAmount] call AP_fnc_numberText, _exchangeID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                closeDialog 0;
                uiSleep 0.5;
                if (_isVehicle isEqualTo 1) exitWith {[
                        [2, [2, _exchangeID, player, _itemClassname, _sellingPrice]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;};};
        case "removeListing": {_listingInfo = parseSimpleArray(_listingInfo select 0);
                _listingInfo params["_exchangeID", "_playerUID", "_playerName", "_itemClassname", "_vehicleID", "_sellingPrice", "_itemQuantity", "_isVirtual", "_isPhysical", "_isVehicle", "_expiresTimeArray", "_boughtTimeArray"];
                if (_isVirtual isEqualTo 1 && _maxVirtualListing >= 5) exitWith {
                    [format["You can only have 5 listings of virtual items in your Exchange Storage, clear out your Exchange Storage to retrieve more. You currently have %1 virtual item listings in storage.", _maxVirtualListing], "basic"] spawn AP_fnc_handleMessage;
                };
                if (_isPhysical isEqualTo 1 && _maxPhysicalListing >= 5) exitWith {
                    [format["You can only have 5 listings of physical items in your Exchange Storage, clear out your Exchange Storage to retrieve more. You currently have %1 physical item listings in storage.", _maxPhysicalListing], "basic"] spawn AP_fnc_handleMessage;
                };
                if !(_playerUID isEqualTo(getPlayerUID player)) exitWith {};
                AP_lagRandomID = round(random(800));
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _dialogQuestion = [format["Would you like to retract the selected listing for %1 and recieve it back in your LoonyBin Exchange Storage?", _resourceDisplayName], "LoonyBin Exchange Retract Listing", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_dialogQuestion) exitWith {["You chose not to retract the selected listing!"] spawn AP_fnc_handleMessage;};
                if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                    ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                private _randID = AP_lagRandomID;
                AP_didServerRespond = false;
                private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
                waitUntil {time > _maxDelayTime || AP_didServerRespond};
                if (time > _maxDelayTime) exitWith {["Exchange failed, try again.", "basic"] spawn AP_fnc_handleMessage;};
                if !(_randID isEqualTo AP_lagRandomID) exitWith {
                    ["Please wait for the exchange...", "basic"] spawn AP_fnc_handleMessage;};
                [format["Retracting request sent for your listing of %1..", _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage; [
                    [4, [_exchangeID, player, getPlayerUID player, _itemClassname]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP; [
                    ["-EXCHANGERETRACT-", player, (profileName), format["ID: %4, Retracted a listing: Item: %1, Quantity: %2, Set Price: $%3", _resourceDisplayName, _itemQuantity, [_sellingPrice] call AP_fnc_numberText, _exchangeID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                closeDialog 0;};};