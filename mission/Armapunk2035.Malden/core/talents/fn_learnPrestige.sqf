/*
    fn_learnPrestige.sqf -- learn or unlearn one speciality in the four XP trees
    (bh = Honor, cop = Prestige, rebel = Infamy, medic = TT Prestige).

    Re-plumbed 2026-08-11 so the web deck can drive it, same shape as
    fn_learnTalent: the id used to come only from the tree dialog's listbox.

        ["bh"] spawn AP_fnc_learnPrestige;             // dialog -- unchanged
        ["bh", 11, true] call AP_fnc_learnPrestige;    // deck -> returns bool

    UNLIKE TALENTS these trees spend an XP CURRENCY, not a point pool: each row
    carries its price in field 6 and the balance lives in AP_honor_exp /
    AP_prestige / AP_infamy_exp / AP_medic_exp. Unlearning is not uniform
    either -- bh and rebel cost $5,000 and refund the XP, while cop and medic
    have empty unlearn cases below, i.e. those two trees are PERMANENT. Anything
    driving this from outside must not offer an unlearn button for them.

    PERSISTENCE IS THE CALLER'S JOB. fn_prestigeMenu syncs on dialog close;
    a caller without that dialog has to call ClupdatePartial itself
    (14 bh / 16 cop / 22 rebel / 23 medic).
*/
params[["_side", "", [""]], ["_idIn", -1, [0]], ["_confirmed", false, [false]]];
if (_side isEqualTo "") exitWith {false};

private _body = {
    params ["_side", "_idIn", "_confirmed"];
    private _specialityID = if (_idIn >= 0) then { _idIn } else { parseNumber(lbData[123001, lbCurSel 123001]) };
    (switch (_side) do {case "bh": {
                [AP_honor_talents, ["getRowByID", "bh", _specialityID] call AP_fnc_prestigeCfg]}; case "cop": {
                    [AP_cop_talents, ["getRowByID", "cop", _specialityID] call AP_fnc_prestigeCfg]};
            case "rebel": {[AP_infamy_talents, ["getRowByID", "rebel", _specialityID] call AP_fnc_prestigeCfg]};
            case "medic": {[AP_medic_talents, ["getRowByID", "medic", _specialityID] call AP_fnc_prestigeCfg]};
    }) params["_playerSpecialitysUnlocked", "_requestedSpecialityRow"];
    if (isNil "_requestedSpecialityRow" || {_requestedSpecialityRow isEqualTo[]}) exitWith {systemChat "Error."; false};
    _requestedSpecialityRow params["_specialityID", "_requestSide", "_prerequisiteSpecialityID", "_depth", "_title", "_description", "_prestigeReq"];
    private _result = if (_specialityID in _playerSpecialitysUnlocked) then {private _child = ["getChild", _side, _specialityID] call AP_fnc_prestigeCfg;
        if !(_child isEqualTo[]) exitWith {
            [format["You can't unlearn this speciality as it has a child talent, %1, which will need to be unlearned first.", _child select 4], "basic"] spawn AP_fnc_handleMessage;
            false
        };
        switch (_side) do {case "bh": {private _action = true;
                    if (!_confirmed) then {
                        _action = ["Unlearning an honor speciality will cost $5,000 - are you sure?", "Unlearn and refund honor", "Yes", "No"] call BIS_fnc_guiMessage;
                    };
                    if !(_action) exitWith {false};
                    if !([5000] call AP_fnc_debitCard) exitWith {false};
                    _playerSpecialitysUnlocked deleteAt(_playerSpecialitysUnlocked findIf {_x isEqualTo _specialityID});
                    AP_honor_exp = AP_honor_exp + _prestigeReq;
                    [format["You have unlearned the speciality %1 and been refunded %2 honor.", _title, [_prestigeReq] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                    true
                }; case "cop": {false};
                case "rebel": {private _action = true;
                        if (!_confirmed) then {
                            _action = ["Unlearning an infamy speciality will cost $5,000 - are you sure?", "Unlearn and refund infamy", "Yes", "No"] call BIS_fnc_guiMessage;
                        };
                        if !(_action) exitWith {false};
                        if !([5000] call AP_fnc_debitCard) exitWith {false};
                        _playerSpecialitysUnlocked deleteAt(_playerSpecialitysUnlocked findIf {_x isEqualTo _specialityID});
                        AP_infamy_exp = AP_infamy_exp + _prestigeReq;
                        [format["You have unlearned the speciality %1 and been refunded %2 infamy.", _title, [_prestigeReq] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                        true
                    };
                case "medic": {false};
                default {false};};} else {switch (_side) do {case "bh": {
                    if (_prerequisiteSpecialityID > 0 && !(_prerequisiteSpecialityID in _playerSpecialitysUnlocked)) exitWith {
                        ["This speciality requires another speciality that you don't have!", "basic"] spawn AP_fnc_handleMessage; false};
                    if (count AP_honor_talents > 14) exitWith {
                        ["You may only have a maximum of 15 specialities in the skiptracer system", "basic"] spawn AP_fnc_handleMessage; false};
                    if (_prestigeReq > AP_honor_exp) exitWith {
                        ["You don't have enough honor to learn this.", "basic"] spawn AP_fnc_handleMessage; false};
                    if (AP_effSide isEqualTo civilian && (_specialityID isEqualTo 11 && !(10 in AP_honor_talents && 7 in AP_honor_talents && 4 in AP_honor_talents) || _specialityID isEqualTo 22 && !(15 in AP_honor_talents && 18 in AP_honor_talents && 21 in AP_honor_talents))) exitWith {
                        ["This is a master level talent which requires all previous talents.", "basic"] spawn AP_fnc_handleMessage; false};
                    _playerSpecialitysUnlocked pushBack _specialityID;
                    AP_honor_exp = AP_honor_exp - _prestigeReq;
                    [format["You have learned the speciality %1.", _title], "basic"] spawn AP_fnc_handleMessage;
                    systemChat format["You have learned the speciality: %1.", _title]; true}; case "cop": {
                        if (_prerequisiteSpecialityID > 0 && !(_prerequisiteSpecialityID in _playerSpecialitysUnlocked)) exitWith {
                            ["This speciality requires another speciality that you don't have!", "basic"] spawn AP_fnc_handleMessage; false};
                        if (_prestigeReq > AP_prestige) exitWith {
                            ["You don't have enough prestige to learn this.", "basic"] spawn AP_fnc_handleMessage; false};
                        _playerSpecialitysUnlocked pushBack _specialityID;
                        AP_prestige = AP_prestige - _prestigeReq;
                        [format["You have learned the speciality %1.", _title], "basic"] spawn AP_fnc_handleMessage;
                        systemChat format["You have learned the speciality: %1.", _title]; true};
                case "rebel": {if (_prerequisiteSpecialityID > 0 && !(_prerequisiteSpecialityID in _playerSpecialitysUnlocked)) exitWith {
                            ["This speciality requires another speciality that you don't have!", "basic"] spawn AP_fnc_handleMessage; false};
                        if (count AP_infamy_talents > 20) exitWith {
                            ["You may only have a maximum of 21 specialities in the infamy system!", "basic"] spawn AP_fnc_handleMessage; false
                        };
                        if (_prestigeReq > AP_infamy_exp) exitWith {
                            ["You don't have enough infamy to learn this.", "basic"] spawn AP_fnc_handleMessage; false};
                        if (AP_effSide isEqualTo civilian && !license_civ_rebel) exitWith {
                            ["You must have a rebel license to learn specialities.", "basic"] spawn AP_fnc_handleMessage; false};
                        _playerSpecialitysUnlocked pushBack _specialityID;
                        AP_infamy_exp = AP_infamy_exp - _prestigeReq;
                        [format["You have learned the speciality %1.", _title], "basic"] spawn AP_fnc_handleMessage;
                        systemChat format["You have learned the speciality: %1.", _title]; true};
                case "medic": {if (_prerequisiteSpecialityID > 0 && !(_prerequisiteSpecialityID in _playerSpecialitysUnlocked)) exitWith {
                            ["This speciality requires another speciality that you don't have!", "basic"] spawn AP_fnc_handleMessage; false};
                        if (!(AP_effSide isEqualTo independent) || ((call AP_medicLevel) < 3)) exitWith {
                            ["You must be an AEMT or higher to learn TT specialities.", "basic"] spawn AP_fnc_handleMessage; false};
                        if (_prestigeReq > AP_medic_exp) exitWith {
                            ["You don't have enough prestige to learn this.", "basic"] spawn AP_fnc_handleMessage; false};
                        _playerSpecialitysUnlocked pushBack _specialityID;
                        AP_medic_exp = AP_medic_exp - _prestigeReq;
                        [format["You have learned the speciality %1.", _title], "basic"] spawn AP_fnc_handleMessage;
                        systemChat format["You have learned the speciality: %1.", _title]; true};
                default {false};};};
    // Dialog-owned repaint; the deck never opens 123000 so it must not be called.
    if (!isNull (findDisplay 123000)) then { [_side] spawn AP_fnc_populatePrestigeTree; };
    _result
};

if (_idIn >= 0) exitWith { [_side, _idIn, _confirmed] call _body };
[_side, -1, false] spawn _body;
true
