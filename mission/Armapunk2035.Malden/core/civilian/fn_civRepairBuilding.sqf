params[["_caseType", "", [""]], ["_repairHouseData", [], [[]]]];
switch (_caseType) do {case ("requestRepair"): {private _ruins =
            if ((((typeOf cursorObject) find "ruin") != -1) || (((typeOf cursorObject) find "dam") != -1)) then {cursorObject} else {
                objNull};
            if (isNull _ruins) exitWith {["You must be looking at the ruins of the building!"] spawn AP_fnc_handleMessage};
            if ((allPlayers select {(side _x isEqualTo independent) && (_x distance(getMarkerPos "respawn_civilian") > 1000)
            }) isEqualTo[]) exitWith {
                ["There's currently no TT medics available to repair your building. Please try again later.", "basic"] spawn AP_fnc_handleMessage
            };
            private _building = (nearestTerrainObjects[player, ["House"], 7, true, true]) param[0, objNull];
            private _building =
            if (_building getVariable["AP_terrainObject_repaired", false]) then {
                (nearestObjects[player, ["House"], 7, true, true]) param[0, objNull]} else {_building};
            private _buildingRepairPrice = (([typeOf _building] call AP_fnc_houseConfig) param[1, 150000]) * 0.3;
            if (_building getVariable["AP_houseOnFire", false]) exitWith {
                ["You can't request TT repair on a burning building!"] spawn AP_fnc_handleMessage};
            if (AP_atmcash < _buildingRepairPrice) exitWith {
                [format["You don't have enough money to have this building repaired. It requires $%1.", [_buildingRepairPrice] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage
            };
            private _confirm = [format["Having this building repaired will cost $%1. Are you sure?", [_buildingRepairPrice] call AP_fnc_numberText], "TT Building Repair", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_confirm) exitWith {}; [
                ["requestRepair", [_ruins, _building, player]], "AP_fnc_medicRepairBuilding", independent] spawn AP_fnc_MP;
            _building setVariable["AP_repairRequested", true, true];
            ["The TT has been notified of your building repair request.", "basic"] spawn AP_fnc_handleMessage;};
        case ("kitRepair"): {
            // owner 2026-06-23: CIV self-repairs their OWN destroyed house with a House Repair Kit (Hospital shop,
            // $50k, consumed per repair). Same repair as a medic's actionRepair, minus the TT payment -- the kit IS
            // the cost. Home-owner only. Anti-dupe: re-check the kit at completion before consuming.
            if (AP_inv_houserepairkit < 1) exitWith { ["You don't have a House Repair Kit.", "basic"] spawn AP_fnc_handleMessage };
            private _ruins = if ((((typeOf cursorObject) find "ruin") != -1) || (((typeOf cursorObject) find "dam") != -1)) then { cursorObject } else { objNull };
            if (isNull _ruins) exitWith { ["You must be looking at the ruins of your building!", "basic"] spawn AP_fnc_handleMessage };
            private _building = (nearestTerrainObjects[player, ["House"], 7, true, true]) param[0, objNull];
            if (_building getVariable["AP_terrainObject_repaired", false]) then { _building = (nearestObjects[player, ["House"], 7, true]) param[0, objNull]; };
            if (isNull _building) exitWith {};
            if !(damage _building isEqualTo 1) exitWith { ["This building isn't destroyed.", "basic"] spawn AP_fnc_handleMessage };
            if (_building getVariable["AP_houseOnFire", false]) exitWith { ["You can't repair a burning building!", "basic"] spawn AP_fnc_handleMessage };
            if !((_building getVariable["AP_homeOwner", ""]) isEqualTo (getPlayerUID player)) exitWith { ["You can only repair a house you own.", "basic"] spawn AP_fnc_handleMessage };
            if !(isNull(_building getVariable["AP_repairingBuilding", objNull])) exitWith { ["This building is already being repaired.", "basic"] spawn AP_fnc_handleMessage };
            _building setVariable["AP_repairingBuilding", player, true];
            disableSerialization;
            5 cutRsc["AP_progress", "PLAIN"];
            private _ui = uiNamespace getVariable "AP_progress";
            private _progress = _ui displayCtrl 38201;
            private _pgText = _ui displayCtrl 38202;
            private _text = format["Repairing %1", getText(configFile >> "CfgVehicles" >> typeOf _building >> "displayName")];
            _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
            _progress progressSetPosition 0.01;
            AP_action_in_use = true;
            private _cP = 0.01;
            private _success = false;
            private _startPos = getPos player;
            ["Acts_carFixingWheel", 12] spawn AP_fnc_handleAnim;
            for "_i" from 0 to 1 step 0 do {uiSleep 0.6;
                _cP = _cP + 0.01;
                _progress progressSetPosition _cP;
                _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
                if (AP_isDowned || !(alive player) || !(AP_action_in_use) || isWeaponDeployed player || player getVariable["AP_restrained", false] || player getVariable["AP_surrendered", false]) exitWith {};
                if (player distance _startPos > 4 || !(damage _building isEqualTo 1) || !(player isEqualTo(_building getVariable["AP_repairingBuilding", objNull]))) exitWith {};
                if (_cP >= 1) exitWith { _success = true };};
            5 cutText["", "PLAIN"];
            AP_action_in_use = false;
            [] spawn AP_fnc_handleAnim;
            _building setVariable["AP_repairingBuilding", nil, true];
            if !(_success) exitWith {};
            if (AP_inv_houserepairkit < 1) exitWith {};   // re-check: still hold the kit at completion (anti-dupe)
            AP_inv_houserepairkit = (AP_inv_houserepairkit - 1) max 0;
            AP_carryWeight = (AP_carryWeight - (["getItemWeight", "houserepairkit"] call AP_fnc_virtItemCfg)) max 0;
            [0] call AP_fnc_ClupdatePartial;
            private _index = AP_vehicles find _building;
            if !(_index isEqualTo - 1) then { AP_vehicles set[_index, -1]; AP_vehicles = AP_vehicles - [-1]; };
            _index = [str(getPosATL _building), AP_houses] call AP_fnc_index;
            if !(_index isEqualTo - 1) then { AP_houses set[_index, -1]; AP_houses = AP_houses - [-1]; };
            _building setVariable["AP_repairRequested", false, true];
            [[player, _building, _ruins], "APS_fnc_repairBuildingSRV", 2] spawn AP_fnc_MP;
            [format["You repaired your %1 with a House Repair Kit.", getText(configFile >> "CfgVehicles" >> typeOf _building >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
            [["-HOUSEREPAIR-", player, (profileName), format["self-repaired with a House Repair Kit. House Type: %1, House ID: %2, House Pos: %3", typeOf _building, _building getVariable["AP_houseID", -1], getPos _building]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        };
        case ("payForRequest"): {
                _repairHouseData params[["_building", objNull, [objNull]], ["_ruins", objNull, [objNull]], ["_medic", objNull, [objNull]]];
                if (isNull _building || isNull _medic) exitWith {};
                private _buildingBuyPrice = ([typeOf _building] call AP_fnc_houseConfig) param[1, 150000];
                private _fee = _buildingBuyPrice * 0.3;
                if (AP_atmcash < _fee) exitWith {
                    ["Your building was not successfully repaired due to your lack of funds.", "basic"] spawn AP_fnc_handleMessage; [
                        ["The home owner failed to have enough funds to pay you for your repair of the building", "basic"], "AP_fnc_handleMessage", _medic] spawn AP_fnc_MP;
                }; [["action", "repairhouse", 1], "AP_fnc_handleQuest", _medic] spawn AP_fnc_MP;
                [format["Your %1 was repaired by %2%3 and a fee of $%4 was taken from your bank account.", getText(configFile >> "CfgVehicles" >> typeOf _building >> "displayName"), [independent, _medic] call AP_fnc_getRankString, name _medic, [_fee] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                _building setVariable["AP_repairRequested", false, true];
                private _index = AP_vehicles find _building;
                if !(_index isEqualTo - 1) then {AP_vehicles set[_index, -1];
                    AP_vehicles = AP_vehicles - [-1];};
                _index = [str(getPosATL _building), AP_houses] call AP_fnc_index;
                if !(_index isEqualTo - 1) then {AP_houses set[_index, -1];
                    AP_houses = AP_houses - [-1];}; [[player, _building, _ruins], "APS_fnc_repairBuildingSRV", 2] spawn AP_fnc_MP; [
                    ["repairPayment", [_fee, profileName, getText(configFile >> "CfgVehicles" >> typeOf _building >> "displayName")]], "AP_fnc_medicRepairBuilding", _medic] spawn AP_fnc_MP;
                [
                    ["-HOUSEREPAIR-", player, (profileName), format["House was repaired by TT Medic: %1, House Type: %2, House ID: %3, Amount Paid to Medic: $%4, House Pos: %5", name _medic, typeOf _building, _building getVariable["AP_houseID", -1], [_fee] call AP_fnc_numberText, getPos _building]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
            };
        case ("houseRepaired"): {_repairHouseData params[["_newHouse", objNull, [objNull]], ["_oldHouse", objNull, [objNull]]];
                AP_vehicles pushBack _newHouse;
                AP_houses pushBack[(str(getPosATL _newHouse)), []]; {if !((_x find "phouse_") isEqualTo - 1) then {deleteMarker _x;};}
                forEach allMapMarkers;
                [] spawn AP_fnc_CLinitHouses;};
        case ("gangHouseRepaired"): {_repairHouseData params[["_newHouse", objNull, [objNull]], ["_oldHouse", objNull, [objNull]]];
                if !((AP_gang_data param[3, [0, 0, 0]]) isEqualTo[0, 0, 0]) then {if !(isNull _newHouse) then {waitUntil {uiSleep 1;
                            !(isNil {_newHouse getVariable "AP_house_gang"})};
                        private _gangID = _newHouse getVariable["AP_house_gang", -1];
                        private _gangOwner = _newHouse getVariable["AP_homeOwner", ""];
                        private _houseTypes = ["getHouses"] call AP_fnc_houseConfig;
                        if (_gangID isEqualTo - 1 || _gangOwner isEqualTo "") exitWith {};
                        if !((typeOf _newHouse) in _houseTypes) exitWith {};
                        AP_gangBuilding = [_newHouse, getPosATL _newHouse];
                        if (_gangOwner isEqualTo(getPlayerUID player)) exitWith {};
                        AP_vehicles deleteAt(AP_vehicles find _oldHouse);
                        AP_houses deleteAt(AP_houses find(str(getPosATL _oldHouse)));
                        deleteMarkerLocal AP_gangBldgMark;
                        AP_gangBldgMark = "";
                        // on-map guard (2026-07-27): gang houses still come back from the DB on ALTIS
                        // coordinates, and a marker at one draws "Gang Building" in the black void off
                        // the edge of Malden. No world, no marker.
                        private _hp = getPosATL _newHouse;
                        if ((_hp select 0) < 0 || {(_hp select 0) > worldSize} || {(_hp select 1) < 0} || {(_hp select 1) > worldSize}) exitWith {};
                        private _marker = createMarkerLocal[format["phouse_%1%2", _gangID, _gangOwner], _hp];
                        _marker setMarkerTextLocal "Gang Building";
                        _marker setMarkerColorLocal "ColorGreen";
                        _marker setMarkerTypeLocal "mil_end";
                        AP_gangBldgMark = _marker;};};};};