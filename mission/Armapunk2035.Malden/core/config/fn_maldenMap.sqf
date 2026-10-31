/*
    AP_fnc_maldenMap  (LooneyBin, owner 2026-07-11)
    MALDEN MAKEOVER lookup -- which Altis house classes have Malden (Structures_F_Argo) model variants and
    what each side maps to. Recon 2026-07-11 (dev config sweep): the Malden "_b_" houses are SEPARATE BAKED
    MODELS (no hiddenSelectionsTextures anywhere in the house tree) so the makeover is a hide-and-replace
    swap (APS_fnc_maldenSRV), not a retexture. Variants exist ONLY for House_Big_01 / House_Big_02 /
    House_Small_01 / House_Small_02 (every V color tier) -- 6 colors each; Small_03, Stone_*, Garage,
    Shed_Ind, Shop and Slum have none, so those houses never show the menu option.

    call:  ["variant", _cls, _color] -> the Malden class for an Altis base in that color ("" = not eligible)
           ["base",    _cls]         -> the family's V1 base for a Malden variant ("" = not a variant)
           ["stem",    _cls]         -> the family stem for base OR variant ("" = not eligible)
           ["colorOf", _cls]         -> the color key of a variant ("" = not a variant)
           ["eligible",_cls]         -> true when the class maps either way (menu visibility)
           ["colors"]                -> [[key, label], ...] for the picker
*/
params [["_mode", "eligible", [""]], ["_cls", "", [""]], ["_color", "whiteblue", [""]]];

if (isNil "AP_maldenStems") then {
    // base class -> family stem (all V tiers share the family's variants)
    AP_maldenStems = createHashMap;
    AP_maldenColors = [["whiteblue", "Seaside White & Blue"], ["white",     "Whitewash"], ["blue",      "Blue"], ["yellow",    "Yellow"],
        ["pink",      "Pink"], ["brown",     "Brown"]];
    private _families = ["Land_i_House_Big_01", "Land_i_House_Big_02", "Land_i_House_Small_01", "Land_i_House_Small_02"]; {
        private _stem = _x;
        { AP_maldenStems set [format ["%1_%2_F", _stem, _x], _stem]; } forEach ["V1", "V2", "V3"];} forEach _families;
    // variant class -> [family stem, color key]; family stem -> V1 base
    AP_maldenBack = createHashMap;
    AP_maldenBaseOf = createHashMap; {private _stem = _x;
        AP_maldenBaseOf set [_stem, format ["%1_V1_F", _stem]];
        { AP_maldenBack set [format ["%1_b_%2_F", _stem, _x select 0], [_stem, _x select 0]]; } forEach AP_maldenColors;
    } forEach _families;};

switch (_mode) do {case "variant": {private _stem = AP_maldenStems getOrDefault [_cls, ""];
        if (_stem isEqualTo "") exitWith { "" };
        if ((AP_maldenColors findIf { (_x select 0) isEqualTo _color }) isEqualTo -1) exitWith { "" };
        format ["%1_b_%2_F", _stem, _color]};
    case "base": {private _e = AP_maldenBack getOrDefault [_cls, []];
        if (_e isEqualTo []) exitWith { "" };
        AP_maldenBaseOf getOrDefault [_e select 0, ""]};
    case "stem": {private _s = AP_maldenStems getOrDefault [_cls, ""];
        if (_s isNotEqualTo "") exitWith { _s };
        (AP_maldenBack getOrDefault [_cls, [""]]) select 0};
    case "colorOf": { (AP_maldenBack getOrDefault [_cls, ["", ""]]) param [1, ""] };
    case "eligible": { (_cls in AP_maldenStems) || {_cls in AP_maldenBack} };
    case "colors": { AP_maldenColors };
    default { false };};
