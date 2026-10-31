params[["_talentType", "", [""]]];
private _plb_display = findDisplay 123000;
private _talentListDisplayCtrl = _plb_display displayCtrl 123001;
private _talentInfoText = _plb_display displayCtrl 123002;
private _talentPointsText = _plb_display displayCtrl 123006;
private _talentButton = _plb_display displayCtrl 123004;
private _talentTreeTitle = _plb_display displayCtrl 123005;
lbClear _talentListDisplayCtrl;
private _playerTalentsUnlocked =
switch (_talentType) do {case "standard": {AP_side_talents}; case "gang": {AP_gang_talents};
        case "bh": {AP_honor_talents};
        case "cop": {AP_cop_talents};
        default {[]};}; private ["_max", "_availTalents", "_playerTalentsUnlocked", "_free"];
if (_talentType isEqualTo "standard") then {_max = AP_maxTalents;
    _availTalents = AP_currentTalents;
    _playerTalentsUnlocked = AP_side_talents;
    _free = _availTalents - count _playerTalentsUnlocked;} else {_max = 9;
    _availTalents = AP_currentGangTalents;
    _playerTalentsUnlocked = AP_gang_talents;
    _free = _availTalents - count _playerTalentsUnlocked;};
private _requestedTalentRow =
switch (_talentType) do {case "standard": {["getTalents"] call AP_fnc_talentCfg}; case "gang": {
                ["getSpecialitys", "gang"] call AP_fnc_prestigeCfg};
        case "cop": {["getTalents", "cop"] call AP_fnc_talentCfg};
}; _talentPointsText ctrlSetStructuredText parseText format["<t size='0.90' align='center'>Points: %1/%2 | Available: %3</t>", count _playerTalentsUnlocked, _max, _free];
private["_dashes", "_index", "_color"]; {_x params["_talentID", "_requestSide", "_prerequisitTalent", "_treePath", "_title"];
    _dashes = "";
    for "_i"
    from 0 to(_treePath - 1) do {_dashes = "- " + _dashes;}; _color =
    if (_prerequisitTalent > 0 && !(_prerequisitTalent in _playerTalentsUnlocked)) then {[1, 0, 0, 0.9]} else {
        if !(_talentID in _playerTalentsUnlocked) then {[1, 1, 1, 0.5]} else {[1, 1, 1, 1]};};
    _index = _talentListDisplayCtrl lbAdd format["%1%2", _dashes, _title];
    _talentListDisplayCtrl lbSetData[_index, str _talentID];
    _talentListDisplayCtrl lbSetColor[_index, _color];}
forEach _requestedTalentRow;