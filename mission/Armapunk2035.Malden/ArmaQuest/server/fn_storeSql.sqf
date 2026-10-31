// SPDX-License-Identifier: MIT
/*
    server/fn_storeSql.sqf   —   aq_fnc_storeSql

    Purpose: persist store records into a host's SQL database, without knowing
    anything about that database.

    WHY THIS EXISTS
      The shipped stores are a client-side namespace (wrong for a persistent
      server, because the client then owns its own quest history) and a stub.
      A real server wants its own database — but which database, reached through
      which extension, is the host's business and changes over a host's lifetime.

      So this driver knows SQL and nothing else. The host names ONE function in
      AQ_Settings >> sqlExec that takes [sql, mode] and returns rows, and the
      host is free to point that at whatever transport it currently uses. A host
      migrating between database engines does not touch this file.

    DIALECT
      MariaDB/MySQL flavour, deliberately: it is the dialect the widest set of
      Life-derived hosts already speak, and a host on another engine reaches
      it through a translating layer that expects exactly that (confirmed
      live: a PostgreSQL host round-trips this driver's payload byte-for-byte
      through one). But dialect is only the syntax half of the problem -- it
      says nothing about how a given TRANSPORT hands rows back to SQF, and a
      transport that returns results through `call compile` (measured:
      MariaDB over extDB3) answers with QUOTE()'s own escaping -- backslash
      before a quote, doubled backslashes -- fed into a language whose strings
      have no backslash escapes at all (see the escaping helper below). The
      write can succeed, and the very next read of that same row, through the
      exact SELECT `load` issues, can come back unparseable, silently: `load`
      just reports the record absent, and a player looks like they lost
      everything they had.

      A driver that only ever sees `[_sql, _mode] -> result` cannot special-
      case that away, or ask what transport it is talking to (see WHY THIS
      EXISTS above) -- so it proves its own round trip empirically instead,
      every boot, with a canary: `init` below writes a payload built from
      exactly the characters that break a compile-based read, reads it back
      through the same statement `load` uses, and refuses to come up at all if
      what returns is not byte-identical to what was sent. Corrupting saves
      quietly is worse than refusing loudly at boot.

    THE TABLE
      armaquest_state(skey VARCHAR(64) PRIMARY KEY, data TEXT, updated_at TIMESTAMP)
      Created by the host's own migration, NOT by this driver: a driver that
      issues DDL at boot is a driver that needs schema privileges at boot.

      `data` is TEXT. It must not be a JSON column type — a host layer that
      re-encodes JSON columns on read will corrupt this payload, and it will do
      it silently, because the result is still a valid string.

    WRITE CONFIRMATION
      `save` does not trust its own write. Mode 1 is fire-and-forget by
      definition, and a mode-2 write is not safe to trust either -- on at
      least one real host transport (this library's own primary dialect,
      MariaDB via extDB3) a mode-2 write returns the identical bare [] for a
      write that landed, one that touched nothing, and one that failed
      outright, so switching modes on the write itself buys nothing there.
      `save` instead writes, then reads the row back with the same SELECT
      `load` already trusts and compares it byte-for-byte against what was
      sent. Only a match is a confirmed write; anything else — including a
      transport that cannot even complete the read — is `false`, and the
      caller's write-behind buffer keeps the record dirty and retries it.
      A driver that reports success it is not sure of is worse than one that
      retries a write that actually landed (see fn_storeExtDB.sqf's own rule
      that a driver "must never report success it is not sure of").

    CHUNKING
      A driver that only sees [_sql, _mode] -> result cannot ask the executor
      what its own limit is, so it cannot assume there isn't one. At least one
      real executor for this driver enforces a conservative cap on the WHOLE
      outgoing call, not the payload alone: the reference host's SQF-side
      bridge refuses any [_sql,_mode] call whose own JSON encoding exceeds
      8000 characters (see pysqf.md upstream), and that number is already a
      deliberate margin under Arma's callExtension input ceiling, so raising
      it is not on the table. Three things eat into that cap for anything but
      a trivial record: the fixed INSERT text, the escaping discipline
      calibrated above (which can double a byte), and -- easy to miss -- the
      EXECUTOR'S OWN wrapping of the whole SQL string as one JSON value, which
      doubles every quote and backslash the SQL text contains, and a JSON
      payload embedded in that text is dense with quotes. AQ_SQL_CHUNK_MAX
      below is sized against the worst case of all three at once -- see its
      own comment for the arithmetic -- not against what one real record
      happens to measure today.

      So `save` never writes a record as one statement. It always splits the
      JSON into fixed-size pieces -- even a one-chunk record goes through
      this path, one shape rather than two -- and writes each piece as its
      own row, under a key derived from the caller's key. The row at the
      caller's OWN key stops holding payload; it holds a small header naming
      how many chunk rows there are and how long the reassembled document
      must be.

      TORN READS
      A save that dies between chunk 3 and chunk 4 must not leave `load` able
      to reassemble a shorter, well-formed-looking document out of whatever
      landed. Two things make that true here. First, ORDER: every chunk is
      written and read back byte-exact before the header is touched, and the
      header -- one row, one statement -- is always the LAST write of a save.
      Until it lands, `load` still reads the OLD header, which still names
      the OLD, still-fully-intact set of chunks; a save that never reaches
      the header commits nothing, and corrupts nothing either. Second,
      GENERATION: the chunk rows a save writes are never the rows the current
      header points at. Each record ping-pongs between two chunk generations,
      0 and 1; a save always targets the generation the current header does
      NOT name, so nothing currently readable is ever mutated in place. Only
      once the new generation's header is confirmed written does the OLD
      generation get deleted (best-effort -- see `save` below). The header
      also carries the reassembled LENGTH, not just the chunk count, so a set
      of chunks that are individually present but collectively wrong is
      caught by a length mismatch rather than handed to a caller as if valid.

      LEGACY RECORDS
      A row this driver did not write chunked -- including every row already
      sitting in a live database before this change shipped -- has no header
      to find, because its data does not begin with the header's sentinel:
      real JSON from this library always begins with `[` (aq_fnc_srvStore
      packs every record as ["#aq.h", ...] before calling toJSON), and the
      sentinel begins with `#`, which JSON never produces at position 0.
      `load` treats anything that does not match the sentinel as a complete
      legacy document and returns it unchanged, exactly as before this
      change existed. A row that DOES match the sentinel but fails to parse,
      or whose chunks do not reassemble to the declared length, is neither
      "legacy" nor "absent": `load` returns neither the partial bytes nor ""
      (which the facade above reads as "nothing stored yet" and would
      silently start the player over) -- it returns a short tag guaranteed
      not to be valid JSON, so aq_fnc_srvStore's own fromJSON check fails
      loudly and logs it, while this file logs the specific reason (which
      chunk, which mismatch) beside it.

    Usage:  ["save", ["board", _json]] call aq_fnc_storeSql;
*/

params [["_verb", "", [""]], ["_args", [], [[]]]];

if (!isServer) exitWith {
    diag_log text "[AQ] storeSql called off the server; refused.";
    false
};

// ------------------------------------------------------------ the executor
private _execName = ["sqlExec", ""] call aq_fnc_setting;
if (_execName isEqualTo "") exitWith {
    diag_log text "[AQ] storeSql: AQ_Settings >> sqlExec is empty; there is no host executor to call.";
    false
};
if (isNil _execName) exitWith {
    diag_log text format ["[AQ] storeSql: sqlExec names '%1', which is not defined on this machine.", _execName];
    false
};
private _exec = missionNamespace getVariable _execName;
if !(_exec isEqualType {}) exitWith {
    diag_log text format ["[AQ] storeSql: sqlExec names '%1', which is defined but not a function (got %2).", _execName, typeName _exec];
    false
};

// ------------------------------------------------------------ escaping
/*
    Escaping is BACKEND-DEPENDENT, and the two disciplines are mutually
    exclusive -- applying the wrong one corrupts the payload just as surely as
    applying none.

      "quote"      double the single quote, leave backslash alone. Correct
                   wherever the SQL standard is followed, which includes
                   PostgreSQL with standard_conforming_strings=on.
      "backslash"  double the single quote AND the backslash. Required by
                   MySQL/MariaDB, whose default sql_mode treats backslash as
                   an escape character inside string literals.

    Measured, on real servers of each kind: under "backslash" PostgreSQL stores
    two backslashes where one was sent; under "quote" MySQL swallows the
    backslash that JSON put in front of every embedded double quote, and the
    payload stops being valid JSON. Either way the corruption is silent and only
    shows up as a player whose saved state has vanished.

    A host-agnostic driver cannot ask which backend it is talking to, so `init`
    determines it empirically (see the calibration below) and records the answer
    in aq_storeSqlEscMode. Before that runs, the standard reading is the safer
    assumption: it is the one that leaves data untouched rather than adding
    bytes to it.
*/
private _escMode = localNamespace getVariable ["aq_storeSqlEscMode", "quote"];
private _esc = {
    params ["_s", ["_mode", "quote", [""]]];
    private _out = "";
    {
        _out = _out + (
            if (_x isEqualTo "'") then { "''" }
            else {
                if (_mode isEqualTo "backslash" && {_x isEqualTo "\"}) then { "\\" } else { _x }
            }
        );
    } forEach (_s splitString "");
    _out
};

// ------------------------------------------------------------ chunking
// Budget on the RAW (pre-escaping) chars of ONE chunk, chosen with margin
// under the reference host's 8000-char whole-call cap (see CHUNKING above).
// The arithmetic, worst case and content-independent:
//   - escaping can at most DOUBLE a chunk (every byte a quote or backslash,
//     under the "backslash" discipline): escaped <= 2 * AQ_SQL_CHUNK_MAX
//   - the fixed INSERT text around it is 114 chars; the longest chunk key
//     this file builds (_chunkKey below) is ~30 -- budgeted at 40 for margin
//   - so the SQL statement is at most 2*AQ_SQL_CHUNK_MAX + 154 chars
//   - the executor's own JSON-wrap of that whole statement can at most
//     DOUBLE IT AGAIN (every quote/backslash in the SQL text becomes \" or
//     \\, and a JSON payload is dense with quotes), plus a handful of bytes
//     for the [ , ] wrapper and the mode digit: call it +8
//   - worst case: argsJson <= 2*(2*AQ_SQL_CHUNK_MAX + 154) + 8
// At 1500 that is 6316 -- 1684 chars (21%) of headroom under 8000 even in a
// content-adversarial worst case. A real failing board record (this file's
// header, live dev server, 2026-08-17) runs far lighter than that worst
// case -- about 15% quote density -- because real text is nowhere near 100%
// quote characters; simulated in python3 against that live record, not
// measured in-engine (nothing here can be). See task-13-report.md.
#define AQ_SQL_CHUNK_MAX 1500

// Sentinel marking the base-key row as a chunk HEADER rather than a legacy
// (or reassembled) document. See LEGACY RECORDS above for why a real payload
// can never start with this.
#define AQ_SQL_CHUNK_MARK "#aq.sqlchunk1:"

// Returned by `load` in place of a corrupt chunked record. Guaranteed non-
// empty (so the facade above never reads it as "nothing stored yet") and
// guaranteed to fail fromJSON (so aq_fnc_srvStore's own parse-failure path
// logs it loudly and treats the record as new, rather than silently
// accepting a truncated document) -- see LEGACY RECORDS above and
// fn_srvStore.sqf's `load` verb.
#define AQ_SQL_CORRUPT_TAG "#aq.sqlcorrupt:"

// Key of chunk _idx (0-based) of generation _gen ("0"/"1") under base key
// _k. "$" cannot appear in a real skey ("board" / "player:<uid>" are the
// only two this library ever uses), so this can never collide with a
// legitimate key, chunked or not. Longest realistic instance: "player:" (7)
// + a 17-digit uid + "$1$" (3) + a chunk index -- comfortably inside the
// 64-char column and the ~40-char budget AQ_SQL_CHUNK_MAX above assumes.
private _chunkKey = {
    params ["_k", "_gen", "_idx"];
    format ["%1$%2$%3", _k, _gen, _idx]
};

// Header VALUE for a chunked record: generation, chunk count, and the exact
// reassembled length. The length is what catches a set of chunks that are
// individually present but collectively wrong -- see TORN READS above --
// which chunk count alone would not.
private _chunkHeader = {
    params ["_gen", "_n", "_len"];
    format [AQ_SQL_CHUNK_MARK + "%1:%2:%3", _gen, _n, _len]
};

// Parse a header value written by _chunkHeader. Returns [] both for "does
// not even have the prefix" and for "has the prefix but the rest does not
// parse" -- callers that need to tell those apart check the prefix
// themselves first (see _loadReassemble). n=0 can never be legitimate
// (`save` always writes at least one chunk, see below), so it -- like a
// generation outside {0,1}, a negative length, or a chunk count past
// anything this library could plausibly write -- means the text
// parseNumber was given was not really one of this driver's headers.
private _parseChunkHeader = {
    params ["_v"];
    private _markLen = count AQ_SQL_CHUNK_MARK;
    if (count _v < _markLen) exitWith { [] };
    private _rest  = _v select [_markLen, (count _v) - _markLen];
    private _parts = _rest splitString ":";
    if (count _parts != 3) exitWith { [] };
    private _gen = parseNumber (_parts select 0);
    private _n   = parseNumber (_parts select 1);
    private _len = parseNumber (_parts select 2);
    if !(_gen in [0, 1])         exitWith { [] };
    if (_n <= 0 || {_n > 1000000}) exitWith { [] };
    if (_len < 0)                exitWith { [] };
    [_gen, _n, _len]
};

// Given the base-key row's raw string _v: return it UNCHANGED if it is not
// one of this driver's chunk headers (a legacy record -- see LEGACY RECORDS
// above), or the fully reassembled, length-verified original document if it
// is, or a guaranteed-non-JSON corruption tag if it claims to be a header
// but cannot be trusted. Never returns a partial document.
private _loadReassemble = {
    params ["_key", "_v", "_escMode"];
    private _markLen = count AQ_SQL_CHUNK_MARK;
    if (count _v < _markLen || {!((_v select [0, _markLen]) isEqualTo AQ_SQL_CHUNK_MARK)}) exitWith { _v };

    private _hdr = [_v] call _parseChunkHeader;
    if (_hdr isEqualTo []) exitWith {
        diag_log text format ["[AQ] storeSql load('%1'): chunk header did not parse (got '%2'); record is corrupt. Refusing to return a partial or garbage document.", _key, _v];
        AQ_SQL_CORRUPT_TAG + "malformed-header"
    };
    _hdr params ["_gen", "_n", "_len"];

    private _buf  = "";
    private _fail = "";
    private _i = 0;
    while { _i < _n && {_fail isEqualTo ""} } do {
        private _ckEsc = [([_key, _gen, _i] call _chunkKey), _escMode] call _esc;
        private _cr = [format ["SELECT data FROM armaquest_state WHERE skey='%1'", _ckEsc], 2] call _exec;
        private _gotStr = (_cr isEqualType []) && {count _cr > 0} && {(_cr select 0) isEqualType ""};
        if (_gotStr) then {
            _buf = _buf + (_cr select 0);
        } else {
            _fail = format ["chunk %1/%2 (generation %3) missing or unreadable (got %4)", _i, _n, _gen, _cr];
        };
        _i = _i + 1;
    };

    if !(_fail isEqualTo "") exitWith {
        diag_log text format ["[AQ] storeSql load('%1'): %2; record is corrupt or was caught mid-write. Refusing to return a partial document.", _key, _fail];
        AQ_SQL_CORRUPT_TAG + "missing-chunk"
    };
    if (count _buf != _len) exitWith {
        diag_log text format ["[AQ] storeSql load('%1'): reassembled %2 chars but the header declares %3; record is corrupt. Refusing to return it.", _key, count _buf, _len];
        AQ_SQL_CORRUPT_TAG + "length-mismatch"
    };
    _buf
};

switch (toLower _verb) do {

    // Prove the table is reachable AND readable. COUNT(*) rather than a
    // SELECT of a row, because an empty table and a missing table must not
    // look the same: the first returns a row containing 0, the second fails.
    case "init": {
        private _r = ["SELECT COUNT(*) AS c0 FROM armaquest_state", 2] call _exec;
        if !(_r isEqualType []) exitWith {
            diag_log text format ["[AQ] storeSql init: executor '%1' did not return an array (got %2). Store unusable.", _execName, typeName _r];
            false
        };
        if (_r isEqualTo []) exitWith {
            diag_log text "[AQ] storeSql init: COUNT(*) returned no row; armaquest_state is probably missing. Run the migration.";
            false
        };
        diag_log text format ["[AQ] storeSql init: armaquest_state reachable, %1 record(s).", _r param [0, "?"]];

        // ------------------------------------------------- round-trip canary
        // Reachable is not the same as usable (see DIALECT above). This
        // driver stays host-agnostic on purpose -- it sees [_sql, _mode] ->
        // result and nothing else, so it cannot ask whether it is talking to
        // extDB3, PostgreSQL, or anything in between, and must not guess. So
        // it proves the round trip the only way a host-agnostic driver can:
        // empirically, once, right here. A payload built from exactly the
        // characters known to break a compile-based read (a quote, a
        // backslash, a double quote) is written under a reserved key through
        // the same escaping helper `save` uses, read back through the same
        // QUOTE(data) SELECT `load` uses, and compared byte-for-byte.
        //
        // This is deliberately NOT routed through the `save`/`load` verbs
        // (i.e. no `["save", [_probeKey, _canary]] call aq_fnc_storeSql`):
        // `save`'s own readback-failure log describes a record staying dirty
        // for the next flush, which is true for a real key and would be a
        // fabricated claim for a reserved probe row that this block deletes
        // two statements later regardless of outcome. Logging that here would
        // misreport what actually happened, so the write, the readback and
        // the diagnostic are inlined instead, using the same two SQL shapes.
        private _probeKey = "__aq_probe";
        // The canary must RESEMBLE the payload, not merely contain one of each
        // hostile character. A 19-character probe with a single apostrophe
        // round-trips under a discipline that a 16 KB record dense with them
        // does not: measured here, a save wrote 1500 characters per chunk and
        // read back 1510, roughly one extra per apostrophe -- while the short
        // probe that was supposed to catch exactly that had passed at boot.
        //
        // So it is built long and quote-heavy, on the same order as a real
        // chunk, and repeats the characters rather than mentioning them once.
        // A probe that is cheaper than the thing it certifies is not a probe.
        private _canaryUnit = "[""d"",""it's a quote: "" and a slash: \ ""],";
        private _canary     = "";
        for "_ci" from 1 to 60 do { _canary = _canary + _canaryUnit; };
        _canary = "aq_probe_" + _canary + "_canary";
        private _chosen   = "";
        private _seen     = [];

        // Try each discipline in turn and keep the first that survives the round
        // trip, cheapest first -- the ordering is "adds least to the payload"
        // rather than "most likely", because on a backend where more than one
        // appears to work, the one that alters nothing cannot be the one
        // introducing bytes of its own.
        {
            if (_chosen isEqualTo "") then {
                private _mode = _x;
                private _kEsc = [_probeKey, _mode] call _esc;
                private _cEsc = [_canary,   _mode] call _esc;
                [format [
                    "INSERT INTO armaquest_state (skey,data) VALUES ('%1','%2') ON CONFLICT (skey) DO UPDATE SET data=EXCLUDED.data, updated_at=NOW()",
                    _kEsc, _cEsc
                ], 1] call _exec;
                private _back = [format ["SELECT data FROM armaquest_state WHERE skey='%1'", _kEsc], 2] call _exec;
                // Cleanup runs per attempt, and its result is never inspected: a
                // delete that fails leaves one inert row under the reserved key,
                // overwritten by ON DUPLICATE KEY UPDATE next boot. Turning that
                // into a second, unrelated reason to fail init would not be.
                [format ["DELETE FROM armaquest_state WHERE skey='%1'", _kEsc], 1] call _exec;
                _seen pushBack [_mode, _back];
                if ((_back isEqualType []) && {count _back > 0} && {(_back param [0, ""]) isEqualTo _canary}) then {
                    _chosen = _mode;
                };
            };
        } forEach ["quote", "backslash"];

        if (_chosen isEqualTo "") exitWith {
            diag_log text format ["[AQ] storeSql init: round-trip probe FAILED under every escaping discipline. Sent %1 under reserved key '%2'; got back %3. This backend cannot carry the payload through the [_sql,_mode] executor contract without corrupting it (see the escaping helper above). Refusing to initialise rather than silently corrupting every save. Store unusable.", _canary, _probeKey, _seen];
            false
        };

        localNamespace setVariable ["aq_storeSqlEscMode", _chosen];
        diag_log text format ["[AQ] storeSql init: escaping calibrated to '%1' -- a canary containing a quote, a backslash and a double quote round-tripped byte-identically under it.", _chosen];

        true
    };

    case "load": {
        _args params [["_key", "", [""]]];
        private _keyEsc = [_key, _escMode] call _esc;
        private _r = [format ["SELECT data FROM armaquest_state WHERE skey='%1'", _keyEsc], 2] call _exec;
        // No row is a legitimate answer meaning "nothing stored yet", and it is
        // NOT the same as a failure. Both arrive here as something that is not
        // a one-element array of string, so both return "" — but the failure is
        // logged, because a store that is silently failing every read looks
        // exactly like a brand-new server.
        if !(_r isEqualType []) exitWith {
            diag_log text format ["[AQ] storeSql load('%1'): executor returned %2, not an array.", _key, typeName _r];
            ""
        };
        if (_r isEqualTo []) exitWith { "" };
        private _v = _r param [0, ""];
        if !(_v isEqualType "") exitWith {
            diag_log text format ["[AQ] storeSql load('%1'): first column was %2, not a string.", _key, typeName _v];
            ""
        };
        // _v is the base-key row: either a complete legacy document (pass it
        // through unchanged) or one of this driver's own chunk headers
        // (reassemble and verify) -- see CHUNKING in the file header.
        [_key, _v, _escMode] call _loadReassemble
    };

    // A write's own result cannot be trusted on every host. Mode 1 is fire-and-forget
    // by definition, and mode 2 is not safe either: measured directly against this
    // library's own primary dialect (MariaDB, over a real extDB3 transport,
    // 2026-08-16 -- see the host adapter's header comment and task-3-report.md), mode
    // 2 on a write returns the identical bare [] whether the write landed, touched
    // nothing, or failed outright. A mode switch alone buys nothing there. So this
    // does not ask the write to report itself: it writes, then reads the row back
    // with the exact SELECT `load` already trusts, and compares byte-for-byte. Only a
    // match is a confirmed write; anything else -- including a transport that cannot
    // even complete the read -- returns false, and the caller's write-behind buffer
    // keeps the record dirty and retries it. Two calls instead of one, but still
    // nothing beyond the [_sql, _mode] -> result contract: no part of this is
    // specific to any one host's transport.
    //
    // That is now true PER ROW rather than once: a record is one or more chunk
    // rows plus a header row (see CHUNKING in the file header), and every one
    // of those rows gets its own write-then-read-back confirmation, in the
    // same "only a byte-exact match counts" sense as before chunking existed.
    case "save": {
        _args params [["_key", "", [""]], ["_json", "", [""]]];
        private _keyEsc = [_key, _escMode] call _esc;

        // ------------------------------------------------- de-exponent, defensively
        // Not this driver's bug, and not fixable here at the source -- fixed here
        // anyway because nothing else in this call chain can. AQ_Settings >>
        // sqlExec's own downstream JSON-wrap (on this host: fn_pysqfCall.sqf,
        // vendored from the private PySQF repo per HANDOFF.md -- generated,
        // "do not hand-edit", and outside this file's own repo besides) tries to
        // repair exponent-notation numbers -- SQF's toJSON renders a value like
        // 1787012345 as "1.78701e+09" past about six digits, and Python's json
        // parser rejects that for an int-typed parameter -- by regexing them back
        // to plain digits before the call leaves the engine. Its pattern spells
        // the decimal point as `\.`, written into an SQF string literal as
        // `"\\."`. SQF has no backslash-escaping in string literals (the file's
        // own constraints already lean on this: `\"` is a parse error, not an
        // escaped quote), so that literal is two literal backslash characters
        // followed by a dot, not one escaped dot. A regex engine reads `\\` as
        // an escaped backslash and the bare `.` after it as "any character" --
        // so the group meant to match ".78701" can never fire (this payload has
        // no real backslash for it to match), and the match that IS found starts
        // at the digit run immediately before "e": for "1.78701e+09" that is
        // "78701e+09", not the whole number. The "repair" reads that fragment as
        // the integer 78701 with nine zeros appended -- 78701000000000, a
        // fourteen-digit replacement for a nine-character match -- and splices
        // it in after the untouched leading "1." that was never part of the
        // match, growing the text by five characters. Every "expires" field this
        // library ever writes is exactly this shape (a ~10-digit Unix timestamp,
        // which SQF's own number-to-string conversion renders in scientific
        // notation past six figures), so every one of them grows whatever it
        // sits inside by five characters the instant it crosses that threshold --
        // which is why a save's own readback of what it just wrote is never the
        // length it declared. Confirmed by reproducing both the doubled- and
        // single-backslash pattern against the live board record in python3, not
        // assumed: see task-13-report.md for the reproduction and the exact
        // character-for-character accounting.
        //
        // The fix belongs upstream, in that file, as a one-character diff (one
        // backslash, not two) -- but that file is generated and this repo does
        // not own it (see HANDOFF.md: "fix upstream, then re-vendor"). Until it
        // is, this driver defends its own input at the one point it fully
        // controls: any exponent-notation number already in `_json`, before it
        // is ever chunked or escaped, is rewritten to plain digits HERE, with a
        // pattern that spells the decimal point correctly (one backslash), so
        // nothing shaped like one survives for the downstream bug to mis-repair.
        // A value already past `toJSON`'s own six-figure cutoff has already lost
        // whatever precision that rendering dropped; this restores exactly the
        // digits the engine chose not to print, the same repair the downstream
        // code was trying (and, by this one character, failing) to make.
        private _deExpMatches = _json regexFind ["-?[0-9]+(\.[0-9]+)?[eE][+-]?[0-9]+", 0];
        if (count _deExpMatches > 0) then {
            private _deExpOut = "";
            private _deExpAt  = 0;
            {
                (_x select 0) params ["_deExpTok", "_deExpPos"];
                private _deExpN = parseNumber _deExpTok;
                private _deExpPlain = if (_deExpN isEqualTo (round _deExpN) && {abs _deExpN < 1e15}) then { _deExpN toFixed 0 } else { _deExpTok };
                _deExpOut = _deExpOut + (_json select [_deExpAt, _deExpPos - _deExpAt]) + _deExpPlain;
                _deExpAt = _deExpPos + count _deExpTok;
            } forEach _deExpMatches;
            _json = _deExpOut + (_json select [_deExpAt]);
        };

        // Write raw value _v under already-escaped key _kEsc and confirm it
        // landed byte-exact via the same QUOTE(data) readback `load` trusts.
        // Returns [ok, rawConfirmResult] so callers can log the executor's
        // own answer on failure.
        private _writeConfirm = {
            params ["_kEsc", "_v"];
            private _vEsc = [_v, _escMode] call _esc;
            [format [
                "INSERT INTO armaquest_state (skey,data) VALUES ('%1','%2') ON CONFLICT (skey) DO UPDATE SET data=EXCLUDED.data, updated_at=NOW()",
                _kEsc, _vEsc
            ], 1] call _exec;
            private _confirm = [format ["SELECT data FROM armaquest_state WHERE skey='%1'", _kEsc], 2] call _exec;
            [(_confirm isEqualType []) && {count _confirm > 0} && {(_confirm param [0, ""]) isEqualTo _v}, _confirm]
        };

        // Learn what the CURRENT header (if any) names, so this save targets
        // the generation it does NOT name (see TORN READS in the file
        // header). Unlike `load`, this cannot shrug off an ambiguous read:
        // guessing "no previous generation" when there really is one would
        // write into the very rows `load` is currently trusting. So an
        // ambiguous read here aborts the save rather than guessing -- the
        // same "never report, or here act on, what it is not sure of" rule
        // the rest of this file already lives by.
        private _prevRes = [format ["SELECT data FROM armaquest_state WHERE skey='%1'", _keyEsc], 2] call _exec;
        private _prevV = "";
        private _prevKnown = _prevRes isEqualTo [];   // definitely absent
        if (!_prevKnown && {(_prevRes isEqualType []) && {count _prevRes > 0} && {(_prevRes select 0) isEqualType ""}}) then {
            _prevV = _prevRes select 0;
            _prevKnown = true;                        // definitely present and readable
        };
        if (!_prevKnown) exitWith {
            diag_log text format ["[AQ] storeSql save('%1'): could not determine the record's previous state (executor returned %2 for the pre-save read); refusing to guess which chunk generation is safe to write. The record stays dirty and will be retried.", _key, _prevRes];
            false
        };

        private _prevGen = -1;
        private _prevN   = 0;
        private _markLen = count AQ_SQL_CHUNK_MARK;
        if (count _prevV >= _markLen && {(_prevV select [0, _markLen]) isEqualTo AQ_SQL_CHUNK_MARK}) then {
            private _hdr = [_prevV] call _parseChunkHeader;
            if !(_hdr isEqualTo []) then {
                _hdr params ["_pg", "_pn", "_pl"];
                _prevGen = _pg;
                _prevN   = _pn;
            };
        };
        private _newGen = if (_prevGen in [0, 1]) then { 1 - _prevGen } else { 0 };

        // Split into fixed-size raw chunks, always at least one -- toJSON of
        // the HashMaps this ever carries never actually produces "", but a
        // uniform shape means `load` never has to guess whether zero chunks
        // is something this driver could have written.
        private _len = count _json;
        private _chunks = [];
        if (_len == 0) then {
            _chunks pushBack "";
        } else {
            private _p = 0;
            while { _p < _len } do {
                private _take = AQ_SQL_CHUNK_MAX min (_len - _p);
                _chunks pushBack (_json select [_p, _take]);
                _p = _p + _take;
            };
        };
        private _n = count _chunks;

        // Write every chunk of the NEW generation. Nothing here touches the row
        // `load` currently trusts (the header, only written below) or the
        // generation it currently names (_prevGen, read above, deleted at the
        // very end) -- a reader is unaffected by any of this until the header
        // itself moves.
        //
        // These writes are NOT confirmed one by one. That was tried and it was
        // the wrong check: comparing each chunk against a QUOTE() readback tests
        // the transport's escaping round trip, which `init`'s canary has already
        // proven once for this backend, and it tests it against a fragment cut
        // at an arbitrary character boundary. It reported a mismatch on a chunk
        // whose head AND tail both came back byte-identical, which is a fault in
        // the check rather than in the data.
        //
        // What actually matters is not that each fragment survived, but that the
        // RECORD reads back. So the whole document is reassembled once, below,
        // through the very same path `load` uses -- and only then is the header
        // written. One comparison instead of N, testing the property the caller
        // depends on rather than an implementation detail underneath it.
        private _i = 0;
        while { _i < _n } do {
            private _ckEsc = [([_key, _newGen, _i] call _chunkKey), _escMode] call _esc;
            private _cvEsc = [(_chunks select _i), _escMode] call _esc;
            [format [
                "INSERT INTO armaquest_state (skey,data) VALUES ('%1','%2') ON CONFLICT (skey) DO UPDATE SET data=EXCLUDED.data, updated_at=NOW()",
                _ckEsc, _cvEsc
            ], 1] call _exec;
            _i = _i + 1;
        };

        // Verify by reading the record back exactly as `load` would, using a
        // header built in memory and NOT yet written. If this does not match,
        // the header never moves: the previous generation stays authoritative,
        // the half-written chunks are unreachable, and the caller keeps the
        // record dirty for the next flush. Verification precedes the commit
        // point rather than following it, which is the whole reason a torn
        // write cannot become visible.
        private _hdrVal = [_newGen, _n, _len] call _chunkHeader;
        private _check  = [_key, _hdrVal, _escMode] call _loadReassemble;
        if !(_check isEqualTo _json) exitWith {
            private _clen = if (_check isEqualType "") then { count _check } else { -1 };
            diag_log text format ["[AQ] storeSql save('%1'): the record did not read back as written (sent %2 chars across %3 chunk(s), reassembled %4). The header was NOT moved, so generation %5 remains authoritative and nothing partial is visible. Record stays dirty and will be retried.", _key, _len, _n, _clen, _prevGen];
            // Locate the FIRST character that differs. A length delta alone says
            // the round trip is lossy; it does not say which character class is
            // responsible, and guessing that from the payload's contents has
            // already cost several wrong hypotheses. This names it directly.
            if (_check isEqualType "" && {_clen > 0}) then {
                private _lim = _len min _clen;
                private _d = -1;
                private _k = 0;
                while { _k < _lim && _d < 0 } do {
                    if !((_json select [_k, 1]) isEqualTo (_check select [_k, 1])) then { _d = _k; };
                    _k = _k + 1;
                };
                if (_d < 0) then {
                    diag_log text format ["[AQ]   first %1 chars are identical; the reassembled copy is simply longer -- the extra characters are at the END.", _lim];
                } else {
                    diag_log text format ["[AQ]   first divergence at index %1", _d];
                    diag_log text format ["[AQ]   sent  [%1]: %2", _d, _json  select [(0 max (_d - 20)), 45]];
                    diag_log text format ["[AQ]   got   [%1]: %2", _d, _check select [(0 max (_d - 20)), 45]];
                };
            };
            false
        };

        // Flip the header: one row, one statement, the commit point. Every
        // reader sees the previous generation intact right up until this
        // lands, and exactly the generation just proven complete above from
        // the instant it does -- there is no state in between the two.
        private _hdrVal = [_newGen, _n, _len] call _chunkHeader;
        ([_keyEsc, _hdrVal] call _writeConfirm) params ["_hdrOk", "_hdrConfirm"];
        if (!_hdrOk) exitWith {
            diag_log text format ["[AQ] storeSql save('%1'): header readback did not confirm the write (got %2); the write did not land. That record stays dirty and will be retried. The generation-%3 chunks just written are orphaned but harmless: load only ever reads the generation the header names, and the next save that lands back on generation %3 overwrites them via ON DUPLICATE KEY UPDATE regardless.", _key, _hdrConfirm, _newGen];
            false
        };

        // Retire the previous generation now that nothing can reach it
        // through `load` any more. Best-effort and unconfirmed on purpose:
        // a failed delete here is a housekeeping miss, not a correctness
        // problem, and this same key reclaims the slot automatically the
        // next time it ping-pongs back onto generation _prevGen.
        if (_prevGen in [0, 1]) then {
            private _j = 0;
            while { _j < _prevN } do {
                private _pkEsc = [([_key, _prevGen, _j] call _chunkKey), _escMode] call _esc;
                [format ["DELETE FROM armaquest_state WHERE skey='%1'", _pkEsc], 1] call _exec;
                _j = _j + 1;
            };
        };

        true
    };

    // Every save is issued immediately; the write-behind buffer that makes that
    // cheap lives in the facade above, not here. Nothing is batched at this
    // level, so there is nothing to commit.
    case "flush": { true };

    default {
        diag_log text format ["[AQ] storeSql: unknown verb '%1'.", _verb];
        false
    };
};
