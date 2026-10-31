#include "..\..\macro.h"
params[["_target", objNull, [objNull]], ["_caller", objNull, [objNull]], ["_actionId", -1, [-1]], ["_arguments", "", [""]], ["_bankMode", 0, [0]]];
if !(AP_use_atm) exitWith {["Because you robbed a store you can't use the ATM for 5 minutes.", "basic"] spawn AP_fnc_handleMessage;};
// ASSET FREEZE (owner 2026-07-21): a wanted suspect an officer froze (TAL Asset Freeze -> AP_assetFrozen, a
// server-set + published expiry) can't touch an ATM until it lifts. Consistent with the existing client-money
// trust model -- the freeze var is server-authoritative, the enforcement point is the client like every other
// money op. Server-side ATM Jackpot honours the same freeze independently.
if ((player getVariable ["AP_assetFrozen", 0]) > serverTime) exitWith {
    [format ["<t color='#4aa3ff'>ACCOUNTS FROZEN</t> -- an officer locked your assets. %1s left.", ceil ((player getVariable ["AP_assetFrozen", 0]) - serverTime)], "basic"] spawn AP_fnc_handleMessage;
};
if (player getVariable["AP_restrained", false]) exitWith {};
if (player getVariable["AP_surrendered", false]) exitWith {};
// ATM SKIMMER: remember which physical ATM this session is on, so withdraw/deposit can read its skimmer owner.
// The open action already gates cursorObject to an ATM within 3m, so it IS the machine here. Anything else (NPC
// banker, laptop) clears it: a stale ATM from earlier used to skim this session too, and the server refuses that credit.
AP_skimATM = if (!isNull cursorObject && {((typeOf cursorObject) in ["Land_Atm_01_F","Land_Atm_02_F","Land_Mattaust_ATM","Land_atm"]) || {[str cursorObject, "atm_0"] call KRON_StrInStr}}) then {
    cursorObject} else {objNull};
// DECK ROUTE (UI overhaul 2026-08-26): the ATM opens as a deck app. Every ATM in
// the world calls this function, so this one branch converts all of them; the
// native dialog stays below as the AP_deckApps=false fallback, same pattern as
// AP_webShops. The restrained/surrendered checks moved ABOVE this route -- the
// native ran them after its dialog was already up, which only worked because a
// second exitWith closed nothing.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["Bank", cursorObject] call AP_fnc_deckOpenApp;
};
if !(dialog) then {["atmV2Menu"] call AP_fnc_createDialog;};
disableSerialization;
private _display = findDisplay 2700;
private _text = _display displayCtrl 2701;
private _units = _display displayCtrl 2703;
private _withButton = _display displayCtrl 2706;
private _depButton = _display displayCtrl 2707;
private _depAllButton = _display displayCtrl 2708;
if !(AP_gfunds_active) then {_withButton ctrlEnable true;
    _depButton ctrlEnable true;
    _depAllButton ctrlEnable true;} else {
    ["You currently are performing another banking action, please reopen the menu when done.", "basic"] spawn AP_fnc_handleMessage;};
_text ctrlSetStructuredText parseText format["<img size='1.7' image='icons\bank.paa'/> $%1<br/><img size='1.6' image='icons\money.paa'/> $%2", [AP_atmcash] call AP_fnc_numberText, [AP_cash] call AP_fnc_numberText];
lbClear _units; {if ((alive _x) && !(_x distance2D(getMarkerPos "respawn_civilian") <= 1000)) then {private _type =
        switch (side _x) do {case civilian: {"Civ"};
            case west: {"Cop"};
            case independent: {
                    "EMS"};}; private _playerData = [_x getVariable["AP_name", name _x], _x getVariable["AP_playerid", getPlayerUID _x]];
        private _idx = _units lbAdd format["%1 (%2)", _playerData param[0, "Error Name"], _type];
        _units lbSetData[_idx, _playerData param[1, "Error UID"]];};}
forEach((playableUnits - [player]) select { (typeOf _x) isNotEqualTo "HeadlessClient_F" });   // never list the headless client as a transfer target
lbSort _units;
lbSetCurSel[2703, 0];
if (((A_stats_crimes param[0, 0]) > 1000) && ((time - AP_last_wanted) > 240)) then {AP_last_wanted = time;
    private _toSend = allPlayers - [allDeadMen] select {((side _x isEqualTo civilian && !(((_x getVariable["AP_myBounties", []]) findIf {
            getPlayerUID player in _x}) isEqualTo - 1)) || side _x isEqualTo west)};
    if !(_toSend isEqualTo[]) then {[
            [9, profileName, str(A_stats_crimes select 0), player], "AP_fnc_clientMessage", _toSend] spawn AP_fnc_MP;};};