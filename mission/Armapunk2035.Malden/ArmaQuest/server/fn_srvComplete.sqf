// SPDX-License-Identifier: MIT
/*
    server/fn_srvComplete.sqf   —   aq_fnc_srvComplete

    Purpose: close out a quest whose objectives are all done — pay it, record it,
    start its chain, persist, and tell the player.

    WHY THIS EXISTS
    Completion is four bookkeeping steps that must happen together or not at all:
    payout, the completed-count that later prerequisites read, the cooldown that
    governs repeats, and the chain that unlocks the next quest. Split across the
    callers that notice a quest finished, they drift: one path pays but does not
    record, another records but never chains, and the symptom appears days later
    as a quest line that stops for some players and not others.
    The order below is deliberate. Payment happens FIRST and everything else is
    conditional on it. If a grant fails the quest stays active and completable —
    the alternative, marking it complete and paying later, means the record says
    a player was paid when they were not, and nothing can tell the two apart
    afterwards.

    WHAT IT DOES
      1. Re-verifies that every objective really is done. Being called is not
         evidence; the check is cheap and this is the function that pays.
      2. Pays via aq_fnc_srvPayout. Any failure aborts here, leaving the quest
         active with its receipts, so handing in again resumes the payout.
      3. Marks completed, increments the completion count, stamps the cooldown
         from `repeatable`.
      4. Offers `chain` to this player, if it names a quest that exists.
      5. Marks the record dirty and notifies the owner.

    Usage:  [_player, "copper_run"] call aq_fnc_srvComplete;

    Returns: BOOL — did the quest actually complete.
*/

params [["_player", objNull, [objNull]], ["_questId", "", [""]]];

if (!isServer) exitWith { false };
if !(localNamespace getVariable ["aq_srvReady", false]) exitWith { false };
if (isNull _player || {_questId isEqualTo ""}) exitWith { false };

// NOT guarded on remoteExecutedOwner, deliberately. This function is reached
// from fn_srvFact, which may itself be running inside a client's remoteExec
// frame; remoteExecutedOwner is still that client's id there, so a guard here
// would refuse every completion earned by a reported fact — the normal path.
// The invariant below carries the weight instead: the objective index is server
// state that only reported-and-validated facts advance, so a client calling
// this directly can only succeed when the server already agrees the quest is
// finished. Hosts should still leave aq_fnc_srvComplete out of any
// CfgRemoteExec whitelist; nothing legitimate calls it from a client.

private _uidFn = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
if (_uidFn isEqualTo {}) exitWith { false };
private _uid = [_player] call _uidFn;
if (!(_uid isEqualType "") || {_uid isEqualTo ""}) exitWith { false };

private _pst = ["player", _uid] call aq_fnc_srvStore;
if (isNil "_pst") exitWith { false };
private _active = _pst getOrDefault ["active", createHashMap];
private _qstate = _active getOrDefault [_questId, nil];
if (isNil "_qstate") exitWith {
    diag_log text format ["[AQ] complete: '%1' is not active for %2; ignored.", _questId, _uid];
    false
};

private _objIds = _qstate getOrDefault ["objIds", []];
if ((_qstate getOrDefault ["index", 0]) < count _objIds) exitWith {
    diag_log text format ["[AQ] complete: '%1' for %2 is only at objective %3 of %4; refusing to pay.",
        _questId, _uid, (_qstate getOrDefault ["index", 0]) + 1, count _objIds];
    false
};

private _now = (localNamespace getVariable "aq_srvEpochBase") + time;
private _inst = _qstate getOrDefault ["inst", createHashMap];
private _src  = if (count _inst > 0) then { _inst } else { [_questId] call aq_fnc_cfgQuest };
private _own  = owner _player;

// ------------------------------------------------------------- rewards -----
// A quest with no reward block is legal — some quests exist to unlock the next
// one — so an absent class is an empty payout, not an error.
private _rewards = createHashMap;
if (count _inst > 0) then {
    private _r = _inst getOrDefault ["rewards", createHashMap];
    if (_r isEqualType createHashMap) then { _rewards = _r; };
} else {
    if (!isNull _src && {isClass (_src >> "rewards")}) then { _rewards = _src >> "rewards"; };
};

([_player, _uid, _rewards, _qstate] call aq_fnc_srvPayout) params ["_paidOk", "_receipts"];

if (!_paidOk) exitWith {
    // The record is still marked dirty: the receipts written by the partial
    // payout must survive a restart, or a retry pays those grants twice.
    ["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore;
    if (_own > 0) then {
        ["error", ["payoutFailed", _questId]] remoteExec ["aq_fnc_sync", _own];
    };
    diag_log text format ["[AQ] complete: '%1' for %2 left ACTIVE because payout did not fully succeed. See the payout line above for the grant that failed.", _questId, _uid];
    false
};

// ---------------------------------------------------------- bookkeeping ----
_qstate set ["state", "completed"];
_active deleteAt _questId;

private _completed = _pst getOrDefault ["completed", createHashMap];
_completed set [_questId, (_completed getOrDefault [_questId, 0]) + 1];

private _repeat = [_src, "repeatable", 0] call aq_fnc_cfgGet;
if (_repeat isEqualType "") then { _repeat = parseNumber _repeat; };
if !(_repeat isEqualType 0) then { _repeat = 0; };

private _cool = _pst getOrDefault ["cooldown", createHashMap];
switch (true) do {
    // once: retired permanently. -1 is the sentinel every eligibility check
    // already understands, so there is no second "finished" list to keep in step.
    case (_repeat isEqualTo 0):  { _cool set [_questId, -1]; };
    case (_repeat isEqualTo -1): { _cool deleteAt _questId; };
    default                      { _cool set [_questId, _now + _repeat]; };
};

// A radiant instance is consumed by completion: its id was unique to this
// offer, so leaving state keyed on it would grow the player's record forever.
if (count _inst > 0) then {
    _completed deleteAt _questId;
    _cool deleteAt _questId;
    private _tpl = _inst getOrDefault ["template", ""];
    if (_tpl isEqualType "" && {_tpl != ""}) then {
        // Templates, not instances, are what a player can be said to have done.
        private _k = format ["template:%1", _tpl];
        _completed set [_k, (_completed getOrDefault [_k, 0]) + 1];
    };
};

// ---------------------------------------------------------------- chain ----
private _chain = [_src, "chain", ""] call aq_fnc_cfgGet;
private _chained = "";
if (_chain isEqualType "" && {_chain != ""}) then {
    private _cc = [_chain] call aq_fnc_cfgQuest;
    if (isNull _cc) then {
        diag_log text format ["[AQ] complete: quest '%1' chains to '%2', which is not in the catalogue. The chain ends here — check it with aq_fnc_reachability.", _questId, _chain];
    } else {
        // A chained quest becomes a personal offer rather than being force-
        // accepted: acceptance runs every gate in fn_srvAccept, and a chain that
        // bypassed them could hand a player a quest their side or licences say
        // they cannot have.
        private _offer = createHashMap;
        _offer set ["quest", _chain];
        _offer set ["giver", [_cc, "giver", ""] call aq_fnc_cfgGet];
        _offer set ["expires", 0];
        _offer set ["inst", createHashMap];
        _offer set ["used", []];
        (_pst getOrDefault ["offers", createHashMap]) set [_chain, _offer];
        _chained = _chain;
    };
};

["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore;

private _title = [[_src, "title", _questId] call aq_fnc_cfgGet] call aq_fnc_text;
if (_own > 0) then {
    ["complete", [_questId, _title, _receipts, _chained]] remoteExec ["aq_fnc_sync", _own];
    // The announcement is not the state. The client holds no quest state of its
    // own, so it keeps showing a finished quest — with its watchers still armed
    // and still reporting — until it is told otherwise. A resync is what tells
    // it, and it is the same push the client asks for on join, so there is one
    // code path for "here is everything you hold".
    [_player, "", []] call aq_fnc_srvFact;
};

diag_log text format ["[AQ] complete: %1 finished '%2'%3.", _uid, _questId,
    ["", format [" -> chained '%1'", _chained]] select (_chained != "")];

true
