params["_target", "_caller", "_actionID", "_type"];
if !(alive player) exitWith {};
if (AP_action_in_use) exitWith {};
if (AP_loadoutHolder isEqualTo[] || !(AP_loadoutRequested)) then {AP_loadoutRequested = false; [
        [player, AP_effSide, 1], "APS_fnc_fetchLoadouts", 2] call AP_fnc_MP;
    waitUntil {uiSleep 0.1;
        AP_loadoutRequested};};
// DECK ROUTE (UI overhaul 2026-08-26): the rack opens as a deck app. The fetch
// above already ran, so AP_loadoutHolder is warm.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    AP_deckLoadoutType = _type;
    ["Loadouts"] call AP_fnc_deckOpenApp;
};
["AP_loadout_system"] call AP_fnc_createDialog;
private _plb_display = findDisplay 39400;
if (isNull _plb_display) exitWith {};
private _filterList = _plb_display displayCtrl 39402;
private _mainListGroup = _plb_display displayCtrl 39404;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _sideListGroup = _plb_display displayCtrl 39405;
private _sideItemList = _sideListGroup controlsGroupCtrl 1000;
private _sideItemListButton = _sideListGroup controlsGroupCtrl 1001;
private _deleteButton = _sideListGroup controlsGroupCtrl 1005;
private _saveButton = _sideListGroup controlsGroupCtrl 1004;
private _dollarsButton = _sideListGroup controlsGroupCtrl 1006;
private _ndButton = _sideListGroup controlsGroupCtrl 1007; {_x lnbAddColumn 0.70}
forEach[_mainItemList, _sideItemList]; {private _headerInfo =
    if (_forEachIndex isEqualTo 0) then {[["Name", false], ["Quantity", false]]} else {[["Name", false], ["Price", true]]};
    private _idx = _forEachIndex;
    private _itemListGroup = _x;
    private _itemList = _x controlsGroupCtrl 1000;
    private _itemListWidth = (ctrlPosition _itemList) select 2;
    private _columnPositions = lnbGetColumnsPosition _itemList; {private _currentColumnPosition = _x * _itemListWidth;
        (_headerInfo select _forEachIndex) params[["_headerText", ""], ["_sortByValue", false]];
        private _nextColumnPosition =
        if !(_forEachIndex isEqualTo((count _columnPositions) - 1)) then {_columnPositions select(_forEachIndex + 1)} else {1};
        _nextColumnPosition = _nextColumnPosition * _itemListWidth;
        private _control = _plb_display ctrlCreate["AP_RscListNBoxHeaderButton", 1002, _itemListGroup];
        _control ctrlSetPosition[_currentColumnPosition, 0, (_nextColumnPosition - _currentColumnPosition) + 0.0002, 0.05];
        private _arrows =
        if (_idx isEqualTo 0) then {"<img image='icons\arrows.paa'/></t>"} else {""};
        _control ctrlSetStructuredText parseText format["<t size='0.8'>%1</t><t align='right' size='0.6'>%2", _headerText, _arrows];
        _control ctrlCommit 0;
        if (_idx isEqualTo 0) then {
            _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 39400) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _itemListGroup], _forEachIndex, _sortByValue]];
            if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};};}
    forEach _columnPositions;}
forEach[_mainListGroup, _sideListGroup]; {_x ctrlEnable false;}
forEach[_sideItemListButton, _deleteButton, _saveButton];
_sideItemList ctrlAddEventHandler["LBSelChanged", "[_this] call AP_fnc_loadoutSelection;"];
_mainItemList ctrlAddEventHandler["LBSelChanged", "[_this] call AP_fnc_loadoutPreview;"];
_saveButton ctrlAddEventHandler["ButtonClick", format["['%1', _this] spawn AP_fnc_saveLoadout;", _type]];
_deleteButton ctrlAddEventHandler["ButtonClick", format["['%1', _this] spawn AP_fnc_deleteLoadout;", _type]];
_dollarsButton ctrlAddEventHandler["ButtonClick", format["['%1', _this, '$'] spawn AP_fnc_equipLoadout", _type]];
_ndButton ctrlAddEventHandler["ButtonClick", format["['%1', _this, 'ND'] spawn AP_fnc_equipLoadout", _type]];
if (_type isEqualTo "rebel") then {
    _sideItemListButton ctrlAddEventHandler["ButtonClick", format["['%1', _this] spawn AP_fnc_chooseLoadoutCurrency", _type]];} else {
    _sideItemListButton ctrlAddEventHandler["ButtonClick", format["['%1', _this] spawn AP_fnc_equipLoadout", _type]];};
private _allControls = allControls _plb_display;
if ((lbSize _filterList) <= 1) then {_allControls = _allControls - [_filterList]}; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05;}
forEach _allControls;
ctrlSetFocus _mainItemList; {_x ctrlEnable false;
    _x ctrlShow false;}
forEach[_dollarsButton, _ndButton];
private _subscriber = true;   // LooneyBin: all players get every loadout slot (no LoonyBin+ gate on slots 3/4)
private _loadouts = AP_loadoutHolder;
if (AP_loadoutHolder isEqualTo[]) exitWith {closeDialog 0;
    ["An error has occured fetching your loadouts. Please try again later or contact a developer for assistance.", "basic"] spawn AP_fnc_handleMessage;
};
if ((count AP_loadoutHolder) < 8) then {private _toAdd = 8 - (count AP_loadoutHolder);
    for [{_x = 1}, {_x <= _toAdd}, {_x = _x + 1}] do {AP_loadoutHolder pushBack[];};}; {if (_forEachIndex in [3, 4] || {_x isEqualTo[]
    }) then {if (_forEachIndex in [3, 4] && !_subscriber) then {
            private _rowIndex = _sideItemList lnbAddRow["LoonyBin Plus Required", "LOCKED"];
            _sideItemList lnbSetValue[[_rowIndex, 0], -2];
            _sideItemList lnbSetValue[[_rowIndex, 1], _forEachIndex];
            for "_columnIndex"
            from 0 to 1 do {_sideItemList lnbSetColor[[_rowIndex, _columnIndex], [1, 1, 1, 0.5]]};} else {if (_x isEqualTo[]) then {
                private _rowIndex = _sideItemList lnbAddRow["Empty Slot", "$0"];
                _sideItemList lnbSetValue[[_rowIndex, 0], -4];
                _sideItemList lnbSetValue[[_rowIndex, 1], _forEachIndex];} else {
                _x params["", "_loadoutType", "_loadoutName", "_gearArray", "_virtualArray"];
                if (_type == _loadoutType) then {private _price = [_loadoutType, _gearArray, _virtualArray] call AP_fnc_getLoadoutPrice;
                    if (_price < 10 && _price > 0) then {_price = 10;};
                    _price = round(_price * 1.03);
                    if !(_price isEqualTo - 1) then {
                        private _rowIndex = _sideItemList lnbAddRow[_loadoutName, format["$%1", [_price] call AP_fnc_numberText]];
                        _sideItemList lnbSetValue[[_rowIndex, 0], _forEachIndex];
                        _sideItemList lnbSetValue[[_rowIndex, 1], _price];} else {
                        private _rowIndex = _sideItemList lnbAddRow[_loadoutName, "INVALID"];
                        _sideItemList lnbSetValue[[_rowIndex, 0], -5];
                        _sideItemList lnbSetValue[[_rowIndex, 1], _forEachIndex];
                        for "_columnIndex"
                        from 0 to 1 do {_sideItemList lnbSetColor[[_rowIndex, _columnIndex], [1, 1, 1, 0.5]]};};} else {
                    private _rowIndex = _sideItemList lnbAddRow["Unavilable at this location", "$0"];
                    _sideItemList lnbSetValue[[_rowIndex, 0], -3];
                    _sideItemList lnbSetValue[[_rowIndex, 1], _forEachIndex];
                    _sideItemList lnbSetData[[_rowIndex, 0], _loadoutName];
                    for "_columnIndex"
                    from 0 to 1 do {_sideItemList lnbSetColor[[_rowIndex, _columnIndex], [1, 1, 1, 0.5]]};};};};} else {
        _x params["", "_loadoutType", "_loadoutName", "_gearArray", "_virtualArray"];
        if (_type == _loadoutType) then {private _price = [_loadoutType, _gearArray, _virtualArray] call AP_fnc_getLoadoutPrice;
            if (_price < 10 && _price > 0) then {_price = 10;};
            _price = round(_price * 1.03);
            if !(_price isEqualTo - 1) then {
                private _rowIndex = _sideItemList lnbAddRow[_loadoutName, format["$%1", [_price] call AP_fnc_numberText]];
                _sideItemList lnbSetValue[[_rowIndex, 0], _forEachIndex];
                _sideItemList lnbSetValue[[_rowIndex, 1], _price];} else {
                private _rowIndex = _sideItemList lnbAddRow[_loadoutName, "INVALID"];
                _sideItemList lnbSetValue[[_rowIndex, 0], -5];
                _sideItemList lnbSetValue[[_rowIndex, 1], _forEachIndex];
                for "_columnIndex"
                from 0 to 1 do {_sideItemList lnbSetColor[[_rowIndex, _columnIndex], [1, 1, 1, 0.5]]};};} else {
            private _rowIndex = _sideItemList lnbAddRow["Unavilable at this location", "$0"];
            _sideItemList lnbSetValue[[_rowIndex, 0], -3];
            _sideItemList lnbSetValue[[_rowIndex, 1], _forEachIndex];
            _sideItemList lnbSetData[[_rowIndex, 0], _loadoutName];
            for "_columnIndex"
            from 0 to 1 do {_sideItemList lnbSetColor[[_rowIndex, _columnIndex], [1, 1, 1, 0.5]]};};};}
forEach _loadouts;

if ((AP_loadoutHolder findIf { _x isEqualTo [] }) isEqualTo -1) then {
    ["All loadout slots are full. Delete a loadout to save a new one.", "basic"] spawn AP_fnc_handleMessage;};
