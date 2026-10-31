/*
    File: fn_mapEditorOps.sqf  (AP_fnc_mapEditorOps)
    Defines the editor's mutation helpers and the axis gizmo. Called once at session open.

    EVERY OBJECT IS A ROW WITH AN ID. Since the v2 migration a moved object is one
    "move" op keyed by its id and a deleted object is one "del"; the server updates the
    row's transform columns only, so an NPC anchor keeps its init when it is dragged.
    There is no baked/live distinction anywhere in this file any more.

    Undo covers moves. A placement's id is not known client-side until the server's
    broadcast returns, so undoing a placement is a DEL on the row once you can see it.
*/
if (!hasInterface) exitWith {};

if !(isFinal "AP_fnc_mapEdGizmo") then {AP_fnc_mapEdGizmo = compileFinal {
    params ["_o"];
    private _p = ASLToAGL (getPosWorld _o);
    private _len = 1.5 max ((boundingBoxReal _o select 1 select 0) * 1.4);
    {
        _x params ["_v", "_col", "_i"];
        private _bright = if (_i isEqualTo AP_mapEd_axis) then { 1 } else { 0.35 };
        drawLine3D [_p, _p vectorAdd (_v vectorMultiply _len),
            [_col select 0, _col select 1, _col select 2, _bright]];
    } forEach [
        [[1,0,0], [1, 0.25, 0.25], 0],
        [[0,1,0], [0.3, 1, 0.3],   1],
        [[0,0,1], [0.35, 0.55, 1], 2]];
}};

if !(isFinal "AP_fnc_mapEdIdOf") then {AP_fnc_mapEdIdOf = compileFinal { _this getVariable ["AP_mapId", -1] }};

if !(isFinal "AP_fnc_mapEdCancelGrab") then {AP_fnc_mapEdCancelGrab = compileFinal {
    if (count AP_mapEd_drag isEqualTo 0) exitWith {};
    AP_mapEd_drag params ["", "", "_start"];
    if (!isNull AP_mapEd_sel) then { AP_mapEd_sel setPosWorld _start; };
    AP_mapEd_drag = [];
    systemChat "grab cancelled";
}};

if !(isFinal "AP_fnc_mapEdCommitGrab") then {AP_fnc_mapEdCommitGrab = compileFinal {
    if (isNull AP_mapEd_sel) exitWith { AP_mapEd_drag = []; };
    private _o = AP_mapEd_sel;
    private _new = getPosWorld _o;
    private _old = if (count AP_mapEd_drag > 0) then { AP_mapEd_drag select 2 } else { _new };
    AP_mapEd_drag = [];
    if (_new distance _old < 0.0005) exitWith {};

    // Orthonormalise before sending. A non-orthonormal pair does not merely lose
    // precision, it COMPOUNDS -- every trip through angles and back re-rounds it.
    // Measured on the shipped map: the worst row already carries |vdir| = 1.0000191.
    private _d = vectorNormalized (vectorDir _o);
    private _up = vectorUp _o;
    private _u = vectorNormalized (_up vectorDiff (_d vectorMultiply (_d vectorDotProduct _up)));
    private _vdu = [_d, _u];

    // Put it back where it was and let the SERVER move it. The world changes when the
    // broadcast returns, so the admin sees what everyone else sees.
    _o setPosWorld _old;
    private _id = _o call AP_fnc_mapEdIdOf;
    if (_id < 1) exitWith { systemChat "not a map row (no id)"; };
    AP_mapEd_undo pushBack ["move", [_id, _old, [vectorDir _o, vectorUp _o]]];
    [["move", [_id, _new, _vdu]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    systemChat format ["move requested (row %1)", _id];
}};

if !(isFinal "AP_fnc_mapEdDelete") then {AP_fnc_mapEdDelete = compileFinal {
    if (isNull AP_mapEd_sel) exitWith {};
    private _id = AP_mapEd_sel call AP_fnc_mapEdIdOf;
    if (_id < 1) exitWith { systemChat "not a map row (no id)"; };
    [["del", [_id]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    systemChat format ["delete requested (row %1)", _id];
    AP_mapEd_sel = objNull;
}};

if !(isFinal "AP_fnc_mapEdPlace") then {AP_fnc_mapEdPlace = compileFinal {
    params [["_cls", "", [""]]];
    if (_cls isEqualTo "") exitWith {};
    if !([_cls] call AP_fnc_mapPlaceable) exitWith {
        systemChat format ["%1 is not placeable (the server would refuse it too)", _cls];
    };
    // 8 m ahead of the camera, dropped to the surface, aligned to the surface normal
    private _p = AGLToASL (positionCameraToWorld [0, 0, 8]);
    private _gp = [_p select 0, _p select 1, getTerrainHeightASL [_p select 0, _p select 1]];
    private _n = surfaceNormal (ASLToAGL _gp);
    private _d = [0,1,0] vectorDiff (_n vectorMultiply ([0,1,0] vectorDotProduct _n));
    if (vectorMagnitude _d < 0.01) then { _d = [1,0,0]; };
    [["add", [_cls, _gp, [vectorNormalized _d, _n]]], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
    systemChat format ["place requested: %1", _cls];
}};

if !(isFinal "AP_fnc_mapEdUndo") then {AP_fnc_mapEdUndo = compileFinal {
    if (count AP_mapEd_undo isEqualTo 0) exitWith { systemChat "nothing to undo"; };
    private _op = AP_mapEd_undo deleteAt ((count AP_mapEd_undo) - 1);
    _op params ["_kind", "_pl"];
    switch (_kind) do {
        case "move": {
            [["move", _pl], "APS_fnc_mapEditSRV", 2, false] spawn AP_fnc_MP;
            systemChat "undo: move";
        };
        default { systemChat format ["cannot undo: %1", _pl param [0, ""]]; };
    };
}};
