#include "..\..\macro.h"
// DECK ROUTE: amount + target as params; page arm-confirms so no guiMessage.
params [["_deckAmt", -1, [0]], ["_deckUid", "", [""]], ["_deckName", "", [""]]];
private _fromDeck = _deckAmt >= 0;
if (scriptAvailable(5)) exitWith {["Please wait a few seconds before trying to send money again!", "basic"] spawn AP_fnc_handleMessage;};
if (!_fromDeck && {(lbCurSel 3306) isEqualTo - 1}) exitWith {
    ["You need to select a gang member to transfer the money to.", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3705, true];};
if (AP_gang_funds isEqualTo - 1) exitWith {closeDialog 0;};
AP_gang_data params[["_gangID", -1, [0]], ["_gangName", "", [""]], ["_rank", 5, [0]]];
if (_gangID isEqualTo - 1) exitWith {closeDialog 0;};
if (_rank > 2) exitWith {["You must be a rank 2 or above to transfer gang funds!", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3307, false];};
private _val = if (_fromDeck) then {_deckAmt} else {parseNumber(ctrlText 3305)};
if !([str _val] call AP_fnc_isNumber) exitWith {["Invalid number.", "basic"] spawn AP_fnc_handleMessage;};
if (_val > 9999999) exitWith {["You can't transfer more than $9,999,999 at a time.", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[2705, true];};
if (_val < 1000) exitWith {["You cannot transfer less than $1000."] spawn AP_fnc_handleMessage;
    ctrlEnable[2705, true];};
if (_val > AP_gang_funds) exitWith {["There is not enough gang funds in the account!", "basic"] spawn AP_fnc_handleMessage;
    ctrlEnable[3302, true];};
private "_playerUID"; private "_playerName";
if (_fromDeck) then { _playerUID = _deckUid; _playerName = _deckName; } else {
    (parseSimpleArray(lbData[3306, lbCurSel 3306])) params["_playerUID2", "_playerName2"];
    _playerUID = _playerUID2; _playerName = _playerName2;
};
private _action = if (_fromDeck) then { true } else {
    [format["Are you sure you want to send $%1 to %2?", [_val] call AP_fnc_numberText, _playerName], "Approve Gang Funds Transfer", "Send Money", "Cancel"] call BIS_fnc_guiMessage};
if (_action) then {[[4, _gangID, player, -(_val), 0, 0, "", _playerUID], "APS_fnc_gangBank", false, false] spawn AP_fnc_MP;
    ctrlEnable[3302, false];
    ctrlEnable[3303, false];
    ctrlEnable[3304, false];
    ctrlEnable[3307, false];
    AP_gfunds_active = true;
    AP_gangfund_ready = false;
    AP_gang_funds = -1;
    disableSerialization;
    private _display = findDisplay 3300;
    private _text = _display displayCtrl 3301;
    _text ctrlSetStructuredText parseText format["<img size='1.7' image='icons\bank.paa'/> %1<br/><img size='1.6' image='icons\money.paa'/> $%2", "Processing Txn...", [AP_cash] call AP_fnc_numberText];
    [] spawn {waitUntil {!AP_gfunds_active};
        if (isNull(findDisplay 3300)) exitWith {}; [
            [0, AP_gang_data select 0, player], "APS_fnc_gangBank", false, false] spawn AP_fnc_MP;
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
        ctrlEnable[3304, true];
        ctrlEnable[3307, true];};
    private _nearATMs = (nearestObjects[player, [], 10]) select {private _object = _x;
        private _hasAction = ((((actionIDs _object) findIf {(((_object actionParams _x) select 1) find "AP_fnc_atmMenu") >= 0
        }) >= 0) && !(_object in allPlayers));
        private _alwaysATM = ((typeOf _object) in ["Land_Atm_01_F", "Land_Atm_02_F", "Land_ATM_01_malden_F", "Land_ATM_02_malden_F"]) || (((str _object) find "atm_0") >= 0);
        _hasAction =
        if (!isNil "_hasAction") then {_hasAction} else {false};
        (_hasAction || _alwaysATM);};
    [format["Attempting to transfer $%1 to %2.", [_val] call AP_fnc_numberText, _playerName], "basic"] spawn AP_fnc_handleMessage; [
        ["-GANGBANKTRANSFER-", player, profileName, format["attemped to wiretransfer gang funds, $%1 to %2 (%3).", [_val] call AP_fnc_numberText, _playerName, _playerUID]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (AP_effSide isEqualTo civilian && {A_stats_civTime < 300 && _val >= 74999}) then {[
            ["-MONEYWARNING-", player, profileName, format["wiretransferred gang funds, %1 to %2 (%3). Civ time: %4 minutes | Bank: $%5 | Cash: $%6 | Position: %7 | Experience: %8.", [_val] call AP_fnc_numberText, _playerName, _playerUID, A_stats_civTime, [AP_atmcash] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText, getPosATL player, [AP_side_exp] call AP_fnc_numberText]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };} else {["You have decided to cancel the gang funds transfer at this time...", "basic"] spawn AP_fnc_handleMessage;};
ctrlEnable[3705, true];