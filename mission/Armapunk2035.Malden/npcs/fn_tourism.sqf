params["_obj_main", "_stance", "_applyCop"];
if (_obj_main isKindOf "CAManBase") then {};
switch (_applyCop) do {case true: {_obj_main addAction["Skydive! ($200)", AP_fnc_skyDive, "", 1.5, false, false, "", '', 5];
            _obj_main addAction["Join the Police", AP_fnc_policeRecruit, "", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
        };
    case false: {_obj_main addAction["Skydive! ($200)", AP_fnc_skyDive, "", 1.5, false, false, "", 'AP_effSide isEqualTo civilian', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store', 5];}}