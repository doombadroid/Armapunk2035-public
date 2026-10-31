params[["_shop", "", [""]]];
if (_shop isEqualTo "") exitWith {closeDialog 0};
private _copLevel = call AP_copLevel;
if (AP_activeMAXTAC) then {_copLevel = 6;};
private _ret =
switch (_shop) do {case "police_weapons": {switch (true) do {case (_copLevel >= 1): {[["16Rnd_9x21_Mag", "9mm 16Rnd", 50],
                            ["30Rnd_9x21_Mag", "9mm 30Rnd", 75], ["30Rnd_9x21_Mag_SMG_02", nil, 75], ["50Rnd_570x28_SMG_03", nil, 150],
                            ["30Rnd_545x39_Mag_F", "5.45 30Rnd", 100], ["30Rnd_556x45_Stanag", "5.56 30Rnd", 100],
                            ["30Rnd_556x45_Stanag_Sand", "5.56 30Rnd Sand", 100], ["acc_flashlight", nil, 125],
                            ["acc_pointer_IR", nil, 125], ["optic_ACO", nil, 125], ["optic_Aco_smg", nil, 125],
                            ["optic_Holosight", nil, 125], ["optic_Holosight_smg", nil, 125], ["optic_Holosight_smg_blk_F", nil, 125],
                            ["optic_Holosight_blk_F", nil, 125]];};
                default {"You are not a Police Officer";};};}; case "srt_weapons": {switch (true) do {case (_copLevel >= 1): {[
                                ["16Rnd_9x21_Mag", "9mm 16Rnd", 0], ["30Rnd_9x21_Mag", "9mm 30Rnd", 0], ["30Rnd_9x21_Mag_SMG_02", nil, 0],
                                ["30Rnd_556x45_Stanag", "5.56 30Rnd", 0], ["30Rnd_556x45_Stanag_Sand", "5.56 30Rnd Sand", 0],
                                ["acc_flashlight", nil, 0], ["acc_pointer_IR", nil, 0], ["optic_ACO", nil, 0], ["optic_Aco_smg", nil, 0],
                                ["optic_Holosight", nil, 0], ["optic_Holosight_smg", nil, 0], ["optic_Holosight_smg_blk_F", nil, 0],
                                ["optic_Holosight_blk_F", nil, 0]];};
                    default {"You are not a Police Officer";};};};
        case "bounty": {[["6Rnd_GreenSignal_F", nil, 50], ["6Rnd_RedSignal_F", nil, 50], ["30Rnd_9x21_Mag", "9mm 30Rnd Rubber", 75],
                    ["30Rnd_45ACP_Mag_SMG_01_tracer_green", ".45 30Rnd Rubber", 75],
                    ["30Rnd_556x45_Stanag_Tracer_Green", "5.56 30Rnd Rubber", 100],
                    ["30Rnd_556x45_Stanag_Sand_Tracer_Green", "5.56 30Rnd Rubber Sand", 100], ["optic_ACO_grn_smg", nil, 250],
                    ["optic_ACO_grn", nil, 250], ["optic_ACO", nil, 250], ["optic_ACO_smg", nil, 250], ["optic_Holosight", nil, 250],
                    ["optic_Holosight_blk_F", nil, 250], ["optic_Holosight_khk_F", nil, 250], ["optic_Holosight_smg", nil, 250],
                    ["optic_Holosight_smg_blk_F", nil, 250], ["optic_MRCO", nil, 1000], ["optic_hamr", nil, 1000],
                    ["optic_Hamr_khk_F", nil, 1000], ["optic_Arco", nil, 1000], ["optic_Arco_blk_F", nil, 1000],
                    ["optic_Arco_ghex_F", nil, 1000], ["optic_Arco_AK_blk_F", nil, 1000], ["optic_ERCO_blk_F", nil, 1000],
                    ["optic_ERCO_khk_F", nil, 1000], ["optic_ERCO_snd_F", nil, 1000], ["acc_flashlight", nil, 250],
                    ["acc_pointer_IR", nil, 250]]};
        case "skiptracer": {[["6Rnd_GreenSignal_F", nil, 50], ["6Rnd_RedSignal_F", nil, 50], ["30Rnd_9x21_Mag", "9mm 30Rnd Rubber", 50],
                    ["30Rnd_45ACP_Mag_SMG_01_tracer_green", ".45 30Rnd Rubber", 75],
                    ["30Rnd_556x45_Stanag_Tracer_Green", "5.56 30Rnd Rubber", 100],
                    ["30Rnd_556x45_Stanag_Sand_Tracer_Green", "5.56 30Rnd Rubber Sand", 100],
                    ["30Rnd_65x39_caseless_mag_Tracer", "6.5mm 30Rnd Sand Rubber", 150],
                    ["30Rnd_65x39_caseless_khaki_mag_Tracer", "6.5mm 30Rnd Khaki Rubber", 150], ["optic_ACO_grn_smg", nil, 250],
                    ["optic_ACO_grn", nil, 250], ["optic_ACO", nil, 250], ["optic_ACO_smg", nil, 250], ["optic_Holosight", nil, 250],
                    ["optic_Holosight_blk_F", nil, 250], ["optic_Holosight_khk_F", nil, 250], ["optic_Holosight_smg", nil, 250],
                    ["optic_Holosight_smg_blk_F", nil, 250], ["optic_MRCO", nil, 1000], ["optic_hamr", nil, 1000],
                    ["optic_Hamr_khk_F", nil, 1000], ["optic_Arco", nil, 1000], ["optic_Arco_blk_F", nil, 1000],
                    ["optic_Arco_ghex_F", nil, 1000], ["optic_Arco_AK_blk_F", nil, 1000], ["optic_ERCO_blk_F", nil, 1000],
                    ["optic_ERCO_khk_F", nil, 1000], ["optic_ERCO_snd_F", nil, 1000], ["acc_flashlight", nil, 250],
                    ["acc_pointer_IR", nil, 250]]};
        // NEW DRACHMA heavy shop -- side list = just the mags for the four guns (prices are ND via
        // fn_ndPriceCfg; these cash values are the 6000:1 fallback only). Type 115 .50 Beowulf mag included.
        case "ndheavy": {[["5Rnd_127x108_Mag", "GM6 12.7mm", 1500], ["10Rnd_338_Mag", "Mar-10 .338 Lapua", 1500],
                    ["130Rnd_338_Mag", "SPMG .338 Belt", 1500], ["10Rnd_93x64_DMR_05_Mag", "Cyrus 9.3mm", 1500],
                    ["10Rnd_50BW_Mag_F", "Type 115 .50 Beowulf", 12000]]};
        case "rebelwep": {[["6Rnd_GreenSignal_F", nil, 50], ["6Rnd_RedSignal_F", nil, 50], ["10Rnd_9x21_Mag", nil, 50],
                    ["16Rnd_9x21_Mag", nil, 50], ["9Rnd_45ACP_Mag", nil, 50], ["6Rnd_45ACP_Cylinder", nil, 50], ["30Rnd_9x21_Mag", nil, 75],
                    ["30Rnd_9x21_Mag_SMG_02", nil, 75], ["30Rnd_45ACP_Mag_SMG_01", nil, 75],
                    ["30Rnd_45ACP_Mag_SMG_01_tracer_green", nil, 75], ["30Rnd_545x39_Mag_F", nil, 100], ["30Rnd_762x39_Mag_F", nil, 150],
                    ["20Rnd_556x45_UW_mag", nil, 100], ["30Rnd_556x45_Stanag", "5.56 30Rnd", 100],
                    ["30Rnd_556x45_Stanag_Sand", "5.56 30Rnd Sand", 100], ["30Rnd_580x42_Mag_F", nil, 150],
                    ["50Rnd_570x28_SMG_03", nil, 150], ["30Rnd_65x39_caseless_green", nil, 150],
                    ["30Rnd_65x39_caseless_msbs_mag", nil, 150], ["10Rnd_762x54_Mag", nil, 150], ["20Rnd_762x51_Mag", nil, 200],
                    ["10Rnd_Mk14_762x51_Mag", nil, 100], ["30Rnd_762x39_AK12_Mag_F", nil, 200], ["30Rnd_762x39_AK12_Lush_Mag_F", nil, 200],
                    ["75rnd_762x39_AK12_Lush_Mag_F", nil, 750], ["75rnd_762x39_AK12_Mag_F", nil, 750], ["75Rnd_762x39_Mag_F", nil, 750],
                    ["200Rnd_65x39_cased_Box", nil, 2500], ["200Rnd_556x45_Box_F", nil, 3000], ["2Rnd_12Gauge_Slug", nil, 100],
                    ["optic_Yorris", nil, 250], ["optic_ACO_grn_smg", nil, 250], ["optic_ACO_grn", nil, 250], ["optic_ACO", nil, 250],
                    ["optic_ACO_smg", nil, 250], ["optic_Holosight", nil, 250], ["optic_Holosight_blk_F", nil, 250],
                    ["optic_Holosight_khk_F", nil, 250], ["optic_Holosight_smg", nil, 250], ["optic_Holosight_smg_blk_F", nil, 250],
                    ["optic_MRCO", nil, 1000], ["optic_hamr", nil, 1000], ["optic_Hamr_khk_F", nil, 1000], ["optic_Arco", nil, 1000],
                    ["optic_Arco_blk_F", nil, 1000], ["optic_Arco_ghex_F", nil, 1000], ["optic_Arco_AK_blk_F", nil, 1000],
                    ["optic_ERCO_blk_F", nil, 1000], ["optic_ERCO_khk_F", nil, 1000], ["optic_ERCO_snd_F", nil, 1000],
                    ["acc_flashlight", nil, 250], ["acc_pointer_IR", nil, 250],
                    // LooneyBin (owner, 2026-06-11): all bipods FREE in the rebel shop. The shop side
                    // panel filters by the selected weapon's compatibleItems, so each gun only shows the
                    // bipods it actually supports. No sell-back path in the weapon shop = 0 resale.
                    ["bipod_01_F_snd", "Bipod (Tan)", 0], ["bipod_01_F_blk", "Bipod (Black)", 0], ["bipod_01_F_mtp", "Bipod (MTP)", 0],
                    ["bipod_02_F_blk", "Bipod (Black)", 0], ["bipod_02_F_hex", "Bipod (Hex)", 0], ["bipod_02_F_tan", "Bipod (Tan)", 0],
                    ["bipod_03_F_blk", "Bipod (Black)", 0], ["bipod_03_F_oli", "Bipod (Olive)", 0]]};
        case "turf": {[["6Rnd_GreenSignal_F", nil, 50], ["6Rnd_RedSignal_F", nil, 50], ["10Rnd_9x21_Mag", nil, 50],
                    ["16Rnd_9x21_Mag", nil, 50], ["9Rnd_45ACP_Mag", nil, 50], ["6Rnd_45ACP_Cylinder", nil, 50], ["30Rnd_9x21_Mag", nil, 75],
                    ["30Rnd_9x21_Mag_SMG_02", nil, 75], ["30Rnd_45ACP_Mag_SMG_01", nil, 75],
                    ["30Rnd_45ACP_Mag_SMG_01_tracer_green", nil, 75], ["30Rnd_545x39_Mag_F", nil, 100], ["20Rnd_556x45_UW_mag", nil, 100],
                    ["30Rnd_556x45_Stanag", "5.56 30Rnd", 100], ["30Rnd_556x45_Stanag_Sand", "5.56 30Rnd Sand", 100],
                    ["30Rnd_580x42_Mag_F", nil, 150], ["50Rnd_570x28_SMG_03", nil, 150], ["30Rnd_65x39_caseless_green", nil, 150],
                    ["30Rnd_65x39_caseless_msbs_mag", nil, 150], ["10Rnd_762x54_Mag", nil, 150], ["20Rnd_762x51_Mag", nil, 200],
                    ["30Rnd_762x39_AK12_Mag_F", nil, 200], ["30Rnd_762x39_AK12_Lush_Mag_F", nil, 200],
                    ["75rnd_762x39_AK12_Lush_Mag_F", nil, 750], ["75rnd_762x39_AK12_Mag_F", nil, 750], ["75Rnd_762x39_Mag_F", nil, 750],
                    ["200Rnd_65x39_cased_Box", nil, 2500], ["200Rnd_556x45_Box_F", nil, 3000], ["2Rnd_12Gauge_Slug", nil, 100],
                    ["optic_Yorris", nil, 250], ["optic_ACO_grn_smg", nil, 250], ["optic_ACO_grn", nil, 250], ["optic_ACO", nil, 250],
                    ["optic_ACO_smg", nil, 250], ["optic_Holosight", nil, 250], ["optic_Holosight_blk_F", nil, 250],
                    ["optic_Holosight_khk_F", nil, 250], ["optic_Holosight_smg", nil, 250], ["optic_Holosight_smg_blk_F", nil, 250],
                    ["optic_MRCO", nil, 1000], ["optic_hamr", nil, 1000], ["optic_Hamr_khk_F", nil, 1000], ["optic_Arco", nil, 1000],
                    ["optic_Arco_blk_F", nil, 1000], ["optic_Arco_ghex_F", nil, 1000], ["optic_Arco_AK_blk_F", nil, 1000],
                    ["optic_ERCO_blk_F", nil, 1000], ["optic_ERCO_khk_F", nil, 1000], ["optic_ERCO_snd_F", nil, 1000],
                    ["acc_flashlight", nil, 250], ["acc_pointer_IR", nil, 250]]};
        case "gun": {[["6Rnd_GreenSignal_F", nil, 50], ["6Rnd_RedSignal_F", nil, 50], ["10Rnd_9x21_Mag", nil, 75],
                    ["16Rnd_9x21_Mag", nil, 75], ["30Rnd_9x21_Mag", nil, 100], ["9Rnd_45ACP_Mag", nil, 75],
                    ["20Rnd_556x45_UW_mag", nil, 150], ["30Rnd_556x45_Stanag", "5.56 30Rnd", 150],
                    ["30Rnd_556x45_Stanag_Sand", "5.56 30Rnd Sand", 150], ["optic_ACO_grn", nil, 375], ["optic_ACO_grn_smg", nil, 375],
                    ["acc_flashlight_pistol", nil, 250]]};
        case "huntingwep": {[["6Rnd_GreenSignal_F", nil, 50], ["6Rnd_RedSignal_F", nil, 50], ["10Rnd_9x21_Mag", nil, 50],
                    ["16Rnd_9x21_Mag", nil, 50], ["30Rnd_9x21_Mag", nil, 75], ["10Rnd_Mk14_762x51_Mag", nil, 100],
                    ["2Rnd_12Gauge_Slug", nil, 100]]};
        case "med_basic": {private _med = [["6Rnd_GreenSignal_F", nil, 75], ["6Rnd_RedSignal_F", nil, 75]];
                if ((call AP_medicLevel) >= 3) then {   // AEMT+ green P07: its 9mm mags + suppressor show in the gun's ammo/scopes submenu
                    _med pushBack ["16Rnd_9x21_Mag", "9mm 16Rnd", 100];
                    _med pushBack ["30Rnd_9x21_Mag", "9mm 30Rnd", 150];
                    _med pushBack ["muzzle_snds_L", "9mm Suppressor", 1000];};
                _med};
        case "maxtac_weapons": {[["optic_ACO", nil, 250], ["optic_ACO_smg", nil, 250], ["optic_Holosight", nil, 250],
                    ["optic_Holosight_blk_F", nil, 250], ["optic_Holosight_smg", nil, 250], ["optic_Holosight_smg_blk_F", nil, 250],
                    ["optic_MRCO", nil, 750], ["optic_hamr", nil, 750], ["optic_Hamr_khk_F", nil, 750], ["optic_Arco", nil, 750],
                    ["optic_Arco_blk_F", nil, 750], ["optic_ERCO_blk_F", nil, 750], ["optic_MRD", nil, 125], ["optic_MRD_black", nil, 125],
                    ["acc_flashlight", nil, 125], ["acc_pointer_IR", nil, 125]]};
        default {[]};};
if (_shop isEqualTo "police_weapons") then {if (AP_copRole in ["scd", "all"] || AP_activeMAXTAC) then {
        _ret pushBack["6Rnd_GreenSignal_F", nil, 50];
        _ret pushBack["6Rnd_RedSignal_F", nil, 50];
        _ret pushBack["optic_ACO", nil, 250];
        _ret pushBack["optic_ACO_grn_smg", nil, 250];
        _ret pushBack["optic_ACO_grn", nil, 250];
        _ret pushBack["optic_Holosight_khk_F", nil, 250];
        _ret pushBack["optic_Hamr_khk_F", nil, 1000];
        _ret pushBack["optic_Arco", nil, 1000];
        _ret pushBack["optic_Arco_ghex_F", nil, 1000];
        _ret pushBack["optic_ERCO_khk_F", nil, 1000];
        _ret pushBack["optic_ERCO_snd_F", nil, 1000];
        _ret pushBack["30Rnd_45ACP_Mag_SMG_01", nil, 150];
        _ret pushBack["30Rnd_65x39_caseless_mag", "6.5mm 30Rnd Sand", 150];
        _ret pushBack["30Rnd_65x39_caseless_khaki_mag", "6.5mm 30Rnd Khaki", 150];
        _ret pushBack["30Rnd_580x42_Mag_F", nil, 150];
        _ret pushBack["10Rnd_762x54_Mag", nil, 150];
        _ret pushBack["30Rnd_762x39_AK12_Mag_F", nil, 200];
        _ret pushBack["30Rnd_762x39_AK12_Mag_F", nil, 200];
        _ret pushBack["30Rnd_762x39_AK12_Lush_Mag_F", nil, 200];
        _ret pushBack["75rnd_762x39_AK12_Lush_Mag_F", nil, 750];
        _ret pushBack["75rnd_762x39_AK12_Mag_F", nil, 750];
        _ret pushBack["75Rnd_762x39_Mag_F", nil, 750];
        _ret pushBack["muzzle_snds_L", nil, 500];
        _ret pushBack["10Rnd_9x21_Mag", nil, 50];};
    if (_copLevel >= 2) then {_ret pushBack["30Rnd_65x39_caseless_black_mag", "6.5mm 30Rnd Black", 75];
        _ret pushBack["30Rnd_65x39_caseless_msbs_mag", "6.5mm 30Rnd Promet", 75];
        _ret pushBack["20Rnd_556x45_UW_mag", nil, 50];
        _ret pushBack["optic_MRCO", nil, 500];
        _ret pushBack["optic_hamr", nil, 500];
        _ret pushBack["optic_Arco_blk_F", nil, 500];
        _ret pushBack["optic_Arco_AK_blk_F", nil, 500];
        _ret pushBack["optic_ERCO_blk_F", nil, 500];};
    if (_copLevel >= 3) then {_ret pushBack["30Rnd_65x39_caseless_green", "30Rnd 6.5mm Caseless", 150];
        _ret pushBack["150Rnd_556x45_Drum_Mag_F", "5.66 150Rnd Drum", 500];   // owner 2026-06-20 (Payton): SPAR-16S 150rd drum -> Corporal+ (was Sergeant+ / copLevel 4)
    };
    if (_copLevel >= 4) then {_ret pushBack["optic_Yorris", nil, 125];
        _ret pushBack["6Rnd_45ACP_Cylinder", nil, 50];
        _ret pushBack["acc_flashlight_pistol", nil, 125];
        _ret pushBack["100Rnd_65x39_caseless_black_mag", "6.5mm 100Rnd", 1250];   // owner 2026-06-20 (Payton): MX SW 100rd -> Sergeant+ (was Captain+ / copLevel 6)
    };
    if (_copLevel >= 5) then {_ret pushBack["20Rnd_762x51_Mag", nil, 100];
        _ret pushBack["10Rnd_Mk14_762x51_Mag", nil, 100];
        _ret pushBack["11Rnd_45ACP_Mag", nil, 25];
        _ret pushBack["optic_MRD", nil, 125];
        _ret pushBack["optic_MRD_black", nil, 125];};
    if (_copLevel >= 6) then {_ret pushBack["bipod_01_F_blk", nil, 2500];};};
if (_shop isEqualTo "skiptracer") then {_ret pushBack ["muzzle_snds_H", "6.5mm Suppressor", 1500];
    _ret pushBack ["muzzle_snds_M", "5.56mm Suppressor", 1500];
    if (22 in AP_honor_talents) then {_ret pushBack["30Rnd_65x39_caseless_mag", "6.5mm 30Rnd Sand Lethal", 150];
        _ret pushBack["30Rnd_65x39_caseless_khaki_mag", "6.5mm 30Rnd Kakhi Lethal", 150];
        
            _ret pushBack["30Rnd_65x39_caseless_black_mag", "6.5mm 30Rnd Black Lethal", 150];};
    
        _ret pushBack["30Rnd_65x39_caseless_black_mag_Tracer", "6.5mm 30Rnd Black Rubber", 150];};
if (_shop isEqualTo "rebelwep") then {if (AP_ndShop) then {_ret pushBack["RPG7_F", nil, 110000];} else {
        _ret pushBack["RPG7_F", nil, 140000];};};
if (_shop isEqualTo "srt_weapons") then {};
// LooneyBin: suppressors for every caliber as $10,000 weapon addons. The weapon shop already filters
// attachments by the selected weapon's compatibleItems (and skips any with no displayName), so only cans
// that actually fit the chosen gun show up. Rebels get the coloured cans AND (owner 2026-06-13) every
// black can too, all at the same $20k price.
if (_shop isEqualTo "rebelwep") then {{_ret pushBack [_x, nil, 20000];   // owner 2026-06-13: rebel suppressors $10k -> $20k
    } forEach ["muzzle_snds_H_khk_F", "muzzle_snds_H_snd_F", "muzzle_snds_H_hex_F", "muzzle_snds_H_ghex_F",  // 6.5mm
        // owner 2026-06-22: 7.62mm cans (muzzle_snds_B_khk_F/_snd_F) moved to the $80k push below
        "muzzle_snds_338_green", "muzzle_snds_338_sand",                                               // .338
        "muzzle_snds_93mmg_tan",                                                                       // 9.3mm (.408)
        "muzzle_snds_58_wdl_F", "muzzle_snds_58_hex_F",                                                // 5.8mm
        "muzzle_snds_570",                                                                             // 5.7mm (P90 / Type 115)
        "muzzle_snds_L", "muzzle_snds_acp", "muzzle_snds_M",  // 9mm/.45/5.56 black
        // owner 2026-06-13: all BLACK cans added at the same $20k (filtered to the gun by compatibleItems)
        "muzzle_snds_H", "muzzle_snds_H_MG", "muzzle_snds_65_TI_blk_F",   // 6.5mm black (+ MG, + TI)
        "muzzle_snds_338_black",                                          // .338 black
        "muzzle_snds_93mmg",                                              // 9.3mm black
        "muzzle_snds_58_blk_F"                                            // 5.8mm black
    ];
    // owner 2026-06-22: 7.62mm suppressors priced at $80k for civs/rebels (pulled out of the $20k push above).
    { _ret pushBack [_x, nil, 80000]; } forEach ["muzzle_snds_B", "muzzle_snds_B_khk_F", "muzzle_snds_B_snd_F"];};
// owner 2026-06-13: fixed rebel ammo prices. Pushed BEFORE the dynamic mag block so its dedup keeps these
// (Zafir 150rnd box both types @10k; Titan compact AT/AP @190k -- full Titan AA was dropped from the catalog).
if (_shop isEqualTo "rebelwep") then {_ret pushBack ["150Rnd_762x54_Box", "Zafir 150Rnd", 10000];
    // owner 2026-06-13: Zafir tracer box removed (no tracer ammo in the rebel shop -- also stripped by the
    // "tracer" filter at the end of this fn, so this push was redundant + self-cancelling).
    _ret pushBack ["Titan_AT", "Titan Compact (AT)", 190000];
    _ret pushBack ["Titan_AP", "Titan Compact (AP)", 190000];};
// owner 2026-06-20 (Payton): rifle/SMG suppressors are LIEUTENANT+ (copLevel 5) in the regular police armory.
// Sergeant and below get NO cans except the 9mm P07 can (muzzle_snds_L, sold in the scd/all-role/MaxTac
// optics block above). The MaxTac armory keeps every can unconditionally (and a MaxTac-active cop also reads
// _copLevel=6, so they pass the police gate too).
if (_shop isEqualTo "maxtac_weapons" || {_shop isEqualTo "police_weapons" && {_copLevel >= 5}}) then {{_ret pushBack [_x, nil, 10000];
    } forEach ["muzzle_snds_acp",        // .45 ACP
        "muzzle_snds_M",          // 5.56mm
        "muzzle_snds_H",          // 6.5mm
        "muzzle_snds_B",          // 7.62mm
        "muzzle_snds_338_black",  // .338
        "muzzle_snds_93mmg",      // 9.3mm (.408)
        "muzzle_snds_570",        // 5.7mm (P90 / Type 115)
        "muzzle_snds_58_blk_F"    // 5.8mm   (9mm muzzle_snds_L already sold above at $500)
    ];};
// owner 2026-06-20 (Payton): MaxTac-only ammo. The side panel filters ammo by the selected gun's compatibleItems,
// so each only appears when the gun that takes it is selected.
if (_shop isEqualTo "maxtac_weapons") then {
    // Promet GL ("Promet Smoke Launcher") -- SMOKE only (owner: HE removed). White + colours, 1Rnd/3Rnd.
    {_ret pushBack [_x, nil, 250];} forEach ["1Rnd_Smoke_Grenade_shell", "3Rnd_Smoke_Grenade_shell",
        "1Rnd_SmokeRed_Grenade_shell", "1Rnd_SmokeGreen_Grenade_shell", "1Rnd_SmokeYellow_Grenade_shell", "1Rnd_SmokeBlue_Grenade_shell"];
    // Type 115 (arifle_ARX) .50 Beowulf mag + the Promet-SG / undersling-shotgun (arifle_MSBS65_UBS_F) 12-gauge
    // "pods" -- pellets (B_12Gauge_Pellets_Submunition) + slugs.
    _ret pushBack ["10Rnd_50BW_Mag_F", "Type 115 .50 Beowulf", 300];
    _ret pushBack ["2Rnd_12Gauge_Pellets", "Promet 12ga Pellets", 200];
    _ret pushBack ["2Rnd_12Gauge_Slug", "Promet 12ga Slug", 200];};
// LoonyBin (owner): AMS + DMS marksman scopes in BOTH the rebel and MaxSec armories. The side panel
// filters attachments by the selected gun's compatibleItems, so they only show on weapons that fit.
if (_shop in ["rebelwep", "police_weapons", "maxtac_weapons", "med_basic"] && {_ret isEqualType []}) then {
    _ret pushBack ["optic_DMS", nil, 30000];
    _ret pushBack ["optic_AMS", nil, 30000];};
// LooneyBin (#562, 2026-07-03): the red-dot + magnified optics + flashlight/pointer below are the
// Trauma Team (med_basic) shop ONLY. Cops get their optics RANK-GATED in the police block above;
// commit e8affb5 appended these to the shared block, which handed MRCO/HAMR/ARCO/ERCO/MRD to EVERY cop
// rank and bypassed those gates. Scoping to med_basic restores the MaxSec rank gates (TT intent preserved).
if (_shop isEqualTo "med_basic" && {_ret isEqualType []}) then {_ret pushBack ["optic_ACO", nil, 250];
    _ret pushBack ["optic_ACO_smg", nil, 250];
    _ret pushBack ["optic_Holosight", nil, 250];
    _ret pushBack ["optic_Holosight_blk_F", nil, 250];
    _ret pushBack ["optic_Holosight_smg", nil, 250];
    _ret pushBack ["optic_Holosight_smg_blk_F", nil, 250];
    _ret pushBack ["optic_MRCO", nil, 750];
    _ret pushBack ["optic_hamr", nil, 750];
    _ret pushBack ["optic_Hamr_khk_F", nil, 750];
    _ret pushBack ["optic_Arco", nil, 750];
    _ret pushBack ["optic_Arco_blk_F", nil, 750];
    _ret pushBack ["optic_ERCO_blk_F", nil, 750];
    _ret pushBack ["optic_MRD", nil, 125];
    _ret pushBack ["optic_MRD_black", nil, 125];
    _ret pushBack ["acc_flashlight", nil, 125];
    _ret pushBack ["acc_pointer_IR", nil, 125];};
// Loone
// LooneyBin 2026-06-10: ammo for the full gun catalog. The side panel (fn_weaponShopSelection) shows
// addons that are COMPATIBLE with the selected weapon, so adding EVERY gun's magazines here lets any
// new gun find its ammo. Mags $100 / launcher missiles $25k. Launcher missiles stay REBEL-only.
// Built once from CfgWeapons, deduped against whatever the case already returned.
if (_shop in ["rebelwep", "police_weapons", "maxtac_weapons", "med_basic"] && {_ret isEqualType []}) then {
    if (isNil "AP_dynShopMags") then {AP_dynShopMags = [];
        private _seenM = [];
        private _cfgW = configFile >> "CfgWeapons";
        for "_i" from 0 to ((count _cfgW) - 1) do {private _c = _cfgW select _i;
            if (isClass _c && {(getNumber (_c >> "scope")) isEqualTo 2}) then {private _cn = configName _c;
                private _type = getNumber (_c >> "type");
                if (_type in [1, 2, 4]) then {private _isL = _type isEqualTo 4;
                    if (!_isL || {(_cn find "Titan") > -1 || {(_cn find "RPG7") > -1}}) then {
                        private _mp = if (_isL) then { 25000 } else { 100 }; {private _mag = _x;
                            if !(_mag in _seenM) then {_seenM pushBack _mag;
                                AP_dynShopMags pushBack [_mag, _mp, _isL];};} forEach (getArray (_c >> "magazines"));};};};};}; {
        _x params ["_mCls", "_mPrice", ["_mL", false]];
        if (_mL && {_shop in ["police_weapons", "maxtac_weapons", "med_basic"]}) then {} else {
            if ((_ret findIf { (_x select 0) isEqualTo _mCls }) isEqualTo -1) then {_ret pushBack [_mCls, nil, _mPrice];};};
    } forEach AP_dynShopMags;};
// owner 2026-07-03: MaxTac Titan AA missiles at $5000 (the launcher is $1000 in the MaxTac armory). The generic
// launcher-missile block above SKIPS launcher ammo for police/maxtac, so Titan_AA is added explicitly here. It
// only appears when the Titan AA launcher is the selected weapon (compatibleItems filter), which only MaxTac can buy.
if (_shop in ["maxtac_weapons", "police_weapons"] && {_ret isEqualType []}) then {
    if ((_ret findIf { (_x isEqualType []) && {(_x select 0) isEqualTo "Titan_AA"} }) isEqualTo -1) then {
        _ret pushBack ["Titan_AA", "Titan AA Missile", 5000];};};
// owner 2026-06-13: rebels/gangs get NO "downing" tracer ammo. fn_handleDamage treats ANY mag with "Tracer"
// in its name as a stun/down round (MK200 red-tracer box, etc.), so a rebel could down instead of kill.
// Strip every tracer mag from the rebel + turf ammo lists (lethal non-tracer boxes stay; optics/suppressors
// have no "tracer" in their classnames so they pass untouched).
if (_shop in ["rebelwep", "turf"]) then {_ret = _ret select {private _keep = true;
        if ((_x isEqualType []) && {(_x select 0) isEqualType ""}) then {private _ln = toLower (_x select 0);
            // (a) classic "tracer"-named mags. (b) owner 2026-06-24: COLOR-named tracer BELTS that DON'T contain
            // "tracer" (e.g. 5000Rnd_762x51_Yellow_Belt, *_Red/_Green belts) leaked into rebel at the $100 dynamic
            // default = cheap stun/down ammo. Strip a belt/box mag whose name carries a tracer colour (red/yellow/
            // green). Lethal BALL belts (200Rnd_65x39_cased_Box, 150Rnd_762x54_Box, 5000Rnd_762x51_Belt) have no
            // colour -> kept. Cosmetic mag colours (khaki/black/sand/camo) aren't tracer colours -> unaffected.
            if ((_ln find "tracer") >= 0) then { _keep = false; };
            if (((_ln find "belt") >= 0) || {(_ln find "box") >= 0}) then {
                if (((_ln find "red") >= 0) || {(_ln find "yellow") >= 0} || {(_ln find "green") >= 0}) then { _keep = false; };};};
        _keep};};
// ---------------------------------------------------------------------------------------------
// ECONOMY 2026-09-05: attachments are priced by TIER, and the civilian side gets the tier at all.
//
// Walking this file shop by shop turned up that the DMS and the AMS were sold at exactly one
// counter -- the MaxTac armory -- and so was every suppressor in the game (snds_L, snds_H, snds_M),
// with a single 9 mm can at the medic shop as the only exception. The rebel, turf, skiptracer and
// bounty catalogues stopped at a 2x ARCO for $1,000 and carried NO suppressor at any price, so a
// rebel buying the $15,300 DMR could not put marksman glass on it or quiet it. The attachment tier
// the gun ladder is built around existed for one faction.
//
// Owner call: the can is the tier gate, not the gun. A 6.5-and-up suppressor costs 2.7x the rifle it
// screws onto, deliberately -- suppressed play is an expensive commitment rather than a default.
//
// Ordered prefix match, FIRST hit wins, so the specific families are listed ahead of the general
// ones (65_TI before the plain 6.5 can, H_MG/H_SW before snds_h). Case-insensitive, because the
// shipped configs are not consistent about it. A row already priced 0 is free SRT/MaxTac issue and
// is left alone.
private _attachTiers = [
    // --- suppressors, 6.5 mm and up: $20,000 --------------------------------------------------
    ["muzzle_snds_65_ti",  35000],   // thermal-suppressing; strictly better than the plain 6.5 can,
                                     // so it prices above it or the plain one becomes dead stock
    ["muzzle_snds_h_mg",   20000],   // 6.5 MG (Mk200, MX SW)
    ["muzzle_snds_h_sw",   20000],
    ["muzzle_snds_h",      20000],   // 6.5 rifle (MX family, Katiba, Promet)
    ["muzzle_snds_b",      20000],   // 7.62x51 (AK-12, DMR-01, DMR-03, EBR, SPAR-17, RPK-12)
    ["muzzle_snds_338",    20000],   // .338 (Mar-10, SPMG)
    ["muzzle_snds_93mmg",  20000],   // 9.3 mm (Navid)
    ["muzzle_tma_65",      20000],
    // --- suppressors below the 6.5 line: cheap, on purpose ------------------------------------
    ["muzzle_snds_58",      2500],   // 5.8 mm CTAR -- the cheapest suppressed rifle in the game
    ["muzzle_snds_570",     1500],   // 5.7 mm P90
    ["muzzle_snds_m",       1500],   // 5.56
    ["muzzle_snds_acp",     1000],   // .45 ACP
    ["muzzle_snds_l",       1000],   // 9 mm
    // --- optics -------------------------------------------------------------------------------
    ["optic_lrps",         60000],   // 6-25x
    ["optic_dms",          30000],   // 2.0-4.0x, zeroes from 100 m, two units lighter than the rest
    ["optic_sos",          30000],   // 2.3-5.0x
    ["optic_ams",          30000],   // 3.3-10x
    ["optic_khs",          30000],   // 4.7-11x
    ["optic_arco",          2500],   // 1x / 2x combined
    ["optic_mrco",          2500],
    ["optic_hamr",          2500],
    ["optic_erco",          2500],
    ["optic_aco",            500],   // 1x reflex
    ["optic_holosight",      500],
    ["optic_mrd",            500],
    ["optic_yorris",         500]
];
if (_ret isEqualType []) then {
    {
        if (_x isEqualType [] && {count _x >= 3} && {(_x select 2) > 0}) then {
            private _ln = toLower (_x select 0);
            private _i = _attachTiers findIf { (_ln find (_x select 0)) isEqualTo 0 };
            if (_i > -1) then { _x set [2, (_attachTiers select _i) select 1]; };
        };
    } forEach _ret;
    // The civilian-side counters get the marksman tier and the cans that fit what they already sell.
    // Gates are unchanged -- rebel training and the bounty licence still decide who reaches the shop.
    if (_shop in ["rebelwep", "turf", "skiptracer", "bounty"]) then {
        _ret append [
            ["optic_DMS", nil, 30000], ["optic_SOS", nil, 30000],
            ["optic_AMS", nil, 30000], ["optic_KHS_blk", nil, 30000],
            ["optic_LRPS", nil, 60000],
            ["muzzle_snds_L", nil, 1000], ["muzzle_snds_acp", nil, 1000],
            ["muzzle_snds_570", nil, 1500], ["muzzle_snds_M", nil, 1500],
            ["muzzle_snds_58_blk_F", "5.8mm Suppressor", 2500],
            ["muzzle_snds_H", nil, 20000], ["muzzle_snds_H_MG", nil, 20000],
            ["muzzle_snds_B", nil, 20000], ["muzzle_snds_338_black", nil, 20000],
            ["muzzle_snds_93mmg", nil, 20000]
        ];
    };
    // MaxTac already stocked the DMS and the AMS; give the tier its other two members.
    if (_shop isEqualTo "maxtac_weapons") then {
        _ret append [["optic_SOS", nil, 30000], ["optic_KHS_blk", nil, 30000],
                     ["muzzle_snds_B", nil, 20000]];
    };
};
// LooneyBin Economy: owner overrides for ammo/attachment prices (weap p0 = price, entry index 2)
{if (_x isEqualType [] && {count _x >= 3}) then {private _ov = ["weap", _x select 0] call AP_fnc_priceOv;
        if (_ov isNotEqualTo [] && {(_ov select 2) >= 0}) then { _x set [2, _ov select 2]; };};} forEach _ret;
_ret;
