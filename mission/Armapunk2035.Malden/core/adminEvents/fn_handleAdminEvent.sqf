disableSerialization;
if ((lbCurSel 3901) isEqualTo - 1) exitWith {["You must select an event to host.", "basic"] spawn AP_fnc_handleMessage;};
if ((lbCurSel 3902) isEqualTo - 1) exitWith {["You must select a location to host the event.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_adminEvent select 0) exitWith {["There is already an admin event in progress.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_seasonalEvent select 0) exitWith {
    ["A seasonal event is already in progress / about to start and therefor no admin events can be started", "basic"] spawn AP_fnc_handleMessage;
};
private _eventID = parseNumber(lbData[3901, lbCurSel 3901]);
private _locationID = parseNumber(lbData[3902, lbCurSel 3902]);
private _exit = false;
private _confirm = ["Do you want to start the admin event?", "Start Admin Event", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_confirm) then {_exit = true;};
if (_exit) exitWith {};
_locationID call((["getEventByID", _eventID] call AP_fnc_eventCfg) select 3);