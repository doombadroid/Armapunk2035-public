params["_obj_main", "_stance"];
if (_obj_main isKindOf "CAManBase") then {};
_obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu}, nil, 2, true, true, "", 'isNull objectParent player', 5];
_obj_main addAction["Loadout System", AP_fnc_loadoutMenu, "skiptracer", 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian && (8 in AP_side_talents)', 5];
_obj_main addAction["Bounty Hunter Shop", AP_fnc_weaponShopMenu, "bounty", 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian', 5];
_obj_main addAction["Bounty Hunter Item Shop", AP_fnc_virtualShopMenu, "vig", 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian', 5];
_obj_main addAction["Skiptracer Clothing Shop", AP_fnc_clothingMenu, "skip", 1.5, false, false, "", ' license_civ_bounty && AP_effSide isEqualTo civilian && 8 in AP_side_talents', 5];
_obj_main addAction["Skiptracer Weapon Shop", AP_fnc_weaponShopMenu, "skiptracer", 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian && (8 in AP_side_talents)', 5];
_obj_main addAction["Bounty Hunter Training ($12,500) <t color='#FF0000'>(replace rebel)</t>", AP_fnc_buyLicense, "bounty", 1.5, false, false, "", '!license_civ_bounty && AP_effSide isEqualTo civilian && (1 in AP_side_talents)', 5];
_obj_main addAction["Skiptracer Item Shop", AP_fnc_virtualShopMenu, "skiptracer", 1.5, false, false, "", ' license_civ_bounty && AP_effSide isEqualTo civilian && (8 in AP_side_talents)', 5];
_obj_main addAction["Request Bounty", {[] call AP_fnc_requestBounty
}, nil, 1.5, false, false, "", ' license_civ_bounty && AP_effSide isEqualTo civilian && (8 in AP_side_talents)', 5];
_obj_main addAction["General Store", AP_fnc_weaponShopMenu, "genstore", 1.5, false, false, "", 'isNull objectParent player', 5];
_obj_main addAction["Refill Magazines", AP_fnc_refillAmmo, "", 1.5, false, false, "", 'license_civ_bounty && AP_effSide isEqualTo civilian', 5];
_obj_main addAction["EMT Item Shop", AP_fnc_virtualShopMenu, "hospital", 1.5, false, false, "", '', 5];
_obj_main addAction["Medical Assistance", AP_fnc_healHospital, "", 1.5, false, false, "", '', 5];