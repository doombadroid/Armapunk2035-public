params[["_list", controlNull], ["_columnIndex", 0], ["_sortByValue", false], ["_isReversed", false], ["_button", controlNull], ["_triggerSelect", true]];
if (isNull _list) exitWith {};
if ((lbSize _list) > 1) then {if (_sortByValue) then {_list lnbSortByValue[_columnIndex, _isReversed]} else {
        _list lnbSort[_columnIndex, _isReversed]};
    if (_triggerSelect) then {_list lbSetCurSel(lbCurSel _list)};};
if (isNull _button) exitWith {};
private _listString =
switch (true) do {case (!isNull(ctrlParentControlsGroup _list)): {
            format["(((findDisplay %1) displayCtrl %2) controlsGroupCtrl %3)", ctrlIDD(ctrlParent _list), ctrlIDC(ctrlParentControlsGroup _list), ctrlIDC _list]
        };
    default {format["((findDisplay %1) displayCtrl %2)", ctrlIDD(ctrlParent _list), ctrlIDC _list]};
}; _button ctrlSetEventHandler["ButtonClick", format["[%1, %2, %3, %4, _this select 0] call AP_fnc_listNBoxSort;", _listString, _columnIndex, _sortByValue, !(_isReversed)]];