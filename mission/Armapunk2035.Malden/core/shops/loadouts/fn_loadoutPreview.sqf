params[["_controlData", [], [[]]]];
_controlData params["_control", "_selectedIndex"];
private _plb_display = findDisplay 39400;
if (isNull _plb_display) exitWith {};
private _itemPreview = _plb_display displayCtrl 39403;
private _class = _control lnbData[_selectedIndex, 0];
if (_class isEqualTo "") exitWith {_itemPreview ctrlSetText ""};
private _picture =
if (_class in ([2] call AP_fnc_virtItemCfg)) then {["getIcon", _class] call AP_fnc_virtItemCfg} else {
    (([_class] call AP_fnc_fetchCfgDetails) param[2, ""])};
_itemPreview ctrlSetText _picture;