// LooneyBin :: FULL-MAP IMPORT -- every allLocalMapEntities entry -> editable 3DEN entities.
//
//   1) stage first:  python3 tools/mapdata_all.py extract
//   2) open the mission in the 3DEN editor
//   3) Tools -> Debug Console:  call compile preprocessFileLineNumbers "mapImportAll.sqf"
//
// Everything lands in layer 'MapDataAll' (named md_0..), FULL orientation preserved -- tilted
// kerbs/walls/props keep their tilt (vectorDir+vectorUp applied, then the 3DEN rotation/position
// attributes are written back FROM the engine's read of the placed entity, so what the editor
// saves matches what the game spawns). The server-side spawn flag (5th field) rides in each
// entity's DESCRIPTION attribute as AP_SERVERSIDE -- don't clear descriptions.
// ~7000 entities: expect the editor to chew for a bit; progress prints every 500.

if (!is3DEN) exitWith { systemChat "mapImportAll: open the mission in the 3DEN editor, run from its Debug Console."; };
// double-run guard: a half-imported layer + a second pass = duplicates. Delete the layer first.
private _existing = (all3DENEntities select 0) findIf { (_x get3DENAttribute "name") param [0, ""] isEqualTo "md_0" };
if (_existing isNotEqualTo -1) exitWith { systemChat "mapImportAll: a MapDataAll import already exists -- DELETE the 'MapDataAll' layer (and its entities) before re-importing."; };

call compile preprocessFileLineNumbers "mapImportAll_data.sqf";      // defines AP_dataAll
private _data = missionNamespace getVariable ["AP_dataAll", []];
if (_data isEqualTo []) exitWith { systemChat "mapImportAll: AP_dataAll empty -- run  python3 tools/mapdata_all.py extract  first."; };

private _lay = -1 add3DENLayer "MapDataAll";
private _made = [];
private _skipped = 0;
private _skippedUnits = 0;
private _importedUnits = 0;
// ANTI-DRIFT (owner 2026-07-11, "seafortress/prison mangled"): Eden re-grounds water-over + stacked objects
// AT PLACEMENT (setPosATL over sea measures from the SEABED; stacked walls physics-settle), so an export that
// re-reads live transforms re-derives DRIFTED coords for entities the user never touched -- compounding every
// round-trip (the fortress ended 40m off). Record each entity's actual POST-PLACEMENT transform; the export
// emits the ORIGINAL staged transform verbatim unless the entity moved RELATIVE TO THIS RECORD (= a real,
// deliberate user move). Stored per data-index in profileNamespace, like AP_mapImportedIdx.
private _placedXf = [];
_placedXf resize (count _data);
// per-side group headroom = 285 (3 spare) minus groups already in the scenario (playable slots etc.)
private _fnClassSide = {
    params ["_c"];
    switch ((getNumber (configFile >> "CfgVehicles" >> _c >> "side"))) do {
        case 0: { east }; case 1: { west }; case 2: { independent }; default { civilian };
    }
};
private _sideRoom = createHashMap;
{
    private _s = _x;
    private _used = { side _x isEqualTo _s } count (all3DENEntities select 1);
    _sideRoom set [_s, (285 - _used) max 0];
} forEach [west, east, independent, civilian];
diag_log format ["mapImportAll: side group headroom %1", _sideRoom];
private _unitIdx = [];
{
    _x params [["_cls", "", [""]], ["_pos", [0,0,0], [[]]], ["_du", [[0,1,0],[0,0,1]], [[]]], ["_init", "", [""]], ["_srv", false]];
    // NPCs: import as REAL units (outfit/loadout editable via Eden's Edit Loadout) WHEN the side has
    // group headroom -- Eden hard-caps 288 groups per side and every unit is its own group, and the
    // mission.sqm playable slots already occupy most of CIV. Sides without room keep their NPCs as
    // data (re-emitted verbatim by the export). Trim sqm civ slots to unlock civilian NPCs.
    if ((getText (configFile >> "CfgVehicles" >> _cls >> "simulation")) isEqualTo "soldier") then {
        private _side = [_cls] call _fnClassSide;
        private _room = _sideRoom getOrDefault [_side, 0];
        if (_room <= 0) then {
            _skippedUnits = _skippedUnits + 1;
            continue
        };
        _sideRoom set [_side, _room - 1];
        _importedUnits = _importedUnits + 1;
        _unitIdx pushBack _forEachIndex;   // recorded below in profileNamespace for the export
    };
    private _e = create3DENEntity ["Object", _cls, [0,0,0], false];
    if (isNull _e) then {
        diag_log format ["mapImportAll: skipped unknown class %1 @ %2", _cls, _pos];
        _skipped = _skipped + 1;
    } else {
        // engine math end-to-end: place by real transform, then write the editor attributes back
        // from what the engine says (the compImport technique -- no hand conversion, no tilt loss)
        _e setVectorDirAndUp [_du param [0, [0,1,0]], _du param [1, [0,0,1]]];
        _e setPosATL _pos;
        private _pb = _e call BIS_fnc_getPitchBank;
        private _atl = getPosATL _e;
        _e set3DENAttribute ["rotation", [_pb select 0, _pb select 1, getDir _e]];
        _e set3DENAttribute ["position", _atl];
        _e set3DENAttribute ["init", _init];
        _e set3DENAttribute ["name", format ["md_%1", _forEachIndex]];
        // anti-drift record: where Eden ACTUALLY put it (see header) -- the export's moved-or-not baseline
        _placedXf set [_forEachIndex, [getPosATL _e, vectorDir _e, vectorUp _e]];
        // stored outfit (6th field) -> put it on the editor unit so Edit Loadout starts from it
        private _lo = _x param [5, []];
        if (_lo isEqualType [] && {_lo isNotEqualTo []} && {_e isKindOf "CAManBase"}) then {
            _e setUnitLoadout _lo;
        };
        if (_srv) then { _e set3DENAttribute ["description", "AP_SERVERSIDE"]; };
        _made pushBack _e;
    };
    if ((_forEachIndex % 500) isEqualTo 499) then { systemChat format ["mapImportAll: %1 / %2 ...", _forEachIndex + 1, count _data]; };
} forEach _data;
_made set3DENLayer _lay;
// which NPC data-indexes became EDITOR UNITS: the export must NOT passthrough these rows -- if the
// unit still exists it exports live; if you DELETED it, the deletion must stick (re-emitting the data
// row resurrected deleted NPCs). profileNamespace so it survives editor restarts between import/export.
profileNamespace setVariable ["AP_mapImportedIdx", _unitIdx];
profileNamespace setVariable ["AP_mapPlacedXf", _placedXf];   // anti-drift baseline (survives editor restarts)

systemChat format ["mapImportAll: %1 entities in 'MapDataAll' (%2 NPCs as REAL units -- Edit Loadout works) | %3 NPCs kept as data (side at group cap) | %4 unknown-class skips (RPT).", count _made, _importedUnits, _skippedUnits, _skipped];
