// SPDX-License-Identifier: MIT
/*
    server/fn_srvInit.sqf   —   aq_fnc_srvInit

    Purpose: bring the authoritative half of ArmaQuest online. Loads persisted
    state, builds the offer board, and starts the two background timers
    (write-behind flush, expiry sweep).

    WHY THIS EXISTS
    A quest system with no single boot point acquires half a dozen implicit
    ones: a board built lazily on first interaction, a store opened on first
    write, timers started by whichever function happens to run first. Order
    then depends on who talks to a giver first, which is unreproducible and
    makes "the board was empty after a restart" impossible to diagnose. One
    boot function that runs once, checks its dependencies by name and refuses
    to come up half-wired turns a silent misconfiguration into a startup error.

    WHAT IT DOES
      1. Refuses to run anywhere but the server, and refuses to run twice.
      2. Establishes the absolute clock (see CLOCK below) — cooldowns and
         expiries must survive a mission restart, so they cannot be mission time.
      3. Verifies every function this area calls into actually exists, and names
         each missing one. A missing dependency aborts boot loudly.
      4. Loads the persisted board and marks the store live.
      5. Builds/refills the board (`aq_fnc_srvBoard`).
      6. Starts the flush timer and the expiry sweep.
      7. Installs a disconnect handler that flushes the leaver's state.

    Usage:  [] call aq_fnc_srvInit;      // from the mission's server init

    ---------------------------------------------------------------------------
    SERVER AREA CONTRACT — read this before editing anything under server/.
    ---------------------------------------------------------------------------

    CLOCK.  All persisted stamps (cooldowns, offer expiries, radiant recent-use)
    are absolute UTC epoch seconds, never mission `time`. `time` restarts with
    the mission, so a cooldown stored as mission time is a cooldown that expires
    on restart. Read the current stamp anywhere in this area as:

        private _now = (localNamespace getVariable "aq_srvEpochBase") + time;

    aq_srvEpochBase is fixed at boot to (epoch at boot - time at boot).

    SERVER GLOBALS (server localNamespace only; never published to clients)
    LOCAL PATCH (VENDORED.txt): these, aq_srvFactRate (fn_srvFact) and
    aq_srvStoreDirty (fn_srvStore) are read and written ONLY through
    localNamespace. A client's publicVariable overwrites a missionNamespace
    global on the server too: aq_srvReady=false switched the system off,
    a moved aq_srvEpochBase shifted every deadline and cooldown, and a forged
    aq_srvBoard offer carried its own objectives and rewards into srvAccept.
      aq_srvReady      BOOL     boot completed
      aq_srvEpochBase  NUMBER   see CLOCK
      aq_srvPlayers    HashMap  uid -> pstate
      aq_srvBoard      HashMap  giverId -> ARRAY of offer
      aq_srvSeq        NUMBER   monotonic counter for generated instance ids

    pstate  HashMap (persisted per player, key "player:<uid>")
      "uid"       STRING
      "completed" HashMap questId -> NUMBER   times completed
      "cooldown"  HashMap questId -> NUMBER   epoch when offerable again,
                                              -1 = permanently locked
      "active"    HashMap questId -> qstate
      "offers"    HashMap questId -> offer    personal offers (chain, onDemand)
      "recent"    HashMap "<pool>:<value>" -> NUMBER   epoch when the entry was
                                              LAST USED (radiant notUsedWithin
                                              history). Last-used, not an expiry:
                                              the generator's filter is
                                              (now - last) < notUsedWithin, and
                                              the window belongs to the slot
                                              asking, not to the stamp. Storing
                                              an expiry would bake one template's
                                              window into a record every other
                                              template also reads.

    qstate  HashMap (one accepted quest)
      "quest"    STRING   quest id, or the instance id for a radiant quest
      "giver"    STRING
      "state"    STRING   "active" | "completed" | "failed" | "expired"
                          | "abandoned"
      "started"  NUMBER   epoch
      "deadline" NUMBER   epoch, 0 = no time limit
      "index"    NUMBER   index of the current objective
      "objIds"   ARRAY    objective ids in declaration order
      "objState" HashMap  objective id -> the type's own mutable state HashMap
      "paid"     ARRAY    receipt keys already granted (see fn_srvPayout)
      "inst"     HashMap  radiant instance snapshot, or empty for authored

    offer   HashMap
      "quest"   STRING   quest id (authored) or instance id (radiant)
      "giver"   STRING
      "expires" NUMBER   epoch, 0 = never
      "inst"    HashMap  radiant instance, empty for authored
      "used"    ARRAY    [["<pool>:<value>", cooldownSeconds], ...]
                         The pair is what makes the stamp meaningful: the key
                         says which pool entry the offer spent, the number says
                         for how long taking it should keep the generator away
                         from it. Both come from the slot that drew it.

    CLIENT-FACING CALLS THIS AREA MAKES (one entry point, by design)
        [_topic, _data] remoteExec ["aq_fnc_sync", _ownerId];

      Payloads are nested arrays only. Nothing here depends on how the engine
      serialises a HashMap over the network; where a HashMap has to travel it is
      converted with ["pack", _hm] call aq_fnc_srvStore, whose format is one
      rule — a HashMap becomes ["#aq.h", [[key, packedValue], ...]] — so the
      client can restore it with a few lines and no shared code.

        "quest"       [questId, state, index, objIds,
                       [[objId, cur, max, text], ...],
                       remaining, title, summary, packedInstance]
        "state"       [[ <a "quest" payload>, ... ]]        every active quest
        "board"       [giverId, [[questId, title, summary,
                                  [objectiveLine, ...], remaining,
                                  packedInstance], ...]]
        "offerResult" [ok, reason, questId]
        "complete"    [questId, title, receipts, chainedQuestId]
        "terminal"    [questId, title, "failed"|"expired"|"abandoned"]
        "error"       [code, questId]

      `remaining` is SECONDS LEFT at the moment of sending, or 0 for no limit.
      Deliberately not the absolute stamp: the stamps this area keeps are on the
      clock established below, and a client has no way to read that clock — it
      holds mission `time`, which restarts, and no epoch base of its own. A
      countdown does go slightly stale in flight, and a few hundred milliseconds
      on a thirty-minute deadline is a far smaller error than a client
      subtracting two numbers from different clocks.

    CLIENT-TO-SERVER ENTRY POINTS (remoteExec'd to the server, id 2)
        [_player, _giverId, _questId]  -> aq_fnc_srvAccept
        [_player, _factName, _args]    -> aq_fnc_srvFact
        [_player, "", []]              -> aq_fnc_srvFact   (resync; the client
                                          holds no quest state of its own and
                                          asks for it on join)
        [_player, _questId, "abandoned"] -> aq_fnc_srvFail
        ["offers", _giverId, _player]  -> aq_fnc_srvBoard
      Every one of them re-derives the caller from remoteExecutedOwner and
      refuses to act for a unit the calling machine does not own. If the host
      mission uses a CfgRemoteExec whitelist, these four and the client-side
      aq_fnc_sync all need entries: a whitelist rejection is silent on the
      calling machine and looks exactly like the server ignoring the player.

    CALLS INTO OTHER AREAS (these are the names the design fixes; this area
    treats them as existing and fails loudly at boot if they do not)
      [_key, _default]            call aq_fnc_setting    AQ_Settings reader
      [_questId]                  call aq_fnc_cfgQuest   CONFIG or configNull
      [_key]                      call aq_fnc_profile    STRING fn name or ""
      [_cfgOrMap, _key, _default] call aq_fnc_cfgGet     value from CONFIG or
                                                         HashMap alike
      [_text]                     call aq_fnc_text       resolves $STR_
      [_giverId, _player]         call aq_fnc_genOffer   radiant instance
                                                         HashMap, empty on fail
    Two lookups are read straight from the indexes preInit built rather than
    through a function, because a wrapper over one HashMap read is a name that
    can go missing without anything else changing:
      aq_idxGiver getOrDefault [_giverId, configNull]    the giver's config
      aq_types    getOrDefault [_typeName, {}]           the objective plugin

    DESIGN NOTE (recorded because DESIGN.md leaves it open): the objective-type
    ctx key "cfg" is documented as a CONFIG. A radiant instance has no config
    class, so this area passes the resolved objective HashMap instead and reads
    every field through aq_fnc_cfgGet, which accepts both. The alternative —
    materialising a config class at runtime — is not possible, and letting the
    client supply the objective's parameters would move authority to the client.
*/

if (!isServer) exitWith {
    diag_log text "[AQ] srvInit called on a non-server machine; ignored.";
    false
};

if ((localNamespace getVariable ["aq_srvReady", false]) isEqualTo true) exitWith {
    diag_log text "[AQ] srvInit called twice; ignoring the second call.";
    true
};

// ---------------------------------------------------------------- clock ----
// UNVERIFIED: systemTimeUTC returns [year, month, day, hour, minute, second]
// (later patches append milliseconds; only the first six are read here).
// Confirm with:  diag_log str systemTimeUTC;
private _st = systemTimeUTC;
if (count _st < 6) exitWith {
    diag_log text "[AQ] FATAL srvInit: systemTimeUTC returned an unexpected shape; cannot establish the persistence clock.";
    false
};
_st params ["_yr", "_mo", "_dy", "_hh", "_mm", "_ss"];

// Days from the civil calendar epoch (1970-01-01). Integer arithmetic only, so
// there is no drift and no dependency on the mission date.
private _y  = _yr - ([0, 1] select (_mo <= 2));
private _era = floor ((([_y, _y - 399] select (_y < 0))) / 400);
private _yoe = _y - _era * 400;
private _doy = floor ((153 * (_mo + ([-3, 9] select (_mo <= 2))) + 2) / 5) + _dy - 1;
private _doe = _yoe * 365 + floor (_yoe / 4) - floor (_yoe / 100) + _doy;
private _days = _era * 146097 + _doe - 719468;
localNamespace setVariable ["aq_srvEpochBase", (_days * 86400 + _hh * 3600 + _mm * 60 + _ss) - time];

// ------------------------------------------------------ dependency gate ----
private _needed = [
    "aq_fnc_setting", "aq_fnc_cfgQuest", "aq_fnc_profile", "aq_fnc_cfgGet",
    "aq_fnc_text",
    "aq_fnc_srvStore", "aq_fnc_srvBoard", "aq_fnc_srvAccept",
    "aq_fnc_srvFact", "aq_fnc_srvComplete", "aq_fnc_srvFail", "aq_fnc_srvPayout"
];
private _missing = _needed select {
    private _f = missionNamespace getVariable [_x, {}];
    !(_f isEqualType {}) || {_f isEqualTo {}}
};
if (count _missing > 0) exitWith {
    {
        diag_log text format ["[AQ] FATAL srvInit: required function %1 is not defined.", _x];
    } forEach _missing;
    diag_log text "[AQ] FATAL srvInit: aborting boot. ArmaQuest is OFF; no quest can be accepted or paid.";
    localNamespace setVariable ["aq_srvReady", false];
    false
};

// aq_fnc_genOffer is only required when radiant content is configured. Its
// absence is reported once here rather than at every board refill.
if ((missionNamespace getVariable ["aq_fnc_genOffer", {}]) isEqualTo {}) then {
    diag_log text "[AQ] srvInit: aq_fnc_genOffer is not defined; radiant offers will be skipped and only authored quests will be offered.";
};

// The indexes this area reads directly. Their absence means preInit never ran,
// which is a different fault from a missing function and deserves its own line.
if (isNil "aq_idxGiver" || {isNil {localNamespace getVariable "aq_types"}}) exitWith {
    diag_log text "[AQ] FATAL srvInit: the preInit indexes (aq_idxGiver, aq_types) do not exist, so no giver and no objective type can be resolved. Is aq_fnc_preInit registered with preInit = 1?";
    diag_log text "[AQ] FATAL srvInit: aborting boot. ArmaQuest is OFF; no quest can be accepted or paid.";
    localNamespace setVariable ["aq_srvReady", false];
    false
};

// -------------------------------------------------------------- state ------
localNamespace setVariable ["aq_srvPlayers", createHashMap];
localNamespace setVariable ["aq_srvSeq",     0];
localNamespace setVariable ["aq_srvBoard",   createHashMap];

// The store must come up before anything reads player state, so this call is
// the one place that is allowed to block boot on it.
private _storeOk = ["init"] call aq_fnc_srvStore;
if (!_storeOk) then {
    diag_log text "[AQ] srvInit: the store driver failed to initialise. The system will run, but NOTHING WILL PERSIST this session.";
};

// The board is server state, not player state: it is loaded once, here.
// `load` answers "HashMap or nil", and in SQF assigning nil to a private does
// not define it -- so on the nil branch _savedBoard does not exist at all, and
// merely reading it throws. Guard with isNil FIRST, exactly as the three other
// callers of a nil-returning store verb already do (fn_srvAccept, fn_srvFact,
// fn_srvComplete). A store that failed to initialise returns nil here, which is
// the ordinary case on a fresh or unreachable database, not an exceptional one.
private _savedBoard = ["load", "board"] call aq_fnc_srvStore;
if (!isNil "_savedBoard" && {_savedBoard isEqualType createHashMap}) then {
    localNamespace setVariable ["aq_srvBoard", _savedBoard];
    private _n = 0;
    { _n = _n + count _y } forEach _savedBoard;
    diag_log text format ["[AQ] srvInit: restored %1 board offer(s) across %2 giver(s).", _n, count _savedBoard];
};

localNamespace setVariable ["aq_srvReady", true];

// -------------------------------------------------------------- givers -----
// Before the board, because a giver with no object is a giver no client can
// arm, and the client's arming pass (aq_fnc_postInit) starts looking for these
// as soon as it has a player.
[] call aq_fnc_srvSpawnGivers;

// -------------------------------------------------------------- board ------
["init"] call aq_fnc_srvBoard;

// -------------------------------------------------------------- timers -----
private _flushIv = ["flushInterval", 60] call aq_fnc_setting;
if (!(_flushIv isEqualType 0) || {_flushIv < 5}) then { _flushIv = 60; };

private _sweepIv = ["sweepInterval", 5] call aq_fnc_setting;
if (!(_sweepIv isEqualType 0) || {_sweepIv < 1}) then { _sweepIv = 5; };

// Write-behind. Progress ticks mark state dirty; only this loop writes. A
// system that saved on every objective tick would issue one database round
// trip per bullet fired at a bounty target.
[_flushIv] spawn {
    params ["_iv"];
    while {true} do {
        sleep _iv;
        if (localNamespace getVariable ["aq_srvReady", false]) then { ["flush"] call aq_fnc_srvStore; };
    };
};

// Expiry sweep: offer lifetimes and quest time limits. UNVERIFIED: scheduled
// scripts are frame-budgeted, so this loop can drift by seconds under load.
// Deadlines are therefore treated as "no earlier than", never as exact — the
// design's timeLimit is a pressure device, not a stopwatch.
[_sweepIv] spawn {
    params ["_iv"];
    while {true} do {
        sleep _iv;
        if (localNamespace getVariable ["aq_srvReady", false]) then {
            ["sweep"] call aq_fnc_srvBoard;

            private _now = (localNamespace getVariable "aq_srvEpochBase") + time;
            // Collected first, then acted on: fn_srvFail mutates the very maps
            // being walked, and mutating a HashMap during its own forEach is
            // exactly the kind of bug that only shows up under load.
            private _due = [];
            {
                private _pst = _y;
                private _uid = _x;
                {
                    private _dl = _y getOrDefault ["deadline", 0];
                    if (_dl > 0 && {_now > _dl}) then { _due pushBack [_uid, _x]; };
                } forEach (_pst getOrDefault ["active", createHashMap]);
            } forEach (localNamespace getVariable "aq_srvPlayers");

            // The owner may have logged out while the clock ran down, so the
            // unit is resolved best-effort and the uid is passed explicitly:
            // an expiry must be booked whether or not anyone is there to see it.
            // The name is resolved rather than the call made through
            // aq_fnc_profile, because this loop calls it once per online player
            // per expiry and the lookup is the expensive half.
            private _uidFn = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
            {
                _x params ["_uid", "_qid"];
                private _unit = objNull;
                if !(_uidFn isEqualTo {}) then {
                    {
                        if (([_x] call _uidFn) isEqualTo _uid) exitWith { _unit = _x; };
                    } forEach allPlayers;
                };
                [_unit, _qid, "expired", _uid] call aq_fnc_srvFail;
            } forEach _due;
        };
    };
};

// A leaver's state is flushed immediately: the write-behind window is the one
// place where a crash can lose real progress, and disconnect is when a player
// is most likely to check whether it stuck.
addMissionEventHandler ["HandleDisconnect", {
    // UNVERIFIED: HandleDisconnect passes [unit, id, uid, name]. Confirm with a
    // diag_log of _this on a real disconnect. Returning false must be preserved
    // or the engine will not clean the body up.
    params [["_unit", objNull, [objNull]], ["_id", 0, [0]], ["_uid", "", [""]]];
    // pg-native U1: this handler is UNSCHEDULED and was the tree's one live
    // unscheduled->DB path. The store's save is a mode-2 read-back verify, and
    // apdb refuses mode 2 outside a scheduled context (fn_pysqfCall's
    // !canSuspend guard) -- so under PySQF/PostgreSQL the leaver's flush was
    // silently lost, the exact loss this handler exists to prevent. Spawn-and-
    // carry, the fn_dutySRV.sqf idiom: the uid rides into the thread as an
    // argument (frame-locals die with the frame), the save+flush PAIR stays
    // together, and the handler still returns false so the engine cleans up.
    if (_uid != "" && {localNamespace getVariable ["aq_srvReady", false]}) then {
        [_uid] spawn {
            params ["_uid"];
            ["save", format ["player:%1", _uid]] call aq_fnc_srvStore;
            ["flush"] call aq_fnc_srvStore;
        };
    };
    false
}];

diag_log text format [
    "[AQ] srvInit: online. store=%1 boardMode=%2 flush=%3s sweep=%4s",
    ["store", "profileNamespace"] call aq_fnc_setting,
    ["boardMode", "shared"] call aq_fnc_setting,
    _flushIv, _sweepIv
];

true
