params["_obj_main", "_stance", "_type"];
if (_obj_main isKindOf "CAManBase") then {};
switch (_type) do {case "clinic": {_obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu
            }, nil, 2, true, true, "", 'isNull objectParent player', 5];
            _obj_main addAction["Medical Assistance", AP_fnc_healHospital, "", 1.5, false, false, "", '', 5];
            _obj_main addAction["TT Item Shop", AP_fnc_virtualShopMenu, "hospital", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
            _obj_main addAction["TT Item Shop", AP_fnc_virtualShopMenu, "meditemshop", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
            _obj_main addAction["TT Equipment Shop", AP_fnc_weaponShopMenu, "med_basic", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
            _obj_main addAction["Check in to Rehab", {[] spawn AP_fnc_rehab}, "", 0, false, false, "", '', 5];}; case "hospital": {
                _obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu
                }, nil, 2, true, true, "", 'isNull objectParent player', 5];
                _obj_main addAction["Medical Assistance", AP_fnc_healHospital, "", 1.5, false, false, "", '', 5];
                _obj_main addAction["TT Item Shop", AP_fnc_virtualShopMenu, "hospital", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["TT Item Shop", AP_fnc_virtualShopMenu, "meditemshop", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["TT Equipment Shop", AP_fnc_weaponShopMenu, "med_basic", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["Check in to Rehab", {[] spawn AP_fnc_rehab}, "", 0, false, false, "", '', 5];};
        case "clothing": {
                _obj_main addAction["Loadout System", AP_fnc_loadoutMenu, "medic", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["TT Uniform Shop", AP_fnc_clothingMenu, "med", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                _obj_main addAction["Redeploy Me!", AP_fnc_redeployMenu, "", 1.5, false, false, "", 'AP_effSide isEqualTo independent', 5];
                // owner 2026-07-13: firefighting opened to ALL independent-whitelisted TT. Removed the separate
                // Register/Resign firefighter whitelist (AP_isFirefighter) and the medic-level requirement --
                // any TT can now respond to an active fire directly from the clinic.
                _obj_main addAction["<t color='#8b2b13'>Respond to Active Fire</t>", {
                    ["toggleFirefighter", [SRV_houseOnFire]] spawn AP_fnc_medicFireClient
                }, "", 1.5, false, false, "", '(AP_effSide isEqualTo independent) && !AP_isActiveFirefighter && (count SRV_houseOnFire != 0)', 5];
            };};
"<img image='mpmissions\__cur_mp.altis\icons\canna_rawpapers.paa' /> <t color='#8b2b13'>Sign Up As Firefighter</t>"
