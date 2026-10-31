#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {
    ["Wait a few seconds before depositing more money in your bank account or try the deposit all feature instead.", "basic"] spawn AP_fnc_handleMessage;
};
params[["_depositAll", false, [false]]];
private _preBalance = AP_atmcash;
private _value = 0;
_value =
if (_depositAll) then {AP_cash} else {parseNumber(ctrlText 2702)};
if !(_value isEqualType 0) exitWith {};
if (!_depositAll && (_value > 9999999)) exitWith {["You can't deposit more than $9,999,999", "basic"] spawn AP_fnc_handleMessage;};
if (!_depositAll && !([str(_value)] call AP_fnc_isNumber)) exitWith {
    ["You can't deposit an expontential value due to the A3 Engine limitations... Try an amount below $9,999,999.", "basic"] spawn AP_fnc_handleMessage;
};
if (_value <= 0) exitWith {["You did not enter an amount to deposit!", "basic"] spawn AP_fnc_handleMessage;};
if (_value > AP_cash) exitWith {["You do not have that much cash on you.", "basic"] spawn AP_fnc_handleMessage;};
// ATM SKIMMER: if this ATM is rigged (and not by you), a slice of the deposit is siphoned to the planter.
// owner 2026-07-21: 10% -> 3% (Skim Daemon rebalance, spec band 2-4%). Server rolls the silent alarm.
private _skim = 0;
if (!isNil "AP_skimATM" && {!isNull AP_skimATM}) then {private _so = AP_skimATM call AP_fnc_atmSkimOwner;
    if (_so isNotEqualTo "" && {_so isNotEqualTo (getPlayerUID player)}) then { _skim = round (_value * 0.03); };};
AP_cash = AP_cash - _value;
AP_cashCacheB = ((AP_cash / 4) + 9);
AP_atmcash = AP_atmcash + (_value - _skim);
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
if (_skim > 0) then {[["credit", getPosATL AP_skimATM, _skim], "APS_fnc_atmSkimSRV", 2] spawn AP_fnc_MP;
    [format ["An ATM skimmer siphoned $%1 (3%%) off your deposit.", [_skim] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
};
[6] call AP_fnc_ClupdatePartial;
[] call AP_fnc_atmMenu;
[format["You have deposited $%1 into your bank account", [_value] call AP_fnc_numberText]] spawn AP_fnc_handleMessage; [
    ["-DEPOSIT-", player, (profileName), format["deposited $%1 into their bank account. Pre Bal: $%2 - Post Bal: $%3", [_value] call AP_fnc_numberText, [_preBalance] call AP_fnc_numberText, [AP_atmcash] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
if (AP_effSide isEqualTo civilian && {A_stats_civTime < 300 && _value >= 74999}) then {[
        ["-MONEYWARNING-", player, profileName, format["deposited $%1 to their bank. Civ time: %2 minutes | Bank: $%3 | Cash: $%4 | Position: %5 | Experience: %6.", [_value] call AP_fnc_numberText, A_stats_civTime, [AP_atmcash] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText, getPosATL player, [AP_side_exp] call AP_fnc_numberText]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};