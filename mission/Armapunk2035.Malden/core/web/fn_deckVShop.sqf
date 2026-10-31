/*
    AP_fnc_deckVShop -- the deck's VEHICLE SHOP app (approved mock deck-vshop-a).

    Buy logic is NOT here: fn_vehicleShopBuy takes the whole configure result as
    a parameter and keeps every gate (garage cap, duty caps, ND pricing, gov
    tax, talent locks, pad raycasts). This builds the payload
    and RECOMPUTES the mod cost from AP_fnc_vehicleModConfig / AP_fnc_hornCfg by
    the chosen VALUES -- the page picks options, it never prices them.

    ["data"]                                   payload for "vshop"
    ["buy", class, alarm, skinID, skinText, modVals[8]]
*/
params [["_verb", "", [""]], ["_class", "", [""]], ["_alarm", 0, [0]],
        ["_skinID", -1, [0]], ["_skinText", "", [""]], ["_modVals", [], [[]]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

switch (toLower _verb) do {

case "data": {
    AP_veh_shop params [["_shop", "", [""]], "", "", ["_disableBuy", false, [false]]];
    if (_shop isEqualTo "") exitWith { createHashMapFromArray [["gone", true]] };
    private _list = +(["shopVehicles", _shop] call AP_fnc_vehicleConfig);
    // same curation the native menu applies (fn_vehicleShopMenu srt_car block)
    if (_shop isEqualTo "srt_car" && {AP_effSide isEqualTo west}) then {
        {
            private _cut = _x;   // findIf's _x shadows forEach's -- capture first
            private _i = _list findIf { (_x select 0) isEqualTo _cut };
            if (_i isNotEqualTo -1) then { _list deleteAt _i };
        } forEach ["B_G_Offroad_01_armed_F", "O_MRAP_02_F"];
    };
    private _ndShop = _shop isEqualTo "nd_car";
    private _tax = if (_shop in ["reb_car", "nd_car"]) then { 0 } else { call AP_fnc_getGovTax };
    private _rows = [];
    {
        private _cn = _x select 0;
        private _label = _x select 1;
        private _info = [_cn] call AP_fnc_fetchVehInfo;
        private _row = ["getVehicleRowParsed", "", _cn] call AP_fnc_vehicleConfig;
        private _p = (_row param [7, 0]) * (["vehshop", true] call AP_fnc_getDiscount);
        _p = _p + (_p * _tax);
        private _ndP = "";
        if (_ndShop) then {
            _ndP = [_cn] call AP_fnc_ndPriceCfg;
            if (_ndP isEqualTo "") then { _ndP = [round _p] call AP_fnc_ndFromLegacy; };
        };
        private _texs = (["ownedTextures", _cn] call AP_fnc_vehicleTextures) apply {
            createHashMapFromArray [["id", _x select 0], ["name", _x select 1]] };
        _rows pushBack (createHashMapFromArray [
            ["class", _cn],
            ["name", if (_label isEqualTo "") then {_info param [3, _cn]} else {_label}],
            ["pic", _info param [2, ""]],
            ["price", round _p], ["ndPrice", _ndP],
            ["sell", _row param [8, 0]], ["fee", _row param [9, 0]],
            ["trunk", _row param [10, 0]],
            ["speed", _info param [8, 0]],
            ["seats", ([_cn, true] call BIS_fnc_crewCount) - 1],
            ["fuel", _info param [12, 0]], ["armor", _info param [9, 0]],
            ["talent", ["talentCheck", "", _cn] call AP_fnc_vehicleConfig],
            ["kind", switch (true) do {
                case (_cn isKindOf "Air"): {"AIR"};
                case (_cn isKindOf "Ship"): {"SEA"};
                default {"LAND"} }],
            ["skins", _texs]
        ]);
    } forEach _list;

    // mod catalogue once: [slot, label, [[optLabel, value, cost], ...]]
    private _cfg = call AP_fnc_vehicleModConfig;
    private _mods = [];
    {
        _x params ["_slot", "_mName", "_opts"];
        if (_slot in [1, 2, 4, 5, 6, 7, 8, 9]) then {
            private _apFree = _slot isEqualTo 9 && {201 in AP_side_talents};
            _mods pushBack (createHashMapFromArray [
                ["slot", _slot], ["name", _mName],
                ["opts", _opts apply {
                    private _cost = _x select 2;
                    private _lbl = _x select 0;
                    if (_apFree && {(_x select 1) isEqualTo 1}) then { _cost = 0; _lbl = "Autopilot Module - FREE"; };
                    createHashMapFromArray [["label", _lbl], ["val", _x select 1], ["cost", _cost]] }]
            ]);
        };
    } forEach _cfg;
    _mods pushBack (createHashMapFromArray [
        ["slot", 3], ["name", "Custom Horn"],
        ["opts", ([1] call AP_fnc_hornCfg) apply {
            createHashMapFromArray [["label", _x select 1], ["val", _x select 0], ["cost", _x select 2]] }]
    ]);

    createHashMapFromArray [
        ["shop", _shop], ["nd", _ndShop], ["ndBal", AP_nd toFixed 4],
        ["bank", AP_atmcash], ["disableBuy", _disableBuy],
        ["duty", _shop in ["maxtac_car", "firefighter_car", "srt_car"]],
        ["rows", _rows], ["mods", _mods]
    ]
};

case "buy": {
    if (_class isEqualTo "") exitWith { ["Pick a vehicle first."] call _no };
    // recompute the mod cost from the config by VALUE -- never from the page
    private _cfg = call AP_fnc_vehicleModConfig;
    private _cost = 0;
    private _slots = [1, 2, 3, 4, 5, 7, 8, 9, 6];   // 6 (Chameleon Paint) APPENDED: the page sends it 9th, so an older page's 8 values still line up
    {
        private _slot = _slots select _forEachIndex;
        private _val = _x;
        if (_val isNotEqualTo 0) then {
            if (_slot isEqualTo 3) then {
                private _h = ([1] call AP_fnc_hornCfg) select { (_x select 0) isEqualTo _val };
                _cost = _cost + ((_h param [0, [0, "", 0]]) param [2, 0]);
            } else {
                private _opts = ((_cfg select { (_x select 0) isEqualTo _slot }) param [0, [0, "", []]]) select 2;
                private _o = _opts select { (_x select 1) isEqualTo _val };
                private _c2 = (_o param [0, ["", 0, 0]]) param [2, 0];
                if (_slot isEqualTo 9 && {_val isEqualTo 1} && {201 in AP_side_talents}) then { _c2 = 0; };
                _cost = _cost + _c2;
            };
        };
    } forEach _modVals;
    // The native dialog resets AP_ndShop in its wait-until-closed tail; the deck
    // has no such tail, so derive it per purchase or an nd_car visit would leave
    // every later cash buy priced in New Drachma.
    AP_ndShop = (AP_veh_shop param [0, ""]) isEqualTo "nd_car";
    [[_class, _alarm, _skinID, _skinText, _modVals, _cost]] spawn AP_fnc_vehicleShopBuy;
    ["Purchase sent."] call _yes
};

default { ["unknown vshop verb"] call _no };
};
