#include "..\..\macro.h"
if (scriptAvailable(8)) exitWith {["You cannot access the gang bank again so soon.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0};
params[["_target", objNull, [objNull]], ["_caller", objNull, [objNull]], ["_actionId", -1, [-1]], ["_arguments", "", [""]]];
// owner 2026-06-15 (#252): gang bank stays its own scroll-wheel action, but only the TOP gang ranks may USE
// it -- rank 1 (leader), 2 (manage/withdraw) and 3 (invite). AP_gang_data[2] = the player's gang rank
// (set in fn_gangRanks). param[2,-1] is safe for non-gang / short data -> rejected.
if !((AP_gang_data param [2, -1]) in [1, 2, 3]) exitWith {
    ["Only your gang's top ranks can access the gang bank.", "basic"] spawn AP_fnc_handleMessage;};
if !(AP_use_atm) exitWith {["Because you robbed a store you can't use the ATM for 5 minutes.", "basic"] spawn AP_fnc_handleMessage;};
// DECK ROUTE (UI overhaul 2026-08-26): the gang bank lives in the deck's My Gang
// command cards now. The ledger fetch runs the same mode-0 request.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["My Gang"] call AP_fnc_deckOpenApp;
    ["bank"] call AP_fnc_deckGang;
};
if !(dialog) then {["atmV2MenuV2Gang"] call AP_fnc_createDialog;};
if (player getVariable["AP_restrained", false]) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {};
if (AP_gfunds_active) exitWith {closeDialog 0;
    ["There is a transaction in progress. Please wait until it is complete.", "basic"] spawn AP_fnc_handleMessage};
AP_gangfund_ready = false;
AP_gang_funds = -1;
AP_gangMembersList_ready = false;
AP_gangMembersList = []; [[0, AP_gang_data select 0, player], "APS_fnc_gangBank", false, false] spawn AP_fnc_MP; [
    [AP_gang_data select 0, player], "APS_fnc_getGangInfo", 2] call AP_fnc_MP;
disableSerialization;
private _display = findDisplay 3300;
private _text = _display displayCtrl 3301;
private _title = _display displayCtrl 3308;
_text ctrlSetStructuredText parseText format["<img size='1.7' image='icons\bank.paa'/> %1<br/><img size='1.6' image='icons\money.paa'/> $%2", "Loading...", [AP_cash] call AP_fnc_numberText];
_title ctrlSetText format["%1's Bank", AP_gang_data select 1];
ctrlEnable[3302, false];
ctrlEnable[3303, false];
ctrlEnable[3304, false];
ctrlEnable[3307, false];
[] spawn {waitUntil {uiSleep 0.3;
        AP_gangfund_ready && AP_gangMembersList_ready};
    uiSleep 0.5;
    disableSerialization;
    private _display = findDisplay 3300;
    private _text = _display displayCtrl 3301;
    private _gangMembersList = _display displayCtrl 3306;
    _text ctrlSetStructuredText parseText format["<img size='1.7' image='icons\bank.paa'/> $%1<br/><img size='1.6' image='icons\money.paa'/> $%2", [AP_gang_funds] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText];
    if ((AP_gang_funds >= 1) && ((AP_gang_data select 2) <= 2)) then {ctrlEnable[3302, true];
        ctrlEnable[3307, true];};
    lbClear _gangMembersList; {_x params["_xGangName", "_xGangUID"];
        _gangMembersList lbAdd format["%1 (%2)", _xGangName, _xGangUID];
        _gangMembersList lbSetData[(lbSize _gangMembersList) - 1, str[_xGangName, _xGangUID]];}
    forEach AP_gangMembersList;
    ctrlEnable[3303, true];
    ctrlEnable[3304, true];};