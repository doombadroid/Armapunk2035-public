params[["_caseType", "", [""]], ["_repairHouseData", [], [[]]]];
switch (_caseType) do {case ("requestRepair"): {
            _repairHouseData params[["_ruins", objNull, [objNull]], ["_building", objNull, [objNull]], ["_homeOwner", objNull, [objNull]]];
            if (isNull _ruins || isNull _building || isNull _homeOwner) exitWith {};
            private _nearestLocation = text(nearestLocations[_ruins, ["NameCityCapital", "NameCity", "NameVillage"], 5000] select 0);
            private _position = getPos _ruins;
            [format["<t align='center' size='1.5' color='#ff1717'>TT Dispatch</t><br/><br/>A building near %1 needs repairing and has been marked on your map.", _nearestLocation], "event"] spawn AP_fnc_handleMessage;
            private _marker = createMarkerLocal[format["building_repair%1", random 9999], _position];
            _marker setMarkerShapeLocal "ICON";
            _marker setMarkerTypeLocal "mil_pickup";
            _marker setMarkerTextLocal format["%1 - Needs Repair", getText(configFile >> "CfgVehicles" >> typeOf _building >> "displayName")];
            _marker setMarkerColorLocal "ColorPink";
            [_marker, _homeOwner, _ruins] spawn {params["_marker", "_homeOwner", "_ruins"];
                waitUntil {uiSleep 5;
                    (isNull _homeOwner) || (isNull _ruins) || {(damage _ruins) < 1}};
                deleteMarker _marker;};}; case ("repairPayment"): {
                _repairHouseData params[["_paymentFee", -1, [0]], ["_homeOwnerName", "", [""]], ["_houseType", "", [""]]];
                if (_paymentFee isEqualTo - 1) exitWith {};
                AP_atmcash = AP_atmcash + _paymentFee;
                AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
                AP_side_exp = AP_side_exp + 150;
                150 call AP_fnc_medicEarn;   // TT prestige
                [format["Your were paid $%1 for the repair work done to %2's %3", [_paymentFee] call AP_fnc_numberText, _homeOwnerName, _houseType], "basic"] spawn AP_fnc_handleMessage;
            };
        case ("actionRepair"): {private _ruins =
                if ((((typeOf cursorObject) find "ruin") != -1) || (((typeOf cursorObject) find "dam") != -1)) then {cursorObject} else {
                    objNull};
                if (isNull _ruins) exitWith {["You must be looking at the ruins of the building!"] spawn AP_fnc_handleMessage};
                private _building = (nearestTerrainObjects[player, ["House"], 7, true, true]) param[0, objNull];
                private _building =
                if (_building getVariable["AP_terrainObject_repaired", false]) then {
                    (nearestObjects[player, ["House"], 7, true]) param[0, objNull]} else {_building};
                if (isNull _building) exitWith {};
                if !(_building getVariable["AP_repairRequested", false]) exitWith {};
                if !(damage _building isEqualTo 1) exitWith {};
                private _ownerIsOnline = !(isNull(allPlayers param[allPlayers findIf {
                    getPlayerUID _x isEqualTo(_building getVariable["AP_homeOwner", ""])}, objNull]));
                if !(_ownerIsOnline) exitWith {
                    ["You cannot repair this building as the home owner is currently offline.", "basic"] spawn AP_fnc_handleMessage};
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
                private _nearbyPlayers = ((getPos player) nearEntities["CAManBase", 10]) select {isPlayer _x};
                private _sleepDelay =
                if (count _nearbyPlayers > 1) then {0.7} else {0.6};
                if !(isNull(_building getVariable["AP_repairingBuilding", objNull])) exitWith {
                    ["This building is already being repaired.", "basic"] spawn AP_fnc_handleMessage};
                _building setVariable["AP_repairingBuilding", player, true];
                ["Acts_carFixingWheel", 12] spawn AP_fnc_handleAnim;
                [] spawn {for "_i"
                    from 1 to 3 do {private _toSend = (allPlayers - [allDeadMen]) select {(_x distance player) <= 100}; [
                            [player, "houseRepair"], "AP_fnc_playSound", _toSend] spawn AP_fnc_MP;
                        uiSleep 9;};};
                for "_i"
                from 0 to 1 step 0 do {uiSleep _sleepDelay;
                    _cP = _cP + 0.01;
                    _progress progressSetPosition _cP;
                    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
                    if (AP_isDowned || !(alive player) || !(AP_action_in_use) || isWeaponDeployed player || player getVariable["AP_restrained", false] || player getVariable["AP_surrendered", false]) exitWith {};   // #361: hands-up (TAB) cancels the repair so you can comply
                    if (player distance _startPos > 4 || !(damage _building isEqualTo 1) || !(player isEqualTo(_building getVariable["AP_repairingBuilding", objNull]))) exitWith {};
                    if (_cP >= 1) exitWith {_success = true};}; 5 cutText["", "PLAIN"];
                AP_action_in_use = false;
                [] spawn AP_fnc_handleAnim;
                _building setVariable["AP_repairingBuilding", nil, true];
                if !(_success) exitWith {};
                private _homeOwner = allPlayers param[allPlayers findIf {
                    getPlayerUID _x isEqualTo(_building getVariable["AP_homeOwner", ""])}, objNull];
                if (isNull _homeOwner) then {
                    ["The repair was not completed as the home owner is offline and unable to pay.", "basic"] spawn AP_fnc_handleMessage
                } else {
                    [format["House repair payment request sent to home owner of %1", getText(configFile >> "CfgVehicles" >> typeOf _building >> "displayName")], "basic"] spawn AP_fnc_handleMessage;
                    [["payForRequest", [_building, _ruins, player]], "AP_fnc_civRepairBuilding", _homeOwner] spawn AP_fnc_MP;};};};