#include "..\..\macro.h"
if (scriptAvailable(3)) exitWith {["You cannot mine so fast!", "basic"] spawn AP_fnc_handleMessage;};
if (AP_action_in_use) exitWith {};
if (isNil "AP_action_gathering") then {AP_action_gathering = false;};
if (AP_action_gathering) exitWith {};
if (AP_inv_pickaxe < 1) exitWith {["You must have a pickaxe in order to mine uranium.", "basic"] spawn AP_fnc_handleMessage;};
// No marker means no uranium site on this map. Without this the 300 m loop check below measures against
// [0,0,0] and the whole site exists in the map's SW corner. See fn_gather.
if (markerType "illegal_marker_4_0" isEqualTo "") exitWith {};
titleText[format["Mining..."], "PLAIN"];
playSound "pickaxe";
AP_action_gathering = true;
AP_action_in_use = true;
private _startPos = getPos player;
private _delay =
if (52 in AP_side_talents) then {4} else {5};
private _exit = false;
private _amount = 1;
private _distance = 300;
private _totalGathered = 0;
["AinvPercMstpSnonWnonDnon_Putdown_AmovPercMstpSnonWnonDnon", 2.5] spawn AP_fnc_handleAnim;
for "_i"
from 0 to 1 step 0 do {
    if (_exit || (player distance2D _startPos) > 4 || (player distance(getMarkerPos "illegal_marker_4_0") > _distance) || !(isNull objectParent player) || !(AP_action_in_use)) exitWith {};
    private _random = floor(random 500);
    private _item =
    if (_random < 3) then {"diamondf"} else {"uraniumu"};
    private _amount = 1;
    // ROCKHOUND (223): +1 unit every mining swing.
    if (223 in AP_side_talents) then { _amount = _amount + 1; };
    uiSleep _delay;
    if ([true, _item, _amount] call AP_fnc_handleInv) then {
        titleText[format["Mined %1 %2. %3/%4", _amount, (["getName", _item] call AP_fnc_virtItemCfg), AP_carryWeight, AP_maxWeight], "PLAIN"];
        if (_item isEqualTo "uraniumu") then {_totalGathered = _totalGathered + _amount;};
        if (AP_currentTalents < 15) then {AP_side_exp = AP_side_exp + 2;};} else {_exit = true;};}; if (_exit) then {
    titleText["Mining done. You can't hold more uranium.", "PLAIN"];
    playSound "ziptie";
    playSound "ziptie";
    playSound "ziptie";} else {titleText["Mining cancelled.", "PLAIN"];};
[] spawn AP_fnc_handleAnim;
AP_action_gathering = false;
AP_action_in_use = false; [
    ["-GATHER-", player, profileName, format["gathered %1 %2 at position %3.", _totalGathered, "Uranium Ore", getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;