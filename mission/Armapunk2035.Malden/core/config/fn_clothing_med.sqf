params[["_filter", 0, [0]]];
if ((call AP_medicLevel) isEqualTo 0) then {_ret = "You are not a medical professional!";};
// TT "EMT Volunteer" (level-99 sentinel) -> treat as tier 1 for GEAR gates so a volunteer gets only basic
// kit, never high-rank combat armor (raw 99 >= N would pass every check). The isEqualTo
// 0/7 checks deliberately keep raw AP_medicLevel (they handle 99 / volunteer explicitly).
private _glvl = if ((call AP_medicLevel) isEqualTo 99) then {1} else {call AP_medicLevel};
// TT rank for the rank-ISSUED military kit added below. Volunteer (99) -> 0 so volunteers get NONE of it
// (they keep ONLY the current medic kit). Real ranks 1-7 pass their tier gates; cumulative (>= N).
private _ttClothRank = if ((call AP_medicLevel) isEqualTo 99) then {0} else {call AP_medicLevel};
ctrlSetText[3103, "Trauma Team Locker"];
private _ret = [];
switch (_filter) do {case 0: {if (_glvl >= 1) then {
                _ret pushBack["U_Marshal", "Fire Uniform", 25];};
            if (_glvl >= 2) then {};
            if (_glvl >= 3) then {_ret pushBack["U_C_CBRN_Suit_01_White_F", "Hazmat Uniform", 25];};
            if (_glvl >= 3) then {_ret pushBack["U_B_HeliPilotCoveralls", "Pilot Coveralls", 25];};
            if (_glvl >= 3) then {_ret pushBack["U_B_Wetsuit", "Mustang Suit", 25];};
            if (_glvl >= 3) then {_ret pushBack["U_C_ConstructionCoverall_Red_F", "Bunker Uniform", 25];};
            if (_glvl >= 4) then {_ret pushBack["U_B_CombatUniform_mcam", "Combat Uniform", 25];};
            // --- TT rank-issued uniforms (non-volunteer; cumulative) ---
            if (_ttClothRank >= 1) then {_ret pushBack["U_B_CombatUniform_mcam", "Combat Fatigues (MTP)", 25];
                _ret pushBack["U_B_CombatUniform_mcam_tshirt", "Combat Fatigues (MTP) (Tee)", 25];
                _ret pushBack["U_B_CombatUniform_mcam_vest", "Recon Fatigues (MTP)", 25];
                _ret pushBack["U_B_HeliPilotCoveralls", "Pilot Coveralls [NATO]", 25];
                _ret pushBack["U_B_Wetsuit", "Wetsuit [NATO]", 25];};
            if (_ttClothRank >= 4) then {_ret pushBack["U_B_ParadeUniform_01_US_F", "Parade Uniform [US]", 25];};
            if (_ttClothRank >= 6) then {_ret pushBack["U_B_ParadeUniform_01_US_decorated_F", "Parade Uniform (Decorated) [US]", 25];};};
    case 1: {_ret = [["H_Cap_surfer", nil, 25], ["H_Cap_red", nil, 25], ["H_Cap_blu", nil, 25], ["H_Cap_oli", nil, 25],
                ["H_Cap_grn", nil, 25], ["H_Cap_grn_BI", nil, 25], ["H_Cap_tan", nil, 25], ["H_Cap_blk", nil, 25],
                ["H_Cap_headphones", nil, 25], ["H_Cap_blk_CMMG", nil, 25], ["H_Cap_blk_ION", nil, 25], ["H_Cap_oli_hs", nil, 25],
                ["H_Cap_press", nil, 25], ["H_Cap_usblack", nil, 25], ["H_Booniehat_grn", nil, 25], ["H_Booniehat_tan", nil, 25],
                ["H_Booniehat_dirty", nil, 25], ["H_Bandanna_surfer", nil, 25], ["H_Bandanna_surfer_blk", nil, 25],
                ["H_Bandanna_surfer_grn", nil, 25], ["H_Bandanna_khk", nil, 25], ["H_Bandanna_cbr", nil, 25], ["H_Bandanna_sgg", nil, 25],
                ["H_Bandanna_blu", nil, 25], ["H_Bandanna_sand", nil, 25], ["H_Bandanna_gry", nil, 25], ["H_StrawHat", nil, 25],
                ["H_StrawHat_dark", nil, 25], ["H_Hat_blue", nil, 25], ["H_Hat_brown", nil, 25], ["H_Hat_grey", nil, 25],
                ["H_Hat_tan", nil, 25], ["H_Watchcap_blk", nil, 25], ["H_Watchcap_khk", nil, 25], ["H_Watchcap_sgg", nil, 25],
                ["H_Watchcap_camo", nil, 25], ["H_Hat_checker", nil, 25], ["H_Cap_Black_IDAP_F", nil, 25], ["H_Cap_Orange_IDAP_F", nil, 25],
                ["H_Cap_White_IDAP_F", nil, 25], ["H_EarProtectors_black_F", nil, 25], ["H_Hat_Tinfoil_F", nil, 25]];
            // LooneyBin: TT prestige-gated helmets
            if (3 in AP_medic_talents) then { _ret pushBack ["H_Helmet_Skate", "Skate Helmet", 1000]; };   // Mommy's special boy
            if (5 in AP_medic_talents) then {                                                               // Mild Concussion
                _ret pushBack ["H_PilotHelmetHeli_B", "Pilot Helmet", 1000];
                _ret pushBack ["H_CrewHelmetHeli_B", "Crew Helmet", 1000];};
            if (110 in AP_side_talents) then {if (_glvl >= 4) then {_ret pushBack["H_PASGT_basic_blue_F", "Balistic Helmet", 1000];};
                if (_glvl >= 5) then {_ret pushBack["H_PASGT_basic_white_F", "Balistic Helmet", 1000];};};
            
                // LooneyBin TT patch: Berets available from SGT (rank 3) and above only.
                if (_ttClothRank >= 3) then {_ret pushBack["H_Beret_blk", "Stylish Beret", 50];
                    _ret pushBack["H_Beret_EAF_01_F", "Fancy Beret", 50];
                    _ret pushBack["H_Beret_02", "Executive Beret", 50];
                    _ret pushBack["H_Beret_Csat_01_F", "Red Beret", 50];
                    _ret pushBack["H_Hat_Safari_olive_F", "Safari Hat (Olive)", 50];
                    _ret pushBack["H_Hat_Safari_sand_F", "Safari Hat (Sand)", 50];
                    _ret pushBack["H_Beret_Colonel", "Master Beret", 50];
                    _ret pushBack["H_Beret_gen_F", "Exclusive Beret", 50];};
                _ret pushBack["H_HeadBandage_clean_F", nil, 50];
            
                _ret pushBack["H_HeadBandage_stained_F", nil, 50];
            
                _ret pushBack["H_HeadBandage_bloody_F", nil, 50];
            // --- TT rank-issued headgear (non-volunteer; cumulative). Berets gated to SGT(3)+ above ---
            if (_ttClothRank >= 1) then {_ret pushBack["H_PilotHelmetFighter_B", "Pilot Helmet [NATO]", 50];};
            if (_ttClothRank >= 2) then {_ret pushBack["H_HelmetB_light", "Light Combat Helmet", 50];
                // LooneyBin TT patch: Carrier Lite (Green) vest added for CPL+
                _ret pushBack["V_PlateCarrierL_CTRG", "Carrier Lite (Green)", 500];};
            if (_ttClothRank >= 4) then {_ret pushBack["H_ParadeDressCap_01_US_F", "Parade Cap [US]", 50];
                _ret pushBack["H_HelmetSpecB_snakeskin", "Enhanced Combat Helmet (Snakeskin)", 50];};};
    case 2: {_ret = [["G_Aviator", nil, 10], ["G_Tactical_Black", "Tactical Shades", 10], ["G_Tactical_Clear", "Tactical Glasses", 10],
                ["G_Combat", nil, 10], ["G_Combat_Goggles_tna_F", nil, 10], ["G_Lowprofile", nil, 10], ["G_Shades_Black", nil, 10],
                ["G_Shades_Blue", nil, 10], ["G_Spectacles", nil, 10], ["G_Spectacles_Tinted", nil, 10], ["G_Sport_Blackred", nil, 10],
                ["G_Sport_Checkered", nil, 10], ["G_Sport_Blackyellow", nil, 10], ["G_Sport_BlackWhite", nil, 10],
                ["G_Sport_Greenblack", nil, 10], ["G_Sport_Red", nil, 10], ["G_Squares", nil, 10], ["G_Squares_Tinted", nil, 10],
                ["G_Lady_Blue", nil, 10], ["G_Lady_Red", nil, 10], ["G_Lady_Mirror", nil, 10], ["G_Lady_Dark", nil, 10],
                ["G_Respirator_blue_F", "Blue SARS mask", 10], ["G_Respirator_white_F", "White SARS mask", 10],
                ["G_Respirator_yellow_F", "Yellow SARS mask", 10]];
            
                _ret pushBack["G_EyeProtectors_F", "Safety Goggles", 10];
                _ret pushBack["G_EyeProtectors_Earpiece_F", "Safety Goggles (Nerd)", 10];
            
                _ret pushBack["G_Goggles_VR", nil, 10];
            if (_glvl >= 3) then {_ret pushBack["G_AirPurifyingRespirator_02_sand_F", "SCBA Mask", 200];
                _ret pushBack["G_B_Diving", nil, 100];};
            
                _ret pushBack["G_AirPurifyingRespirator_02_olive_F", nil, 200];
            
                _ret pushBack["G_AirPurifyingRespirator_02_black_F", nil, 200];
            
                _ret pushBack["G_AirPurifyingRespirator_01_F", nil, 200];
            
                _ret pushBack["G_RegulatorMask_F", "SCBA Mask", 200];
                _ret pushBack["G_EyeProtectors_F", "Safety Goggles", 10];
                _ret pushBack["G_EyeProtectors_Earpiece_F", "Safety Goggles (Nerd)", 10];
            
                _ret pushBack["G_Goggles_VR", nil, 10];};
    case 3: {_ret = [["V_Safety_yellow_F", nil, 100], ["V_Safety_orange_F", nil, 100], ["V_Safety_blue_F", nil, 100],
                ["V_Plain_crystal_F", "Training Vest", 100]];
            // LooneyBin: TT prestige vest tiers
            if (1 in AP_medic_talents) then {                          // Field Medic -> Tier 2
                _ret pushBack ["V_PlateCarrier1_rgr", "Tier 2 Carrier (Green)", 1000];
                _ret pushBack ["V_PlateCarrier1_blk", "Tier 2 Carrier (Black)", 1000];};
            if (2 in AP_medic_talents) then {                          // Deer with Kevlar -> Tier 3
                _ret pushBack ["V_PlateCarrier2_rgr", "Tier 3 Carrier (Green)", 2000];
                _ret pushBack ["V_PlateCarrierSpec_rgr", "Tier 3 Carrier (Spec)", 2000];};
            if (4 in AP_medic_talents) then {                          // Luke Cage -> Tier 4 (EOD + GL)
                _ret pushBack ["V_PlateCarrierGL_rgr", "Tier 4 GL Carrier", 4000];
                _ret pushBack ["V_HarnessOGL_brn", "Tier 4 EOD Harness", 4000];};
            if (109 in AP_side_talents) then {if (_glvl >= 2) then {_ret pushBack["V_Deckcrew_yellow_F", nil, 350];
                    _ret pushBack["V_Deckcrew_red_F", nil, 350];
                    _ret pushBack["V_Deckcrew_white_F", nil, 350];
                    _ret pushBack["V_Deckcrew_blue_F", nil, 350];};
                if (_glvl >= 3) then {_ret pushBack["V_TacVestIR_blk", nil, 250];
                    _ret pushBack["V_RebreatherB", nil, 250];};
                if (_glvl >= 4) then {_ret pushBack["V_PlateCarrier1_blk", nil, 1000];};
                if (_glvl >= 5) then {_ret pushBack["V_EOD_blue_F", nil, 500];};
                 if (_glvl >= 6 || (call AP_medicLevel) isEqualTo 7) then {_ret pushBack["V_PlateCarrierGL_blk", nil, 1500];};
                
                    _ret pushBack["V_LegStrapBag_coyote_F", nil, 350];
                
                    _ret pushBack["V_LegStrapBag_black_F", nil, 350];};
            // --- TT rank-issued vests (non-volunteer; cumulative) ---
            if (_ttClothRank >= 1) then {_ret pushBack["V_TacVest_oli", "Tactical Vest (Olive)", 100];
                _ret pushBack["V_Chestrig_oli", "Chest Rig (Olive)", 100];
                _ret pushBack["V_RebreatherB", "Rebreather [NATO]", 250];};
            if (_ttClothRank >= 3) then {_ret pushBack["V_PlateCarrier1_rgr", "Carrier Lite (Green)", 1000];};
            if (_ttClothRank >= 6) then {_ret pushBack["V_PlateCarrierGL_rgr", "Carrier GL Rig (Green)", 1500];};};
    case 4: {_ret = [["B_AssaultPack_dgtl", nil, 250], ["B_AssaultPack_ocamo", nil, 250], ["B_AssaultPack_blk", nil, 250],
                ["B_AssaultPack_cbr", nil, 250], ["B_AssaultPack_mcamo", nil, 250], ["B_AssaultPack_rgr", nil, 250],
                ["B_AssaultPack_khk", nil, 250], ["B_AssaultPack_sgg", nil, 250], ["B_AssaultPack_tna_F", nil, 250],
                ["B_AssaultPack_eaf_F", nil, 250], ["B_AssaultPack_wdl_F", nil, 250], ["B_AssaultPack_Kerry", nil, 250],
                ["B_FieldPack_ocamo", nil, 250], ["B_FieldPack_khk", nil, 250], ["B_FieldPack_oucamo", nil, 250],
                ["B_FieldPack_cbr", nil, 250], ["B_FieldPack_blk", nil, 250], ["B_FieldPack_ghex_F", nil, 250], ["B_Kitbag_rgr", nil, 250],
                ["B_Kitbag_cbr", nil, 250], ["B_Kitbag_mcamo", nil, 250], ["B_Kitbag_sgg", nil, 250], ["B_TacticalPack_ocamo", nil, 250],
                ["B_TacticalPack_oli", nil, 250], ["B_Bergen_sgg", nil, 250], ["B_Bergen_mcamo", nil, 250], ["B_Bergen_rgr", nil, 250],
                ["B_Bergen_blk", nil, 250], ["B_Carryall_oli", nil, 350], ["B_Carryall_ocamo", nil, 350], ["B_Carryall_oucamo", nil, 350],
                ["B_Carryall_mcamo", nil, 350], ["B_Carryall_cbr", nil, 350], ["B_Carryall_ghex_F", nil, 350], ["B_Carryall_khk", nil, 350],
                ["B_Carryall_taiga_F", nil, 350], ["B_Carryall_eaf_F", nil, 350], ["B_Carryall_green_F", nil, 350],
                ["B_Carryall_wdl_F", nil, 350], ["B_Carryall_blk", nil, 350], ["B_ViperHarness_blk_F", nil, 350],
                ["B_ViperHarness_ghex_F", nil, 350], ["B_ViperHarness_hex_F", nil, 350], ["B_ViperHarness_khk_F", nil, 350],
                ["B_ViperHarness_oli_F", nil, 350], ["B_ViperLightHarness_blk_F", nil, 300], ["B_ViperLightHarness_ghex_F", nil, 300],
                ["B_ViperLightHarness_hex_F", nil, 300], ["B_ViperLightHarness_khk_F", nil, 300], ["B_ViperLightHarness_oli_F", nil, 300],
                ["B_RadioBag_01_oucamo_F", nil, 250], ["B_RadioBag_01_digi_F", nil, 250], ["B_RadioBag_01_mtp_F", nil, 250],
                ["B_Messenger_Black_F", nil, 200], ["B_Messenger_Coyote_F", nil, 200], ["B_Messenger_Gray_F", nil, 200],
                ["B_Messenger_Olive_F", nil, 200], ["B_LegStrapBag_olive_F", nil, 350]];
            if (_glvl >= 3) then {_ret pushBack["B_SCBA_01_F", nil, 100];};
            if (9 in AP_medic_talents) then {                                          // Do drones dream... (medic prestige 9) -> revive drone kit
                _ret pushBack["I_UAV_06_medical_backpack_F", "Medic Revive Drone", 20000];};
            
                _ret pushBack["B_CivilianBackpack_01_Everyday_IDAP_F", nil, 150];
                _ret pushBack["B_CivilianBackpack_01_Sport_Red_F", nil, 150];
            
                _ret pushBack["B_RadioBag_01_hex_F", nil, 250];
                _ret pushBack["B_Carryall_khk", "Black Carryall Backpack", 250, "A3\weapons_f\ammoboxes\bags\data\backpack_tortila_blk_co.paa"];
                _ret pushBack["B_CivilianBackpack_01_Everyday_Astra_F", nil, 150];
                _ret pushBack["B_CivilianBackpack_01_Sport_Blue_F", nil, 150];
            
                _ret pushBack["B_RadioBag_01_tropic_F", nil, 250];
                _ret pushBack["B_RadioBag_01_eaf_F", nil, 250];
                _ret pushBack["B_RadioBag_01_ghex_F", nil, 250];
                _ret pushBack["B_CivilianBackpack_01_Everyday_Vrana_F", nil, 150];
                _ret pushBack["B_CivilianBackpack_01_Sport_Green_F", nil, 150];
            
                _ret pushBack["B_RadioBag_01_wdl_F", nil, 250];
                _ret pushBack["B_CivilianBackpack_01_Everyday_Black_F", nil, 150];
            
                _ret pushBack["B_RadioBag_01_black_F", nil, 250];
                _ret pushBack["B_LegStrapBag_coyote_F", nil, 350];
            
                _ret pushBack["B_LegStrapBag_black_F", nil, 350];
            
                _ret pushBack["B_Carryall_khk", "Hiker's Backpack", 250, "images\b_carryall_hiker.jpg"];
            
                _ret pushBack["B_AssaultPack_blk", "Blue Assault Pack", 250, "images\b_assaultpack_blue.jpg"];
            
                _ret pushBack["B_AssaultPack_khk", "Green Assault Pack", 250, "images\b_assaultpack_green.jpg"];
            
                _ret pushBack["B_AssaultPack_sgg", "Orange Assault Pack", 250, "images\b_assaultpack_orange.jpg"];
            
                _ret pushBack["B_AssaultPack_wdl_F", "Red Assault Pack", 250, "images\b_assaultpack_red.jpg"];
            
                _ret pushBack["B_AssaultPack_rgr", "Purple Assault Pack", 250, "images\b_assaultpack_purple.jpg"];};
    case 5: {_ret = [];
            for "_i"
            from 0 to 4 do {_ret append([_i] call AP_fnc_clothing_med);};};}; _ret ;
