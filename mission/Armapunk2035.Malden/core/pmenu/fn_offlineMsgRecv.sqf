/*
    AP_fnc_offlineMsgRecv  (Armapunk 2035, owner 2026-08-11) -- take delivery of the texts that
    arrived while this player was offline. CfgRE allowedTargets = 1 (server -> client only).

    Pushed by APS_fnc_offlineMsgDeliver as ONE batch: [[fromName, text], ...].

    Deliberately NOT routed through AP_fnc_clientMessage. That function throws a full-screen
    "New Message" box and a systemChat line per text, which is right for a live message and very
    wrong for a backlog -- someone away overnight would log in to a stack of boxes. These land
    silently in the thread store and the inbox, and the player gets a single summary instead.
    The unread counts AP_fnc_msgAppend keeps are what actually draws attention to them.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_msgs", [], [[]]]];
if (_msgs isEqualTo []) exitWith {};

private _n = 0;
private _senders = [];
{
    _x params [["_from", "", [""]], ["_txt", "", [""]], ["_fromUid", "", [""]]];
    if (_from isNotEqualTo "" && {_txt isNotEqualTo ""}) then {
        // Remember who they are BEFORE filing the message. The thread store is keyed by display
        // name, so without this the reply button has no uid to send to and the send is refused
        // -- which is exactly what happened to the first offline batch.
        if (_fromUid isNotEqualTo "") then { [_from, _fromUid] call AP_fnc_msgUidSet; };
        [_from, 0, _txt] call AP_fnc_msgAppend;                       // thread store + unread
        AP_messages pushBack [_from, format [">>>MESSAGE FROM %1: %2", _from, _txt], time];
        if !(_from in _senders) then { _senders pushBack _from };
        _n = _n + 1;
    };
} forEach _msgs;

if (_n isEqualTo 0) exitWith {};

private _who = if (count _senders isEqualTo 1) then { _senders select 0 }
               else { format ["%1 people", count _senders] };
[format ["<t color='#c9e21a'>%1 MESSAGE%2</t> arrived while you were away -- from %3. Open the phone to read %4.",
    _n, ["S", ""] select (_n isEqualTo 1), _who, ["them", "it"] select (_n isEqualTo 1)], "basic"] spawn AP_fnc_handleMessage;
systemChat format ["[PHONE] %1 message(s) received while you were offline.", _n];
