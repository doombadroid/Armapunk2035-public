#include "..\..\macro.h"
/*
    AP_fnc_adminClothingMenu (LooneyBin, ui branch) -- the staff menu's CLOTHING tab (idd 12900, panel
    13105). Indexes EVERY clothing item in the game, shops or not: uniforms (ItemInfo type 801), vests
    (701), headgear (605) from CfgWeapons, goggles from CfgGlasses, backpacks from CfgVehicles Bag_Base --
    all scope 2. WEAR equips it on the selected player (or yourself); GIVE puts it in their inventory
    (goggles/backpacks always equip -- they aren't carriable items). Level > 2, every action logged.
    Modes: ["init"] | ["filter"] | ["select"] | ["wear"] | ["give"]
*/
params [["_mode", "init", [""]]];
if ((call AP_adminLevel) <= 2) exitWith {};
disableSerialization;
private _display = findDisplay 12900;
if (isNull _display) exitWith {};
private _list = _display displayCtrl 13121;
private _info = _display displayCtrl 13124;

// selected player in the staff list (12901) or yourself -- same resolution as fn_adminAddMoney
private _fnTarget = {private _sel = lbCurSel 12901;
    if (_sel < 0) exitWith { player };
    private _u = missionNamespace getVariable [lbData [12901, _sel], objNull];
    if (isNull _u || {!alive _u}) then { player } else { _u }};
private _fnLog = {params ["_what", "_t"];
    [["-ADMINSPAWN-", player, profileName, format ["admin-spawned %1 for %2 at POS: %3", _what, name _t, getPosATL _t]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
#define KIND_TAGS ["[UNI]", "[VST]", "[HAT]", "[GLS]", "[BAG]"]

switch (_mode) do {

    case "init";
    case "filter": {if (isNil "AP_adminClothCache") then {AP_adminClothCache = [];
            // uniforms / vests / headgear live in CfgWeapons with an ItemInfo type
            {private _dn = getText (_x >> "displayName");
                if (_dn != "") then {private _it = getNumber (_x >> "ItemInfo" >> "type");
                    private _kind = switch (_it) do { case 801: { 0 }; case 701: { 1 }; case 605: { 2 }; default { -1 }; };
                    if (_kind >= 0) then { AP_adminClothCache pushBack [_dn, configName _x, _kind, getText (_x >> "picture")]; };};
            } forEach ("getNumber (_x >> 'scope') == 2 && {isClass (_x >> 'ItemInfo')}" configClasses (configFile >> "CfgWeapons"));
            // goggles
            {private _dn = getText (_x >> "displayName");
                if (_dn != "") then { AP_adminClothCache pushBack [_dn, configName _x, 3, getText (_x >> "picture")]; };
            } forEach ("getNumber (_x >> 'scope') == 2" configClasses (configFile >> "CfgGlasses"));
            // backpacks
            {private _dn = getText (_x >> "displayName");
                if (_dn != "" && {(configName _x) isKindOf "Bag_Base"}) then {
                    AP_adminClothCache pushBack [_dn, configName _x, 4, getText (_x >> "picture")];};
            } forEach ("getNumber (_x >> 'scope') == 2" configClasses (configFile >> "CfgVehicles"));
            AP_adminClothCache sort true;};
        private _filter = toLower (ctrlText (_display displayCtrl 13120));
        lbClear _list; {_x params ["_dn", "_cls", "_kind", "_pic"];
            if (_filter isEqualTo "" || {(toLower _dn) find _filter >= 0} || {(toLower _cls) find _filter >= 0}) then {
                private _i = _list lbAdd format ["%1 %2", KIND_TAGS select _kind, _dn];
                _list lbSetData [_i, _cls];
                _list lbSetValue [_i, _kind];
                _list lbSetPicture [_i, _pic];};} forEach AP_adminClothCache;
        if (_mode isEqualTo "init") then {
            _info ctrlSetStructuredText parseText format ["<t color='#8993a0'>%1 clothing items indexed (uniforms, vests, headgear, goggles, backpacks).<br/>WEAR equips the selected player (or you). GIVE adds to inventory.</t>", count AP_adminClothCache];
        };};

    case "select": {private _sel = lbCurSel _list;
        if (_sel < 0) exitWith {};
        private _cls = _list lbData _sel;
        private _kind = _list lbValue _sel;
        private _root = ["CfgWeapons", "CfgWeapons", "CfgWeapons", "CfgGlasses", "CfgVehicles"] select _kind;
        _info ctrlSetStructuredText parseText format ["<t color='#ebeff4' size='1.1'>%1</t><br/><t color='#8993a0'>%2  ·  %3</t>",
            getText (configFile >> _root >> _cls >> "displayName"), _cls,
            ["uniform", "vest", "headgear", "goggles", "backpack"] select _kind];};

    case "wear";
    case "give": {private _sel = lbCurSel _list;
        if (_sel < 0) exitWith { ["Select a clothing item first.", "basic"] spawn AP_fnc_handleMessage; };
        private _cls = _list lbData _sel;
        private _kind = _list lbValue _sel;
        private _t = call _fnTarget;
        private _wear = (_mode isEqualTo "wear") || (_kind in [3, 4]);   // goggles/backpacks always equip
        if (_wear) then {private _k = ["uniform", "vest", "headgear", "goggles", "backpack"] select _kind;
            [[_k, _cls, 1], "AP_fnc_adminGearReceive", _t, false] call AP_fnc_MP;} else {
            [["item", _cls, 1], "AP_fnc_adminGearReceive", _t, false] call AP_fnc_MP;};
        [format ["1x %1 (%2, %3)", _cls, ["uniform", "vest", "headgear", "goggles", "backpack"] select _kind, ["give", "wear"] select _wear], _t] call _fnLog;
        [format ["%1 %2 for %3.", ["Gave", "Equipped"] select _wear, _cls, name _t], "basic"] spawn AP_fnc_handleMessage;};};
