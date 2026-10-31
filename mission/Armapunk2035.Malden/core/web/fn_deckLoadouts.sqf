#include "..\..\macro.h"
/*
    AP_fnc_deckLoadouts -- the LOADOUT RACK as a deck app (approved mock
    deck-loadouts-b).

    Equip runs through the parametrized fn_equipLoadout -- its 150-line gear
    application (progress bar, virtual items, skins, the ND sync charge) stays
    the single copy, and the price is recomputed from the loadout content by
    AP_fnc_getLoadoutPrice, never read from the page.

    Save and delete are PORTS of their 60/30-line natives minus the input
    dialog and listbox slot codes: same name charset, length, weight and
    dupe-name rules, same APS_fnc_handleLoadouts calls, same logs. Slot
    addressing is the plain AP_loadoutHolder index -- the -3/-4/-5 codes were
    listbox artifacts, not data.

    ["data", type] / ["equip", idx, currency] / ["save", idx, name, type] /
    ["del", idx]
*/
params [["_verb", "", [""]], ["_a", 0, [0, ""]], ["_b", "", [""]], ["_c", "", [""]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

switch (toLower _verb) do {

case "data": {
    private _type = if (_a isEqualType "") then { _a } else { missionNamespace getVariable ["AP_deckLoadoutType", "rebel"] };
    AP_deckLoadoutType = _type;
    private _rows = [];
    {
        if (_x isNotEqualTo [] && {(_x select 1) isEqualTo _type}) then {
            _x params ["_uid", "_ltype", "_lname", "_gear", "_virt", "_skins"];
            private _price = [_ltype, _gear, _virt] call AP_fnc_getLoadoutPrice;
            private _items = [_gear] call AP_fnc_getLoadoutItems;
            _rows pushBack (createHashMapFromArray [
                ["idx", _forEachIndex], ["name", _lname],
                ["price", _price],
                ["nd", ([_price] call AP_fnc_ndFromLegacy)],
                ["items", _items apply { createHashMapFromArray [
                    ["name", getText (configFile >> "CfgWeapons" >> (_x select 0) >> "displayName")],
                    ["raw", _x select 0], ["n", _x select 1] ] }],
                ["virt", _virt apply { createHashMapFromArray [
                    ["name", ["getName", _x select 0] call AP_fnc_virtItemCfg], ["n", _x select 1] ] }]
            ]);
        };
    } forEach AP_loadoutHolder;
    createHashMapFromArray [
        ["type", _type], ["rows", _rows],
        ["slots", { _x isEqualTo [] } count AP_loadoutHolder],
        ["bank", AP_atmcash], ["ndBal", AP_nd toFixed 4],
        ["carry", missionNamespace getVariable ["AP_carryWeight", 0]]
    ]
};

case "equip": {
    private _row = AP_loadoutHolder param [_a, []];
    if (_row isEqualTo []) exitWith { ["Empty slot."] call _no };
    private _cur = if (_b isEqualTo "ND") then { "ND" } else { "$" };
    [_row select 1, [], _cur, _a] spawn AP_fnc_equipLoadout;
    ["Equipping -- the deck closes while your gear changes."] call _yes
};

case "save": {
    // fn_saveLoadout's validation, ported verbatim; slot -1 = first empty
    if (scriptAvailable(5)) exitWith { ["You spam this action..."] call _no };
    private _slot = _a;
    private _loadoutName = _b;
    private _type = if (_c isEqualTo "") then { missionNamespace getVariable ["AP_deckLoadoutType", "rebel"] } else { _c };
    if (((_loadoutName find "call ") != -1) || ((_loadoutName find "spawn ") != -1) || ((_loadoutName find "execVM") != -1) || ((_loadoutName find "_fnc_") != -1)) exitWith {
        ["Invalid loadout name."] call _no };
    private _chrByte = toArray _loadoutName;
    private _allowed = toArray "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_ ";
    if (count _chrByte < 3) exitWith { ["Name too short -- 3 characters minimum."] call _no };
    if (count _chrByte > 20) exitWith { ["Name too long -- 20 characters maximum."] call _no };
    if ((_chrByte findIf { !(_x in _allowed) }) != -1) exitWith { ["Unsupported characters in the name."] call _no };
    private _loadout = getUnitLoadout player;
    private _virtualInv = [_type] call AP_fnc_getVirtualInv;
    private _loadoutPrice = [_type, _loadout, _virtualInv, true] call AP_fnc_getLoadoutPrice;
    if (_loadoutPrice isEqualTo -1) exitWith { ["This loadout cannot be priced -- something worn is not sold anywhere."] call _no };
    if (AP_carryWeight > 90) exitWith { ["The maximum virtual weight for a loadout is 90."] call _no };
    private _skins = [AP_uniformBackpack_skins param [0, -1], AP_uniformBackpack_skins param [1, -1]];
    if (_slot < 0) then { _slot = AP_loadoutHolder findIf { _x isEqualTo [] }; };
    if (_slot < 0) exitWith { ["Every slot is full -- delete one first."] call _no };
    private _existing = AP_loadoutHolder param [_slot, []];
    if (_existing isEqualTo []) then {
        if ((AP_loadoutHolder findIf { (_x isNotEqualTo []) && {(_x select 1) isEqualTo _type} && {(_x select 2) isEqualTo _loadoutName} }) != -1) exitWith {
            [format ["You already have a loadout named '%1'.", _loadoutName]] call _no };
        private _uniqueID = round serverTime;
        [[2, getPlayerUID player, _uniqueID, AP_effSide, _type, _loadoutName, _loadout, _virtualInv, _skins], "APS_fnc_handleLoadouts", 2] call AP_fnc_MP;
        AP_loadoutHolder set [_slot, [_uniqueID, _type, _loadoutName, _loadout, _virtualInv, _skins]];
    } else {
        private _uniqueID = _existing select 0;
        [[3, getPlayerUID player, _uniqueID, AP_effSide, _type, _loadoutName, _loadout, _virtualInv, _skins], "APS_fnc_handleLoadouts", 2] call AP_fnc_MP;
        AP_loadoutHolder set [_slot, [_uniqueID, _type, _loadoutName, _loadout, _virtualInv, _skins]];
    };
    [["-LOADOUTSAVE-", player, profileName, format ["deck-saved loadout %1 at POS: %2 - %3 - %4", _loadoutName, getPosATL player, _loadout, _virtualInv]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    [format ["Saved '%1'.", _loadoutName]] call _yes
};

case "del": {
    private _row = AP_loadoutHolder param [_a, []];
    if (_row isEqualTo []) exitWith { ["Empty slot."] call _no };
    private _uniqueID = _row select 0;
    private _loadoutName = _row select 2;
    [[1, getPlayerUID player, _uniqueID, AP_effSide], "APS_fnc_handleLoadouts", 2] call AP_fnc_MP;
    AP_loadoutHolder set [_a, []];
    [["-LOADOUTDEL-", player, profileName, format ["deck-deleted loadout %1 at POS: %2", _uniqueID, getPosATL player]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    [format ["Deleted '%1'.", _loadoutName]] call _yes
};

default { ["unknown loadout verb"] call _no };
};
