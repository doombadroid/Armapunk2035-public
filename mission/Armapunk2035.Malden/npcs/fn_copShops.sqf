params["_obj_main", "_stance", "_type"];
// owner 2026-06-13 (#170): same shop-building protection as fn_shops -- block the cop-shop building from
// being bought as a house (AP_restricted_house was never set anywhere).
if (!isNull _obj_main) then {private _ht = if (isNil "AP_houseTypes") then { ["House_F"] } else { AP_houseTypes };
    // owner 2026-06-20: flag the nearest UN-OWNED house-type building, skipping registered player houses (see fn_shops)
    // -- a player house within 10m of a cop-shop NPC was being grabbed + restricted, killing the owner's house menu.
    {if ((_x getVariable ["AP_homeOwner", ""]) isEqualTo "") exitWith { _x setVariable ["AP_restricted_house", true]; };
    } forEach (nearestObjects [getPosATL _obj_main, _ht, 10]);};
// owner 2026-06-15: de-brand EVERY cop-shop NPC (gear vendor 'general', diving, copdive). They wore the bare
// stock Rangemaster -- the stock upstream cop look -- and the fix that day was a sgt_grumpy MaxSec retexture,
// matching the cop recruiter (NPC_fnc_applyCop). SUPERSEDED the next day (below) and the skin itself was
// deleted 2026-08-13, so no texture is applied here.
if (_obj_main isKindOf "CAManBase") then {
    // owner 2026-06-16: strip the uniform instead (naked) -- U_Rangemaster IS the stock cop look, so the
    // retexture added nothing over it. The de-brand is the strip, nothing else.
    // owner 2026-07-10: SKIP when the map data dressed this NPC with a custom
    // loadout (Eden round-trip, fn_createVehicleLocal tags AP_hasLoadout) -- stripping undid the outfit.
    if !(_obj_main getVariable ["AP_hasLoadout", false]) then { removeUniform _obj_main; };};
switch (_type) do {case "general": {
            _obj_main addAction["Report for MaxTac Duty", AP_fnc_maxtacEnroll, nil, 2, false, true, "", 'AP_effSide isEqualTo west && SRV_MAXTACrequested && AP_isMaxTac && !AP_activeMAXTAC', 5];
            _obj_main addAction["<t color='#1E90FF'>MaxTac Armory</t>", AP_fnc_weaponShopMenu, "maxtac_weapons", 2, false, false, "", 'AP_effSide isEqualTo west && AP_isMaxTac', 5];
            _obj_main addAction["<t color='#ADFF2F'>ATM</t>", {[] call AP_fnc_atmMenu
            }, nil, 2, true, true, "", 'isNull objectParent player', 5];
            _obj_main addAction["Loadout System", AP_fnc_loadoutMenu, "cop", 1.5, false, false, "", 'AP_effSide isEqualTo west && !AP_activeMAXTAC', 5];
            _obj_main addAction["Redeploy Me!", AP_fnc_redeployMenu, "", 1.5, false, false, "", 'AP_effSide isEqualTo west && (AP_serverId isEqualTo 1)', 5];
            _obj_main addAction["Gear Up!", AP_fnc_reGear, "", 1.5, false, false, "", 'AP_effSide isEqualTo west && count AP_dead_gear > 0 && !AP_activeMAXTAC && !AP_eviSpawn && (AP_serverId isEqualTo 1)', 5];
            _obj_main addAction["Police Items Shop", AP_fnc_virtualShopMenu, "cop", 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
            // owner 2026-09-05: the $1,000 "MaxSec VR Goggles" buy is REMOVED. It sold the hardware gate for
            // the TAL OS ring (SHIFT+Y); that gate is gone from fn_visorOpen, so every officer has the visor
            // from spawn and this action sold nothing. See talos.md.
            _obj_main addAction["Police Uniform Shop", AP_fnc_clothingMenu, "cop", 1.5, false, false, "", 'AP_effSide isEqualTo west  && !AP_activeMAXTAC', 5];
            _obj_main addAction["Police Equipment Shop", AP_fnc_weaponShopMenu, "police_equipment", 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
            _obj_main addAction["Police Weapons Shop", AP_fnc_weaponShopMenu, "police_weapons", 1.5, false, false, "", 'AP_effSide isEqualTo west && !AP_activeMAXTAC', 5];
            _obj_main addAction["Air Training ($1,500)", AP_fnc_buyLicense, "pilot", 1.5, false, false, "", '!license_cop_air && AP_effSide isEqualTo west && (call AP_copLevel) > 1', 5];
            _obj_main addAction["EMT Item Shop", AP_fnc_virtualShopMenu, "hospital", 1.5, false, false, "", 'isNull objectParent player && AP_effSide isEqualTo west', 5];
            _obj_main addAction["Medical Assistance", AP_fnc_healHospital, "", 1.5, false, false, "", '', 5];
            _obj_main addAction["Refill Magazines", AP_fnc_refillAmmo, "", 1.5, false, false, "", 'AP_effSide isEqualTo west', 5];
}; case "diving": {
                _obj_main addAction["Refill Magazines", AP_fnc_refillAmmo, "", 1.5, false, false, "", 'AP_effSide isEqualTo west && (call AP_copLevel) > 1', 5];
            };
        case "copdive": {
                _obj_main addAction["Diving Shop", AP_fnc_clothingMenu, "copdive", 1.5, false, false, "", 'AP_effSide isEqualTo west && (call AP_copLevel) > 1', 5];
            };};