/*
    APS_fnc_eventBlackoutSRV  (LooneyBin world event -- Ben Bones canon). AP_adminEvent type 11.
    "The Governor missed the power bill." Every streetlamp within 900m of the chosen city square goes DARK
    for 10 minutes (switchLight OFF is a global effect on the map lamps), then the grid "recovers"
    (switchLight AUTO). Pure ambiance + crime enablement; no damage, fully reversible.
*/
if (!isServer) exitWith {};
params [["_locID", -1, [0]]];
if !([4, "eventBlackoutSRV START"] call APS_fnc_isAdminCaller) exitWith {};   // admin-menu event (eventCfg owner-only row, client gate >= 4): the caller's DB adminlevel, never the payload
if (AP_adminEvent param [0, false]) exitWith {};
AP_adminEvent = [true, false, 11, _locID];
publicVariable "AP_adminEvent";
private _locData = (["getLocationByID", _locID] call AP_fnc_eventCfg);
private _locName = _locData param [1, "?"];
private _pos = _locData param [2, [0,0,0]];

private _lamps = (_pos nearObjects ["Lamps_base_F", 900]) + (_pos nearObjects ["PowerLines_base_F", 900]);
{ _x switchLight "OFF"; } forEach _lamps;
diag_log format ["[LooneyBin][blackout] %1: %2 lamps dark", _locName, count _lamps];

[[0, format ["BLACKOUT IN %1! The Governor's office 'is aware of the situation'. Grid crews estimate 10 minutes. Lock your doors.", _locName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
["GRID", format ["%1 GOES DARK -- GOVERNOR 'FORGOT' THE POWER BILL, SAYS SOURCE", toUpper _locName], format ["the lights are OUT in %1. this is what they WANT. crime o'clock, patriot. i'll be in the bunker (generator).", _locName]] call APS_fnc_newsPush;
["-BLACKOUT-", objNull, "SERVER", format ["%1: %2 lamps off", _locName, count _lamps]] call APS_fnc_logIt;

[_lamps, _locName] spawn {params ["_lamps", "_locName"];
    uiSleep 600;
    { if (!isNull _x) then { _x switchLight "AUTO"; }; } forEach _lamps;
    if (AP_adminEvent param [0, false] && {(AP_adminEvent param [2, 0]) isEqualTo 11}) then {
        AP_adminEvent = [false, false, 0, 0]; publicVariable "AP_adminEvent";
        [[0, format ["Power restored in %1. The Governor took credit.", _locName]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    };
    diag_log format ["[LooneyBin][blackout] %1: restored", _locName];};
