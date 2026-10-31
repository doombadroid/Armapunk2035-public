/*
    AP_fnc_deckHouse -- the deck's HOUSE dashboard (approved mock deck-house-a).

    One screen of function cards over the native fn_houseMenu's dispatcher. All
    downstream actions already read AP_pInact_curTarget and own their flows, so
    this splits them honestly:

      IN-DECK (instant, no native confirm): lock/unlock, lights, rename.
      CLOSE-AND-RUN (the native flow has its own dialog or guiMessage confirm):
      upgrades, sell, list, helipad, makeover, storage, keys, gang house,
      garage access. Running a blocking confirm UNDER an open browser control
      is how a deck gets wedged; handing over is how it stays honest.

    ["data"] / ["lock"] / ["lights", rgbIdx] / ["rename", name] /
    ["run", verb]  -- close the deck, run the named native flow
*/
params [["_verb", "", [""]], ["_a", "", ["", 0]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
private _house = missionNamespace getVariable ["AP_pInact_curTarget", objNull];
private _isOwner = !isNull _house && {(getPlayerUID player) isEqualTo (_house getVariable ["AP_homeOwner", ""])};

private _LIGHTS = [["Regular", [250, 150, 50]], ["Red", [40, 0, 0]], ["Blue", [0, 0, 40]], ["Aqua", [0, 40, 40]],
                   ["Green", [0, 40, 0]], ["Orange", [80, 40, 0]], ["Yellow", [80, 80, 0]], ["Pink", [40, 0, 40]]];

switch (toLower _verb) do {

case "data": {
    if (isNull _house || {!((typeOf _house) in AP_houseTypes)}) exitWith { createHashMapFromArray [["gone", true]] };
    private _isGarage = (typeOf _house) in ["Land_i_Garage_V1_F", "Land_i_Garage_V2_F", "Land_i_Garage_V1_dam_F", "Land_i_Garage_V2_dam_F"];
    private _vCap = _house getVariable ["AP_vcap", 100];
    private _pCap = _house getVariable ["AP_phys_cap", 100];
    ([typeOf _house] call AP_fnc_houseConfig) params ["_cost", "_sellPrice", "_pCaps", "_vCaps"];
    private _upCost = {
        params ["_cur", "_caps"];
        private _i = _caps findIf { (_x select 0) > _cur };
        if (_i isEqualTo -1) then { [] } else { [(_caps select _i) select 0, (_caps select _i) select 1] }
    };
    // house value = the same paid-in total the native panel shows
    private _paid = { params ["_cur", "_caps"]; private _t = 0;
        { _x params ["_cap", "_c"]; if (_cur < _cap) exitWith {}; _t = _t + _c; } forEach _caps; _t };
    private _value = _cost + ([_pCap, _pCaps] call _paid) + ([_vCap, _vCaps] call _paid)
        + ([0, 20000] select (_house getVariable ["AP_barrel_unaged", false]))
        + ([0, 20000] select (_house getVariable ["AP_greenhouse_unaged", false]))
        + ([0, 350000] select (_house getVariable ["AP_leadcontainer_unaged", false]));
    private _price = _house getVariable ["AP_house_price", -1];
    private _gid = AP_gang_data param [0, -1];
    createHashMapFromArray [
        ["name", getText (configFile >> "CfgVehicles" >> (typeOf _house) >> "displayName")],
        ["custom", _house getVariable ["AP_houseName", ""]],
        ["id", _house getVariable ["AP_houseID", -1]],
        ["owner", _isOwner], ["garage", _isGarage],
        ["value", _value],
        ["vCap", _vCap], ["pCap", _pCap],
        ["vNext", [_vCap, _vCaps] call _upCost], ["pNext", [_pCap, _pCaps] call _upCost],
        ["locked", _house getVariable ["AP_buildingLocked", false]],
        ["lightsOn", !isNull (_house getVariable ["AP_lightSource", objNull])],
        ["lights", _LIGHTS apply { _x select 0 }],
        ["barrel", _house getVariable ["AP_barrel_unaged", false]],
        ["greenhouse", _house getVariable ["AP_greenhouse_unaged", false]],
        ["lead", _house getVariable ["AP_leadcontainer_unaged", false]],
        ["listed", _price isNotEqualTo -1], ["listPrice", _price],
        ["keys", (_house getVariable ["AP_house_keys", []]) apply { format ["%1", _x param [1, _x param [0, "?"]]] }],
        ["keyCap", _house getVariable ["AP_keycap", 0]],
        ["helipadable", (typeOf _house isEqualTo "Land_i_Shed_Ind_F") && _isOwner && {!(_house getVariable ["AP_helipad", false])}],
        ["makeover", (["eligible", typeOf _house] call AP_fnc_maldenMap) && _isOwner],
        ["gangSet", (_gid isNotEqualTo -1) && {AP_gang_data param [2, 0] isEqualTo 1}],
        ["isGangHouse", (_house getVariable ["AP_house_gang", -1]) isEqualTo _gid]
    ]
};

case "lock": {
    if (!_isOwner) exitWith { ["Owner only."] call _no };
    [_house] call AP_fnc_lockHouse;
    [["Unlocked.", "Locked."] select (_house getVariable ["AP_buildingLocked", false])] call _yes
};

case "lights": {
    if (!_isOwner) exitWith { ["Owner only."] call _no };
    private _rgb = (_LIGHTS param [_a max 0, _LIGHTS select 0]) select 1;
    [_house, _rgb] call AP_fnc_lightHouseAction;
    ["Lights."] call _yes
};

case "rename": {
    if (!_isOwner) exitWith { ["Owner only."] call _no };
    if !(_a isEqualType "") exitWith { ["Type a name."] call _no };
    [_house, _a] spawn AP_fnc_renameHouse;
    ["Rename sent."] call _yes
};

case "run": {
    // every one of these flows confirms or dialogs natively -- hand the screen over
    private _act = switch (_a) do {
        case "upV":      { { [AP_pInact_curTarget, 'vstorage'] spawn AP_fnc_upgradeProperty } };
        case "upP":      { { [AP_pInact_curTarget, 'pstorage'] spawn AP_fnc_upgradeProperty } };
        case "barrel":   { { [AP_pInact_curTarget, 'aging'] spawn AP_fnc_upgradeProperty } };
        case "greenhouse": { { [AP_pInact_curTarget, 'greenhouse'] spawn AP_fnc_upgradeProperty } };
        case "lead":     { { [AP_pInact_curTarget, 'leadcontainer'] spawn AP_fnc_upgradeProperty } };
        case "storage":  { { [AP_pInact_curTarget, false] spawn AP_fnc_storageOpen } };
        case "keys":     { { ['propertyKeys'] call AP_fnc_createDialog } };
        case "sellBank": { { [AP_pInact_curTarget] spawn AP_fnc_sellHouse } };
        case "listMkt":  { { [AP_pInact_curTarget] spawn AP_fnc_marketSellHouse } };
        case "helipad":  { { [AP_pInact_curTarget] spawn AP_fnc_buyHelipad } };
        case "makeover": { { ["open", AP_pInact_curTarget] spawn AP_fnc_maldenPicker } };
        case "shop":     { { [player, player, -1, "homegoods"] spawn AP_fnc_virtualShopMenu } };
        case "garage":   { { ['Car', AP_pInact_curTarget] call AP_fnc_handleVehicles } };
        case "storeVeh": { { [AP_pInact_curTarget, player] spawn AP_fnc_storeVehicle } };
        case "setGang":  { { [AP_pInact_curTarget] spawn AP_fnc_setGangHouse } };
        default { {} };
    };
    if (!_isOwner && !(_a in ["storage", "garage", "storeVeh"])) exitWith { ["Owner only."] call _no };
    [_act] spawn { params ["_act"]; closeDialog 0; uiSleep 0.15; call _act; };
    ["Handing over..."] call _yes
};

default { ["unknown house verb"] call _no };
};
