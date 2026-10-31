params["_obj_main", "_stance", "_turf"];
if (_obj_main isKindOf "CAManBase") then {};
switch (_turf) do {case "Rodopoli": {
            _obj_main addAction["Drug Dealer", AP_fnc_virtualShopMenu, "heroin", 1.5, false, false, "", ' AP_effSide isEqualTo civilian', 5];
        }; case "Zaros": {
                _obj_main addAction["Drug Dealer", AP_fnc_virtualShopMenu, "heroin", 1.5, false, false, "", ' AP_effSide isEqualTo civilian', 5];
            };
        case "Panagia": {
                _obj_main addAction["Drug Dealer", AP_fnc_virtualShopMenu, "heroin", 1.5, false, false, "", ' AP_effSide isEqualTo civilian', 5];
            };};