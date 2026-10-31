/*
    APS_fnc_hudLayoutSRV -- read and write one account's status-HUD layout. Spec: hudeditor.md.

        ["get"] remoteExec ["APS_fnc_hudLayoutSRV", 2];
        ["set", [[0,0,1],[0.1,-0.04,1],[0.05,-0.04,1.2],[0,-0.04,1],[0,0,1],[0,0.02,1],[-0.31,0.44,1.5]]]
            remoteExec ["APS_fnc_hudLayoutSRV", 2];

    Both modes answer the CALLER with AP_fnc_hudLayoutRecv, always with a full seven-triple
    array -- so the client never has to decide what "no answer" meant, and a refused write is
    answered with what is actually stored rather than with silence.

    THE CALLER IS remoteExecutedOwner, NEVER THE PAYLOAD -- the standing rule. The payload
    carries no identity at all: there is no uid field to forge, and the only thing a client can
    influence is its OWN row. The uid comes from getPlayerUID on the unit that owns the sending
    machine, which is engine-derived.

    AND IT IS CAPTURED IN THE FIRST FRAME, because remoteExecutedOwner is FRAME-LOCAL and both
    branches below suspend on the database. A naive `_this spawn` would read 0 inside the
    spawned thread -- "the server called me" -- and lose the caller entirely. Same wrapper the
    duty framework uses (APS_fnc_dutySRV): capture, re-enter through a two-element carrier, and
    unwrap it ONLY in a frame that reports no remote sender of its own. A client that sends the
    carrier shape itself is read with its own owner id, the unwrap is skipped, and its
    array-in-slot-0 then fails the `params` string check and lands in `default`, logged.

    NOTHING IS COMPILED, HERE OR ON THE CLIENT. The column comes back as text and is read with
    parseSimpleArray -- the rule at core\DB\fn_queryRequest.sqf:40 ("parse, never call compile
    -- a poisoned free-text column would otherwise execute as SQF on login", the Lystic
    compile-RCE class). The stored shape is an array of arrays of NUMBERS with no object keys
    precisely so that parseSimpleArray is sufficient and compile is never tempting.

    NO CLIENT VALUE EVER REACHES SQL. Both statements are PARAMETERISED -- %s placeholders with
    the values riding beside the statement (DB_fnc_asyncQuery's fourth argument /
    DB_fnc_asyncExec's second). The JSON text written for a "set" is rebuilt here from numbers
    this file has already validated, one at a time, through toFixed -- the client's own string
    is never stored and never seen by the database.

    THE VALIDATOR IS STRICT AND IT REJECTS, IT DOES NOT REPAIR. Exactly seven triples [dx, dy, s],
    dx/dy finite in [-1, 1], s finite in [0.25, 3] (hudeditor.md §9), or the write is refused
    whole. THE ONE LENIENCY IS ON READ: v1 wrote PAIRS, and a stored pair is read as scale 1 --
    the `_strict` flag is false for "get" and true for "set", so a client cannot write the old
    shape but an account that never opened the v2 editor still loads. Repairing a malformed
    payload would mean guessing which half of it was meant, and a client that sends a bad shape
    is either broken or probing -- neither deserves a partial write into the account row.
    (The CLIENT's own AP_fnc_hudLayoutNorm is deliberately the opposite: it clamps rather than
    rejects, because a client that refuses a layout has no HUD to fall back to.)
*/

// ---- caller, captured before anything suspends ------------------------------------------
private _owner = remoteExecutedOwner;
if (!canSuspend) exitWith { [_this, _owner] spawn APS_fnc_hudLayoutSRV; };

private _payload = _this;
private _src = _owner;
if (_owner isEqualTo 0 && {(count _this) isEqualTo 2}
    && {(_this select 0) isEqualType []} && {(_this select 1) isEqualType 0}) then {
    _src = _this select 1;
    _payload = _this select 0;
};

_payload params [["_mode", "", [""]], ["_raw", [], [[]]]];

// Server-internal calls have nobody to answer and no row to touch. There is no legitimate
// local caller for this function; it exists only to serve a client.
if (_src isEqualTo 0) exitWith {
    diag_log format ["[HUDLAY] refused: no remote caller (mode '%1')", _mode];
    false
};

private _unit = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _unit) exitWith {
    diag_log format ["[HUDLAY] refused: owner %1 resolves to no player", _src];
    false
};
private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {
    diag_log format ["[HUDLAY] refused: empty uid for owner %1", _src];
    false
};

// ---- the validator ------------------------------------------------------------------------
// NO exitWith INSIDE THE forEach. exitWith in a forEach body exits that ITERATION's scope, not
// the loop, so an early-out written that way would skip one bad pair and carry on validating
// the rest -- the phantom-else shape that has bitten this codebase before. A flag it is.
private _fnNorm = {
    params [["_in", [], [[]]], ["_strict", true, [true]]];
    private _out = [];
    private _ok = ((count _in) isEqualTo 7);
    if (_ok) then {
        {
            private _p = _x;
            private _n = if (_p isEqualType []) then { count _p } else { -1 };
            // A pair is a v1 row and is only acceptable when READING (see the header).
            private _shapeOk = (_n isEqualTo 3) || {!_strict && {_n isEqualTo 2}};
            if (!_shapeOk) then { _ok = false } else {
                private _a = _p select 0;
                private _b = _p select 1;
                private _c = _p param [2, 1];
                if (!(_a isEqualType 0) || {!(_b isEqualType 0)} || {!(_c isEqualType 0)}) then { _ok = false } else {
                    if (!finite _a || {!finite _b} || {!finite _c}
                        || {_a < -1} || {_a > 1} || {_b < -1} || {_b > 1}
                        || {_c < 0.25} || {_c > 3}) then { _ok = false }
                    else { _out pushBack [_a, _b, _c] };
                };
            };
        } forEach _in;
    };
    if (_ok && {(count _out) isEqualTo 7}) then { _out } else { [] }
};

private _zero = [[0,0,1],[0,0,1],[0,0,1],[0,0,1],[0,0,1],[0,0,1],[0,0,1]];

switch (toLower _mode) do {

    case "get": {
        private _row = ["SELECT COALESCE(ui_layout::text, '') FROM players_global WHERE playerid = %s",
                        2, true, [_uid]] call DB_fnc_asyncQuery;
        // ROW then CELL: a bare param [0, ""] returns the whole first ROW. Same unwrap as
        // fn_fabDebugSRV, for the same reason.
        private _txt = format ["%1", (_row param [0, [""]]) param [0, ""]];

        // jsonb::text emits "[[0.1, 0.2], [0, 0]]" WITH spaces after the commas, and
        // parseSimpleArray does not accept them. Strip every space before parsing -- there is
        // nothing but digits, signs, dots, commas and brackets in a valid value, so this can
        // never change a number.
        _txt = (_txt splitString " ") joinString "";

        private _arr = [];
        if !(_txt isEqualTo "" || {_txt isEqualTo "[]"} || {_txt isEqualTo "NULL"}) then {
            // SECURITY: parseSimpleArray, never call compile. See the header.
            _arr = parseSimpleArray _txt;
            if (isNil "_arr") then { _arr = [] };
            if !(_arr isEqualType []) then { _arr = [] };
        };

        private _L = [_arr, false] call _fnNorm;          // lenient: v1 pairs read as scale 1
        if (_L isEqualTo []) then { _L = _zero };   // NULL, or a row written before the shape settled
        [_L] remoteExec ["AP_fnc_hudLayoutRecv", _src];
        true
    };

    case "set": {
        private _L = [_raw, true] call _fnNorm;           // strict: triples only
        if (_L isEqualTo []) exitWith {
            ["-SEC-", _unit, format ["hudLayoutSRV: malformed layout refused (%1 entries)", count _raw]] call APS_fnc_logIt;
            // Answer anyway, with what is stored, so a client that sent junk re-syncs to the
            // truth instead of believing its own bad value took. THE CARRIER FORM, not a bare
            // ["get"]: remoteExecutedOwner reads 0 in a spawned frame, so a plain re-entry
            // would lose the caller and refuse itself one line later.
            [["get"], _src] spawn APS_fnc_hudLayoutSRV;
            false
        };

        // Rebuilt from the validated numbers. The client's own text is never stored.
        private _json = "[" + ((_L apply {
            format ["[%1,%2,%3]", (_x select 0) toFixed 5, (_x select 1) toFixed 5, (_x select 2) toFixed 5]
        }) joinString ",") + "]";

        private _r = ["UPDATE players_global SET ui_layout = %s::jsonb WHERE playerid = %s",
                      [_json, _uid]] call DB_fnc_asyncExec;

        if ((_r param [0, 0]) isEqualTo 1) then {
            if ((_r param [1, 0]) isEqualTo 0) then {
                diag_log format ["[HUDLAY] set: no players_global row for %1 -- nothing written", _uid];
            } else {
                diag_log format ["[HUDLAY] set: %1 saved", _uid];
            };
        } else {
            diag_log format ["[HUDLAY] set: write FAILED for %1 -- %2", _uid, _r param [1, ""]];
        };

        // Echo the stored value back either way: the client applies what the server says it
        // has, never what the client thinks it sent.
        [_L] remoteExec ["AP_fnc_hudLayoutRecv", _src];
        true
    };

    default {
        ["-SEC-", _unit, format ["hudLayoutSRV: unknown mode '%1'", _mode]] call APS_fnc_logIt;
        false
    };
};
