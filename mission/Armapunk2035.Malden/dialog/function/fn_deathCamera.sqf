params[["_unit", objNull, [objNull]]];
AP_corpse = _unit;
if (AP_deathCameraEVH != -1) then {removeMissionEventHandler["EachFrame", AP_deathCameraEVH];
    AP_deathCameraEVH = -1;};
AP_deathCamera = "camera"
camCreate(getPosASLVisual(vehicle AP_corpse));
AP_deathCamera camCommit 0;
showCinemaBorder true;
AP_deathCameraEVH = addMissionEventHandler["EachFrame", {if ((isNull AP_corpse) || (isNull AP_deathCamera)) then {
        removeMissionEventHandler["EachFrame", _thisEventHandler];
        AP_deathCameraEVH = -1;
        AP_deathCamera cameraEffect["terminate", "back"];
        camDestroy AP_deathCamera; [[AP_corpse], "AP_fnc_corpse", 0] spawn AP_fnc_MP;} else {private _unit = AP_corpse;
        private _vehicle =
        if (!isNull(objectParent _unit)) then {objectParent _unit} else {vehicle _unit};
        private _position = AGLToASL(_unit modelToWorldVisual(_unit selectionPosition "pelvis"));
        private _distance3D = [0, 3.5, 4.5];
        _distance3D =
        if !(_vehicle isEqualTo _unit) then {_distance3D vectorMultiply 2} else {_distance3D};
        private _relativePosition = AGLToASL(_vehicle modelToWorldVisual _distance3D);
        _relativePosition set[2, (_position select 2) + (_distance3D select 2)];
        private _intersections = lineIntersectsSurfaces[_position, _relativePosition, _vehicle, _unit];
        if ((count _intersections) isEqualTo 1) then {private _surface = _intersections select 0;
            if (([_surface select 2, _surface select 3] findIf {(isNull _x) || (_x isKindOf "CAManBase")}) isEqualTo - 1) then {
                if !((_position distance(_surface select 0)) <= 1) then {_relativePosition = _surface select 0;};};};
        AP_deathCamera camSetTarget(getPosVisual _unit);
        AP_deathCamera camCommit 0;
        private _plb_pos = _relativePosition;
        AP_deathCamera setPosASL _plb_pos;};}];
AP_deathCamera cameraEffect["internal", "back"];