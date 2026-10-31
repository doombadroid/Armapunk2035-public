// LooneyBin :: COMPOSITION IMPORT -- a compositions/zone_*.sqf on the clipboard -> editable 3DEN entities.
//
//   1) copy the WHOLE zone file's text onto the clipboard (the file body IS the array; the // header is
//      preprocessor-stripped by the console compile, so copying the entire file just works)
//   2) open the mission in the 3DEN editor
//   3) Tools -> Debug Console: paste this file's text (or, if you copied it into the editor mission
//      folder: call compile preprocessFileLineNumbers "compImport.sqf") and LOCAL EXEC
//   4) objects land in layer 'comp_<name>', full tilt/bank preserved. Edit, then run compExport.sqf.
//   5) DELETE the comp_<name> layer before saving the mission -- otherwise Eden bakes a second copy of
//      the composition into mission.sqm and it doubles up with the streamed one in-game.
//
// TRANSFORMS: the ENGINE does all the math. Each entity is placed by setVectorDirAndUp + setPosWorld
// (raw world frame -- sea-safe), then its Eden rotation/position ATTRIBUTES are written back FROM the
// engine's own read of the placed object (BIS_fnc_getPitchBank / getDir / getPosATL). Nothing is
// hand-converted, so tilted/banked pieces round-trip exactly (unlike the mapdata edenImport, which
// flattens rotation to yaw-only).

if (!is3DEN) exitWith { systemChat "compImport: open the mission in the 3DEN editor, run from its Debug Console."; };

private _clip = copyFromClipboard;
private _zone = call compile _clip;
if (isNil "_zone" || {!(_zone isEqualType [])} || {count _zone < 6}) exitWith {
    systemChat "compImport: clipboard is not a zone array -- copy a compositions/zone_*.sqf file's text first.";
};
_zone params [["_name", "zone", [""]], "_c", "_r", "_en", "_srv", ["_objs", [], [[]]]];
if (_objs isEqualTo []) exitWith { systemChat format ["compImport: zone '%1' has no objects.", _name]; };

private _lay = -1 add3DENLayer format ["comp_%1", _name];
private _made = [];
{
    _x params [["_cls", "", [""]], ["_pw", [0,0,0], [[]]], ["_vd", [0,1,0], [[]]], ["_vu", [0,0,1], [[]]]];
    private _e = create3DENEntity ["Object", _cls, [0,0,0], false];
    if (isNull _e) then {
        diag_log format ["compImport: skipped unknown class %1", _cls];
    } else {
        // place by raw world transform first (engine math)...
        _e setVectorDirAndUp [_vd, _vu];
        _e setPosWorld _pw;
        // ...then write the Eden attributes back FROM the engine so the editor's saved state matches
        // exactly what the loader will spawn. Rotation before position: the rotation attribute can pivot
        // the model, position is re-asserted last.
        private _pb = _e call BIS_fnc_getPitchBank;
        private _atl = getPosATL _e;
        _e set3DENAttribute ["rotation", [_pb select 0, _pb select 1, getDir _e]];
        _e set3DENAttribute ["position", _atl];
        _e set3DENAttribute ["name", format ["cz_%1_%2", _name, _forEachIndex]];
        _made pushBack _e;
    };
} forEach _objs;
_made set3DENLayer _lay;

systemChat format ["compImport: zone '%1' -> %2/%3 objects in layer 'comp_%1'. Edit, compExport, then DELETE the layer before saving.",
    _name, count _made, count _objs];
