params["_obj_main", "_stance", "_type"];
if (_obj_main isKindOf "CAManBase") then {};
// 2026-08-22: the Factory builds VEHICLES and nothing else. Both remaining spawn types open the
// same one station -- the "weapons" and "blackmarket" production catalogues moved to the Fabricator.
//
// The blackmarket case keeps the vehicle action deliberately. It is the ONLY factory NPC actually
// placed on Malden (edenNPC_data has no "vehicles" row), so dropping its production action would
// leave the vehicle factory reachable from nowhere at all. Its shop and gold-bar actions are
// untouched -- they are not production.
switch (_type) do {case "vehicles": {_obj_main addAction["Vehicle Production", {["vehicles"] call AP_fnc_factory
            }, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];}; case "weapons": {
                _obj_main addAction["Vehicle Production", {["vehicles"] call AP_fnc_factory
                }, nil, 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];};
        case "blackmarket": {_obj_main addAction["Vehicle Production", {["vehicles"] call AP_fnc_factory
                }, nil, 0, false, false, "", 'AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Black Market", AP_fnc_virtualShopMenu, "blackmarket", 0, false, false, "", 'AP_effSide isEqualTo civilian', 5];
                _obj_main addAction["Break Down Gold Bar", AP_fnc_processAction, "goldnugget", 1.5, false, false, "", 'AP_inv_goldbar > 0 && !AP_is_processing', 5];
            };};