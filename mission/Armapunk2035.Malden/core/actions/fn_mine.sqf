params[["_zone", "", [""]], ["_distance", 0, [0]]];
if (AP_action_in_use) exitWith {};
if (AP_inv_pickaxe < 1) exitWith {["You must have a pickaxe in order to gather this resource.", "basic"] spawn AP_fnc_handleMessage;};
private _yield =
switch (true) do {case (_zone in ["mine_2", "mine_3", "mine_4", "mine_5"]): {1};
    case (_zone in ["mine_1", "mine_6"]): {2};}; titleText [format["Mining..."], "PLAIN"];
PlaySound "pickaxe";
AP_action_gathering = true;
AP_action_in_use = true;
private _startPos = getPos player;
private _delay =
if (52 in AP_side_talents) then {3} else {4};
private _ironChance =
if (53 in AP_side_talents) then {4} else {5};
private _diamondChance =
if (54 in AP_side_talents) then {4} else {5};
private _random = "";
private _gathered = [];
private _exit = false;
["AinvPercMstpSnonWnonDnon_Putdown_AmovPercMstpSnonWnonDnon", 2.5] spawn AP_fnc_handleAnim;
for "_i"
from 0 to 1 step 0 do {private _amount = 1;
    uiSleep _delay;
    _random =
    if ((AP_is_arrested param [0,0]) isEqualTo 0) then {switch (true) do {case (random 2000 < 1): {"treasuremap";};
            // owner 2026-06-14 (#226): gold nuggets + flawless diamonds were near-unobtainable from the
            // quarry. 5x the drop rate for both (random N<K has prob K/N -> 5x the K). goldnugget 2->10
            // (0.04%->0.2%), diamondf 3->15 (1.2%->6%); the 2nd diamondf path below also 5x'd.
            case (random 5000 < 10): {"goldnugget";};
            case (random 250 < 15): {"diamondf";};
            case (floor(random 5 * _yield) < 1 && !(51 in AP_side_talents)): {"rock";};
            case (floor(random(100 / _yield)) < 1):   // #226: 2nd flawless-diamond path 5x'd (500/_yield -> 100/_yield)
                {"diamondf";};
            case (floor(random(_ironChance / _yield)) < 1): {"ironore";};
            case (floor(random(_diamondChance / _yield)) < 1): {"diamond";};
            case (floor(random(3 / _yield)) < 1): {"copperore";};
            case (floor(random(4 / _yield)) < 1): {"sand";};
            default {"rock"};};};
    if (_random isEqualTo "copperore" && 51 in AP_side_talents) then {_amount = 2};
    if ([true, _random, _amount] call AP_fnc_handleInv) then {
        titleText[format["Mined %1 %2. %3/%4", _amount, ["getName", _random] call AP_fnc_virtItemCfg, AP_carryWeight, AP_maxWeight], "PLAIN"];
        if (AP_currentTalents < 10) then {AP_side_exp = AP_side_exp + 2;};
        private _index = _gathered findIf {(_x select 0) isEqualTo _random};
        if (_index isEqualTo - 1) then {_gathered pushBack[_random, _amount];} else {
            private _currentAmount = (_gathered select _index) select 1;
            (_gathered select _index) set[1, _currentAmount + _amount];};
        [_random, _amount] call AP_fnc_statArrUpdate;
        // Schematic drop, same contract as fn_gather: report the action, the SERVER rolls.
        [["roll", [player, "mine", ""]], "APS_fnc_fabGrantSRV", 2] spawn AP_fnc_MP;} else {_exit = true;
        // BUGS.md #91 ("still broken"): tell the server WHY the add was refused so we can see the
        // real limiter in the RPT/log table (weight vs item-monitor vs nil roll).
        private _tot = 0; { _tot = _tot + (missionNamespace getVariable [_x, 0]); } forEach AP_invMonVars; [
            ["-MINE-", player, profileName, format ["handleInv REFUSED item=%1 x%2 | carry %3/%4 (itemW %5) | items %6 | monitor-slack %7 | arrested %8", if (isNil "_random") then {"<nil>"} else {_random}, _amount, AP_carryWeight, AP_maxWeight, ["getItemWeight", if (isNil "_random") then {"rock"} else {_random}] call AP_fnc_virtItemCfg, _tot, AP_invMonitor - AP_invRVar, AP_is_arrested param [0,0]]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };
    if (_exit || (player distance2D _startPos) > 4 || (player distance(getMarkerPos _zone) > _distance) || !(isNull objectParent player) || !AP_action_in_use) exitWith {};
}; if (_exit) then {titleText["Mining done. You can't hold more minerals.", "PLAIN"];
    playSound "ziptie";
    playSound "ziptie";
    playSound "ziptie";} else {titleText["Mining cancelled.", "PLAIN"];};
[] spawn AP_fnc_handleAnim;
AP_action_gathering = false;
AP_action_in_use = false; [["-GATHER-", player, profileName, format["mined %1 at position %2.", _gathered apply {[
            ["getName", _x select 0] call AP_fnc_virtItemCfg, _x select 1]}, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;