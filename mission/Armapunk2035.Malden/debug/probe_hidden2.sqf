/*
    [AP-PROBE2] Module-mechanics discriminator (3D-map hidden-building leak).
    1. Do any ModuleHideTerrainObjects_F logics still exist? (init self-deletes
       on the global path -- a survivor means its init never ran/finished.)
    2. Replicate the BIS runtime collection for the big palace module and report
       whether the leaked shop is in the found set / in the area.
*/
if (!isServer) exitWith {};
private _mods = allMissionObjects "ModuleHideTerrainObjects_F";
diag_log format ["[AP-PROBE2] surviving hide modules: %1", count _mods];
{
    diag_log format ["[AP-PROBE2] survivor at %1 objectarea=%2 filter=%3",
        getPosWorld _x, _x getVariable ["objectarea", "<unset>"], _x getVariable ["#filter", "<unset>"]];
} forEach _mods;

// the big palace module per the shipped sqm
private _pivot = [7219.39, 7868.01];
private _a = 43.119305; private _b = 52.750744;
private _deg = 0.09137059 * 180 / pi;
// VERBATIM from fn_mapBake's own sweep -- a probe that queries different
// categories than the code it diagnoses can only produce a false clean bill.
private _cats = ["BUILDING","HOUSE","CHURCH","CHAPEL","FUELSTATION","HOSPITAL",
                 "BUNKER","FORTRESS","TOURISM","LIGHTHOUSE"];
private _found = nearestTerrainObjects [_pivot, _cats, (_a max _b) * 1.42, false, true];
diag_log format ["[AP-PROBE2] palace module: %1 building-cat terrain objs in radius", count _found];
{
    private _in  = _x inArea [_pivot, _a, _b, _deg, true, -1];
    private _inE = _x inArea [_pivot, _a, _b, _deg, false, -1];
    diag_log format ["[AP-PROBE2] cand %1 pos=%2 hidden=%3 inRect=%4 inEllipse=%5",
        getModelInfo _x param [0, "?"], getPosWorld _x, isObjectHidden _x, _in, _inE];
} forEach _found;
diag_log "[AP-PROBE2] done";
