params[["_type", "", [""]]];
private _plb_display = findDisplay 123000;
private _talentListDisplayCtrl = _plb_display displayCtrl 123001;
private _talentInfoText = _plb_display displayCtrl 123002;
private _talentPointsText = _plb_display displayCtrl 123006;
private _talentButton = _plb_display displayCtrl 123004;
private _talentTreeTitle = _plb_display displayCtrl 123005;
private _talentID = parseNumber(lbData[123001, lbCurSel 123001]);
if (isNil "_talentID" || {_talentID isEqualTo - 1}) exitWith {_talentInfoText ctrlSetText "";}; (switch (_type) do {case "standard": {
            [AP_side_talents, ["getRowByID", _talentID] call AP_fnc_talentCfg]}; case "gang": {
                [AP_gang_talents, ["getRowByID", "gang", _talentID] call AP_fnc_prestigeCfg]};
        default {[]}}) params[["_playerTalentsUnlocked", [], [[]]], ["_requestedTalentRow", [], [[]]]];
_requestedTalentRow params["_talentID", "_requestSide", "_prerequisitTalentID", "_depth", "_title", "_description"];
if (_requestedTalentRow isEqualTo[]) exitWith {_talentInfoText ctrlSetText "Talent data not found.";};
private _label = format["<t font='puristaMedium' align='center' shadow='1' size='1'>%1</t><br/>", _title];
_talentButton ctrlShow true;
_talentButton ctrlEnable true;
_label =
if (_prerequisitTalentID > 0 && !(_talentID in _playerTalentsUnlocked)) then {
    format["%1<t size='0.7'align='center' >Requires %2.</t><br/>", _label, _title];} else {if (_talentID in _playerTalentsUnlocked) then {
        format["%1<t color='#00FF00' align='center' size='0.7'>You have learned this talent</t><br/>", _label];} else {
        if (_prerequisitTalentID > 0) then {if !(_prerequisitTalentID in _playerTalentsUnlocked) then {
                format["%1<t color='#FF0000' align='center' size='0.7' >You must learn %2 before you can learn this</t><br/>", _label, _title];
            } else {
                format["%1<t size='0.7' align='center' >You have not yet learned this talent, but you do meet its requirements</t><br/>", _label];
            };} else {format["%1<t size='0.7' align='center' >You have not yet learned this talent</t><br/>", _label];};};};
if (_prerequisitTalentID > 0 && !(_prerequisitTalentID in _playerTalentsUnlocked)) then {_talentButton ctrlEnable false;};
_label = format["%1%2", _label, format["<t size='0.8'align='center' >%1</t>", _description]];
_talentInfoText ctrlSetStructuredText parseText _label;
if !(_talentID in _playerTalentsUnlocked) then {_talentButton ctrlSetText "Learn"} else {_talentButton ctrlSetText "Unlearn"};