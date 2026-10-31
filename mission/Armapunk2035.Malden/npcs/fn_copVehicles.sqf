params["_obj_main", "_spawns", "_stance", ["_type", "", [""]]];
// owner 2026-07-31: an EMPTY spawns list means "use the nearby convention markers" -- see
// npcs\fn_nearSpawns.sqf. Explicit marker lists keep working unchanged; this only fills a [].
if (_spawns isEqualType [] && {_spawns isEqualTo []}) then {
    private _want = createHashMapFromArray [
        ["air", ["air_spawn"]], ["sea", ["boat_spawn"]],
        ["boatGround", ["boat_spawn", "car_spawn", "air_spawn"]],
        ["airground", ["car_spawn", "air_spawn"]]
    ] getOrDefault [_type, ["car_spawn", "air_spawn"]];
    _spawns = [getPosATL _obj_main, _want] call NPC_fnc_nearSpawns;
    if (_spawns isEqualTo []) then {
        diag_log format ["[NPC][%1] NO SPAWN PADS near %2 at %3 -- place markers named car_spawn.. air_spawn.. boat_spawn..", _type, typeOf _obj_main, getPosATL _obj_main];
        systemChat format ["GARAGE HAS NO SPAWN PADS (%1) -- see RPT", _type];
    };
};

// owner 2026-06-15: de-brand the cop VEHICLE vendor (ground/air/sea) -- it wore the bare stock
// B_Survivor_F/B_Pilot_F uniform (the stock upstream cop look). That day's fix was a sgt_grumpy MaxSec
// retexture; SUPERSEDED the next day (below) and the skin itself was deleted 2026-08-13, so no texture
// is applied here.
if (_obj_main isKindOf "CAManBase") then {
    // owner 2026-06-16: strip the uniform instead (naked) -- U_Rangemaster IS the stock cop look, so the
    // retexture added nothing over it. The de-brand is the strip, nothing else.
    // owner 2026-07-10: SKIP when the map data dressed this NPC with a custom
    // loadout (Eden round-trip, fn_createVehicleLocal tags AP_hasLoadout) -- stripping undid the outfit.
    if !(_obj_main getVariable ["AP_hasLoadout", false]) then { removeUniform _obj_main; };};
private _type =
_type;
switch (_type) do {case "ground": {
            _obj_main addAction["Report for MaxTac Duty", AP_fnc_maxtacEnroll, nil, 2, false, true, "", 'AP_effSide isEqualTo west && SRV_MAXTACrequested && AP_isMaxTac && !AP_activeMAXTAC', 5];
            _obj_main addAction["<t color='#1E90FF'>MaxTac Garage</t>", AP_fnc_vehicleShopMenu, ["maxtac_car", west, _spawns, "cop", "MaxTac Garage"], 1.5, false, false, "", 'AP_effSide isEqualTo west && AP_isMaxTac', 5];
            _obj_main addAction["Car Shop", AP_fnc_vehicleShopMenu, ["cop_car", west, _spawns, "cop", "LoonyBin Car"], 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo west', 5];
            if !("cop_g_mobile" in _spawns) then {_obj_main addAction["Buy mobile HQ", {
                    ["buyMobileHQ", _this select 3] spawn AP_fnc_clientMobileHQ;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west && (call AP_copLevel >= 4)', 5];};}; case "srt": {
                _obj_main addAction["SRT Vehicle Shop", AP_fnc_vehicleShopMenu, ["srt_car", west, _spawns, "cop", "SRT Garage"], 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["SRT Ground Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["SRT Air Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo west', 5];
            };
        case "airground": {
                _obj_main addAction["Report for MaxTac Duty", AP_fnc_maxtacEnroll, nil, 2, false, true, "", 'AP_effSide isEqualTo west && SRV_MAXTACrequested && AP_isMaxTac && !AP_activeMAXTAC', 5];
                _obj_main addAction["<t color='#1E90FF'>MaxTac Garage</t>", AP_fnc_vehicleShopMenu, ["maxtac_car", west, _spawns, "cop", "MaxTac Garage"], 1.5, false, false, "", 'AP_effSide isEqualTo west && AP_isMaxTac', 5];
                _obj_main addAction["Car Shop", AP_fnc_vehicleShopMenu, ["cop_car", west, _spawns, "cop", "LoonyBin Car"], 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Helicopter Shop", AP_fnc_vehicleShopMenu, ["cop_air", west, _spawns, "cop", "LoonyBin Helicopter"], 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo west', 5];
            };
        case "boatGround": {
                _obj_main addAction["Report for MaxTac Duty", AP_fnc_maxtacEnroll, nil, 2, false, true, "", 'AP_effSide isEqualTo west && SRV_MAXTACrequested && AP_isMaxTac', 5];
                _obj_main addAction["Boat Shop", AP_fnc_vehicleShopMenu, ["cop_ship", west, _spawns, "cop", "Cop Boat Shop"], 1.5, false, false, "", 'AP_effSide isEqualTo west && license_cop_cg', 5];
                _obj_main addAction["Boat Garage", {["Ship", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west && license_cop_cg', 5];
                _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Cop Boat License ($800)", AP_fnc_buyLicense, "cg", 1.5, false, false, "", '!license_cop_cg && AP_effSide isEqualTo west', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo west', 5];
            };
        case "air": {
                _obj_main addAction["Report for MaxTac Duty", AP_fnc_maxtacEnroll, nil, 2, false, true, "", 'AP_effSide isEqualTo west && SRV_MAXTACrequested && AP_isMaxTac && !AP_activeMAXTAC', 5];
                _obj_main addAction["Helicopter Shop", AP_fnc_vehicleShopMenu, ["cop_air", west, _spawns, "cop", "LoonyBin Helicopter"], 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo west', 5];
            };
        case "sea": {
                _obj_main addAction["Report for MaxTac Duty", AP_fnc_maxtacEnroll, nil, 2, false, true, "", 'AP_effSide isEqualTo west && SRV_MAXTACrequested && AP_isMaxTac && !AP_activeMAXTAC', 5];
                _obj_main addAction["Boat Shop", AP_fnc_vehicleShopMenu, ["cop_ship", west, _spawns, "cop", "Cop Boat Shop"], 1.5, false, false, "", 'AP_effSide isEqualTo west && license_cop_cg', 5];
                _obj_main addAction["Boat Garage", {["Ship", _this select 3] call AP_fnc_handleVehicles;
                }, _spawns, 1.5, false, false, "", 'AP_effSide isEqualTo west && license_cop_cg', 5];
                _obj_main addAction["Cop Boat License ($800)", AP_fnc_buyLicense, "cg", 1.5, false, false, "", '!license_cop_cg && AP_effSide isEqualTo west', 5];
                _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store && AP_effSide isEqualTo west', 5];
            };};