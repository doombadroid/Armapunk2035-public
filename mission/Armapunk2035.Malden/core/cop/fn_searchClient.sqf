if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server hop only: APS_fnc_victimSRV checks actor/range/state
params[["_cop", objNull, [objNull]]];
if (isNull _cop) exitWith {};
private _inv = [];
private _clothes = [];
private _robber = false;
private _runner = false;
private _seizableMoney = 0;
private _val = 0;
private _licenses = "";
private _illegalExempt =
if (SRV_governorData param[3, false]) then {AP_governorLegalisableItems} else {[]}; {_x params["_item"];
    private _val = missionNamespace getVariable [format["AP_inv_%1", _item], 0];
    if ((_val > 0) && !(_item in _illegalExempt)) then {_inv pushBack[_item, _val];};}
forEach(["getIllegalItems"] call AP_fnc_virtItemCfg);
if (license_civ_bounty) then {missionNamespace setVariable["license_civ_gun", true]}; {_x params["_license", "_side"];
    _val = missionNamespace getVariable[_license, false];
    if (!isNil "_val") then {if (_val && _side isEqualTo "civ") then {
            _licenses = _licenses + (["varToStr", _license] call AP_fnc_licenseCfg) + "<br/>";};};}
forEach AP_licenses; {private _item = _x;
    if (_item in ["V_HarnessOGL_brn", "U_B_CombatUniform_mcam_worn", "U_I_CombatUniform_shortsleeve", "U_BG_Guerrilla_6_1", "U_Rangemaster", "V_TacVest_gen_F"]) then {
        private _clothingExists = _clothes findIf {(_x select 0) isEqualTo _item};
        if (_clothingExists isEqualTo - 1) then {_clothes pushBack[_item, 1];} else {
            _clothes set[_clothingExists, [_item, ((_clothes select _clothingExists) select 1) + 1]];};};}
forEach([uniform player, vest player] + (items player));
private _illegalActivity = "";
if (time - (player getVariable["AP_drugtrace", -1000]) < 400) then {if (AP_cash > 0) then {_seizableMoney = AP_cash};
    AP_cash = 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [0] call AP_fnc_ClupdatePartial; [[getPlayerUID player, "AP_drugtrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
    _illegalActivity = "drugRunner";};
if (time - (player getVariable["AP_banktrace", -1000]) < 400) then {if (AP_cash > 0) then {_seizableMoney = AP_cash};
    AP_cash = 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [0] call AP_fnc_ClupdatePartial; [[getPlayerUID player, "AP_banktrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
    _illegalActivity = "bankRobber";};
if (time - (player getVariable["AP_choptrace", -1000]) < 200) then {if (AP_cash > 0) then {_seizableMoney = AP_cash};
    AP_cash = 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [0] call AP_fnc_ClupdatePartial; [[getPlayerUID player, "AP_choptrace", -1000], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
    _illegalActivity = "vehicleChop";};
AP_lastPersistVar = ["", time];
if !(AP_use_atm) then {if (AP_cash > 0) then {_seizableMoney = AP_cash};
    AP_cash = 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    [0] call AP_fnc_ClupdatePartial;
    _illegalActivity = "gasStationRobber";};
private _newPlayer =
if (A_stats_civTime < 1440) then {"(NEW PLAYER)"} else {""}; [
    [player, _inv, _clothes, _illegalActivity, _licenses, _seizableMoney, AP_alcohol_level, AP_drug_level, _newPlayer], "AP_fnc_copSearch", _cop] spawn AP_fnc_MP;   // owner 2026-09-05: the 10th arg (illegal cyberdeck firmware) is GONE -- AP_fnc_hasDeck is now just "you are civilian", so it flagged every civilian on every search. fn_copSearch dropped the matching param.