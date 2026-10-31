/*
    File: fn_mapEditorCatalog.sqf  (AP_fnc_mapEditorCatalog)
    The placement catalogue, built from the same config Eden's asset browser reads.

    Eden sorts its browser purely from config: editorCategory (a CfgEditorCategories
    class) and editorSubcategory (a CfgEditorSubcategories class), both declared on
    the CfgVehicles entry, with editorPreview for the thumbnail. Reading those means
    the in-game browser is Eden's browser -- same grouping, same display names, same
    coverage, automatically correct for mods -- instead of a hand-curated list that
    starts stale and drifts.

    Filtered through AP_fnc_mapPlaceable, which is the SAME predicate the server
    enforces. A catalogue that offered anything else would just be a list of things
    the server refuses.

    Cached: walking CfgVehicles is a few thousand config lookups and the answer cannot
    change without a restart.

    returns: [[categoryDisplay, [[subcatDisplay, [[display, class, preview], ...]], ...]], ...]
*/
if (!isNil "AP_mapCatalog") exitWith { AP_mapCatalog };

private _cats = createHashMap;

{
    private _c = configName _x;
    if ([_c] call AP_fnc_mapPlaceable) then {
        // scope 2 = public (browsable). scope 1 is spawnable but deliberately hidden,
        // scope 0 is not spawnable at all -- offering either produces an editor full
        // of duplicates and placeholders.
        if ((getNumber (_x >> "scope")) isEqualTo 2) then {
            private _catCls = getText (_x >> "editorCategory");
            private _subCls = getText (_x >> "editorSubcategory");
            if (_catCls isEqualTo "") then { _catCls = "EdCat_Misc"; };
            if (_subCls isEqualTo "") then { _subCls = "EdSubcat_Misc"; };

            private _catName = getText (configFile >> "CfgEditorCategories" >> _catCls >> "displayName");
            if (_catName isEqualTo "") then { _catName = _catCls; };
            private _subName = getText (configFile >> "CfgEditorSubcategories" >> _subCls >> "displayName");
            if (_subName isEqualTo "") then { _subName = _subCls; };

            private _disp = getText (_x >> "displayName");
            if (_disp isEqualTo "") then { _disp = _c; };

            private _subs = _cats getOrDefault [_catName, createHashMap, true];
            private _list = _subs getOrDefault [_subName, [], true];
            _list pushBack [_disp, _c, getText (_x >> "editorPreview")];
        };
    };
} forEach ("true" configClasses (configFile >> "CfgVehicles"));

// Flatten to sorted arrays. A hashmap has no order, and a browser whose categories
// shuffle between sessions is one nobody can build muscle memory in.
private _out = [];
{
    private _catName = _x;
    private _subsOut = [];
    {
        private _l = (_cats get _catName) get _x;
        _l sort true;
        _subsOut pushBack [_x, _l];
    } forEach (keys (_cats get _catName) apply { _x });
    _subsOut sort true;
    _out pushBack [_catName, _subsOut];
} forEach (keys _cats);
_out sort true;

AP_mapCatalog = _out;
diag_log format ["[AP-MAPEDIT] catalogue: %1 categories, %2 classes", count _out,
    count ("true" configClasses (configFile >> "CfgVehicles") select { [configName _x] call AP_fnc_mapPlaceable })];
AP_mapCatalog
