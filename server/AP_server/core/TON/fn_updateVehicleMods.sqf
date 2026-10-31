/*
    APS_fnc_updateVehicleMods  (LooneyBin: REWRITTEN -- persist vehicle mods to the player vehicles table)
    Client (fn_garageBuyMods) args: [uid, classname, plate, mods(9-array), color, customPlate].

    WAS a stub that fed DB_fnc_updateVehicle (a fuel/damage STATE saver that expects a vehicle OBJECT) with
    scrambled args, so nothing useful was written. On top of that the vehicles table had no mods column and
    fn_getVehicles hardcoded an empty mods array on retrieve -> every upgrade (nitrous, handling, +trunk,
    locks, doors, tracker) was silently discarded => "mods don't stick / nitro doesn't work".

    Now writes the full 9-slot mods array (slot 0 = alarm, mirrored to the legacy `alarm` column so anything
    still reading that column stays correct) + color, keyed on pid+plate. fn_getVehicles reads `mods` back.
    Requires: ALTER TABLE vehicles ADD COLUMN mods TEXT  (done live).
    customPlate has no column yet -> not persisted (cosmetic; deferred).
*/
if ("AP_server_training" call DB_fnc_flag) exitWith {};
params [["_uid", "", [""]], ["_class", "", [""]], ["_plate", -1, [0]], ["_mods", [], [[]]], ["_color", -1, [0]], ["_customPlate", "", [""]]
];
// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account write + SQLi): the client _uid was used raw in
// the vehicles UPDATE, so a scripter could rewrite ANY account's vehicle mods / inject SQL. Force the actor to
// the NON-SPOOFABLE caller's OWN account (fn_garageBuyMods always passes the local player's uid).
// Server-internal (_src==0) keeps the passed _uid. (_plate numeric; _customPlate already stripped below.)
private _src = remoteExecutedOwner;
if (_src != 0) then { _uid = getPlayerUID ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull]); };
if (_uid isEqualTo "" || _plate isEqualTo -1) exitWith {};
if (count _mods < 9) exitWith {};
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;

// owner 2026-06-23 SECURITY (security.md §2.3): _mods elements are NOT type-checked (params only verified it's
// an array), so a crafted _mods could smuggle a quote into str _mods / _alarm -> injection. Legit mods are
// pure ints, so coercing _alarm to a number and stripping any quote/backtick from _modsStr is lossless here.
private _alarm = round (parseNumber format ["%1", _mods select 0]);
private _modsStr = (str _mods) splitString "\'""`" joinString "";
private _colorSet = if (_color >= 0) then { format [", color='%1'", round _color] } else { "" };
// owner 2026-06-16 (#284): the custom LICENSE PLATE now persists (was "deferred -- no column"; the player paid
// but the plate never stuck). vehicles.customplate added live. _customPlate is already validated client-side
// (fn_checkPlate: <=9 chars, allowed set); strip any quote/backslash as a final SQL guard.
private _plateClean = (_customPlate splitString "'""\") joinString "";
private _q = format ["UPDATE %1 SET mods='%2', alarm='%3', customplate='%7'%4 WHERE pid='%5' AND plate='%6'",
    "vehicles", _modsStr, _alarm, _colorSet, _uid, round _plate, _plateClean];
[_q] call DB_fnc_asyncQuery;
diag_log format ["[LooneyBin][vehMods] saved plate=%1 uid=%2 mods=%3 customplate='%4'", _plate, _uid, _modsStr, _plateClean];
