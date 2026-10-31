/*
    Re-plumbed 2026-08-11 so the web deck can send. The message body and the
    recipient used to be read straight out of dialog 3000's own controls
    (ctrlText 3001, lbData 3002), which meant only that dialog could ever send
    anything. Both are optional parameters now, falling back to those controls
    when absent:

        [_ctrl, 0] call AP_fnc_sendText;                            // native, unchanged
        [controlNull, 0, "hi", "76561198..."] call AP_fnc_sendText;  // deck

    Every gate below is untouched: the Silence Cell jam, the parseText content
    blacklist, the 500-character cap, the prisoner-cannot-text-police rule and
    the staff/governor checks.
*/
if !(params[["_button", controlNull], ["_mode", -1], ["_msgIn", "", [""]], ["_uidIn", "", [""]]]) exitWith {false};
disableSerialization;
private _direct  = _msgIn isNotEqualTo "";
private _message = if (_direct) then { _msgIn } else { ctrlText 3001 };
// Recipient uid: the caller's, or the dialog listbox. lbData answers "" when
// nothing is selected, so one emptiness test covers both callers.
private _sel = if (_direct) then { _uidIn } else { lbData [3002, lbCurSel 3002] };
if ((!alive player) || (isNull player)) exitWith {};
// Silence Cell quickhack: outgoing comms are jammed (all modes -- DM, police, medic, gang)
if (diag_tickTime < (missionNamespace getVariable ["AP_qhSilencedUntil", 0])) exitWith {
    [format ["<t color='#ff3b1e'>SIGNAL JAMMED</t> -- your comms are muted for another %1s.",
        ceil ((missionNamespace getVariable ["AP_qhSilencedUntil", 0]) - diag_tickTime)], "basic"] spawn AP_fnc_handleMessage;};
if (_mode isEqualTo 4) exitWith {["This message type is currently disabled.", "basic"] spawn AP_fnc_handleMessage;};
if ((_message isEqualTo "") && !(_mode in [4])) exitWith {["You must enter a message to send!", "basic"] spawn AP_fnc_handleMessage;};
private _disallowedContent = ["<br/>", "<t", "<img", "<a"] apply {toLower _x};
if !(_disallowedContent findIf {_x in toLower _message}
isEqualTo - 1) exitWith {systemChat format["Your message contains disallowed content: %1", _disallowedContent select {
        _x in toLower _message}
    joinString ", "]};
switch (_mode) do {case 0: {if (_sel isEqualTo "") exitWith {
                ["You must select a player you are sending the text to!", "basic"] spawn AP_fnc_handleMessage;};
            if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;};
            if (_sel isEqualTo "BENBONES") exitWith {   // AI DM, not a player
                ["Ben Bones Official", 1, _message] call AP_fnc_msgAppend;   // threads store
                if (!isNull (findDisplay 3000)) then {  };
                [["send", _message], "APS_fnc_bonesDM", 2, false, false] spawn AP_fnc_MP;
                ["You texted Ben Bones Official. He's in the bunker -- give him a minute to reply.", "basic"] spawn AP_fnc_handleMessage;
            };
            private _target = allPlayers param[allPlayers findIf {_sel isEqualTo (getPlayerUID _x)}, objNull];
            // OFFLINE (owner 2026-08-11): queue it server-side rather than refusing. _sel is a
            // uid either way -- for someone not on the server it came out of AP_msgUids, the
            // local name->uid map, which exists precisely because the thread store is keyed by
            // display name and an absent player cannot be resolved from allPlayers.
            if (isNull _target) exitWith {
                private _who = [_sel] call AP_fnc_msgNameGet;
                if (_who isEqualTo "") exitWith {
                    ["The player you are trying to message can't be found", "basic"] spawn AP_fnc_handleMessage; false
                };
                [[_sel, _message], "APS_fnc_offlineMsg", 2] spawn AP_fnc_MP;
                [_who, 1, _message] call AP_fnc_msgAppend;   // shows in the thread immediately
                if (!isNull (findDisplay 3000)) then {  };
                true
            };
            if (((side _target) isEqualTo west) && ((AP_is_arrested select 0) isEqualTo 1)) exitWith {
                ["Prison inmates are not allowed to message officers of the law!", "basic"] spawn AP_fnc_handleMessage;};
            [[name _target] call AP_fnc_cleanName, (getPlayerUID _target)] call AP_fnc_msgUidSet;   // remember for offline sends
            [[name _target] call AP_fnc_cleanName, 1, _message] call AP_fnc_msgAppend;   // threads store
            if (!isNull (findDisplay 3000)) then {  }; [[_mode, player, _target, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;
            [format["You sent %1 a message: %2", [name _target] call AP_fnc_cleanName, _message], "basic"] spawn AP_fnc_handleMessage;
        };
    case 1: {if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;
            };
            private _target = "The Police";
            if ((AP_is_arrested select 0) isEqualTo 1) exitWith {
                ["Prison inmates are not allowed to message officers of the law!", "basic"] spawn AP_fnc_handleMessage;};
            if (!isNull (findDisplay 3000)) then {  }; [[_mode, player, objNull, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;
            [format["You sent %1 a message: %2", _target, _message], "basic"] spawn AP_fnc_handleMessage;};
    case 2: {if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;
            };
            private _target = "Emergency Medical";
            if (!isNull (findDisplay 3000)) then {  }; [[_mode, player, objNull, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;
            [format["You sent %1 a message: %2", _target, _message], "basic"] spawn AP_fnc_handleMessage;};
    case 3: {if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;
            };
            private _target = "The Admins";
            if (!isNull (findDisplay 3000)) then {  }; [[_mode, player, objNull, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;
            [format["You sent %1 a message: %2", _target, _message], "basic"] spawn AP_fnc_handleMessage;};
    case 4: {if ((AP_last_taxi > 0) && ((time - AP_last_taxi) < 300)) exitWith {
                ["You may only call for a taxi once every 5 minutes.", "basic"] spawn AP_fnc_handleMessage;};
            AP_last_taxi = time;
            ["A taxi has been called.	Note that taxis are not always available.", "basic"] spawn AP_fnc_handleMessage;};
    case 5: {if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;
            };
            if ((call AP_adminLevel) <= 1) exitWith {["You are not an admin!", "basic"] spawn AP_fnc_handleMessage;};
            if (!isNull (findDisplay 3000)) then {  };
            [format["Message Sent To All: %1", _message], "basic"] spawn AP_fnc_handleMessage; [
                [_mode, player, objNull, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;};
    case 6: {if ((call AP_adminLevel) <= 1) exitWith {["You are not an admin!", "basic"] spawn AP_fnc_handleMessage;};
            if (_sel isEqualTo "") exitWith {
                ["You must select a player you are sending the text to!", "basic"] spawn AP_fnc_handleMessage;};
            if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;};
            private _target = allPlayers param[allPlayers findIf {_sel isEqualTo (getPlayerUID _x)}, objNull];
            if (isNull _target) exitWith {["The player you are trying to message can't be found", "basic"] spawn AP_fnc_handleMessage;};
            [[name _target] call AP_fnc_cleanName, 1, _message] call AP_fnc_msgAppend;   // threads store
            if (!isNull (findDisplay 3000)) then {  }; [[_mode, player, _target, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;
            [format["Admin Message Sent To: %1 - Message: %2", [name _target] call AP_fnc_cleanName, _message], "basic"] spawn AP_fnc_handleMessage;
        };
    case 7: {if ((getPlayerUID player) isNotEqualTo(SRV_governorData param[0, "GovUID"])) exitWith {
                ["You are not the governor!", "basic"] spawn AP_fnc_handleMessage;};
            if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;};
            if (serverTime < (profileNamespace getVariable["AP_lastgov_message", [0, 0]] param[1, 0])) exitWith {
                [format["You have sent a recent governor message! Try again in %1 second(s).", round((profileNamespace getVariable["AP_lastgov_message", [0, 0]] param[1, 0]) - serverTime)], "basic"] spawn AP_fnc_handleMessage;
            };
            if (!isNull (findDisplay 3000)) then {  };
            [format["Message Sent To All: %1", _message], "basic"] spawn AP_fnc_handleMessage; [
                [10, player, objNull, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;
            profileNameSpace setVariable["AP_lastgov_message", [AP_instance_id, serverTime + 1800]];};
    case 8: {if ((call AP_eventCoordinatorLevel) <= 0) exitWith {};
            if ((count _message) > 500) exitWith {["The message you entered is too long to send!", "basic"] spawn AP_fnc_handleMessage;};
            if (!isNull (findDisplay 3000)) then {  };
            [format["Message Sent To All: %1", _message], "basic"] spawn AP_fnc_handleMessage; [
                [11, player, objNull, _message], "APS_fnc_handlePhoneMsg", false] call AP_fnc_MP;};};