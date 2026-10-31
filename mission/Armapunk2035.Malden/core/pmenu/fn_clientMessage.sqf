params[["_type", -2, [0]], ["_senderName", "", [""]], ["_message", "", [""]], ["_senderObj", objNull, [objNull]]];
if (_type isEqualTo - 2 || _senderName isEqualTo "" || _message isEqualTo "") exitWith {};
switch (_type) do {case 0: {
            if (!isNil "AP_streamerMode" && {AP_streamerMode}) then { _message = [_message] call AP_fnc_profanityFilter; };
            _senderGroup = (group _senderObj) getVariable["AP_grpTag", ""];
            _senderGroup =
            switch (true) do {
                case ((side _senderObj isEqualTo west) && (_senderObj getVariable["AP_unitCopRole", ""] isNotEqualTo "scd")): {
                        "[MaxSec] "};
                case (side _senderObj isEqualTo independent): {"[TT] "};
                case ((side _senderObj isEqualTo civilian) && (_senderGroup isEqualTo "")): {""};
                default {_senderGroup};}; _senderGroupColor =
            switch (true) do {case (_senderObj in (units group player) && AP_effSide isEqualTo civilian): {"00FF00"};
                case ((_senderObj getVariable["AP_aggressive", -300]) > (time - 300)): {"FF0000"};
                case ((_senderObj getVariable["gang_data", [-1]] select 0) in AP_gang_wars): {"FF0000"};
                // Fixer war. The chat colour has to agree with the name tag or the
                // feature reads as half-applied: a red tag over a white name in side
                // chat is the player wondering which one is lying.
                case ([_senderObj] call AP_fnc_factionHostile): {"FF0000"};
                default {"FFFFFF"};};
            [ format ["<t color='#FFCC00'><t size='1.8'><t align='center'>New Message<br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>You<br/><t color='#33CC33'>From: <t color='#%3'>%4%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", _senderName, _message, _senderGroupColor, _senderGroup], "playermsg"] spawn AP_fnc_handleMessage;
            systemChat format[">>>MESSAGE FROM %3%1: %2", _senderName, _message, _senderGroup];
            AP_messages pushBack[_senderName, format[">>>MESSAGE FROM %3%1: %2", _senderName, _message, _senderGroup], time];
            AP_last_message = _senderName;
            // owner 2026-08-11: learn this contact's uid while they are in front of us -- it is
            // what lets us text them back once they have logged off (AP_msgUids).
            if (!isNull _senderObj) then { [_senderName, getPlayerUID _senderObj] call AP_fnc_msgUidSet; };
            [_senderName, 0, _message] call AP_fnc_msgAppend;   // owner 2026-07-20: message-threads store
        };
    case 1: {
            [format["<t color='#316dff'><t size='1.8'><t align='center'>New Dispatch<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Officers<br/><t color='#33CC33'>From: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", _senderName, _message], "copmsg"] spawn AP_fnc_handleMessage;
            systemChat format["---911 DISPATCH FROM %1: %2", _senderName, _message];
            [_senderName, getPosATL _senderObj, "911"] spawn AP_fnc_createLMarker;
            AP_messages pushBack[_senderName, format["---911 DISPATCH FROM %1: %2", _senderName, _message], time];};
    case 2: {
            [format["<t color='#0b9401'><t size='1.8'><t align='center'>New Dispatch<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Medics<br/><t color='#33CC33'>From: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", _senderName, _message], "emsmsg"] spawn AP_fnc_handleMessage;
            systemChat format["---EMT DISPATCH FROM %1: %2", _senderName, _message];
            [_senderName, getPosATL _senderObj, "EMS"] spawn AP_fnc_createLMarker;
            AP_messages pushBack[_senderName, format["---EMT DISPATCH FROM %1: %2", _senderName, _message], time];};
    case 3: {
            [format["<t color='#FF0000'><t size='1.8'><t align='center'>Admin Request<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>Admins<br/><t color='#33CC33'>From: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", _senderName, _message], "toadmin"] spawn AP_fnc_handleMessage;
            systemChat format["???ADMIN REQUEST FROM %1: %2", _senderName, _message];
            [_senderName, getPosATL _senderObj, "ADMIN REQUEST"] spawn AP_fnc_createLMarker;
            AP_messages pushBack[_senderName, format["???ADMIN REQUEST FROM %1: %2", _senderName, _message], time];};
    case 4: {};
    case 5: {
            [format["<t color='#FF0000'><t size='1.8'><t align='center'>Admin Message<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Players<br/><t color='#33CC33'>From: <t color='#ffffff'>The Admins<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%1", _message], "adminall"] spawn AP_fnc_handleMessage;
            systemChat format["!!!ADMIN MESSAGE: %1", _message];
            AP_messages pushBack["The Admins", format["!!!ADMIN MESSAGE: %1", _message], time];
            if ((call AP_adminLevel) >= 2) then {systemChat format["Sent by admin: %1", _senderName];};};
    case 6: {
            [format["<t color='#FF0000'><t size='1.8'><t align='center'>Admin Message<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>You<br/><t color='#33CC33'>From: <t color='#ffffff'>An Admin<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%1", _message], "fromadmin"] spawn AP_fnc_handleMessage;
            systemChat format["!!!ADMIN MESSAGE: %1", _message];
            AP_messages pushBack["The Admins", format["!!!ADMIN MESSAGE: %1", _message], time];
            if ((call AP_adminLevel) >= 2) then {systemChat format["Sent by admin: %1", _senderName];};};
    case 7: {private _unit = _senderObj;
            if (isNull _unit) exitWith {};
            if !(AP_effSide in [west, civilian]) exitWith {};
            if (AP_effSide isEqualTo civilian && (AP_bounty_list findIf {getPlayerUID _unit in _x}
            isEqualTo - 1)) exitWith {};
            if (AP_effSide isEqualTo west && (player distance _unit > 4000)) exitWith {};
            private _distance = str(round(player distance _unit) / 1000) + " km";
            if (round((player distance _unit) / 1000) < 1) then {_distance = str(round(player distance _unit)) + " Meters"};
            private _message = format["An informant has spotted the fugitive, %1, %3 (%2 away). Location indicated on your map.", [_senderName] call AP_fnc_cleanName, _distance, (getPos _unit) call BIS_fnc_locationDescription];
            [format["<t color='#316dff'><t size='1.5'><t align='center'>Fugitive Located<br/><br/><t color='#33CC33'><t align='left'><t size='0.85'>To: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", [profileName] call AP_fnc_cleanName, _message], "basic"] spawn AP_fnc_handleMessage;
            systemChat _message;
            [_senderName, getPosATL _unit, "Fugitive"] spawn AP_fnc_createLMarker;};
    case 8: {private _unit = _senderObj;
            if (isNull _unit) exitWith {};
            if !(77 in AP_side_talents) exitWith {};
            private _message = format["An informant has spotted %1 with a known drug dealer %2.", [_senderName] call AP_fnc_cleanName, (getPos _unit) call BIS_fnc_locationDescription];
            [format["<t color='#316dff'><t size='1.5'><t align='center'>Fugitive Located<br/><br/><t color='#33CC33'><t align='left'><t size='0.85'>To: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", [profileName] call AP_fnc_cleanName, _message], "basic"] spawn AP_fnc_handleMessage;
            systemChat _message;
            [_senderName, getPosATL _unit, "Fugitive"] spawn AP_fnc_createLMarker;};
    case 9: {private _unit = _senderObj;
            if (isNull _unit) exitWith {};
            if !(AP_effSide in [west, civilian]) exitWith {};
            if ((AP_effSide isEqualTo civilian && (AP_bounty_list findIf {getPlayerUID _unit in _x}
            isEqualTo - 1))) exitWith {};
            if (AP_effSide isEqualTo west && player distance _unit > 4000) exitWith {};
            private _distance = str(round(player distance _unit) / 1000) + " km";
            if (round((player distance _unit) / 1000) < 1) then {_distance = str(round(player distance _unit)) + " Meters"};
            private _message = format["The fugitive, %1, has been spotted %4 (%2 away). Bounty reward at least $%3.", [_senderName] call AP_fnc_cleanName, _distance, [parseNumber _message] call AP_fnc_numberText, (getPos _unit) call BIS_fnc_locationDescription];
            [format["<t color='#316dff'><t size='1.5'><t align='center'>Fugitive Located<br/><br/><t color='#33CC33'><t align='left'><t size='0.85'>To: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", [profileName] call AP_fnc_cleanName, _message], "basic"] spawn AP_fnc_handleMessage;
            systemChat _message;
            [_senderName, getPosATL _unit, "Fugitive"] spawn AP_fnc_createLMarker;};
    case 10: {
            [format["<t color='#00FF00'><t size='1.8'><t align='center'>Gov Message<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Players<br/><t color='#33CC33'>From: <t color='#ffffff'>Governor %2<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%1", _message, [_senderName] call AP_fnc_cleanName], "govall"] spawn AP_fnc_handleMessage;
            systemChat format["!!!GOV MESSAGE: %1", _message];
            ["GovMessage", [format["You have received a message from the Governor of %1!", worldName]]] call BIS_fnc_showNotification;
            AP_messages pushBack[format["Governor %1", [_senderName] call AP_fnc_cleanName], format["!!!GOV MESSAGE: %1", _message], time];
        };
    case 11: {
            [format["<t color='#fffb00'><t size='1.8'><t align='center'>Event Message<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Players<br/><t color='#33CC33'>From: <t color='#ffffff'>Event Coordinator<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%1", _message], "eventall"] spawn AP_fnc_handleMessage;
            systemChat format["!!!EVENT MESSAGE: %1", _message];
            AP_messages pushBack["Event", format["!!!EVENT MESSAGE: %1", _message], time];
            if ((call AP_adminLevel) >= 2) then {systemChat format["Sent by event coordinator: %1", _senderName];};};};