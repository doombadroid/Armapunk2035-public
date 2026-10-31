/*
    fn_invSnapshot.sqf -- the `inventory` push for the I-screen (INVENTORY_SPEC.md §4a, §9.3).

        [] call AP_fnc_invSnapshot -> hashmap { you, ground, container, players }

    Reads only. Every list the page shows comes from here, built from the engine (worn slots,
    weaponsItems, the three container objects, weapon holders and suitcases within 5 m, the reach
    container fn_invOpen was handed) and from the deck's own bag builder (["inv"] call
    AP_fnc_deckData) so the phone's Inventory app and this screen can never disagree about the bag.

    JSON null is spelled objNull here: toJSON turns an Object into null (BIKI), and that is the
    documented way to put a null into a HashMap payload.
*/
private _wiAll = weaponsItems player;

private _fnInfoMap = {
    params ["_cls"];
    if (_cls isEqualTo "") exitWith { objNull };
    private _i = [_cls] call AP_fnc_invItemInfo;
    createHashMapFromArray [["cls", _cls], ["name", _i get "name"], ["icon", _i get "icon"]]
};
private _fnSlotWpn = {
    params ["_slot", "_cls"];
    if (_cls isEqualTo "") exitWith { objNull };
    private _i = [_cls] call AP_fnc_invItemInfo;
    private _wi = (_wiAll select { (_x select 0) isEqualTo _cls }) param [0, [_cls, "", "", "", [], [], ""]];
    private _cw = configFile >> "CfgWeapons" >> _cls >> "WeaponSlotsInfo";
    private _sockets = createHashMap;
    {
        _x params ["_key", "_cfgName", "_idx"];
        if (isClass (_cw >> _cfgName)) then { _sockets set [_key, [_wi param [_idx, ""]] call _fnInfoMap]; };
    } forEach [["muzzle", "MuzzleSlot", 1], ["pointer", "PointerSlot", 2], ["optic", "CowsSlot", 3], ["bipod", "UnderBarrelSlot", 6]];
    private _magArr = _wi param [4, []];
    private _mag = objNull;
    if (_magArr isNotEqualTo []) then {
        private _mi = [_magArr select 0] call AP_fnc_invItemInfo;
        _mag = createHashMapFromArray [["cls", _magArr select 0], ["name", _mi get "name"], ["ammo", _magArr select 1], ["cap", _mi get "cap"]];
    };
    createHashMapFromArray [
        ["id", format ["slot|%1|%2", _slot, _cls]], ["cls", _cls], ["name", _i get "name"], ["icon", _i get "icon"],
        ["mass", _i get "mass"], ["kind", "weapon"], ["wide", true], ["mag", _mag], ["sockets", _sockets]
    ]
};
private _fnSlotItem = {
    params ["_slot", "_cls", "_kind"];
    if (_cls isEqualTo "") exitWith { objNull };
    private _i = [_cls] call AP_fnc_invItemInfo;
    createHashMapFromArray [
        ["id", format ["slot|%1|%2", _slot, _cls]], ["cls", _cls], ["name", _i get "name"], ["icon", _i get "icon"],
        ["mass", _i get "mass"], ["kind", _kind], ["wide", false]
    ]
};

// ---- worn slots ----
private _assigned = createHashMapFromArray [["map", objNull], ["gps", objNull], ["radio", objNull], ["compass", objNull], ["watch", objNull], ["nvg", objNull]];
{
    private _cls = _x;
    private _cw = configFile >> "CfgWeapons" >> _cls;
    private _key = switch (getText (_cw >> "simulation")) do {
        case "ItemMap": { "map" }; case "ItemGPS": { "gps" }; case "ItemRadio": { "radio" };
        case "ItemCompass": { "compass" }; case "ItemWatch": { "watch" };
        default { if ((getNumber (_cw >> "ItemInfo" >> "type")) isEqualTo 616) then { "nvg" } else { "" } };
    };
    if (_key != "") then { _assigned set [_key, ["assigned:" + _key, _cls, "assigned"] call _fnSlotItem]; };
} forEach (assignedItems player);

private _slots = createHashMapFromArray [
    ["primary",   ["primary",  primaryWeapon player]   call _fnSlotWpn],
    ["launcher",  ["launcher", secondaryWeapon player] call _fnSlotWpn],
    ["handgun",   ["handgun",  handgunWeapon player]   call _fnSlotWpn],
    ["uniform",   ["uniform",  uniform player,  "uniform"]   call _fnSlotItem],
    ["vest",      ["vest",     vest player,     "vest"]      call _fnSlotItem],
    ["backpack",  ["backpack", backpack player, "backpack"]  call _fnSlotItem],
    ["headgear",  ["headgear", headgear player, "headgear"]  call _fnSlotItem],
    ["facewear",  ["facewear", goggles player,  "facewear"]  call _fnSlotItem],
    ["binocular", ["binocular", binocular player, "binocular"] call _fnSlotItem],
    ["assigned",  _assigned]
];

// ---- containers ----
private _containers = [];
{
    _x params ["_id", "_label", "_cls", "_obj"];
    if (_cls != "" && {!isNull _obj}) then {
        _containers pushBack (createHashMapFromArray [
            ["id", _id], ["label", _label], ["cls", _cls], ["name", ([_cls] call AP_fnc_invItemInfo) get "name"],
            ["load", loadAbs _obj], ["cap", maxLoad _obj], ["items", [_obj, _id] call AP_fnc_invCargoRead]
        ]);
    };
} forEach [
    ["uniform",  "UNIFORM",  uniform player,  uniformContainer player],
    ["vest",     "VEST",     vest player,     vestContainer player],
    ["backpack", "BACKPACK", backpack player, backpackContainer player]
];

// ---- bag (the deck's builder, remapped to the §4a names) ----
private _deck = ["inv"] call AP_fnc_deckData;
private _bagItems = (_deck get "items") apply {
    private _id = _x get "id";
    private _ill = ["getIllegalPrice", _id] call AP_fnc_virtItemCfg;
    createHashMapFromArray [
        ["id", _id], ["name", _x get "name"], ["icon", ["getIcon", _id] call AP_fnc_virtItemCfg],
        ["qty", _x get "qty"], ["wt", _x get "weight"], ["total", _x get "total"], ["sell", _x get "sell"],
        ["illegal", (_ill isEqualType 0) && {_ill >= 0}], ["canDrop", true], ["desc", _x get "desc"]
    ]
};
private _bag = createHashMapFromArray [
    ["load", _deck get "weight"], ["cap", _deck get "max"], ["items", _bagItems], ["odd", _deck get "odd"]
];

// ---- ground: every weapon holder + suitcase within 5 m, one merged pile ----
private _gPhys = []; private _gVirt = []; private _gDist = -1;
{
    private _h = _x;
    private _rows = [_h, "ground:" + (netId _h)] call AP_fnc_invCargoRead;
    if (_rows isNotEqualTo []) then {
        _gPhys append _rows;
        private _d = player distance _h;
        if (_gDist < 0 || {_d < _gDist}) then { _gDist = _d };
    };
} forEach (nearestObjects [player, ["WeaponHolder", "WeaponHolderSimulated"], 5]);
{
    private _c = _x;
    private _items = _c getVariable ["AP_droppedItems", []];
    if (_items isNotEqualTo []) then {
        private _left = round ((_c getVariable ["AP_dropUntilSrv", serverTime + 1200]) - serverTime);
        {
            _x params [["_id", "", [""]], ["_qty", 0, [0]]];
            if (_qty > 0) then {
                private _isCash = _id isEqualTo "money";
                _gVirt pushBack (createHashMapFromArray [
                    ["case", netId _c], ["id", _id],
                    ["name", if (_isCash) then { "Cash" } else { ["getName", _id] call AP_fnc_virtItemCfg }],
                    ["icon", if (_isCash) then { "icons\money.paa" } else { ["getIcon", _id] call AP_fnc_virtItemCfg }],
                    ["qty", _qty], ["wt", if (_isCash) then { 0 } else { ["getItemWeight", _id] call AP_fnc_virtItemCfg }],
                    ["despawn", _left]
                ]);
            };
        } forEach _items;
        private _d = player distance _c;
        if (_gDist < 0 || {_d < _gDist}) then { _gDist = _d };
    };
} forEach (nearestObjects [player, ["Land_Suitcase_F"], 5]);

// ---- the reach container (vehicle / crate) fn_invOpen was handed ----
private _cont = uiNamespace getVariable ["AP_invContainer", objNull];
private _container = objNull;
if (!isNull _cont) then {
    private _note = "";
    private _usedBy = _cont getVariable ["AP_veh_in_use", objNull];
    if (!alive _cont) then { _note = "GONE" };
    if (_note == "" && {vehicle player != _cont} && {player distance _cont > (10 + 0.5 * sizeOf typeOf _cont)}) then { _note = "OUT OF REACH" };
    if (_note == "" && {_cont getVariable ["AP_trunkLock", false]}) then { _note = "THE SERVER IS SAVING THIS VEHICLE" };
    if (_note == "" && {_cont getVariable ["AP_seizing", false]}) then { _note = "BEING SEIZED" };
    if (_note == "" && {!isNull _usedBy} && {_usedBy != player}) then { _note = "SOMEONE ELSE IS IN IT" };
    private _sub = switch (true) do {
        case (_cont in AP_vehicles): { "KEYED · YOURS" };
        case (AP_effSide isEqualTo west): { "POLICE" };
        default { "UNLOCKED" };
    };
    _container = createHashMapFromArray [
        ["id", netId _cont],
        ["label", toUpper getText (configFile >> "CfgVehicles" >> (typeOf _cont) >> "displayName")],
        ["sub", _sub], ["load", loadAbs _cont], ["cap", maxLoad _cont],
        ["items", if (_note == "") then { [_cont, "container"] call AP_fnc_invCargoRead } else { [] }],
        ["lockedNote", _note]
    ];
};

// ---- GIVE targets within 5 m ----
private _players = [];
{
    if (_x isNotEqualTo player && { alive _x } && { !(_x getVariable ["AP_invisOn", false]) } && { player distance _x <= 5 }) then {
        _players pushBack (createHashMapFromArray [
            ["uid", getPlayerUID _x], ["name", [name _x] call AP_fnc_cleanName], ["dist", (player distance _x) toFixed 1]
        ]);
    };
} forEach allPlayers;

private _side = switch (true) do {
    case (AP_effSide isEqualTo west): { "cop" };
    case (AP_effSide isEqualTo independent): { "medic" };
    default { "civ" };
};

createHashMapFromArray [
    ["you", createHashMapFromArray [
        ["name", [name player] call AP_fnc_cleanName], ["side", _side],
        ["flags", createHashMapFromArray [
            ["overweight", AP_carryWeight > AP_maxWeight],
            ["restrained", player getVariable ["AP_restrained", false]],
            ["inVehicle", vehicle player != player]
        ]],
        ["slots", _slots], ["containers", _containers], ["bag", _bag]
    ]],
    ["ground", createHashMapFromArray [["dist", _gDist max 0], ["physical", _gPhys], ["virtual", _gVirt]]],
    ["container", _container],
    ["players", _players]
]
