#include "..\..\macro.h"
/*
    AP_fnc_deckBank -- the deck's BANK app: payload builder and every mutation.

    First screen of the deck-app wave (design handoff 2026-08-26): the ATM
    interact routes into the deck instead of dialog 2700, and this function is
    the ported logic of fn_bankDeposit / fn_bankWithdraw / fn_bankTransfer --
    ported, not shared, because the natives read their own dialog controls
    (ctrlText 2702, lbCurSel 2703) and cannot take a parameter. Every guard
    they enforce is enforced here: the spam limiter, the engine number caps,
    the asset freeze, the ATM-skimmer slice, and the -MONEYWARNING- log line.

    ["data"]                      -> payload hashmap for the "bank" channel
    ["dep"|"wd", <amount>]        -> {ok, msg}
    ["depall"]                    -> {ok, msg}
    ["xfer", <amount>, <uid>]     -> {ok, msg}   (spawned -- guiMessage-free)

    History is session-local by design: nothing in the DB stores personal bank
    lines, so the app shows what THIS session did and says no more than that.
*/
params [["_verb", "", [""]], ["_amt", 0, [0]], ["_uid", "", [""]]];

private _hist = {
    params ["_label", "_delta"];
    private _h = missionNamespace getVariable ["AP_deckBankHist", []];
    _h pushBack [_label, _delta, [AP_atmcash] call AP_fnc_numberText];
    if (count _h > 6) then { _h deleteAt 0 };
    AP_deckBankHist = _h;
};
private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

// Gates every verb shares. The freeze and the robbery lockout are the OPEN
// gates of fn_atmMenu; restated per-op because the app can sit open across
// their onset, and the native enforcement point is the client throughout.
private _gate = {
    if (!AP_use_atm) exitWith { "Because you robbed a store you can't use the ATM for 5 minutes." };
    if ((player getVariable ["AP_assetFrozen", 0]) > serverTime) exitWith {
        format ["ACCOUNTS FROZEN -- an officer locked your assets. %1s left.",
            ceil ((player getVariable ["AP_assetFrozen", 0]) - serverTime)] };
    if (player getVariable ["AP_restrained", false]) exitWith { "You are restrained." };
    if (player getVariable ["AP_surrendered", false]) exitWith { "You are surrendered." };
    ""
};

// The skimmer slice, shared by deposit and withdraw. AP_skimATM is stamped by
// the interact (fn_atmMenu) before it routes here, so it IS the machine used.
private _skimOf = {
    params ["_value"];
    private _skim = 0;
    if (!isNil "AP_skimATM" && {!isNull AP_skimATM}) then {
        private _so = AP_skimATM call AP_fnc_atmSkimOwner;
        if (_so isNotEqualTo "" && {_so isNotEqualTo (getPlayerUID player)}) then {
            _skim = round (_value * 0.03);
        };
    };
    if (_skim > 0) then {
        [["credit", getPosATL AP_skimATM, _skim], "APS_fnc_atmSkimSRV", 2] spawn AP_fnc_MP;
    };
    _skim
};

private _sw = toLower _verb;
if (_sw in ["dep", "depall"]) then { _sw = "deposit" };
switch (_sw) do {

case "data": {
    private _players = [];
    {
        private _type = switch (side _x) do {
            case west: {"Cop"}; case independent: {"EMS"}; default {"Civ"} };
        _players pushBack (createHashMapFromArray [
            ["uid",  _x getVariable ["AP_playerid", getPlayerUID _x]],
            ["name", format ["%1 (%2)", _x getVariable ["AP_name", name _x], _type]]
        ]);
    } forEach ((playableUnits - [player]) select {
        (typeOf _x) isNotEqualTo "HeadlessClient_F"
        && {alive _x} && {!(_x distance2D (getMarkerPos "respawn_civilian") <= 1000)}
    });
    createHashMapFromArray [
        ["cash",    AP_cash],
        ["bank",    AP_atmcash],
        ["frozen",  (player getVariable ["AP_assetFrozen", 0]) > serverTime],
        ["recent",  missionNamespace getVariable ["AP_deckBankHist", []]],
        ["players", _players]
    ]
};

// SQF switch has NO fall-through -- "case a; case b:" compiles the first case as
// an empty statement and the arm never runs for it. Both deposit verbs are
// collapsed BEFORE the switch instead.
case "deposit": {
    private _g = call _gate; if (_g isNotEqualTo "") exitWith { [_g] call _no };
    private _all = _verb isEqualTo "depall";
    if (!_all && {scriptAvailable(5)}) exitWith {
        ["Wait a few seconds before depositing again -- or use DEP ALL."] call _no };
    private _value = if (_all) then { AP_cash } else { _amt };
    if (!_all && {_value > 9999999}) exitWith { ["You can't deposit more than $9,999,999."] call _no };
    if (!_all && {!([str _value] call AP_fnc_isNumber)}) exitWith { ["Invalid amount."] call _no };
    if (_value <= 0) exitWith { ["You did not enter an amount to deposit."] call _no };
    if (_value > AP_cash) exitWith { ["You do not have that much cash on you."] call _no };

    private _preBalance = AP_atmcash;
    private _skim = [_value] call _skimOf;
    AP_cash = AP_cash - _value;             AP_cashCacheB = ((AP_cash / 4) + 9);
    AP_atmcash = AP_atmcash + (_value - _skim); AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [6] call AP_fnc_ClupdatePartial;
    ["DEPOSIT", _value - _skim] call _hist;
    [["-DEPOSIT-", player, profileName, format ["deposited $%1 into their bank account. Pre Bal: $%2 - Post Bal: $%3",
        [_value] call AP_fnc_numberText, [_preBalance] call AP_fnc_numberText, [AP_atmcash] call AP_fnc_numberText]],
        "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (AP_effSide isEqualTo civilian && {A_stats_civTime < 300 && _value >= 74999}) then {
        [["-MONEYWARNING-", player, profileName, format ["deposited $%1 to their bank. Civ time: %2 minutes | Bank: $%3 | Cash: $%4 | Position: %5 | Experience: %6.",
            [_value] call AP_fnc_numberText, A_stats_civTime, [AP_atmcash] call AP_fnc_numberText,
            [AP_cash] call AP_fnc_numberText, getPosATL player, [AP_side_exp] call AP_fnc_numberText]],
            "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };
    if (_skim > 0) exitWith {
        [format ["Deposited $%1 -- an ATM skimmer siphoned $%2 (3%3).",
            [_value - _skim] call AP_fnc_numberText, [_skim] call AP_fnc_numberText, "%"]] call _yes };
    [format ["Deposited $%1.", [_value] call AP_fnc_numberText]] call _yes
};

case "wd": {
    private _g = call _gate; if (_g isNotEqualTo "") exitWith { [_g] call _no };
    if (scriptAvailable(3)) exitWith { ["Wait a few seconds before withdrawing again."] call _no };
    private _val = _amt;
    private _preBalance = AP_atmcash;
    if (_val > 9999999) exitWith { ["You can't withdraw more than $9,999,999."] call _no };
    if (_val <= 0) exitWith { ["You did not enter an amount to withdraw."] call _no };
    if !([str _val] call AP_fnc_isNumber) exitWith { ["Invalid amount."] call _no };
    if (_val < 100 && AP_atmcash > 20000000) exitWith { ["You can't withdraw less than $100."] call _no };
    if (_val > AP_atmcash) exitWith { ["You do not have that much money to withdraw."] call _no };

    private _skim = [_val] call _skimOf;
    AP_cash = AP_cash + (_val - _skim);     AP_cashCacheB = ((AP_cash / 4) + 9);
    AP_atmcash = AP_atmcash - _val;         AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [6] call AP_fnc_ClupdatePartial;
    ["WITHDRAW", -_val] call _hist;
    [["-WITHDRAW-", player, profileName, format ["withdrew $%1 from their bank account. Pre Bal: $%2 - Post Bal: $%3",
        [_val] call AP_fnc_numberText, [_preBalance] call AP_fnc_numberText, [AP_atmcash] call AP_fnc_numberText]],
        "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (_skim > 0) exitWith {
        [format ["Withdrew $%1 -- an ATM skimmer siphoned $%2 (3%3).",
            [_val - _skim] call AP_fnc_numberText, [_skim] call AP_fnc_numberText, "%"]] call _yes };
    [format ["Withdrew $%1.", [_val] call AP_fnc_numberText]] call _yes
};

case "xfer": {
    private _g = call _gate; if (_g isNotEqualTo "") exitWith { [_g] call _no };
    if (scriptAvailable(4)) exitWith { ["Please wait a few seconds before sending money again."] call _no };
    private _val = _amt;
    if !([str _val] call AP_fnc_isNumber) exitWith { ["Invalid amount."] call _no };
    if (_val > 9999999) exitWith { ["You can't transfer more than $9,999,999 at a time."] call _no };
    if (_val < 100) exitWith { ["You cannot transfer less than $100."] call _no };
    if (_val > AP_atmcash) exitWith { ["You do not have enough in your bank account."] call _no };
    private _unit = allPlayers param [allPlayers findIf {
        (_x getVariable ["AP_playerid", getPlayerUID _x]) isEqualTo _uid }, objNull];
    if (isNull _unit) exitWith { ["That player is no longer online."] call _no };
    if ((_unit distance (getMarkerPos "respawn_civilian") < 1000) || !(alive _unit)) exitWith {
        ["This player is dead. Try again soon."] call _no };
    if ((player distance (getMarkerPos "respawn_civilian") < 1000) || !(alive player)) exitWith {
        ["You cannot conduct wire transfers while dead."] call _no };

    // The deck's own arm-then-commit replaces BIS_fnc_guiMessage -- the page
    // asks twice before this verb is ever called, so no blocking dialog here.
    private _preBalance = AP_atmcash;
    AP_atmcash = (round (AP_atmcash - _val)) max 0;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;
    // Same physical-ATM sweep as the native: the server pays out only near a
    // real machine, which is what stops a wire transfer from a ditch.
    private _nearATMs = ((nearestObjects [player, [], 10]) + (nearestTerrainObjects [player, [], 10])) select {
        private _object = _x;
        private _alwaysATM = ((typeOf _object) in ["Land_Atm_01_F", "Land_Atm_02_F", "Land_ATM_01_malden_F", "Land_ATM_02_malden_F", "Land_Laptop_Intel_01_F"]) || (((str _object) find "atm_0") >= 0);
        private _hasAction = ((((actionIDs _object) findIf { "AP_fnc_atmMenu" in ((_object actionParams _x) select 1) }) >= 0) && !(_object in allPlayers));
        _hasAction = if (!isNil "_hasAction") then { _hasAction } else { false };
        (_hasAction || _alwaysATM)
    };
    [[_val, player, _unit, _preBalance, _nearATMs], "APS_fnc_handleWireTransfer", 2, false, false] spawn AP_fnc_MP;
    ["TRANSFER", -_val] call _hist;
    [["-BANKTRANSFER-", player, profileName, format ["wiretransfered $%1 to %2 (%3).",
        [_val] call AP_fnc_numberText, name _unit, getPlayerUID _unit]],
        "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (AP_effSide isEqualTo civilian && {A_stats_civTime < 1440 && _val >= 74999}) then {
        [["-MONEYWARNING-", player, profileName, format ["wiretransferred $%1 to %2 (%3). Civ time: %4 minutes | Bank: $%5 | Cash: $%6 | Position: %7 | Experience: %8.",
            [_val] call AP_fnc_numberText, _unit getVariable ["AP_name", name _unit], getPlayerUID _unit,
            A_stats_civTime, [AP_atmcash] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText,
            getPosATL player, [AP_side_exp] call AP_fnc_numberText]],
            "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };
    [format ["Transferred $%1 to %2.", [_val] call AP_fnc_numberText, _unit getVariable ["AP_name", name _unit]]] call _yes
};

default { ["unknown bank verb"] call _no };
};
