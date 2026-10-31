// SPDX-License-Identifier: MIT
/*
    server/fn_srvFact.sqf   —   aq_fnc_srvFact

    Purpose: receive one reported fact from a client, decide whether it advances
    that player's current objective on any active quest, and push the resulting
    progress back. Also the single place progress figures are computed.

    WHY THIS EXISTS
    The client reports facts because only the client knows where the player is
    standing and what is in their inventory. That makes this function the entire
    trust boundary: everything a hostile client can say enters the system here.
    A fact handler that takes its arguments at face value hands out "I sold
    2,000,000,000 copper" and, worse, does it through the legitimate reward path
    so nothing downstream looks wrong.
    It is also why progress lives here rather than in three callers: the offer
    screen, the journal and the HUD asking three different pieces of code what
    "3 of 8" means is how a system ends up with a task marker that never clears.

    WHAT IT DOES
      - Rejects facts sent for a unit the calling machine does not own.
      - Rate-limits per player, so a client cannot spend the server's frame in a
        loop of harmless-looking facts.
      - Sanitises every argument: numbers clamped, strings length-capped, arrays
        depth- and length-capped, anything else refused.
      - Offers the fact ONLY to the current objective of each active quest.
        A fact naming an objective the player has already passed, or has not
        reached, is ignored — that ordering is what makes a chain of objectives
        mean anything.
      - Re-derives server-side whatever it can. Position is the big one: if an
        objective names a marker and a radius, the server measures the distance
        itself instead of believing "I am inside marker X".
      - Advances, completes, and pushes.

    WHAT IT CANNOT DO, STATED PLAINLY
      Facts the server cannot re-derive — "I sold 10 copper", "I killed one" —
      are trusted in kind and only bounded in degree. Closing that gap properly
      means the host firing those events from server-side code at the shop and
      the kill handler, which the profile's call-site snippets encourage but
      cannot enforce. Clamping is the floor, not the ceiling: it turns an
      unbounded exploit into a grind-speed one.

    WHERE THE FACT COMES FROM
      The client sends the EVENT — its name and its arguments — never a claim
      about which objective it advanced. Routing is this function's job, from
      state only the server holds: the fact is offered to the current objective
      of each of that player's active quests and to nothing else. A client
      naming an objective could only ever name one it was not on, so there is
      deliberately no way for it to name one at all.

    Usage:  [_player, "aq_sold", ["copper", 10]] call aq_fnc_srvFact;
            [_player, "", []] call aq_fnc_srvFact;   // resync: recompute and push

    Returns: BOOL — did anything advance.
*/

params [
    ["_player", objNull, [objNull]],
    ["_name",   "",      [""]],
    ["_args",   [],      [[]]]
];

if (!isServer) exitWith { false };
if !(localNamespace getVariable ["aq_srvReady", false]) exitWith { false };

private _reo = remoteExecutedOwner;
if (_reo > 0 && {owner _player != _reo}) exitWith {
    diag_log text format ["[AQ] SECURITY fact: machine %1 reported '%2' for a unit it does not own (%3).", _reo, _name, _player];
    false
};
if (isNull _player) exitWith { false };

// LOCAL PATCH (VENDORED.txt): a verb listed in AQ_Settings >> serverFacts[] is
// counted only when server code that WITNESSED it reports it -- the host's
// APS_fnc_aqFact, which declares _aqServerFact before calling here. A local
// variable is the one thing a client cannot put on this call stack, and
// remoteExecutedOwner cannot tell the two apart: the host's witnesses are
// themselves remoteExec'd by that client and still read its id. Without this a
// single [player, "robstore", [10000]] remoteExec satisfied the objective.
if (_name != "" && {isNil "_aqServerFact"} && {_name in (["serverFacts", []] call aq_fnc_setting)}) exitWith {
    diag_log text format ["[AQ] SECURITY fact: machine %1 reported server-only fact '%2' for %3; dropped.", _reo, _name, _player];
    false
};

private _uidFn = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
if (_uidFn isEqualTo {}) exitWith { false };
private _uid = [_player] call _uidFn;
if (!(_uid isEqualType "") || {_uid isEqualTo ""}) exitWith { false };

private _pst = ["player", _uid] call aq_fnc_srvStore;
if (isNil "_pst") exitWith { false };
private _active = _pst getOrDefault ["active", createHashMap];
private _now = (localNamespace getVariable "aq_srvEpochBase") + time;

// ---------------------------------------------------------- rate limit -----
// Only real facts are counted; a resync is answered from state the server
// already holds and cannot be used to make the server do work.
// The result is carried in a flag rather than an exitWith inside the `then`
// block: exitWith leaves the block it is written in, not the function, and a
// rate limiter that only exits the `if` is a rate limiter that does nothing.
private _rateOk = true;
if (_name != "") then {
    if (isNil {localNamespace getVariable "aq_srvFactRate"}) then { localNamespace setVariable ["aq_srvFactRate", createHashMap]; };
    private _rl = (localNamespace getVariable "aq_srvFactRate") getOrDefault [_uid, [_now, 0, 0]];
    _rl params ["_win", "_n", "_warned"];
    if (_now - _win >= 10) then { _win = _now; _n = 0; _warned = 0; };
    _n = _n + 1;

    private _cap = ["factRateLimit", 60] call aq_fnc_setting;   // per 10 seconds
    if (!(_cap isEqualType 0) || {_cap < 1}) then { _cap = 60; };
    if (_n > _cap) then {
        _rateOk = false;
        if (_warned == 0) then {
            _warned = 1;
            diag_log text format ["[AQ] SECURITY fact: %1 exceeded %2 facts/10s (latest '%3'); dropping the excess. Either the host is firing an event in a loop, or this client is not stock.", _uid, _cap, _name];
        };
    };
    (localNamespace getVariable "aq_srvFactRate") set [_uid, [_win, _n, _warned]];
};
if (!_rateOk) exitWith { false };

// ----------------------------------------------------------- sanitising ----
private _maxCount = ["factMaxCount", 10000] call aq_fnc_setting;
if (!(_maxCount isEqualType 0) || {_maxCount <= 0}) then { _maxCount = 10000; };

private _dirtyInput = false;
private _clean = {
    params ["_v", ["_depth", 0]];
    switch (true) do {
        case (_v isEqualType 0): {
            // NaN and infinity survive arithmetic and poison every comparison
            // they touch, so they are rejected rather than clamped.
            if !(finite _v) exitWith { _dirtyInput = true; 0 };
            (_v min _maxCount) max (-_maxCount)
        };
        case (_v isEqualType ""): {
            if (count _v > 64) then { _dirtyInput = true; _v select [0, 64] } else { _v }
        };
        case (_v isEqualType true): { _v };
        case (_v isEqualType []): {
            if (_depth >= 2) exitWith { _dirtyInput = true; [] };
            private _a = _v;
            if (count _a > 16) then { _dirtyInput = true; _a = _a select [0, 16]; };
            _a apply { [_x, _depth + 1] call _clean }
        };
        default { _dirtyInput = true; "" };
    };
};
private _factArgs = [_args, 0] call _clean;
if (_dirtyInput && {_name != ""}) then {
    diag_log text format ["[AQ] SECURITY fact: %1 sent '%2' with out-of-range arguments; clamped. Raw: %3", _uid, _name, _args];
};

// ------------------------------------------------- objective resolution ----
// Authored quests read their objective from config; radiant instances carry
// resolved HashMaps. aq_fnc_cfgGet reads both, so nothing below cares which.
private _objCfgOf = {
    params ["_qstate", "_objId"];
    private _inst = _qstate getOrDefault ["inst", createHashMap];
    if (count _inst > 0) exitWith {
        private _found = createHashMap;
        { if ((_x getOrDefault ["id", ""]) isEqualTo _objId) exitWith { _found = _x; }; }
            forEach (_inst getOrDefault ["objectives", []]);
        _found
    };
    private _qc = [_qstate getOrDefault ["quest", ""]] call aq_fnc_cfgQuest;
    if (isNull _qc) exitWith { configNull };
    _qc >> "objectives" >> _objId
};

private _titleOf = {
    params ["_qstate"];
    private _inst = _qstate getOrDefault ["inst", createHashMap];
    private _src = if (count _inst > 0) then { _inst } else { [_qstate getOrDefault ["quest", ""]] call aq_fnc_cfgQuest };
    [[_src, "title", _qstate getOrDefault ["quest", ""]] call aq_fnc_cfgGet] call aq_fnc_text
};

// The wire payload for one quest. Positional and small on purpose: it crosses
// the network on every objective tick, and its shape is documented in
// fn_srvInit.sqf's contract block rather than being inferred from the journal.
//   [questId, state, index, objIds, [[objId, cur, max, text], ...],
//    deadline, title, summary, packedInstance]
private _payloadOf = {
    params ["_qstate"];
    private _qid  = _qstate getOrDefault ["quest", ""];
    private _inst = _qstate getOrDefault ["inst", createHashMap];
    private _src  = if (count _inst > 0) then { _inst } else { [_qid] call aq_fnc_cfgQuest };
    private _prog = [];
    {
        private _objId = _x;
        private _ocfg  = [_qstate, _objId] call _objCfgOf;
        private _type  = [_ocfg, "type", ""] call aq_fnc_cfgGet;
        private _tfn   = (localNamespace getVariable "aq_types") getOrDefault [_type, {}];
        private _row   = [0, 1, _objId];
        if !(_tfn isEqualTo {}) then {
            private _ctx = createHashMap;
            _ctx set ["quest", _qid];
            _ctx set ["objective", _objId];
            _ctx set ["cfg", _ocfg];
            _ctx set ["state", (_qstate getOrDefault ["objState", createHashMap]) getOrDefault [_objId, createHashMap]];
            _ctx set ["player", _player];
            private _r = ["progress", _ctx] call _tfn;
            // progress is mandatory in the type contract, but a type that
            // returns rubbish must degrade to a readable line rather than
            // corrupt the journal for every quest on screen.
            if (_r isEqualType [] && {count _r >= 3}) then { _row = _r } else {
                diag_log text format ["[AQ] fact: type '%1' returned %2 for the progress verb on objective '%3'; expected [cur, max, text].", _type, _r, _objId];
            };
        };
        private _label = _row select 2;
        if !(_label isEqualType "") then { _label = str _label; };
        _prog pushBack [_objId, _row select 0, _row select 1, _label];
    } forEach (_qstate getOrDefault ["objIds", []]);

    [
        _qid,
        _qstate getOrDefault ["state", "active"],
        _qstate getOrDefault ["index", 0],
        _qstate getOrDefault ["objIds", []],
        _prog,
        // SECONDS REMAINING, not the stamp. The stamp is on the server's
        // absolute clock (see fn_srvInit, CLOCK) and the client has no way to
        // read it: it holds mission time, which restarts, and no epoch base.
        // Sending the difference is the only form both machines can agree on.
        // 0 means no limit; a deadline already past reads as 0, not negative.
        ([0, ((_qstate getOrDefault ["deadline", 0]) - _now) max 0] select ((_qstate getOrDefault ["deadline", 0]) > 0)),
        [[_src, "title", _qid] call aq_fnc_cfgGet] call aq_fnc_text,
        [[_src, "summary", ""] call aq_fnc_cfgGet] call aq_fnc_text,
        ["pack", _inst] call aq_fnc_srvStore
    ]
};

private _own = owner _player;

// ------------------------------------------------------------- resync ------
// Used on join, after acceptance, and any time the client asks. The client is
// stateless about quests by design: it is always told, never remembers.
if (_name isEqualTo "") exitWith {
    if (_own > 0) then {
        private _all = [];
        { _all pushBack ([_y] call _payloadOf); } forEach _active;
        ["state", [_all]] remoteExec ["aq_fnc_sync", _own];
    };
    true
};

// -------------------------------------------------------------- routing ----
private _advanced = false;
private _changed  = [];

{
    private _qid    = _x;
    private _qstate = _y;
    if ((_qstate getOrDefault ["state", ""]) isEqualTo "active") then {
        private _objIds = _qstate getOrDefault ["objIds", []];
        private _idx    = _qstate getOrDefault ["index", 0];

        if (_idx >= 0 && {_idx < count _objIds}) then {
            private _objId = _objIds select _idx;
            private _ocfg  = [_qstate, _objId] call _objCfgOf;
            private _type  = [_ocfg, "type", ""] call aq_fnc_cfgGet;
            private _tfn   = (localNamespace getVariable "aq_types") getOrDefault [_type, {}];

            if (_tfn isEqualTo {}) then {
                diag_log text format ["[AQ] fact: quest '%1' objective '%2' names type '%3', which is not registered. The quest cannot progress.", _qid, _objId, _type];
            } else {
                // Server-side re-derivation. If the objective is anchored to a
                // place, the server measures the distance rather than believing
                // the report. The slack absorbs the position update the server
                // has not received yet; it is not a tolerance for being wrong.
                private _geoOk = true;
                private _marker = [_ocfg, "marker", ""] call aq_fnc_cfgGet;
                if (_marker isEqualType "" && {_marker != ""}) then {
                    private _radius = [_ocfg, "radius", 0] call aq_fnc_cfgGet;
                    if (!(_radius isEqualType 0) || {_radius <= 0}) then { _radius = 25; };
                    private _slack = ["factGeoSlack", 1.5] call aq_fnc_setting;
                    if (!(_slack isEqualType 0) || {_slack < 1}) then { _slack = 1.5; };
                    private _mp = getMarkerPos _marker;
                    if (_mp isEqualTo [0,0,0]) then {
                        diag_log text format ["[AQ] fact: objective '%1' of quest '%2' names marker '%3', which does not exist. Distance cannot be checked, so the fact is refused rather than trusted.", _objId, _qid, _marker];
                        _geoOk = false;
                    } else {
                        if ((getPosWorld _player) distance2D _mp > _radius * _slack) then {
                            _geoOk = false;
                            diag_log text format ["[AQ] SECURITY fact: %1 reported '%2' for objective '%3' of '%4' while %5m from marker '%6' (radius %7).",
                                _uid, _name, _objId, _qid, round ((getPosWorld _player) distance2D _mp), _marker, _radius];
                        };
                    };
                };

                if (_geoOk) then {
                    private _ostate = (_qstate getOrDefault ["objState", createHashMap]) getOrDefault [_objId, createHashMap];
                    private _ctx = createHashMap;
                    _ctx set ["quest", _qid];
                    _ctx set ["objective", _objId];
                    _ctx set ["cfg", _ocfg];
                    _ctx set ["state", _ostate];
                    _ctx set ["player", _player];
                    _ctx set ["event", [_name, _factArgs]];
                    /*
                        The authoritative invocation. A type's `event` verb runs
                        twice — once on the reporting client, for its own
                        watcher teardown and display, and once here against the
                        state the server actually keeps. This flag is how a type
                        tells the two apart, and everything that consumes an
                        item or changes the host's world sits behind it. Without
                        it a delivery is consumed on both machines, which on a
                        listen server means the same cargo taken twice, and on a
                        dedicated one means a client deciding what it spent.
                    */
                    _ctx set ["server", true];

                    private _before = str _ostate;
                    private _done = ["event", _ctx] call _tfn;
                    // The type mutates its own state in place; the server holds
                    // the authoritative copy of it. The client's copy of the
                    // same state holds only watcher handles and is discarded.
                    (_qstate getOrDefault ["objState", createHashMap]) set [_objId, _ostate];

                    if (_done isEqualType true && {_done}) then {
                        _qstate set ["index", _idx + 1];
                        _advanced = true;
                        _changed pushBackUnique _qid;
                    } else {
                        if (str _ostate != _before) then { _changed pushBackUnique _qid; };
                    };
                };
            };
        };
    };
} forEach _active;

if (count _changed > 0) then {
    ["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore;
};

// Completion is checked after the walk, not inside it: fn_srvComplete removes
// the quest from the very map being iterated.
{
    private _qstate = _active getOrDefault [_x, nil];
    if !(isNil "_qstate") then {
        if ((_qstate getOrDefault ["index", 0]) >= count (_qstate getOrDefault ["objIds", []])) then {
            [_player, _x] call aq_fnc_srvComplete;
        } else {
            if (_own > 0) then { ["quest", ([_qstate] call _payloadOf)] remoteExec ["aq_fnc_sync", _own]; };
        };
    };
} forEach _changed;

_advanced
