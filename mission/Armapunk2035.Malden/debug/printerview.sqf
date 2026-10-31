/*
    debug/printerview.sqf -- spawn the F770 fabricator body in front of the player to eyeball it.

    Paste into the debug console (LOCAL EXEC). Re-running deletes the previous copy first, so it is
    safe to spam while judging materials.

        [] execVM "debug\printerview.sqf";

    It is createSimpleObject like every other custom p3d here, so:
      * the path MUST come from getMissionPath -- a written-out world name is the bug that made
        every model silently fail to spawn after the Altis -> Malden fork (custom_p3ds/load.sqf);
      * the third argument MUST be true (local), or running this on a server spawns one copy per
        connected client;
      * the model is CENTRED on its own bbox, so setPosASL needs + halfHeight to sit it on the
        floor rather than half-buried. 0.9075, the F770 body's measured half-height
        (custom_p3ds/fab_parts_data.sqf) -- both printer tiers now draw this one model.

    No collision by design (owner 2026-08-22) -- you will walk straight through it. That is
    correct, not a missing Geometry LOD.
*/
private _root = getMissionPath "custom_p3ds\";
private _half = 0.9075;

{ deleteVehicle _x } forEach (missionNamespace getVariable ["AP_printerPreview", []]);

private _spawned = [];
{
    _x params ["_model", "_offset", "_label"];
    private _p = player getRelPos [_offset select 0, _offset select 1];
    private _z = getTerrainHeightASL _p;
    private _o = createSimpleObject [_root + _model + ".p3d", [_p select 0, _p select 1, _z + _half], true];
    _o setDir (getDir player + 180);
    _spawned pushBack _o;
    diag_log format ["[AP-PROBE] printerview: %1 at %2", _label, getPosASL _o];
} forEach [
    ["ap_printer_f770_body_r1", [2.0, 0], "F770 fabricator body"]
];

AP_printerPreview = _spawned;
hint "F770 fabricator body spawned ahead of you. No collision by design -- walk through it.";
