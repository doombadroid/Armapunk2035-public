/*  VENDORED from the PySQF repo -- do not hand-edit.
    Re-vendor with scratchpad vendor_pysqf.py after pulling upstream.
    Renamed for this mission's convention: APS_ = owned by the server addon,
    which matters because the server compiles both CfgFunctions trees into
    missionNamespace and a shared name silently overwrites.
    Upstream name: fn_pysqf.sqf  */
// SPDX-License-Identifier: MIT
/*
    sqf/fn_pysqf.sqf   —   registered as  APS_fnc_pysqfRaw

    PURPOSE
        The whole SQF side of the wire protocol (docs/PROTOCOL.md) in one place:
        the six verbs, plus client-side chunk reassembly and JSON decoding.

    WHY THIS EXISTS
        Every caller that hand-rolls `callExtension` gets one of three things
        wrong, and all three present later as something else:
          1. It ignores the engine's own error code, so a malformed call looks
             like a backend failure.
          2. It forgets a result can arrive in more than one chunk, so anything
             over 8 KB comes back as "JSON parse error" with no cause — the
             exact failure mode the chunking exists to prevent.
          3. It treats an empty reply — which means the extension is not loaded
             at all — as an empty result.
        This is the single place those are handled, so no mission code ever
        touches `callExtension` directly.

    WHAT IT DOES
        [<verb>, [<args>]] call APS_fnc_pysqfRaw

        Speaks the protocol's own vocabulary: it returns an array of strings
        whose element 0 is "ok", "err" or "pending", and it reports client-side
        failures in exactly that shape (["err", "<message>"]).  So a caller only
        ever has to look at element 0, and a failure can never be mistaken for a
        result.  (APS_fnc_pysqfCall is the friendlier layer on top: it converts
        this vocabulary to [true, <value>] / [false, "<message>"].)

        Verbs, exactly as in docs/PROTOCOL.md §2:

          ["version"]                      -> ["ok","<semver>","<backend>"]
          ["call",  [_fn, _argsJson]]      -> ["ok","<ticket>"] | ["err",_msg]
          ["poll",  [_ticket]]             -> ["pending"] | ["ok",_n,_bytes] | ["err",_msg]
          ["chunk", [_ticket, _index]]     -> ["ok","<raw chunk text>"] | ["err",_msg]
          ["free",  [_ticket]]             -> ["ok"] | ["err",_msg]
          ["stats"]                        -> ["ok","<json>"] | ["err",_msg]

        Two deliberate departures from that table, both client-side only — the
        C core is untouched:

          * `chunk` on the wire returns bare text.  Here it is wrapped as
            ["ok", <text>] so every verb has one shape and an error is never
            indistinguishable from a chunk that happens to read "err".
          * `fetch` does not exist on the wire at all.  It is the reassembly
            helper — see below — and lives here because reassembly is policy,
            not transport, and the protocol says the core moves opaque bytes.

          ["fetch", [_ticket, _nchunks]]   -> ["ok", <decoded value>] | ["err",_msg]

        `fetch` pulls chunks 0.._nchunks-1, joins them in index order, and runs
        `fromJSON` over the result.  It does NOT free the ticket — freeing is
        the caller's job precisely because it must also happen on the error and
        timeout paths (see APS_fnc_pysqfCall).

    CONTEXT
        Nothing here sleeps, so it is safe unscheduled.  But `fetch` on a large
        result is real work: in a scheduled context the VM frame-slices the
        chunk loop for you, unscheduled it all lands in one frame.  Prefer
        scheduled, which is what APS_fnc_pysqfCall requires anyway.

    REQUIRES
        `fromJSON` — Arma 3 v2.18 or later.  Used rather than parseSimpleArray
        because error messages are JSON strings and may legitimately contain
        escaped quotes, commas and backslashes, which parseSimpleArray does not
        understand and would silently mangle.
*/

#define PYSQF_EXT           "pysqf"
// Refuse an args payload bigger than this rather than let the engine truncate it.
// UNVERIFIED: the exact input limit of the array form of callExtension is not
// documented; 8000 is a conservative floor. Confirm by sending a growing payload
// from a real server and finding where the extension stops seeing the tail.
#define PYSQF_MAX_ARG_JSON  8000
// A completed result cannot plausibly need more chunks than this (8 KB each,
// so ~32 MB). The cap exists so a garbled poll reply can never spin a loop.
#define PYSQF_MAX_CHUNKS    4096

params [
    ["_verb", "", [""]],
    ["_args", [],  [[]]]
];

/* ------------------------------------------------------------------ *
 * One raw hop to the extension.
 * Returns [true, "<text>"] or [false, "<message>"] — engine-level only.
 * ------------------------------------------------------------------ */
private _hop = {
    params ["_hopVerb", "_hopArgs"];

    private _r = PYSQF_EXT callExtension [_hopVerb, _hopArgs];

    // UNVERIFIED: the array form of callExtension is documented to return
    // [data, returnCode, errorCode], and to return ["",0,0] with an RPT line
    // when the extension is not loaded. Confirm with one diag_log of _r from a
    // real server before trusting the error text below.
    _r params [["_text", "", [""]], ["_rc", 0, [0]], ["_ec", 0, [0]]];

    if (_ec != 0) exitWith {
        [false, format ["pysqf: engine rejected verb '%1' (errorCode %2, returnCode %3)", _hopVerb, _ec, _rc]]
    };
    if (_text isEqualTo "") exitWith {
        // Not "empty result" — the protocol has no empty reply. Either the
        // extension is missing (client-side? wrong build? not server-side?) or
        // it is a ticket/index the core does not know.
        [false, format ["pysqf: empty reply to verb '%1' — extension not loaded, or unknown ticket/index", _hopVerb]]
    };
    [true, _text]
};

/* ------------------------------------------------------------------ *
 * Decode one protocol envelope. Never returns nil, never returns a
 * non-array: a malformed envelope becomes ["err", …] like anything else.
 * ------------------------------------------------------------------ */
private _envelope = {
    params ["_envVerb", "_envText"];

    private _a = fromJSON _envText;
    if (isNil "_a") exitWith {
        [false, format ["pysqf: unparsable reply to '%1': %2", _envVerb, _envText select [0, 200]]]
    };
    if !(_a isEqualType []) exitWith {
        [false, format ["pysqf: reply to '%1' is not an array: %2", _envVerb, _envText select [0, 200]]]
    };
    if (_a isEqualTo []) exitWith {
        [false, format ["pysqf: empty envelope from '%1'", _envVerb]]
    };
    [true, _a]
};

/* ------------------------------------------------------------------ *
 * Verb + args -> decoded envelope, or a synthesised ["err", …].
 * ------------------------------------------------------------------ */
private _speak = {
    params ["_spVerb", "_spArgs"];

    ([_spVerb, _spArgs] call _hop) params ["_hopOk", "_hopVal"];
    if (!_hopOk) exitWith { ["err", _hopVal] };

    ([_spVerb, _hopVal] call _envelope) params ["_envOk", "_envVal"];
    if (!_envOk) exitWith { ["err", _envVal] };

    _envVal
};

// Tickets are opaque decimal strings, but accepting a number costs one line and
// removes a whole class of caller mistake.
private _asTicket = {
    params ["_t"];
    if (_t isEqualType 0) then { _t = str _t };
    if !(_t isEqualType "") exitWith { "" };
    _t
};

// The counts in a poll reply arrive as strings, so accept either form rather
// than making every caller remember to parseNumber first.
private _asCount = {
    params ["_n"];
    if (_n isEqualType "") then { _n = parseNumber _n };
    if !(_n isEqualType 0) exitWith { -1 };
    floor _n
};

switch (toLowerANSI _verb) do {

    case "version": {
        ["version", []] call _speak
    };

    case "stats": {
        // Returned as the raw JSON string the core produced; run fromJSON over
        // element 1 yourself if you want it structured. Kept unparsed so this
        // function has exactly one JSON-decoding path (fetch).
        ["stats", []] call _speak
    };

    case "call": {
        _args params [["_fn", "", [""]], ["_argsJson", "", [""]]];

        if (_fn isEqualTo "") exitWith { ["err", "pysqf: call needs a '<module>.<func>' name"] };
        // PROTOCOL §2 writes the name as "<module>.<func>", so this checks for a
        // dot with something either side and nothing more. Deliberately not
        // "exactly one dot": a dotted package path is still resolvable at the
        // Python end, and the C core does not look at the name at all, so a
        // stricter rule here could only invent failures the backend would not.
        private _dot = _fn find ".";
        if (_dot < 1 || {_dot >= (count _fn) - 1}) exitWith {
            ["err", format ["pysqf: '%1' is not a <module>.<func> name", _fn]]
        };
        if (count _argsJson > PYSQF_MAX_ARG_JSON) exitWith {
            // Loudly, rather than sending a payload the engine may cut in half.
            // The protocol has no chunked upload; if you need one, that is a
            // protocol change, not something to paper over here.
            ["err", format ["pysqf: args JSON is %1 chars, limit is %2 — split the work", count _argsJson, PYSQF_MAX_ARG_JSON]]
        };

        ["call", [_fn, _argsJson]] call _speak
    };

    case "poll": {
        private _ticket = [_args param [0, ""]] call _asTicket;
        if (_ticket isEqualTo "") exitWith { ["err", "pysqf: poll needs a ticket"] };
        ["poll", [_ticket]] call _speak
    };

    case "free": {
        private _ticket = [_args param [0, ""]] call _asTicket;
        if (_ticket isEqualTo "") exitWith { ["err", "pysqf: free needs a ticket"] };
        ["free", [_ticket]] call _speak
    };

    case "chunk": {
        private _ticket = [_args param [0, ""]] call _asTicket;
        private _index  = [_args param [1, -1]] call _asCount;
        if (_ticket isEqualTo "") exitWith { ["err", "pysqf: chunk needs a ticket"] };
        if (_index < 0) exitWith { ["err", "pysqf: chunk needs a non-negative index"] };

        // Raw text, not an envelope — wrapped so callers see one shape.
        ([ "chunk", [_ticket, str _index] ] call _hop) params ["_ok", "_val"];
        if (!_ok) exitWith { ["err", _val] };
        ["ok", _val]
    };

    case "fetch": {
        private _ticket  = [_args param [0, ""]] call _asTicket;
        private _nchunks = [_args param [1, -1]] call _asCount;

        if (_ticket isEqualTo "") exitWith { ["err", "pysqf: fetch needs a ticket"] };
        if (_nchunks <= 0) exitWith {
            // A complete result is "exactly one JSON document" (PROTOCOL §2), so
            // zero chunks is a protocol violation, not an empty result. The core
            // now enforces the same reading — it converts an ok completion with
            // an empty payload into an error before a poll can ever report zero
            // chunks (src/results.c, uncarriable) — so reaching this line means
            // the core itself is broken. Kept anyway: it costs one comparison,
            // and the alternative reading (silently treating it as an empty
            // result) is the failed-versus-returned-nothing conflation.
            ["err", format ["pysqf: ticket %1 completed with %2 chunks — protocol violation", _ticket, _nchunks]]
        };
        if (_nchunks > PYSQF_MAX_CHUNKS) exitWith {
            ["err", format ["pysqf: ticket %1 claims %2 chunks, refusing above %3", _ticket, _nchunks, PYSQF_MAX_CHUNKS]]
        };

        // joinString, not repeated `+`: string concatenation in SQF reallocates
        // every time, which is O(n^2) over a few thousand chunks.
        private _parts = [];
        private _bad   = "";

        for "_i" from 0 to (_nchunks - 1) do {
            ([ "chunk", [_ticket, str _i] ] call _hop) params ["_ok", "_val"];
            if (!_ok) exitWith { _bad = _val };
            if (_val isEqualTo "") exitWith {
                // An empty chunk inside a completed result means the result was
                // truncated. Say so here, where the cause is still visible,
                // instead of letting fromJSON report it as a syntax error.
                _bad = format ["pysqf: chunk %1 of %2 for ticket %3 came back empty (truncated result)", _i, _nchunks, _ticket]
            };
            _parts pushBack _val;
        };

        if (_bad != "") exitWith { ["err", _bad] };

        private _text = _parts joinString "";
        private _val  = fromJSON _text;

        // SCALAR DOCUMENTS. Measured on 2.22.153995: fromJSON returns nil for a
        // top-level scalar at EVERY length -- `"hi"`, a 66-character string, a
        // bare number -- while arrays and objects parse. The BIKI's own example
        // (fromJSON """Hello there""") does not hold on this build.
        //
        // That is not exotic: any Python function returning a str, an int or a
        // bool serialises to exactly such a document, and diag.raw returns
        // nothing else. Without this the client reports "could not parse" for a
        // result that is perfectly well-formed JSON.
        //
        // Wrapping in an array and taking element 0 hands the same text to the
        // engine's own parser in a shape it accepts, so every scalar type is
        // covered without hand-rolled unescaping. Tried only after the direct
        // read fails, so documents that already parse pay nothing.
        if (isNil "_val" && { !(_text regexMatch "\s*null\s*") }) then {
            private _wrapped = fromJSON ("[" + _text + "]");
            if (!isNil "_wrapped" && { _wrapped isEqualType [] } && { count _wrapped isEqualTo 1 }) then {
                _val = _wrapped select 0;
            };
        };

        if (isNil "_val") exitWith {
            // fromJSON gives nil for two very different reasons: the document
            // was literally `null`, or it did not parse at all. Telling them
            // apart matters — collapsing them would re-create, one layer down,
            // the exact failed/empty conflation this project exists to avoid —
            // and the text is the only thing left that can tell them apart.
            if (_text regexMatch "\s*null\s*") then {
                // A real result that happens to be null. nil cannot be carried
                // safely inside an SQF array, so it is normalised to [], and it
                // is still reported as success.
                ["ok", []]
            } else {
                ["err", format ["pysqf: ticket %1 reassembled to %2 chars that fromJSON could not parse: %3",
                    _ticket, count _text, _text select [0, 200]]]
            };
        };

        ["ok", _val]
    };

    default {
        ["err", format ["pysqf: unknown verb '%1' (call, poll, chunk, free, version, stats, fetch)", _verb]]
    };
};
