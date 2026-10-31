/*
    AP_fnc_deckChop -- CHOP SHOP as a deck app (approved mock deck-chopshop),
    plus the Pay 'n' Spray skin vendor (approved mock deck-skinshop) -- two tiny
    verbs sets, one file, because both are a list and one commit.

    ["chopData"] / ["chop", netId] / ["claim", netId]
    ["skinData"] / ["skin", lootBoxID]

    Chop prices are ALWAYS re-derived from the vehicle config row inside the
    parametrized natives -- the page shows a quote, it never sets one. The skin
    buy re-reads the price from the config by lootBox id for the same reason.
*/
params [["_verb", "", [""]], ["_a", "", ["", 0]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

switch (toLower _verb) do {

case "chopdata": {
    private _mk = missionNamespace getVariable ["AP_chopShop", ""];
    if (_mk isEqualTo "") exitWith { createHashMapFromArray [["gone", true]] };
    private _rows = [];
    {
        if (alive _x && {crew _x isEqualTo []}) then {
            private _cn = typeOf _x;
            private _row = ["getVehicleRow", "", _cn] call AP_fnc_vehicleConfig;
            private _side = switch (_x getVariable ["AP_side", -1]) do { case "cop": {1}; case "med": {2}; default {0} };
            private _price = if ((_row select 8) isEqualType []) then {(_row select 8) select _side} else {_row select 8};
            private _mineIdx = AP_vehicles find _x;
            _rows pushBack (createHashMapFromArray [
                ["net", netId _x],
                ["name", getText (configFile >> "CfgVehicles" >> _cn >> "displayName")],
                ["pic", getText (configFile >> "CfgVehicles" >> _cn >> "picture")],
                ["price", _price],
                ["mine", _mineIdx isNotEqualTo -1],
                ["dist", round (player distance _x)]
            ]);
        };
    } forEach (nearestObjects [getMarkerPos _mk, ["Car", "Truck", "Air", "Ship"], 25]);
    createHashMapFromArray [["rows", _rows]]
};

case "chop": {
    if !(_a isEqualType "") exitWith { ["bad id"] call _no };
    [_a] spawn AP_fnc_chopShopSell;
    ["Chopping..."] call _yes
};

case "claim": {
    if !(_a isEqualType "") exitWith { ["bad id"] call _no };
    [_a] spawn AP_fnc_chopShopClaim;
    ["Claiming..."] call _yes
};

case "skindata": {
    createHashMapFromArray [
        ["rows", (call AP_fnc_vehicleSkinShopCfg) select 1 apply { createHashMapFromArray [
            ["class", _x select 0], ["name", _x select 1],
            ["id", _x select 2], ["price", _x select 3],
            ["pic", getText (configFile >> "CfgVehicles" >> (_x select 0) >> "picture")],
            ["owned", (_x select 2) in AP_lootRewards]
        ] }],
        ["bank", AP_atmcash]
    ]
};

case "skin": {
    private _id = _a;
    private _row = ((call AP_fnc_vehicleSkinShopCfg) select 1) select { (_x select 2) isEqualTo _id };
    if (_row isEqualTo []) exitWith { ["No such skin."] call _no };
    (_row select 0) params ["", "_name", "_lootBoxID", "_price"];
    if (_lootBoxID in AP_lootRewards) exitWith { ["You already own that skin."] call _no };
    if !([_price] call AP_fnc_debitCard) exitWith { ["You cannot afford that."] call _no };
    [[player, _lootBoxID, getPlayerUID player], "APS_fnc_doBuySkin", 2] spawn AP_fnc_MP;
    AP_lootRewards pushBack _lootBoxID;
    playSound "purchase";
    [format ["Bought %1 -- apply it at any garage.", _name]] call _yes
};

default { ["unknown chop verb"] call _no };
};
