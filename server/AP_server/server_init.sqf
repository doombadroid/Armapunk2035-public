
// LooneyBin: AP_UsingHeadless was NEVER defined anywhere, so the diag_log + `if (AP_UsingHeadless)`
// below threw "Undefined variable" and HALTED server_init.sqf before the HandleDisconnect EH (and
// eventhandlers.sqf) were ever added -> disconnect cleanup never ran (corpse left at feet, no final
// flush). No headless client in this deployment -> false.
if (isNil "AP_UsingHeadless") then { AP_UsingHeadless = false; };
AP_radio_dispatch = radioChannelCreate [[0, 0, 1, 1], "MaxSec Dispatch", "%UNIT_NAME", []];
AP_radio_RF = [radioChannelCreate [[0.8,0,0.6,0.9], "Radio Chan 1", "%UNIT_NAME", []],
radioChannelCreate [[0.8,0,0.6,0.9], "Radio Chan 2", "%UNIT_NAME", []],
radioChannelCreate [[0.8,0,0.6,0.9], "Radio Chan 3", "%UNIT_NAME", []]];
// owner 2026-06-13: phone-call line pool. handlePhoneCallSRV seeds AP_phoneCalls from these (valid/non-zero
// channels only) -> this is the max CONCURRENT calls. Bumped 5 -> 10 for headroom; any that exceed Arma's
// channel cap come back 0 and are skipped by the handler, so over-allocating here is harmless.
AP_phone_groups = [[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []],
[radioChannelCreate [[0.8,0,0.6,0.9], "Cell Phone", "%UNIT_NAME", []], []]];

// FACTION REWORK -- duty framework master switch. TRUE as of PR7, the flip: mission.sqm ships 60 civilian
// slots and nothing else, so MaxSec and Trauma exist ONLY through this. With it on, "init" below creates
// the two persistent groups, the roster, the cooldown maps and the stale-roster sweep, and the two HQ
// terminal actions appear.
//
// IT IS STILL THE KILL-SWITCH, and that is why the variable and every gate keyed on it survive the flip.
// Counted over mission/ + server/ (.sqf/.hpp/.fsm/.ext/.h), case-insensitive, with comment text excluded --
// state the method or the number rots, and the three numbers this line used to carry had each been measured
// a different way: 17 code occurrences of AP_dutyEnabled (15 gate reads plus the write and the
// publicVariable two lines below), 46 APS_fnc_isDutyCop call sites, 1 APS_fnc_isDutyMed call site.
// set this back to false and redeploy and the world runs as a plain all-civilian server -- the terminals
// vanish, APS_fnc_dutySRV exits at its first line, nobody can sign on, and every compat clause falls back
// to its pre-duty reading. Rolling back is one boolean, not a revert of PRs 1-6.
//
// THE ONE THING THAT MUST NEVER BE SPLIT: the compat clauses key on this flag ALONE. Ship it true against
// a mission.sqm that still has west/independent slots and anyone standing on one loses all faction
// authority the moment the server boots -- authority comes from the roster now, and a lobby slot puts
// nobody on it. Flag and slots are one deployable unit, in both directions.
// THE SERVER READS ITS OWN COPY FROM localNamespace (audit Lsec-0-1): a client's publicVariable overwrites
// missionNamespace on the server too, and `AP_dutyEnabled = false` from any client turned APS_fnc_isDutyCop
// back into a bare side test. The published copy below is display-only (terminals, landing screen). A RUNTIME
// flip therefore has to write both: the bot_commands verb "dutyswitch" (init.sqf) does, DUTY_SOAK.md section E. THE SWITCH IS THE LITERAL ON THE NEXT LINE; the
// global is derived from it, never read back into it (a scheduled script can be preempted between the two).
localNamespace setVariable ["AP_dutyEnabled", true];
AP_dutyEnabled = localNamespace getVariable "AP_dutyEnabled";
publicVariable "AP_dutyEnabled";
SRV_dutyCooldown = 600;   // seconds after a release before the same uid may sign on again
SRV_dutyNakCooldown = 30; // fn_dutySRV.sqf "nak" case: a short cooldown for an ABORTED grant, not a real
                          // shift -- backdated into the same AP_dutyCooldown stamp so :285's one gate formula
                          // (measured against SRV_dutyCooldown) still does the arithmetic.
// fn_dutySRV.sqf "payoff" case: what a MaxSec officer pays to settle their OWN bounty at the duty terminal
// and sign on, as a multiple of the wanted row's stored total (APS_wantedList index 3 -- the same figure an
// arresting officer is paid). 1.0 = face value, which is the owner ruling as given (2026-08-20: "they pay it
// off themselves ... instead of hunting for another cop to pardon them"); raise it to make buying out of your
// own bounty deliberately worse than being pardoned, lower it for a policing discount. THE PRICE IS ONLY EVER
// COMPUTED SERVER-SIDE -- the client is told what it costs and never the other way round -- and the server
// reads this through a getVariable default of 1, so an addon that predates the var prices at face value
// rather than throwing inside a money path.
// Both live in localNamespace, not as globals: a published-or-not global is still one client publicVariable
// away from a $1 bounty buyout (audit Lsec-0-1).
localNamespace setVariable ["SRV_dutyBuyoutMult", 1.0];
localNamespace setVariable ["SRV_dutyBountyGate", false];   // owner 2026-09-06: a bounty no longer blocks MaxSec sign-on/clock-off (fn_dutySRV); true restores the buyout gate

// SERVER-OWNED PUBLISHED FLAGS: THE DISPLAY COPY IS PUT BACK WHEN A CLIENT OVERWRITES IT (audit Lsec-0-1).
// Every server-side read of these goes to localNamespace, which the network cannot write, so a forged
// publicVariable no longer changes what the server decides. It still overwrites the missionNamespace copy
// that every other client displays -- and four reads in core/DB/ still go to missionNamespace until that
// layer moves to localNamespace too -- so the server restores its own value and re-publishes it. The
// server's own publicVariable never fires this (the EH runs only on receiving machines), and no client
// legitimately publishes any of these names. The engine does not say WHO sent a publicVariable, so the row
// is attributed to the server; the subject is never taken from the payload.
{
    _x addPublicVariableEventHandler {
        params ["_name", ["_value", "nil"]];
        ["-SEC-", objNull, format ["BLOCKED client publicVariable of server-owned %1 (sent %2); server value restored", _name, (str _value) select [0, 120]]] call APS_fnc_logIt;
        missionNamespace setVariable [_name, localNamespace getVariable _name];
        publicVariable _name;
    };
} forEach ["AP_dutyEnabled", "AP_betaZeroCops", "AP_fabFreeBuild", "AP_priceOv", "AP_purgeZone", "AP_devAutoAdmin", "SRV_grantNewbieRoles", "SRV_governorData", "AP_foreskinReg"];

// PHASE 9's OWN KILL-SWITCH, and it is a SEPARATE switch from AP_dutyEnabled on purpose. The landing screen
// is not part of the duty framework: it is the connect-time UX that replaced the lobby welcome's PLAY gate,
// and it works perfectly well with duty turned off (solo is always available; the MaxSec and Trauma cards
// are pushed locked with "DUTY SYSTEM OFFLINE"). So a bad landing must be revertible without also taking
// the shifts down, and a bad duty framework must be revertible without also taking the welcome screen down.
// FALSE = AP_fnc_landingOpen declines and fn_initCiv runs the pre-PR9 flow verbatim -- the lobby welcome's
// PLAY gate, then the spawn menu. Nothing else in the tree keys on this flag: there is no landing state to
// unwind, because the screen only ever forwards to paths that already existed.
// READ THROUGH A getVariable DEFAULT OF TRUE on the client (fn_landingOpen), same as SRV_baseNoSaveRadius
// below, so a client that has not yet received the publish behaves identically to one that has.
SRV_landingEnabled = true;
publicVariable "SRV_landingEnabled";

// THE 3D SPAWN SCREEN'S KILL SWITCH (owner 2026-09-11). ui\html\spawn.html (dialog 938700) replaces the
// native spawn menu (dialog 38500) for every path -- first spawn, respawn and redeploy, all three sides.
// Set this false and redeploy and AP_fnc_spawnWebOpen declines at its first gate: fn_spawnMenu and
// fn_redeployMenu each fall through to the native dialog they have always opened, byte for byte, and
// nothing else in the tree keys on the flag. There is no spawn state to unwind, because the web screen
// commits through AP_fnc_spawnConfirm -- the SAME function the native SPAWN button calls -- rather than
// teleporting anyone itself.
// SEPARATE from SRV_landingEnabled on purpose, the same way that one is separate from AP_dutyEnabled: the
// landing screen and the spawn screen are met one after the other on a single connect, and a bad one of
// them must be revertible without taking the other down.
// READ THROUGH A getVariable DEFAULT OF TRUE on the client, same idiom as above, so a client that has not
// yet received the publish behaves identically to one that has.
SRV_spawnWebEnabled = true;
publicVariable "SRV_spawnWebEnabled";

// THE VERTICAL CITY TOWER'S KILL SWITCH (owner 2026-09-22). custom_p3ds\vcity_tower.sqf assembles the
// ap_vcity tower where skyscraper30 stood. False = the script declines and NO tower is placed -- the
// old skyscraper30 row was soft-deleted in the same change, so a full rollback is restoring the rows in
// deploy/map_backups/vcity_site_20260922.sql first. Server-only; not published (clients never read it).
SRV_vcityEnabled = true;

// THE DEATH SCREEN'S KILL SWITCH (owner 2026-09-11, the approved FLATLINED design). ui\html\death.html
// (dialog 938800) replaces the native DeathScreen (dialog 7300) over the real corpse camera. Set this false
// and redeploy and AP_fnc_deathWebOpen declines at its first gate: evh\fn_onPlayerKilled.sqf creates dialog
// 7300 and runs the native readout exactly as before. Nothing else keys on the flag, and there is no death
// state to unwind -- fn_onPlayerKilled owns both clocks, the pause/extend and the automatic respawn on BOTH
// paths, and the web screen only renders what that thread publishes.
// SEPARATE from SRV_spawnWebEnabled deliberately: the death screen hands off to the spawn screen, so the two
// are met back to back and a bad one of them must be revertible without taking the other down.
// READ THROUGH A getVariable DEFAULT OF TRUE on the client, same idiom as above.
SRV_deathWebEnabled = true;
publicVariable "SRV_deathWebEnabled";

// MOVEMENT KILL SWITCHES (owner 2026-09-16: parkour, wall running, body drag). Server-owned and
// publicVariable'd so a feature that misbehaves in front of players is one edit and a restart away from
// gone, with no mission repack. Each is read on the client through a getVariable default of TRUE, so a
// client that joins before the publish arrives behaves as if the feature is on.
//   SRV_parkourEnabled  false -> AP_fnc_parkour declines; V falls back to the old running hop (AP_fnc_jump).
//   SRV_wallRunEnabled  false -> the probe skips the side scan; vault/mantle/drop are untouched.
//   SRV_dragBodyEnabled false -> the "Drag body" action never shows and AP_fnc_dragBody refuses; an active
//                             drag is released by its watchdog on the next tick.
SRV_parkourEnabled = true;
publicVariable "SRV_parkourEnabled";
SRV_wallRunEnabled = true;
publicVariable "SRV_wallRunEnabled";
SRV_dragBodyEnabled = true;
publicVariable "SRV_dragBodyEnabled";

// LUXE AV (owner 2026-09-22, addon ap_av, APS_fnc_avSRV): the autonomous air taxi. Kill switch read through a
// getVariable default of TRUE on both sides. AP_avDest = the preset destinations shown to passengers:
// [label, [x, y]] -- each is a DESIGNER-PLACED helipad (map_objects row in the comment) checked free of
// other rows within 9 m on 2026-09-22. The server cannot see streamed map objects, so a new entry must be a
// pad verified the same way (tools/map_query.py near X Y 9), never an arbitrary street corner.
SRV_avEnabled = true;
publicVariable "SRV_avEnabled";
AP_avDest = [
    ["Larche Helipad",        [6153.6, 8563.3]],   // row 8250 Land_HelipadCircle_F
    ["North Coast Heliport",  [7932.3, 9063.6]],   // row 6989 Land_HelipadCivil_F
    ["Chapoi Clinic Pad",     [6098.4, 3651.3]],   // row 8009 Land_HelipadRescue_F
    ["La Port Helipad",       [7677.1, 3689.2]],   // row 8251 Land_HelipadCircle_F
    ["West Clinic Pad",       [3044.9, 6158.8]],   // row 8011 Land_HelipadRescue_F
    ["Mountain Heliport",     [4581.7, 7077.8]]    // row 6987 Land_HelipadCivil_F
];
publicVariable "AP_avDest";

// THE BASE NO-GEAR-SAVE RING, in metres, measured from the respawn_west marker. It is READ ON THE CLIENT
// -- fn_saveGear.sqf, fn_ClupdatePartial.sqf's case 3 and fn_ClupdateRequest.sqf all test it -- so it has
// to be published, and every one of those three reads it through a getVariable default of 75 so a client
// that has not yet received the publish behaves identically to one that has.
// WHY 75 AND NOT THE OLD HARDCODED 1000. respawn_west sits AT the MaxSec HQ terminal (cop_spawn_2,
// [10502, 4048]) as of PR6, and a 1000 m ring drawn from there swallows two heist targets whole:
// fed_reserve is 808 m away and jail_marker2 (the Prison) 751 m. Inside the ring no gear save persists,
// which is a dupe in one direction (spend/drop inside it, disconnect, and the DB rolls the items back)
// and a loss in the other (loot the Fed, time out, keep nothing). 75 m covers the HQ compound and only
// the HQ compound -- the farthest marker inside it is air_spawn_4 at 46.3 m, and the next-nearest thing
// on the map is 751 m out, so there is ~700 m of clearance either side of the number.
// The ring is a base-camping guard, not a persistence policy; if the HQ ever grows, widen this rather
// than reintroducing a literal at the three call sites.
SRV_baseNoSaveRadius = 75;
publicVariable "SRV_baseNoSaveRadius";
// APS_fnc_dutySRV's headcount helper. Defined HERE, at boot, whatever the flag says -- not inside the
// "init" case: that case also runs at RUNTIME (bot verb "dutyswitch" on a server that booted false), and a
// compileFinal first assigned then can be pre-empted by any client's publicVariableServer of a final copy
// (a broadcast final stays final), which would then run server-side on every roster change. It has to be a
// GLOBAL because the watchdog spawn and the scheduler's sweep job do not inherit the caller's privates.
// APS_, not AP_: server-only and unregistered (this assignment IS the definition), and the server compiles
// BOTH CfgFunctions trees into one missionNamespace, so an AP_ name is one client function away from a clash.
// Harmless with the flag false: it exits on a nil roster.
APS_fnc_dutyRecount = compileFinal {
    if (isNil {localNamespace getVariable "AP_dutyRoster"}) exitWith {};
    private _cop = 0;
    private _med = 0;
    {
        switch (_y param [0, ""]) do {
            case "maxsec": { _cop = _cop + 1; };
            case "trauma": { _med = _med + 1; };
        };
    } forEach (localNamespace getVariable "AP_dutyRoster");
    if (isNil "AP_dutyCopCount" || {AP_dutyCopCount isNotEqualTo _cop}) then { AP_dutyCopCount = _cop; publicVariable "AP_dutyCopCount"; };
    if (isNil "AP_dutyMedCount" || {AP_dutyMedCount isNotEqualTo _med}) then { AP_dutyMedCount = _med; publicVariable "AP_dutyMedCount"; };
};
["init"] call APS_fnc_dutySRV;

// TEXAS HOLD'EM (APS_fnc_holdemSRV). Server-only -- the page is told the numbers in every state push
// and never carries them as literals, so these are the single source and changing them needs no client
// repack. NOT publicVariable'd for that reason.
// THE NUMBERS, and why. The casino's own bet band is $10k-$500k (fn_casinoData's clamp, and
// APS_fnc_bjTableSRV's BJ_MIN_BET/BJ_MAX_BET), so a $10k big blind puts one hold'em bet at the floor of
// what the rest of the floor already takes, and the designer's page demos at exactly 5k/10k. The buy-in
// band is then 20-100 big blinds, which is the normal live-poker spread: deep enough that position and
// betting matter, shallow enough that one cooler is not somebody's week. The page's own chip ladder
// renders $200k / $250k / $500k / $1M off these two numbers.
// HOLD'EM IS NOT A SINK. There is no house hand and, at SRV_holdemRake = 0, no cut: every chip that
// leaves one player's bank arrives in another's. That is a deliberate default for a table whose whole
// appeal is playing the room, but it means hold'em adds nothing to the inflation posture the rest of the
// casino was tuned for. SRV_holdemRake is the lever -- a percent taken off each pot before it is shared,
// clamped 0-5 by the engine and written to the `log` table as its own row so it is auditable the moment
// it is non-zero. Owner's call, not mine.
SRV_holdemBlinds = [5000, 10000];       // small blind, big blind
SRV_holdemBuyIn  = [200000, 1000000];   // 20 - 100 big blinds
SRV_holdemActMs  = 20000;               // turn clock in ms (engine clamps 5000-120000)
SRV_holdemNextMs = 6000;                // rest between hands in ms
SRV_holdemRake   = 0;                   // percent of each pot to the house; 0 = winner takes the pot

// THE KILL-SWITCH, AND IT IS A MONEY SWITCH. The five numbers above change how the table plays; this
// one exists because AP_holdemTable is MEMORY AND NOTHING ELSE. A player's buy-in leaves a real
// `players.bankacc` row the moment they sit down and comes back only when they stand up -- so a
// stack still sat on a seat when the process dies is money that exists nowhere. Six seats at the
// $1M cap is $6M a restart could evaporate, and nobody would know which six rows to make good.
//
// FALSE closes the table AND EMPTIES IT: APS_fnc_holdemSRV refuses sit / act / open, deals no
// further hands, and on its very next entry -- the 1 s wheel tick, or whatever anybody does first if
// the wheel is down -- runs its "drain" case. The drain ABORTS any live hand rather than settling it
// (nobody wins an aborted pot): every chip committed goes back to whoever committed it, then every
// remaining stack is banked. All of it by UID, so a seat whose player is already disconnected or
// still on a loading screen banks exactly like one stood at the felt, and every movement is its own
// -CASINO-HOLDEM- row written after the bank row was read back and confirmed.
// TRUE re-opens it, empty. Flipping it does not double-refund: the drain runs once per flip.
//
// THE DEPLOY PROCEDURE, because a restart is the case this was built for:
//   1. SRV_holdemEnabled = false; publicVariable "SRV_holdemEnabled";   (debug console, server exec)
//   2. wait for [HOLDEM] DRAIN (…) in the RPT -- one line, with the movement count and the total
//   3. deploy / restart
// Steps 1-2 are wired automatically at the three points a restart is actually announced on this
// codebase and you should not normally have to do them by hand:
//   * init.sqf's 4-hour cycle, at the T-5 feature lock beside serverRestartLock
//   * init.sqf's bot_commands "gracefulsave" -- every !srv softr / hardr and every deploy
//   * APS_fnc_changeServCycle, at T-0 of an in-game HARD / UPDATE restart
// A crash or a raw pkill still loses the table; nothing script-side can catch those, which is why
// the lever is a lever and not only a hook.
//
// PUBLISHED, unlike the five tunables above: the table's own state pushes carry the numbers, but a
// client has no way to learn the table is shut without asking, and a page that shows a live felt
// nobody can sit at is worse than one that says CLOSED. Every read is through a getVariable default
// of TRUE (the SRV_landingEnabled idiom), so a client -- or a server file deployed ahead of this
// one -- that never sees the publish behaves exactly as shipped.
SRV_holdemEnabled = true;
publicVariable "SRV_holdemEnabled";

// The turn clock and the deal pump, on the single wheel rather than a permanent spawn (singleevh.md).
// 1 s is the wheel's own base granularity, and the job is cheap: it pushes only when the hand actually
// moved. runAtStart / no jitter, because a table that deals late by a random offset on boot looks stuck.
// The engine does not depend on this job for correctness -- every client-reachable case runs the same
// pump first -- so if the wheel ever auto-disables it, the table degrades to advancing on interaction
// instead of freezing. That is the design, not a happy accident; see the file header.
["holdemClock", { ["tick"] call APS_fnc_holdemSRV; }, 1, true, false] call AP_fnc_schedule;

diag_log format["AP_UsingHeadless = %1", AP_UsingHeadless];
if (AP_UsingHeadless) then {publicVariable "AP_radio_dispatch";
publicVariable "AP_radio_RF";
publicVariable "AP_phone_groups";};

addMissionEventHandler ["HandleDisconnect", {if (!isServer) exitWith {};
// owner 2026-07-16 INCIDENT FIX: the autopilot HC (HC1) is NOT mission-critical. The old code ended
// the mission (BIS_fnc_endMission) whenever HC1 dropped -> every autopilot-HC reconnect booted the whole
// server. Now an HC disconnect just clears AP_hcOwner (the autopilot features then refuse new
// requests client-side) and NEVER ends the mission. Player disconnects always run on the server.
if (!isNil "HC1" && {!isNull HC1} && {(_this select 0) isEqualTo HC1}) exitWith { AP_hcOwner = 0; localNamespace setVariable ["AP_hcOwner", 0]; publicVariable "AP_hcOwner"; diag_log "[LooneyBin][HC] autopilot HC disconnected -> no driver until it returns (mission kept alive)"; };
[_this select 3,_this select 2, _this select 0] spawn APS_fnc_playerDisconnected;}];

// eventhandlers.sqf (legacy client->server publicVariable handlers) DELETED 2026-09-26: no legitimate publisher
// for any of them, and each one let any client frame/clear wanted, rewrite config (SQL) or move the market.
// The one live flow, the market sell/buy hook, is now the CfgRE-whitelisted APS_fnc_stockUpdate.

// singleevh.md: day/night setTimeMultiplier migrated onto the single-wheel scheduler (id "dayNightTime", 200s).
// Cross-iteration de-dupe local _lastMultiplyer -> per-job state _st["last"]. Flag OFF => original loop runs
// byte-for-byte (else branch) = ZERO behavior change.
["dayNightTime", {params ["_st"];
    // Armapunk 2035 runs PERMANENT DUSK, so the time-of-day clock is parked rather than cycled.
    // Without this the job re-applied a 12x/54x multiplier every 200s, the clock drifted off 16:00,
    // and the client atmosphere loop fought it back with a setDate every few seconds -- which is a
    // full lighting recalculation, so it flashed and dropped frames on every client.
    if (missionNamespace getVariable ["AP_freezeTimeOfDay", false]) exitWith {
        if ((_st getOrDefault ["last", -1]) != 0) then { setTimeMultiplier 0; _st set ["last", 0]; };
    };
    private _multiplier = 12;
    if (sunOrMoon < 1) then { _multiplier = _multiplier * 4.5; };
    if ((_st getOrDefault ["last", -1]) != _multiplier) then { setTimeMultiplier _multiplier; _st set ["last", _multiplier]; };
}, 200, false, true] call AP_fnc_schedule;

// owner 2026-07-10: AUTOMATIC WEATHER CYCLE (sibling of dayNightTime; weather was admin-only -> stayed clear
// forever). Every ~40 min pick weighted-random weather [rain,fog,overcast] and broadcast: SRV_wcweather drives
// every client + JIP via the initPlayerLocal publicVariable handler, and the server applies it too with a
// smooth 120s transition. RESPECTS an admin-forced toggle (AP_wx_rain / AP_wx_snow from APS_fnc_changeWeather)
// -- won't auto-override admin weather until they clear it. Flag OFF => the equivalent legacy loop.
AP_fnc_wxRoll = compileFinal {private _r = random 1;
    // owner 2026-08-04 After-Dark bias: never fully clear, drizzle is the default state,
    // overcast floors at 0.5 so the permanent night sky stays heavy. Same shape/consumers.
    switch (true) do {                                                     // [rain, fog, overcast]
        // After-Dark v11: fog ALWAYS 0 and overcast low — both read as a gray
        // veil at night (verified in-game). Clear is the default; rain is a
        // visitor, not the climate.
        case (_r < 0.60): { [0, 0, 0.05 + random 0.15] };                  // clear night (default)
        case (_r < 0.85): { [0.10 + random 0.15, 0, 0.25 + random 0.2] };  // light drizzle
        default          { [0.35 + random 0.25, 0, 0.45 + random 0.2] };   // real rain
    }}; ["weatherCycle", {params ["_st"];
    if ((missionNamespace getVariable ["AP_wx_rain", false]) || {missionNamespace getVariable ["AP_wx_snow", false]}) exitWith {};
    private _wx = call AP_fnc_wxRoll;
    SRV_wcweather = _wx; publicVariable "SRV_wcweather";
    120 setOvercast (_wx select 2); 120 setRain (_wx select 0); 120 setFog (_wx select 1);
    diag_log format ["[LooneyBin][weather] auto-cycle -> rain %1 / fog %2 / overcast %3", _wx select 0, _wx select 1, _wx select 2];
}, 2400, false, true] call AP_fnc_schedule;

// owner 2026-06-14 (#205): DISABLED the legacy auto-soft-restart. This spawned APS_fnc_rebootMonitor (a
// 30-min "Server Maintenance" countdown -> doRestart/endMission = mission soft-reload) after AP_restart_delay.
// It was never removed when the 4h ALWAYS-HARD scheduler (init.sqf ~line 227) became the sole restart
// authority, so BOTH ran -- the rebootMonitor reload landed right on top of the 4h scheduler's "1 Hour until
// RESTART" warning (RPT 13:50:01 warning -> 13:50:31 mission reload), which players saw as "it gave the 1
// hour msg then immediately restarted" (#195/#205). The 4h hard cycle handles restarts now; rebootMonitor is
// kept only for a MANUAL admin-triggered reboot. Re-enable this block only if the 4h scheduler is removed.
// [] spawn
// {
// waitUntil {!isNil "AP_restart_delay"};
// sleep AP_restart_delay;
// [] spawn APS_fnc_rebootMonitor;
// };