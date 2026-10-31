// SPDX-License-Identifier: MIT
/*
    diagnostics/fn_dumpState.sqf  —  aq_fnc_dumpState

    Purpose: decode one player's quest state — active quests with per-objective
    progress, completed ids, cooldowns and radiant slot history — into readable
    lines.

    WHY THIS EXISTS
        Player state is a nest of hash maps that persists across sessions and is
        written by the server, so when a player says "the quest won't complete" or
        "it says I already did this", there is no way to answer them from inside
        the game. Guessing produces the worst outcome available: an operator who
        resets state to be safe, destroying progress that was fine. One printed
        decode turns an argument into a fact — and it is equally the fastest way to
        see that an objective was armed twice, that a cooldown stamp is in the far
        future, or that a completed id refers to a quest that no longer exists.

    WHAT IT DOES
        Resolves the player's uid, finds the state — `aq_srvPlayers` when this
        runs on the server, the client's own `aq_quests` mirror when it does not
        — and prints it under the four headings the design persists: `active`,
        `completed`, `cooldown`, `recent` (the radiant slot history). The client
        mirror can only fill the first of those: the client is told what it
        holds and is deliberately never told its own cooldowns, so a dump taken
        on a client is not a smaller version of the server's, it is a different
        question. The source is printed for that reason. Per-objective
        progress is rendered by asking each objective's own type for it, which is
        the only component that knows what its numbers mean. Anything the decoder
        does not recognise is still printed, generically and depth-bounded, because
        a dump that hides the unexpected field hides the bug. Read-only and
        bounded; safe on a live server.

    Usage:
        [player] call aq_fnc_dumpState;           // the local player
        ["76561190000000000"] call aq_fnc_dumpState;
        [player, false] call aq_fnc_dumpState;    // do not call into type plugins

    Runs synchronously and never suspends, so `call` it. Run it on the server for
    the authoritative copy; on a client it can only reach the local mirror.

    Read-only, and read-only in a way that matters: the server's record is read
    straight out of aq_srvPlayers rather than through aq_fnc_srvStore, because
    the store's fetch-or-create would manufacture an empty record for any uid
    typed at it. A diagnostic that writes is a diagnostic nobody dares run.
*/

params [
    ["_target", objNull, [objNull, ""]],
    ["_callTypes", true, [true]]
];

private _tag = "[AQ-STATE]";
private _maxLines = 300;      // bounded output
private _maxDepth = 4;
private _maxItems = 24;
private _lines = 0;

private _say = {
    params ["_txt"];
    if (_lines < _maxLines) then {
        _lines = _lines + 1;
        diag_log format ["%1 %2", _tag, _txt];
    } else {
        if (_lines == _maxLines) then {
            _lines = _lines + 1;
            diag_log format ["%1 ... output capped at %2 lines", _tag, _maxLines];
        };
    };
};

// Self-contained config lookup, as with the other diagnostics.
private _root = {
    params [["_class", "", [""]]];
    private _found = configNull;
    {
        if (isClass (_x >> _class)) exitWith { _found = _x >> _class };
    } forEach [missionConfigFile, campaignConfigFile, configFile];
    _found
};
private _gTxt = {
    params ["_cfg", "_key", ["_def", ""]];
    if (isText (_cfg >> _key)) then { getText (_cfg >> _key) } else { _def }
};

// ---------------------------------------------------------------------------
// 1. Whose state?
// ---------------------------------------------------------------------------
if ((_target isEqualType objNull) && { isNull _target } && { hasInterface }) then {
    _target = player;
};

private _uid = "";
if (_target isEqualType "") then {
    _uid = _target;
} else {
    // The host owns identity, so ask the profile first and only fall back to the
    // engine's own id. A host that keys state on something other than the Steam
    // id would otherwise be dumped under a key that does not exist.
    private _profile = ["AQ_Profile"] call _root;
    private _fncName = if (isNull _profile) then { "" } else {
        [_profile, "playerUid", ""] call _gTxt
    };
    private _fnc = if (_fncName isEqualTo "") then { nil } else {
        missionNamespace getVariable [_fncName, nil]
    };
    if (!isNull _target) then {
        if (!isNil "_fnc" && { _fnc isEqualType {} }) then {
            _uid = [_target] call _fnc;
        } else {
            _uid = getPlayerUID _target;
        };
    };
};

if (!(_uid isEqualType "") || { _uid isEqualTo "" }) exitWith {
    ["ERROR: could not resolve a uid. Pass a player object or a uid string."] call _say;
    if (hasInterface) then { systemChat format ["%1 could not resolve a uid.", _tag] };
    false
};

// ---------------------------------------------------------------------------
// 2. Where is the state?
// ---------------------------------------------------------------------------
// Two sources, tried in order of authority: the server's in-memory player
// table, then the client's own mirror of what it was last told. Which one
// answered is printed, because "the client mirror says you have three active
// quests" and "the server says so" are very different statements.
//
// The server table is read DIRECTLY rather than through aq_fnc_srvStore, which
// would create an empty record for a uid it has never seen. A diagnostic that
// writes is a diagnostic nobody dares run on a live server.
private _state = nil;
private _source = "";
private _note = "";

// On the server, aq_srvPlayers is the record. Its ABSENCE for one uid is an
// answer, not a miss -- a player who has never accepted a quest has no record --
// so the search stops there rather than falling through to a client mirror that
// exists on the server too and is always empty on it.
private _table = localNamespace getVariable ["aq_srvPlayers", nil];
if (isServer && { !isNil "_table" } && { _table isEqualType createHashMap }) then {
    private _r = _table getOrDefault [_uid, nil];
    if (!isNil "_r" && { _r isEqualType createHashMap }) then {
        _state = _r; _source = "aq_srvPlayers (server, authoritative)";
    } else {
        _note = "the server holds no record for this uid. That is what a player who has never accepted a quest looks like, and it is not a fault.";
    };
};

if (isNil "_state" && { !isServer }) then {
    // The client keeps questId -> record and nothing else, so it is wrapped to
    // look like the "active" half of a player record. Wrapping rather than
    // teaching the decoder a second shape: the shapes are genuinely different,
    // and a decoder that guesses which one it is looking at is a decoder that
    // will one day guess wrong on a live server.
    private _mirror = localNamespace getVariable ["aq_quests", nil];
    if (!isNil "_mirror" && { _mirror isEqualType createHashMap }) then {
        _state = createHashMapFromArray [["active", _mirror]];
        _source = "aq_quests (client mirror — local player only; the client is never told cooldowns or radiant history)";
    };
};

["--- quest state ---"] call _say;
[format ["uid       %1", _uid]] call _say;
[format ["serverTime %1 (cooldown stamps below are read as serverTime values)",
         round serverTime]] call _say;
if !(_note isEqualTo "") then { [format ["note      %1", _note]] call _say };

if (isNil "_state") exitWith {
    ["ERROR: no state found. Looked for aq_srvPlayers (on the server) and aq_quests (the client mirror)."] call _say;
    ["If this ran on a client, the server holds the authoritative copy — run it there with the target set to SERVER."] call _say;
    if (hasInterface) then { systemChat format ["%1 no state found for %2.", _tag, _uid] };
    false
};
[format ["source    %1", _source]] call _say;

// ---------------------------------------------------------------------------
// 3. Generic, bounded dump
// ---------------------------------------------------------------------------
// Iterative rather than recursive, with an explicit work stack: the depth and
// item caps are then structural rather than a matter of trusting a call chain,
// which is what makes this safe to point at unknown state on a live server.
private _short = {
    params ["_v"];
    if (isNil "_v") exitWith { "<nil>" };
    if (_v isEqualType "") exitWith { """" + _v + """" };
    if (_v isEqualType 0) exitWith { str _v };
    if (_v isEqualType true) exitWith { str _v };
    if (_v isEqualType {}) exitWith { "<code>" };
    if (_v isEqualType objNull) exitWith { format ["<object %1>", _v] };
    if (_v isEqualType createHashMap) exitWith { format ["<map, %1 key(s)>", count (keys _v)] };
    if (_v isEqualType []) exitWith { format ["<array, %1 item(s)>", count _v] };
    str _v
};
private _isContainer = {
    params ["_v"];
    if (isNil "_v") exitWith { false };
    (_v isEqualType createHashMap) || { (_v isEqualType []) && { !(_v isEqualTo []) } }
};
private _dump = {
    params ["_label", "_value", ["_indent", 2]];
    private _stack = [[_label, _value, _indent]];
    while { (count _stack) > 0 && { _lines <= _maxLines } } do {
        private _item = _stack deleteAt 0;
        _item params ["_l", "_v", "_d"];
        private _pad = "";
        for "_k" from 1 to _d do { _pad = _pad + "  " };
        [format ["%1%2 %3", _pad, _l, [_v] call _short]] call _say;

        if (([_v] call _isContainer) && { _d < (_indent + _maxDepth) }) then {
            private _children = [];
            if (_v isEqualType createHashMap) then {
                private _ks = keys _v;
                {
                    if (_forEachIndex < _maxItems) then {
                        _children pushBack [_x, _v get _x, _d + 1];
                    };
                } forEach _ks;
                if ((count _ks) > _maxItems) then {
                    _children pushBack [format ["...%1 more key(s)", (count _ks) - _maxItems],
                                        "", _d + 1];
                };
            } else {
                {
                    if (_forEachIndex < _maxItems) then {
                        _children pushBack [format ["[%1]", _forEachIndex], _x, _d + 1];
                    };
                } forEach _v;
                if ((count _v) > _maxItems) then {
                    _children pushBack [format ["...%1 more item(s)", (count _v) - _maxItems],
                                        "", _d + 1];
                };
            };
            _stack insert [0, _children];
        };
    };
};

// First key name that the state actually carries, from a list of the names the
// same concept is plausibly stored under. The decoder must not invent a shape.
private _pickKey = {
    params ["_map", "_names"];
    private _hit = "";
    private _ks = keys _map;
    { if (_x in _ks) exitWith { _hit = _x } } forEach _names;
    _hit
};

private _ks = keys _state;
// The names the server actually persists come first; the rest are kept as
// fallbacks so a record written by a host that renamed something still decodes
// into the right heading rather than falling into OTHER KEYS.
private _kActive    = [_state, ["active", "activeQuests", "quests"]] call _pickKey;
private _kCompleted = [_state, ["completed", "done", "completedQuests"]] call _pickKey;
private _kCooldown  = [_state, ["cooldown", "cooldowns", "cooldownStamps"]] call _pickKey;
private _kRecent    = [_state, ["recent", "radiantRecent", "slotHistory", "notUsedWithin"]] call _pickKey;

// ---------------------------------------------------------------------------
// 4. Active quests, with per-objective progress
// ---------------------------------------------------------------------------
private _typeReg = localNamespace getVariable ["aq_types", nil];
private _typesLoaded = !isNil "_typeReg" && { _typeReg isEqualType createHashMap };
private _questsCfg = ["AQ_Quests"] call _root;
private _playerObj = if (_target isEqualType objNull) then { _target } else { objNull };

[""] call _say;
["ACTIVE"] call _say;

if (_kActive isEqualTo "") then {
    ["  (no active-quest key in this state)"] call _say;
} else {
    private _active = _state get _kActive;
    if (!([_active] call _isContainer)) then {
        [format ["  %1 = %2", _kActive, [_active] call _short]] call _say;
    } else {
        // A plain array of ids is as legitimate a shape as a map keyed by id, and
        // str on a string would wrap the id in quotes, so ids are taken as they
        // are and only non-strings are stringified.
        private _qids = if (_active isEqualType createHashMap) then { keys _active } else {
            _active apply { if (_x isEqualType "") then { _x } else { str _x } }
        };
        if (_qids isEqualTo []) then { ["  (none)"] call _say };

        {
            private _qid = _x;
            private _qstate = nil;
            if (_active isEqualType createHashMap) then { _qstate = _active get _qid };

            private _qcfg = if (isNull _questsCfg) then { configNull } else { _questsCfg >> _qid };
            private _title = if (isNull _qcfg) then { "" } else { [_qcfg, "title", ""] call _gTxt };
            [format ["  %1%2", _qid,
                     if (_title isEqualTo "") then {
                         "   (not in AQ_Quests — radiant instance, or the quest was removed)"
                     } else { format ["   ""%1""", _title] }]] call _say;

            if (isNil "_qstate") then {
                ["    (no per-quest state stored)"] call _say;
            } else {
                if (!(_qstate isEqualType createHashMap)) then {
                    [format ["    state %1", [_qstate] call _short]] call _say;
                } else {
                    private _kObjs = [_qstate, ["objectives", "objs", "progress"]] call _pickKey;
                    {
                        private _mk = _x;
                        if (!(_mk isEqualTo _kObjs)) then {
                            [format ["    %1 %2", _mk, [_qstate get _mk] call _short]] call _say;
                        };
                    } forEach (keys _qstate);

                    if (_kObjs isEqualTo "") then {
                        ["    (no per-objective state stored)"] call _say;
                    } else {
                        private _objs = _qstate get _kObjs;
                        if (!(_objs isEqualType createHashMap)) then {
                            ["objectives", _objs, 2] call _dump;
                        } else {
                            {
                                private _oid = _x;
                                private _ostate = _objs get _oid;
                                private _ocfg = if (isNull _qcfg) then { configNull } else {
                                    _qcfg >> "objectives" >> _oid
                                };
                                private _type = if (isNull _ocfg) then { "" } else {
                                    [_ocfg, "type", ""] call _gTxt
                                };
                                private _rendered = "";

                                // The type is the only component that knows what
                                // its own numbers mean, so ask it. progress is a
                                // mandatory render verb and is contractually pure.
                                // UNVERIFIED: purity is a contract, not something
                                // this file can enforce — a type that mutates in
                                // progress would make this dump non-read-only.
                                // Pass false as the second argument to skip it.
                                if (_callTypes && _typesLoaded && { _type != "" }
                                    && { _type in (keys _typeReg) } && { !isNull _ocfg }) then {
                                    private _fnc = _typeReg get _type;
                                    if (_fnc isEqualType {}) then {
                                        private _ctx = createHashMapFromArray [
                                            ["quest", _qid],
                                            ["objective", _oid],
                                            ["cfg", _ocfg],
                                            ["state", _ostate],
                                            ["player", _playerObj]
                                        ];
                                        private _p = ["progress", _ctx] call _fnc;
                                        if (!isNil "_p" && { _p isEqualType [] }
                                            && { (count _p) >= 3 }) then {
                                            _rendered = format ["  ->  %1/%2  %3",
                                                                _p select 0, _p select 1,
                                                                _p select 2];
                                        };
                                    };
                                };

                                [format ["    objective %1 [%2] %3%4", _oid,
                                         if (_type isEqualTo "") then { "type unknown" }
                                             else { _type },
                                         [_ostate] call _short, _rendered]] call _say;
                                if ([_ostate] call _isContainer) then {
                                    ["state", _ostate, 3] call _dump;
                                };
                            } forEach (keys _objs);
                        };
                    };
                };
            };
        } forEach _qids;
    };
};

// ---------------------------------------------------------------------------
// 5. Completed
// ---------------------------------------------------------------------------
[""] call _say;
["COMPLETED"] call _say;
if (_kCompleted isEqualTo "") then {
    ["  (no completed key in this state)"] call _say;
} else {
    private _done = _state get _kCompleted;
    private _ids = if (_done isEqualType createHashMap) then { keys _done } else {
        if (_done isEqualType []) then { _done } else { [] }
    };
    if (_ids isEqualTo []) then { ["  (none)"] call _say };
    {
        private _qid = if (_x isEqualType "") then { _x } else { str _x };
        private _known = !isNull _questsCfg && { isClass (_questsCfg >> _qid) };
        [format ["  %1%2", _qid,
                 if (_known) then { "" } else { "   (no longer in AQ_Quests)" }]] call _say;
    } forEach _ids;
};

// ---------------------------------------------------------------------------
// 6. Cooldowns
// ---------------------------------------------------------------------------
[""] call _say;
["COOLDOWNS"] call _say;
if (_kCooldown isEqualTo "") then {
    ["  (no cooldown key in this state)"] call _say;
} else {
    private _cd = _state get _kCooldown;
    if (!(_cd isEqualType createHashMap)) then {
        ["cooldowns", _cd, 1] call _dump;
    } else {
        if ((keys _cd) isEqualTo []) then { ["  (none)"] call _say };
        {
            private _qid = _x;
            private _v = _cd get _qid;
            if (_v isEqualType 0) then {
                private _left = _v - serverTime;
                [format ["  %1  stamp %2  (%3)", _qid, round _v,
                         if (_left > 0) then { format ["%1s remaining", round _left] }
                             else { "elapsed" }]] call _say;
            } else {
                [format ["  %1  %2", _qid, [_v] call _short]] call _say;
            };
        } forEach (keys _cd);
    };
};

// ---------------------------------------------------------------------------
// 7. Radiant slot history (notUsedWithin)
// ---------------------------------------------------------------------------
[""] call _say;
["RADIANT HISTORY"] call _say;
if (_kRecent isEqualTo "") then {
    ["  (no radiant-history key in this state)"] call _say;
} else {
    ["  " + _kRecent, _state get _kRecent, 1] call _dump;
};

// ---------------------------------------------------------------------------
// 8. Anything the decoder did not recognise
// ---------------------------------------------------------------------------
private _known = [_kActive, _kCompleted, _kCooldown, _kRecent];
private _other = _ks select { !(_x in _known) };
if (!(_other isEqualTo [])) then {
    [""] call _say;
    ["OTHER KEYS"] call _say;
    { [_x, _state get _x, 1] call _dump } forEach _other;
};

[""] call _say;
["--- end ---"] call _say;
if (hasInterface) then {
    systemChat format ["%1 dumped state for %2 (%3). Details in the RPT.", _tag, _uid, _source];
};

true
