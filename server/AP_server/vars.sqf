AP_gangbank_cap = 100000;
// Gang rename fee, charged to the GANG BANK by APS_fnc_gangRenameSRV (owner 2026-08-14:
// "build it, and charge for it"). Published so the deck's gang screen can price the
// button before the player commits; the server is what actually charges, so a client
// that rewrites its copy just gets a refusal.
AP_gangRenameFee = 50000;
publicVariable "AP_gangRenameFee";
AP_dispatchTasks = [];
AP_isRebooting = false;
AP_animals_spawned = false;
AP_animals_spawned_time = -500;
AP_animals_array = [];
AP_storage_array = [];
AP_configuration = [];
AP_dispatchUsers = [];
AP_restart_delay = 9000;
publicVariable "AP_restart_delay";
localNamespace setVariable ["AP_server_training", false];   // DB-writer kill switch; localNamespace + DB_fnc_flag so a client publicVariable cannot flip it
AP_server_instance = profileNamespace getVariable ["server_instance",1];
// SQL reads the instance from HERE, never from AP_server_instance: a client's publicVariable overwrites a
// missionNamespace global on the server too, and that one was formatted raw into ten statements (SQLi).
// localNamespace cannot be written over the network. Filled from the profile, never copied from the global.
localNamespace setVariable ["APS_serverInstance", profileNamespace getVariable ["server_instance",1]];
AP_server_port = -1;
AP_scanned_houses = [];
AP_server_gangs = [];
AP_server_gangs_queue = [];
AP_server_gang_groups = [];
AP_join_queue = [];
AP_dispatcher = objNull;
// srv_table_players/_wanted/_vehicles are GONE (their Australia/Stratis/Tanoa branches were dead on Malden):
// as plain globals any client could publicVariable srv_table_wanted = "players WHERE true --" and have the
// next wanted DELETE wipe the players table. Every statement names its table literally now; do not bring
// a table-name global back.
publicVariable "AP_dispatcher";
AP_dispatchWaypoints = [];
AP_capture_changed = [];
AP_capture_containers = [];
AP_lastWeather = [0,0,0,0];
AP_gang_banks = [];
AP_house_owners = []; 
// HC_UID / AP_HC removed 2026-07-24 with the dead headless-offload gate they fed. The live
// headless mechanism is AP_UsingHeadless (server/AP_server/server_init.sqf).
AP_wanted = 0;
// The wanted list and the re-jail list are server authority (index 3 is the arrest payout), so they live in
// localNamespace: a client publicVariable of a missionNamespace global overwrites it on the server too.
localNamespace setVariable ["APS_wantedList", []];   // [[name, uid, [chargeIDs], bounty, jailTime], ...] -- APS_fnc_wantedSyncList / wantedFetch
localNamespace setVariable ["APS_restrainedPlayers", []];   // uids to re-jail -- APS_fnc_setJail / claimBodybagSRV
localNamespace setVariable ["APS_bodybags", createHashMap];   // fugitive bag netId -> [uid, name, bounty, jail] (fn_playerDisconnected)
// uid-keyed server authority (audit 2026-09-26, mints2): an object var is client-writable published or not, so these
// are not on the player. AP_fab*Srv = fabrication level / xp / known schematics (DB_fnc_queryRequest fills them at
// login). AP_wreckLedger = "uid|plate" -> lower-case class of a vehicle whose row APS_fnc_vehicleDead really deleted;
// APS_fnc_recoverWreck re-inserts a missing row only against one of these. APS_gangOfUid = uid -> gang id (seeded by
// DB_fnc_queryRequest, kept by APS_fnc_updateGangMem, dropped on disconnect); gang-HQ storage and align: contracts gate on it.
{ localNamespace setVariable [_x, createHashMap] } forEach ["AP_fabLevelSrv", "AP_fabXpSrv", "AP_fabSchemSrv", "AP_wreckLedger", "APS_gangOfUid"];
AP_past_APB = [];
AP_coca_leaves = 0;
publicVariable "AP_coca_leaves";
AP_active_football = [];
AP_bank_funds = 10000;
AP_topWealth = [];
AP_trial_votes = 0;
// LooneyBin 2026-06-11: the 2020 client trial UI (fn_trialSystem) gates on SRV_trialData
// = [defendant, juryArr, _, proceeding, courtsBusy, deliberating, defName] plus SRV_trialPreviousDefenders,
// but the server NEVER initialized/published either -> every "Request Trial"/"Register for Jury" threw on
// `SRV_trialData select N`. Server owns + publishes them; fn_trialRequest / fn_trialBegin drive the phases.
SRV_trialData = [objNull,[],[],false,false,false,""];
publicVariable "SRV_trialData";
SRV_trialPreviousDefenders = [];
publicVariable "SRV_trialPreviousDefenders";
AP_laser_queue = [];
AP_laser_players = [];
AP_maxtac_instance = 0;
AP_activeMAXTAC = false;   // LooneyBin 2026-06-09: read by fedAlarm/maxtacDispatch/bankDrillVault/startPrisonBreak but NEVER initialized -> undefined-var error killed the MaxTac escalation thread the first time the fed alarm rang
// LooneyBin (bank drill): the client "Begin Drilling Vault" action condition reads AP_bank_robbed
// ([inProgress, lastEndTime]) and several feds read SRV_lastRobbery -- NEITHER was ever defined in this
// build, so the bank drill action never appeared and every "Security is high" cooldown errored.
// Server owns both; bankDrillVault/fedAlarm update + re-publicVariable them.
AP_bank_robbed = [false, -99999];
publicVariable "AP_bank_robbed";
SRV_lastRobbery = -99999;
publicVariable "SRV_lastRobbery";
// fed-reserve robbery state [inProgress, lastTime] -- read by the evidence-lockup bomb timer
// (fn_evidenceSystems case 2 adds +10min fuse when another fed is hot); maintained by fn_fedAlarm
AP_fed_robbed = [false, -99999];
publicVariable "AP_fed_robbed";
// LooneyBin Economy: live owner price overrides [[family,key,p0,p1,p2],...]; filled by economySRV "load"
AP_priceOv = [];
publicVariable "AP_priceOv";
AP_maxtac_deployed = false;
AP_maxtac_officers = [];
AP_maxtac_active = [];
AP_laser_inprogress = false;
AP_laser_group_blue = grpNull;
AP_laser_group_red = grpNull;
AP_animal_group = createGroup Civilian;
publicVariable "AP_laser_group_blue";
publicVariable "AP_laser_group_red";
publicVariable "AP_animal_group";
AP_laser_group1 = (createGroup civilian);
AP_laser_group2 = (createGroup civilian);
AP_lastPrison = -1000;
AP_active_turf = -1;
publicVariable "AP_lastPrison";
publicVariable "AP_active_turf";
AP_karaoke = "";
publicVariable "AP_karaoke";
AP_active_event = [];
publicVariable "AP_active_event";

localNamespace setVariable ["DB_Async_Active", false];   // the query mutex (fn_asyncQuery/fn_asyncExec); read via DB_fnc_flag

AP_capture_list = [["Arms Dealer", "0", 0, -2100, true, "AP_inv_dirty_money", 0],
["Drug Cartel", "0", 0, -2100, true, "AP_inv_dirty_money", 0], ["Oil Cartel", "0", 0, -2100, false, "AP_inv_rubber", 0],
["Wong Triad", "0", 0, -2100, false, "AP_inv_dirty_money", 0]];
AP_capture_old = AP_capture_list;
publicVariable "AP_capture_list";

AP_turf_list = switch (worldName) do {case "Altis": {[["Rodopoli", "0", "Contested"], ["Zaros", "0", "Contested"],
["Panagia", "0", "Contested"]];};
case "Tanoa": {[["Nandai", "0", "Contested"], ["Moddergat", "0", "Contested"], ["Lakatoro", "0", "Contested"]];};
case "Australia": {[["Tailem Bend", "0", "Contested"], ["Willcania", "0", "Contested"], ["Broken Hill", "0", "Contested"]];};
default {[];};};   // Armapunk 2035: no turfs on this map (see malden_cartels.sqf)
AP_capture_old = AP_turf_list;
publicVariable "AP_turf_list";

AP_last_broadcast = -3000;
publicVariable "AP_last_broadcast";

AP_trial_jury = [];
AP_trial_inprogress = false;
publicVariable "AP_trial_inprogress";

AP_bank_spawns = switch (worldName) do {
case "Stratis": { [[1609.52,5177.26,6.23029],[1609.62,5174.75,6.09425],[1604.09,5150.38,6.23029],[1603.93,5152.89,6.23029],[1660.5,5112.94,6.23029],[1656.51,5091.67,6.23029],[1654.33,5089.76,6.23029],[1595.9,5066.33,6.10311],[1594.33,5061.43,6.10311],[1589.67,5068.47,6.10311],[1588.56,5064.72,8.70311],[1567.81,5130.07,6.10311],[1565.93,5124.87,6.10311],[1560.04,5124.99,6.10311],[1563.54,5130.41,8.70311]] };
case "Altis": { [[16145.5,16948.9,13.9942],[16147.6,16947.3,13.9892],[16148.1,16949.4,13.8519],[16165.5,16970.3,13.8247],[16068.7,16912,14.0727],[16074.3,16913.8,16.5885],[16075.6,16919.3,14.0616],[16015.2,16960,14.4047],[16013.4,16958.5,14.4085],[16014.6,16957.1,14.2699],[16014.9,16959.9,14.4054],[16028.5,17047.5,14.0661],[16017.1,17028.2,16.5607],[16023.3,17022.9,13.9512],[16014.7,17062.3,13.9901],[16005.2,17031.9,14.1631],[16007.1,17037.9,14.1605],[16094.5,17083.4,14.21],[16091.5,17095,14.068],[16095.6,17073,14.2049],[16071.4,17088,14.2217],[16156.1,17042.3,14.1817],[16153.7,17044.6,14.0457],[16156.4,17041.2,14.1817],[16018.7,16853.1,14.9652],[16010.9,16854.5,17.5652]] };
case "Australia": { [[19732,24333,19.2],[19727,24339,21.7],[19778,24301,21.7],[19782,24296,19.2],[19901,24302,19.2],[19917,24287,19.2],[19973,24243,19.2],[19957,24258,19.2]] };
};
AP_prison_inProgress = false;
publicVariable "AP_prison_inProgress";
AP_bank_inProgress = false;
publicVariable "AP_bank_inProgress";
AP_bank_robbers = [];
publicVariable "AP_bank_robbers";

AP_race1 = 0;
AP_race2 = 0;
AP_race3 = 0;
AP_race4 = 0;
AP_race5 = 0;
publicVariable "AP_race1";
publicVariable "AP_race2";
publicVariable "AP_race3";
publicVariable "AP_race4";
publicVariable "AP_race5";
AP_racers = [[],[],[],[]];