// SPDX-License-Identifier: MIT
/*
    server/fn_srvBoard.sqf   —   aq_fnc_srvBoard

    Purpose: maintain the offers each giver is holding — K radiant offers with
    individual expiries in "shared" mode, or a fresh roll per interaction in
    "onDemand" mode — and answer "what can this player take from this giver?".

    WHY THIS EXISTS
    A board is what turns generated quests into a place. If offers were rolled
    per player at the moment of interaction, two players standing at the same
    desk would see different work, nobody could say "take the one on the left,
    I'll take the other", and an expiry would be meaningless because the offer
    was never anybody's to lose. Shared offers are therefore server state: one
    board, visible to all, surviving a relog, and taken by whoever gets there
    first.
    The board also has to refill without a player present. If offers were only
    regenerated when someone looked, a server would come back from a restart
    with an empty board and stay empty until interaction, which reads as the
    quest system being broken.

    WHAT IT DOES
      ["init"]                     build/repair the board at boot
      ["sweep"]                    drop expired offers and refill      (on a timer)
      ["refill", giverId]          top one giver back up to its size
      ["take", giverId, questId]   consume an offer and immediately regenerate
      ["offers", giverId, player]  the list this player may take, as wire data
      ["clear"]                    empty the board (diagnostics, mode switches)

    PER-PLAYER FAIRNESS ON A SHARED BOARD. `notUsedWithin` is per player, but a
    shared offer is generated once for everybody, so it cannot be filtered at
    generation. It is filtered at presentation instead: an offer whose slot
    values are still on cooldown for the player looking at the board is not shown
    to that player, and the cooldown itself is stamped on accept. The board stays
    shared; the "not this place again" promise stays personal.

    Usage:  ["offers", "police_desk", _player] call aq_fnc_srvBoard;

    Returns: per verb; "offers" returns the wire payload described below.
*/

params [["_verb", "", [""]]];
// Read positionally rather than through a params default: a `params` default of
// nil is not a portable way to say "may be absent", and these two arguments
// legitimately are.
private _a = _this param [1];
private _b = _this param [2];

if (!isServer) exitWith { [] };
if !(localNamespace getVariable ["aq_srvReady", false]) exitWith {
    // "offers" is reachable from a client interaction, so this can be hit
    // legitimately during a slow boot. It is still worth a line: an empty board
    // with no explanation is the hardest kind of report to act on.
    diag_log text format ["[AQ] board('%1') before srvInit finished; returning nothing.", _verb];
    []
};
// LOCAL PATCH (VENDORED.txt): server state lives in localNamespace, which no
// client publicVariable can overwrite (see fn_srvInit, SERVER GLOBALS).
if (isNil {localNamespace getVariable "aq_srvBoard"}) then { localNamespace setVariable ["aq_srvBoard", createHashMap]; };
private _board = localNamespace getVariable "aq_srvBoard";

// LOCAL PATCH (VENDORED.txt): this is whitelisted for "offers", and a whitelist
// entry admits every verb. init/sweep/refill/clear are server housekeeping, so a
// client is refused them here -- otherwise anyone could empty every board.
// "take" reaches us from fn_srvAccept inside the accepting client's own frame,
// so it is let through and checked against that caller's active quests below.
private _reo = remoteExecutedOwner;
if (_reo > 0 && {!(toLower _verb in ["offers", "take"])}) exitWith {
    diag_log text format ["[AQ] SECURITY board: machine %1 asked for '%2'; clients may only ask for offers.", _reo, _verb];
    []
};

private _mode = toLower (["boardMode", "shared"] call aq_fnc_setting);
if !(_mode in ["shared", "ondemand"]) then {
    diag_log text format ["[AQ] board: AQ_Settings >> boardMode is '%1'; expected 'shared' or 'onDemand'. Using 'shared'.", _mode];
    _mode = "shared";
};

// --------------------------------------------------------------- lookups ---
// The indexes preInit built are the only source. Scanning the config roots here
// instead would happen on every board sweep, which is exactly the per-event
// catalogue scan the design forbids -- and it would also disagree with the rest
// of the runtime the moment a mission overrode a class.
private _giverIds = if (isNil "aq_idxGiver") then { [] } else { keys aq_idxGiver };
private _questIds = if (isNil "aq_idxQuest") then { [] } else { keys aq_idxQuest };

private _sizeOf = {
    params ["_gid"];
    private _gc = aq_idxGiver getOrDefault [_gid, configNull];
    // The settings-level boardSize is the default for a giver that does not
    // declare one, and it defaults to 0: a giver silently holding radiant offers
    // it never asked for is content appearing where the author did not put it.
    private _n = [_gc, "boardSize", ["boardSize", 0] call aq_fnc_setting] call aq_fnc_cfgGet;
    if (!(_n isEqualType 0) || {_n < 0}) then { _n = 0; };
    _n min 20    // a config typo must not spend the frame generating quests
};

private _lifeOf = {
    params ["_gid"];
    private _gc = aq_idxGiver getOrDefault [_gid, configNull];
    private _t = [_gc, "offerLifetime", ["offerLifetime", 1800] call aq_fnc_setting] call aq_fnc_cfgGet;
    if !(_t isEqualType 0) then { _t = 1800; };
    _t max 0     // 0 = never expires
};

private _now = (localNamespace getVariable "aq_srvEpochBase") + time;
private _hasGen = !((missionNamespace getVariable ["aq_fnc_genOffer", {}]) isEqualTo {});

// Roll one instance for a giver and wrap it as an offer. _forPlayer is objNull
// and _history empty for a shared refill: the offer belongs to nobody yet, so
// there is no history it could honestly be filtered against, and the per-player
// part of the promise is kept at presentation instead.
private _makeOffer = {
    params ["_gid", ["_forPlayer", objNull], ["_history", createHashMap]];
    if (!_hasGen) exitWith { nil };

    // The generator's context. A shared refill belongs to nobody yet, so it
    // carries no history and notUsedWithin cannot be applied at generation --
    // it is applied at presentation instead (see PER-PLAYER FAIRNESS above).
    // An onDemand roll is made for one player, so their history goes in and the
    // constraint means what it was written to mean.
    private _gctx = createHashMap;
    _gctx set ["player", _forPlayer];
    if !(isNull _forPlayer) then { _gctx set ["playerPos", getPosWorld _forPlayer]; };
    _gctx set ["now", _now];
    if (_history isEqualType createHashMap && {count _history > 0}) then {
        _gctx set ["history", _history];
    };

    private _inst = [_gid, _gctx] call aq_fnc_genOffer;
    if (!(_inst isEqualType createHashMap) || {count _inst == 0}) exitWith { nil };

    private _id = _inst getOrDefault ["id", ""];
    if (!(_id isEqualType "") || {_id isEqualTo ""}) then {
        private _seq = (localNamespace getVariable ["aq_srvSeq", 0]) + 1;
        localNamespace setVariable ["aq_srvSeq", _seq];
        _id = format ["aq_r_%1_%2", _gid, _seq];
        _inst set ["id", _id];
    };

    private _life = [_gid] call _lifeOf;
    private _offer = createHashMap;
    _offer set ["quest", _id];
    _offer set ["giver", _gid];
    _offer set ["expires", [0, _now + _life] select (_life > 0)];
    _offer set ["inst", _inst];
    _offer set ["used", _inst getOrDefault ["used", []]];
    _offer
};

private _refill = {
    params ["_gid"];
    private _want = [_gid] call _sizeOf;
    private _list = _board getOrDefault [_gid, []];
    private _added = 0;
    private _attempts = 0;
    // Bounded attempts: a template whose slots cannot be satisfied returns
    // nothing every time, and an unbounded top-up loop would then spin for the
    // whole frame, once per giver, every sweep.
    while {count _list < _want && {_attempts < _want * 3}} do {
        _attempts = _attempts + 1;
        private _o = [_gid, objNull] call _makeOffer;
        if (isNil "_o") exitWith {};
        _list pushBack _o;
        _added = _added + 1;
    };
    _board set [_gid, _list];
    if (_added > 0) then { ["dirty", "board"] call aq_fnc_srvStore; };
    _added
};

// ------------------------------------------------------------- dispatch ----
switch (toLower _verb) do {

    case "init": {
        if (_mode isEqualTo "ondemand") exitWith {
            // Offers rolled at interaction time are held on the player, not
            // here. Leaving stale shared offers around would let a mode switch
            // resurrect quests nobody can see.
            localNamespace setVariable ["aq_srvBoard", createHashMap];
            ["dirty", "board"] call aq_fnc_srvStore;
            diag_log text "[AQ] board: onDemand mode; no shared board is kept.";
            0
        };

        // Repair on load: a restored board can name givers that no longer exist
        // and hold offers that expired while the server was down.
        {
            if !(_x in _giverIds) then {
                diag_log text format ["[AQ] board: dropping restored offers for giver '%1', which is no longer configured.", _x];
                _board deleteAt _x;
            };
        } forEach keys _board;

        private _total = 0;
        {
            private _gid = _x;
            private _kept = (_board getOrDefault [_gid, []]) select {
                private _e = _x getOrDefault ["expires", 0];
                (_e isEqualTo 0) || {_now < _e}
            };
            _board set [_gid, _kept];
            [_gid] call _refill;
            _total = _total + count (_board getOrDefault [_gid, []]);
        } forEach _giverIds;

        ["dirty", "board"] call aq_fnc_srvStore;
        diag_log text format ["[AQ] board: %1 offer(s) live across %2 giver(s)%3.",
            _total, count _giverIds,
            ["", " (no generator: authored quests only)"] select (!_hasGen)];
        _total
    };

    case "sweep": {
        if (_mode isEqualTo "ondemand") exitWith { 0 };
        private _expired = 0;
        {
            private _gid = _x;
            private _list = _board getOrDefault [_gid, []];
            private _kept = _list select {
                private _e = _x getOrDefault ["expires", 0];
                (_e isEqualTo 0) || {_now < _e}
            };
            if (count _kept != count _list) then {
                _expired = _expired + (count _list - count _kept);
                _board set [_gid, _kept];
            };
            [_gid] call _refill;
        } forEach _giverIds;
        if (_expired > 0) then {
            ["dirty", "board"] call aq_fnc_srvStore;
        };
        _expired
    };

    case "refill": {
        if (isNil "_a") exitWith { 0 };
        [_a] call _refill
    };

    case "take": {
        if (isNil "_a" || {isNil "_b"}) exitWith { false };
        // LOCAL PATCH (VENDORED.txt): from a client, a take is only fn_srvAccept
        // consuming the offer it has just made active for that caller. Anything
        // else is a client pulling offers off the board to grief or re-roll it.
        private _denied = false;
        if (_reo > 0) then {
            private _caller = (allPlayers select { owner _x == _reo }) param [0, objNull];
            private _uidFn  = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
            private _cuid   = if (isNull _caller || {_uidFn isEqualTo {}}) then { "" } else { [_caller] call _uidFn };
            private _cpst   = createHashMap;
            if (_cuid isEqualType "" && {_cuid != ""}) then { _cpst = ["player", _cuid] call aq_fnc_srvStore; };
            _denied = isNil "_cpst" || {!(_b isEqualType "")} || {!(_b in (_cpst getOrDefault ["active", createHashMap]))};
        };
        if (_denied) exitWith {
            diag_log text format ["[AQ] SECURITY board: machine %1 tried to take '%2' off %3's board without holding it.", _reo, _b, _a];
            false
        };
        private _list = _board getOrDefault [_a, []];
        private _before = count _list;
        _list = _list select { !((_x getOrDefault ["quest", ""]) isEqualTo _b) };
        _board set [_a, _list];
        if (count _list == _before) exitWith {
            // Two players accepting the same offer in the same instant: the
            // second one is refused in fn_srvAccept by the offer no longer
            // existing, so reaching here means the caller and the board
            // disagree about what is on it.
            diag_log text format ["[AQ] board take: '%1' was not on %2's board.", _b, _a];
            false
        };
        [_a] call _refill;
        ["dirty", "board"] call aq_fnc_srvStore;
        true
    };

    case "clear": {
        localNamespace setVariable ["aq_srvBoard", createHashMap];
        ["dirty", "board"] call aq_fnc_srvStore;
        true
    };

    // ------------------------------------------------------------ offers ---
    // Wire payload:
    //   [giverId, [ [questId, title, summary, [objectiveLine, ...],
    //                remaining, packedInstance], ... ] ]
    // `remaining` is SECONDS LEFT on the offer at the moment of sending, 0 for
    // never — see fn_srvInit's contract block for why it is not the stamp.
    // Sent to the asking client only. It is built here rather than on the
    // client because eligibility is a server decision and the client must never
    // be handed the list of quests it was not allowed to see.
    case "offers": {
        private _gid = if (isNil "_a") then { "" } else { _a };
        private _player = if (isNil "_b") then { objNull } else { _b };
        if (_gid isEqualTo "" || {isNull _player}) exitWith { [_gid, []] };

        private _reo = remoteExecutedOwner;
        if (_reo > 0 && {owner _player != _reo}) exitWith {
            diag_log text format ["[AQ] SECURITY board: machine %1 asked for offers as a unit it does not own.", _reo];
            [_gid, []]
        };

        private _uidFn = missionNamespace getVariable [(["playerUid"] call aq_fnc_profile), {}];
        private _uid = if (_uidFn isEqualTo {}) then { "" } else { [_player] call _uidFn };
        if (!(_uid isEqualType "") || {_uid isEqualTo ""}) exitWith { [_gid, []] };
        private _pst = ["player", _uid] call aq_fnc_srvStore;
        if (isNil "_pst") exitWith { [_gid, []] };
        private _recent = _pst getOrDefault ["recent", createHashMap];

        private _describe = {
            params ["_src", "_qid"];
            private _lines = [];
            if (_src isEqualType createHashMap) then {
                {
                    private _o = _x;
                    private _t = (localNamespace getVariable "aq_types") getOrDefault [[_o, "type", ""] call aq_fnc_cfgGet, {}];
                    if !(_t isEqualTo {}) then {
                        private _ctx = createHashMap;
                        _ctx set ["quest", _qid];
                        _ctx set ["objective", _o getOrDefault ["id", ""]];
                        _ctx set ["cfg", _o];
                        _ctx set ["state", createHashMap];
                        _ctx set ["player", _player];
                        private _d = ["describe", _ctx] call _t;
                        if (_d isEqualType "") then { _lines pushBack _d; };
                    };
                } forEach (_src getOrDefault ["objectives", []]);
            } else {
                private _root = _src >> "objectives";
                if (isClass _root) then {
                    {
                        private _oc = _x;
                        private _t = (localNamespace getVariable "aq_types") getOrDefault [[_oc, "type", ""] call aq_fnc_cfgGet, {}];
                        if !(_t isEqualTo {}) then {
                            private _ctx = createHashMap;
                            _ctx set ["quest", _qid];
                            _ctx set ["objective", configName _oc];
                            _ctx set ["cfg", _oc];
                            _ctx set ["state", createHashMap];
                            _ctx set ["player", _player];
                            private _d = ["describe", _ctx] call _t;
                            if (_d isEqualType "") then { _lines pushBack _d; };
                        };
                    } forEach (configProperties [_root, "isClass _x", true]);
                };
            };
            _lines
        };

        private _out = [];

        // 1. Authored quests this giver holds, filtered through the one and only
        //    eligibility implementation (fn_srvAccept in dry-run mode).
        {
            private _qid = _x;
            private _qc = [_qid] call aq_fnc_cfgQuest;
            if (!isNull _qc && {([_qc, "giver", ""] call aq_fnc_cfgGet) isEqualTo _gid}) then {
                if (([_player, _gid, _qid, true] call aq_fnc_srvAccept) select 0) then {
                    _out pushBack [
                        _qid,
                        [[_qc, "title", _qid] call aq_fnc_cfgGet] call aq_fnc_text,
                        [[_qc, "summary", ""] call aq_fnc_cfgGet] call aq_fnc_text,
                        [_qc, _qid] call _describe,
                        0,
                        []
                    ];
                };
            };
        } forEach _questIds;

        // 2. Personal offers (chains, and onDemand rolls from a previous look).
        {
            private _o = _y;
            if ((_o getOrDefault ["giver", ""]) isEqualTo _gid) then {
                private _qid = _x;
                private _inst = _o getOrDefault ["inst", createHashMap];
                private _src = if (count _inst > 0) then { _inst } else { [_qid] call aq_fnc_cfgQuest };
                private _skip = (count _inst == 0) && {isNull _src};
                if (!_skip && {([_player, _gid, _qid, true] call aq_fnc_srvAccept) select 0}) then {
                    _out pushBack [
                        _qid,
                        [[_src, "title", _qid] call aq_fnc_cfgGet] call aq_fnc_text,
                        [[_src, "summary", ""] call aq_fnc_cfgGet] call aq_fnc_text,
                        [_src, _qid] call _describe,
                        // Seconds left, not the stamp: see fn_srvInit's contract
                        // block. The client cannot read the server's clock.
                        ([0, ((_o getOrDefault ["expires", 0]) - _now) max 0] select ((_o getOrDefault ["expires", 0]) > 0)),
                        ["pack", _inst] call aq_fnc_srvStore
                    ];
                };
            };
        } forEach (_pst getOrDefault ["offers", createHashMap]);

        // 3. Radiant offers.
        private _radiant = [];
        if (_mode isEqualTo "ondemand") then {
            // Rolled now and parked on the player, because fn_srvAccept must be
            // able to find the exact instance the player was shown — not a
            // second roll with different numbers.
            private _want = [_gid] call _sizeOf;
            private _mine = _pst getOrDefault ["offers", createHashMap];
            private _have = count (_out select { !((_x select 5) isEqualTo []) });
            for "_i" from 1 to (_want - _have) do {
                private _o = [_gid, _player, _recent] call _makeOffer;
                if !(isNil "_o") then {
                    _mine set [_o getOrDefault ["quest", ""], _o];
                    _radiant pushBack _o;
                };
            };
            if (count _radiant > 0) then { ["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore; };
        } else {
            {
                private _o = _x;
                // Per-player notUsedWithin filter — see the header.
                // "recent" stores WHEN an entry was last used, and the window
                // travels with the offer rather than with the stamp, because the
                // window is the slot's property: two templates may draw the same
                // pool entry with two different notUsedWithin values, and a
                // stored expiry would let whichever wrote last decide for both.
                private _hot = false;
                {
                    _x params [["_k", "", [""]], ["_secs", 0, [0]]];
                    if (_k != "" && {_secs > 0}) then {
                        private _last = _recent getOrDefault [_k, -1e12];
                        if ((_now - _last) < _secs) then { _hot = true; };
                    };
                } forEach (_o getOrDefault ["used", []]);
                if (!_hot) then { _radiant pushBack _o; };
            } forEach (_board getOrDefault [_gid, []]);
        };

        {
            private _o = _x;
            private _inst = _o getOrDefault ["inst", createHashMap];
            private _qid = _o getOrDefault ["quest", ""];
            if (count _inst > 0 && {([_player, _gid, _qid, true] call aq_fnc_srvAccept) select 0}) then {
                _out pushBack [
                    _qid,
                    [[_inst, "title", _qid] call aq_fnc_cfgGet] call aq_fnc_text,
                    [[_inst, "summary", ""] call aq_fnc_cfgGet] call aq_fnc_text,
                    [_inst, _qid] call _describe,
                    ([0, ((_o getOrDefault ["expires", 0]) - _now) max 0] select ((_o getOrDefault ["expires", 0]) > 0)),
                    ["pack", _inst] call aq_fnc_srvStore
                ];
            };
        } forEach _radiant;

        private _payload = [_gid, _out];
        private _own = owner _player;
        if (_own > 0) then { ["board", _payload] remoteExec ["aq_fnc_sync", _own]; };
        _payload
    };

    default {
        diag_log text format ["[AQ] board: unknown verb '%1'.", _verb];
        []
    };
};
