// LooneyBin :: FULL-MAP EXPORT -- selected 3DEN objects -> the complete allLocalMapEntities array.
//
//   1) SELECT NOTHING. Imported objects are gathered by their md_ name, and anything you PLACED is
//      recognised by Eden id against the mission's own .sqm (stage it once with
//      `python3 tools/mapdata_all.py baseline`). Deleting an md_ entity still means "delete".
//      ADD-ONLY: if you never ran mapImportAll, only your new objects are exported and the apply
//      step appends them -- no 8k-entry round-trip just to add a bollard.
//   2) Tools -> Debug Console:  call compile preprocessFileLineNumbers "mapExportAll.sqf"
//   3) wl-paste > /tmp/mapdata_all_export.sqf
//   4) python3 tools/mapdata_all.py apply /tmp/mapdata_all_export.sqf
//
// Entry format out = entry format in: ["class",[x,y,z],[[dir],[up]],"init",isServer] -- FULL
// orientation (vectorDir + vectorUp: tilt round-trips exactly), init verbatim, the server-spawn
// flag read back from the DESCRIPTION attribute (AP_SERVERSIDE, set by mapImportAll).
// Exclusion list below: classes never exported even if selected.

if (!is3DEN) exitWith { systemChat "mapExportAll: open the mission in the 3DEN editor, run from its Debug Console."; };

// -- knobs -------------------------------------------------------------------------------------
private _exclude = ["Logic", "Module", "SoundSource", "EmptyDetector"];   // class PREFIX skip (NEVER add real map classes -- Sign_Arrow* are live DP/trial markers, lesson learned)
// ----------------------------------------------------------------------------------------------

// SELECTION-PROOF: every imported entity is named md_<i> -- gather them ALL by name (layers proved
// unreliable: Eden's All Descendants missed them). Deletions are done by actually deleting the md_
// entity in the editor.
private _sel = (all3DENEntities select 0) select { (((_x get3DENAttribute "name") param [0, ""]) select [0, 3]) isEqualTo "md_" };
private _importedN = count _sel;

// AUTO-NEW (owner 2026-07-26: "instead of having to select things that I added, grab anything new").
// Every entity the mission's own .sqm ships with carries an Eden id, and get3DENEntityID returns that
// same number in the editor (BIKI: survives save/load). tools/mapdata_all.py baseline stages that id
// set as AP_sqmIds. So an object that is neither an md_ import nor one of those ids can only be
// something you placed this session -- it gets picked up with no selection at all.
private _newN = 0;
private _baseTxt = preprocessFileLineNumbers "mapBaseline_ids.sqf";   // "" when the file is absent
if (_baseTxt isNotEqualTo "") then {
    call compile _baseTxt;                                            // AP_sqmIds
    private _base = createHashMap;
    { _base set [_x, true]; } forEach (missionNamespace getVariable ["AP_sqmIds", []]);
    {
        private _nm = (_x get3DENAttribute "name") param [0, ""];
        if (!((_nm select [0, 3]) isEqualTo "md_") && {!(_base getOrDefault [get3DENEntityID _x, false])}) then {
            _sel pushBackUnique _x;
            _newN = _newN + 1;
        };
    } forEach (all3DENEntities select 0);
} else {
    systemChat "mapExportAll: no mapBaseline_ids.sqf -- run 'python3 tools/mapdata_all.py baseline' and new objects get picked up on their own. Using your selection this time.";
};
{ _sel pushBackUnique _x; } forEach (get3DENSelected "object");       // belt and braces
if (_sel isEqualTo []) exitWith { systemChat "mapExportAll: nothing to export -- place something, or run mapImportAll first."; };

// ADD-ONLY session: nothing was imported, so everything here is new. Emit just those rows and mark
// the output so the apply step APPENDS them rather than treating the array as replaced-and-emptied.
private _appendMode = _importedN isEqualTo 0;

private _q  = toString [34];
private _nl = toString [10];
private _fmtN = { params ["_v", ["_d", 3]]; _v toFixed _d };

// ANTI-DRIFT (owner 2026-07-11, "seafortress/prison mangled"): Eden re-grounds water-over + stacked objects
// at import placement, so re-reading live transforms re-derives DRIFTED coords for entities the user never
// touched -- compounding every round-trip (the sea fortress ended 40m off). For each md_ entity, compare its
// live transform against the POST-PLACEMENT record mapImportAll stored (AP_mapPlacedXf): unmoved -> emit the
// ORIGINAL staged transform VERBATIM (init/serverside/loadout still read live); moved -> live re-derive (a
// deliberate user move). Legacy sessions without the record fall back to live reads everywhere -- re-import
// once with the current tools to arm the protection.
call compile preprocessFileLineNumbers "mapImportAll_data.sqf";      // AP_dataAll (also used by the NPC block)
private _stagedAll = missionNamespace getVariable ["AP_dataAll", []];
private _placedXf = profileNamespace getVariable ["AP_mapPlacedXf", []];
private _passN = 0;

private _out = "";
private _n = 0; private _srvN = 0; private _skipped = 0;
{
    private _cls = typeOf _x;
    if ((_exclude findIf { (_cls find _x) isEqualTo 0 }) isNotEqualTo -1 || {_cls isEqualTo ""}) then {
        _skipped = _skipped + 1;
    } else {
        private _p  = getPosATL _x;
        private _vd = vectorDir _x;
        private _vu = vectorUp _x;
        // unmoved md_ entity -> take the staged transform verbatim (numbers survive the round-trip exactly)
        private _nm = (_x get3DENAttribute "name") param [0, ""];
        if ((_nm select [0, 3]) isEqualTo "md_") then {
            private _di = parseNumber (_nm select [3]);
            private _rec = _placedXf param [_di, nil];
            private _st  = _stagedAll param [_di, []];
            if (!isNil "_rec" && {_rec isEqualType []} && {_st isNotEqualTo []}) then {
                _rec params ["_rp", "_rvd", "_rvu"];
                if ((_p distance _rp) < 0.05 && {(_vd vectorDistance _rvd) < 0.002} && {(_vu vectorDistance _rvu) < 0.002}) then {
                    _p  = _st param [1, _p];
                    private _du = _st param [2, [_vd, _vu]];
                    _vd = _du param [0, _vd];
                    _vu = _du param [1, _vu];
                    _passN = _passN + 1;
                };
            };
        };
        private _init = _x get3DENAttribute "init";
        if (_init isEqualType []) then { _init = _init param [0, ""] };
        if !(_init isEqualType "") then { _init = "" };
        private _desc = _x get3DENAttribute "description";
        if (_desc isEqualType []) then { _desc = _desc param [0, ""] };
        private _srv = (_desc isEqualType "") && {"AP_SERVERSIDE" in _desc};
        if (_srv) then { _srvN = _srvN + 1; };
        private _ie = "";                                     // double every quote for the SQF literal
        { _ie = _ie + (if (_x == 34) then { _q + _q } else { toString [_x] }); } forEach (toArray _init);
        // outfit capture: a unit whose loadout differs from its class default gets a 6th field
        // (getUnitLoadout array -- applied at spawn by fn_createVehicleLocal). str output is a valid
        // SQF literal. Unchanged units emit no field -> identical look + zero size cost.
        private _loTxt = "";
        if (_x isKindOf "CAManBase") then {
            private _lo = getUnitLoadout _x;
            if !(_lo isEqualTo (getUnitLoadout _cls)) then { _loTxt = "," + (str _lo); };
        };
        _out = _out + format ["[%1%2%1,[%3,%4,%5],[[%6,%7,%8],[%9,%10,%11]],%1%12%1,%13%14],%15",
            _q, _cls,
            [_p select 0] call _fmtN, [_p select 1] call _fmtN, [_p select 2] call _fmtN,
            [_vd select 0, 4] call _fmtN, [_vd select 1, 4] call _fmtN, [_vd select 2, 4] call _fmtN,
            [_vu select 0, 4] call _fmtN, [_vu select 1, 4] call _fmtN, [_vu select 2, 4] call _fmtN,
            _ie, str _srv, _loTxt, _nl];
        _n = _n + 1;
    };
} forEach _sel;
// NPCs were never imported (Eden group cap) -- re-emit every soldier-sim row from the staged data
// verbatim so the applied array keeps ALL of them. (AP_dataAll already loaded by the anti-drift block.)
private _unitN = 0;
if (!_appendMode) then {
// data indexes that were IMPORTED AS EDITOR UNITS (recorded by mapImportAll in profileNamespace).
// Those rows never passthrough: still-existing units export live; DELETED units stay deleted
// (re-emitting their data row was resurrecting them).
private _mdIdx = createHashMap;
{ _mdIdx set [_x, true]; } forEach (profileNamespace getVariable ["AP_mapImportedIdx", []]);
if (count _mdIdx isEqualTo 0) then {
    // session imported with an OLDER mapImportAll (no recorded list): fall back to present-entity scan.
    // Deletion of unit-NPCs is NOT honored in this mode -- re-import with the current tools for that.
    {
        private _nm = (_x get3DENAttribute "name") param [0, ""];
        if ((_nm select [0, 3]) isEqualTo "md_" && {_x isKindOf "CAManBase"}) then { _mdIdx set [parseNumber (_nm select [3]), true]; };
    } forEach _sel;
    systemChat "mapExportAll: legacy session (no import record) -- unit-NPC deletions will NOT stick this session.";
};
{
    _x params [["_uCls", "", [""]], ["_uPos", [0,0,0], [[]]], ["_uDu", [[0,1,0],[0,0,1]], [[]]], ["_uInit", "", [""]], ["_uSrv", false], ["_uLo", [], [[]]]];
    // ONLY the NPCs that were NOT imported as editor units (their md_ name is absent) -- imported ones
    // export from the editor with live loadouts; double-emitting them would duplicate NPCs.
    if ((getText (configFile >> "CfgVehicles" >> _uCls >> "simulation")) isEqualTo "soldier"
        && {!(_mdIdx getOrDefault [_forEachIndex, false])}) then {
        private _ie = "";
        { _ie = _ie + (if (_x == 34) then { _q + _q } else { toString [_x] }); } forEach (toArray _uInit);
        private _ud = _uDu param [0, [0,1,0]]; private _uu = _uDu param [1, [0,0,1]];
        private _loTxt = ["", "," + str _uLo] select (_uLo isNotEqualTo []);
        _out = _out + format ["[%1%2%1,[%3,%4,%5],[[%6,%7,%8],[%9,%10,%11]],%1%12%1,%13%14],%15",
            _q, _uCls,
            [_uPos select 0] call _fmtN, [_uPos select 1] call _fmtN, [_uPos select 2] call _fmtN,
            [_ud select 0, 4] call _fmtN, [_ud select 1, 4] call _fmtN, [_ud select 2, 4] call _fmtN,
            [_uu select 0, 4] call _fmtN, [_uu select 1, 4] call _fmtN, [_uu select 2, 4] call _fmtN,
            _ie, str _uSrv, _loTxt, _nl];
        _unitN = _unitN + 1;
    };
} forEach (missionNamespace getVariable ["AP_dataAll", []]);
};
_out = _out select [0, (count _out) - 2];                     // strip trailing ",\n"
if (_appendMode) then { _out = "// AP_MAPALL_MODE_APPEND" + _nl + _out; };

copyToClipboard _out;
diag_log "===AP_MAPALL_BEGIN===";
// RPT fallback in 50-entry chunks (diag_log truncates very long lines)
private _lines = _out splitString _nl;
private _chunk = "";
{
    _chunk = _chunk + _x + _nl;
    if ((_forEachIndex % 50) isEqualTo 49) then { diag_log _chunk; _chunk = ""; };
} forEach _lines;
if (_chunk isNotEqualTo "") then { diag_log _chunk; };
diag_log "===AP_MAPALL_END===";

systemChat format ["mapExportAll: %1 props + %2 NPCs (preserved) -> clipboard (%3 server-side, %4 excluded, %5 transform-passthrough). Save: wl-paste > /tmp/mapdata_all_export.sqf then tools/mapdata_all.py apply.", _n, _unitN, _srvN, _skipped, _passN];
if (_passN isEqualTo 0 && {_n > 100}) then { systemChat "mapExportAll: WARNING -- 0 passthroughs (legacy session?). Delete the MapDataAll layer and RE-IMPORT once to arm anti-drift, or water/stacked props will drift again."; };
