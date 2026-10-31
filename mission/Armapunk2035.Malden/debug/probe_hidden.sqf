/*
    [AP-PROBE] hidden-terrain-object truth (2026-08-28, 3D-map leak investigation).
    For each sample point: every terrain object within 8 m -> model, isObjectHidden,
    isHidden, and the EXACT ray test fn_mapBake's _emit runs. Server-side, one shot.
    Points: leaked rows near the palace + a control inside the FED hide module +
    one known-visible building.
*/
if (!isServer) exitWith {};
{
    _x params ["_label", "_px", "_py"];
    diag_log format ["[AP-PROBE] ==== %1 (%2,%3)", _label, _px, _py];
    {
        private _obj = _x;
        private _mi = getModelInfo _obj;
        private _pw = getPosWorld _obj;
        private _dirR = -(getDir _obj);   // DEGREES -- SQF trig is degree-based (see fn_mapBake)
        private _bb2 = boundingBoxReal _obj;
        private _qx = (((_bb2 select 1) select 0) - ((_bb2 select 0) select 0)) * 0.3;
        private _qy = (((_bb2 select 1) select 1) - ((_bb2 select 0) select 1)) * 0.3;
        private _zTop = (_pw select 2) + ((_bb2 select 1) select 2) + 4;
        private _zBot = (_pw select 2) + ((_bb2 select 0) select 2) - 4;
        private _found = false;
        private _hitDump = [];
        {
            _x params ["_ox", "_oy"];
            private _wx2 = (_pw select 0) + (_ox * cos _dirR) - (_oy * sin _dirR);
            private _wy2 = (_pw select 1) + (_ox * sin _dirR) + (_oy * cos _dirR);
            private _hits = lineIntersectsSurfaces [[_wx2, _wy2, _zTop], [_wx2, _wy2, _zBot], objNull, objNull, true, 8, "GEOM", "NONE"];
            { _hitDump pushBackUnique format ["%1", _x select 2] } forEach _hits;
            if ((_hits findIf { (_x select 2) isEqualTo _obj || { (_x select 3) isEqualTo _obj } }) > -1) exitWith { _found = true };
        } forEach [[0, 0], [_qx, 0], [-_qx, 0], [0, _qy], [0, -_qy]];
        diag_log format ["[AP-PROBE] obj=%1 model=%2 hidden=%3 simple=%4 rayFound=%5 hitObjs=%6",
            _obj, _mi param [1, "?"], isObjectHidden _obj, isSimpleObject _obj, _found, _hitDump];
    } forEach (nearestTerrainObjects [[_px, _py], [], 8, false]);
} forEach [
    ["LEAK shop near palace",  7174.2, 7900.9],
    ["LEAK house near palace", 7185.0, 7967.0],
    ["LEAK wall near palace",  7296.7, 7892.0],
    ["CONTROL fed module",     11259.3, 4396.9],
    ["CONTROL visible house",  7099.1, 7865.4]
];
diag_log "[AP-PROBE] done";
