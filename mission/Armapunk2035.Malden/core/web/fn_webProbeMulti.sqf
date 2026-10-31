/*
    fn_webProbeMulti.sqf — onLoad for dialog 937610.

    Four CT_WEBBROWSER controls at once. Each gets its own bridge, and each is
    asked who it is. However many answer is how many the engine will really run
    together — a number that was being guessed at.
*/
params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;

private _ids = [937611, 937612, 937613, 937614];
{ 
    private _c = _display displayCtrl _x;
    if (!isNull _c) then { [_c] call webui_fnc_init; };
} forEach _ids;

[_display, _ids] spawn {
    params ["_display", "_ids"];
    uiSleep 6;
    private _alive = 0;
    {
        private _c = _display displayCtrl _x;
        private _r = if (isNull _c) then { nil } else { [_c, "whoami", [_x], 6] call webui_fnc_call };
        if (isNil "_r") then {
            diag_log format ["[WEBPROBE] multi: control %1 did NOT answer", _x];
        } else {
            _alive = _alive + 1;
            diag_log format ["[WEBPROBE] multi: control %1 answered %2", _x, _r];
        };
    } forEach _ids;
    diag_log format ["[WEBPROBE] MULTI RESULT: %1 of %2 browser controls live simultaneously", _alive, count _ids];
};
