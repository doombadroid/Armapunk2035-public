/*
    File: fn_mapEditor.sqf  (AP_fnc_mapEditor)
    The in-game map editor session, on top of Splendid Camera.

    THE CAMERA IS BIS_fnc_camera. The first version carried its own free camera and
    mouse-look; it was unusable in the owner's hands and, more to the point, it was a
    worse copy of a camera every Arma admin already knows. Splendid Camera owns
    movement, look, speed and exit; this session adds selection and editing on top of
    its display (BIS_fnc_camera_display) and reads the view through the active camera.

    A CLIENT-SIDE SESSION WITH NO AUTHORITY OF ITS OWN. Every mutation is a request to
    APS_fnc_mapEditSRV; the world changes only when the server's broadcast returns
    through AP_fnc_mapEditApply, so the admin sees exactly what every other client sees
    and a refused edit visibly does nothing. The level check here is UI courtesy.

    ONLY MAP OBJECTS ARE SELECTABLE. Selection requires AP_mapId, the integer row id
    fn_dynamicMapSystem sets on every streamed object. Players, vehicles, mission
    content and the designer's own entities have no id and are invisible to the tool.

    Keys (chosen to avoid every Splendid Camera binding -- WASD/Q/Y, LMB/RMB, 0-9,
    numpad, Space, N, M, Backspace, F1, Ctrl+P/X/C/V, Esc):
        Enter  select what the camera centre is on / confirm a grab or nudge
        G      grab (object follows the view); X cycles the constraint axis
        Up/Dn  nudge along the active axis by AP_mapEd_snap
        C      cancel a pending grab or nudge
        Del    delete the selection
        Tab    panel (catalogue + exact numbers)
        Ctrl+Z undo the last move
        Esc    Splendid's exit -- also ends this session (pending edits are cancelled)

    Toggle: [] call AP_fnc_mapEditor   (F12)
*/
if (!hasInterface) exitWith {};

// Splendid stores its display with a bare assignment in whichever namespace its onLoad
// happens to run in. Look in both, every time.
if !(isFinal "AP_fnc_mapEdCamDisplay") then {AP_fnc_mapEdCamDisplay = compileFinal {
    private _d = missionNamespace getVariable ["BIS_fnc_camera_display", displayNull];
    if (isNull _d) then { _d = uiNamespace getVariable ["BIS_fnc_camera_display", displayNull]; };
    _d
}};

if !(isFinal "AP_fnc_mapEdTeardown") then {AP_fnc_mapEdTeardown = compileFinal {
    if (isNil "AP_mapEd_active" || {!AP_mapEd_active}) exitWith {};
    AP_mapEd_active = false;
    if (count AP_mapEd_drag > 0) then { [] call AP_fnc_mapEdCancelGrab; };
    if !(isNil "AP_mapEd_ehDraw")  then { removeMissionEventHandler ["Draw3D",    AP_mapEd_ehDraw]; };
    if !(isNil "AP_mapEd_ehFrame") then { removeMissionEventHandler ["EachFrame", AP_mapEd_ehFrame]; };
    private _d = call AP_fnc_mapEdCamDisplay;
    if (!isNull _d) then {
        {
            _x params ["_var", "_evt"];
            private _h = missionNamespace getVariable [_var, -1];
            if (_h >= 0) then { _d displayRemoveEventHandler [_evt, _h]; };
        } forEach [["AP_mapEd_ehKeyDown", "KeyDown"], ["AP_mapEd_ehUnload", "Unload"]];
    };
    { missionNamespace setVariable [_x, nil]; } forEach ["AP_mapEd_ehDraw", "AP_mapEd_ehFrame", "AP_mapEd_ehKeyDown", "AP_mapEd_ehUnload"];
    AP_mapEd_sel = objNull;
    systemChat "MAP EDITOR: off";
}};

// ---- selection ray: whatever the active camera's centre is on ------------
if !(isFinal "AP_fnc_mapEdUnderCursor") then {AP_fnc_mapEdUnderCursor = compileFinal {
    private _from = AGLToASL (positionCameraToWorld [0, 0, 0]);
    private _to   = AGLToASL (positionCameraToWorld [0, 0, 300]);
    private _hits = lineIntersectsSurfaces [_from, _to, player, objNull, true, 8, "GEOM", "NONE"];
    private _found = objNull;
    {
        private _o = _x param [2, objNull];
        if (!isNull _o && {(_o getVariable ["AP_mapId", -1]) >= 1}) exitWith { _found = _o; };
    } forEach _hits;
    _found
}};

if !(isFinal "AP_fnc_mapEdBox") then {AP_fnc_mapEdBox = compileFinal {
    params ["_o", "_col"];
    private _bb = boundingBoxReal _o;
    _bb params ["_min", "_max"];
    private _c = [];
    { _c pushBack (_o modelToWorldVisual _x); } forEach [
        [_min select 0, _min select 1, _min select 2], [_max select 0, _min select 1, _min select 2],
        [_max select 0, _max select 1, _min select 2], [_min select 0, _max select 1, _min select 2],
        [_min select 0, _min select 1, _max select 2], [_max select 0, _min select 1, _max select 2],
        [_max select 0, _max select 1, _max select 2], [_min select 0, _max select 1, _max select 2]];
    { _x params ["_a", "_b"]; drawLine3D [_c select _a, _c select _b, _col]; }
        forEach [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]];
}};

// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};

// ---------------------------------------------------------------- close
if (!isNil "AP_mapEd_active" && {AP_mapEd_active}) exitWith {
    [] call AP_fnc_mapEdTeardown;
    // closing Splendid's display makes it exit cleanly; its Unload would call the
    // teardown again, which is why teardown is idempotent
    private _cd = call AP_fnc_mapEdCamDisplay;
    if (!isNull _cd) then { _cd closeDisplay 1; };
};

// ---------------------------------------------------------------- open
if ((call AP_adminLevel) < 5) exitWith { hint "Map editor is level 5."; };
if (!isNull (missionNamespace getVariable ["BIS_fnc_camera_display", displayNull]) || {!isNull (uiNamespace getVariable ["BIS_fnc_camera_display", displayNull])}) exitWith { hint "Splendid Camera is already open -- close it first."; };

AP_mapEd_active = true;
AP_mapEd_sel    = objNull;
AP_mapEd_drag   = [];          // [axisIndex, grabDistance, startWorldPos, tracking] while an edit is pending
AP_mapEd_axis   = 2;           // 0=X 1=Y 2=Z
AP_mapEd_snap   = 0.1;         // metres per nudge; the panel changes it
AP_mapEd_undo   = [];

AP_mapEd_ehDraw = addMissionEventHandler ["Draw3D", {
    if (isNil "AP_mapEd_active" || {!AP_mapEd_active}) exitWith {};
    // a small centre reticle so the selection ray has a visible origin
    private _c = positionCameraToWorld [0, 0, 20];
    drawIcon3D ["\a3\ui_f\data\IGUI\Cfg\Cursors\iconCursorSupport_ca.paa", [1,1,1,0.6], _c, 0.6, 0.6, 0, "", 0];
    private _hover = call AP_fnc_mapEdUnderCursor;
    if (!isNull _hover && {_hover != AP_mapEd_sel}) then { [_hover, [1, 1, 1, 0.35]] call AP_fnc_mapEdBox; };
    if (!isNull AP_mapEd_sel) then {
        [AP_mapEd_sel, [0.2, 1, 0.4, 0.9]] call AP_fnc_mapEdBox;
        [AP_mapEd_sel] call AP_fnc_mapEdGizmo;
        private _pw = getPosWorld AP_mapEd_sel;
        drawIcon3D ["", [0.2,1,0.4,1], ASLToAGL _pw vectorAdd [0,0,1.2], 0, 0, 0,
            format ["row %1  [%2 %3 %4]  axis %5%6", AP_mapEd_sel getVariable ["AP_mapId", "?"],
                (_pw select 0) toFixed 2, (_pw select 1) toFixed 2, (_pw select 2) toFixed 2,
                ["X","Y","Z"] select AP_mapEd_axis, if (count AP_mapEd_drag > 0) then {"  [pending: Enter confirm / C cancel]"} else {""}],
            1, 0.03, "RobotoCondensed"];
    };
}];

[] call AP_fnc_mapEditorOps;

// ---- Splendid Camera, then our handlers on ITS display --------------------
[] spawn {
    diag_log "[AP-MAPEDIT] editor: opening Splendid Camera";
    [] spawn BIS_fnc_camera;
    private _t0 = diag_tickTime;
    waitUntil { !isNull (call AP_fnc_mapEdCamDisplay) || {diag_tickTime - _t0 > 8} };
    private _d = call AP_fnc_mapEdCamDisplay;
    if (isNull _d) exitWith {
        diag_log format ["[AP-MAPEDIT] editor: no camera display after 8s (mn=%1 ui=%2)",
            missionNamespace getVariable ["BIS_fnc_camera_display", "nil"], uiNamespace getVariable ["BIS_fnc_camera_display", "nil"]];
        systemChat "MAP EDITOR: Splendid Camera did not open"; [] call AP_fnc_mapEdTeardown;
    };
    diag_log format ["[AP-MAPEDIT] editor: camera display %1 (mission ns: %2) cam=%3", _d,
        !isNull (missionNamespace getVariable ["BIS_fnc_camera_display", displayNull]), missionNamespace getVariable ["BIS_fnc_camera_cam", "nil"]];
    [] call AP_fnc_mapEditorInput;
    systemChat "MAP EDITOR: on.  Enter select/confirm | G grab | X axis | Up/Dn nudge | C cancel | Del | Tab panel | Ctrl+Z undo | Esc exit";
};
