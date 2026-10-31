/*
    debug\frame_probe.sqf   --  POSITION-FRAME PROBE  (dev instrumentation)

    Answers one question with numbers: when an allLocalMapEntities entry is spawned, does the model
    end up where the designer's mission.sqm put it?

    Arma anchors an object two different ways and the map pipeline touches both:
      * getPosWorld / setPosWorld / createSimpleObject  -> the MODEL CENTRE ([0,0,0] of the p3d).
        mission.sqm's position[] is in this frame.
      * getPos* / setPos* (ATL/ASL)                     -> the transformed boundingCenter/LandContact.
        debug\mapExportRuntime.sqf captured getPosATL, and fn_createVehicleLocal replays setPosATL.

    Capture and replay both use the boundingCenter frame, so the per-class offset between the two
    frames should cancel and the model centre should land back on the sqm value -- PROVIDED the
    offset is the same for the object the export measured (a real sqm object) and the object the
    loader creates (a createSimpleObject copy, which does not load every LOD). If it is not, every
    exported object is off by that class's offset, which is what "the HESCOs float at the prison"
    would look like.

    So per test row it spawns the SAME class twice, aims both with the entry's own vectors, places
    both with the entry's own ATL height, and prints:
      cS / cR   boundingCenter offset (getPosASL - getPosWorld) for the simple and the real object
      errS/errR model-centre height minus the designer's sqm height  <- 0.000 means faithful
    A settle read follows 1 s later, so a physics nudge cannot be mistaken for a frame error.

    Test rows are seven Malden prison objects (the reported compound), one per class, taken straight
    out of fn_mapData.sqf and paired to the sqm the export actually ran against
    (git show ddae690^:mission/Armapunk2035.Malden/mission.sqm, md5 a93a7b29..).

    Output: diag_log -> loonydev.log (server) or the client RPT. grep [FRAMEPROBE].
    Objects are deleted again; nothing is left in the world.

    DEV INSTRUMENTATION -- remove the initServer.sqf / initPlayerLocal.sqf calls before any live deploy.
*/
if (worldName != "Malden") exitWith {};

private _tag = "[FRAMEPROBE]";

//        class                               entry pos [x, y, ATL z]              entry vectors [[dir],[up]]                          sqm world z (ASL)
private _rows = [
    // the prison stack that the class+XY join collapsed: lower barrier (ATL 0.000 <-> sqm 40.100),
    // then the upper one (ATL 2.126 <-> sqm 42.226). Before the rebuild BOTH entries read 2.126.
    ["Land_HBarrier_Big_F",            [9731.229, 3978.071, 0.000], [[ 0.0205, 0.9998, 0.0000], [0.0000, 0.0000, 1.0000]], 40.100],
    ["Land_HBarrier_Big_F",            [9731.224, 3978.049, 2.126], [[ 0.0205, 0.9998, 0.0000], [0.0000, 0.0000, 1.0000]], 42.226],
    ["Land_Canal_Dutch_01_plate_F",    [11267.6,  4394.3,  -0.360], [[ 0.0000, 1.0000, 0.0000], [0.0000, 0.0000, 1.0000]],  9.191],
    ["Land_LampHalogen_F",             [9809.627, 3917.188, 0.035], [[-0.7181, 0.6960, 0.0000], [0.0000, 0.0000, 1.0000]], 44.907],
    ["Land_Cargo_Patrol_V3_F",         [9705.006, 3934.017, 0.000], [[ 0.0255, 0.9997, 0.0000], [0.0000, 0.0000, 1.0000]], 43.795],
    ["Land_Sidewalk_01_8m_F",          [9774.223, 3881.579, 0.024], [[-0.7071, 0.7071, 0.0000], [0.0000, 0.0000, 1.0000]], 38.769],
    ["Land_Mil_WallBig_4m_battered_F", [9721.247, 3916.068, 0.648], [[ 1.0000,-0.0000, 0.0000], [0.0000, 0.0000, 1.0000]], 41.237],
    ["Land_CobblestoneSquare_01_8m_F", [9724.657, 3913.962, 0.008], [[ 0.0000, 1.0000, 0.0000], [0.0000, 0.0000, 1.0000]], 38.892],
    ["Land_HBarrier_5_F",              [9710.686, 3882.388, 0.020], [[ 0.0000, 1.0000, 0.0000], [0.0000, 0.0000, 1.0000]], 39.650]
];

diag_log format ["%1 ==== start  world=%2 isServer=%3 isDedicated=%4 hasInterface=%5 terrainGrid=%6 ====",
    _tag, worldName, isServer, isDedicated, hasInterface, getTerrainGrid];

{
    _x params ["_cls", "_pos", "_vec", "_sqmZ"];
    _pos params ["_px", "_py", "_pz"];
    private _terrain = getTerrainHeightASL [_px, _py];

    // the loader's client branch: a local simple object, aimed then placed
    private _s = createSimpleObject [_cls, [0, 0, 0], true];
    _s enableSimulation false;
    _s setVectorDirAndUp _vec;
    _s setPosATL _pos;

    // the same class as a real object -- what the export measured when it read the sqm's copies
    private _r = _cls createVehicleLocal [0, 0, 0];
    _r enableSimulation false;
    _r allowDamage false;
    _r setVectorDirAndUp _vec;
    _r setPosATL _pos;

    private _read = {
        params ["_o"];
        [(getPosWorld _o) select 2, (getPosASL _o) select 2, (getPosATL _o) select 2]
    };

    ([_s] call _read) params ["_wS", "_aS", "_tS"];
    ([_r] call _read) params ["_wR", "_aR", "_tR"];

    diag_log format ["%1 %2", _tag, _cls];
    diag_log format ["%1    terrain=%2  sqmZ=%3  entryATL=%4", _tag,
        _terrain toFixed 3, _sqmZ toFixed 3, _pz toFixed 3];
    diag_log format ["%1    SIMPLE world=%2 asl=%3 atl=%4  centreOffset=%5  ERR_vs_sqm=%6", _tag,
        _wS toFixed 3, _aS toFixed 3, _tS toFixed 3, (_aS - _wS) toFixed 3, (_wS - _sqmZ) toFixed 3];
    diag_log format ["%1    REAL   world=%2 asl=%3 atl=%4  centreOffset=%5  ERR_vs_sqm=%6", _tag,
        _wR toFixed 3, _aR toFixed 3, _tR toFixed 3, (_aR - _wR) toFixed 3, (_wR - _sqmZ) toFixed 3];

    uiSleep 1;   // settle read: proves the numbers above are placement, not physics
    ([_s] call _read) params ["_wS2"];
    ([_r] call _read) params ["_wR2"];
    if (abs (_wS2 - _wS) > 0.001 || {abs (_wR2 - _wR) > 0.001}) then {
        diag_log format ["%1    SETTLED simple %2 -> %3   real %4 -> %5", _tag,
            _wS toFixed 3, _wS2 toFixed 3, _wR toFixed 3, _wR2 toFixed 3];
    };

    deleteVehicle _s;
    deleteVehicle _r;
} forEach _rows;

diag_log format ["%1 ==== end ====", _tag];
