params[["_caseType", "", [""]], "_phoneData"];
switch (_caseType) do {case ("startPhoneCall"): {_phoneData params[["_button", controlNull, [controlNull]]];
            if (_button isEqualTo controlNull) exitWith {[format["fucked %1", _this], "warning"] spawn AP_fnc_handleMessage;};
            if !((lbCurSel 9501) >= 0) exitWith {
                ["You must select a player you are trying to call!", "basic"] spawn AP_fnc_handleMessage;};
            private _data = (lbData[9501, lbCurSel 9501]);
            if (_data in ["enginekillswitch", "remotebomb"]) exitWith {
                // LooneyBin: use the STORED vehicle object directly. The old plate-lookup (vehicles findIf
                // AP_dbInfo[1] == plate) returned objNull / the wrong vehicle when the plate was -1, non-DB, or
                // re-plated -> callInBomb's "_vehicle == AP_remoteExplosive#0" guard failed -> detonator did nothing.
                private _target = if (_data == "enginekillswitch") then {AP_engineKillSwitch param[0, objNull]} else {
                    AP_remoteExplosive param[0, objNull]};
                if !(isNull _target) exitWith {if (_data == "enginekillswitch") then {
                        ["callInKillSwitch", _target] spawn AP_fnc_remoteEngineKillSwitch;} else {
                        ["callInBomb", _target] spawn AP_fnc_remoteExplosive;};};};
            private _target = allPlayers param[allPlayers findIf {_data isEqualTo(getPlayerUID _x)}, objNull];
            if (isNull _target) exitWith {["The player you are trying to call can't be found", "basic"] spawn AP_fnc_handleMessage;};
            if (((side _target) isEqualTo west) && ((AP_is_arrested param[0, 0]) isEqualTo 1)) exitWith {
                ["Prison inmates are not allowed to call officers of the law!", "basic"] spawn AP_fnc_handleMessage;};
            if ((_target distance(getMarkerPos "respawn_civilian")) < 1000) exitWith {
                ["The player you are trying to call is currently not available."] spawn AP_fnc_handleMessage};
            AP_phoneCallStatus = 1;
            ["Phone"] call AP_fnc_deckOpenApp; [
                ["receivePhoneCall", [profileName, player]], "AP_fnc_phoneCallClient", _target] spawn AP_fnc_MP;
            [format["You have started calling %1", [name _target] call AP_fnc_cleanName], "basic"] spawn AP_fnc_handleMessage;
            [] spawn {for "_i"
                from 1 to 4 do {if (AP_phoneCallStatus isNotEqualTo 1) exitWith {};
                    if !(AP_isRingEnabled) exitWith {};
                    playSound "PhoneDial";
                    uiSleep 3;};};
            private _ringStart = time;
            waitUntil {uiSleep 1;
                ((_ringStart < time - 30) || (AP_phoneCallStatus isNotEqualTo 1))};
            if ((_ringStart < time - 30) && (AP_phoneCallStatus isEqualTo 1)) then {
                ["declinePhoneCallReciever"] spawn AP_fnc_phoneCallClient;};
            
            [] spawn {waitUntil {uiSleep 0.5;
                    (AP_phoneCallStatus isEqualTo - 1)};
                };}; case ("receivePhoneCall"): {
                _phoneData params[["_callerName", "", [""]], ["_callerObj", objNull, [objNull]]];
                if (AP_phoneCallStatus isEqualTo 2) exitWith {};
                if !(AP_incomingCallsIgnored) then {
                    [format["%1 is calling your phone! Press 8 to answer or 9 to decline.", _callerName], "phone_call"] spawn AP_fnc_handleMessage;
                    systemChat "You can also disable all incoming calls in your phone settings";
                    [] spawn {for "_i"
                        from 1 to 4 do {if !(AP_isRingEnabled) exitWith {};
                            if (AP_phoneCallStatus isNotEqualTo 1) exitWith {};
                            playSound "PhoneRing";
                            uiSleep 3;};};};
                AP_phoneCallStatus = 1;
                AP_phoneCallData = [_callerObj, _callerName, player, profileName];
                private _ringStart = time;
                waitUntil {uiSleep 1;
                    ((_ringStart < time - 30) || (AP_phoneCallStatus isNotEqualTo 1))};
                if ((_ringStart < time - 30) && (AP_phoneCallStatus isEqualTo 1)) then {if !(AP_incomingCallsIgnored) then {
                        [format["You ignored the incoming phone call from %1", _callerName], "basic"] spawn AP_fnc_handleMessage;};
                    AP_phoneCallStatus = 3;
                    AP_phoneCallData = [objNull, "", objNull, ""];
                    
                    [] spawn {uiSleep 10;
                        AP_phoneCallStatus = 0;
                        };};};
        case ("answerPhoneCall"): {
                AP_phoneCallData params[["_callerObj", objNull, [objNull]], ["_callerName", "", [""]], ["_recieverObj", objNull, [objNull]], ["_recieverName", "", [""]]];
                if (isNull _callerObj || _callerName isEqualTo "") exitWith {};
                [format["You have answered the phone call from %1", _callerName], "basic"] spawn AP_fnc_handleMessage; [
                    ["startPhoneCall", [_callerObj, player]], "APS_fnc_handlePhoneCallSRV", 2] spawn AP_fnc_MP;};
        case ("declinePhoneCallReciever"): {
                AP_phoneCallData params[["_callerObj", objNull, [objNull]], ["_callerName", "", [""]], ["_recieverObj", objNull, [objNull]], ["_recieverName", "", [""]]];
                AP_phoneCallStatus = 3;
                AP_phoneCallData = [objNull, "", objNull, ""];
                
                if (isNull _callerObj) exitWith {["Your phone call wasn't answered in time", "basic"] spawn AP_fnc_handleMessage;
                    
                    [] spawn {uiSleep 10;
                        AP_phoneCallStatus = 0;
                        };};
                if (_recieverObj isNotEqualTo player) exitWith {};
                [format["You declined the incoming phone call from %1", _callerName], "basic"] spawn AP_fnc_handleMessage; [
                    ["declinePhoneCallCaller", [profileName]], "AP_fnc_phoneCallClient", _callerObj] spawn AP_fnc_MP;
                [] spawn {uiSleep 10;
                    AP_phoneCallStatus = 0;
                    };};
        case ("declinePhoneCallCaller"): {_phoneData params[["_recieverName", "", [""]]];
                [format["%1 has declined your phone call!", _recieverName], "basic"] spawn AP_fnc_handleMessage;
                AP_phoneCallStatus = 3;
                AP_phoneCallData = [objNull, "", objNull, ""];
                
                [] spawn {uiSleep 10;
                    AP_phoneCallStatus = 0;
                    };};
        case ("endPhoneCall"): {_phoneData params[["_button", controlNull, [controlNull]]];
                if (_button isEqualTo controlNull) exitWith {};
                if (AP_phoneCallStatus isNotEqualTo 2) exitWith {};
                private _dialogQuestion = ["Do you want to hang up your phone call?", "Hang Up", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_dialogQuestion) exitWith {}; [
                    ["endPhoneCall", [AP_phoneCallID, player]], "APS_fnc_handlePhoneCallSRV", 2] spawn AP_fnc_MP;
                ["phoneCallEnded"] call AP_fnc_phoneCallClient;
                uiSleep 0.5;
                };
        case ("phoneCallEstablished"): {_phoneData params[["_channelID", -1, [0]]];
                if (_channelID isEqualTo - 1) exitWith {};
                AP_phoneCallID = _channelID;
                AP_phoneCallStatus = 2;
                ["Phone link established!"] spawn AP_fnc_handleMessage;
                };
        case ("phoneLinesMaxed"): {AP_phoneCallStatus = 0;
                AP_phoneCallID = -1;
                AP_phoneCallData = [objNull, "", objNull, ""];
                ["Phone lines are currently at maximum capacity, try again later!"] spawn AP_fnc_handleMessage;
                };
        case ("phoneCallEnded"): {AP_phoneCallStatus = 0;
                AP_phoneCallID = -1;
                AP_phoneCallData = [objNull, "", objNull, ""];
                ["Your phone call has ended"] spawn AP_fnc_handleMessage;
                };};