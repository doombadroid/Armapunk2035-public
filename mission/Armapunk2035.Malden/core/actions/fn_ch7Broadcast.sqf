// LooneyBin 2026-06-09: rank OWNER (adminlevel 5) broadcasts free + unlimited from the CH7 station
private _plb_isOwner = (call AP_adminLevel) >= 5;
if (!_plb_isOwner && {(time - AP_last_broadcast) < 2700}) exitWith {
    ["A broadcast was sent within the last 45 minutes. Try again later", "basic"] spawn AP_fnc_handleMessage};
if (!_plb_isOwner && {AP_atmcash < 30000}) exitWith {
    ["You do not have $30,000 in your bank to send a broadcast", "basic"] spawn AP_fnc_handleMessage};
disableSerialization;
["AP_broadcast_menu"] call AP_fnc_createDialog;
private _display = findDisplay 10400;
private _headerInput = _display displayCtrl 10401;
private _messageInput = _display displayCtrl 10402;
private _sendButton = _display displayCtrl 10403;
private _message = "";
_sendButton ctrlAddEventHandler["ButtonClick", {_this spawn {params["_control"];
        _control ctrlEnable false;
        private _header = ctrlText 10401;
        private _message = ctrlText 10402;
        closeDialog 0;
        if ((call AP_adminLevel) < 5) then {   // owners broadcast free
            AP_atmcash = AP_atmcash - 30000;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [1] call AP_fnc_ClupdatePartial;}; [[_header, _message, profileName], "AP_fnc_showBroadcast", -2] spawn AP_fnc_MP;
        AP_last_broadcast = time;
        publicVariable "AP_last_broadcast";};}];
70 cutrsc["rscAAN", "plain", 0.001];
_display = uiNamespace getVariable["BIS_AAN", displayNull];
if (isNull _display) exitWith {};
private _textHeader = _display displayctrl 3001;
private _textLine = _display displayctrl 3002;
private _textClock = _display displayctrl 3003;
while {!isNull(findDisplay 10400)}
do {_message = "";
    for "_i"
    from 1 to 20 do {_message = _message + format["%2 %1", (ctrlText _messageInput), "      --      "]
    }; _textLine ctrlsetstructuredtext parseText _message;
    _textHeader ctrlsetstructuredtext parseText format["<t size='2'>%1</t><br />A paid message from %2", (ctrlText _headerInput), profileName];
    _textClock = _display displayCtrl 3003;
    _textClock ctrlSetText([daytime, "HH:MM"] call BIS_fnc_timeToString);}; 70 cutText["", "plain"];