params[["_vehicle", objNull, [objNull]]];
if (isNull _vehicle) exitWith {systemChat "Error! Null vehicle.";};
if !(alive _vehicle) exitWith {systemChat "Error! Dead vehicle.";};
if (player distance2D _vehicle > 7) exitWith {systemChat "Error! Too far away."};
if (AP_action_in_use) exitWith {};
private _exit = false; {if (_vehicle distance(getMarkerPos _x) < 1000) exitWith {_exit = true;};}
forEach["city", "city_athira", "city_pyrgos", "city_sofia"];
if (_exit) exitWith {["Starting a distillery this close to a city would be unwise.", "basic"] spawn AP_fnc_handleMessage;};
for "_i"
from 1 to 25 do {if (_vehicle distance(getMarkerPos format["dp_1_%1", _i]) < 300) exitWith {_exit = true;};}; if (_exit) exitWith {
    ["I think the delivery man is watching you. Did he just call the cops?", "basic"] spawn AP_fnc_handleMessage;}; {
    private _housePosition = parseSimpleArray(_x select 0);
    if (_vehicle distance _housePosition < 400) exitWith {_exit = true;};}
forEach AP_houses;
if (_exit) exitWith {["You can not start a distillery so close to your own house", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle distance(getMarkerPos "arms_island_crank") < 3200) exitWith {
    ["The arms dealers don't like moonshiners around, starting a distillery here is not possible.", "basic"] spawn AP_fnc_handleMessage;
};
if (_vehicle distance(getMarkerPos "skull_island_crank") < 600) exitWith {
    ["The spirits of those who have been sacrificed can not be desecrated in this manner. Try starting the distillery elsewhere.", "basic"] spawn AP_fnc_handleMessage;
};
if (_vehicle distance(getMarkerPos "courtroom") < 300) exitWith {["Really???", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle distance(getMarkerPos "Respawn_west") < 1000) exitWith {["Really???", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle distance(getMarkerPos "admin_island") < 1000) exitWith {
    ["This island is not a suitable place to distill.", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle distance(getMarkerPos "oilrig_1") < 500) exitWith {
    ["You would have to be drunk on this stuff to think this is a good idea.", "basic"] spawn AP_fnc_handleMessage;};
if (count(nearestObjects[_vehicle, ["Land_i_Shed_Ind_F"], 20]) > 0) exitWith {
    ["You cannot prep your distillery this close to an industrial shed!", "basic"] spawn AP_fnc_handleMessage;};
if ({_vehicle distance getMarkerPos format["police_hq_%1", _x] < 300}
count[1, 2, 3, 4, 5, 6, 7] > 0) exitWith {["You want to go to jail right?", "basic"] spawn AP_fnc_handleMessage;};
if (_vehicle distance(nearestBuilding _vehicle) <= 20) exitWith {
    ["You're too close to a building to be messing with a mobile distillery.", "basic"] spawn AP_fnc_handleMessage};
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_progress progressSetPosition 0.01;
private _cP = 0.01;
private _success = false;
if !(_vehicle getVariable["AP_labMode", false]) then {["The distillery is warming up.", "basic"] spawn AP_fnc_handleMessage;
    private _text = "Warming up the distillery";
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
            ["You need to stay within 10m to warm up the distillery.", "basic"] spawn AP_fnc_handleMessage;};
        if !(AP_action_in_use) exitWith {["Action cancelled. Aborted distillery warm up!", "basic"] spawn AP_fnc_handleMessage;};
        if !(alive player) exitWith {["You need to be alive to warm up the distillery.", "basic"] spawn AP_fnc_handleMessage;};
        if (speed _vehicle > 1) exitWith {["Moving this will make it explode!", "basic"] spawn AP_fnc_handleMessage;};
    }; 5 cutText["", "PLAIN"];
    AP_is_processing = false;
    AP_action_in_use = false;
    if !(_success) exitWith {};
    _vehicle setHit[getText(configfile >> "CfgVehicles" >> typeOf _vehicle >> "HitPoints" >> "HitEngine" >> "name"), 1];
    _vehicle setVariable["AP_labMode", true, true];
    [_vehicle] spawn {params["_vehicle"];
        while {_vehicle getVariable["AP_labMode", false] && alive _vehicle && !(isNull _vehicle)}
        do {if (speed _vehicle > 1) exitWith {
                _vehicle setHit[getText(configfile >> "CfgVehicles" >> typeOf _vehicle >> "HitPoints" >> "HitEngine" >> "name"), 1];
                _vehicle setVariable["AP_labMode", false, true];
                _vehicle enableRopeAttach false;
                ["The distillery shut down while being moved!", "basic"] spawn AP_fnc_handleMessage;};
            uiSleep 4;};}; [[_vehicle, "crankSmoke"], "APS_fnc_srvObjectMonitor", 2, false, false] spawn AP_fnc_MP;
    // owner 2026-06-24 (#493): distillery smoke renders GLOBALLY + JIP-safe via the per-client renderer in
    // initPlayerLocal (keyed off AP_labMode), same as the Glitter RV -> everyone sees it, not just nearby-at-start.
} else {["You are breaking down the distillery equipment.", "basic"] spawn AP_fnc_handleMessage;
    private _text = "Breaking down the distillery";
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
            ["You need to stay within 10m to break down the distillery.", "basic"] spawn AP_fnc_handleMessage;};
        if !(AP_action_in_use) exitWith {
            ["Action cancelled. You didn't break down the distillery!", "basic"] spawn AP_fnc_handleMessage;};
        if !(alive player) exitWith {["You need to be alive to break down the distillery.", "basic"] spawn AP_fnc_handleMessage;};
    }; 5 cutText["", "PLAIN"];
    AP_is_processing = false;
    AP_action_in_use = false;
    if !(_success) exitWith {};
    _vehicle setVariable["AP_labMode", false, true];
    _vehicle setHit[getText(configfile >> "CfgVehicles" >> typeOf _vehicle >> "HitPoints" >> "HitEngine" >> "name"), 0];};