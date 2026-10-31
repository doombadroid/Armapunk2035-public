/*
    AP_fnc_deckSuites -- LUXE SUITES tower directory + tenant actions
    (approved mock deck-suites).

    Rows come off AP_suiteRows by the same oid walk the kiosk did; days and
    arrears are computed from the SERVER's pushed clock (AP_suiteNow), never
    the client's. Lease keeps the courtesy ND check and the AP_suiteBusy latch;
    the server debits and is free to refuse regardless.

    ["data"] / ["lease", oid, floor] / ["pay", oid] / ["end", oid]
    ["storage", oid, floor]  hands over to the native storage flow
    ["furn"]                 hands over to the homegoods shop
*/
params [["_verb", "", [""]], ["_a", "", [""]], ["_b", 0, [0]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

switch (toLower _verb) do {

case "data": {
    private _tower = missionNamespace getVariable ["AP_suiteKioskTower", objNull];
    if (isNull _tower) exitWith { createHashMapFromArray [["gone", true]] };
    private _uid = getPlayerUID player;
    private _now = missionNamespace getVariable ["AP_suiteNow", 0];
    private _rowsH = missionNamespace getVariable ["AP_suiteRows", createHashMap];
    private _rows = [];
    for "_f" from 2 to 30 do {
        private _oid = [_tower, _f] call AP_fnc_suiteOid;
        private _row = _rowsH getOrDefault [_oid, []];
        private _owner = _row param [2, ""];
        private _due = _row param [3, 0];
        private _over = _row param [4, 0];
        private _mine = _owner isEqualTo _uid;
        _rows pushBack (createHashMapFromArray [
            ["oid", _oid], ["floor", _f],
            ["status", if (_owner isEqualTo "") then { "vacant" } else {
                if (_mine) then { if (_over > 0) then { "overdue" } else { "mine" } } else { "leased" } }],
            ["days", if (_mine && {_due > 0} && {_now > 0}) then { floor ((_due - _now) / 86400) } else { -1 }],
            ["settleDays", if (_mine && {_over > 0} && {_now > 0}) then { (10 - floor ((_now - _over) / 86400)) max 0 } else { -1 }]
        ]);
    };
    createHashMapFromArray [
        ["rows", _rows],
        ["rent", missionNamespace getVariable ["AP_suiteRentND", 0]],
        ["nd", AP_nd toFixed 4],
        ["busy", missionNamespace getVariable ["AP_suiteBusy", false]]
    ]
};

case "lease": {
    if (missionNamespace getVariable ["AP_suiteBusy", false]) exitWith { ["Still working on your last request."] call _no };
    private _row = (missionNamespace getVariable ["AP_suiteRows", createHashMap]) getOrDefault [_a, []];
    if ((_row param [2, ""]) isNotEqualTo "") exitWith { ["That suite is leased."] call _no };
    if !([AP_suiteRentND] call AP_fnc_ndAfford) exitWith {
        [format ["You need %1 ND for the first month.", AP_suiteRentND]] call _no };
    AP_suiteBusy = true;
    [["lease", _a, _b], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    [format ["Leasing floor %1...", _b]] call _yes
};

case "pay": {
    if (missionNamespace getVariable ["AP_suiteBusy", false]) exitWith { ["Busy."] call _no };
    AP_suiteBusy = true;
    [["payNow", _a], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    ["Settling your arrears..."] call _yes
};

case "end": {
    // page double-arms with the destruction warning; the server re-checks ownership
    if (missionNamespace getVariable ["AP_suiteBusy", false]) exitWith { ["Busy."] call _no };
    AP_suiteBusy = true;
    [["end", _a], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    ["Lease ended."] call _yes
};

case "storage": {
    [_a, _b] spawn {
        params ["_oid", "_floor"];
        closeDialog 0;
        uiSleep 0.15;
        [_oid, _floor] spawn AP_fnc_suiteStorage;
    };
    ["Opening storage..."] call _yes
};

case "furn": {
    [] spawn {
        closeDialog 0;
        uiSleep 0.15;
        [player, player, -1, "homegoods"] spawn AP_fnc_virtualShopMenu;
    };
    ["Opening the furniture shop..."] call _yes
};

default { ["unknown suites verb"] call _no };
};
