params["_obj_main", "_stance", "_type"];
if (_obj_main isKindOf "CAManBase") then {};
switch (_type) do {case "mineral": {
            _obj_main addAction["Process Iron", AP_fnc_processAction, "iron", 1.5, false, false, "", 'AP_inv_ironore > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Iron</t>", AP_fnc_processVehicle, "iron", 1.5, false, false, "", '!AP_is_processing', 5];
            _obj_main addAction["Process Copper", AP_fnc_processAction, "copper", 1.5, false, false, "", 'AP_inv_copperore > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Copper</t>", AP_fnc_processVehicle, "copper", 1.5, false, false, "", '!AP_is_processing', 5];
            _obj_main addAction["Process Diamond", AP_fnc_processAction, "diamond", 1.5, false, false, "", 'AP_inv_diamond > 0 && !AP_is_processing', 5];
            // owner 2026-06-14 (#207): add the bulk vehicle-trunk diamond process. The "diamond" -> "diamondc"
            // recipe already exists in fn_processVehicle; Iron/Copper had their "Process Vehicle" action but
            // diamond was missing, so only ores could be bulk-processed at the mineral processor.
            _obj_main addAction["<t color='#33FF99'>Process Vehicle: Diamond</t>", AP_fnc_processVehicle, "diamond", 1.5, false, false, "", '!AP_is_processing', 5];
            _obj_main addAction["Process Sand", AP_fnc_processAction, "sand", 1.5, false, false, "", 'AP_inv_sand > 0 && !AP_is_processing', 5];
            _obj_main addAction["Crush Rock", AP_fnc_processAction, "sandr", 1.5, false, false, "", 'AP_inv_rock > 0 && !AP_is_processing', 5];
        }; case "smashpowder": {
                _obj_main addAction["Process Smash", AP_fnc_processAction, "smashpowder", 1.5, false, false, "", 'AP_inv_smashpowder > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Smash</t>", AP_fnc_processVehicle, "smashpowder", 1.5, false, false, "", '!AP_is_processing', 5];
                _obj_main addAction["Press Smash Bricks", AP_fnc_processAction, "smashbrick", 1.5, false, false, "", 'AP_inv_smash > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Smash Bricks</t>", AP_fnc_processVehicle, "smashbrick", 1.5, false, false, "", '!AP_is_processing', 5];
            };
        case "blacklace": {
                _obj_main addAction["Mix Lace Base", AP_fnc_processAction, "lacebase", 1.5, false, false, "", 'AP_inv_sparkdust > 0 && AP_inv_redshift > 0 && AP_inv_toxicslurry > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Lace Base</t>", AP_fnc_processVehicle, "lacebase", 1.5, false, false, "", '!AP_is_processing', 5];
                _obj_main addAction["Cook Black Lace", AP_fnc_processAction, "blacklace", 1.5, false, false, "", 'AP_inv_lacebase > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Black Lace</t>", AP_fnc_processVehicle, "blacklace", 1.5, false, false, "", '!AP_is_processing', 5];
                _obj_main addAction["Refine Black Lace Prime", AP_fnc_processAction, "blacklaceprime", 1.5, false, false, "", 'AP_inv_blacklace > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Black Lace Prime</t>", AP_fnc_processVehicle, "blacklaceprime", 1.5, false, false, "", '!AP_is_processing', 5];
            };
        case "marijuana": {
                _obj_main addAction["Process Marijuana", AP_fnc_processAction, "marijuana", 1.5, false, false, "", 'AP_inv_cannabis > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Marijuana</t>", AP_fnc_processVehicle, "marijuana", 1.5, false, false, "", '!AP_is_processing', 5];
                _obj_main addAction["<img image='mpmissions\__cur_mp.altis\icons\cannabisplant.paa' /> <t color='#ff547f'>Dry Indica Plant</t>", AP_fnc_processAction, "cannai_2", 1.5, false, false, "", 'AP_inv_cannai_2 > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["<img image='mpmissions\__cur_mp.altis\icons\cannabisplant.paa' /> <t color='#ff547f'>Dry Sativa Plant</t>", AP_fnc_processAction, "cannas_2", 1.5, false, false, "", 'AP_inv_cannas_2 > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
                // owner 2026-06-13: bud -> Golden Wax moved here from the removed purificationfactory (weed.md)
                _obj_main addAction["<img image='mpmissions\__cur_mp.altis\icons\cannabisdab.paa' /> <t color='#ff547f'>Process Indica Bud into Golden Wax</t>", AP_fnc_processAction, "cannai_3", 1.5, false, false, "", 'AP_inv_cannai_3 > 0 && !AP_is_processing', 5];
                // owner 2026-06-17: Sativa-bud -> Golden Wax action REMOVED (wax is INDICA-only). Sativa bud sells as a bud.
                // owner 2026-06-14 (#206): bulk vehicle-trunk bud -> Golden Wax. The cannas_3/cannai_3 -> canna_dab
                // recipes already exist in fn_processVehicle, but only the hand actions were here, so a trunk of
                // home-grown weed couldn't be bulk-processed into wax. Mirrors the other "Process Vehicle" options.
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Indica Golden Wax</t>", AP_fnc_processVehicle, "cannai_3", 1.5, false, false, "", '!AP_is_processing', 5];
                // owner 2026-06-17: Process-Vehicle Sativa-Wax action REMOVED (wax is INDICA-only).
                _obj_main addAction["Marijuana Processing Contract ($800)", AP_fnc_buyLicense, "marijuana", 1.5, false, false, "", '!license_civ_marijuana && AP_effSide isEqualTo civilian', 5];
            };
        case "medmarijuana": {
                _obj_main addAction["Process Marijuana", AP_fnc_processAction, "marijuanam", 1.5, false, false, "", 'AP_inv_cannabis > 0 && !AP_is_processing && (SRV_governorData param [3, false])', 5];
                _obj_main addAction["Marijuana Processing Contract ($800)", AP_fnc_buyLicense, "marijuana", 1.5, false, false, "", '!license_civ_marijuana && AP_effSide isEqualTo civilian', 5];
            };
        case "oyster": {
            };
        case "oil": {
                _obj_main addAction["Process Oil", AP_fnc_processAction, "drilledoil", 1.5, false, false, "", 'AP_inv_oilu > 0 && !AP_is_processing', 5];
                _obj_main addAction["<t color='#33FF99'>Process Vehicle: Oil</t>", AP_fnc_processVehicle, "drilledoil", 1.5, false, false, "", '!AP_is_processing', 5];
                _obj_main addAction["Oil Processing ($1,000)", AP_fnc_buyLicense, "oil", 1.5, false, false, "", '!license_civ_oil && AP_effSide isEqualTo civilian', 5];
            };
        case "salt": {
                _obj_main addAction["Process Salt", AP_fnc_processAction, "salt", 1.5, false, false, "", 'AP_inv_salt > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
            };
        case "timber": {
                _obj_main addAction["Mill Pine Timber", AP_fnc_processAction, "timber", 1.5, false, false, "", 'AP_inv_timber > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Mill Olive Timber", AP_fnc_processAction, "timberl", 1.5, false, false, "", 'AP_inv_timberl > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Mill Hardwood Timber", AP_fnc_processAction, "timberh", 1.5, false, false, "", 'AP_inv_timberh > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
            };
        case "purificationfactory": {
                // owner 2026-06-13: PURIFICATION FACTORY REMOVED. Every 2nd-stage/purify recipe was moved to
                // the matching normal processor (cokebrick->cocaine, bluemeth->meth,
                // scotch3->scotchHeatPump, bud->GoldenWax->marijuana). Case kept empty in case a stray NPC
                // still spawns with this type (also stripped from fn_mapData). Double-process at the normal spot.
            };
        case "scotchHeatPump": {
                _obj_main addAction["See Alcohol Recipes", AP_fnc_alcoholRecipes, "", 0, false, true, "", ' !AP_is_processing'];
                _obj_main addAction["Process White Lightning", AP_fnc_processAction, "moonshinep", 0, false, true, "", ' AP_inv_moonshine > 0 && !AP_is_processing'];
                _obj_main addAction["Age Scotch (Aging Chemicals)", AP_fnc_processAction, "scotch3", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_scotch_2 > 0 && !AP_is_processing'];
                _obj_main addAction["Process Scotch", AP_fnc_processAction, "scotch", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_water > 0 && AP_inv_yeast > 0 && AP_inv_barley > 0 && !AP_is_processing'];
                _obj_main addAction["Process Scotch", AP_fnc_processAction, "scotchsalt", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_saltwater > 0 && AP_inv_yeast > 0 && AP_inv_barley > 0 && !AP_is_processing'];
                _obj_main addAction["Process Corn Whiskey", AP_fnc_processAction, "whiskeyc", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_water > 0 && AP_inv_yeast > 0 && AP_inv_barley > 0 && AP_inv_corn > 0 && !AP_is_processing'];
                _obj_main addAction["Process Corn Whiskey", AP_fnc_processAction, "whiskeycsalt", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_saltwater > 0 && AP_inv_yeast > 0 && AP_inv_barley > 0 && AP_inv_corn > 0 && !AP_is_processing'];
                _obj_main addAction["Process Rye Whiskey", AP_fnc_processAction, "whiskeyr", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_water > 0 && AP_inv_yeast > 0 && AP_inv_barley > 0 && AP_inv_rye > 0 && !AP_is_processing'];
                _obj_main addAction["Process Rye Whiskey", AP_fnc_processAction, "whiskeyrsalt", 0, false, true, "", ' AP_effSide isEqualTo civilian && AP_inv_saltwater > 0 && AP_inv_yeast > 0 && AP_inv_barley > 0 && AP_inv_rye > 0 && !AP_is_processing'];
            };};