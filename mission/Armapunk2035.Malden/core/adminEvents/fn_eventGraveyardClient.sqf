params[["_type", "", [""]], ["_plb_obj", objNull, [objNull]]];
if !(AP_effSide isEqualTo civilian) exitWith {};
private _plb_player = player;
switch (_type) do {case "startEvent": {
            if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false] || ((AP_is_arrested param [0,0]) isEqualTo 1)) exitWith {
                ["You cannot join the admin event at this time.", "basic"] spawn AP_fnc_handleMessage;};
            if (AP_adminEvent select 1) exitWith {["You cannot join the admin event in progress.", "basic"] spawn AP_fnc_handleMessage;
            }; [[true, player], "APS_fnc_eventParticipants", 2] spawn AP_fnc_MP;
            AP_inEvent = true;
            private _preEventLoadout = getUnitLoadout player;
            private _preEventSkins = AP_uniformBackpack_skins;
            private _preEventPos =
            if (surfaceIsWater(getPosATL player)) then {getPosASL player} else {getPosATL player};
            private _plb_player = player;
            private _location = (["getLocationByID", (AP_adminEvent select 3)] call AP_fnc_eventCfg) select 2;
            if !(isNull objectParent player) then {moveOut player;};
            [_location, 14, {false}, "Halloween Graveyard Shift Admin Event"] spawn AP_fnc_uavCinematic;
            titleText["Welcome to the LoonyBin 2020 Halloween Graveyard Shift Admin Event<br/>To win, you must burn skeletal remains and be lucky enough to find a special secret!<br/>You must stay within this zone to participate<br/>May the best grave robber win!", "PLAIN", -1, true, true];
            disableUserInput true;
            // owner 2026-06-24: graveyard is OPEN-JOIN (come-and-go dig) -- NO join-lock phase. The old
            // waitUntil{AP_adminEvent select 1} below hung FOREVER (the SRV never sets select 1) leaving the
            // player input-disabled/frozen. Unfreeze after the fixed intro flyover (or instantly if event ends).
            private _introEnd = time + 14;
            AP_old_group = group player;
            [player] join grpNull;
            uiSleep 2;
            private _plb_pos = _location;
            while {_plb_pos isEqualTo _location}
            do {_plb_pos = [_location, 1, 75, 1, 0, 0, 0, [], _location] call BIS_fnc_findSafePos;}; player setPos _plb_pos;
            player setDamage 0;
            private _eventLoadout = [[], [], [], ["U_C_Uniform_Farmer_01_F", []], ["V_BandollierB_blk", []],
                ["B_Carryall_eaf_F", []], "H_HeadBandage_bloody_F", "G_Bandanna_beast", [],
                ["ItemMap", "", "", "ItemCompass", "ItemWatch", ""]];
            player setUnitLoadout _eventLoadout;
            uiSleep 2.5;
            waitUntil {(time > _introEnd) || !(AP_adminEvent select 0)};
            disableUserInput false;
            if (sunOrMoon < 0.5) then {player action["nvGoggles", player];};
            private _task = player createSimpleTask["AE_GraveyardShift_Task"];
            _task setSimpleTaskDescription["", "Graveyard Shift Event", ""];
            _task setSimpleTaskDestination _location;
            _task setTaskState "Assigned";
            player setCurrentTask _task;
            _plb_player setVariable["AP_eventHallow_playerStats", [0, 0]];
            private _eventShovel = "Land_Shovel_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire1 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire2 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire3 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire4 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire5 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire6 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire7 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire8 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire9 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _eventCampfire10 = "Land_Campfire_F"
            createVehicleLocal[0, 0, 0];
            private _churchObject1 = "Land_OrthodoxChurch_03_F"
            createVehicleLocal[0, 0, 0];
            private _churchObject2 = "Land_Canal_Wall_Stairs_F"
            createVehicleLocal[0, 0, 0]; {_x setPos[9610.1, 15868.1, 0.343491];
                _x setDir 119.399;
                _x allowDamage false;}
            forEach[_churchObject1]; {_x setPos[9614.71, 15879.7, 1.5089];
                _x setDir 208.586;
                _x allowDamage false;}
            forEach[_churchObject2];
            _eventCampfire1 setPosATL[9604.13, 15858, 0.35];
            _eventCampfire2 setPosATL[9601.33, 15858.8, 0.35];
            _eventCampfire3 setPosATL[9599.1, 15860.3, 0.35];
            _eventCampfire4 setPosATL[9596.74, 15862.1, 0.35];
            _eventCampfire5 setPosATL[9599.22, 15873.6, 1];
            _eventCampfire6 setPosATL[9595.46, 15867.4, 0.35];
            _eventCampfire7 setPosATL[9609.13, 15860.2, 0.4];
            _eventCampfire8 setPosATL[9612.92, 15866.6, 0.9];
            _eventCampfire9 setPosATL[9606.32, 15870.3, 1];
            _eventCampfire10 setPosATL[9604.52, 15867.1, 0.7];
            _eventShovel attachTo[_plb_player, [0, 0.15, -0.3], "righthand"];
            _eventShovel setVectorUp[0, 1, 0.5]; {_x allowDamage false;}
            forEach[_eventShovel, _eventCampfire1, _eventCampfire2, _eventCampfire3, _eventCampfire4, _eventCampfire5, _eventCampfire6, _eventCampfire7, _eventCampfire8, _eventCampfire9, _eventCampfire10];
            _objLocations = [[9612.13, 15853.8, 7.62939e-006], [9614.02, 15852.4, 7.62939e-006], [9619.89, 15851, 7.62939e-006],
                [9617.12, 15852.4, 0], [9622.86, 15849.1, 0], [9625.07, 15847.2, 0], [9627.45, 15846, 0], [9630.44, 15844.8, 0],
                [9634.03, 15842.3, 0], [9636.67, 15841.9, 7.62939e-006], [9640.81, 15840.4, 0], [9663.45, 15831.5, 7.62939e-006],
                [9667.83, 15829.2, 0], [9638.1, 15848.1, 0], [9635.39, 15848.1, 0], [9633.75, 15850.1, 0], [9631.09, 15851, 0],
                [9628.13, 15852.6, -7.62939e-006], [9625.77, 15853.7, -7.62939e-006], [9623.43, 15855.5, 0], [9621.5, 15857.7, 0],
                [9624.08, 15866, 0], [9626.41, 15863.4, 0], [9628.95, 15862.2, 0], [9631.41, 15860.2, 0], [9637.56, 15856.7, 0],
                [9640.93, 15855.3, 0], [9643.55, 15853.7, 0], [9646.21, 15851.6, 0], [9639.36, 15867.2, 0], [9629.9, 15881.6, 0],
                [9632.34, 15880.7, 0], [9635.46, 15880.2, 0], [9639.01, 15878.6, 0], [9649.15, 15863.2, 0],
                [9651.99, 15862.1, -7.62939e-006], [9654.89, 15859.6, 0], [9657.5, 15858.2, 0], [9659.9, 15856.6, 0], [9656.52, 15871.1, 0],
                [9659.7, 15869.5, -7.62939e-006], [9661.84, 15866.8, 0], [9665.35, 15867.8, 7.62939e-006], [9668.1, 15864.7, 0],
                [9671.74, 15864.5, 0], [9674.38, 15863.2, 7.62939e-006], [9676.89, 15862.2, 0], [9681.1, 15861.3, 0], [9680.01, 15849.7, 0],
                [9679.94, 15847.2, 7.62939e-006], [9679.44, 15844.9, 7.62939e-006], [9662.52, 15848.7, 0],
                [9660.72, 15846.8, -7.62939e-006], [9659.34, 15844.7, -7.62939e-006], [9666.08, 15841.2, 0]]; {private _xLocation = _x;
                _xEventObj = "Land_ShellCrater_01_F"
                createVehicleLocal[0, 0, 0]; {_x allowDamage false;
                    _x enableSimulation false;
                    _x setPosATL _xLocation;}
                forEach[_xEventObj];}
            forEach _objLocations;
            uiSleep 5;
            [format["<t color='#ff7b0e' align='center'><t size='1.25'>Halloween Graveyard Shift Event</t></t><br/><br/>A Graveyard Keeper has tasked with you unearthing remains of skeletons in their graves! Each grave will contain remains that need to burned at the church! Burning bones that aren't any special will still grant you valuable items!<br/><br/>You've been given a shovel in order to do your job as a grave robber!<br/><br/>In order to win this event you must find the bones one of the four horsemen, Death himself and burn them!"], "event"] spawn AP_fnc_handleMessage;
            waitUntil {!(AP_adminEvent select 0) || !(player distance(getMarkerPos "graveyardshift1") < 300)};
            if (AP_adminEvent select 0) then {if !(player distance(getMarkerPos "graveyardshift1") < 300) then {
                    ["You have left the event area, so you were removed!", "basic"] spawn AP_fnc_handleMessage;};};
            uiSleep 10; [[false, player], "APS_fnc_eventParticipants", 2] spawn AP_fnc_MP;
            AP_inEvent = false; {deleteVehicle _x}
            forEach(nearestObjects[_plb_pos, ["Land_Grave_11_F", "Land_HumanSkeleton_F", "Sign_Arrow_F", "Land_ShellCrater_01_F"], 300]); {
                deleteVehicle _x;}
            forEach[_eventShovel, _eventCampfire1, _eventCampfire2, _eventCampfire3, _eventCampfire4, _eventCampfire5, _eventCampfire6, _eventCampfire7, _eventCampfire8, _eventCampfire9, _eventCampfire10, _churchObject1, _churchObject2];
            if (AP_isDead) then {
                ["You have 45 seconds to respawn, in order to keep your pre-event position and loadout!", "basic"] spawn AP_fnc_handleMessage;
                uiSleep 45;};
            player removeSimpleTask _task;
            player setUnitLoadout _preEventLoadout;
            AP_uniformBackpack_skins = _preEventSkins;
            if (surfaceIsWater _preEventPos) then {player setPosASL _preEventPos} else {player setPosATL _preEventPos};
            _plb_player setDamage 0;
            [player] joinSilent AP_old_group;
            [10] call AP_fnc_ClupdatePartial;
            titleText["You have been given back your previous loadout", "PLAIN"];
            [] spawn {uiSleep 0.5;
                [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
                [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;};}; case "digGrave": {
                if !(AP_adminEvent select 0) exitWith {
                    ["The Graveyard Shift Event has already ended and a winner was already chosen!", "basic"] spawn AP_fnc_handleMessage;
                };
                if (_plb_obj getVariable["AP_eventHallow_objGraveRobbed", false]) exitWith {
                    ["This grave has already been robbed! Try another grave!", "basic"] spawn AP_fnc_handleMessage;};
                if (_plb_player getVariable["AP_eventHallow_currentlyDiggingGrave", false]) exitWith {
                    ["You are currently already robbing a grave, don't try to get greedy!", "basic"] spawn AP_fnc_handleMessage;};
                if (_plb_player getVariable["AP_eventHallow_activeSkeletalRemains", false]) exitWith {
                    ["You are currently have bones in your backpack or active skeletal remains on the ground, burn those first to dig for more!", "basic"] spawn AP_fnc_handleMessage;
                };
                _plb_obj setVariable["AP_eventHallow_objGraveRobbed", true];
                _plb_player setVariable["AP_eventHallow_currentlyDiggingGrave", true];
                ["You start to unearth the reamins of this tomb... Stay within 7 meters or else digging will fail!", "basic"] spawn AP_fnc_handleMessage;
                closeDialog 0;
                private _success = false;
                private _text = "Excavating a gravesite for remains";
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _ui = uiNamespace getVariable["AP_progress", displayNull];
                private _progress = _ui displayCtrl 38201;
                private _pgText = _ui displayCtrl 38202;
                _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
                _progress progressSetPosition 0.01;
                private _cP = 0.01;
                player forceWalk true;
                ["AinvPknlMstpSnonWnonDnon_medic_1", 1.5] spawn AP_fnc_handleAnim;
                AP_action_in_use = true;
                for "_i"
                from 0 to 1 step 0 do {uiSleep 0.25;
                    _cP = _cP + 0.01;
                    _progress progressSetPosition _cP;
                    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
                    if !(alive player) exitWith {};
                    if !(isNull objectParent player) exitWith {player action["Eject", vehicle player]};
                    if (isWeaponDeployed player) exitWith {};
                    if (player getVariable["AP_downed", false]) exitWith {};
                    if (player distance _plb_obj > 7) exitWith {};
                    if (_cP >= 1) exitWith {_success = true;};
                    if !(AP_action_in_use) exitWith {};}; AP_action_in_use = false;
                player forceWalk false;
                [] spawn AP_fnc_handleAnim;
                5 cutText["", "PLAIN"];
                player playActionNow "stop";
                if !(_success) exitWith {["Unearthing skeletal remains has failed.", "basic"] spawn AP_fnc_handleMessage;
                    _plb_obj setVariable["AP_eventHallow_objGraveRobbed", false];
                    _plb_player setVariable["AP_eventHallow_currentlyDiggingGrave", false];};
                if ((_plb_player getVariable["AP_eventHallow_playerStats", [0, 0]] select 0) > 1) exitWith {
                    ["You can only hold the bones of 1 body at a time! Burn them to gather more!", "basic"] spawn AP_fnc_handleMessage;};
                if (_plb_player distance2D _plb_obj > 10) exitWith {
                    ["You have traveled to far away from the tombstone! Go back and try again!", "basic"] spawn AP_fnc_handleMessage;
                    _plb_obj setVariable["AP_eventHallow_objGraveRobbed", false];
                    _plb_player setVariable["AP_eventHallow_currentlyDiggingGrave", false];};
                if (floor(random 6) isEqualTo 0) exitWith {
                    ["It appears this grave has no remains inside it! Quickly start digging another grave!", "basic"] spawn AP_fnc_handleMessage;
                    _plb_obj setVariable["AP_eventHallow_objGraveRobbed", true];
                    _plb_player setVariable["AP_eventHallow_currentlyDiggingGrave", false];};
                private _dirtGrave = "Land_Grave_11_F"
                createVehicleLocal[0, 0, 0];
                private _skeletonBones = "Land_HumanSkeleton_F"
                createVehicleLocal[0, 0, 0];
                private _graveArrow = "Sign_Arrow_F"
                createVehicleLocal[0, 0, 0]; {_x allowDamage false;
                    _x enableSimulation false;}
                forEach[_dirtGrave, _skeletonBones, _graveArrow]; {_x setPos(getPosATL _plb_player)}
                forEach[_dirtGrave, _skeletonBones, _graveArrow];
                _graveArrow setPos(_dirtGrave modelToWorld[0, 0, 1]);
                _skeletonBones setPos(_dirtGrave modelToWorld[0, 0, 0.3]);
                _skeletonBones setVectorUp[0, 0, 2];
                titleText["You have unearthed skeletal remains, gather them quickly to see what you have unearthed!", "PLAIN", -1, true, true];
                ["You have unearthed skeletal remains, gather them quickly to see what you have unearthed!", "basic"] spawn AP_fnc_handleMessage;
                _plb_player say3D["CokeSlosh2", 50];
                _plb_player say3D["CokeSlosh1", 50];
                _plb_player setVariable["AP_eventHallow_currentlyDiggingGrave", false];
                _plb_player setVariable["AP_eventHallow_activeSkeletalRemains", true];};
        case "gatherBones": {if !(AP_adminEvent select 0) exitWith {
                    ["The Graveyard Shift Event has already ended and a winner was already chosen!", "basic"] spawn AP_fnc_handleMessage;
                };
                private _totalBones = (_plb_player getVariable["AP_eventHallow_playerStats", [0, 0]] select 0);
                private _totalBurnedBodies = (_plb_player getVariable["AP_eventHallow_playerStats", [0, 0]] select 1);
                if (_totalBones > 1) exitWith {
                    ["You can only hold the bones of 1 body at a time! Burn them to gather more!", "basic"] spawn AP_fnc_handleMessage;};
                if (floor(random 80) isEqualTo 0) then {
                    ["You have found the bones of the one of the four horsemen, Death himself! Go burn these bones to automatically win the event!", "basic"] spawn AP_fnc_handleMessage;
                    titleText["You have found the bones of the one of the four horsemen, Death himself! Go burn these bones to automatically win the event!", "PLAIN", -1, true, true];
                    _plb_player setVariable["AP_eventHallow_playerStats", [1, 30]];} else {
                    ["It appears you have found ordinary bones! You can still burn them for valuable items!", "basic"] spawn AP_fnc_handleMessage;
                    titleText["It appears you have found ordinary bones! You can still burn them for valuable items!", "PLAIN", -1, true, true];
                    _plb_player setVariable["AP_eventHallow_playerStats", [1, _totalBurnedBodies]];}; {deleteVehicle _x}
                forEach(nearestObjects[_plb_player, ["Land_Grave_11_F", "Land_HumanSkeleton_F", "Sign_Arrow_F"], 10]);
                [_plb_obj, _plb_player] say3D["CokeSlosh2", 50];
                [_plb_obj, _plb_player] say3D["CokeSlosh1", 50];};
        case "burnBones": {if !(AP_adminEvent select 0) exitWith {
                    ["The Graveyard Shift Event has already ended and a winner was already chosen!", "basic"] spawn AP_fnc_handleMessage;
                };
                private _totalBones = (_plb_player getVariable["AP_eventHallow_playerStats", [0, 0]] select 0);
                private _totalBurnedBodies = (_plb_player getVariable["AP_eventHallow_playerStats", [0, 0]] select 1);
                private _monsterNames = ["Wendigo", "Bigfoot", "Ghoul", "Demon", "Jersey Devil", "Slender Man", "Undead Human", "Werewolf", "Vampire", "Mummy"];
                if !(_totalBones isEqualTo 1) exitWith {
                    ["You have no bones to burn! Get to digging slacker!", "basic"] spawn AP_fnc_handleMessage;};
                if (_plb_player getVariable["AP_eventHallow_currentlyBurningBones", false]) exitWith {
                    ["You are currently already burning bones! Please wait for them to finish cooking...", "basic"] spawn AP_fnc_handleMessage;
                };
                _plb_player setVariable["AP_eventHallow_currentlyBurningBones", true];
                ["You begin to burn the bones of the skeletal remains... Stay within 7 meters or else this process will fail!", "basic"] spawn AP_fnc_handleMessage;
                closeDialog 0;
                private _success = false;
                private _text =
                if (_totalBurnedBodies > 15) then {format["Burning the remains of the Horsemen: %1", "Death"]} else {
                    format["Burning the remains of a %1", selectRandom _monsterNames]};
                disableSerialization;
                5 cutRsc["AP_progress", "PLAIN"];
                private _ui = uiNamespace getVariable["AP_progress", displayNull];
                private _progress = _ui displayCtrl 38201;
                private _pgText = _ui displayCtrl 38202;
                _pgText ctrlSetText format["%2 (1%1)...", "%", _text];
                _progress progressSetPosition 0.01;
                private _cP = 0.01;
                player forceWalk true;
                ["AinvPknlMstpSnonWnonDnon_medic_1", 1.5] spawn AP_fnc_handleAnim;
                AP_action_in_use = true;
                for "_i"
                from 0 to 1 step 0 do {uiSleep 0.25;
                    _cP = _cP + 0.01;
                    _progress progressSetPosition _cP;
                    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
                    if !(alive player) exitWith {};
                    if !(isNull objectParent player) exitWith {player action["Eject", vehicle player]};
                    if (isWeaponDeployed player) exitWith {};
                    if (player getVariable["AP_downed", false]) exitWith {};
                    if (player distance _plb_obj > 7) exitWith {};
                    if (_cP >= 1) exitWith {_success = true;};
                    if !(AP_action_in_use) exitWith {};}; AP_action_in_use = false;
                player forceWalk false;
                [] spawn AP_fnc_handleAnim;
                5 cutText["", "PLAIN"];
                player playActionNow "stop";
                if !(_success) exitWith {["Burning skeletal bones has failed.", "basic"] spawn AP_fnc_handleMessage;
                    _plb_player setVariable["AP_eventHallow_currentlyBurningBones", false];};
                if (_plb_player distance2D _plb_obj > 10) exitWith {
                    ["You have traveled to far away from the campfire! Go back and try again!", "basic"] spawn AP_fnc_handleMessage;
                    _plb_player setVariable["AP_eventHallow_currentlyBurningBones", false];};
                _plb_player setVariable["AP_eventHallow_playerStats", [0, (_totalBurnedBodies + 1)]];
                if (_totalBurnedBodies > 15) then {private _lootTableWinner = [["smashbrick", round random[3, 8, 12]],
                        ["blacklaceprime", round random[4, 6, 12]], ["giftHallo", 1], ["money", round random[5000, 7500, 15000]],
                        ["speedbomb", 1], ["scotch_3", round random[4, 6, 8]]]; {_x params["_item", "_amount"];
                        [true, _item, _amount] call AP_fnc_handleInv;}
                    forEach _lootTableWinner;
                    ["You have been given highly profitable items for winning the LoonyBin 2020 Halloween Event!", "basic"] spawn AP_fnc_handleMessage;
                    titleText["You have been given highly profitable items for winning the LoonyBin 2020 Halloween Event!", "PLAIN", -1, true, true];
                    uiSleep 10; [[2, player], "APS_fnc_eventGraveyardSRV", 2] spawn AP_fnc_MP; {deleteVehicle _x}
                    forEach(nearestObjects[_plb_player, ["Land_Shovel_F"], 5]);} else {private _lootTableNormal = [["beer", 3],
                        ["diamondf", round random[1, 3, 1]], ["diamondc", round random[2, 3, 1]], ["smash", round random[2, 3, 5]],
                        ["marijuana", round random[4, 6, 5]], ["doubloon", round random[2, 4, 6]], ["dogp", round random[2, 4, 5]],
                        ["goatp", round random[1, 2, 3]], ["blacklace", round random[1, 4, 5]], ["rubber", round random[2, 4, 5]],
                        ["redgull", round random[2, 3, 5]], ["donerkebab", round random[3, 2, 5]], ["speedbomb", 1],
                        ["manflesh", round random[1, 2, 3]], ["treasuremap", 1], ["treasure", 1], ["whiskeyr_3", round random[2, 4, 6]],
                        ["money", 1500], ["money", 2500]];
                    private _lootTableNormal = selectRandom _lootTableNormal;
                    _lootTableNormal params["_item", "_amount"];
                    [true, _item, _amount] call AP_fnc_handleInv;
                    [format["You have burned some bones! You currently have %1 total bone(s) burned!", (_plb_player getVariable["AP_eventHallow_playerStats", [0, 0]] select 1)], "basic"] spawn AP_fnc_handleMessage;
                    titleText["You have been given a valuable item for burning some ordinary bones during the the LoonyBin 2020 Halloween Event!", "PLAIN", -1, true, true];
                };
                if (AP_carryWeight < 10) then {
                    ["You are getting a bit heavy, clear some inventory space to keep getting valuable items!", "basic"] spawn AP_fnc_handleMessage;
                };
                _plb_player setVariable["AP_eventHallow_currentlyBurningBones", false];
                _plb_player setVariable["AP_eventHallow_activeSkeletalRemains", false];};};