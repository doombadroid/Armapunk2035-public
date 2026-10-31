/*
    File: fn_mapEditorInput.sqf  (AP_fnc_mapEditorInput)
    Editing keys on Splendid Camera's display, and the grab tracker.

    Splendid Camera owns movement and look. This installs ONLY the editing keys, on the
    camera's own display so they arrive while it has focus, and returns false for
    everything else so the camera keeps its bindings. A modal grab makes the selected
    object follow the view at the distance it was grabbed from; X constrains it to an
    axis; Enter confirms, C cancels. Nudging shares the same pending-edit state so a
    whole nudging session is one request.

    NOTHING HERE MUTATES THE WORLD. A confirmed edit sends a request; the object snaps
    back until the server's broadcast returns through AP_fnc_mapEditApply.
*/
if (!hasInterface) exitWith {};
private _d = call AP_fnc_mapEdCamDisplay;
if (isNull _d) exitWith { systemChat "Map editor: no camera display."; };

// Splendid's exit (Esc) unloads its display, and that ends our session. But Splendid may
// also recreate its display during its own init -- an Unload then is NOT an exit. Wait a
// beat: if a camera display is back, re-attach to it; if not, tear down.
if (!isNil "AP_mapEd_ehFrame") then { removeMissionEventHandler ["EachFrame", AP_mapEd_ehFrame]; AP_mapEd_ehFrame = nil; };
AP_mapEd_ehUnload = _d displayAddEventHandler ["Unload", {
    [] spawn {
        uiSleep 0.5;
        if (isNil "AP_mapEd_active" || {!AP_mapEd_active}) exitWith {};
        private _again = call AP_fnc_mapEdCamDisplay;
        if (isNull _again) then {
            diag_log "[AP-MAPEDIT] editor: camera display unloaded -- session ends";
            [] call AP_fnc_mapEdTeardown;
        } else {
            diag_log "[AP-MAPEDIT] editor: camera display recreated -- re-attaching";
            [] call AP_fnc_mapEditorInput;
        };
    };
    false
}];

AP_mapEd_ehFrame = addMissionEventHandler ["EachFrame", {
    if (isNil "AP_mapEd_active" || {!AP_mapEd_active}) exitWith {};
    // GRAB mode: the object tracks the camera ray at the distance it was grabbed from.
    // A nudge shares the pending state but must not be dragged back to the ray.
    if (count AP_mapEd_drag > 0 && {AP_mapEd_drag param [3, false]} && {!isNull AP_mapEd_sel}) then {
        AP_mapEd_drag params ["_axis", "_dist", "_start"];
        private _target = AGLToASL (positionCameraToWorld [0, 0, _dist]);
        if (_axis > -1) then {
            private _ax = [[1,0,0],[0,1,0],[0,0,1]] select _axis;
            _target = _start vectorAdd (_ax vectorMultiply ((_target vectorDiff _start) vectorDotProduct _ax));
        };
        AP_mapEd_sel setPosWorld _target;
    };
}];

AP_mapEd_ehKeyDown = _d displayAddEventHandler ["KeyDown", {
    params ["", "_key", "", "_ctrl", ""];
    if (isNil "AP_mapEd_active" || {!AP_mapEd_active}) exitWith {false};
    if (_key in [28, 34, 45, 200, 208, 46, 211, 15, 44]) then { diag_log format ["[AP-MAPEDIT] editor key %1 ctrl=%2 sel=%3 pending=%4", _key, _ctrl, AP_mapEd_sel, count AP_mapEd_drag > 0]; };
    private _handled = true;
    switch (true) do {
        case (_key isEqualTo 28): {                                  // Enter: confirm, else select
            if (count AP_mapEd_drag > 0) then { [] call AP_fnc_mapEdCommitGrab; }
            else {
                AP_mapEd_sel = call AP_fnc_mapEdUnderCursor;
                if (isNull AP_mapEd_sel) then { systemChat "nothing under the reticle (map objects only)"; }
                else { systemChat format ["selected row %1", AP_mapEd_sel getVariable ["AP_mapId", "?"]]; };
                if (!isNull (uiNamespace getVariable ["AP_mapEd_display", displayNull])) then { [] call AP_fnc_mapEditorPanelSync; };
            };
        };
        case (_key isEqualTo 34): {                                  // G: grab
            if (!isNull AP_mapEd_sel && {count AP_mapEd_drag isEqualTo 0}) then {
                AP_mapEd_drag = [-1, (getPosWorld AP_mapEd_sel) distance (AGLToASL (positionCameraToWorld [0,0,0])), getPosWorld AP_mapEd_sel, true];
                systemChat "grab: move the camera, X to constrain, Enter confirm, C cancel";
            };
        };
        case (_key isEqualTo 45): {                                  // X: cycle constraint axis
            AP_mapEd_axis = (AP_mapEd_axis + 1) mod 3;
            if (count AP_mapEd_drag > 0) then { AP_mapEd_drag set [0, AP_mapEd_axis]; };
            systemChat format ["axis: %1", ["X","Y","Z"] select AP_mapEd_axis];
        };
        case (_key in [200, 208]): {                                 // Up/Down: nudge along the axis
            if (!isNull AP_mapEd_sel) then {
                if (count AP_mapEd_drag isEqualTo 0) then {
                    AP_mapEd_drag = [AP_mapEd_axis, 0, getPosWorld AP_mapEd_sel, false];   // tracking=false: a nudge
                    systemChat "nudging: Enter confirm, C cancel";
                };
                private _ax = [[1,0,0],[0,1,0],[0,0,1]] select AP_mapEd_axis;
                AP_mapEd_sel setPosWorld ((getPosWorld AP_mapEd_sel) vectorAdd (_ax vectorMultiply (AP_mapEd_snap * ([-1, 1] select (_key isEqualTo 200)))));
            };
        };
        case (_key isEqualTo 46): { [] call AP_fnc_mapEdCancelGrab; };            // C: cancel
        case (_key isEqualTo 211): { if (!isNull AP_mapEd_sel) then { [] call AP_fnc_mapEdDelete; }; };   // Del
        case (_key isEqualTo 15): { [] spawn AP_fnc_mapEditorPanel; };           // Tab
        case (_key isEqualTo 44 && _ctrl): { [] call AP_fnc_mapEdUndo; };        // Ctrl+Z
        default { _handled = false; };                                           // Splendid's keys stay Splendid's
    };
    _handled
}];
diag_log format ["[AP-MAPEDIT] editor: handlers installed on %1 (key=%2 unload=%3 frame=%4)", _d, AP_mapEd_ehKeyDown, AP_mapEd_ehUnload, AP_mapEd_ehFrame];
