class AP_Client_Core {tag = "AP";
 class Master_Directory {file = "core";
 class initCiv {};
 class setupActions {};
 class setupEVH {};
 class survival {};};
 class Duty { // faction rework: server-orchestrated duty shifts (everything behind AP_dutyEnabled)
 file = "core\duty";
 class dutyCfg {};      // AP_fnc_dutyCfg -- faction data table, pure data
 class dutyFlushBlock {}; // AP_fnc_dutyFlushBlock -- "" if a gear/position save will land, else the reason
 class dutyContext {};  // AP_fnc_dutyContext -- applies the current duty state (AP_effSide's first real writer)
 class dutyClient {};   // AP_fnc_dutyClient -- server -> client apply/remove (CfgRE allowedTargets = 1)
 class dutyTerminal {}; // AP_fnc_dutyTerminal -- HQ terminal action body, client pre-checks only
 class dutyGate {};     // AP_fnc_dutyGate -- "" or the refusal line: the terminal's client gates, shared with the landing screen
 class dutyRequest {};  // AP_fnc_dutyRequest -- send ["request",faction,role] and BLOCK until the grant/refusal can be attributed to it; "" = granted
 class dutyPayoff {};   // AP_fnc_dutyPayoff -- confirm + send ["payoff",faction] and BLOCK until the debit is confirmed; true = the bounty is settled
 };
 class LoonyBin115C {file = "core\session";
 class ClupdatePartial {};
 class ClupdateRequest {};
 class dataQuery {};
 class insertPlayerInfo {};
 class requestReceived {};
 class syncData {};
 class ndSync {}; // New Drachma: server -> client authoritative balance push
 class ndResult {}; // New Drachma: server -> client debit result (token continuation)
 };
 class Radio { // LooneyBin car radio (driver-controlled, shared: occupants say2D / bystanders say3D)
 file = "core\radio";
 class autoRadio {};
 class radioHud {};
 class radioKeys {};
 class radioRadial {};
 class radioListen {};
 class hudToast {}; // AP_fnc_hudToast -- generalised radio-card notification (core\radio\fn_hudToast.sqf)
 class toastDemo {}; // AP_fnc_toastDemo -- owner test trigger for the notification language
 class plbShopDemo {}; // AP_fnc_plbShopDemo -- PROOF: custom-PAA "real way" shop (core\radio\fn_plbShopDemo.sqf)
 class plbInvDemo {}; // AP_fnc_plbInvDemo -- PROOF: custom-PAA STRONGBOX inventory (core\radio\fn_plbInvDemo.sqf)
 };
 // owner 2026-06-23: SpyGlass anti-cheat REMOVED entirely (legacy/unmaintained, caused more issues than it
 // solved -- menuCheck false-positives nuked the display hierarchy on spawn). The WAC tamper-report sink it
 // shared was renamed WAC -> DONG (APS_fnc_dongClient) and kept. The 64 inert checkIntegrity guards were stripped.
 class Admin {file = "core\admin";
 class mapPrune {};   // AP_fnc_mapPrune -- level-5 "delete the map object I am looking at"; a REQUEST, the server decides
 class mapEditorCatalog {};  // AP_fnc_mapEditorCatalog -- placement browser built from Eden's own editorCategory/editorSubcategory config
 class mapEditor {};      // AP_fnc_mapEditor -- level-5 in-game editor session (toggle); freecam, selection, highlight
 class mapEditorInput {}; // AP_fnc_mapEditorInput -- camera, keys, modal grab
 class mapEditorOps {};   // AP_fnc_mapEditorOps -- defines the mutation helpers + axis gizmo; every edit is a REQUEST
 class mapEditorPanel {}; // AP_fnc_mapEditorPanel -- optional TAB panel: Eden's catalogue + exact numeric transforms
 class adminAddND {};
		class adminAddMoney {};
 class adminTeleportFacing {};
 class adminInfo {};
 class adminMenu {};
 class staffMenu {};   // picks the STAFF DECK or admin_menu.hpp from AP_webAdmin
 class adminMenuTabSwitch {};
 class adminQuery {};
 class adminTP {};
 class adminRevive {};
 class adminInvis {};
 class adminBulletCam {};
 class adminKick {};
 class adminBan {};
 class economyMenu {};
 class adminNewsBroadcast {};
 class adminMessage {};
 class adminJail {};
 class adminSetPos {};
 class adminGetPos {};
 class adminMode {};
 class adminGodmode {};
 class adminPlayerQuery {};
 class adminSpectate {};
 class srvCycAdjust {};
 class adminSpawnVehicle {};
 class adminRestrain {};
 class adminUnrestrain {};
 class unitRestrain {};
 class eventVehMarkers {};
 class adminCam {};
 class adminWeather {};
 class adminWeaponMenu {}; // ui branch: WEAPONS & GEAR tab -- spawn any weapon/mag/attachment (level >2, logged)
 class adminVehicleList {}; // ui branch: vehicle tab list -- curated sections + full-game search
 class adminClothingMenu {}; // ui branch: CLOTHING tab -- every uniform/vest/hat/goggles/backpack in the game
 class adminGearReceive {}; // target-side receiver for staff-menu gives (CfgRE-whitelisted; raw engine remoteExec is blocked)
 class adminSnowFX {};};
 class AdminSpectate {file = "core\adminSpectate";
 class spectateESP {};
 class spectateSettings {};};
 class SeasonalEvents {file = "core\seasonalEvents";
 class easterSeasonalEventCL {};
 class openChristmasTreePresentCL {};};
 class Bounty {file = "core\bounty";
 class dropBounty {};
 
 class removeBounty {};
 class requestBounty {};
 class trackBounty {};
 class setGroupMarker {};
 class trackAPB {};
 class bodybagMarker {};};
 class Medical_System {file = "core\medical";
 class acceptMedicalRequest {};
 class deathScreen {};
 class deathMedics {}; // the ONE eligible-responder rule: [online, nearest] -- 99999 nearest = none
 class deathUiOpen {}; // is a death screen up, native 7300 OR web 938800 -- six guards ask this
 class deathWebMedical {}; // request / allow for the web death screen: no engine confirm, timestamped cooldowns
 class doRespawn {};
 class requestMedicalConfirmation {};
 class medicRespondDone {};
 class medicLights {};
 class medicLoadout {};
 class medicMarkers {};
 class sendRequestToMedic {};
 class medicSiren {};
 class medicSirenLights {};
 class medicHexs {};
 class medicDeleteVeh {};
 class deathScreenMedicalButtonClick {};
 class respawned {};
 class revived {};
 class revivePlayer {};
 class loveBomb {};
 class loveBombHeal {};
 class reviveDrone {};
 class medicEarn {};
 class medSupplyEarn {};
 class setPain {};
 class painkillers {};
 class medicPartners {};
 class rehab {};
 class medicRepairBuilding {};
 class medicRespondMenu {};
 class medicFireClient {};};
 class Actions {file = "core\actions";
 class dragBody {};     // owner 2026-09-16: drag a dead player's body until they respawn
 class dragBodyStop {}; // idempotent release, every exit path
 class activateNitro {};
 class alcoholRecipes {};
 class arrestAction {};
 class bankToggleLighthouse {};
 class blindfoldAction {};
 class blindfoldClient {};
 class buyLicense {};
 class handleLicense {}; // AP_fnc_handleLicense -- ArmaQuest grantLicense's client-side applier (Task 6); CfgRE allowedTargets=1
 class catchFish {};
 class catchTurtle {};
 class ch7Broadcast {};
 class chopTree {};
 class glitterLab {};
 class closeMap {};
 class commitArsonClient {};
 class drillOil {};
 class dropFishingNet {};
 class dropOil {};
 class escortAction {};
 class evidenceVaultOpen {};
 class flip {};
 class fastRope {};       // AP_fnc_fastRope -- the roping client's descent
 class fastRopeRope {};   // AP_fnc_fastRopeRope -- ropes + doors, runs on the heli's owner; CfgRE allowedTargets=1
 class gather {};
 class gatherObject {};
 class gatherOil {};
 class gatherWater {};
 class getDPMission {};
 class finishDPMission {};
 class healHospital {};
 class holsterWeapon {};
 class lottoTix {};
 class medSupplyDestroy {};
 class mine {};
 class mineUranium {};
 class oilPump {};
 class openGate {};
 class prisonGate {};
 class openSafe {};
 class openVault {};
 class alamoFed {};
 class packupSpikes {};
 class pickupItem {};
 class pickupOil {};
 class placeOil {};
 class postBail {};
 class processAction {};
 class processVehicle {};
 class pulloutAction {};
 class pushVehicle {};
 class putInVeh {};
 class refillAmmo {};
 class repairTruck {};
 class restrainAction {};
 class robAction {};
 class babyOil {};
 class babyOilStrip {};
 class robStoreAction {};
 class searchAction {};
 class searchVehAction {};
 class searchWreck {};
 
 class serviceChopper {};
 class skinAnimal {};
 class stopBankRobbery {};
 class stopEscorting {};
 class storeVehicle {};
 class surrender {};
 class ticketAction {};
 class translateOil {};
 class treasureChestCreate {};
 class treasureMapOpen {};
 class turnedIn {};
 class unrestrain {};
 class useShank {};
 class evidenceSystems {};
 class fedRadarCharge {};
 class startConvoyRobbery {};
 class finishConvoyRobbery {};
 class moonshineLab {};
 class metalDetector {};
 class loonyBin {};
 class putInVehAction {};
 class jewelryEmporium {};
 class enterActiveTurf {};
 class campFire {};};
 class Intake {file = "core\intake";
 class intake {}; // owner 2026-07-11: THE INTAKE Act 1 -- new-player onboarding (wake in the Bin) // owner 2026-07-11: PAROLE PAPERS Act 2 -- 6-contract starter arc
 class mentor {}; // owner 2026-07-11: MENTOR PROGRAM Act 3 -- veterans adopt New Bloods, paid on graduation
 };
 class GPS { // owner 2026-07-12: road-graph GPS -- routing + map overlay (roadgraph_data.sqf generated by tools/roadgraph_build.py)
 file = "core\gps";
 class gpsInit {}; // lazy graph loader (nodes/edges/adjacency)
 class routeFind {}; // A* over the road graph -> route polyline
 class gps {}; // UI: ALT+MapClick set/clear, map Draw overlay, G-on-map search hook
 class gpsSearch {}; // destination search dialog (towns + named markers)
 class gpsHud {}; // turn-by-turn banner loop (reroute + arrival)
 class gpsAutopilot {};// TESLA MODE: scroll autopilot along the active route (driver-local)
 class hcDrive {}; // HEADLESS AUTOPILOT: drive a driverless veh to a dest, player-less, runs on the HC (any range)
 class hcShield {}; // collision shield (ignore impact/fire, let weapons through) -- shared by hcDrive + hcFly
 class isRotorcraft {}; // helicopter or VTOL (config-chain test) -- the one class gate every air autopilot path uses
 class flyStep {}; // ROTORCRAFT AUTOPILOT: one frame of flight, all state on the vehicle (seated player + HC share it)
 class hcFly {}; // HEADLESS ROTORCRAFT AUTOPILOT, scripted core: fly + land an EMPTY heli/VTOL (kinematic; the VTOL hand-over and fallbacks)
 class flyCruiseAlt {}; // cruise altitude ASL for a straight line: highest terrain OR object top + 80 m
 class flyLandSpot {}; // the clear landing spot NEAREST a target where the aircraft can take off again (rotor clearance, column above, no people/vehicles) -- both flight hosts
 class hcFlyAI {}; // HEADLESS ROTORCRAFT AUTOPILOT, engine-AI flavour: a real AI pilot flies it (real physics, smooth for observers) HEADLESS ROTORCRAFT AUTOPILOT: fly + land an empty heli/VTOL on the HC (sibling of hcDrive)
 class summonPoint {}; // SUMMON: pick the ~1 km spawn point (road for land, flat spot for air), client-side
 class summonSpawn {}; // SUMMON: materialise the starred row ~1 km out on the OWNER's client (prepareVehicle needs player)
 class summonState {}; // SUMMON: server -> client progress; pushes the deck's summon channel
 class hcReverse {}; // physics reverse (negative model-space velocity), raycast-guarded behind
 class hcTurnAround {};// 3-point turn to a target heading (forward/reverse arcs) -- cars with no reverse gear
 class hcDepart {}; // clean departure: reverse off the spot -> 3-point turn -> hand back to hcDrive to leave
 };
 class Housing {class miningRig {}; // install/collect house mining rig
class housePayTax {}; // pay house tax by index or all -- the native chain, dialog-free
 file = "core\housing";
 class buyHouse {};
 class getBuildingPositions {};
 class handleHouse {};
 class houseMenu {};
 class renameHouse {};
 class buyHelipad {}; // owner 2026-07-10: shed helipad upgrade purchase (house menu)
 class maldenPicker {}; // owner 2026-07-11: Malden Makeover skin picker (client half; 6 colors + off)
 class maldenSync {}; // owner 2026-07-11: swap-time client registry fix (AP_vehicles door-lock gate)
 class storageVault {}; // owner 2026-07-11: Storage Worker NPC -- vault dialog (pack/unpack)
 class storageVaultRecv {}; // owner 2026-07-11: server -> client vault panel push (CfgRE targets=1)
 class storageWorker {}; // owner 2026-07-11: Storage Worker NPC init hook (scroll action)
 class vaultClassLabel {}; // owner 2026-07-11: friendly house-class name for the vault UI
 class renameHouseDone {};
 class marketSellHouse {};
 class CLinitHouses {};
 class initKeyHouseMarkers {};
 class lightHouseAction {};
 class lightHouse {};
 class lockHouse {};
 class sellHouse {};
 class upgradeProperty {};
 class manageBldgKeys {};
 class listKeyHolders {};
 class keyHolderStatus {};
 class manageHouseTax {};};
 class Config {file = "core\config";
 class qhCfg {}; // quickhack catalogue (Tier 1)
 class eatFood {};
 class houseConfig {};
 
 class licenseCfg {};
 class maldenMap {}; // owner 2026-07-11: Malden Makeover class map (base <-> Argo variant; server reads it too)
 class prestigeCfg {};
 class talentCfg {};
 class factionCfg {};   // the four NPC factions -- FACTION_REP_SPEC.md
 class factionPerkCfg {};   // faction perks, gated on RELATIVE standing
 class timeTrialCfg {};
 class vehicleAnimate {};
 class vehicleTextures {};
 class tutorialCfg {};
 class vehicleConfig {};
 class ndPriceCfg {}; // New Drachma price override table (seeded 6000:1, hand-tunable)
 class virt_shops {};
 class virtItemCfg {};

 class cartelCfg {};
 class weaponAddons {};
 class clothingTextures {};
 class weaponShopCfg {};
 class vehicleSkinShopCfg {};
 class clothing_civ {};
 class clothing_barber {};
 class clothing_faces {};
 class clothing_cop {};
 class clothing_dive {};
 class clothing_kart {};
 class clothing_reb {};
 class clothing_copdive {};
 class clothing_med {};
 class recipeDetail {};
 class fabCfg {}; // 3D printer recipe + tuning tables (client renders, server validates from the same table)
 class fabFee {}; // recursive backbone-unit count -> schematic price in New Drachma
 class fabSchemCfg {}; // schematic acquisition: dropchance, sources, rarity
 class fabGen {};      // GENERATED catalogue block (scratchpad/gen_fab_catalogue.py)
 class fastRopeCfg {}; // fast-rope airframes, rope anchors and the hover envelope
 class parkourCfg {};  // parkour + wall-run tunables, animation tables
 class titleCfg {};
 class eventCfg {};
 class hornCfg {};
 class exchangeCfg {};
 class wantedChargesConfig {};
 class loginBonusCfg {};
 class sprayCanCfg {};
 class hexIconCfg {};
 class medicFireRelPositionsCfg {};
 class christmasTreePresentsCfg {};
 class welcomeUIConfig {};
 class vehicleModConfig;};
 class Player_Menu {file = "core\pmenu";
 class phoneGlobals {}; // the four always-present apps, shared by the native phone and the web deck rail
 class clientMessage {};
 class bonesText {}; // incoming Ben Bones AI text
 class offlineMsgRecv {}; // texts that arrived while this player was offline (one batch)
 class dropCharge {};
 class dropItem {};
 class giveItem {};
 class giveMoney {};
 class keyDrop {};
 class keyGive {};
 class pardon {};
 
 class brightNight {};

 
 
 class sendText {};
 class settingsInit {};
 class setWallpaper {};
 class updateMarkers {};
 class updateViewDistance {};
 class useItem {};
 class p_openLightSwitchBox {};};
 class WebUI_Mission {file = "core\web";   // mission-specific; the library lives in webui\
  class webBridgeOpen {}; // opens the harness dialog 937400, pushes live data
  class webProbe {}; // ExecJS payload ceiling, Deflate ratio, audio capability
  class webProbeOpen {}; // onLoad 937600 -- transparency rig
  class webProbeMulti {}; // onLoad 937610 -- how many browser controls run at once
 class canvasProbe {}; // onLoad 937620 -- canvas/WebGL viability for HTML5 games
 class casinoOpen {}; // dialog 930400 onLoad: bridge + casino verbs
 class casinoData {}; // one payload for the whole casino
 class casinoDiag {}; // why is the casino page deaf -- paints the answer on the page
 class casinoFit {}; // size a casino table to the safezone -- the page scales with the control
 class bjLedger {}; // blackjack money ledger: toggle
 class bjLedgerNote {}; // blackjack money ledger: one entry
 class deckFx {}; // A/B the phone's always-on chrome animation against Arma's fps
 class deckFps {}; // print the PAGE's own frame rate on the page -- raf/timer/css
 class deckSettings {}; // every native settings slot, as one payload
 class deckSettingsSet {}; // change one setting: apply live + persist to the right slot
 class webMap {}; // open MALDEN GRID from anywhere
 class mapOpen {}; // dialog 930430 onLoad: tiles + live push
 class mapDiag {}; // arm-first input probe: which events reach the map page
 class mapWpHud {}; // waypoint outside the map: Draw3D icon + live distance
 class armoryOpen {}; // dialog 930460: the HTML weapon shop
 class fittingOpen {}; // dialog 3100 web: FITTING ROOM bridge -- drives the native hidden controls
 class lootOpen {}; // LOOT CARD entry: the menu's guards, then the web card
 class lootBridge {}; // dialog 1530: LOOT CARD verbs over fn_pickupItem
 class visorOpen {}; // dialog 941700: the HTML visor -- quickhack plate stack (the native vr_dock it replaced was deleted 2026-09-04)
 class visorBridge {}; // visor verbs; casting goes out through AP_fnc_qhCast unchanged
 class deckNetlink {}; // NETLINK deck app (CTX_APPS "net"): TWATTER on APS_fnc_loonerSRV, EXCHANGE still sample data
 class carRadioOpen {}; // dialog 515600: the HTML car radio, alongside radialRadio 515500
 class carRadioBridge {}; // car-radio verbs over the existing AUTORADIO station chain
 class storageOpen {}; // dialog 938000: the HTML storage screen -- house + vehicle trunk, dual manifest
 class storageBridge {}; // storage verbs over AP_fnc_handleInv / calWeightDiff, never a new price path
 class landingOpen {}; // dialog 938100: the connect-time landing screen -- opened from fn_initCiv in place of the lobby welcome's PLAY gate
 class landingBridge {}; // dialog 938100 onLoad: landingReady / landingDeploy over the EXISTING APS_fnc_dutySRV request path
 class landingData {}; // one payload for the landing page: name/players/cap/build/loadPct + the three faction locks
 class spawnWebOpen {}; // dialog 938700: the 3D spawn screen -- takes the screen or declines to the native dialog 38500
 class spawnWebBridge {}; // dialog 938700 onLoad: spawnReady / spawnDeploy / spawnCancel over the EXISTING AP_fnc_spawnConfirm
 class spawnPointList {}; // one payload for the spawn page: every wake point with a POSITION and a reason ("" = usable)
 class deathWebOpen {}; // dialog 938800: the FLATLINED death screen -- takes the screen or declines to the native dialog 7300
 class deathWebBridge {}; // dialog 938800 onLoad: deathReady / deathRequest / deathAllow / deathRespawn
 class deathState {}; // one payload for the death page: both clocks, both cooldowns, responder, medic counts
 // CONNECT-TIME CACHE (ui\html\warm.html): the invisible RscTitles warmer became a reporting
 // worker, so the landing screen's loadPct is a real figure instead of a hardcoded 100. It never
 // gates PLAY -- the bar is informational and the cache keeps filling after DEPLOY closes the dialog.
 class warmBridge {}; // layer AP_map_warm (930450/930451): wire the warmer's progress channel, with a watchdog
 class warmProgress {}; // warm.html -> [pct, done, total]: clamp into AP_warmPct and refresh the landing bar
 class warmRepush {}; // push a fresh landing payload by idd, for callers that are not the landing's own bridge
 class warmCatalogue {}; // answer warm.html's "warmReady": every weapon-shop thumbnail path, at 128, pushed on "warmGuns"
 class dutyTermOpen {}; // dialog 938200: the MaxSec HQ tablet sign-on screen -- opened OFF duty; every failure falls back to AP_fnc_dutyTerminal's picker
 class dutyTermBridge {}; // dialog 938200 onLoad: dutyStart / dutyClose over the EXISTING APS_fnc_dutySRV request path, with the PAGE's role id
 class dutyTermData {}; // one payload for the duty terminal page: station + officer rank/scd + per-role on-duty counts
 class webServeRecv {}; // server -> client: deflated page markup for a webui page override
 class webServeInit {postInit = 1;}; // registers webui_serveFetcher; setting it is what enables serving
 class bjOpen {}; // dialog 930420 onLoad: DEALERBOT'S TABLE bridge + verbs
 class holdemOpen {}; // dialog 930422 onLoad: TEXAS HOLD'EM -- bind, register, subscribe as a viewer
 class holdemBridge {}; // hold'em verbs: hSit / hLeave / hAct, over APS_fnc_holdemSRV. Moves no money
 class hudWebInit {}; // layer AP_web_hud (938300): cut the STATUS HUD title layer, bridge it, keep it up. NOT a dialog -- a HUD must not take input
 class hudWebPush {}; // one { hp, h2o, food, wanted, paused, regen, map } push into the HUD page, gated on the payload having changed
 // HUD UI EDITOR (hudeditor.md): drag the status HUD's pieces where you want them, stored in
 // players_global.ui_layout. Never profileNamespace, and nothing here or on the server compiles
 // a stored value -- the layout is numbers only and is read with parseSimpleArray.
 class hudEdit {}; // entry point: cut the live layer, open dialog 938400
 class hudEditOpen {}; // dialog 938400 onLoad: bridge, synthetic payload, inject ui\html\hudedit.js, two verbs
 class hudEditClose {}; // dialog 938400 onUnload: clear the flag, let the keeper restore the layer
 class hudLayoutNorm {}; // anything -> a legal seven-pair layout. CLAMPS (the server's twin rejects)
 class hudLayoutApply {}; // build the transform stylesheet and ExecJS it into a bridged hud.html control
 class hudLayoutGet {}; // ask the server for this account's layout, throttled
 class hudLayoutRecv {}; // server -> client answer: cache it, wear it on the live layer
  class deckPhone {}; // CTRL+Y: open the HTML phone (dialog 937500)
  class deckOpen {}; // dialog 937500 onLoad: bridge + deck handlers + push loop
  class deckData {}; // builds one channel payload (phone/gang/keys/money) for deck.html
  class deckBank {}; // BANK app: payload + dep/wd/xfer verbs (ported native guards, param-taking)
  class deckExchange {}; // EXCHANGE app: browse/buy/retract/vault over APS_fnc_exchangeSystemSRV
  class deckFab {}; // FABRICATOR app: recipes/queue/collect/schematics over APS_fnc_fabSRV
  class deckGarage {}; // GARAGE app: rows to the parametrized pull/sell/repair/to-gang natives
  class deckSummon {}; // SUMMON VEHICLE app: state + go
  class deckTrunk {}; // TRUNK app: queue-and-commit over the parametrized take/store natives
  class deckVShop {}; // VEHICLE SHOP app: catalogue + configure; buy re-priced SQF-side
  class deckHouse {}; // HOUSE dashboard: instant verbs in-deck, confirm flows hand over
  class deckGang {}; // gang COMMAND verbs: bank/tag/leadership/wars over parametrized natives
  class deckChop {}; // CHOP SHOP + PAY-N-SPRAY: list + commit, prices re-derived from config
  class deckLoadouts {}; // ARMORY RACK: equip via parametrized native, save/del ported validation
  class deckSpray {}; // texture-grid picker: spray stencils + group hex, one component
  class deckIntake {}; // MAXSEC INTAKE: charge warrant + ticket over native protocols
  class deckMedic {}; // TT RESPONSE BOARD: dispatch rows + accept over the native request array
  class deckSuites {}; // LUXE SUITES: tower directory + lease/pay/end over APS_fnc_suiteSRV
  class deckDuel {}; // THE PIT: invite (ported escrow protocol) + accept via the native mode
  class deckBoot {}; // DAILY BONUS: streak + tier preview + claim via AP_fnc_loginBonusGive
  class deckRig {}; // RIG CONSOLE: extractor control + mine-target picker over APS_fnc_rigSRV
  class deckGangRequest {}; // ask APS_fnc_getGangInfo to refill AP_gangMembersList
  class deckPing {}; // short-lived local map ping for MARK / LOCATE
  class deckDiag {}; // ask the open phone to bisect its own chassis rendering cost
  class deckScale {}; // resize the browser control; the page's fit() rescales the chassis to match
 class deckQh {}; // ICEBREAKER OS / TAL OS payloads (loadout + live targets)
 class breachOpen {}; // dialog 937700: SEQUENCE BREACH
 class termOpen {};   // dialog 937800: TERMINAL BREACH // dialog 937700 onLoad: SEQUENCE BREACH page
 class deckOpenApp {}; // one door: any native surface -> the phone, on a named app
 class staffWire {}; // registers the staff verbs + roster push on a control (phone or fullscreen)
 class staffAct {};  // one router for every staff.html verb
 class shopOpen {}; // dialog 39600 onLoad: bridge + shop handlers
 class shopData {}; // one payload for every virtual shop
 class shopDiag {}; // RPT dump of a shop's computed prices + every modifier
 class deckQhResult {}; // server -> client: cast outcome, incl. the ICE firewall state
 class deckList {}; // the eight read-only list apps behind one payload
 class deckTree {}; // one payload for all six point-spend apps (talents/perks/honor/prestige/ng/infamy)
  class deckTreeAction {}; // toggle one node in those trees, and persist it (the dialogs sync on close)
 // owner 2026-09-05: aqDeckTrigger + aqDeckBootstrap are DELETED. Between them they armed six permanent
 // "Cyberdeck: Contact X" self-actions on the player at boot -- the only quest entries left on the scroll
 // wheel once the giver NPCs went. Their one job (choose a giver, call aq_fnc_openOffers) now lives in the
 // CONTRACTS picker below, inside the phone. No giver names the "deck" trigger (all six say "addAction"),
 // so unregistering that driver reaches nothing.
 class wearMatrix {}; // AP_fnc_wearMatrix -- PoC: the matrix page as a clothing skin (uniform + backpack), live for every viewer via uiTexLiveClient
 class uiTexLiveClient {}; // AP_fnc_uiTexLiveClient -- per-viewer: register an animated HTML texture with the cap manager (JIP)
 class htmlSkin {}; // AP_fnc_htmlSkin -- SPIKE: a server-streamed HTML skin on a vehicle (setObjectTextureGlobal uiEx string; page served per viewer)
 class htmlSkinClient {}; // AP_fnc_htmlSkinClient -- per-viewer: waits for the skin display, serves skins\<id>.html into it, freezes after first paint
 class uiTexManager {}; // AP_fnc_uiTexManager -- the ONE pump for live HTML textures, capped to the nearest AP_uiTexCap (20) objects; StopBrowser beyond the cap
 class uiTexBench {}; // AP_fnc_uiTexBench -- N local cars wearing live HTML textures, diag_fps before/during/after
 class skinStaticPump {}; // AP_fnc_skinStaticPump -- remoteExec'd to nearby clients: pumps displayUpdate on the broadcast static for N seconds
 class skinSwitch {}; // AP_fnc_skinSwitch -- PoC: 2 s of HTML static on the car, then a stock textureSources skin via BIS_fnc_initVehicle (car radio SKINS ring)
 class uiTexHolo {}; // AP_fnc_uiTexHolo -- PROOF OF CONCEPT 2: holographic HTML shell floating 1-2" off a car (dialog\uitex_holo.hpp, ui\html\holo.html)
 class uiTexMatrix {}; // AP_fnc_uiTexMatrix -- PROOF OF CONCEPT: paints ui\html\matrix.html onto a car via UI-on-texture (dialog\uitex_matrix.hpp). Owner debug-console call; see its header.
 class aqContracts {}; // AP_fnc_aqContracts -- the CONTRACTS picker (dialog\aq_contracts.hpp, AP_AqContracts idd 941800): lists every giver + "My Journal", hands the choice to aq_fnc_openOffers. The deck's "Quest Log" app opens it.
 class aqJournalOpen {}; // AP_fnc_aqJournalOpen -- Task 9: opens dialog\web_journal.hpp (AQ_Journal, idd 937900) via aq_fnc_journal's own ["open"] verb. Still the direct journal opener; the CONTRACTS picker's "My Journal" row calls the same aq_fnc_journal ["open"] verb.
 };
 class Phone {file = "core\phone";
 class loonerReceive {}; // Looner microblog: server pushes the feed to the client
 };
 class Casino {file = "core\casino";
 class casinoApp {}; // phone-app entry -> game-select landing
 class casinoBanConfirm {}; // self-exclusion confirm + apply (Settings "Casino Ban")
 class blackJack {}; // blackjack client controller + server "render" callback
 class blackJackReceive {}; // owner-2-gated BANK credit (server-initiated only)
 class bjTable {}; // server->client snapshot of the shared table
 class holdemReceive {}; // server->client PER-VIEWER hold'em snapshot (hole cards are yours alone)
 class holdemCash {}; // owner-2-gated BANK movement for hold'em -- SIGNED, the server orders both directions
 class casino {}; // client controller for Coin Flip/Wheel/Slots/Roulette/Hi-Lo + landing + server "result" render
 class casinoReceive {}; // owner-2-gated BANK credit for the five simple games (server-initiated only)
 };
 class Functions {file = "core\functions";
 class weaponAllMags {}; // every magazine a weapon accepts (staff menu + STAFF DECK weaponAcc)
 class accType {};
 class priceOv {};
 class marketFactor {};
 class achievementGrant {};
 class achievementScan {};
 class actionKeyHandler {};
 class actionUIHandler {};
 class adjustInventoryArray {};
 class autoRun {};
 class autoDrive {};
 class calWeight {};
 class calWeightDiff {};
 class dbNum {}; // one DB integer as a Number -- apdb types ints by MAGNITUDE (>16.7M arrive as strings)
 class clearVehicleAmmo {};
 class checkMailbox {};
 class clientWireTransfer {};
 class createLMarker {};
 class createVehicleLocal {};
class mapCfg {};        // mapdb: streaming constants (one definition, every machine)
class mapCellFor {};    // mapdb: (pos, stream_r) -> cell key
class mapCellsNear {};  // mapdb: cells within a radius of a position
class mapRowText {};    // mapdb: the one row serialiser (toFixed, never str/format for numbers)
class mapPlace {};      // mapdb: orientation -> world position -> scale, the one placement rule (fresh object or in-place move)
class spawnScatterCheck {};   // boot invariant: every town spawn scatter marker still stands a player on open ground
class nearTown {};      // the ONE list of town centres: "no <x> in town" rules ask this, not their own chain of getMarkerPos
 class mapLightAttach {}; // scripted, tunable light on a placed fixture (plaza floodlights) -- the reflector was far too bright
 class floodTune {}; // [brightness] in the console re-lights every scripted floodlight live
 class dropItems {};
 class mapPlaceable {}; // AP_fnc_mapPlaceable -- THE placeable-class rule; the server's authority calls this same one
 class mapEditApply {};      // AP_fnc_mapEditApply -- the ONLY writer of live map state (server broadcast + join replay)
 class mapEditRemoveId {};   // AP_fnc_mapEditRemoveId -- forget one row by id; marks it dirty for the tick
 class mapStream {};         // mapdb: init + tick loop (spawn from core/init.sqf)
 class mapStreamInit {};     // mapdb: per-machine state + the far-bucket request
 class mapTick {};           // mapdb: ONE tick -- the only creator/deleter of map objects on a client
 class mapFocus {};          // mapdb: where distance is measured from (respawn / suspect-ESP / override)
 class telemetryBeat {};     // telemetry: 10 s beat of five numbers to APS_fnc_telemetryBeat (players AND the HC)
 class mapCellRecv {};       // mapdb: a cell blob from the server (server-origin only; not in CfgRE)
 class mapIndexRecv {};      // mapdb: the server's cell index (self-test; server-origin only; not in CfgRE)
 class mapWaitLoaded {};     // mapdb: block until the cell under a position is in (fn_initCiv)
 class mapSelfTest {};       // AP_fnc_mapSelfTest -- headless-client self-test of the map runtime; dispatched by the mapselftest verb, reports via APS_fnc_logIt
 class dynamicMapVehicleFix {};
 class getDiscount {};
 class earthquakeClient {};
 class animSync {};
 class pushFunction {};
 class evidenceDefense {};
 class fedAirLock {};
 class gangBoatDefense {};
 class enableActions {};
 class slingAndMass {};
 class emote {};
 class fetchCfgDetails {};
 class maldenBullets {}; // owner 2026-07-11: heavy-caliber hit reporter for Malden Makeover shells (client sensor)
 class inputMenu {};
 class fetchDeadGear {};
 class fetchVehInfo {};
 class fireMissile {};
 class fetchWeaponMagazines {};
 class fixUniform {};
 class filterChat {};
 class profanityFilter {};
 class forceDropItem {};
 class isUnitCopilot {};
 class getRankString {};
 class giveDiff {};
 class giveGift {};
 class handleAnim {};
 class handleInv {};
 class handleItem {};
 class hudSetup {};
 class hudUpdate {};
 class index {};
 class initStats {};
 class inventoryDifference {};
 class jump {};
 class parkour {};      // owner 2026-09-16: V context move -- vault / mantle / drop / wall run (entry, key-handler called)
 class parkourProbe {}; // pure classifier: what the V key would do from here
 class parkourMove {};  // spawned mover: helper glide, sweeps, teardown
 class zoneCreator {};
 class cleanName {};
 class isNumber {};
 class isUIDActive {};
 class KRON_Strings {};
 class listNBoxSort {};
 class loadDeadGear {};
 class loadGear {};
 class nearestDoor {};
 class numberText {};
 class playerTags {};
 class ownerMode {};
 class invisBag {};
 class policeRequired {};
 class pullOutVeh {};
 class pushObject {};
 class radiationZone {};
 class receiveItem {};
 class receiveMoney {};
 class saveGear {};
 class setAggressive {};
 class setVehicleIdle {};
 class setTitle {};
 class setUnconscious {};
 
 class sideString {};
 class showBroadcast {};
 class simDisable {};
 class slingParachute {};
 class statArrUpdate {};
 class flushStats {}; // singleevh.md Phase 3a: durable stat-buffer flush (AP_fnc_flushStats)
 class stripDownPlayer {};
 class tacticalPing {};
 class tazeSound {};
 class trackMarkers {};
 
 class wantedListAdd {};
 class updateRemoteStat {};
 class uavCinematic {};
 class welcomeCredits {};
 class isAlphanumeric {};
 class directCall {};
 class notifyServerRestart {};
 class manageSidechat {};
 class calculateWarRating {};
 class handleChair {};
 class phoneCallClient {};
 class activeFederalEvent {};
 class lbScene {}; // Loony Bin heist: applies the scene to this client's LOCAL mapData props (see APS_fnc_loonyBinSRV)
 class inZone {};
 class dropPhysicalItem {};
 class getTitleColor {};
 class getDateUTC {};
 class formatContainer {};
 class applyRandomBillboardTexture {};
 class duelArenaSystem {};
 class clientMobileHQ {};};
 class gangfort {file = "core\gangfort";
 class initGangBoatClient;
 class gangBoatHud;
 };
 class quests {file = "core\quests";
 // task 11: the legacy quest catalogue and its dialog/sync/loot functions are
 // deleted (questSel/questAccept/questSync/questPlayerKilled/createQuestLoot).
 // handleQuest SURVIVES, gutted -- see its own header for why (Parole Papers
 // onboarding shares this chokepoint and is not part of the legacy system).
 class handleQuest {};
 // ArmaQuest profile (Task 6): preInit=1 so its nine AP_fnc_aq* globals exist
 // in missionNamespace before ArmaQuest's own preInit validation looks them
 // up by name (aq_content.hpp >> class AQ_Profile). This whole tag
 // (AP_Client_Core) is declared ahead of ArmaQuest's `aq` tag further down
 // this file, which is what makes that ordering hold -- see fn_aqProfile.sqf.
 class aqProfile {preInit = 1;};
 // Faction reputation, same preInit=1 and same reason: AQ_Profile names getRep
 // and addRep by string and the library's validation resolves them at preInit,
 // refusing to arm if either is missing. FACTION_REP_SPEC.md.
 class aqRep {preInit = 1;};
 // The client half of awardXp. NOT preInit: it is pushed by the server at payout
 // time, long after boot, and nothing resolves it by name during validation --
 // only AP_fnc_aqAwardXp (in aqProfile, which IS preInit) is named by AQ_Profile.
 class aqAwardXpClient {};
 class aqWorld {};};
 class FactionWorld {file = "core\functions";
  // Territory containment. Lives beside the other core helpers rather than in
  // core\config, because it caches and the config functions deliberately do not.
  class factionTerritory {};
  // The engagement-rules layer. factionHostile is called per rendered unit per
  // frame by fn_playerTags, which is why almost all of its work is done once per
  // 3s tick by factionBanner and left in AP_warHere / AP_myFaction.
  class factionHostile {};
  class factionBanner {};};
 class FactionTalents {file = "core\talents";
  class calFactionTalents {};   // standing -> perk points (FACTION_REP_SPEC.md)
  class hasFactionPerk {};};
 class Network {file = "core\functions\network";
 class botKick {};
 class broadcast {};
 class corpse {};
 class MP {};
 class netSetVar {};
 class setFuel {};
 class setTexture {};
 class soundDevice {};
 class playSound {};
 };
 class Civilian {file = "core\civilian";
 class addInfamy {};
 class civLoadout {};
 class craftRecipe {};
 class doPrisonBreak {};
 class airplaneDrugRunner {};
 class execute {};
 class factory {};
 class jailPlayer {};
 class jailMe {};
 class policeRecruit {};
 class removeLicenses {};
 class robPerson {};
 class robReceive {};
 class skyDive {};
 class cookMeat {};
 class laserJoin {};
 class initLaser {};
 class civRepairBuilding {};
 class ufoCrash {};
 class trialSystem {};
 class harvestScalp {};
 class tutorialNewPlayer {};
 class loginBonusInit {};
 class loginBonusGive {};
 class executionerMove {};
 class timeTrial {};
 class passiveMode {};};
 class Vehicle {file = "core\vehicle";
 class avClient {}; // LUXE AV passenger actions (fly-to preset pads, door); server does the flying (APS_fnc_avSRV)
 class addVehicle2Chain {};
 class colorVehicle {};
 class openVehDoors {};
 class deviceMine {};
 class handleVehicles {};
 class lockVehicle {};
 class removeVehKey {};
 class vehicleOwners {};
 class vehicleWeight {}; class rigClient {}; // resource extractor/processor visuals: client-local parts + animation
 class vInteractionMenu {};
 class horn {};
 class prepareVehicle {};
 class refuelVehicle {};
 class tractorMine {};
 class checkPlate {};
 class forceVehicleEnter {};};
 class Inventory {file = "core\inventory";
 class openInventory {};
 class refreshInventory {};
 class storeInventory {};
 class takeInventory {}; class trunkCloseSettle {}; // shared close-persist choreography (dialog + deck sessions)
 class physicalInventoryWeight {};
 class physTally {};   // the player's physical gear as [[class, qty], ...] -- the set fn_refreshInventory paints, shared so a _deckMax ceiling matches the mover
 class moveItemInventory {};
 class refreshAdminInventory {};
 class dropTrunkInventory {};
 class dropPlayerInventory {};
 class vehSwapItem {};
 class houseToVehicleStore {};
 class vehicleToHouseStore {};
 // the I-screen (dialog 938500, ui\html\inventory.html) -- INVENTORY_SPEC.md §9
 class invOpen {};       // entry from fn_inventoryOpened: reserve the container, createDialog
 class invBridge {};     // dialog onLoad: bridge, geometry, verbs, watcher, cleanup
 class invSnapshot {};   // the `inventory` push
 class invItemInfo {};   // per-class name/icon/mass/kind, cached
 class invCargoRead {};  // a container's cargo as rows with deterministic ids
 class invLocal {};      // own-body moves: move / equip / unequip / swapWorn / spill
 class invGunsmith {};   // GUNSMITH: open / mount / detach / unload / reload / close
 class invCommit {};     // after every mutation: Take/Put replication, saveGear, re-push
 class invCargoRecv {};  // server verdicts for APS_fnc_invCargo tickets (allowedTargets=1)
 class invFigure {};     // the WORN figure as a render-to-texture camera on the player's body (native picture over the page)
};
 class Cop {file = "core\cop";
 class talAction {}; // TAL OS wedge dispatcher (MaxSec visor ring) -- talos.md
 class talTrace {}; // ICE TRACE ping receiver (passive -- no wedge)
 class talMarker {}; // TAL dispatch pin / backup beacon (local marker)
 class talFieldReply {}; // runs on the SUSPECT: returns breathalyser/drug screen
 class talLog {}; // TAL audit trail -> APS_fnc_logIt
 class addPrestige {};
 class applyCharge {};
 class bountyReceive {};
 class copSplitReceive {};

 class copInteractionMenu {};
 class copLights {};
 class copLoadout {};
 class copSearch {};
 class copSiren {};
 class crimeCharge {};
 class selfCharge {};
 class copUAV {};
 class scdGear {};
 class maxtacEnroll {};
 
 class disarmed {};
 class disarmAction {};
 class removeFiringPin {};
 class breakGuns {};
 class fixFiringPin {};
 class earnPrestige {};
 class doorAnimate {};
 class impoundAction {};
 class jailCL {};
 class licenseCheck {};
 class licensesRead {};
 class nonLethal {};
 class radar {};
 class reGear {};
 class repairDoor {};
 class restrain {};
 class revokeLicense {};
 class revokeLicenseAction {};
 class searchClient {};
 class seizePlayerIllegal {};
 class seizePlayerIllegalAction {};
 class seizeToVehicle {};
 class seizeIllegalTent {};
 class seizeObjects {};
 class sirenLights {};
 class speedCamera {};
 class trafficCams {};
 class spikeStripEffect {};
 class stopPrisonBreak {};
 class ticketGive {};
 class ticketPaid {};
 class ticketPay {};
 class ticketPrompt {};
 class vehBaseSeize {};
 class houseInvSearch {};
 class houseInvSeize {};
 class vehicleInvSearch {};
 class vehicleInvSeize {};
 class giveMedkits {};
 class requestBackup {};
 class requestSuperior {};
 class dispatchClientMessage {};
 class toggleMaxTacLights {};};
 class Gangs {file = "core\gangs";
 class createGang {};
 class gangInviteMenu {};
 class cartelEventCapture {};
 class gangCreated {};
 class gangMenu {};
 class initGang {};
 class setGangGrpLdr {};
 class setGangHouse {};
 class populateGangInfo {};
 class invite2Gang {};
 class gangRename {};    // deck gang screen -> APS_fnc_gangRenameSRV (leader only, gang-bank fee)
 class gangRenamed {};   // server -> every online member after a rename commits
 class captureCartel {};
 class getCartelRubber {};

 class cartelGrant {};
 class gangRanks {};
 class clientGangLeader {};
 class gangDisbanded {};
 class gangDisband {};
 class gangInvite {};
 class gangKick {};
 class gangLeave {};
 class gangNewLeader {};
 class getOnlineMembers {};
 class manageRank {};
 class removeGangHouse {};
 class captureTurf {};
 class acceptWar {};
 class gangWarsMenu {};
 class warStatus {};
 class gangWarsMenuLBChange {};
 class warChallenged {};
 class surrenderWar {};
 class challengeWar {};
 class changeGangHouse {};
 class setGangHouseForMembers {};
 class gangSetOwner {};
 class gangTransferOwner {};
 class setGangTag {};
 class gangGarageAdd {};
 class gangGarageLBChange {};
 class gangGarageMenu {};
 class gangGaragePull {};
 class gangGarageRepairRefuel {};
 class gangGarageDestroy {};
 class captureGangBoatFlag {};};
 class Gov {file = "core\gov";
 class getGovTax {};
 class govCandidateMenu {};
 class govLawMenu {};
 class govVotingMenu {};
 class govSystem {};
 class govPardon {};
 class govBank {};
 class govBankWithdraw {};};
 class AP_Groups12 {file = "core\groups";
 class groupMenu {};
 class groupBrowser {};
 class createGroup {};
 class groupManagement {};
 class clientGroupKick {};
 class clientGroupLeader {};
 class joinGroup {};
 class kickGroup {};
 class leaveGroup {};
 class lockGroup {};
 class setGroupLeader {};
 class unlockGroup {};
 class setGroupPass {};
 class setGroupRestrainMarker {};};
 class Shops {file = "core\shops";
 class atmMenu {};
 class gangAtmMenu {};
 class buyClothes {};
 class changeClothes {};
 class changeVision {};
 class chopShopClaim {};
 class chopShopMenu {};
 class chopShopSelection {};
 class chopShopSell {};
 class clothingFilter {};
 class clothingMenu {};
 
 class simpleShopBuySell {};
 class simpleShopSelection {};
 class vehicleSkinShopMenu;
 class vehicleSkinShopBuy {};
 class vehicleSkinShopSelection {};
 class vehicleShopBuy {};
 class vehicleShopLBChange {};
 class vehicleShopMenu {};
 class virtualShopManage {};
 class sellVehicleInv {};
 class virtualShopMenu {};
 class virtualShopUpdate {};
 class virtualShopPopulate {};
 class virtShopPrice {}; // ONE copy of the virtual-shop buy price chain
 class virtShopSellPrice {}; // ONE copy of the sell chain, anti-arbitrage guards included
 class ncShop {}; // AP_fnc_ncShop -- NIGHT CITY weapon shop (ui branch; rebelwep routes here)
 class vehicleShopMods {}; // ui branch: fill the vehicle-shop buy-time configure grid
 class vehicleShopTotal {}; // ui branch: recompute the vehicle-shop TOTAL readout
 class weaponShopBuy {};
 class weaponShopFilter {};
 class weaponShopMenu {};
 class weaponShopSelection {};};
 class Loadout {file = "core\shops\loadouts";
 class chooseLoadoutCurrency {};
 class deleteLoadout {};
 class equipLoadout {};
 class getLoadoutItems {};
 class getLoadoutPrice {};
 class getVirtualInv {};
 class loadoutMenu {};
 class loadoutPreview {};
 class loadoutSelection {};
 class saveLoadout {};};
 class Talents {file = "core\talents";
 class buyTalentPoint {}; // purchase an extra talent point ($1m, +$500k each) past the free cap
 class talentPointsRecv {}; // server -> client: purchased-point count (login + after each buy)
 class addExperience {};
 class populatePrestigeTree {};
 class populateTalentTree {};
 class calGangTalents {};
 class calTalents {};
 class learnPrestige {};
 class learnTalent {};
 class prestigeInfo {};
 class respec {};
 class talentInfo {};
 class verifyTalents {};};
 class Tutorials {file = "core\tutorial";
 
 class tutorialSel {};
 class tutorialStart {};
 class handleTutorial {};};
 class Suites {file = "core\suites";   // Luxe Suites -- leased lux-tower floors (suites.md)
    class suiteData {};        // shared identity + geometry helpers (AP_fnc_suite*)
    class suiteKiosk {};       // lobby directory dialog
    class suiteKioskArt {};    // bakes the welcome panel onto the kiosk screen
    class suitePresence {};    // asks the server to spawn this tenant's furniture
    class suiteMenu {};        // tenant's three-action menu
    class suiteReceive {};     // server -> client row push
    class suiteDoorSync {};    // front-door lock state
    class suiteEvicted {};    // lease-ended notice
    class suiteRentNotice {};  // rent paid / overdue toast
    class suiteStorage {};    // suite storage: drives the house TrunkMenu UI
    class suiteStorageSync {}; // persist the open suite crate on every take/store
    class suiteStorageRecv {};};// server -> client storage payload
 class Items {file = "core\items";
 // 3D printer / Fabricator. fabModel + fabReceive + fabGiveGear are server->client callbacks and
 // also need CfgRE entries; the rest are local-only.
 class fabMenu {};
 class fabMenuFill {};
 class fabJobFill {};
 class fabLBChange {};
 class fabQueue {};
 class fabMode {};
 class fabBurn {};
 class fabCollect {};
 class fabNear {};
 class fabModel {};
 class fabModelClear {};
 class fabAnim {};        // F770: move the parts while it prints (client-local, started by fabModel)
 class fabReceive {};
 class fabGiveGear {};
 class fabQuestEvent {};
 class adrenalineShot {};
 class supermale {};
 class miningAssemble {}; // build a mining rig from components
 class grabComponent {}; // grab a crypto component from an event crate // Super Male Vitality supplement (sprint + damage-resist buff)
 class adrenalineShotEffect {};
 class alarm {};
 class bloodbag {};
 class boltcutter {};
 class recoverWreck {};
 class debitCard {};
 class applyAtmSkimmer {}; // plant a $50k ATM skimmer on the physical ATM you're facing (fn_atmSkimSRV backend)
 class atmSkimOwner {}; // owner UID of the skimmer on an ATM (reads synced AP_atmSkim by position)
 class jerryRefuel {};
 class lockpick {};
 class cyberdeck {}; // LooneyBin 2026-07-18: Cyberdeck launcher (replaces lockpick+drill)
 class cyberdeckSeq {}; // Sequence Breach minigame controller (blocking)
 class cyberdeckTerm {}; // Terminal Breach minigame controller (blocking)
 class cyberdeckSubmit {}; // Terminal Breach ENTER handler
 class cyberdeckIgnition {}; // Hack Ignition -- temp engine-fry on any vehicle (cdfeatures #3)
 class cyberdeckATM {}; // ATM jackpot hack (cdfeatures #2)
 class cyberdeckWardrive {}; // Wardrive scan -- ping nearby hackable targets (cdfeatures #8)
 class cyberdeckLaunch {}; // Home-menu hack dispatcher
 class cyberdeckBuyModule {};
 class qhRecycle {}; // Chip Recycler: melt 3 hack chips -> 1 random Tier-3 chip (Kabuki scroll)
 class cyberdeckBank {}; // Bank Vault hack (home-menu entry, mirrors the scroll action)
 class qhCast {}; // quickhack caster -- validate + hand off to APS_fnc_qhSRV
 class qhEffect {}; // quickhack victim-side effect + trace-window arm
 class qhTrace {}; // victim trace-back (scroll action inside the 10s window)
 class qhTraceResult {}; // trace outcome (server -> both parties)
 class qhPing {}; // server-streamed ping/pursuit map marker
 class qhEyeSpy {}; // Eye Spy CCTV feed viewer (server picks the camera -> client renders it)
 class qhEngineKill {}; // setHit an engine on the vehicle's OWNER (occupied cars are driver-local)
 class qhChauffeur {}; // Chauffeur Override victim-side drive + wrestle/kill-switch/bail controller
 class qhPuppet {}; // Puppet Strings hacker-side deck-dive: slump body + capture/publish input
 class qhCuffHack {}; // Cuff Cracker: sequence-breach your own restraints (SHIFT+Y while cuffed)
 class openGift {};
 class nitro {};
 class redgull {};
 class spikeStrip {};
 class speedbomb {};
 class vehAmmo {};
 class pickupObject {};
 class tent {};
 class placeObject {};
 class holdObject {};
 class furnitureAction {};
 class tracker {};
 class protest {};
 class medKit {};
 class ignitionBomb {};
 class boomBox {};
 class sprayPaint {};
 class remoteExplosive {};
 class remoteEngineKillSwitch {};};
 class exchange {file = "core\exchange";
 class exchangeMenu {};
 class exchangeMenuFilter {};
 class exchangeMenuManage {};
 class exchangeMenuSelection {};
 class exchangeStorageMenu {};
 class exchangeStorageMenuFilter {};
 class exchangeStorageMenuManage {};
 class exchangeStorageMenuSelection {};
 class exchangeCreateListing {};};
 class Dialog_Controls {file = "dialog\function";
 class adminEventMenuLB {};
 class animateDialog {};
  class bankDeposit {};
 class bankTransfer {};
 class bankWithdraw {};
 class gangBankHist {};
 class gangDeposit {};
 class gangWithdraw {};
 class createDialog {};
 class createMessage {};
 class deleteMessage {};
 class displayHandler {};
 class doubleClickItem {};
 class factoryLBChange {};
 
 class handleMessage {};
 class initMessageHUD {};
 class insertElement {};
 class pickupSelected {};
 class menuPickupItems {};
 class prisonBreakQuery {};
 class setMapPosition {};
 class spawnConfirm {};
 class statsMenu {};
 class statsFilter {};
 class spawnMenu {};
 class spawnPointCfg {};
 class spawnPointSelected {};
 class vehicleGarageLBChange {};
 class vehicleGarageMenu {};
 class vehicleGaragePull {};
 class vehicleGarageSell {};
 class deathCamera {};
 class redeployMenu {};
 class garageModMenu {};
 class garageBuyMods {};
 class vehicleGarageRepairRefuel {};
 class guiMessage {};
 class serverInfoMessages {};
 class gangBankTransfer {};
 class sprayPaintMenu {};
 class coloredHexes {};
 class coloredHexesMenu {};
 class titleColorMenu {};
 class ctrlCreate {};
 class loadingScreen {};
 class welcomeUI {};
 class garageModComboChange {};};
 class LoonyBin_EVH {file = "evh";
 class getInMan {};
 class getOutMan {};
 class handleDamage {};
 class handleDowned {};
 class handleVehicleDamage {};
 class handleTagged {};
 class inventoryClosed {};
 class inventoryOpened {};
 class onFired {};
 class onPlayerKilled {};
 class suicideVest {};
 class forceRagDoll {};
 class handleFlashbang {};
 class mouseDownHandler {};
 class mouseUpHandler {};
 class onPlayerRespawn {};
 class onTakeItem {};
 class onPutItem {};
 class seatSwitchedMan {};
 class onGameInterrupt {};
 class keyDownHandler {};
 class keyUpHandler {};
 class handleChatMessage {};};
 class LoonyBin_OEF {file = "evh\eachFrame";
 class addPerFrameHandler {};
 class onEachFrame {};
 class removePerFrameHandler {};};
 class AdminEvents {file = "core\adminEvents";
 class adminEventMenu {};
 class eventGunGameClient {};
 class funGunClient {}; // owner admin-menu fun guns (server->client effect)
 class eventGunGameKill {};
 class eventBRClient {};
 class eventGraveyardClient {};
 class eventPurgeClient {};
 class eventGridrunnerClient {};
 class handleAdminEvent {};};
 class drugs {file = "core\drugs";
 class attachSmoke {};
 class glitter {};
 class drugUsed {};
 class blackLace {};
 class smash {};
 class overdose {};
 class drinkAlcohol {};
 class cannabisItems {};
 class greenhouse {};
 class barrel {};
 class healBlocked {};}};
class NPC_Core {tag = "NPC";
 class animation {file = "npcs\animation";
 };
 class NPCs {file = "npcs";
 class applyCop {};
 
 class CH7 {};
 class chopshop {};
 
 class civDMV {};
 class civDrugRunner {};
 class civFactory {};
 class civHuntingWeapon {};
 class civProcessItem {};
 class civRebelVehicles {};
 class civRebelWeapon {};
 class civSkiptracer {};
 class civTurfShops {};
 class civTurfVehicles {};
 class civTurfDealer {};
 class civVehicles {};
 class nearSpawns {};
 class civTimeTrials {};
 class clinics {};
 class copGetBounty {};
 class copShops {};
 class copVehicles {};
 class courthouse {};
 class duelArena {};
 class gasStations {};
 class governor {};
 class missionDP {};
 class medVehicles {};
 class prison {};
 class shops {};
 class vendShop {}; // NPC_fnc_vendShop -- wires one vending machine to the shop on its sign; called from the machine's own map_objects row init
 class tourism {};
 class civConvoy {};
 class civExchange {};
 class civJewelry {};
 };};
class ChatcomFiles {tag = RWT;
 class chatcom {file = "core\chatcom\chatfuncs";
 class chatcomExec {};
 class chatcomProcess {};
 class chatcomVerify {};};};
	class LooneyBin_Compat {tag = "AP";
 class Compat {file = "core\compat";
 // reverse-drift: mission callbacks the 2017 server calls (2020 renamed/removed)
 class GEMenu {};
 class addStatistic {};
 class addToGang {};
 class applyWeather {};
 class battlEyeReceive {};
 class calcPrice {};
 class candidate {};
 class candidates {};
 class capNotice {};
 class createDispatch {};
 class createVehicle {};
 class finishDispatch {};
 class forceJoinGroup {};
 class gangBank {};
 class gangMembersReceive {};
 class getBuildID {};
 class getQuantity {};
 class itemDemand {};
 class jackpot {};
 class jailSys {};
 class joinRace {};
 class localChatMessage {};
 class newDispatch {};
 class newWaypoint {};
 class playKaraoke {};
 class prisonBreaker {};
 class raceWon {};
 class receiveOwner {};
 class reqsync {};
 class setBounty {};
 class setRestrained {};
 class setReturnValue {};
 class startPrisonBreak {};
 class startRace {};
 class maxtacDeactivate {};
 class maxtacDispatch {};
 class maxtacDispatched {};
 class trialBegin {};
 class uC {};
 class vehicleColorCfg {};
 class vehicleExit {};
 class wantedPardon {};
 class wantedPerson {};};};

// arma-webui. This must sit OUTSIDE class AP_Client_Core: Functions.h is the
// body of CfgFunctions, so a tag nested inside another tag turns its categories
// into functions whose `file` is a directory -- the engine then reports
// "Script webui\functions not found" once per attempt.
#include "webui\config\CfgFunctions.hpp"

// ArmaQuest. Must sit OUTSIDE class AP_Client_Core for the same reason the
// arma-webui include above does: CfgFunctions resolves a file path relative to
// the enclosing class, so nested one level too deep every function fails to
// compile with "Script ArmaQuest\functions not found", once per attempt.
#include "ArmaQuest\config\CfgFunctions.hpp"
