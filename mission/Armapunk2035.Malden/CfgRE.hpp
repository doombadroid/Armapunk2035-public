class Functions {mode = 1;
    jip = 0;

    //class BIS_fnc_debugConsoleExec {allowedTargets = 2;};

    // allowedTargets limits a call's TARGET, never its SENDER: a client may remoteExec any
    // allowedTargets = 1 entry at any other client. A server -> client receiver therefore opens with
    // `if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};` and is listed in
    // tools/cfgre_server_only.txt, which tools/cfgre_origin_check.py (run_checks.sh) enforces.

    // Map streamer receivers (server -> clients). Kept WHITELISTED: every map row/cell reaches players through
    // these, and the repo has only ever run them listed (BIKI is ambiguous on whether a server-originated call
    // needs the entry). Listing does not reopen the audit 2026-09-26 hole: rows carry init CODE, so each
    // receiver drops a remoteExec whose remoteExecutedOwner is not 2 (tools/cfgre_server_only.txt,
    // enforced by cfgre_origin_check.py), and the row stores live in localNamespace.
    class AP_fnc_mapEditApply {allowedTargets = 1;};
    class AP_fnc_mapSelfTest {allowedTargets = 1;};
    class AP_fnc_mapCellRecv {allowedTargets = 1;};
    class AP_fnc_mapIndexRecv {allowedTargets = 1;};
    // mapdb: the client asks for map cells (read-only); the server answers the requester
    // alone, resolved from remoteExecutedOwner.
    class APS_fnc_mapFetch {allowedTargets = 2;};
    // Live map editor: client -> server REQUEST only. The server derives the caller from
    // remoteExecutedOwner, re-reads adminlevel from the database, refuses any class outside
    // the inert-geometry allowlist, and never accepts an init string -- so the payload
    // carries nothing that grants anything.
    class APS_fnc_mapEditSRV {allowedTargets = 2;};
    // Telemetry: client -> server beat of five clamped numbers (fps, fps min, view distance,
    // nearby count, in-vehicle). Identity comes from remoteExecutedOwner; the payload grants nothing.
    class APS_fnc_telemetryBeat {allowedTargets = 2;};
    class APS_fnc_telemetryProfile {allowedTargets = 2;};   // once per session: resolution/fov/build/branch/language, sanitised server-side

    class AP_fnc_colorVehicle {allowedTargets = 0;};
    class AP_fnc_openVehDoors {allowedTargets = 0;};
    class AP_fnc_breakGuns {allowedTargets = 0;};
    class AP_fnc_corpse {allowedTargets = 0;};
    class AP_fnc_lockVehicle {allowedTargets = 0;};
    class AP_fnc_setTexture {allowedTargets = 0;};
    class AP_fnc_simDisable {allowedTargets = 0;};

    class AP_fnc_cartelGrant {allowedTargets = 1;};        // server -> the collecting client

    class AP_fnc_fedAirLock {allowedTargets = 1;};        // server -> the pilot it is about to shoot
    class AP_fnc_lbScene {allowedTargets = 1;};           // server -> every client, Loony Bin scene state (takes no args)
    class APS_fnc_fedRadarSRV {allowedTargets = 2;};        // client -> server, footing index only (server re-validates)
    class APS_fnc_maldenFedSRV {allowedTargets = 2;};      // client -> server request only; the server re-checks caller, distance and phase
    class APS_fnc_prisonGateSRV {allowedTargets = 2;};   // client -> server, bare mode string only; the server re-checks caller, side and distance

    // Faction rework duty framework. The client may only ASK; APS_fnc_dutySRV derives the caller from
    // remoteExecutedOwner and re-reads the whitelist from the database, so the request carries nothing the
    // server trusts. The reverse direction is server-only: a client that could call AP_fnc_dutyClient
    // would grant itself a side switch and a MaxSec loadout, so it stays allowedTargets = 1.
    class APS_fnc_dutySRV {allowedTargets = 2;};             // client -> server, request/ack/release only
    class APS_fnc_preSpawnPos {allowedTargets = 2;};
    class APS_fnc_adminNdSRV {allowedTargets = 2;};         // client -> server, staff ND grant; caller from remoteExecutedOwner, level re-checked server-side         // client -> server, own-unit only (owner check inside): pre-position the networked copy before a spawn release
    class AP_fnc_dutyClient {allowedTargets = 1;};           // server -> the one client being swapped

    class APS_fnc_cartelCollectSRV {allowedTargets = 2;};    // client -> server, ID only

    class APS_fnc_cartelReturnSRV {allowedTargets = 2;};     // client -> server, overflow back
    class AP_fnc_vehicleAnimate {allowedTargets = 0;};
    
    // LAUNCH (launch.md #3, 2026-06-13): BIS_fnc_debugConsoleExec REMOVED from the whitelist. mode=1 means
    // anything not listed cannot be remoteExec'd, so this closes the arbitrary-code RCE (a client could
    // remoteExec it at the server and run any code). Admins still use the debug console LOCALLY (no RE needed).
    class AP_fnc_addVehicle2Chain {allowedTargets = 1;};
    class AP_fnc_ndSync {          // New Drachma: server pushes authoritative balance
        allowedTargets = 1;};
    class AP_fnc_ndResult {        // New Drachma: server pushes debit result
        allowedTargets = 1;};
    // Luxe Suites (suites.md): server -> client only. allowedTargets = 1 limits the
    // TARGET, not the sender, so it does not stop a client faking a lease row or
    // unlocking a door on every machine: each receiver refuses a non-server
    // remoteExecutedOwner itself (tools/cfgre_server_only.txt).
    class AP_fnc_suiteReceive {    // suite directory / row updates / refusals
        allowedTargets = 1;};
    class AP_fnc_suiteDoorSync {   // front-door lock state for one floor
        allowedTargets = 1;};
    class AP_fnc_suiteEvicted {    // lease-ended notice
        allowedTargets = 1;};
    class AP_fnc_suiteRentNotice { // rent paid / overdue toast
        allowedTargets = 1;};
    class AP_fnc_suiteStorageRecv { // suite contents push
        allowedTargets = 1;};

    class AP_fnc_fastRopeRope {allowedTargets = 1;};      // roping client -> the helicopter's owner (a client), ropes + doors only
    class AP_fnc_giveGift {allowedTargets = 1;};
    class AP_fnc_medicPartners {allowedTargets = 1;};
    class AP_fnc_statArrUpdate {allowedTargets = 1;};
    class AP_fnc_adminInfo {allowedTargets = 1;};
    class AP_fnc_broadcast {allowedTargets = 1;};
    class AP_fnc_trialSystem {allowedTargets = 1;};
    class AP_fnc_copLights {allowedTargets = 1;};
    class AP_fnc_copSearch {allowedTargets = 1;};
    class AP_fnc_copSiren {allowedTargets = 1;};
    class AP_fnc_giveDiff {allowedTargets = 1;};
    class AP_fnc_licenseCheck {allowedTargets = 1;};
    class AP_fnc_licensesRead {allowedTargets = 1;};
    class AP_fnc_lightHouse {allowedTargets = 1;};
    class AP_fnc_sendRequestToMedic {allowedTargets = 1;};
    class AP_fnc_medicSiren {allowedTargets = 1;};
    class AP_fnc_medicLights {allowedTargets = 1;};
    class AP_fnc_netSetVar {allowedTargets = 1;};
    class AP_fnc_pullOutVeh {allowedTargets = 1;};
    class AP_fnc_receiveItem {allowedTargets = 1;};
    class AP_fnc_receiveMoney {allowedTargets = 1;};
    class AP_fnc_removeLicenses {allowedTargets = 1;};
    class AP_fnc_revived {allowedTargets = 1;};
    class AP_fnc_robPerson {allowedTargets = 1;};
    class AP_fnc_robReceive {allowedTargets = 1;};
    class AP_fnc_searchClient {allowedTargets = 1;};
    class AP_fnc_setFuel {allowedTargets = 1;};
    class AP_fnc_soundDevice {allowedTargets = 1;};
    class AP_fnc_spikeStripEffect {allowedTargets = 1;};
    class AP_fnc_tazeSound {allowedTargets = 1;};
    class AP_fnc_ticketPaid {allowedTargets = 1;};
    class AP_fnc_ticketPrompt {allowedTargets = 1;};
    class AP_fnc_setGangGrpLdr {allowedTargets = 1;};
    class AP_fnc_seizePlayerIllegalAction {allowedTargets = 1;};
    class AP_fnc_seizeToVehicle {allowedTargets = 1;};
    class AP_fnc_removeVehKey {allowedTargets = 1;};
    // client -> clients is legitimate (cop alerts etc.), so the RECEIVER screens client senders (top of
    // fn_handleMessage): no _condition code, plain styles only, and nothing trusted survives its respawn.
    class AP_fnc_handleMessage {allowedTargets = 1;};
    // UI page serving (arma-webui). Direction is load-bearing in BOTH entries:
    //   webServeRecv carries executable page markup, so allowedTargets = 1 keeps it
    //   server -> client. The receiver ALSO checks remoteExecutedOwner, because a
    //   whitelist limits a call's TARGET and never its ORIGIN.
    //   webPageSRV is the client's request for a page and is server-only.
    class AP_fnc_webServeRecv {allowedTargets = 1;};
    // HUD UI EDITOR (hudeditor.md). The client may only ask for ITS OWN row: the payload carries no
    // identity at all, and APS_fnc_hudLayoutSRV takes the uid from remoteExecutedOwner -- captured in
    // the first frame, because it reads 0 inside the spawn the DB call forces. The reverse direction
    // is server-only: AP_fnc_hudLayoutRecv moves nothing but the receiver's own plates, but there is
    // no reason for a client to reach it and no reason to widen a whitelist without one.
    class APS_fnc_hudLayoutSRV {allowedTargets = 2;};   // client -> server, "get" / "set" + 7 number pairs
    class AP_fnc_hudLayoutRecv {allowedTargets = 1;};   // server -> the one client that asked

    class APS_fnc_webPageSRV {allowedTargets = 2;};   // PR10: the comment above always said this entry exists; it never did, so every client page request died at the whitelist ("tried to remoteExec a disabled function", owner playtest 2026-08-20) and screens only ever rendered their PBO fallback
    class AP_fnc_renameHouseDone {   // owner 2026-07-10: server confirms a house rename -> refresh the client's marker
        allowedTargets = 1;};
    class AP_fnc_playSound {allowedTargets = 1;};
    class AP_fnc_skinStaticPump {allowedTargets = 1;};
    class AP_fnc_htmlSkinClient {allowedTargets = 1; jip = 1;};
    class AP_fnc_uiTexLiveClient {allowedTargets = 1; jip = 1;};   // carries an object + display name only; registers with the capped pump   // carries a skin ID only; the page itself comes from the server via the serve fetcher   // client -> nearby clients: pump the broadcast reskin static (fn_skinSwitch)
    class AP_fnc_setAggressive {allowedTargets = 1;};
    class AP_fnc_adrenalineShotEffect {allowedTargets = 1;};
    class AP_fnc_restrainAction {allowedTargets = 1;};
    class AP_fnc_babyOilStrip {allowedTargets = 1;};
    // Player-on-player actions (rob, baby oil, restrain, pull out, search, seize, disarm, shank, firing pin,
    // revoke licence, blindfold, put in vehicle): the actor's client asks the server, which resolves the actor
    // from remoteExecutedOwner, re-checks range + victim state and forwards to the victim's function. Those
    // victim functions keep their allowedTargets = 1 entries and refuse any sender but the server.
    class APS_fnc_victimSRV {allowedTargets = 2;};
    class AP_fnc_clientGroupLeader {allowedTargets = 1;};
    class AP_fnc_clientGroupKick {allowedTargets = 1;};
    class AP_fnc_revokeLicenseAction {allowedTargets = 1;};
    class AP_fnc_tacticalPing {allowedTargets = 1;};
    class AP_fnc_gangRanks {allowedTargets = 1;};
    class AP_fnc_gangDisbanded {allowedTargets = 1;};
    class AP_fnc_gangMembersReceive {allowedTargets = 1;};
    class AP_fnc_gangInvite {allowedTargets = 1;};
    class AP_fnc_clientGangLeader {allowedTargets = 1;};
    class AP_fnc_gangCreated {allowedTargets = 1;};
    class AP_fnc_gangRenamed {allowedTargets = 1;};   // server -> members after APS_fnc_gangRenameSRV commits
    class AP_fnc_doRespawn {allowedTargets = 1;};
    class AP_fnc_disarmed {allowedTargets = 1;};
    class AP_fnc_blindfoldClient {allowedTargets = 1;};
    class AP_fnc_adminGearReceive {   // NC_PHONE: staff-menu weapon/clothing gives to the target client
        allowedTargets = 0;};
    class AP_fnc_adminPlayerQuery {allowedTargets = 1;};
    class AP_fnc_updateRemoteStat {allowedTargets = 1;};
    class AP_fnc_horn {allowedTargets = 1;};
    class AP_fnc_removeGangHouse {allowedTargets = 1;};
    class AP_fnc_closeMap {allowedTargets = 1;};
    class AP_fnc_unitRestrain {allowedTargets = 1;};
    class AP_fnc_removeBounty {allowedTargets = 1;};
    class AP_fnc_handleDowned {allowedTargets = 1;};
    class AP_fnc_talMarker {allowedTargets = 0;};
    class AP_fnc_talFieldReply {allowedTargets = 0;};
    class AP_fnc_qhEffect {allowedTargets = 1;};
    class AP_fnc_fabModel {allowedTargets = 1;};      // attach a fabricator p3d to its anchor
    class AP_fnc_fabModelClear {allowedTargets = 1;}; // and drop it before the anchor is deleted
    class AP_fnc_fabReceive {allowedTargets = 1;};    // push a house's printer states (display only)
    class AP_fnc_fabGiveGear {allowedTargets = 1;};   // hand over PHYSICAL printed gear
    class AP_fnc_fabQuestEvent {allowedTargets = 1;}; // one craft event per collect, for the quest systems
    class AP_fnc_qhTraceResult {allowedTargets = 1;};
    class AP_fnc_qhPing {allowedTargets = 1;};
    class AP_fnc_qhEyeSpy {allowedTargets = 1;};
    class AP_fnc_qhEngineKill {allowedTargets = 1;};
    class AP_fnc_qhChauffeur {allowedTargets = 1;};
    class AP_fnc_qhPuppet {allowedTargets = 1;};
    class AP_fnc_talTrace {allowedTargets = 1;};
    class AP_fnc_clientMessage {allowedTargets = 1;};
    class AP_fnc_dispatchClientMessage {allowedTargets = 1;};
    class AP_fnc_requestMedicalConfirmation {allowedTargets = 1;};
    class AP_fnc_showBroadcast {allowedTargets = 1;};
    class AP_fnc_medicRespondDone {allowedTargets = 1;};
    class AP_fnc_setGroupMarker {allowedTargets = 1;};
    class AP_fnc_setUnconscious {allowedTargets = 1;};
    class AP_fnc_addExperience {allowedTargets = 1;};
    // Quest XP payout, server -> the rewarded client only. Carries a number and
    // nothing else; the client clamps it to > 0 before applying.
    class AP_fnc_aqAwardXpClient {allowedTargets = 1;};
    class AP_fnc_earnPrestige {allowedTargets = 1;};
    class AP_fnc_addPrestige {allowedTargets = 1;};
    class AP_fnc_warStatus {allowedTargets = 1;};
    class AP_fnc_warChallenged {allowedTargets = 1;};
    class AP_fnc_eventGunGameClient {allowedTargets = 1;};
    class AP_fnc_funGunClient {   // owner fun guns server->client effect
        allowedTargets = 1;};
    class AP_fnc_eventGungameKill {allowedTargets = 1;};
    class AP_fnc_eventGridrunnerClient {allowedTargets = 1;};
    class AP_fnc_evidenceSystems {allowedTargets = 1;};
    class AP_fnc_attachSmoke {allowedTargets = 1;};
    class AP_fnc_setGroupRestrainMarker {allowedTargets = 1;};
    class AP_fnc_changeGangHouse {allowedTargets = 1;};
    class AP_fnc_setGangHouseForMembers {allowedTargets = 1;};
    class AP_fnc_bodybagMarker {allowedTargets = 1;};
    class AP_fnc_handleQuest {allowedTargets = 1;};
    class AP_fnc_gangSetOwner {allowedTargets = 1;};
    class AP_fnc_medicRepairBuilding {allowedTargets = 1;};
    class AP_fnc_civRepairBuilding {allowedTargets = 1;};
    class AP_fnc_initKeyHouseMarkers {allowedTargets = 1;};
    class AP_fnc_cannabisItems {allowedTargets = 1;};
    class AP_fnc_handleAnim {allowedTargets = 1;};
    class AP_fnc_boomBox {allowedTargets = 1;};
    class AP_fnc_govSystem {allowedTargets = 1;};
    class AP_fnc_govPardon {allowedTargets = 1;};
    class AP_fnc_phoneCallClient {allowedTargets = 1;};
    class AP_fnc_executionerMove {allowedTargets = 1;};
    class AP_fnc_sprayPaint {allowedTargets = 1;};
    class AP_fnc_medicFireClient {allowedTargets = 1;};
    class AP_fnc_putInVehAction {allowedTargets = 1;};
    class AP_fnc_duelArenaSystem {allowedTargets = 1;};
    class AP_fnc_storageVaultRecv {   // owner 2026-07-11: Storage Worker (server -> client: repaint panels)
        allowedTargets = 1;};
    class APS_fnc_loonerSRV {allowedTargets = 2;};
    class AP_fnc_summonSpawn {allowedTargets = 1;};   // server -> owner client: spawn the recall vehicle
    class AP_fnc_summonState {allowedTargets = 1;};   // server -> owner client: summon progress
    class APS_fnc_summonSRV {allowedTargets = 2;};    // client -> server: set/info/go/drive/spawnfail
    class APS_fnc_avSRV {allowedTargets = 2;};        // client -> server: LUXE AV go/door (caller = remoteExecutedOwner)
    class APS_fnc_registerMaxTac {allowedTargets = 2;};
    class DB_fnc_insertRequest {allowedTargets = 2;};
    class APS_fnc_statTableUpdate {allowedTargets = 2;};
    class APS_fnc_fetchLoadouts {allowedTargets = 2;};
    class APS_fnc_handleLoadouts {allowedTargets = 2;};
    class DB_fnc_queryRequest {allowedTargets = 2;};
    class DB_fnc_updatePartial {allowedTargets = 2;};
    class DB_fnc_updateRequest {allowedTargets = 2;};
    class APS_fnc_jailSys {allowedTargets = 2;};
    class APS_fnc_bulkAdd {allowedTargets = 2;};
    class APS_fnc_wantedAdd {allowedTargets = 2;};
    class APS_fnc_wantedSyncList {allowedTargets = 2;};
    class APS_fnc_wantedFetch {allowedTargets = 2;};
    class APS_fnc_garageCount {allowedTargets = 2;};
    class APS_fnc_storageVaultSRV {   // owner 2026-07-11: Storage Worker (client -> server: list/pack/unpack)
        allowedTargets = 2;};
    class APS_fnc_maldenSRV {   // owner 2026-07-11: Malden Makeover apply/bullets (client -> server; owner re-verified)
        allowedTargets = 2;};
    class AP_fnc_maldenSync {   // owner 2026-07-11: Malden swap client-registry fix (server -> clients)
        allowedTargets = 1;};
    class APS_fnc_intakeSRV {   // owner 2026-07-11: THE INTAKE Act 1 (client -> server: complete/skip/reset)
        allowedTargets = 2;};
    class AP_fnc_intake {   // owner 2026-07-11: THE INTAKE stipend ack (server -> client; handler gates remoteExecutedOwner==2)
        allowedTargets = 1;};
    class AP_fnc_mentor {   // owner 2026-07-11: mentor offer/link/payout messages (client<->client prompt is spoof-useless; money paths gate ==2)
        allowedTargets = 1;};
    class APS_fnc_wantedPardon {allowedTargets = 2;};
    class APS_fnc_wantedRemove {allowedTargets = 2;};
    // owner 2026-06-23: AP_fnc_observe removed with SpyGlass (whitelist entry deleted so no undefined-fn remoteExec target remains).
    class APS_fnc_addHouse {allowedTargets = 2;};
    class APS_fnc_spawnPhysicalItem {allowedTargets = 2;};
    class APS_fnc_srvChopShopSell {allowedTargets = 2;};
    class APS_fnc_lagCheck {allowedTargets = 2;};
    // the I-screen (INVENTORY_SPEC.md §9.4): the ONE server mutator for vehicle/crate/ground cargo, and
    // its verdict receiver. Direction matters both ways: the mutator is client->server only, and the
    // receiver is server->client only so no client can forge another client's verdict.
    class APS_fnc_invCargo {allowedTargets = 2;};
    class AP_fnc_invCargoRecv {allowedTargets = 1;};
    class APS_fnc_vehicleSetActive {allowedTargets = 2;};
    class APS_fnc_getID {allowedTargets = 2;};
    class APS_fnc_getGangInfo {allowedTargets = 2;};
    class APS_fnc_changeServCycle {allowedTargets = 2;};
    class APS_fnc_getVehicles {allowedTargets = 2;};
    class APS_fnc_keyManagement {allowedTargets = 2;};
    class APS_fnc_checkPlayer {allowedTargets = 2;};
    class APS_fnc_chopTreeSRV {allowedTargets = 2;};
    class APS_fnc_copUAVSRV {allowedTargets = 2;};
    class APS_fnc_registerForeskin {allowedTargets = 2;};
    class APS_fnc_srvSellHouse {allowedTargets = 2;};
    class APS_fnc_renameHouseSRV {   // owner 2026-07-10: player house rename (owner-gated + re-sanitized server-side)
        allowedTargets = 2;};
    class APS_fnc_shedHelipadSRV {   // LooneyBin: shed helipad upgrade purchase (owner-gated server-side)
        allowedTargets = 2;};
    class APS_fnc_srvSpikeStrip {allowedTargets = 2;};
    class APS_fnc_wantedRemoveCharge {allowedTargets = 2;};
    class APS_fnc_updateHouseTrunk {allowedTargets = 2;};
    class APS_fnc_vehicleCreate {allowedTargets = 2;};
    // APS_fnc_vehicleDelete is deliberately ABSENT (audit 2026-09-26, mints/srvsys-0-3): it paid a client-chosen
    // price whether or not a row was deleted, and it has no legitimate client caller.
    class APS_fnc_vehicleStore {allowedTargets = 2;};
    class APS_fnc_copSplit {allowedTargets = 2;};
    class APS_fnc_seizeLock {allowedTargets = 2;};
    class APS_fnc_vehicleDead {allowedTargets = 2;};
    class APS_fnc_recoverWreck {allowedTargets = 2;};
    class APS_fnc_logIt {allowedTargets = 2;};
    class APS_fnc_insertGang {allowedTargets = 2;};
    class APS_fnc_doBuySkin {allowedTargets = 2;};
    class APS_fnc_flipVehicle {allowedTargets = 2;};
    class APS_fnc_enableCoPilot {allowedTargets = 2;};
    // owner 2026-07-28: REMOVED APS_fnc_fedRobbery client whitelist entry. The function is now server-only
    // (called via direct call in fn_iceTrace, not remoteExec). No client code calls it anymore; removing
    // this entry closes the last client-reachable path into the fed alarm. DO NOT re-add without verifying
    // that no live code calls it client-side; re-opening this window would allow client-driven alarm bypass.
    class APS_fnc_fedGoldSpawn {allowedTargets = 2;};
    class APS_fnc_evidenceTruck {allowedTargets = 2;};
    class APS_fnc_adminMsg {                  // admin-menu "Message All" (client admin -> server relay)
        allowedTargets = 2;};
    class APS_fnc_discordEmbed {              // client exploit-flag reports -> server (stub logs them)
        allowedTargets = 2;};
    class AP_fnc_animSync {                 // boltcutter/repair work-anim broadcast (client -> everyone)
        allowedTargets = 0;};
    class AP_fnc_pushFunction {             // Push Vehicle -> runs where the vehicle is local (client -> client)
        allowedTargets = 0;};
    class APS_fnc_droneCharges {allowedTargets = 2;};
    class APS_fnc_bankRobbery {allowedTargets = 2;};
    class APS_fnc_bankLightHouseToggle {allowedTargets = 2;};
    class APS_fnc_createItem {allowedTargets = 2;};
    class APS_fnc_handlePrisonBreak {allowedTargets = 2;};
    class APS_fnc_srvRobStore {allowedTargets = 2;};
    class APS_fnc_updateProperty {allowedTargets = 2;};
    class APS_fnc_handlePhoneMsg {allowedTargets = 2;};
    class APS_fnc_handleDispatch {allowedTargets = 2;};
    class APS_fnc_updateGangMem {allowedTargets = 2;};
    class APS_fnc_removeGang {allowedTargets = 2;};
    class APS_fnc_vehAddAlarm {allowedTargets = 2;};
    class APS_fnc_srvSellVehicle {allowedTargets = 2;};
    class APS_fnc_gangBank {allowedTargets = 2;};
    class APS_fnc_gangBHistory {allowedTargets = 2;};
    class APS_fnc_setJail {allowedTargets = 2;};
    class APS_fnc_wantedBounty {allowedTargets = 2;};
    class APS_fnc_claimBodybagSRV {allowedTargets = 2;};
    class APS_fnc_addGangHouse {allowedTargets = 2;};
    class APS_fnc_visible {allowedTargets = 2;};
    class APS_fnc_setCleanTime {allowedTargets = 2;};
    class APS_fnc_updateGangTalents {allowedTargets = 2;};
    class APS_fnc_adminDelVeh {allowedTargets = 2;};
    class APS_fnc_vehOwnerSwap {allowedTargets = 2;};
    class APS_fnc_airDrop {allowedTargets = 2;};
    class APS_fnc_updateVehicleMods {allowedTargets = 2;};
    class APS_fnc_createAdminVeh {allowedTargets = 2;};
    class APS_fnc_changeWeather {allowedTargets = 2;};
    class APS_fnc_duelArenaSystemSRV {allowedTargets = 2;};
    class APS_fnc_createTimeTrialVehSRV {allowedTargets = 2;};
    class APS_fnc_timeTrialSRV {allowedTargets = 2;};
    class APS_fnc_easterSeasonalEvent {allowedTargets = 2;};
    class APS_fnc_updateHousePrice {allowedTargets = 2;};
    class APS_fnc_processMailbox {allowedTargets = 2;};
    class APS_fnc_transferHouse {allowedTargets = 2;};
    class APS_fnc_srvPersistentBounties {allowedTargets = 2;};
    class APS_fnc_varPersist {allowedTargets = 2;};
    class APS_fnc_evidenceAppend {allowedTargets = 2;};
    class APS_fnc_laserQueue {allowedTargets = 2;};
    class APS_fnc_laserEliminated {allowedTargets = 2;};
    class APS_fnc_medicSplit {allowedTargets = 2;};
    class APS_fnc_igiInit {allowedTargets = 2;};
    class APS_fnc_add2Lotto {allowedTargets = 2;};
    class APS_fnc_updateWar {allowedTargets = 2;};
    class APS_fnc_srvObjectMonitor {allowedTargets = 2;};
    class APS_fnc_getStatsArr {allowedTargets = 2;};
    class APS_fnc_bldgUpdateKeys {allowedTargets = 2;};
    class APS_fnc_toggleNewbieRoles {allowedTargets = 2;};
    class APS_fnc_ownerSpangle {allowedTargets = 2;};
    class APS_fnc_airDropMedic {allowedTargets = 2;};
    class APS_fnc_eventGunGameSRV {allowedTargets = 2;};
    class APS_fnc_eventChemtrailSRV {allowedTargets = 2;};
    // owner 2026-07-17: HC-driven admin dynamic events (admin client -> server). mode=1 whitelist:
    // without these the admin-menu remoteExec is silently denied and nothing spawns.
    class APS_fnc_eventIceCreamSRV {allowedTargets = 2;};
    class APS_fnc_eventSupplyBomberSRV {allowedTargets = 2;};
    class APS_fnc_eventCropDusterSRV {allowedTargets = 2;};
    class APS_fnc_eventSmugglerBoatSRV {allowedTargets = 2;};
    class APS_fnc_bonesDM {allowedTargets = 2;};
    class AP_fnc_bonesText {allowedTargets = 1;};
    class APS_fnc_offlineMsg {allowedTargets = 2;};       // client -> server: queue for an offline player
    class AP_fnc_offlineMsgRecv {allowedTargets = 1;};  // server -> client: the backlog, one batch
    class AP_fnc_deckQhResult {allowedTargets = 1;};   // server -> client: how a quickhack ended (ICE firewall is only known there)
    class APS_fnc_miningSRV {allowedTargets = 2;};
    class APS_fnc_cyberdeckSRV {allowedTargets = 2;};
    class APS_fnc_talSRV {allowedTargets = 2;};
    class APS_fnc_iceTrace {allowedTargets = 2;};
    class APS_fnc_ndSRV {allowedTargets = 2;};
    // Luxe Suites lease authority. NOTE: APS_fnc_ndDebitSrv, APS_fnc_suiteRelease
    // and APS_fnc_suiteRentSweep are deliberately ABSENT from this whitelist --
    // that absence is what makes them server-only, exactly like APS_fnc_ndCreditSrv.
    class APS_fnc_suiteSRV {allowedTargets = 2;};
    class APS_fnc_suiteStorageSRV {allowedTargets = 2;};
    class APS_fnc_suiteFurnitureSRV {allowedTargets = 2;};
    class APS_fnc_qhSRV {allowedTargets = 2;};
    // 3D printer. The client sends INTENT only -- a printer id, a recipe key and a count. Level,
    // schematic ownership, the machine tier cap, proximity, house rights and whether the job is
    // actually finished are all recomputed server-side from the database, so a lying client can
    // ask and be refused but cannot grant. APS_fnc_fabXp is deliberately ABSENT from this list:
    // it is the only thing that can raise a fabrication level, and that absence is what stops a
    // client reaching it -- the same reasoning as APS_fnc_ndDebitSrv.
    class APS_fnc_fabSRV {allowedTargets = 2;};
    // Schematic grants. The client can only ever ask to consume a shard it holds or to BUY a
    // named schematic; which schematic a drop yields is rolled server-side, and the purchase is
    // charged through APS_fnc_ndDebitSrv, which is itself absent from this whitelist.
    class APS_fnc_fabGrantSRV {allowedTargets = 2;};
    // FREE BUILD testing override. Whitelisted so an admin can flip it from their own console;
    // the authority is the adminlevel the SERVER reads for remoteExecutedOwner, not the packet,
    // so a non-admin reaching this gets a -SEC- row and nothing else.
    class APS_fnc_fabDebugSRV {allowedTargets = 2;};
    // RESOURCE RIG (traded system 2026-08-27). Client requests go to the server,
    // which validates everything (owner/keys, distance, speed, empty crew, zone,
    // legal transition) and publishes state; the visuals fn is server->clients
    // only and draws local simple objects from that state.
    class APS_fnc_rigSRV {allowedTargets = 2;};
    class AP_fnc_rigClient {allowedTargets = 1;};
    class APS_fnc_qhLootSRV {allowedTargets = 2;};
    class APS_fnc_eventBlackoutSRV {allowedTargets = 2;};
    class APS_fnc_eventBugInvasionSRV {allowedTargets = 2;};
    class APS_fnc_eventLizardPoliceSRV {allowedTargets = 2;};
    class APS_fnc_funGunSRV {   // owner fun guns: grant/revoke + player sub-spawn callback
        allowedTargets = 2;};
    class APS_fnc_eventBRSRV {allowedTargets = 2;};
    class APS_fnc_eventPurgeSRV {allowedTargets = 2;};
    class APS_fnc_eventGridrunnerSRV {allowedTargets = 2;};
    class APS_fnc_eventParticipants {allowedTargets = 2;};
    class APS_fnc_handleTimer {allowedTargets = 2;};
    class APS_fnc_huntingGrounds {allowedTargets = 2;};
    class APS_fnc_changeGangHouseSRV {allowedTargets = 2;};
    class APS_fnc_removeGangHouseSRV {allowedTargets = 2;};
    class APS_fnc_medSupplySpawn {allowedTargets = 2;};
    class APS_fnc_medSupplyPay {allowedTargets = 2;};
    class APS_fnc_vehicleRepairSRV {allowedTargets = 2;};
    class APS_fnc_initHouseInventory {allowedTargets = 2;};
    class APS_fnc_eventGraveyardSRV {allowedTargets = 2;};
    class APS_fnc_convoyRobbery {allowedTargets = 2;};
    class APS_fnc_endConvoyRobbery {allowedTargets = 2;};
    class APS_fnc_transferGangOwnerSRV {allowedTargets = 2;};
    class APS_fnc_setGangTagSRV {allowedTargets = 2;};
    class APS_fnc_gangRenameSRV {allowedTargets = 2;};
    class APS_fnc_pysqfDiag {allowedTargets = 2;};   // pysqf smoke/conform; re-checks adminlevel server-side   // deck gang rename: leader-gated + gang-bank fee, server-side
    class APS_fnc_exchangeSystemSRV {allowedTargets = 2;};
    class APS_fnc_houseFurnitureSRV {allowedTargets = 2;};
    class APS_fnc_loveBombSRV {allowedTargets = 2;};
    class AP_fnc_loveBombHeal {allowedTargets = 1;};
    class APS_fnc_adminKickBan {allowedTargets = 2;};
    class APS_fnc_economySRV {allowedTargets = 2;};
    // market sell/buy hook: server clamps qty to the good's depth and a per-caller net budget (remoteExecutedOwner)
    class APS_fnc_stockUpdate {allowedTargets = 2;};
    class APS_fnc_trialSystemSRV {allowedTargets = 2;};
    class APS_fnc_repairBuildingSRV {allowedTargets = 2;};
    class APS_fnc_sendKeyHouses {allowedTargets = 2;};
    class APS_fnc_loginBonusSRV {allowedTargets = 2;};
    class APS_fnc_xmasTreeAndPresentsSRV {allowedTargets = 2;};
    class APS_fnc_ignitionBombSRV {allowedTargets = 2;};
    class APS_fnc_govSystemSRV {allowedTargets = 2;};
    class APS_fnc_greenhouseSRV {allowedTargets = 2;};
    class APS_fnc_barrelSRV {allowedTargets = 2;};
    class APS_fnc_loonyBinSRV {allowedTargets = 2;};
    class APS_fnc_handlePhoneCallSRV {allowedTargets = 2;};
    class APS_fnc_gangGarageGetVehicles {allowedTargets = 2;};
    class APS_fnc_gangGarageCount {allowedTargets = 2;};
    class APS_fnc_gangGarageAddSRV {allowedTargets = 2;};
    class APS_fnc_gangGarageStore {allowedTargets = 2;};
    class APS_fnc_gangGarageSetActive {allowedTargets = 2;};
    class APS_fnc_medicFireSRV {allowedTargets = 2;};
    class APS_fnc_jewelryEmporiumSRV {allowedTargets = 2;};
    class APS_fnc_adminPlayerQuerySRV {allowedTargets = 2;};
    class APS_fnc_srvMobileHQ {allowedTargets = 2;};
    class APS_fnc_cartelSRV {allowedTargets = 2;};
    class APS_fnc_handleWireTransfer {allowedTargets = 2;};
    class APS_fnc_houseTaxSRV {allowedTargets = 2;};
    // owner 2026-07-24: the two OWNER-ONLY control tools were registered in config.cpp and wired to admin-menu
    // buttons via AP_fnc_MP, but had NO CfgRE entry -- under mode = 1 every call was silently dropped while
    // the UI reported success, so "Fed Control" and "Stimmy Checks" have never worked from in-game. (Fed
    // Override was still ACTIVE only because server_control.fedoverride=1 is restored at boot in
    // init.sqf:1013 -- but it could not be turned OFF.) Both re-verify the caller against the owner UID via
    // remoteExecutedOwner (hardened in the same commit; they previously trusted a client-passed object).
    class APS_fnc_fedOverrideSRV {allowedTargets = 2;};
    class APS_fnc_stimmySRV {allowedTargets = 2;};
    class APS_fnc_dongClient {allowedTargets = 2;};
    class APS_fnc_handleJail {allowedTargets = 2;};
    class APS_fnc_blackJackSRV {   // LooneyBin: Casino phone app -- blackjack (deal/hit/stand/double/split)
        allowedTargets = 2;};
    class APS_fnc_bjTableSRV {   // Armapunk: DEALERBOT'S TABLE -- shared 5-seat blackjack (watch/sit/leave/bet/act)
        allowedTargets = 2;};
    class APS_fnc_holdemSRV {   // Armapunk: TEXAS HOLD'EM -- shared 6-seat table (open/close/sit/leave/act).
        // allowedTargets restricts the TARGET, not the sender, so the fn's own first statement captures
        // remoteExecutedOwner and its three server-local cases (tick/expire/disconnect) refuse anything
        // that is not owner 0. APS_fnc_holdemEval is deliberately absent: it ranks hands and pays pots.
        allowedTargets = 2;};
    class APS_fnc_casinoSRV {   // LooneyBin: Casino -- Coin Flip/Wheel/Slots/Roulette/Hi-Lo engine (client->server intent)
        allowedTargets = 2;};
    class APS_fnc_createP3DObjects {allowedTarget = 2;};
    // LooneyBin: server->client callbacks. Under mode=1 these MUST be whitelisted or the engine
    // silently blocks the server's remoteExec to the client. AP_fnc_requestReceived is THE
    // player-load return (server queryRequest/insert -> client) — without it the client hangs at
    // waitUntil{AP_session_completed} forever (no spawn/HUD/phone). Others: GE/exchange, money
    // (uC), gang garage, weapon grant — all server-initiated calls onto clients.
    class AP_fnc_requestReceived {allowedTargets = 1;};
    class AP_fnc_blackJack {   // LooneyBin: Casino -- server->client table render
        allowedTargets = 1;};
    class AP_fnc_blackJackReceive {   // LooneyBin: Casino -- server->client bank payout credit
        allowedTargets = 1;};
    class AP_fnc_holdemReceive {   // Armapunk: HOLD'EM -- server->client per-viewer table snapshot
        allowedTargets = 1;};
    class AP_fnc_holdemCash {   // Armapunk: HOLD'EM -- server-ordered BANK movement, both directions
        allowedTargets = 1;};
    class AP_fnc_bjTable {   // Armapunk: DEALERBOT'S TABLE -- server->client table snapshot / wallet / event
        allowedTargets = 1;};
    class AP_fnc_casino {   // LooneyBin: Casino -- server->client result render (Coin Flip/Wheel/Slots/Roulette/Hi-Lo)
        allowedTargets = 1;};
    class AP_fnc_casinoReceive {   // LooneyBin: Casino -- server->client bank payout credit (five simple games)
        allowedTargets = 1;};
    class AP_fnc_loonerReceive {   // LooneyBin: Looner -- server->client feed push
        allowedTargets = 1;};
    class APS_fnc_talentPointsSRV {   // LooneyBin: buyable talent points (client -> server load/buy)
        allowedTargets = 2;};
    class AP_fnc_talentPointsRecv { // LooneyBin: buyable talent points (server -> client count push)
        allowedTargets = 1;};
    class APS_fnc_atmSkimSRV {        // LooneyBin: ATM skimmer (client -> server apply/remove/credit)
        allowedTargets = 2;};
    class AP_fnc_botKick {allowedTargets = 1;};   // server -> client kick; 2 let any client endMission the SERVER
    class AP_fnc_uC {allowedTargets = 1;};
    class AP_fnc_GEMenu {allowedTargets = 1;};
    class AP_fnc_gangGarageMenu {allowedTargets = 1;};
    class AP_fnc_vehicleGarageMenu {allowedTargets = 1;};
    class AP_fnc_handleHouse {allowedTargets = 1;};
    // LooneyBin: arrest/ticket cop pay. Both are server->client callbacks (wantedBounty -> bountyReceive
    // on the cop; copSplit -> copSplitReceive on each active cop). Without whitelisting, mode=1 silently
    // blocks them and cops are never paid for arrests OR tickets.
    class AP_fnc_bountyReceive {allowedTargets = 1;};
    class AP_fnc_copSplitReceive {allowedTargets = 1;};

    // ArmaQuest. mode=1 means anything not listed here silently does nothing,
    // which for a quest system means quests that can be accepted and never
    // progress, with an empty log. allowedTargets: 2 = server only (client->
    // server), 1 = clients only (server->client).
    class aq_fnc_srvAccept { allowedTargets = 2; };
    class aq_fnc_srvBoard  { allowedTargets = 2; };
    class aq_fnc_srvFact   { allowedTargets = 2; };
    class aq_fnc_srvFail   { allowedTargets = 2; };
    class aq_fnc_journal   { allowedTargets = 1; };
    class aq_fnc_sync      { allowedTargets = 1; };

    // Host-side helpers the profile calls server->client (Task 6).
    // AP_fnc_handleMessage is already whitelisted above (see class AP_fnc_handleMessage).
    // NOTE: AP_fnc_aqGrantLicense itself (the AQ_Profile >> grantLicense capability,
    // aq_content.hpp) needs NO entry here -- it runs on the server and is called
    // locally via aq_fnc_profile, never remoteExec'd. The name originally reserved
    // here was renamed to AP_fnc_handleLicense (core/actions/fn_handleLicense.sqf)
    // specifically to avoid that collision: both would otherwise compile under the
    // same AP tag into one missionNamespace slot, and whichever loaded second would
    // silently win. AP_fnc_handleLicense is the one actually dispatched
    // server->client, so it is the one that needs the whitelist entry.
    class AP_fnc_handleLicense { allowedTargets = 1; };
    // AP_fnc_handleInv was confirmed MISSING by grep before this edit -- the profile
    // calls it the same server->client way, so it is added here too (Step 4).
    class AP_fnc_handleInv { allowedTargets = 1; };
	// Gang -> NPC faction alignment. Client asks, server decides: gang, rank and
	// the right to change alignment are all re-derived from the database inside
	// the receiver, so a lying client can only ask for something and be refused.
	class APS_fnc_gangAlignSRV { allowedTargets = 2; };
	// Buying a faction perk. Client sends only a perk id; standing, primary
	// faction, points available and spent, and prerequisites are ALL recomputed
	// server-side, so a lying client can ask and be refused but cannot grant.
	class APS_fnc_buyFactionPerkSRV { allowedTargets = 2; };};
class Commands {mode = 0;
    jip = 0;};