params[["_filter", 0, [0]]];
private _titleText =
if (license_civ_bounty) then {"Rita's Skiptracer Shop"} else {"Mohammed's Jihadi Shop"};
if (AP_ndShop) then {_titleText = _titleText + (format[" - %1 ND", [AP_ndStr] call AP_fnc_ndText])};
ctrlSetText[3103, _titleText];
private _ret = [];
switch (_filter) do {case 0: {_ret = [["U_IG_Guerilla1_1", nil, 300], ["U_IG_leader", nil, 300], ["U_I_G_resistanceLeader_F", nil, 300],
                ["U_I_G_Story_Protagonist_F", nil, 300], ["U_I_CombatUniform", nil, 300], ["U_I_CombatUniform_tshirt", nil, 300],
                ["U_I_OfficerUniform", nil, 300], ["U_O_CombatUniform_oucamo", nil, 6000], ["U_OG_Guerrilla_6_1", nil, 300],
                ["U_B_survival_uniform", nil, 1000], ["U_MillerBody", nil, 300], ["U_KerryBody", nil, 300],
                ["U_B_CombatUniform_mcam", nil, 300], ["U_B_CombatUniform_mcam_tshirt", nil, 300],
                ["U_B_CombatUniform_mcam_vest", nil, 300], ["U_B_CTRG_Soldier_F", nil, 300], ["U_B_CTRG_Soldier_3_F", nil, 300],
                ["U_B_CTRG_Soldier_2_F", nil, 300], ["U_B_CTRG_Soldier_urb_1_F", nil, 300], ["U_B_CTRG_Soldier_urb_2_F", nil, 300],
                ["U_B_CTRG_Soldier_urb_3_F", nil, 300], ["U_I_C_Soldier_Para_1_F", nil, 300], ["U_I_C_Soldier_Para_2_F", nil, 300],
                ["U_I_C_Soldier_Para_3_F", nil, 300], ["U_I_C_Soldier_Para_4_F", nil, 300], ["U_I_C_Soldier_Para_5_F", nil, 300],
                ["U_B_CTRG_1", nil, 1000], ["U_B_CTRG_2", nil, 1000], ["U_B_CTRG_3", nil, 1000], ["U_C_CBRN_Suit_01_Blue_F", nil, 300],
                ["U_C_CBRN_Suit_01_White_F", nil, 300], ["U_I_E_Uniform_01_shortsleeve_F", nil, 300],
                ["U_I_E_Uniform_01_sweater_F", nil, 300], ["U_I_E_Uniform_01_tanktop_F", nil, 300],
                ["U_B_CombatUniform_mcam_wdl_f", nil, 300], ["U_B_CombatUniform_tshirt_mcam_wdL_f", nil, 300], ["U_Tank_green_F", nil, 300],
                ["U_I_L_Uniform_01_camo_F", nil, 300], ["U_I_L_Uniform_01_deserter_F", nil, 300],
                ["U_B_CombatUniform_vest_mcam_wdl_f", nil, 300], ["U_B_Wetsuit", nil, 250]];
            _ret pushBack["U_I_GhillieSuit", nil, 1500];
            _ret pushBack["U_B_FullGhillie_sard", nil, 1500];
            _ret pushBack["U_B_FullGhillie_ard", nil, 1500];
            _ret pushBack["U_B_FullGhillie_lsh", nil, 1500];
            _ret pushBack["U_B_T_FullGhillie_tna_F", nil, 1500];
            _ret pushBack["U_O_R_Gorka_01_brown_F", nil, 6000];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit adidas (Tan/Black)", 6000, "images\craterewards\uniform1\granit_loonydidas_tan.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit adidas (Camo/Tan)", 6000, "images\craterewards\uniform1\granit_loonydidas_camo.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit adidas (White/Camo)", 6000, "images\craterewards\uniform1\granit_loonydidas_white.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit adidas (Green/Black)", 6000, "images\craterewards\uniform1\granit_loonydidas_green.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit adidas (Orange/Black)", 6000, "images\craterewards\uniform1\granit_loonydidas_orange.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit (Graffiti)", 6000, "images\craterewards\uniform1\granit_graffiti.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit (Electric)", 6000, "images\craterewards\uniform1\granit_electric.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit (Toxic)", 6000, "images\craterewards\uniform1\granit_toxic.jpg"];
            
                _ret pushBack["U_O_R_Gorka_01_brown_F", "Granit (Off-White)", 6000, "images\craterewards\uniform1\granit_off-white.jpg"];
            
            if (32 in AP_achievements) then {
                _ret pushBack["U_O_OfficerUniform_ocamo", "Desert 6 Color", 300, "images\o_officer_desert.jpg"];};
            
                _ret pushBack["U_O_CombatUniform_ocamo", nil, 6000];
            
                _ret pushBack["U_O_PilotCoveralls", nil, 5000];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Dark Camo)", 5000, "images\lc5_coveralls.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Pink Camo)", 5000, "images\covs_pink_camo.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Purple Camo)", 5000, "images\covs_purple_camo.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Red Camo)", 5000, "images\covs_red_camo.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Orange Camo)", 5000, "images\covs_orange_camo.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Green Camo)", 5000, "images\covs_green_camo.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Blue Camo)", 5000, "images\covs_blue_camo.jpg"];
                
                    _ret pushBack["U_O_PilotCoveralls", "Pilot Coveralls (Toxic)", 5000, "images\craterewards\retribution\toxiccsats.jpg"];
                
                _ret pushBack["U_B_T_Soldier_F", nil, 2000];
            
                _ret pushBack["U_B_Wetsuit", "Dark Water Wetsuit", 250, "images\lc4_dark_1.jpg"];
            
                _ret pushBack["U_C_Poloshirt_salmon", "Hawaiian", 50, "images\c_poloshirt_flowers.jpg"];
                _ret pushBack["U_C_ArtTShirt_01_v6_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v1_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v3_F", nil, 50];
            
                _ret pushBack["U_C_ArtTShirt_01_v5_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v2_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v4_F", nil, 50];
            
                _ret pushBack["U_C_Uniform_Scientist_02_formal_F", nil, 50];
                _ret pushBack["U_I_E_ParadeUniform_01_LDF_F", nil, 300];
                _ret pushBack["U_I_E_ParadeUniform_01_LDF_decorated_F", nil, 300];
                _ret pushBack["U_I_E_Uniform_01_officer_F", nil, 300];
                _ret pushBack["U_I_E_Uniform_01_coveralls_F", nil, 300];
            
                _ret pushBack["U_O_ParadeUniform_01_CSAT_F", nil, 300];
                _ret pushBack["U_O_ParadeUniform_01_CSAT_decorated_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_blue_F", nil, 300];
                _ret pushBack["U_B_CBRN_Suit_01_Wdl_F", nil, 300];
                _ret pushBack["U_B_CBRN_Suit_01_MTP_F", nil, 300];
                _ret pushBack["U_B_CBRN_Suit_01_Tropic_F", nil, 300];
                _ret pushBack["U_O_Wetsuit", nil, 250];
            
                _ret pushBack["U_C_Journalist", nil, 50];
                _ret pushBack["U_B_ParadeUniform_01_US_F", nil, 300];
                _ret pushBack["U_B_ParadeUniform_01_US_decorated_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_khaki_F", nil, 300];
                _ret pushBack["U_O_R_Gorka_01_camo_F", nil, 6000];
                _ret pushBack["U_I_Wetsuit", nil, 250];
            
                _ret pushBack["U_C_Uniform_Scientist_01_F", nil, 50];
                _ret pushBack["U_I_ParadeUniform_01_AAF_F", nil, 300];
                _ret pushBack["U_I_ParadeUniform_01_AAF_decorated_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_gray_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_tshirt_gray_F", nil, 300];
            
                _ret pushBack["U_B_Protagonist_VR", "Blue VR Suit", 200];
                _ret pushBack["U_O_Protagonist_VR", "Red VR Suit", 200];
                _ret pushBack["U_I_Protagonist_VR", "Green VR Suit", 200];
                _ret pushBack["U_C_FormalSuit_01_black_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_tshirt_black_F", nil, 300];
                _ret pushBack["U_O_R_Gorka_01_black_F", nil, 6000];
                _ret pushBack["U_C_E_LooterJacket_01_F", nil, 50];
            
                _ret pushBack["U_C_Uniform_Scientist_02_F", nil, 50];
            
            if ((call AP_adminLevel) >= 3) then {};};
    case 1: {_ret = [
                // ECONOMY 2026-09-05: across 41 headgear rows the only item with any ballistic value at
                // all was the skate helmet (4 armour). The street could not buy a real helmet at any
                // price while MaxSec bought a 10-armour one for $1,000. These carry no price of their own
                // -- fn_clothingFilter bands every armoured item from its own HitpointsProtectionInfo, so
                // the 6-armour lids land at $1,400 and the 10-armour ones at $2,500. The 1 below is a
                // non-zero placeholder: a 0 would read as free faction issue and be left alone.
                ["H_HelmetB", "Combat Helmet", 1], ["H_HelmetB_black", "Combat Helmet (Black)", 1],
                ["H_HelmetB_desert", "Combat Helmet (Desert)", 1], ["H_HelmetB_sand", "Combat Helmet (Sand)", 1],
                ["H_HelmetB_grass", "Combat Helmet (Grass)", 1], ["H_HelmetB_snakeskin", "Combat Helmet (Snakeskin)", 1],
                ["H_HelmetSpecB", "Enhanced Combat Helmet", 1], ["H_HelmetSpecB_blk", "Enhanced Combat Helmet (Black)", 1],
                ["H_HelmetSpecB_sand", "Enhanced Combat Helmet (Sand)", 1],
                ["H_HelmetSpecB_snakeskin", "Enhanced Combat Helmet (Snakeskin)", 1],
                ["H_HelmetO_ocamo", "Enhanced Combat Helmet (Hex)", 1], ["H_HelmetO_oucamo", "Enhanced Combat Helmet (Urban)", 1],
["H_ShemagOpen_tan", nil, 25], ["H_Shemag_tan", "Shemag (Pattern)", 25], ["H_Shemag_olive", nil, 25],
                ["H_Shemag_olive_hs", nil, 25], ["H_ShemagOpen_khk", nil, 25], ["H_Cap_grn_BI", nil, 25], ["H_Cap_blk_ION", nil, 25],
                ["H_Cap_blk_CMMG", nil, 25], ["H_Cap_brn_SPECOPS", nil, 25], ["H_Cap_tan_specops_US", nil, 25],
                ["H_Cap_khaki_specops_UK", nil, 25], ["H_Cap_blk_Raven", nil, 25], ["H_Cap_oli_hs", nil, 25], ["H_MilCap_ocamo", nil, 25],
                ["H_MilCap_mcamo", nil, 25], ["H_MilCap_oucamo", nil, 25], ["H_MilCap_dgtl", nil, 25], ["H_MilCap_gry", nil, 25],
                ["H_MilCap_blue", nil, 25], ["H_MilCap_tna_F", nil, 25], ["H_MilCap_ghex_F", nil, 25], ["H_Hat_camo", nil, 25],
                ["H_Cap_headphones", nil, 25], ["H_Booniehat_tna_F", nil, 25], ["H_Booniehat_oli", nil, 25], ["H_Booniehat_mcamo", nil, 25],
                ["H_Booniehat_grn", nil, 25], ["H_Booniehat_tan", nil, 25], ["H_Booniehat_dgtl", nil, 25], ["H_Booniehat_khk_hs", nil, 25],
                ["H_Bandanna_camo", nil, 25], ["H_Bandanna_khk_hs", nil, 25], ["H_Bandanna_mcamo", nil, 25], ["H_Watchcap_blk", nil, 25],
                ["H_Watchcap_sgg", nil, 25], ["H_Watchcap_khk", nil, 25], ["H_Watchcap_camo", nil, 25], ["H_Watchcap_cbr", nil, 25],
                ["H_Cap_Black_IDAP_F", nil, 25], ["H_Cap_White_IDAP_F", nil, 25], ["H_Helmet_Skate", nil, 1500]];
            // LooneyBin (owner, 2026-06-11): Level IV + V combat helmets (best-armor vanilla helmets).
            // Viper removed; Level V = the crew helmets (same top armor tier as Viper, non-CSAT look).
            _ret pushBack ["H_HelmetSpecB_blk", "GA Spec Helmet Black (Level IV)", 8000];
            _ret pushBack ["H_HelmetSpecB", "GA Spec Helmet (Level IV)", 8000];
            _ret pushBack ["H_HelmetSpecB_snakeskin", "GA Spec Helmet Snakeskin (Level IV)", 8000];
            _ret pushBack ["H_HelmetCrew_B", "GA Crew Helmet (Level V)", 15000];
            _ret pushBack ["H_HelmetCrew_O", "GA Crew Helmet Hex (Level V)", 15000];
            _ret pushBack ["H_HelmetCrew_O_ghex_F", "GA Crew Helmet Green-Hex (Level V)", 15000];
            _ret pushBack ["H_HelmetCrew_I", "GA Crew Helmet AAF (Level V)", 15000];

                _ret pushBack["H_Tank_black_F", "Tanker Helmet", 1500];
            
                _ret pushBack["H_HelmetB_light", nil, 1500];
            
                _ret pushBack["H_HelmetB_light_snakeskin", nil, 1500];
            
                _ret pushBack["H_Beret_blk", "Stylish Beret", 50];
            
                _ret pushBack["H_Beret_EAF_01_F", "Fancy Beret", 50];
            
                _ret pushBack["H_Beret_02", "Executive Beret", 50];
                _ret pushBack["H_Beret_Csat_01_F", "Red Beret", 50];
            
                _ret pushBack["H_Construction_basic_yellow_F", nil, 1500];
                _ret pushBack["H_HelmetB_light_wdl", nil, 1500];
            
                _ret pushBack["H_Hat_Safari_olive_F", "Safari Hat (Olive)", 50];
                _ret pushBack["H_Hat_Safari_sand_F", "Safari Hat (Sand)", 50];
                _ret pushBack["H_Construction_basic_orange_F", nil, 1500];
            
                _ret pushBack["H_Beret_Colonel", "Master Beret", 50];
                _ret pushBack["H_Construction_basic_red_F", nil, 1500];
            
                _ret pushBack["H_Construction_basic_white_F", nil, 1500];
                _ret pushBack["H_Beret_gen_F", "Exclusive Beret", 50];
                _ret pushBack["H_HeadBandage_clean_F", nil, 50];
            
                _ret pushBack["H_Construction_basic_black_F", nil, 1500];
                _ret pushBack["H_HeadBandage_stained_F", nil, 50];
            
                _ret pushBack["H_Construction_earprot_black_F", nil, 1500];
                _ret pushBack["H_HeadBandage_bloody_F", nil, 50];};
    case 2: {_ret = [["G_Balaclava_blk", nil, 200], ["G_Balaclava_combat", nil, 200], ["G_Balaclava_lowprofile", nil, 200],
                ["G_Balaclava_TI_blk_F", nil, 200], ["G_Balaclava_TI_G_blk_F", nil, 200], ["G_Balaclava_TI_tna_F", nil, 200],
                ["G_Balaclava_TI_G_tna_F", nil, 200], ["G_Balaclava_oli", nil, 150], ["G_blindfold_01_black_F", nil, 200],
                ["G_blindfold_01_white_F", nil, 200], ["G_AirPurifyingRespirator_02_sand_F", nil, 200], ["G_Bandanna_aviator", nil, 150],
                ["G_Bandanna_beast", nil, 150], ["G_Bandanna_blk", nil, 150], ["G_Bandanna_khk", nil, 150], ["G_Bandanna_oli", nil, 150],
                ["G_Bandanna_shades", nil, 150], ["G_Bandanna_sport", nil, 150], ["G_Bandanna_tan", nil, 150], ["G_Aviator", nil, 10],
                ["G_Tactical_Black", "Tactical Shades", 10], ["G_Tactical_Clear", "Tactical Glasses", 10], ["G_Combat", nil, 10],
                ["G_Combat_Goggles_tna_F", nil, 10], ["G_Lowprofile", nil, 10], ["G_Shades_Black", nil, 10], ["G_Shades_Blue", nil, 10],
                ["G_Spectacles", nil, 10], ["G_Spectacles_Tinted", nil, 10], ["G_Sport_Blackred", nil, 10], ["G_Sport_Checkered", nil, 10],
                ["G_Sport_Blackyellow", nil, 10], ["G_Sport_BlackWhite", nil, 10], ["G_Sport_Greenblack", nil, 10],
                ["G_Sport_Red", nil, 10], ["G_Squares", nil, 10], ["G_Squares_Tinted", nil, 10], ["G_Lady_Blue", nil, 10],
                ["G_Lady_Red", nil, 10], ["G_Lady_Mirror", nil, 10], ["G_Lady_Dark", nil, 10],
                ["G_Respirator_blue_F", "Blue SARS mask", 10], ["G_Respirator_white_F", "White SARS mask", 10],
                ["G_Respirator_yellow_F", "Yellow SARS mask", 10]];
            
                _ret pushBack["G_AirPurifyingRespirator_02_olive_F", nil, 200];
            
                _ret pushBack["G_AirPurifyingRespirator_02_black_F", nil, 200];
            
                _ret pushBack["G_AirPurifyingRespirator_01_F", nil, 200];
            
                _ret pushBack["G_RegulatorMask_F", nil, 200];
                _ret pushBack["G_EyeProtectors_F", "Safety Goggles", 10];
                _ret pushBack["G_EyeProtectors_Earpiece_F", "Safety Goggles (Nerd)", 10];
            
                _ret pushBack["G_Goggles_VR", nil, 10];};
    case 3: {_ret = [["V_PlateCarrier1_blk", nil, 5000], ["V_PlateCarrier1_rgr_noflag_F", nil, 5000], ["V_PlateCarrier1_tna_F", nil, 5000],
                ["V_PlateCarrier1_wdl", nil, 5000], ["V_PlateCarrierL_CTRG", nil, 5000], ["V_CarrierRigKBT_01_EAF_F", nil, 5000],
                ["V_CarrierRigKBT_01_Olive_F", nil, 5000], ["V_CarrierRigKBT_01_light_Olive_F", nil, 5000],
                ["V_PlateCarrier2_rgr", "GA Carrier Rig (Level IV)", 12000],
                ["V_PlateCarrier2_blk", "GA Carrier Rig Black (Level IV)", 12000],
                ["V_PlateCarrier2_rgr_noflag_F", "GA Carrier Rig No-Flag (Level IV)", 12000],
                ["V_PlateCarrierIA2_dgtl", "Mk.II Carrier Rig (Level IV)", 12000],
                ["V_PlateCarrierSpec_rgr", "GA Special Rig (Level V)", 25000],
                ["V_PlateCarrierSpec_blk", "GA Special Rig Black (Level V)", 25000],
                ["V_PlateCarrierSpec_mtp", "GA Special Rig MTP (Level V)", 25000],
                ["V_PlateCarrierGL_rgr", "GA Heavy GL Rig (Level V)", 25000], ["V_TacVest_blk", nil, 3000], ["V_TacVest_brn", nil, 3000],
                ["V_TacVest_camo", nil, 3000], ["V_TacVest_khk", nil, 3000], ["V_TacVest_oli", nil, 3000],
                ["V_I_G_resistanceLeader_F", nil, 3000], ["V_TacVestIR_blk", nil, 3000], ["V_LegStrapBag_olive_F", nil, 350],
                ["V_Chestrig_rgr", nil, 200], ["V_Chestrig_khk", nil, 200], ["V_HarnessOSpec_brn", nil, 200],
                ["V_HarnessOSpec_gry", nil, 200], ["V_Chestrig_blk", nil, 200], ["V_Chestrig_oli", nil, 200], ["V_HarnessO_gry", nil, 200]
            ];
            if (AP_effSide isEqualTo civilian && !(license_civ_bounty)) then {_ret pushBack["V_HarnessOGL_brn", "Suicide vest", 235000];};
            
                _ret pushBack["V_LegStrapBag_coyote_F", nil, 350];
            
                _ret pushBack["V_LegStrapBag_black_F", nil, 350];};
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
                ["B_Messenger_Olive_F", nil, 200]];
            
                _ret pushBack["B_Messenger_Black_F", "Messenger Bag (Worship)", 200, "images\craterewards\retribution\worshipback.jpg"];
            
                _ret pushBack["B_Messenger_Black_F", "Messenger Bag (Toxic)", 200, "images\craterewards\retribution\toxicback.jpg"];
            
                // LooneyBin BUGS #148: removed the upstream-branded subscriber bag skin from the rebel shop
                // (label was de-branded to "LoonyBin+", the TEXTURE still showed the upstream brand -> IP/rebrand leak, reported in-game).
                // Re-add with a de-branded LoonyBin+ bag texture when one exists.
            
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
            
                _ret pushBack["B_AssaultPack_rgr", "Purple Assault Pack", 250, "images\b_assaultpack_purple.jpg"];
            
                _ret pushBack["B_LegStrapBag_olive_F", nil, 350];
                // owner 2026-06-25 (Northhhhh): invisible backpacks now buyable at rebel shops (were civ/cop only); prices mirror civ shop.
                _ret pushBack["B_AssaultPack_blk",   "Invisible Assault Pack", 500, "AP_INVIS_BAG"];
                _ret pushBack["B_FieldPack_blk",     "Invisible Field Pack",   500, "AP_INVIS_BAG"];
                _ret pushBack["B_Kitbag_cbr",        "Invisible Kitbag",       500, "AP_INVIS_BAG"];
                _ret pushBack["B_TacticalPack_oli",  "Invisible Tactical Pack",500, "AP_INVIS_BAG"];
                _ret pushBack["B_Bergen_blk",        "Invisible Bergen",       500, "AP_INVIS_BAG"];
                _ret pushBack["B_Carryall_blk",      "Invisible Carryall",     700, "AP_INVIS_BAG"];
                _ret pushBack["B_Messenger_Black_F", "Invisible Messenger",    400, "AP_INVIS_BAG"];;};
    case 5: {_ret = [];
            for "_i"
            from 0 to 4 do {_ret append([_i] call AP_fnc_clothing_reb);};};
}; if (!(_filter isEqualTo 5)) then {   // owner 2026-07-13: go-kart clothing baked to core (Speed Racer 69 pruned)
    _ret append([_filter] call AP_fnc_clothing_kart);};
_ret;