params[["_caller", objNull, [objNull]], ["_responder", objNull, [objNull]]];
if (isNil "AP_session_completed" || {!AP_session_completed}) exitWith {};
if (_responder isEqualTo _caller && _responder isEqualTo player || (isNull(AP_medicAcceptedCorpse param[1, objNull]))) exitWith {};
if (_responder isNotEqualTo player && {
    isNull _caller || (isNull(AP_medicAcceptedCorpse param[1, objNull])) || AP_effSide isEqualTo civilian || (AP_effSide isEqualTo west && !(AP_copRole in ["medic", "all"]))
}) exitWith {};
private _travelBonus =
if ((AP_medicAcceptedCorpse param[4, [0, 0, 0]]) isEqualTo[0, 0, 0]) then {0} else {
    0.2 * (round(getPos player distance(AP_medicAcceptedCorpse param[4, [0, 0, 0]])))};
if ((AP_medicAcceptedCorpse param[1, objNull]) isEqualTo _responder) then {AP_atmcash = (round(AP_atmcash + _travelBonus)) max 0;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [format["%1 bled out and no longer requires medical attention. You have received $%2 for your troubles.", name _caller, _travelBonus], "basic"] spawn AP_fnc_handleMessage;
    AP_medicAcceptedCorpse = [objNull, objNull, "", "", [0, 0, 0], -1800];} else {if (_responder isNotEqualTo player) then {
        AP_atmcash = (round(AP_atmcash + _travelBonus)) max 0;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [format["%1 was revived by %2 and no longer requires medical attention. You have received $%3 for your troubles.", name _caller, name _responder, _travelBonus], "basic"] spawn AP_fnc_handleMessage;
        AP_medicAcceptedCorpse = [objNull, objNull, "", "", [0, 0, 0], -1800];} else {
        if ((AP_medicAcceptedCorpse param[0, objNull]) isEqualTo _caller) then {
            _travelBonus = 0.25 * (round(getPos player distance(AP_medicAcceptedCorpse param[4, [0, 0, 0]])));
            AP_medicAcceptedCorpse = [objNull, objNull, "", "", [0, 0, 0], -1800];} else {_travelBonus = 0;};
        private _reviveReward = (call AP_revive_fee);
        if (AP_effSide isEqualTo independent && side _caller isEqualTo independent) then {_travelBonus = 0;} else {
            _reviveReward = _reviveReward + 1000;
            if (122 in AP_side_talents) then {_reviveReward = _reviveReward * 1.2};};
        _reviveReward = _reviveReward + _travelBonus;
        if (_reviveReward < 0) then {_reviveReward = 0;};
        if (AP_effSide isEqualTo independent) then {private _partners = [];
            if !(AP_medPartners isEqualTo[]) then {_partners = [7, objNull] call AP_fnc_medicPartners;};
            if (_partners isEqualTo[]) then {AP_atmcash = AP_atmcash + _reviveReward;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                titleText[format["You have revived %1 and received $%2 for rendering aid.", name player, [_reviveReward] call AP_fnc_numberText], "PLAIN"];
            } else {_reviveReward = round(_reviveReward / ((count _partners) + 1));
                AP_atmcash = AP_atmcash + _reviveReward;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                titleText[format["You have revived %1 and received $%2 for rendering aid.", name player, [_reviveReward] call AP_fnc_numberText], "PLAIN"];
                [
                    [format["You have received %1 for a revive performed by %2.", [_reviveReward] call AP_fnc_numberText, profileName]], "AP_fnc_handleMessage", _partners] call AP_fnc_MP;
                [[_partners, _reviveReward], "APS_fnc_medicSplit", 2] spawn AP_fnc_MP;};} else {
            AP_atmcash = (round(AP_atmcash + (_reviveReward + _travelBonus))) max 0;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
        titleText[format["You have revived %1 and received $%2 for your services.", name _caller, [_reviveReward] call AP_fnc_numberText], "PLAIN"];
        private _xpReward =
        if (AP_effSide isEqualTo independent) then {50} else {30};
        AP_side_exp = AP_side_exp + _xpReward;};};
[1] call AP_fnc_ClupdatePartial;