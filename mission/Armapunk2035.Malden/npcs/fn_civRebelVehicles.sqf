params["_obj_main", "_spawns", "_stance", "_type"];
// owner 2026-07-31: an EMPTY spawns list means "use the nearby convention markers" -- see
// npcs\fn_nearSpawns.sqf. Explicit marker lists keep working unchanged; this only fills a [].
if (_spawns isEqualType [] && {_spawns isEqualTo []}) then {
    private _want = createHashMapFromArray [
        ["air", ["air_spawn", "car_spawn"]]
    ] getOrDefault [_type, ["car_spawn", "air_spawn"]];
    _spawns = [getPosATL _obj_main, _want] call NPC_fnc_nearSpawns;
    if (_spawns isEqualTo []) then {
        diag_log format ["[NPC][%1] NO SPAWN PADS near %2 at %3 -- place markers named car_spawn.. air_spawn.. boat_spawn..", _type, typeOf _obj_main, getPosATL _obj_main];
        systemChat format ["GARAGE HAS NO SPAWN PADS (%1) -- see RPT", _type];
    };
};

private _type =
_type;
switch (_type) do {case "ground": {
            _obj_main addAction["Rebel Car Shop", AP_fnc_vehicleShopMenu, ['reb_car', civilian, _spawns, 'reb', "LoonyBin Rebel Vehicles"], 1.5, false, false, "", 'license_civ_rebel && isNull objectParent player', 5];
            _obj_main addAction["New Drachma Car Shop", AP_fnc_vehicleShopMenu, ['nd_car', civilian, _spawns, 'reb', "LoonyBin New Drachma Vehicles"], 1.5, false, false, "", 'license_civ_rebel && isNull objectParent player', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
        }; case "air": {
                _obj_main addAction["Rebel Car Shop", AP_fnc_vehicleShopMenu, ['reb_car', civilian, _spawns, 'reb', "LoonyBin Rebel Vehicles"], 1.5, false, false, "", 'license_civ_rebel && isNull objectParent player', 5];
                _obj_main addAction["New Drachma Car Shop", AP_fnc_vehicleShopMenu, ['nd_car', civilian, _spawns, 'reb', "LoonyBin New Drachma Vehicles"], 1.5, false, false, "", 'license_civ_rebel && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Ground Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Gang Air Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };};