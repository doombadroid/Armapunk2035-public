/*
    (ASY|TON)_fnc_getVehicles  (LooneyBin: 2020 garage-retrieve adapter)
    2020 client args : [player, _type]   (fn_handleVehicles -> "AP_vehicleGarage" dialog)
    Queries the player's STORED vehicles (alive=1, active=0, not listed) of _type, reshapes each
    row into the index layout fn_vehicleGarageMenu / fn_vehicleGaragePull expect, and sends the
    list (wrapped once) to AP_fnc_vehicleGarageMenu -> AP_garageData.

    Client row indices consumed (fn_vehicleGarageMenu builds _temp from these, fn_vehicleGaragePull reads it):
      0 = id (lbValue)   2 = classname   4 = pid (ownership)
      7 = plate   8 = color   10 = mods   11 = vehWear[dmg,fuel,armour]   12 = customPlate
    THIS ADAPTER IS THE ONLY PRODUCER (fn_handleVehicles -> here). The client must read THIS reshaped
    layout, NOT the raw `vehicles` table schema -- b0162 mis-"fixed" the client to raw-table indices
    (mods@15/fuel@11/damage@12/customplate@16) and broke mods+fuel+damage because the client never sees
    the raw row. mods/customplate now come from real columns; vehWear built from the fuel/damage ints below.
    NOTE: rewritten from the 2017 5-arg signature — only caller was fn_garageCount, now self-contained.
    NOTE: DB_fnc_asyncQuery `call compile`s the whole extDB3 result, so raw varchar columns
    (classname/pid) MUST be QUOTE()'d in SQL or compile dies on the bare token (Undefined variable).
    Numeric columns come back already typed — do NOT parseNumber them.
*/
params [["_unit",objNull,[objNull]], ["_type","",[""]]];
if (isNull _unit || _type == "") exitWith {};

private _uid = getPlayerUID _unit;
if (_uid == "") exitWith {};
// GARAGE SIDE BY ROSTER, NOT BY ENGINE SIDE. `side _unit` was a safe enough source while the only way to be
// west was to hold a west mission slot; it stops being one the moment the MaxSec group is published by netId,
// because a client that joins it is genuinely side west to the engine and would be handed the cop garage.
// The roster is the record a client cannot reach. Unrostered players -- and everyone, while AP_dutyEnabled is
// false -- fall through to the switch below unchanged, so a flag-false server queries exactly what it did
// before. (Rows are also filtered by pid, so the worst case was always "your own cop vehicles", never
// someone else's; this is about which garage a self-joiner may open, not whose.)
private _sideStr = switch (side _unit) do {case west: {"cop"};
    case civilian: {"civ"};
    case independent: {"med"};
    default {"civ"};};
// Slot 3 is the ack flag, and it is required here for the reason DB_fnc_updatePartial's copy of this block
// spells out at length: an unacked entry is a grant whose side flip has not landed yet, so the player is
// still a civilian and their civilian garage is the right answer.
private _dutyRow = _unit call APS_fnc_dutyLookup;
if ((localNamespace getVariable ["AP_dutyEnabled", false]) && {_dutyRow param [3, false]}) then {
    switch (_dutyRow param [0, ""]) do {
        case "maxsec": { _sideStr = "cop"; };
        case "trauma": { _sideStr = "med"; };
    };
};

// `mods` (TEXT) holds the full 9-slot upgrade array as an SQF literal e.g. "[1,50,2,0,1,0,0,3,1]"
// (written by APS_fnc_updateVehicleMods). COALESCE(...,'[]') keeps legacy NULL rows compile-safe, QUOTE()
// makes the value a single-quoted (SQF-valid) string token in the call-compiled result.
private _q = format [
    "SELECT id,classname,pid,plate,color,COALESCE(mods,'[]') AS mods,alarm,COALESCE(customplate,'') AS customplate,fuel,damage,COALESCE(rig_kind,'') AS rig_kind, recall FROM %1 WHERE pid='%2' AND side='%3' AND type='%4' AND alive = true AND active = false AND listed = false ORDER BY classname, color",
    "vehicles", _uid, _sideStr, _type];
private _rows = [_q, 2, true] call DB_fnc_asyncQuery;
if (isNil "_rows" || {!(_rows isEqualType [])}) then { _rows = []; };

// Columns arrive pre-typed: id/plate/color/alarm/fuel/damage = Number, classname/pid/mods/customplate = String (QUOTE'd).
// SELECT order: 0 id,1 classname,2 pid,3 plate,4 color,5 mods,6 alarm,7 customplate,8 fuel,9 damage,10 rig_kind,11 recall.
private _out = _rows apply {
    private _modsArr = parseSimpleArray (_x select 5);   // "[...]" -> array, "[]"/malformed -> [] (data-only parse; never compiles the DB mods blob -- Lystic RCE class)
    if (!(_modsArr isEqualType []) || {count _modsArr < 9}) then {
        _modsArr = [_x select 6,0,0,0,0,0,0,0,0];    // legacy / un-modded row: fall back to the alarm column
    };
    // DB stores fuel/damage as 0-100 ints (fn_updateVehicle writes (fuel)*100 / (damage)*100); the client wants
    // vehWear = [damage, fuelPercent, armour] in 0-1. (Was hardcoded [0,0.5] -> garage always showed 0 dmg / 50% fuel.)
    private _fuel01 = ((_x select 8) max 0) / 100;
    private _dmg01  = ((_x select 9) max 0) / 100; [_x select 0,                    // 0  id
        "",                             // 1  (unused)
        _x select 1,                    // 2  classname
        "",                             // 3  (unused)
        _x select 2,                    // 4  pid (ownership check)
        "",                             // 5  (unused)
        "",                             // 6  (unused)
        _x select 3,                    // 7  plate
        _x select 4,                    // 8  color
        "",                             // 9  (unused / "")
        _modsArr,                       // 10 mods (full 9-slot upgrade array)
        [_dmg01, _fuel01, 0],           // 11 vehWear [damage, fuelPercent, armour] (0-1) from DB fuel(#8)/damage(#9)
        _x select 7,                    // 12 customPlate (owner 2026-06-16 #284: loaded from the customplate column)
        format ["%1", _x param [10, ""]], // 13 rig_kind ("" for ordinary vehicles)
        ((_x param [11, 0]) in [1, true])  // 14 recall: the starred SUMMON VEHICLE (PySQF hands booleans back as 0/1)
    ]};

// Wrap once: fn_vehicleGarageMenu does params[["_garageArr",[],[[]]]] -> reads _this#0 as the list.
[[_out], "AP_fnc_vehicleGarageMenu", _unit, false] spawn AP_fnc_MP;
