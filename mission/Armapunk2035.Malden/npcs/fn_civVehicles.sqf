params["_obj_main", "_spawns", "_stance", "_type"];
// owner 2026-07-31: an EMPTY spawns list means "use the nearby convention markers" -- see
// npcs\fn_nearSpawns.sqf. Explicit marker lists keep working unchanged; this only fills a [].
if (_spawns isEqualType [] && {_spawns isEqualTo []}) then {
    private _want = createHashMapFromArray [
        ["heliGarage", ["air_spawn"]], ["airshop", ["air_spawn"]],
        ["boat", ["boat_spawn"]],
        ["boatGround", ["boat_spawn", "car_spawn", "air_spawn"]],
        ["groundAir", ["car_spawn", "air_spawn"]], ["airground", ["car_spawn", "air_spawn"]],
        ["aircraftCarrier", ["air_spawn"]]
    ] getOrDefault [_type, ["car_spawn", "air_spawn"]];
    _spawns = [getPosATL _obj_main, _want] call NPC_fnc_nearSpawns;
    if (_spawns isEqualTo []) then {
        diag_log format ["[NPC][%1] NO SPAWN PADS near %2 at %3 -- place %4 markers (car_spawn*/air_spawn*/boat_spawn*)",
            _type, typeOf _obj_main, getPosATL _obj_main, _want];
        systemChat format ["GARAGE HAS NO SPAWN PADS (%1) -- see RPT", _type];
    };
};

if (_obj_main isKindOf "CAManBase") then {};
private _buyPilotLoadout = {private _plb_player = player;
    private _action = ["Do you want to purchase a pilot outfit for $5,000? This will replace your current outfit entirely!", "Pilot Outfit", "Yes", "No"] call BIS_fnc_GUIMessage;
    if !(_action) exitWith {};
    if !([5000] call AP_fnc_debitCard) exitWith {};
    _plb_player setUnitLoadout[[], [], [], ["U_Tank_green_F", []], [], ["B_Parachute", []], "H_HelmetB_Light_tna_F", "G_RegulatorMask_F", ["Rangefinder", "", "", "", [],
        [], ""], ["ItemMap", "", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]];;};
switch (_type) do {case "carShop": {
            _obj_main addAction["Car Shop", AP_fnc_vehicleShopMenu, ["civ_car", civilian, _spawns, "civ", "LoonyBin Autos"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
        }; case "heliGarage": {_obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", '(AP_effSide isEqualTo civilian || AP_effSide isEqualTo west) && isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "airshop": {
                _obj_main addAction["Helicopter Shop", AP_fnc_vehicleShopMenu, ["civ_air", civilian, _spawns, "civ", "LoonyBin Air"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", '(AP_effSide isEqualTo civilian || AP_effSide isEqualTo west) && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Ground Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Gang Air Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "boat": {
                _obj_main addAction["Boat Shop", AP_fnc_vehicleShopMenu, ["civ_ship", civilian, _spawns, "civ", "LoonyBin Boat Marina"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Boat Shop", AP_fnc_vehicleShopMenu, ["med_ship", independent, _spawns, "med", "TT Boat Shop"], 1.5, false, false, "", 'AP_effSide isEqualTo independent && isNull objectParent player', 5];
                _obj_main addAction["Boat Garage", {["Ship", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Ship", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "boatGround": {
                _obj_main addAction["Boat Shop", AP_fnc_vehicleShopMenu, ["civ_ship", civilian, _spawns, "civ", "LoonyBin Boat Marina"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Boat Shop", AP_fnc_vehicleShopMenu, ["med_ship", independent, _spawns, "med", "TT Boat Shop"], 1.5, false, false, "", 'AP_effSide isEqualTo independent && isNull objectParent player', 5];
                _obj_main addAction["Boat Garage", {["Ship", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Boat Garage", {["Ship", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Gang Ground Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "gokart": {_obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu
                }, nil, 2, true, true, "", 'isNull objectParent player', 5];
                _obj_main addAction["<t color='#FFFF2F'>Gang Account</t>", {[] call AP_fnc_gangAtmMenu
                }, nil, 2, true, true, "", '(count AP_gang_data > 0)', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Go-Kart Shop", AP_fnc_vehicleShopMenu, ["civ_kart", civilian, _spawns, "civ", "LoonyBin Karts"], 1.5, false, false, "", '', 5];
                _obj_main addAction["Go-Kart Garage", {["Kart", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Kart Clothing Store", AP_fnc_clothingMenu, "kart", 1.5, false, false, "", '', 5];
                _obj_main addAction["Purchase Pilot Outfit", _buyPilotLoadout, "", 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "groundAir": {
                _obj_main addAction["Helicopter Shop", AP_fnc_vehicleShopMenu, ["civ_air", civilian, _spawns, "civ", "LoonyBin Air"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", '(AP_effSide isEqualTo civilian || AP_effSide isEqualTo west) && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Ground Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Gang Air Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "truckShop": {
                _obj_main addAction["Truck Shop", AP_fnc_vehicleShopMenu, ["civ_truck", civilian, _spawns, "civ", "LoonyBin Truck"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "groundGarage": {_obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "airground": {_obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", '(AP_effSide isEqualTo civilian || AP_effSide isEqualTo west) && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Ground Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Gang Air Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "mechanic": {
                _obj_main addAction["Car Shop", AP_fnc_vehicleShopMenu, ["civ_car", civilian, _spawns, "civ", "LoonyBin Autos"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Mechanic Shop", AP_fnc_virtualShopMenu, "gas", 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "RV": {
                _obj_main addAction["RV Shop", AP_fnc_vehicleShopMenu, ["civ_special", civilian, _spawns, "civ", "LoonyBin RV"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "vigi": {
                _obj_main addAction["Bounty Hunter Car Shop", AP_fnc_vehicleShopMenu, ["bh_car", civilian, _spawns, "civ", "LoonyBin Autos"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && license_civ_bounty', 5];
                _obj_main addAction["Helicopter Shop", AP_fnc_vehicleShopMenu, ["civ_air", civilian, _spawns, "civ", "LoonyBin Air"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && license_civ_bounty', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && license_civ_bounty', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Ground Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Gang Air Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "gov": {_obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };
        case "sofiaGas": {_obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["Gang Garage", {["Car", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
                _obj_main addAction["Gas Station", AP_fnc_weaponShopMenu, "gas", 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu
                }, nil, 2, true, true, "", 'isNull objectParent player', 5];
                _obj_main addAction["<t color='#FFFF2F'>Gang Account</t>", {[] call AP_fnc_gangAtmMenu
                }, nil, 2, true, true, "", '(count AP_gang_data > 0)', 5];
                _obj_main addAction["Gas Market", AP_fnc_virtualShopMenu, "gas", 1.5, false, false, "", '', 5];
                _obj_main addAction["Get Lottery Jackpot", {[0] call AP_fnc_lottoTix
                }, "", 1.5, false, false, "", 'isNull objectParent player', 5];
                _obj_main addAction["<t color='#00BFFF'>Buy Lottery Ticket ($2,000)</t>", {[1] spawn AP_fnc_lottoTix
                }, "", 0, false, false, "", 'isNull objectParent player', 5];};
        case "aircraftCarrier": {
                _obj_main addAction["Helicopter Shop", AP_fnc_vehicleShopMenu, ["civ_air", civilian, _spawns, "civ", "LoonyBin Air"], 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", '(AP_effSide isEqualTo civilian || AP_effSide isEqualTo west) && isNull objectParent player', 5];
                _obj_main addAction["Gang Air Garage", {["Air", _this select 3, true] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'isNull objectParent player && ((AP_gang_data param [0, -1]) isNotEqualTo -1) && ((AP_gang_data param [2, 5]) <= 3)', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && isNull objectParent player', 5];
            };};
