#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {
    ["You can only attempt to vote for a candidate every couple seconds!", "basic"] spawn AP_fnc_handleMessage;};
private _submitVote = {params[["_control", controlNull]];
    if (isNull _control) exitWith {};
    if !(ctrlEnabled _control) exitWith {};
    private _plb_display = findDisplay 351000;
    private _mainListGroup = _plb_display displayCtrl 351002;
    private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
    private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
    private _rightListGroup = _plb_display displayCtrl 351003;
    private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
    private _mainItemListSelect = lbCurSel _mainItemList;
    private _voteButton = _rightListGroup controlsGroupCtrl 1001;
    if ((_control isEqualTo _voteButton) && (_mainItemListSelect isEqualTo - 1)) exitWith {
        ["You need to select a candidate to vote for!", "basic"] spawn AP_fnc_handleMessage;};
    (parseSimpleArray(_mainItemList lnbData[_mainItemListSelect, 0])) params["_playerUID", "_playerName", "_policy", "_investment", "_votes"];
    private _action = [format["Would you like submit a vote for %1 for Governor of %2?", _playerName, worldName], format["%1 Office", worldName], "Yes", "No"] call BIS_fnc_GUIMessage;
    if (_action) then {
        [format["Your vote for %1, has been submitted to the Government of %2", _playerName, worldName]] spawn AP_fnc_handleMessage; [
            ["addCandidateVote", [player, getPlayerUID player, _playerUID]], "APS_fnc_govSystemSRV", 2] call AP_fnc_MP;
        AP_govClientData set[2, true];
        [21] call AP_fnc_ClupdatePartial;
        closeDialog 0;} else {
        [format["You have chosen not to vote for %1, select another candidate!", _playerName]] spawn AP_fnc_handleMessage;
        _voteButton ctrlEnable false;};};
private _selectCandidate = {params[["_controlData", [], [[]]]];
    if (_controlData isEqualTo[]) exitWith {};
    private _plb_display = findDisplay 351000;
    private _mainListGroup = _plb_display displayCtrl 351002;
    private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
    private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
    private _rightListGroup = _plb_display displayCtrl 351003;
    private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
    private _mainItemListSelect = lbCurSel _mainItemList;
    private _voteButton = _rightListGroup controlsGroupCtrl 1001;
    _controlData params["_control", "_selectedIndex"];
    if (_selectedIndex isEqualTo - 1) exitWith {};
    (parseSimpleArray(_control lnbData[_selectedIndex, 0])) params["_playerUID", "_playerName", "_policy", "_investment", "_votes"];
    _formatString = format["<t %5 %6>Candidate: %1</t><br/><t %5 %6>Votes: %2</t><br/><t %5 %6>Investment: $%3</t><br/><t %5 %6>Policy: %4</t>", _playerName, _votes, [_investment] call AP_fnc_numberText, _policy, "size=1.0", "align=left"];
    _rightItemList ctrlSetStructuredText parseText _formatString;
    if (AP_govClientData param[2, false]) exitWith {_voteButton ctrlEnable false;};
    _voteButton ctrlEnable true;};
params["_target", "_caller", "_actionID"];
while {dialog}
do {closeDialog 0}; if (AP_govCandidates isEqualTo[] || !(AP_govCandidatesRequested)) then {AP_govCandidatesRequested = false; [
        ["getCandidates", [player, AP_effSide]], "APS_fnc_govSystemSRV", 2] call AP_fnc_MP;
    waitUntil {uiSleep 0.1;
        AP_govCandidatesRequested};};
AP_govCandidatesRequested = false;
disableSerialization;
["govVote"] call AP_fnc_createDialog;
private _plb_display = findDisplay 351000;
private _mainListGroup = _plb_display displayCtrl 351002;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _rightListGroup = _plb_display displayCtrl 351003;
private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
private _voteButton = _rightListGroup controlsGroupCtrl 1001; {_x lnbAddColumn 0.70}
forEach[_mainItemList];
private _headerInfo = [["Candidate", false], ["Votes", true]]; {private _mainItemList = _x;
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
        _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 351000) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _mainItemList], _forEachIndex, _sortByValue]];
        if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};}
    forEach _columnPositions;}
forEach[_mainListGroup];
_voteButton ctrlEnable false;
_mainItemList ctrlAddEventHandler["LBSelChanged", format["[_this] call %1;", _selectCandidate]];
_voteButton ctrlAddEventHandler["ButtonClick", format["[_this select 0] spawn %1;", _submitVote]];
private _allControls = allControls _plb_display; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05}
forEach _allControls;
ctrlSetFocus _mainItemList;
lbClear _mainItemList; {_x params["_playerUID", "_playerName", "_policy", "_investment", "_votes"];
    private _color = [0, 0.2, 0, 1];
    private _formatText = format["%1", [_votes] call AP_fnc_numberText];
    private _rowIndex = _mainItemList lnbAddRow[format["%1", _playerName], _formatText];
    _mainItemList lnbSetData[[_rowIndex, 0], (str _x)];
    _mainItemList lnbSetValue[[_rowIndex, 0], _playerName];
    _mainItemList lnbSetValue[[_rowIndex, 1], round _votes];}
forEach AP_govCandidates;
waitUntil {(isNull _plb_display)};
AP_govCandidates = [];