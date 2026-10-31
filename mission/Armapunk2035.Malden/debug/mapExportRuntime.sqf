/*
    debug/mapExportRuntime.sqf  -- one-shot, DEV ONLY. Never wire this into a live boot path.

    Exports every STATIC object placed in mission.sqm into the allLocalMapEntities entry format, so
    the map can be moved out of the .sqm and spawned locally per-machine (zero network/JIP cost --
    see tools/MAP_EDITING.md). The canonical route for this is the 3DEN round-trip
    (mapImportAll -> edit -> mapExportAll), but that needs a human in the editor; this does the same
    capture headlessly.

    WHY IT RUNS FIRST: it must execute BEFORE initServer's `[] call AP_fnc_mapData` and before
    custom_p3ds/malden_buildings.sqf, because after those the world also contains array-spawned
    props and the designer's simple objects, which are NOT sqm entities and must not be re-exported.
    At this point in the boot, every static object present came from mission.sqm.

    WHY THE ENGINE AND NOT PYTHON: entry z is ATL (above terrain). The sqm stores world height, and
    its atlOffset attribute is NOT the above-terrain height (measured: Land_Cargo_HQ_V4_F carries
    atlOffset 0.002 while sitting 14.24m above terrain -- it is relative to whatever is underneath).
    Only the engine knows the real value, hence getPosATL here.
*/
if (!isServer) exitWith {};

private _skip = ["Logic", "Module", "SoundSource", "EmptyDetector", "Marker"];
private _q = toString [34];
private _n = 0;

diag_log format ["-MAPEXPORT- START world=%1", worldName];
{
    private _o = _x;
    private _cls = typeOf _o;
    if (_cls isEqualTo "") then { continue };
    if (_o isKindOf "CAManBase") then { continue };          // playable slots + any unit
    if (!(_o isKindOf "Static") && {!(_o isKindOf "Thing")} && {!(_o isKindOf "Building")}) then { continue };
    private _bad = false;
    { if ((_cls select [0, count _x]) isEqualTo _x) then { _bad = true } } forEach _skip;
    if (_bad) then { continue };

    private _p = getPosATL _o;
    private _d = vectorDir _o;
    private _u = vectorUp _o;
    diag_log format ["-MAPEXPORT- [%1%2%1,[%3,%4,%5],[[%6,%7,%8],[%9,%10,%11]]]",
        _q, _cls,
        (_p select 0) toFixed 3, (_p select 1) toFixed 3, (_p select 2) toFixed 3,
        (_d select 0) toFixed 4, (_d select 1) toFixed 4, (_d select 2) toFixed 4,
        (_u select 0) toFixed 4, (_u select 1) toFixed 4, (_u select 2) toFixed 4];
    _n = _n + 1;
} forEach (allMissionObjects "All");
diag_log format ["-MAPEXPORT- END count=%1", _n];
