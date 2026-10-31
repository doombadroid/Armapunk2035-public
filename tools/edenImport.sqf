// LooneyBin :: array region -> editable 3DEN entities. THE ENGINE SETS HEIGHTS (setPosATL),
// so terrain + on-structure offsets come out identical to live. No offline height guessing.
//
// 1) stage the region first:   python3 tools/eden_region.py extract X Y R
//    (writes edenImport_data.sqf into the mission folder)
// 2) open the mission in the 3DEN editor
// 3) Tools -> Debug Console, type:
//        call compile preprocessFileLineNumbers "edenImport.sqf"
//
// Objects land in layer 'ArrayImport', named imp_0.. . Edit freely, then run edenExport.sqf.

if (!is3DEN) exitWith { systemChat "edenImport: open the mission in the 3DEN editor, run from its Debug Console."; };

call compile preprocessFileLineNumbers "edenImport_data.sqf";        // defines AP_data
private _data = if (isNil "AP_data") then {[]} else {AP_data};
if (_data isEqualTo []) exitWith { systemChat "edenImport: AP_data empty -- run  tools/eden_region.py extract X Y R  first."; };

private _lay = -1 add3DENLayer "ArrayImport";
private _made = [];
{
    _x params [["_cls","",[""]], ["_pos",[0,0,0],[[]]], ["_du",[[0,1,0],[0,0,1]],[[]]], ["_init","",[""]]];
    private _e = create3DENEntity ["Object", _cls, [0,0,0], false];
    if (isNull _e) then {
        diag_log format ["edenImport: skipped unknown class %1", _cls];
    } else {
        _e set3DENAttribute ["position", _pos];                    // "position" attribute is ATL (height above terrain); array z is already ATL -> pass through
        _e set3DENAttribute ["rotation", [0, 0, (_du select 0 select 0) atan2 (_du select 0 select 1)]];
        _e set3DENAttribute ["init", _init];
        _e set3DENAttribute ["name", format ["imp_%1", _forEachIndex]];
        _made pushBack _e;
    };
} forEach _data;
_made set3DENLayer _lay;

systemChat format ["edenImport: %1 objects spawned in layer 'ArrayImport' (heights by engine). Verify a few, edit, then run edenExport.sqf.", count _made];
