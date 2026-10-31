#include "..\..\macro.h"
if (scriptAvailable(8)) exitWith {
    ["You can only attempt to open the LoonyBin Exchange every 8 seconds!", "basic"] spawn AP_fnc_handleMessage;};
params["_target", "_caller", "_actionID"];
if (!alive player || AP_action_in_use) exitWith {};
if !(SRV_exchangeIsReady) exitWith {["The LoonyBin Exchange is still being initialized, wait a moment!", "basic"]};
if (AP_exchangePlayerOwnedListings isEqualTo[] || AP_exchangeAllListings isEqualTo[] || !(AP_exchangeRequested)) then {
    AP_exchangeRequested = false; [[5, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;
    waitUntil {uiSleep 0.1;
        AP_exchangeRequested};};
AP_exchangeRequested = false;
if (AP_exchangeStorageMaxListings isEqualTo[0, 0] || !(AP_exchangeStorageRequested)) then {AP_exchangeStorageRequested = false; [
        [6, [0, getPlayerUID player, player]], "APS_fnc_exchangeSystemSRV", 2] call AP_fnc_MP;   // owner 2026-06-23 (bug B): was [7,[1,...]] -> case 7 sets AP_exchangeRequested, but this block waits on AP_exchangeStorageRequested = fresh-session HANG. Mode 6 _fetchStorage sets the storage flag + caps the block needs.
    waitUntil {uiSleep 0.1;
        AP_exchangeStorageRequested};};
AP_exchangeStorageRequested = false;
// DECK ROUTE (UI overhaul 2026-08-26): browsing opens as the deck EXCHANGE app.
// The fetch dance above has already run, so the app's first data build is warm.
// Native dialog 875000 stays as the AP_deckApps=false fallback. The broker's
// CREATE LISTING action is untouched -- listing from a trunk stays native.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["Exchange"] call AP_fnc_deckOpenApp;
};
while {dialog}
do {closeDialog 0}; disableSerialization ;
["exchangeMenu"] call AP_fnc_createDialog;
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
_mainFilterList lbSetCurSel 0;
_leftFilterList lbSetCurSel 0;
_menuTitle ctrlSetText(format["LoonyBin Grand Exchange", profileName, (getPlayerUID player)]); {_x params["_title"];
    if !(_title in ["My Listings", "All Listings"]) then {private _index = _leftFilterList lbAdd _title;
        _leftFilterList lbSetData[_index, _title];} else {private _index = _mainFilterList lbAdd _title;
        _mainFilterList lbSetData[_index, _title];};}
forEach["Virtual Items", "Weapons", "Vehicles", "Ammo", "Attachments", "Headgear", "Glasses", "Vests", "Uniforms", "Backpacks", "My Listings", "All Listings"]; {
    _x lnbAddColumn 0.70}
forEach[_mainItemList, _leftItemList];
if ((lbSize _mainFilterList) <= 1) then {_mainFilterList ctrlShow false;
    private _mainFilterListPosition = ctrlPosition _mainFilterList;
    private _controls = ((allControls _plb_display) select {
        ((ctrlParentControlsGroup _x) isEqualTo _mainListGroup) && !((ctrlIDC _x) in [1000, 1002, 1003])});
    _mainListGroup ctrlSetPosition[_mainFilterListPosition select 0, _mainFilterListPosition select 1]; {
        _x ctrlSetPosition[(ctrlPosition _x) select 0, ((ctrlPosition _x) select 1) + (_mainFilterListPosition select 3) + 0.0055]}
    forEach _controls; {
        _x ctrlSetPosition[(ctrlPosition _x) select 0, (ctrlPosition _x) select 1, (ctrlPosition _x) select 2, ((ctrlPosition _x) select 3) + (_mainFilterListPosition select 3) + 0.0055]
    }
    forEach[_mainItemList, _mainItemListBackground]; {_x ctrlCommit 0}
    forEach(allControls _plb_display);};
if ((lbSize _leftFilterList) <= 1) then {_leftFilterList ctrlShow false;
    private _leftFilterListPosition = ctrlPosition _leftFilterList;
    private _controls = ((allControls _plb_display) select {
        ((ctrlParentControlsGroup _x) isEqualTo _leftListGroup) && !((ctrlIDC _x) in [1000, 1002, 1003])});
    _leftListGroup ctrlSetPosition[_leftFilterListPosition select 0, _leftFilterListPosition select 1]; {
        _x ctrlSetPosition[(ctrlPosition _x) select 0, ((ctrlPosition _x) select 1) + (_leftFilterListPosition select 3) + 0.0055]}
    forEach _controls; {
        _x ctrlSetPosition[(ctrlPosition _x) select 0, (ctrlPosition _x) select 1, (ctrlPosition _x) select 2, ((ctrlPosition _x) select 3) + (_leftFilterListPosition select 3) + 0.0055]
    }
    forEach[_leftItemList, _leftItemListBackground]; {_x ctrlCommit 0}
    forEach(allControls _plb_display);}; {_x params["_itemListGroup", "_itemListName"];
    private _headerInfo =
    if (_itemListName isEqualTo "Resources") then {[["Resource", false], ["Type", false]]} else {[["Listing Information", false],
            ["Price", true]]};
    private _idx = _forEachIndex;
    private _itemList = _itemListGroup controlsGroupCtrl 1000;
    private _itemListWidth = (ctrlPosition _itemList) select 2;
    private _columnPositions = lnbGetColumnsPosition _itemList; {private _currentColumnPosition = _x * _itemListWidth;
        (_headerInfo select _forEachIndex) params[["_headerText", ""], ["_sortByValue", false]];
        private _nextColumnPosition =
        if !(_forEachIndex isEqualTo((count _columnPositions) - 1)) then {_columnPositions select(_forEachIndex + 1)} else {1};
        _nextColumnPosition = _nextColumnPosition * _itemListWidth;
        private _control = _plb_display ctrlCreate["AP_RscListNBoxHeaderButton", 1002, _itemListGroup];
        _control ctrlSetPosition[_currentColumnPosition, 0, (_nextColumnPosition - _currentColumnPosition) + 0.0002, 0.05];
        _control ctrlSetStructuredText parseText format["<t size='0.8'>%1</t><t align='right' size='0.6'><img image='%2'/></t>", _headerText, "icons\arrows.paa"];
        _control ctrlCommit 0;
        _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 875000) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _itemListGroup], _forEachIndex, _sortByValue]];
        if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};}
    forEach _columnPositions;}
forEach[[_mainListGroup, "Listings"], [_leftListGroup, "Resources"]]; {_x ctrlEnable false;}
forEach[_purchaseListingButton, _checkAvailButton, _retractListingButton];
_mainFilterList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_exchangeMenuFilter;", "listingFilter"]];
_leftFilterList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_exchangeMenuFilter;", "resourcesFilter"]];
_mainItemList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_exchangeMenuSelection;", "selectedListing"]];
_leftItemList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_exchangeMenuSelection;", "selectedResource"]];
_retractListingButton ctrlAddEventHandler["ButtonClick", format["['%1', _this select 0] spawn AP_fnc_exchangeMenuManage;", "removeListing"]];
_purchaseListingButton ctrlAddEventHandler["ButtonClick", format["['%1', _this select 0] spawn AP_fnc_exchangeMenuManage;", "purchaseListing"]];
_checkAvailButton ctrlAddEventHandler["ButtonClick", format["['%1', _this select 0] spawn AP_fnc_exchangeMenuManage;", "checkListing"]];
_mainFilterList lbSetCurSel 2;
_leftFilterList lbSetCurSel 0;
private _allControls = allControls _plb_display;
if ((lbSize _mainFilterList) <= 1) then {_allControls = _allControls - [_mainFilterList]};
if ((lbSize _leftFilterList) <= 1) then {_allControls = _allControls - [_leftFilterList]}; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05}
forEach _allControls;
private _refreshTime = time + 180;
if (AP_exchangeAllListings isEqualTo[]) then {
    ["It appears there are no listings on the LoonyBin Exchange", "basic"] spawn AP_fnc_handleMessage;} else {
    [format["The top %1 cheapest listing(s) of each item type on the entire LoonyBin Exchange have been fetched. Check availability of other items to search for listings for that specific item.", count AP_exchangeAllListings], "basic"] spawn AP_fnc_handleMessage;
};
waitUntil {uiSleep 0.1;
    isNull _plb_display || time > _refreshTime};
AP_exchangeRequested = false;
AP_exchangePlayerOwnedListings = [];
AP_exchangeAllListings = [];
AP_exchangeStorageMaxListings = [0, 0];
if (time > _refreshTime) exitWith {["Refreshing the LoonyBin Exchange...", "basic"] spawn AP_fnc_handleMessage;
    [_this] spawn AP_fnc_exchangeMenu;};