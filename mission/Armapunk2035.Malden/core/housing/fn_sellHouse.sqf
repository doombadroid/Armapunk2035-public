#include "..\..\macro.h"
params[["_house", objNull, [objNull]]];
if (isNull _house) exitWith {};
if !(_house isKindOf "House_F") exitWith {};
if (AP_action_in_use) exitWith {["You're already performing another action.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_houseTxn) exitWith {["You are currently in the process of buying or selling a home.", "basic"] spawn AP_fnc_handleMessage;};
if (isNil {_house getVariable["AP_homeOwner", ""]}) exitWith {["There is no owner for this house.", "basic"] spawn AP_fnc_handleMessage
};
closeDialog 0;
private _houseCfg = [typeOf _house] call AP_fnc_houseConfig;
if (_houseCfg isEqualTo[]) exitWith {};
_houseCfg params[["_buyPrice", -1], ["_sellPrice", -1], ["_physInv", []], ["_virtInv", []]];
private _action = [format["Are you sure you want to sell your house? It will sell for: <t color='#8cff9b'>$%1</t>", [_sellPrice] call AP_fnc_numberText, _houseCfg select 1], "Sell House", "Sell", "Cancel"] call BIS_fnc_guiMessage;
if (_action) then {if (AP_houseTxn) exitWith {
        ["You are currently in the process of buying or selling a home.", "basic"] spawn AP_fnc_handleMessage;};
    if (AP_lastSoldHouse isEqualTo _house) exitWith {
        ["You cannot sell the same house multiple times! This action has been logged!", "basic"] spawn AP_fnc_handleMessage; [
            ["-EXPLOIT-", player, (profileName), format["attempted to sell a house multiple times. Position(XYZ): %1", getPosATL _house]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };
    AP_lastSoldHouse = _house;
    AP_houseTxn = true;
    AP_action_in_use = true;
    ["Attempting to sell your house to the bank...", "basic"] spawn AP_fnc_handleMessage; [
        [_house, player], "APS_fnc_srvSellHouse", 2] call AP_fnc_MP;
    _house setVariable["AP_house_sold", true, true];};