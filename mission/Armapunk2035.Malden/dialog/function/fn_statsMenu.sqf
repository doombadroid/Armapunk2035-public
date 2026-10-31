#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {["You can only attempt to open your stats every couple seconds!", "basic"] spawn AP_fnc_handleMessage;
};
params["_target", "_caller", "_actionID"];
if (!alive player) exitWith {};
while {dialog}
do {closeDialog 0}; disableSerialization ;
["myloonybinstats"] call AP_fnc_createDialog;
private _plb_display = findDisplay 877000;
private _menuTitle = _plb_display displayCtrl 877002;
private _mainFilterList = _plb_display displayCtrl 877003;
private _mainListGroup = _plb_display displayCtrl 877005;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
_mainFilterList lbSetCurSel 0;
_menuTitle ctrlSetText(format["%1's MyLoonyBin Stats", profileName]);
private _activeLists = ["MyLoonyBin Statistics", "Other Statistics"]; {_activeLists pushBack _x}
forEach["Monthly Gang Wins", "Monthly Gang Money Won", "Top 35 - Kills", "Top 35 - K/Ds", "Top New Drachma"]; {_x params["_title"];
    private _index = _mainFilterList lbAdd _title;
    _mainFilterList lbSetData[_index, _title];}
forEach _activeLists; {_x lnbAddColumn 0.70}
forEach[_mainItemList];
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
private _headerInfo = [["Stat", false], ["Quantity", true]]; {private _mainItemList = _x;
    private _itemList = _x controlsGroupCtrl 1000;
    private _itemListWidth = (ctrlPosition _itemList) select 2;
    private _columnPositions = lnbGetColumnsPosition _itemList; {private _currentColumnPosition = _x * _itemListWidth;
        (_headerInfo select _forEachIndex) params[["_headerText", ""], ["_sortByValue", false]];
        private _nextColumnPosition =
        if !(_forEachIndex isEqualTo((count _columnPositions) - 1)) then {_columnPositions select(_forEachIndex + 1)} else {1};
        _nextColumnPosition = _nextColumnPosition * _itemListWidth;
        private _control = _plb_display ctrlCreate["AP_RscListNBoxHeaderButton", 1002, _mainItemList];
        _control ctrlSetPosition[_currentColumnPosition, 0, (_nextColumnPosition - _currentColumnPosition) + 0.0002, 0.05];
        _control ctrlSetStructuredText parseText format["<t size='0.8'>%1</t><t align='right' size='0.6'><img image='%2'/></t>", _headerText, "icons\arrows.paa"];
        _control ctrlCommit 0;
        _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 877000) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _mainItemList], _forEachIndex, _sortByValue]];
        if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};}
    forEach _columnPositions;}
forEach[_mainListGroup];
_mainFilterList ctrlAddEventHandler["LBSelChanged", format["['%1', _this] call AP_fnc_statsFilter;", "listingFilter"]];
_mainFilterList lbSetCurSel 0;
private _allControls = allControls _plb_display;
if ((lbSize _mainFilterList) <= 1) then {_allControls = _allControls - [_mainFilterList]}; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05}
forEach _allControls;
waitUntil {(isNull _plb_display)};