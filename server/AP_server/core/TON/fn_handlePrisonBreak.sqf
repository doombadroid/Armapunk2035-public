/*
    APS_fnc_handlePrisonBreak  (LooneyBin -- implemented 2026-06-09; the passthrough fed
    [mode, unit, uid, group] into 2017 startPrisonBreak [unit, jailID, npc] -> isNull gate killed it
    instantly = PRISON BREAK NEVER STARTED. Mode 2 (cop stop) had no 2017 equivalent at all.)
      [1, player, uid, group]  civ starts the break (core/civilian/fn_doPrisonBreak.sqf)
      [2, player, uid]         cop restores security (core/cop/fn_stopPrisonBreak.sqf)
    SRV_prisonData = [lastBreak(serverTime), active(bool)] -- was NEVER defined anywhere (clients read
    slot 1); init.sqf now publishes it and this keeps it synced alongside 2017's AP_prison_inProgress.
*/
params [["_mode", -1, [0]], ["_unit", objNull, [objNull]], ["_uid", "", [""]], ["_grp", grpNull, [grpNull]]];
// owner 2026-06-23 SECURITY (security.md §2.2): per-mode authz. mode 1 = a civ STARTING the break
// (fn_doPrisonBreak, passes `player`) -> require the starter to BE the real caller. mode 2 = a COP STOPPING it
// (fn_stopPrisonBreak, west-gated client-side) -> require side==west. Ungated, any civ could start/stop the
// prison-break event at will (grief/availability). Derive the caller from remoteExecutedOwner (non-spoofable);
// server-internal passes either mode. _uid is sanitized downstream by APS_fnc_logIt.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0) then {private _ok = switch (_mode) do {case 1: { _unit isEqualTo _caller };
        case 2: { _caller call APS_fnc_isDutyCop };
        default { false };};
    // owner 2026-07-28 SECURITY: SENTINEL, not a bare refusal. This exitWith sits inside the then {}
    // opened above, so on its own it leaves ONLY that block -- execution falls straight through into
    // the switch and a REFUSED call still ran the whole case: it started (or stopped) the break and,
    // since 2026-07-28, armed the 15-minute server-wide SRV_lastRobbery lockout below. Any client
    // could then deny every major heist to everyone for 15 minutes, on repeat, by sending a mode 1
    // it knew would be rejected -- name any other player as _unit and the authz refuses it. Nulling
    // _unit hands the refusal to the flat top-level guard on the next line, which is what actually
    // leaves the function. Same shape as the _data = [] sentinel in the Jewelry Emporium's caller
    // check (fn_jewelryEmporiumSRV.sqf:59-66); this codebase has shipped the nested-exitWith bug
    // twice already. _unit is a params-declared private of THIS scope, so the assignment reaches the
    // guard below -- do not re-declare it private inside the block.
    // Logged against _caller, which is derived from remoteExecutedOwner and is objNull when the
    // sender cannot be resolved; never against the client-supplied _unit, which is exactly the
    // player a forged call would name in order to manufacture -SEC- evidence against an innocent.
    if (!_ok) exitWith { ["-SEC-", _caller, format ["BLOCKED handlePrisonBreak mode %1 by %2", _mode, getPlayerUID _caller]] call APS_fnc_logIt;
        _unit = objNull;   // signal for the guard below
    };
};
// flat, top level: leaves the FUNCTION. Covers a genuinely null unit and, via the sentinel above,
// every authorization refusal -- nothing past this line runs for either.
if (isNull _unit) exitWith {};

switch (_mode) do {case 1: {if (SRV_prisonData param [1, false]) exitWith {};
        // owner 2026-06-16 (#302): server-authoritative one-federal-event-at-a-time gate (client check has a window).
        if (["prison"] call APS_fnc_fedEventActive) exitWith {
            [[2, "Another major crime is already in progress -- the prison break can't kick off."], "AP_fnc_broadcast", _unit, false, false] spawn AP_fnc_MP;
        };
        // owner 2026-07-28 SECURITY: SERVER-AUTHORITATIVE COP GATE. b831655 gave four heists a server-side
        // SRV_lastRobbery guard and missed this file; the cop requirement was never here at all. It lived
        // ONLY in fn_doPrisonBreak:12 (and its post-upload re-check at :53), and this fn is CfgRE
        // allowedTargets = 2, so an authenticated player naming HIMSELF -- which is all the mode-1 authz at
        // :18 asks for -- could start a prison break with zero police online, from anywhere on the map,
        // without the virus upload. Same tenuredCops + AP_betaZeroCops idiom the siblings carry
        // (fn_jewelryEmporiumSRV:30, fn_loonyBinSRV:133, fn_convoyRobbery:29, fn_bankDrillVault:22).
        // REQUIREMENT: slot 2 of SRV_prisonData is the field the client reads, so read the same slot. It
        // does not exist today -- init.sqf:267 seeds [-1800, false] and this case re-stamps [serverTime,
        // true], both two-element -- so both halves fall back to 1: the client's params default is 1 and
        // AP_fnc_policeRequired floors every requirement at `max 1`. `param`, not `select`, so a missing
        // slot yields the default instead of nil, and `max 1` so the two still agree if a third slot is
        // ever added holding 0.
        // PARITY: bb571bc passed _ignoreTenure = true from fn_doPrisonBreak on the stated grounds that
        // "APS_fnc_handlePrisonBreak has no cop gate to be in parity with". It has one now, so that flag is
        // reverted in the same commit. Left as it was, the client would count every cop online while this
        // counts only cops continuously on duty >= AP_copTenureReq (300s): one freshly-on-duty officer
        // would let the client green-light the job, apply wanted charge 14 (fn_doPrisonBreak:57 fires
        // BEFORE the server call on :58) and stand the player through the whole 30-second upload, only for
        // this line to refuse it -- the exact client/server divergence fc17562 exists to close, running the
        // wrong way.
        // No -SEC- row: AP_tenuredCopCount reaches the client on a 20-second wheel job, so an honest
        // client can pass its own gate off a stale count and land here on a plain race. This server has
        // already auto-banned legitimate players off a false positive, and the refusal message below is
        // messaging, not evidence.
        private _pbReq = (SRV_prisonData param [2, 1]) max 1;
        if ((([] call AP_fnc_tenuredCops) < _pbReq) && {!(localNamespace getVariable ["AP_betaZeroCops", false])}) exitWith {
            [[2, format ["The prison cannot be broken with fewer than %1 police officer(s) online.", _pbReq]], "AP_fnc_broadcast", _unit, false, false] spawn AP_fnc_MP;
        };
        // owner 2026-07-28 SECURITY: SERVER-AUTHORITATIVE 30-MINUTE RE-RUN COOLDOWN. Mirrors
        // fn_doPrisonBreak:17 exactly -- same slot, same 1800s interval, same comparison written the same
        // way round (serverTime - last < 1800) -- so the two can be grepped as one expression and cannot
        // drift apart. It was client-only: slot 0 is stamped a few lines below and nothing on this side
        // ever read it back, so an authenticated caller could re-arm the break the moment one ended.
        // MUST read slot 0 BEFORE the stamp below replaces the array, or it would be testing the value it
        // is about to write -- SQF arrays are references and this case reassigns the whole global.
        // `param [0, -1800]` reproduces init.sqf:267's seed, so a missing slot behaves exactly like a fresh
        // boot rather than raising.
        // FRESH BOOT is never blocked: init.sqf:267 seeds SRV_prisonData = [-1800, false] and serverTime
        // starts at 0, so this reads 0 - (-1800) = 1800, and 1800 < 1800 is FALSE. The first break of a
        // session runs, for exactly the reason the client's own copy of this check lets it run.
        if ((serverTime - (SRV_prisonData param [0, -1800])) < 1800) exitWith {
            [[2, format ["This prison is on lockdown. Try again in %1 minute(s).",
                ceil ((1800 - (serverTime - (SRV_prisonData param [0, -1800]))) / 60)]], "AP_fnc_broadcast", _unit, false, false] spawn AP_fnc_MP;
        };
        // owner 2026-07-28 SECURITY: SERVER-AUTHORITATIVE cross-heist "security is high" lockout -- the
        // guard b831655 gave the other four heists and missed on the one heist that ARMS it for everybody.
        // Interval copied verbatim from the six client readers, (60 * 15) = 900s; this heist's own reader
        // is fn_doPrisonBreak:25.
        // PLACEMENT: last of the guards and ABOVE the SRV_prisonData stamp below -- NOT beside the arming
        // write further down. Between the two the break is already published ACTIVE while the 20-minute
        // watchdog that clears it is not spawned until later still, so a refusal there would strand the
        // prison "active" and block every federal event until a restart or !srv resetfed. This guard writes
        // nothing and refuses before any state is stamped.
        // FRESH BOOT is never blocked -- vars.sqf:66 seeds SRV_lastRobbery = -99999, so the test needs
        // serverTime below -99099 to fire; serverTime starts at 0 and only climbs.
        // Messaged to _unit with no -SEC- row, matching the fed-event guard above: past the flat guard at
        // :41 a client-sent mode 1 has already been proven to have _unit isEqualTo the remoteExecutedOwner
        // player, so this reaches the authenticated caller and nobody else. An honest client that had not
        // yet received the publicVariable of SRV_lastRobbery can pass its own gate and land here, so a row
        // would feed the auto-ban table a false positive for a plain network race.
        if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
            [[2, format ["Security is high due to a recent robbery and you cannot start the prison break. Try again in %1 minute(s).",
                ceil ((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)]], "AP_fnc_broadcast", _unit, false, false] spawn AP_fnc_MP;
        };
        SRV_prisonData = [serverTime, true];
        publicVariable "SRV_prisonData";
        // owner 2026-07-28: OPEN THE PER-RUN ARM LATCH. This is the ONLY line in the tree that sets
        // AP_prisonEndArmed false (seeded true at init.sqf:280), and it sits below all five of this
        // case's guards and below the authz sentinel at :35/:41, so the latch opens ONLY for a break the
        // server actually accepted. Every end path arms only when it finds the latch open and closes it in
        // the same breath, which gives both halves of the requirement at once: a legitimately started break
        // arms SRV_lastRobbery exactly ONCE however it ends, and a refused call -- which never reaches this
        // line -- finds the latch shut and arms NOTHING. Reset happens HERE, at the start of the next run,
        // not at the end of this one: a stale-open latch is harmless (the next accepted start reopens it
        // anyway) whereas resetting it at an end would race the other two end paths.
        // NO CROSS-RUN RACE, and this is what makes reopening it here safe rather than merely convenient:
        // by the time this line can run again, every end path of the PREVIOUS run is provably dead. The
        // 30-minute guard above requires serverTime - slot0 >= 1800 and slot0 is stamped at the START, so
        // the next accepted start is at least T+1800. The old watchdog spawn below dies at T+1200 at the
        // latest; AP_fnc_startPrisonBreak's own waitUntil is capped by _breakTimer = 800 (Malden is not
        // "Australia") on a 2 s poll, and its deferred slot-1 clear adds 70 s, so that whole chain is gone
        // by ~T+872. 1800 > 1200 > 872: an old run can never observe a latch this line reopened for a new
        // one, so no stale end path can consume the new run's arm.
        // Server-local, no publicVariable: nothing client-side reads it.
        AP_prisonEndArmed = false;
        // owner 2026-07-28: ARM the 15-minute cross-heist "security is high" lockout. The client action
        // that reaches this case (core/civilian/fn_doPrisonBreak.sqf:25) refuses to start while
        // SRV_lastRobbery is inside the window, but fn_bankDrillVault was the only writer in the tree,
        // so a prison break locked nothing out. Armed at the START, alongside the state stamp above it.
        // owner 2026-07-28, CORRECTED: the note that first landed here claimed every guard above this
        // line was "a flat top-level exitWith" and that a refusal therefore left the block. That was
        // FALSE for the one guard it mattered most for. The mode-1/mode-2 authz refusal at :35 is
        // nested inside a then {}, so it left that block ONLY and dropped straight into this switch:
        // a break the server had just refused armed the lockout anyway, and any client could deny
        // every major heist server-wide for 15 minutes, on repeat, by sending a call it knew would be
        // rejected. It is now a _data = []-style sentinel (_unit = objNull at :36) caught by the flat
        // top-level guard at :41, which is what actually leaves the function.
        // So, accurately: everything above this line stops a refusal before it reaches here --
        //   :35/:41 authz .............. nested exitWith + sentinel -> the flat guard leaves the FUNCTION
        //   already active ............. exitWith in this case block -> leaves the case
        //   fed-event lock ............. exitWith in this case block -> leaves the case
        //   cop count (2026-07-28) ..... exitWith in this case block -> leaves the case
        //   30-min lockdown (ditto) .... exitWith in this case block -> leaves the case
        //   15-min cross-heist lockout . exitWith in this case block -> leaves the case
        // Every one of those five is a FLAT statement of the case block, and this switch is the LAST
        // statement in the file, so leaving the case is terminal in effect -- stated explicitly because
        // relying on it silently is how this codebase shipped the nested-exitWith bug three times. If a
        // statement is ever appended after the switch, every one of them needs re-checking.
        // publicVariable is mandatory -- every reader is client-side.
        // owner 2026-07-28, CORRECTED: the note that stood here called the missing SERVER-side re-run
        // cooldown "a pre-existing gap in this file, not something the sentinel above can close", which
        // reads as "nothing new here". The GAP was pre-existing -- the 30-minute lockdown had only ever
        // been checked in fn_doPrisonBreak:17, client-side. What was NEW is the CONSEQUENCE: 70382fd made
        // this case arm the server-wide SRV_lastRobbery lockout, which turned an ungated re-run from "one
        // heist starts early" into "one authenticated player denies the bank, the Cyberdeck bank app, the
        // convoy, the Loony Bin and the Jewelry Emporium to the entire server, on repeat". That is what
        // made it exploitable, and it is closed by the 30-minute guard above rather than merely noted.
        SRV_lastRobbery = serverTime;
        publicVariable "SRV_lastRobbery";
        // 2017 fn wants [unit, jailID, npcAnchor]; the prison NPC global doesn't exist in this build --
        // the breaker himself anchors the 300m MaxTac-candidate scan (he's standing at the prison).
        [_unit, 1, _unit] spawn AP_fnc_startPrisonBreak;
        ["-PRISON-", _unit, "started a prison break"] call APS_fnc_logIt;
        [_unit] spawn {   // watchdog: 20-min cap resets the event state
            params ["_u"];
            private _endAt = serverTime + 1200;
            waitUntil { uiSleep 10; (serverTime > _endAt) || !(SRV_prisonData param [1, false]) };
            if (SRV_prisonData param [1, false]) then {SRV_prisonData set [1, false]; publicVariable "SRV_prisonData";
                AP_prison_inProgress = false; publicVariable "AP_prison_inProgress";
                "corrections" setMarkerText "Prison";
                "corrections" setMarkerColor "ColorBlue";
                // owner 2026-07-28: ARM THE LOCKOUT AT THE END TOO (owner decision). The start arm above
                // is 900s while this watchdog caps the break at 1200s, so the start arm has already EXPIRED
                // 300s before this fires and delivers no cooling-off at all; re-arming here gives the
                // genuine 15 minutes. Keeping the start arm preserves the anti-overlap behaviour.
                // owner 2026-07-28, CORRECTED: the note that stood here said "a break a cop stopped, or one
                // that completed, has already cleared slot 1, so this branch does not run and does not
                // double-arm: case 2 arms that one." The first clause was right and the second was FALSE.
                // case 2 is the COP-STOP path ONLY. A break that ran its full 800s hold and a break the
                // breaker abandoned BOTH end inside AP_fnc_startPrisonBreak, whose deferred slot-1 clear
                // sits BELOW its if/else and so runs on the success branch and the failure branch alike --
                // and whose waitUntil returns the moment the breaker dies, is restrained, boards a vehicle
                // or leaves 500 m. Slot 1 was therefore false by ~872 s at the very latest in every real
                // run, this waitUntil short-circuited on it, the `then {}` never executed, and a completed
                // or abandoned break armed NOTHING. The real end arm now lives at the bottom of
                // AP_fnc_startPrisonBreak (BOTH copies) and this branch is only the BACKSTOP: it fires
                // when the 1200 s cap expires with slot 1 still set, i.e. when startPrisonBreak's own end
                // never ran at all. A 20-minute expiry IS a legitimate end of a heist that really ran, so
                // it SHOULD arm.
                // NO DOUBLE-ARM: all three end paths share the AP_prisonEndArmed latch, opened in exactly
                // one place (case 1's stamp, below every guard) and closed by whoever ends the break first.
                // There is NO suspension point between the read and the write below -- no sleep/uiSleep/
                // waitUntil, and publicVariable does not yield -- so under SQF's cooperative scheduler the
                // check-and-set is atomic and two end paths cannot both observe an open latch.
                // NO REFUSAL CAN REACH IT: this spawn is created below every guard in case 1 -- all five of
                // them FLAT statements of that case block (see the inventory above), plus the nested-exitWith
                // authz at :35 whose _unit = objNull sentinel is caught by the FLAT guard at :41 -- so a
                // refused start never gets as far as creating it, and never opens the latch either.
                // `if (!...) then {}` and deliberately NOT exitWith: this body is nested inside a then {}
                // inside a spawn, where an exitWith would leave only this block.
                if (!(missionNamespace getVariable ["AP_prisonEndArmed", true])) then {
                    AP_prisonEndArmed = true;
                    SRV_lastRobbery = serverTime;
                    publicVariable "SRV_lastRobbery";};};};};
    case 2: {if !(SRV_prisonData param [1, false]) exitWith {};
        SRV_prisonData set [1, false];
        publicVariable "SRV_prisonData";
        // owner 2026-07-28: ARM THE LOCKOUT AT THE END TOO (owner decision) -- see the watchdog above.
        // DoS: this is the COP-STOP path and a cop stopping a live break is a legitimate END, not a
        // refusal, so it should arm. A refusal cannot reach it. Mode 2 requires side _caller isEqualTo
        // west (:19), and that check's exitWith is nested in the then {} at :18, so it hands off through
        // the _unit = objNull sentinel to the FLAT guard at :41 which leaves the FUNCTION -- a civ forging
        // a mode 2 never enters this case at all. The flat guard on the line above this case's opening
        // brace then requires a break to actually be in progress, and it is cleared in the same tick, so a
        // cop spamming the stop action arms this exactly once per break.
        // owner 2026-07-28: now behind the same AP_prisonEndArmed latch as the other two end paths, and
        // the latch -- not slot 1 -- is what makes "exactly once" true. Slot 1 alone no longer proves this
        // is the FIRST end path to fire: AP_fnc_startPrisonBreak now arms at its natural end but clears
        // slot 1 only 70 s later, so for that whole window a cop can still press stop and land here on a
        // break that has already armed. The latch is closed by then, so this is a no-op. The REST of the
        // case still runs on purpose -- the marker restore, the broadcast and the -PRISON- row are wanted
        // and idempotent; only the arm is suppressed.
        // A refusal still cannot reach the latch at all: it is opened only by case 1's stamp, below every
        // guard, so a civ forging a mode 2 (bounced at :19 -> sentinel -> flat guard at :41) never gets
        // here, and a mode 2 arriving with no break ever started finds the latch shut.
        if (!(missionNamespace getVariable ["AP_prisonEndArmed", true])) then {
            AP_prisonEndArmed = true;
            SRV_lastRobbery = serverTime;
            publicVariable "SRV_lastRobbery";};
        AP_prison_inProgress = false; publicVariable "AP_prison_inProgress";
        "corrections" setMarkerText "Prison";
        "corrections" setMarkerColor "ColorBlue";
        [[0, format ["%1 has restored the prison security systems -- the break is OVER!", name _unit]], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        ["-PRISON-", _unit, "stopped the prison break"] call APS_fnc_logIt;};};
