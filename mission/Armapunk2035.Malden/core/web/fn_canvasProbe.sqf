/*
    fn_canvasProbe.sqf — open the canvas/WebGL probe, or receive its display.

        [] call AP_fnc_canvasProbe;    <- run this, then read the RPT

    Results print on screen AND to the RPT via the bridge's log handler, because
    the page cannot be read while the game is focused.
*/
// Default is "" so a bare  [] call AP_fnc_canvasProbe  OPENS the probe. With
// displayNull as the default it fell straight through to the onLoad branch,
// found a null display and exited without a word -- which is exactly what a
// no-arg call did on the first attempt.
params [["_arg", "", [displayNull, ""]]];

if (_arg isEqualType "") exitWith {
    if (!isNull (findDisplay 937620)) exitWith { closeDialog 0 };
    diag_log "[CANVASPROBE] opening";
    createDialog "AP_canvas_probe";
};

private _display = _arg;
if (isNull _display) exitWith {};
disableSerialization;
private _ctrl = _display displayCtrl 937621;
if (isNull _ctrl) exitWith { diag_log "[CANVASPROBE] control missing"; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[CANVASPROBE] bridge init failed"; };

[_ctrl, "log", {
    params [["_msg", "", [""]]];
    diag_log format ["[CANVASPROBE] %1", _msg];
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];
