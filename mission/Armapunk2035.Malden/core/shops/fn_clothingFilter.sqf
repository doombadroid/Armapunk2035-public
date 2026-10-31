params["_basic", ["_type", ""], ["_oldLoadout", ""], ["_searchRefresh", false]];
_basic params["_filter", "_selection"];
if (_type isEqualTo "") exitWith {};
disableSerialization;
// owner 2026-07-10: remember the last real (category) filter call so the search box's KeyUp can re-run us
// with the SAME category + loadout and just re-apply the name filter (_searchRefresh=true on those re-runs).
uiNamespace setVariable ["AP_clothingFilterArgs", [_basic, _type, _oldLoadout]];
private _selection = _filter lbValue _selection;
// on a SEARCH refresh, skip the preview-camera repositioning -- same category/angle, so re-committing it
// every keystroke is pointless jitter. Only the list gets rebuilt through the name filter below.
if (!_searchRefresh) then {if (_selection isEqualTo 4) then {private _distance = -4;
    while {_distance < -1}
    do {
        if (!lineIntersects[ATLToASL(player modelToWorld[1, _distance, 2]), ATLToASL(player modelToWorld[0, -.15, 1.3]), player]) exitWith {};
        _distance = _distance + 0.5;}; AP_shop_cam camSetTarget(player modelToWorld[0, -.15, 1.3]);
    AP_shop_cam camSetPos(player modelToWorld[1, _distance, 2]);
    AP_shop_cam camCommit 1;} else {private _distance = 4;
    while {_distance > 1}
    do {if (!lineIntersects[ATLToASL(player modelToWorld[1, _distance, 2]), ATLToASL(player modelToWorld[0, 0, 1]), player]) exitWith {};
        _distance = _distance - 0.5;}; AP_shop_cam camSetTarget(player modelToWorld[0, 0, 1]);
    AP_shop_cam camSetPos(player modelToWorld[1, _distance, 2]);
    AP_shop_cam camCommit 1;};};
private _display = findDisplay 3100;
if (isNull _display) exitWith {};
disableSerialization;
private _list = _display displayCtrl 3101;
// owner 2026-07-10: search-bar filter. The typed text only feeds toLower/find (substring match) below --
// never compiled or executed -- so the live edit box has no script-injection surface. Dim placeholder
// (3111) shows only while the box is empty.
private _q = toLower ctrlText (_display displayCtrl 3110);
(_display displayCtrl 3111) ctrlShow (_q isEqualTo "");
private _cancel = _display displayCtrl 1000;
private _priceText = _display displayCtrl 3107;
lbClear _list;
private _items =
switch (_type) do {case "civ": {[_selection] call AP_fnc_clothing_civ}; case "cop": {[_selection] call AP_fnc_clothing_cop};
        case "skip": {[_selection] call AP_fnc_clothing_reb};
        case "rebcloth": {[_selection] call AP_fnc_clothing_reb};
        case "dive": {[_selection] call AP_fnc_clothing_dive};
        case "copdive": {[_selection] call AP_fnc_clothing_copdive};
        case "kart": {[_selection] call AP_fnc_clothing_kart};
        case "barber": {[_selection] call AP_fnc_clothing_barber};
        case "faces": {[_selection] call AP_fnc_clothing_faces};
        case "med": {[_selection] call AP_fnc_clothing_med};
        default {[]};}; if !(_items isEqualType[]) exitWith {};
if (_items isEqualTo[]) exitWith {};
// ---------------------------------------------------------------------------------------------
// ECONOMY 2026-09-05: armour is priced by BAND, from the item's own HitpointsProtectionInfo.
//
// Every vest in the game resolves to one of six chest values and every helmet to one of four head
// values -- that is the whole design space, which is why this is a band table and not a curve: a
// continuous formula would invent precision the source data does not have. What it replaces:
//
//   * the same protection sold at two prices. Nine vests share the 16-armour / 0.30-passthrough
//     profile and the digital IA2 carrier was priced at the heavy-plate tier while carrying the
//     light-plate one, so the shop taught a ranking that was false.
//   * the Carrier GL, which is the best chest protection in Arma 3 by a wide margin (78 against the
//     next-best 24), priced identically to the Carrier Special.
//   * MaxSec's best helmet costing a THIRD LESS than its worst: 10 armour at $1,000, 4 armour at
//     $1,500.
//
// One table serves both slots. They overlap at 8 -- the CSAT helmets sit there alongside the soft
// vests -- and $1,500 is the right number for either, so the shared band is a feature rather than a
// coincidence to design around.
// Armour 0 -- rigs, bandoliers, caps, uniforms, backpacks, goggles -- is left alone: those are
// carry capacity and cosmetics, and they are already priced as such. An item already at 0 is free
// faction issue and stays free.
private _armourBands = [[70, 20000], [24, 12000], [20, 7500], [16, 4500], [10, 2500], [8, 1500], [6, 1400], [4, 600]];
private _armourMult = switch (_type) do {
    case "cop"; case "copdive": { 0.55 };   // department issue, same multiplier the armory uses
    case "med":                 { 0.75 };
    default                     { 1 };      // civ / rebel / skiptracer is the baseline
};
{
    if (_x isEqualType [] && {count _x >= 3} && {(_x select 2) > 0}) then {
        private _best = 0;
        private _hp = configFile >> "CfgWeapons" >> (_x select 0) >> "ItemInfo" >> "HitpointsProtectionInfo";
        if (isClass _hp) then {
            for "_ci" from 0 to ((count _hp) - 1) do {
                private _sub = _hp select _ci;
                if (isClass _sub) then { _best = _best max (getNumber (_sub >> "armor")); };
            };
        };
        if (_best > 0) then {
            private _bi = _armourBands findIf { _best >= (_x select 0) };
            if (_bi > -1) then { _x set [2, (round (((_armourBands select _bi) select 1) * _armourMult / 100)) * 100]; };
        };
    };
} forEach _items;
// LooneyBin Economy: owner clothing-price overrides (cloth p0 = price, entry index 2)
{if (_x isEqualType [] && {count _x >= 3}) then {private _ov = ["cloth", _x select 0] call AP_fnc_priceOv;
        if (_ov isNotEqualTo [] && {(_ov select 2) >= 0}) then { _x set [2, _ov select 2]; };};} forEach _items;
private _oldLoadout = parseSimpleArray format["%1", _oldLoadout];
if !(_oldLoadout isEqualType[]) exitWith {};
private _oldItem = _oldLoadout select _selection;
private _priceTextFormat =
if !(AP_ndShop) then {"$0"} else {"0 ND"};
_priceText ctrlSetText _priceTextFormat;
private _index = _list lbAdd "Remove purchase";
_list lbSetData[_index, str["remove", ""]];
_list lbSetValue[_index, 0];
if !(_oldItem isEqualTo "") then {_list lbSetPicture[_index, ([_oldItem] call AP_fnc_fetchCfgDetails) select 2]};
{
    // FACES resolve differently (owner 2026-08-03, BUGS.md #65). AP_fnc_fetchCfgDetails only knows
    // CfgMagazines/CfgWeapons/CfgVehicles/CfgGlasses, so it returned [] for every face and `params` below
    // was false -- every row silently dropped, which is why filling the catalogue alone showed nothing.
    // Faces also live NESTED at CfgFaces >> Man_A3 >> class, a path the single-string root in _details
    // select 6 structurally cannot express, so the isClass guard below is skipped for them and the class
    // is validated here instead. A face the client cannot resolve (mod not loaded) drops out quietly.
    private _details = if (_type isEqualTo "faces") then {
        private _fCfg = configFile >> "CfgFaces" >> "Man_A3" >> (_x select 0);
        if (isClass _fCfg) then {
            [(_x select 0), getText (_fCfg >> "displayName"), "", 2, -1, -1, "", [], [], "", [], [], [], configNull, []]
        } else { [] };
    } else { [_x select 0] call AP_fnc_fetchCfgDetails };
    if (_details params["_class", "_displayName", "_picture"]) then {
        if (_type isNotEqualTo "faces" && {!(isClass(configFile >> (_details select 6) >> _class))}) exitWith {};
        private _price = _x select 2;
        _price =
        if (AP_ndShop || (_type isEqualTo "rebcloth")) then {_price} else {_price + (_price * (call AP_fnc_getGovTax))};
        _price = round(_price);
        _price =
        _price;
        private _displayName =
        if (isNil {_x select 1}) then {_displayName} else {_x select 1};
        private _customTexture =
        if (isNil {_x select 3}) then {""} else {_x select 3};
        private _picture =
        if (_type isEqualTo "faces") then {""} else {_picture};
        // LooneyBin (owner, 2026-06-11): show the armor value next to each vest/clothing item. Take the
        // highest `armor` across the item's protected hitpoints (vest=chest/body, helmet=head). A `for`
        // loop (not forEach) so the outer clothing-loop `_x` isn't clobbered before lbSetData below.
        private _armor = 0;
        private _hpInfo = configFile >> "CfgWeapons" >> (_x select 0) >> "ItemInfo" >> "HitpointsProtectionInfo";
        if (isClass _hpInfo) then {for "_ci" from 0 to ((count _hpInfo) - 1) do {private _sub = _hpInfo select _ci;
                if (isClass _sub) then { private _a = getNumber (_sub >> "armor"); if (_a > _armor) then { _armor = _a; }; };};};
        if (_armor > 0) then { _displayName = format ["%1  [Armor %2]", _displayName, _armor]; };
        if (_q isEqualTo "" || {(toLower _displayName) find _q >= 0}) then {private _index = _list lbAdd format["%1", _displayName];
            _list lbSetPicture[_index, _picture];
            _list lbSetData[_index, str([_x select 0, _customTexture])];
            _list lbSetValue[_index, _price];};};}
forEach _items;
// owner 2026-07-10: don't steal focus back to the list on a search refresh -- it would yank the caret out
// of the search box after every keystroke. Only grab focus on the initial/category populate.
if (!_searchRefresh) then {ctrlSetFocus _list;
    _list lbSetCurSel - 1;};