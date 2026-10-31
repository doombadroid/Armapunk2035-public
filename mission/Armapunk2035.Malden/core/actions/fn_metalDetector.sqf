#include "..\..\macro.h"
if (scriptAvailable(3)) exitWith {["You cannot metal detect so fast!", "basic"] spawn AP_fnc_handleMessage;};
private _resourceZones = ["mine_1", "mine_2", "mine_3", "mine_4", "mine_5", "mine_6"];
private _nearbyZones = _resourceZones select {player distance(getMarkerPos _x) <= 150};
private _zone = _nearbyZones param[(_nearbyZones apply {player distance(getMarkerPos _x)}) findIf {
    _x isEqualTo(selectMin(_nearbyZones apply {player distance(getMarkerPos _x)}))}, ""];
private _distance = 70;
if (AP_action_in_use) exitWith {};
if (isNil "AP_action_gathering") then {AP_action_gathering = false;};
if (AP_action_gathering) exitWith {};
if (AP_inv_metaldetector < 1) exitWith {
    ["You must have a metal detector in order to scan for metals.", "basic"] spawn AP_fnc_handleMessage;};
if (_zone isEqualTo "") exitWith {};
titleText[format["Starting Metal Detection..."], "PLAIN"];
PlaySound "metalDetectScan";
AP_action_gathering = true;
AP_action_in_use = true;
private _delay =
if (52 in AP_side_talents) then {8} else {10};
private _random = "";
private _gathered = [];
private _exit = false;
private _randomID = round(random 500);
profileNamespace setVariable["AP_metalDetectorID", _randomID];
private _plb_player = player;
private _plb_obj = "Weapon_hgun_esd_01_antenna_02_F"
createVehicleLocal[0, 0, 0];
_plb_obj attachTo[_plb_player, [0, 0, 0.05], "righthand"];
_plb_obj setVectorUp[1, 0.5, 0.5];
private _itemTable = [
    ["lockpick"], 8, ["rubber"], 6, ["doubloon"], 16, ["ruby"], 7, ["smash"], 3, ["uraniump"], 3, ["silverpiece"], 10, ["redgull"], 1];
private _yield =
switch (true) do {case (_zone in ["mine_2", "mine_3", "mine_4", "mine_5", ""]): {1};
    case (_zone in ["mine_1", "mine_6"]): {2};}; uiSleep 1;
while {speed player >= 2}
do {uiSleep _delay;
    private _amountEarned = _yield;
    private _randomItem =
    switch (true) do {case (random 2000 < 1): {"treasuremap"};
        case (random 2000 < 1): {"goldbar"};
        case (random 2000 < 1): {"goldnugget"};
        case (random 2000 < 1): {"diamondf"};
        default {(selectRandomWeighted _itemTable) select 0};}; private _amountEarned =
    if (_randomItem in ["treasuremap", "diamondf", "goldnugget"]) then {1} else {_amountEarned};
    if ([true, _randomItem, _amountEarned] call AP_fnc_handleInv) then {
        titleText[format["Unearthed %1 %2. %3/%4", _amountEarned, ["getName", _randomItem] call AP_fnc_virtItemCfg, AP_carryWeight, AP_maxWeight], "PLAIN"];
        if (AP_currentTalents < 10) then {AP_side_exp = AP_side_exp + 2;};
        playSound "metalDetectScan";
        private _index = _gathered findIf {(_x select 0) isEqualTo _randomItem};
        if (_index isEqualTo - 1) then {_gathered pushBack[_randomItem, _amountEarned];} else {
            private _currentAmount = (_gathered select _index) select 1;
            (_gathered select _index) set[1, _currentAmount + _amountEarned];};} else {_exit = true;};
    if (_exit || (player distance(getMarkerPos _zone) > _distance) || !(isNull objectParent player) || !(AP_action_in_use) || !((profileNamespace getVariable["AP_metalDetectorID", -1]) isEqualTo _randomID)) exitWith {};
}; if (_exit) then {titleText["Metal Detecting done. You can't hold more metals.", "PLAIN"];} else {
    titleText["Metal Detecting cancelled.", "PLAIN"];
    ["You must be constantly moving to detect metals!", "basic"] spawn AP_fnc_handleMessage;};
AP_action_gathering = false;
AP_action_in_use = false;
deleteVehicle _plb_obj; [["-GATHER-", player, profileName, format["Metal Detected %1 at position %2.", _gathered apply {[
            ["getName", _x select 0] call AP_fnc_virtItemCfg, _x select 1]}, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;