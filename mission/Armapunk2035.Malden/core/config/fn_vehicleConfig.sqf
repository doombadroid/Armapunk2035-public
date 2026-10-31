#include "..\..\macro.h"
params[["_mode", "", ["", 0]], ["_shop", "", [""]], ["_className", "", [""]], ["_vehicle", objNull, [objNull]]];
if (_mode isEqualTo "") exitWith {};
if (_mode isEqualTo "getSellPrice" && {isNull _vehicle}) exitWith {};
// LooneyBin 2026-06-12: server-safe (APS_fnc_srvSellVehicle calls "getVehicleRowParsed" server-side for an
// authoritative sell-back; the dedicated server / HC has no player, so AP_copLevel/AP_medicLevel would
// throw). These two are unused by the getVehicleRowParsed/getEconList price paths anyway.
private _copLevel = if (hasInterface) then {call AP_copLevel} else {0};
private _medicLevel = if (hasInterface) then {call AP_medicLevel} else {0};
// LooneyBin TT patch: Volunteers (level 99) get same vehicle access as Privates (level 1)
if (_medicLevel isEqualTo 99) then { _medicLevel = 1; };
private _donorLevel = 10;
// Audit 2026-09-26 (mints): the cache lives in localNamespace. The server prices sell-backs and chops from these
// rows, including which vehicles settle in New Drachma (idx 3), and a client publicVariable overwrites a
// missionNamespace global on the server too. The network cannot write localNamespace. The literal is built into a
// private (audit r2items): a global here was a publicVariable target between the build and the seed below, and a
// scheduled first call could be suspended in that gap. scratchpad/seed_nd_prices.py parses `_vt = [`.
if (isNil {localNamespace getVariable "AP_vehConfigTable"}) then { private _vt = [
    // owner 2026-06-20 (Payton): MaxTac garage consolidated to ONE of each at set prices. Strider $15k, Hunter $15k,
    // Prowler $6k, Van $6k. The duplicate (pricier) copies elsewhere in this config had their maxtac_car flag stripped
    // so the MaxTac shop shows this clean dedicated block only. MaxTac pulls are unlimited (fn_vehicleShopBuy).
    ["O_MRAP_02_F", "", [west], ["srt_car", "maxtac_car"], 0, 0, 0, 15000, 12000, 2000, 900, [], [50, 50, 50]], ["B_MRAP_01_F", "", [west],
        ["srt_car", "maxtac_car"], 0, 0, 0, 15000, 12000, 2000, 900, [], [50, 50, 50]], ["I_MRAP_03_F", "", [west],
        ["srt_car", "maxtac_car"], 0, 0, 0, 15000, 12000, 2000, 900, [], [50, 50, 50]], ["B_T_LSV_01_unarmed_F", "", [west],
        ["srt_car", "maxtac_car"], 0, 0, 0, 6000, 3000, 2000, 900, [], [50, 50, 50]], ["O_T_LSV_02_unarmed_F", "", [west],
        ["srt_car", "maxtac_car"], 0, 0, 0, 5000, 3000, 2000, 900, [], [50, 50, 50]], ["O_Heli_Light_02_unarmed_F", "", [west],
        ["srt_car", "maxtac_car"], 0, 0, 0, 20000, 15000, 2000, 900, [], [50, 50, 50]], ["C_Van_02_transport_F", "", [west],
        ["srt_car", "maxtac_car"], 0, 0, 0, 6000, 3000, 2000, 900, [], [60, 60, 60]], ["B_T_VTOL_01_infantry_F", "", [west],
        ["cop_air"], 6, 0, 0, 204600, 102300, 2000, 3000, [], [50, 50, 50]], ["C_Boat_Transport_02_F", "", [west],
        ["cop_ship"], 3, 0, 0, 1100, 600, 1000, 500, [], [50, 50, 50]], ["C_Kart_01_Blu_F", "", [civilian],
        ["civ_kart"], 0, 0, 0, 200, 100, 0, 10, [], [0, 0, 0]], ["C_Kart_01_Fuel_F", "", [civilian],
        ["civ_kart"], 0, 0, 0, 200, 100, 0, 10, [], [0, 0, 0]], ["C_Kart_01_Red_F", "", [civilian],
        ["civ_kart"], 0, 0, 0, 200, 100, 0, 10, [], [0, 0, 0]], ["C_Kart_01_Vrana_F", "", [civilian],
        ["civ_kart"], 0, 0, 0, 200, 100, 0, 10, [], [0, 0, 0]], ["B_Quadbike_01_F", "", [civilian],
        ["civ_car", "reb_car"], 0, 0, 0, 400, 200, 0, 50, [], [10, 10, 10]], ["I_Quadbike_01_F", "", [west],
        ["cop_car"], 1, 0, 0, 200, 100, 0, 0, [], [10, 10, 10]], ["C_Quadbike_01_F", "", [independent],
        ["med_car"], 0, 1, 0, 400, 200, 0, 0, [], [10, 10, 10]], ["C_Hatchback_01_F", "", [civilian, west],
        ["civ_car", "cop_car", "reb_car"], 0, 0, 0, 2100, 1000, 150, 100, [], [34, 34, 34], 24],
    ["C_Offroad_01_F", "", [civilian, west, independent], ["civ_car", "cop_car", "med_car"], 1, 1, 0, 2300, 1200,
        [250, 250, 250], [150, 150, 0], [], [42, 42, 42], 25], ["C_Offroad_01_repair_F", "", [independent],
        ["med_car"], 0, 2, 0, 2000, 1000, 250, 100, [], [42, 42, 42]], ["C_Offroad_01_comms_F", "", [west, independent],
        ["cop_car", "med_car"], 0, 3, 0, 2300, 1200, [250, 250, 250], [300, 300, 300], [], [42, 42, 42]],
    ["C_Offroad_01_covered_F", "", [civilian], ["civ_car"], 3, 3, 0, 2300, 1200, 250, 300, [], [42, 42, 42]],
    ["B_G_Offroad_01_F", "", [civilian, west], ["reb_car", "bh_car", "cop_car"], 0, 0, 0, 2300, 1200,
        [350, 350, 350], [150, 150, 150], [], [42, 42, 42], 26], ["B_G_Offroad_01_armed_F", "", [civilian],
        ["reb_car", "nd_car"], 0, 0, 0, 45000, 22500, 3000, 0, [19], [42, 42, 42]], ["C_SUV_01_F", "", [civilian, west, independent],
        ["civ_car", "med_car", "bh_car", "cop_car"], 2, 2, 0, 2500, 1200, [200, 200, 200], [125, 125, 125],
        [100, 112], [34, 34, 34], 26], ["C_Van_02_medevac_F", "", [independent], ["med_car"], 0, 2, 0, 4500, 2200, 350, 0, [112],
        [50, 50, 50]],
    ["C_Hatchback_01_sport_F", "", [civilian, west, independent], ["civ_car", "med_car", "bh_car", "cop_car", "reb_car"], 2, 1, 0, 2600, 1300, [235, 235, 235], [100, 100, 100], [100], [34, 34, 34], 26],
    ["C_Van_01_transport_F", "", [civilian, west],
        ["civ_car", "bh_car", "cop_car", "civ_truck"], 1, 0, 0, 4400, 2200, 750, 250, [],   
        [50, 50, 50], 26], ["O_MRAP_02_F", "", [civilian, west], ["reb_car", "nd_car", "cop_car"], 5, 0, 0, 45000, 22500, [3000, 1500, 0], [120, 120, 0], [19], [34, 34, 34]],
    // LooneyBin (owner, 2026-06-11): Ifrit HMG (machine gun, NOT the GMG) -> rebel shop
    // owner 2026-06-19: REMOVED from rebel store (shop keys emptied; was ["reb_car","nd_car"]). Entry kept so existing units keep sell-back/chop price.
    // owner 2026-07-24: REMOVED from the shop again (shop keys emptied). The RCWS zoom + T auto-range can't be
    // nerfed server-side (client-rendered optic; mission config can't override a base vehicle's turret -- proven
    // via merged-config dump), so the armed HMG is un-limitable and too strong. Entry kept for existing units'
    // sell-back/chop price. (Was ["nd_car"] @ 60 ND for ~a day this session.)
    // owner 2026-07-24 FIX (money printer reopened by 87e30d4): emptying the shop-key list to pull the Ifrit
    // from the shop ALSO cleared its ND marker, because both payout paths derive "is this an ND vehicle" from
    // this same list ("nd_car" in idx 3). An Ifrit bought for 60 ND then sold/chopped back for CASH. The list
    // was doing double duty: "which shops sell it" AND "what currency it settles in". "nd_priced" is a
    // currency-only sentinel -- shops match with `_shop in (_x select 3)` against real shop names, so it can
    // never list the vehicle anywhere, but the sell/chop paths now still recognise it as ND.
    ["O_MRAP_02_hmg_F", "", [civilian], ["nd_priced"], 0, 0, 0, 135000, 67500, [5000, 0, 0], [120, 0, 0], [19],
        [34, 34, 34]],
    // owner 2026-07-23: AWC Nyx (autocannon variant sold as a TURRETLESS armored hull -- turret hidden by
    // the civ_nyx preset in fn_vehicleAnimate, all turret mags stripped in fn_clearVehicleAmmo) -> ND
    // shop (33.3333 ND). Caliber gate in fn_handleVehicleDamage: nothing under 7.62 hurts it.
    ["I_LT_01_cannon_F", "AWC Nyx", [civilian], ["nd_car"], 0, 0, 0, 135000, 67500, [5000, 0, 0], [120, 0, 0], [],
        [40, 40, 40]], ["B_MRAP_01_F", "", [civilian, west, independent],
        ["bh_car", "cop_car", "med_car"], 3, 3, 0, 45000, 22500, [2000, 1000, 1000], [120, 120, 120], [101], [34, 34, 34]],
    // LooneyBin (owner, 2026-06-11): Hunter HMG (machine gun) -> MaxSec shop, Lieutenant+ (cop level 5)
    // owner 2026-06-19: REMOVED from cop store (shop keys emptied; was ["cop_car","maxtac_car"]). Entry kept so existing units keep sell-back/chop price.
    
    ["I_MRAP_03_F", "", [civilian, west, independent], ["cop_car", "med_car", "nd_car", "reb_car"], 4, 5, 0, 45000, 22500, [1500, 1500, 1500], [150, 150, 150], [101, 115], [34, 34, 34]], ["Land_CargoBox_V1_F", "", [civilian],
        ["chop_shop"], 0, 0, 0, 1400, 700, 500, 200, [], [10, 10, 10]], ["Land_Cargo20_red_F", "", [civilian],
        ["chop_shop"], 0, 0, 0, 1700, 850, 550, 200, [], [10, 10, 10]], ["O_Truck_03_covered_F", "", [civilian],
        ["chop_shop"], 0, 0, 0, 45000, 22500, 2000, 900, [], [50, 50, 50]], ["B_T_Truck_01_ammo_F", "", [civilian],
        ["chop_shop"], 0, 0, 0, 45000, 22500, 2000, 900, [], [50, 50, 50]], ["B_T_Truck_01_box_F", "", [civilian],
        ["chop_shop"], 0, 0, 0, 45000, 22500, 2000, 900, [], [50, 50, 50]], ["O_T_Truck_03_repair_ghex_F", "", [civilian],
        ["chop_shop"], 0, 0, 0, 45000, 22500, 2000, 900, [], [50, 50, 50]], ["O_APC_Wheeled_02_rcws_v2_F", "", [west],
        ["cop_car"], 6, 0, 0, 247500, 123800, [3000, 1500, 0], [100, 100, 0], [19], [34, 34, 34]],
    ["C_Tractor_01_F", "", [civilian, west], ["civ_truck", "cop_car"], 0, 0, 0, 2000, 1000, 100, 150, [], [5, 5, 5], 26],
    ["C_Van_01_fuel_F", "", [civilian], ["civ_truck", "civ_special"], 0, 0, 0, 2000, 1000, [750, 1000, 0],
        [350, 350, 0], [], [15, 15, 15]],
    // BUGS.md #77: box truck ($7,100) undercut the plain transport van ($8,500) at identical 50 storage.
    // Re-slotted mid-ladder: van 8.5k/50 -> van02 12k/60 -> BOX 15k/65 -> zamak 20k/70 -> covered 25k/80.
    ["C_Van_01_box_F", "", [civilian, west],
        ["civ_truck", "cop_car", "civ_special"], 1, 0, 0, 5700, 2800, [750, 1000, 0], [350, 350, 0], [], [65, 65, 65], 27], ["C_Van_02_vehicle_F", "", [civilian, west],
        ["civ_truck", "cop_car"], 1, 0, 0, 7200, 3600, [850, 850, 0], [400, 400, 0], [100], [60, 60, 60], 26], ["C_Van_02_transport_F", "", [civilian, west],
        ["civ_truck", "cop_car"], 1, 0, 0, 7800, 3900, [850, 850, 0], [400, 400, 0], [100], [60, 60, 60], 26], ["I_Truck_02_transport_F", "", [civilian, west],
        ["civ_truck", "cop_car"], 4, 0, 0, 7600, 3800, [1000, 1000, 0], [600, 600, 0], [17], [70, 70, 70], 27],
    ["C_Truck_02_fuel_F", "", [civilian, west], ["civ_truck", "cop_car"], 0, 0, 0, 2300, 1200, [1250, 1250, 0],
        [700, 700, 0], [17], [30, 30, 30], 27], ["I_Truck_02_covered_F", "", [civilian, west],
        ["civ_truck", "cop_car"], 0, 0, 0, 8300, 4200, [1250, 1250, 0], [700, 700, 0], [17], [80, 80, 80], 27],
    ["B_Truck_01_transport_F", "", [civilian, west], ["civ_truck", "cop_car"], 5, 0, 0, 45000, 22500,
        [1500, 1500, 0], [850, 850, 0], [17], [100, 100, 100], 27], ["B_Truck_01_flatbed_F", "", [civilian], ["civ_truck"], 0, 0, 0, 45000, 22500, 900, 220, [], [120, 120, 120], 27], ["B_Truck_01_box_F", "", [civilian, west],
        ["civ_truck", "cop_car"], 0, 0, 0, 45000, 22500, [1750, 1750, 0], [1000, 1000, 0], [17],
        [120, 120, 120], 27], ["B_Truck_01_fuel_F", "", [civilian, west], ["civ_truck", "cop_car"], 0, 0, 0, 45000, 22500, [1750, 1750, 0], [1000, 1000, 0], [17], [30, 30, 30], 27], ["O_Truck_03_device_F", "", [civilian],
        ["civ_truck"], 0, 0, 0, 45000, 22500, 5000, 1250, [17], [50, 50, 50]], ["O_Truck_03_medical_F", "", [independent],
        ["med_car"], 0, 2, 0, 33800, 16900, 2000, 250, [113], [50, 50, 50]], ["O_Truck_03_fuel_F", "", [independent],
        ["med_car", "firefighter_car"], 0, 3, 0, 45000, 22500, 2000, 250, [113], [50, 50, 50]],
    ["O_T_LSV_02_unarmed_F", "", [civilian, west, independent], ["reb_car", "bh_car", "cop_car", "med_car"], 3, 2, 0, 22500, 11200, [750, 750, 750], [175, 175, 175], [], [30, 30, 30], 27],
    // LooneyBin: TT prestige Xi'an (Trauma Team Executive Package, talent 10) — independent-only, med_air shop
    
    ["B_T_LSV_01_unarmed_F", "", [civilian, west],
        ["reb_car", "bh_car", "cop_car"], 3, 0, 0, 22500, 11200, [700, 700, 0], [175, 175, 175], [101], [30, 30, 30], 27], ["I_C_Offroad_02_LMG_F", "", [civilian, west],
        ["reb_car", "cop_car"], 4, 0, 0, 45000, 22500, 1000, 0, [17], [30, 30, 30]], ["O_LSV_02_armed_F", "", [civilian],
        ["reb_car", "nd_car"], 0, 0, 0, 45000, 22500, 3000, [175, 175, 175], [17], [30, 30, 30]],
    ["O_T_LSV_02_armed_F", "", [civilian], ["chop_shop"], 0, 0, 0, 45000, 22500, 3000, 175, [], [30, 30, 30]],
    ["C_Offroad_02_unarmed_F", "", [civilian, west], ["civ_car", "bh_car", "cop_car"], 2, 0, 0, 1500, 800,
        [250, 250, 250], [150, 150, 150], [99], [30, 30, 30], 25], ["I_G_Offroad_01_repair_F", "", [civilian],
        ["reb_car", "bh_car"], 2, 0, 10, 2000, 1000, [250, 250, 250], [150, 150, 150], [99], [30, 30, 30], 25],
    ["C_Plane_Civil_01_F", "", [civilian, west], ["civ_air", "cop_air"], 5, 0, 0, 64900, 32400, 1500, 150, [], [9, 9, 9]],
    
    ["C_Heli_Light_01_civil_F", "", [civilian, independent, west], ["civ_air", "med_air", "cop_air"], 2, 2, 0, 37900, 19000, [750, 750, 750], [80, 80, 80], [114], [17, 17, 17], 28],
    ["B_Heli_Light_01_F", "", [civilian, west, independent], ["civ_air", "cop_air", "bh_car", "med_air", "reb_car"], 2, 1, 0, 37900, 19000, [750, 750, 750], [80, 80, 0], [102, 114], [17, 17, 17], 28],
    ["I_Heli_light_03_unarmed_F", "Hellcat", [civilian, west, independent], ["reb_car", "bh_car", "cop_air", "med_air"], 3, 2, 0, 95400, 47700, [850, 850, 850], [100, 100, 100], [20, 103, 114], [34, 34, 34], 29],
    
    ["O_Heli_Light_02_unarmed_F", "", [civilian, west, independent], ["civ_air", "cop_air", "reb_car", "bh_car", "med_air"], 4, 3, 0, 138200, 69100, [750, 750, 750], [80, 80, 80], [20, 104], [50, 50, 50], 29],
    // owner 2026-07-03: armed helis in the REBEL air shop (reb_car), missiles stripped on spawn (fn_clearVehicleAmmo).
    
    
    // owner 2026-07-03: Blackfish vehicle transport in the CIV air shop. $300k, 3000 virtual-inv cap
    // BEFORE upgrades (field 10 = getVirtCap base; storage upgrades add on top via fn_prepareVehicle _mods).
    ["B_T_VTOL_01_infantry_F", "Blackfish (Transport)", [civilian], ["civ_air"], 0, 0, 0, 372000, 186000, 15000, 3000, [], [100, 100, 100]],
    ["I_Heli_Transport_02_F", "", [civilian, west], ["civ_air", "cop_air"], 4, 0, 0, 241700, 120800, [1000, 1000, 0],
        [300, 300, 0], [20], [84, 84, 84], 30], ["B_Heli_Transport_03_unarmed_F", "", [west],
        ["cop_air"], 5, 0, 0, 128500, 64200, 2000, 80, [104], [100, 100, 100]], ["O_Heli_Transport_04_F", "", [civilian],
        ["reb_car"], 0, 0, 0, 117600, 58800, 2000, 100, [20], [67, 67, 67]], ["O_Heli_Transport_04_bench_F", "", [civilian],
        ["reb_car"], 0, 0, 0, 117600, 58800, 1500, 100, [20], [67, 67, 67]], ["O_Heli_Transport_04_medevac_F", "", [independent],
        ["med_air"], 0, 3, 0, 104900, 52400, 1500, 100, [20, 114], [67, 67, 67]], ["O_Heli_Transport_04_F", "", [independent],
        ["med_air"], 0, 4, 0, 88200, 44100, 1500, 100, [20, 114], [67, 67, 67]],  ["B_Heli_Transport_01_F", "", [west],
        ["cop_air"], 6, 0, 0, 260500, 130200, 2500, 80, [104], [50, 50, 50]],  ["C_Rubberboat", "", [civilian],
        ["civ_ship"], 0, 0, 0, 300, 200, 50, 60, [], [9, 9, 9]], ["C_Scooter_Transport_01_F", "", [civilian],
        ["civ_ship"], 0, 0, 0, 800, 400, 100, 75, [], [9, 9, 9]], ["C_Boat_Civil_01_F", "", [civilian],
        ["civ_ship"], 0, 0, 0, 2000, 1000, 200, 200, [], [9, 9, 9]], ["C_Boat_Civil_01_rescue_F", "", [civilian, independent],
        ["civ_ship", "med_ship"], 0, 3, 0, 2000, 1000, [200, 200, 200], [200, 200, 200], [], [9, 9, 9]],
    ["C_Boat_Transport_02_F", "", [civilian, independent], ["civ_ship", "med_ship"], 0, 3, 0, 2000, 1000,
        [300, 300, 300], [200, 100, 100], [], [9, 9, 9]], ["O_SDV_01_F", "", [civilian], ["civ_ship"], 0, 0, 0, 30000, 15000, 200, 200, [],
        [9, 9, 9]], ["B_Boat_Transport_01_F", "", [west], ["cop_ship"], 2, 0, 0, 600, 300, 50, 200, [], [9, 9, 9]],
    ["C_Boat_Civil_01_police_F", "", [west], ["cop_ship"], 2, 0, 0, 1100, 600, 200, 200, [], [9, 9, 9]],
    ["B_Boat_Armed_01_minigun_F", "", [west], ["cop_ship"], 5, 0, 0, 247500, 123800, 2500, 200, [], [9, 9, 9]],
        // --- TT rank-issued military fleet (owner 2026-06-27) ---
        ["C_Van_01_transport_F", "", [independent], ["med_car"], 0, 1, 0, 3300, 1600, 500, 100, [], [100, 100, 100]],
        ["C_Truck_02_transport_F", "", [independent], ["med_car"], 0, 1, 0, 12800, 6400, 1000, 200, [], [200, 200, 200]],
        ["B_T_LSV_01_unarmed_F", "", [independent], ["med_car"], 0, 2, 0, 16900, 8400, 1500, 200, [], [40, 40, 40]],
        ["B_G_Offroad_01_armed_F", "", [independent], ["med_car"], 0, 3, 0, 33800, 16900, 3000, 200, [], [40, 40, 40]],
        ["O_MRAP_02_F", "", [independent], ["med_car"], 0, 6, 0, 33800, 16900, 5000, 300, [], [50, 50, 50]],  
        ["B_APC_Wheeled_01_cannon_F", "", [independent], ["med_car"], 0, 7, 0, 337500, 168800, 8000, 400, [], [60, 60, 60]],
        ["I_Heli_Transport_02_F", "", [independent], ["med_air"], 0, 3, 0, 181300, 90600, 4000, 300, [], [60, 60, 60]],  
        ["C_Plane_Civil_01_F", "", [independent], ["med_air"], 0, 3, 0, 48700, 24400, 3000, 250, [], [30, 30, 30]],
        ["B_UAV_01_F", "", [independent], ["med_air"], 0, 5, 0, 18800, 9400, 2000, 100, [], [10, 10, 10]],
        
        ["B_Heli_Transport_01_F", "", [independent], ["med_air"], 0, 6, 0, 355200, 177600, 10000, 400, [], [60, 60, 60]],
        ["B_Heli_Transport_03_unarmed_F", "", [independent], ["med_air"], 0, 6, 0, 175200, 87600, 9000, 400, [], [80, 80, 80]],
        ["B_T_VTOL_01_infantry_F", "", [independent], ["med_air"], 0, 7, 0, 279000, 139500, 15000, 3000, [], [100, 100, 100]],
        ["C_Offroad_01_F", "", [independent], ["med_car"], 0, 1, 0, 1700, 800, 250, 100, [], [34, 34, 34]],
        ["C_Van_02_medevac_F", "", [independent], ["med_car"], 0, 1, 0, 4500, 2200, 350, 100, [], [50, 50, 50]],
        ["I_MRAP_03_F", "", [independent], ["med_car"], 0, 3, 0, 33800, 16900, 1500, 150, [], [34, 34, 34]],
        ["B_MRAP_01_F", "", [independent], ["med_car"], 0, 3, 0, 33800, 16900, 1500, 150, [], [34, 34, 34]],
        ["O_Heli_Light_02_unarmed_F", "", [independent], ["med_air"], 0, 3, 0, 103600, 51800, 750, 80, [], [50, 50, 50]],
        ["C_Boat_Civil_01_F", "", [independent], ["med_ship"], 0, 1, 0, 1500, 800, 500, 100, [], [30, 30, 30]],
        ["B_Boat_Transport_01_F", "", [independent], ["med_ship"], 0, 1, 0, 800, 400, 500, 100, [], [30, 30, 30]],
        ["C_Scooter_Transport_01_F", "", [independent], ["med_ship"], 0, 2, 0, 600, 300, 800, 100, [], [10, 10, 10]],
        ["O_SDV_01_F", "", [independent], ["med_ship"], 0, 2, 0, 22500, 11200, 3000, 200, [], [30, 30, 30]],
        ["B_Boat_Armed_01_minigun_F", "", [independent], ["med_ship"], 0, 7, 0, 337500, 168800, 5000, 300, [], [40, 40, 40]],
        // --- ECONOMY 2026-09-05: catalogue completion (see the price-ladder teardown, section 05).
        // 26 unarmed models existed in CfgVehicles and were in no shop. These are the ones that make
        // sense in a garage: the Taru pod family, the unarmed Ghost Hawk, the NATO/CSAT truck variants,
        // the Zamak box, the Darter and the unarmed Nyx. The other 122 unsold classes are pure re-skins
        // of models already listed and belong in fn_vehicleTextures.sqf, not here -- adding them as rows
        // would put the same helicopter in the list eleven times. Every dynamicLoadout class is EXCLUDED
        // on purpose: they scan as unarmed but carry pylons and can be given missiles at spawn.
        // Prices are derived: max(K * (slots + 3*seats)^1.05 * (min(speed,280)/100)^0.5 * armourBand, floor).
        ["B_Heli_Transport_01_unarmed_F", "", [civilian], ["civ_air", "reb_car"], 0, 0, 0, 157900, 79000, 3200, 800, [], [60, 60, 60]],
        ["B_Heli_Transport_01_unarmed_F", "", [independent], ["med_air"], 0, 6, 0, 118400, 59200, 2400, 600, [], [60, 60, 60]],
        ["O_Heli_Transport_04_covered_F", "", [civilian], ["civ_air", "reb_car"], 0, 0, 0, 220700, 110400, 4400, 1100, [], [80, 80, 80]],
        ["O_Heli_Transport_04_box_F", "", [civilian], ["civ_air", "reb_car"], 0, 0, 0, 141700, 70800, 2800, 700, [], [80, 80, 80]],
        ["O_Heli_Transport_04_fuel_F", "", [civilian], ["civ_air", "reb_car"], 0, 0, 0, 141700, 70800, 2800, 700, [], [60, 60, 60]],
        ["O_Heli_Transport_04_repair_F", "", [civilian], ["civ_air", "reb_car"], 0, 0, 0, 141700, 70800, 2800, 700, [], [60, 60, 60]],
        ["O_Heli_Transport_04_ammo_F", "", [civilian], ["civ_air", "reb_car"], 0, 0, 0, 141700, 70800, 2800, 700, [], [60, 60, 60]],
        ["B_UAV_06_F", "", [civilian], ["civ_air"], 0, 0, 0, 25000, 12500, 500, 100, [], [5, 5, 5]],
        ["C_Truck_02_box_F", "", [civilian], ["civ_truck"], 0, 0, 0, 4400, 2200, 100, 50, [], [150, 150, 150]],
        ["B_T_Truck_01_covered_F", "", [civilian], ["civ_truck"], 0, 0, 0, 45000, 22500, 900, 200, [], [110, 110, 110]],
        ["B_T_Truck_01_cargo_F", "", [civilian], ["civ_truck"], 0, 0, 0, 45000, 22500, 900, 200, [], [140, 140, 140]],
        ["B_T_Truck_01_mover_F", "", [civilian], ["civ_truck"], 0, 0, 0, 45000, 22500, 900, 200, [], [60, 60, 60]],
        ["B_T_Truck_01_medical_F", "", [independent], ["med_car"], 0, 3, 0, 33800, 16900, 700, 150, [], [90, 90, 90]],
        ["I_E_Truck_02_Medical_F", "", [independent], ["med_car"], 0, 2, 0, 5500, 2800, 100, 50, [], [90, 90, 90]],
        ["O_T_Truck_03_transport_ghex_F", "", [civilian], ["civ_truck"], 0, 0, 0, 45000, 22500, 900, 200, [], [100, 100, 100]],
        ["O_T_Truck_03_ammo_ghex_F", "", [civilian], ["civ_truck"], 0, 0, 0, 45000, 22500, 900, 200, [], [120, 120, 120]],
        ["I_LT_01_scout_F", "", [civilian], ["reb_car"], 0, 0, 0, 45000, 22500, 900, 200, [], [40, 40, 40]]];
    // owner 2026-07-08 (perf + MaxTac-shop fix): build the srt-excluded VIEW once, alongside the full table. The old
    // code REBUILT the ~90-row literal every call then re-filtered it; worse, the global srt_car filter stripped the
    // MaxTac/SRT rows (tagged srt_car) from their OWN shop -> empty garage. Now shopVehicles reads the FULL table and
    // every other case reads the srt-excluded view (dup classnames still resolve to the civ/non-srt row, as before).
    // NonSrt first: the isNil gate above keys on AP_vehConfigTable, so a caller that sees it set finds both.
    localNamespace setVariable ["AP_vehConfigNonSrt", _vt select { !("srt_car" in (_x param[3, []])) }];
    localNamespace setVariable ["AP_vehConfigTable", _vt];};
private _vehicleArray = localNamespace getVariable "AP_vehConfigNonSrt";   // srt-excluded (default -- identical to the old global-filtered array)
private _fullTable    = localNamespace getVariable "AP_vehConfigTable";    // full table incl srt/maxtac rows (shopVehicles only)
private "_return";
switch (_mode) do {case "getVehicleRow": {_return = []; {if ((_className == (_x select 0)) && !("srt_car" in (_x param[3, []]))) exitWith {
                    _return = +_x;   // deep copy -- a caller could mutate the row; with the cached table a bare ref would corrupt the shared table
                };}
            forEach _vehicleArray;}; case "getVehicleRowParsed": {_return = []; {
                    if ((_className == (_x select 0)) && !("srt_car" in (_x param[3, []]))) exitWith {
                        _return = +_x;   // deep copy -- getVehicleRowParsed mutates _return in place (set 7/8/9/10); with the cached table a bare ref would corrupt the shared row
                    };}
                forEach _vehicleArray;
                // Slots 7/8/9/10 (buy/sell/rent/...) may each hold a per-side array [civ, cop, ind];
                // flatten to this player's side. No default arm on purpose: east/other sides leave the
                // arrays untouched, exactly as the three-case switch this replaced did.
                private _sideIdx = switch (AP_effSide) do {case civilian: {0}; case west: {1}; case independent: {2}; default {-1}};
                // a classname with NO row leaves _return = [] -- flattening it threw
                // "0 elements provided, 8 expected" on every read of an unlisted class
                if (_sideIdx > -1 && {_return isNotEqualTo []}) then {
                    {if ((_return select _x) isEqualType[]) then {_return set[_x, ((_return select _x) select _sideIdx)];};} forEach [7, 8, 9, 10];
                };
                // LooneyBin Economy: owner vehicle-price overrides (veh p0=buy idx7, p1=sell idx8)
                if (_return isNotEqualTo []) then {private _ov = ["veh", _className] call AP_fnc_priceOv;
                    if (_ov isNotEqualTo []) then {if ((_ov select 2) >= 0) then { _return set [7, _ov select 2]; };
                        if ((_ov select 3) >= 0) then { _return set [8, _ov select 3]; };};};};
        case "getEconList":   // LooneyBin Economy UI: [[class,name,buy,sell],...] (civ tier 0)
            {_return = _vehicleArray apply {private _b = _x param [7, 0]; if (_b isEqualType []) then { _b = _b param [0, 0]; };
                    private _s = _x param [8, 0]; if (_s isEqualType []) then { _s = _s param [0, 0]; };
                    [_x select 0, getText (configFile >> "CfgVehicles" >> (_x select 0) >> "displayName"), _b, _s]};};
        case "shopVehicles": {_return = [];
                // owner 2026-07-08: removed the -VEHSHOPDBG- diag (fired a remoteExec + DB log on every cop/MaxTac/SRT
                // shop open) now the empty-garage root cause is fixed (shopVehicles reads _fullTable above).
                {if ((_shop in (_x select 3)) && (AP_effSide in (_x select 2))) then {switch (AP_effSide) do {case civilian: {
                                    if (_donorLevel >= (_x select 6)) then {_return pushBackUnique _x;};};
                            case west: {
                                    // owner 2026-06-25 (MaxTac/SRT garage STILL empty -- the REAL cause): these two branches
                                    // used `exitWith`, not `then`. `exitWith` here terminates the whole fn_vehicleConfig
                                    // `call` and makes it RETURN the value of its block -- `_return pushBackUnique _x`, which
                                    // yields the new index (a NUMBER, 0), not the array. So the caller got `0`; the -VEHSHOP-
                                    // diag showed exactly `maxtac_car -> 0 veh: []` (count 0 / apply []). The 2026-06-21 isMaxTac
                                    // tweak never touched this. Use `then` like every sibling branch (civ donor / cop rank /
                                    // medic) so each matching vehicle is pushed and the forEach keeps going -> all 7 show.
                                    if (_shop isEqualTo "maxtac_car") then {_return pushBackUnique _x;};
                                    if (_shop isEqualTo "srt_car") then {_return pushBackUnique _x;};
                                    if (_copLevel >= (_x select 4) && !(_x select 4 isEqualTo 0)) then {_return pushBackUnique _x;};
                                    if ((_x param[13, -1] in AP_cop_talents) && (AP_copRole in ["all", "scd"])) then {
                                        _return pushBackUnique _x;};};
                            case independent: {
                                    // owner 2026-06-25: same exitWith-returns-from-the-call bug as maxtac_car/srt_car above
                                    // (would blank the firefighter shop). Use `then` so the forEach keeps building the list.
                                    if (AP_isActiveFirefighter && _shop isEqualTo "firefighter_car") then {_return pushBackUnique _x;};
                                    // LooneyBin: TT prestige-gated vehicles -> shown ONLY if the matching prestige
                                    // talent is owned (overrides the rank gate for these specific classes).
                                    private _ngVehRank = if (_medicLevel isEqualTo 99) then {0} else {_medicLevel};
                                    private _pGate = switch (_x select 0) do {
                                        case "B_Heli_Light_01_F": {6};                      // Flight Medic -> Hummingbird
                                        case "I_Heli_light_03_unarmed_F";
                                        case "I_Heli_light_03_F": {7};                      // Hellcat
                                        case "O_Heli_Light_02_unarmed_F": {8};              // Orca
                                        case "I_Vtol_02_infantry_dynamicLoadout_F": {10};   // Xi'an
                                        case "O_T_LSV_02_unarmed_F";
                                        case "O_LSV_02_unarmed_F": {12};                    // Qilin
                                        case "B_MRAP_01_F": {13};                           // Hunter
                                        case "I_MRAP_03_F": {14};                           // Strider
                                        default {-1};};
                                    // owner 2026-06-25: was `exitWith` (same footgun as maxtac_car/srt_car above) -- on the
                                    // FIRST prestige-gated medic vehicle the forEach hit, it bailed out of the list-build,
                                    // truncating/blanking the TT vehicle shop. if/else keeps the intent (prestige vehicles
                                    // gated by talent, the rest by rank) while letting the forEach finish every entry.
                                    if (_pGate != -1) then {
                                        if ((_pGate in AP_medic_talents) && (_ngVehRank >= (_x select 5))) then { _return pushBackUnique _x; };
                                    } else {if (_ngVehRank >= (_x select 5)) then { _return pushBackUnique _x; };};};};};}
                forEach _fullTable;   // owner 2026-07-08: shopVehicles reads the FULL table so MaxTac/SRT rows (tagged srt_car) show in their own shop; non-matching srt rows are still filtered by the per-shop tag test above
                _return = _return apply { +_x };   // copy rows out of the cached table so a shop consumer can't mutate the shared cache in place
            };
        case "talentCheck": {if (AP_effSide isEqualTo west && {AP_activeMAXTAC}) exitWith {_return = "";};
                _return = "";
                private _allSideTalents = ["getFactionTalentsIDs"] call AP_fnc_talentCfg;
                private _requiredVehTalents = []; {if (_className == (_x select 0)) exitWith {_requiredVehTalents = (_x param [11, []]);};}
                forEach _vehicleArray;
                if ((count _requiredVehTalents) isEqualTo 0) exitWith {_return = "";};
                private _talentsNeeded = _requiredVehTalents arrayIntersect _allSideTalents; {if !(_x in AP_side_talents) exitWith {
                        _return = ["getTalentName", _x] call AP_fnc_talentCfg;};}
                forEach _talentsNeeded;};
        case "getVirtCap": {_return = 0; {if (_className isEqualTo(_x param[0, ""])) exitWith {if ((_x select 10) isEqualType[]) then {
                            _return = (_x select 10) select 0;} else {_return = _x select 10;};};}
                forEach _vehicleArray;};
        case "getPhysCap": {_return = 0; {if (_className isEqualTo(_x param[0, ""])) exitWith {if ((_x select 12) isEqualType[]) then {
                            _return = (_x select 12) select 0;} else {_return = _x select 12;};};}
                forEach _vehicleArray;};}; _return ;
