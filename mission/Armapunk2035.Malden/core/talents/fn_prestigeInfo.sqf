params[["_side", "", [""]]];
private _plb_display = findDisplay 123000;
private _specialityListDisplayCtrl = _plb_display displayCtrl 123001;
private _specialityInfoText = _plb_display displayCtrl 123002;
private _specialityPointsText = _plb_display displayCtrl 123006;
private _specialityButton = _plb_display displayCtrl 123004;
private _specialityTreeTitle = _plb_display displayCtrl 123005;
private _specialityRequiredPointsTitle = _plb_display displayCtrl 123003;
private _specialityID = parseNumber(lbData[123001, lbCurSel 123001]);
if (isNil "_specialityID" || {_specialityID isEqualTo - 1}) exitWith {_specialityInfoText ctrlSetText "";}; (switch (_side) do {case "bh": {
            [AP_honor_talents, ["getRowByID", "bh", _specialityID] call AP_fnc_prestigeCfg, "Honor"]}; case "cop": {
                [AP_cop_talents, ["getRowByID", "cop", _specialityID] call AP_fnc_prestigeCfg, "Prestige"]};
        case "rebel": {[AP_infamy_talents, ["getRowByID", "rebel", _specialityID] call AP_fnc_prestigeCfg, "Infamy"]};
        case "medic": {[AP_medic_talents, ["getRowByID", "medic", _specialityID] call AP_fnc_prestigeCfg, "Prestige"]};
        default {[]};}) params[["_playerSpecialitysUnlocked", [], [[]]], ["_requestedSpecialityRow", [], [[]]
], ["_prestigeType", "", [""]]];
_requestedSpecialityRow params["_specialityID", "_requestSide", "_prerequisiteSpecialityID", "_depth", "_title", "_description", "_amount"];
if (_requestedSpecialityRow isEqualTo[]) exitWith {_specialityInfoText ctrlSetText "Data not found.";};
private _label = format["<t font='puristaMedium' shadow='1' align='center' size='1'>%1</t><br/>", _title];
_specialityButton ctrlShow true;
_specialityButton ctrlEnable true;
if (_side isEqualTo "cop" && _specialityID in _playerSpecialitysUnlocked) then {_specialityButton ctrlEnable false};
_label =
if (_prerequisiteSpecialityID > 0 && !(_specialityID in _playerSpecialitysUnlocked)) then {
    private _required = (["getRowByID", _side, _prerequisiteSpecialityID] call AP_fnc_prestigeCfg) select 4;
    format["%1<t shadow='1' align='center' size='0.7' >Requires %2.</t><br/>", _label, _required];} else {
    if (_specialityID in _playerSpecialitysUnlocked) then {
        format["%1<t color='#00FF00' size='0.7' align='center' >You have learned this speciality.</t><br/>", _label];} else {
        if (_prerequisiteSpecialityID > 0) then {if !(_prerequisiteSpecialityID in _playerSpecialitysUnlocked) then {
                format["%1<t color='#FF0000' align='center' size='0.7' >You must learn %2 before you can learn this</t><br/>", _label, _title];
            } else {
                format["%1<t size='0.7' align='center' >You have not yet learned this speciality, but you do meet its requirements</t><br/>", _label];
            };} else {format["%1<t size='0.7' align='center' >You have not yet learned this speciality</t><br/>", _label];};};};
if (_prerequisiteSpecialityID > 0 && !(_prerequisiteSpecialityID in _playerSpecialitysUnlocked)) then {_specialityButton ctrlEnable false;
};
if (_amount != 0 && !(_specialityID in _playerSpecialitysUnlocked)) then {
    _specialityRequiredPointsTitle ctrlSetStructuredText parseText format["<t size='0.70' align='center'>Required: %1</t>", [_amount] call AP_fnc_numberText];
} else {_specialityRequiredPointsTitle ctrlSetStructuredText parseText "<t size='0.70' align='center'>No requirements.</t>";};
_label = format["%1%2", _label, format["<t size='0.6'align='center' >%1</t>", _description]];
_specialityInfoText ctrlSetStructuredText parseText _label;
if !(_specialityID in _playerSpecialitysUnlocked) then {_specialityButton ctrlSetText "Learn"} else {
    _specialityButton ctrlSetText "Unlearn"};