#include "..\..\macro.h"
params[["_mode", -1, [0]], "_amount"];
if (_mode isEqualTo - 1) exitWith {};
private _lottoTixPrice = 2000;
// owner 2026-06-14 (#194): the jackpot lives in AP_configuration[8] -- the server bumps it +1 (= +$1000)
// per ticket in fn_addToLottery and publicVariables AP_configuration. The display used `AP_lotteryVal`,
// which is NEVER assigned from that, so the shown jackpot never moved. Read the live synced value instead.
private _jackpot = (missionNamespace getVariable ["AP_configuration", []]) param [8, 25];
if !(_jackpot isEqualType 0) then { _jackpot = parseNumber format ["%1", _jackpot] };
if (_mode isEqualTo 1 && {AP_atmcash < _lottoTixPrice}) exitWith {
    ["Your bank balance is too low to play the lottery!", "basic"] spawn AP_fnc_handleMessage;};
private _exit = false;
switch (_mode) do {case 0: {
            [format["<t color='#00BFFF'><t size='1'>Lottery Value</t></t><br/>The lottery is currently up to $%1. Play today to try your chance at winning!", [(_jackpot * 1000)] call AP_fnc_numberText], "lottoinfo"] spawn AP_fnc_handleMessage;
        };
    case 1: {if (scriptAvailable(4)) exitWith {["You cannot rapidly buy lottery tickets!", "basic"] spawn AP_fnc_handleMessage;};
            private _action = [format["Would you like to buy a lottery ticket for $%1? The jackpot is currently $%2.", [_lottoTixPrice] call AP_fnc_numberText, [(_jackpot * 1000)] call AP_fnc_numberText], "LoonyBin Lottery Commission", "Yes", "No"] call BIS_fnc_guiMessage;
            if (_action) then {[[player], "APS_fnc_add2Lotto", 2] call AP_fnc_MP;
                systemChat format["You purchased a lottery ticket for $%1.", [_lottoTixPrice] call AP_fnc_numberText];
                AP_atmcash = AP_atmcash - _lottoTixPrice;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                [1] call AP_fnc_ClupdatePartial;
                ["lottoloss", _lottoTixPrice] call AP_fnc_statArrUpdate;};};
    case 2: {if (remoteExecutedOwner != 2) exitWith {};
            [format["<t color='#00BFFF'><t size='1'><t align='center'>Lottery Won!</t></t></t><br/>Congratulations! You won the $%1 lottery jackpot! The funds have been added to your bank account.", [_amount] call AP_fnc_numberText], "lottoinfo"] spawn AP_fnc_handleMessage;
            AP_atmcash = AP_atmcash + _amount;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [1] call AP_fnc_ClupdatePartial;
            ["lottowin", _amount] call AP_fnc_statArrUpdate;};
    default {["Bad values passed... Try again please...", "basic"] spawn AP_fnc_handleMessage;};}; if (_exit) exitWith {};