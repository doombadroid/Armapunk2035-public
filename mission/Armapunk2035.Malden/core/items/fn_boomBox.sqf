params[["_caseType", "", [""]], "_boomBoxData"];
switch (_caseType) do {case ("initBoomBox"): {
            
            _boomBoxData params[["_boomBox", objNull, [objNull]]];
            if (typeOf _boomBox isNotEqualTo "Land_BatteryPack_01_closed_black_F") exitWith {};
            _boomBox setVariable["AP_boomBoxData", [player, getPlayerUID player, profileName, ""], true];
            ["Your boom box is now ready for music to be played! Your boombox will automatically delete in 10 minutes!"] spawn AP_fnc_handleMessage;
            [[_boomBox, 600], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;
            AP_boomBox = _boomBox;}; case ("deleteBoomBox"): {_boomBoxData params[["_boomBox", objNull, [objNull]]];
                (_boomBox getVariable["AP_boomBoxData", []]) params[["_boomBoxOwnerObj", objNull, [objNull]], ["_boomBoxOwnerUID", "", [""]], ["_boomBoxOwnerName", "", [""]], ["_boomBoxCurrentSong", "", [""]], ["_boomBoxCurrentSongDelay", 0, [0]], ["_boomBoxCurrentSongStartedServerTime", 0, [0]]];
                if (_boomBoxOwnerUID isNotEqualTo(getPlayerUID player)) exitWith {};
                if (typeOf _boomBox isNotEqualTo "Land_BatteryPack_01_closed_black_F") exitWith {};
                private _dialogQuestion = ["Are you sure you want to delete your Boom Box?", "Boom Box MP3", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_dialogQuestion) exitWith {};
                deleteVehicle _boomBox;
                AP_boomBox = objNull;};
        case ("startMusic"): {
                
                _boomBoxData params[["_boomBox", objNull, [objNull]]];
                (_boomBox getVariable["AP_boomBoxData", []]) params[["_boomBoxOwnerObj", objNull, [objNull]], ["_boomBoxOwnerUID", "", [""]], ["_boomBoxOwnerName", "", [""]], ["_boomBoxCurrentSong", "", [""]], ["_boomBoxCurrentSongDelay", 0, [0]], ["_boomBoxCurrentSongStartedServerTime", 0, [0]]];
                if (_boomBoxOwnerUID isNotEqualTo(getPlayerUID player)) exitWith {};
                if (typeOf _boomBox isNotEqualTo "Land_BatteryPack_01_closed_black_F") exitWith {};
                private _songs = [["NCS | Alan Walker - Fade", "alanWalkerFade", 80], ["Deaf Kev - Invincible", "deafKevInvincible", 98],
                    ["Different Heaven - My Heart", "differentHeaven", 92]];
                
                    _songs append[["Shipwrek and Zookeepers - Ark", "ShipwrekZooKeepersArk", 109], ["Daniel Levi and Cartoon - On and On", "cartoonOnOn", 82]];
                private _chosenSong = ["", "", 0]; {if (_chosenSong isNotEqualTo["", "", 0]) exitWith {};
                    private _dialogQuestion = [format["Would you like to play %1?", _x param[0, ""]], "Boom Box MP3", "Yes", "No"] call BIS_fnc_guiMessage;
                    if (_dialogQuestion) exitWith {_chosenSong = _x};}
                forEach _songs;
                if (_chosenSong isEqualTo["", "", 0]) exitWith {};
                _chosenSong params["_songDisplayName", "_soundFile", "_loopDelay"];
                _boomBox setVariable["AP_boomBoxData", [player, getPlayerUID player, profileName, _soundFile, _loopDelay, serverTime], true];
                [format["Your boom box has started playing %1!", _songDisplayName]] spawn AP_fnc_handleMessage;
                private _toSend = allPlayers select {(_x distance player) <= 350}; [
                    ["initMusic", [_boomBox]], "AP_fnc_boomBox", _toSend] spawn AP_fnc_MP;};
        case ("stopMusic"): {_boomBoxData params[["_boomBox", objNull, [objNull]]];
                (_boomBox getVariable["AP_boomBoxData", []]) params[["_boomBoxOwnerObj", objNull, [objNull]], ["_boomBoxOwnerUID", "", [""]], ["_boomBoxOwnerName", "", [""]], ["_boomBoxCurrentSong", "", [""]], ["_boomBoxCurrentSongDelay", 0, [0]], ["_boomBoxCurrentSongStartedServerTime", 0, [0]]];
                if (_boomBoxOwnerUID isNotEqualTo(getPlayerUID player)) exitWith {};
                private _dialogQuestion = ["Are you sure you want to stop the music for your Boom Box?", "Boom Box MP3", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_dialogQuestion) exitWith {};
                _boomBox setVariable["AP_boomBoxData", [player, getPlayerUID player, profileName, ""], true];};
        case ("initMusic"): {_boomBoxData params[["_boomBox", objNull, [objNull]]];
                (_boomBox getVariable["AP_boomBoxData", []]) params[["_boomBoxOwnerObj", objNull, [objNull]], ["_boomBoxOwnerUID", "", [""]], ["_boomBoxOwnerName", "", [""]], ["_boomBoxCurrentSong", "", [""]], ["_boomBoxCurrentSongDelay", 0, [0]], ["_boomBoxCurrentSongStartedServerTime", 0, [0]]];
                if (_boomBoxCurrentSong isEqualTo "") exitWith {};
                if ((isNull AP_boomBox) && (_boomBoxOwnerUID isEqualTo(getPlayerUID player))) then {AP_boomBox = _boomBox;};
                private _hiddenObject = "Land_ClutterCutter_small_F"
                createVehicleLocal[0, 0, 0];
                _hiddenObject setPosATL(getPosATL _boomBox);
                _hiddenObject hideObject true;
                private _startSong = _boomBoxCurrentSong;
                private _songInstace = 0;
                private _exit = false;
                while {
                    !(isNull _boomBox) || !(isNull _hiddenObject) || (((_boomBox getVariable["AP_boomBoxData", []]) param[3, ""]) isEqualTo _startSong)
                }
                do {if (_exit) exitWith {};
                    private _songInstace = (random 999999);
                    profileNameSpace setVariable["AP_boomBoxSongInstance", _songInstace];
                    _hiddenObject say3D[_boomBoxCurrentSong, 60];
                    for "_i"
                    from 1 to _boomBoxCurrentSongDelay do {if (_exit) exitWith {};
                        if ((((_boomBox getVariable["AP_boomBoxData", []]) param[3, ""]) isNotEqualTo _startSong) || (_songInstace isNotEqualTo(profileNameSpace getVariable["AP_boomBoxSongInstance", 999999]))) then {
                            if !(isNull _hiddenObject) exitWith {deleteVehicle _hiddenObject;
                                _exit = true;};} else {uiSleep 1;};};}; if !(isNull _hiddenObject) then {deleteVehicle _hiddenObject;};
                if ((((_boomBox getVariable["AP_boomBoxData", []]) param[3, ""]) isNotEqualTo "") && (_songInstace isNotEqualTo(profileNameSpace getVariable["AP_boomBoxSongInstance", 999999]))) then {
                    ["initMusic", [_boomBox]] spawn AP_fnc_boomBox;};};
        case ("startDance"): {
                
                AP_isDancing = true;
                private _toSend = allPlayers select {(_x distance player) <= 200}; [
                    [(selectRandom["Acts_Dance_01", "Acts_Dance_02"]), 600, "switchMove", player], "AP_fnc_handleAnim", _toSend] spawn AP_fnc_MP;
            };
        case ("stopDance"): {
                
                AP_isDancing = false;
                ["", 0, "switchMove", player] spawn AP_fnc_handleAnim;};};