params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle || AP_action_in_use) exitWith {};
if !(alive _vehicle) exitWith {};
if (player distance2D _vehicle > 7) exitWith {["You are too far from the vehicle!", "basic"] spawn AP_fnc_handleMessage;};
if ({player distance getMarkerPos format["oil_%1", _x] < 150}
count[1, 2, 3, 4, 5] isEqualTo 0) exitWith {["You can't drill for oil at this location!", "basic"] spawn AP_fnc_handleMessage;};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
[_vehicle, 1200] call AP_fnc_setVehicleIdle;
if !(_vehicle getVariable["AP_oilPump", false]) then {["The pump and drill are setting up.", "basic"] spawn AP_fnc_handleMessage;
    private _text = "Setting up the drill and pump.";
    _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
    AP_is_processing = true;
    AP_action_in_use = true;
    _vehicle enableRopeAttach false;
    private _sleep = 0.3;
    for "_i"
    from 0 to 1 step 0 do {uiSleep _sleep;
        _cP = _cP + 0.01;
        _progress progressSetPosition _cP;
        _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
        if (_cP >= 1) exitWith {_success = true;};
        if (player distance _vehicle > 10) exitWith {
            ["You need to stay within 10m to setup the drill.", "basic"] spawn AP_fnc_handleMessage;};
        if !(AP_action_in_use) exitWith {["Action cancelled. Aborted lab warm up!", "basic"] spawn AP_fnc_handleMessage;};
        if !(alive player) exitWith {["You need to be alive to setup the drill.", "basic"] spawn AP_fnc_handleMessage;};
        if (count(crew _vehicle) > 0) exitWith {
            ["No one should be inside the truck without special gear.", "basic"] spawn AP_fnc_handleMessage;};}; 5 cutText["", "PLAIN"];
    AP_is_processing = false;
    AP_action_in_use = false;
    if !(_success) exitWith {};
    _vehicle setHit[getText(configfile >> "CfgVehicles" >> typeOf _vehicle >> "HitPoints" >> "HitEngine" >> "name"), 1];
    _vehicle setVariable["AP_oilPump", true, true];} else {["You are retracting the drill.", "basic"] spawn AP_fnc_handleMessage;
    private _text = "Retracting the Drill.";
    _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
    AP_is_processing = true;
    AP_action_in_use = true;
    _vehicle enableRopeAttach true;
    private _sleep = 0.1;
    for "_i"
    from 0 to 1 step 0 do {uiSleep _sleep;
        _cP = _cP + 0.01;
        _progress progressSetPosition _cP;
        _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
        if (_cP >= 1) exitWith {_success = true;};
        if (player distance _vehicle > 10) exitWith {
            ["You need to stay within 10m to setup the drill.", "basic"] spawn AP_fnc_handleMessage;};
        if !(AP_action_in_use) exitWith {["Action cancelled. Aborted lab warm up!", "basic"] spawn AP_fnc_handleMessage;};
        if !(alive player) exitWith {["You need to be alive to retract the drill.", "basic"] spawn AP_fnc_handleMessage;};
    }; 5 cutText["", "PLAIN"];
    AP_is_processing = false;
    AP_action_in_use = false;
    if !(_success) exitWith {};
    (_vehicle setVariable["AP_oilPump", false, true]);
    _vehicle setHit[getText(configfile >> "CfgVehicles" >> typeOf _vehicle >> "HitPoints" >> "HitEngine" >> "name"), 0];};