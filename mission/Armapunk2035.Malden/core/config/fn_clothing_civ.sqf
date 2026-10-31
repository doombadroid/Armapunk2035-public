params[["_filter", 0, [0]]];
ctrlSetText[3103, "Bruce's Outback Outfits"];
private _ret = [];
switch (_filter) do {case 0: {_ret = [["U_C_Poloshirt_blue", "Poloshirt Blue", 25], ["U_C_Poloshirt_burgundy", "Poloshirt Burgundy", 25],
                ["U_C_Poloshirt_stripped", "Poloshirt Stripped", 25], ["U_C_Poloshirt_tricolour", "Poloshirt Tricolour", 25],
                ["U_C_Poloshirt_salmon", "Poloshirt Salmon", 25], ["U_C_Poloshirt_redwhite", "Poloshirt Red and White", 25],
                ["U_Marshal", "Yellow Plaid", 50, "images\marshal_yellow_plaid.jpg"], ["U_C_Poor_1", "Shirt Blue", 25],
                ["U_I_G_Story_Protagonist_F", "Buttonup Black Camo", 25], ["U_I_G_resistanceLeader_F", "Combat T Green", 25],
                ["U_NikosBody", "Buttonup Red Dragon", 25], ["U_Marshal", "White Shirt", 25], ["U_OrestesBody", nil, 25],
                ["U_C_HunterBody_grn", "Hunter Cream", 25], ["U_OG_Guerilla1_1", "Tan Guerilla", 30],
                ["U_OG_Guerilla1_1", "Brown Guerilla", 30, "\A3\characters_f_gamma\civil\data\c_cloth1_brown.paa"],
                ["U_OG_Guerilla1_1", "Metal Guerilla", 30, "\A3\characters_f_gamma\civil\data\c_cloth1_black.paa"],
                ["U_OG_Guerilla3_1", "Hunter Tan", 25], ["U_OG_Guerilla3_2", "Hunter Green", 25],
                ["U_IG_Guerilla2_1", "Buttonup Black", 25], ["U_IG_Guerilla2_2", "Buttonup Checked", 25],
                ["U_IG_Guerilla2_3", "Buttonup Navy", 50], ["U_I_C_Soldier_Bandit_1_F", nil, 50], ["U_I_C_Soldier_Bandit_2_F", nil, 50],
                ["U_I_C_Soldier_Bandit_3_F", nil, 50], ["U_I_C_Soldier_Bandit_4_F", nil, 50], ["U_I_C_Soldier_Bandit_5_F", nil, 50],
                ["U_C_Man_casual_1_F", nil, 50], ["U_C_Man_casual_2_F", nil, 50], ["U_C_Man_casual_3_F", nil, 50],
                ["U_C_man_sport_1_F", nil, 50], ["U_C_man_sport_2_F", nil, 50], ["U_C_man_sport_3_F", nil, 50],
                ["U_C_man_sport_1_F", "Sports Clothes (Adidas)", 50, "images\sportsclothes_adidas.jpg"], ["U_C_Man_casual_4_F", nil, 50],
                ["U_C_Man_casual_5_F", nil, 50], ["U_C_Man_casual_6_F", nil, 50], ["U_C_IDAP_Man_cargo_F", nil, 50],
                ["U_C_IDAP_Man_Jeans_F", nil, 50], ["U_C_IDAP_Man_casual_F", nil, 50], ["U_C_IDAP_Man_shorts_F", nil, 50],
                ["U_C_IDAP_Man_Tee_F", nil, 50], ["U_C_IDAP_Man_TeeShorts_F", nil, 50], ["U_C_ConstructionCoverall_Black_F", nil, 50],
                ["U_C_ConstructionCoverall_Blue_F", nil, 50], ["U_C_ConstructionCoverall_Red_F", nil, 50],
                ["U_C_ConstructionCoverall_Vrana_F", nil, 50], ["U_C_Mechanic_01_F", nil, 50], ["U_C_CBRN_Suit_01_Blue_F", nil, 300],
                ["U_C_CBRN_Suit_01_White_F", nil, 300], ["U_I_L_Uniform_01_camo_F", nil, 300], ["U_I_L_Uniform_01_deserter_F", nil, 300],
                ["U_I_L_Uniform_01_tshirt_black_F", nil, 50], ["U_I_L_Uniform_01_tshirt_olive_F", nil, 50],
                ["U_I_L_Uniform_01_tshirt_skull_F", nil, 50], ["U_I_L_Uniform_01_tshirt_sport_F", nil, 50],
                ["U_C_Uniform_Scientist_01_formal_F", nil, 50], ["U_C_Uniform_Farmer_01_F", nil, 50]];
            
                _ret pushBack["U_C_Poloshirt_salmon", "Hawaiian", 50, "images\c_poloshirt_flowers.jpg"];
                // LooneyBin (owner 2026-06-13): Beta Tester Shirt now GATED to the beta-tester whitelist
                // (AP_betaTester, set from players_global.betatester on load). getVariable default = nil-safe.
                if (missionNamespace getVariable ["AP_betaTester", false]) then {
                    _ret pushBack["U_C_Poloshirt_blue", "Beta Tester Shirt", 50, "images\beta_shirt.paa"];};
                _ret pushBack["U_C_ArtTShirt_01_v6_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v1_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v3_F", nil, 50];
            
                _ret pushBack["U_C_ArtTShirt_01_v5_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v2_F", nil, 50];
                _ret pushBack["U_C_ArtTShirt_01_v4_F", nil, 50];
            
                _ret pushBack["U_C_Uniform_Scientist_02_formal_F", nil, 50];
                _ret pushBack["U_I_E_ParadeUniform_01_LDF_F", nil, 300];
                _ret pushBack["U_I_E_ParadeUniform_01_LDF_decorated_F", nil, 300];
            
                _ret pushBack["U_O_ParadeUniform_01_CSAT_F", nil, 300];
                _ret pushBack["U_O_ParadeUniform_01_CSAT_decorated_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_blue_F", nil, 300];
            
                _ret pushBack["U_C_Journalist", nil, 50];
                _ret pushBack["U_B_ParadeUniform_01_US_F", nil, 300];
                _ret pushBack["U_B_ParadeUniform_01_US_decorated_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_khaki_F", nil, 300];
            
                _ret pushBack["U_C_Uniform_Scientist_01_F", nil, 50];
                _ret pushBack["U_I_ParadeUniform_01_AAF_F", nil, 300];
                _ret pushBack["U_I_ParadeUniform_01_AAF_decorated_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_gray_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_tshirt_gray_F", nil, 300];
            
                _ret pushBack["U_I_Protagonist_VR", "White VR Suit", 200, "#(argb,8,8,3)color(1,1,1,1)"];
                _ret pushBack["U_B_Protagonist_VR", "Blue VR Suit", 200];
                _ret pushBack["U_O_Protagonist_VR", "Red VR Suit", 200];
                _ret pushBack["U_I_Protagonist_VR", "Green VR Suit", 200];
                _ret pushBack["U_C_FormalSuit_01_black_F", nil, 300];
                _ret pushBack["U_C_FormalSuit_01_tshirt_black_F", nil, 300];;
            
                _ret pushBack["U_C_Uniform_Scientist_02_F", nil, 50];
            if (difficultyEnabledRTD) then {_ret pushBack["U_B_HeliPilotCoveralls", nil, 2500];
                _ret pushBack["U_I_HeliPilotCoveralls", nil, 2500];};
            if ((call AP_adminLevel) >= 3) then {};
            if ((getPlayerUID player) isEqualTo(SRV_governorData param[0, "GovUID"])) then {
                _ret pushBack["U_NikosAgedBody", "Governor Outfit", 300];};};
    case 1: {_ret = [["H_Cap_surfer", nil, 25], ["H_Cap_red", nil, 25], ["H_Cap_blu", nil, 25], ["H_Cap_oli", nil, 25],
                ["H_Cap_grn", nil, 25], ["H_Cap_grn_BI", nil, 25], ["H_Cap_tan", nil, 25], ["H_Cap_blk", nil, 25],
                ["H_Cap_headphones", nil, 25], ["H_Cap_blk_CMMG", nil, 25], ["H_Cap_blk_ION", nil, 25], ["H_Cap_oli_hs", nil, 25],
                ["H_Cap_press", nil, 25], ["H_Cap_usblack", nil, 25], ["H_Booniehat_grn", nil, 25], ["H_Booniehat_tan", nil, 25],
                ["H_Booniehat_dirty", nil, 25], ["H_Bandanna_surfer", nil, 25], ["H_Bandanna_surfer_blk", nil, 25],
                ["H_Bandanna_surfer_grn", nil, 25], ["H_Bandanna_khk", nil, 25], ["H_Bandanna_cbr", nil, 25], ["H_Bandanna_sgg", nil, 25],
                ["H_Bandanna_blu", nil, 25], ["H_Bandanna_sand", nil, 25], ["H_Bandanna_gry", nil, 25], ["H_StrawHat", nil, 25],
                ["H_StrawHat_dark", nil, 25], ["H_Hat_blue", nil, 25], ["H_Hat_brown", nil, 25], ["H_Hat_grey", nil, 25],
                ["H_Hat_tan", nil, 25], ["H_Watchcap_blk", nil, 25], ["H_Watchcap_khk", nil, 25], ["H_Watchcap_sgg", nil, 25],
                ["H_Watchcap_camo", nil, 25], ["H_Hat_checker", nil, 25], ["H_Helmet_Skate", nil, 1500], ["H_Cap_Black_IDAP_F", nil, 25],
                ["H_Cap_Orange_IDAP_F", nil, 25], ["H_Cap_White_IDAP_F", nil, 25], ["H_EarProtectors_black_F", nil, 25],
                ["H_Hat_Tinfoil_F", nil, 25]];
            
                _ret pushBack["H_Beret_blk", "Stylish Beret", 50];
            
                _ret pushBack["H_Beret_EAF_01_F", "Fancy Beret", 50];
                _ret pushBack["H_ParadeDressCap_01_LDF_F", nil, 50];
            
                _ret pushBack["H_Beret_02", "Executive Beret", 50];
                _ret pushBack["H_Beret_Csat_01_F", "Red Beret", 50];
                _ret pushBack["H_ParadeDressCap_01_CSAT_F", nil, 50];
            
                _ret pushBack["H_Construction_basic_yellow_F", nil, 1500];
                _ret pushBack["H_ParadeDressCap_01_US_F", nil, 50];
            
                _ret pushBack["H_Hat_Safari_olive_F", "Safari Hat (Olive)", 50];
                _ret pushBack["H_Hat_Safari_sand_F", "Safari Hat (Sand)", 50];
                _ret pushBack["H_Construction_basic_orange_F", nil, 1500];
                _ret pushBack["H_ParadeDressCap_01_AAF_F", nil, 50];
            
                _ret pushBack["H_Beret_Colonel", "Master Beret", 50];
                _ret pushBack["H_Construction_basic_red_F", nil, 1500];
            
                _ret pushBack["H_Construction_basic_white_F", nil, 1500];
                _ret pushBack["H_Beret_gen_F", "Exclusive Beret", 50];
                _ret pushBack["H_HeadBandage_clean_F", nil, 50];
            
                _ret pushBack["H_HeadBandage_stained_F", nil, 50];
                _ret pushBack["H_Construction_basic_black_F", nil, 1500];
            
                _ret pushBack["H_Construction_earprot_black_F", nil, 1500];
                _ret pushBack["H_HeadBandage_bloody_F", nil, 50];};
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
            
                _ret pushBack["G_Goggles_VR", nil, 10];};
    case 3: {_ret = [["V_Rangemaster_belt", nil, 350], ["V_LegStrapBag_olive_F", nil, 350], ["V_BandollierB_cbr", nil, 450],
                ["V_BandollierB_khk", nil, 450], ["V_BandollierB_rgr", nil, 450], ["V_BandollierB_blk", nil, 450],
                ["V_BandollierB_oli", nil, 450], ["V_Safety_blue_F", nil, 50], ["V_Safety_orange_F", nil, 50],
                ["V_Safety_yellow_F", nil, 50], ["V_SmershVest_01_radio_F", nil, 450], ["V_SmershVest_01_F", nil, 450]];
            if ((license_civ_bounty) || ((call AP_copLevel) > 2)) then {_ret pushBack["V_TacVest_blk", nil, 3000];};
            
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
                ["B_Carryall_wdl_F", nil, 350], ["B_Carryall_blk", nil, 350], ["B_Messenger_Black_F", nil, 200],
                ["B_Messenger_Coyote_F", nil, 200], ["B_Messenger_Gray_F", nil, 200], ["B_Messenger_Olive_F", nil, 200],
                ["B_LegStrapBag_olive_F", nil, 350]];
            
                _ret pushBack["B_CivilianBackpack_01_Everyday_IDAP_F", nil, 150];
                _ret pushBack["B_CivilianBackpack_01_Sport_Red_F", nil, 150];
            
                _ret pushBack["B_Carryall_khk", "Black Carryall Backpack", 250, "A3\weapons_f\ammoboxes\bags\data\backpack_tortila_blk_co.paa"];
                _ret pushBack["B_CivilianBackpack_01_Everyday_Astra_F", nil, 150];
                _ret pushBack["B_CivilianBackpack_01_Sport_Blue_F", nil, 150];
            
                _ret pushBack["B_CivilianBackpack_01_Everyday_Vrana_F", nil, 150];
                _ret pushBack["B_CivilianBackpack_01_Sport_Green_F", nil, 150];
            
                _ret pushBack["B_CivilianBackpack_01_Everyday_Black_F", nil, 150];
            
                _ret pushBack["B_LegStrapBag_coyote_F", nil, 350];
            
                _ret pushBack["B_LegStrapBag_black_F", nil, 350];
            
                _ret pushBack["B_Carryall_khk", "Hiker's Backpack", 250, "images\b_carryall_hiker.jpg"];
            
                _ret pushBack["B_AssaultPack_blk", "Blue Assault Pack", 250, "images\b_assaultpack_blue.jpg"];
            
                _ret pushBack["B_AssaultPack_khk", "Green Assault Pack", 250, "images\b_assaultpack_green.jpg"];
            
                _ret pushBack["B_AssaultPack_sgg", "Orange Assault Pack", 250, "images\b_assaultpack_orange.jpg"];
            
                _ret pushBack["B_AssaultPack_wdl_F", "Red Assault Pack", 250, "images\b_assaultpack_red.jpg"];
            
                _ret pushBack["B_AssaultPack_rgr", "Purple Assault Pack", 250, "images\b_assaultpack_purple.jpg"];
            // owner 2026-06-13: invisible backpacks (1 per kind), 2x the normal price. The transparent
            // procedural texture is applied to the pack by fn_changeClothes (setObjectTexture slot 0).
                _ret pushBack["B_AssaultPack_blk",   "Invisible Assault Pack", 500, "AP_INVIS_BAG"];
                _ret pushBack["B_FieldPack_blk",     "Invisible Field Pack",   500, "AP_INVIS_BAG"];
                _ret pushBack["B_Kitbag_cbr",        "Invisible Kitbag",       500, "AP_INVIS_BAG"];
                _ret pushBack["B_TacticalPack_oli",  "Invisible Tactical Pack",500, "AP_INVIS_BAG"];
                _ret pushBack["B_Bergen_blk",        "Invisible Bergen",       500, "AP_INVIS_BAG"];
                _ret pushBack["B_Carryall_blk",      "Invisible Carryall",     700, "AP_INVIS_BAG"];
                _ret pushBack["B_Messenger_Black_F", "Invisible Messenger",    400, "AP_INVIS_BAG"];};
    case 5: {_ret = [];
            for "_i"
            from 0 to 4 do {_ret append([_i] call AP_fnc_clothing_civ);};};
}; if (!(_filter isEqualTo 5)) then {   // owner 2026-07-13: go-kart clothing baked to core (Speed Racer 69 pruned)
    _ret append([_filter] call AP_fnc_clothing_kart);};
_ret;