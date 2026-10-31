/*
    terrainDeform.sqf -- applies the Deformer heightfield WITHOUT the mod.

    The Deformer editor mod (Greenfist) stores every terrain edit in a scenario attribute
    (GF_deformMission >> GF_deformString) as "x" + str of per-column runs:
        [[xCell, [yStartCell, h, h, ...], [yStartCell, h, ...]], ...]
    world pos = cell index * heightmap cell size (getTerrainInfo#2). The mod's own MP path and
    its bundled sqfexport stub do exactly this decode; replicated here so the DEV/LIVE servers
    stay vanilla. setTerrainHeight is serverExec + GLOBAL effect (engine-synced, JIP-persistent,
    Arma 2.10+), so this runs on the SERVER only and every client inherits the terrain.

    Wired from init.sqf. Editing terrain: MaldenEdit in 3DEN with Deformer loaded, save, apply --
    the pipeline (tools/map_codegen.py sync_scenario_attrs) ships the attribute automatically.
*/
if (!isServer) exitWith {};

private _s = getMissionConfigValue ["GF_deformString", ""];
// Normal saves are "x"+str(runs). A FULL revert makes Deformer write bare "[]" (its clear path
// skips the "x" prefix -- fn_deformFunc line 139), so anything not starting "x[" means "no
// deformation": absent, cleared, or a format we don't know. Silence, not an error.
if ((_s select [0, 2]) isNotEqualTo "x[") exitWith {};

private _hm = parseSimpleArray (_s select [1]);      // strip the leading "x"
if (isNil "_hm" || {!(_hm isEqualType [])} || {_hm isEqualTo []}) exitWith {
    diag_log "[MAD] terrainDeform: GF_deformString present but did not parse -- terrain NOT applied";
};

private _cell = getTerrainInfo select 2;
private _def = [];
{
    private _xw = (_x select 0) * _cell;
    for "_i" from 1 to (count _x - 1) do {
        private _seg = _x select _i;
        private _y0 = _seg select 0;
        for "_j" from 1 to (count _seg - 1) do {
            _def pushBack [_xw, (_y0 + _j - 1) * _cell, _seg select _j];
        };
    };
} forEach _hm;

setTerrainHeight [_def, true];
diag_log format ["[MAD] terrainDeform: applied %1 heightfield points across %2 columns", count _def, count _hm];
