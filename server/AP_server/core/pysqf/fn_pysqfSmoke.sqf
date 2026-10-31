/*  VENDORED from the PySQF repo -- do not hand-edit.
    Re-vendor with scratchpad vendor_pysqf.py after pulling upstream.
    Renamed for this mission's convention: APS_ = owned by the server addon,
    which matters because the server compiles both CfgFunctions trees into
    missionNamespace and a shared name silently overwrites.
    Upstream name: fn_pysqfSmoke.sqf  */
// SPDX-License-Identifier: MIT
/*
    sqf/fn_pysqfSmoke.sqf   —   registered as  APS_fnc_pysqfSmoke

    WHY THIS EXISTS
      This subsystem has several independent ways to be "not working", and from
      inside the game they all look identical — a call that returns nothing:

        1. the extension is not loaded at all (wrong -serverMod, wrong filename,
           wrong architecture),
        2. the extension is loaded but the Python daemon is not running, or is
           listening on a different socket,
        3. both are up but the database is unreachable or the credentials are
           wrong.

      Guessing between those from a silent failure is the whole problem. This
      walks them in order and names the first one that breaks, so the answer to
      "why isn't it working" is one line in the RPT instead of an afternoon.

    WHY EVERY STAGE IS WRAPPED
      Because this one already lied once. Stage 2 read the raw client's STRING
      tag as a Bool, `!"ok"` threw, and the function died where stage 2 begins —
      after stage 1 had printed PASS. The output said the extension was the last
      working thing; the truth was that it was the only thing tested.

      A diagnostic that can throw does not merely fail, it misattributes. So no
      stage may throw: each runs inside `_guard`, and an exception becomes that
      stage's FAIL with the exception text attached. Then a shape mismatch reads
      "2 protocol FAILED: !: Type String, expected Bool" instead of silence,
      which names the bug on the first run.

      This is the same rule stage 4 tests for, applied to the tester.

    WHAT IT DOES
      Five stages, each gated on the previous one, each reporting pass or the
      exact failure text. Read-only: touches no game state, and the only SQL it
      issues is `select 1`.

    Usage (server debug console):
        [] spawn APS_fnc_pysqfSmoke;

    Read the RPT for lines prefixed [pysqf-smoke].

    Registering it is sqf/README.md; the wire contract the stages exercise is
    docs/PROTOCOL.md; deployment — filename, -serverMod, architecture — is
    README.md.
*/

if (!isServer) exitWith {
    diag_log "[pysqf-smoke] refused: server only. Run this on the server, not a client.";
};
if (!canSuspend) exitWith {
    diag_log "[pysqf-smoke] refused: needs a scheduled context. Use  [] spawn APS_fnc_pysqfSmoke";
};

private _say = {
    params ["_stage", "_ok", "_detail"];
    // Coerced rather than trusted: `if (_ok)` on a non-Bool throws, and this is
    // the one function that must never throw — it is how every other failure
    // gets reported.
    private _tag = if (_ok isEqualType true && {_ok}) then { "PASS" } else { "FAIL" };
    diag_log format ["[pysqf-smoke] %1 %2 — %3", _tag, _stage, _detail];
    (_ok isEqualType true && {_ok})
};

/*  Run one stage. `_body` returns [ok, detail]; a throw becomes [false, "threw: …"].
    Returns the Bool so callers can gate the next stage on it.  */
private _guard = {
    params ["_stage", "_body"];
    private _r = [false, "stage body returned nothing"];
    try {
        _r = call _body;
        if !(_r isEqualType []) then { _r = [false, format ["stage body returned %1, expected an array", _r]]; };
    } catch {
        _r = [false, format ["threw: %1", _exception]];
    };
    _r params [["_ok", false], ["_detail", ""]];
    [_stage, _ok, _detail] call _say
};

private _fail = false;

// ---------------------------------------------------------------- 1. loaded --
// callExtension on a missing extension returns "" rather than erroring, which
// is exactly why this is stage one and not an assumption.
// The message names the three ways this fails rather than pointing at a doc:
// whoever reads it is at a console with a server that will not talk, and a
// reference they have to go and find is a reference they will not follow.
if !(["1 extension loaded", {
    private _ver = "pysqf" callExtension ["version", []];
    if (_ver isEqualTo "") exitWith {
        [false, "'pysqf' callExtension returned nothing. The extension is not loaded. Check that pysqf_x64.so is in a mod folder named in -serverMod, and that the filename matches (Linux 64-bit wants pysqf_x64.so)."]
    };
    [true, str _ver]
}] call _guard) exitWith {
    diag_log "[pysqf-smoke] RESULT: stopped at stage 1 — nothing downstream was tested.";
};

// ------------------------------------------------------------- 2. protocol --
// Proves the verb layer answers in the shape the client expects, before any
// Python is involved. A failure here is a disagreement between the .so and the
// SQF client — or, as history records, between this file and the
// client it calls.
if !(["2 protocol", {
    private _raw = ["version", []] call APS_fnc_pysqfRaw;
    // APS_fnc_pysqfRaw answers with a STRING tag — "ok" | "err" | "pending" —
    // because `poll` genuinely has three outcomes and a Bool cannot carry that.
    // APS_fnc_pysqfCall answers with a Bool, since by the time it returns the
    // polling is over. The type filter below makes a mix-up fail HERE, loudly,
    // rather than at the first operator that cares.
    _raw params [["_vOk", "err", [""]], ["_vPayload", []]];
    if (_vOk isNotEqualTo "ok") exitWith {
        [false, format ["APS_fnc_pysqfRaw could not decode the reply: %1 %2", _vOk, _vPayload]]
    };
    [true, str _vPayload]
}] call _guard) exitWith {
    diag_log "[pysqf-smoke] RESULT: stopped at stage 2 — nothing downstream was tested.";
};

// -------------------------------------------------------------- 3. daemon --
// The first call that requires Python to actually be alive. With the ipc
// back end this is where a stopped daemon or a wrong socket path surfaces.
if !(["3 python reachable", {
    private _r = ["diag.ping", [], 5] call APS_fnc_pysqfCall;
    _r params [["_ok", false, [false]], ["_res", ""]];
    if (!_ok) exitWith {
        [false, format ["%1 — is the daemon running, and is PYSQF_SOCKET the same for both sides? `python3 pysqfd.py --check` validates config without starting.", _res]]
    };
    [true, str _res]
}] call _guard) exitWith {
    diag_log "[pysqf-smoke] RESULT: stopped at stage 3 — the database was not tested.";
};

// ---------------------------------------------------------------- 4. error --
// The distinction this whole project exists for: a failure must arrive as a
// failure, never as an empty success. A PASS here on an ok flag of true would
// mean the error channel is broken and every diagnosis above it is unreliable.
if !(["4 error channel", {
    private _e = ["diag.boom", [], 5] call APS_fnc_pysqfCall;
    _e params [["_eOk", true, [false]], ["_eRes", ""]];
    if (_eOk) exitWith {
        [false, "a deliberately failing call reported SUCCESS. Failure and emptiness are being conflated — do not trust anything above."]
    };
    [true, format ["failure arrived as a failure: %1", _eRes]]
}] call _guard) then { _fail = true; };

// -------------------------------------------------------------------- 5. db --
// Read-only. A failure here is a database problem, not a PySQF problem, and the
// message says so to stop the next person debugging the wrong layer.
if !(["5 database", {
    private _d = ["db.query", ["select 1 as ok", []], 10] call APS_fnc_pysqfCall;
    _d params [["_dOk", false, [false]], ["_dRes", ""]];
    if (!_dOk) exitWith {
        [false, format ["%1 — PySQF itself is working (stages 1-4 passed). This is the DSN, the server, or psycopg. Check PYSQF_DB_DSN and that psycopg is importable by the daemon's interpreter.", _dRes]]
    };
    [true, str _dRes]
}] call _guard) then { _fail = true; };

diag_log (if (_fail) then {
    "[pysqf-smoke] RESULT: some stages failed — see FAIL lines above."
} else {
    "[pysqf-smoke] RESULT: all stages passed. PySQF is reachable end to end."
});
