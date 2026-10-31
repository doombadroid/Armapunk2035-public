/*
    AP_fnc_fabMenuFill -- (re)draw the recipe list. Also the search box's onKeyUp handler.

    ROW COLOUR ENCODES THE XP RULE, not affordability:
        green  -- printing this still earns progress (its level is yours, or one below)
        red    -- above your level, or above what this machine's tier can print
        dim    -- printable, but you have outgrown it and it earns nothing

    That is the one presentational decision worth copying wholesale from the system this came from.
    Affordability lives in the ingredient panel, where the numbers are; putting it in the list too
    would mean two colour languages competing in one window.
*/
disableSerialization;
private _d = findDisplay 1810;
if (isNull _d) exitWith {};
private _list = _d displayCtrl 1850;
lbClear _list;

private _lvl = missionNamespace getVariable ["AP_fabLevel", 1];
private _known = missionNamespace getVariable ["AP_fabSchem", []];
private _tier = (missionNamespace getVariable ["AP_fabAnchor", objNull]) getVariable ["AP_fabTier", 1];
private _tcfg = ["tier", _tier] call AP_fnc_fabCfg;
private _cap = _tcfg param [2, 10];
// A machine lists only what IT can make. Weapons are bench recipes and everything else is a
// printer recipe, so without this a gunsmith bench would advertise 503 items it will refuse.
private _kind = _tcfg param [6, "printer"];
private _free = missionNamespace getVariable ["AP_fabFreeBuild", false];
private _filter = toLower (ctrlText (_d displayCtrl 1813));

// SHOP MODE: the vendor list is everything sold that you do not already know. Kept in the same
// control as the printable list because it answers the question the printable list just raised.
if ((missionNamespace getVariable ["AP_fabMode", "print"]) isEqualTo "shop") exitWith {
    private _shop = [];
    {
        private _row = ["get", _x] call AP_fnc_fabSchemCfg;
        private _rflags = (["getRecipe", _x] call AP_fnc_fabCfg) param [2, []];
        private _rk = if ("bench" in _rflags) then {"bench"} else {"printer"};
        if (_rk isEqualTo _kind && {"shop" in (_row select 1)} && {!(_x in _known)}) then {
            _shop pushBack [((["getRecipe", _x] call AP_fnc_fabCfg) param [0, 1]), _x, _row select 2];
        };
    } forEach (["getAll"] call AP_fnc_fabSchemCfg);
    _shop sort true;
    {
        _x params ["_rl", "_key", "_rarity"];
        private _price = ([_key] call AP_fnc_fabFee) param [1, "?"];
        private _i = _list lbAdd format ["%1  (L%2)  %3 ND", _key, _rl, _price];
        _list lbSetData [_i, _key];
        _list lbSetColor [_i, switch (_rarity) do {
            case "epic": {[0.69, 0.51, 0.91, 1]};
            case "rare": {[0.34, 0.84, 0.89, 1]};
            default     {[0.86, 0.92, 0.96, 1]};
        }];
    } forEach _shop;
    (_d displayCtrl 1812) ctrlSetStructuredText parseText format [
        "<t size='0.9'>Schematic vendor   ·   you hold <t color='#56d6e2'>%1 ND</t>   ·   price is derived from what the item actually contains</t>",
        AP_nd toFixed 4];
    if (_shop isEqualTo []) then {
        (_d displayCtrl 1865) ctrlSetStructuredText parseText "<t color='#7ad19a'>You know every schematic on sale.</t>";
    } else { _list lbSetCurSel 0; };
};

// BUILD THE ROW LIST ONCE PER MENU OPEN, not per keystroke. This is the search box's onKeyUp
// handler, and the uncached version walked all 574 recipes on every character typed -- each walk
// doing a DEEP COPY out of AP_fnc_fabCfg (the copy is load-bearing, so it cannot be skipped) plus
// up to three BIS_fnc_displayName lookups per row. That is a visible hitch on a text field.
// fn_fabMenu clears the cache on open and fn_fabMode clears it on a mode flip, which are the only
// two events that change what belongs in it.
private _cache = missionNamespace getVariable ["AP_fabRowCache", []];
// The cache is per machine KIND as well as per mode -- fn_fabMenu clears it on every open, which
// is also every time the player could have walked from a printer to a bench.
if (_cache isEqualTo []) then {
    {
        private _row = ["getRecipe", _x] call AP_fnc_fabCfg;
        _row params ["_rl", "_parts", "_flags"];
        // A recipe you cannot unlock is not shown at all. Showing every locked recipe is how the
        // ported system ended up advertising 39 items no player could ever reach.
        private _rk = if ("bench" in _flags) then {"bench"} else {"printer"};
        // Free build shows the machine's WHOLE catalogue -- the point of the override is to reach
        // recipes you have not unlocked, so hiding them would defeat it.
        if (_rk isEqualTo _kind && {_free || {("noSchematic" in _flags) || {_x in _known}}}) then {
            private _isVirt = (["getItemRow", _x] call AP_fnc_virtItemCfg) isNotEqualTo [];
            private _name = if (_isVirt) then { ["getName", _x] call AP_fnc_virtItemCfg } else {
                private _cfgName = [configFile >> "CfgWeapons" >> _x] call BIS_fnc_displayName;
                if (_cfgName isEqualTo "") then { _cfgName = [configFile >> "CfgVehicles" >> _x] call BIS_fnc_displayName; };
                if (_cfgName isEqualTo "") then { _cfgName = [configFile >> "CfgMagazines" >> _x] call BIS_fnc_displayName; };
                if (_cfgName isEqualTo "") then { _x } else { _cfgName };
            };
            private _icon = if (_isVirt) then { ["getIcon", _x] call AP_fnc_virtItemCfg } else {
                private _pi = getText (configFile >> "CfgWeapons" >> _x >> "picture");
                if (_pi isEqualTo "") then { _pi = getText (configFile >> "CfgVehicles" >> _x >> "picture"); };
                if (_pi isEqualTo "") then { _pi = getText (configFile >> "CfgMagazines" >> _x >> "picture"); };
                _pi
            };
            _cache pushBack [_rl, _name, _x, _icon];
        };
    } forEach (["getAll"] call AP_fnc_fabCfg);
    _cache sort true;              // by level, then name -- the ladder reads top to bottom
    AP_fabRowCache = _cache;
};

private _rows = _cache select { _filter isEqualTo "" || {(toLower (_x select 1)) find _filter >= 0} };

{
    // Name and icon come out of the cache; only the COLOUR is recomputed, because it encodes the
    // player's level and that can change between two draws of the same list.
    _x params ["_rl", "_name", "_key", "_icon"];
    private _i = _list lbAdd format ["%1  (L%2)", _name, _rl];
    _list lbSetData [_i, _key];
    private _colour = switch (true) do {
        case (_rl > _lvl || {_rl > _cap}): { [0.86, 0.32, 0.32, 1] };
        case (_rl >= (_lvl - 1)):          { [0.33, 0.85, 0.55, 1] };
        default                            { [0.72, 0.75, 0.78, 0.55] };
    };
    _list lbSetColor [_i, _colour];
    if (_icon isNotEqualTo "") then { _list lbSetPicture [_i, _icon]; };
} forEach _rows;

(_d displayCtrl 1812) ctrlSetStructuredText parseText format [
    "<t size='0.9'>Fabrication <t color='#56d6e2'>level %1</t>   ·   %2 XP toward level %3   ·   this machine prints up to <t color='#56d6e2'>L%4</t></t>",
    _lvl, missionNamespace getVariable ["AP_fabXp", 0], (_lvl + 1) min 20, _cap];
if (_free) then {
    (_d displayCtrl 1812) ctrlSetStructuredText parseText format [
        "<t size='0.9' color='#7ad19a'>FREE BUILD</t><t size='0.9'> — ingredients, level and schematics ignored. This machine prints up to <t color='#56d6e2'>L%1</t>.</t>", _cap];
};

if (count _rows > 0) then { _list lbSetCurSel 0; } else {
    (_d displayCtrl 1865) ctrlSetStructuredText parseText "<t color='#c8a05a'>No schematics learned yet.</t>";
};
