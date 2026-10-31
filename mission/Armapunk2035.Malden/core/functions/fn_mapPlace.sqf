/*
    File: fn_mapPlace.sqf  (AP_fnc_mapPlace)
    Puts an existing map object where its row says. The one copy of the placement rule:
    AP_fnc_createVehicleLocal uses it for a fresh class object, APS_fnc_mapRowUpdate for an edit
    that keeps the server's object (the boot resolvers -- the Reserve's gates, safes, dome and
    centre, the bank and emporium gates, the compound gates -- hold handles to is_server objects,
    and a delete + recreate left every one of them stale until the next restart).
    params: 0 = object, 1 = direction (number, or [dir, up]), 2 = WORLD-frame position
            (model centre, mapedit.md), 3 = scale
    Order matters: orientation first, then position, scale LAST -- setDir / setVectorDirAndUp
    rebuild the matrix and reset scale to 1.
*/
params [["_o", objNull, [objNull]], ["_direction", 0, [0, []]], ["_position", [], [[]]], ["_scale", 1, [0]]];
if (isNull _o || {_position isEqualTo []}) exitWith {};
if (_direction isEqualType []) then { _o setVectorDirAndUp _direction; } else { _o setDir _direction; };
_o setPosWorld _position;
if (_scale isNotEqualTo 1) then { _o setObjectScale _scale; };
