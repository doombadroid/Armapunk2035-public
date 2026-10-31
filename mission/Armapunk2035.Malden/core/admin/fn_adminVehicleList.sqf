#include "..\..\macro.h"
/*
    AP_fnc_adminVehicleList (LooneyBin, ui branch) -- fills the staff menu's vehicle list (idc 12943).
    No search text: the curated sections (water/ground/air/armed/special + the owner-only armor) FOLLOWED
    BY the full game catalogue (every scope-2 Car/Air/Ship/Tank/StaticWeapon) so all vehicles are
    browsable without typing. The search box (idc 12947) filters that same catalogue by name/classname.
    Row data stays str [classname, weaponsArray] so fn_adminSpawnVehicle / APS_fnc_createAdminVeh are
    untouched. Catalogue built once (AP_adminVehCache).
*/
if ((call AP_adminLevel) <= 1) exitWith {};
disableSerialization;
private _display = findDisplay 12900;
if (isNull _display) exitWith {};
private _vehicleList = _display displayCtrl 12943;
private _adminlevel = call AP_adminLevel;

// ── curated sections (armed recipes + gating preserved from the old inline list) ──
private _waterVeh = [["Boat | Rescue Boat", "B_Lifeboat"], ["Boat | Motorboat", "C_Boat_Civil_01_F"], ["Boat | SDV", "B_SDV_01_F"],
    ["Boat | RHIB", "C_Boat_Transport_02_F"], ["Boat | Jetski", "C_Scooter_Transport_01_F"],
    ["Boat | Assault Boat", "B_Boat_Transport_01_F"]];
private _landVeh = [["Kart | Random", "C_Kart_01_F"], ["Auto | Quadbike", "B_Quadbike_01_F"], ["Auto | Hatchback", "C_Hatchback_01_F"],
    ["Auto | Hatchback Sport", "C_Hatchback_01_sport_F"], ["Auto | SUV", "C_SUV_01_F"], ["Auto | Qilin", "O_T_LSV_02_unarmed_F"],
    ["Auto | Prowler", "B_T_LSV_01_unarmed_F"], ["Auto | Offroad", "B_G_Offroad_01_F"], ["Auto | Offroad (Comms)", "C_Offroad_01_comms_F"],
    ["Auto | 4WD Offroad", "C_Offroad_02_unarmed_F"], ["Auto | Box Truck", "C_Van_01_box_F"], ["Auto | Fuel Truck", "C_Van_01_fuel_F"],
    ["Auto | Van Cargo", "B_G_Van_02_vehicle_F"], ["Auto | Van Transport", "B_G_Van_02_transport_F"], ["Auto | Tractor", "C_Tractor_01_F"],
    ["Truck | HEMTT Transport", "B_Truck_01_transport_F"], ["Truck | HEMTT Fuel", "B_Truck_01_fuel_F"],
    ["Truck | HEMTT Box", "B_Truck_01_box_F"], ["Truck | Tempest Transport", "O_Truck_03_transport_F"],
    ["Truck | Tempest Covered", "O_Truck_03_covered_F"], ["Truck | Tempest Fuel", "O_Truck_03_fuel_F"],
    ["Truck | Tempest Device", "O_Truck_03_device_F"], ["Truck | Zamak Transport", "O_Truck_02_transport_F"],
    ["Truck | Zamak Covered", "O_Truck_02_covered_F"], ["Truck | Zamak Fuel", "I_Truck_02_fuel_F"], ["Armored | Hunter", "B_MRAP_01_F"],
    ["Armored | Ifrit", "O_MRAP_02_F"], ["Armored | Strider", "I_MRAP_03_F"]];
private _airVeh = [["Heli | MH-9 Hummingbird", "B_Heli_Light_01_F"], ["Heli | M-900 Civilian", "C_Heli_Light_01_civil_F"],
    ["Heli | Hellcat", "I_Heli_light_03_unarmed_F"], ["Heli | Orca", "O_Heli_Light_02_unarmed_F"],
    ["Heli | Mohawk", "I_Heli_Transport_02_F"], ["Heli | Taru Sling", "O_Heli_Transport_04_F"],
    ["Heli | Taru Open Bench", "O_Heli_Transport_04_bench_F"], ["Heli | Taru Enclosed Bench", "O_Heli_Transport_04_covered_F"],
    ["Heli | Huron", "B_Heli_Transport_03_unarmed_F"], ["Plane | Caesar BTT", "C_Plane_Civil_01_F"],
    ["Plane | A-143 Buzzard", "I_Plane_Fighter_03_CAS_F"], ["Plane | A-149 Gryphon", "I_Plane_Fighter_04_F"],
    ["Plane | Blackfish infantry", "B_T_VTOL_01_infantry_F"], ["Plane | Blackfish vehicle", "B_T_VTOL_01_vehicle_F"]];
private _armedVeh = [["Boat | Minigun Speedboat", "B_Boat_Armed_01_minigun_F"], ["Auto | Offroad (Armed)", "B_G_Offroad_01_armed_F"],
    ["Auto | Jeep (Armed)", "I_C_Offroad_02_LMG_F"], ["Auto | Ifrit (Armed)", "O_MRAP_02_hmg_F"],
    ["Other | Mortar (Armed)", "I_E_Mortar_01_F"], ["Heli | Huron (Armed)", "B_Heli_Transport_03_F"],
    ["Heli | Ghosthawk (Armed)", "B_Heli_Transport_01_F"], ["Heli | Hellcat (Armed)", "I_Heli_light_03_F"],
    ["Heli | Orca (Armed)", "O_Heli_Light_02_F"], ["Heli | AH-9 Pawnee (Armed)", "B_Heli_Light_01_armed_F"],
    ["Plane | Wipeout (Armed)", "B_Plane_CAS_01_dynamicLoadout_F"], ["Plane | Blackfish (Armed)", "B_T_VTOL_01_armed_F"],
    ["Plane | Y-32 Xi'an (Armed) infantry", "O_T_VTOL_02_infantry_F"], ["Plane | Y-32 Xi'an (Armed) vehicle", "O_T_VTOL_02_vehicle_F"]];
private _specialVeh = [["Plane | Caesar BTT (Armed)", "C_Plane_Civil_01_F", ["M134_minigun", "HMG_static"]],
    ["Plane | A-149 Gryphon (Armed)", "I_Plane_Fighter_04_F", ["weapon_Fighter_Gun20mm_AA", "Laserdesignator_pilotCamera", "weapon_BIM9xLauncher", "weapon_AGM_65Launcher"]],
    ["Plane | A-143 Buzzard (Armed)", "I_Plane_Fighter_03_CAS_F", ["Twin_Cannon_20mm", "missiles_SCALPEL", "missiles_ASRAAM", "GBU12BombLauncher_Plane_Fighter_03_F"]],
    ["Kart | Kart (Armed)", "C_Kart_01_F", ["M134_minigun"]], ["Auto | Quadbike (Armed)", "B_Quadbike_01_F", ["M134_minigun"]],
    ["Auto | Hatchback Sport (Armed)", "C_Hatchback_01_sport_F", ["M134_minigun"]]];
if (_adminlevel >= 5) then {_armedVeh append [["ZSU-39 Tigris", "O_APC_Tracked_02_AA_F"], ["T-100 Varsuk", "O_MBT_02_cannon_F"]];};

// ── full-game catalogue, built once: every scope-2 Car/Air/Ship/Tank/StaticWeapon ──
if (isNil "AP_adminVehCache") then {AP_adminVehCache = []; {private _dn = getText (_x >> "displayName");
        if (_dn != "") then {private _cls = configName _x;
            if (_cls isKindOf "Car" || {_cls isKindOf "Air"} || {_cls isKindOf "Ship"} || {_cls isKindOf "Tank"} || {_cls isKindOf "StaticWeapon"}) then {
                AP_adminVehCache pushBack [_dn, _cls];};};
    } forEach ("getNumber (_x >> 'scope') == 2" configClasses (configFile >> "CfgVehicles"));
    AP_adminVehCache sort true;};

// 2026-08-20: was 12944 -- that idc was DUPLICATED by the Actions-tab query readout (queryTxt1), which is
// defined first, so displayCtrl handed back the structured text and this read the player dossier as the
// filter (vehicle list went empty after any player query). vehSearch is 12947 now.
private _filter = toLower (ctrlText (_display displayCtrl 12947));
lbClear _vehicleList;

if (_filter isEqualTo "") then {{_x params ["_vehicles", "_text"];
        private _h = _vehicleList lbAdd _text;
        _vehicleList lbSetData [_h, str ["", []]]; {private _index = _vehicleList lbAdd (_x select 0);
            _vehicleList lbSetData [_index, str [_x select 1, _x param [2, []]]];} forEach _vehicles;
        private _b = _vehicleList lbAdd "";
        _vehicleList lbSetData [_b, str ["", []]];
    } forEach [[_waterVeh, "- Water Vehicles -"], [_landVeh, "- Ground Vehicles -"], [_airVeh, "- Air Vehicles -"], [_armedVeh, "- Armed Vehicles -"], [_specialVeh, "- Special Vehicles -"]];
    // full game catalogue, browsable inline (no typing) -- the search box still filters this same set
    private _allHdr = _vehicleList lbAdd format ["- ALL VEHICLES (%1) -", count AP_adminVehCache];
    _vehicleList lbSetData [_allHdr, str ["", []]]; {_x params ["_dn", "_cls"];
        private _index = _vehicleList lbAdd format ["%1  [%2]", _dn, _cls];
        _vehicleList lbSetData [_index, str [_cls, []]];} forEach AP_adminVehCache;} else {
    // curated matches keep their armed recipes
    {_x params ["_vehicles", ""]; {if ((toLower (_x select 0)) find _filter >= 0) then {private _index = _vehicleList lbAdd (_x select 0);
                _vehicleList lbSetData [_index, str [_x select 1, _x param [2, []]]];};} forEach _vehicles;
    } forEach [[_waterVeh, ""], [_landVeh, ""], [_airVeh, ""], [_armedVeh, ""], [_specialVeh, ""]];
    // then the whole game
    {_x params ["_dn", "_cls"];
        if (((toLower _dn) find _filter >= 0) || {(toLower _cls) find _filter >= 0}) then {
            private _index = _vehicleList lbAdd format ["%1  [%2]", _dn, _cls];
            _vehicleList lbSetData [_index, str [_cls, []]];};} forEach AP_adminVehCache;};
