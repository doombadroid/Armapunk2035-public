#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {
    ["You can only attempt to manage your listings in the LoonyBin Exchange Storage every couple seconds!", "basic"] spawn AP_fnc_handleMessage;
};
params[["_selectedType", "", [""]], ["_control", controlNull]];
if (isNull _control) exitWith {};
if (_selectedType isEqualTo "") exitWith {};
if !(ctrlEnabled _control) exitWith {};
if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
    ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
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
private _itemPreview = _plb_display displayCtrl 876001;
private _mainFilterListSelect = lbCurSel _mainFilterList;
private _mainItemListSelect = lbCurSel _mainItemList;
if ((_control isEqualTo _retrieveButton) && (_mainItemListSelect isEqualTo - 1)) exitWith {
    ["You need to select your listing to retrieve it's items!", "basic"] spawn AP_fnc_handleMessage;};
if ((_control isEqualTo _relistButton) && (_mainItemListSelect isEqualTo - 1)) exitWith {
    ["You need to select a listing to re-list on the LoonyBin Exchange!", "basic"] spawn AP_fnc_handleMessage;};
private _listingInfo =
switch (_control) do {case _retrieveButton: {[_mainItemList lnbData[_mainItemListSelect, 0]]};
    case _relistButton: {[_mainItemList lnbData[_mainItemListSelect, 0]]};
    default {[]};}; switch (_selectedType) do {case "retrieveListing": {closeDialog 0;
            _listingInfo = parseSimpleArray(_listingInfo select 0);
            _listingInfo params["_storageID", "_purchaserUID", "_boughtFromUID", "_itemClassname", "_itemQuantity", "_sellingPrice", "_isVirtual", "_isPhysical", "_expiresTimeSeconds", "_boughtTimeSeconds"];
            AP_lagRandomID = round(random(800));
            private _listingItemData = [];
            switch (true) do {case (_isVirtual isEqualTo 1): {
                        _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                    };
                default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
            }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
            private _dialogQuestion = [format["Do you want to retrieve your %1, from your LoonyBin Exchange Storage?", _resourceDisplayName], format["LoonyBin Exchange Storage: %1", _resourceDisplayName], "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_dialogQuestion) exitWith {};
            switch (true) do {case (_isVirtual isEqualTo 1): {
                        private _totalWeightLeftToCarry = [_itemClassname, _itemQuantity, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
                        if (_totalWeightLeftToCarry <= 0) exitWith {
                            [format["You don't have enought space to retrieve %1 from your LoonyBin Exchange Storage!", _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
                        };
                        if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                            ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                        if !(_totalWeightLeftToCarry isEqualTo _itemQuantity) then {
                            if ([true, _itemClassname, _totalWeightLeftToCarry] call AP_fnc_handleInv) then {
                                private _updatedQuantity = (_itemQuantity - _totalWeightLeftToCarry);
                                [format["You have retrieved %1 from your LoonyBin Exchange Storage. There is %2 %3(s) left.", _totalWeightLeftToCarry, _updatedQuantity, _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
                                [
                                    [6, [1, getPlayerUID player, player, _storageID, [_itemClassname, _updatedQuantity]]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
                                [
                                    ["-EXCHANGESTORAGERETRIEVE-", player, (profileName), format["ID: %3, Retrieved item from Exchange Storage: Virtual Item: %1, Quantity Taken: %2", _resourceDisplayName, _totalWeightLeftToCarry, _storageID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                            };} else {if ([true, _itemClassname, _itemQuantity] call AP_fnc_handleInv) then {
                                [format["You have retrieved all %1 %2(s) from your LoonyBin Exchange Storage!", _itemQuantity, _resourceDisplayName], "basic"] spawn AP_fnc_handleMessage;
                                [
                                    [6, [1, getPlayerUID player, player, _storageID, [_itemClassname, 0]]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
                                [
                                    ["-EXCHANGESTORAGERETRIEVE-", player, (profileName), format["ID: %3, Retrieved item from Exchange Storage: Virtual Item: %1, Quantity Taken: %2", _resourceDisplayName, _itemQuantity, _storageID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                            };};};
                case (_isPhysical isEqualTo 1): {private "_vehicle";
                        if !(isNull objectParent player) then {_vehicle = objectParent player;} else {
                            private _nearVehicles = nearestObjects[player, ["Car", "Air", "Ship"], 35];
                            _vehicle = _nearVehicles param[_nearVehicles findIf {((_x getVariable["AP_vehOwners", [[]
                                ]] select 0) select 0) isEqualTo getPlayerUID player && alive _x}, objNull]};
                        if (isNil "_vehicle" || {isNull _vehicle}) exitWith {
                            ["There isn't a vehicle near the NPC to store physical items from your LoonyBin Exchange Storage!", "basic"] spawn AP_fnc_handleMessage
                        };
                        private _vehicleDisplayName = [configFile >> "CfgVehicles" >> (typeOf _vehicle)] call BIS_fnc_displayName;
                        _vehicle setVariable["AP_activeTrunk", player, true];
                        private _vehPhysicalInventory = +(([getItemCargo _vehicle] call AP_fnc_formatContainer) + ([getWeaponCargo _vehicle] call AP_fnc_formatContainer) + ([getMagazineCargo _vehicle] call AP_fnc_formatContainer) + ([getBackpackCargo _vehicle] call AP_fnc_formatContainer));
                        private _toExit = false;
                        ["asy_exchange_input"] call AP_fnc_createDialog;
                        ((findDisplay 781000) displayCtrl 781001) ctrlSetText(format["Enter the amount of %1 you want to retrieve", _resourceDisplayName]);
                        waitUntil {!(isNull(findDisplay 781000))};
                        waitUntil {(isNull(findDisplay 781000) || AP_exchangeInput)};
                        if !(AP_exchangeInput) exitWith {_vehicle setVariable["AP_activeTrunk", nil, true];};
                        AP_exchangeInput = false;
                        private _amountToTakeString = ctrlText 781002;
                        private _amountToTake = parseNumber _amountToTakeString;
                        private _updatedQuantity = (_itemQuantity - _amountToTake);
                        private _updatedQuantity = selectMax[0, _updatedQuantity];
                        if (_amountToTake isEqualTo - 1) exitWith {
                            [format["You've entered %1, which isn't a real number!", _amountToTakeString], "basic"] spawn AP_fnc_handleMessage;
                            closeDialog 0;
                            _vehicle setVariable["AP_activeTrunk", nil, true];};
                        if (_amountToTake > _itemQuantity) exitWith {
                            [format["You don't have that much to take out! You requested %1 while there was only %2!", _amountToTake, _itemQuantity], "basic"] spawn AP_fnc_handleMessage;
                            closeDialog 0;
                            _vehicle setVariable["AP_activeTrunk", nil, true];};
                        if (_amountToTake < 1) exitWith {
                            [format["You can't take less than what is currently available! You requested less than 1 while there was only %1!", _itemQuantity]] spawn AP_fnc_handleMessage;
                            closeDialog 0;
                            _vehicle setVariable["AP_activeTrunk", nil, true];};
                        if !(_vehicle canAdd[_itemClassname, _amountToTake]) exitWith {
                            [format["Your %1 can't hold %2 %3! Take some physical items out before trying to put more in!", _vehicleDisplayName, _itemQuantity, _resourceDisplayName]] spawn AP_fnc_handleMessage;
                            closeDialog 0;
                            _vehicle setVariable["AP_activeTrunk", nil, true];};
                        if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                            ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                        private _findIDX = _vehPhysicalInventory findIf {(_x param[0, ""]) isEqualTo _itemClassname};
                        if (_findIDX isNotEqualTo - 1) then {
                            _vehPhysicalInventory set[_findIDX, [_itemClassname, ((_vehPhysicalInventory param[_findIDX, []]) param[1, 0]) + _amountToTake]];
                        } else {_vehPhysicalInventory pushBack[_itemClassname, _amountToTake];};
                        clearMagazineCargoGlobal _vehicle;
                        clearBackpackCargoGlobal _vehicle;
                        clearItemCargoGlobal _vehicle;
                        clearWeaponCargoGlobal _vehicle; {if (isClass(configFile >> "CfgVehicles" >> _x select 0)) then {
                                private _config = configFile >> "CfgVehicles" >> _x select 0;
                                private _type = getText(_config >> "vehicleClass");
                                if (_type == "Backpacks") then {_vehicle addBackpackCargoGlobal _x;} else {_vehicle addItemCargoGlobal _x;
                                };} else {_vehicle addItemCargoGlobal _x;};}
                        forEach _vehPhysicalInventory;
                        [format["%1 %2(s) has been inserted into your %4's trunk. There is still %3 left in your LoonyBin Exchange Storage.", _amountToTake, _resourceDisplayName, _updatedQuantity, _vehicleDisplayName], "basic"] spawn AP_fnc_handleMessage;
                        [
                            [6, [1, getPlayerUID player, player, _storageID, [_itemClassname, _updatedQuantity]]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
                        [
                            ["-EXCHANGESTORAGERETRIEVE-", player, (profileName), format["ID: %1, Retrieved item from Exchange Storage: Physical Item: %2, Quantity Taken: %3", _storageID, _resourceDisplayName, 1]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                    };}; closeDialog 0;
            [true] call AP_fnc_saveGear;}; case "relistListing": {closeDialog 0;
                _listingInfo = parseSimpleArray(_listingInfo select 0);
                _listingInfo params["_storageID", "_purchaserUID", "_boughtFromUID", "_itemClassname", "_itemQuantity", "_sellingPrice", "_isVirtual", "_isPhysical", "_expiresTimeSeconds", "_boughtTimeSeconds"];
                if !(_purchaserUID isEqualTo(getPlayerUID player)) exitWith {};
                AP_lagRandomID = round(random(800));
                private _listingItemData = [];
                switch (true) do {case (_isVirtual isEqualTo 1): {
                            _listingItemData = [_itemClassname, (["getName", _itemClassname] call AP_fnc_virtItemCfg), (["getIcon", _itemClassname] call AP_fnc_virtItemCfg)];
                        };
                    default {_listingItemData = [_itemClassname] call AP_fnc_fetchCfgDetails};
                }; _listingItemData params["_resourceString", "_resourceDisplayName", "_resourceImage"];
                private _listingFee = ((_sellingPrice * _itemQuantity) * 0.05);
                private _dialogQuestion = [format["Do you want to re-list %1 %2 at a set price of 1 x $%4. With a listing fee of $%3, from your LoonyBin Exchange Storage?", _itemQuantity, _resourceDisplayName, [_listingFee] call AP_fnc_numberText, [_sellingPrice] call AP_fnc_numberText], format["LoonyBin Exchange Re-List: %1", _resourceDisplayName], "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_dialogQuestion) exitWith {};
                if ((serverCycleLength - (serverTime - serverStartTime)) <= 180) exitWith {
                    ["You cannot use the exchange just before a server restart!", "basic"] spawn AP_fnc_handleMessage;};
                private _randID = AP_lagRandomID;
                AP_didServerRespond = false;
                private _maxDelayTime = time + 5; [[player], "APS_fnc_lagCheck", 2] spawn AP_fnc_MP;
                waitUntil {time > _maxDelayTime || AP_didServerRespond};
                if (time > _maxDelayTime) exitWith {["Exchange failed, try again.", "basic"] spawn AP_fnc_handleMessage;};
                if !(_randID isEqualTo AP_lagRandomID) exitWith {
                    ["Please wait for the exchange...", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_atmcash < _listingFee) exitWith {
                    [format["You do not have $%1 in your bank account, To afford the listing fee for this item!", [_listingFee] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                };
                AP_atmcash = AP_atmcash - _listingFee;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                [1] call AP_fnc_ClupdatePartial; [
                    ["-EXCHANGESTORAGERELIST-", player, (profileName), format["ID: %5, Relisted an item from Exchange Storage: Item: %1, Quantity Inputed: %2, Set Price: $%3, Listing Fee: $%4", _resourceDisplayName, _itemQuantity, [_sellingPrice] call AP_fnc_numberText, [_listingFee] call AP_fnc_numberText, _storageID]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
                switch (true) do {case (_isVirtual isEqualTo 1): {[
                                [1, [1, player, getPlayerUID player, _itemClassname, _sellingPrice, _itemQuantity, _listingFee]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
                            [
                                [6, [1, getPlayerUID player, player, _storageID, [_itemClassname, 0]]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
                        };
                    case (_isPhysical isEqualTo 1): {[
                                [3, [1, player, getPlayerUID player, _itemClassname, _sellingPrice, _itemQuantity, _listingFee]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
                            [
                                [6, [1, getPlayerUID player, player, _storageID, [_itemClassname, 0]]], "APS_fnc_exchangeSystemSRV", 2] spawn AP_fnc_MP;
                        };};
                [ format ["You have re-listed %1 %2 back on the LoonyBin Exchange. For $%3 x 1 and also paid fee of $%4!", _itemQuantity, _resourceDisplayName, [_sellingPrice] call AP_fnc_numberText, [_listingFee] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
            };};