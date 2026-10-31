// SPDX-License-Identifier: MIT
/*
    server/fn_srvFail.sqf   —   aq_fnc_srvFail

    Purpose: end a quest without completing it — failed, expired, or abandoned —
    with the same bookkeeping rigour as completion.

    WHY THIS EXISTS
    "Quests can be lost" is only true if losing one is as carefully recorded as
    winning one. A failure path that just deletes the active entry produces
    quests that quietly re-offer themselves a second later (so failure costs
    nothing and the time limit is decoration), or that vanish for good when they
    were meant to be repeatable (so a player loses content to a disconnect).
    Both are the same missing step: the terminal state has to write the cooldown,
    exactly as completion does, from the same `repeatable` value.

    It also has to work with no player object at all. Expiry is swept on a timer
    and the owner may have logged out mid-run — the quest still ends, and the
    record still has to say so before the next flush.

    WHAT IT DOES
      1. Accepts the three terminal reasons and normalises anything else.
      2. Forces a remote caller's reason to "abandoned" — the only terminal
         transition a player is entitled to ask for.
      3. Removes the active entry, stamps the cooldown, marks the record dirty.
      4. Notifies the owner if there is one.
      No reward is granted and no receipt is cleared: a partial payout that was
      already made stays recorded, so a later retry of a *repeatable* quest
      cannot be used to farm the grants that already succeeded.

    Usage:  [_player, "copper_run", "abandoned"] call aq_fnc_srvFail;
            [objNull, "copper_run", "expired", _uid] call aq_fnc_srvFail;

    Returns: BOOL — was a terminal transition actually written.
*/

params [
    ["_player",  objNull, [objNull]],
    ["_questId", "",      [""]],
    ["_reason",  "failed", [""]],
    ["_uidIn",   "",      [""]]
];

if (!isServer) exitWith { false };
if !(localNamespace getVariable ["aq_srvReady", false]) exitWith { false };
if (_questId isEqualTo "") exitWith { false };

private _reo = remoteExecutedOwner;
if (_reo > 0) then {
    // LOCAL PATCH (VENDORED.txt): a remote caller never names the owner. The
    // uid argument exists for the timer sweep's absent player; from a client it
    // was the victim's uid riding on the caller's own (ownership-checked) unit,
    // which let anyone end anyone's quests. Remote calls derive it from _player.
    _uidIn = "";
    if (owner _player != _reo) exitWith {
        diag_log text format ["[AQ] SECURITY fail: machine %1 tried to end '%2' for a unit it does not own.", _reo, _questId];
        _questId = "";
    };
    // A client may give up. It may not declare its own quest expired or failed:
    // those are the server's verdicts, and letting a client pick the reason
    // lets it choose the cheaper cooldown.
    if (_reason != "abandoned") then {
        diag_log text format ["[AQ] fail: remote caller asked for reason '%1' on '%2'; recorded as 'abandoned'.", _reason, _questId];
        _reason = "abandoned";
    };
};
if (_questId isEqualTo "") exitWith { false };

if !(_reason in ["failed", "expired", "abandoned"]) then {
    diag_log text format ["[AQ] fail: unknown reason '%1' for '%2'; recorded as 'failed'.", _reason, _questId];
    _reason = "failed";
};

// The uid may arrive directly (timer sweep for an absent player) or via the
// unit. Neither is preferred: whichever is available is the truth here.
private _uid = _uidIn;
if (_uid isEqualTo "" && {!isNull _player}) then {
    private _uidFn = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
    if !(_uidFn isEqualTo {}) then { _uid = [_player] call _uidFn; };
};
if (!(_uid isEqualType "") || {_uid isEqualTo ""}) exitWith {
    diag_log text format ["[AQ] fail: cannot identify the owner of '%1'; nothing recorded.", _questId];
    false
};

private _pst = ["player", _uid] call aq_fnc_srvStore;
if (isNil "_pst") exitWith { false };
private _active = _pst getOrDefault ["active", createHashMap];
private _qstate = _active getOrDefault [_questId, nil];
if (isNil "_qstate") exitWith { false };

private _now  = (localNamespace getVariable "aq_srvEpochBase") + time;
private _inst = _qstate getOrDefault ["inst", createHashMap];
private _src  = if (count _inst > 0) then { _inst } else { [_questId] call aq_fnc_cfgQuest };

_qstate set ["state", _reason];
_active deleteAt _questId;

private _repeat = [_src, "repeatable", 0] call aq_fnc_cfgGet;
if (_repeat isEqualType "") then { _repeat = parseNumber _repeat; };
if !(_repeat isEqualType 0) then { _repeat = 0; };

private _cool = _pst getOrDefault ["cooldown", createHashMap];
if (count _inst > 0) then {
    // A radiant instance cannot be re-offered — the board will roll a new one —
    // so keeping a cooldown keyed to a dead instance id would only grow the
    // record. The slot cooldowns recorded at accept time already stop the same
    // place coming straight back.
    _cool deleteAt _questId;
} else {
    switch (true) do {
        // A once-only quest that was lost is lost. That is what makes the time
        // limit on a once-only quest mean anything at all; a host that wants a
        // second chance gives the quest a `repeatable` cooldown.
        case (_repeat isEqualTo 0):  { _cool set [_questId, -1]; };
        case (_repeat isEqualTo -1): { _cool deleteAt _questId; };
        default                      { _cool set [_questId, _now + _repeat]; };
    };
};

["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore;

private _title = [[_src, "title", _questId] call aq_fnc_cfgGet] call aq_fnc_text;
private _own = if (isNull _player) then { 0 } else { owner _player };
if (_own > 0) then {
    ["terminal", [_questId, _title, _reason]] remoteExec ["aq_fnc_sync", _own];
    // The announcement is not the state. Without the resync the client keeps a
    // lost quest on screen with its watchers armed and still reporting facts
    // against it, which is exactly the leak abandonment exists to close.
    [_player, "", []] call aq_fnc_srvFact;
};

diag_log text format ["[AQ] fail: %1 lost '%2' (%3).", _uid, _questId, _reason];

true
