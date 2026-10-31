params["_obj_main", "_spawns", "_stance", "_location"];
if (_obj_main isKindOf "CAManBase") then {};
switch (_location) do {case 1: {
            _obj_main addAction["Get Plane Drug Runner Job", AP_fnc_airplaneDrugRunner, 1, 1.5, false, false, "", 'AP_drug_stage isEqualTo 0', 5];
            _obj_main addAction["Load Drugs on Plane", {AP_drug_stage = 2
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 1) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Deliver to Smuggler", {AP_drug_stage = 3
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 2) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Abandon Job!", AP_fnc_airplaneDrugRunner, 0, 1.5, false, false, "", '(AP_drug_stage >= 1)', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 1.5, false, false, "", '!AP_garage_store'];};
    case 2: {
            _obj_main addAction["Get Plane Drug Runner Job", AP_fnc_airplaneDrugRunner, 2, 1.5, false, false, "", 'AP_drug_stage isEqualTo 0', 5];
            _obj_main addAction["Load Drugs on Plane", {AP_drug_stage = 2
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 1) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Deliver to Smuggler", {AP_drug_stage = 3
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 2) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Abandon Job!", AP_fnc_airplaneDrugRunner, 0, 1.5, false, false, "", '(AP_drug_stage >= 1)', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 0, false, false, "", '!AP_garage_store', 5];};
    case 3: {
            _obj_main addAction["Get Plane Drug Runner Job", AP_fnc_airplaneDrugRunner, 3, 1.5, false, false, "", 'AP_drug_stage isEqualTo 0', 5];
            _obj_main addAction["Load Drugs on Plane", {AP_drug_stage = 2
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 1) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Deliver to Smuggler", {AP_drug_stage = 3
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 2) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Abandon Job!", AP_fnc_airplaneDrugRunner, 0, 1.5, false, false, "", '(AP_drug_stage >= 1)', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 0, false, false, "", '!AP_garage_store', 5];};
    case 4: {
            _obj_main addAction["Get Plane Drug Runner Job", AP_fnc_airplaneDrugRunner, 4, 1.5, false, false, "", 'AP_drug_stage isEqualTo 0', 5];
            _obj_main addAction["Load Drugs on Plane", {AP_drug_stage = 2
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 1) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Deliver to Smuggler", {AP_drug_stage = 3
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 2) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Abandon Job!", AP_fnc_airplaneDrugRunner, 0, 1.5, false, false, "", '(AP_drug_stage >= 1)', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 0, false, false, "", '!AP_garage_store', 5];};
    case 5: {
            _obj_main addAction["Get Plane Drug Runner Job", AP_fnc_airplaneDrugRunner, 5, 1.5, false, false, "", 'AP_drug_stage isEqualTo 0', 5];
            _obj_main addAction["Load Drugs on Plane", {AP_drug_stage = 2
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 1) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Deliver to Smuggler", {AP_drug_stage = 3
            }, "", 1.5, false, false, "", '(AP_drug_stage isEqualTo 2) && (AP_drug_end isEqualTo _target)', 5];
            _obj_main addAction["Abandon Job!", AP_fnc_airplaneDrugRunner, 0, 1.5, false, false, "", '(AP_drug_stage >= 1)', 5];
            _obj_main addAction["Vehicle Garage", {["Car", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Helicopter Garage", {["Air", _this select 3] call AP_fnc_handleVehicles;
            }, _spawns, 1.5, false, false, "", 'isNull objectParent player', 5];
            _obj_main addAction["Store vehicle in Garage", AP_fnc_storeVehicle, "", 0, false, false, "", '!AP_garage_store', 5];};};