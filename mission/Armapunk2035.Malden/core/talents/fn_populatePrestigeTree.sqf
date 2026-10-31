params[["_specialityType", "", [""]]];
private _plb_display = findDisplay 123000;
private _specialityListDisplayCtrl = _plb_display displayCtrl 123001;
private _specialityInfoText = _plb_display displayCtrl 123002;
private _specialityPointsText = _plb_display displayCtrl 123006;
private _specialityButton = _plb_display displayCtrl 123004;
private _specialityTreeTitle = _plb_display displayCtrl 123005;
lbClear _specialityListDisplayCtrl;
private _requestedSpecialityRow =
switch (_specialityType) do {case "bh": {["getSpecialitys", "bh"] call AP_fnc_prestigeCfg}; case "cop": {
                ["getSpecialitys", "cop"] call AP_fnc_prestigeCfg};
        case "rebel": {["getSpecialitys", "rebel"] call AP_fnc_prestigeCfg};
        case "medic": {["getSpecialitys", "medic"] call AP_fnc_prestigeCfg};};
( switch (_specialityType) do {case "bh": {[AP_honor_talents, "Honor", AP_honor_exp]}; case "cop": {
                [AP_cop_talents, "Prestige", AP_prestige]};
        case "rebel": {[AP_infamy_talents, "Infamy", AP_infamy_exp]};
        case "medic": {[AP_medic_talents, "Infamy", AP_medic_exp]};
}) params["_playerSpecialitysUnlocked", "_specialityName", "_specialityValue"];
_specialityPointsText ctrlSetStructuredText parseText format["<t size='0.70' align='center'>Available %1: %2</t>", _specialityName, [_specialityValue] call AP_fnc_numberText]; {
    _x params["_specialityID", "_specialityTypeName", "_requiredTalent", "_treePath", "_title", "_price"];
    _dashes = "";
    for "_i"
    from 0 to(_treePath - 1) do {_dashes = "- " + _dashes;}; _color =
    if (_requiredTalent > 0 && !(_requiredTalent in _playerSpecialitysUnlocked)) then {[1, 0, 0, 0.9]} else {
        if !(_specialityID in _playerSpecialitysUnlocked) then {[1, 1, 1, 0.5]} else {[1, 1, 1, 1]};};
    _index = _specialityListDisplayCtrl lbAdd format["%1%2", _dashes, _title];
    _specialityListDisplayCtrl lbSetData[_index, str _specialityID];
    _specialityListDisplayCtrl lbSetColor[_index, _color];}
forEach _requestedSpecialityRow;