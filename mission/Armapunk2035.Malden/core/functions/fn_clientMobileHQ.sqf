
params[["_mode", "", [""]], ["_spawnPoints", "", ["", [], objNull]], ["_playerObj", objNull, [objNull]], ["_centerVehicle", objNull, [objNull]]];
private _buyPrice = 40000;
switch (_mode) do {case ("buyMobileHQ"): {if !(35 in AP_cop_talents) exitWith {
                ["You do not have the prestige talent to pull this vehicle.", "basic"] spawn AP_fnc_handleMessage;};
            private _action = [format["Are you sure you want to buy the mobile HQ for %1?", _buyPrice], "Mobile HQ", "Yes", "No"] call BIS_fnc_guiMessage;
            if !(_action) exitWith {};
            private _spawnPoint = "";
            if (_spawnPoints isEqualType[]) then {_spawnPoints = _spawnPoints select {"_g_" in (str _x)};
                _spawnPoint = _spawnPoints param[_spawnPoints findIf {
                    nearestObjects[getMarkerPos _x, ["Car", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _x, ["Air"], 14] isEqualTo[]
                }, ""];} else {if (_spawnPoints isEqualType "") then {
                    if (nearestObjects[getMarkerPos _spawnPoints, ["Car", "Ship"], 5] isEqualTo[] && nearestObjects[getMarkerPos _spawnPoints, ["Air"], 14] isEqualTo[]) then {
                        _spawnPoint = _spawnPoints};} else {
                    if (nearestObjects[getPosATL _spawnPoints, ["Car", "Ship"], 5] isEqualTo[] && nearestObjects[getPosATL _spawnPoints, ["Air"], 14] isEqualTo[]) then {
                        _spawnPoint = _spawnPoints};};};
            if (_spawnPoint isEqualTo "") exitWith {
                ["There is a vehicle currently blocking the spawn point(s).", "basic"] spawn AP_fnc_handleMessage;};
            if !([_buyPrice] call AP_fnc_debitCard) exitWith {
                ["You do not have enough money to buy this", "basic"] spawn AP_fnc_handleMessage;};
            if (_spawnPoint in (["civ_air_carrier_1", "civ_air_carrier_2", "civ_air_carrier_3"] apply { missionNamespace getVariable [_x, _x] })) exitWith {   // owner 2026-09-06: the carriers are Altis objects; undefined on Malden, so resolve by name
                ["You can not spawn a mobile HQ here", "basic"] spawn AP_fnc_handleMessage;};
            [6] call AP_fnc_ClupdatePartial;
            private _markerPos =
            if (_spawnPoint isEqualType objNull) then {getPosATL _spawnPoint} else {getMarkerPos _spawnPoint};
            _markerPos set[2, (_markerPos select 2) + 1.5];
            private _vehicle = createVehicle["B_Truck_01_covered_F", [random 999, random 999, 999], [], 0, "CAN_COLLIDE"];
            waitUntil {!isNil "_vehicle" && {!isNull _vehicle}};
            _vehicle lock true;
            _vehicle allowDamage false;
            if (_spawnPoint isEqualType objNull) then {
                _vehicle setDir([((direction _spawnPoint) - 90), direction _spawnPoint] select("VR" in typeOf _spawnPoint))} else {
                _vehicle setDir(markerDir _spawnPoint)};
            _vehicle setPos _markerPos;
            _vehicle setVectorUp(surfaceNormal _markerPos);
            playSound "purchase";
            [_vehicle] call AP_fnc_clearVehicleAmmo;
            clearItemCargoGlobal _vehicle;
            clearBackpackCargoGlobal _vehicle;
            uiSleep 1;
            [_vehicle, [0, 0, 0, 0], 0, "", [0, 1], false, false, false, false, true] spawn AP_fnc_prepareVehicle;   // owner 2026-06-13: full fuel (was 0.5)
        }; case ("setupMobileHQ"): {if (isNull _centerVehicle) exitWith {};
                if !(alive _centerVehicle) exitWith {};
                if (speed _centerVehicle > 0) exitWith {[1, "The vehicle has to be stationary to set up the HQ."] spawn AP_fnc_broadcast;
                };
                private _exit = false; {if (_centervehicle distance2D(getMarkerPos _x) < 1500) exitWith {
                        ["You must be 1500m from a federal event to set up the HQ.", "basic"] spawn AP_fnc_handleMessage;
                        _exit = true;};}
                forEach["AP_mentalHospital", "fed_reserve", "AP_convoy_start", "armory_marker", "AP_bank", "corrections"];
                if (_exit) exitWith {};
                // 2026-07-28: the Jewelry Emporium joins the 1500m federal-event ring above, matched to
                // fed_reserve -- same radius, same message. It is the same class of site: fn_activeFederalEvent
                // lists "jewelry" beside fed/bank/prison/convoy, and fed_reserve is the entry in that list this
                // map demonstrably still has (initServer.sqf creates its marker). Without this a MaxSec mobile HQ
                // -- a cop spawn point with gear and vehicle shops attached -- can be planted on the emporium's
                // doorstep. UNCONDITIONAL, exactly like every fixed site in the list above and deliberately
                // unlike fn_spawnPointCfg's active-only jewelry rule: an HQ parked there BEFORE the window
                // opens is the abuse, and by the time slot 1 flips it is already built.
                // The emporium is absent from that forEach because the forEach is a list of MARKER NAMES and
                // the emporium has no marker on Malden. Its anchor is AP_JEWEL_CENTRE, the position
                // APS_fnc_maldenJewelSRV publicVariable's at boot (so it is JIP-persistent). Read GUARDED, the
                // same idiom fn_spawnPointCfg uses: on a client that somehow has not received the publish the
                // [0,0,0] default cannot raise inside this menu path -- it degrades to today's behaviour (no
                // emporium exclusion) everywhere except within 1500m of the map's SW corner, where the cost is
                // one spurious refusal. Both directions are survivable; a script error here is not.
                if ((_centerVehicle distance2D (missionNamespace getVariable ["AP_JEWEL_CENTRE", [0,0,0]])) < 1500) exitWith {
                    ["You must be 1500m from a federal event to set up the HQ.", "basic"] spawn AP_fnc_handleMessage;};
                // 2026-07-28: "illegal_warlord" RESTORED to the list below. It was dropped earlier today
                // only because no marker of that name existed on Malden, which fed getMarkerPos a [0,0,0]
                // and pointed the test at the map's SW sea corner. The owner has now sited the African
                // Warlord fence at [8546.79, 7674.1] and initServer.sqf creates both of his markers there
                // at boot, so the name resolves to a real place and the exclusion means what it says: no
                // MaxSec mobile HQ -- a cop spawn point with a gear shop and a vehicle shop on it -- inside
                // 1000m of the only buyer for the Jewelry Emporium's loot.
                // Known side effect, deliberate: the same 1000m ring also covers the cocaine field 423m
                // away and the lumber mill 786m away. Nothing else is inside it -- La Trinite and its
                // civ_spawn_1 sit 1309m out, the nearest gang compound 1490m, the emporium itself 3064m --
                // and gang/turf/cartel rings on this map already swallow their own neighbourhoods, so the
                // radius stays at the list's 1000m rather than being shrunk for one site.
                {if (_centervehicle distance2D(getMarkerPos _x) < 1000) exitWith {
                        ["This area is controlled by a gang (Move 1000m away)", "basic"] spawn AP_fnc_handleMessage;
                        _exit = true;};}
                forEach["illegal_warlord", "turf_area_panagia_flag", "turf_area_rodo_flag", "turf_area_zaros_flag", "arms_cartel", "drug_cartel", "oil_cartel", "wongs_cartel"];
                if (_exit) exitWith {};
                private _nearBuildings = nearestObjects[_centerVehicle, ["house"], 30];
                if !(_nearBuildings isEqualTo[]) exitWith {
                    [1, "You need to be 30m+ from a building to set the Mobile HQ up."] spawn AP_fnc_broadcast;};
                if ((SRV_mobileHQ param[0, -1800]) > (serverTime - (60 * 30))) exitWith {
                    [1, format["MaxSec is out of building supplies for another mobile HQ. Try again in %1 minute(s).", ceil(((SRV_mobileHQ param[0, -1800]) - (serverTime - (60 * 30))) / 60)]] spawn AP_fnc_broadcast;
                };
                if (SRV_mobileHQ select 2) exitWith {[1, "There is already a Mobile HQ being set up."] spawn AP_fnc_broadcast;};
                private _action = [format["Are you sure you want to setup the mobile HQ?"], "Mobile HQ", "Yes", "No"] call BIS_fnc_guiMessage;
                if !(_action) exitWith {};
                _centerVehicle setVariable["AP_mobileHeadQuartersTruckLocked", true, true];
                (_playerObj) moveOut _centerVehicle;
                SRV_mobileHQ set[2, true];
                publicVariable "SRV_mobileHQ";
                private _level =
                switch (true) do {case (37 in AP_cop_talents): {2};
                    case (36 in AP_cop_talents): {1};
                    default {0};}; [[ _playerObj , _centerVehicle, _level], "APS_fnc_srvMobileHQ", 2] spawn AP_fnc_MP;
                [1, "Setting up the MaxSec Mobile HQ. Keep the surrounding area clear!"] spawn AP_fnc_broadcast;};
        case ("setupShops"): {private _data = SRV_mobileHQ select 3;
                private _level = ((_data) select 0);
                private _gearNPC = ((_data) select 1);
                private _vehicleNPC = ((_data) select 2);
                private _base = _data param [3, objNull];                  // owner 2026-06-20: HQ base building (pack-up action target)
                private _vehSpawns = _data param [5, ["cop_g_mobile"]];     // owner 2026-06-20: per-deploy spawn markers -- ground motor pool (right) + air helipad (left)
                if !(isNull _gearNPC) then {[_gearNPC, 'STAND_U1', 'general'] call NPC_fnc_copShops;
                    [_gearNPC, 'STAND_U1', 'copdive'] call NPC_fnc_copShops;};
                if !(isNull _vehicleNPC) then {if (_level == 1) then {
                        [_vehicleNPC, _vehSpawns, 'STAND_U1', 'ground'] call NPC_fnc_copVehicles;};
                    if (_level == 2) then {[_vehicleNPC, _vehSpawns, 'STAND_U1', 'airground'] call NPC_fnc_copVehicles;};};
                // owner 2026-06-20 (item 2): scroll-wheel "Pack Up" on the HQ base. Sets a public flag the server's
                // teardown waitUntil catches -> despawns the whole HQ (base/NPCs/helipad/markers). West-only +
                // confirm dialog so a stray scroll can't nuke the HQ.
                if (!isNull _base) then {_base addAction ["<t color='#FF6666'>Pack Up Mobile HQ</t>", {params ["_tgt", "_caller"];
                            private _ok = ["Pack up and despawn the Mobile HQ? This removes the base, NPCs and helipad.", "Mobile HQ", "Yes", "No"] call BIS_fnc_guiMessage;
                            if (_ok) then {_tgt setVariable ["AP_mobileHQPackup", true, true];
                                ["Packing up the Mobile HQ...", "basic"] spawn AP_fnc_handleMessage;};}, nil, 1.5, true, true, "",
                        'AP_effSide isEqualTo west && (_target distance _this < 8)', 5];};};};