params[["_caseType", "", [""]], "_govData"];
// SECURITY 2026-09-26: CfgRE allowedTargets=1 let ANY client remoteExec any case at anyone (-2 included):
// "electricChair" straps, kills and respawns every target, "configChanged" fakes a law announcement. Only two
// cases legitimately arrive remotely: "configChanged" from the SERVER (APS_fnc_govSystemSRV updateGovConfig,
// after it verifies the governor) and "electricChairEffects" (the condemned client -> players within 75m;
// sound/lights/message only). Every other case is a local call.
if (isRemoteExecuted && {!(_caseType isEqualTo "electricChairEffects" || {_caseType isEqualTo "configChanged" && {remoteExecutedOwner isEqualTo 2}})}) exitWith {};
switch (_caseType) do {case ("initGovClient"): {_govData params["_thisSelect29"];
            _thisSelect29 =
            if (_thisSelect29 isEqualTo[]) then {[false, false, false, false, 12391021, "ASSADFT3", -2200]} else {_thisSelect29};
            _thisSelect29 params["_isGov", "_isCandidate", "_hasVoted", "_hasPardoned", "_lastSessionID", "_lastElectionID", "_lastTimeConfigChanged"];
            private _newElection = !((SRV_governorData param[6, 0]) isEqualTo _lastElectionID);   // electedAt = per-term identity
            private _serverRestarted = !(AP_instance_id isEqualTo _lastSessionID);
            private _isGov = ((SRV_governorData param[0, "GovUID"]) isEqualTo(getPlayerUID player));
            private _hasPardoned =
            switch (true) do {case (!_hasPardoned && _serverRestarted): {false};
                case (_hasPardoned && !_serverRestarted): {true};
                case (_hasPardoned && _serverRestarted): {false};
                default {false};}; private _hasVoted =
            switch (true) do {case (!_hasVoted && _newElection): {false};
                case (_hasVoted && !_newElection): {true};
                case (_hasVoted && _newElection): {false};
                default {false};}; private _isCandidate =
            switch (true) do {case (!_isCandidate && _newElection): {false};
                case (_isCandidate && !_newElection): {true};
                case (_isCandidate && _newElection): {false};
                default {false};}; private _lastTimeConfigChanged =
            if (_serverRestarted) then {-2200} else {_lastTimeConfigChanged};
            AP_govTax set[0, _isGov];
            AP_govClientData = [_isGov, _isCandidate, _hasVoted, _hasPardoned, AP_instance_id, (SRV_governorData param[6, 0]), _lastTimeConfigChanged];
            // owner 2026-06-13: apply current weed legality on join. Markers are LOCAL and only configChanged
            // updates them (on change), so a fresh/JIP client must set the current state here.
            if (SRV_governorData param[3, false]) then {
                "Weed_p_2" setMarkerAlphaLocal 1;} else {
                "Weed_p_2" setMarkerAlphaLocal 0;};
        }; case ("newGovChosen"): {_govData params["_newGovData"];
                _newGovData params["_xPlayerUID", "_xPlayerName", "_voteCount"];
                ["GovMessage", [format["%1 has been elected into Office of %2!", _xPlayerName, worldName]]] call BIS_fnc_showNotification;
            };
        case ("updateConfig"): {_govData params["_updatedArray"];
                // owner 2026-06-13: pass player so the server can verify the caller IS the governor (security).
                // The server re-broadcasts "configChanged" once it has verified the caller (clients can't send it).
                [["updateGovConfig", [player, _updatedArray]], "APS_fnc_govSystemSRV", 2] spawn AP_fnc_MP;};
        case ("payGovernor"): {_govData params[["_moneyToSend", 0, [0]]];
                if (_moneyToSend <= 0) exitWith {};
                // owner 2026-06-13: tax now reliably funds the governor. Was gated behind a 15% RNG roll
                // (`random 100 <= 15`) so 85% of collected tax vanished -> the treasury barely filled. RNG
                // removed; cap raised to $5m so legit tax on big purchases isn't clipped. -> gang 50000.
                if (_moneyToSend > 5000000) then { _moneyToSend = 5000000 }; [
                    ["addTaxToCache", [_moneyToSend]], "APS_fnc_govSystemSRV", 2] spawn AP_fnc_MP;};
        case ("toggleGovBuildingLocks"): {_govData params["_govBuilding"];
                private _isLocked = _govBuilding getVariable["AP_buildingLocked", false];
                private _buildingName = getText(configFile >> "CfgVehicles" >> typeOf _govBuilding >> "displayName");
                private _numDoors = getNumber(configFile >> "CfgVehicles" >> typeOf _govBuilding >> "numberOfDoors");
                if (_isLocked) then {_isLocked = false;
                    [format["Unlocked all doors of the Governor Office", _buildingName], "basic"] spawn AP_fnc_handleMessage;} else {
                    _isLocked = true;
                    [format["Locked all doors of the Governor Office", _buildingName], "basic"] spawn AP_fnc_handleMessage;};
                _govBuilding setVariable["AP_buildingLocked", _isLocked, true];
                private _num =
                if (_isLocked) then {1} else {0};
                for "_i"
                from 1 to _numDoors do {_govBuilding setVariable[format["bis_disabled_Door_%1", _i], _num, true];
                    if (_isLocked) then {_govBuilding animate[format["door_%1_rot", _i], 0]; {_govBuilding animate[_x, 0]}
                        forEach(animationNames _govBuilding);};}; private _soundFile =
                if (_isLocked) then {"lock"} else {"unlock"};
                private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 10}; [
                    [player, _soundFile], "AP_fnc_playSound", _toSend, false, false] spawn AP_fnc_MP;};
        case ("configChanged"): {
                // owner 2026-06-13: payload is now [tax, weedLegal, sparLegal] (matches the law menu + server).
                _govData params["_updatedArray"];
                _updatedArray params[["_govTax", 0], ["_govIsWeedLegal", false], ["_govIsSparLegal", false]];
                if (_govIsWeedLegal) then {"Weed_p_2" setMarkerAlphaLocal 1;} else {"Weed_p_2" setMarkerAlphaLocal 0;};
                if !(isNull AP_govSpeaker) then {AP_govSpeaker say3D["govSpeaker", 1200];};
                private _weedText = ["Weed is now illegal", "Weed is now legal"] select _govIsWeedLegal;
                private _sparText = ["SPAR-16s are now illegal", "SPAR-16s are now legal"] select _govIsSparLegal;
                private _taxRate  = format["Sales tax is now %1%2", _govTax, "%"];
                [format["<t color='#FF0000'><t size='1.5'><t align='center'>Government Laws Changed<br/><br/></t></t></t>The Governor has changed the laws of %1!<br/><br/>%2<br/><br/>%3<br/><br/>%4", worldName, _taxRate, _weedText, _sparText], "shortwarning"] spawn AP_fnc_handleMessage;
            };
        case ("electricChairEffects"): {
                _govData params[["_plb_dmg", objNull, [objNull]], "_profileName", "_plb_pos", "_chair", "_posATL", "_zCoord", "_chairDirection"];
                // Any client can send this remotely: only play it for a real player near us (the sender picks players
                // within 75 m, then moves to the chair, hence the slack).
                if (!isPlayer _plb_dmg || {(_plb_dmg distance player) > 100}) exitWith {};
                _plb_dmg say3D["handcuffs", 100];
                [format["%1 will be executed by electric chair in 30 seconds!", _profileName]] spawn AP_fnc_handleMessage;
                uiSleep 30;
                _plb_dmg say3D["elechair", 1000];
                uiSleep 21;
                for "_i"
                from 1 to 7 do {private _radius = 1;
                    private _dir = _plb_dmg getDir AP_electricChair;
                    private _centre = getPosATL AP_electricChair;
                    private _pos = _centre getPos[_radius, _dir];
                    private _light = "#lightpoint"
                    createVehicleLocal _pos;
                    _light setPosATL(_pos vectorAdd[0, 0, 10]);
                    _light setLightDayLight true;
                    _light setLightBrightness 300;
                    _light setLightAmbient[0.05, 0.05, 0.1];
                    _light setlightcolor[1, 1, 2];
                    uiSleep 0.1;
                    _light setLightBrightness 0;
                    uiSleep(random 0.1);
                    for "_i"
                    from 0 to(3 + random 1) do {private _time = time + 0.1;
                        _light setLightBrightness(100 + random 100);
                        waituntil {time > _time};}; deleteVehicle _light;
                    uiSleep 2.5;};};
        case ("electricChair"): {[999, getPlayerUID player] call AP_fnc_wantedListAdd; [
                    [getPlayerUID player], "APS_fnc_wantedRemove", 2] spawn AP_fnc_MP;
                private _createCamera = {AP_electricChairCamera =
                    if (isNull AP_electricChairCamera) then {
                        "camera"
                        camCreate(getPosATL player)} else {AP_electricChairCamera};
                    waitUntil {!isNull AP_electricChairCamera};
                    private _distance = 4;
                    while {_distance > 1}
                    do {
                        if (!lineIntersects[ATLToASL(player modelToWorld[1, _distance, 2]), ATLToASL(player modelToWorld[0, 0, 1]), player]) exitWith {};
                        _distance = _distance - 0.5;}; AP_electricChairCamera camSetTarget(player modelToWorld[0, 0, 1]);
                    AP_electricChairCamera camSetPos(player modelToWorld[1, _distance, 2]);
                    AP_electricChairCamera camSetFOV 0.33;
                    AP_electricChairCamera camSetFocus[50, 0];
                    AP_electricChairCamera camCommit 0;
                    showCinemaBorder false;
                    AP_electricChairCamera cameraEffect["internal", "back"];};
                private _destroyCamera = {AP_electricChairCamera cameraEffect["terminate", "back"];
                    camDestroy AP_electricChairCamera;
                    AP_electricChairCamera = objNull;};
                AP_electricChairCamera = objNull;
                private _plb_dmg = player;
                private _plb_pos = (getPosATL AP_electricChair);
                private _chair = AP_electricChair;
                private _posATL = getPosATL AP_electricChair;
                private _chairDirection = 0;
                private _zCoord = 0;
                private _hiddenObject = "Land_ClutterCutter_small_F"
                createVehicle _posATL;
                _hiddenObject setPosATL _posATL;
                _hiddenObject setDir((direction _chair) - _chairDirection);
                private _headBucket = "Land_Bucket_F"
                createVehicle(getPos player);
                _headBucket attachTo[player, [-0.05, -0.07, 0.1], "Head"];
                _headBucket setVectorUp[0, 0, -1];
                player attachTo[_hiddenObject, [0, 0, _zCoord]];
                player forceAddUniform "U_C_Scientist";
                [] spawn {uiSleep 0.5;
                    [uniform player, "setIdx", 28] call AP_fnc_clothingTextures;};
                AP_killedByElectricChair = true;
                [] spawn _createCamera;
                _plb_dmg say3D["handcuffs", 100];
                ["You will be put down like a dog, momentarily. Thank you for cooperating with your Governor!"] spawn AP_fnc_handleMessage;
                private _toSend = (allPlayers - [player]) select {(_x distance player) <= 75}; [
                    ["electricChairEffects", [player, profileName, _plb_pos, _chair, _posATL, _zCoord, _chairDirection]], "AP_fnc_govSystem", _toSend, false, false] spawn AP_fnc_MP;
                if (isWeaponDeployed player) then {player playMove "";};
                _plb_dmg setPosATL _plb_pos; [["crew", 75, "switchMove", player], "AP_fnc_handleAnim", allPlayers select {
                        (_x distance player) <= 75}] spawn AP_fnc_MP;
                uiSleep 30;
                player say3D["elechair", 1000];
                uiSleep 21;
                for "_i"
                from 1 to 7 do {private _radius = 1;
                    private _dir = player getDir AP_electricChair;
                    private _centre = getPosATL AP_electricChair;
                    private _pos = _centre getPos[_radius, _dir];
                    private _light = "#lightpoint"
                    createVehicleLocal _pos;
                    _light setPosATL(_pos vectorAdd[0, 0, 10]);
                    _light setLightDayLight true;
                    _light setLightBrightness 300;
                    _light setLightAmbient[0.05, 0.05, 0.1];
                    _light setlightcolor[1, 1, 2];
                    uiSleep 0.1;
                    _light setLightBrightness 0;
                    uiSleep(random 0.1);
                    for "_i"
                    from 0 to(3 + random 1) do {private _time = time + 0.1;
                        _light setLightBrightness(100 + random 100);
                        waitUntil {time > _time};}; deleteVehicle _light;
                    uiSleep 2.5;}; uiSleep 6;
                _plb_dmg setDamage 1;
                detach player; {deleteVehicle _x}
                forEach[_headBucket, _hiddenObject];
                uiSleep 2;
                ["You have been pardoned from prison and life.", "basic"] spawn AP_fnc_handleMessage;
                ["payGovernor", [5000]] spawn AP_fnc_govSystem;
                uiSleep 15;
                [] spawn _destroyCamera;
                [] call AP_fnc_doRespawn;
                AP_killedByElectricChair = false;
                ["executedelectricchair", 1] call AP_fnc_statArrUpdate;};};