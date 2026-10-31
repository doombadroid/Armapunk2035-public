private _acceptedRequest = {params[["_control", controlNull, [controlNull]]];
    if (isNull _control) exitWith {};
    if !(ctrlEnabled _control) exitWith {};
    private _plb_display = findDisplay 352000;
    private _mainListGroup = _plb_display displayCtrl 352002;
    private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
    private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
    private _rightListGroup = _plb_display displayCtrl 352003;
    private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
    private _acceptButton = _rightListGroup controlsGroupCtrl 1001;
    private _mainItemListSelect = lbCurSel _mainItemList;
    if ((_control isEqualTo _acceptButton) && (_mainItemListSelect isEqualTo - 1)) exitWith {
        ["You need to select a patient to accept a request from!", "basic"] spawn AP_fnc_handleMessage;};
    private _arrayIDX = (parseNumber(_mainItemList lnbData[_mainItemListSelect, 0]));
    [_arrayIDX] spawn AP_fnc_acceptMedicalRequest;
    _acceptButton ctrlEnable false;
    closeDialog 0;};
private _selectPatient = {params[["_controlData", [], [[]]]];
    if (_controlData isEqualTo[]) exitWith {};
    private _plb_display = findDisplay 352000;
    private _mainListGroup = _plb_display displayCtrl 352002;
    private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
    private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
    private _rightListGroup = _plb_display displayCtrl 352003;
    private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
    private _acceptButton = _rightListGroup controlsGroupCtrl 1001;
    private _mainItemListSelect = lbCurSel _mainItemList;
    _controlData params["_control", "_selectedIndex"];
    if (_selectedIndex isEqualTo - 1) exitWith {};
    private _arrayIDX = (parseNumber(_mainItemList lnbData[_mainItemListSelect, 0]));
    (AP_medicRequestedCorpses param[_arrayIDX, [objNull, "", "", 0]]) params[["_xCaller", objNull, [objNull]], ["_xCorpse", objNull, [objNull]], ["_xCorpseUID", "", [""]], ["_xCorpseName", "", [""]], ["_xRequestedTime", 0, [0]]];
    if (isNull _xCorpse) exitWith {_mainItemList lnbDeleteRow _selectedIndex;
        _rightItemList ctrlSetStructuredText parseText "";
        ["There are no active medical requests at this time!"] spawn AP_fnc_handleMessage;};
    private _corpseDirection = call {private _heading = (player getDir _xCorpse);
        if (_heading >= 338) exitWith {"N"};
        if (_heading <= 23) exitWith {"N"};
        if (_heading <= 68) exitWith {"NE"};
        if (_heading <= 113) exitWith {"E"};
        if (_heading <= 158) exitWith {"SE"};
        if (_heading <= 203) exitWith {"S"};
        if (_heading <= 248) exitWith {"SW"};
        if (_heading <= 293) exitWith {"W"};
        if (_heading <= 338) exitWith {"NW"};"Unknown direction";};
    private _requestorGroup = (group _xCaller) getVariable["AP_grpTag", ""];
    private _requestorGroup =
    switch (true) do {case (side _xCaller isEqualTo west): {" [MaxSec]"};
        case (side _xCaller isEqualTo independent): {" [TT]"};
        case ((side _xCaller isEqualTo civilian) && (_requestorGroup isEqualTo "")): {""};
        default {format[" %1", _requestorGroup]};}; private _responderName =
    if ((_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]] param[1, ""]) isEqualTo "") then {
        "None"} else {(_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]] param[1, ""])};
    private _distanceMeters = (_xCorpse distance2D player);
    private _isReviveable =
    if (_xCorpse getVariable["AP_revivable", false]) then {"Yes"} else {"No"};
    private _isDefibCooldownActive =
    if (time < (_xCorpse getVariable["AP_next_revive", -1000]) && !(call AP_medicLevel >= 5 || (call AP_copLevel >= 6 && AP_copRole in ["all", "medic"] && 22 in AP_cop_talents))) then {
        "Active"} else {"Inactive"};
    private _currentReviver =
    if ((_xCorpse getVariable["AP_reviving", objNull]) isEqualTo objNull) then {
        "None"} else {name(_xCorpse getVariable["AP_reviving", objNull])};
    private _nearestLocation = text(nearestLocations[_xCorpse, ["NameCityCapital", "NameCity", "NameVillage"], 5000] select 0);
    private _side =
    if (AP_effSide isEqualTo independent) then {independent} else {west};
    private _rank = [_side, (_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]] param[0, objNull])] call AP_fnc_getRankString;
    _formatString = format["<t %5 %6>Patient: %1</t><br/><t %5 %6>Nearest Location: %7</t><br/><t %5 %6>Distance: %2 meters %8</t><br/><t %5 %6>Responder: %4</t><br/><t %5 %6>Reviver: %9</t><br/><t %5 %6>Revivable: %3</t><br/><t %5 %6>Cooldown: %10</t><br/><t %5 %6>Requested: %11 mins ago</t>", format["%1%2", _xCorpseName, _requestorGroup], [_distanceMeters] call AP_fnc_numberText, _isReviveable, format["%1%2", _rank, _responderName], "size=1.0", "align=left", _nearestLocation, _corpseDirection, _currentReviver, _isDefibCooldownActive, ((time - _xRequestedTime) / 60)];
    _rightItemList ctrlSetStructuredText parseText _formatString;
    if ((_currentReviver isEqualTo "None") && (isNull(AP_medicAcceptedCorpse param[1, objNull])) && (_isReviveable isEqualTo "Yes")) then {
        _acceptButton ctrlEnable true;};
    if ((_responderName isNotEqualTo "None") && (_responderName isNotEqualTo profileName)) then {_acceptButton ctrlEnable false;};};
while {dialog}
do {closeDialog 0}; disableSerialization ;
["medicRespond"] call AP_fnc_createDialog;
private _plb_display = findDisplay 352000;
private _mainListGroup = _plb_display displayCtrl 352002;
private _mainItemList = _mainListGroup controlsGroupCtrl 1000;
private _mainItemListBackground = _mainListGroup controlsGroupCtrl 1003;
private _rightListGroup = _plb_display displayCtrl 352003;
private _rightItemList = _rightListGroup controlsGroupCtrl 1000;
private _acceptButton = _rightListGroup controlsGroupCtrl 1001; {_x lnbAddColumn 0.70}
forEach[_mainItemList];
private _headerInfo = [["Patient", false], ["Distance", true]]; {private _mainItemList = _x;
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
        _control ctrlAddEventHandler["ButtonClick", format["[%1, %2, %3, false, _this select 0] call AP_fnc_listNBoxSort;", format["((findDisplay 352000) displayCtrl %1) controlsGroupCtrl 1000", ctrlIDC _mainItemList], _forEachIndex, _sortByValue]];
        if (_forEachIndex isEqualTo 0) then {[_itemList, _forEachIndex, _sortByValue, false, _control] call AP_fnc_listNBoxSort};}
    forEach _columnPositions;}
forEach[_mainListGroup];
_acceptButton ctrlEnable false;
_mainItemList ctrlAddEventHandler["LBSelChanged", format["[_this] call %1;", _selectPatient]];
_acceptButton ctrlAddEventHandler["ButtonClick", format["[_this select 0] spawn %1;", _acceptedRequest]];
private _allControls = allControls _plb_display; {waitUntil {ctrlCommitted _x};
    _x ctrlSetFade 0;
    _x ctrlCommit 0.05}
forEach _allControls;
lbClear _mainItemList; {
    _x params[["_xCaller", objNull, [objNull]], ["_xCorpse", objNull, [objNull]], ["_xCorpseUID", "", [""]], ["_xCorpseName", "", [""]], ["_xRequestedTime", 0, [0]]];
    if ((isNull _xCorpse) || (_xRequestedTime < time - 360)) then {AP_medicRequestedCorpses = AP_medicRequestedCorpses - [_x];};}
forEach AP_medicRequestedCorpses; {
    _x params[["_xCaller", objNull, [objNull]], ["_xCorpse", objNull, [objNull]], ["_xCorpseUID", "", [""]], ["_xCorpseName", "", [""]], ["_xRequestedTime", 0, [0]]];
    private _distanceMeters = (_xCorpse distance2D player);
    private _color =
    switch (true) do {case (_xCorpse isEqualTo(AP_medicAcceptedCorpse param[1, objNull])): {[0, 1, 0, 1]};
        case ((((_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]]) param[1, ""]) isNotEqualTo "") && (((_xCorpse getVariable["AP_requestAcceptor", [objNull, ""]]) param[0, objNull]) isNotEqualTo player)):
            {[1, 0, 0, 1]};
        default {[1, 1, 1, 1]};}; private _requestorGroup = (group _xCaller) getVariable["AP_grpTag", ""];
    private _requestorGroup =
    switch (true) do {case (side _xCaller isEqualTo west): {" [MaxSec]"};
        case (side _xCaller isEqualTo independent): {" [TT]"};
        case ((side _xCaller isEqualTo civilian) && (_requestorGroup isEqualTo "")): {""};
        default {format[" %1", _requestorGroup]};
    }; private _formatText = format["%1 meters", [round _distanceMeters] call AP_fnc_numberText];
    private _rowIndex = _mainItemList lnbAddRow[format["%1%2", _xCorpseName, _requestorGroup], _formatText];
    if (_xCorpse isEqualTo(AP_medicAcceptedCorpse param[1, objNull])) then {
        profileNameSpace setVariable["AP_respondingIndex", _rowIndex];};
    _mainItemList lnbSetData[[_rowIndex, 0], (str _forEachIndex)];
    _mainItemList lnbSetValue[[_rowIndex, 0], _xCorpseName];
    _mainItemList lnbSetValue[[_rowIndex, 1], round _distanceMeters];
    _mainItemList lnbSetColor[[_rowIndex, 0], _color];
    _mainItemList lnbSetColor[[_rowIndex, 1], _color];}
forEach AP_medicRequestedCorpses;
[_mainItemList, 1, true, false] call AP_fnc_listNBoxSort;
private _savedIndex = profileNameSpace getVariable["AP_respondingIndex", -1];
if ((_savedIndex isNotEqualTo - 1) && ((lbSize _mainItemList) >= 1)) then {_mainItemList lbSetCurSel _savedIndex;} else {
    _mainItemList lbSetCurSel - 1;};
if ((lbSize _mainItemList) isEqualTo 0) then {["There are no active medical requests at this time!"] spawn AP_fnc_handleMessage};
waitUntil {(isNull _plb_display)};
