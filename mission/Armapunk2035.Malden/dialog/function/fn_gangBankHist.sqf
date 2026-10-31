#include "..\..\macro.h" ["gangBankHistory"] call AP_fnc_createDialog;
// owner 2026-06-22 (#473 "Gang Bank History does not work"): the server (APS_fnc_gangBHistory) replies with TWO
// separate async netSetVar messages -- the DATA (AP_gangBank_History) and the READY flag -- in no guaranteed
// order. The old code woke on Ready alone and immediately tested `history isEqualTo []`, so if Ready landed first
// it saw the still-empty list and threw a FALSE "Failed to fetch" (the gang's history never showed). Now:
//   * init the data var to nil (nil = pending; [] = arrived-but-empty; [...] = real rows),
//   * wait for Ready AND the data to actually arrive (closes the race), with a 10s timeout for a true failure,
//   * distinguish "no history yet" (arrived empty) from an actual fetch failure -- no more misleading message.
// Also dropped the stray `lnbAddColumn 0`: gangBankHistory.hpp already defines 3 columns, so it was adding a
// spurious 4th and skewing the table.
AP_gangBank_History = nil;
AP_gangHistory_Ready = false; [[(AP_gang_data select 0), player], "APS_fnc_gangBHistory", false, false] spawn AP_fnc_MP;
disableSerialization;
[] spawn {private _t0 = time;
    waitUntil {(AP_gangHistory_Ready && !isNil "AP_gangBank_History") || !(alive player) || ((time - _t0) > 10)};
    if !(alive player) exitWith {};
    if (!AP_gangHistory_Ready || isNil "AP_gangBank_History") exitWith {
        ["Failed to fetch gang history -- try again in a moment.", "basic"] spawn AP_fnc_handleMessage;
        AP_gangHistory_Ready = false;};
    if (AP_gangBank_History isEqualTo []) exitWith {["Your gang has no bank history yet.", "basic"] spawn AP_fnc_handleMessage;
        AP_gangBank_History = nil;
        AP_gangHistory_Ready = false;};
    uiSleep 0.1;
    disableSerialization;
    private "_type";
    private _display = findDisplay 100300;
    private _list = _display displayCtrl 100302;
    _list lnbSetColumnsPos[0.002, 0.65, 0.8]; {_type =
        switch (_x select 2) do {case 1: {"Deposited"};
            case 2: {"Withdrew"};
            case 3: {"Transferred"};
            default {""};
        }; _list lnbAddRow[format["%1 (%2)", _x select 0, _x select 1], _type, format["$%1", [_x select 3] call AP_fnc_numberText]];}
    forEach AP_gangBank_History;
    AP_gangBank_History = nil;
    AP_gangHistory_Ready = false;};
