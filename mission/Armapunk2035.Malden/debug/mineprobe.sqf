/*
    mineprobe.sqf -- dump every object around you into the CLIENT RPT, one line per object, in the same
    shape build/mapexport_malden.log uses. Paste into the debug console, LOCAL EXEC, standing at the bad
    spot.

    ONE LINE PER OBJECT on purpose. diag_log wraps the logged string in quotes and DOUBLES every inner
    quote, and an embedded newline continues on an unprefixed line -- so a single multi-line dump is
    painful to decode, while one line each greps cleanly.

    ATL on purpose too: allLocalMapEntities is applied with setPosATL (fn_createVehicleLocal), and the
    engine sweep recorded ATL, so getPosATL is the frame that compares directly against both. Do not
    swap it for getPosWorld -- that is the model-centre frame and differs by a per-class constant
    (HBarrier_Big -1.210, Mil_WallBig_4m -1.700, LampHalogen -5.982).

    Terrain objects (typeOf "") are logged too, tagged TERRAIN and named by model, because they are part
    of what you see but are NOT in the array -- so they should be ignored when diffing.

    The RPT is the Proton one, newest by mtime:
      ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/*.rpt
*/

private _r = 30;   // metres. 30 is a stairwell; use 120 for a whole composition.

private _objs = nearestObjects [player, [], _r];
diag_log format ["-MINEPROBE- START pos=%1 r=%2 n=%3 world=%4",
    (getPosATL player) apply { (_x toFixed 2) }, _r, count _objs, worldName];
{
    private _t = typeOf _x;
    private _p = getPosATL _x;
    private _isTerrain = _t isEqualTo "";
    diag_log format ["-MINEPROBE- [""%1"",[%2,%3,%4],[%5,%6]] d=%7%8",
        if (_isTerrain) then { ((getModelInfo _x) select 0) } else { _t },
        (_p select 0) toFixed 3, (_p select 1) toFixed 3, (_p select 2) toFixed 3,
        vectorDir _x, vectorUp _x,
        ((player distance _x) toFixed 1),
        if (_isTerrain) then { " TERRAIN" } else { "" }];
} forEach _objs;
diag_log format ["-MINEPROBE- END n=%1", count _objs];

hint format ["-MINEPROBE- %1 objects within %2 m written to the RPT", count _objs, _r];
