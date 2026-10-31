if !(AP_effSide isEqualTo civilian) exitWith {
    ["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/>Time trials are currently only available for civilians", "shortwarning"] spawn AP_fnc_handleMessage;
};
params[["_caseType", "", [""]], ["_timeTrialID", -1, [0]], ["_failedText", "", [""]]];
private _handleWaypoint = {params["_playerObj", "_posATL", "_text", "_priority", "_imageType"];
    _imageType =
    switch (_imageType) do {case 0: {"a3\ui_f\data\map\markers\military\flag_ca.paa"};
        case 1: {"a3\ui_f\data\map\mapcontrol\waypoint_ca.paa"};
        case 2: {"a3\ui_f\data\igui\cfg\actions\takeflag_ca.paa"};
        default {"a3\ui_f\data\map\markers\military\flag_ca.paa"};}; private _color =
    if (_priority == 0) then {[1, 1, 1, 0.5]} else {[1, 1, 1, 0.2]};
    private _wpHandler = addMissionEventHandler["Draw3D", format["drawIcon3D ['%3', %1, %2, 1.1, 1.1, 0, '', 1, 0.05, 'TahomaB', 'center', true];", _color, _posATL, _imageType]];
    if (_priority == 0 && _text != "") then {["timeTrial", [_text]] call BIS_fnc_showNotification;};
    private _wpTask = _playerObj createSimpleTask["Time Trial"];
    _wpTask setSimpleTaskDescription[_text, "Time Trials", "Time Trials"];
    _wpTask setSimpleTaskDestination _posATL;
    _wpTask setTaskState "Assigned";
    _playerObj setCurrentTask _wpTask;
    if (_priority == 0) then {waitUntil {uiSleep 1;
            AP_timeTrialRemovePrimaryWP || !(_playerObj getVariable['AP_timeTrialActive', false])};
        AP_timeTrialRemovePrimaryWP = false;} else {waitUntil {uiSleep 1;
            AP_timeTrialRemoveSecondaryWP || !(_playerObj getVariable['AP_timeTrialActive', false])};
        AP_timeTrialRemoveSecondaryWP = false;};
    removeMissionEventHandler["Draw3D", _wpHandler];
    _wpTask setTaskState "Succeeded";
    uiSleep(0.3);
    _playerObj removeSimpleTask _wpTask;};
private _handleFailed = {params["_playerObj", "_failedText"];
    AP_timeTrialRemovePrimaryWP = true;
    AP_timeTrialRemoveSecondaryWP = true;
    [format["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/>You have failed the time trial, %1<br/>", _failedText], "timetrialevent"] spawn AP_fnc_handleMessage;
    player setVariable['AP_timeTrialActive', false, true];};
switch (_caseType) do {case ("start"): {if (player getVariable['AP_timeTrialActive', false]) exitWith {
                ["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/>You already have an active time trial and therefor cannot start a new one ", "shortwarning"] spawn AP_fnc_handleMessage;
            };
            if (_timeTrialID == -1) exitWith {
                ["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/>Something went wrong, please send this message to a developer ", "shortwarning"] spawn AP_fnc_handleMessage;
            };
            AP_timeTrialRemovePrimaryWP = false;
            AP_timeTrialRemoveSecondaryWP = false;
            private _timeTrialCfg = ["getTimeTrialByID", _timeTrialID] call AP_fnc_timeTrialCfg;
            _timeTrialCfg params["_id", "_carCFG", "_carPos", "_carD", "_waypoints", "_waypointRadius", "_startWaypointRadius"];
            private _checkNearCars = nearestObjects[_carPos, ["landVehicle", "Air", "Ship"], 4] select 0;
            if (!isNil "_checkNearCars") exitWith {
                ["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/>There is currently already a vehicle on the spawnpoint ", "shortwarning"] spawn AP_fnc_handleMessage;
            };
            player setVariable['AP_timeTrialActive', true, true];
            [player, _id] remoteExec["APS_fnc_createTimeTrialVehSRV", 2];   // server looks up car/pos/dir by course id
            [player, _carPos, "Get in the time trial vehicle", 0, 1] spawn _handleWaypoint;
            ["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/> Welcome to time trials! <br/><br/>A vehicle that is associated with the time trial has spawned <br/><br/>Quickly move over to the vehicle to start the time trial ", "timetrialevent"] spawn AP_fnc_handleMessage;
            waitUntil {sleep 1;
                !(isNull objectParent player) && (objectParent player) getVariable["AP_timeTrialVehicle", false] || !(player getVariable['AP_timeTrialActive', false]) || (_carPos distance2D player) > 150 || !(isNull(findDisplay 314)) || !(isNull(findDisplay 2900))
            };
            AP_timeTrialRemovePrimaryWP = true;
            if !(player getVariable['AP_timeTrialActive', false]) exitWith {
                [player, "due to you stopping your time trial"] spawn _handleFailed;};
            if ((_carPos distance2D player) > 150) exitWith {
                [player, "due to moving to far away from the start vehicle"] spawn _handleFailed;};
            if (!(isNull(findDisplay 314)) || !(isNull(findDisplay 2900))) exitWith {
                [player, "due to attempting to cheat the course"] spawn _handleFailed;};
            ["<t color='#FF0000' size='1.5' align='center'>Time Trials</t><br/><br/>You have succesfully entered your time trial vehicle, leaving your vehicle will result in failure. <br/><br/>now line up at the start hold there and await the countdown", "timetrialevent"] spawn AP_fnc_handleMessage;
            private _startWpPos = (_waypoints param[0]) param[2];
            [player, _startWpPos, "Move to the start and await the countdown", 0, 0] spawn _handleWaypoint;
            waitUntil {sleep 1;
                isNull objectParent player || (_startWpPos distance2D player) < _startWaypointRadius || (_startWpPos distance2D player) > 200 || !(isNull(findDisplay 314)) || !(isNull(findDisplay 2900))
            };
            if (isNull objectParent player) exitWith {[player, "due to leaving your vehicle"] spawn _handleFailed;};
            if ((_carPos distance2D player) > 200) exitWith {[player, "due to moving to far away from the start"] spawn _handleFailed;};
            if (!(isNull(findDisplay 314)) || !(isNull(findDisplay 2900))) exitWith {
                [player, "due to attempting to cheat the course"] spawn _handleFailed;};
            private _secondWpPos = (_waypoints param[1]) param[2];
            [player, _secondWpPos, "", 1, 1] spawn _handleWaypoint;
            private _succes = false;
            private _countDown = 4;
            for "_i"
            from 0 to 1 step 0 do {if (isNull objectParent player) exitWith {[player, "due to leaving your vehicle"] spawn _handleFailed;};
                if !(player getVariable['AP_timeTrialActive', false]) exitWith {
                    [player, "due to stopping your time trial"] spawn _handleFailed;};
                if (!(isNull(findDisplay 314)) || !(isNull(findDisplay 2900))) exitWith {
                    [player, "due to attempting to cheat the course"] spawn _handleFailed;};
                if (!isNull(isVehicleCargo(objectParent player))) exitWith {
                    [player, "due to attempting to cheat the course"] spawn _handleFailed;};
                if (!isNull(ropeAttachedTo(objectParent player))) exitWith {
                    [player, "due to attempting to cheat the course"] spawn _handleFailed;};
                if ((_startWpPos distance2D player) > 200) exitWith {
                    [player, "due to moving to far away from the start"] spawn _handleFailed;};
                if ((_startWpPos distance2D player) < _startWaypointRadius) then {
                    if ((speed(objectParent player)) < 1 && (speed(objectParent player)) > -1) then {_countDown = _countDown - 1;
                        if (_countDown > 0) then {["timeTrialFast", [(format["%1", _countDown])]] call BIS_fnc_showNotification;};} else {
                        _countDown = 4;};
                    if (_countDown <= 0) then {_succes = true};};
                if (_succes) exitWith {};
                uiSleep 1;}; AP_timeTrialRemovePrimaryWP = true;
            if !(_succes) exitWith {};
            ["timeTrial", ["Go!"]] call BIS_fnc_showNotification;
            private _checkpoints = _waypoints select {_x param[1] == 1};
            private _finish = _waypoints param[_waypoints findIf {2 isEqualTo(_x select 1)}];
            private _timer = 0;
            private _checkpointCounter = 0;
            private _isSetWp = false;
            private _succes = false;
            for "_i"
            from 0 to 1 step 0 do {if (isNull objectParent player) exitWith {[player, "due to leaving your vehicle"] spawn _handleFailed;};
                if !(player getVariable['AP_timeTrialActive', false]) exitWith {
                    [player, "due to stopping your time trial"] spawn _handleFailed;};
                if (!(isNull(findDisplay 314)) || !(isNull(findDisplay 2900))) exitWith {
                    [player, "due to attempting to cheat the course"] spawn _handleFailed;};
                if (_timer > 9999) exitWith {[player, "due to running out of time"] spawn _handleFailed;};
                if (!isNull(isVehicleCargo(objectParent player))) exitWith {
                    [player, "due to attempting to cheat the course"] spawn _handleFailed;};
                if (!isNull(ropeAttachedTo(objectParent player))) exitWith {
                    [player, "due to attempting to cheat the course"] spawn _handleFailed;};
                private _primaryCheckpoint =
                if !(_checkpoints param[_checkpointCounter, []] isEqualTo[]) then {_checkpoints param[_checkpointCounter]} else {_finish};
                private _secondaryCheckpoint =
                if !(_checkpoints param[_checkpointCounter + 1, []] isEqualTo[]) then {_checkpoints param[_checkpointCounter + 1]} else {
                    _finish};
                if (((_primaryCheckpoint param[2]) distance2D player) > 2000) exitWith {
                    [player, "due to leaving the tracks"] spawn _handleFailed;};
                if !(_isSetWp) then {AP_timeTrialRemoveSecondaryWP = true;
                    _isSetWp = true;
                    [player, _secondaryCheckpoint param[2], "", 1, 1] spawn _handleWaypoint;
                    [player, _primaryCheckpoint param[2], "", 0, 1] spawn _handleWaypoint;};
                if (((_primaryCheckpoint param[2]) distance2D player) < _waypointRadius) then {AP_timeTrialRemovePrimaryWP = true;
                    AP_timeTrialRemoveSecondaryWP = true;
                    if (_primaryCheckpoint param[1] == 2) exitWith {_succes = true};
                    _checkpointCounter = _checkpointCounter + 1;
                    ["timeTrial", [format["Checkpoint %1 passed", _checkpointCounter]]] call BIS_fnc_showNotification;
                    _primaryCheckpoint =
                    if !(_checkpoints param[_checkpointCounter, []] isEqualTo[]) then {_checkpoints param[_checkpointCounter]} else {
                        _finish};
                    _secondaryCheckpoint =
                    if !(_checkpoints param[_checkpointCounter + 1, []] isEqualTo[]) then {_checkpoints param[_checkpointCounter + 1]
                    } else {_finish};
                    if (_primaryCheckpoint param[1] != 2) then {if (_secondaryCheckpoint param[1] != 2) then {
                            [player, _secondaryCheckpoint param[2], "", 1, 1] spawn _handleWaypoint;} else {
                            [player, _secondaryCheckpoint param[2], "", 1, 2] spawn _handleWaypoint;};
                        [player, _primaryCheckpoint param[2], "", 0, 1] spawn _handleWaypoint;} else {
                        [player, _primaryCheckpoint param[2], "", 0, 2] spawn _handleWaypoint;};};
                if (_succes) exitWith {};
                _timer = _timer + 0.125;
                uiSleep 0.125;}; AP_timeTrialRemovePrimaryWP = true;
            AP_timeTrialRemoveSecondaryWP = true;
            if !(_succes) exitWith {};
            [player, _id, _carCFG, _timer] remoteExec["APS_fnc_timeTrialSRV", 2];
            uiSleep 2;
            player setVariable['AP_timeTrialActive', false, true];
            ["action", "dotimetrial", 1] spawn AP_fnc_handleQuest;}; case ("stop"): {AP_timeTrialRemovePrimaryWP = true;
                AP_timeTrialRemoveSecondaryWP = true;
                if (player getVariable['AP_timeTrialActive', false]) then {player setVariable['AP_timeTrialActive', false, true];};};};