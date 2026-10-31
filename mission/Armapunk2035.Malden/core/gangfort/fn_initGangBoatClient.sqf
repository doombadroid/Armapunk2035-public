params[["_caseType", "", [""]]];
// owner 2026-06-16 (#262): civ/gang event but server remoteExecs to EVERY client (-2) -> cops/medics got the
// "Gang Boat Is Ready For Capture!" pop-up + sound + marker. Gate to civilians (see #262 in fn_initGangFortClient).
if !(AP_effSide isEqualTo civilian) exitWith {};
if (_caseType == "drawHud" && !(player getVariable["gangBoatClientInitialized", false])) exitWith {
    [format["The gang boat hasn't initialized you yet, try again later!"], "warning"] call AP_fnc_handleMessage;};
private _drawGangBoatClient = {if (!isNil "SRV_tempGangRebel") then {{_x params["_weaponShop", "_vehicleShop", "_spawnPoints"];
            [_weaponShop, 'STAND'] call NPC_fnc_civRebelWeapon;
            [_vehicleShop, _spawnPoints, 'REPAIR_VEH_KNEEL', 'ground'] call NPC_fnc_civRebelVehicles;}
        forEach SRV_tempGangRebel;};
    waitUntil {uiSleep 15;
        (player distance2D(getMarkerPos "gangboat_label") <= 500) || !(SRV_gangBoatFortressData select 0)};
    if (SRV_gangBoatFortressData select 0) then {player setVariable["gangBoatParticipant", true];
        [] spawn AP_fnc_gangBoatHud;};};
switch (_caseType) do {case ("initGangShops"): {if (!isNil "SRV_gangBoatShops") then {
                if (((AP_gangBoatFortressObject getVariable["AP_gang_fortress_data", [-1, "Uncontrolled", false]]) select 0) isEqualTo(AP_gang_data select 0)) then {
                    if (!isNil "AP_gangBoatShopInit") exitWith {};
                    AP_gangBoatShopInit = true;
                    [(SRV_gangBoatShops select 0), 'STAND'] call NPC_fnc_civRebelWeapon;
                    [(SRV_gangBoatShops select 1), (SRV_gangBoatShops select 2), 'STAND_U1', 'air'] call NPC_fnc_civRebelVehicles;}};
        }; case ("initMessages"): {if !(SRV_gangBoatFortressData select 0) exitWith {};
                player setVariable["gangBoatClientInitialized", true];
                ["The Gang Boat can now be captured for the next hour! The gang with the longest time holding will win! Two temporary safezone Rebel Outposts have been setup near the boat!", "gang_fortress_long"] spawn AP_fnc_handleMessage;
                [4, format["Gang Boat Is Ready For Capture!"]] call AP_fnc_broadcast;
                [objNull, "fortressStart", true] call AP_fnc_playSound;
                [] call _drawGangBoatClient;};
        case ("missedMessages"): {if !(SRV_gangBoatFortressData select 0) exitWith {};
                if (player getVariable["gangBoatClientInitialized", false]) exitWith {};
                player setVariable["gangBoatClientInitialized", true];
                ["The Gang Boat can now be captured, it started whilst you were offline but you still have a chance! Two temporary safezone Rebel Outposts have been setup near the boat!", "gang_fortress_long"] spawn AP_fnc_handleMessage;
                [objNull, "fortressStart", true] call AP_fnc_playSound;
                [] call _drawGangBoatClient;};
        case ("drawHud"): {if !(SRV_gangBoatFortressData select 0) exitWith {};
                player setVariable["gangBoatParticipant", true];
                [] spawn AP_fnc_gangBoatHud;};};