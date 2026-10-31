params[["_item", "", [""]], "_cannaData"];
if (_item isEqualTo "") exitWith {};
if !(_item in ["createVape", "createGlassRig", "createBongRig", "createJoint"]) then {closeDialog 0;};
switch (_item) do {case ("canna_papers"): {private _exit = false;
            private _chosenItem = ""; {private _xItem = _x;
                private _amount = missionNamespace getVariable(format["AP_inv_%1", _xItem]);
                if (_amount > 0) then {
                    private _action = [format["Would you like to roll your %1 with %2 to make %3 Rolled Joint(s)?", ["getName", _xItem] call AP_fnc_virtItemCfg, "RAW Papers", _amount], "RAW Papers Stoner", "Roll It", "Hell Nah"] call BIS_fnc_GUIMessage;
                    if (_action) exitWith {_exit = true;
                        _chosenItem = _xItem;};};}
            forEach["cannas_3", "cannai_3", "marijuanam", "marijuana"];
            if ((_chosenItem isEqualTo "") || !(_exit)) exitWith {
                ["You either didn't have any flower to roll with or didn't choose!", "basic"] spawn AP_fnc_handleMessage};
            if !([false, _chosenItem, 1] call AP_fnc_handleInv) exitWith {
                [format["You didn't have a %1 to roll with!", ["getName", _chosenItem] call AP_fnc_virtItemCfg], "basic"] spawn AP_fnc_handleMessage
            };
            [player, "", "", "canna_joint"] spawn AP_fnc_processAction;}; case ("canna_bong"): {private _exit = false;
                private _chosenItem = ""; {private _xItem = _x;
                    private _amount = missionNamespace getVariable(format["AP_inv_%1", _xItem]);
                    if (_amount > 0) then {
                        private _action = [format["Would you like to smoke %1 from your Glass Bong?", ["getName", _xItem] call AP_fnc_virtItemCfg], "420 Stoner", "Blaze It", "No"] call BIS_fnc_GUIMessage;
                        if (_action) exitWith {_exit = true;
                            _chosenItem = _xItem;};};}
                forEach["cannas_3", "cannai_3", "marijuanam", "marijuana"];
                if ((_chosenItem isEqualTo "") || !(_exit)) exitWith {
                    ["You either didn't have any flower to smoke or didn't choose!", "basic"] spawn AP_fnc_handleMessage};
                if !([false, _chosenItem, 1] call AP_fnc_handleInv) exitWith {};
                ["smokeWeedBongOrRig", [false]] spawn AP_fnc_cannabisItems;};
        case ("canna_rig"): {private _exit = false;
                private _chosenItem = ""; {private _xItem = _x;
                    private _amount = missionNamespace getVariable(format["AP_inv_%1", _xItem]);
                    if (_amount > 0) then {
                        private _action = [format["Would you like to smoke %1 from your Glass Rig?", ["getName", _xItem] call AP_fnc_virtItemCfg], "3000 Degree Dab", "Yes", "No"] call BIS_fnc_GUIMessage;
                        if (_action) exitWith {_exit = true;
                            _chosenItem = _xItem;};};}
                forEach["canna_dab"];
                if ((_chosenItem isEqualTo "") || !(_exit)) exitWith {
                    ["You either didn't have any Golden Wax to smoke or didn't choose!", "basic"] spawn AP_fnc_handleMessage};
                if !([false, _chosenItem, 1] call AP_fnc_handleInv) exitWith {};
                ["smokeWeedBongOrRig", [true]] spawn AP_fnc_cannabisItems;};
        case ("smokeWeedJointOrVape"): {_cannaData params[["_isVape", false, [false]], ["_jointType", "", [""]]];
                private _exit = false;
                if !(_isVape) then {if !([false, _jointType, 1] call AP_fnc_handleInv) exitWith {_exit = true};};
                if (_exit) exitWith {
                    [format["You didn't have a %1 to smoke!", ["getName", _jointType] call AP_fnc_virtItemCfg], "basic"] spawn AP_fnc_handleMessage
                };
                private _toSend = allPlayers select {player distance _x <= 300};
                player setVariable["AP_cannabisUsing", true];
                if (_isVape) then {[["createVape", [player, "cannabisvaperip"]], "AP_fnc_cannabisItems", _toSend] spawn AP_fnc_MP;
                } else {[["createJoint", [player, "cannabisjointrip"]], "AP_fnc_cannabisItems", _toSend] spawn AP_fnc_MP;
                    ["action", "smokeprerolledjoint", 1] call AP_fnc_handleQuest;};
                player forceWalk true;
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _display = uiNameSpace getVariable["AP_progress", displayNull];
                private _progressBar = _display displayCtrl 38201;
                private _progressText = _display displayCtrl 38202;
                private _increment = 1;
                private _totalTime =
                if (_isVape) then {8} else {12};
                private _currentPoint = 0;
                private _loopDelay = _totalTime / floor(100 / _increment);
                private _text =
                if (_isVape) then {"Ripping Dab Pen"} else {"Chiefing Big Doink"};
                private _startCount = 0;
                _progressBar progressSetPosition _startCount;
                _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
                private _isSuccess =
                for "_i"
                from 0 to 1 step 0 do {uiSleep _loopDelay;
                    if (isNull _progressBar) exitWith {
                        ["Your bong/rig fell out of your hands and broke into millions of pieces!", "basic"] spawn AP_fnc_handleMessage;
                        false;};
                    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                    _progressBar progressSetPosition _currentPoint;
                    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                    if (_currentPoint >= 1) exitWith {true};
                    false;}; 5 cutText["", "PLAIN"];
                player forceWalk false;
                AP_drug_level = selectMin[AP_drug_level + 0.005, 1];
                if (_isVape) then {systemChat "I can't tell if that was nicotine or wax...";} else {
                    systemChat "WOOOOO, This doink is straight zaza fire!";
                    ["cannabisReduceSwayEffect", [60]] spawn AP_fnc_cannabisItems;};
                [] call AP_fnc_hudUpdate;
                [player] call AP_fnc_painkillers;
                ["cannabis"] call AP_fnc_drugUsed;
                [_isVape] spawn {params["_isVape"];
                    if (_isVape) then {player setAnimSpeedCoef 0.5;
                        "radialBlur"
                        ppEffectEnable true;
                        titleText["Who the hell put nicotine in my dab pen?!", "PLAIN"];
                        uiSleep 5;
                        "radialBlur"
                        ppEffectEnable false;
                        titleText["", "PLAIN"];
                        player setAnimSpeedCoef 1;} else {
                        "radialBlur"
                        ppEffectEnable true;
                        titleText["Cheech and Chong would be proud, WOOOOO!", "PLAIN"];
                        uiSleep 5;
                        "radialBlur"
                        ppEffectEnable false;
                        titleText["", "PLAIN"];};};
                player setVariable["AP_cannabisUsing", false];
                if !(AP_smoking) then {AP_smoking = true; [[player], "AP_fnc_attachSmoke", allPlayers select {
                            player distance _x <= 2000}] spawn AP_fnc_MP;
                    uiSleep 300;
                    AP_smoking = false;};};
        case ("smokeWeedBongOrRig"): {_cannaData params[["_isDabRig", false, [false]]];
                private _toSend = allPlayers select {player distance _x <= 300};
                player setVariable["AP_cannabisUsing", true];
                if (_isDabRig) then {[
                        ["createGlassRig", [player, "cannabisbongrip"]], "AP_fnc_cannabisItems", _toSend] spawn AP_fnc_MP;} else {[
                        ["createBongRig", [player, "cannabisbongrip"]], "AP_fnc_cannabisItems", _toSend] spawn AP_fnc_MP;};
                player forceWalk true;
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _display = uiNameSpace getVariable["AP_progress", displayNull];
                private _progressBar = _display displayCtrl 38201;
                private _progressText = _display displayCtrl 38202;
                private _increment = 1;
                private _totalTime =
                if (_isDabRig) then {12} else {12};
                private _currentPoint = 0;
                private _loopDelay = _totalTime / floor(100 / _increment);
                private _text =
                if (_isDabRig) then {"Heating Wax to 9000 Degrees"} else {"Taking Massive Bong Rip"};
                private _startCount = 0;
                _progressBar progressSetPosition _startCount;
                _progressText ctrlSetText format["%1 (%2%3)", _text, _startCount, "%"];
                private _isSuccess =
                for "_i"
                from 0 to 1 step 0 do {uiSleep _loopDelay;
                    if (isNull _progressBar) exitWith {
                        ["Your bong/rig fell out of your hands and broke into millions of pieces!", "basic"] spawn AP_fnc_handleMessage;
                        false;};
                    _currentPoint = (progressPosition _progressBar) + (_increment / 100);
                    _progressBar progressSetPosition _currentPoint;
                    _progressText ctrlSetText format["%1 (%2%3)", _text, round(_currentPoint * 100), "%"];
                    if (_currentPoint >= 1) exitWith {true};
                    false;}; 5 cutText["", "PLAIN"];
                player forceWalk false;
                AP_drug_level = selectMin[AP_drug_level + 0.005, 1];
                if (_isDabRig) then {systemChat "Waaaaaaaaa, This Golden Wax is the fucking bees knees man!";
                    ["cannabisReduceSwayEffect", [360]] spawn AP_fnc_cannabisItems;} else {
                    systemChat "Damn, I'm fucking stoned! Where the damn munchies from Red Burger at!?";
                    ["cannabisReduceSwayEffect", [180]] spawn AP_fnc_cannabisItems;};
                [] call AP_fnc_hudUpdate;
                [player] call AP_fnc_painkillers;
                ["cannabis"] call AP_fnc_drugUsed;
                player setVariable["AP_cannabisUsing", false];
                [_isDabRig, _toSend] spawn {params["_isDabRig", "_toSend"];
                    if (_isDabRig) then {player setAnimSpeedCoef 0.5;
                        "radialBlur"
                        ppEffectEnable true;
                        titleText["SHEESH BRO! MY HEAD IS RUSHING!", "PLAIN"]; [
                            [player, "cannabisohyeah"], "AP_fnc_playSound", _toSend] spawn AP_fnc_MP;
                        uiSleep 15;
                        "radialBlur"
                        ppEffectEnable false;
                        titleText["", "PLAIN"];
                        player setAnimSpeedCoef 1;} else {
                        "radialBlur"
                        ppEffectEnable true;
                        titleText["HOLY SHIT!!! SKY HIGH TO CLOUD 9!", "PLAIN"];
                        uiSleep 3;
                        "radialBlur"
                        ppEffectEnable false;
                        titleText["", "PLAIN"];};};
                if (!(AP_smoking) && !_isDabRig) then {AP_smoking = true; [[player], "AP_fnc_attachSmoke", allPlayers select {
                            player distance _x <= 2000}] spawn AP_fnc_MP;
                    uiSleep 300;
                    AP_smoking = false;};};
        case ("cannabisReduceSwayEffect"): {_cannaData params[["_timeDelay", -1, [0]]];
                if (AP_revive_fatigue > 0) exitWith {
                    ["This item has no effect due to revive fatigue.", "basic"] spawn AP_fnc_handleMessage;};
                if (AP_loweredSwayEnabled) exitWith {
                    ["This item has no effect due to you already using it. Wait for the effects to wear off", "basic"] spawn AP_fnc_handleMessage;
                };
                private _plb_player = player;
                private _startTime = time;
                _plb_player setCustomAimCoef 0.22;  // LoonyBin: 12% under the 0.25 default baseline
                AP_loweredSwayEnabled = true; [
                    [0, 1], format["Your sway has been reduced by 12%1 for %2 minute(s)", "%", round(_timeDelay / 60)]
                ] spawn AP_fnc_broadcast;
                [_plb_player, _startTime, _timeDelay] spawn {params["_plb_player", "_startTime", "_timeDelay"];
                    waitUntil {uiSleep 1;
                        (!alive player || ((time - _startTime) > _timeDelay))};
                    AP_loweredSwayEnabled = false;
                    _plb_player setCustomAimCoef 0.25;  // LoonyBin: restore to the 0.25 default baseline (was 0.7)
                    ["The effects of that fire THC has worn off", "basic"] spawn AP_fnc_handleMessage};};
        case ("createJoint"): {_cannaData params[["_playerObj", objNull, [objNull]], ["_soundString", "", [""]]];
                private _plb_obj = _playerObj;
                private _jointObject = "AntidoteKit_01_F"
                createVehicleLocal[0, 0, 0];
                _jointObject attachTo[_plb_obj, [0.004, 0.188, 1.631]];
                _jointObject setVectorDirAndUp[[0.999, 0.039, 0], [0, 0, 1]];
                private _fireParticleSource = "#particlesource"
                createVehicleLocal[0, 0, 0];
                _fireParticleSource setParticleParams[["\A3\data_f\ParticleEffects\Universal\Universal", 16, 10, 32, 1], "", "Billboard", 2, 0.25, [0, 0, 0], [0, 0, 0.7], 0, 0.05, 0.04, 0.05, [0.02, 0], [
                    [1, 1, 1, -100], [1, 1, 1, -100], [0, 0, 0, 0]], [1], 0, 0, "", "", "", 0, false, 0, [[0, 0, 0, 0]]];
                _fireParticleSource setParticleRandom[0.15, [0.01, 0.01, 0.15], [0.04, 0.04, 0.2], 0, 0.04, [0.1, 0.1, 0.1, 0], 0, 0, 1, 0];
                _fireParticleSource setParticleCircle[0, [0, 0, 0]];
                _fireParticleSource setParticleFire[2, 0.1, 0.1];
                _fireParticleSource setDropInterval 0.022;
                _fireParticleSource setParticleFire[2, 0, 0];
                _fireParticleSource setDropInterval 0.022;
                _fireParticleSource attachTo[_jointObject, [-0.1, -0.02, 0.109]];
                _fireParticleSource setVectorDirAndUp[[0, 1, 0], [0, 0, 1]];
                _jointObject enableSimulation false;
                [_playerObj, _soundString] spawn AP_fnc_playSound;
                if (round(random(100)) <= 33) then {[_playerObj, "cannabisweedevery"] spawn AP_fnc_playSound;};
                uiSleep 12; {deleteVehicle _x}
                forEach[_jointObject, _fireParticleSource];};
        case ("createBongRig"): {_cannaData params[["_playerObj", objNull, [objNull]], ["_soundString", "", [""]]]; [
                    ["action", "bongrip", 1], "AP_fnc_handleQuest", _playerObj] spawn AP_fnc_MP;
                private _plb_obj = _playerObj;
                private _bongObject = "Land_AirHorn_01_F"
                createVehicleLocal[0, 0, 0];
                _bongObject attachTo[_plb_obj, [-0.003, 0.203, 1.54]];
                _bongObject setVectorDirAndUp[[-0.036, -0.803, -0.595], [0.007, 0.596, -0.803]];
                private _budObject = "Land_FlowerPot_01_Flower_F"
                createVehicleLocal[0, 0, 0];
                _budObject attachTo[_plb_obj, [0.003, 0.285, 1.51]];
                _budObject setVectorDirAndUp[[0, 0.589, -0.808], [0, 0.808, 0.589]];
                _budObject setObjectScale 0.05;
                private _fireParticleSource = "#particlesource"
                createVehicleLocal[0, 0, 0];
                _fireParticleSource setParticleParams[["\A3\data_f\ParticleEffects\Universal\Universal", 16, 10, 32, 1], "", "Billboard", 2, 0.15, [0, 0, 0], [0, 0, 0.7], 0, 0.05, 0.04, 0.05, [0.02, 0], [
                    [1, 1, 1, -100], [1, 1, 1, -100], [0, 0, 0, 0]], [1], 0, 0, "", "", "", 0, false, 0, [[0, 0, 0, 0]]];
                _fireParticleSource setParticleRandom[0.15, [0.01, 0.01, 0.15], [0.04, 0.04, 0.2], 0, 0.04, [0.1, 0.1, 0.1, 0], 0, 0, 1, 0];
                _fireParticleSource setParticleCircle[0, [0, 0, 0]];
                _fireParticleSource setParticleFire[2, 0.1, 0.1];
                _fireParticleSource setDropInterval 0.022;
                _fireParticleSource setParticleFire[2, 0, 0];
                _fireParticleSource setDropInterval 0.022;
                _fireParticleSource attachTo[_plb_obj, [-0.002, 0.283, 1.664]];
                _fireParticleSource setVectorDirAndUp[[0, 1, 0], [0, 0, 1]]; {_x enableSimulation false}
                forEach[_bongObject, _budObject];
                [_playerObj, _soundString] spawn AP_fnc_playSound;
                if (round(random(100)) <= 33) then {[_playerObj, "cannabisweedevery"] spawn AP_fnc_playSound;};
                uiSleep 12; {deleteVehicle _x}
                forEach[_bongObject, _budObject, _fireParticleSource];};
        case ("createGlassRig"): {_cannaData params[["_playerObj", objNull, [objNull]], ["_soundString", "", [""]]];
                private _plb_obj = _playerObj;
                private _rigObject = "EauDeCombat_01_F"
                createVehicleLocal[0, 0, 0];
                _rigObject attachTo[_plb_obj, [0.001, 0.166, 1.565]];
                _rigObject setVectorDirAndUp[[-0.165, -0.806, -0.569], [0, -0.577, 0.817]];
                private _bowlObject = "Land_FoodContainer_01_White_F"
                createVehicleLocal[0, 0, 0];
                _bowlObject attachTo[_plb_obj, [0.007, 0.219, 1.554]];
                _bowlObject setVectorDirAndUp[[-0.069, 0.705, -0.705], [0.069, 0.709, 0.702]];
                _bowlObject setObjectScale 0.06;
                private _fireParticleSource = "#particlesource"
                createVehicleLocal[0, 0, 0];
                _fireParticleSource setParticleParams[["\A3\data_f\ParticleEffects\Universal\Universal", 16, 10, 32, 1], "", "Billboard", 2, 0.15, [0, 0, 0], [0, 0, 0.7], 0, 0.05, 0.04, 0.05, [0.02, 0], [
                    [1, 1, 1, -100], [1, 1, 1, -100], [0, 0, 0, 0]], [1], 0, 0, "", "", "", 0, false, 0, [[0, 0, 0, 0]]];
                _fireParticleSource setParticleRandom[0.15, [0.01, 0.01, 0.15], [0.04, 0.04, 0.2], 0, 0.04, [0.1, 0.1, 0.1, 0], 0, 0, 1, 0];
                _fireParticleSource setParticleCircle[0, [0, 0, 0]];
                _fireParticleSource setParticleFire[2, 0.1, 0.1];
                _fireParticleSource setDropInterval 0.022;
                _fireParticleSource setParticleFire[2, 0, 0];
                _fireParticleSource setDropInterval 0.022;
                _fireParticleSource attachTo[_plb_obj, [0.001, 0.258, 1.681]];
                _fireParticleSource setVectorDirAndUp[[0, 1, 0], [0, 0, 1]]; {_x enableSimulation false}
                forEach[_rigObject, _bowlObject];
                [_playerObj, _soundString] spawn AP_fnc_playSound;
                if (round(random(100)) <= 33) then {[_playerObj, "cannabisweedevery"] spawn AP_fnc_playSound;};
                uiSleep 12; {deleteVehicle _x}
                forEach[_rigObject, _bowlObject, _fireParticleSource];};
        case ("createVape"): {_cannaData params[["_playerObj", objNull, [objNull]], ["_soundString", "", [""]]];
                private _plb_obj = _playerObj;
                private _vapeObject = "Land_GasTank_02_F"
                createVehicleLocal[0, 0, 0];
                _vapeObject attachTo[_plb_obj, [0.061, 0.152, 1.568]];
                _vapeObject setVectorDirAndUp[[0.506, -0.862, -0.024], [-0.652, -0.401, 0.644]];
                _vapeObject setObjectScale 0.07;
                _vapeObject enableSimulation false;
                [_playerObj, _soundString] spawn AP_fnc_playSound;
                if (round(random(100)) <= 33) then {[_playerObj, "cannabisweedevery"] spawn AP_fnc_playSound;};
                uiSleep 9; {deleteVehicle _x}
                forEach[_vapeObject];};};