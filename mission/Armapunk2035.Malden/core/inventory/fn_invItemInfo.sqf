/*
    fn_invItemInfo.sqf -- per-class metadata for the I-screen (INVENTORY_SPEC.md §9.3).

        [_cls] call AP_fnc_invItemInfo
        -> hashmap { name, icon, mass, kind, socket, wide, cap }

    kind   : weapon | mag | attach | item | uniform | vest | backpack | headgear |
             facewear | binocular | nvg | assigned
    socket : muzzle | optic | pointer | bipod for kind "attach", else ""
    mass   : the engine's load units (CfgWeapons ItemInfo>>mass for items, attachments and
             clothing; CfgMagazines>>mass; WeaponSlotsInfo>>mass for weapons; CfgVehicles>>mass
             for backpacks). The page divides nothing -- these ARE what loadAbs/maxLoad count.
    cap    : magazine capacity (CfgMagazines>>count), 0 otherwise.
    icon   : the config picture with its leading backslash stripped, the storage.html convention
             so AP.texture resolves it the same way for every page.

    Config never changes during a session, so the answer is cached in uiNamespace
    AP_invInfoCache. Callers must not mutate the returned map.
*/
params [["_cls", "", [""]]];
private _cache = uiNamespace getVariable "AP_invInfoCache";
if (isNil "_cache") then { _cache = createHashMap; uiNamespace setVariable ["AP_invInfoCache", _cache]; };
private _hit = _cache get _cls;
if (!isNil "_hit") exitWith { _hit };

private _name = _cls; private _icon = ""; private _mass = 0; private _kind = "item";
private _socket = ""; private _wide = false; private _cap = 0;
private _cw = configFile >> "CfgWeapons" >> _cls;
private _cm = configFile >> "CfgMagazines" >> _cls;
private _cv = configFile >> "CfgVehicles" >> _cls;
private _cg = configFile >> "CfgGlasses" >> _cls;
switch (true) do {
    case (isClass _cm): {
        _name = getText (_cm >> "displayName"); _icon = getText (_cm >> "picture");
        _mass = getNumber (_cm >> "mass"); _kind = "mag"; _cap = getNumber (_cm >> "count");
    };
    case (isClass _cw): {
        _name = getText (_cw >> "displayName"); _icon = getText (_cw >> "picture");
        private _wtype = getNumber (_cw >> "type");
        private _itype = getNumber (_cw >> "ItemInfo" >> "type");
        private _sim = getText (_cw >> "simulation");
        switch (true) do {
            case (_wtype in [1, 2, 4]): {
                _kind = "weapon"; _wide = true; _mass = getNumber (_cw >> "WeaponSlotsInfo" >> "mass");
            };
            case (_sim isEqualTo "Binocular"): {
                _kind = "binocular"; _mass = getNumber (_cw >> "WeaponSlotsInfo" >> "mass");
            };
            default {
                _mass = getNumber (_cw >> "ItemInfo" >> "mass");
                switch (_itype) do {
                    case 101: { _kind = "attach"; _socket = "muzzle" };
                    case 201: { _kind = "attach"; _socket = "optic" };
                    case 301: { _kind = "attach"; _socket = "pointer" };
                    case 302: { _kind = "attach"; _socket = "bipod" };
                    case 605: { _kind = "headgear" };
                    case 616: { _kind = "nvg" };
                    case 701: { _kind = "vest" };
                    case 801: { _kind = "uniform" };
                    default {
                        if (_sim in ["ItemMap", "ItemGPS", "ItemRadio", "ItemCompass", "ItemWatch"]) then { _kind = "assigned" };
                    };
                };
            };
        };
    };
    case (isClass _cv): {
        _name = getText (_cv >> "displayName"); _icon = getText (_cv >> "picture");
        _mass = getNumber (_cv >> "mass"); _kind = "backpack";
    };
    case (isClass _cg): {
        _name = getText (_cg >> "displayName"); _icon = getText (_cg >> "picture");
        _mass = getNumber (_cg >> "mass"); _kind = "facewear";
    };
};
if (_name isEqualTo "") then { _name = _cls };
if ((_icon select [0, 1]) isEqualTo "\") then { _icon = _icon select [1]; };

private _out = createHashMapFromArray [
    ["name", _name], ["icon", _icon], ["mass", _mass], ["kind", _kind],
    ["socket", _socket], ["wide", _wide], ["cap", _cap]
];
_cache set [_cls, _out];
_out
