params[["_shop", "", [""]]];
if (_shop isEqualTo "") exitWith {};
private _items =
switch (_shop) do {case "tech": {
            // owner 2026-07-22 chip-model: Tier 1 hack chips (USE = permanent install) + the consumable ICE Firewall.
            // owner 2026-07-23: the old scroll-buy MODULES are shop chips now too ($1M each) -- scroll shopping is dead.
            ["Kabuki Electronics", ["proxychain", "breachkit", "pingchip", "distractchip", "staticchip", "whiteoutchip", "icefirewall",
                "overclockchip", "coolingrigchip", "signalampchip", "scramblerchip", "opticfilterchip", "audiolimiterchip",
                "hardenedfwchip", "deadboltchip", "freqhopchip", "encryptedsimchip", "surgechip", "copilotchip", "sealedtankchip", "reflexchip"], []]};
    case "homegoods": {
            ["Homegoods Store", [
             // FABRICATORS. Bought here and placed like any other furniture (Y -> Use -> position
             // -> confirm), because that is what they are: placeable objects that live in a house.
             //
             // This shop is reachable ONLY from the house menu's "Homegoods Store" button
             // (core/housing/fn_houseMenu.sqf) -- it has no NPC on the map, and does not need one.
             // That matters: the printer was briefly put in the `tech` shop instead, which reads
             // fine in the config and is just as unobtainable, because Kabuki Electronics has zero
             // placements in fn_mapData. A shop that exists in a config but not in the world sells
             // nothing to anybody.
             //
             // Money buys the MACHINE, never the goods. Both stay printable too, so a second one
             // costs materials rather than cash, and when P4 empties the shops players buy them off
             // each other on the Exchange, where all three fabricators are already whitelisted.
             "printer_i3", "gunsmith_bench",
             "furn_bed", "furn_chairwood", "furn_chairplastic", "furn_campchair1", "furn_campchair2", "furn_sunchair", "furn_camptable", "furn_tablesmall", "furn_tablelarge", "furn_sleepingbag", "furn_laptop", "furn_tablesmall01", "furn_tablebig01", "furn_rattantable", "furn_officetable", "furn_officechair", "furn_armchair", "furn_flattv", "furn_watercooler", "furn_galleryframe_land", "furn_galleryframe_port", "furn_gaming_camera", "furn_gaming_console", "furn_gaming_controller", "furn_gaming_psu", "furn_sat_black", "furn_sat_olive", "furn_sat_sand", "furn_sat_sm_black", "furn_sat_sm_olive", "furn_sat_sm_sand", "furn_pc_case", "furn_pc_keyboard", "furn_pc_mouse", "furn_pc_mousepad", "furn_pc_screen", "furn_pc_intel1", "furn_pc_intel2", "furn_fridge", "furn_ladder_pier", "furn_deerstand1", "furn_deerstand2", "furn_lifeguard", "furn_lamp_shabby", "furn_lamp_decor", "furn_lamp_harbour", "furn_lamp_solar", "furn_lamp_street", "furn_worklight", "furn_worklight2", "furn_floodlight", "furn_lantern", "furn_firepit", "furn_glow_green", "furn_glow_red", "furn_glow_yellow", "furn_glow_white", "furn_sofa", "furn_cabinet1", "furn_cabinet2", "furn_rug", "furn_plant1", "furn_sink", "furn_cooker", "furn_microwave", "furn_sunshade", "furn_scarecrow", "furn_cctv", "furn_crate"], ["furn_bed", "furn_chairwood", "furn_chairplastic", "furn_campchair1", "furn_campchair2", "furn_sunchair", "furn_camptable", "furn_tablesmall", "furn_tablelarge", "furn_sleepingbag", "furn_laptop", "furn_tablesmall01", "furn_tablebig01", "furn_rattantable", "furn_officetable", "furn_officechair", "furn_armchair", "furn_flattv", "furn_watercooler", "furn_galleryframe_land", "furn_galleryframe_port", "furn_gaming_camera", "furn_gaming_console", "furn_gaming_controller", "furn_gaming_psu", "furn_sat_black", "furn_sat_olive", "furn_sat_sand", "furn_sat_sm_black", "furn_sat_sm_olive", "furn_sat_sm_sand", "furn_pc_case", "furn_pc_keyboard", "furn_pc_mouse", "furn_pc_mousepad", "furn_pc_screen", "furn_pc_intel1", "furn_pc_intel2", "furn_fridge", "furn_ladder_pier", "furn_deerstand1", "furn_deerstand2", "furn_lifeguard", "furn_lamp_shabby", "furn_lamp_decor", "furn_lamp_harbour", "furn_lamp_solar", "furn_lamp_street", "furn_worklight", "furn_worklight2", "furn_floodlight", "furn_lantern", "furn_firepit", "furn_glow_green", "furn_glow_red", "furn_glow_yellow", "furn_glow_white", "furn_sofa", "furn_cabinet1", "furn_cabinet2", "furn_rug", "furn_plant1", "furn_sink", "furn_cooker", "furn_microwave", "furn_sunshade", "furn_scarecrow", "furn_cctv", "furn_crate"]]
        };
    case "rebel": {
            // owner 2026-07-29 (maldenjewelry2.md S6): jewelCrowbar + jewelLaser DELISTED. The emporium is
            // all-hacks now -- no stage requires either tool, so the Rebel Market stops selling them. The item
            // defs stay in fn_virtItemCfg.sqf so stock already in inventories/houses keeps a name and a weight.
            ["Rebel Market", ["water", "apple", "redgull", "supermale", "adrenalineShot", "fuelF", "tbacon", "ziptie", "blindfold", "phonebomb", "remotekillswitch", "arsonistkit", "vammo", "spraycan", "boltCutter", "demoCharge", "thermite", "atmskimmer", "speedbomb", "ignitionbomb", "skinningknife", "nitro", "razorwire", "bagwallshort", "bagwalllong", "bagwallround", "boost"],
                ["water", "apple", "redgull", "adrenalineShot", "fuelF", "tbacon", "patientbag", "ziptie", "blindfold", "goldbar", "goldnugget"]
            ]}; case "turf": {
                ["Turf Market", ["water", "apple", "redgull", "adrenalineShot", "fuelF", "tbacon", "ziptie", "blindfold", "spraycan", "boltCutter", "razorwire", "bagwallshort", "bagwalllong", "bagwallround"],
                    ["water", "apple", "redgull", "adrenalineShot", "fuelF", "tbacon", "ziptie", "blindfold", "goldbar", "goldnugget"]]
            }; case "gas": {
                    ["Gas Station Market", ["water", "apple", "redgull", "supermale", "tbacon", "kebab", "firstAidKit", "wreckkit", "donerkebab", "spraycan", "fuelF", "nitro", "tracker", "caralarm", "airalarm", "campfire"],
                        ["water", "apple", "redgull", "tbacon", "fuelF", "towRope", "nitro", "tracker", "caralarm", "airalarm", "campfire"]
                    ]}; case "market": {[format["%1 Market", worldName],
                            ["water", "apple", "peach", "beer", "redgull", "supermale", "tbacon", "boombox", "kebab", "donerkebab", "yeast", "woodaxe", "firstAidKit", "wreckkit", "skinningknife", "metaldetector", "campfire", "tent1", "tent2", "spraycan", "fuelF", "pickaxe", "protest", "excavator", "caralarm", "furn_chairwood", "furn_chairplastic", "furn_campchair1", "furn_campchair2", "furn_sunchair", "furn_camptable", "furn_tablesmall", "furn_tablelarge", "furn_sleepingbag"],
                            ["water", "rabbit", "apple", "peach", "chicken", "chickenp", "snake", "snakep", "rabbitp", "goat", "goatp", "sheep", "sheepp", "redgull", "tbacon", "yeast", "skinningknife", "timber", "timberl", "timberh", "campfire", "tent1", "tent2", "fuelF", "pickaxe", "protest", "redshift", "toxicslurry", "excavator", "caralarm", "berry"]
                        ]}; case "redburger": {["Red Burger", ["redburger", "soda", "water", "coffee", "beer"], []]};
                    case "hospital": {
                            ["LoonyBin Hospital", ["adrenalineShot", "defib", "bloodbag", "canna_papers", "marijuanam", "firstAidKit", "houserepairkit"],
                                ["marijuanam"]]};
                    case "wongs": {["Wong's Food & Liquor", ["yeast"],
                                ["turtlesoup", "turtle", "dog", "dogp", "moonshine", "moonshinep", "scotch_0", "scotch_1", "scotch_2", "scotch_3", "whiskeyc_0", "whiskeyc_1", "whiskeyc_2", "whiskeyc_3", "whiskeyr_0", "whiskeyr_1", "whiskeyr_2", "whiskeyr_3", "manfleshp", "uraniump", "element115"]
                            ]};
                    case "heroin": {
                            [// owner 2026-07-14: drug dealers are SELL-ONLY (seeds cannas_0/cannai_0 stay buyable -- only seed source).
                            "Drug Dealer", ["cannas_0", "cannai_0"],
                                ["smash", "smashbrick", "marijuana", "marijuanam", "blacklace", "blacklaceprime", "lacebase", "glitterbase", "glitter", "humanscalp", "cannas_3", "cannai_3", "canna_dab"]
                            ]};
                    case "oil": {["Oil Trader", ["oilp", "pickaxe", "fuelF", "rubber"], ["oilp", "pickaxe", "fuelF", "rubber"]]};
                    case "fishmarket": {[format["%1 Fish Market", worldName],
                                ["salema", "ornate", "mackerel", "mullet", "tuna", "catshark"],
                                ["salema", "ornate", "mackerel", "mullet", "tuna", "catshark"]]};
                    case "glass": {["Glass Dealer", ["glass"], ["glass"]]};
                    case "diamond": {["Jewelry Store", ["diamondc", "diamondf", "ruby", "doubloon", "silverpiece", "pickaxe"],
                                ["diamond", "diamondc", "diamondf", "ruby", "doubloon", "silverpiece", "pickaxe", "treasure", "goldnugget"]
                            ]};
                    case "salt": {["Salt Dealer", ["salt_r"], ["salt_r"]]};
                    case "cop": {
                            private _copBuy = ["donuts", "coffee", "water", "apple", "redgull", "fuelF", "vammo", "spikeStrip", "roadCone", "roadConelight", "roadBarrier", "roadBarrierSmall", "cncBarrier", "cncBarrierL", "barGate", "tracker", "caralarm", "airalarm"];
                            if (hasInterface && {(call AP_copLevel) >= 6}) then { _copBuy pushBack "uav05"; };   // owner 2026-06-25: Captain+ only $10k deployable UCAV (-> AP_fnc_copUAV)
                            ["Cop Item Shop", _copBuy,
                                ["donuts", "coffee", "water", "apple", "redgull", "fuelF", "spikeStrip", "roadCone", "roadConelight", "roadBarrier", "roadBarrierSmall", "cncBarrier", "cncBarrierL", "barGate", "tracker", "caralarm", "airalarm"]
                            ]};
                    case "commod": {
                            ["Commodities Trader", ["diamondc", "iron_r", "copper_r", "woodaxe", "pickaxe", "glass", "rubber", "oilp"],
                                ["diamond", "diamondc", "iron_r", "copper_r", "pickaxe", "glass", "rubber", "oilp", "timber", "timberl", "timberh", "plank", "plankl", "plankh", "goldnugget"]
                            ]};
                    case "vig": {["Bounty Hunter Shop", ["water", "apple", "redgull", "fuelF", "tbacon", "ziptie"],
                                ["water", "apple", "redgull", "fuelF", "tbacon", "ziptie"]]};
                    case "skiptracer": {
                            ["Skiptracer Shop", ["water", "apple", "redgull", "fuelF", "tbacon", "firstAidKit", "ziptie", "blindfold", "adrenalineShot", "boltCutter"],
                                ["water", "apple", "redgull", "fuelF", "tbacon", "ziptie"]]};
                    case "blackmarket": {
                            // owner 2026-06-24: the sell list is static, but named foreskins are dynamic (foreskin_<uid>).
                            // Append every registered foreskin classname so they're all sellable here at 7000 (price comes
                            // from virtItemCfg). "foreskin" (legacy generic) kept for any pre-existing stacks.
                            // owner 2026-07-17: Processed Oil buy REMOVED (bought cheap here + sold for profit -- market
                            // exploit). Blackmarket is now SELL-ONLY like the drug dealers (empty buy list). Oil must be
                            // harvested + processed. Sell list (manflesh/foreskin/loonycoin + dynamic foreskins) unchanged.
                            ["Blackmarket", [],
                            // sells: loonycoin appended below via the sell-list edit
                                (["manflesh", "foreskin", "loonycoin"] + ((missionNamespace getVariable ["AP_foreskinReg", []]) apply { format ["foreskin_%1", _x select 0] }))
                            ]};
                    case "delivery": {["Delivery Market", ["water", "tbacon", "fuelF", "redgull", "painkillers"],
                                ["water", "tbacon", "fuelF", "redgull", "painkillers"]]};
                    case "meditemshop": {
                            ["TT Item Shop", ["donuts", "coffee", "water", "redgull", "adrenalineShot", "defib", "bloodbag", "firstAidKit", "nitro", "fuelF", "roadCone", "roadConelight", "roadBarrier", "roadBarrierSmall", "medDrop"],
                                ["roadCone", "roadConelight", "roadBarrier", "roadBarrierSmall"]]};
                    case "hunting": {
                            ["Hunting Item Shop", ["skinningknife", "sickle", "woodaxe", "campfire", "tent1", "tent2", "tbacon", "water", "redgull", "beer", "firstAidKit", "boombox"],
                                []]};
                    case "medicaldispensary": {
                            ["Medicinal Dispensary", ["marijuanam", "canna_dab", "canna_bong", "canna_rig", "canna_prejoint", "canna_vape", "canna_papers"],
                                []]};
                    case "africanwarlord": {["African Warlord", [],
                                ["jewelHope", "jewelRolex", "jewelAP", "jewelDiamonds", "jewelGoldBag", "jewelExoJewels", "jewelRing", "jewelBling", "jewelBag"]
                            ]};}; if ({player distance2D getMarkerPos format["turf_label_%1", _x] < 200}
count[1, 2, 3] > 0) then {(_items select 2) deleteRange[((_items select 2) find "timber"), 3]};
_items;
