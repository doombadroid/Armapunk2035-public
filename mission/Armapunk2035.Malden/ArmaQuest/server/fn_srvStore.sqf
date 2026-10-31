// SPDX-License-Identifier: MIT
/*
    server/fn_srvStore.sqf   —   aq_fnc_srvStore

    Purpose: the single persistence gateway. Dispatches load/save/flush to the
    configured store driver, owns the write-behind buffer, and owns the one
    serialisation format used both for storage and for anything sent to a client.

    WHY THIS EXISTS
    Two failure modes, one file.
      1. A quest system that writes on every progress tick will melt a database.
         "Kill 8 raiders" is eight writes; a full server is thousands of writes a
         minute for state nobody reads until the player logs out. Write-behind
         collapses that to one write per dirty record per flush interval.
      2. Every caller inventing its own way to turn a HashMap into something
         storable produces records that one version can write and the next
         cannot read. Serialisation lives here, is used by the network path too,
         and is symmetrical by construction: pack/unpack are each other's inverse
         or the round trip fails loudly.

    WHAT IT DOES
      ["init"]                  bring the configured driver up            -> BOOL
      ["player", uid]           fetch-or-load a player's state         -> HashMap
      ["load", key]             read one record                 -> HashMap or nil
      ["dirty", key]            mark a record for the next flush          -> BOOL
      ["save", key]             write one record right now                -> BOOL
      ["flush"]                 write every dirty record now              -> BOOL
      ["pack", value]           HashMaps -> nested arrays                -> ARRAY
      ["unpack", value]         nested arrays -> HashMaps                 -> ANY

    Every verb but "pack" and "unpack" refuses off the server. Those two are pure
    and stateless, and the client needs "unpack" to read a radiant instance the
    server put on the wire.

    Keys are "board" and "player:<uid>". Nothing else is stored.

    Usage:  private _pst = ["player", _uid] call aq_fnc_srvStore;
            ["dirty", format ["player:%1", _uid]] call aq_fnc_srvStore;

    ---------------------------------------------------------------------------
    DRIVER CONTRACT
      [_verb, _args] call aq_fnc_store<Name>
        "init"  []             -> BOOL     driver usable this session
        "load"  [_key]         -> STRING   the stored JSON, "" when absent
        "save"  [_key, _json]  -> BOOL     durable-enough write
        "flush" []             -> BOOL     commit anything the driver batched
      A driver never sees a HashMap and never sees game state: it moves strings.
      That is what makes a new backend a single file with no knowledge of quests.

    SERIALISATION FORMAT
      A HashMap is written as ["#aq.h", [[key, value], ...]] with values packed
      recursively; arrays are packed element-wise; numbers, strings and booleans
      pass through. The sentinel is deliberately ugly so that no ordinary data
      array collides with it. CODE and OBJECT are refused, not silently dropped
      to nil: persisting either is always a bug (see the design rule against
      compiling config-supplied strings — a stored CODE value is the same hole).
*/

params [["_verb", "", [""]]];
// Read positionally: a `params` default of nil is not a portable way to say
// "this argument may be absent", and for "flush" it genuinely is.
private _a = _this param [1];
private _b = _this param [2];

// "pack" and "unpack" are the exception, and the exception is deliberate: they
// are pure functions of their argument, they touch no state and no driver, and
// the serialisation format has exactly one definition on purpose. The client has
// to be able to read an instance the server packed onto the wire (aq_fnc_sync),
// and the alternative — a second decoder living on the client — is the drift
// this file exists to prevent. Everything that persists still refuses.
if (!isServer && {!(toLower _verb in ["pack", "unpack"])}) exitWith {
    diag_log text format ["[AQ] srvStore('%1') called off the server; refused.", _verb];
    nil
};

// --------------------------------------------------------------- helpers ---
// Defined per call rather than as engine functions on purpose: they are an
// implementation detail of this file, and exporting them would invite callers
// to serialise state without going through the dirty-tracking above.
// UNVERIFIED: these two recurse by naming themselves, which relies on called
// code seeing the caller's private variables. That is how SQF `call` scoping is
// documented to work, and the round-trip probe in diagnostics/ is what proves
// it on a real engine — a nested HashMap is the case that would break first.
private _packFn = {
    private _v = _this;
    switch (true) do {
        case (_v isEqualType createHashMap): {
            private _out = [];
            { _out pushBack [_x, _y call _packFn]; } forEach _v;
            ["#aq.h", _out]
        };
        case (_v isEqualType []): { _v apply { _x call _packFn } };
        case (_v isEqualType ""):   { _v };
        case (_v isEqualType 0):    { _v };
        case (_v isEqualType true): { _v };
        default {
            diag_log text format ["[AQ] srvStore pack: refusing to store a value of type %1; stored as null.", typeName _v];
            ""
        };
    };
};

private _unpackFn = {
    private _v = _this;
    if !(_v isEqualType []) exitWith { _v };
    if (count _v == 2 && {(_v select 0) isEqualTo "#aq.h"} && {(_v select 1) isEqualType []}) exitWith {
        private _pairs = (_v select 1) apply { [_x select 0, (_x select 1) call _unpackFn] };
        createHashMapFromArray _pairs
    };
    _v apply { _x call _unpackFn }
};

private _driverName = switch (toLower (["store", "profileNamespace"] call aq_fnc_setting)) do {
    case "profilenamespace": { "aq_fnc_storeProfile" };
    case "extdb";
    case "extdb3":           { "aq_fnc_storeExtDB" };
    case "sql":              { "aq_fnc_storeSql" };
    case "none":             { "aq_fnc_storeNone" };
    default {
        diag_log text format ["[AQ] srvStore: unknown store '%1' in AQ_Settings; falling back to 'none' so nothing is silently half-persisted.",
            ["store", "profileNamespace"] call aq_fnc_setting];
        "aq_fnc_storeNone"
    };
};
private _driver = missionNamespace getVariable [_driverName, {}];
if (_driver isEqualTo {}) exitWith {
    diag_log text format ["[AQ] FATAL srvStore: store driver %1 is not defined.", _driverName];
    nil
};

// LOCAL PATCH (VENDORED.txt): server state lives in localNamespace, which no
// client publicVariable can overwrite (see fn_srvInit, SERVER GLOBALS).
if (isNil {localNamespace getVariable "aq_srvStoreDirty"}) then { localNamespace setVariable ["aq_srvStoreDirty", createHashMap]; };
private _dirty = localNamespace getVariable "aq_srvStoreDirty";

// Resolve the live in-memory record a key names. Persistence never guesses:
// if a key has no owner in memory there is nothing to write, and saying so is
// better than writing an empty record over a good one.
private _liveOf = {
    params ["_key"];
    switch (true) do {
        case (_key isEqualTo "board"): { localNamespace getVariable "aq_srvBoard" };
        case (_key select [0, 7] == "player:"): {
            private _uid = _key select [7];
            (localNamespace getVariable ["aq_srvPlayers", createHashMap]) getOrDefault [_uid, nil]
        };
        default { nil };
    };
};

private _writeNow = {
    params ["_key"];
    private _live = [_key] call _liveOf;
    if (isNil "_live") exitWith {
        diag_log text format ["[AQ] srvStore save: '%1' names no live record; nothing written.", _key];
        false
    };
    private _json = toJSON (_live call _packFn);
    // UNVERIFIED: toJSON/fromJSON round-trip nested arrays of number|string|bool
    // exactly (Arma 3 2.18+). Confirm with the round-trip probe in
    // diagnostics/, not by inspection: a silent type change here corrupts every
    // saved record at once.
    private _ok = ["save", [_key, _json]] call _driver;
    if (!_ok) then {
        diag_log text format ["[AQ] srvStore: driver refused the write for '%1'. That record is still dirty and will be retried.", _key];
    };
    _ok
};

// ------------------------------------------------------------- dispatch ----
switch (toLower _verb) do {

    case "init": {
        private _ok = ["init", []] call _driver;
        diag_log text format ["[AQ] srvStore: driver %1 init -> %2", _driverName, _ok];
        _ok
    };

    case "pack":   { if (isNil "_a") then { [] } else { _a call _packFn } };
    case "unpack": { if (isNil "_a") then { [] } else { _a call _unpackFn } };

    case "load": {
        if (isNil "_a" || {!(_a isEqualType "")}) exitWith {
            diag_log text "[AQ] srvStore load: missing or non-string key.";
            nil
        };
        private _json = ["load", [_a]] call _driver;
        if (!(_json isEqualType "") || {_json isEqualTo ""}) exitWith { nil };
        private _raw = nil;
        // A corrupt record must not take the server down with it: a player with
        // an unreadable row starts fresh and is named in the log, which is
        // recoverable. A parse exception during boot is not.
        private _err = false;
        _raw = fromJSON _json;
        if (isNil "_raw") then { _err = true; };
        if (_err) exitWith {
            diag_log text format ["[AQ] srvStore load: record '%1' did not parse as JSON; treating the player as new. Raw length %2.", _a, count _json];
            nil
        };
        private _val = _raw call _unpackFn;
        if !(_val isEqualType createHashMap) exitWith {
            diag_log text format ["[AQ] srvStore load: record '%1' decoded to %2, expected a HashMap; ignored.", _a, typeName _val];
            nil
        };
        _val
    };

    // Fetch-or-create. Every read path in this area goes through here, so a
    // player's record is loaded exactly once per session no matter how many
    // givers they talk to.
    case "player": {
        if (isNil "_a" || {!(_a isEqualType "")} || {_a isEqualTo ""}) exitWith {
            diag_log text "[AQ] srvStore player: empty uid; refusing to create a record.";
            nil
        };
        if (isNil {localNamespace getVariable "aq_srvPlayers"}) then { localNamespace setVariable ["aq_srvPlayers", createHashMap]; };
        private _pst = (localNamespace getVariable "aq_srvPlayers") getOrDefault [_a, nil];
        if !(isNil "_pst") exitWith { _pst };

        _pst = ["load", format ["player:%1", _a]] call aq_fnc_srvStore;
        if (isNil "_pst") then { _pst = createHashMap; };

        // Repair rather than reject: a record written by an older version may be
        // missing a whole map. Filling the gap keeps one added feature from
        // invalidating every existing player.
        _pst set ["uid", _a];
        {
            if !(_pst getOrDefault [_x, createHashMap] isEqualType createHashMap) then { _pst deleteAt _x; };
            if (isNil {_pst get _x}) then { _pst set [_x, createHashMap]; };
        } forEach ["completed", "cooldown", "active", "offers", "recent"];

        (localNamespace getVariable "aq_srvPlayers") set [_a, _pst];
        _pst
    };

    case "dirty": {
        if (isNil "_a" || {!(_a isEqualType "")}) exitWith { false };
        _dirty set [_a, true];
        true
    };

    case "save": {
        if (isNil "_a" || {!(_a isEqualType "")}) exitWith { false };
        private _ok = [_a] call _writeNow;
        if (_ok) then { _dirty deleteAt _a; };
        _ok
    };

    case "flush": {
        private _keys = keys _dirty;
        if (count _keys == 0) exitWith { true };
        private _failed = 0;
        {
            if ([_x] call _writeNow) then { _dirty deleteAt _x } else { _failed = _failed + 1 };
        } forEach _keys;
        private _ok = ["flush", []] call _driver;
        if (_failed > 0 || {!_ok}) then {
            diag_log text format ["[AQ] srvStore flush: %1 of %2 record(s) failed, driver commit %3.", _failed, count _keys, _ok];
        };
        _ok && {_failed == 0}
    };

    default {
        diag_log text format ["[AQ] srvStore: unknown verb '%1'.", _verb];
        nil
    };
};
