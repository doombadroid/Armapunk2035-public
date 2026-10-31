/*  VENDORED from the PySQF repo -- do not hand-edit.
    Re-vendor with scratchpad vendor_pysqf.py after pulling upstream.
    Renamed for this mission's convention: APS_ = owned by the server addon,
    which matters because the server compiles both CfgFunctions trees into
    missionNamespace and a shared name silently overwrites.
    Upstream name: fn_pysqfCall.sqf  */
// SPDX-License-Identifier: MIT
/*
    sqf/fn_pysqfCall.sqf   —   registered as  APS_fnc_pysqfCall

    PURPOSE
        The one function mission code should use. Runs a whole call to
        completion — dispatch, poll, reassemble, free — and answers with

            [true,  <result>]        it worked; <result> is the decoded value
            [false, "<message>"]     it did not; <message> says why

    WHY THIS EXISTS
        *** [false, "…"] and [true, []] are different answers and must stay
        different answers. ***

        The blocking query helper this replaces returned [] both when a query
        failed and when it matched no rows, so every caller downstream had to
        guess which had happened — and they all guessed the same wrong way, by
        testing `count _rows == 0`. "The database is down" and "that player has
        no vehicles" then take the same code path, and the bug surfaces days
        later as data quietly not appearing. Re-creating that conflation here
        would make the whole project pointless. Check element 0. Always.

        Two more failures this prevents:
        - An unscheduled busy-wait. `waitUntil` in an unscheduled context spins
          inside a single frame and starves the entire VM until the extension
          answers; this codebase has shipped that mistake before. So this
          function refuses to run unscheduled rather than degrade quietly.
        - An unbounded wait. `callExtension` cannot hang, but a backend that
          never completes a ticket can leave a `waitUntil` spinning forever, and
          SQF has no timeout of its own. Hence a deadline on every call: a
          wedged backend surfaces as an error, never as a stuck script.

    WHAT IT DOES
        [<fn>, <args>, <timeout>] call APS_fnc_pysqfCall

          _fn       "<module>.<func>", e.g. "db.query"
          _args     any SQF value; converted with toJSON at the boundary
          _timeout  seconds, real time. Default 10.

        e.g.  private _r = ["db.query", [_sql, _params]] call APS_fnc_pysqfCall;
              _r params ["_ok", "_rows"];
              if (!_ok) exitWith { diag_log format ["query failed: %1", _rows] };
              // here _rows is the rows, and [] honestly means no rows

        The ticket is freed on every path — success, backend error, timeout and
        malformed reply — because a ticket never freed is a leak that only shows
        up as a rising eviction count in `stats`.

    CONTEXT
        Scheduled only (spawn / execVM / a CBA-style scheduled call). It sleeps
        between polls, which is precisely why it cannot be called unscheduled.

    POLLING
        Backoff, not a fixed tick. Most calls answer almost immediately, so the
        first wait is short (10 ms) to keep those fast; it then widens by 1.7x
        up to 250 ms so a slow call costs a handful of polls per second instead
        of a hundred. uiSleep rather than sleep: uiSleep is real time, so time
        acceleration cannot stretch or squash the cadence relative to _timeout,
        which is also measured in real seconds (diag_tickTime).
*/

#define PYSQF_DEF_TIMEOUT   10
#define PYSQF_POLL_FIRST    0.01
#define PYSQF_POLL_MAX      0.25
#define PYSQF_POLL_GROWTH   1.7

params [
    ["_fn",      "", [""]],
    ["_args",    []],
    ["_timeout", -1, [0]]
];

if (_fn isEqualTo "") exitWith { [false, "pysqf: no function name given"] };

if (!canSuspend) exitWith {
    [false, format ["pysqf: '%1' was called from an unscheduled context — use spawn/execVM. Polling unscheduled would busy-wait and starve the VM.", _fn]]
};

if (_timeout <= 0) then {
    _timeout = PYSQF_DEF_TIMEOUT;   // AP: no pysqf_timeout global override (client-publishable) -- see vendor_pysqf.py PATCHES
};

// The boundary: SQF value -> JSON string. Past this line nothing but the Python
// end interprets the payload; the C core moves opaque bytes (PROTOCOL §3).
//
// The wrap is load-bearing, not tidiness. The engine hands each argument to the
// extension as a QUOTED string, so the C core strips one surrounding pair of
// quotes — and it cannot tell a quoted argument from a bare one that happens to
// start and end with a quote. `toJSON "hi"` is the document "hi", whose first
// and last bytes are quotes, so the core unquotes it to `hi`, which is not JSON
// and fails at the Python end with a baffling "Expecting value: line 1
// column 1". Worse is silent: `toJSON "[1,2]"` — a JSON *string* whose text
// looks like an array — unquotes to [1,2] and is dispatched as two positional
// arguments nobody asked for. Forcing a container here means _argsJson always
// begins with `[` or `{`, so the core's unquote is provably a no-op and the
// ambiguity cannot arise. A caller passing a single value gets it as one
// positional argument, which is what they meant anyway.
if !(typeName _args in ["ARRAY", "HASHMAP"]) then { _args = [_args] };

private _argsJson = toJSON _args;

// EXPONENT NOTATION. Arma's number type is a 32-bit float and toJSON prints large
// values the way the engine formats them: 1048570 becomes "1.04857e+06". That is
// valid JSON, so nothing here complains -- and Python then refuses it, because a
// parameter annotated int receives 1048570.0 and raises "must be an integer, got
// float". Measured against diag.raw(1048570) on 2026-08-15.
//
// Rewriting the notation is a repair, not a conversion: the value has ALREADY lost
// precision by being a float, and this only restores the digits the engine chose
// not to print. Anything past 2^24 was approximate before it arrived, which is a
// property of the caller's number, not something this layer can fix.
//
// Rebuilt by splice rather than a regex substitution: expanding an exponent needs
// arithmetic, which no replace pattern can do.
// SQF has NO backslash escaping in string literals, so "\\." here is not an
// escaped dot -- it is two literal backslashes followed by a wildcard, and the
// pattern therefore requires a "\\" that never appears in JSON. The fractional
// group can only ever match by being skipped, so the match starts AFTER the
// decimal point: given 1.78621e+09 it matches "78621e+09".
//
// The repair below then substitutes the full expansion of the number it parsed
// over that shorter span, so every exponent-notation value silently gains
// characters -- measured downstream as five per occurrence, which corrupted
// every record a caller wrote and made a byte-exact round trip impossible.
// One backslash is what expresses an escaped dot in an SQF string.
private _exp = _argsJson regexFind ["-?[0-9]+(\.[0-9]+)?[eE][+-]?[0-9]+", 0];
if (count _exp > 0) then {
    private _out = "";
    private _at = 0;
    {
        _x params ["_tok", "_pos"];
        private _n = parseNumber _tok;
        // only integral magnitudes are repaired; a genuine fraction stays as it is
        private _plain = if (_n isEqualTo (round _n) && { abs _n < 1e15 }) then { _n toFixed 0 } else { _tok };
        _out = _out + (_argsJson select [_at, _pos - _at]) + _plain;
        _at = _pos + count _tok;
    // `regexFind` returns, PER MATCH, an array of [text, position] pairs: element
    // 0 is the whole match and the rest are the capture groups. This pattern HAS
    // a group -- `(\.[0-9]+)?` for the fractional part -- so `_x select 0` is
    // itself the [text, pos] pair and `_x select 1` is the group's. Reading them
    // as if `_x` were the pair handed `parseNumber` an ARRAY and threw, which
    // killed the calling script.
    //
    // It stayed latent until a statement carrying exponent notation went through:
    // `DELETE FROM candidates WHERE started_at < 1.78621e+09`. That threw inside
    // the server's main init thread, so AP_server_isReady was never published and
    // every client hung at "waiting for server to be ready" -- a repair for a
    // number-formatting problem taking the whole server down.
    } forEach (_exp apply { _x select 0 });
    _argsJson = _out + (_argsJson select [_at]);
};;

/* ---- dispatch ---------------------------------------------------------- */

private _r = ["call", [_fn, _argsJson]] call APS_fnc_pysqfRaw;
// The [""] filter is not decoration. APS_fnc_pysqfRaw answers with a STRING tag
// ("ok" | "err" | "pending"); this function answers with a BOOL. Both are shaped
// [x, y] and nothing about the shape tells them apart, so a mix-up upstream
// would hand a Bool to a String comparison and be read as "not ok" — or, one
// operator over, throw. Filtered, a wrong type reads as "err" and fails here
// with a message instead of somewhere later without one.
if ((_r param [0, "err", [""]]) isNotEqualTo "ok") exitWith {
    // No ticket was issued, so there is nothing to free.
    [false, format ["pysqf: %1 was refused: %2", _fn, _r param [1, "no reason given"]]]
};

private _ticket = _r param [1, ""];
if (_ticket isEqualTo "") exitWith { [false, format ["pysqf: %1 accepted but no ticket returned", _fn]] };

/* ---- poll until complete, failed, or out of time ------------------------ */

private _deadline = diag_tickTime + _timeout;
private _wait     = PYSQF_POLL_FIRST;
private _polls    = 0;
private _nchunks  = 0;
private _err      = "";

while { true } do {
    private _p  = ["poll", [_ticket]] call APS_fnc_pysqfRaw;
    private _st = _p param [0, "err", [""]];
    _polls = _polls + 1;

    if (_st isEqualTo "ok") exitWith {
        // parseNumber accepts only String and Bool, so an unfiltered read here
        // would THROW on a core that ever reported the chunk count as a JSON
        // number — inside mission code, where nothing catches it. Filtered, it
        // degrades to 0 chunks and fails as a value two lines down.
        _nchunks = parseNumber (_p param [1, "0", [""]]);
    };
    if (_st isEqualTo "err") exitWith {
        _err = format ["pysqf: %1 failed: %2", _fn, _p param [1, "no reason given"]];
    };
    if (_st isNotEqualTo "pending") exitWith {
        _err = format ["pysqf: %1 got an unrecognised poll status '%2'", _fn, _st];
    };

    if (diag_tickTime > _deadline) exitWith {
        // Deliberately an error, not a longer wait. A wedged backend must be
        // visible to the caller; a hung ticket is worse than a failed one.
        _err = format ["pysqf: %1 timed out after %2s (%3 polls, ticket %4)", _fn, _timeout, _polls, _ticket];
    };

    uiSleep _wait;
    _wait = (_wait * PYSQF_POLL_GROWTH) min PYSQF_POLL_MAX;
};

/* ---- reassemble, then free on every path -------------------------------- */

if (_err isNotEqualTo "") exitWith {
    // Free even on the timeout path: the backend may still complete the ticket
    // later, and the core would otherwise hold the result until its TTL evicts
    // it. Free is idempotent (PROTOCOL §2), so this is safe regardless.
    ["free", [_ticket]] call APS_fnc_pysqfRaw;
    [false, _err]
};

private _f = ["fetch", [_ticket, _nchunks]] call APS_fnc_pysqfRaw;
["free", [_ticket]] call APS_fnc_pysqfRaw;

if ((_f param [0, "err", [""]]) isNotEqualTo "ok") exitWith {
    [false, format ["pysqf: %1 completed but could not be read: %2", _fn, _f param [1, "no reason given"]]]
};

// `param` substitutes the default for a nil element, so a JSON null that got
// this far still yields a real value rather than a hole in the array.
[true, (_f param [1, []])]
