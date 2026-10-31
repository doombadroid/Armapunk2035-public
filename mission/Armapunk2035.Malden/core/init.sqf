#include "..\macro.h"
// SECURITY 2026-09-26: functions that define their helper globals on first use define them NOW, before
// this client can meet another client's publicVariable of a compileFinal'd copy (a final value cannot
// be replaced, so whichever lands first stays). Each call defines that file's helpers and returns at its
// "boot" line. Only the pre-join window remains (values published before this client joined).
{ "boot" call _x } forEach [AP_fnc_invBridge, AP_fnc_invFigure, AP_fnc_mapOpen, AP_fnc_spawnWebBridge,
    AP_fnc_visorBridge, AP_fnc_suiteKiosk, AP_fnc_suiteMenu, AP_fnc_mapEditor, AP_fnc_mapEditorOps,
    AP_fnc_mapEditorPanel, AP_fnc_gpsHud, AP_fnc_radioRadial, AP_fnc_weaponShopCfg, AP_fnc_rigClient,
    NPC_fnc_vendShop];
["init", []] call AP_fnc_invLocal;
// Called but never implemented (item uses, a dialog button, a chat command): final no-ops, so no other
// client can publicVariable code under these names for those callers to run.
{ if !(isFinal _x) then { missionNamespace setVariable [_x, compileFinal {}]; }; } forEach ["AP_fnc_inspectLootCrate",
    "AP_fnc_pocketCars", "AP_fnc_pocketparachute", "AP_fnc_distressBeacon", "AP_fnc_removeItem", "AP_fnc_face"];
if (isNil "AP_effSide") then { AP_effSide = playerSide; };
AP_message_active = scriptNull;
AP_firstSpawn = true;
AP_session_completed = false;
AP_lastDisplay = -2;
AP_loadingScreenStatus = "Setting Up Client, Please Wait...";
private _timeStamp = diag_tickTime;
diag_log "------------------------------------------------------------------------------------------------------";
diag_log format["--------------------------------- Starting %1 Life Client Init ----------------------------------", AP_worldName];
diag_log "------------------------------------------------------------------------------------------------------";
waitUntil {!isNull player && player == player};
waitUntil {!(isNull(findDisplay 46))};
[true] spawn AP_fnc_loadingScreen;
uiSleep 0.05;
// The web landing (phase 9) replaces the legacy welcome cover entirely -- showing both meant the
// old screen flashed first for the whole session load (owner report 2026-08-20). Landing disabled
// (SRV_landingEnabled false, or the var never arrives from an older server -- default TRUE keeps the
// modern path) restores the legacy welcome unchanged.
if (!(missionNamespace getVariable ["SRV_landingEnabled", true])) then { ["initWelcomeUI"] spawn AP_fnc_welcomeUI; };
uiSleep 1.5;
waitUntil {!isDedicated || time > 40};
diag_log "::Life Client:: Initialization Variables";
[] call compile PreprocessFileLineNumbers "core\configuration.sqf";
// Luxe Suites shared identity/geometry helpers (AP_fnc_suite*). ONE definition,
// loaded on the client here and on the server in initServer.sqf -- the oid must be
// derived identically on both sides or every lookup silently misses (#374).
[] call AP_fnc_suiteData;
// Kiosk screen art. Must be a running pass, not a one-shot: the diorama is a
// mapData object, i.e. client-local and zone-streamed, so it does not exist yet
// at init and is recreated whenever the player re-enters the area.
[] spawn AP_fnc_suiteKioskArt;
// Furniture is presence-spawned -- this is what tells the server the tenant is here.
[] spawn AP_fnc_suitePresence;
// LooneyBin TEST: Owner-only phone button to toggle auto-granting roles to new players. Condition is
// evaluated at phone-open, so adminLevel need not be set yet here. New players get adminLevel 4 (not 5),
// so they never see this button.
(localNamespace getVariable "AP_phone_buttons") pushBack ["Owner Mode", "", "[] spawn AP_fnc_ownerMode", {(getPlayerUID player) isEqualTo "76561190000000001"}, "Owner Mode: toggle ESP + no sway/recoil (you only) + Super Spangle scroll"];
// Task 9: the ArmaQuest journal, one app in the deck's grid. Named "Quest
// Log", not "Quests" -- this mission already has a native "Quests"/CONTRACTS
// app (fn_deckList.sqf case "quests"; AP_completedQuests/AP_activeQuest;
// favourited by default on the civ side) that is unrelated to ArmaQuest. A
// second app literally called "Quests" would be a second, identically
// labelled menu entry doing something else -- so this one gets its own name.
// Own dialog, like Casino/Summon/Map, so it needs no LIST_APPS/
// TREE_APPS entry in deck.html: the "launch" bridge's generic fallback
// (core\web\fn_deckOpen.sqf, case "launch") already opens any app name not
// special-cased in the page's own JS, exactly like those three.
// UI overhaul (2026-08-26): world interactables open as deck apps. False falls
// every routed entry point back to its native dialog in one flip.
AP_deckApps = true;

// owner 2026-09-05: this button now opens the CONTRACTS picker (AP_fnc_aqContracts), not the journal
// directly. It is the ONLY door to a quest board: the giver NPCs are gone and so are the six
// "Cyberdeck: Contact X" scroll-wheel entries that replaced them, so "who do I call" had to move
// somewhere, and the phone is where the deck's other apps already are. "My Journal" is the first row
// of the picker, so the old one-tap-to-journal path is one extra click, not a lost one. The NAME stays
// "Quest Log" -- fn_deckData's icon catalogue keys off it, and the native "Quests"/CONTRACTS app this
// mission already has (fn_deckList case "quests") is a different, unrelated app.
(localNamespace getVariable "AP_phone_buttons") pushBack ["Quest Log", "", "[] call AP_fnc_aqContracts", {true}, "ArmaQuest -- call a fixer for work, or read your own journal"];
// The HTML rebuild of the handset, reachable from the handset it replaces. CTRL+Y opens it
// too; this button is the entry that cannot depend on a modifier key being free. Deliberately
// has no entry in fn_deckData's catalogue, so the deck does not list itself.
// arma-webui lives under webui\ in this mission, not at the library default.
WEBUI_jsPath = "webui\ui\webui.js";

// Warm the session's assets while the loading screen still owns the frame: an invisible
// layer page pulls the map's three text files, all 169 tile conversions at two mips and
// every item icon through A3API, so the first M press, the first shop and the first
// inventory find them done (and the session's first webview spawn -- the slowest --
// happens here, not on a keypress). Fire-and-forget; it never blocks anything.
//
// AP_warmPct IS SET HERE, NOT LEFT TO THE PAGE, and 0 is the whole reason. The landing
// screen reads it for its loading bar (fn_landingData), and the landing can open BEFORE
// this layer is cut on a client whose session completes in under eight seconds -- so
// without this line that client would see a full bar drop to nothing and climb again.
// The 100 default in fn_landingData still covers the case where this file never ran at
// all, and fn_warmBridge's watchdog covers a bridge that comes up and then goes quiet.
AP_warmPct = 0;
AP_warmReported = false;
["AP_map_warm"] spawn {
    uiSleep 8;
    (_this select 0) cutRsc [_this select 0, "PLAIN", 0, false];
    // The page cannot report until something registers a handler for it to call. Failure
    // is soft in every direction: the warmer warms either way and the bar falls back to 100.
    [] call AP_fnc_warmBridge;
};

// PREPENDED, not pushBack'd. The native phone has exactly 25 app slots
// (smartphone.hpp idc 90200-90224) and fills them in array order; an appended
// entry is the first thing to fall off the end when the array grows. That is
// exactly what happened when the Map tile landed: Deck OS was last, slot 26 is
// displayCtrl 90225 = controlNull, and the tile silently vanished. First place
// is also the right place for the screen that replaces the rest of them.
// localNamespace, not a global (security 2026-09-26): the rows carry CODE gates and action strings that
// fn_deckOpen compiles, and a client's publicVariable of a mission global would replace them on every
// machine. localNamespace cannot be written over the network. AP_achievementInfo/AP_wallpapers likewise.
localNamespace setVariable ["AP_phone_buttons", [["Deck OS", "", "[] call AP_fnc_deckPhone", {true}, "NEON AEGEAN OS -- the HTML phone (work in progress). The native phone stays on Y."]] + (localNamespace getVariable "AP_phone_buttons")];
// mapdb (2026-09-04): no baked array on the client any more. The streamer asks the server for
// the far bucket and then for 1 km cells around the player as they move; every object carries
// its own stream radius and detail tier. AP_exchangeSpots arrives as a server publicVariable.
[] spawn AP_fnc_mapStream;
diag_log "::Life Client:: Variables initialized";
diag_log "::Life Client:: Eventhandlers completed";
diag_log "::Life Client:: Waiting for server functions to transfer..";
diag_log "::Life Client:: Received server functions.";
AP_loadingScreenStatus = "Waiting For Server To Be Ready...";
diag_log "::Life Client:: Waiting for the server to be ready..";
waitUntil {!isNil "AP_server_isReady"};
waitUntil {(AP_server_isReady || !isNil "AP_server_extDB_notLoaded")};
if (!isNil "AP_server_extDB_notLoaded" && {!(AP_server_extDB_notLoaded isEqualTo "")}) exitWith {
    diag_log "::Life Client:: Server did not load extDB3";
    AP_loadingScreenStatus = "Server Side Extension EXTDB3 was not loaded into the engine. Contact an LoonyBin Developer";};
waitUntil {(!isNil "SRV_VehiclesLoaded")};
waitUntil {SRV_VehiclesLoaded};
[] call AP_fnc_dataQuery;
waitUntil {AP_session_completed};
AP_loadingScreenStatus = "Finishing Client Setup...";
[] spawn AP_fnc_initStats;
if ((isNil {profileNamespace getVariable "LoonyBinClientSettings"}) || {
    (count(profileNamespace getVariable "LoonyBinClientSettings")) < count AP_clientDefaultSettings}) then {AP_scrollDisabled = false;
    AP_hexMode = false;
    AP_showTitle = true;};
// FACTION REWORK: everyone logs in a civilian, so there is nothing to dispatch on. The lobby used to
// fan out here by playerSide -- cop init, medic init, and a "coming soon" teaser for the 26 OPFOR
// slots that bounced the player back out -- and all four branches died with the slots themselves.
// MaxSec and Trauma are entered at an HQ duty terminal now (AP_fnc_dutyTerminal -> APS_fnc_dutySRV ->
// AP_fnc_dutyClient), which is a mid-session transition and has nothing to do with login.
private _handle = [] spawn AP_fnc_initCiv;
waitUntil {scriptDone _handle};
[] call AP_fnc_zoneCreator;
player setVariable["AP_restrained", false, true];
player setVariable["AP_escorting", false, true];
player setVariable["AP_transporting", false, true];
diag_log "Past Settings Init";
[] execFSM "core\fsm\client.fsm";
diag_log "Executing client.fsm";
waitUntil {!(isNull(findDisplay 46))};
diag_log "Display 46 Found";
diag_log "::Life Client:: Setting up Eventhandlers";
[] call AP_fnc_setupEVH;
diag_log "------------------------------------------------------------------------------------------------------";
diag_log format["---------------------------------- End of %1 Life Client Init :: Total Execution Time %2 seconds -------------------------------------", AP_worldName, diag_tickTime - _timeStamp];
diag_log "------------------------------------------------------------------------------------------------------";
AP_sidechat = true;
if (AP_effSide isEqualTo civilian || AP_effSide isEqualTo independent) then {[AP_sidechat] call AP_fnc_manageSidechat;};
AP_loadingScreenStatus = "LoonyBin Client Loaded";
[] call AP_fnc_hudSetup;
// The owner's STATUS HUD as an HTML page, on its own RscTitles layer over the native one.
// AFTER hudSetup on purpose: that call is what cuts AP_playerHUD and runs the first
// AP_fnc_hudUpdate, so the native HUD is already on screen and already correct before a second
// one is offered, and the layer that fails to come up costs the player nothing. AP_webHudEnabled
// false skips the whole thing (default true). See core\web\fn_hudWebInit.sqf.
[] call AP_fnc_hudWebInit;
AP_ID_PlayerTags = addMissionEventHandler["EachFrame", {call AP_fnc_playerTags}];
[] call AP_fnc_settingsInit;
player setVariable["AP_steamid", getPlayerUID player, true];
player setVariable["AP_name", profileName, true];
player switchCamera "EXTERNAL";
if ((AP_effSide isEqualTo civilian)) then {if ((((profileNamespace getVariable["AP_coloredHexesData", [[-1, ""], []
    ]]) param[0, []]) param[1, ""]) isNotEqualTo "") then {
        player setVariable["AP_coloredHexesData", (((profileNamespace getVariable["AP_coloredHexesData", [[-1, ""], []
        ]]) param[0, []]) param[1, ""]), -2];};};
setPlayerRespawnTime AP_respawn_timer;
AP_fnc_moveIn = compileFinal "player moveInCargo (_this select 0);";
[] spawn AP_fnc_survival;
if (AP_effSide isEqualTo independent) then {if (124 in AP_side_talents) exitWith {AP_paycheck = 1500};
    if (123 in AP_side_talents) exitWith {AP_paycheck = 1000};};
__SETCONST__(AP_paycheck, AP_paycheck); [{private _units = (player nearEntities[["CAManBase", "Car", "Air", "Ship"], 20]) select {
        isPlayer _x};
    _units = _units - [vehicle player];
    AP_tag_cache = AP_tag_units;
    AP_tag_units = _units;}, [], 1.3] call AP_fnc_addPerFrameHandler; [
    ["-INITPLAYER-", player, (profileName), format["initialised as %1 at %2", side player, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
(findDisplay 12 displayCtrl 51) ctrlAddEventHandler["Draw", {params["_control"];
    _control drawPolygon[AP_eviFencePoly, [0, 0, 1, 1]];}];
if (!isNull(findDisplay 17000)) then {closeDialog 0;};
"loadingScreen"
cutText["", "PLAIN"];
[] spawn AP_fnc_welcomeCredits;
// SECURITY boot assert (2026-09-26): another client's publicVariable replaces any missionNamespace global
// on this machine, so every code-typed one is compileFinal'd where it is defined. Name any that is not.
// 60 s: IgiLoad defines its helpers after a random wait of up to 30 s.
[] spawn {
    uiSleep 60;
    private _bad = (allVariables missionNamespace) select {
        private _v = missionNamespace getVariable _x;
        !isNil "_v" && {_v isEqualType {}} && {!isFinal _v} && {(_x select [0, 4]) isNotEqualTo "bis_"}
    };
    // Enforce, then report: our own helpers are sealed in place (b2042 found CfgFunctions' AP_fnc_guiMessage
    // non-final, cause unknown); only one that cannot be sealed is reported. bis_* is the engine's, not ours.
    { missionNamespace setVariable [_x, compileFinal (missionNamespace getVariable _x)]; } forEach _bad;
    _bad = _bad select { !isFinal (missionNamespace getVariable _x) };
    if (_bad isNotEqualTo []) then {
        diag_log format ["-SEC- BOOT ASSERT: %1 code global(s) not compileFinal: %2", count _bad, _bad];
        // subject objNull, not player: the reporter is the victim (another client's JIP publicVariable plants these),
        // and a player-subject -SEC- row is a clankr ban signal. logIt still stamps @SRC=<reporter uid>.
        [["-SEC-", objNull, format ["CLIENT BOOT ASSERT: %1 code global(s) not compileFinal: %2", count _bad, _bad select [0, 40]]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    };
};