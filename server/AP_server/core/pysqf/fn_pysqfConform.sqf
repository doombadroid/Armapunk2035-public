/*  VENDORED from the PySQF repo -- do not hand-edit.
    Re-vendor with scratchpad vendor_pysqf.py after pulling upstream.
    Renamed for this mission's convention: APS_ = owned by the server addon,
    which matters because the server compiles both CfgFunctions trees into
    missionNamespace and a shared name silently overwrites.
    Upstream name: fn_pysqfConform.sqf  */
// SPDX-License-Identifier: MIT
/*
    sqf/fn_pysqfConform.sqf   —   registered as  APS_fnc_pysqfConform

    WHY THIS EXISTS
      APS_fnc_pysqfSmoke proves the path works. It walks five layers and names
      the first one that is dead, which is the right instrument for "why isn't
      it working" and the wrong instrument for everything else: it only ever
      touches the happy path, one small payload, one error, one `select 1`.

      Every failure this transport can actually ship is in the corners. A chunk
      boundary off by one corrupts roughly one payload in ten thousand — large
      enough to reach production, rare enough to be blamed on anything else. A
      result store that hands ticket B's bytes to ticket A is silent data
      corruption. A `numeric` that arrives as a float is a bank balance that
      eventually disagrees with itself. And the founding defect of this whole
      subsystem — a failure that arrives looking like an empty success — is
      invisible to any test that does not deliberately go looking for it.

      So this suite exists to be exhaustive where the smoke test is fast. Run
      the smoke test when it is broken; run this before trusting it with money.

    WHY NO CASE MAY THROW
      Same reason the smoke test's stages are guarded, and it is not
      theoretical: a previous version of that file read the raw client's STRING
      tag as a Bool, `!"ok"` threw, and stages 2-5 died where stage 1 had just
      printed PASS. The output implicated the last thing that worked.

      A diagnostic that throws does not merely fail — it misattributes. Every
      case here runs inside `_runOne`'s try/catch and an exception becomes that
      case's FAIL with the exception text, so a shape mistake reads
      "FAIL types/shapes.bool_true — threw: |: Type String, expected Bool"
      instead of taking the next forty cases down with it.

    THE TWO RETURN CONVENTIONS — the mistake above, stated once
      APS_fnc_pysqfRaw -> [<String tag>, …]  tag is "ok" | "err" | "pending".
                         Three-valued because `poll` genuinely has three
                         outcomes and a Bool cannot carry that.
      APS_fnc_pysqfCall  -> [<Bool>, <value>]  two-valued, because by the time
                         it returns the polling is over.
      Both are shaped [x, y] and nothing about the shape tells them apart. So
      element 0 is ALWAYS read through a type filter:
          params [["_tag", "err", [""]]]      // raw
          params [["_ok",  false, [false]]]   // call
      A mix-up then fails here, loudly, instead of at the first operator that
      cares about the type.

    HOW TO ADD A CASE
      One entry in `_cases`:
          ["group", "what it proves", { …body… }]
          ["group", "what it proves", { …body… }, [payload for _arg]]
      The body returns [ok, detail] or [ok, detail, severity], where severity is
          ""          normal — a false here is a FAIL
          "critical"  a false here is a CRITICAL, banner-printed at the end
          "note"      not a verdict at all: an OBSERVATION, reported and not
                      counted as a failure (see "loss is not failure" below)
      A body may also read `_arg`, which is element 3 of its own row. That is
      how the table-driven sub-tables (payload sizes, shape keys, awkward
      fields) turn one row of data into one case without compiling code.

      A suite that is painful to extend stops being extended, so keep it to one
      line per case.

    LOSS IS NOT FAILURE
      SQF numbers are 32-bit floats. 16777217 cannot survive the crossing and
      never will. Reporting that as a FAIL would be reporting physics as a bug
      and would train the reader to ignore red. Those cases return "note" and
      print as OBS: a true fact about the engine, made visible, which is the
      suite's actual job.

    WHAT IT ASSUMES OF THE PYTHON SIDE  (the diag helper contract)
      Eight fixtures exist in python/pysqf/diag.py — ping, echo, boom, slow,
      raw, awkward, shapes, nothing — and none of them needs writing. What
      follows is the contract this suite asserts of them, restated here because
      the two sides have disagreed once already: the fixtures were unit-tested
      against their OWN vocabulary, which is invisible to a test that never
      reads this file. Where a helper answers a different shape, its cases fail
      naming the helper — not the transport.

      diag.raw(nbytes)
          A bare JSON string of exactly `nbytes` escape-free characters, so the
          SERIALISED DOCUMENT IS EXACTLY nbytes + 2 BYTES (the two quotes) and
          a case can name a chunk boundary directly. Say the +2 out loud every
          time: a case that asks for 8192 and expects one chunk is measuring a
          two-chunk document and would sit through an off-by-one in the core
          without noticing. The sizes below are therefore chosen as
          (boundary - 2).
          The pattern must contain no character JSON escapes (so bytes ==
          characters == document length - 2) and its period must be coprime
          with 8192 — the fixture's `_CYCLE` is 63 characters, which is odd and
          therefore coprime with a power of two — because a period sharing a
          factor with the chunk size makes a duplicated or dropped whole chunk
          invisible to a pattern check. The pattern must not depend on nbytes:
          two different sizes share a prefix.
          nbytes = 0 is legal to ask for and yields `""` — a two-byte document,
          one chunk, an ok result. That is correct: the empty STRING is a legal
          value and only an empty RESULT is not (PROTOCOL §2). See the
          zero-byte case below for what that does and does not cover.
      diag.awkward()
          A FLAT object of STRING fields, one per character class, keyed as in
          `_awkwardFields` below, plus a `_meta` object this suite ignores. The
          serialised document MUST exceed 8192 bytes and MUST place an escape
          sequence across the boundary — the fixture pads its `boundary` field
          so a six-byte \uXXXX escape starts at byte 8189 and is cut in half by
          the seam — because an escape split by the chunker is the one
          corruption that reassembly cannot see and `fromJSON` reports as a
          syntax error with no cause. `_meta.boundary_escape_at` reports where
          the escape actually landed.
      diag.shapes()
          An object keyed as in `_shapeFields` below, carrying one value per
          JSON type the mapping has to survive — including the ones SQF cannot
          hold faithfully, which are what the observations are for.
      diag.nothing()
          Returns None, i.e. the payload `null`: four bytes, one chunk, and a
          SUCCESS. It exists to be compared against a real failure.

    WHAT IT TOUCHES
      No game state, and no SQL that writes: every database case is a read with
      no table reference (casts and a `where false`), so it runs against any
      database and cannot change one.
      Its own footprint is two `missionNamespace` scratch variables
      (APS_pysqfConform_memo_*, APS_pysqfConform_unsched), cleared when the run
      ends, and one EachFrame handler that removes itself on its first frame.

    Usage (server debug console):
        [] spawn APS_fnc_pysqfConform;                  // everything
        ["chunks"] spawn APS_fnc_pysqfConform;          // one group
        [["chunks","db"]] spawn APS_fnc_pysqfConform;   // several

    Groups, in the order they run:
        verbs        the six verbs and fetch, and every way of calling them wrong
        tickets      ticket lifecycle: unknown, freed, double-freed, out of range
        chunks       the 8192-byte boundary, reassembly, chunk ordering
        content      character-class fidelity in both directions
        types        the JSON type mapping, including where it cannot be faithful
        errors       every error path, each of which must arrive as a value
        empty        returned-nothing versus failed versus empty container
        concurrency  overlap, cross-talk, timeouts, the unscheduled guard
        db           the database behaviours real data depends on
        hygiene      what the run left behind in the core's ticket table

    UNVERIFIED: not yet timed in-engine. Several cases deliberately wait on a
    slow call (1.5s, 3s, 6s) and the largest payload is a 1 MiB document read
    as 128 chunks, so expect tens of seconds rather than one.

    Read the RPT for lines prefixed [pysqf-conform]. The summary at the end
    repeats every failure, so the tail of the log is enough.
*/

// The protocol's chunk size (PROTOCOL §2, PYSQF_CHUNK_SIZE in src/results.h).
// Asserted against `stats` in the verbs group rather than trusted: if the core
// were built with a different value, every boundary expectation below is wrong
// and the suite must say so instead of failing eight cases mysteriously.
#define PYSQF_CHUNK   8192
// The SQF client's own args cap (PYSQF_MAX_ARG_JSON in fn_pysqf.sqf).
#define PYSQF_ARG_CAP 8000
// Detail text longer than this is cut. A 1 MiB payload must not be able to
// print itself into the RPT.
#define PYSQF_DETAIL_MAX    280
// Sentinel for "that key is not in the object". A string rather than nil
// because nil cannot be compared, printed or carried inside an array without
// special handling, and every one of those would be a place this file could
// throw. No producer can collide with it.
#define PYSQF_MISSING       "<absent>"

if (!isServer) exitWith {
    diag_log "[pysqf-conform] refused: server only. Run this on the server, not a client.";
};
if (!canSuspend) exitWith {
    diag_log "[pysqf-conform] refused: needs a scheduled context. Use  [] spawn APS_fnc_pysqfConform";
};

// FIXTURES BEFORE CASES. The daemon's --modules defaults to `pysqf.db` alone, so
// pysqf.diag -- every fixture this suite asserts against -- is absent unless it was
// asked for. Without this check that shows up as 2 CRITICAL and 46 failures whose
// text reads like protocol defects ("returning nothing and raising both report
// ok=false"), and the reader spends an hour in the transport before noticing the
// LookupError buried in each one. Measured 2026-08-15: functions=4 without it, 15
// with, and a NOT CONFORMANT verdict that was entirely false.
//
// A suite that cannot tell "the fixture is missing" from "the contract is broken"
// misattributes exactly the way the diagnostics it replaces did.
// Retried, because the FIRST call after a server restart can be refused while the
// core is still opening its IPC connection -- the daemon logs "client connected" at
// the same instant. A gate that reads a cold start as a missing fixture would send
// the reader to fix the daemon when nothing is wrong with it.
private _reg = [false, ""];
for "_try" from 1 to 3 do {
    if !(_reg param [0, false]) then {
        _reg = ["diag.ping", [], 10] call APS_fnc_pysqfCall;
        if !(_reg param [0, false]) then { uiSleep 1 };
    };
};
if !(_reg param [0, false]) exitWith {
    diag_log "[pysqf-conform] refused: the diag fixtures are not loaded on the daemon.";
    diag_log "[pysqf-conform]   Start it with:  PYSQF_MODULES=pysqf.db,pysqf.diag";
    diag_log format ["[pysqf-conform]   (diag.ping answered: %1)", _reg param [1, "no reason given"]];
    diag_log "[pysqf-conform] Nothing was tested. This is a setup gap, not a conformance result.";
};

params [["_filter", "", ["", []]]];
if (_filter isEqualType "") then { _filter = if (_filter isEqualTo "") then { [] } else { [_filter] }; };
private _wanted = [];
{ if (_x isEqualType "") then { _wanted pushBack toLowerANSI _x; }; } forEach _filter;
_filter = _wanted;

/* ====================================================================== *
 *  Preflight
 *
 *  Without these two checks a missing extension produces a hundred
 *  identical failures and the reader has to find the one that matters. One
 *  line is more useful than a hundred.
 * ====================================================================== */

if (isNil "APS_fnc_pysqfRaw" || {isNil "APS_fnc_pysqfCall"}) exitWith {
    diag_log "[pysqf-conform] refused: APS_fnc_pysqfRaw / APS_fnc_pysqfCall are not defined. The client is not compiled — check that your CfgFunctions registers sqf/fn_pysqf.sqf and sqf/fn_pysqfCall.sqf.";
};
if ((("pysqf" callExtension ["version", []]) param [0, "", [""]]) isEqualTo "") exitWith {
    diag_log "[pysqf-conform] refused: the extension is not loaded. Run  [] spawn APS_fnc_pysqfSmoke  — it diagnoses that in one line. Nothing here was tested.";
};

diag_log "[pysqf-conform] ================================================================";
diag_log format ["[pysqf-conform] starting%1", if (_filter isEqualTo []) then {""} else {format [" (groups: %1)", _filter joinString ", "]}];

/* ====================================================================== *
 *  Helpers
 *
 *  Case bodies are `call`ed from the runner, so everything private here is
 *  visible to them through the scope chain. That is deliberate: it keeps a
 *  case row to one line.
 * ====================================================================== */

// True when a raw text reply is the core's error envelope rather than payload.
// `chunk` returns bare bytes on success and an ["err",…] array on failure, and
// the SQF client wraps BOTH as ["ok", <text>] — so on the chunk path the
// tag cannot be trusted and the text has to be looked at. That asymmetry is
// itself tested in the tickets group.
private _isErrEnvelope = {
    params [["_t", "", [""]]];
    (_t select [0, 6]) isEqualTo "[""err"""
};

private _clip = {
    params [["_v", ""]];
    private _s = if (_v isEqualType "") then { _v } else { str _v };
    if (count _s > PYSQF_DETAIL_MAX) then { (_s select [0, PYSQF_DETAIL_MAX]) + format ["…(+%1 chars)", (count _s) - PYSQF_DETAIL_MAX] } else { _s }
};

// Dispatch. -> [_ticket, _err]; _ticket is "" when the call was refused.
private _dispatch = {
    params [["_fn", "", [""]], ["_args", [], [[]]]];
    // Integral numbers are stringified digit-by-digit rather than left to toJSON,
    // which prints anything past ~1e6 in exponent notation -- valid JSON that
    // Python then refuses for an int-annotated parameter.
    private _argsJson = if (_args isEqualType [] && { (_args findIf { !(_x isEqualType 0) }) isEqualTo -1 } && { count _args > 0 }) then {
        "[" + ((_args apply { if (_x isEqualTo round _x && { abs _x < 1e15 }) then { _x toFixed 0 } else { str _x } }) joinString ",") + "]"
    } else { toJSON _args };
    private _r = ["call", [_fn, _argsJson]] call APS_fnc_pysqfRaw;
    private _tag = _r param [0, "err", [""]];
    if (_tag isNotEqualTo "ok") exitWith { ["", _r param [1, "no reason given", [""]]] };
    private _t = _r param [1, "", [""]];
    if (_t isEqualTo "") exitWith { ["", "accepted but returned no ticket"] };
    [_t, ""]
};

// Poll to completion. -> ["ok", _nchunks, _nbytes, ""] | ["err",0,0,_msg] | ["timeout",0,0,_msg]
// Same backoff as APS_fnc_pysqfCall, and uiSleep for the same reason: real
// time, so time acceleration cannot stretch the cadence relative to a deadline
// that is also measured in real seconds.
private _await = {
    params [["_ticket", "", [""]], ["_timeout", 15, [0]]];
    private _deadline = diag_tickTime + _timeout;
    private _wait = 0.01;
    private _out = ["timeout", 0, 0, "loop exited without a verdict"];
    while { true } do {
        private _p  = ["poll", [_ticket]] call APS_fnc_pysqfRaw;
        private _st = _p param [0, "err", [""]];
        if (_st isEqualTo "ok") exitWith {
            _out = ["ok", parseNumber (_p param [1, "0", [""]]), parseNumber (_p param [2, "0", [""]]), ""];
        };
        if (_st isEqualTo "err") exitWith { _out = ["err", 0, 0, _p param [1, "no reason given", [""]]]; };
        if (_st isNotEqualTo "pending") exitWith { _out = ["err", 0, 0, format ["unrecognised poll status '%1'", _st]]; };
        if (diag_tickTime > _deadline) exitWith { _out = ["timeout", 0, 0, format ["still pending after %1s", _timeout]]; };
        uiSleep _wait;
        _wait = (_wait * 1.7) min 0.25;
    };
    _out
};

/*  One whole call at the verb level, decoded.
    -> [_tag, _nchunks, _nbytes, _payload, _ticket]
       _tag "ok"        _payload is the decoded value
            "err"       _payload is the message from Python or the core
            "timeout"   _payload says how long it waited
            "refused"   the call verb would not take it; _payload says why
            "fetchfail" it completed but could not be reassembled
    The ticket is freed on every path, including the failures — a ticket never
    freed is a leak that only shows up later as a rising eviction count, and
    this suite issues a few hundred of them.  */
private _probe = {
    params [["_fn", "", [""]], ["_args", [], [[]]], ["_timeout", 15, [0]]];
    ([_fn, _args] call _dispatch) params ["_ticket", "_derr"];
    if (_ticket isEqualTo "") exitWith { ["refused", 0, 0, _derr, ""] };

    ([_ticket, _timeout] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    if (_tg isNotEqualTo "ok") exitWith {
        ["free", [_ticket]] call APS_fnc_pysqfRaw;
        [_tg, 0, 0, _msg, _ticket]
    };

    private _f = ["fetch", [_ticket, _n]] call APS_fnc_pysqfRaw;
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if ((_f param [0, "err", [""]]) isNotEqualTo "ok") exitWith {
        ["fetchfail", _n, _bytes, _f param [1, "no reason given", [""]], _ticket]
    };
    ["ok", _n, _bytes, _f param [1, []], _ticket]
};

/*  The same, but stopping at the raw text and reporting every chunk's length.
    This is the instrument the chunk-boundary cases need: `fetch` hides the
    seams, and the seams are the whole point.
    -> [_tag, _nchunks, _nbytes, _text, _lens, _msg]  */
private _probeText = {
    params [["_fn", "", [""]], ["_args", [], [[]]], ["_timeout", 30, [0]]];
    ([_fn, _args] call _dispatch) params ["_ticket", "_derr"];
    if (_ticket isEqualTo "") exitWith { ["refused", 0, 0, "", [], _derr] };

    ([_ticket, _timeout] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    if (_tg isNotEqualTo "ok") exitWith {
        ["free", [_ticket]] call APS_fnc_pysqfRaw;
        [_tg, 0, 0, "", [], _msg]
    };

    private _parts = [];
    private _lens  = [];
    private _bad   = "";
    for "_i" from 0 to (_n - 1) do {
        private _c   = ["chunk", [_ticket, _i]] call APS_fnc_pysqfRaw;
        private _txt = _c param [1, "", [""]];
        if ((_c param [0, "err", [""]]) isNotEqualTo "ok") then {
            if (_bad isEqualTo "") then { _bad = format ["chunk %1 of %2 was refused: %3", _i, _n, _txt]; };
        } else {
            if ([_txt] call _isErrEnvelope) then {
                if (_bad isEqualTo "") then { _bad = format ["chunk %1 of %2 came back as an error envelope: %3", _i, _n, _txt]; };
            };
            _parts pushBack _txt;
            _lens  pushBack (count _txt);
        };
    };
    ["free", [_ticket]] call APS_fnc_pysqfRaw;

    if (_bad isNotEqualTo "") exitWith { ["chunkfail", _n, _bytes, "", _lens, _bad] };
    ["ok", _n, _bytes, _parts joinString "", _lens, ""]
};

/*  Results that several cases share are fetched once. Re-fetching diag.awkward
    fourteen times would turn one helper failure into fourteen different
    latencies and make the log harder to read, not easier.  */
private _memoKeys = ["awkward", "shapes"];
{ missionNamespace setVariable ["APS_pysqfConform_memo_" + _x, nil]; } forEach _memoKeys;
private _memo = {
    params [["_key", "", [""]], ["_fn", "", [""]], ["_args", [], [[]]], ["_timeout", 20, [0]]];
    private _var = "APS_pysqfConform_memo_" + _key;
    private _hit = missionNamespace getVariable [_var, []];
    if (_hit isNotEqualTo []) exitWith { _hit };
    private _r = [_fn, _args, _timeout] call _probe;
    missionNamespace setVariable [_var, _r];
    _r
};

// Smallest period p such that the first 3p characters repeat with period p.
// Detected rather than hardcoded so a different choice on the Python side is
// reported honestly instead of failing every payload case.
private _detectPeriod = {
    params [["_s", "", [""]]];
    private _n = count _s;
    private _p = -1;
    private _lim = 512 min (floor (_n / 3));
    for "_i" from 1 to _lim do {
        if (_p < 0) then {
            private _ref = _s select [0, _i];
            if ((_s select [_i, _i]) isEqualTo _ref && {(_s select [2 * _i, _i]) isEqualTo _ref}) then { _p = _i; };
        };
    };
    _p
};

/*  Integrity without a checksum.
    A window of one period, taken at an offset, must equal the reference
    rotated to that offset's phase. So a byte dropped, duplicated, or a chunk
    delivered out of order shifts the phase and every later window disagrees —
    which is exactly the corruption a chunker can produce and a length check
    cannot see. Windows are taken at 0, on both sides of every chunk boundary,
    and at the tail.
    UNVERIFIED: a substitution inside the first period is invisible to this,
    because the first period IS the reference. Closing that needs a checksum
    from the producing side; the cross-size prefix case below is the cheap
    partial answer.  */
private _checkPeriodic = {
    params [["_s", "", [""]], ["_p", 0, [0]]];
    private _n = count _s;
    if (_p <= 0 || {_n < _p * 3}) exitWith { [true, "not checked: no period detected, or the payload is shorter than three periods"] };

    private _ref = _s select [0, _p];
    private _offsets = [0];
    private _k = 1;
    while { (_k * PYSQF_CHUNK) < (_n - _p) && {_k <= 256} } do {
        _offsets pushBack (((_k * PYSQF_CHUNK) - _p) max 0);
        _offsets pushBack (_k * PYSQF_CHUNK);
        _k = _k + 1;
    };
    _offsets pushBack (_n - _p);

    private _bad = [];
    {
        private _off = _x;
        if (_off >= 0 && {_off + _p <= _n}) then {
            private _phase  = _off mod _p;
            private _expect = (_ref select [_phase]) + (_ref select [0, _phase]);
            if ((_s select [_off, _p]) isNotEqualTo _expect) then { _bad pushBack _off; };
        };
    } forEach _offsets;

    if (count _bad > 0) exitWith {
        [false, format ["the repeating pattern breaks at offset(s) %1 (period %2, %3 bytes) — bytes were dropped, duplicated or reordered by the chunk path", _bad select [0, 6], _p, _n]]
    };
    [true, format ["pattern intact at %1 checkpoints (period %2)", count _offsets, _p]]
};

// First index where two strings differ, or -1. Names the character class that
// broke instead of printing two walls of text.
private _firstDiff = {
    params [["_a", "", [""]], ["_b", "", [""]]];
    private _n = (count _a) min (count _b);
    private _at = -1;
    for "_i" from 0 to (_n - 1) do {
        if (_at < 0 && {(_a select [_i, 1]) isNotEqualTo (_b select [_i, 1])}) then { _at = _i; };
    };
    if (_at < 0 && {(count _a) != (count _b)}) then { _at = _n; };
    _at
};

// The "echo" field of a diag.echo payload, or PYSQF_MISSING.
private _echoOf = {
    params [["_v", []]];
    if !(_v isEqualType createHashMap) exitWith { PYSQF_MISSING };
    _v getOrDefault ["echo", PYSQF_MISSING]
};

// Every printable ASCII character, built from codes rather than written out:
// a literal run of them in this file is one careless editor away from being
// re-encoded, and the case would then be testing the editor.
private _asciiPrintable = [];
for "_i" from 32 to 126 do { _asciiPrintable pushBack _i; };
_asciiPrintable = toString _asciiPrintable;

/* ====================================================================== *
 *  The cases
 * ====================================================================== */

private _cases = [];

/* ---------------------------------------------------------- verbs ----- */

_cases pushBack ["verbs", "version answers ok + semver + a known backend", {
    private _r = ["version", []] call APS_fnc_pysqfRaw;
    _r params [["_tag", "err", [""]], ["_ver", "", [""]], ["_backend", "", [""]]];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["version returned %1", _r]] };
    if !(_ver regexMatch "\d+\.\d+\.\d+.*") exitWith { [false, format ["'%1' is not a semver", _ver]] };
    if !(_backend in ["ipc", "embed"]) exitWith { [false, format ["backend '%1' is neither 'ipc' nor 'embed'", _backend]] };
    [true, format ["%1 on the %2 backend", _ver, _backend]]
}];

_cases pushBack ["verbs", "stats parses, and its chunk_size is the one this suite assumes", {
    private _r = ["stats", []] call APS_fnc_pysqfRaw;
    if ((_r param [0, "err", [""]]) isNotEqualTo "ok") exitWith { [false, format ["stats returned %1", _r]] };
    private _j = fromJSON (_r param [1, "", [""]]);
    if (isNil "_j" || {!(_j isEqualType createHashMap)}) exitWith { [false, "the stats payload is not a JSON object"] };
    private _store = _j getOrDefault ["store", PYSQF_MISSING];
    if !(_store isEqualType createHashMap) exitWith { [false, format ["stats has no 'store' object: keys %1", keys _j]] };
    private _cs = _store getOrDefault ["chunk_size", -1];
    if (_cs isNotEqualTo PYSQF_CHUNK) exitWith {
        [false, format ["the core chunks at %1 bytes; every boundary expectation in the chunks group assumes %2. Fix the constant, not the cases.", _cs, PYSQF_CHUNK]]
    };
    [true, format ["chunk_size %1, slots %2, ttl %3s", _cs, _store getOrDefault ["slots_total", "?"], _store getOrDefault ["ttl_seconds", "?"]]]
}];

_cases pushBack ["verbs", "an unknown verb is refused by the client without a hop", {
    private _r = ["frobnicate", []] call APS_fnc_pysqfRaw;
    private _tag = _r param [0, "", [""]];
    if (_tag isNotEqualTo "err") exitWith { [false, format ["an unknown verb produced %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["verbs", "an unknown verb reaching the core answers err, not silence", {
    // Straight to the engine: the client filters unknown verbs, so this is the
    // only way to see what the core does with one. Silence here would be the
    // bad answer — it is indistinguishable from an unloaded extension.
    private _raw = "pysqf" callExtension ["frobnicate", []];
    private _txt = _raw param [0, "", [""]];
    if (_txt isEqualTo "") exitWith { [false, "the core answered an unknown verb with an empty string, which is how a missing extension looks"] };
    if !([_txt] call _isErrEnvelope) exitWith { [false, format ["expected an err envelope, got: %1", [_txt] call _clip]] };
    [true, [_txt] call _clip]
}];

_cases pushBack ["verbs", "call with a name that is not module.func is refused", {
    private _r = ["call", ["nodothere", "[]"]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "err") exitWith { [false, format ["a malformed function name was accepted: %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["verbs", "call with an empty name is refused", {
    private _r = ["call", ["", "[]"]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "err") exitWith { [false, format ["an empty function name was accepted: %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["verbs", "call with a leading-dot name is refused", {
    private _r = ["call", [".func", "[]"]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "err") exitWith { [false, format ["'.func' was accepted: %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["verbs", "an oversized args payload is refused, not truncated", {
    // The protocol has no chunked upload. A payload the engine cuts in half
    // arrives as a JSON syntax error with no cause, which is the failure the
    // client's cap exists to convert into a sentence.
    private _a = [];
    for "_i" from 1 to (PYSQF_ARG_CAP + 200) do { _a pushBack "x"; };
    private _r = ["call", ["diag.echo", _a joinString ""]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "err") exitWith {
        [false, format ["%1 chars of args JSON were accepted; the client's cap is %2 and the engine's real limit is unknown", PYSQF_ARG_CAP + 200, PYSQF_ARG_CAP]]
    };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["verbs", "fetch of a zero-chunk result is refused as a protocol violation", {
    private _r = ["fetch", ["1", 0]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "err") exitWith { [false, format ["fetch accepted 0 chunks: %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["verbs", "call returns before the work does (poll says pending)", {
    // `call` must dispatch and return. If it blocked, the engine thread would
    // be held for the duration of every Python call — the one thing the whole
    // ticket design exists to prevent.
    private _t0 = diag_tickTime;
    ([ "diag.slow", [1.5] ] call _dispatch) params ["_ticket", "_err"];
    private _dt = diag_tickTime - _t0;
    if (_ticket isEqualTo "") exitWith { [false, format ["dispatch refused: %1", _err]] };
    private _p   = ["poll", [_ticket]] call APS_fnc_pysqfRaw;
    private _st  = _p param [0, "", [""]];
    ([_ticket, 10] call _await) params ["_tg"];
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if (_dt > 0.5) exitWith { [false, format ["the call verb held the thread for %1s — it must not block", _dt toFixed 3]] };
    if (_st isNotEqualTo "pending") exitWith {
        [false, format ["the first poll after dispatching a 1.5s call said '%1', not 'pending' — either the backend is synchronous or the ticket is wrong", _st]]
    };
    [true, format ["dispatched in %1s, first poll pending, completed as '%2'", _dt toFixed 4, _tg]]
}];

/* -------------------------------------------------------- tickets ----- */

_cases pushBack ["tickets", "poll on a ticket that never existed is an error", {
    private _r = ["poll", ["4294967295"]] call APS_fnc_pysqfRaw;
    private _tag = _r param [0, "", [""]];
    if (_tag isEqualTo "pending") exitWith { [false, "a ticket that was never issued reports 'pending' — a caller would poll it until its deadline"] };
    if (_tag isNotEqualTo "err") exitWith { [false, format ["expected err, got %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["tickets", "chunk on a ticket that never existed does not return data", {
    private _r = ["chunk", ["4294967295", 0]] call APS_fnc_pysqfRaw;
    private _tag = _r param [0, "", [""]];
    private _txt = _r param [1, "", [""]];
    if (_tag isEqualTo "err") exitWith { [true, format ["err: %1", _txt]] };
    if ([_txt] call _isErrEnvelope) exitWith {
        // Not a failure: the bytes say error and a reassembly cannot swallow
        // them silently (fromJSON will refuse the document). But it is worth
        // seeing, because the TAG says ok and only the text says otherwise.
        [true, format ["reported as ['ok', <err envelope>] — the tag says ok, the text says %1. Callers on the chunk path must read the text, not the tag.", [_txt] call _clip], "note"]
    };
    [false, format ["a chunk of a non-existent ticket returned %1 bytes that look like data: %2", count _txt, [_txt] call _clip]]
}];

_cases pushBack ["tickets", "free of a ticket that never existed is a no-op, not an error", {
    private _r = ["free", ["4294967295"]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "ok") exitWith {
        [false, format ["free is documented idempotent (PROTOCOL §2) but answered %1 — every error path in the client frees a ticket it may not own", _r]]
    };
    [true, "ok"]
}];

_cases pushBack ["tickets", "double free is idempotent", {
    // The client frees on the success path, the error path and the timeout
    // path. If a second free were an error, every timeout would log a spurious
    // one and the real ones would stop being read.
    ([ "diag.ping", [] ] call _dispatch) params ["_ticket", "_err"];
    if (_ticket isEqualTo "") exitWith { [false, format ["dispatch refused: %1", _err]] };
    ([_ticket, 10] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    if (_tg isNotEqualTo "ok") exitWith { [false, format ["the call did not complete: %1 %2", _tg, _msg]] };
    private _f1 = ["free", [_ticket]] call APS_fnc_pysqfRaw;
    private _f2 = ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if ((_f1 param [0, "", [""]]) isNotEqualTo "ok") exitWith { [false, format ["the first free answered %1", _f1]] };
    if ((_f2 param [0, "", [""]]) isNotEqualTo "ok") exitWith { [false, format ["the second free answered %1 — free must be idempotent", _f2]] };
    [true, format ["ticket %1 freed twice, ok both times", _ticket]]
}];

_cases pushBack ["tickets", "poll after free reports unknown, never pending", {
    // 'pending' here would be the worst answer available: the caller waits out
    // its whole deadline for a result that was deleted.
    ([ "diag.ping", [] ] call _dispatch) params ["_ticket", "_err"];
    if (_ticket isEqualTo "") exitWith { [false, format ["dispatch refused: %1", _err]] };
    ([_ticket, 10] call _await) params ["_tg"];
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    private _p = ["poll", [_ticket]] call APS_fnc_pysqfRaw;
    private _st = _p param [0, "", [""]];
    if (_st isEqualTo "pending") exitWith { [false, "a freed ticket reports 'pending' — a caller would wait for it until its deadline"] };
    if (_st isEqualTo "ok") exitWith { [false, "a freed ticket still reports a complete result; free did not free it"] };
    if (_st isNotEqualTo "err") exitWith { [false, format ["expected err, got %1", _p]] };
    [true, _p param [1, "", [""]]]
}];

_cases pushBack ["tickets", "chunk with a negative index is refused", {
    private _r = ["chunk", ["1", -1]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "err") exitWith { [false, format ["a negative chunk index was accepted: %1", _r]] };
    [true, _r param [1, "", [""]]]
}];

_cases pushBack ["tickets", "chunk past the end of a real result does not return data", {
    ([ "diag.ping", [] ] call _dispatch) params ["_ticket", "_err"];
    if (_ticket isEqualTo "") exitWith { [false, format ["dispatch refused: %1", _err]] };
    ([_ticket, 10] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    if (_tg isNotEqualTo "ok") exitWith { ["free", [_ticket]] call APS_fnc_pysqfRaw; [false, format ["the call did not complete: %1 %2", _tg, _msg]] };
    private _r   = ["chunk", [_ticket, _n + 5]] call APS_fnc_pysqfRaw;
    private _txt = _r param [1, "", [""]];
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isEqualTo "err") exitWith { [true, format ["index %1 of %2: %3", _n + 5, _n, _txt]] };
    if ([_txt] call _isErrEnvelope) exitWith { [true, format ["index %1 of %2 answered an err envelope: %3", _n + 5, _n, [_txt] call _clip], "note"] };
    [false, format ["index %1 of a %2-chunk result returned %3 bytes of something: %4", _n + 5, _n, count _txt, [_txt] call _clip]]
}];

_cases pushBack ["tickets", "chunk of an incomplete result returns nothing usable", {
    // A partial read of a result still being written is silent corruption: the
    // document parses or it does not, and either way the caller was never told
    // the work had not finished.
    ([ "diag.slow", [1.5] ] call _dispatch) params ["_ticket", "_err"];
    if (_ticket isEqualTo "") exitWith { [false, format ["dispatch refused: %1", _err]] };
    private _r   = ["chunk", [_ticket, 0]] call APS_fnc_pysqfRaw;
    private _txt = _r param [1, "", [""]];
    private _tagIsErr = (_r param [0, "", [""]]) isEqualTo "err";
    ([_ticket, 10] call _await) params ["_tg"];
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if (_tagIsErr) exitWith { [true, format ["err while pending: %1", [_txt] call _clip]] };
    if ([_txt] call _isErrEnvelope) exitWith { [true, format ["err envelope while pending: %1", [_txt] call _clip], "note"] };
    [false, format ["chunk 0 of a still-pending ticket returned %1 bytes: %2", count _txt, [_txt] call _clip]]
}];

_cases pushBack ["tickets", "tickets are not reused within a run", {
    // Reuse would let a late completion land on a ticket someone else now owns
    // — one caller reading another caller's result, which is the same class of
    // bug as cross-talk but far harder to see.
    private _seen = [];
    private _dupe = "";
    for "_i" from 1 to 8 do {
        ([ "diag.ping", [] ] call _dispatch) params ["_ticket", "_derr"];
        if (_ticket isEqualTo "") then {
            if (_dupe isEqualTo "") then { _dupe = format ["dispatch %1 refused: %2", _i, _derr]; };
        } else {
            if (_ticket in _seen) then { _dupe = format ["ticket %1 was issued twice", _ticket]; };
            _seen pushBack _ticket;
            ([_ticket, 10] call _await) params ["_tg"];
            ["free", [_ticket]] call APS_fnc_pysqfRaw;
        };
    };
    if (_dupe isNotEqualTo "") exitWith { [false, _dupe] };
    [true, format ["%1 distinct tickets: %2 … %3", count _seen, _seen select 0, _seen select ((count _seen) - 1)]]
}];

/* --------------------------------------------------------- chunks ----- */

/*  The reason diag.raw exists.

    An off-by-one at the 8192 boundary corrupts about one payload in ten
    thousand: frequent enough to ship, rare enough to be blamed on the
    database, the network, or Arma. So the sizes either side of the boundary
    are named explicitly rather than sampled.

    The +2 is the whole reason the sizes look odd. diag.raw(n) produces a
    DOCUMENT of n + 2 bytes, so the sizes asked for below are (boundary - 2)
    and the boundary is the thing actually transported. Asking for 8191/8192/
    8193 — the obvious choice, and the one this file had first — transports
    8193/8194/8195, all of them two-chunk documents, and the 1→2 transition
    that an off-by-one in results.c would break is never issued at all.

    Each case asserts three independent things and reports them separately, so
    a failure names the layer that broke:
      1. the core chunked what it was given correctly (chunks == ceil(bytes/8192))
      2. diag.raw produced the size that was asked for (helper contract)
      3. the bytes came back identical (length, and the pattern's phase)  */
private _caseRawSize = {
    _arg params [["_want", 0, [0]]];
    private _timeout = if (_want > 200000) then { 45 } else { 20 };
    ([ "diag.raw", [_want], _timeout ] call _probeText) params ["_tag", "_n", "_bytes", "_text", "_lens", "_msg"];

    if (_tag isNotEqualTo "ok") exitWith {
        [false, format ["diag.raw(%1) came back '%2': %3", _want, _tag, [_msg] call _clip]]
    };

    private _problems = [];

    // 1. the chunker, measured against what the core itself reported
    private _expectChunks = ceil (_bytes / PYSQF_CHUNK);
    if (_n != _expectChunks) then {
        _problems pushBack format ["poll reported %1 bytes in %2 chunks; %3 bytes needs %4", _bytes, _n, _bytes, _expectChunks];
    };
    if (count _lens != _n) then {
        _problems pushBack format ["poll promised %1 chunks but %2 could be read", _n, count _lens];
    } else {
        private _sum = 0;
        { _sum = _sum + _x } forEach _lens;
        if (_sum != _bytes) then { _problems pushBack format ["the chunks total %1 bytes, poll said %2", _sum, _bytes]; };
        {
            if (_x > PYSQF_CHUNK) then { _problems pushBack format ["chunk %1 is %2 bytes, over the %3 limit", _forEachIndex, _x, PYSQF_CHUNK]; };
            if (_x < 1) then { _problems pushBack format ["chunk %1 is empty", _forEachIndex]; };
            if (_forEachIndex < (_n - 1) && {_x != PYSQF_CHUNK}) then {
                _problems pushBack format ["chunk %1 of %2 is %3 bytes; only the last may be short", _forEachIndex, _n, _x];
            };
        } forEach _lens;
    };

    // 3. reassembly
    if (count _text != _bytes) then {
        _problems pushBack format ["reassembled to %1 characters, poll said %2 bytes", count _text, _bytes];
    };

    // 2. the helper's own contract — a FAILURE, not an annotation. This used to
    //    be appended to a PASS line, which meant every raw case could report
    //    "asked for 8191, produced 8193" and still print PASS: the suite would
    //    have measured a document two bytes from the one it named, at the one
    //    boundary the group exists for, and said so in text nobody reads.
    if (_bytes != _want + 2) then {
        _problems pushBack format ["diag.raw(%1) produced a %2-byte document; the contract is exactly %3 (the payload plus two quotes). Every size below is chosen as (boundary - 2), so a different rule here means the boundary was never issued.", _want, _bytes, _want + 2];
    };

    // the decoded value, and the pattern's phase across every boundary
    private _pattern = "";
    if (_bytes >= 64) then {
        // Same scalar-document limitation the client works around: fromJSON on
        // this build returns nil for ANY top-level scalar, and diag.raw returns
        // nothing else. Wrapping hands the same text to the engine's parser in a
        // shape it accepts, so this case measures the TRANSPORT rather than a
        // documented-but-untrue engine behaviour.
        private _v = fromJSON _text;
        if (isNil "_v") then {
            private _w = fromJSON ("[" + _text + "]");
            if (!isNil "_w" && { _w isEqualType [] } && { count _w isEqualTo 1 }) then { _v = _w select 0 };
        };
        if (isNil "_v") then {
            _problems pushBack format ["the reassembled document does not parse: %1", [_text select [0, 120]] call _clip];
        } else {
            if !(_v isEqualType "") then {
                _problems pushBack format ["diag.raw returned a %1, expected a JSON string", typeName _v];
            } else {
                if (count _v != _bytes - 2) then {
                    _problems pushBack format ["the decoded string is %1 characters; a %2-byte document should carry %3", count _v, _bytes, _bytes - 2];
                };
                private _p = [_v] call _detectPeriod;
                ([_v, _p] call _checkPeriodic) params ["_pOk", "_pDetail"];
                if (!_pOk) then { _problems pushBack _pDetail; } else { _pattern = ", " + _pDetail; };
            };
        };
    };

    if (count _problems > 0) exitWith { [false, _problems joinString "; "] };
    [true, format ["a %1-byte document in %2 chunk(s), reassembled identically%3", _bytes, _n, _pattern]]
};

/*  One line per size, named by the DOCUMENT the size produces rather than the
    payload asked for, because the document is what the chunker sees.
    8189/8190/8191 payloads are documents of 8191/8192/8193 bytes: the last one
    that fits in a chunk, the one that exactly fills it, and the first that
    needs two. 16382 and 65534 are documents of exactly 2 and 8 chunks; 1048574
    is a 1 MiB document, exactly 128.  */
{ _cases pushBack ["chunks", format ["a %1-byte document (payload %2)", _x + 2, _x], _caseRawSize, [_x]]; } forEach
    [1, 2, 64, 8189, 8190, 8191, 16382, 65534, 1048574];

_cases pushBack ["chunks", "an empty payload is never an ok result with zero chunks", {
    // PROTOCOL §2: a complete result is at least one chunk, because the
    // shortest JSON document is `null`. An ok completion carrying nothing is
    // converted to an err by the core and counted as `uncarriable`. Either
    // answer is correct here; ok-with-zero-chunks is the one that would put
    // the failed/empty conflation back into the protocol itself.
    //
    // UNVERIFIED — and this is the honest limit of the case: diag.raw(0)
    // returns the empty STRING, which serialises to `""`, a legal two-byte
    // document. So the branch below is unreachable THROUGH THIS FIXTURE, and
    // no fixture can reach it: nothing `pysqf.to_json` can produce is
    // zero-length. The core's `uncarriable` path is covered only by
    // test/test_results.c, out of process. What this case does prove is that
    // the emptiest thing a Python function can return still crosses as a
    // document — which is the property callers actually depend on.
    ([ "diag.raw", [0], 15 ] call _probeText) params ["_tag", "_n", "_bytes", "_text", "_lens", "_msg"];
    if (_tag isEqualTo "err") exitWith { [true, format ["refused as uncarriable, which is also a documented answer: %1", [_msg] call _clip]] };
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["came back '%1': %2", _tag, [_msg] call _clip]] };
    if (_n < 1) exitWith {
        [false, format ["poll reported an ok result with %1 chunks. PROTOCOL §2 says a successful result is at least one chunk; zero puts 'failed' and 'returned nothing' back on the same code path.", _n], "critical"]
    };
    if (_bytes != 2) exitWith {
        [false, format ["an empty payload produced a %1-byte document; diag.raw(0) is the two bytes of an empty JSON string", _bytes]]
    };
    [true, format ["carried as %1 chunk(s), %2 bytes — the empty payload became a real document. The core's zero-length path is NOT reached from here; see test/test_results.c.", _n, _bytes]]
}];

_cases pushBack ["chunks", "chunks may be read out of order and repeatedly", {
    // PROTOCOL §2: a result is immutable once complete. If it were not, the
    // client's reassembly loop would be the only order that ever worked.
    ([ "diag.raw", [20000] ] call _dispatch) params ["_ticket", "_err"];
    if (_ticket isEqualTo "") exitWith { [false, format ["dispatch refused: %1", _err]] };
    ([_ticket, 20] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    if (_tg isNotEqualTo "ok") exitWith { ["free", [_ticket]] call APS_fnc_pysqfRaw; [false, format ["%1: %2", _tg, [_msg] call _clip]] };
    if (_n < 3) exitWith { ["free", [_ticket]] call APS_fnc_pysqfRaw; [false, format ["expected at least 3 chunks for a 20000-byte payload, poll said %1", _n]] };

    /*  Every read is checked, not just compared. Reading only element 1 and
        trusting it was this case's own version of the bug the suite exists to
        catch: if all 3n reads FAIL, element 1 is the same error message every
        time, forwards equals backwards equals the re-read, and the case prints
        PASS for a result store that returned no data at all. So each read must
        be an ok whose text is not an error envelope, and the reassembled
        length must match what poll promised — an all-error read cannot satisfy
        that last one however self-consistent it is.  */
    private _bad = "";
    private _readChunk = {
        params [["_idx", 0, [0]]];
        private _c   = ["chunk", [_ticket, _idx]] call APS_fnc_pysqfRaw;
        private _txt = _c param [1, "", [""]];
        if ((_c param [0, "err", [""]]) isNotEqualTo "ok") then {
            if (_bad isEqualTo "") then { _bad = format ["chunk %1 was refused: %2", _idx, [_txt] call _clip]; };
        } else {
            if (([_txt] call _isErrEnvelope) && {_bad isEqualTo ""}) then {
                _bad = format ["chunk %1 came back as an error envelope: %2", _idx, [_txt] call _clip];
            };
        };
        _txt
    };

    private _fwd = [];
    for "_i" from 0 to (_n - 1) do { _fwd pushBack ([_i] call _readChunk); };
    private _rev = [];
    _rev resize _n;
    for "_i" from (_n - 1) to 0 step -1 do { _rev set [_i, ([_i] call _readChunk)]; };
    // and chunk 0 a third time, after everything else has been read
    private _again = [0] call _readChunk;
    ["free", [_ticket]] call APS_fnc_pysqfRaw;

    if (_bad isNotEqualTo "") exitWith { [false, _bad] };
    private _joined = _fwd joinString "";
    if ((count _joined) != _bytes) exitWith {
        [false, format ["the %1 chunks reassemble to %2 characters; poll promised %3 bytes", _n, count _joined, _bytes]]
    };
    if (_joined isNotEqualTo (_rev joinString "")) exitWith {
        [false, format ["reading %1 chunks backwards produced a different document — the result is not immutable", _n]]
    };
    if (_again isNotEqualTo (_fwd select 0)) exitWith { [false, "re-reading chunk 0 produced different bytes"] };
    [true, format ["%1 chunks, %2 bytes, identical forwards, backwards, and on a re-read", _n, _bytes]]
}];

_cases pushBack ["chunks", "the pattern does not depend on the size asked for", {
    // Cheap guard on the one corruption the phase check cannot see: a
    // substitution inside the first period, which is the reference the phase
    // check measures everything else against. Two sizes must share a prefix.
    ([ "diag.raw", [9000], 20 ] call _probe) params ["_tagA", "_nA", "_bytesA", "_a"];
    ([ "diag.raw", [70000], 30 ] call _probe) params ["_tagB", "_nB", "_bytesB", "_b"];
    if (_tagA isNotEqualTo "ok" || {_tagB isNotEqualTo "ok"}) exitWith { [false, format ["one of the two calls failed: %1 / %2", _tagA, _tagB]] };
    if !(_a isEqualType "" && {_b isEqualType ""}) exitWith { [false, format ["expected two strings, got %1 and %2", typeName _a, typeName _b]] };
    private _k = 512 min (count _a) min (count _b);
    if ((_a select [0, _k]) isNotEqualTo (_b select [0, _k])) exitWith {
        private _at = [_a select [0, _k], _b select [0, _k]] call _firstDiff;
        [false, format ["a %1-byte and a %2-byte payload disagree at offset %3 — the pattern is size-dependent, so the phase checks measure against a moving reference", _bytesA, _bytesB, _at]]
    };
    [true, format ["the first %1 characters of a %2-byte and a %3-byte payload are identical", _k, _bytesA, _bytesB]]
}];

/* -------------------------------------------------------- content ----- */

/*  Round-trip fidelity, authored on this side.
    Every value here is built in SQF, sent through toJSON / the wire / Python /
    to_json / fromJSON, and compared byte for byte with what was sent. Nothing
    is shared between the two sides but the wire, so an escaping bug in either
    direction shows up as a mismatch and the case names the character class.  */
private _caseEcho = {
    _arg params [["_label", "", [""]], ["_sent", ""]];
    ([ "diag.echo", [_sent], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2 — %3", _label, _tag, [_payload] call _clip]] };
    private _got = [_payload] call _echoOf;
    if (_got isEqualTo PYSQF_MISSING && {_sent isNotEqualTo PYSQF_MISSING}) exitWith { [false, format ["the result has no 'echo' field: %1", [_payload] call _clip]] };
    if (_got isEqualTo _sent) exitWith { [true, format ["%1 chars intact", count _sent]] };
    if !(_got isEqualType _sent) exitWith { [false, format ["sent a %1, got a %2 back", typeName _sent, typeName _got]] };
    if (_sent isEqualType "") exitWith {
        private _at = [_sent, _got] call _firstDiff;
        [false, format ["first difference at character %1: sent %2 bytes %3, got %4 bytes %5", _at,
            count _sent, str ((toArray _sent) select [(_at - 2) max 0, 6]),
            count _got,  str ((toArray _got)  select [(_at - 2) max 0, 6])]]
    };
    [false, format ["sent %1, got %2", [_sent] call _clip, [_got] call _clip]]
};

// One line per character class. toString of explicit codes rather than a
// literal wherever the character cannot be written in an SQF string, or could
// be mangled by a tool that touches this file later.
//
// UNVERIFIED: the last three rows are UTF-8 literals in this file, so they also
// depend on the file surviving packing and preprocessing byte-for-byte. A
// failure there is worth having — it is a real thing that can happen to a
// string on its way to a player — but read it as "somewhere between this file
// and Python", not specifically as a PySQF fault. The rows above them are
// built from character codes and carry no such dependency.
{ _cases pushBack ["content", format ["echo round-trip: %1", _x select 0], _caseEcho, _x]; } forEach [
    ["printable ascii",        _asciiPrintable],
    ["double quotes",          "he said ""hi"" twice"],
    ["backslashes",            "C:\path\to\a\file and a trailing pair \\"],
    ["forward slashes",        "a/b/c and </closing> which JSON may escape or not"],
    ["newline",                toString [97, 10, 98]],
    ["carriage return",        toString [97, 13, 98]],
    ["tab",                    toString [97, 9, 98]],
    ["control bytes 1-8",      toString [1, 2, 3, 4, 5, 6, 7, 8]],
    ["control bytes 11-31",    toString [11, 12, 14, 27, 31]],
    ["delete 127",             toString [97, 127, 98]],
    ["apostrophes",            "O'Brien's ''quoted'' string"],
    ["percent and format",     "100%% done, %1 %2 %%"],
    ["braces and brackets",    "{""a"": [1, 2]} </>"],
    ["a string that looks like an array", "[1,2]"],
    ["a string that looks like a number", "0123.4500"],
    ["a string that looks like null",     "null"],
    ["the empty string",       ""],
    ["leading/trailing space", "  padded  "],
    ["accented latin",         "café naïve — Straße"],
    ["cjk",                    "日本語のテスト"],
    ["emoji",                  "rocket 🚀 and flag 🏴"],
    ["a long line",            "0123456789" + "abcdefghij" + "ABCDEFGHIJ"]
];

_cases pushBack ["content", "a value sent through echo comes back as the same SQF type", {
    // Types are a separate failure from bytes: a string of digits that returns
    // as a number is the money rule broken at the transport layer rather than
    // in the database layer, and it would pass every byte comparison above.
    private _sent = ["12345678.91", 42, true, [], ["a", 1]];
    ([ "diag.echo", [_sent], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    private _got = [_payload] call _echoOf;
    if (_got isEqualTo PYSQF_MISSING) exitWith { [false, format ["no 'echo' field: %1", [_payload] call _clip]] };
    if !(_got isEqualType []) exitWith { [false, format ["expected an array, got %1", typeName _got]] };
    private _bad = [];
    {
        private _want = _x;
        private _idx  = _forEachIndex;
        if (_idx >= count _got) then { _bad pushBack format ["element %1 is missing", _idx]; }
        else {
            // A JSON null lands as a hole in the array, and typeName on a hole
            // throws — which in this file would be a failure attributed to the
            // wrong case.
            if (isNil { _got select _idx }) then { _bad pushBack format ["element %1 came back nil", _idx]; }
            else {
                private _have = _got select _idx;
                if (typeName _have isNotEqualTo typeName _want) then { _bad pushBack format ["element %1: sent %2, got %3", _idx, typeName _want, typeName _have]; };
            };
        };
    } forEach _sent;
    if (count _bad > 0) exitWith { [false, _bad joinString "; "] };
    [true, format ["%1 elements, types preserved", count _sent]]
}];

/*  The same fidelity question asked from the Python side, because the two
    directions fail separately: an encoder bug is invisible to a round-trip
    that only ever sends what SQF can write.  */
private _awkwardFields = [
    // key,               how the class is recognised on this side, argument
    ["ascii",             "hasbyte", 126, "printable ascii"],
    ["quote",             "hasbyte",  34, "double quote"],
    ["backslash",         "hasbyte",  92, "backslash"],
    ["newline",           "hasbyte",  10, "line feed"],
    ["cr",                "hasbyte",  13, "carriage return"],
    ["tab",               "hasbyte",   9, "tab"],
    ["controls",          "hasbyte",   1, "control bytes below space"],
    ["apostrophe",        "hasbyte",  39, "apostrophe"],
    ["percent",           "hasbyte",  37, "percent"],
    ["slash",             "hasbyte",  47, "forward slash"],
    ["unicode",           "nonascii",  0, "non-ascii text"],
    ["emoji",             "nonascii",  0, "astral-plane characters"],
    ["looks_like_json",   "isstring",  0, "a string whose text is JSON"],
    ["empty",             "isstring",  0, "the empty string"],
    ["spaces",            "hasbyte",  32, "surrounding whitespace"],
    ["boundary",          "isstring",  0, "an escape sitting on a chunk boundary"]
];

private _caseAwkward = {
    _arg params [["_key", "", [""]], ["_kind", "", [""]], ["_param", 0, [0]], ["_label", "", [""]]];
    ([ "awkward", "diag.awkward", [], 25 ] call _memo) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["diag.awkward is unavailable (%1): %2", _tag, [_payload] call _clip]] };
    if !(_payload isEqualType createHashMap) exitWith { [false, format ["diag.awkward returned a %1, expected an object", typeName _payload]] };
    private _v = _payload getOrDefault [_key, PYSQF_MISSING];
    if (!(_key in (keys _payload))) exitWith { [false, format ["no field '%1' (%2). Fields present: %3", _key, _label, keys _payload]] };
    if !(_v isEqualType "") exitWith { [false, format ["field '%1' is a %2, expected a string", _key, typeName _v]] };

    private _bytes2 = toArray _v;
    switch (_kind) do {
        case "hasbyte": {
            if (!(_param in _bytes2)) exitWith { [false, format ["field '%1' (%2) does not contain byte %3 — the class did not survive the crossing. Got: %4", _key, _label, _param, [_v] call _clip]] };
            [true, format ["%1 intact (%2 chars)", _label, count _v]]
        };
        case "nonascii": {
            private _hi = _bytes2 findIf {_x > 127};
            if (_hi < 0) exitWith { [false, format ["field '%1' (%2) came back pure ascii: %3", _key, _label, [_v] call _clip]] };
            [true, format ["%1 intact (%2 chars, first non-ascii at %3)", _label, count _v, _hi]]
        };
        default {
            // Presence and type are the whole assertion: an empty string that
            // arrives as an empty string is exactly the point.
            [true, format ["%1: %2 chars", _label, count _v]]
        };
    };
};

{ _cases pushBack ["content", format ["awkward field: %1", _x select 3], _caseAwkward, _x]; } forEach _awkwardFields;

_cases pushBack ["content", "the awkward document is multi-chunk, so an escape crosses a boundary", {
    // An escape sequence split by the chunker is the one corruption that
    // reassembly cannot notice and fromJSON reports as a syntax error with no
    // cause. If this document fits in one chunk, the case above tested the
    // escaping but not the interaction, and the coverage claim is false.
    ([ "awkward", "diag.awkward", [], 25 ] call _memo) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["diag.awkward is unavailable (%1): %2", _tag, [_payload] call _clip]] };
    if (_n < 2) exitWith {
        [false, format ["the document is %1 bytes in %2 chunk(s). The helper contract asks for one over %3 bytes with an escape on the boundary; as it stands the escape/chunk interaction is untested.", _bytes, _n, PYSQF_CHUNK]]
    };
    // Multi-chunk is necessary and not sufficient: the escape has to be ON the
    // seam. The fixture reports where it put it, so the case can say the seam
    // was crossed instead of assuming a long document crossed it somewhere.
    private _at = -1;
    if (_payload isEqualType createHashMap) then {
        private _meta = _payload getOrDefault ["_meta", createHashMap];
        if (_meta isEqualType createHashMap) then { _at = _meta getOrDefault ["boundary_escape_at", -1]; };
    };
    if !(_at isEqualType 0) exitWith { [false, format ["_meta.boundary_escape_at is a %1, expected a number", typeName _at]] };
    if (_at < 0) exitWith {
        [true, format ["%1 bytes in %2 chunks, parsed after reassembly — but the fixture did not report where it placed its boundary escape, so the split-escape case rests on the document being long, not on the escape being cut", _bytes, _n], "note"]
    };
    // A \uXXXX escape is six bytes. Straddling means it starts before the seam
    // and ends after it.
    if (_at >= PYSQF_CHUNK || {_at + 6 <= PYSQF_CHUNK}) exitWith {
        [false, format ["the fixture placed its escape at byte %1, which does not straddle the %2-byte seam — reassembly is exercised, an escape cut in half by the chunker is not", _at, PYSQF_CHUNK]]
    };
    [true, format ["%1 bytes in %2 chunks; a six-byte escape starts at %3 and is cut by the %4-byte seam, and the document still parsed after reassembly", _bytes, _n, _at, PYSQF_CHUNK]]
}];

/* ---------------------------------------------------------- types ----- */

/*  What the JSON type mapping does to each type, including the places it
    cannot be faithful. Those are OBSERVATIONS, not failures: SQF numbers are
    32-bit floats and no amount of red in this log will change that. The job is
    to make the loss visible and quantified at a moment when someone is
    looking, so the decision to carry an id as a string is made on purpose.

    row: key, expected typeName ("<any>" to skip), expected value ("<any>" to
    skip), mode ("" assert | "approx" float compare | "note" observe only)  */
private _shapeFields = [
    ["int_small",       "SCALAR",  42,            ""],
    ["int_negative",    "SCALAR",  -7,            ""],
    ["zero",            "SCALAR",  0,             ""],
    ["float_tenth",     "SCALAR",  0.1,           "approx"],
    ["float_large",     "SCALAR",  "<any>",       "note"],
    // The control for the row below it: 2^24 is the last integer a 32-bit
    // float still holds exactly, so this one must be EXACT. If both it and the
    // edge come back wrong the fault is the transport; if only the edge does,
    // the fault is arithmetic and no protocol work will fix it.
    ["int_24bit_control", "SCALAR", 16777216,     ""],
    ["int_24bit_edge",  "SCALAR",  16777217,      "note"],
    ["int_53bit_edge",  "SCALAR",  "<any>",       "note"],
    ["bool_true",       "BOOL",    true,          ""],
    ["bool_false",      "BOOL",    false,         ""],
    ["string_empty",    "STRING",  "",            ""],
    ["string_numeric",  "STRING",  "12345678.91", ""],
    ["string_digits",   "STRING",  "0123",        ""],
    ["array_empty",     "ARRAY",   [],            ""],
    ["array_mixed",     "ARRAY",   "<any>",       ""],
    ["object_empty",    "HASHMAP", "<any>",       ""],
    ["object_nested",   "HASHMAP", "<any>",       ""],
    ["null_value",      "<any>",   "<any>",       "note"]
];

private _caseShape = {
    _arg params [["_key", "", [""]], ["_type", "", [""]], ["_expect", "<any>"], ["_mode", "", [""]]];
    ([ "shapes", "diag.shapes", [], 20 ] call _memo) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["diag.shapes is unavailable (%1): %2", _tag, [_payload] call _clip]] };
    if !(_payload isEqualType createHashMap) exitWith { [false, format ["diag.shapes returned a %1, expected an object", typeName _payload]] };

    private _present = _key in (keys _payload);
    // PYSQF_MISSING rather than nil: a JSON null may well leave the key present with
    // no value, and every way of handling a nil here is a way this file could
    // throw. The sentinel makes "absent" a value like any other.
    private _v = _payload getOrDefault [_key, PYSQF_MISSING];

    // An ABSENT key is a failure in every mode, including "note". The note
    // modes exist for a value that arrived and arrived lossily — that is a fact
    // about 32-bit floats, and calling it a failure would train the reader to
    // ignore red. A key that never arrived is a different thing entirely: the
    // fixture disagrees with this contract, and reporting it as an observation
    // meant the log could say "key 'int_24bit_edge' is absent" and "conformant"
    // in the same run, with the precision demonstration the group exists for
    // never having been made.
    if (!_present) exitWith {
        [false, format ["key '%1' is absent from the object — the fixture does not carry it, so this case tested nothing. Keys present: %2", _key, keys _payload]]
    };

    if (_mode isEqualTo "note") exitWith {
        // Observation. Report exactly what arrived and, where it is knowable,
        // how much was lost — the number is the useful part.
        if (_v isEqualTo PYSQF_MISSING) exitWith { [true, format ["key '%1' is present but carries no value on this side — a JSON null does not survive as a value inside a container, so a caller must test the KEY, not the value", _key], "note"] };
        private _extra = "";
        if (_expect isEqualType 0 && {_v isEqualType 0} && {_v != _expect}) then {
            _extra = format [" — asked for %1, arrived as %2, difference %3. SQF numbers are 32-bit floats: carry ids and money as strings, never as JSON numbers.", _expect, _v, _expect - _v];
        };
        [true, format ["%1 = %2 (%3)%4", _key, [_v] call _clip, typeName _v, _extra], "note"]
    };

    // Absence was handled above; this is the key that is PRESENT and carries no
    // value — a JSON null. For an asserting row that is a failure, because the
    // row named a type and a value that never arrived.
    if (_v isEqualTo PYSQF_MISSING) exitWith { [false, format ["key '%1' is present but carries no value on this side; the row expects %2. A JSON null does not survive as a value inside an SQF container.", _key, _type]] };
    if (_type isNotEqualTo "<any>" && {typeName _v isNotEqualTo _type}) exitWith {
        [false, format ["%1 arrived as %2, expected %3 (value %4)", _key, typeName _v, _type, [_v] call _clip]]
    };
    if (_expect isEqualTo "<any>") exitWith { [true, format ["%1 = %2 (%3)", _key, [_v] call _clip, typeName _v]] };
    if (_mode isEqualTo "approx") exitWith {
        if (!(_v isEqualType 0)) exitWith { [false, format ["%1 is not a number", _key]] };
        if (abs (_v - _expect) > 1e-6) exitWith { [false, format ["%1 = %2, expected about %3", _key, _v, _expect]] };
        [true, format ["%1 = %2", _key, _v]]
    };
    if (_v isNotEqualTo _expect) exitWith { [false, format ["%1 = %2, expected %3", _key, [_v] call _clip, [_expect] call _clip]] };
    [true, format ["%1 = %2 (%3)", _key, [_v] call _clip, typeName _v]]
};

{ _cases pushBack ["types", format ["shapes.%1", _x select 0], _caseShape, _x]; } forEach _shapeFields;

_cases pushBack ["types", "an exact decimal string is destroyed by parseNumber", {
    // Not a defect anywhere in PySQF — the point is the opposite. It is why
    // `numeric` crosses as a string, and it belongs in the log next to the
    // cases that assert the string, so the next person to reach for
    // parseNumber on a balance has already read what it costs.
    private _exact  = "12345678.91";
    private _parsed = parseNumber _exact;
    private _back   = str _parsed;
    if (_back isEqualTo _exact) exitWith { [true, format ["this engine round-trips %1 through parseNumber intact, which is not what 32-bit floats normally do — check the assumption before relying on it", _exact], "note"] };
    [true, format ["%1 parses to %2 and prints back as '%3' — the cents are gone. Keep money as the string the encoder sends.", _exact, _parsed, _back], "note"]
}];

/* --------------------------------------------------------- errors ----- */

_cases pushBack ["errors", "a Python exception arrives as a failure with its message", {
    ([ "diag.boom", [], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isEqualTo "ok") exitWith {
        [false, format ["a deliberately failing call reported SUCCESS with payload %1. Failure and emptiness are being conflated — the one defect this subsystem exists to avoid.", [_payload] call _clip], "critical"]
    };
    if (_tag isNotEqualTo "err") exitWith { [false, format ["expected err, got '%1': %2", _tag, [_payload] call _clip]] };
    if !(_payload isEqualType "") exitWith { [false, format ["the failure came back as a %1, not a message", typeName _payload]] };
    if ((count _payload) < 1) exitWith { [false, "the failure arrived with an empty message — correct in kind, useless in practice"] };
    if ((_payload find "RuntimeError") < 0) exitWith { [true, format ["failed as expected, but the message does not name the exception type: %1", [_payload] call _clip], "note"] };
    [true, [_payload] call _clip]
}];

_cases pushBack ["errors", "an unknown function name arrives as a failure, not a hang", {
    ([ "nosuchmodule.nosuchfunction", [], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isEqualTo "ok") exitWith { [false, format ["calling a function that does not exist SUCCEEDED: %1", [_payload] call _clip], "critical"] };
    if (_tag isEqualTo "timeout") exitWith { [false, "an unknown function left the ticket pending until the deadline — an unresolvable name must fail immediately"] };
    if (_tag isNotEqualTo "err") exitWith { [false, format ["expected err, got '%1': %2", _tag, [_payload] call _clip]] };
    [true, [_payload] call _clip]
}];

_cases pushBack ["errors", "malformed args JSON arrives as a failure", {
    // Deliberately below APS_fnc_pysqfCall, which builds the JSON with toJSON
    // and so can never produce this. The C core does not parse the payload
    // either (PROTOCOL §6), so the only place this can be caught is Python —
    // and it must be caught as a value.
    private _r = ["call", ["diag.echo", "{not json at all"]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "ok") exitWith { [true, format ["refused at the call verb: %1", _r param [1, "", [""]]]] };
    private _ticket = _r param [1, "", [""]];
    ([_ticket, 15] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if (_tg isEqualTo "ok") exitWith { [false, "malformed args JSON produced a SUCCESSFUL result", "critical"] };
    if (_tg isNotEqualTo "err") exitWith { [false, format ["expected err, got '%1': %2", _tg, [_msg] call _clip]] };
    [true, [_msg] call _clip]
}];

_cases pushBack ["errors", "args JSON that is a bare scalar is refused", {
    // "42" is valid JSON and an invalid argument list. Guessing that it means
    // one positional argument is the kind of guess that produces a wrong call
    // instead of a clear error.
    private _r = ["call", ["diag.echo", "42"]] call APS_fnc_pysqfRaw;
    if ((_r param [0, "", [""]]) isNotEqualTo "ok") exitWith { [true, format ["refused at the call verb: %1", _r param [1, "", [""]]]] };
    private _ticket = _r param [1, "", [""]];
    ([_ticket, 15] call _await) params ["_tg", "_n", "_bytes", "_msg"];
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    if (_tg isEqualTo "ok") exitWith { [false, "a bare scalar was accepted as an argument list"] };
    [true, [_msg] call _clip]
}];

_cases pushBack ["errors", "the wrong number of arguments arrives as a failure", {
    ([ "diag.ping", [1, 2, 3], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isEqualTo "ok") exitWith { [false, format ["diag.ping accepted three arguments it does not take: %1", [_payload] call _clip]] };
    if (_tag isNotEqualTo "err") exitWith { [false, format ["expected err, got '%1': %2", _tag, [_payload] call _clip]] };
    [true, [_payload] call _clip]
}];

_cases pushBack ["errors", "the ergonomic wrapper reports the same failure as [false, msg]", {
    // The two conventions again: whatever the raw layer calls it, mission code
    // sees a Bool, and that Bool must be false.
    private _r = ["diag.boom", [], 10] call APS_fnc_pysqfCall;
    _r params [["_ok", true, [false]], ["_msg", ""]];
    if (_ok) exitWith { [false, "APS_fnc_pysqfCall reported ok=true for a call that raised", "critical"] };
    if !(_msg isEqualType "") exitWith { [false, format ["the failure came back as a %1, not a message", typeName _msg]] };
    if (_msg isEqualTo "") exitWith { [false, "ok=false with an empty message"] };
    [true, [_msg] call _clip]
}];

/* ---------------------------------------------------------- empty ----- */

_cases pushBack ["empty", "a call that returns nothing is a SUCCESS carrying nothing", {
    ([ "diag.nothing", [], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith {
        [false, format ["a function that returns None came back as '%1': %2. Returning nothing is not failing.", _tag, [_payload] call _clip], "critical"]
    };
    if (_n < 1) exitWith { [false, format ["ok with %1 chunks — PROTOCOL §2 says at least one", _n], "critical"] };
    // The byte count is the only proof of WHAT crossed. The client normalises
    // the document `null` to [], so the decoded value is indistinguishable from
    // an empty array and `_n >= 1` alone would pass for any document at all.
    // `null` is four bytes in one chunk, which is exactly what the fixture's
    // docstring pins, so the two together say the shortest legal document was
    // the thing that made the trip.
    if (_n != 1 || {_bytes != 4}) exitWith {
        [false, format ["a function returning None produced %1 chunk(s) and %2 bytes; the document `null` is 4 bytes in 1 chunk. Something other than null crossed, and the decoded value cannot tell you what — it normalises to [] either way.", _n, _bytes]]
    };
    [true, format ["ok, %1 chunk, %2 bytes (the document `null`), decoded as %3 (%4)", _n, _bytes, [_payload] call _clip, typeName _payload]]
}];

_cases pushBack ["empty", "nothing and failure are not the same answer", {
    // THE founding requirement. If this fails, nothing else in this log means
    // anything: every caller downstream decides what happened by looking at
    // exactly this distinction, and they will all decide wrong in the same
    // direction, quietly, for weeks.
    private _a = ["diag.nothing", [], 10] call APS_fnc_pysqfCall;
    private _b = ["diag.boom",    [], 10] call APS_fnc_pysqfCall;
    _a params [["_aOk", false, [false]], ["_aVal", ""]];
    _b params [["_bOk", true,  [false]], ["_bVal", ""]];
    if (_aOk isEqualTo _bOk) exitWith {
        [false, format ["returning nothing and raising both report ok=%1. 'The database is down' and 'that player has no vehicles' are now the same code path — do not trust any other result from this subsystem.", _aOk], "critical"]
    };
    if (!_aOk) exitWith { [false, "diag.nothing reported ok=false; emptiness is being reported as failure", "critical"] };
    if (_bOk) exitWith { [false, "diag.boom reported ok=true; failure is being reported as emptiness", "critical"] };
    [true, format ["nothing -> [true, %1]; failure -> [false, %2]", [_aVal] call _clip, [_bVal] call _clip]]
}];

_cases pushBack ["empty", "an empty container is not nothing either", {
    // [] is a third answer: the call worked and the answer is empty. It must
    // not collapse into either of the other two.
    ([ "diag.echo", [[]], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    if !(_payload isEqualType createHashMap) exitWith { [false, format ["expected an object, got %1", typeName _payload]] };
    if !("echo" in (keys _payload)) exitWith { [false, format ["the 'echo' key is missing entirely: %1", keys _payload]] };
    private _v = _payload getOrDefault ["echo", "<nil>"];
    if !(_v isEqualType []) exitWith { [false, format ["an empty array came back as a %1: %2", typeName _v, [_v] call _clip]] };
    if (count _v != 0) exitWith { [false, format ["an empty array came back with %1 elements", count _v]] };
    [true, "an empty array round-trips as an empty array, with the key present"]
}];

/* ---------------------------------------------------- concurrency ----- */

_cases pushBack ["concurrency", "several tickets in flight each resolve to their OWN result", {
    // Cross-talk in the result store is silent data corruption: two callers
    // both get a plausible answer and one of them is somebody else's. It is
    // invisible to every test that only ever has one call outstanding, which
    // is every test above this line.
    private _n = 8;
    private _pend = [];
    for "_i" from 0 to (_n - 1) do {
        private _marker = format ["conform-marker-%1-%2", _i, round (random 100000)];
        ([ "diag.echo", [_marker] ] call _dispatch) params ["_ticket", "_derr"];
        _pend pushBack [_ticket, _marker, _derr];
    };

    private _bad = [];
    private _seen = [];
    {
        _x params ["_ticket", "_marker", "_derr"];
        if (_ticket isEqualTo "") then { _bad pushBack format ["dispatch %1 refused: %2", _forEachIndex, _derr]; }
        else {
            if (_ticket in _seen) then { _bad pushBack format ["ticket %1 was issued twice", _ticket]; };
            _seen pushBack _ticket;
            ([_ticket, 20] call _await) params ["_tg", "_nc", "_bytes", "_msg"];
            if (_tg isNotEqualTo "ok") then { _bad pushBack format ["ticket %1 (%2): %3 %4", _ticket, _marker, _tg, _msg]; }
            else {
                private _f = ["fetch", [_ticket, _nc]] call APS_fnc_pysqfRaw;
                if ((_f param [0, "err", [""]]) isNotEqualTo "ok") then { _bad pushBack format ["ticket %1: %2", _ticket, _f param [1, "", [""]]]; }
                else {
                    private _v = _f param [1, []];
                    private _got = if (_v isEqualType createHashMap) then { _v getOrDefault ["echo", "<no echo field>"] } else { format ["<%1>", typeName _v] };
                    if (_got isNotEqualTo _marker) then {
                        _bad pushBack format ["ticket %1 asked for '%2' and received '%3'", _ticket, _marker, [_got] call _clip];
                    };
                };
            };
            ["free", [_ticket]] call APS_fnc_pysqfRaw;
        };
    } forEach _pend;

    if (count _bad > 0) exitWith {
        // Any mismatch here is a result store handing one ticket's bytes to
        // another. Nothing downstream can defend against that.
        private _crosstalk = (_bad findIf {(_x find "received") >= 0}) >= 0;
        [false, _bad joinString "; ", if (_crosstalk) then {"critical"} else {""}]
    };
    [true, format ["%1 tickets in flight, each returned its own payload", _n]]
}];

_cases pushBack ["concurrency", "a slow call does not block a fast one", {
    private _t0 = diag_tickTime;
    ([ "diag.slow", [3] ] call _dispatch) params ["_slowT", "_slowE"];
    ([ "diag.ping", []  ] call _dispatch) params ["_fastT", "_fastE"];
    if (_slowT isEqualTo "" || {_fastT isEqualTo ""}) exitWith { [false, format ["dispatch refused: %1 / %2", _slowE, _fastE]] };

    ([_fastT, 2] call _await) params ["_fTag", "_fN", "_fBytes", "_fMsg"];
    private _fastAt = diag_tickTime - _t0;
    private _slowState = (["poll", [_slowT]] call APS_fnc_pysqfRaw) param [0, "", [""]];

    ["free", [_fastT]] call APS_fnc_pysqfRaw;
    ["free", [_slowT]] call APS_fnc_pysqfRaw;

    if (_fTag isNotEqualTo "ok") exitWith {
        [false, format ["the fast call did not finish while a 3s call was running (%1: %2). The backend is serialising work — check the daemon's worker count.", _fTag, [_fMsg] call _clip]]
    };
    if (_slowState isNotEqualTo "pending") exitWith {
        [true, format ["the fast call finished in %1s, but the slow one was already '%2' — the two did not actually overlap, so this proves less than it looks", _fastAt toFixed 3, _slowState], "note"]
    };
    [true, format ["the fast call finished in %1s while the 3s call was still pending", _fastAt toFixed 3]]
}];

_cases pushBack ["concurrency", "a client timeout arrives as a timeout, not a hang", {
    // callExtension cannot hang, but a backend that never completes a ticket
    // can leave a waitUntil spinning forever and SQF has no timeout of its
    // own. A wedged backend must surface as an error with a deadline on it.
    private _t0 = diag_tickTime;
    private _r  = ["diag.slow", [6], 1] call APS_fnc_pysqfCall;
    private _dt = diag_tickTime - _t0;
    _r params [["_ok", true, [false]], ["_msg", ""]];
    if (_ok) exitWith { [false, format ["a 6s call with a 1s deadline reported success after %1s", _dt toFixed 2]] };
    if (_dt > 4) exitWith { [false, format ["the 1s deadline took %1s to fire — the wait is not bounded by the timeout", _dt toFixed 2]] };
    if !(_msg isEqualType "") exitWith { [false, format ["the timeout came back as a %1", typeName _msg]] };
    if ((_msg find "timed out") < 0) exitWith { [true, format ["failed within %1s, but the message does not say it was a timeout: %2", _dt toFixed 2, [_msg] call _clip], "note"] };
    [true, format ["%1s: %2", _dt toFixed 2, [_msg] call _clip]]
}];

_cases pushBack ["concurrency", "a call from an unscheduled context is refused, not busy-waited", {
    // waitUntil in an unscheduled context spins inside one frame and starves
    // the whole VM until the extension answers. This codebase has shipped that
    // mistake before, which is why the client refuses rather than degrades.
    // An EachFrame handler is the cheapest genuinely unscheduled context here.
    // The 2s timeout is not decoration: if the guard is broken, that handler
    // polls inside a single frame for the whole of it and the server stops
    // dead. Two seconds is enough to see, short enough to survive.
    missionNamespace setVariable ["APS_pysqfConform_unsched", "waiting"];
    addMissionEventHandler ["EachFrame", {
        // Remove FIRST, then probe. With the removal last, a throw inside
        // APS_fnc_pysqfCall — the function under test, and the reason this case
        // exists — skips it, and the handler re-runs the probe every frame for
        // the rest of the mission. The throw would also escape _runOne's catch
        // (different execution context), so the case would report "the probe
        // never ran" and the real fault would be a permanent per-frame leak
        // nobody attributed to this file.
        removeMissionEventHandler ["EachFrame", _thisEventHandler];
        // A String in element 0 marks "it threw" — the two return conventions
        // both put a Bool or a tag there, so the case can tell a refusal
        // (what must happen) from an exception (a different bug) without
        // either one being reported as the other.
        private _v = ["threw", "the probe never reached its own try block"];
        try {
            _v = ["diag.ping", [], 2] call APS_fnc_pysqfCall;
        } catch {
            _v = ["threw", format ["%1", _exception]];
        };
        missionNamespace setVariable ["APS_pysqfConform_unsched", _v];
    }];
    private _deadline = diag_tickTime + 8;
    // A plain loop, not waitUntil: suspending inside a waitUntil condition is
    // illegal, and this is the file that must not throw.
    while { ((missionNamespace getVariable ["APS_pysqfConform_unsched", ""]) isEqualTo "waiting") && {diag_tickTime < _deadline} } do { uiSleep 0.05; };
    private _r = missionNamespace getVariable ["APS_pysqfConform_unsched", ""];
    missionNamespace setVariable ["APS_pysqfConform_unsched", nil];
    if (_r isEqualTo "waiting") exitWith { [false, "the unscheduled probe never ran (no frame in 8s?) — the guard is untested"] };
    if !(_r isEqualType []) exitWith { [false, format ["the unscheduled call returned a %1", typeName _r]] };
    if ((_r param [0, false]) isEqualType "") exitWith {
        [false, format ["the unscheduled call THREW rather than refusing: %1. It must return [false, <reason>] — a throw from an EachFrame handler is caught by nothing and would be attributed to whatever ran next.", [_r param [1, "", [""]]] call _clip]]
    };
    _r params [["_ok", true, [false]], ["_msg", ""]];
    if (_ok) exitWith { [false, "APS_fnc_pysqfCall ran to completion from an unscheduled context — it must refuse, or it will busy-wait inside one frame"] };
    [true, [_msg] call _clip]
}];

/* ------------------------------------------------------------- db ----- */

/*  The behaviours anything moving real data onto PostgreSQL depends on. Every
    statement here is a cast or a `where false`: no table is named, nothing is
    written, and the suite is safe to run against a live database.

    If the database is not configured on this box the whole group is skipped
    with the reason printed once. A red db group on a machine with no DSN would
    train the reader to ignore red.  */

_cases pushBack ["db", "a parameterised query binds its values", {
    ([ "db.query", ["select %s::int as n, %s::text as t", [7, "seven"]], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    if !(_payload isEqualType []) exitWith { [false, format ["expected an array of rows, got %1", typeName _payload]] };
    if (count _payload != 1) exitWith { [false, format ["expected 1 row, got %1", count _payload]] };
    private _row = _payload select 0;
    if !(_row isEqualType createHashMap) exitWith { [false, format ["a row came back as %1, expected an object", typeName _row]] };
    if ((_row getOrDefault ["n", -1]) isNotEqualTo 7) exitWith { [false, format ["n = %1, expected 7", _row getOrDefault ["n", "<missing>"]]] };
    if ((_row getOrDefault ["t", ""]) isNotEqualTo "seven") exitWith { [false, format ["t = %1, expected 'seven'", _row getOrDefault ["t", "<missing>"]]] };
    [true, "both parameters bound and returned"]
}];

_cases pushBack ["db", "an exact decimal arrives as a STRING, not a float", {
    // The money rule. A balance that round-trips through an IEEE double is a
    // balance that eventually disagrees with itself, and the disagreement
    // surfaces as a player complaint months later with no way to reconstruct
    // which side rounded.
    ([ "db.query", ["select 12345678.91::numeric as amount", []], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    if (count _payload != 1) exitWith { [false, format ["expected 1 row, got %1", count _payload]] };
    private _v = (_payload select 0) getOrDefault ["amount", PYSQF_MISSING];
    if (_v isEqualTo PYSQF_MISSING) exitWith { [false, "no 'amount' column in the row"] };
    if (_v isEqualType 0) exitWith {
        [false, format ["numeric arrived as the SQF number %1. It passed through a float somewhere between PostgreSQL and here, and the cents are no longer trustworthy.", _v], "critical"]
    };
    if !(_v isEqualType "") exitWith { [false, format ["numeric arrived as a %1", typeName _v]] };
    if (_v isNotEqualTo "12345678.91") exitWith { [false, format ["numeric arrived as the string '%1', expected '12345678.91' exactly", _v]] };
    [true, "'12345678.91' — exact digits, as a string"]
}];

_cases pushBack ["db", "NULL is distinguishable from a missing column and from zero", {
    ([ "db.query", ["select null::text as a, 0 as b, '' as c", []], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    if (count _payload != 1) exitWith { [false, format ["expected 1 row, got %1", count _payload]] };
    private _row = _payload select 0;
    private _ks  = keys _row;
    if (!("b" in _ks) || {!("c" in _ks)}) exitWith { [false, format ["columns went missing: %1", _ks]] };
    if ((_row getOrDefault ["b", -1]) isNotEqualTo 0)  exitWith { [false, format ["b = %1, expected 0", _row getOrDefault ["b", "<missing>"]]] };
    if ((_row getOrDefault ["c", "x"]) isNotEqualTo "") exitWith { [false, format ["c = %1, expected an empty string", _row getOrDefault ["c", "<missing>"]]] };
    private _aPresent = "a" in _ks;
    private _aNil     = isNil { _row get "a" };
    // How a NULL presents on this side is a fact to record, not a rule to
    // enforce — but a caller must be able to tell it from 0 and from "", and
    // the assertions above are what prove that.
    [true, format ["NULL: key present = %1, value nil = %2. 0 and '' both survived as themselves, so NULL is distinguishable from either.", _aPresent, _aNil], "note"]
}];

_cases pushBack ["db", "an empty result set is a success, not an error", {
    private _r = ["db.query", ["select 1 as n where false", []], 15] call APS_fnc_pysqfCall;
    _r params [["_ok", false, [false]], ["_rows", ""]];
    if (!_ok) exitWith { [false, format ["a query matching no rows reported failure: %1. That is the conflation this project exists to avoid, one layer down.", [_rows] call _clip], "critical"] };
    if !(_rows isEqualType []) exitWith { [false, format ["expected an array, got %1", typeName _rows]] };
    if (count _rows != 0) exitWith { [false, format ["expected 0 rows, got %1", count _rows]] };
    [true, "[true, []] — no rows, and the call worked"]
}];

_cases pushBack ["db", "no rows and a broken query are different answers", {
    // Both of these used to return [] under the blocking helper this replaces,
    // and every caller downstream guessed the same wrong way.
    private _empty = ["db.query", ["select 1 as n where false", []], 15] call APS_fnc_pysqfCall;
    private _broke = ["db.query", ["select * from pysqf_conform_no_such_table_9x7", []], 15] call APS_fnc_pysqfCall;
    _empty params [["_eOk", false, [false]], ["_eVal", ""]];
    _broke params [["_bOk", true,  [false]], ["_bVal", ""]];
    if (_eOk isEqualTo _bOk) exitWith {
        [false, format ["an empty result and a broken query both report ok=%1 — indistinguishable at the SQF layer", _eOk], "critical"]
    };
    if (_bOk) exitWith { [false, "a query against a table that does not exist reported SUCCESS", "critical"] };
    if (_bVal isEqualTo "") exitWith { [false, "the database error arrived with no message"] };
    [true, format ["empty -> [true, []]; broken -> [false, %1]", [_bVal] call _clip]]
}];

_cases pushBack ["db", "an injection attempt is inert", {
    // A game server takes strings from players. This is the boundary where
    // that stops being dangerous, and the proof is that the payload comes back
    // as data, character for character, having done nothing.
    private _evil = "'; drop table players; -- \ ""x"" %s";
    ([ "db.query", ["select %s::text as v", [_evil]], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    if (count _payload != 1) exitWith { [false, format ["expected 1 row, got %1", count _payload]] };
    private _v = (_payload select 0) getOrDefault ["v", PYSQF_MISSING];
    if (_v isEqualTo PYSQF_MISSING) exitWith { [false, "no 'v' column"] };
    if (_v isNotEqualTo _evil) exitWith {
        private _at = [_evil, if (_v isEqualType "") then {_v} else {str _v}] call _firstDiff;
        [false, format ["the payload came back altered at character %1: %2", _at, [_v] call _clip]]
    };
    [true, format ["%1 characters returned as data, unexecuted", count _evil]]
}];

_cases pushBack ["db", "an apostrophe survives the round trip", {
    ([ "db.query", ["select %s::text as v", ["O'Brien's ''table''"]], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    private _v = (_payload param [0, createHashMap]) getOrDefault ["v", PYSQF_MISSING];
    if (_v isEqualTo PYSQF_MISSING) exitWith { [false, "no 'v' column"] };
    if (_v isNotEqualTo "O'Brien's ''table''") exitWith { [false, format ["came back as %1", [_v] call _clip]] };
    [true, "unchanged"]
}];

_cases pushBack ["db", "already-interpolated SQL is refused, not run", {
    // The rule that makes the one above hold: values reach PostgreSQL as bound
    // parameters or they do not reach it at all. A caller who built the string
    // must get an error, or the rule survives only as long as everyone
    // remembers it.
    ([ "db.query", ["select 1 as n", ["a value with no placeholder"]], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isEqualTo "ok") exitWith { [false, "params were supplied for a statement with no placeholders and the query ran anyway"] };
    if (_tag isNotEqualTo "err") exitWith { [false, format ["expected err, got '%1': %2", _tag, [_payload] call _clip]] };
    [true, [_payload] call _clip]
}];

_cases pushBack ["db", "two statements in one call are refused", {
    ([ "db.query", ["select 1 as n; select 2 as n", []], 15 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isEqualTo "ok") exitWith { [false, "a two-statement string was executed by db.query"] };
    if (_tag isNotEqualTo "err") exitWith { [false, format ["expected err, got '%1': %2", _tag, [_payload] call _clip]] };
    [true, [_payload] call _clip]
}];

_cases pushBack ["db", "a large result set crosses the wire whole", {
    // The chunk path with real rows rather than a synthetic payload: 400 rows
    // is comfortably several chunks, and generate_series needs no table.
    ([ "db.query", ["select g as n, repeat('x', 40) as pad from generate_series(1, %s) g", [400]], 25 ] call _probe) params ["_tag", "_n", "_bytes", "_payload"];
    if (_tag isNotEqualTo "ok") exitWith { [false, format ["%1: %2", _tag, [_payload] call _clip]] };
    if !(_payload isEqualType []) exitWith { [false, format ["expected an array, got %1", typeName _payload]] };
    if (count _payload != 400) exitWith { [false, format ["expected 400 rows, got %1", count _payload]] };
    private _first = (_payload select 0) getOrDefault ["n", -1];
    private _last  = (_payload select 399) getOrDefault ["n", -1];
    if (_first isNotEqualTo 1 || {_last isNotEqualTo 400}) exitWith { [false, format ["rows are out of order or incomplete: first %1, last %2", _first, _last]] };
    if (_n < 2) exitWith { [true, format ["400 rows, %1 bytes, but only %2 chunk — this did not exercise reassembly", _bytes, _n], "note"] };
    [true, format ["400 rows, %1 bytes, %2 chunks, first and last row intact", _bytes, _n]]
}];

/* -------------------------------------------------------- hygiene ----- */

_cases pushBack ["hygiene", "the suite leaked no tickets and the core refused nothing", {
    // A ticket never freed is a leak, and the only symptom is a rising
    // eviction count long after the code that leaked it ran. This suite issues
    // a few hundred, so it is the right place to notice.
    private _r = ["stats", []] call APS_fnc_pysqfRaw;
    if ((_r param [0, "err", [""]]) isNotEqualTo "ok") exitWith { [false, format ["stats returned %1", _r]] };
    private _j = fromJSON (_r param [1, "", [""]]);
    if (isNil "_j" || {!(_j isEqualType createHashMap)}) exitWith { [false, "the stats payload is not a JSON object"] };
    private _s = _j getOrDefault ["store", PYSQF_MISSING];
    if !(_s isEqualType createHashMap) exitWith { [false, "stats has no 'store' object"] };

    private _issued  = _s getOrDefault ["issued", 0];
    private _freed   = _s getOrDefault ["freed", 0];
    private _used    = _s getOrDefault ["slots_used", 0];
    private _pending = _s getOrDefault ["pending", 0];
    private _refused = _s getOrDefault ["refused", 0];
    private _oom     = _s getOrDefault ["oom", 0];
    private _evictC  = _s getOrDefault ["evicted_complete", 0];
    private _uncarr  = _s getOrDefault ["uncarriable", 0];
    private _late    = _s getOrDefault ["dropped_late", 0];

    private _problems = [];
    if (_refused > 0) then { _problems pushBack format ["the core refused %1 call(s) for want of a ticket slot", _refused]; };
    if (_oom > 0)     then { _problems pushBack format ["%1 result(s) could not be allocated", _oom]; };
    if (_evictC > 0)  then { _problems pushBack format ["%1 completed ticket(s) were evicted unfreed — something is leaking", _evictC]; };
    // slots_used > 0 is normal at this instant: the timeout case deliberately
    // leaves work running, and its result is dropped when it lands.
    if (count _problems > 0) exitWith { [false, _problems joinString "; "] };
    [true, format ["issued %1, freed %2, still held %3 (%4 pending), uncarriable %5, dropped-late %6", _issued, _freed, _used, _pending, _uncarr, _late], "note"]
}];

/* ====================================================================== *
 *  Preconditions that skip a whole group
 *
 *  A group that cannot possibly pass on this box is SKIPPED with the reason
 *  printed once. Printing fifteen identical database failures on a machine
 *  with no DSN teaches the reader to scroll past red, which is the one habit
 *  a conformance suite must not create.
 * ====================================================================== */

private _skipGroups = createHashMap;

/*  This block is the one place in the file that runs OUTSIDE a case, so it is
    the one place a throw would kill the whole run — before a single case had
    executed and before any summary was printed, which is precisely the failure
    the rest of the file is built to prevent. Hence the guard around a
    precondition, which looks like belt and braces and is not.

    Two probes, not one, because "no database is configured on this box" and
    "the database is configured and down" are different facts and only the
    first is a reason to shrug. diagdb.ready answers the first without touching
    a socket; db.ping answers the second. An older daemon without diagdb simply
    errs on the first probe and falls through to the second, which is why the
    fall-through is not treated as an answer.  */
if (_filter isEqualTo [] || {"db" in _filter}) then {
    private _why = "";
    try {
        private _ready = ["diagdb.ready", [], 10] call APS_fnc_pysqfCall;
        _ready params [["_rOk", false, [false]], ["_rVal", ""]];
        if (_rOk && {_rVal isEqualType createHashMap}) then {
            // Type-filtered, and defaulting to "assume ready": an unreadable
            // answer here must fall through to db.ping, never skip the group.
            private _isReady = _rVal getOrDefault ["ready", true];
            if (_isReady isEqualType false && {!_isReady}) then {
                _why = "no DSN is configured on this box, so there is no database to be conformant with (diagdb.ready)";
            };
        };
        if (_why isEqualTo "") then {
            private _ping = ["db.ping", [], 15] call APS_fnc_pysqfCall;
            _ping params [["_pOk", false, [false]], ["_pMsg", ""]];
            if (!_pOk) then {
                _why = format ["a DSN is set but the database did not answer: %1", [_pMsg] call _clip];
            };
        };
    } catch {
        _why = format ["the database precondition itself threw: %1", _exception];
    };
    if (_why isNotEqualTo "") then { _skipGroups set ["db", _why]; };
};

/* ====================================================================== *
 *  The runner
 * ====================================================================== */

// [pass, fail, critical, note, skip]
private _totals = [0, 0, 0, 0, 0];
private _byGroup = createHashMap;
private _failLines = [];
private _critLines = [];
private _t0Suite = diag_tickTime;

private _bump = {
    params ["_group", "_slot"];
    _totals set [_slot, (_totals select _slot) + 1];
    private _g = _byGroup getOrDefault [_group, [0, 0, 0, 0, 0]];
    _g set [_slot, (_g select _slot) + 1];
    _byGroup set [_group, _g];
};

private _runOne = {
    params [["_row", [], [[]]]];
    _row params [["_group", "", [""]], ["_name", "", [""]], ["_body", {}, [{}]], ["_arg", [], [[]]]];

    private _skip = _skipGroups getOrDefault [_group, ""];
    if (_skip isNotEqualTo "") exitWith {
        [_group, 4] call _bump;
        diag_log format ["[pysqf-conform] SKIP %1/%2 — %3", _group, _name, _skip];
    };

    private _t0 = diag_tickTime;
    private _ok = false;
    private _detail = "the case body returned nothing";
    private _sev = "";

    // The rule this whole file is built around: a case may fail, but it may
    // not throw. An exception becomes THIS case's failure, with its text, so
    // it can never be attributed to the last case that printed PASS.
    try {
        private _r = call _body;
        if (isNil "_r") then { throw "the case body returned nil"; };
        if !(_r isEqualType []) then { throw format ["the case body returned a %1, expected [ok, detail]", typeName _r]; };
        _r params [["_rOk", false], ["_rDetail", ""], ["_rSev", "", [""]]];
        _ok     = _rOk isEqualType true && {_rOk};
        _detail = [_rDetail] call _clip;
        _sev    = toLowerANSI _rSev;
    } catch {
        _ok     = false;
        _detail = format ["threw: %1", _exception];
        _sev    = "";
    };

    private _ms = round ((diag_tickTime - _t0) * 1000);

    if (_ok) then {
        if (_sev isEqualTo "note") then {
            [_group, 3] call _bump;
            diag_log format ["[pysqf-conform] OBS  %1/%2 — %3 [%4ms]", _group, _name, _detail, _ms];
        } else {
            [_group, 0] call _bump;
            diag_log format ["[pysqf-conform] PASS %1/%2 — %3 [%4ms]", _group, _name, _detail, _ms];
        };
    } else {
        if (_sev isEqualTo "critical") then {
            [_group, 2] call _bump;
            _critLines pushBack format ["%1/%2 — %3", _group, _name, _detail];
            diag_log format ["[pysqf-conform] CRIT %1/%2 — %3 [%4ms]", _group, _name, _detail, _ms];
        } else {
            [_group, 1] call _bump;
            _failLines pushBack format ["%1/%2 — %3", _group, _name, _detail];
            diag_log format ["[pysqf-conform] FAIL %1/%2 — %3 [%4ms]", _group, _name, _detail, _ms];
        };
    };
};

private _ran = 0;
private _matched = 0;
{ if (_filter isEqualTo [] || {(toLowerANSI (_x param [0, "", [""]])) in _filter}) then { _matched = _matched + 1; }; } forEach _cases;
diag_log format ["[pysqf-conform] %1 case(s) selected of %2 defined", _matched, count _cases];

{
    private _row = _x;
    private _group = toLowerANSI (_row param [0, "", [""]]);
    if (_filter isEqualTo [] || {_group in _filter}) then {
        _ran = _ran + 1;
        [_row] call _runOne;
    };
} forEach _cases;

if (_ran isEqualTo 0) then {
    diag_log format ["[pysqf-conform] nothing ran: no group matched %1. Groups are verbs, tickets, chunks, content, types, errors, empty, concurrency, db, hygiene.", _filter];
};

{ missionNamespace setVariable ["APS_pysqfConform_memo_" + _x, nil]; } forEach _memoKeys;

/* ====================================================================== *
 *  Summary
 *
 *  The tail of the log has to be enough on its own: every failure is
 *  repeated here, so nobody has to scroll back through a thousand lines of
 *  a busy server's RPT to find the two that mattered.
 * ====================================================================== */

private _elapsed = diag_tickTime - _t0Suite;

diag_log "[pysqf-conform] ---------------------------------------------------------------";
diag_log format ["[pysqf-conform] summary — %1 case(s) in %2s", _ran, _elapsed toFixed 1];

{
    private _g = _y;
    _g params ["_p", "_f", "_c", "_o", "_s"];
    diag_log format ["[pysqf-conform]   %1: %2 passed, %3 failed, %4 critical, %5 observation(s), %6 skipped",
        _x, _p, _f, _c, _o, _s];
} forEach _byGroup;

_totals params ["_tp", "_tf", "_tc", "_to", "_ts"];
diag_log format ["[pysqf-conform] TOTAL: %1 passed, %2 failed, %3 CRITICAL, %4 observation(s), %5 skipped", _tp, _tf, _tc, _to, _ts];

if (_ts > 0) then {
    { diag_log format ["[pysqf-conform] skipped group '%1' — %2", _x, _y]; } forEach _skipGroups;
};

if (count _failLines > 0) then {
    diag_log "[pysqf-conform] failures, repeated:";
    { diag_log format ["[pysqf-conform]   FAIL %1", _x]; } forEach _failLines;
};

if (count _critLines > 0) then {
    // A critical failure is one of: failure and emptiness became the same
    // answer, one ticket received another's result, or money crossed as a
    // float. Each is silent in production and expensive to find later, so the
    // banner is deliberately impossible to scroll past.
    diag_log "[pysqf-conform] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
    diag_log "[pysqf-conform] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
    diag_log format ["[pysqf-conform] !!! %1 CRITICAL FAILURE(S). DO NOT PUT DATA THROUGH THIS.", count _critLines];
    { diag_log format ["[pysqf-conform] !!! %1", _x]; } forEach _critLines;
    diag_log "[pysqf-conform] !!! A critical here means a failure cannot be told from an empty";
    diag_log "[pysqf-conform] !!! success, a result cannot be told from someone else's, or an";
    diag_log "[pysqf-conform] !!! exact value cannot be told from a rounded one. Every one of";
    diag_log "[pysqf-conform] !!! those is silent in production. Fix before migrating anything.";
    diag_log "[pysqf-conform] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
    diag_log "[pysqf-conform] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
};

diag_log (
    if (_tc > 0) then { format ["[pysqf-conform] VERDICT: NOT CONFORMANT — %1 critical, %2 other failure(s).", _tc, _tf] } else {
        if (_tf > 0) then { format ["[pysqf-conform] VERDICT: %1 failure(s), none critical. Read the FAIL lines above.", _tf] } else {
            if (_ts > 0) then { format ["[pysqf-conform] VERDICT: conformant over what ran — %1 case(s) passed, %2 skipped, %3 observation(s).", _tp, _ts, _to] } else {
                format ["[pysqf-conform] VERDICT: conformant — %1 case(s) passed, %2 observation(s).", _tp, _to]
            }
        }
    }
);
diag_log "[pysqf-conform] ================================================================";

[_tp, _tf, _tc, _to, _ts]
