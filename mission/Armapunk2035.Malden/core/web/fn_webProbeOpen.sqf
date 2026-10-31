/*
    fn_webProbeOpen.sqf — onLoad for dialog 937600 (the transparency rig).
    Just wires the bridge; the page announces itself and fn_webProbe drives it.
*/
params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;
private _ctrl = _display displayCtrl 937601;
if (isNull _ctrl) exitWith { diag_log "[WEBPROBE] control 937601 missing"; };
[_ctrl] call webui_fnc_init;
[_ctrl] spawn webui_fnc_volumeSlave;      // page audio obeys the game's sliders
diag_log "[WEBPROBE] transparency rig open — is the WORLD visible around the panel?";
