params["_target", "_caller", "_actionId", "_arguments"];
_arguments params[["_start", 0, [0]]];
if (_start isEqualTo 0) exitWith {
    if !(["Are you sure you want to abandon the job? The smugglers will take $3,000 for their troubles.", "Drug Runner", "Yes, I'm sure!", "No, keep going", findDisplay 46, false, false] call BIS_fnc_guiMessage) exitWith {};
    AP_drug_stage = 4;};
if !(AP_effSide isEqualTo civilian) exitWith {["Only civilians can perform drug delivery missions!", "basic"] spawn AP_fnc_handleMessage
};
if ((count(nearestObjects[getMarkerPos format["drug_spawn_%1", _start], ["Car", "Ship", "Air"], 5])) >= 1) exitWith {
    ["Unable to continue as there's another vehicle on the plane spawn point!", "basic"] spawn AP_fnc_handleMessage};
if !(["We'll supply you with the plane and drugs, but if you fail you'll be held liable for $15,000! Are you up for it?", "Drug Runner", "I'll do it!", "No, I'm afraid.", findDisplay 46, false, false] call BIS_fnc_guiMessage) exitWith {};
if (AP_atmcash < 15000) exitWith {
    ["You don't have enough money in your bank account to put a deposit on the plane!", "basic"] spawn AP_fnc_handleMessage};
AP_atmcash = AP_atmcash - 15000;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial;
[format["A deposit of $%1 was taken from your bank account.", [15000] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
private _informant =
switch (true) do {case (35 in AP_side_talents): {(random 100) < 20};
    case (36 in AP_side_talents): {(random 100) < 10};
    default {(random 100) < 30};}; private _plane = "C_Plane_Civil_01_F"
createVehicle(getMarkerPos format["drug_spawn_%1", _start]);
_plane setDir(markerDir format["drug_spawn_%1", _start]);
_plane setHitPointDamage["HitHull", 0.5];
_plane setFuel 0.5;
[_plane] spawn {while {uiSleep 0.5;
        !isNull(_this select 0)}
    do {(_this select 0) action["cancelLand", (_this select 0)]}};
_plane setVariable["AP_side", "civ", true];
_plane setVariable["AP_vinv", [[], 0], true];
_plane setVariable["AP_vcap", ["getVirtCap", "", typeOf _plane] call AP_fnc_vehicleConfig, true];
_plane setVariable["AP_vehOwners", [[getPlayerUID player, profileName]], true];
_plane setVariable["AP_canChop", false, true];
private _drugRunners = ([1, 2, 3, 4, 5]) - [_start];
private _targetID = selectRandom _drugRunners;
_drugRunners = _drugRunners - [_targetID];
_drugRunners = _drugRunners + [_start];
AP_drug_end = missionNamespace getVariable(format["drugrunner_%1", _targetID]);
AP_drug_start = _target;
private _totalDistance = AP_drug_start distance AP_drug_end;
private _timer = time + (floor(((AP_drug_start distance AP_drug_end) * (0.3 / 1000)) * 60)) + 60;
_timer =
if (_timer < (time + 180)) then[{time + 180}, {_timer}];
private _startTime = time;
private _instanceID = floor(random 999999);
private _startLogTime = time; [
    ["-AIRDRUGRUNNER-", player, (profileName), format["Air Drug Runner Started (ID: %1), Start Port: %2, Start Pos: %3, Time To Collect: %4 minutes", _instanceID, _start, getPosATL player, ((_timer - 60) / 60)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
AP_drug_distanceTraveled = 0;
private _task = player createSimpleTask[format["Delivery_%1", _start]];
["DeliveryAssigned", ["Collect the drugs"]] call BIS_fnc_showNotification;
private _notice = format["Bring the plane to the drug runner airfield at location %1 and load it with the drugs. You have %2 minutes!", _targetID, floor((_timer - time) / 60)];
_task setSimpleTaskDescription[_notice, "Drug Running", "Drug Running"];
_task setSimpleTaskDestination(getPos AP_drug_end);
_task setTaskState "Assigned";
player setCurrentTask _task;
systemChat _notice;
[_notice, "basic"] spawn AP_fnc_handleMessage;
if (_informant) then {
    private _message = format["You receive word that a plane may land at Drug Runner Airfield %1 to pickup drugs within the next %2 minutes.", _targetID, floor((_timer - time) / 60)];
    [[_message, "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;};
(findDisplay 12 displayCtrl 51) ctrlAddEventHandler["Draw", {
    (_this select 0) drawLine[getPosATL player, getPosATL AP_drug_end, [0, 0, 1, 1]]}];
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _display = uiNameSpace getVariable["AP_progress", displayNull];
private _progressBar = _display displayCtrl 38201;
private _progressText = _display displayCtrl 38202;
_progressText ctrlSetText "Time to collect";
_progressBar progressSetPosition 1;
AP_drug_stage = 1;
private _completed =
while {(_timer - time) >= 0}
do {uiSleep 1;
    private _timeRemaining = toArray([_timer - time, "MM:SS"] call BIS_fnc_secondsToString);
    if ((_timeRemaining select 0) in [48]) then {_timeRemaining deleteAt 0};
    private _isSeconds = ((_timeRemaining select 0) in [48]);
    _timeRemaining = toString(_timeRemaining);
    _progressText ctrlSetText format["Time to collect: %1 %2", _timeRemaining, if (_isSeconds) then[{"seconds"}, {"minutes"}]];
    _progressBar progressSetPosition(1 - ((time - _startTime) / (_timer - _startTime)));
    private _success =
    if (AP_drug_stage isEqualTo 2) then {if (isNull _plane) exitWith {
            ["Your plane could not be found!", "basic"] spawn AP_fnc_handleMessage;
            AP_drug_stage = 1;
            false};
        if ((_plane distance AP_drug_end) > 50) exitWith {
            ["The supplied plane must be within 50 meters to load the drugs!", "basic"] spawn AP_fnc_handleMessage;
            AP_drug_stage = 1;
            false};
        true} else {false};
    if (_success) exitWith {[true, 0]};
    if (!alive player) exitWith {[false, 1]};
    if ((isNull _plane) || (!alive _plane)) exitWith {[false, 2]};
    if (AP_drug_stage isEqualTo 4) exitWith {[false, 3]};
    [false, 0];}; if !(_completed select 0) exitWith {systemChat "The smugglers keep the $15,000 you loaned them to cover their expenses";
    switch (_completed select 1) do {case 1: {
                ["DeliveryFailed", ["You failed to collect the drugs because you died!"]] call BIS_fnc_showNotification;};
        case 2: {["DeliveryFailed", ["Your vehicle has been destroyed. You've failed!"]] call BIS_fnc_showNotification;};
        case 3: {[
                    [0, 1, 2], "You've abandoned the job! The smugglers keep $3,000 from the money you loaned them."] call AP_fnc_broadcast;
                AP_atmcash = AP_atmcash + 12000;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
        default {["DeliveryFailed", ["You've taken too long to get the drugs. You've failed!"]] call BIS_fnc_showNotification;};
    }; 5 cutText["", "PLAIN"];
    _task setTaskState "Failed";
    player removeSimpleTask _task;
    AP_drug_stage = 0;
    if (!isNull _plane) then {while {!isNull _plane}
        do {uiSleep 1;
            if ({alive _x}
            count(crew _plane) isEqualTo 0) exitWith {deleteVehicle _plane;
                (findDisplay 12 displayCtrl 51) ctrlRemoveAllEventHandlers "Draw";};};};};
if (isNull _plane) exitWith {["Your plane could not be found!", "basic"] spawn AP_fnc_handleMessage};
if ((_plane distance AP_drug_end) > 50) exitWith {
    ["The supplied plane must be within 50 meters to load the drugs!", "basic"] spawn AP_fnc_handleMessage};
AP_drug_distanceTraveled = AP_drug_distanceTraveled + ((getPosATL AP_drug_start) distance2D(getPosATL AP_drug_end));
private _collectID = _targetID;
AP_drug_start = AP_drug_end;
_targetID = selectRandom _drugRunners;
AP_drug_end = missionNamespace getVariable format["drugrunner_%1", _targetID];
_totalDistance = _totalDistance + (AP_drug_start distance AP_drug_end);
_timer = time + (floor(((AP_drug_start distance AP_drug_end) * (0.3 / 1000)) * 60)) + 60;
_timer =
if (_timer < (time + 180)) then[{time + 180}, {_timer}];
_startTime = time; [
    ["-AIRDRUGRUNNER-", player, (profileName), format["Air Drug Runner Collected (ID: %1), Collect Port: %2, Collect Pos: %3, Time To Deliver: %4 minutes", _instanceID, _collectID, getPosATL player, ((_timer - 60) / 60)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
_task setTaskState "Succeeded";
player removeSimpleTask _task;
_task = player createSimpleTask[format["Delivery_%1", _targetID]];
systemChat "The aircraft is now loaded with drugs. Don't get caught!";
["DeliveryAssigned", ["Deliver drugs to smuggler"]] call BIS_fnc_showNotification;
_notice = format["Return the plane, with the drugs, to location %1. You have %2 minutes.", _targetID, floor((_timer - time) / 60)];
_task setSimpleTaskDescription[_notice, "Drug Running", " Drug Running"];
_task setSimpleTaskDestination(getPos AP_drug_end);
_task setTaskState "Assigned";
player setCurrentTask _task;
systemChat _notice;
[_notice, "basic"] spawn AP_fnc_handleMessage;
_plane setVariable["AP_drugrunning", true, true];
if (_informant) then {
    private _message = format["You receive word that a plane laden with drugs may land at Drug Runner Airfield %1 within the next %2 minutes.", _targetID, floor((_timer - time) / 60)];
    [[_message, "copalert"], "AP_fnc_handleMessage", west] spawn AP_fnc_MP;};
if (isNull _display) then {5 cutRsc["AP_progress", "PLAIN"]};
_display = uiNameSpace getVariable["AP_progress", displayNull];
_completed =
while {(_timer - time) >= 0}
do {uiSleep 1;
    private _timeRemaining = toArray([_timer - time, "MM:SS"] call BIS_fnc_secondsToString);
    if ((_timeRemaining select 0) in [48]) then {_timeRemaining deleteAt 0};
    private _isSeconds = ((_timeRemaining select 0) in [48]);
    _timeRemaining = toString(_timeRemaining);
    _progressText ctrlSetText format["Time to deliver: %1 %2", _timeRemaining, if (_isSeconds) then[{"seconds"}, {"minutes"}]];
    _progressBar progressSetPosition(1 - ((time - _startTime) / (_timer - _startTime)));
    private _success =
    if (AP_drug_stage isEqualTo 3) then {if (isNull _plane) exitWith {
            ["Your plane could not be found!", "basic"] spawn AP_fnc_handleMessage;
            AP_drug_stage = 2;
            false};
        if ((_plane distance AP_drug_end) > 50) exitWith {
            ["The supplied plane must be within 50 meters to load the drugs!", "basic"] spawn AP_fnc_handleMessage;
            AP_drug_stage = 2;
            false};
        true} else {false};
    if (_success) exitWith {[true, 0]};
    if (!alive player) exitWith {[false, 1]};
    if ((isNull _plane) || (!alive _plane)) exitWith {[false, 2]};
    if (AP_drug_stage isEqualTo 4) exitWith {[false, 3]};
    [false, 0];}; if !(_completed select 0) exitWith {systemChat "The smugglers keep the $15,000 you loaned them to cover their expenses!";
    switch (_completed select 1) do {case 1: {
                ["DeliveryFailed", ["You failed to deliver the drugs because you died!"]] call BIS_fnc_showNotification;};
        case 2: {["DeliveryFailed", ["Your vehicle has been destroyed. You've failed!"]] call BIS_fnc_showNotification;};
        case 3: {[
                    [0, 1, 2], "You've abandoned the job! The smugglers keep $3,000 from the money you loaned them."] call AP_fnc_broadcast;
                AP_atmcash = AP_atmcash + 12000;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
        default {["DeliveryFailed", ["You've taken too long to deliver the drugs. You've failed!"]] call BIS_fnc_showNotification;};
    }; 5 cutText["", "PLAIN"];
    _task setTaskState "Failed";
    player removeSimpleTask _task;
    AP_drug_stage = 0;
    if (!isNull _plane) then {while {!isNull _plane}
        do {uiSleep 1;
            if ({alive _x}
            count(crew _plane) isEqualTo 0) exitWith {deleteVehicle _plane;
                (findDisplay 12 displayCtrl 51) ctrlRemoveAllEventHandlers "Draw";};};};};
private _reward = (floor(_totalDistance * 0.8));
if (24 in AP_infamy_talents && license_civ_rebel) then {_reward = _reward * 1.05};
AP_cash = AP_cash + _reward;
AP_cashCacheB = ((AP_cash / 4) + 9);
AP_atmcash = AP_atmcash + 15000;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[format["You were rewarded $%1 for completing the Drug Runner mission and $%2 was transferred back to your bank account.", [_reward] call AP_fnc_numberText, [15000] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
AP_side_exp = AP_side_exp + 10;
["drugrunnerplanes", 1] call AP_fnc_statArrUpdate;
5 cutText["", "PLAIN"];
deleteVehicle _plane;
(findDisplay 12 displayCtrl 51) ctrlRemoveAllEventHandlers "Draw";
_task setTaskState "Succeeded";
player removeSimpleTask _task;
AP_drug_stage = 0;
if ((((AP_lastPersistVar select 0) isEqualTo "AP_drugtrace") && ((AP_lastPersistVar select 1) < time)) || !((AP_lastPersistVar select 0) isEqualTo "AP_drugtrace")) then {
    [[getPlayerUID player, "AP_drugtrace", time], "APS_fnc_varPersist", 2] spawn AP_fnc_MP;
    AP_lastPersistVar = ["AP_drugtrace", time + 30];};
[15, true] call AP_fnc_addInfamy;
["action", "completedrugrunner", 1] call AP_fnc_handleQuest;
AP_drug_distanceTraveled = AP_drug_distanceTraveled + ((getPosATL AP_drug_start) distance2D(getPosATL AP_drug_end)); [
    ["-AIRDRUGRUNNER-", player, (profileName), format["Air Drug Runner Completed (ID: %1), Complete Port: %2, Complete Pos: %3, Took: %4 minutes, Time Left To Deliver: %5 minutes, Total Distance Traveled: %6 meters, Payment: $%7", _instanceID, _targetID, getPosATL player, ((time - _startLogTime) / 60), ((_timer - time) / 60), [AP_drug_distanceTraveled] call AP_fnc_numberText, [_reward] call AP_fnc_numberText]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;