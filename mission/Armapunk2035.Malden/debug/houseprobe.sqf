/*
    debug\houseprobe.sqf -- SERVER ONLY, one-shot dev probe. Identify whatever
    stands at a map position: classname (if any), model path, bbox. Terrain
    query included because Malden 2035 map objects are often CLASSLESS terrain
    p3ds (typeOf "") invisible to nearestObjects. grep [HOUSEPROBE].
*/
if (!isServer) exitWith {};
uiSleep 15;
private _pos = [7262.54, 7992.64, 0.4];
{
    diag_log format ["[HOUSEPROBE] obj d=%1 type=%2 model=%3 pos=%4 dir=%5",
        _x distance2D _pos, typeOf _x, getModelInfo _x, getPosASL _x, getDir _x];
} forEach ((nearestObjects [_pos, [], 25]) select { !(_x isKindOf "Man") });
{
    diag_log format ["[HOUSEPROBE] terrain d=%1 type=%2 model=%3 pos=%4",
        _x distance2D _pos, typeOf _x, getModelInfo _x, getPosASL _x];
} forEach (nearestTerrainObjects [_pos, [], 25, false]);
diag_log "[HOUSEPROBE] done";
