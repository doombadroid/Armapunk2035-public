params[["_mode", "", ["", 0]], "_toFind"];
if (_mode isEqualTo "") exitWith {};
// perf 2026-07-05: the 277-row catalog (+ dynamic foreskins) was rebuilt from a literal on EVERY call --
// 183 call sites, several inside per-item loops (calWeight/calWeightDiff/handleInv rebuilt it dozens of
// times per call). Build it ONCE into cached vars; rebuild only when the foreskin registry grows. Two
// classname hashMaps (_idx = classname, _idxLife = "AP_inv_"+classname) turn the point-lookup modes from
// an O(n) findIf (+ per-row format) into an O(1) get. Full-scan modes just reuse the cached array.
// Audit 2026-09-26 (r2items): the cache lives in localNamespace on every machine. The server takes weight,
// price and "is this a real item" from these rows (createItem budgets, house/vehicle trunk saves, rig, fab),
// and a client publicVariable overwrites a missionNamespace global on the server and on every other client.
// The network cannot write localNamespace. The server also reads the foreskin registry from its own
// localNamespace copy (server init.sqf / APS_fnc_registerForeskin); clients read the published one.
private _reg = ([missionNamespace, localNamespace] select isServer) getVariable ["AP_foreskinReg", []];
private _itemArray = localNamespace getVariable ["AP_virtItemArr", []];
private _idx = localNamespace getVariable ["AP_virtItemIdx", createHashMap];
private _idxLife = localNamespace getVariable ["AP_virtItemIdxLife", createHashMap];
// content-sensitive key: rebuild on ANY registry change, not just a count change -- the foreskin name can be
// replaced at the SAME count (optimistic live name -> server's DB-sanitized name), which a count key misses.
if (_itemArray isEqualTo [] || {!(_reg isEqualTo (localNamespace getVariable ["AP_virtItemRegSnap", [-1]]))}) then {_itemArray = [
    ["adrenalineShot", "Adrenaline Shot", 1, -1, -1, -1, 1425, 1000, 700, -1, "icons\adrenalineShot.paa"],
    ["houserepairkit", "House Repair Kit", 10, -1, -1, -1, 50000, 50000, 50000, -1, "icons\boltCutter.paa"],   // owner 2026-06-23: civ buys at the Hospital shop ($50k, fixed) -> self-repair own destroyed house like a medic (consumed per repair). fn_civRepairBuilding "kitRepair".
    ["uav05", "MaxSec UCAV (Sentinel)", 20, -1, -1, -1, 10000, 5000, 5000, -1, "icons\agingbarrel.paa"],
    ["babyoil", "Baby Oil", 1, -1, -1, -1, 5000, 2500, 2500, -1, "icons\adrenalineShot.paa"],   // owner 2026-06-25: scroll-wheel use on a RESTRAINED player strips them to underwear (AP_fnc_babyOil). NOT in any shop yet.
    ["agingbarrel", "Spirit Aging Barrel", 12, -1, -1, -1, 10687, 10000, 7000, -1, "icons\agingbarrel.paa"],
    ["airalarm", "Helicopter Alarm", 6, -1, -1, -1, 2137, 2000, 1000, -1, "icons\airalarm.paa"],
    ["medDrop", "Medical Supply Drop", 20, -1, -1, -1, 5100, 1000, 500, -1, "icons\airdrop.paa"],
    ["ultimateHealBomb", "Ultimate Healing Sunshine Love Bomb", 25, -1, -1, -1, 10000000, 5000000, 5000000, -1, "icons\adrenalineShot.paa"],
    ["apple", "Apple", 1, -1, -1, -1, 6, 6, 5, -1, "icons\apple.paa"],
    ["bagwalllong", "Long Bag Wall", 6, -1, -1, -1, 1602, 1500, 1000, -1, "icons\bagwalllong.paa"],
    ["bagwallround", "Round Bag Wall", 4, -1, -1, -1, 1068, 1000, 700, -1, "icons\bagwallround.paa"],
    ["bagwallshort", "Short Bag Wall", 4, -1, -1, -1, 1068, 1000, 700, -1, "icons\bagwallshort.paa"],
    ["bank_money", "Dirty Money", 0, -1, 0.1, -1, -1, -1, -1, -1, "icons\bank_money.paa"],
    ["barGate", "Bar Gate", 2, -1, -1, -1, 180, 150, 50, -1, "icons\barGate.paa"],
    ["barley", "Barley", 1, -1, 100, -1, -1, -1, -1, -1, "icons\barley.paa"],
    ["beer", "Pint of Beer", 1, -1, -1, -1, 12, 10, 7, -1, "icons\beer.paa"],
    ["berry", "Wild Berry", 1, -1, -1, -1, 12, 12, 9, -1, "icons\berry.paa"],
    ["blindfold", "Blindfold", 1, -1, -1, -1, 1068, 1000, 500, -1, "icons\blindfold.paa"],
    ["bloodbag", "Blood Bag", 3, -1, -1, -1, 159, 150, 75, -1, "icons\bloodbag.paa"],
    ["boltCutter", "Bolt Cutter", 4, -1, 500, -1, 1068, 1000, 500, -1, "icons\boltCutter.paa"],
    ["boombox", "Boom Box", 3, -1, -1, -1, 1500, 1000, 500, -1, "icons\boombox.paa"],
    ["campfire", "Campfire Kit", 2, -1, -1, -1, 534, 500, 250, -1, "icons\campfire.paa"],
    ["furn_chairwood", "Wooden Chair", 5, -1, -1, -1, 350, 300, 150, -1, "icons\campfire.paa"],
    ["furn_chairplastic", "Plastic Chair", 5, -1, -1, -1, 300, 250, 125, -1, "icons\campfire.paa"],
    ["furn_campchair1", "Camping Chair (Blue)", 5, -1, -1, -1, 350, 300, 150, -1, "icons\campfire.paa"],
    ["furn_campchair2", "Camping Chair (White)", 5, -1, -1, -1, 350, 300, 150, -1, "icons\campfire.paa"],
    ["furn_sunchair", "Sun Lounger", 6, -1, -1, -1, 450, 400, 200, -1, "icons\campfire.paa"],
    ["furn_camptable", "Camping Table", 6, -1, -1, -1, 450, 400, 200, -1, "icons\campfire.paa"],
    ["furn_tablesmall", "Wooden Table (Small)", 7, -1, -1, -1, 550, 500, 250, -1, "icons\campfire.paa"],
    ["furn_tablelarge", "Wooden Table (Large)", 8, -1, -1, -1, 750, 650, 325, -1, "icons\campfire.paa"],
    ["furn_sleepingbag", "Sleeping Bag", 4, -1, -1, -1, 300, 250, 125, -1, "icons\campfire.paa"],
    ["furn_bed", "Wooden Double Bed", 30, -1, -1, -1, 25000, 12000, 8000, -1, "icons\campfire.paa"],
    ["furn_ladder_pier", "Steel Ladder", 20, -1, -1, -1, 15000, 7500, 5000, -1, "icons\campfire.paa"],
    ["furn_deerstand1", "Deer Stand (Wood)", 40, -1, -1, -1, 30000, 15000, 10000, -1, "icons\campfire.paa"],
    ["furn_deerstand2", "Deer Stand (Camo)", 40, -1, -1, -1, 30000, 15000, 10000, -1, "icons\campfire.paa"],
    ["furn_lifeguard", "Lifeguard Tower", 50, -1, -1, -1, 45000, 20000, 15000, -1, "icons\campfire.paa"],
    ["furn_laptop", "Laptop", 4, -1, -1, -1, 5000, 2500, 2500, -1, "icons\campfire.paa"],
    ["furn_tablesmall01", "Small Table", 12, -1, -1, -1, 7000, 3500, 3500, -1, "icons\campfire.paa"],
    ["furn_tablebig01", "Big Table", 20, -1, -1, -1, 12000, 6000, 6000, -1, "icons\campfire.paa"],
    ["furn_rattantable", "Rattan Table", 14, -1, -1, -1, 9000, 4500, 4500, -1, "icons\campfire.paa"],
    ["furn_officetable", "Office Table", 18, -1, -1, -1, 11000, 5500, 5500, -1, "icons\campfire.paa"],
    ["furn_officechair", "Office Chair", 12, -1, -1, -1, 8000, 4000, 4000, -1, "icons\campfire.paa"],
    ["furn_armchair", "Arm Chair", 16, -1, -1, -1, 10000, 5000, 5000, -1, "icons\campfire.paa"],
    ["furn_flattv", "Flat Screen TV", 12, -1, -1, -1, 18000, 9000, 9000, -1, "icons\campfire.paa"],
    ["furn_lamp_shabby", "Shabby Street Lamp", 8, -1, -1, -1, 6500, 3250, 3250, -1, "icons\campfire.paa"],
    ["furn_lamp_decor", "Decorative Lamp Post", 8, -1, -1, -1, 7500, 3750, 3750, -1, "icons\campfire.paa"],
    ["furn_lamp_harbour", "Harbour Lamp", 8, -1, -1, -1, 7000, 3500, 3500, -1, "icons\campfire.paa"],
    ["furn_lamp_solar", "Solar Garden Lamp", 8, -1, -1, -1, 5500, 2750, 2750, -1, "icons\campfire.paa"],
    ["furn_lamp_street", "Street Lamp", 8, -1, -1, -1, 8000, 4000, 4000, -1, "icons\campfire.paa"],
    ["furn_worklight", "Work Light", 8, -1, -1, -1, 4500, 2250, 2250, -1, "icons\campfire.paa"],
    ["furn_worklight2", "Work Light (Double)", 8, -1, -1, -1, 6000, 3000, 3000, -1, "icons\campfire.paa"],
    ["furn_floodlight", "Floodlight", 8, -1, -1, -1, 9500, 4750, 4750, -1, "icons\campfire.paa"],
    ["furn_lantern", "Camping Lantern", 8, -1, -1, -1, 3000, 1500, 1500, -1, "icons\campfire.paa"],
    ["furn_firepit", "Fire Pit (lit)", 8, -1, -1, -1, 5000, 2500, 2500, -1, "icons\campfire.paa"],
    ["furn_glow_green", "Glow Light (Green)", 8, -1, -1, -1, 2500, 1250, 1250, -1, "icons\campfire.paa"],
    ["furn_glow_red", "Glow Light (Red)", 8, -1, -1, -1, 2500, 1250, 1250, -1, "icons\campfire.paa"],
    ["furn_glow_yellow", "Glow Light (Yellow)", 8, -1, -1, -1, 2500, 1250, 1250, -1, "icons\campfire.paa"],
    ["furn_glow_white", "Glow Light (White)", 8, -1, -1, -1, 2500, 1250, 1250, -1, "icons\campfire.paa"],
    ["furn_sofa", "Sofa", 8, -1, -1, -1, 9000, 4500, 4500, -1, "icons\campfire.paa"],
    ["furn_cabinet1", "Office Cabinet (Tall)", 8, -1, -1, -1, 5000, 2500, 2500, -1, "icons\campfire.paa"],
    ["furn_cabinet2", "Office Cabinet (Wide)", 8, -1, -1, -1, 5000, 2500, 2500, -1, "icons\campfire.paa"],
    ["furn_rug", "Rug", 8, -1, -1, -1, 4000, 2000, 2000, -1, "icons\campfire.paa"],
    ["furn_plant1", "Potted Plant", 8, -1, -1, -1, 2000, 1000, 1000, -1, "icons\campfire.paa"],
    ["furn_sink", "Kitchen Sink", 8, -1, -1, -1, 3500, 1750, 1750, -1, "icons\campfire.paa"],
    ["furn_cooker", "Gas Cooker", 8, -1, -1, -1, 4500, 2250, 2250, -1, "icons\campfire.paa"],
    ["furn_microwave", "Microwave", 8, -1, -1, -1, 3500, 1750, 1750, -1, "icons\campfire.paa"],
    ["furn_sunshade", "Sunshade", 8, -1, -1, -1, 3000, 1500, 1500, -1, "icons\campfire.paa"],
    ["furn_scarecrow", "Scarecrow", 8, -1, -1, -1, 6900, 3450, 3450, -1, "icons\campfire.paa"],
    ["furn_cctv", "Security Camera (Prop)", 8, -1, -1, -1, 4500, 2250, 2250, -1, "icons\campfire.paa"],
    ["furn_crate", "Wooden Crate", 8, -1, -1, -1, 1500, 750, 750, -1, "icons\campfire.paa"],
    ["furn_watercooler", "Water Cooler", 10, -1, -1, -1, 6000, 3000, 3000, -1, "icons\campfire.paa"],
    ["furn_galleryframe_land", "Gallery Frame (Landscape)", 6, -1, -1, -1, 7000, 3500, 3500, -1, "icons\campfire.paa"],
    ["furn_galleryframe_port", "Gallery Frame (Portrait)", 6, -1, -1, -1, 7000, 3500, 3500, -1, "icons\campfire.paa"],
    ["furn_gaming_camera", "Streaming Webcam", 3, -1, -1, -1, 4000, 2000, 2000, -1, "icons\campfire.paa"],
    ["furn_gaming_console", "Gaming Console", 6, -1, -1, -1, 9000, 4500, 4500, -1, "icons\campfire.paa"],
    ["furn_gaming_controller", "Game Controller", 2, -1, -1, -1, 2000, 1000, 1000, -1, "icons\campfire.paa"],
    ["furn_gaming_psu", "Gaming Power Supply", 5, -1, -1, -1, 3000, 1500, 1500, -1, "icons\campfire.paa"],
    ["furn_sat_black", "Satellite Dish (Black)", 18, -1, -1, -1, 12000, 6000, 6000, -1, "icons\campfire.paa"],
    ["furn_sat_olive", "Satellite Dish (Olive)", 18, -1, -1, -1, 12000, 6000, 6000, -1, "icons\campfire.paa"],
    ["furn_sat_sand", "Satellite Dish (Sand)", 18, -1, -1, -1, 12000, 6000, 6000, -1, "icons\campfire.paa"],
    ["furn_sat_sm_black", "Small Satellite Dish (Black)", 12, -1, -1, -1, 9000, 4500, 4500, -1, "icons\campfire.paa"],
    ["furn_sat_sm_olive", "Small Satellite Dish (Olive)", 12, -1, -1, -1, 9000, 4500, 4500, -1, "icons\campfire.paa"],
    ["furn_sat_sm_sand", "Small Satellite Dish (Sand)", 12, -1, -1, -1, 9000, 4500, 4500, -1, "icons\campfire.paa"],
    ["furn_pc_case", "PC Tower", 10, -1, -1, -1, 7000, 3500, 3500, -1, "icons\campfire.paa"],
    ["furn_pc_keyboard", "Keyboard", 2, -1, -1, -1, 1500, 750, 750, -1, "icons\campfire.paa"],
    ["furn_pc_mouse", "Mouse", 1, -1, -1, -1, 1000, 500, 500, -1, "icons\campfire.paa"],
    ["furn_pc_mousepad", "Mouse Pad", 1, -1, -1, -1, 800, 400, 400, -1, "icons\campfire.paa"],
    ["furn_pc_screen", "PC Monitor", 8, -1, -1, -1, 6000, 3000, 3000, -1, "icons\campfire.paa"],
    ["furn_pc_intel1", "Computer Setup (1)", 14, -1, -1, -1, 14000, 7000, 7000, -1, "icons\campfire.paa"],
    ["furn_pc_intel2", "Computer Setup (2)", 14, -1, -1, -1, 14000, 7000, 7000, -1, "icons\campfire.paa"],
    ["furn_fridge", "Refrigerator", 22, -1, -1, -1, 13000, 6500, 6500, -1, "icons\campfire.paa"],
    ["caralarm", "Vehicle Alarm", 6, -1, -1, -1, 534, 500, 250, -1, "icons\caralarm.paa"],
    ["catshark", "Cat Shark Meat", 6, -1, -1, -1, 138, 130, 91, -1, "icons\catshark.paa"],
    ["chicken", "Raw Chicken Meat", 4, -1, -1, -1, 319, 300, 210, -1, "icons\chicken.paa"],
    ["chickenp", "Cooked Chicken Meat", 2, -1, -1, -1, 747, 700, 490, -1, "icons\chickenp.paa"],
    ["cncBarrier", "Concrete Barrier", 3, -1, -1, -1, 180, 150, 50, -1, "icons\cncBarrier.paa"],
    ["cncBarrierL", "Concrete Barrier Long", 3, -1, -1, -1, 240, 200, 75, -1, "icons\cncBarrierL.paa"],
    ["coffee", "Coffee", 1, -1, -1, -1, 6, 6, 3, -1, "icons\coffee.paa"],
    ["smashpowder", "Smash Powder", 3, -1, 150, -1, 267, 250, 175, -1, "icons\smashpowder.paa"],
    ["smash", "Smash", 3, -1, 300, 1, 1018, 999, 600, -1, "icons\smash.paa"],
    ["smashbrick", "Smash Bricks", 2, -1, 550, 1, 1618, 1100, 1000, -1, "icons\smashbrick.paa"],
    ["phonebomb", "Remote Explosive", 10, -1, 3500, -1, 300000, 215000, 50000, -1, "icons\phonebomb.paa"],
    ["remotekillswitch", "Remote Engine Kill Switch", 10, -1, 3500, -1, 50000, 50000, 25000, -1, "icons\phonebomb.paa"],
    ["arsonistkit", "Arson Kit", 8, -1, 2500, -1, -1, 75000, 25000, -1, "icons\arsonistkit.paa"],
    ["copperore", "Copper Ore", 3, -1, -1, -1, -1, -1, -1, -1, "icons\copperore.paa"],
    ["copper_r", "Copper Ingot", 1, -1, -1, -1, 99, 95, 85, -1, "icons\copper_r.paa"],
    ["corn", "Corn", 1, -1, -1, -1, -1, -1, -1, -1, "icons\corn.paa"],
    ["glitterbase", "Glitter Base", 2, -1, 200, -1, -1, -1, 235, -1, "icons\glitterbase.paa"],
    ["glitter", "Glitter", 2, -1, 450, 1, 1780, 1699, 1000, -1, "icons\glitter.paa"],
    ["defib", "Defibrillator", 20, -1, -1, -1, 961, 900, 450, -1, "icons\defib.paa"],
    ["cyberdeck", "Cyberdeck", 3, -1, 2500, -1, 10000, 10000, 5000, -1, "icons\cyberdeck.paa"],   // LooneyBin 2026-07-18: hacking deck (replaces lockpick+drill)
    ["demoCharge", "Demo Charge", 2, -1, 500, -1, 1602, 1500, 1000, -1, "icons\demoCharge.paa"],
    ["diamond", "Diamond Uncut", 4, -1, -1, 1, 285, 200, 140, -1, "icons\diamond.paa"],
    ["diamondc", "Diamond Cut", 2, -1, -1, 1, 612, 550, 480, -1, "icons\diamondc.paa"],
    ["diamondf", "Flawless Diamond", 2, -1, -1, 1, 2850, 2000, 1400, -1, "icons\diamondf.paa"],
    ["dog", "Raw Dog Meat", 4, -1, 250, 1, 1710, 1200, 840, -1, "icons\dog.paa"],
    ["dogp", "Cooked Dog Meat", 2, -1, 250, 1, 2992, 2100, 1470, -1, "icons\dogp.paa"],
    ["donerkebab", "Doner Kebab", 2, -1, -1, -1, 85, 81, 57, -1, "icons\donerkebab.paa"],
    ["donuts", "Donuts", 1, -1, -1, -1, 13, 13, 10, -1, "icons\donuts.paa"],
    ["doubloon", "Gold doubloon", 2, -1, -1, -1, 186, 175, 122, -1, "icons\doubloon.paa"],
    ["ducttape", "Duct Tape", 1, -1, -1, -1, -1, -1, -1, -1, "icons\ducttape.paa"],
    ["lacebase", "Lace Base", 2, -1, 225, -1, -1, -1, 375, -1, "icons\lacebase.paa"],
    ["sparkdust", "Sparkdust", 2, -1, 100, -1, -1, -1, -1, -1, "icons\sparkdust.paa"],
    ["excavator", "Wreck Excavator", 1, -1, -1, -1, 319, 300, 200, -1, "icons\excavator.paa"],
    ["fuelE", "Empty Fuel Can", 2, -1, -1, -1, -1, -1, -1, -1, "icons\fuelE.paa"],
    ["fuelF", "Full Fuel Can", 4, -1, -1, -1, 75, 60, 30, -1, "icons\fuelF.paa"],
    ["firstAidKit", "First Aid Kit", 1, -1, -1, -1, 75, 50, 25, -1, "icons\firstaid.paa"],
    ["wreckkit", "Wreckage Recovery Kit", 1, -1, -1, -1, 1000, 1000, 500, -1, "icons\boltCutter.paa"],   // owner 2026-07-04: scroll a WRECK with this in Y-inv -> "Recover Wreckage" returns it to the OWNER's garage (AP_fnc_recoverWreck). Weight = virtual FAK (1). Gas Station + Market. Consumed per use.
    ["giftAdmin", "Admin Gift", 0, -1, -1, -1, 1, 1, 1, -1, "icons\bluegift.paa"],
    ["giftHallo", "Halloween Gift", 0, -1, -1, -1, 1, 1, 1, -1, "icons\halloweengift.paa"],
    ["giftXmas", "Christmas Gift", 0, -1, -1, -1, 1, 1, 1, -1, "icons\xmasgift.paa"],
    ["glass", "Glass", 1, -1, -1, -1, 250, 230, 200, -1, "icons\glass.paa"],
    ["goat", "Raw Goat Meat", 4, -1, -1, 1, 570, 400, 569, -1, "icons\goat.paa"],
    ["goatp", "Cooked Goat Meat", 2, -1, -1, 1, 1852, 1300, 1851, -1, "icons\goatp.paa"],
    ["goldbar", "Gold Bar", 64, -1, 3000, 1, 78375, 55000, 50000, -1, "icons\goldbar.paa"],
    ["goldnugget", "Gold Nugget", 8, -1, -1, -1, 58375, 35000, 30000, -1, "icons\goldnugget.paa"],   // ECONOMY 2026-09-05: weight 2 -> 8. At $15,000 of sell value per weight unit this was eight times denser than the best drug in the game and the single most out-of-line row in the table. The PAYOUT is untouched -- what changes is that hauling it now costs cargo, exactly the way the gold bar already expresses the same idea with weight 64 and a walk penalty.
    // MALDEN FIELDS 2026-07-26: three resources the map designer marked and the code never had. Raw
    // ends only -- the processing recipes, dealers and shop entries land with the processor pass.
    // boost (renamed from fentanylu, Task 6 2026-08-21) was raw feedstock with no chain and was
    // deliberately left unpriced; it is now purchasable (rebel shop) as the cutting agent for §4,
    // while the two farm goods still carry placeholder prices. Icons are stand-ins until they are baked.
    ["tobaccou", "Tobacco Leaf", 2, -1, 50, -1, 90, 80, 60, -1, "icons\tobaccou.paa"],
    ["boost", "Boost", 2, -1, 200, 1, 900, 800, 600, -1, "icons\boost.paa"],
    ["grapes", "Grapes", 2, -1, -1, -1, 20, 18, 14, -1, "icons\grapes.paa"],
    ["toxicslurry", "Toxic Slurry", 2, -1, -1, -1, 234, 165, 115, -1, "icons\toxicslurry.paa"],
    ["ironore", "Iron Ore", 3, -1, -1, -1, -1, -1, -1, -1, "icons\ironore.paa"],
    ["iron_r", "Iron Ingot", 1, -1, -1, 1, 315, 290, 270, -1, "icons\iron_r.paa"],
    ["jewelLaser", "Plasma Cutter", 5, -1, 500, 1, 1200, 1000, 500, -1, "icons\jewelLaser.paa"],
    ["jewelCrowbar", "Crowbar", 5, -1, 100, 1, 500, 375, 100, -1, "icons\jewelCrowbar.paa"],
    ["jewelHope", "Hope Diamond", 10, -1, 3000, 1, -1, -1, 108000, -1, "icons\jewelhope.paa"],
    ["jewelRolex", "Rolex Watch", 3, -1, 2500, 1, -1, -1, 10284, -1, "icons\jewelrolex.paa"],
    ["jewelAP", "AP Watch", 3, -1, 1200, 1, -1, -1, 4840, -1, "icons\jewelap.paa"],
    ["jewelDiamonds", "Blood Diamond", 8, -1, 1700, 1, -1, -1, 6765, -1, "icons\jeweldiamonds.paa"],
    ["jewelGoldBag", "Sack of Gold Nuggets", 8, -1, 2500, 1, -1, -1, 9999, -1, "icons\jewelgoldbag.paa"],
    ["jewelExoJewels", "Bag Of Exotic Jewels", 5, -1, 1000, 1, -1, -1, 4000, -1, "icons\jewelexobag.paa"],
    ["jewelRing", "Engagement Ring", 2, -1, 1600, 1, -1, -1, 6420, -1, "icons\jewelring.paa"],
    ["jewelBling", "Diamond Cuban Link", 8, -1, 1900, 1, -1, -1, 7690, -1, "icons\jewelcuban.paa"],
    ["jewelBag", "Bag Of Jewelry", 8, -1, 2500, 1, -1, -1, 17500, -1, "icons\jewelbag.paa"],
    ["kebab", "Kebab", 2, -1, -1, -1, 100, 75, 25, -1, "icons\kebab.paa"],
    ["ladder", "Ladder Bridge", 1, -1, -1, -1, -1, -1, -1, -1, "icons\ladder.paa"],
    ["money", "Dollars", 0, -1, -1, -1, -1, -1, -1, -1, "icons\money.paa"],
    ["newdrachma", "New Drachma", 0, -1, -1, -1, -1, -1, -1, -1, "icons\newdrachma.paa"],
    ["mackerel", "Mackerel Meat", 4, -1, -1, -1, 73, 70, 49, -1, "icons\mackerel.paa"],
    ["cannabis", "Reggie Stems", 2, -1, 100, 1, -1, -1, -1, -1, "icons\marijuana.paa"],
    ["marijuana", "Reggie Cannabis", 2, -1, 200, 1, 500, 749, 420, -1, "icons\marijuana.paa"],
    ["marijuanam", "Medicinal Cannabis", 2, -1, 200, 1, 285, 699, 380, -1, "icons\cannabismedical.paa"],
    ["cannas_0", "Sativa Seed", 1, -1, 35, -1, 100, 100, 35, -1, "icons\cannabisseed.paa"],
    ["cannai_0", "Indica Seed", 1, -1, 35, -1, 100, 100, 35, -1, "icons\cannabisseed.paa"],
    ["cannas_1", "Sativa Sprout", 3, -1, 200, -1, 52, 50, 35, -1, "icons\cannabissprout.paa"],
    ["cannai_1", "Indica Sprout", 3, -1, 200, -1, 52, 50, 35, -1, "icons\cannabissprout.paa"],
    ["cannas_2", "Sativa Adult Plant", 3, -1, 200, -1, 52, 50, 35, -1, "icons\cannabisplant.paa"],
    ["cannai_2", "Indica Adult Plant", 3, -1, 200, -1, 52, 50, 35, -1, "icons\cannabisplant.paa"],
    ["cannas_3", "Sativa Bud", 1, -1, 250, 1, 200, 200, 120, -1, "icons\cannabisindica.paa"],
    ["cannai_3", "Indica Bud", 1, -1, 250, 1, 200, 200, 120, -1, "icons\cannabisindica.paa"],
    ["canna_dab", "Golden Wax", 1, -1, 300, 1, 400, 400, 230, -1, "icons\cannabisdab.paa"],
    ["canna_bong", "Glass Bong", 1, -1, -1, -1, 12, 10, 7, -1, "icons\canna_bong.paa"],
    ["canna_rig", "Glass Rig", 1, -1, -1, -1, 12, 10, 7, -1, "icons\canna_rig.paa"],
    ["canna_prejoint", "Pre-Roll Joint", 1, -1, -1, -1, 12, 10, 7, -1, "icons\canna_preroll.paa"],
    ["canna_vape", "Dab Vape", 1, -1, -1, -1, 12, 10, 7, -1, "icons\canna_vape.paa"],
    ["canna_papers", "RAW Papers", 1, -1, -1, -1, 12, 10, 7, -1, "icons\canna_rawpapers.paa"],
    ["canna_joint", "Rolled Joint", 1, -1, -1, -1, 12, 10, 7, -1, "icons\canna_joint.paa"],
    ["cryptoConsole", "Gaming LoonyBin Console", 5, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoConsole.paa"],
    ["cryptoCPU", "AMD Ryzen 9 12950X", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoCPU.paa"],
    ["cryptoGPU", "NVIDIA RTX 7090 Ti", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoGPU.paa"],
    ["cryptoPSU", "3000W Quantum Titanium PSU", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoPSU.paa"],
    ["cryptoStorage", "32TB PCIe 7.0 NVMe SSD", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoStorage.paa"],
    ["cryptoMotherboard", "ASUS ROG Dark Hero X9 Motherboard", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoMotherboard.paa"],
    ["cryptoRam", "128GB DDR6-12800 ECC Kit", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoRam.paa"],
    ["cryptoCooler", "NZXT Kraken Elite 360mm AIO (2035)", 3, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoCooler.paa"],
    ["cryptoCase", "4u Rackmount Case", 5, -1, -1, -1, 12, 10, 7, -1, "icons\cryptoCase.paa"],
    ["cryptoRig", "LoonyBin Mining Rig", 15, -1, -1, -1, -1, -1, -1, -1, "icons\cryptoConsole.paa"],   // owner 2026-07-15: assembled from all 8 components; installs into a house to mine
    ["loonycoin", "New Drachma", 0, -1, 6500, -1, 7200, 7200, 6000, -1, "icons\newdrachma.paa"],       // mined output; sell-only at the Blackmarket. WEIGHTLESS (owner 2026-07-22, like bank_money). Key stays "loonycoin" (DB inventories + CLANKR reference it)
    ["manflesh", "Human Organs", 15, -1, 3000, -1, 10000, 10000, 10000, -1, "icons\manflesh.paa"],   // owner 2026-06-28: organ sell ~3.3k -> 10k (community ask). manflesh is sell-only (not in any buy shop) so no arbitrage.
    ["foreskin", "Foreskin", 1, -1, 6000, -1, 7000, 7000, 6600, -1, "icons\manflesh.paa"],   // owner 2026-06-23: harvested from COP corpses (fn_execute). Weighs 1; all prices = 2x manflesh -> sells for twice as much. Sold at the Blackmarket (fn_virt_shops). Reuses the manflesh icon.
    ["manfleshp", "Cooked Human Organs", 13, -1, 5000, -1, 8550, 8000, 8000, -1, "icons\manfleshp.paa"],
    ["humanscalp", "Human Scalp", 13, -1, 5000, -1, 6000, 6000, 6000, -1, "icons\skull.paa"],
    ["blacklace", "Black Lace", 2, -1, 400, 1, 3277, 2800, 1800, -1, "icons\blacklace.paa"],
    ["metaldetector", "Metal Detector", 1, -1, -1, -1, 100, 100, 50, -1, "icons\metaldetector.paa"],
    ["blacklaceprime", "Black Lace Prime", 2, -1, 900, 1, 3880, 3200, 2700, -1, "icons\blacklaceprime.paa"],
    ["mullet", "Mullet Meat", 4, -1, -1, -1, 117, 110, 77, -1, "icons\mullet.paa"],
    ["nitro", "Nitrous Injector", 5, -1, -1, -1, 1602, 1500, 1000, -1, "icons\nitro.paa"],
    ["oilb", "Oil Barrel", 1, -1, -1, -1, -1, -1, -1, -1, "icons\oilp.paa"],
    ["oilp", "Processed Oil", 2, -1, -1, 1, 484, 340, 210, -1, "icons\oilp.paa"],
    ["oilu", "Unprocessed Oil", 4, -1, -1, -1, -1, -1, -1, -1, "icons\oilu.paa"],
    ["ornate", "Ornate Meat", 1, -1, -1, -1, 43, 42, 30, -1, "icons\ornate.paa"],
    ["painkillers", "Pain Killers", 1, -1, -1, -1, 15, 15, 11, -1, "icons\painkillers.paa"],
    ["patientbag", "Mental Patient Remains", 15, -1, 5000, -1, 80000, 80000, 80000, -1, "icons\skull.paa"],
    ["peach", "Peach", 1, -1, -1, -1, 6, 6, 5, -1, "icons\peach.paa"],
    ["redshift", "Redshift", 2, -1, -1, 1, 234, 165, 115, -1, "icons\redshift.paa"],
    ["pickaxe", "Pickaxe", 1, -1, -1, -1, 52, 50, 35, -1, "icons\pickaxe.paa"],
    ["plank", "Pine Plank", 3, -1, -1, 1, 171, 160, 112, -1, "icons\plank.paa"],
    ["plankh", "Hardwood Plank", 3, -1, -1, 1, 570, 400, 280, -1, "icons\plankh.paa"],
    ["plankl", "Olive Plank", 3, -1, -1, 1, 342, 240, 168, -1, "icons\plankl.paa"],
    ["protest", "Protest Sign", 5, -1, -1, -1, 200, 100, 50, -1, "icons\protest.paa"],
    ["rabbit", "Raw Rabbit Meat", 2, -1, -1, -1, 192, 180, 126, -1, "icons\rabbit.paa"],
    ["rabbitp", "Cooked Rabbit Meat", 1, -1, -1, -1, 213, 200, 140, -1, "icons\rabbitp.paa"],
    ["razorwire", "Razorwire", 3, -1, -1, -1, 2137, 2000, 1000, -1, "icons\razorwire.paa"],
    ["redburger", "Red Burger", 1, -1, -1, -1, 5, 5, 5, -1, "icons\redburger.paa"],
    ["redgull", "RedGull", 1, -1, -1, -1, 160, 150, 75, -1, "icons\redgull.paa"],
    ["supermale", "Super Male Vitality", 1, -1, -1, -1, 5000, 2500, 1200, -1, "icons\redgull.paa"],
    ["roadBarrier", "Road Barrier", 1, -1, -1, -1, 200, 150, 75, -1, "icons\roadBarrier.paa"],
    ["roadBarrierSmall", "Road Barrier Small", 1, -1, -1, -1, 200, 100, 50, -1, "icons\roadBarrier.paa"],
    ["roadCone", "Road Cone", 1, -1, -1, -1, 200, 100, 50, -1, "icons\roadCone.paa"],
    ["roadConelight", "Road Cone Light", 1, -1, -1, -1, 200, 150, 75, -1, "icons\roadCone.paa"],
    ["rock", "Rock", 3, -1, -1, -1, -1, -1, -1, -1, "icons\rock.paa"],
    ["rubber", "Rubber", 2, -1, -1, 1, 1500, 1050, 950, -1, "icons\rubber.paa"],
    ["ruby", "Ruby", 2, -1, -1, -1, 480, 450, 315, -1, "icons\ruby.paa"], ["rye", "Rye", 1, -1, -1, -1, -1, -1, -1, -1, "icons\rye.paa"],
    ["salema", "Salema Meat", 1, -1, -1, -1, 42, 40, 28, -1, "icons\salema.paa"],
    ["salt", "Salt", 3, -1, -1, -1, -1, -1, -1, -1, "icons\salt.paa"],
    ["salt_r", "Refined Salt", 1, -1, -1, 1, 256, 180, 126, -1, "icons\salt_r.paa"],
    ["saltwater", "Salt Water", 1, -1, -1, -1, -1, -1, -1, -1, "icons\saltwater.paa"],
    ["sand", "Sand", 3, -1, -1, -1, -1, -1, -1, -1, "icons\sand.paa"],
    // owner 2026-06-21 (#spirit-barrel "no Lay Down Spirits option"): rum was half-added -- it's a process output
    // (fn_processAction), a barrel type, a wongs-shop item, and referenced in useItem/itemDemand,
    // AND the rum_0..3 icons exist -- but the ITEM DEFINITIONS were never added here, so the per-item init at L375
    // never created AP_inv_rum_0..3. The barrel "Lay Down Spirits" action's show-condition sums
    // AP_inv_scotch_0 + ... + AP_inv_rum_0, so the UNDEFINED AP_inv_rum_0 threw every frame -> the condition
    // failed -> the action was hidden for EVERYONE (scotch + whiskey too), and nobody could age anything (0 barrel_crop).
    // Add the 4 rum stages mirroring rye whiskey (New Make -> Rum -> Aged -> Reserve; barrel ages 0->1->2, Reserve via processor).
    ["rum_0", "New Make Rum", 3, -1, 150, -1, 213, 200, 212, -1, "icons\rum_0.paa"],
    ["rum_1", "Rum", 3, -1, 150, -1, 480, 450, 479, -1, "icons\rum_1.paa"],
    ["rum_2", "Aged Rum", 3, -1, 150, -1, 694, 650, 693, -1, "icons\rum_2.paa"],
    ["rum_3", "Reserve Rum", 3, -1, 150, -1, 1014, 950, 1013, -1, "icons\rum_3.paa"],
    ["scotch_0", "New Make Scotch", 3, -1, 200, -1, 52, 50, 35, -1, "icons\scotch_0.paa"],
    ["scotch_1", "Scotch", 3, -1, 200, -1, 355, 250, 375, -1, "icons\scotch_1.paa"],
    ["scotch_2", "15 Year Scotch", 3, -1, 250, 1, 1282, 900, 700, -1, "icons\scotch_2.paa"],
    ["scotch_3", "25 Year Scotch", 3, -1, 300, 1, 2035, 1429, 1200, -1, "icons\scotch_3.paa"],
    ["shank", "Prison Shank", 3, -1, -1, -1, -1, -1, -1, -1, "icons\shank.paa"],
    ["sheep", "Raw Sheep Meat", 4, -1, -1, 1, 427, 300, 210, -1, "icons\sheep.paa"],
    ["sheepp", "Cooked Sheep Meat", 2, -1, -1, 1, 1710, 1200, 840, -1, "icons\sheepp.paa"],
    ["sickle", "Sickle", 3, -1, 2000, -1, 5000, 5000, 2500, -1, "icons\sickle.paa"],
    ["silverpiece", "Silver Piece", 2, -1, -1, -1, 159, 150, 105, -1, "icons\silverpiece.paa"],
    ["skinningknife", "Skinning Knife", 1, -1, -1, -1, 200, 150, 70, -1, "icons\skinningknife.paa"],
    ["snake", "Raw Snake Meat", 2, -1, -1, -1, 196, 185, 129, -1, "icons\snake.paa"],
    ["snakep", "Cooked Snake Meat", 1, -1, -1, -1, 213, 200, 140, -1, "icons\snakep.paa"],
    ["soda", "LoonyBin Soda", 1, -1, -1, -1, 7, 7, 5, -1, "icons\soda.paa"],
    ["speedbomb", "Speed Bomb", 10, -1, 3500, -1, 300000, 235000, 56000, -1, "icons\speedbomb.paa"],
    ["ignitionbomb", "Ignition Explosive", 10, -1, 2500, -1, 300000, 200000, 50000, -1, "icons\ignitionbomb.paa"],
    ["spikeStrip", "Spike Strip", 12, -1, -1, -1, 1335, 1000, 750, -1, "icons\spikeStrip.paa"],
    ["spraycan", "Spray Can", 1, -1, -1, -1, 500, 500, 200, -1, "icons\spraycan.paa"],
    ["hboxsmall", "H Box (Small Crate)", 5, -1, -1, -1, 2675, 2500, 1500, -1, "icons\storage1.paa"],
    ["hboxlarge", "H Box (Large Crate)", 9, -1, -1, -1, 8025, 7500, 4500, -1, "icons\storage2.paa"],
    ["storage1", "House Storage", 10, -1, -1, -1, 16030, 15000, 10000, -1, "icons\storage1.paa"],
    ["storage2", "House Storage Large", 12, -1, -1, -1, 21375, 20000, 10000, -1, "icons\storage2.paa"],
    ["tbacon", "Tactical Bacon", 1, -1, -1, -1, 8, 8, 5, -1, "icons\tbacon.paa"],
    ["tent1", "Tent (A-shape)", 15, -1, -1, -1, 1068, 1000, 500, -1, "icons\tent1.paa"],
    ["tent2", "Tent (Dome-shape)", 15, -1, -1, -1, 1602, 1500, 750, -1, "icons\tent2.paa"],
    ["timber", "Pine Timber", 4, -1, -1, 1, 114, 80, 50, -1, "icons\timber.paa"],
    ["timberh", "Hardwood Timber", 4, -1, -1, 1, 285, 200, 120, -1, "icons\timberh.paa"],
    ["timberl", "Olive Timber", 4, -1, -1, 1, 171, 120, 75, -1, "icons\timberl.paa"],
    ["tracker", "Tracking Device", 3, -1, -1, -1, 1300, 1250, 500, -1, "icons\tracker.paa"],
    ["treasure", "Treasure", 20, -1, -1, -1, 40000, 35000, 30000, -1, "icons\treasure.paa"],
    ["treasuremap", "Treasure Map", 20, -1, -1, -1, -1, -1, -1, -1, "icons\treasuremap.paa"],
    ["tuna", "Tuna Meat", 8, -1, -1, -1, 267, 250, 175, -1, "icons\tuna.paa"],
    ["turtle", "Turtle Meat", 6, -1, 500, 1, 2422, 1700, 2000, -1, "icons\turtle.paa"],
    ["thermite", "Thermite", 5, -1, 500, 1, 1430, 1700, 1000, -1, "icons\thermite.paa"],
    ["atmskimmer", "ATM Skimmer", 4, -1, 25000, 1, 50000, 50000, 25000, -1, "icons\debitcard.paa"],   // LooneyBin 2026-07-16: rebel $50k device, siphons 10% at a rigged ATM (fn_atmSkimSRV)
    ["ghostplatechip", "Ghost Plate Chip", 1, -1, -1, 1, 250000, 250000, 250000, -1, "icons\qhchip.paa"],   // 2026-07-21: DROP-ONLY (fed/cartel/van loot) -- USE installs the Plate Ghost quickhack permanently
    // 2026-07-21 TIER 4 + counter chips -- ALL DROP-ONLY (sell/buy price -1). USE installs the matching id
    // into AP_cdMods: 202 Blackout, 203 Flatline (single charge, burns on cast), 204 Memory Hole, 108 ICE Firewall.
    ["blackoutdaemon", "Blackout Daemon", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["flatlinecharge", "Flatline Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["memoryholechip", "Memory Hole Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["icefirewall", "ICE Firewall Chip", 1, -1, -1, 1, 450000, 450000, 450000, -1, "icons\qhchip.paa"],   // owner 2026-07-22: consumable firewall now ALSO sold at Kabuki (still drops)
    ["puppetchip", "Puppet Strings Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["chauffeurchip", "Chauffeur Override Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["detonatechip", "Detonate Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],   // apex drop, never sold (-1 prices)
    // chip-model (owner 2026-07-22): every civ hack = a chip. T1 (207-210) SOLD at Kabuki Electronics;
    // T3 (211-219) loot-only. USE installs permanently; duplicates refused (fn_useItem).
    ["pingchip", "Ping.exe Chip", 1, -1, -1, 1, 100000, 100000, 100000, -1, "icons\qhchip.paa"],
    ["distractchip", "Distract.exe Chip", 1, -1, -1, 1, 100000, 100000, 100000, -1, "icons\qhchip.paa"],
    ["staticchip", "Static Burst Chip", 1, -1, -1, 1, 100000, 100000, 100000, -1, "icons\qhchip.paa"],
    ["whiteoutchip", "Whiteout Chip", 1, -1, -1, 1, 100000, 100000, 100000, -1, "icons\qhchip.paa"],
    ["stickychip", "Sticky Fingers Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["jamchip", "Jam.exe Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["wiretapchip", "Wiretap Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["crybabychip", "Crybaby Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["synapsechip", "Synapse Drag Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["leechchip", "Leech Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["shortchip", "Short Circuit Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["eyespychip", "Eye Spy Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["valetchip", "Valet Protocol Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    // owner 2026-07-23: Kabuki scroll-buy MODULES converted to shop chips, $1M flat. USE installs the
    // module id (deck upgrade / firewall permanent) via the same chip path. Ids match AP_cdModules.
    ["overclockchip", "Overclock Chip", 1, -1, -1, 1, 1000000, 1000000, 1000000, -1, "icons\qhchip.paa"],
    ["coolingrigchip", "Cooling Rig Chip", 1, -1, -1, 1, 1000000, 1000000, 1000000, -1, "icons\qhchip.paa"],
    ["reflexchip", "Reflex Tuning Implant", 1, -1, -1, 1, 1500000, 1500000, 1500000, -1, "icons\qhchip.paa"],   // owner 2026-09-16: bioware id 5 -- wall running, any side
    ["signalampchip", "Signal Amp Chip", 1, -1, -1, 1, 1000000, 1000000, 1000000, -1, "icons\qhchip.paa"],
    ["scramblerchip", "Scrambler Chip", 1, -1, -1, 1, 250000, 250000, 250000, -1, "icons\qhchip.paa"],
    ["opticfilterchip", "Optic Filter Chip", 1, -1, -1, 1, 250000, 250000, 250000, -1, "icons\qhchip.paa"],
    ["audiolimiterchip", "Audio Limiter Chip", 1, -1, -1, 1, 250000, 250000, 250000, -1, "icons\qhchip.paa"],
    ["hardenedfwchip", "Hardened Firmware Chip", 1, -1, -1, 1, 400000, 400000, 400000, -1, "icons\qhchip.paa"],
    ["deadboltchip", "Deadbolt Chip", 1, -1, -1, 1, 350000, 350000, 350000, -1, "icons\qhchip.paa"],
    ["freqhopchip", "Freq-Hop Radio Chip", 1, -1, -1, 1, 300000, 300000, 300000, -1, "icons\qhchip.paa"],
    ["encryptedsimchip", "Encrypted SIM Chip", 1, -1, -1, 1, 350000, 350000, 350000, -1, "icons\qhchip.paa"],
    ["surgechip", "Surge Protector Chip", 1, -1, -1, 1, 300000, 300000, 300000, -1, "icons\qhchip.paa"],
    ["copilotchip", "Co-Pilot Guardian Chip", 1, -1, -1, 1, 350000, 350000, 350000, -1, "icons\qhchip.paa"],
    ["sealedtankchip", "Sealed Tank Chip", 1, -1, -1, 1, 250000, 250000, 250000, -1, "icons\qhchip.paa"],
    ["deadmanchip", "Dead Man's Clutch Chip", 1, -1, -1, 1, -1, -1, -1, -1, "icons\qhchip.paa"],
    ["proxychain", "Proxy Chain", 1, -1, -1, 1, 60000, 60000, 60000, -1, "icons\debitcard.paa"],   // owner 2026-07-20: cyberdeck consumable -- USE to arm; your NEXT hack leaves no MaxSec ping (Kabuki Electronics)
    ["breachkit", "Breach Kit", 2, -1, -1, 1, 150000, 150000, 150000, -1, "icons\debitcard.paa"],   // owner 2026-07-20: cyberdeck consumable -- USE to arm; your NEXT Sequence/Terminal breach auto-completes
    ["uraniumu", "Uranium Ore", 3, -1, 200, -1, -1, -1, -1, -1, "icons\uraniumu.paa"],
    ["uraniump", "Uranium (Weapon Grade)", 2, -1, 300, 1, 1000, 800, 575, -1, "icons\uraniump.paa"],
    ["element115", "Element 115", 2, -1, 300, 1, -1, 100000, 69420, -1, "icons\element115.paa"],
    ["turtlesoup", "Turtle Soup", 2, -1, 200, -1, 267, 250, 175, -1, "icons\turtlesoup.paa"],
    ["vammo", "Vehicle Ammo", 5, -1, -1, -1, 3739, 3500, 2450, -1, "icons\vammo.paa"],
    ["water", "Water Bottle", 1, -1, -1, -1, 7, 7, 5, -1, "icons\water.paa"],
    ["whiskeyc_0", "White Dog Corn Whiskey", 3, -1, 150, -1, 181, 170, 180, -1, "icons\whiskeyc_0.paa"],
    ["whiskeyc_1", "Corn Whiskey", 3, -1, 150, -1, 427, 400, 426, -1, "icons\whiskeyc_1.paa"],
    ["whiskeyc_2", "Aged Corn Whiskey", 3, -1, 150, -1, 640, 600, 639, -1, "icons\whiskeyc_2.paa"],
    ["whiskeyc_3", "Reserve Corn Whiskey", 3, -1, 150, -1, 988, 925, 987, -1, "icons\whiskeyc_3.paa"],
    ["whiskeyr_0", "White Dog Rye Whiskey", 3, -1, 150, -1, 213, 200, 212, -1, "icons\whiskeyr_0.paa"],
    ["whiskeyr_1", "Rye Whiskey", 3, -1, 150, -1, 480, 450, 479, -1, "icons\whiskeyr_1.paa"],
    ["whiskeyr_2", "Aged Rye Whiskey", 3, -1, 150, -1, 694, 650, 693, -1, "icons\whiskeyr_2.paa"],
    ["whiskeyr_3", "Reserve Rye Whiskey", 3, -1, 150, -1, 1014, 950, 1013, -1, "icons\whiskeyr_3.paa"],
    ["woodaxe", "Wood Axe", 2, -1, -1, -1, 100, 75, 35, -1, "icons\woodaxe.paa"],
    ["yeast", "Yeast", 1, -1, -1, -1, 20, 20, 11, -1, "icons\yeast.paa"],
    ["ziptie", "Ziptie", 1, -1, -1, -1, 24, 20, 15, -1, "icons\ziptie.paa"],
    ["moonshinehash", "Moonshine Hash", 3, -1, 100, -1, 45, 380, 125, -1, "icons\agingbarrel.paa"],
    ["moonshine", "Homebrew Moonshine", 3, -1, 100, -1, 600, 380, 790, -1, "icons\moonshine.paa"],
    ["moonshinep", "White Lightning", 3, -1, 100, -1, 1300, 380, 1100, -1, "icons\moonshine.paa"],
    // ---- 3D printer feedstock (2026-08-21). Every one of these is PRINTED, never bought: buy
    // price is -1 across the board and none of them is listed in fn_virt_shops, so no NPC sells
    // them. The max/sell figures are REFERENCE VALUES ONLY -- they anchor the Exchange's price
    // bands and the dynamic-market factor; nothing in the world pays them out today, and under the
    // closed-economy direction nothing should. filament is the backbone the schematic price is
    // derived from (AP_fnc_fabFee), which makes its numbers the single economic lever here.
    ["filament", "Printer Filament", 1, -1, -1, -1, 900, -1, 700, -1, "icons\filament.paa"],
    ["polymer_pellet", "Polymer Pellets", 1, -1, -1, -1, 1400, -1, 1100, -1, "icons\polymer_pellet.paa"],
    ["optic_blank", "Optic Blank", 1, -1, -1, -1, 1300, -1, 1000, -1, "icons\optic_blank.paa"],
    ["circuit_lamina", "Circuit Lamina", 1, -1, -1, -1, 1200, -1, 900, -1, "icons\circuit_lamina.paa"],
    ["carbon_weave", "Carbon Weave", 2, -1, -1, -1, 3600, -1, 2800, -1, "icons\carbon_weave.paa"],
    ["nanofoam", "Nanofoam Block", 2, -1, -1, -1, 6500, -1, 5000, -1, "icons\nanofoam.paa"],
    ["ballistic_plate", "Ballistic Plate", 2, -1, -1, -1, 9500, -1, 7500, -1, "icons\ballistic_plate.paa"],
    // ---- lower receivers. The printer makes these and nothing else about a gun: a weapon is
    // assembled at a GUNSMITH BENCH from a receiver, the rest of its materials and its schematic.
    // Four classes rather than one universal part, so the printer's own level decides which weapon
    // classes you can supply the bench with -- and rather than one per gun, which would have meant
    // ~80 more item rows, icons and recipes for the same decision.
    ["lower_pistol", "Pistol Lower Receiver", 2, -1, 1200, -1, 9000, -1, 7000, -1, "icons\lower_pistol.paa"],
    ["lower_smg", "SMG Lower Receiver", 3, -1, 2400, -1, 18000, -1, 14000, -1, "icons\lower_smg.paa"],
    ["lower_rifle", "Rifle Lower Receiver", 10, -1, 5000, -1, 42000, -1, 33000, -1, "icons\lower_rifle.paa"],   // ECONOMY 2026-09-05: weight 4 -> 10. A printed receiver sold at $8,250 per weight unit, so printing-to-SELL beat printing-to-use and the fabricator became a money press rather than a way to arm yourself. Same treatment as the gold nugget: the value stands, the haulage stops being free.
    ["lower_heavy", "Heavy Lower Receiver", 16, -1, 9000, -1, 90000, -1, 70000, -1, "icons\lower_heavy.paa"],   // ECONOMY 2026-09-05: weight 6 -> 16, same reason -- $11,667 per weight unit was the second-densest good in the game behind the gold nugget.
    // Illegal (column 4 is the seizure value): an unserialised receiver is the part that makes a
    // printed gun a printed gun, so cops taking them off a courier should mean something.
    ["gunsmith_bench", "Gunsmith Bench", 45, -1, -1, -1, 180000, 160000, 140000, -1, "icons\gunsmith_bench.paa"],
    // ---- the printers themselves, as carryable items. Heavy on purpose: against AP_maxWeight 96
    // a CoreXY is a third of your capacity, so moving a workshop is a job with a truck rather than
    // an afterthought. Both are printed or traded, never bought.
    ["printer_i3", "i3 Fabricator", 20, -1, -1, -1, 90000, 75000, 45000, -1, "icons\printer_i3.paa"],
    ["printer_corexy", "CoreXY Fabricator", 35, -1, -1, -1, 320000, -1, 250000, -1, "icons\printer_corexy.paa"],
    // ---- schematic shards. Bought from the schematic vendor in New Drachma, not cash, so buy is
    // -1 here too; these rows exist so the shards can be carried, stored and listed on the
    // Exchange. Rarity is a FIELD on the schematic row, never inferred from the icon path.
    ["shard", "Data Shard", 1, -1, -1, -1, 12000, -1, 9000, -1, "icons\shard.paa"],
    ["shard_rare", "Encrypted Shard", 1, -1, -1, -1, 40000, -1, 30000, -1, "icons\shard_rare.paa"],
    ["shard_epic", "Black-ICE Shard", 1, -1, -1, -1, 120000, -1, 90000, -1, "icons\shard_epic.paa"]];
// owner 2026-06-24: DYNAMIC NAMED FORESKINS. Each circumcised cop = a per-uid virtual item foreskin_<uid> shown as
// "<victim>'s Foreskin". The registry AP_foreskinReg=[[uid,name],...] loads from the `foreskins` DB table on server
// boot + is publicVariable'd to every client (so a foreskin traded to another player still renders its name). Merging
// each entry here as a full item makes display / store / carry-weight / DB save+load all handle it generically (they
// iterate THIS cfg). Columns mirror the static "foreskin" row (weight 1, sells 7000 at the Blackmarket).
{if ((_x isEqualType []) && {count _x >= 2}) then {
        _itemArray pushBack [format ["foreskin_%1", _x select 0], format ["%1's Foreskin", _x select 1], 1, -1, 6000, -1, 7000, 7000, 6600, -1, "icons\manflesh.paa"];
    };} forEach _reg;
_idx = createHashMap;
_idxLife = createHashMap; {private _cls = _x select 0;
    if (isNil {_idx get _cls}) then { _idx set [_cls, _x]; };
    private _lk = format ["AP_inv_%1", _cls];
    if (isNil {_idxLife get _lk}) then { _idxLife set [_lk, _x]; };} forEach _itemArray;
localNamespace setVariable ["AP_virtItemArr", _itemArray];
localNamespace setVariable ["AP_virtItemIdx", _idx];
localNamespace setVariable ["AP_virtItemIdxLife", _idxLife];
localNamespace setVariable ["AP_virtItemRegSnap", +_reg];};
private "_return";
switch (_mode) do {case "getCfg": {_return = +_itemArray;}; case "getItemRow": {_return = +(_idx getOrDefault [_toFind, []]);};
        case "getItemWeight": {_return = (_idx getOrDefault [_toFind, []]) param[2, 0];};
        case "getShortName": {_return = (_idxLife getOrDefault [_toFind, []]) param[0, ""];};
        case "getMaxPrice": {private _ov = ["virt", _toFind] call AP_fnc_priceOv;   // Economy: p2 (idx4) = market max
                if (_ov isNotEqualTo [] && {(_ov select 4) >= 0}) exitWith { _return = _ov select 4; };
                private _row = _idx getOrDefault [_toFind, []];
                if (_row isNotEqualTo []) then {_return = (_row select 6);
                    if (_return isEqualTo - 1) then { _return = (_row select 7); };};};
        case "getBasePrice": {private _ov = ["virt", _toFind] call AP_fnc_priceOv;   // Economy: p0 (idx2) = base/buy
                if (_ov isNotEqualTo [] && {(_ov select 2) >= 0}) exitWith { _return = _ov select 2; };
                private _row = _idx getOrDefault [_toFind, []];
                if (_row isNotEqualTo []) then { _return = (_row select 7); };};
        case "getLowestPrice": {private _ov = ["virt", _toFind] call AP_fnc_priceOv;   // Economy: p1 (idx3) = lowest/sell
                // Economy 2026-06-16: farmable/tracked goods FLOOR their sell price at their MAX (idx 6); the
                // neglect premium (AP_fnc_marketFactor >= 1) then floats it ABOVE max. Untracked goods keep
                // their old lowest (idx 8) baseline. AP_marketGoods is publicVariable'd by APS_fnc_marketTick.
                private _tracked = (!isNil "AP_marketGoods") && {_toFind in AP_marketGoods};
                if (_ov isNotEqualTo [] && {(_ov select 3) >= 0}) then {_return = _ov select 3;} else {
                    private _row = _idx getOrDefault [_toFind, []];
                    if (_row isNotEqualTo []) then {_return = if (_tracked) then { _row select 6 } else { _row select 8 };
                        if (_return isEqualTo - 1) then { _return = (_row select 7); };};};
                // scale by the good's current premium (marketFactor returns 1 for any untracked good, so this
                // is a no-op there; tracked goods get maxPrice * prem).
                if (_return isEqualType 0 && {_return > 0}) then {_return = round (_return * ([_toFind] call AP_fnc_marketFactor));};};
        case "getIllegalPrice": {_return = (_idx getOrDefault [_toFind, []]) param[4, 0];};
        case "getIllegalItems": {_return = (_itemArray) select {(_x select 4) != -1}
                apply {[_x select 0, _x select 4]};};
        case "getIcon": {_return = (_idx getOrDefault [_toFind, []]) param[10, ""];};
        case "getName": {private _row = _idx getOrDefault [_toFind, []];
                if (_row isEqualTo []) then { _row = _idxLife getOrDefault [_toFind, []]; };
                _return = _row param[1, ""];};
        case "getEconList":   // LooneyBin Economy UI: [[key,name,base,low,max],...] for priced items
            {_return = (_itemArray select { (_x select 7) isNotEqualTo -1 }) apply {private _b = _x select 7;
                    private _l = _x select 8;
                    private _m = _x select 6;
                    [_x select 0, _x select 1, _b, (if (_l isEqualTo -1) then {_b} else {_l}), (if (_m isEqualTo -1) then {_b} else {_m})]
                };};
        case 0: {{missionNamespace setVariable[format["AP_inv_%1", _x select 0], 0];}
                forEach _itemArray;
                _return = true;};
        case 1: {_return = _itemArray apply {format["AP_inv_%1", _x select 0]};};
        case 2: {_return = _itemArray apply {_x select 0};};
        case 3: {{if !((_x select 2) isEqualTo 0) then {AP_invMonVars pushBackUnique format["AP_inv_%1", _x select 0];};}
                forEach _itemArray;
                _return = true;};}; _return ;