params["_obj_main", "_spawns", "_stance", "_location"];
// owner 2026-07-31: empty spawns -> nearby convention markers (npcs\fn_nearSpawns.sqf).
if (_spawns isEqualType [] && {_spawns isEqualTo []}) then {
    _spawns = [getPosATL _obj_main, ["car_spawn", "air_spawn"]] call NPC_fnc_nearSpawns;
};

if (_obj_main isKindOf "CAManBase") then {};
switch (_location) do {case "Kavala": {
            _obj_main addAction["Chop Shop", AP_fnc_chopShopMenu, "chop_shop_1", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
            _obj_main addAction["RV Shop", AP_fnc_vehicleShopMenu, ["civ_special", civilian, _spawns, "civ", "LoonyBin RV"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
        }; case "Athira": {
                _obj_main addAction["Chop Shop", AP_fnc_chopShopMenu, "chop_shop_2", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["RV Shop", AP_fnc_vehicleShopMenu, ["civ_special", civilian, _spawns, "civ", "LoonyBin RV"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };};