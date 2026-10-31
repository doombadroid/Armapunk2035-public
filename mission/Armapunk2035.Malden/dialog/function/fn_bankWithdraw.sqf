#include "..\..\macro.h"
if (scriptAvailable(3)) exitWith {["Wait a few seconds before withdrawing more money.", "basic"] spawn AP_fnc_handleMessage;};
private _val = parseNumber(ctrlText 2702);
private _preBalance = AP_atmcash;
if (_val > 9999999) exitWith {["You can't withdraw more than $9,999,999", "basic"] spawn AP_fnc_handleMessage;};
if (_val <= 0) exitWith {["You did not enter an amount to withdraw!", "basic"] spawn AP_fnc_handleMessage;};
if !([str _val] call AP_fnc_isNumber) exitWith {
    ["You can't deposit an expontential value due to the A3 Engine limitations... Try an amount below $9,999,999.", "basic"] spawn AP_fnc_handleMessage;
};
if (_val < 100 && AP_atmcash > 20000000) exitWith {["You can't withdraw less than $100.", "basic"] spawn AP_fnc_handleMessage};
if (_val > AP_atmcash) exitWith {["You do not have that much money to withdraw!", "basic"] spawn AP_fnc_handleMessage;};
// ATM SKIMMER: if this ATM is rigged (and not by you), a slice of the withdrawal is siphoned to the planter.
// owner 2026-07-21: 10% -> 3% (Skim Daemon rebalance, spec band 2-4%). Server rolls the silent alarm.
private _skim = 0;
if (!isNil "AP_skimATM" && {!isNull AP_skimATM}) then {private _so = AP_skimATM call AP_fnc_atmSkimOwner;
    if (_so isNotEqualTo "" && {_so isNotEqualTo (getPlayerUID player)}) then { _skim = round (_val * 0.03); };};
AP_cash = AP_cash + (_val - _skim);
AP_cashCacheB = ((AP_cash / 4) + 9);
AP_atmcash = AP_atmcash - _val;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
if (_skim > 0) then {[["credit", getPosATL AP_skimATM, _skim], "APS_fnc_atmSkimSRV", 2] spawn AP_fnc_MP;
    [format ["An ATM skimmer siphoned $%1 (3%%) off your withdrawal.", [_skim] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
};
[6] call AP_fnc_ClupdatePartial;
[] call AP_fnc_atmMenu;
[format["You have withdrawn $%1 from your bank account.", [_val] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage; [
    ["-WITHDRAW-", player, (profileName), format["withdrew $%1 from their bank account. Pre Bal: $%2 - Post Bal: $%3", [_val] call AP_fnc_numberText, [_preBalance] call AP_fnc_numberText, [AP_atmcash] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;