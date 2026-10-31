/*
    APS_fnc_createAdminVeh  (LooneyBin: admin-menu vehicle spawn / clear)
    2020 client args (fn_adminSpawnVehicle):
      case 1 (spawn): [1, _player, _classname, _position, _weapons]
      case 2 (clear): [2, _player]   -> delete every admin-spawned vehicle
    Was a passthrough to the 2017 APS_fnc_spawnVehicle (params [vid,pid,sp,unit,price,talents,insured,
    scd]) -> arg mismatch -> nothing spawned. Now a real spawn: validate the class, create it a few
    metres from the admin, empty + unlock it, tag it AP_adminVehicle so case 2 can clean it up.
*/
params [["_mode", 0, [0]], ["_player", objNull, [objNull]], ["_class", "", [""]], ["_pos", [0,0,0], [[]]], ["_weapons", [], [[]]]];
if (isNull _player) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.3 — no admin check): this had NO server-side authz, so any
// client could remoteExec it to spawn ANY CfgVehicles class (incl. armed gunships/tanks) + add arbitrary
// turret weapons. Re-query the NON-SPOOFABLE caller's adminlevel from the DB and require >= 3 (the
// client gate is `(call AP_adminLevel) <= 2` in fn_adminSpawnVehicle). The passed _player is
// attacker-controlled; remoteExecutedOwner is the engine-set real sender (0 = server-internal = trusted).
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 3) exitWith { ["-SEC-", _caller, format ["BLOCKED createAdminVeh by %1", _callerUID]] call APS_fnc_logIt; };

switch (_mode) do {case 1: {if (_class isEqualTo "" || {!isClass (configFile >> "CfgVehicles" >> _class)}) exitWith {};
        private _base = if (count _pos >= 2) then { _pos } else { getPosATL _player };
        private _spawnPos = [(_base select 0) + 5, (_base select 1) + 5, 0];
        private _veh = createVehicle [_class, _spawnPos, [], 0, "CAN_COLLIDE"];
        if (isNull _veh) exitWith {};
        _veh setPosATL _spawnPos;
        _veh setDir (getDir _player);
        clearWeaponCargoGlobal _veh;
        clearMagazineCargoGlobal _veh;
        clearItemCargoGlobal _veh;
        clearBackpackCargoGlobal _veh;
        _veh setFuel 1;
        _veh setVehicleLock "UNLOCKED";
        _veh setVariable ["AP_adminVehicle", true, true];
        _veh setVariable ["AP_owner", _player, true];
        // optional weapons selected in the admin menu (usually [] for normal vehicles)
        { _veh addWeaponTurret [_x, [0]]; } forEach _weapons;};
    case 2: {{ if (_x getVariable ["AP_adminVehicle", false]) then { deleteVehicle _x; }; } forEach vehicles;};};
