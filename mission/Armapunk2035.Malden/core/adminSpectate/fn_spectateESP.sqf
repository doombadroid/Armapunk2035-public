private _deleteESP = {espHandlers =
    if (isNil "espHandlers") then {[]} else {espHandlers};
    if !(espHandlers isEqualTo[]) then {{removeMissionEventHandler["Draw3D", _x]}
        forEach espHandlers;};
    espHandlers = nil;};
if ((call AP_adminLevel) <= 1) exitWith {};
call _deleteESP;
suspectESP_tracingBulletsOn = true;
suspectESP_healthBarsOn = true;
suspectESP_boxesOn = true;
suspectESP_bonesOn = true;
suspectESP_namesOn = true;
suspectESP_vehiclesOn = true;
suspectESP_eyeSightLine = true;
suspectESP_on = true;
[0] call AP_fnc_spectateSettings;
suspectESP_suspectObj = nil;
suspectESP_suspectObj = lbData[12901, lbCurSel 12901];
suspectESP_suspectObj = missionNamespace getVariable suspectESP_suspectObj;
if (isNil "suspectESP_suspectObj") exitWith {systemChat "You must select someone to spectate.";};
closeDialog 0; [
    [player, getPlayerUID player, suspectESP_suspectObj, getPlayerUID suspectESP_suspectObj], "APS_fnc_adminPlayerQuerySRV", 2] spawn AP_fnc_MP;
if (!(isNull suspectESP_suspectObj) && {isPlayer suspectESP_suspectObj}) then {[
        ["-ADMINACTION-", player, profileName, format["spectated %1 (%2).", suspectESP_suspectObj getVariable["AP_name", [name suspectESP_suspectObj] call AP_fnc_cleanName], getPlayerUID suspectESP_suspectObj]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    if !(isNil "SPEC_EXIT") then {(findDisplay 46) displayRemoveEventHandler["KeyDown", SPEC_EXIT];};
    SPEC_EXIT = (findDisplay 46) displayAddEventHandler["KeyDown", {params["_ctrl", "_code", "_shift", "_ctrlKey", "_alt"];
        if (isNil "espHandlers") then {private _esp = addMissionEventHandler["Draw3D", {
                // owner 2026-06-14 (#209): self-terminate the ESP overlay the moment spectate is no longer
                // active -- suspect cleared/null, suspectESP_on false, or no longer an admin. Without this a
                // spectate that ended via any path other than the F10 stop (esp. self-spectate, or a relog)
                // left the Draw3D ESP drawing forever. Removes ITS OWN handler via _thisEventHandler.
                if (isNil "suspectESP_on" || {!suspectESP_on} || {isNil "suspectESP_suspectObj"} || {isNull suspectESP_suspectObj} || {(call AP_adminLevel) <= 1}) exitWith {
                    removeMissionEventHandler ["Draw3D", _thisEventHandler];
                    espHandlers = nil;}; {private _curPlayer = _x;
                    private _distance = round(_curPlayer distance2D suspectESP_suspectObj);
                    private _posX = (_curPlayer modelToWorldVisual[0, 0, -0.15]);
                    private _healthBarIcon = [round(100 - ((getDammage _curPlayer) * 100))] call {params["_health"];
                        if (_health isEqualTo 100) exitWith {"images\spectate\admin_spec_hp100.paa"};
                        if (_health < 100 && _health >= 90) exitWith {"images\spectate\admin_spec_hp90.paa"};
                        if (_health < 90 && _health >= 80) exitWith {"images\spectate\admin_spec_hp80.paa"};
                        if (_health < 80 && _health >= 70) exitWith {"images\spectate\admin_spec_hp70.paa"};
                        if (_health < 70 && _health >= 60) exitWith {"images\spectate\admin_spec_hp60.paa"};
                        if (_health < 60 && _health >= 50) exitWith {"images\spectate\admin_spec_hp50.paa"};
                        if (_health < 50 && _health >= 40) exitWith {"images\spectate\admin_spec_hp40.paa"};
                        if (_health < 40 && _health >= 30) exitWith {"images\spectate\admin_spec_hp30.paa"};
                        if (_health < 30 && _health >= 20) exitWith {"images\spectate\admin_spec_hp20.paa"};
                        if (_health < 20 && _health >= 10) exitWith {"images\spectate\admin_spec_hp10.paa"};
                        if (_health < 10) exitWith {"images\spectate\admin_spec_hp10.paa"};};
                    private _tagColor = [side _curPlayer] call {params["_side"];
                        if (_side isEqualTo civilian) exitWith {[1, 0.5, 1, 1]};
                        if (_side isEqualTo west) exitWith {[0, 1, 1, 1]};
                        if (_side isEqualTo independent) exitWith {[0, 1, 0, 1]};
                        if (true) exitWith {[1, 1, 1, 1]};};
                    if !(isNull _curPlayer) then {private _canSee = [_curPlayer] call {params["_curPlayer"];
                            private _visibility = 0;
                            _visibility = _visibility + ([suspectESP_suspectObj, "VIEW", _curPlayer] checkVisibility[AGLToASL positionCameraToWorld[0, 0, 0], _curPlayer modelToWorldVisualWorld(_curPlayer selectionPosition "pelvis")]);
                            _visibility = _visibility + ([suspectESP_suspectObj, "VIEW", _curPlayer] checkVisibility[AGLToASL positionCameraToWorld[0, 0, 0], _curPlayer modelToWorldVisualWorld(_curPlayer selectionPosition "head")]);
                            _visibility = _visibility + ([suspectESP_suspectObj, "VIEW", _curPlayer] checkVisibility[AGLToASL positionCameraToWorld[0, 0, 0], _curPlayer modelToWorldVisualWorld(_curPlayer selectionPosition "leftfoot")]);
                            _visibility = _visibility + ([suspectESP_suspectObj, "VIEW", _curPlayer] checkVisibility[AGLToASL positionCameraToWorld[0, 0, 0], _curPlayer modelToWorldVisualWorld(_curPlayer selectionPosition "rightfoot")]);
                            _visibility = _visibility + ([suspectESP_suspectObj, "VIEW", _curPlayer] checkVisibility[AGLToASL positionCameraToWorld[0, 0, 0], _curPlayer modelToWorldVisualWorld(_curPlayer selectionPosition "righthand")]);
                            _visibility = _visibility + ([suspectESP_suspectObj, "VIEW", _curPlayer] checkVisibility[AGLToASL positionCameraToWorld[0, 0, 0], _curPlayer modelToWorldVisualWorld(_curPlayer selectionPosition "lefthand")]);
                            (_visibility isNotEqualTo 0)};
                        private _posBox = (_curPlayer modelToWorldVisual((_curPlayer selectionPosition "pelvis") vectorAdd[0, 0, -0.1]));
                        private _distance = (positionCameraToWorld[0, 0, 0]) distance _curPlayer;
                        private _fov = (worldToScreen(positionCameraToWorld[safeZoneW, 0, safeZoneH]) select 0);
                        private _width = (24 / _distance * _fov);
                        private _height = (32 / _distance * _fov);
                        private _color =
                        if !(_canSee) then {[1, 0, 0, 1]} else {[0.137, 0.941, 0.137, 1]};
                        if (stance _curPlayer isEqualTo "CROUCH") then {
                            _posBox = (_curPlayer modelToWorldVisual((_curPlayer selectionPosition "pelvis") vectorAdd[0, 0, 0.05]));
                            _width = (24 / _distance * _fov);
                            _height = (18 / _distance * _fov);};
                        if (stance _curPlayer isEqualTo "PRONE") then {_width = (24 / _distance * _fov);
                            _height = (7 / _distance * _fov);};
                        if (suspectESP_boxesOn && (_distance <= suspectESP_boxesDistance)) then {
                            drawIcon3D[getMissionPath "images\spectate\admin_spec_box.paa", _color, _posBox, _width, _height, 0, "", 0, 0.0255, "PuristaLight"];
                        };
                        if (suspectESP_namesOn && (_distance <= suspectESP_namesDistance)) then {
                            drawIcon3D["", _tagColor, _posX, 0, 0, 0, format["%2 %1", name _curPlayer, ((group _curPlayer) getVariable["AP_grpTag", ""])], 2.35, 0.0255, "PuristaSemiBold"];
                            drawIcon3D["", _tagColor, _posX, 0, 1, 0, format["[%1m]", round _distance], 2.35, 0.0255, "PuristaSemiBold"];};
                        if (suspectESP_healthBarsOn && (_distance <= suspectESP_healthDistance)) then {
                            private _distMod = [_curPlayer] call {params["_curPlayer"];
                                private _distance = suspectESP_suspectObj distance _curPlayer;
                                if (_distance >= 50) exitWith {1};
                                if (_distance >= 10) exitWith {2};
                                if (true) exitWith {3};};
                            drawIcon3D[getMissionPath _healthBarIcon, [0.137, 0.941, 0.137, 0.6], _posX, _distMod, _distMod, 0, "", 0, 1, "PuristaSemiBold"];
                        };
                        if (suspectESP_bonesOn && (_distance <= suspectESP_bonesDistance)) then {{private _bodyColor = [_x] call {
                                    params["_bodyType"];
                                    if (_bodyType isEqualTo "righthand") exitWith {[1, 1, 1, 1]};
                                    if (_bodyType isEqualTo "lefthand") exitWith {[1, 1, 1, 1]};
                                    if (true) exitWith {[1, 0.5, 0, 1]};};
                                private _distMod = [_curPlayer] call {params["_curPlayer"];
                                    private _distance = suspectESP_suspectObj distance _curPlayer;
                                    if (_distance >= 800) exitWith {[20, 0.6]};
                                    if (_distance >= 700) exitWith {[20, 0.4]};
                                    if (_distance >= 200) exitWith {[5, 0.8]};
                                    if (_distance >= 100) exitWith {[4, 0.8]};
                                    if (_distance >= 50) exitWith {[3, 1]};
                                    if (_distance >= 25) exitWith {[2.5, 1.15]};
                                    if (true) exitWith {[2.00, 1.15]};};
                                private _posIcon = _curPlayer modelToWorldVisual(_curPlayer selectionPosition _x);
                                if !((_curPlayer selectionPosition _x) isEqualTo[0, 0, 0] || (_curPlayer isEqualTo suspectESP_suspectObj)) then {
                                    if (_x == "neck") then {
                                        drawIcon3D["\A3\ui_f\data\map\markers\military\dot_CA.paa", _color, _posIcon, (_distMod select 1), (_distMod select 1), 0, "", 2, 0.018, "TahomaB", "center", false];
                                    } else {if (suspectESP_suspectObj distance _curPlayer < 200) then {
                                            drawIcon3D["\A3\ui_f\data\map\markers\military\box_CA.paa", _bodyColor, _posIcon, 0.4, 0.4, 0, ""];
                                        };};};}
                            forEach["neck", "pelvis", "leftfoot", "rightfoot", "righthand", "lefthand"];};};}
                forEach((allPlayers - (units group suspectESP_suspectObj)) select {
                    alive _x && ((suspectESP_suspectObj distance2D _x) < suspectESP_bonesDistance) && ((worldToScreen getPosATL _x) isNotEqualTo[])
                });
                if (suspectESP_vehiclesOn && (_distance <= suspectESP_vehiclesDistance)) then {{
                        if (((suspectESP_suspectObj distance _x) < suspectESP_vehiclesDistance) && (vehicle suspectESP_suspectObj != _x) && ((_x isKindOf "Air") || (_x isKindOf "Ship") || (_x isKindOf "Car"))) then {
                            private _tagColor = [(_x getVariable["AP_side", ""])] call {params[["_side", "civ", [""]]];
                                if (_side isEqualTo "civ") exitWith {[1, 0.5, 1, 1]};
                                if (_side isEqualTo "cop") exitWith {[0, 1, 1, 1]};
                                if (_side isEqualTo "med") exitWith {[0, 1, 0, 1]};
                                if (true) exitWith {[1, 1, 1, 1]};};
                            drawIcon3D["", _tagColor, [visiblePosition _x select 0, visiblePosition _x select 1, (getPosATL _x select 2) + 2], 0.1, 0.1, 45, (format["%2 | %1HP | %3m | %4crew", round(100 - ((getDammage _x) * 100)), (getText(configfile >> "CfgVehicles" >> (typeOf _x) >> "displayName")), round(suspectESP_suspectObj distance _x), count(crew _x)]), 2, 0.01, "TahomaB", "center", false];
                        };}
                    forEach vehicles select {(alive _x) && ((worldToScreen getPos _x) isNotEqualTo[])};};}];
            // owner 2026-06-14 (#209): record the handle INSIDE the gate. `_esp` is a private declared in this
            // block, so on every keypress AFTER the first (espHandlers already set, block skipped) the old
            // `espHandlers = [_esp]` below ran with _esp UNDEFINED -> script error that aborted the rest of the
            // KeyDown handler -> the toggle keys AND the F10 stop (code 68) silently stopped working = "no way
            // to stop spectating". Assigning here (only when _esp exists) lets the stop/toggle code below run
            // on every keypress.
            espHandlers = [_esp];};
        if (_code isEqualTo 60) then {if !(suspectESP_vehiclesOn) then {suspectESP_vehiclesOn = true;
                [format["ESP Vehicles toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {suspectESP_vehiclesOn = false;
                [format["ESP Vehicles toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 61) then {if !(suspectESP_healthBarsOn) then {suspectESP_healthBarsOn = true;
                [format["ESP Health Bars toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {suspectESP_healthBarsOn = false;
                [format["ESP Health Bars toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 62) then {if !(suspectESP_namesOn) then {suspectESP_namesOn = true;
                [format["ESP Names toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {suspectESP_namesOn = false;
                [format["ESP Names toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 63) then {if !(suspectESP_boxesOn) then {suspectESP_boxesOn = true;
                [format["ESP Boxes toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {suspectESP_boxesOn = false;
                [format["ESP Boxes toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 64) then {if !(suspectESP_bonesOn) then {suspectESP_bonesOn = true;
                [format["ESP Bones toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {suspectESP_bonesOn = false;
                [format["ESP Bones toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 65) then {if !(suspectESP_tracingBulletsOn) then {BIS_tracedShooter = nil;
                [suspectESP_suspectObj, 30] spawn BIS_fnc_traceBullets;
                suspectESP_tracingBulletsOn = true;
                [format["Bullet Tracing toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {BIS_tracedShooter = nil;
                [player, 0] spawn BIS_fnc_traceBullets;
                suspectESP_tracingBulletsOn = false;
                [format["Bullet Tracing toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 66) then {if !(suspectESP_eyeSightLine) then {suspectESP_eyeSightLine = true;
                [format["ESP Eye Sight Line toggled ON"], "basic"] spawn AP_fnc_handleMessage;} else {suspectESP_eyeSightLine = false;
                [format["ESP  Eye Sight Line toggled OFF"], "basic"] spawn AP_fnc_handleMessage;};};
        if (_code isEqualTo 67) then {["spectateSettings"] call AP_fnc_createDialog;};
        if (_code isEqualTo 68) then {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Spectating Suspect<br/><br/></t></t></t>You have stopped spectating: %1", suspectESP_suspectObj getVariable["AP_name", [name suspectESP_suspectObj] call AP_fnc_cleanName]], "shortwarning"] spawn AP_fnc_handleMessage;
            (findDisplay 46) displayRemoveEventHandler["KeyDown", SPEC_EXIT]; [
                ["-ADMINACTION-", player, profileName, format["stopped spectating %1 (%2).", suspectESP_suspectObj getVariable["AP_name", [name suspectESP_suspectObj] call AP_fnc_cleanName], getPlayerUID suspectESP_suspectObj]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
            if ((uiNamespace getVariable "RscTitleDisplayEmpty") isNotEqualTo controlNull) then {
                (uiNamespace getVariable["RscTitleDisplayEmpty", displayNull]) closeDisplay 0;};
            (findDisplay 46) displayRemoveEventHandler["KeyDown", SPEC_EXIT];
            player switchCamera "Internal";
            suspectESP_on = false;   // owner 2026-06-14 (#209): flips the Draw3D self-terminate guard too
            call _deleteESP;
            suspectESP_suspectObj = nil;};}];
    [format["<t color='#FF0000'><t size='1.5'><t align='center'>Spectating Suspect<br/><br/></t></t></t>You are now spectating: %1", suspectESP_suspectObj getVariable["AP_name", [name suspectESP_suspectObj] call AP_fnc_cleanName]], "shortwarning"] spawn AP_fnc_handleMessage;
    [] spawn {suspectESP_suspectObj switchCamera "INTERNAL";
        waitUntil {uiSleep 0.1;
            (AP_suspectInfo isNotEqualTo[])};
        "infoLayer"
        cutRsc["RscTitleDisplayEmpty", "PLAIN", -1, true];
        private _plb_display = uiNamespace getVariable "RscTitleDisplayEmpty";
        private _suspectInfoTitle = _plb_display ctrlCreate["AP_RscTitle", -1];
        _suspectInfoTitle ctrlSetPosition[0.005 * safezoneW + safezoneX, 0.1634 * safezoneH + safezoneY, 0.145625 * safezoneW, 0.0249999 * safezoneH];
        _suspectInfoTitle ctrlSetBackgroundColor[0.4, 0, 0, 0.7];
        _suspectInfoTitle ctrlCommit 0;
        private _suspectInfoText = _plb_display ctrlCreate["AP_RscStructuredText", -1];
        _suspectInfoText ctrlSetPosition[0.005 * safezoneW + safezoneX, 0.1898 * safezoneH + safezoneY, 0.145625 * safezoneW, 0.22 * safezoneH];
        _suspectInfoText ctrlSetBackgroundColor[0, 0, 0, 0.5];
        _suspectInfoText ctrlCommit 0;
        private _keyBindInfo = _plb_display ctrlCreate["AP_RscStructuredText", -1];
        _keyBindInfo ctrlSetPosition[0.896406 * safezoneW + safezoneX, 0.82 * safezoneH + safezoneY, 0.12375 * safezoneW, 0.20 * safezoneH];
        _keyBindInfo ctrlSetBackgroundColor[0, 0, 0, 0.5];
        _keyBindInfo ctrlCommit 0;
        _suspectInfoTitle ctrlsetText "Suspect Info";
        _keyBindInfo ctrlSetStructuredText parseText "<br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F2 to toggle ESP Vehicles</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F3 to toggle ESP Health Bars</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F4 to toggle ESP Names</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F5 to toggle ESP Boxes</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F6 to toggle ESP Bones</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F7 to toggle Bullet Tracing</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F8 to toggle ESP Eye Line</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F9 to open Spectate Settings</t><br/><t size='0.800' align='left' valign='middle' color='#ffffff'>F10 to stop Spectating</t><br/>";
        private _name = name suspectESP_suspectObj;
        private _pid = getPlayerUID suspectESP_suspectObj;
        private _lastUpdatedData = time;
        while {!isNil "suspectESP_suspectObj"}
        do {if (isNil "suspectESP_suspectObj") exitWith {};
            if !(_lastUpdatedData > time - 15) then {_lastUpdatedData = time; [
                    [player, getPlayerUID player, suspectESP_suspectObj, getPlayerUID suspectESP_suspectObj], "APS_fnc_adminPlayerQuerySRV", 2] spawn AP_fnc_MP;
            };
            private _targetName =
            switch (true) do {case (cursorObject isKindOf "CAManBase"): {
                        format["%1 (Vis: %2%3) (%4m)", (name cursorTarget), (round(([objNull, "VIEW"] checkVisibility[eyePos suspectESP_suspectObj, eyePos cursorObject]) * 100)), "%", (round(suspectESP_suspectObj distance cursorObject))]
                    };
                case ((cursorObject isKindOf "Car" || cursorObject isKindOf "Ship" || cursorObject isKindOf "Air") && !(isNull(currentPilot cursorObject))):
                    {
                        format["%1 (Vis: %2%3) (%4m)", (name(currentPilot cursorObject)), (round(([objNull, "VIEW"] checkVisibility[eyePos suspectESP_suspectObj, eyePos(currentPilot cursorObject)]) * 100)), "%", (round(suspectESP_suspectObj distance(currentPilot cursorObject)))]
                    };
                default {""};}; private _timeDate = call AP_fnc_getDateUTC;
            if (isNil "suspectESP_suspectObj") exitWith {};
            private _gangData = suspectESP_suspectObj getVariable["gang_data", []];
            _gangData params["_suspectGangID", "_suspectGangName"];
            if (_gangData isEqualTo[]) then {_suspectGangID = -1;
                _suspectGangName = "No Gang";};
            _suspectTextFormat = format["<t %1 %2>Username: %3</t><br/><t %1 %2>Steam Profile: %4</t><br/><t %1 %2>UID: %5</t><br/><t %1 %2>Gang: %6 (%7)</t><br/><t %1 %2>Health: %8 HP</t><br/><t %1 %2>Weapon: %9</t><br/><t %1 %2>Civ Minutes: %12</t><br/><t %1 %2>CurObj: %11</t><br/><t %1 %2>%10 UTC</t>", "size='0.85'", "", _name, _name, _pid, _suspectGangName, _suspectGangID, round(100 - ((getDammage suspectESP_suspectObj) * 100)), getText(configFile >> "CfgWeapons" >> (currentWeapon suspectESP_suspectObj) >> "DisplayName"), _timeDate, _targetName, A_stats_civTime];
            _suspectInfoText ctrlSetStructuredText(parseText _suspectTextFormat);};};
    [] spawn {waitUntil {sunOrMoon isEqualTo 0};
        if (isNil "suspectESP_suspectObj") exitWith {};
        setAperture 1;
        private _nvgEffect = ppEffectCreate["ColorCorrections", 1500];
        _nvgEffect ppEffectEnable true;
        _nvgEffect ppEffectAdjust[0.75, 0.75, 0, [0, 0, 0, 0], [1, 2.5, 1, 0.5], [0.33, 0.33, 0.33, 0], [0, 0, 0, 0, 0, 0, 4]];
        _nvgEffect ppEffectCommit 0;
        waitUntil {(sunOrMoon > 0) || (isNil "suspectESP_suspectObj")};
        setAperture - 1;
        ppEffectDestroy _nvgEffect;};
    [] spawn {while {true}
        do {if (isNil "suspectESP_suspectObj" || AP_adminMode) exitWith {};
            private _markers = [];
            private _marker = "";
            private _color = "";
            waitUntil {uiSleep 0.2;
                visibleMap}; {_marker = createMarkerLocal[format["%1_marker_HAX", _x], getPosATL _x];
                private _markerType =
                if (_x isEqualTo suspectESP_suspectObj || _x isEqualTo player) then {"mil_arrow2"} else {"Mil_dot"};
                _marker setMarkerTypeLocal _markerType;
                _marker setMarkerTextLocal format["%1 - %2m", name _x, round(suspectESP_suspectObj distance _x)];
                _markers pushBack[_marker, _x];
                _color =
                switch (true) do {case (_x isEqualTo suspectESP_suspectObj || _x isEqualTo player): {"ColorOrange"};
                    case (side _x isEqualTo west): {"colorBLUFOR"};
                    case (side _x isEqualTo independent): {"ColorGreen"};
                    default {"colorCivilian"};}; _marker setMarkerColorLocal _color;}
            forEach allPlayers;
            while {visibleMap}
            do {{_x params["_marker", "_unit"];
                    if (!isNull _unit && !isNil "_unit") then {_marker setMarkerPosLocal(getPosATL _unit);
                        if ((markerColor _marker) isEqualTo "ColorOrange") then {_marker setMarkerDirLocal(getDir suspectESP_suspectObj)};
                    };} forEach _markers;
                if !(visibleMap) exitWith {};
                uiSleep 0.02;}; { deleteMarkerLocal (_x select 0);}
            forEach _markers;
            _markers = [];
            if (isNil "suspectESP_suspectObj" || AP_adminMode) exitWith {};};};};