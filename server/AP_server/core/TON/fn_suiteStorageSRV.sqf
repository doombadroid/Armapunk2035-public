/*
    File: fn_suiteStorageSRV.sqf  (APS_fnc_suiteStorageSRV)
    Luxe Suites 2026-08-07 -- suite storage authority. See suites.md §6.

        ["load", "<oid>", []]                  -> push contents + capacities
        ["sync", "<oid>", [_vinv, _pinv, _seq]] -> validate and persist, session stays open
        ["save", "<oid>", [_vinv, _pinv, _seq]] -> validate and persist, session ends (close)

    CfgRE: allowedTargets = 2.

    v2: the client now drives the REAL house storage screen (TrunkMenu) against a
    local crate, so this handles a whole-inventory load/save rather than
    item-at-a-time deposits. The house hydrate/persist functions are untouched --
    they are the two most incident-scarred files in the mission and they key on
    the `houses` table.

    WHAT IS TRUSTED
      * The CALLER comes from remoteExecutedOwner and is matched against
        suites.owner. A client-supplied oid only ever selects a row after that.
      * The submitted inventory is NOT trusted as given. Item keys are
        format-checked (that check is also the SQL-injection guard), quantities
        are bounded, and both lists are truncated to capacity. The player's own
        virtual inventory is already client-authoritative in this codebase
        (CLAUDE.md names it as the existing trust boundary), so the goal here is
        not to make deposits unforgeable -- it is that nothing a client sends can
        corrupt the row, exceed capacity, or reach a suite it does not own.
      * Weight is not recomputed: virtual item weights live in a client config
        the server cannot read. Capacity is therefore counted in UNITS, which the
        server CAN enforce. A capacity the server cannot compute is not a
        capacity, it is a suggestion.
*/
params [["_mode", "", [""]], ["_oid", "", [""]], ["_arg", [], [[]]]];
if (_mode isEqualTo "" || {_oid isEqualTo ""}) exitWith {};

#define SUITE_VCAP 900
#define SUITE_PCAP 3000
#define STACK_CAP  100000

private _ro = remoteExecutedOwner;
if (_ro <= 2) exitWith {};
private _pl = (allPlayers select { owner _x == _ro }) param [0, objNull];
if (isNull _pl) exitWith {};
private _uid = getPlayerUID _pl;
if !(_uid regexMatch "\d{17}") exitWith {};
if !(_oid regexMatch "LUX\d{1,12}F\d{1,2}") exitWith {
    diag_log format ["[SUITE][SEC] storage: bad oid '%1' from %2", _oid, _uid]; };
// ONE TENANT, ONE CALL AT A TIME, IN THE ORDER SENT. Each call suspends on the server-wide DB
// lock, which is not FIFO, so without this a quick close+reopen could run "load" before the
// previous open's last writes: the tenant is shown a stale row, and a late "save" then ends
// the NEW session so every take after it is refused while the gear still saves (a dupe).
// The ticket is drawn before the first suspension, so it follows message order.
// ponytail: 30 s self-expiry so one wedged call cannot lock a tenant out; past it only the
// seq claim below orders writes. Release is the last line of this file, and the one
// top-level exit after this point releases too.
private _q = createHashMap; private _tk = 0;
isNil { _q = localNamespace getVariable ["AP_suiteQueue", createHashMap]; localNamespace setVariable ["AP_suiteQueue", _q];
    private _e = _q getOrDefault [_uid, [0, 0]]; _tk = _e select 1; _e set [1, _tk + 1]; _q set [_uid, _e]; };
private _qUntil = diag_tickTime + 30;
waitUntil { (((_q get _uid) select 0) >= _tk) || {diag_tickTime > _qUntil} };
private _release = { private _e = _q get _uid; _e set [0, (_e select 0) max (_tk + 1)]; };
// Open sessions, uid -> [oid, serverTime, seq, vEnc, pEnc, vTotal, pTotal]. localNamespace, not a
// mission global: a client's publicVariable overwrites a same-named global on the server,
// and this map decides which writes are accepted. Fetch-or-create inside isNil (atomic).
private _sessions = [];
isNil { _sessions = localNamespace getVariable ["AP_suiteLoadOk", createHashMap]; localNamespace setVariable ["AP_suiteLoadOk", _sessions]; };

// vinv/pinv are mres blobs and are read BARE. QUOTE() on an mres column is a
// documented project footgun this file was bitten by on 2026-08-07 (16 diamonds
// destroyed): DB_fnc_mresArray stores the value WITH its own outer quotes, which
// are what DB_fnc_asyncQuery's compile consumes, so QUOTE() adds a second layer,
// mresToArray's compile throws "Missing ;" and the decode yields nothing.
// owner IS a plain VARCHAR and DOES need QUOTE, or compile eats it as a bareword.
// NULLIF+COALESCE hands back a well-formed EMPTY blob instead of a NULL or an
// empty token, so the row always compiles whether or not it has ever been saved.
private _row = [format ["SELECT COALESCE(owner,'') AS owner, COALESCE(NULLIF(vinv,''),'""[[],0]""') AS vinv, COALESCE(NULLIF(pinv,''),'""[[],0]""') AS pinv FROM suites WHERE oid='%1'", _oid], 2, true] call DB_fnc_asyncQuery;
private _r0 = if (_row isEqualType []) then { _row param [0, []] } else { [] };
if !((_r0 param [0, ""]) isEqualTo _uid) exitWith {
    call _release;
    diag_log format ["[SUITE][SEC] %1 touched storage they do not hold (%2)", _uid, _oid];
    [["denied", [[], 0], [[], 0], SUITE_VCAP, SUITE_PCAP], "AP_fnc_suiteStorageRecv", _pl, false] spawn AP_fnc_MP; };

// Decode, and FAIL LOUDLY -- the previous version coerced every unreadable
// result to [[],0]. That comment correctly predicted the disaster ("a decode
// that silently returned nothing would show the tenant an EMPTY suite, and the
// save on close would then overwrite their real contents") and then the code
// did precisely that: the defensive fallback is what CONVERTED a read bug into
// destroyed property. Defensive defaults belong on values that are allowed to
// be missing; an inventory that failed to parse is not missing, it is unknown,
// and the only safe response to unknown is to refuse.
//
// "FAIL" vs a real empty suite is unambiguous: an empty suite is STORED as the
// blob "[[],0]" and decodes to [[],0] (count 2). DB_fnc_mresToArray returns []
// for a malformed blob (its own belt-and-suspenders), so a non-empty column
// that decodes to [] can only be a decode failure.
private _decode = {
    params ["_enc"];
    if !(_enc isEqualType "") exitWith { "FAIL" };
    if (_enc isEqualTo "" || {_enc isEqualTo "NULL"}) exitWith { [[], 0] };
    private _d = [_enc] call DB_fnc_mresToArray;
    if (typeName _d isEqualTo "STRING") then { _d = parseSimpleArray (format ["%1", _d]); };
    if (isNil "_d") exitWith { "FAIL" };
    if !(_d isEqualType []) exitWith { "FAIL" };
    if (_d isEqualTo []) exitWith { "FAIL" };
    if (count _d < 2) exitWith { "FAIL" };
    if !((_d select 0) isEqualType []) exitWith { "FAIL" };
    _d
};

switch (_mode) do {

    case "load": {
        private _v = [_r0 param [1, ""]] call _decode;
        private _p = [_r0 param [2, ""]] call _decode;
        // Refuse the whole session rather than present an empty suite. If the
        // screen never opens, no close can follow, and no close means the row
        // cannot be overwritten -- the contents survive the bug that broke the
        // read, which is the entire point.
        if ((_v isEqualTo "FAIL") || {_p isEqualTo "FAIL"}) exitWith {
            diag_log format ["[SUITE][STORE][ABORT] %1 %2: inventory did not decode, session REFUSED (nothing written). raw vinv=%3 pinv=%4",
                _uid, _oid, _r0 param [1, ""], _r0 param [2, ""]];
            [["error", [[], 0], [[], 0], SUITE_VCAP, SUITE_PCAP], "AP_fnc_suiteStorageRecv", _pl, false] spawn AP_fnc_MP;
        };
        // A save is only accepted from a session that actually LOADED. Belt to
        // the refusal above: it stops an empty write from any client that never
        // read the row, however it got there.
        _sessions set [_uid, [_oid, serverTime]];
        [["ok", _v, _p, SUITE_VCAP, SUITE_PCAP], "AP_fnc_suiteStorageRecv", _pl, false] spawn AP_fnc_MP;
        diag_log format ["[SUITE][STORE] %1 opened %2 with %3 virtual, %4 gear",
            _uid, _oid, _v param [1, 0], count (_p param [0, []])];
    };

    // "sync" is a take/store/swap/drop with the screen still open (AP_fnc_suiteStorageSync):
    // the same validated write as "save", but the session stays open. The crate is local to
    // the client, so before this the row was written only on close -- alt-F4 with storage
    // open left a taken item in the suite row AND in the gear row the take had already
    // saved (a dupe from an unmodified client; store + crash was the mirror-image loss).
    case "sync";
    case "save": {
        private _vin = _arg param [0, [[], 0]];
        private _pin = _arg param [1, [[], 0]];
        private _seq = _arg param [2, 0, [0]];

        // ---- virtual: [[key, qty], ...] ------------------------------------
        private _vItems = [];
        private _vTotal = 0;
        {
            private _k = _x param [0, ""];
            private _n = round (_x param [1, 0]);
            if (_k isEqualType "" && {_k regexMatch "[a-zA-Z0-9_]{1,32}"} && {_n > 0}) then {
                _n = _n min STACK_CAP;
                if (_vTotal + _n > SUITE_VCAP) then { _n = (SUITE_VCAP - _vTotal) max 0; };
                if (_n > 0) then { _vItems pushBack [_k, _n]; _vTotal = _vTotal + _n; };
            };
        } forEach (_vin param [0, []]);

        // ---- physical: the gear arrays the trunk UI produces ----------------
        // Kept as-is structurally (the UI round-trips its own format) but bounded
        // by count, and every entry must be a real classname the engine knows --
        // an unknown class here is how the 2026-06-24 gear-vanishing bug started.
        private _pItems = [];
        private _pTotal = 0;
        {
            private _e = _x;
            private _cls = if (_e isEqualType "") then { _e } else { _e param [0, ""] };
            if (_cls isEqualType "" && {_cls isNotEqualTo ""} && {_pTotal < SUITE_PCAP}
                && {isClass (configFile >> "CfgWeapons" >> _cls)
                    || {isClass (configFile >> "CfgMagazines" >> _cls)}
                    || {isClass (configFile >> "CfgVehicles" >> _cls)}
                    || {isClass (configFile >> "CfgGlasses" >> _cls)}}) then {
                _pItems pushBack _e; _pTotal = _pTotal + 1;
            };
        } forEach (_pin param [0, []]);

        private _vEnc = (([[_vItems, _vTotal]] call DB_fnc_mresArray) splitString "'") joinString "''";
        private _pEnc = (([[_pItems, _pTotal]] call DB_fnc_mresArray) splitString "'") joinString "''";

        // CLAIM. No load, no write: a write can only legitimately follow an open, so one
        // with no matching session is a bug mid-flight or a forged call, and the damage it
        // would do is a wipe. And never an OLDER snapshot after a newer one: _seq is the
        // client's write counter (it only ever climbs), every write is a whole snapshot, and each one
        // suspends on the DB, so they can reach this line out of order -- an older one
        // landing last would put back an item already taken. isNil runs the check-and-set
        // unscheduled, so two writers cannot interleave inside it. "save" ends the session
        // by staling its time (nothing further is accepted) but keeps the snapshot for the
        // catch-up loop below.
        private _next = [];
        isNil {
            private _s = _sessions getOrDefault [_uid, []];
            if ((_s param [0, ""]) isEqualTo _oid && {(serverTime - (_s param [1, -1e9])) <= 3600} && {_seq > (_s param [2, 0])}) then {
                _next = [_oid, [serverTime, -1e9] select (_mode isEqualTo "save"), _seq, _vEnc, _pEnc, _vTotal, _pTotal];
                _sessions set [_uid, _next];
            };
        };
        if (_next isEqualTo []) exitWith {
            diag_log format ["[SUITE][STORE][REFUSED] %1 %2 %3 seq %4: no open session, or older than a write already taken -- ignored", _uid, _mode, _oid, _seq]; };

        // WRITE THE NEWEST, THEN CATCH UP. Two claimed writes can still queue on the DB lock
        // in either order, so after each UPDATE re-read the session and write again while a
        // newer snapshot has been claimed. Whichever writer writes last writes the newest.
        // A reload of the suite resets the session (seq 0) and stops the loop; the queue at
        // the top keeps a reload behind every write sent before it.
        private _wrote = [];
        while { ((_next param [0, ""]) isEqualTo _oid) && {(_next param [2, 0]) > (_wrote param [2, 0])} } do {
            _wrote = _next;
            [format ["UPDATE suites SET vinv='%1', pinv='%2' WHERE oid='%3' AND owner='%4'", _wrote select 3, _wrote select 4, _oid, _uid], 2] call DB_fnc_asyncQuery;
            _next = _sessions getOrDefault [_uid, []];
        };

        // PROOF READ. extDB3 reports no row count through this pipe, and silently
        // losing a deposit is the one failure this file must never have.
        // The old proof read could not fail: it was QUOTE'd (so a NULL came back
        // as the two-character string '' -- never empty) and it only tested for
        // non-emptiness. It logged "ok" for every write including the wipe. A
        // check that cannot fail is not a check; read it back the same way the
        // load does, DECODE it, and compare the total we meant to store.
        private _chk = [format ["SELECT COALESCE(NULLIF(vinv,''),'""[[],0]""') AS vinv FROM suites WHERE oid='%1'", _oid], 2, true] call DB_fnc_asyncQuery;
        private _back = if (_chk isEqualType []) then { (_chk param [0, []]) param [0, ""] } else { "" };
        private _backDec = [_back] call _decode;
        private _ok = !(_backDec isEqualTo "FAIL") && {(_backDec param [1, -1]) isEqualTo (_wrote select 5)};

        diag_log format ["[SUITE][STORE] %1 %8 %2 (seq %9): %3/%4 virtual, %5/%6 gear -> %7",
            _uid, _oid, _wrote select 5, SUITE_VCAP, _wrote select 6, SUITE_PCAP,
            ["WRITE FAILED", "ok"] select _ok, _mode, _wrote select 2];
    };
};
call _release;
