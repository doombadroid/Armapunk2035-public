#include "macro.h"
params["_player", "_didJIP"];
if !(hasInterface) exitWith {};
if (isNil "AP_effSide") then { AP_effSide = playerSide; };
// owner 2026-07-27: the sqm player slots sit at 50km and a session STARTS held -- frozen by the line below,
// NOT by any sqm attribute. Nothing may re-enable simulation until a real teleport clears this: see the
// failsafe loop further down, fn_spawnMenu (spawn-select hold), fn_spawnConfirm and fn_initCiv.
AP_spawnHold = true;
AP_spawnHoldSince = diag_tickTime;
// THE HOLD, done CLIENT-SIDE on a normally-simulated unit -- the mechanism fn_spawnMenu has always
// used and the only one that holds. The sqm slots sit at 50km, so freezing here (first thing, before
// the ~20s of client init) means a connecting or relogging player never falls and is never seen on the
// old [1000,500] proxy cluster. Released at the real teleport: fn_initCiv (relog) or fn_spawnConfirm.
//
// It must NOT be done with mission.sqm's "Disable simulation" attribute instead. That applies on every
// machine, and enableSimulation is eff=LOCAL, so the SERVER's copy stays non-simulated all session and
// re-asserts the slot position 0.08-0.59s after any client setPos -- measured b0106-b0109 on
// 2026-07-27, and the cause of the 50km login free-fall. tools/sqm_slot_sim.py strips it if it returns.
player enableSimulation false;
player setVelocity [0, 0, 0];
// ...and take the unit out of the freefall ANIMATION. The player never actually falls (measured
// b0111: velocity 0 and altitude unchanged for the whole 8s hold) -- but the engine gives any
// airborne unit `halofreefall_non`, and freezing latches that animation, wind loop included, until
// something else changes it. That is the "falling sound for a split second" on spawn-in. Simulation
// is already off here, so nothing re-evaluates the stance and the switch sticks.
player switchMove "AmovPercMstpSnonWnonDnon";
// DEV 2026-07-27: 50km slot-hold fall diagnosis. Remove this line + debug/simProbe.sqf before a live pack.
[] execVM "debug\simProbe.sqf";
// LooneyBin 2026-06-11: nil-guard the server-owned trial vars so the prison/courthouse NPC actions and
// fn_trialSystem never throw on `SRV_trialData select N` before the server's publicVariable arrives (JIP race).
if (isNil "SRV_trialData") then { SRV_trialData = [objNull,[],[],false,false,false,""]; };
if (isNil "SRV_trialPreviousDefenders") then { SRV_trialPreviousDefenders = []; };
if (isNil "AP_airDrop_last") then { AP_airDrop_last = -99999; };
// LooneyBin dynamic market (2026-06-11): keep this client's AP_price_index in sync with the server.
// The server pushes the full index on login (fn_query) and broadcasts each per-good change as
// AP_stock_change=[class,newSaturation]; apply it so AP_fnc_marketFactor prices stay live.
if (isNil "AP_price_index" || {!(AP_price_index isEqualType [])}) then { AP_price_index = []; };
"AP_stock_change" addPublicVariableEventHandler {if (!(AP_price_index isEqualType [])) exitWith {};
    private _d = _this select 1;
    if (!(_d isEqualType []) || {count _d < 2}) exitWith {};
    private _i = AP_price_index findIf {(_x isEqualType []) && {(_x param [0, ""]) isEqualTo (_d select 0)}};
    if (_i > -1) then { (AP_price_index select _i) set [1, _d select 1]; };};
// postgis (2026-09-04): territory polygons come from the table; a re-bake re-publishes them and
// the cached position->faction answers must be rebuilt.
"AP_factionPolys" addPublicVariableEventHandler { ["flush"] call AP_fnc_factionTerritory; };
// LooneyBin (owner, 2026-06-11): MAX-VERBOSITY -- capture EVERY client script error to this client's RPT AND
// mirror it to the SERVER console.log (+ DB `log` table) so errors on REMOTE players' machines are visible
// centrally (otherwise a client's errors only land in that client's local RPT, unreadable server-side).
// Throttled 2s/client so a recurring error can't flood the wire. Returns false -> engine still logs/handles it.
addMissionEventHandler ["ScriptError", {diag_log format ["[LB-SCRIPTERR][client] %1", _this];
    if ((time - (missionNamespace getVariable ["AP_lastScriptErrT", -10])) > 2) then {
        missionNamespace setVariable ["AP_lastScriptErrT", time];
        [["-SCRIPTERR-", player, profileName, ((format ["%1", _this]) select [0, 380])], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };
    false}];
__SETCONST__(BIS_fnc_endMission, BIS_fnc_endMission);
AP_quitWelcomeUI = false;
[missionNamespace, "OnGameInterrupt", {_this call AP_fnc_onGameInterrupt}] call BIS_fnc_addScriptedEventHandler;
AP_redgull_effect = [false, time];
AP_supermale_effect = [false, time];
AP_trackedVehicles = [];
AP_clothing_store = "init";
AP_fatigueEnabled = true;
AP_loweredSwayEnabled = false;
[] execVM "core\init.sqf";
[] execVM "outlw_magRepack\MagRepack_init_sv.sqf";
[] spawn {waitUntil {!isNil "AP_serverId"};
    // LooneyBin: gate removed -- IgiLoad only initialised when AP_serverId==1 (profileName "LoonyBinServer1");
    // on any other profile the carrier load/unload action never appeared. Single server -> always init.
    // diag_log confirms it fired (client RPT) for next-reboot verification.
    diag_log format ["[LooneyBin][IgiLoad] init fired (AP_serverId=%1)", AP_serverId];
    [] execVM "IgiLoad\IgiLoadInit.sqf";};
if (_didJIP) then {{private _textureIndex = _x getVariable "AP_vehicleColor";
        private _hasEmergencyLights = _x getVariable["AP_lights", false];
        private _side = _x getVariable["AP_side", ""];
        private _trackers = _x getVariable["AP_vehicleTrackers", []];
        if !(isNil "_textureIndex") then {[_x, _textureIndex] spawn AP_fnc_colorVehicle;};
        if (_hasEmergencyLights && !(_side isEqualTo "")) then {switch (_side) do {case "cop": {[_x] spawn AP_fnc_copLights}; case "med":
                        {[_x] spawn AP_fnc_medicLights};
                    default {};};};
        if !(_trackers isEqualTo[]) then {private _vehicle = _x; {_x params["_playerSide", "_PID"];
                if (AP_effSide isEqualTo _playerSide && (getPlayerUID player isEqualTo _PID)) then {AP_trackedVehicles pushBackUnique _vehicle;};
            }
            forEach _trackers;};}
    forEach(allMissionObjects "Car") + (allMissionObjects "Air") + (allMissionObjects "Ship");};
// The three names this used to reference -- fedGate_west/east/SE -- are ALTIS mission.sqm objects.
// Malden's sqm has none of them, and an undefined variable in an expression HALTS the script rather
// than warning, so every client aborted initPlayerLocal here and silently skipped everything below
// (confirmed in the RPT: "Undefined variable in expression: fedgate_west"). The Malden Fed resolves
// its gates at boot instead, into AP_fedGates, which arrives by publicVariable and may not be here yet
// on a fast join -- hence the default rather than a direct read.
// 2026-07-29: this reads the LIST now, not the single anchor. The compound has three
// Land_ConcreteWall_01_l_gate_F and this used to name only the one the breach is anchored on
// (AP_fedGate, which still exists and still means exactly that one gate). The list is what the server
// seals and opens, so it is what the client should mirror; the old name is kept as the fallback for a
// client that lands between the two publicVariables.
// WHAT AP_fed_gates IS FOR, because the name oversells it: it is an EXCLUSION list, not an inclusion
// one. Corrected 2026-07-29 -- the note here used to claim its "only readers are the cop Open/Close
// Police Gate scroll actions". There are FOUR readers, all in core/fn_setupActions.sqf, and the medic
// pair matters just as much as the cop pair:
//   cop   "Open Police Gate"   added :1032, tests AP_fed_gates :1036 (body and condition string)
//   cop   "Close Police Gate"  added :1038, tests AP_fed_gates :1042 (body and condition string)
//   medic "Open Gate"          added :1139, tests AP_fed_gates :1147 (body) and :1151 (condition)
//   medic "Close Gate"         added :1153, tests AP_fed_gates :1161 (body) and :1165 (condition)
// All four search Land_BarGate_F / Land_RoadBarrier_01_F within 15 m and REFUSE to animate anything
// that is in this list; the medic pair additionally refuses AP_cop_gates and says so. Neither Fed
// gate class can be returned by that search, so this remains a belt-and-braces guard rather than a live
// one. Keeping it correct still matters: a stale exclusion list only bites once someone adds a class to
// that search, and then it bites silently -- for medics as well as police.
AP_fed_gates = (missionNamespace getVariable
    ["AP_fedGates", [missionNamespace getVariable ["AP_fedGate", objNull]]]) select { !isNull _x };
// Jewelry Emporium: Altis binds these three from mission.sqm init lines; Malden's sqm has none of
// them, and all three are read inside scroll-menu CONDITIONS where an undefined variable RAISES.
// The server publishes the objects; bind whatever has arrived, defaulting to objNull so a condition
// that runs before the publicVariable lands simply does not match instead of throwing.
AP_jewerlySafe      = missionNamespace getVariable ["AP_jewelSafe", objNull];
AP_jewerlyEmporium  = missionNamespace getVariable ["AP_jewelGate", objNull];
AP_jewerlyContainer = objNull;
private _UIDs = profileNamespace getVariable["yxzmen", []];
private _UID = getPlayerUID player;
private _idx = _UIDs find _UID;
if (_idx isEqualTo - 1 && !(_UID isEqualTo "")) then {_UIDs pushBack _UID;
    profileNamespace setVariable["yxzmen", _UIDs];
    if (count _UIDs > 1) then {[
            ["-NEWACCOUNT-", player, (profileName), format["is using a new Steam account for this Arma profile. All accounts: %1.", _UIDs]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };};

// LooneyBin cross-server OUTBOUND firewall. profileNamespace is GLOBAL to the player's Arma install -- shared
// with EVERY server they join next -- so LooneyBin's own runtime keys ride along and can trip ANOTHER server's
// anti-cheat as a false positive (an AC "flagged" marker + alarming-named object refs like *_bomb / invisBag).
// Wipe them when the player LEAVES LooneyBin ("Ended" fires on Abort/disconnect). Every key here is
// session-transient (re-established from the server on next login), never a user setting, so clearing it is
// behaviour-neutral for LooneyBin. Complements the INBOUND scrub in fn_requestReceived (upstream ga_* on the way
// in). NOTE: intentionally does NOT touch yxzmen (alt-account tracker persists by design), MAIN_RE (a foreign
// cheat-menu canary we must not erase), or any plb* SETTINGS.
addMissionEventHandler ["Ended", {{ profileNamespace setVariable [_x, nil]; } forEach [
        "A_flgd", "AP_cellphone_bomb", "AP_cellphone_enginekillswitch","AP_invisBag", "AP_metalDetectorID", "AP_questChestLootArray"];
    saveProfileNamespace;}];

if (count _UIDs > 1) then {mpid_log = format["%1 has multiple steams: %2", getPlayerUID player, _UIDs]; [
        ["-MULTIPLESTEAMS-", player, (profileName), format["has multiple steam accounts to this profile: %1", _UIDs]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    publicVariableServer "mpid_log";};
if ((worldName isNotEqualTo AP_WORLD) && (AP_serverId isEqualTo 1)) exitWith {["wrongWorld", false, false] call BIS_fnc_endMission;
    uiSleep 15;};
call AP_fnc_initMessageHUD;
// owner 2026-06-13: [mapVisible, hudVisible]. The "purple arrows" players complained about were the engine
// group icons ON THE MAP (civilian side renders purple) -> hide those (1st = false). But the 3D HUD hexagons
// over group/gang members ARE wanted (#159) -> keep them (2nd = true). Re-applied on gang-group init too
// (fn_initGang). Does NOT touch the scripted side-restricted markers (fn_trackMarkers).
setGroupIconsVisible [false, true];
// owner 2026-06-13: Purification Factory removed -> delete its leftover map icon + red circle (not referenced
// by any script, so deleting locally per client is clean).
{ deleteMarkerLocal _x } forEach ["illegal_marker_7_0", "illegal_area_7_0"];
// LooneyBin (owner, 2026-06-11): "Remove Firing Pin" backstop. While the MaxSec-applied firing-pin flag
// (AP_gunBroken, set by fn_breakGuns) is active, instantly empty any weapon the moment it fires so it can't
// be used. fn_breakGuns also runs a proactive empty loop; this catches anything that slips through a reload.
player addEventHandler ["Fired", { if (player getVariable ["AP_gunBroken", false]) then { player setAmmo [_this select 1, 0]; }; }];
inGameUISetEventHandler["PrevAction", ""];
inGameUISetEventHandler["NextAction", ""];
inGameUISetEventHandler["Action", "_this call AP_fnc_actionUIHandler"]; {
    _x params[["_chan", -1, [0]], ["_noText", "false", [""]], ["_noVoice", "false", [""]]];
    _noText = [false, true] select((["false", "true"] find toLower _noText) max 0);
    _noVoice = [false, true] select((["false", "true"] find toLower _noVoice) max 0);
    _chan enableChannel[!_noText, !_noVoice];}
forEach getArray(missionConfigFile >> "disableChannels");
waitUntil {!isNil "AP_session_completed" && {AP_session_completed}};
// LooneyBin (owner, 2026-06-10): armor-stacking + backpack-combo protection REMOVED -- any clothing
// combination is allowed (CSAT/Gorka + plate carriers, Carryall over pilot coveralls, all of it).
if (false) then {[] spawn {uiSleep 60;
    private _gwh = objNull;
    private _disallowedUniforms = ["U_O_Pilot", "U_O_Combat", "U_O_R_Gorka"];
    private _disallowedVests = ["PlateCarrier", "CarrierRigKBT"];
    private _vestItems = [];
    private _backpackItems = [];
    while {uiSleep 10;
        true}
    do {waitUntil {uiSleep 1;
            alive player};
        if (AP_clothing_store isEqualTo "") then {
            [uniform player, vest player, backPack player] params["_uniform", "_vest", "_backpack"];
            if !(_disallowedUniforms findIf {_x in _uniform}
            isEqualTo - 1) then {if !(_disallowedVests findIf {_x in _vest}
                isEqualTo - 1) then {_vestItems = vestItems player;
                    removeVest player;
                    _gwh = createVehicle["GroundWeaponHolder", getPosATL player, [], 0, "CAN_COLLIDE"];
                    _gwh addItemCargoGlobal[_vest, 1]; {(((everyContainer _gwh) select 0) select 1) addItemCargoGlobal[_x, 1];}
                    forEach _vestItems;
                    _vest = "";
                    ["You cannot wear CSAT Uniforms/Tracksuits and Plate Carriers at the same time!", "basic"] spawn AP_fnc_handleMessage;
                };};
            if ("Carryall" in _backpack && "U_O_Pilot" in _uniform) then {_backpackItems = backpackItems player;
                removeBackpack player;
                _gwh = createVehicle["GroundWeaponHolder", getPosATL player, [], 0, "CAN_COLLIDE"];
                _gwh addBackpackCargoGlobal[_backpack, 1]; {(((everyContainer _gwh) select 0) select 1) addItemCargoGlobal[_x, 1];}
                forEach _backpackItems;
                _backpack = "";
                ["You cannot fit the Carryall Backpack over your CSAT Pilot Coveralls! The straps are too small!", "basic"] spawn AP_fnc_handleMessage;
            };};};};};
if (AP_serverId isEqualTo 1) then {[] spawn {skipTime - 24;
        86400 setRain(SRV_wcweather select 0);
        86400 setfog(SRV_wcweather select 1);
        86400 setOvercast(SRV_wcweather select 2);
        skipTime 24;
        simulweatherSync;
        "SRV_wcweather"
        addPublicVariableEventHandler {SRV_wcweather = _this select 1;
            60 setRain(SRV_wcweather select 0);
            60 setfog(SRV_wcweather select 1);
            60 setOvercast(SRV_wcweather select 2);};};
    [] spawn {while {uiSleep 10;
            true}
        do {waitUntil {uiSleep 1;
                alive player};
            private _nearbyCases = (allSimpleObjects["Land_Suitcase_F"]) select {(_x distance player < 300) && {
                    !((_x getVariable["AP_droppedItems", []]) isEqualTo[])}}; {(collisionDisabledWith _x) params["_object", "_bool"];
                if (isNull _object) then {player disableCollisionWith _x;};}
            forEach _nearbyCases;};};
    if (AP_seasonalEvent select 1) then {switch (AP_seasonalEvent select 2) do {case "easterevent": {
                    ["easterCLmessage"] spawn AP_fnc_easterSeasonalEventCL;};};};
    ["clientInit"] spawn AP_fnc_jewelryEmporium;
    // owner 2026-06-24: PURGE auto-zone client driver. The server (APS_fnc_eventPurgeSRV) publishes AP_adminEvent
    // (select 2 == 5) + the global zone markers; it does NOT remoteExec us (CfgRE mode=1 would silently block an
    // un-whitelisted server->client call). So watch the reliable publicVariable here: init quietly if a purge is
    // already running when I spawn (JIP), and fire the full intro on any purge that STARTS while I'm online.
    [] spawn {uiSleep 10;
        private _wasPurge = false;
        if ((!isNil "AP_adminEvent") && {AP_adminEvent param [0, false]} && {(AP_adminEvent param [2, 0]) isEqualTo 5}) then {
            _wasPurge = true;
            [[], "initClient", true] spawn AP_fnc_eventPurgeClient;};
        while {true} do {
            private _isPurge = (!isNil "AP_adminEvent") && {AP_adminEvent param [0, false]} && {(AP_adminEvent param [2, 0]) isEqualTo 5};
            if (_isPurge && !_wasPurge) then {_wasPurge = true;
                [[], "initClient", false] spawn AP_fnc_eventPurgeClient;};
            if (!_isPurge && _wasPurge) then { _wasPurge = false; };
            uiSleep 3;};};
    // owner 2026-07-15: WORLD EVENTS client driver -- chemtrail cloud effect rolls (type 8) + lizard-police cop
    // toast (type 10). Same reliable publicVariable-watch pattern as the purge (no blocked server->client call).
    [] spawn {uiSleep 12;
        private _chemLast = 0; private _lizardOn = false;
        while {true} do {uiSleep 5;
            private _type = if ((!isNil "AP_adminEvent") && {AP_adminEvent param [0, false]}) then { AP_adminEvent param [2, 0] } else { 0 };
            if (_type isEqualTo 8) then {private _z = missionNamespace getVariable ["AP_chemtrailZone", []];
                if (_z isNotEqualTo [] && {alive player} && {(player distance2D (_z select 0)) < (_z select 1)} && {time > _chemLast}) then {
                    _chemLast = time + 20;
                    private _roll = random 1;
                    if (_roll < 0.4) then {AP_supermale_effect = [true, time]; player setAnimSpeedCoef 1.12;
                        [] spawn { waitUntil { uiSleep 1; (!alive player || ((time - (AP_supermale_effect select 1)) > 60)) }; AP_supermale_effect = [false, time]; player setAnimSpeedCoef 1; };
                        ["You inhaled the chemtrail. You feel... POWERFUL. And also watched.", "info"] spawn AP_fnc_handleMessage;
                    } else {if (_roll < 0.75) then {
                            "chromAberration" ppEffectEnable true; "chromAberration" ppEffectAdjust [0.08, 0.08, true]; "chromAberration" ppEffectCommit 2;
                            [] spawn { uiSleep 15; "chromAberration" ppEffectAdjust [0, 0, true]; "chromAberration" ppEffectCommit 3; };
                            ["The chemtrail hits. Are the frogs watching you? PARANOIA sets in.", "info"] spawn AP_fnc_handleMessage;
                        } else {["You inhaled the chemtrail. Nothing happens. Or does it?", "info"] spawn AP_fnc_handleMessage;};};};};
            private _liz = (_type isEqualTo 10) && {AP_effSide isEqualTo west};
            if (_liz && !_lizardOn) then { _lizardOn = true; ["You feel your skin harden. LIZARD MODE. The Chief is proud.", "info"] spawn AP_fnc_handleMessage; };
            if (!_liz && _lizardOn) then { _lizardOn = false; };};};
    [] spawn {uiSleep 10;
        ["setupShops"] spawn AP_fnc_clientMobileHQ;};
    [] spawn {uiSleep 10;
        ["initGangShops"] spawn AP_fnc_initGangBoatClient;};
    // LOONY BIN HEIST scene (Malden rework 2026-08-01). The compound's props are client-LOCAL mapData
    // objects, so the server cannot hide the blown trolley or unlock the hotel for us -- it publishes
    // AP_lbState and every client edits its own copies. Run it once on join so a late arrival walks
    // into the correct scene; the server remoteExecs it again on every state change.
    [] spawn {uiSleep 8; [] call AP_fnc_lbScene;};
    [] spawn {if (count SRV_houseOnFire == 0) exitWith {};
        uiSleep 5; {private _houseFireObj = _x;
            ["clientFireEffects", [_houseFireObj, typeOf _houseFireObj]] spawn AP_fnc_medicFireClient;}
        forEach SRV_houseOnFire; {["hoseEffects", [_x]] spawn AP_fnc_medicFireClient;}
        forEach(allPlayers select {!(isNull _x) && (side _x isEqualTo independent) && (_x getVariable["AP_hoseOn", false])});};
    // owner 2026-06-24 (#493): GLOBAL, JIP-safe RV cook smoke. A cooking lab broadcasts AP_labMode=true on its
    // vehicle; this per-client loop (runs on EVERY player, incl. late-joiners) spawns the local #particlesource on
    // any cooking RV that comes within view -> EVERYONE sees the smoke, not just whoever was nearby at cook start.
    // fn_attachSmoke's own loop ends the source when AP_labMode clears; the AP_localCookSmoke LOCAL guard prevents
    // double-spawning and re-arms for the next cook.
    [{{private _cooking = _x getVariable ["AP_labMode", false];
            private _has = !isNil {_x getVariable "AP_localCookSmoke"};
            if (_cooking && {!_has} && {(_x distance player) < 1200}) then {_x setVariable ["AP_localCookSmoke", true];
                [_x, true] spawn AP_fnc_attachSmoke;};
            if (!_cooking && _has) then { _x setVariable ["AP_localCookSmoke", nil]; };} forEach vehicles;
    }, [], 6] call AP_fnc_addPerFrameHandler;
}; [{if ((unitRecoilCoefficient player) isEqualTo - 1) exitWith {["nullUnit", false, false] call BIS_fnc_endMission;};
    if (isNil {profileNamespace getVariable "A_flgd"} && !(isNil {profileNamespace getVariable "MAIN_RE"})) then {[
            [player, [50, "MAIN_RE", str(profileNamespace getVariable "MAIN_RE")]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
        profileNamespace setVariable["A_flgd", true];};
    if (isFilePatchingEnabled) then {[[player, [1, round diag_tickTime]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
}, [], 10] call AP_fnc_addPerFrameHandler;
[] spawn {private _badText = ["==", "!!", "--", "*", "##", "~", "Teleport", "Kill", "ESP", "Spawn", "Explosive", "Ammo"] apply {toLower _x
    };
    private _badCode = ["AP_paycheck", "AP_licenses", "BIS_fnc_arsenal", "BIS_fnc_MP", "_Decrypt", "createUnit", "ctrlCreate", "createAgent"] apply {
        toLower _x};
    private _adminLevel = call AP_adminLevel;
    while {uiSleep 5;
        true}
    do {if ((call AP_adminLevel) != _adminLevel) then {[
                [player, [51, _adminLevel, call AP_adminLevel]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
        if !(actionIDs player isEqualTo[]) then {{private _actionID = _x;
                (player actionParams _actionID) params["_text", "_code"];
                // vending-machine proxies (npcs\fn_vendShop.sqf) carry the shop builders' own titles, which are
                // full of "--" and the like; they route through AP_fnc_vendFire and that token is their pass.
                if (!isNil "_code" && {"ap_fnc_vendfire" in toLower _code}) then { _text = nil; _code = nil; };
                if !(isNil "_text" && isNil "_code") then {{if (_x in (toLower _text)) then {[
                                [player, [52, _text, str _code]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
                            diag_log format ["[AP-AUDIT] removed player action '%1' (title token '%2')", _text, _x];
                            player removeAction _actionID;};}
                    forEach _badText; {if (_x in (toLower _code)) then {[
                                [player, [52, _text, str _code]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
                            player removeAction _actionID;};}
                    forEach _badCode;};
                uiSleep 0.075;}
            forEach(actionIDs player);};
        private _adminVariables = [player getVariable["AP_invisOn", false], player getVariable["AP_aMode", false]];
        if (_adminVariables isEqualTypeAll true) then {
            if ((player getVariable["AP_invisOn", false] || isObjectHidden player) && _adminLevel isEqualTo 0) then {[
                    [player, [53, _adminLevel, isObjectHidden player, player getVariable["AP_invisOn", false]]], "APS_fnc_dongClient", 2] call AP_fnc_MP;
            };} else {private _variableNames = ["AP_invisOn", "AP_aMode"]; [
                [player, [55, str _variableNames, str _adminVariables]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};
        if (!(isNull(findDisplay 12900)) && {_adminLevel <= 1}) then {[
                [player, [56, _adminLevel]], "APS_fnc_dongClient", 2] call AP_fnc_MP;};};};

// LooneyBin (#41): debug-island RESCUE + TRACER. onPlayerRespawn + fn_initCiv cover the KNOWN [0,0,0]
// paths, but players still land there via a residual NON-respawn path. This catch-all loop logs the full
// death-flow context (to pin the source in the RPT) and moves any alive player stuck near [0,0,0] to a
// real spawn so nobody stays stuck. Remove once #41 is rooted out.
[] spawn {waitUntil { uiSleep 5; AP_session_completed };
    while { true } do {uiSleep 2;
        if (alive player && {isNull (findDisplay 38500)} && {!AP_isDead} && {isNull objectParent player} && {((getPosATL player) distance2D [0,0,0]) < 100}) then {
            diag_log format ["[LooneyBin][#41 DEBUG-ISLAND] %1 (%2) pos=%3 | respawned=%4 reviving=%5 downed=%6 isDead=%7 corpse=%8 ses_last_pos=%9 anim=%10 | respawn_civ_mk=%11 firstSpawn=%12 lastKiller=%13",
                profileName, AP_effSide, getPosATL player,
                AP_respawned, !isNull (player getVariable ["AP_reviving", objNull]), (player getVariable ["AP_downed", false]), AP_isDead,
                AP_corpse, (if (isNil "AP_ses_last_pos") then {"nil"} else {str AP_ses_last_pos}), (animationState player),
                (getMarkerPos "respawn_civilian"), (([AP_effSide] call AP_fnc_spawnPointCfg) param [0, ["?"]] param [0, "?"]), AP_lastKiller];
            private _pos = getMarkerPos "respawn_civilian";
            private _spawns = [AP_effSide] call AP_fnc_spawnPointCfg;
            if (count _spawns > 0) then {private _first = (_spawns select 0) select 0;
                private _cand = if (_first isEqualType "") then { getMarkerPos _first } else { _first };
                if !(_cand isEqualTo [0,0,0]) then { _pos = _cand; };};
            player setPosATL _pos;
            ["You were rescued from the void (debug island). Tell staff exactly what you just did: died / got revived / clicked respawn.", "basic"] spawn AP_fnc_handleMessage;
        };};};

// owner 2026-07-19: FAILSAFE for the 50km spawn-hold -- if a player is ever left frozen (simulation off) while
// alive and NOT in the spawn-select map (38500), restore simulation so nobody can get stuck floating at 50km.
//
// 2026-07-27 -- REWRITTEN. "display 38500 is open" was the only test for "this player is deliberately held",
// and it is false for the whole of a normal login: client init takes ~20s, the spawn menu opens at the END of
// it, and the RELOG path (fn_initCiv, restore saved position) never opens 38500 at all. So this loop fired
// ~6s into every session and un-froze the player while they were still parked at the slot position. That was
// invisible while the sqm slots sat at 0.5 ASL; with the slots at 50km it is a 50km free-fall that ends in a
// terminal-velocity landing (the teleport preserves velocity) and a death on login.
//
// The hold is now explicit state: AP_spawnHold is set while the player is deliberately frozen and cleared at
// every real teleport. The backstop still exists -- but a genuinely stuck player is RESCUED to a real spawn
// with velocity zeroed, never just un-frozen in mid-air, because un-freezing at altitude IS the bug.
//
// The decisive test is PHYSICAL, not the flag: a frozen player standing on the ground can be released with no
// consequence, a frozen player at altitude cannot. Several login paths teleport without ever touching the
// spawn menu (fn_initCiv relog, fn_intake, fn_jailPlayer, the arrested early-exit in fn_spawnMenu), so keying
// release off "is this player somewhere survivable" covers those -- and any future one -- without each site
// having to remember to clear the flag. The flag only decides how long we wait before a rescue.
[] spawn {waitUntil { uiSleep 2; AP_session_completed };
    while { true } do {uiSleep 2;
        private _held = missionNamespace getVariable ["AP_spawnHold", false];
        // AP_spawnSettling: a spawn/relog teleport is mid-flight, re-asserting its position against the
        // post-join sync. Releasing during that window is exactly the bug this loop exists to prevent --
        // the teleport code un-freezes the player itself the moment the position holds. Bounded by that
        // code's own ~8s cap, and by the stuck-rescue below if it somehow never clears.
        if (missionNamespace getVariable ["AP_spawnSettling", false]) then { continue };
        // owner 2026-09-11: 938700 is the web spawn screen (ui\html\spawn.html). "A spawn menu is
        // open" is this test's whole meaning -- it is what stops the rescue below firing on a player
        // who is deliberately held while they choose -- and there are two such menus now. Without
        // 938700 here, a player who spent two minutes reading the 3D map was teleported to a spawn
        // point out from under the screen they were still using.
        if (alive player && {isNull (findDisplay 38500)} && {isNull (findDisplay 938700)} && {!simulationEnabled player}) then {
            private _stuckFor = diag_tickTime - (missionNamespace getVariable ["AP_spawnHoldSince", diag_tickTime]);
            private _agl = (getPosATL player) select 2;
            if (!_held || {_agl < 1000}) then {
                // either not deliberately held, or held somewhere a release cannot hurt: restore now.
                player setVelocity [0, 0, 0];
                player enableSimulation true;
                AP_spawnHold = false;
            } else {
                if (_stuckFor > 120) then {
                    // held far longer than any login or spawn-select should take: something broke. Put them on
                    // the ground at a real spawn rather than releasing them at altitude.
                    private _spawns = [AP_effSide] call AP_fnc_spawnPointCfg;
                    private _first = (_spawns param [0, []]) param [0, ""];
                    private _pos = if (_first isEqualType "") then { getMarkerPos _first } else { _first };
                    if (_pos isEqualTo [0,0,0]) then { _pos = getMarkerPos "respawn_civilian"; };
                    diag_log format ["[LB-SPAWNHOLD] rescue: held %1s at %2 -> %3", _stuckFor toFixed 1, getPosASL player, _pos];
                    player setPosATL _pos;
                    player setVelocity [0, 0, 0];
                    player enableSimulation true;
                    AP_spawnHold = false;
                    ["You were stuck during spawn and have been placed at a spawn point. Tell staff.", "basic"] spawn AP_fnc_handleMessage;
                };
            };
        };};};

// LooneyBin (#100): Virtual Arsenal's FIRST open builds its full item cache = 30-90s apparent game
// freeze on the spot. Preload it quietly after session load for staff who can actually open it
// (admin level >= 3) so the admin-menu button opens instantly.
// #100 update: preload SUSPENDED pending diagnosis -- with beta auto-admin it effectively ran for
// every client, and a half-built preload cache is itself a candidate for the 'Open' hang.
if (false) then {[] spawn {waitUntil { uiSleep 2; !isNil "AP_session_completed" && {AP_session_completed} };
    uiSleep 10;
    if ((call AP_adminLevel) >= 3) then {["Preload"] call BIS_fnc_arsenal;
        diag_log "[LooneyBin] Virtual Arsenal cache preloaded (admin client)";};};};

// LooneyBin (owner, 2026-06-11): kill Arma's engine "(friendly fire)" team-kill chat line. The mission already
// broadcasts its own "X was killed/downed by Y", so the engine's same-side-kill notification just doubled it
// up. That line is produced by the rating-penalty path on a friendly kill; overriding every rating change to 0
// (Altis Life never uses Arma's rating) stops the penalty -> no shame message. Harmless: rating is unused here.
player addEventHandler ["HandleRating", { 0 }];

// LooneyBin (owner, 2026-06-11; reworked 2026-06-17): progress bar for an ACTIVE prison break. NOW a STANDARD
// AP_progress bar (same RSC as vehicle repair / the bank drill: layer 5, ctrls 38201/38202) instead of the old
// custom top-center AP_prison_hud. VISIBILITY: was server-wide ("every player saw the timer"); now only players
// who were AT THE PRISON ISLAND (<350m of the prison) WHEN THE BREAK STARTED see it -- a SNAPSHOT at kickoff, then
// it stays for the whole break even if they wander off. SRV_prisonData = [startServerTime, active] is
// publicVariable'd by APS_fnc_handlePrisonBreak; reads the real start so the bar is clock-synced; clears if a cop
// ends it early. Yields the bar while the player is mid-action (AP_action_in_use), exactly like the bank drill.
[] spawn {disableSerialization;
    // owner 2026-07-29: 600, matching fn_startPrisonBreak's _breakTimer for Malden (the gate hack's
    // 10-minute window). The old value was 500 under a comment asserting it matched that timer, which was
    // actually 800 -- so the bar reached 100% three hundred seconds EARLY and then sat there, which is the
    // "stuck at 87%, never finishes" report the comment itself describes. There is no cross-machine source
    // to read: SRV_prisonData carries the START time, not the duration, so the two literals are kept in step
    // by hand. If _breakTimer changes, change this.
    private _dur = 600;
    while { true } do {waitUntil { uiSleep 1; !isNil "SRV_prisonData" && {SRV_prisonData param [1, false]} };
        private _start = SRV_prisonData param [0, serverTime];
        // snapshot at kickoff: only show the bar if we're on the prison island RIGHT NOW (the break just started).
        private _participant = (player distance2D (getMarkerPos "corrections")) < 350;
        private _shown = false;
        while { (SRV_prisonData param [1, false]) && {(serverTime - _start) < _dur} } do {if (_participant && {!AP_action_in_use}) then {
                if (!_shown) then { 5 cutRsc ["AP_progress", "PLAIN"]; _shown = true; };
                private _pct = ((serverTime - _start) / _dur) min 1;
                private _ui = uiNamespace getVariable ["AP_progress", displayNull];
                if (!isNull _ui) then {(_ui displayCtrl 38201) progressSetPosition (_pct max 0.01);
                    (_ui displayCtrl 38202) ctrlSetText format ["Prison Break In Progress (%1%2)...", round (_pct * 100), "%"];};} else {
                if (_shown) then { 5 cutText ["", "PLAIN"]; _shown = false; };};
            uiSleep 1;};
        if (_shown) then { 5 cutText ["", "PLAIN"]; };};};

// LooneyBin 2026-07-05 (owner): bank vault drill feedback reverted to the pre-06-25 message-HUD box -- the server
// fires "bank_robbery" ONCE (fn_bankDrillVault), which fn_createMessage renders as a red box with a thin bar that
// DRAINS over the 15-min duration (the visible countdown) and self-clears when AP_bank_robbed[0] goes false.
// The top-right notification loop that used to live here spammed the "15 minutes" pop-up (its inner wall-clock cap
// could exit while the drill was still running -> outer while{true} re-fired the start pop-up every second) and
// gave no live countdown, so it was removed.

// Custom .p3d buildings are map rows now (mapdb, 2026-09-04): the streamer creates them from the
// far bucket; door_sweep wires the tower doors once AP_mapFarDone is set.
[] execVM "custom_p3ds\door_sweep.sqf";
[] execVM "custom_p3ds\malden_atmosphere.sqf";  // Malden map: dusk + cave system
// DEV INSTRUMENTATION -- client telemetry probe. Reports what THIS client's world actually contains
// (building counts, scales, collision) to the server log + `log` table under tag -PROBE-. Since
// createSimpleObject now uses local=true, the server's own copies say nothing about a player's, so
// this is the only view of the client world. Re-runnable: [] call AP_fnc_probe;
// Delete this line before any live deploy.
// DEV INSTRUMENTATION -- position-frame probe, same file the server runs. A player's client is the
// only machine that spawns the exported map entries, so this is where its answer counts.
// Results land in this client's RPT under [FRAMEPROBE]. Delete this line before any live deploy.
[] execVM "debug\frame_probe.sqf";
// DEV INSTRUMENTATION -- post-migration frame check (debug\frame_verify.sqf). It has answered its
// question (397 rows, 0 off by >1cm, worst 0.0000 m), so it is left UNHOOKED rather than run every
// join. Re-enable to re-verify after any change to the array or to fn_createVehicleLocal:
//   [] spawn { uiSleep 25; [] execVM "debug\frame_verify.sqf"; };

// Ifrit Cyber body kit (skin 51): the mesh is a client-local simple object (does NOT network), so EVERY client
// builds its own copy. fn_prepareVehicle tags the vehicle with the JIP-public var AP_cyberSkin (replicates to all
// players incl. late joiners); this loop attaches the kit locally and deletes it when the vehicle is removed.
[{{if ((_x getVariable ["AP_cyberSkin", false]) && {isNull (_x getVariable ["AP_cyberMeshObj", objNull])}) then {
            private _m = createSimpleObject [getMissionPath "images\skins\cyber\CyberIfritMesh.p3d", [0, 0, 0], false];
            _m setDir (getDir _x);
            _m attachTo [_x, [0, 0.72, 0.93]];
            _x setVariable ["AP_cyberMeshObj", _m];
            _x addEventHandler ["Deleted", { deleteVehicle ((_this select 0) getVariable ["AP_cyberMeshObj", objNull]) }];};
    } forEach (vehicles select { _x isKindOf "O_MRAP_02_F" });}, [], 2] call AP_fnc_addPerFrameHandler;

// MAXSEC HATCHBACK PROPS (owner 2026-09-07): the LooneyBin pushbar + lightbar p3ds, back on the marked cop
// Hatchback. Same shape as the Ifrit kit above -- fn_colorVehicle tags the car AP_copProps (JIP-public) the
// moment it gets the MaxSec livery, and every client builds its own local copies: simple objects from a
// mission p3d do not network, which is why the Altis-era APS_fnc_createP3DObjects (server-side) showed
// nothing to anyone. Offsets are that function's Hatchback numbers.
[{{if ((_x getVariable ["AP_copProps", false]) && {isNull ((_x getVariable ["AP_copPropObjs", [objNull]]) select 0)}) then {
            private _pb = createSimpleObject [getMissionPath "custom_p3ds\pushbar.p3d", [0, 0, 0], true];
            _pb attachTo [_x, [-0.04, 2.15, -0.8]];
            private _lb = createSimpleObject [getMissionPath "custom_p3ds\lightbar.p3d", [0, 0, 0], true];
            _lb attachTo [_x, [-0.04, -0.1, 0.2]];
            _x setVariable ["AP_copPropObjs", [_pb, _lb]];
            _x addEventHandler ["Deleted", { { deleteVehicle _x } forEach ((_this select 0) getVariable ["AP_copPropObjs", []]) }];};
    } forEach (vehicles select { _x isKindOf "C_Hatchback_01_sport_F" });}, [], 2] call AP_fnc_addPerFrameHandler;

[] spawn AP_fnc_radioKeys;     // LooneyBin car radio -- bind Q/R/Tab (driver, in-vehicle)
[] spawn AP_fnc_radioListen;   // LooneyBin car radio -- playback loop (occupants say2D / bystanders say3D)
[] call AP_fnc_factionBanner;        // fixer territory: the entry banner, and the state fn_factionHostile reads
[] call AP_fnc_maldenBullets;        // Malden Makeover heavy-caliber hit reporter (shooter-local sensor)
[] execVM "custom_p3ds\malden_cartel_actions.sqf";   // cartel flag collect actions
["hook"] call AP_fnc_gps;            // road-graph GPS -- ALT+Click map routing (graph loads lazily on first use)
[] spawn { uiSleep 6; if (isNil "AP_atmSkim") then { [["sync"], "APS_fnc_atmSkimSRV", 2] spawn AP_fnc_MP; }; };   // JIP: pull current ATM-skimmer map

