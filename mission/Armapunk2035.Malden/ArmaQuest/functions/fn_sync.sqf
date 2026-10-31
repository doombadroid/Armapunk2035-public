// SPDX-License-Identifier: MIT
/*
    fn_sync.sqf -- the client's one inbound door from the server, and the only
    place a wire payload becomes a quest record.

    WHY THIS EXISTS
      The server sends small positional arrays, because their shape is fixed in
      one contract block (server/fn_srvInit.sqf) and does not depend on how the
      engine happens to serialise a HashMap across the network. The journal
      consumes quest RECORDS, because a record is what the objective types and
      the task mirror read. Something has to be the translator, and if that
      something is the journal then the journal grows knowledge of the wire; if
      it is spread across the six topics then six copies of the translation
      drift apart.

      There is a second, larger reason to translate in one place and to do it
      here rather than by rebuilding the quest on the client: TITLES, SUMMARIES
      AND DEADLINES ARE THE SERVER'S. A radiant quest's title exists only on the
      instance the server generated; a deadline is on a clock the client cannot
      read. If the client re-derived either from config, a player would be
      looking at a quest the server has never agreed to — which is the whole
      failure the server-authoritative split exists to remove. So everything the
      server sent is used as sent, and config is consulted only for the
      decorative fields the wire does not carry.

    WHAT IT DOES
      Translates each server topic into one of the journal's three inbound verbs:

        "state"       [[<quest payload>, ...]]      -> ["sync",   _records]
        "quest"       <quest payload>               -> ["sync",   _records]  (merged)
        "board"       [giverId, [<offer row>, ...]] -> ["offers", [giverId, _records]]
        "offerResult" [ok, reason, questId]         -> ["notice", [...]]
        "complete"    [questId, title, receipts, chainedQuestId]
        "terminal"    [questId, title, reason]
        "error"       [code, questId]

      Quest payload (positional, from fn_srvInit's contract block):
        [questId, state, index, objIds, [[objId, cur, max, text], ...],
         remaining, title, summary, packedInstance]

      Offer row:
        [questId, title, summary, [objectiveLine, ...], remaining, packedInstance]

      `remaining` is SECONDS LEFT at the moment the server sent it, 0 for no
      limit. The server's stamps are on an absolute clock the client has no way
      to read, so a difference is the only form both machines can agree on.

      "state" is a full replacement of everything the player holds. "quest" is
      one quest changing, so the other records are rebuilt from the client's
      current view and pushed with it — the journal's `sync` verb is a full
      replacement by design (it is what disarms the watchers of a quest that has
      gone), so handing it one record would tear down every other quest.

    Usage (from the server):
        ["state", [_all]] remoteExec ["aq_fnc_sync", _clientOwner];
*/

params [
    ["_topic", "", [""]],
    ["_data",  [],  [[]]]
];

if (!hasInterface) exitWith { false };
// LOCAL PATCH (VENDORED.txt): the whitelist lets any CLIENT target this at any
// other client too. Only the server may push quest state; local calls still work.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith { false };
if (_topic isEqualTo "") exitWith {
    diag_log "[AQ] sync: refused, empty topic";
    false
};

if (isNil {localNamespace getVariable "aq_quests"}) then { localNamespace setVariable ["aq_quests", createHashMap]; };

// ---------------------------------------------------------------- helpers
/*
    The packed instance is the generator's own output, flattened by
    aq_fnc_srvStore's one serialisation rule. Unpacking it here is what gives a
    radiant quest its slot substitutions on the client, so the task marker
    points at the place the server actually chose rather than at "%PLACE%".
    An authored quest packs to an empty array and this costs nothing.
*/
private _unpack = {
    params ["_packed"];
    if (!(_packed isEqualType []) || {_packed isEqualTo []}) exitWith { createHashMap };
    private _v = ["unpack", _packed] call aq_fnc_srvStore;
    if (isNil "_v" || {!(_v isEqualType createHashMap)}) exitWith { createHashMap };
    _v
};

/*
    One wire payload -> one quest record, in the shape aq_fnc_preInit documents.

    Objective state maps are NOT built here. The journal's `sync` carries the
    previous record's objective states over when the incoming record has none,
    which is what stops a state push from wiping a watcher's local counters.
*/
private _record = {
    params ["_p"];
    _p params [
        ["_qid",      "", [""]],
        ["_state",    "", [""]],
        ["_index",    0,  [0]],
        ["_objIds",   [], [[]]],
        ["_prog",     [], [[]]],
        ["_remaining", 0, [0]],
        ["_title",    "", [""]],
        ["_summary",  "", [""]],
        ["_packed",   [], [[]]]
    ];
    if (_qid isEqualTo "") exitWith { createHashMap };

    private _inst = [_packed] call _unpack;
    private _rec  = createHashMap;

    _rec set ["id",      _qid];
    _rec set ["state",   _state];
    _rec set ["title",   _title];
    _rec set ["summary", _summary];
    _rec set ["order",   _objIds select { _x isEqualType "" }];
    _rec set ["index",   _index];
    _rec set ["remaining", _remaining];
    _rec set ["subst",   _inst getOrDefault ["subst", createHashMap]];

    // Decoration the wire does not carry. A generated instance answers for
    // itself; an authored quest is read from the catalogue it was authored in.
    private _cfg = [_qid] call aq_fnc_cfgQuest;
    _rec set ["description", [_inst, "description", [_cfg, "description", ""] call aq_fnc_cfgGet] call aq_fnc_cfgGet];
    _rec set ["giver",       [_inst, "giver",       [_cfg, "giver",       ""] call aq_fnc_cfgGet] call aq_fnc_cfgGet];
    _rec set ["icon",        [_inst, "icon",        [_cfg, "icon",        ""] call aq_fnc_cfgGet] call aq_fnc_cfgGet];

    /*
        The server's own progress figures, kept under one key rather than
        written into the objective state maps. Those maps belong to the types,
        and the server computed these numbers from ITS copy of them; writing
        them back into the client's copy would leave a watcher counting from a
        number it did not produce. The journal prefers this table when it is
        present, so what the player reads is what the server believes.
    */
    private _rows = createHashMap;
    {
        if (_x isEqualType [] && {count _x >= 4}) then {
            _rows set [_x select 0, [_x select 1, _x select 2, _x select 3]];
        };
    } forEach _prog;
    _rec set ["progress", _rows];

    _rec
};

// A board row is an offer, not a quest the player holds. It is rendered from
// the server's describe lines, because eligibility and text are both the
// server's answers and the client has no business recomputing either.
private _offerRecord = {
    params ["_row"];
    _row params [
        ["_qid",     "", [""]],
        ["_title",   "", [""]],
        ["_summary", "", [""]],
        ["_lines",   [], [[]]],
        ["_remaining", 0, [0]],
        ["_packed",  [], [[]]]
    ];
    if (_qid isEqualTo "") exitWith { createHashMap };

    private _inst = [_packed] call _unpack;
    private _cfg  = [_qid] call aq_fnc_cfgQuest;

    private _order = [];
    private _rows  = createHashMap;
    {
        private _oid = format ["obj%1", _forEachIndex];
        _order pushBack _oid;
        _rows set [_oid, [0, 1, if (_x isEqualType "") then { _x } else { str _x }]];
    } forEach _lines;

    private _rec = createHashMap;
    _rec set ["id",       _qid];
    _rec set ["state",    "offered"];
    _rec set ["title",    _title];
    _rec set ["summary",  _summary];
    _rec set ["order",    _order];
    _rec set ["progress", _rows];
    _rec set ["remaining", _remaining];
    _rec set ["subst",    _inst getOrDefault ["subst", createHashMap]];
    _rec set ["description", [_inst, "description", [_cfg, "description", ""] call aq_fnc_cfgGet] call aq_fnc_cfgGet];
    _rec set ["giver",       [_inst, "giver",       [_cfg, "giver",       ""] call aq_fnc_cfgGet] call aq_fnc_cfgGet];
    _rec set ["icon",        [_inst, "icon",        [_cfg, "icon",        ""] call aq_fnc_cfgGet] call aq_fnc_cfgGet];
    _rec set ["offer",    true];
    _rec
};

// ------------------------------------------------------------------ topics
switch (toLower _topic) do {

    case "state": {
        private _all = _data param [0, [], [[]]];
        private _records = [];
        {
            if (_x isEqualType []) then {
                private _r = [_x] call _record;
                if !(count _r isEqualTo 0) then { _records pushBack _r; };
            };
        } forEach _all;
        ["sync", _records] call aq_fnc_journal;
        true
    };

    case "quest": {
        private _one = [_data] call _record;
        if (count _one isEqualTo 0) exitWith {
            diag_log "[AQ] sync: 'quest' payload carried no quest id";
            false
        };
        private _id = _one get "id";
        // Everything else the client currently holds, sent again unchanged, so
        // the journal's full-replacement sync does not tear the rest down.
        private _records = [_one];
        { if !(_x isEqualTo _id) then { _records pushBack ((localNamespace getVariable "aq_quests") get _x); }; } forEach (keys (localNamespace getVariable "aq_quests"));
        ["sync", _records] call aq_fnc_journal;
        true
    };

    case "board": {
        private _giverId = _data param [0, "", [""]];
        private _rows    = _data param [1, [], [[]]];
        private _records = [];
        {
            if (_x isEqualType []) then {
                private _r = [_x] call _offerRecord;
                if !(count _r isEqualTo 0) then { _records pushBack _r; };
            };
        } forEach _rows;
        ["offers", [_giverId, _records]] call aq_fnc_journal;
        true
    };

    case "offerresult": {
        _data params [["_ok", false, [false]], ["_reason", "", [""]], ["_questId", "", [""]]];
        // A refusal is the only one worth saying out loud; a success announces
        // itself as the quest appearing in the journal a moment later.
        ["notice", ["accept", _questId, if (_ok) then { "" } else { _reason }]] call aq_fnc_journal;
        true
    };

    case "complete": {
        _data params [["_questId", "", [""]], ["_title", "", [""]], ["_receipts", [], [[]]], ["_chained", "", [""]]];
        // The third element is what the player is shown, so it is a sentence
        // rather than an id: the journal announces it natively when the page is
        // not open, and a quest id in the chat bar explains nothing.
        ["notice", ["complete", _questId, format ["Completed: %1", _title]]] call aq_fnc_journal;
        if !(_chained isEqualTo "") then {
            diag_log format ["[AQ] sync: '%1' chained to '%2'", _questId, _chained];
        };
        true
    };

    case "terminal": {
        _data params [["_questId", "", [""]], ["_title", "", [""]], ["_reason", "", [""]]];
        ["notice", [_reason, _questId, format ["%1: %2", _title, _reason]]] call aq_fnc_journal;
        true
    };

    case "error": {
        _data params [["_code", "", [""]], ["_questId", "", [""]]];
        diag_log format ["[AQ] sync: server reported error '%1' on quest '%2'", _code, _questId];
        ["notice", ["error", _questId, format ["The server refused: %1", _code]]] call aq_fnc_journal;
        true
    };

    default {
        diag_log format ["[AQ] sync: unknown topic '%1' from the server", _topic];
        false
    };
}
