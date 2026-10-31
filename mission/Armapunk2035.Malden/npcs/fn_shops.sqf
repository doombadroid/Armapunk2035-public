params["_obj_main", "_stance", ["_type", "", [""]]];
if (_obj_main isKindOf "CAManBase") then {};
// owner 2026-06-13 (#170): block the building this shop NPC sits in from being bought as a house. The
// AP_restricted_house guard exists in fn_buyHouse/fn_houseMenu but was NEVER set anywhere, so NPC shop
// buildings (e.g. the Kavala gun store) were purchasable. Flag the nearest house-type building (runs per
// client when the NPC spawns; fn_buyHouse reads the flag locally on the buyer).
if (!isNull _obj_main) then {private _ht = if (isNil "AP_houseTypes") then { ["House_F"] } else { AP_houseTypes };
    // owner 2026-06-20: flag the nearest UN-OWNED house-type building (the shop's own building), SKIPPING registered
    // player houses. A player house that happens to sit within 10m of a shop NPC (e.g. the Athira big house by the
    // market, oid 1403618707) was being grabbed as the "nearest" and flagged AP_restricted_house=true -> the owner
    // lost their House Menu + grab-ID. Owned houses carry AP_homeOwner (set by fn_receiveHouses/_tagHouses, broadcast
    // global) so a connecting client sees it here; iterate by distance and flag the first that ISN'T an owned house.
    {if ((_x getVariable ["AP_homeOwner", ""]) isEqualTo "") exitWith { _x setVariable ["AP_restricted_house", true]; };
    } forEach (nearestObjects [getPosATL _obj_main, _ht, 10]);};
switch (_type) do {case "wongs": {
            _obj_main addAction["Wong's Food Court", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            _obj_main setVariable["AP_name", "Wong The Dong"]}; case "redburger": {
                _obj_main addAction["Red Burger", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", '', 5];};
        case "diamond": {
                _obj_main addAction["Jewelry Store", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "oil": {
                _obj_main addAction["Oil Trader", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "paintshop": {
                _obj_main addAction["Pay 'n' Spray", AP_fnc_vehicleSkinShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "home": {_obj_main addAction["Locate Homes for Sale", {
                    ["Houses listed for sale by owner have been marked on your map.", "basic"] spawn AP_fnc_handleMessage;
                    private _houses = (player nearObjects["House_F", 25000]) select {_x getVariable["AP_house_price", -1] > 1}; {
                        private _marker = createMarkerLocal[format["listhouse_%1", _forEachIndex], getPos _x];
                        _marker setMarkerTypeLocal "hd_warning";
                        _marker setMarkerColorLocal "colorRed";
                        _marker setMarkerTextLocal format["House For Sale: $%1", [_x getVariable "AP_house_price"] call AP_fnc_numberText];
                        AP_houseListMarkers pushBack _marker;}
                    forEach _houses;
                }, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && AP_houseListMarkers isEqualTo []', 6];
                _obj_main addAction["Remove House Markers", {["Markers removed from your map.", "basic"] spawn AP_fnc_handleMessage; {
                        deleteMarkerLocal _x}
                    forEach AP_houseListMarkers;
                    AP_houseListMarkers = []
                }, "", 1.5, false, false, "", '!(AP_houseListMarkers isEqualTo []) && AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "fishmarket": {
                _obj_main addAction["Fish Market", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "salt": {
                _obj_main addAction["Salt Trader", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "market": {
                _obj_main addAction["Market", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'isNull objectParent player', 5];};
        case "heroin": {
                _obj_main addAction["Drug Dealer", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                _obj_main addAction["<t color='#ff547f'>Sell Vehicle Inventory</t>", AP_fnc_sellVehicleInv, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && !(missionNamespace getVariable ["AP_bulkSell", false])', 5];
                _obj_main addAction["<img image='mpmissions\__cur_mp.altis\icons\cannabisplant.paa' /> <t color='#ff547f'>Dry Indica Plant</t>", AP_fnc_processAction, "cannai_2", 1.5, false, false, "", 'AP_inv_cannai_2 > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["<img image='mpmissions\__cur_mp.altis\icons\cannabisplant.paa' /> <t color='#ff547f'>Dry Sativa Plant</t>", AP_fnc_processAction, "cannas_2", 1.5, false, false, "", 'AP_inv_cannas_2 > 0 && !AP_is_processing && AP_effSide isEqualTo civilian', 5];
                // owner 2026-06-22: bud -> Golden Wax REMOVED from the Drug Dealer -- wax is now made ONLY at the weed
                // processor (fn_civProcessItem "marijuana" case: hand "Process Indica Bud into Golden Wax" + the bulk
                // vehicle option). The plant -> bud DRYING actions above STAY at the dealer; only the bud -> wax step
                // moved back to weed-processing-only. (Reverses the 2026-06-14 "wax at every dealer" change.)
            };
        case "commod": {
                _obj_main addAction["Commodities Trading", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
            };
        case "gun": {
                _obj_main addAction["Firearm License ($250)", AP_fnc_buyLicense, _type, 1.5, false, false, "", '!license_civ_gun && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Gun Store", AP_fnc_weaponShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && license_civ_gun', 5];
            };
        case "genstore": {
                _obj_main addAction["General Store", AP_fnc_weaponShopMenu, "genstore", 1.5, false, false, "", 'isNull objectParent player', 5];
            };
        case "civ": {
                _obj_main addAction["Clothing Shop", AP_fnc_clothingMenu, _type, 1.5, false, false, "", 'isNull objectParent player', 5];
                // Face shop (owner 2026-08-03, BUGS.md #65). Free. The "faces" shop type was already
                // plumbed through clothingMenu/clothingFilter/changeClothes/buyClothes but no NPC ever
                // offered it, so it was unreachable. Faces come from the FSOF pack in the @Armapunk2035
                // client mod; without the mod loaded the list resolves to nothing and shows empty, so the
                // action is safe to offer to everyone rather than gated on a mod check the client cannot
                // honestly answer.
                _obj_main addAction["Face Shop", AP_fnc_clothingMenu, "faces", 1.5, false, false, "", 'isNull objectParent player', 5];
            };
        case "dive": {
                _obj_main addAction["Diving License ($200)", AP_fnc_buyLicense, 'dive', 1.5, false, false, "", '!license_civ_dive && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Diving Shop", AP_fnc_clothingMenu, _type, 1.5, false, false, "", 'license_civ_dive && AP_effSide isEqualTo civilian', 5];
            };
        case "vig": {
                _obj_main addAction["Bounty Hunter Training ($6,500) <t color='#FF0000'>(replace rebel)</t>", AP_fnc_buyLicense, "bounty", 1.5, false, false, "", '!license_civ_bounty && AP_effSide isEqualTo civilian && (1 in AP_side_talents)', 5];
                _obj_main addAction["Bounty Hunter Shop", AP_fnc_weaponShopMenu, "bounty", 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Bounty Hunter Item Shop", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Request Bounty", {[] call AP_fnc_requestBounty
                }, nil, 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu
                }, nil, 2, true, true, "", 'isNull objectParent player', 5];
                _obj_main addAction["<t color='#FFFF2F'>Gang Account</t>", {[] call AP_fnc_gangAtmMenu
                }, nil, 2, true, true, "", '(count AP_gang_data > 0)', 5];};
        case "laser": {
                _obj_main addAction["Queue for Laser tag", AP_fnc_laserJoin, "", 0, false, false, "", ' AP_effSide isEqualTo civilian', 5];
            };
        case "medicaldispensary": {
                _obj_main addAction["Medical Dispensary", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'isNull objectParent player', 5];
            };
        case "tech": {
                // owner 2026-07-23: the per-module scroll-buy loop is GONE -- deck modules + firewall permanents
                // sell as $1M chips in the Kabuki virtual shop (USE installs; see fn_virt_shops / fn_useItem).
                // owner 2026-09-05: AND THE TWO BOOTSTRAP ACTIONS ARE GONE TOO. "Flash Cyberdeck Firmware"
                // ($1,000, module id 0) and "Buy VR Goggles" ($1,000, G_Goggles_VR) both sold prerequisites
                // that no longer exist: every civilian boots ICEBREAKER OS on spawn (AP_fnc_hasDeck is now
                // just the side check) and the visor no longer looks at your face. Nothing else buys module
                // id 0 -- it is not in the chip map -- so AP_fnc_cyberdeckBuyModule is now modules 1+ only.
                // G_Goggles_VR is still sold as ordinary clothing (fn_clothing_civ / fn_clothing_reb) and is
                // still fabricable (fn_fabGen); it is cosmetic now, it gates nothing.
                // the store: consumables + every purchasable chip (T1 hacks, modules, firewall permanents)
                _obj_main addAction ["<t color='#33ffbb'>Kabuki Electronics -- Chips & Consumables</t>", AP_fnc_virtualShopMenu, _type, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player', 5];
                // CHIP RECYCLER (owner 2026-07-23): melt 3 duplicate hack chips into 1 random Tier-3 chip.
                _obj_main addAction ["<t color='#c9e21a'>Chip Recycler</t> <t color='#7f918a'>-- melt 3 chips into 1 random Tier 3</t>", { [] spawn AP_fnc_qhRecycle; }, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian && isNull objectParent player && (call AP_fnc_hasDeck)', 5];
            };};