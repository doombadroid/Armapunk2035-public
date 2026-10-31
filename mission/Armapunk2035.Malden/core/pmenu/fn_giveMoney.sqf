#include "..\..\macro.h"
/*
    fn_giveMoney.sqf -- hand cash to a nearby player.

    Two callers, ONE set of rules:
        [_ctrl] spawn AP_fnc_giveMoney;             // native money dialog button EH
        [_uid, _amount] call AP_fnc_giveMoney;      // web deck (fn_deckOpen "transfer")

    Re-plumbed 2026-08-14. It used to read the recipient and the amount straight
    out of dialog 341000's listbox and edit box, which is why the deck could not
    call it and why its "transfer" verb answered ok=false. Every guard below IS
    the trust boundary for a client-authoritative cash move, so the deck path
    goes through this function rather than getting a second, thinner copy of them
    (security.md).

    Returns true only when the money actually moved.
*/
if (scriptAvailable(3)) exitWith { false };
disableSerialization;

params [["_arg0", controlNull], ["_arg1", 0, [0]]];
// The native caller is a ButtonClick EH, so _arg0 arrives as a control; the deck
// passes a uid string. Type, not count -- an EH array is never one string.
private _fromDialog = !(_arg0 isEqualType "");

private _uid = "";
private _cashAmount = 0;
if (_fromDialog) then {
    if ((lbCurSel 341003) isNotEqualTo -1) then {
        _uid = lbData[341003, lbCurSel 341003];
        _cashAmount = parseNumber(ctrlText 341002);
    };
} else {
    _uid = _arg0;
    _cashAmount = round _arg1;
};

if (_uid isEqualTo "") exitWith {["You didn't select anyone to give this to", "basic"] spawn AP_fnc_handleMessage;
    false};
private _unit = allPlayers param[allPlayers findIf {(getPlayerUID _x) isEqualTo _uid}, objNull];
if ((isNull _unit) || (_unit isEqualTo player)) exitWith {["That player is no longer online.", "basic"] spawn AP_fnc_handleMessage;
    false};
if (_cashAmount <= 0) exitWith {["You didn't input any money to give", "basic"] spawn AP_fnc_handleMessage;
    false};
if (_cashAmount > AP_cash) exitWith {["You don't have that much to give!", "basic"] spawn AP_fnc_handleMessage;
    false};
if (_cashAmount > 999999) exitWith {["You can't give more than $999,999 at a time.", "basic"] spawn AP_fnc_handleMessage;
    false};
if (!AP_use_atm) exitWith {["You recently robbed a store! You can't give money away just yet.", "basic"] spawn AP_fnc_handleMessage;
    false};
// Was reading lbData[361003] -- the INVENTORY dialog's listbox, not this one -- so
// the arrest check tested whatever the inventory happened to have selected and
// usually passed. Fixed 2026-08-14 to test the actual recipient.
if (_uid in AP_arrested_uid) exitWith {
    ["You have recently arrested this player; you cannot give them the money you made from their arrest!", "basic"] spawn AP_fnc_handleMessage;
    false};
if (AP_gfunds_active) exitWith {
    ["You can't give money while having an active gang bank withdrawal. Try again in a couple seconds.", "basic"] spawn AP_fnc_handleMessage;
    false};
if (player distance2D _unit > 20) exitWith {["The selected player is too far away!", "basic"] spawn AP_fnc_handleMessage;
    false};
[format["You gave $%1 to %2.", [_cashAmount] call AP_fnc_numberText, name _unit], "basic"] spawn AP_fnc_handleMessage; [
    [_unit, _cashAmount, player], "AP_fnc_receiveMoney", _unit, false, false] spawn AP_fnc_MP;
// Only the native dialog needs repainting -- calling this unconditionally would
// OPEN dialog 341000 on top of the deck.

AP_cash = AP_cash - _cashAmount;
AP_ucashCacheC = ((AP_cash / 2) + 5);
[0] call AP_fnc_ClupdatePartial; [
    ["-CASHGIVE-", player, (profileName), format["gave $%1 cash to %2 (%3).", [_cashAmount] call AP_fnc_numberText, (name _unit), (getPlayerUID _unit)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
["cash_send", _cashAmount] call AP_fnc_statArrUpdate;
if (AP_effSide isEqualTo civilian && {A_stats_civTime < 300 && _cashAmount >= 74999}) then {[
        ["-MONEYWARNING-", player, profileName, format["gave $%1 to %2 (%3). Civ time: %4 minutes | Bank: $%5 | Cash: $%6 | Position: %7 | Experience: %8.", [_cashAmount] call AP_fnc_numberText, _unit getVariable["AP_name", name _unit], getPlayerUID _unit, A_stats_civTime, [AP_atmcash] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText, getPosATL player, [AP_side_exp] call AP_fnc_numberText]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};
true
