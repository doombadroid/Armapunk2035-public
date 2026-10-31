if (isDedicated) exitWith {};
// SEC (audit 2026-09-26): a message ANOTHER CLIENT sent is screened HERE, before the respawn below. The spawned
// copy reads isRemoteExecuted false (frame-local), so a client's remoteExecCall used to shed every sender check in
// this file -- and _condition is CODE that fn_createMessage calls every 10 ms, i.e. arbitrary SQF on every target.
// No client->client send in the tree carries a _condition or a style outside this list (grep the quoted fn name),
// so anything else is refused and reported (dong 60, the reported sender in var/val). What passes is rebuilt as
// [text, style, {true}, true]: slot 3 marks it untrusted across the respawn. It can only ever REMOVE trust -- a
// client cannot clear it, because its own frame always reads _reClient true and gets rebuilt.
private _reClient = isRemoteExecuted && {remoteExecutedOwner != 2};
private _reType = if (_reClient) then {toLower (_this param [1, "", [""]])} else {""};
if (_reClient && {!(_this isEqualType []) || {count _this > 2} || {!(_reType in ["", "basic", "copalert", "shortwarning", "cartelcapture", "event"])}}) exitWith {
    [[player, [60, "sender", str remoteExecutedOwner]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
if (_reClient) then {_this = [_this param [0, "", [""]], _reType, {true}, true];};
if ((isNil "_thisScript") || !(canSuspend)) exitWith {_this spawn AP_fnc_handleMessage};
if (isNil "AP_message_active") exitWith {};
params[["_text", ""], ["_type", ""], ["_condition", {true}], ["_untrusted", false, [false]]];
if (_text isEqualTo "") exitWith {};
// PR9 (LANDING SCREEN), widened to every web duty page in PR11 -- the refusal tap, and it is a READ, not a
// hook: nothing below sees it, no message is consumed, altered, delayed or suppressed, and with no request
// in flight it is one getVariable per call.
// WHY IT HAS TO BE HERE. A web page's sign-on button is a Promise the page is holding open, and a duty
// request is fire-and-forget: a GRANT comes back as a server push into AP_fnc_dutyClient (which leaves
// AP_onDuty + AP_dutyFaction behind for anyone to read -- fn_casino.sqf:42's idiom), but a REFUSAL comes
// back as a server push into THIS function and leaves nothing at all. APS_fnc_dutySRV's _fnc_refuse and
// fn_dutyClient's own two aborts all arrive here and nowhere else, so this is the only point at which an
// async refusal can be correlated back to the page that is waiting for it.
// ARMED ONLY WHILE A REQUEST IS IN FLIGHT: AP_dutyReqWait is set immediately before the send and cleared
// the moment the wait ends (AP_fnc_dutyRequest, the one owner of both slots -- the landing screen at
// connect and the MaxSec duty terminal at the HQ tablet both go through it), which is a window of seconds
// per sign-on attempt. The grant is tested FIRST on the other side, so the apply's own "You are on duty:
// ..." cannot be read as a refusal. Restricted to "basic" because every duty refusal is "basic", and to the
// FIRST such message because the first one after the send is the answer.
// SENDER GUARD. Without this, `["<anything>","basic"] remoteExec ["AP_fnc_handleMessage", <victim>]` from
// ANY client during that window writes AP_dutyReqErr with attacker-controlled text -- the tap checks
// the message's SHAPE, not who sent it. The two legitimate producers survive: dutySRV's _fnc_refuse spawns
// AP_fnc_MP with _unit as the remoteExec target FROM THE SERVER, so the victim's client sees isRemoteExecuted
// true and remoteExecutedOwner 2 (the sender screen at the top of this file uses the identical
// idiom); fn_dutyClient's two aborts (:207, :247) are local `spawn`s, which are FRAME-LOCAL for
// remoteExecutedOwner (fn_dutySRV.sqf's own comment on the same command) and so read isRemoteExecuted false
// regardless of whether the enclosing apply was itself remoteExec'd from the server. The test reads
// _untrusted, which that screen sets and which (unlike isRemoteExecuted) survives the respawn at the top.
if ((missionNamespace getVariable ["AP_dutyReqWait", ""]) isNotEqualTo ""
    && {(missionNamespace getVariable ["AP_dutyReqErr", ""]) isEqualTo ""}
    && {(toLower _type) isEqualTo "basic"} && {_text isEqualType ""}
    && {!_untrusted}) then { AP_dutyReqErr = _text; };
// Streamer Mode: filter every incoming message (admin/adminall/player/cop/gov/etc.) before it renders.
// Runs on the raw text ahead of the switch, so img/<t> wrappers added per-type are unaffected.
if (!isNil "AP_streamerMode" && {AP_streamerMode} && {_text isEqualType ""}) then { _text = [_text] call AP_fnc_profanityFilter; };
private _duration = 7;
private _priority = 5;
private _color = [0.216, 0.910, 0.941];
private _textCount = 0;
_type = toLower(_type);
if (_type in ["adminall", "fromadmin", "toadmin", "emsmsg", "copmsg", "playermsg", "govall", "federaleventcop", "federaleventmedic"]) then { playSound "taskAssigned"; };   // LooneyBin: Arma new-objective ping on incoming texts/admin/gov/server messages
switch (_type) do {case "basic": {_textCount = (((count(str(_text))) - 256) / 4);
            _duration =
            if (_textCount < 7) then {7} else {
                // owner 2026-06-16 (#256): duration scales with the RAW string length, which counts every HTML
                // tag (<t color=...> etc). The cop search readout is a huge formatted block -> ~60s on screen
                // ("search menu stays open for ~60s"). Cap basic messages at 20s; no plain message needs more.
                (round(_textCount)) min 20};
            _priority = 5;
            _color = [0.216, 0.910, 0.941];};
        case "bones": {
                // owner 2026-07-17: Ben Bones texts dwell a fixed 30s (was "basic" -> length-scaled, capped 20s).
                _duration = 30;
                _priority = 9;
                _color = [0.910, 0.698, 0.227];   // Ben Bones gold (#e8b23a)
            };
        case "copalert": {_duration = 30;
                _priority = 9;
                _color = [0.255, 0.478, 0.800];
                _text = format["<img size='0.8' image='icons\badgeico.paa' />  %1", _text];};
        case "medicalert": {_duration = 30;
                _priority = 9;
                _color = [0.255, 0.478, 0.800];
                _text = format["<img size='0.8' image='icons\med_emt.paa' />  %1", _text];};
        case "federaleventcop": {_duration = 15;
                _priority = 13;
                _color = [0.255, 0.478, 0.800];
                _text = format["<img size='0.8' image='icons\badgeico.paa' /><t align='center'><t color='#FF0000'><t size='1.5'>Federal Event</t></t><br/><br/>All MaxSec officers are being requested for assistance in quelling the %1.", _text];
            };
        case "federaleventmedic": {_duration = 15;
                _priority = 13;
                _color = [0.255, 0.478, 0.800];
                _text = format["<img size='0.8' image='icons\med_emt.paa' /><t align='center'><t color='#FF0000'><t size='1.5'>TT Dispatch</t></t><br/><br/>The alarm at the %1 has been activated!", _text];
            };
        case "maxtac": {_duration = 30;
                _priority = 12;
                _color = [0.255, 0.478, 0.800];
                _text = format["<img size='0.8' image='icons\badgeico.paa' /><t align='center'><t color='#FF0000'><t size='1.5'>Requesting MaxTac</t></t><br/><br/>Active duty MaxTac members are being requested for assistance in quelling the %1. Please report to the nearest MaxSec HQ or Checkpoint to gear up!", _text];
            };
        case "warning": {_duration = 30;
                _priority = 9;
                _color = [0.957, 0.686, 0.176];
                _text = format["<img size='0.8' image='icons\warningico.paa' />  %1", _text];};
        case "servernotice": {_duration = 30;
                _priority = 15;
                _color = [0.957, 0.686, 0.176];
                _text = format["<img size='0.8' image='icons\warningico.paa' />  %1", _text];};
        case "shortwarning": {_duration = 10;
                _priority = 9;
                _color = [0.957, 0.686, 0.176];
                _text = format["<img size='0.8' image='icons\warningico.paa' />  %1", _text];};
        case "tutorial": {_duration = 30;
                _priority = 9;
                _color = [0.957, 0.686, 0.176];
                _text = format["<img size='0.8' image='icons\tutorial.paa' />  %1", _text];};
        case "civ_restraints": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "bank_robbery": {_duration = (60 * 15);
                _priority = 10;
                _color = [0.2, 1.0, 0.73];   // LooneyBin 2026-07-18: cyberdeck cyan (#33ffbb) -- style unchanged, just the colour
            };
        case "lb_doorfuse": {_duration = (60 * 5);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];   // Loony Bin door satchel: 5-minute fuse, danger red
            };
        case "lb_database": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.2, 1.0, 0.73];        // Loony Bin record-database breach: cyberdeck cyan
            };
        case "fed_countdown": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.2, 1.0, 0.73];   // cyberdeck cyan, same as the bank drill
            };
        case "alamo_countdown": {_duration = (60 * 20);
                _priority = 10;
                _color = [0.957, 0.686, 0.176];   // amber -- a second, longer clock, visibly not the first
            };
        case "prison_break": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "evidence_lockup": {_duration = (60 * 15);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "evidence_lockup_ext": {_duration = (60 * 25);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "civ_lockup": {_duration = (60 * 15);
                _priority = 10;
                _color = [0.957, 0.686, 0.176];};
        case "civ_lockup_ext": {_duration = (60 * 25);
                _priority = 10;
                _color = [0.957, 0.686, 0.176];};
        case "policerecruit": {_duration = 30;
                _priority = 5;
                _color = [0.937, 0.192, 0.224];};
        case "playermsg": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 10;
                _color = [0.945, 0.239, 0.659];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#9342f5' />  %1", _text];};
        case "copmsg": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 11;
                _color = [0.255, 0.478, 0.800];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#0035f5' />  %1", _text];};
        case "adminall": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 10;
                _color = [0.937, 0.192, 0.224];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#ff1100' />  %1", _text];};
        case "emsmsg": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 11;
                _color = [0.325, 0.890, 0.612];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#0b9401' />  %1", _text];};
        case "toadmin": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 12;
                _color = [0.937, 0.192, 0.224];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#ff1100' />  %1", _text];};
        case "fromadmin": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 12;
                _color = [0.937, 0.192, 0.224];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#ff1100' />  %1", _text];};
        case "cartelcapture": {_duration = 15;
                _priority = 10;
                _color = [0.957, 0.686, 0.176];
                _text = format["<img size='1.5' image='\A3\Ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa' color='#ff1100' /><t align='center'><t color='#FF0000'><t size='1.5'>Attention</t></t><br/><br/><t color='#ffffff'>Your territory zone, <t color='#00ff00'>%1</t>, is being captured by another gang!", _text];
            };
        case "weppurchase": {_duration = 10;
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "lottoinfo": {_duration = 15;
                _priority = 5;
                _color = [0.325, 0.890, 0.612];
                _text = format["<img size='0.8' image='icons\dollarsign.paa' />  %1", _text];};
        case "event": {_duration = 30;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];};
        case "timetrialevent": {_duration = 15;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];};
        case "turf": {_duration = 15;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];};
        case "speedingticket": {_duration = 8;};
        case "cartel_event": {_duration = 20;
                _priority = 10;
                _color = [0.957, 0.686, 0.176];
                _text = format["<img size='1.5' image='a3\Ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa' color='#ff7d15' /><t ><t color='#ff7d15'><t size='1.5'>Cartel Event</t></t><br/><t >%1</t>", _text];
            };
        case "mentalrob_first": {_duration = (60 * 5);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "mentalrob_second": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "jewelrob_first": {_duration = (60 * 5);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "jewelrob_second": {_duration = (60 * 13);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "jewelrob_bonus": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "jewelrob_safe": {_duration = (60 * 1.5);
                _priority = 9;
                _color = [0.937, 0.192, 0.224];};
        case "jewelrob_loadsafe": {_duration = (60 * 5);
                _priority = 10;
                _color = [0.937, 0.192, 0.224];};
        case "exchange": {_duration = 20;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];
                _text = format["<img size='1' image='icons\dollarsign.paa' /><t ><t color='#00ff00'><t size='1'>LoonyBin Exchange</t></t><br/><t >%1</t>", _text];
            };
        case "giveaway": {_duration = 13;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];
                _text = format["<img size='1' image='icons\loonybinpartystreamer.paa' /><t ><t color='#18e3f3'><t size='1'>LoonyBin Giveaway</t></t><br/><t >%1</t>", _text];
            };
        case "login_bonus": {_duration = 13;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];
                _text = format["<img size='1' image='icons\loonybinpartystreamer.paa' /><t ><t color='#fbe296'><t size='1'>Login Bonus</t></t><br/><t >%1</t>", _text];
            };
        case "christmas_present": {_duration = 13;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];
                _text = format["<img size='1' image='icons\loonybinpartystreamer.paa' /><t ><t color='#E40010'><t size='1'>C<t color='#1FD537'>h</t>r<t color='#1FD537'>i</t>s<t color='#1FD537'>t</t>m<t color='#1FD537'>a</t>s <t color='#1FD537'>g</t>i<t color='#1FD537'>f</t>t</t></t><br/><t >%1</t>", _text];
            };
        case "phone_call": {_duration = 15;
                _priority = 5;
                _color = [0.216, 0.910, 0.941];
                _text = format["<img size='1' image='icons\phone_phone.paa' /><t ><t color='#6bf017'><t size='1'>Phone Call</t></t><br/><t >%1</t>", _text];
            };
        case "govall": {_textCount = (((count _text) - 256) / 4);
                _duration =
                if (_textCount < 10) then {10} else {round(_textCount)};
                _priority = 10;
                _color = [0.325, 0.890, 0.612];
                _text = format["<img size='1.5' image='\A3\ui_f\data\GUI\Cfg\Hints\Chat_ca.paa' color='#00FF00' />  %1", _text];};
        case "cyberjackpot": {_duration = 10;
                _priority = 9;
                _color = [0.79, 0.89, 0.10];
                _text = format["<t align='center'><t color='#c9e21a' size='1.35'>◈ ATM JACKPOT</t><br/><t size='0.95'>%1</t></t>", _text];
            };
        default {_textCount = (((count(str(_text))) - 256) / 4);
            _duration =
            if (_textCount < 7) then {7} else {round(_textCount)};
            _priority = 5;
            _color = [0.216, 0.910, 0.941];};}; for "_i"
from 0 to 1 step 0 do {if (AP_message_active isEqualTo _thisScript) exitWith {};
    waitUntil {uiSleep 0.1;
        scriptDone AP_message_active};
    AP_message_active = _thisScript;}; AP_message_list = AP_message_list select {!isNull(_x select 1)};
private _insertIndex = 0;
private _currentMessages = +AP_message_list;
reverse _currentMessages;
private _foundPriorities = {(_x select 0) isEqualTo _priority}
count _currentMessages; {if ((_x select 0) >= _priority) exitWith {
        _insertIndex = ((count _currentMessages) - (_forEachIndex + _foundPriorities))};}
forEach _currentMessages;
[_insertIndex, _text, _duration, _priority, _color, _condition] call AP_fnc_createMessage;
