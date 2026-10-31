params[["_caseType", "", [""]], ["_vehicle", objNull, [objNull]]];
if (_caseType isEqualTo "" || isNull _vehicle) exitWith {};
switch (_caseType) do {case ("attach"): {
            if !((_vehicle isKindOf "Car") || (_vehicle isKindOf "Air") || (_vehicle isKindOf "Ship") || (_vehicle isKindOf "Tank")) exitWith {
                ["The remote engine kill switch cannot be fitted to this vehicle!"] spawn AP_fnc_handleMessage};
            if (speed(vehicle player) > 0) exitWith {
                ["This vehicle must be at a standstill before you start adding the remote engine kill switch!"] spawn AP_fnc_handleMessage
            };
            if !([false, "remotekillswitch", 1] call AP_fnc_handleInv) exitWith {
                ["You don't have an remote engine kill switch in your inventory!"] spawn AP_fnc_handleMessage};
            if (_vehicle getVariable["AP_EngineKillSwitchActive", false]) exitWith {
                ["There is already a remote engine kill switch to this vehicle!"] spawn AP_fnc_handleMessage};
            if (AP_engineKillSwitch isNotEqualTo[objnull, -1]) exitWith {
                ["You already have a remote engine kill switch active!"] spawn AP_fnc_handleMessage};
            private _displayName = (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName"));
            disableSerialization;
            5 cutRsc["AP_progress", "PLAIN"];
            private _text = format["Priming engine kill switch to %1", _displayName];
            private _ui = uiNamespace getVariable "AP_progress";
            private _progress = _ui displayCtrl 38201;
            private _pgText = _ui displayCtrl 38202;
            _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
            _progress progressSetPosition 0.01;
            private _cP = 0.01;
            private _success = false;
            AP_action_in_use = true; [["Acts_TerminalOpen", 30, "switchMove", player], "AP_fnc_handleAnim", (allPlayers select {
                    (_x distance player) <= 100})] spawn AP_fnc_MP;
            for "_i"
            from 0 to 1 step 0 do {uiSleep 0.15;
                _cP = _cP + 0.01;
                _progress progressSetPosition _cP;
                _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
                if (_cP >= 1) exitWith {_success = true;};
                if !(isNull objectParent player) exitWith {
                    ["You cannot enter a vehicle while planting the remote engine kill switch."] spawn AP_fnc_handleMessage};
                if (speed(vehicle player) > 0) exitWith {
                    ["The vehicle cannot move while planting the remote engine kill switch."] spawn AP_fnc_handleMessage};
                if !(alive player) exitWith {};
                if !(AP_action_in_use) exitWith {};};
            ["", 0 , "switchMove", player] spawn AP_fnc_handleAnim;
            5 cutText["", "PLAIN"];
            AP_action_in_use = false;
            if !(_success) exitWith {[true, "remotekillswitch", 1] call AP_fnc_handleInv;};
            AP_side_exp = AP_side_exp + 15;
            (_vehicle getVariable["AP_dbInfo", []]) params[["_vehOwner", "", [""]], ["_plateID", -1, [0]]]; [
                ["-ENGINEKILLSWITCH-", player, profileName, format["attached a remote engine kill switch to a %1, Plate: %2, belonging to %3, POS: %4.", (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")), _plateID, _vehOwner, getPosATL _vehicle]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
            [format["You have inserted a remote engine kill switch to this %1. Call your remote detonator via the cellphone app!", _displayName]] spawn AP_fnc_handleMessage;
            AP_engineKillSwitch = +[_vehicle, _plateID];
            _vehicle setVariable["AP_remoteEngineKillSwitchActive", true, true];
            profileNamespace setVariable["AP_cellphone_enginekillswitch", [AP_instance_id, _vehicle, _plateID]];
        }; case ("callInKillSwitch"): {if (_vehicle isNotEqualTo(AP_engineKillSwitch param[0, objNull])) exitWith {};
                private _distanceMeters = round(player distance2D _vehicle);
                if (_distanceMeters >= 1000) exitWith {
                    [format["You must be within 1km of your remote engine kill switch to reach it's signal. You are currently %1 meters away.", _distanceMeters], "basic"] spawn AP_fnc_handleMessage
                };
                (_vehicle getVariable["AP_dbInfo", []]) params[["_vehOwner", "", [""]], ["_plate", -1, [0]]];
                [] spawn {AP_phoneCallStatus = 1;
                    if !(isNull(findDisplay 9500)) then {["Phone"] call AP_fnc_deckOpenApp;};
                    uiSleep 3;
                    AP_phoneCallStatus = 2;
                    if !(isNull(findDisplay 9500)) then {["Phone"] call AP_fnc_deckOpenApp;};
                    uiSleep 5;
                    AP_phoneCallStatus = 0;
                    if !(isNull(findDisplay 9500)) then {["Phone"] call AP_fnc_deckOpenApp;};};
                ["You have started calling your remote detonator...", "basic"] spawn AP_fnc_handleMessage;
                playSound "bombPhoneInit";
                uiSleep 3.7;
                playSound "bombPhoneAnswer";
                uiSleep 0.5;
                playSound "bombPhoneAnswerTalk";
                uiSleep 2;
                playSound "bombPhoneLoop";
                uiSleep 1;
                _vehicle setHit[getText(configfile >> "CfgVehicles" >> typeOf _vehicle >> "HitPoints" >> "HitEngine" >> "name"), 1]; [
                    ["-ENGINEKILLSWITCH-", player, profileName, format["detonated their remote engine kill switch attached to a %1, Plate: %2, belonging to %3, POS: %4.", (getText(configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName")), _plate, _vehOwner, getPosATL _vehicle]], "APS_fnc_logIt", 2, false, false] call AP_fnc_MP;
                [
                    [0, format["A remote engine kill switch planted by %1 has activated!", profileName]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
                ["remoteenginekillswitch", 1] call AP_fnc_statArrUpdate;
                AP_engineKillSwitch = +[objNull, -1];
                profileNamespace setVariable["AP_cellphone_enginekillswitch", [AP_instance_id, objNull, -1]];};};