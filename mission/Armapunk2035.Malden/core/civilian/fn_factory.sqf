params[["_factoryType", "", [""]]];
if !(isNull(findDisplay 1800)) exitWith {};
["AP_factory_menu"] call AP_fnc_createDialog;
disableSerialization;
waitUntil {!isNull(findDisplay 1800)};
private _display = findDisplay 1800;
private _recipeList = _display displayCtrl 1850;
private _recipes =
// ONE station. The Factory minted 161 classes across vehicles / blackmarket / weapons until
// 2026-08-22; the owner cut it to vehicles only and the other 136 moved to the Fabricator, which
// is where everything that is not a vehicle is made now. The 8 vehicles that used to sit under the
// blackmarket station fold in here -- they are vehicles, and there is only one place to build one.
    [
            "B_G_Offroad_01_F",
            "B_G_Offroad_01_armed_F",
            "B_Heli_Light_01_F",
            "B_MRAP_01_F",
            "B_Truck_01_box_F",
            "B_Truck_01_transport_F",
            "C_Boat_Civil_01_F",
            "C_Boat_Civil_01_rescue_F",
            "C_Hatchback_01_F",
            "C_Hatchback_01_sport_F",
            "C_Heli_Light_01_civil_F",
            "C_Offroad_01_F",
            "C_SUV_01_F",
            "C_Van_01_box_F",
            "C_Van_01_transport_F",
            "I_C_Offroad_02_LMG_F",
            "I_Heli_Transport_02_F",
            "I_Heli_light_03_unarmed_F",
            "I_Truck_02_covered_F",
            "I_Truck_02_transport_F",
            "O_Heli_Light_02_unarmed_F",
            "O_Heli_Transport_04_F",
            "O_Heli_Transport_04_bench_F",
            "O_LSV_02_armed_F",
            "O_MRAP_02_F",
            "rig_extractor",
            "rig_processor"
    ];
if (_recipes isEqualTo[]) exitWith {};
lbClear _recipeList;
(arms_flag getVariable["AP_capData", [0, "Neutral", 0.5]]) params["_flagGangID", "_flagGangName", "_progress"];
AP_garageCount = -1; [[getPlayerUID player, AP_effSide, player], "APS_fnc_garageCount", 2] spawn AP_fnc_MP;
private _armsOwner = (AP_gang_data param[0, -5]) isEqualTo _flagGangID;
private _armsVeh = ["B_G_Offroad_01_armed_F", "O_LSV_02_armed_F", "LMG_03_F", "RPG7_F", "V_HarnessOGL_brn"]; {private _show =
    if (_x in _armsVeh) then {_armsOwner} else {true};
    if (_show) then {(switch (true) do {case (isClass(configFile >> "CfgWeapons" >> _x)): {
                    ["CfgWeapons", getText(configFile >> "CfgWeapons" >> _x >> "displayName"), getText(configFile >> "CfgWeapons" >> _x >> "picture")]
                };
            case (isClass(configFile >> "CfgVehicles" >> _x)): {
                    ["CfgVehicles", getText(configFile >> "CfgVehicles" >> _x >> "displayName"), getText(configFile >> "CfgVehicles" >> _x >> "picture")]
                };
            case (isClass(configFile >> "CfgMagazines" >> _x)): {
                    ["CfgMagazines", getText(configFile >> "CfgMagazines" >> _x >> "displayName"), getText(configFile >> "CfgMagazines" >> _x >> "picture")]
                };
            default {[configNull, "", ""]};}) params["_cfgType", "_name", "_icon"];
        if (_x isEqualTo "V_HarnessOGL_brn") then {_name = "Suicide Vest";};
        // rig sentinels are not config classes -- name and icon by hand
        if (_x isEqualTo "rig_extractor") then {_name = "Resource Extractor (HEMTT)";
            _icon = getText (configFile >> "CfgVehicles" >> "B_Truck_01_flatbed_F" >> "picture");};
        if (_x isEqualTo "rig_processor") then {_name = "Resource Processor (HEMTT)";
            _icon = getText (configFile >> "CfgVehicles" >> "B_Truck_01_flatbed_F" >> "picture");};
        private _index = _recipeList lbAdd _name;
        _recipeList lbSetData[_index, _x];
        _recipeList lbSetPicture[_index, _icon];};}
forEach _recipes;
private _name = "Vehicle Production Factory";
( _display displayCtrl 1835) ctrlSetText _name;
lbSetCurSel[1850, 0];