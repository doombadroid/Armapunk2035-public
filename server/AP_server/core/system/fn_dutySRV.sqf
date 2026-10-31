/*
    APS_fnc_dutySRV -- the authority for duty shifts. Nothing else may put a player on or off duty.

      ["init"]                       server-internal, from server_init.sqf. Creates the two persistent
                                     shared groups, the roster and the cooldown map, and registers the
                                     stale-roster sweep.
      ["request", faction, role]      client -> server. Every gate lives here.
      ["payoff", faction]             client -> server. MaxSec only: settle your own bounty at the price
                                      the SERVER computes from the wanted row, then clear it through
                                      APS_fnc_wantedPardon so the sign-on that follows can pass.
      ["ack", faction]                client -> server. Confirms the engine side actually moved.
      ["ackoff", faction, reason]     client -> server. Confirms a remove landed. Log only.
      ["nak", faction, reason]        client -> server. Aborts an UNCONFIRMED grant that is still inside its
                                      watchdog window, and nothing else -- it is not a second release path.
      ["release"]                     client -> server. Player-initiated clock-off.
      ["disconnect", uid]             server-internal. Drop a roster entry for someone who is gone.
      ["sweep"]                       server-internal, from the scheduler job registered by "init". It is
                                     also the ONE mode that still does something with AP_dutyEnabled false:
                                     it drains a roster stranded by a runtime kill-switch flip, and keeps
                                     both duty groups empty while the flag is off.

    THE CALLER IS remoteExecutedOwner, NEVER THE PAYLOAD -- the standing rule, and the payload is exactly
    what a forged call would use to name somebody else. The only thing a client can influence here is WHICH
    faction and role it is asking for; identity, whitelist, wanted state and cooldown all come from the
    server's own reads. The client's own AP_copLevel/AP_medicLevel are never consulted.
    The one owner id that travels IN a payload is the scheduled-respawn wrapper below, and it is believed
    only in a frame that reports no remote sender of its own -- a state no client can produce. See the
    guard's own comment for why the respawn cannot simply re-read remoteExecutedOwner.

    WHY THE GROUPS ARE deleteWhenEmpty = FALSE. PR1 made every throwaway group `createGroup [side, true]`,
    which is right for gangs and squads. These two are the opposite case: they are created once at boot and
    referenced by netId for the life of the server, so letting the engine collect them the moment the last
    cop clocks off would leave every later applicant resolving grpNull.
*/
// KILL-SWITCH. Everything below is off while the flag is false -- with ONE deliberate exception, and it is
// the exception that makes the switch usable at RUNTIME and not only across a redeploy.
// THE STRAND IT FIXES. Flipping AP_dutyEnabled false with officers on the roster used to leave them exactly
// as they were: side west or independent, wearing the duty kit, holding a headcount, with no terminal to
// clock off at (the terminal action is flag-gated too) and no route off the roster short of a relog -- and
// a relog is a disconnect, i.e. the civilian character is restored by nothing and the duty kit is what the
// next login reads. The sweep job registered by "init" keeps firing every 60s after the flip, because the
// scheduler wheel knows nothing about the flag, so the drain rides that: one "remove" push per rostered
// player AND a server-side leave-group for each, then the roster and both published headcounts are
// cleared, and every later tick keeps both duty groups empty for as long as the flag stays off.
// NO COOLDOWN STAMP, deliberately. A drain is not a clock-off and nobody chose it; stamping the usual
// SRV_dutyCooldown would lock every drained player out for ten minutes if the switch is flipped back on,
// which is exactly the case this exists to make survivable. Flipping back on needs no second "init" either
// -- the two groups, the cooldown/stamp maps and the sweep job all survive the off state, and the roster
// this leaves behind is a fresh empty hashMap rather than a nil.
// THE PUSH HAS TO BE HONOURED ON THE OTHER END. AP_fnc_dutyClient's own first statement is this same flag,
// so its "remove" arm is let through the flag while "apply" stays shut. That is the one deliberate
// loosening in this system and its cost is written out in full at fn_dutyClient.sqf's gate.
// Two conditions besides the flag, both server-side facts: it is the SWEEP (not a client-reachable mode),
// and it came from this machine (remoteExecutedOwner 0 -- a client cannot forge that, and "sweep" is
// refused from the wire anyway once the flag is on). "Is there anything to drain" is NOT one of them any
// more: it used to gate the whole block, which meant that once the roster had been emptied by the first
// flag-off tick, every later tick did nothing at all -- and section 2 below has to keep running for as
// long as the flag is off, because nothing else ejects a self-joiner while the normal sweep is dead.
// THE PUSH IS NOT THE EVICTION. The drain's only mechanism used to be a "remove" push at the client,
// which does the leave-group itself (fn_dutyClient.sqf:396). A client that drops that push -- offline
// between the send and its arrival, an errored remove arm, or simply a modified client that ignores it --
// stays a MEMBER of the published duty group on the server, i.e. side west, in a kit, on a kill-switched
// server, with the roster entry that was its only record already deleted. So the server does the
// leave-group itself now, on its own side, for everyone it drains: the push is the client's cue to undress
// and restore its civilian character, not the thing that takes the side away.
if !(localNamespace getVariable ["AP_dutyEnabled", false]) exitWith {
    if ((toLower (_this param [0, "", [""]])) isEqualTo "sweep"
        && {remoteExecutedOwner isEqualTo 0}) then {
        private _realp = call AP_fnc_realPlayers;

        // 1. DRAIN THE ROSTER.
        if (!isNil {localNamespace getVariable "AP_dutyRoster"} && {(count (localNamespace getVariable "AP_dutyRoster")) > 0}) then {
            private _drained = count (localNamespace getVariable "AP_dutyRoster");
            {
                private _duid = _x;
                private _e = _y;
                // By uid, not by the entry's stored owner id (slot 5): a player who reconnected during the
                // shift carries a stale one, and this is the last chance to reach them.
                private _u = (_realp select { (getPlayerUID _x) isEqualTo _duid }) param [0, objNull];
                if (!isNull _u) then {
                    [["remove", "flag-off"], "AP_fnc_dutyClient", _u, false, false] spawn AP_fnc_MP;
                    // Server-side eviction, the exact idiom the normal sweep's reconciliation uses
                    // (:575 below). Independent of whether the push above is ever honoured.
                    [_u] joinSilent (createGroup [civilian, true]);
                };
                ["-DUTY-", _u, format ["RELEASED faction=%1 uid=%2 reason=kill-switch drain", _e param [0, ""], _duid]] call APS_fnc_logIt;
            } forEach (localNamespace getVariable "AP_dutyRoster");
            localNamespace setVariable ["AP_dutyRoster", createHashMap];
            AP_dutyCopCount = 0; publicVariable "AP_dutyCopCount";
            AP_dutyMedCount = 0; publicVariable "AP_dutyMedCount";
            diag_log format ["[AP-DUTY] kill-switch: roster drained, %1 entries removed", _drained];
        };

        // 2. EMPTY THE TWO DUTY GROUPS, every tick, roster or no roster. With the flag off NOBODY belongs
        // in either group -- there is no roster to hold an entry and no terminal to have granted one -- so
        // this needs no per-faction roster test the way the flag-on reconciliation at :550-579 does; group
        // membership alone is the whole offence. It catches the two cases section 1 cannot: a client that
        // dropped its "remove" push, and a modified client that joins the published group by netId
        // (AP_dutyGroupCopNet / AP_dutyGroupMedNet are publicVariable'd and stay published while the flag
        // is off) at any point AFTER the roster was drained. Filtered through AP_fnc_realPlayers so the
        // headless client is never touched; `units _g` returns a fresh array, so leaving the group inside
        // the loop does not disturb the iteration (same as :568-577).
        {
            private _gv = _x;   // captured: the inner forEach shadows _x with the UNIT
            private _g = missionNamespace getVariable [_gv, grpNull];
            if !(isNull _g) then {
                {
                    private _m = _x;
                    if (_m in _realp) then {
                        ["-SEC-", _m, format ["EJECTED from duty group %1: uid %2, kill-switch is off", _gv, getPlayerUID _m]] call APS_fnc_logIt;
                        [_m] joinSilent (createGroup [civilian, true]);
                    };
                } forEach (units _g);
            };
        } forEach ["AP_dutyGroupCop", "AP_dutyGroupMed"];
    };
};

// SCHEDULED-ONLY -- AND THE CALLER HAS TO CROSS THE RESPAWN WITH THE CALL.
// "request" awaits up to three DB_fnc_asyncQuery reads, and fn_asyncQuery.sqf opens with two waitUntils,
// so an UNSCHEDULED arrival dies inside the whitelist gate with a suspension error. CfgRE cannot prevent
// one: `allowedTargets = 2` restricts the TARGET, not the verb, so any client can send this by
// remoteExecCall instead of remoteExec. Every legitimate caller is already scheduled today -- server_init
// is execVM'd, the sweep runs in the wheel's transient spawn, fn_playerDisconnected is spawned from the
// HandleDisconnect EH, and AP_fnc_MP sends _isCall = false for the client sites -- so this guard is
// reached only by a forged unscheduled call, and its job is to make that case behave like every other
// one rather than to fix a live path.
// THE HAZARD IS THE RESPAWN ITSELF, and it is PR4's client-side finding pointed the other way.
// remoteExecutedOwner is FRAME-LOCAL: it reads 0 inside the spawned thread, and 0 is this file's word for
// "the server called me". A naive `_this spawn APS_fnc_dutySRV` would therefore hand a client the three
// server-internal modes the block below exists to refuse -- "init" alone reassigns AP_dutyRoster and
// de-rosters everyone on the server -- and lose the caller for every other mode besides. So capture the
// owner id in THIS frame and carry it across in a two-element wrapper the re-entry unpacks.
// It sits AFTER the kill-switch, not before it: with the flag off there is nothing to respawn INTO
// (the next line would exit anyway), and spawning first would hand a flag-false server a free
// thread-per-forged-call. Nothing above this line can suspend, so the ordering costs nothing.
private _owner = remoteExecutedOwner;
if (!canSuspend) exitWith { [_this, _owner] spawn APS_fnc_dutySRV; };

// Re-entry from the guard above: [originalArgs, capturedOwner]. Honoured ONLY when this frame has no
// remote owner of its own, which is exactly the spawned case -- a remoteExec'd frame always reports its
// real sender, so a client that sends this shape itself is read with its own owner id and the wrapper is
// never unwrapped (its array-in-slot-0 then fails `params` below and lands in `default`, logged). No
// server-internal caller collides with the shape either: "init"/"sweep" are one element and "disconnect"
// carries a uid STRING, not a number.
private _payload = _this;
private _src = _owner;
if (_owner isEqualTo 0 && {(count _this) isEqualTo 2}
    && {(_this select 0) isEqualType []} && {(_this select 1) isEqualType 0}) then {
    _src = _this select 1;
    _payload = _this select 0;
};

_payload params [["_mode", "", [""]]];
private _args = _payload;   // captured for the case bodies: only outer PRIVATES are reliably in scope there

private _unit = if (_src isEqualTo 0) then { objNull } else {
    (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]
};
private _uid = if (isNull _unit) then { "" } else { getPlayerUID _unit };

// SERVER-INTERNAL MODES ARE SERVER-INTERNAL. allowedTargets = 2 restricts the TARGET (this server), not the
// sender, so every mode below is reachable by any client that can form a remoteExec. Three of them must not
// be: "init" reassigns AP_dutyRoster to a fresh hashMap and would de-roster every player on the server on
// demand, "disconnect" takes its uid straight from the payload and would let anyone drop anyone, and "sweep"
// has no business being client-driven. remoteExecutedOwner 0 == called locally on the server == trusted.
if ((toLower _mode) in ["init", "disconnect", "sweep"] && {_src isNotEqualTo 0}) exitWith {
    ["-SEC-", _unit, format ["BLOCKED dutySRV server-internal mode %1 from owner %2 (uid %3)", _mode, _src, _uid]] call APS_fnc_logIt;
};

// Refusals go back to the caller as a message and to the log as a -DUTY- row, always with uid + faction +
// reason so a refused shift can be reconstructed from the table alone.
private _fnc_refuse = {
    params [["_faction", "", [""]], ["_why", "", [""]], ["_say", "", [""]]];
    if (!isNull _unit && {_say isNotEqualTo ""}) then {
        [[_say, "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
    };
    ["-DUTY-", _unit, format ["REFUSED faction=%1 uid=%2 reason=%3", _faction, _uid, _why]] call APS_fnc_logIt;
};

// THE WANTED ROW, READ IN ONE PLACE -> [isWanted, bounty]. Three sites need it now (the sign-on gate,
// the clock-off gate and "payoff"'s price) and they must never disagree about what "what you owe" means.
// APS_wantedList (localNamespace) rows are [name, uid, chargeIDs[], bounty, jailTime] (vars.sqf; written by
// APS_fnc_wantedSyncList:39 and the legacy wanted_add.sqf:17).
// INDEX 3 IS THE STORED TOTAL, NOT A PER-CHARGE FIGURE, and that distinction is the one that would have
// cost money if it were guessed. fn_wantedSyncList rebuilds the entry from the offender's own
// A_stats_crimes counts (count x charge value; the client's slot-0 total is NOT trusted) into index 3 -- while
// index 2 is the FLATTENED CHARGE ID LIST, so "sum the charges" would be summing crime ids and not
// dollars. APS_fnc_wantedBounty:29-38 pays an arresting officer `_entry select 3` and fn_pardon prices a
// pardon off the same figure, so index 3 is already the number the state treats as the debt. Rounded
// because it is about to be interpolated into money.
private _fnc_wanted = {
    params [["_forUid", "", [""]]];
    private _wl = localNamespace getVariable "APS_wantedList";
    private _i = _wl findIf { (_x param [1, ""]) isEqualTo _forUid };
    if (_i isEqualTo -1) exitWith { [false, 0] };
    private _bounty = round ((_wl select _i) param [3, 0]);
    // A ROW CAN EXIST WITH BOUNTY <= 0 -- a legacy/manual insert, never the live sync path: both writers
    // that touch the wanted list already guard this (fn_wantedSyncList.sqf:38 deletes the row outright the
    // moment its rebuilt total is <= 0, and the legacy wanted_add.sqf never leaves one behind either).
    // Treated as NOT wanted here so a stray $0/negative row cannot lock a sign-on out: the old form
    // returned [true, 0] for it, which the sign-on gate below read as wanted=true while quoting a $0
    // buyout (AP_dutyBuyout stays 0, so no buy action is ever offered) -- and "payoff" refused right back
    // at its own price<=0 check without ever reaching APS_fnc_wantedPardon. Sign-on refused, no route to
    // clear it: an unpayable lockout.
    if (_bounty <= 0) exitWith { [false, 0] };
    [true, _bounty]
};

switch (toLower _mode) do {

    case "init": {
        // APS_fnc_dutyRecount is defined in server_init.sqf, just before the boot "init" call, on EVERY
        // boot: this case can also run at runtime (bot verb "dutyswitch" on a server that booted false),
        // and a helper first defined then can be pre-empted by a client's publicVariableServer'd final copy.

        private _cop = createGroup [west, false];
        _cop setGroupIdGlobal ["MaxSec"];
        AP_dutyGroupCop = _cop;
        AP_dutyGroupCopNet = netId _cop;
        publicVariable "AP_dutyGroupCopNet";

        private _med = createGroup [independent, false];
        _med setGroupIdGlobal ["Trauma Team"];
        AP_dutyGroupMed = _med;
        AP_dutyGroupMedNet = netId _med;
        publicVariable "AP_dutyGroupMedNet";

        // THE ROSTER LIVES IN localNamespace (audit Lsec-0-1). As a missionNamespace global, one client
        // `publicVariableServer "AP_dutyRoster"` replaced it with a map naming itself maxsec, and a joinSilent
        // into the published group did the rest. localNamespace cannot be written over the network.
        localNamespace setVariable ["AP_dutyRoster", createHashMap];     // uid -> [faction, role, startTime, startPos, confirmed, ownerId]
        AP_dutyCooldown = createHashMap;   // uid -> time of last release
        AP_dutyReqStamp = createHashMap;   // uid -> time of last "request" that reached the DB reads
        AP_dutyPayStamp = createHashMap;   // uid -> time of last "payoff" that reached the DB reads
        AP_dutyCopCount = 0; publicVariable "AP_dutyCopCount";
        AP_dutyMedCount = 0; publicVariable "AP_dutyMedCount";

        // Defensive sweep: a client that vanished without a HandleDisconnect (crash, timeout, a kick that
        // beat the EH) would otherwise hold a roster slot and a headcount forever. PR5 wires the real
        // disconnect call; this is the backstop that does not depend on it.
        ["dutySweep", { ["sweep"] call APS_fnc_dutySRV; }, 60, false, true] call AP_fnc_schedule;

        diag_log format ["[AP-DUTY] init: MaxSec=%1 TraumaTeam=%2 roster ready", AP_dutyGroupCopNet, AP_dutyGroupMedNet];
    };

    case "request": {
        _args params [["_m", "", [""]], ["_faction", "", [""]], ["_role", "", [""]]];
        if (isNull _unit || {_uid isEqualTo ""}) exitWith {
            ["-DUTY-", objNull, format ["REFUSED faction=%1 uid= reason=nocaller (owner %2)", _faction, _src]] call APS_fnc_logIt;
        };
        // UIDs are Steam64s and every one below is interpolated into SQL. The unit came from the engine,
        // not the payload, so this can only ever fail on the headless client -- which must not hold a slot.
        if ((toArray _uid) findIf {_x < 48 || _x > 57} isNotEqualTo -1) exitWith {
            [_faction, "nonnumeric uid", ""] call _fnc_refuse;
        };

        private _row = [_faction] call AP_fnc_dutyCfg;
        if (_row isEqualTo []) exitWith { [_faction, "unknown faction", ""] call _fnc_refuse; };

        if (!alive _unit) exitWith { [_faction, "dead", "You cannot sign on while dead."] call _fnc_refuse; };
        if !((side _unit) isEqualTo civilian) exitWith {
            [_faction, format ["wrong side %1", side _unit], "Only a civilian can sign on for a duty shift."] call _fnc_refuse;
        };
        if (_unit getVariable ["AP_restrained", false]) exitWith {
            [_faction, "restrained", "You are restrained."] call _fnc_refuse;
        };
        // ALREADY ROSTERED -- but is the entry still real? A player who relogs while on duty comes back as a
        // fresh civilian on a NEW network owner id with the same uid, and the 60s sweep only drops uids that
        // are absent from AP_fnc_realPlayers -- which a reconnected player is not. The entry would then block
        // that player from ever signing on again and hold a phantom headcount until restart. The one tell
        // that proves the entry belongs to a session that no longer exists: the stored owner id is not the
        // owner id this request came from (the definition of a reconnect).
        // CONFIRMED-but-civilian was tried as a second tell and removed: a still-connected player (same
        // owner id) who is somehow back on the civilian side with a CONFIRMED roster entry is not proof of a
        // dead session -- reaping it here would skip every one of "release"'s own gates (wanted, federal
        // event, restrained) and its cooldown stamp entirely, i.e. a free unthrottled re-roll of the release
        // path for anyone who can force their own side back to civilian without going through it.
        // An UNCONFIRMED entry is deliberately not reapable either: that is a grant still inside its own 10s
        // watchdog window, i.e. terminal spam, and the watchdog is the thing that owns it.
        // PR5's HandleDisconnect makes this path rare; it does not make it unnecessary, because a crash that
        // never fires the handler followed by a fast reconnect looks exactly like this.
        if (_uid in (localNamespace getVariable "AP_dutyRoster")) then {
            private _stale = (localNamespace getVariable "AP_dutyRoster") get _uid;
            private _staleOwner = _stale param [5, -1];
            private _reapable = (_staleOwner isNotEqualTo -1) && {_staleOwner isNotEqualTo _src};
            if (_reapable) then {
                (localNamespace getVariable "AP_dutyRoster") deleteAt _uid;
                call APS_fnc_dutyRecount;
                ["-DUTY-", _unit, format ["REAPED stale-entry faction=%1 uid=%2 owner was %3 now %4 confirmed=%5",
                    _stale param [0, ""], _uid, _staleOwner, _src, _stale param [4, false]]] call APS_fnc_logIt;
            };
        };
        if (_uid in (localNamespace getVariable "AP_dutyRoster")) exitWith {
            [_faction, "already rostered", "You are already on a duty roster."] call _fnc_refuse;
        };

        // COOLDOWN. Presence of a stamp is the test, NOT `time - stamp`: `time` starts at 0 on a fresh
        // mission, so a bare `time - 0 > 600` would refuse every single sign-on for the first ten minutes
        // after a restart -- exactly the window when the shift change happens.
        // The whole test is ONE statement at case-body level on purpose. It was an `exitWith` nested inside
        // an `if..then`, which exits only the THEN BLOCK: the player got the refusal message and the grant.
        // That is this repo's PHANTOM-ELSE bug class; never nest a gate's exitWith inside a conditional.
        if ((_uid in AP_dutyCooldown) && {(SRV_dutyCooldown - (time - (AP_dutyCooldown get _uid))) > 0}) exitWith {
            private _left = SRV_dutyCooldown - (time - (AP_dutyCooldown get _uid));
            [_faction, format ["cooldown %1s left", round _left],
                format ["You came off duty too recently. %1 seconds left.", round _left]] call _fnc_refuse;
        };

        // WANTED -- MAXSEC ONLY NOW. Owner ruling from the playtest, 2026-08-20: Trauma Team has NO
        // bounty gate on sign-on. Medics are non-combatants, a bounty is a matter between the wanted
        // player and MaxSec, and it must not stop anybody treating people -- so trauma is simply not
        // tested here rather than tested and waved through, and there is nothing for a medic to buy.
        // MaxSec keeps the gate, because an officer carrying a bounty is the state's own problem. What
        // changed on that side is the REFUSAL: it now carries the price, because the alternative the
        // officer had was to go and find a second cop willing to pardon them, which is a silly errand
        // for a small fine. See the "payoff" case for what they can do with it.
        //
        // ONE STATEMENT AT CASE-BODY LEVEL, deliberately -- the read is folded into an if..then..else
        // that yields a value and the exitWith stands alone. An exitWith nested inside the faction test
        // would exit only the THEN BLOCK and hand a wanted officer both the refusal and the shift: this
        // repo's PHANTOM-ELSE class, written up in full at the cooldown gate twelve lines above.
        //
        // THE MACHINE-READABLE MARKER IS A VARIABLE, NOT THE TEXT. Refusals reach the client as an
        // English message (_fnc_refuse -> AP_fnc_handleMessage), and a client that had to parse "$4,500"
        // back out of a sentence to know what to charge would be the client pricing the buyout. So the
        // SERVER publishes its own quote on the caller's unit and the client keys on THAT: AP_dutyBuyout
        // > 0 means "the refusal you just got was the wanted one, and this is what it would cost".
        // Published exactly the way AP_wantedAmt is (setVariable ... true) -- the bounty is already a
        // public unit variable, so the quote discloses nothing new -- and published BEFORE the refusal
        // is sent, so it can never trail the message the client is correlating against.
        // IT IS ONLY EVER A QUOTE. "payoff" re-reads the row and re-applies the multiplier itself, so a
        // client that replays a stale or edited number changes nothing about what it is charged.
        // owner 2026-09-06: THE BOUNTY GATE IS OFF. "remove the bounty requirement to join maxsec ... it was a
        // dumb idea on my part" -- a $6k bounty locked the owner out of his own faction. SRV_dutyBountyGate
        // (server_init.sqf, default false) keeps the whole buyout path intact for the day it comes back.
        private _wanted = if ((_row select 0) isEqualTo "maxsec" && {localNamespace getVariable ["SRV_dutyBountyGate", false]}) then { [_uid] call _fnc_wanted } else { [false, 0] };
        if (_wanted param [0, false]) exitWith {
            private _bounty = _wanted param [1, 0];
            private _price = round (_bounty * (localNamespace getVariable ["SRV_dutyBuyoutMult", 1]));
            _unit setVariable ["AP_dutyBuyout", _price, true];
            [_faction, format ["wanted $%1 (buyout $%2)", _bounty, _price],
                format ["You have an outstanding bounty of $%1. Clear it or pay it off.", [_bounty] call AP_fnc_numberText]] call _fnc_refuse;
        };

        // THROTTLE, immediately before the first DB round-trip. Everything above is in-memory; everything
        // below hits the serialized extDB3 mutex, up to twice per request, and the client end of this is a
        // scroll action a modified client can fire as fast as it likes. Silent by design -- a refusal
        // message here would just be a second thing to spam. Stamp BEFORE the read so an in-flight request
        // throttles the next one rather than the two racing each other through the gates.
        if (isNil "AP_dutyReqStamp") then { AP_dutyReqStamp = createHashMap; };
        if ((_uid in AP_dutyReqStamp) && {(time - (AP_dutyReqStamp get _uid)) < 10}) exitWith {
            // Server RPT only, not a -DUTY- row: this is the one gate a modified client can trigger as fast
            // as it likes (see the throttle's own comment above), so a logIt here is the same unthrottled
            // per-attempt DB write through the serialized extDB3 mutex that the throttle exists to avoid.
            diag_log format ["[AP-DUTY] request throttled: faction=%1 uid=%2 (within 10s of the last one)", _faction, _uid];
        };
        AP_dutyReqStamp set [_uid, time];

        // Whitelist, from the SERVER's own read. players_global is where coplevel/adminlevel/mediclevel
        // live (fn_queryRequest.sqf:46); isscd is on the per-world character table (fn_queryRequest.sqf:89).
        private _g = [format ["SELECT coplevel,adminlevel,mediclevel FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
        if (!(_g isEqualType []) || {_g isEqualTo []}) exitWith {
            [_faction, "no players_global row", "Your record could not be read. Try again."] call _fnc_refuse;
        };
        private _copLevel = parseNumber (format ["%1", _g param [0, 0]]);
        private _adminLevel = parseNumber (format ["%1", _g param [1, 0]]);
        private _medicLevel = parseNumber (format ["%1", _g param [2, 0]]);

        private _entryOK = switch (_row select 0) do {
            // The cop lobby gate PR7 deleted -- any cop rank OR any admin level.
            case "maxsec": { (_copLevel >= 1) || (_adminLevel >= 1) };
            // The medic one WITHOUT the volunteer sentinel: 99 was injected at login for an un-whitelisted
            // medic-SLOT picker, and it must never be a Trauma Team credential here. Nothing writes 99 any
            // more now the slots are gone, but it is still a legal value in players_global.mediclevel.
            case "trauma": { (_medicLevel >= 1) && (_medicLevel != 99) };
            default { false };
        };
        if (!_entryOK) exitWith {
            [_faction, format ["not whitelisted (cop %1 admin %2 med %3)", _copLevel, _adminLevel, _medicLevel],
                "You are not on this faction's roster."] call _fnc_refuse;
        };

        // Role re-check, mirroring the cfg gateCodes off server-read values. The read is UNCONDITIONAL now
        // (was `if (_role isEqualTo "scd")`): arrest has to gate every faction/role's request, not just SCD's.
        // isscd stays index 0 -- arrested is APPENDED at index 1, never prepended, so the existing isscd
        // consumer below is not index-shifted by the widening.
        // `arrested` is players.arrested, TEXT (sql/looneybin_schema.sql:56) -- the SAME mres-encoded
        // [flag,bail,sentence] column fn_queryRequest.sqf:197 decodes for login (encoder: fn_claimBodybagSRV.
        // sqf:38-42) -- NOT a plain flag like isscd, so it cannot be parseNumber'd the way isscd is below.
        // fn_talSRV.sqf:22 reads this same column with a bare parseNumber and is not a safe precedent to
        // copy: an mres blob is not numeric-leading text, so parseNumber silently returns 0 on it every time
        // -- a gate written that way would compile clean and never fire. Mirrors fn_queryRequest.sqf:29-39's
        // `_dec` instead: mresToArray, then the STRING-typename parseSimpleArray fallback, then a non-array
        // default, then read index 0 the same way the client normalises AP_is_arrested (fn_requestReceived.
        // sqf:132).
        private _isSCD = false;
        private _p = [format ["SELECT isscd, arrested FROM %2 WHERE playerid='%1'", _uid, "players"], 2] call DB_fnc_asyncQuery;
        _isSCD = (parseNumber (format ["%1", _p param [0, 0]])) isEqualTo 1;
        private _arrDec = [_p param [1, ""]] call DB_fnc_mresToArray;
        if (typeName _arrDec == "STRING") then { _arrDec = parseSimpleArray (format ["%1", _arrDec]); };
        if (!(_arrDec isEqualType [])) then { _arrDec = []; };
        if ((_arrDec param [0, 0]) isEqualTo 1) exitWith {
            [_faction, "arrested", "You cannot go on duty while incarcerated."] call _fnc_refuse;
        };
        private _roleOK = switch (_role) do {
            case "patrol": { (_row select 0) isEqualTo "maxsec" };
            case "warrant": { ((_row select 0) isEqualTo "maxsec") && (_copLevel >= 3) };
            case "medic": { ((_row select 0) isEqualTo "maxsec") && (_copLevel >= 3) };
            case "scd": { ((_row select 0) isEqualTo "maxsec") && _isSCD };
            case "all": { ((_row select 0) isEqualTo "maxsec") && ((_copLevel >= 6) || (_adminLevel >= 3)) };
            case "ttmedic": { (_row select 0) isEqualTo "trauma" };
            default { false };
        };
        if (!_roleOK) exitWith {
            [_faction, format ["role %1 not permitted", _role], format ["You are not cleared for the %1 role.", toUpper _role]] call _fnc_refuse;
        };

        // The unit could have gone away across three awaited DB reads.
        if (isNull _unit || {!alive _unit} || {!((side _unit) isEqualTo civilian)}) exitWith {
            [_faction, "caller changed state during validation", ""] call _fnc_refuse;
        };

        // Slot 5 is the network owner id this shift was granted to. It is what tells a reconnect apart from
        // a duplicate request when the same uid comes back (see the stale-entry reap above).
        (localNamespace getVariable "AP_dutyRoster") set [_uid, [_faction, _role, time, getPosATL _unit, false, _src]];
        call APS_fnc_dutyRecount;

        // The WHOLE dutyLoad payload goes to the client, not just slot 0's gear: talents, exp, the
        // prestige tree and the side's licences belong to the duty character too, and AP_fnc_dutyClient has
        // to have them in hand before it calls AP_fnc_dutyContext (which derives AP_track_radius from
        // AP_cop_talents).
        private _load = [_uid, _faction] call DB_fnc_dutyLoad;
        private _grpNet = if ((_row select 0) isEqualTo "maxsec") then { AP_dutyGroupCopNet } else { AP_dutyGroupMedNet };

        [["apply", _faction, _role, _load, _grpNet], "AP_fnc_dutyClient", _unit, false, false] spawn AP_fnc_MP;
        ["-DUTY-", _unit, format ["GRANTED faction=%1 role=%2 uid=%3", _faction, _role, _uid]] call APS_fnc_logIt;

        // Watchdog. A client that takes the grant but never joins the group (script error, alt-F4 mid-swap,
        // a modified client that keeps the gear and skips the side change) must not keep a roster slot or a
        // headcount. 10s is generous next to a joinSilent.
        [_uid, _unit, _faction] spawn {
            params ["_uid", "_unit", "_faction"];
            uiSleep 10;
            if !(localNamespace getVariable ["AP_dutyEnabled", false]) exitWith {};
            if !(_uid in (localNamespace getVariable "AP_dutyRoster")) exitWith {};
            private _e = (localNamespace getVariable "AP_dutyRoster") get _uid;
            if (_e param [4, false]) exitWith {};                                   // acked
            // ENGINE-CONFIRM. A withheld/suppressed ack must not leave the entry unconfirmed for the rest of
            // the shift -- every routing site (DB_fnc_updatePartial, DB_fnc_updateRequest, APS_fnc_vehicleCreate,
            // the garage/vehicle reads) treats slot 4 as "trust the client until this flips true". If the
            // client got this far it already paid the joinSilent cost, so the engine's own side IS the
            // confirmation: same idiom the "ack" case above uses (compare against the cfg row's side), just
            // read here instead of trusted from the packet. Honest clients are unaffected -- their ack lands
            // within a second or two of the flip, long before this 10s window closes. A side that did NOT
            // move to the granted faction's side falls through to the rollback below, unchanged.
            private _row = [_faction] call AP_fnc_dutyCfg;
            if (!isNull _unit && {(side _unit) isEqualTo (_row select 1)}) exitWith {
                _e set [4, true];
                (localNamespace getVariable "AP_dutyRoster") set [_uid, _e];
                ["-DUTY-", _unit, format ["CONFIRMED faction=%1 role=%2 uid=%3 reason=engine-confirmed (no ack)", _faction, _e param [1, ""], _uid]] call APS_fnc_logIt;
            };
            (localNamespace getVariable "AP_dutyRoster") deleteAt _uid;
            AP_dutyCooldown set [_uid, time];
            call APS_fnc_dutyRecount;
            if (!isNull _unit) then {
                [["remove", "watchdog"], "AP_fnc_dutyClient", _unit, false, false] spawn AP_fnc_MP;
            };
            ["-DUTY-", _unit, format ["ROLLBACK faction=%1 uid=%2 reason=no ack within 10s", _faction, _uid]] call APS_fnc_logIt;
        };
    };

    // ── PAYOFF ───────────────────────────────────────────────────────────────────────────────────
    // ["payoff", faction] -- settle your own bounty at the duty terminal and sign on.
    //
    // WHY IT EXISTS. Owner ruling from the playtest, 2026-08-20: an officer with an outstanding bounty
    // still cannot go on shift, but making them hunt down a second cop to pardon them over a small fine
    // is a silly errand. They pay it themselves, at the terminal, and sign on.
    //
    // WHAT THE CLIENT IS ALLOWED TO SAY: the faction, and nothing else. No amount travels in this
    // payload and none would be believed -- the price is computed HERE from the wanted row this server
    // holds, times a server-side multiplier. That is the whole of "the server prices and moves money,
    // never the client", and it is why the buyout quote published on the refusal above is only ever a
    // display value.
    //
    // THE GATES ARE THE SIGN-ON GATES, in the sign-on order, and that is not tidiness. Money must not
    // move for a thing that cannot then happen: a player who is dead, on the wrong side, restrained,
    // already rostered, inside their release cooldown, jailed or not on the MaxSec whitelist is going
    // to be refused by "request" a second later, and taking their money first would be charging them
    // for a shift they cannot start. THE WHITELIST GATE IS ALSO A SECURITY GATE -- without it any
    // civilian could clear their own wanted level for cash through a door that has nothing to do with
    // policing.
    // Two of "request"'s gates are deliberately NOT here: the ROLE table (a payoff picks no role, and
    // the role is re-checked by the sign-on that follows) and the grant watchdog (nothing is granted).
    //
    // TRAUMA CANNOT REACH THIS AT ALL. There is no medic bounty gate any more, so there is nothing for
    // a medic to buy; a "payoff" naming trauma is a client asking to be charged for nothing and is
    // refused before any read.
    case "payoff": {
        _args params [["_m", "", [""]], ["_faction", "", [""]]];
        if (isNull _unit || {_uid isEqualTo ""}) exitWith {
            ["-DUTY-", objNull, format ["REFUSED faction=%1 uid= reason=payoff nocaller (owner %2)", _faction, _src]] call APS_fnc_logIt;
        };
        // Same guard and same reason as "request": every uid below is interpolated into SQL.
        if ((toArray _uid) findIf {_x < 48 || _x > 57} isNotEqualTo -1) exitWith {
            [_faction, "payoff nonnumeric uid", ""] call _fnc_refuse;
        };

        private _row = [_faction] call AP_fnc_dutyCfg;
        if (_row isEqualTo []) exitWith { [_faction, "payoff unknown faction", ""] call _fnc_refuse; };
        if !((_row select 0) isEqualTo "maxsec") exitWith {
            [_faction, "payoff non-maxsec faction", "There is no bounty gate on this faction's roster."] call _fnc_refuse;
        };

        if (!alive _unit) exitWith { [_faction, "payoff dead", "You cannot sign on while dead."] call _fnc_refuse; };
        if !((side _unit) isEqualTo civilian) exitWith {
            [_faction, format ["payoff wrong side %1", side _unit], "Only a civilian can sign on for a duty shift."] call _fnc_refuse;
        };
        if (_unit getVariable ["AP_restrained", false]) exitWith {
            [_faction, "payoff restrained", "You are restrained."] call _fnc_refuse;
        };
        if (_uid in (localNamespace getVariable "AP_dutyRoster")) exitWith {
            [_faction, "payoff already rostered", "You are already on a duty roster."] call _fnc_refuse;
        };
        // THE COOLDOWN IS A MONEY GATE HERE, not a convenience. Charge someone inside their release
        // cooldown and the sign-on they paid for is refused by "request" seconds later with their money
        // already gone. Same formula, same stamp, same wording as :285 -- presence of the stamp is the
        // test, never `time - stamp`, because `time` starts at 0 on a fresh mission.
        if ((_uid in AP_dutyCooldown) && {(SRV_dutyCooldown - (time - (AP_dutyCooldown get _uid))) > 0}) exitWith {
            private _left = SRV_dutyCooldown - (time - (AP_dutyCooldown get _uid));
            [_faction, format ["payoff cooldown %1s left", round _left],
                format ["You came off duty too recently. %1 seconds left.", round _left]] call _fnc_refuse;
        };

        // NOTHING TO BUY. Cheap, in-memory, and it is also what makes a replayed payoff a no-op: the
        // first one clears the row through the pardon path below, so the second finds nothing.
        private _w0 = [_uid] call _fnc_wanted;
        if !(_w0 param [0, false]) exitWith {
            [_faction, "payoff not wanted", "You have no outstanding bounty to pay off."] call _fnc_refuse;
        };

        // THROTTLE, immediately before the first DB round-trip, exactly as "request" does -- and on its
        // OWN map, which is the point. Sharing AP_dutyReqStamp would have the payoff burn the sign-on's
        // 10s slot, so the retry that is the entire purpose of the payoff would be silently swallowed by
        // the request throttle a second later. Silent by design for the same reason as :296: a refusal
        // here would just be a second thing to spam, and a logIt would be the very unthrottled DB write
        // the throttle exists to prevent.
        if (isNil "AP_dutyPayStamp") then { AP_dutyPayStamp = createHashMap; };
        if ((_uid in AP_dutyPayStamp) && {(time - (AP_dutyPayStamp get _uid)) < 10}) exitWith {
            diag_log format ["[AP-DUTY] payoff throttled: faction=%1 uid=%2 (within 10s of the last one)", _faction, _uid];
        };
        AP_dutyPayStamp set [_uid, time];

        // Whitelist + arrest, from the SERVER's own reads, both copied from "request" so the two cannot
        // drift. A non-whitelisted player must not be able to buy a wanted-level clear, and a prisoner
        // must not be able to buy their way off the sentence the arrest wrote.
        private _g = [format ["SELECT coplevel,adminlevel FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
        if (!(_g isEqualType []) || {_g isEqualTo []}) exitWith {
            [_faction, "payoff no players_global row", "Your record could not be read. Try again."] call _fnc_refuse;
        };
        private _copLevel = parseNumber (format ["%1", _g param [0, 0]]);
        private _adminLevel = parseNumber (format ["%1", _g param [1, 0]]);
        if !((_copLevel >= 1) || (_adminLevel >= 1)) exitWith {
            [_faction, format ["payoff not whitelisted (cop %1 admin %2)", _copLevel, _adminLevel],
                "You are not on this faction's roster."] call _fnc_refuse;
        };

        // players.arrested is the mres-encoded [flag, bail, sentence] blob, NOT a plain flag -- decoded
        // the way fn_queryRequest.sqf:29-39 does it and never with a bare parseNumber, which returns 0
        // on an mres blob every time and would compile clean while never firing. Full write-up at the
        // identical read in "request".
        private _p = [format ["SELECT arrested FROM %2 WHERE playerid='%1'", _uid, "players"], 2] call DB_fnc_asyncQuery;
        private _arrDec = [_p param [0, ""]] call DB_fnc_mresToArray;
        if (typeName _arrDec == "STRING") then { _arrDec = parseSimpleArray (format ["%1", _arrDec]); };
        if (!(_arrDec isEqualType [])) then { _arrDec = []; };
        if ((_arrDec param [0, 0]) isEqualTo 1) exitWith {
            [_faction, "payoff arrested", "You cannot go on duty while incarcerated."] call _fnc_refuse;
        };

        // THE CALLER COULD HAVE GONE AWAY ACROSS TWO AWAITED DB READS, and this one is about to spend
        // their money. Same re-check "request" makes at the same point, plus the wanted row itself:
        // an arrest, a pardon or a bounty payout in that window changes what is owed, so the PRICE is
        // read here and not from the check above.
        if (isNull _unit || {!alive _unit} || {!((side _unit) isEqualTo civilian)} || {_uid in (localNamespace getVariable "AP_dutyRoster")}) exitWith {
            [_faction, "payoff caller changed state during validation", ""] call _fnc_refuse;
        };
        private _w = [_uid] call _fnc_wanted;
        if !(_w param [0, false]) exitWith {
            [_faction, "payoff not wanted (cleared during validation)", "Your bounty was already cleared."] call _fnc_refuse;
        };

        // THE PRICE. SRV_dutyBuyoutMult is the owner's dial (server_init.sqf); read through a getVariable
        // default so a server addon that predates it prices at face value rather than throwing inside a
        // money path.
        private _bounty = _w param [1, 0];
        private _price = round (_bounty * (localNamespace getVariable ["SRV_dutyBuyoutMult", 1]));
        if (_price <= 0) exitWith {
            [_faction, format ["payoff price %1 <= 0 (bounty %2)", _price, _bounty], "You have no outstanding bounty to pay off."] call _fnc_refuse;
        };

        // THE MOVEMENT. APS_fnc_bankMove is hold'em's reviewed primitive, lifted into core\system so this
        // is the same guarded write and not a second one: it refuses an unbacked debit BEFORE the write
        // (`AND bankacc >= N` in the SQL as well as in SQF), confirms by read-back, and writes the one
        // `log` row itself -- on CONFIRMATION, never on intent. That is why there is no logIt of our own
        // for the money below: a second row would be a second record of one movement.
        private _mv = [_uid, -_price, "duty bounty payoff", "-DUTY-", "AP-DUTY"] call APS_fnc_bankMove;
        _mv params [["_paid", false], ["_before", 0], ["_after", 0]];
        if (!_paid) exitWith {
            // REFUSALS SURFACE WITH ENOUGH DATA FOR THE CLIENT TO ACT. Insufficient funds is the case a
            // player can actually do something about, so it names both figures; anything else is the
            // read-back disagreeing with the write, which is a human's problem and already has its own
            // UNCONFIRMED row in `log`. Nothing was debited on either branch and nothing was cleared.
            private _say = if (_before < _price) then {
                format ["You cannot afford the $%1 payoff -- your bank holds $%2.", [_price] call AP_fnc_numberText, [_before] call AP_fnc_numberText]
            } else {
                "The bank did not confirm the payment. Nothing was charged."
            };
            [_faction, format ["payoff bank refused $%1 (bank $%2)", _price, _before], _say] call _fnc_refuse;
        };

        // CLEARED THROUGH THE PARDON PATH, NOT BY HAND. APS_fnc_wantedPardon is the ONE function that
        // knows every consumer of wanted state: the wanted-list entry the cop menu reads, the
        // offender's own client (AP_fnc_wantedListAdd 999, which zeroes A_stats_crimes, republishes
        // AP_wantedAmt and pushes the corrected array back up), the re-jail list, an active parole,
        // the bounty-board entry (AP_fnc_removeBounty) and the `wanted` DB row. A partial clear written
        // here would leave the officer signed on and still showing wanted on somebody's screen.
        // ITS OWN GUARD ALLOWS THIS CALL, verified rather than assumed. The block reads
        //   _src isNotEqualTo 0 && {!(_caller call APS_fnc_isDutyCop)} && {_uid isNotEqualTo _callerUID}
        // i.e. all three must hold to refuse. This is a `call`, so the frame is ours: if the request
        // arrived over the wire, remoteExecutedOwner is the payer's own owner id and _callerUID resolves
        // to the payer's uid -- the same uid we are passing -- so the third clause is false and the guard
        // does not fire. If we were re-entered through the unscheduled-respawn wrapper at the top of this
        // file, remoteExecutedOwner reads 0 and the FIRST clause is false instead. Both readings pass,
        // and neither depends on the payer being a cop (they are not one yet -- that is the point).
        [_uid] call APS_fnc_wantedPardon;

        // THE ANSWER, on the same correlation the request path uses: a GRANT is read off the client state
        // the server's push wrote (fn_dutyRequest tests AP_onDuty), and a REFUSAL arrives as a message and
        // is tapped in fn_handleMessage. So success here is a variable and not a sentence -- AP_dutyPaid
        // is the amount actually debited, published like AP_wantedAmt, and AP_dutyBuyout is put back to 0
        // because the quote it carried has been spent.
        // NO SUCCESS MESSAGE IS SENT, and that is deliberate rather than an omission. The client's tap
        // copies the FIRST "basic" message that arrives while a request is in flight into AP_dutyReqErr,
        // and it cannot tell a congratulation from a refusal; a server-sent "you paid $N" racing the
        // pardon's own client push would be read as the payoff FAILING with that text. The client toasts
        // it locally off AP_dutyPaid instead, which cannot race itself.
        _unit setVariable ["AP_dutyPaid", _price, true];
        _unit setVariable ["AP_dutyBuyout", 0, true];
        diag_log format ["[AP-DUTY] payoff: uid=%1 paid $%2 (bounty $%3) bank $%4 -> $%5, wanted cleared via APS_fnc_wantedPardon", _uid, _price, _bounty, _before, _after];
    };

    case "ack": {
        _args params [["_m", "", [""]], ["_faction", "", [""]]];
        if (isNull _unit || {!(_uid in (localNamespace getVariable "AP_dutyRoster"))}) exitWith {};
        private _e = (localNamespace getVariable "AP_dutyRoster") get _uid;
        if !((_e param [0, ""]) isEqualTo _faction) exitWith {
            ["-DUTY-", _unit, format ["ACK MISMATCH uid=%1 claimed=%2 rostered=%3", _uid, _faction, _e param [0, ""]]] call APS_fnc_logIt;
        };
        private _row = [_faction] call AP_fnc_dutyCfg;
        if !((side _unit) isEqualTo (_row select 1)) exitWith {
            ["-DUTY-", _unit, format ["ACK REJECTED uid=%1 faction=%2 side is still %3", _uid, _faction, side _unit]] call APS_fnc_logIt;
        };
        _e set [4, true];
        (localNamespace getVariable "AP_dutyRoster") set [_uid, _e];
        ["-DUTY-", _unit, format ["CONFIRMED faction=%1 role=%2 uid=%3", _faction, _e param [1, ""], _uid]] call APS_fnc_logIt;
    };

    case "ackoff": {
        _args params [["_m", "", [""]], ["_faction", "", [""]], ["_reason", "", [""]]];
        // THE SENDER MUST HAVE BEEN REMOVED FROM SOMETHING. Ungated, this was the one client-reachable
        // mode with no gate at all: three free-text-ish payload fields going straight into APS_fnc_logIt,
        // i.e. a DB write per call, unthrottled, from a sender that never had to have been on duty. The
        // caller is resolved from remoteExecutedOwner as everywhere else, so it can only ever name
        // ITSELF -- the row is attributed correctly -- but a sender who has never clocked on has nothing
        // to confirm and gets no row.
        // THE TEST IS THE COOLDOWN STAMP, NOT ROSTER MEMBERSHIP, and that is not a preference. Every one
        // of the three sites that pushes ["remove", ...] deletes the roster entry BEFORE or in the same
        // breath as the push -- "release" at :517-518, the grant watchdog at :397-401, and the kill-switch
        // drain at the top of this file -- while the client sends "ackoff" at the very END of its remove
        // arm (fn_dutyClient.sqf:451), after the gear restore and the position restore. By then the uid
        // is out of AP_dutyRoster in 100% of legitimate cases, so `_uid in AP_dutyRoster` would refuse
        // every honest clock-off and the "OFF CONFIRMED" audit line (DUTY_SOAK.md B) would never be
        // written again. AP_dutyCooldown is the record that IS written on the way out: "release" (:519),
        // the watchdog (:398), "disconnect" and the stale-roster sweep all stamp it with `time`. It is
        // pruned by the sweep once older than SRV_dutyCooldown, so it is also a self-maintaining window
        // -- roughly "was removed within the last ten minutes" -- rather than a map that grows forever.
        // The kill-switch drain deliberately stamps NO cooldown, and that costs nothing here: an "ackoff"
        // arriving while the flag is off never reaches this switch at all, it exits at the flag gate on
        // line 63, which lets only "sweep" through.
        if (_uid isEqualTo "" || {isNil "AP_dutyCooldown"} || {!(_uid in AP_dutyCooldown)}) exitWith {
            diag_log format ["[AP-DUTY] ackoff refused, sender holds no release record: uid=%1 owner=%2 faction=%3 reason=%4", _uid, _src, _faction, _reason];
        };
        ["-DUTY-", _unit, format ["OFF CONFIRMED faction=%1 uid=%2 reason=%3", _faction, _uid, _reason]] call APS_fnc_logIt;
    };

    case "nak": {
        _args params [["_m", "", [""]], ["_faction", "", [""]], ["_reason", "", [""]]];
        if (_uid isEqualTo "" || {!(_uid in (localNamespace getVariable "AP_dutyRoster"))}) exitWith {};
        private _e = (localNamespace getVariable "AP_dutyRoster") get _uid;
        // A nak is the ABORT OF AN IN-FLIGHT GRANT, and nothing else. Unhardened it was a release with no
        // gates at all: a rostered officer could send it and be de-rostered while wanted or mid-heist,
        // skipping every "release" check, with no cooldown stamp and no remove pushed -- so they stayed
        // west + geared, invisible to the headcount and to the roster. A ghost.
        // Three conditions make it a genuine abort, and all three are server-side facts, not payload:
        //   * the entry is UNCONFIRMED -- the client never acked a completed side change,
        //   * it is younger than 15s, i.e. still inside the grant's own 10s watchdog window (+ slack), and
        //   * the sender's side has not already moved to west/independent -- mirrors the watchdog's own
        //     "side did move" exit (:392, inside "request"'s watchdog spawn): if the flip already landed the
        //     apply already succeeded, and a nak claiming otherwise is the client lying -- they already
        //     joined the group, so honoring it would de-roster a live, geared officer with no cooldown and
        //     no remove pushed. A ghost.
        // (The uid is the SENDER's, resolved from remoteExecutedOwner, so a nak can only ever reach the
        // sender's own entry.) No remove push is needed on a genuine abort: the client's only nak site is
        // fn_dutyClient's pre-mutation group-resolve/flush-block path, which fires before the swap guard is
        // held and before any state changes, so there is nothing on that end to undo.
        if ((_e param [4, false]) || {(time - (_e param [2, 0])) >= 15}
            || {!isNull _unit && {(side _unit) in [west, independent]}}) exitWith {
            ["-SEC-", _unit, format ["BLOCKED dutySRV nak: uid=%1 faction=%2 confirmed=%3 age=%4s reason=%5",
                _uid, _faction, _e param [4, false], round (time - (_e param [2, 0])), _reason]] call APS_fnc_logIt;
        };
        (localNamespace getVariable "AP_dutyRoster") deleteAt _uid;
        // A SHORT cooldown, not the full SRV_dutyCooldown: this is the abort of a grant the player never
        // actually used, not a release, and stamping the full 600s would punish a clean terminal-cancel as
        // hard as an actual shift. AP_dutyCooldown only ever stores a TIMESTAMP, and the gate at :285 always
        // measures remaining time against SRV_dutyCooldown, so a shorter effective window has to be encoded
        // by backdating the stamp rather than changing the gate: `time - (SRV_dutyCooldown -
        // SRV_dutyNakCooldown)` makes `SRV_dutyCooldown - (time - stamp)` read exactly SRV_dutyNakCooldown
        // seconds remaining right now, decaying at the same rate as every other stamp in this map -- so the
        // sweep's prune-by-age at :585 keeps working unchanged.
        AP_dutyCooldown set [_uid, time - (SRV_dutyCooldown - SRV_dutyNakCooldown)];
        call APS_fnc_dutyRecount;
        ["-DUTY-", _unit, format ["ROLLBACK faction=%1 uid=%2 reason=nak-abort (%3)", _faction, _uid, _reason]] call APS_fnc_logIt;
    };

    case "release": {
        if (isNull _unit || {_uid isEqualTo ""}) exitWith {};
        if !(_uid in (localNamespace getVariable "AP_dutyRoster")) exitWith {
            ["", "release while not rostered", "You are not on duty."] call _fnc_refuse;
        };
        private _e = (localNamespace getVariable "AP_dutyRoster") get _uid;
        private _faction = _e param [0, ""];

        if (_unit getVariable ["AP_restrained", false]) exitWith {
            [_faction, "restrained", "You cannot clock off while restrained."] call _fnc_refuse;
        };
        // WANTED, ON THE WAY OUT -- A DIFFERENT RULE FROM THE SIGN-ON GATE, and it stays. This one is not
        // "no wanted player may serve", it is "an officer does not get to end their shift to walk away
        // from their own bounty", and no owner ruling touched it.
        // BUT IT HAD TO FOLLOW TRAUMA'S EXEMPTION, because it was the same flat test and it is the other
        // half of the same trap. As of the sign-on change above a wanted player may clock ON as a medic;
        // leaving this gate flat would then hold that medic on shift for as long as the bounty stood --
        // a player who did nothing wrong by the new rule, stuck in a kit with no route off the roster
        // short of a disconnect. That is the strand the kill-switch drain at the top of this file exists
        // to stop happening, arrived at from the other direction. So: same faction test, same reason.
        // MaxSec is untouched -- an officer with a bounty still cannot clock off to escape it, which is
        // exactly why the buyout at the terminal is worth having.
        private _wantedOut = if (_faction isEqualTo "maxsec" && {localNamespace getVariable ["SRV_dutyBountyGate", false]}) then { [_uid] call _fnc_wanted } else { [false, 0] };   // same owner switch as the sign-on gate
        if (_wantedOut param [0, false]) exitWith {
            [_faction, format ["wanted $%1", _wantedOut param [1, 0]],
                "You have an outstanding bounty. You cannot clock off yet."] call _fnc_refuse;
        };
        // APS_fnc_fedEventActive is the server's own mutual-exclusion check and already enumerates every
        // heist that has an "active" signal: Malden Fed (SRV_maldenFed[0]), bank (AP_bank_robbed[0]),
        // evidence (SRV_evidence_status[1]), prison (SRV_prisonData[1]), convoy (SRV_convoy_status[0]),
        // Loony Bin (SRV_loonyBinData[1]) and jewelry (SRV_jewelryEmporiumSRV[1]). Reusing it means the
        // clock-off gate can never drift out of step with the list the heists themselves police.
        if ([""] call APS_fnc_fedEventActive) exitWith {
            [_faction, "federal event active", "A major incident is in progress. You cannot clock off yet."] call _fnc_refuse;
        };
        if (!isNil "SRV_houseOnFire" && {(count SRV_houseOnFire) isNotEqualTo 0} && {_faction isEqualTo "trauma"}) exitWith {
            [_faction, "structure fire active", "There is an active structure fire. You cannot clock off yet."] call _fnc_refuse;
        };

        [["remove", "released"], "AP_fnc_dutyClient", _unit, false, false] spawn AP_fnc_MP;
        (localNamespace getVariable "AP_dutyRoster") deleteAt _uid;
        AP_dutyCooldown set [_uid, time];
        call APS_fnc_dutyRecount;
        ["-DUTY-", _unit, format ["RELEASED faction=%1 role=%2 uid=%3", _faction, _e param [1, ""], _uid]] call APS_fnc_logIt;
    };

    case "disconnect": {
        _args params [["_m", "", [""]], ["_duid", "", [""]]];
        if (_duid isEqualTo "" || {!(_duid in (localNamespace getVariable "AP_dutyRoster"))}) exitWith {};
        private _e = (localNamespace getVariable "AP_dutyRoster") get _duid;
        (localNamespace getVariable "AP_dutyRoster") deleteAt _duid;
        AP_dutyCooldown set [_duid, time];
        call APS_fnc_dutyRecount;
        ["-DUTY-", objNull, format ["RELEASED faction=%1 uid=%2 reason=disconnect", _e param [0, ""], _duid]] call APS_fnc_logIt;
    };

    case "sweep": {
        if (isNil {localNamespace getVariable "AP_dutyRoster"}) exitWith {};
        private _realp = call AP_fnc_realPlayers;
        private _live = _realp apply { getPlayerUID _x };

        // 1. Roster entries whose player is gone (crash / timeout / a kick that beat the disconnect EH).
        private _stale = [];
        { if !(_x in _live) then { _stale pushBack _x; }; } forEach (keys (localNamespace getVariable "AP_dutyRoster"));
        {
            private _e = (localNamespace getVariable "AP_dutyRoster") get _x;
            (localNamespace getVariable "AP_dutyRoster") deleteAt _x;
            AP_dutyCooldown set [_x, time];
            ["-DUTY-", objNull, format ["RELEASED faction=%1 uid=%2 reason=sweep (gone)", _e param [0, ""], _x]] call APS_fnc_logIt;
        } forEach _stale;
        if !(_stale isEqualTo []) then { call APS_fnc_dutyRecount; };

        // 2. GROUP-vs-ROSTER RECONCILIATION -- the other direction, and the one that matters for cheating.
        // Both duty groups are published by netId (they have to be: the client resolves them from the
        // payload), so a modified client can `[player] joinSilent (groupFromNetId AP_dutyGroupCopNet)` and
        // become a side-west MaxSec member without ever touching this file: no whitelist read, no cooldown,
        // no roster entry, no headcount, and in-world indistinguishable from a real officer. The roster is
        // the ONLY authority on who belongs in these groups, so anyone else is logged and put back into a
        // civilian group. Not a substitute for the AP_effSide-gated checks -- an ejected self-joiner never
        // had AP_onDuty set client-side anyway -- but it removes the engine-side masquerade.
        // Recently-released uids get a 30s pass: `release` deletes the roster entry immediately while the
        // client's own leave-group lands a moment later, and ejecting them would only spam -SEC- with the
        // tail of every legitimate clock-off.
        // The test is roster entry FOR THIS GROUP'S FACTION, not merely "rostered": a trauma-rostered client
        // that joins the MaxSec group by netId is on side west with an independent roster entry, and a
        // membership-only test would wave it through.
        {
            _x params ["_gv", "_gvFaction"];
            private _g = missionNamespace getVariable [_gv, grpNull];
            if !(isNull _g) then {
                {
                    private _m = _x;
                    private _mu = getPlayerUID _m;
                    if ((_m in _realp)
                        && {(((localNamespace getVariable "AP_dutyRoster") getOrDefault [_mu, []]) param [0, ""]) isNotEqualTo _gvFaction}
                        && {(AP_dutyCooldown getOrDefault [_mu, -99999]) < (time - 30)}) then {
                        ["-SEC-", _m, format ["EJECTED from duty group %1: uid %2 holds no %3 roster entry", _gv, _mu, _gvFaction]] call APS_fnc_logIt;
                        [_m] joinSilent (createGroup [civilian, true]);
                    };
                } forEach (units _g);
            };
        } forEach [["AP_dutyGroupCop", "maxsec"], ["AP_dutyGroupMed", "trauma"]];

        // 3. Prune the two bookkeeping maps. A cooldown stamp older than the cooldown itself can never
        // refuse anything again, and a request stamp older than its 10s window is equally dead; left alone
        // they are two hashMaps that only ever grow, for the life of the server.
        if !(isNil "AP_dutyCooldown") then {
            private _dead = (keys AP_dutyCooldown) select { (time - (AP_dutyCooldown get _x)) > SRV_dutyCooldown };
            { AP_dutyCooldown deleteAt _x; } forEach _dead;
        };
        if !(isNil "AP_dutyReqStamp") then {
            private _deadReq = (keys AP_dutyReqStamp) select { (time - (AP_dutyReqStamp get _x)) > 60 };
            { AP_dutyReqStamp deleteAt _x; } forEach _deadReq;
        };
        if !(isNil "AP_dutyPayStamp") then {
            private _deadPay = (keys AP_dutyPayStamp) select { (time - (AP_dutyPayStamp get _x)) > 60 };
            { AP_dutyPayStamp deleteAt _x; } forEach _deadPay;
        };
    };

    default { diag_log format ["[AP-DUTY] dutySRV: unknown mode %1 from owner %2", _mode, _src]; };
};
