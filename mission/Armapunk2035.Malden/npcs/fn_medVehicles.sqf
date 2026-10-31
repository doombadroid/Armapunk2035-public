params["_obj_main", "_spawns", "_stance", ["_type", "", [""]]];
// owner 2026-07-31: an EMPTY spawns list means "use the nearby convention markers" -- see
// npcs\fn_nearSpawns.sqf. Explicit marker lists keep working unchanged; this only fills a [].
if (_spawns isEqualType [] && {_spawns isEqualTo []}) then {
    private _want = createHashMapFromArray [
        ["air", ["air_spawn"]], ["boat", ["boat_spawn"]],
        ["boatGround", ["boat_spawn", "car_spawn", "air_spawn"]]
    ] getOrDefault [_type, ["car_spawn", "air_spawn"]];
    _spawns = [getPosATL _obj_main, _want] call NPC_fnc_nearSpawns;
    if (_spawns isEqualTo []) then {
        diag_log format ["[NPC][%1] NO SPAWN PADS near %2 at %3 -- place markers named car_spawn.. air_spawn.. boat_spawn..", _type, typeOf _obj_main, getPosATL _obj_main];
        systemChat format ["GARAGE HAS NO SPAWN PADS (%1) -- see RPT", _type];
    };
};

if (_obj_main isKindOf "CAManBase") then {};
switch (_type) do {case "ground": {
            _obj_main addAction["TT Vehicle Shop", AP_fnc_vehicleShopMenu, ["med_car", independent, _spawns, "med", "TT Motorpool"], 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
            _obj_main addAction["Firefighter Garage", AP_fnc_vehicleShopMenu, ["firefighter_car", independent, _spawns, "med", "Firefighter Garage"], 1.5, false, false, "", 'AP_effSide isEqualTo independent && AP_isActiveFirefighter', 5];
            _obj_main addAction["TT Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo independent', 5];
        }; case "air": {
                _obj_main addAction["TT Air Shop", AP_fnc_vehicleShopMenu, ["med_air", independent, _spawns, "med", "TT Helicopters"], 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["TT Air Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo independent', 5];
            };
        case "boat": {
                _obj_main addAction["TT Boat Shop", AP_fnc_vehicleShopMenu, ["med_ship", independent, _spawns, "med", "TT Boat Shop"], 1.5, false, false, "", 'AP_effSide isEqualTo independent && isNull objectParent player', 5];
                _obj_main addAction["TT Boat Garage", {["Ship", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo independent && isNull objectParent player', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo independent && isNull objectParent player', 5];
            };
        case "boatGround": {
                _obj_main addAction["TT Boat Shop", AP_fnc_vehicleShopMenu, ["med_ship", independent, _spawns, "med", "TT Boat Shop"], 1.5, false, false, "", 'AP_effSide isEqualTo independent && isNull objectParent player', 5];
                _obj_main addAction["TT Boat Garage", {["Ship", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo independent && isNull objectParent player', 5];
                _obj_main addAction["TT Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo independent && isNull objectParent player', 5];
            };};
