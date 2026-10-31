#include "..\..\macro.h"
if (scriptAvailable(5)) exitWith {
    ["Wait a few seconds before depositing more money in to gang bank account or try the deposit all feature instead.", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3303, true];};
if (AP_gang_funds isEqualTo - 1) exitWith {closeDialog 0;};
AP_gang_data params[["_gangID", -1, [0]], ["_gangName", "", [""]], ["_rank", 5, [0]]];
if (_gangID isEqualTo - 1) exitWith {closeDialog 0;};
params[["_depositAll", false, [false]], ["_deckAmt", -1, [0]]];
private _value = 0;
_value =
if (_depositAll) then {AP_cash} else {
    if (_deckAmt >= 0) then {_deckAmt} else {parseNumber(ctrlText 3305)}};
if !(_value isEqualType 0) exitWith {ctrlEnable[3303, true];};
if (!_depositAll && (_value > 9999999)) exitWith {["You can't deposit more than $9,999,999", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3303, true];};
if (!_depositAll && !([str(_value)] call AP_fnc_isNumber)) exitWith {
    ["You can't deposit an expontential value due to the A3 Engine limitations... Try an amount below $9,999,999.", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3303, true];};
if (_value <= 0) exitWith {["You did not enter an amount to deposit!", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3303, true];};
if (_value > AP_cash) exitWith {["You do not have that much cash on you.", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3303, true];};
ctrlEnable[3302, false];
ctrlEnable[3303, false];
ctrlEnable[3304, false];
AP_gfunds_active = true;
[format["Attempting to deposit $%1 in your gang account...", [_value] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage; [
    ["-GANGDEPOSIT-", player, (profileName), format["attempted to deposit $%1 from their GANG bank account. GANG ACCOUNT BAL: $%2 - Player Cash: $%3", [_value] call AP_fnc_numberText, [AP_gang_funds] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[[1, _gangID, player, _value, AP_cash, AP_cashCacheB], "APS_fnc_gangBank", false, false] spawn AP_fnc_MP;
AP_cash = AP_cash - _value;
AP_cashCacheB = ((AP_cash / 4) + 9);
[6] call AP_fnc_ClupdatePartial;
AP_gangfund_ready = false;
AP_gang_funds = -1;
disableSerialization;
private _display = findDisplay 3300;
private _text = _display displayCtrl 3301;
_text ctrlSetStructuredText parseText format["<img size='1.7' image='icons\bank.paa'/> %1<br/><img size='1.6' image='icons\money.paa'/> $%2", "Processing Txn...", [AP_cash] call AP_fnc_numberText];
[] spawn {waitUntil {!AP_gfunds_active};
    if (isNull(findDisplay 3300)) exitWith {}; [[0, AP_gang_data select 0, player], "APS_fnc_gangBank", 2] spawn AP_fnc_MP;
    waitUntil {uiSleep 0.3;
        AP_gangfund_ready};
    uiSleep 0.5;
    [6] call AP_fnc_ClupdatePartial;
    disableSerialization;
    private _display = findDisplay 3300;
    private _text = _display displayCtrl 3301;
    _text ctrlSetStructuredText parseText format["<img size='1.7' image='icons\bank.paa'/> $%1<br/><img size='1.6' image='icons\money.paa'/> $%2", [AP_gang_funds] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText];
    if ((AP_gang_funds >= 1) && ((AP_gang_data select 2) <= 2)) then {ctrlEnable[3302, true];};
    ctrlEnable[3303, true];
    ctrlEnable[3304, true];};