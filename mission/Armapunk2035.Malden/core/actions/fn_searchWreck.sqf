private _wreck = cursorObject;
private _delay =
if (66 in AP_side_talents) then {3.5;} else {4;};
private _depth = ((getPosASL player) select 2);
private _success = false;
private _weightGained = 0;
if (isNil "AP_action_gathering") then {AP_action_gathering = false;};
if !((str(_wreck) find "wreck_") >= 0) exitWith {titleText["You need to be looking at a ship wreck to use the excavator.", "PLAIN"]};
if (player distance _wreck > 20) exitWith {titleText["You need to be closer to a ship wreck to use the excavator.", "PLAIN"]};
if (_depth > -15) exitWith {titleText["The excavator requires more water pressure (you're not deep enough).", "PLAIN"]};
if (AP_carryWeight >= AP_maxWeight) exitWith {titleText["You are too heavy to hold any more treasures.", "PLAIN"]};
if (AP_action_in_use) exitWith {};
if (AP_action_gathering) exitWith {};
AP_action_gathering = true;
AP_action_in_use = true;
private _itemTable = [
    ["silverpiece"], 30, ["saltwater"], 14, ["lockpick"], 13, ["ziptie"], 10, ["oilp"], 6, ["doubloon"], 15, ["ruby"], 6, ["smash"], 3, ["tbacon"], 1, ["redgull"], 1, ["diamondf"], 4];
_delay = (_delay * (1 - ((abs(_depth + 9)) * 0.001)));
titleText["Searching Wreck...", "PLAIN"];
["wreckexcavate", 1] call AP_fnc_statArrUpdate;
while {!_success}
do {if (speed player > 1) exitWith {};
    if ((player distance _wreck) > 20) exitWith {titleText["You need to be closer to a ship wreck to use the excavator.", "PLAIN"]};
    if (_depth > -15) exitWith {titleText["The excavator requires more water pressure (you're not deep enough).", "PLAIN"]};
    if (AP_carryWeight >= AP_maxWeight) exitWith {_success = true;};
    private _randomItem =
    switch (true) do {case (random 2500 < 1): {"treasuremap"};
        case (random 5000 < 1): {"goldbar"};
        case (random 3000 < 1): {"goldnugget"};
        default {(selectRandomWeighted _itemTable) select 0};
    }; private _sum = [_randomItem, 1, AP_carryWeight, AP_maxWeight] call AP_fnc_calWeightDiff;
    private _itemWeight = ["getItemWeight", _randomItem] call AP_fnc_virtItemCfg;
    if (_sum > 0) then {if ([true, _randomItem, 1] call AP_fnc_handleInv) then {uiSleep _delay;
            titleText[format["You have collected 1 %1 from the wreck.", ["getName", _randomItem] call AP_fnc_virtItemCfg], "PLAIN"];
            titleFadeOut 1.5;
            AP_side_exp = AP_side_exp + 2;
            _weightGained = _weightGained + _itemWeight;};};}; AP_action_gathering = false;
AP_action_in_use = false;
if (_success) then {titleText["The excavator is full, check your haul!", "PLAIN"];
    playSound "ziptie";
    playSound "ziptie";
    playSound "ziptie";
    ["action", "excavatorfull", 1] call AP_fnc_handleQuest;} else {titleText["Excavation has failed!", "PLAIN"];};