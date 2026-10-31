// PR9 -- THE LANDING SCREEN replaces the lobby welcome's PLAY gate. AP_fnc_landingOpen returns true only
// when it actually took the screen, and it has already blocked until the player deployed or dismissed it;
// false means it declined (SRV_landingEnabled off, a fresh account on the intake path, a jailed account,
// or createDialog failing) and the pre-PR9 flow runs untouched. Its own header has each decline's reason.
// Nothing below this line changes for a solo deploy or a dismissal: the branch tree is the same one it
// always was. The single exception is the duty override at the _onMap test.
if !([] call AP_fnc_landingOpen) then { ["waitForPlay"] call AP_fnc_welcomeUI; };
civ_spawn_1 = nearestObjects[getMarkerPos "civ_spawn_1", ["Land_i_Shop_01_V1_F", "Land_i_Shop_02_V1_F", "Land_i_Shop_01_V1_dam_F", "Land_i_Shop_02_V1_dam_F", "Land_i_Barracks_V1_F", "Land_i_Barracks_V2_dam_F", "Land_i_Barracks_V2_F", "Land_i_Garage_V1_F"], 100];
civ_spawn_2 = nearestObjects[getMarkerPos "civ_spawn_2", ["Land_i_Shop_01_V1_F", "Land_i_Shop_02_V1_F", "Land_i_Shop_01_V1_dam_F", "Land_i_Shop_02_V1_dam_F", "Land_i_Barracks_V1_F", "Land_i_Barracks_V2_dam_F", "Land_i_Barracks_V2_F", "Land_i_Garage_V1_F"], 100];
civ_spawn_3 = nearestObjects[getMarkerPos "civ_spawn_3", ["Land_i_Shop_01_V1_F", "Land_i_Shop_02_V1_F", "Land_i_Shop_01_V1_dam_F", "Land_i_Shop_02_V1_dam_F", "Land_i_Barracks_V1_F", "Land_i_Barracks_V2_dam_F", "Land_i_Barracks_V2_F", "Land_i_Garage_V1_F"], 100];
civ_spawn_4 = nearestObjects[getMarkerPos "civ_spawn_4", ["Land_i_Shop_01_V1_F", "Land_i_Shop_02_V1_F", "Land_i_Shop_01_V1_dam_F", "Land_i_Shop_02_V1_dam_F", "Land_i_Barracks_V1_F", "Land_i_Barracks_V2_dam_F", "Land_i_Barracks_V2_F", "Land_i_Garage_V1_F"], 100];
donor_town = nearestObjects[getMarkerPos "donor_town", ["Land_i_Shop_01_V1_F", "Land_i_Shop_02_V1_F", "Land_i_Shop_01_V1_dam_F", "Land_i_Shop_02_V1_dam_F", "Land_i_Barracks_V1_F", "Land_i_Barracks_V2_dam_F", "Land_i_Barracks_V2_F", "Land_i_Garage_V1_F"], 150];
waitUntil {!(isNull(findDisplay 46))};
private _thread = [] spawn {[[getPlayerUID player, profileName, A_stats_crimes], "APS_fnc_bulkAdd", 2] spawn AP_fnc_MP;};
// LooneyBin: type-safe arrested check. AP_is_arrested must be an array whose [0]==1 to mean
// "in jail". A nil/malformed value (bad DB decode) was passing the old `select 0 isEqualTo 1`
// (or aborting it) -> player wrongly sent to fn_jailPlayer -> setPosATL getMarkerPos "jail_marker2"
// (a marker that doesn't exist in mission.sqm) -> [0,0,0] debug island, stuck. param[0,0]
// defaults to 0 for empty/short arrays, so only a genuine [1,...] jails.
if ((AP_is_arrested isEqualType []) && {(AP_is_arrested param [0,0]) isEqualTo 1}) then {waitUntil {scriptDone _thread};
    [player, false, false, false, true] spawn AP_fnc_jailPlayer;} else {
    // LooneyBin: only treat as a returning-player teleport if AP_ses_last_pos is a real position
    // array (3+ numbers). A junk sentinel (string/[[]]/[]) must fall through to the spawn menu;
    // otherwise `AP_ses_last_pos distance [0,0,0]` throws and the player is never positioned.
    // owner 2026-06-20 (#SOFTLOG instrument): the owner STILL hits the spawn-selection menu on relog while
    // alive, but the entire load chain (queryRequest col 11 -> packet[17] -> requestReceived:183 -> here)
    // checks out in static analysis AND in the live DB (a real 3-number position, far from spawn+origin).
    // fn_initCiv runs CLIENT-side so its diag_log is invisible (can't read client RPT) -- mirror the EXACT
    // decision state to the SERVER log via APS_fnc_logIt so the NEXT relog tells us which sub-condition
    // actually fails at runtime instead of guessing a 4th positional fix. One row per civ login; remove once
    // the cause is pinned. The branch below now reads `_onMap` directly instead of re-testing the same
    // predicate inline, so the SOFTLOG line and the actual branch can no longer drift apart.
    private _slpOK = (AP_ses_last_pos isEqualType []) && {count AP_ses_last_pos > 2} && {(AP_ses_last_pos select 0) isEqualType 0} && (AP_serverId isEqualTo 1);
    // A saved position only means anything on the world it was saved on. This fork moved from Altis
    // (worldSize 30720) to Malden (12800) while fn_query/fn_update still resolve the SAME `worldspace`
    // DB column -- they carry per-world columns for Stratis and Tanoa but no Malden case -- so a
    // returning player's ALTIS coordinate is loaded here verbatim. Observed: [14047, 18745], both axes
    // past Malden's edge. The returning-player TELEPORT branch then setPosATL'd the player into open
    // sea beyond the map and never opened the spawn menu, so they sat on the "spawning in" loading
    // screen hearing water with no way out. Reject any saved position outside THIS world's bounds so
    // it falls through to the spawn menu exactly like a fresh login. This is a safety net, not the
    // fix for the shared column -- an Altis position that happens to fall inside 0..12800 still lands
    // somewhere arbitrary on Malden.
    private _onMap = _slpOK
        && {(AP_ses_last_pos select 0) > 0} && {(AP_ses_last_pos select 0) < worldSize}
        && {(AP_ses_last_pos select 1) > 0} && {(AP_ses_last_pos select 1) < worldSize};
    // PR9: A SHIFT TAKEN AT THE LANDING SCREEN OVERRIDES THE RELOG TELEPORT. AP_ses_last_pos is the
    // CIVILIAN character's last spot and this player is not a civilian any more -- AP_fnc_dutyClient has
    // already moved AP_effSide, so what they need is a MaxSec precinct or a TT helipad, which is exactly
    // what fn_spawnMenu now offers (it keys the list off AP_effSide since PR6). Forcing the menu branch is
    // safe from here: the landing never opens for an intake account (fn_landingOpen declines on
    // AP_intakePath == 0), so :182's intake test cannot be true on any path that reaches it with a shift.
    private _dutyAtLanding = missionNamespace getVariable ["AP_onDuty", false];
    if (_dutyAtLanding) then { _onMap = false; };
    private _farOK = if (_onMap) then { (AP_ses_last_pos distance [0,0,0]) > 500 } else { false };
    private _branch = if (_dutyAtLanding) then { "MENU(duty taken at landing)" } else {
        if (_onMap && _farOK) then { "TELEPORT" } else {
            if (_slpOK && !_onMap) then { "MENU(off-world pos)" } else {
                if (_slpOK) then { "MENU(near-origin<=500)" } else { "MENU(bad-pos/AP_serverId)" }; }; }; };
    [["-SOFTLOG-", player, name player, format ["spawnDecide branch=%1 ses_last_pos=%2 type=%3 cnt=%4 AP_serverId=%5 arrested=%6", _branch, str AP_ses_last_pos, typeName AP_ses_last_pos, (if (AP_ses_last_pos isEqualType []) then { count AP_ses_last_pos } else { -1 }), AP_serverId, str AP_is_arrested]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    if (_onMap) then {
        private _plb_dmg = player;
        APV_thirst = profileNamespace getVariable["AP_thirst", 100];
        APV_hunger = profileNamespace getVariable["AP_hunger", 100];
        player setDir(profileNamespace getVariable["AP_playerDir", 0]);
        _plb_dmg setDamage(profileNamespace getVariable["AP_playerDamage", 0]);
        if (AP_ses_last_pos distance[0, 0, 0] > 500) then {if ((AP_ses_last_pos select 2) > 50) then {AP_ses_last_pos set[2, 0];};
            private _rebelMarkers = ["Rebelop_1", "Rebelop_2", "Rebelop_3", "Rebelop_4", "Rebelop_5", "Rebelop_6"];
            private _markerIndex = _rebelMarkers findIf {AP_ses_last_pos distance(getMarkerPos _x) <= 150};
            if !(_markerIndex isEqualTo - 1) then {private _marker = _rebelMarkers select _markerIndex;
                private _toSend = (allPlayers select {
                    isPlayer _x && _x distance(getMarkerPos _marker) <= 150 && !(AP_gang_data param[0, -33] isEqualTo(_x getVariable["gang_data", [-22]] select 0))
                }) - [player];
                if (_toSend isEqualTo[]) exitWith {}; [[
                        [0, 1, 2], "A potentially hostile player has entered the world nearby!"], "AP_fnc_broadcast", _toSend] spawn AP_fnc_MP;
            };
            [AP_ses_last_pos, 20] call AP_fnc_mapWaitLoaded;   // mapdb: the cell under the saved position is in and built
            // owner 2026-07-25: logging out INSIDE a cartel zone and logging back in there lets a
            // gang sit on contested ground through a restart, and drops a returning player straight
            // into a KOS circle before they can react. Relocate any saved position inside a cartel
            // to neutral ground. Radius is generous (120m) because the capture trigger is 50m but
            // Boomtown's capture radius is widened to 95 for its larger footprint.
            {
                if ((AP_ses_last_pos distance2D (_x select 4)) < 120) exitWith {
                    AP_ses_last_pos = [6613.99, 10028.3, 0];
                    ["You logged out inside a cartel zone -- moved outside it.", "basic"] spawn AP_fnc_handleMessage;
                };
            } forEach ([] call AP_fnc_cartelCfg);
            // owner 2026-07-27: the RELOG teleport. This branch never opens the spawn menu, so it is the one
            // place a returning player leaves the 50km slot hold -- end the hold here, restore simulation and
            // zero velocity (setPos preserves it; arriving with fall speed kills the player on landing).
            // Snap to the saved spot, THEN enable simulation. Two things this has to respect, both measured:
            //   1. OWNERSHIP. A setPos from a machine the unit is not local to is overwritten by the owner's
            //      replicated position. Logged on 2026-07-27 b0106: the snap landed at 166.2 and 0.08s later
            //      the player was back at the sqm slot [5826.91,6873.62,50324.5] and free-falling. Waiting for
            //      `local player` is what makes the snap stick; without it this branch cannot work at all.
            //   2. ORDER. Simulation goes on AFTER the move -- this runs scheduled, so any gap between
            //      un-freezing and moving is spent falling from 50km -- and velocity is zeroed across it,
            //      because setPos preserves velocity and a fast arrival is fatal on landing.
            diag_log format ["[TPTRACE] initCiv/relog BEFORE pos=%1 sim/local=%2 slp=%3 water=%4",
                getPosASL player, [simulationEnabled player, local player],
                AP_ses_last_pos, surfaceIsWater AP_ses_last_pos];
            private _localWait = diag_tickTime + 15;
            waitUntil { uiSleep 0.05; (local player) || {diag_tickTime > _localWait} };
            if (!local player) then {
                diag_log format ["[LB-SPAWNHOLD] relog: unit still not local after 15s -- snapping anyway (%1)", netId player];
            };
            // 3. THE MOVE HAS TO BE RE-ASSERTED -- AFTER THE RELEASE, NOT BEFORE IT. b33403e held the player
            //    frozen and polled until the position stopped moving, on the theory that the server contests
            //    the snap for 0.08-0.59s and the release had to wait that window out. Paired client+server
            //    probes killed that theory on 2026-07-27: the frozen settle reported "0 re-applies" (nothing
            //    contested it at all, in 0.78s of waiting) and the snap-back landed ~40ms AFTER
            //    enableSimulation, not during the wait.
            //    The mechanism is simpler than a race. A setPos on a unit whose simulation is DISABLED does
            //    not propagate: while the client showed the player at 69.4 ASL the SERVER showed 50324.5 for
            //    the entire frozen period. Re-enabling simulation re-syncs the unit from its last NETWORKED
            //    position -- the 50km sqm slot -- and it falls from there. Which also means a poll loop run
            //    while frozen can only ever read back its own local write; it is structurally incapable of
            //    detecting the thing it was added to detect. The pre-release settle is therefore GONE (it
            //    cost up to 0.8s of login and measured nothing), and the position is instead re-asserted for
            //    ~2s AFTER simulation comes back, which is the only window that is actually contested.
            private _tgt = AP_ses_last_pos;
            private _water = surfaceIsWater _tgt;   // pick the frame ONCE -- every setPos and every compare below uses it
            AP_spawnSettling = true;               // stays true through the POST-release hold too, so the initPlayerLocal watchdog cannot act inside it
            if (_water) then {player setPosASL _tgt} else {player setPosATL _tgt};
            player setVelocity [0, 0, 0];
            // PR10: move the NETWORKED copy first. The re-sync below restores the unit's last networked
            // position, which for the whole frozen hold is still the 50 km slot (a frozen setPos never
            // leaves this machine) -- that snap-back is the "1 re-applies" on nearly every [TPTRACE] line,
            // and the simulated instant spent at 50 km is what latches the freefall animation and shows
            // every other player a body dropping off the slot. APS_fnc_preSpawnPos sets the server copy to
            // the target (owner-checked, own unit only) while we are still frozen and therefore not
            // streaming; the short sleep is one server frame + wire so it lands before the release. The
            // re-assert loop below stays as the safety net either way.
            [[player, _tgt, _water], "APS_fnc_preSpawnPos", 2] call AP_fnc_MP;
            uiSleep 0.3;
            player enableSimulation true;
            // Same breath, no tick in between: the re-sync arrives ~40ms after this, so re-assert NOW rather
            // than waiting for the hold loop's first sleep. setPos preserves velocity -- zero it every time.
            if (_water) then {player setPosASL _tgt} else {player setPosATL _tgt};
            player setVelocity [0, 0, 0];
            // Stand up. Arriving from the 50km hold means arriving out of a freefall animation, and the
            // engine reads that as a landing and drops the player prone. setUnitPos cannot fix this --
            // BIKI: it "will not change the stance of the human player" -- playAction is what moves a
            // player's stance.
            player playActionNow "PlayerStand";
            // Now hold it against the re-sync: ~2s at 0.1s. Any sample more than 2m off target is a yank --
            // re-apply AND zero velocity, because a re-apply mid-fall without zeroing just leaves them
            // falling from the new spot. Exit early after 5 consecutive clean samples (0.5s of stillness,
            // an order of magnitude past the ~40ms the snap-back took to arrive) so a normal login is not
            // pinned for the full 2s. vectorDistance, not distance: `distance` re-reads array coordinates as
            // PositionAGL (BIKI), which would silently compare an ATL/ASL target against a re-framed current
            // position; vectorDistance is raw Euclidean on the numbers we actually set.
            private _t0 = diag_tickTime;
            private _deadline = _t0 + 2;
            private _stable = 0;
            private _applies = 0;
            while {_stable < 5 && {diag_tickTime < _deadline}} do {
                uiSleep 0.1;                    // sleep FIRST: the clean samples must postdate the last re-apply
                private _cur = if (_water) then {getPosASL player} else {getPosATL player};
                if ((_cur vectorDistance _tgt) > 2) then {
                    if (_water) then {player setPosASL _tgt} else {player setPosATL _tgt};
                    player setVelocity [0, 0, 0];   // setPos preserves velocity -- zero it on EVERY re-apply
                    _applies = _applies + 1;
                    _stable = 0;
                } else {_stable = _stable + 1;};
            };
            // Stand them, DETERMINISTICALLY, now that the position has settled. playActionNow above goes
            // through the animation state machine, and when the release yanked the player to 50 km for a
            // frame the machine was mid freefall->landing -- it ate the request and left them prone for
            // ~20s (client probe 2026-08-20: halofreefall at t+7, prone t+10..t+29). switchMove snaps the
            // state outright -- the same idiom initPlayerLocal.sqf:26 uses on this exact animation -- and
            // running it after the settle loop means nothing re-evaluates the stance behind our back.
            // Skipped on water: the engine must keep the swim state there.
            if (!_water) then {player switchMove "AmovPercMstpSnonWnonDnon";};
            private _off = (if (_water) then {getPosASL player} else {getPosATL player}) vectorDistance _tgt;
            // THE number this fix turns on. On a login that previously ended in a 50km fall, re-applies must
            // be >= 1; a persistent 0 here would mean the post-release window is not the contested one either.
            // `stable` at exit < 5 means it never settled inside the 2s -- read it with the offset.
            diag_log format ["[TPTRACE] initCiv/relog post-release hold %1s, %2 re-applies, stable=%3, final offset %4m, frame=%5",
                ((diag_tickTime - _t0) toFixed 2), _applies, _stable, (_off toFixed 2), (if (_water) then {"ASL"} else {"ATL"})];
            AP_spawnHold = false;
            AP_spawnSettling = false;
            diag_log format ["[TPTRACE] initCiv/relog released at %1 (wanted %2)", getPosASL player, _tgt];
            diag_log format ["[TPTRACE] initCiv/relog AFTER  pos=%1 sim/local=%2 terrain=%3",
                getPosASL player, [simulationEnabled player, local player],
                getTerrainHeightASL [AP_ses_last_pos select 0, AP_ses_last_pos select 1]];
        } else {[] call AP_fnc_spawnMenu;
            // owner 2026-09-11: display 38500 belongs to the NATIVE spawn menu only. On the web path
            // (AP_fnc_spawnWebOpen, dialog 938700) fn_spawnMenu has ALREADY blocked until the player
            // deployed, so there is nothing left to wait for -- and waiting for a display that never
            // appears would hang this login for the rest of the session.
            if !(missionNamespace getVariable ["AP_spawnMenuWeb", false]) then {
                waitUntil {!isNull(findDisplay 38500)};
                waitUntil {isNull(findDisplay 38500)};};};} else {
        // owner 2026-07-11: THE INTAKE Act 1 -- a fresh account (players.intake_path = 0, veterans are
        // grandfathered to 9) never sees the spawn menu: they wake up committed inside the Loony Bin
        // (cinematic -> padded-ward basics -> interview -> release into Kavala). Disconnecting mid-intake
        // leaves the flag 0, so it simply runs again next login. Everyone else: spawn menu as always.
        if (AP_intakePath isEqualTo 0) then {["start"] spawn AP_fnc_intake;} else {[] call AP_fnc_spawnMenu;
            // owner 2026-09-11: display 38500 belongs to the NATIVE spawn menu only. On the web path
            // (AP_fnc_spawnWebOpen, dialog 938700) fn_spawnMenu has ALREADY blocked until the player
            // deployed, so there is nothing left to wait for -- and waiting for a display that never
            // appears would hang this login for the rest of the session.
            if !(missionNamespace getVariable ["AP_spawnMenuWeb", false]) then {
                waitUntil {!isNull(findDisplay 38500)};
                waitUntil {isNull(findDisplay 38500)};};};};};
// owner 2026-07-11 (PAROLE PAPERS, Act 2): a relog mid-arc resumes the contract chain from the persisted
// step (players.intake_step, login payload slot 39). Fresh intake sessions start it themselves.
// Parole Papers removed: its launcher lived here. A new opening questline replaces it.
// owner 2026-06-21 (PFH leak): register the 240s civ save-loop ONCE per session. fn_initCiv re-runs within a
// session, and the custom PFH system has NO removePerFrameHandler + this call never captured its handle ->
// duplicate handlers ACCUMULATED -> the same position+gear save fired 2-3x per cycle (confirmed live: Spark /
// kiosk / Mr player104 each saved position 3x within 5s), tripling the holding-area position-blank odds + the log
// spam. Guard on a handle in AP_civSavePFH (reset to nil per connect in init.sqf next to the
// AP_eachFrameHandlerArray reset) so exactly one handler exists per session.
if (isNil "AP_civSavePFH") then {AP_civSavePFH = [{if (alive player) then {[10] call AP_fnc_ClupdatePartial;
            // owner 2026-06-19 (kit-loss-on-restart cluster #408/#409/#413/#414/#416/#417/#418): civ gear was persisted
            // ONLY on an inventory CHANGE (handleInv/saveGear) and at the T-55 scheduled-restart sync. A crash / deploy /
            // manual hard-restart (watchdog pkill -> no disconnect handler fires) reverted gear to the last change-save =
            // "lost my kit". Persist worn gear every cycle too. saveGear self-gates (arrest / dead / near-cop-spawn) and
            // mode-3 self-dedups (AP_lastSynced_gear), so this only writes when the kit actually changed -> an ungraceful
            // exit now loses <=4 min, not the whole loadout. Skip during clothing-store edits (finalized on store close).
            if (AP_clothing_store isEqualTo "") then { [true] call AP_fnc_saveGear; };};}, [], 240] call AP_fnc_addPerFrameHandler;};
// owner 2026-06-21: REMOVED the proximity fed-alarm trigger. The alarm used to trip from standing inside fedWalls
// on foot, holding any robbery item, on a random roll (the "fed triggers too easy" report #449). Per owner, the
// Federal Reserve alarm now fires ONLY when a gate is bolt-cut (fn_openGate sends hack request to server) or a
// dome side door is hacked (fn_openVault sends hack request to server); the server validates the hack in fn_iceTrace
// and calls APS_fnc_fedRobbery server-side. The matching server-side UNMASKED-ENTRY-within-175m trigger
// in AP_server/init.sqf is removed too. (Nothing replaces this per-frame handler -- the robbery is action-driven now.)
[{if (((A_stats_crimes param[0, 0]) > 10000)) then {private _toSend = (allPlayers - [allDeadMen] - [player]) select {
            side _x isEqualTo west || (side _x isEqualTo civilian && _x getVariable["AP_isBountyHunter", false])};
        if ((round(random 1)) isEqualTo 0) then {
            private _nearTown = (player distance(getMarkerPos "city") < 250) || (player distance(getMarkerPos "donor_town") < 250) || (player distance(getMarkerPos "civ_spawn_2") < 250) || (player distance(getMarkerPos "civ_spawn_3") < 250) || (player distance(getMarkerPos "civ_spawn_4") < 250);
            if (_nearTown) then {[[7, profileName, "0", player], "AP_fnc_clientMessage", _toSend] spawn AP_fnc_MP;} else {
                private _marker = [allMapMarkers, player] call BIS_fnc_nearestPosition;
                if ((getMarkerColor _marker) in ["ColorRed", "ColorEast"]) then {if !("_USER_DEFINED" in _marker) then {
                        if ((player distance2D(getMarkerPos _marker) < 300)) then {[
                                [7, profileName, "1", player], "AP_fnc_clientMessage", _toSend] spawn AP_fnc_MP;};};};};};};
}, [], 300] call AP_fnc_addPerFrameHandler; [{if (!license_civ_bounty || !(8 in AP_side_talents)) then {
        if (alive player && !(AP_isDead)) then {private _currentWeapon = primaryWeapon player;
            if (_currentWeapon in ["arifle_MX_F", "arifle_MXC_F", "arifle_MX_khk_F"]) then {
                private _gwh = createVehicle["GroundWeaponHolder", getPosATL player, [], 0, "CAN_COLLIDE"];
                private _gItems = primaryWeaponItems player;
                player removeWeapon(primaryWeapon player);
                _gwh addWeaponCargoGlobal[_prev, 1]; {_gwh addItemCargoGlobal[_x, 1]}
                forEach _gItems;
                ["You cannot carry an MX without a BH License and the Master Bounty Hunter Talent!", "basic"] spawn AP_fnc_handleMessage;
            };};};}, [], 10] call AP_fnc_addPerFrameHandler;
if ((license_civ_bounty)) then {
    // owner 2026-06-20 (#447, decision A = NO bounty persistence): this fired a per-connect SELECT on the (always
    // empty) `bounties` table and MP'd to AP_fnc_persistentBounties, which doesn't exist -- the whole persistence
    // chain is half-built (requestBounty never writes the table, no receiver fn, target/hunter query mismatch) and
    // was the source of the old "BH stuck tracking a $0 ghost" bug. Bounties intentionally do NOT survive a relog;
    // the BH re-requests after login. Trigger disabled. To re-enable (decision B) restore this + build the save side.
    // [[getPlayerUID player], "APS_fnc_srvPersistentBounties", 2] spawn AP_fnc_MP;
    player setVariable["AP_isBountyHunter", true, true];};
AP_maxTalents = 20;
[] call AP_fnc_verifyTalents;
[] spawn AP_fnc_trackMarkers;
if (SRV_ufoCrash select 0) then {uiSleep 5;
    [(SRV_ufoCrash select 3)] spawn AP_fnc_ufoCrash;};
[] spawn AP_fnc_serverInfoMessages;
if (true) then {
    if ((A_stats_civTime <= 180) || ((profileNamespace getVariable["AP_tutorialProgress", -1]) < 14) && (A_stats_civTime <= 180)) then {
        [] spawn {uiSleep 5;
            [] spawn AP_fnc_tutorialNewPlayer;};} else {if (A_stats_civTime >= 180 && A_stats_civTime <= 360) then {
            [format["<t color='#FF0000'><t size='1.5'><t align='center'>Tutorials<br/><br/></t></t></t>We see that you have completed our message tutorials but you are still a fairly new player, we'd like to give you a friendly reminder that you can always checkout the tutorials in your phone by pressing y and clicking on the tab tutorials"], "warning"] spawn AP_fnc_handleMessage;
        };
        profileNamespace setVariable["AP_tutorialProgress", 14];};
    // LooneyBin (owner, 2026-06-11): passive mode for new players REMOVED -- no auto-enable, no "new player is
    // invulnerable" message. New players spawn vulnerable like everyone else.
};
[] spawn {uiSleep 30;
    AP_loginBonusData params["_playerUID", "_consecutiveDays", "_needsGift", "_wipeProgress"];
    if ((_needsGift)) then {
        ["You have a login bonus available for you! Type !loginbonus to retrieve it.", "login_bonus"] spawn AP_fnc_handleMessage;};};
[] spawn {if (!("winter" in SRV_enabledSeasonalEvents)) exitWith {};
    uiSleep 30;
    AP_christmasTreeGiftData params["_playerUID", "_needsGift"];
    if ((_needsGift)) then {
        ["You have not opened your christmas gift yet, go to the christmas tree to open your gift.", "christmas_present"] spawn AP_fnc_handleMessage;
    };};
[] spawn {uiSleep 8;
    private _nearbyBoomBoxes = player nearObjects["Land_BatteryPack_01_closed_black_F", 350];
    if (_nearbyBoomBoxes isNotEqualTo[]) then {{["initMusic", [_x]] spawn AP_fnc_boomBox;}
        forEach _nearbyBoomBoxes;};};
[] spawn {uiSleep 10;
    ["missedMessages"] spawn AP_fnc_initGangBoatClient;};

// owner 2026-07-12: everyone carries a GPS -- the map's G-search / route HUD is gated on it
if !("ItemGPS" in assignedItems player) then { player linkItem "ItemGPS"; };
// owner 2026-07-15: re-link after a beat -- fn_loadGear (login/respawn gear restore) can strip assignedItems
// AFTER this init runs, leaving civs GPS-less. A short delayed re-link survives that clobber.
[] spawn { uiSleep 6; if (alive player && {!("ItemGPS" in assignedItems player)}) then { player linkItem "ItemGPS"; }; };
