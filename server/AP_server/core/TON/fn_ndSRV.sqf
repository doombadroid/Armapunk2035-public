/*
    File: fn_ndSRV.sqf  (APS_fnc_ndSRV)
    LooneyBin 2026-07-23: NEW DRACHMA authority — the server-side wallet. First server-authoritative
    currency on the box: the ledger lives in players.new_drachma (DECIMAL(20,4)), ALL arithmetic is
    SQL, amounts travel as 4dp STRINGS end to end. SQF 32-bit floats never touch the ledger — that is
    the entire reason this file exists (exact 4-decimal money beyond the 2^24 float ceiling).

      ["credit", "<amt>", "<reason>"]            remote, from a client — "warkill" (needs a server-seen kill) or
                                                  "coinsell" only, rate-capped per reason
      ["debit",  "<amt>", "<token>"]             remote, from a client — atomic conditional spend (files a
                                                  receipt APS_fnc_vehicleCreate consumes for an ND-only vehicle)
      ["get"]                                    remote, from a client — re-sync balance
    Server-internal credits (mining, quests, login bonus) do NOT come through here: they call
    APS_fnc_ndCreditSrv, which is deliberately absent from CfgRE.hpp.

    Caller identity comes from remoteExecutedOwner (unspoofable), NEVER from client-passed uids.
    Per-uid lock serializes every txn for a player (credit AND debit), so the old/new string compare
    that detects debit success can't be fooled by an interleaved credit.
*/
private ["_mode"];
params [["_a", "", ["", objNull]], ["_b", "", ["", objNull]], ["_c", "", [""]], ["_d", "", [""]]];
_mode = if (_a isEqualType "") then { _a } else { "" };
if (_mode isEqualTo "") exitWith {};

// ---------- shared helpers (file-local) ----------------------------------------------------------
// strict wire format: 1-14 int digits, optional . + 1-4 frac digits. Doubles as the SQL-injection
// guard — a validated amount is safe to interpolate.
private _ndValid = { params ["_s"]; (_s isEqualType "") && {_s regexMatch "\d{1,14}(\.\d{1,4})?"} && {_s isNotEqualTo "0"} && {!(_s regexMatch "0+(\.0{1,4})?")} };
// zero-pad to 14+4 digits for exact ordering
private _ndPad = {params ["_s"];
    private _p = _s splitString ".";
    private _i = _p param [0, "0"];
    private _f = _p param [1, ""];
    while { count _f < 4 } do { _f = _f + "0" };
    while { count _i < 14 } do { _i = "0" + _i };
    _i + _f};
// exact a >= b on padded digit strings (char-by-char — SQF has no string ordering)
private _ndGE = {params ["_pa", "_pb"];
    private _aa = toArray _pa; private _bb = toArray _pb;
    private _r = true;
    for "_i" from 0 to ((count _aa) - 1) do {private _ca = _aa select _i; private _cb = _bb select _i;
        if (_ca != _cb) exitWith { _r = _ca > _cb };};
    _r};
private _ndSelect = {params ["_uid"];
    private _row = [format ["SELECT new_drachma FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    if !(_row isEqualType []) exitWith { "" };
    private _v = _row param [0, ""];
    if !(_v isEqualType "") exitWith { "" };
    _v};
private _resolveCaller = {private _ro = remoteExecutedOwner;
    if (_ro <= 2) exitWith { objNull };   // 0 = local, 2 = server — remote modes require a real client
    (allPlayers select { owner _x == _ro }) param [0, objNull]};
// localNamespace (mints audit 2026-09-26): as a mission global a client publicVariable could clear the lock and
// interleave a credit with a debit, which reads as a successful debit that never happened.
private _ndLocks = localNamespace getVariable "AP_ndLocks";
if (isNil "_ndLocks") then { _ndLocks = createHashMap; localNamespace setVariable ["AP_ndLocks", _ndLocks]; };
private _lockAcquire = {params ["_uid"];
    private _t0 = diag_tickTime;
    waitUntil { !(_ndLocks getOrDefault [_uid, false]) || {diag_tickTime - _t0 > 8} };
    if (_ndLocks getOrDefault [_uid, false]) exitWith { false };   // 8s bail — DB is wedged, refuse the txn
    _ndLocks set [_uid, true];
    true};
private _lockRelease = { params ["_uid"]; _ndLocks set [_uid, false]; };

// NOTE: server-internal trusted credit is APS_fnc_ndCreditSrv (a SEPARATE fn NOT in CfgRE, so a client
// cannot remoteExec it). It can't live here as a mode: ndSRV is CfgRE-whitelisted, and during a
// client-initiated RE chain (e.g. mining) remoteExecutedOwner stays the client's id, so an
// owner-based guard here can't tell a legit internal call from a client forging the mode.

// ---------- remote modes: resolve caller first ---------------------------------------------------
private _pl = call _resolveCaller;
if (isNull _pl) exitWith {};
private _uid = getPlayerUID _pl;
if !(_uid regexMatch "\d{17}") exitWith {};

switch (_mode) do {case "get": {private _bal = [_uid] call _ndSelect;
        if (_bal isNotEqualTo "") then { [[_bal, "sync", ""], "AP_fnc_ndSync", _pl, false] spawn AP_fnc_MP; };};
    case "credit": {private _amt = _b; private _reason = _c;
        if !([_amt] call _ndValid) exitWith { diag_log format ["[LooneyBin][ND][TAMPER] bad credit amount '%1' from %2 (%3)", _amt, _uid, _reason]; };
        // per-reason hourly caps: the client only ever REQUESTS a credit; these bound what a modified
        // client can grind out of each source. Unknown reason = rejected outright. TUNE freely.
        // Audit 2026-09-26 (mints/docsopen-0-0): ND is the one server-owned wallet, and this used to pay any
        // amount a client asked for under five hourly caps -- coinsell alone 100,000 ND/hour. Only the two
        // reasons with a live client caller survive, and neither is a bare ask any more:
        //   warkill  -- needs a player kill the SERVER saw. server init.sqf's EntityKilled handler files one proof
        //               per kill (localNamespace AP_ndKillProof); one proof buys one credit of <= 0.35 ND, the most
        //               fn_updateRemoteStat ever asks for. Whether it was a WAR kill stays the victim's call (gang
        //               wars live client-side), but a kill by this caller has to have happened.
        //   coinsell -- legacy coins are a client-auth item, so the cap IS the bound: 100 ND/hour (the dearest ND
        //               item is ~39 ND). The coins were consumed before this request, so anything over the cap is
        //               HANDED BACK below rather than silently eaten.
        // quest / event / loginbonus are refused: quests pay through APS_fnc_ndCreditSrv (fn_aqProfile), the login
        // bonus is paid by APS_fnc_loginBonusSRV off its own claim, and "event" only fed the dormant xmas present.
        private _caps = createHashMapFromArray [["warkill", 60], ["coinsell", 100]];
        if !(_reason in _caps) exitWith { diag_log format ["[LooneyBin][ND][TAMPER] unknown credit reason '%1' from %2", _reason, _uid];
            ["-SEC-", _pl, format ["BLOCKED ndSRV credit '%1' of %2 ND (reason not client-creditable)", _reason, _amt]] call APS_fnc_logIt; };
        private _amtN = parseNumber _amt;
        private _proofs = localNamespace getVariable ["AP_ndKillProof", createHashMap];
        private _kills = (_proofs getOrDefault [_uid, []]) select { serverTime - _x < 600 };
        if (_reason isEqualTo "warkill" && {_kills isEqualTo [] || {_amtN > 0.35}}) exitWith {
            ["-SEC-", _pl, format ["BLOCKED ndSRV warkill credit of %1 ND (no unredeemed server-seen kill)", _amt]] call APS_fnc_logIt; };
        if (_reason isEqualTo "warkill") then { _kills deleteAt 0; _proofs set [_uid, _kills]; };
        // cap accounting in floats is fine — caps are << the 2^24 ceiling, and the LEDGER never sees these numbers.
        // localNamespace, not a mission global: a client's publicVariable overwrites a missionNamespace global on
        // the server too, and a reset window is a reset cap.
        private _win = localNamespace getVariable "AP_ndRateWin";
        if (isNil "_win") then { _win = createHashMap; localNamespace setVariable ["AP_ndRateWin", _win]; };
        private _k = _uid + "|" + _reason;
        private _w = _win getOrDefault [_k, [serverTime, 0]];
        if (serverTime - (_w select 0) > 3600) then { _w = [serverTime, 0]; };
        private _room = floor ((_caps get _reason) - (_w select 1));
        if (_reason isEqualTo "coinsell" && {_amtN > _room}) then {
            // The hand-back pays out what the CLIENT says it converted, through a server-origin handleInv the item
            // monitor trusts, so it is bounded too: 10,000 coins per uid per hour (slot 2 of the same window), which
            // covers any honest stash re-tried each hour and stops a forged amount becoming a clean coin mint.
            private _over = _amtN - (_room max 0);
            private _back = floor ((_over min (10000 - (_w param [2, 0]))) max 0);
            _w set [2, (_w param [2, 0]) + _back];
            _win set [_k, _w];
            if (_back > 0) then { [[true, "loonycoin", _back], "AP_fnc_handleInv", _pl, false] spawn AP_fnc_MP; };
            [[format ["Coin conversion is capped at %1 per hour -- %2 coin(s) went back into your inventory%3.", _caps get _reason, _back,
                ["", format [" (%1 over the 10,000-per-hour hand-back limit are gone)", _over - _back]] select (_over > _back)], "basic"], "AP_fnc_handleMessage", _pl, false] spawn AP_fnc_MP;
            _amtN = _room max 0;
            _amt = str _amtN;
        };
        if (_amtN <= 0 || {((_w select 1) + _amtN) > (_caps get _reason)}) exitWith {
            diag_log format ["[LooneyBin][ND][CAP] %1 hit the '%2' hourly cap (%3 + %4)", _uid, _reason, _w select 1, _amt];};
        _w set [1, (_w select 1) + _amtN];
        _win set [_k, _w];
        if !([_uid] call _lockAcquire) exitWith {};
        [format ["UPDATE players SET new_drachma = new_drachma + %1 WHERE playerid='%2'", _amt, _uid], 2] call DB_fnc_asyncQuery;
        private _new = [_uid] call _ndSelect;
        [_uid] call _lockRelease;
        if (_new isEqualTo "") exitWith {};
        diag_log format ["[LooneyBin][ND] credit +%1 (%2) -> %3 = %4", _amt, _reason, _uid, _new];
        [[_new, _reason, _amt], "AP_fnc_ndSync", _pl, false] spawn AP_fnc_MP;};
    case "debit": {private _amt = _b; private _tok = _c;
        if (_tok isEqualTo "" || {count _tok > 40}) exitWith {};
        if !([_amt] call _ndValid) exitWith {diag_log format ["[LooneyBin][ND][TAMPER] bad debit amount '%1' from %2", _amt, _uid];
            [[false, "", _tok], "AP_fnc_ndResult", _pl, false] spawn AP_fnc_MP;};
        if !([_uid] call _lockAcquire) exitWith { [[false, "", _tok], "AP_fnc_ndResult", _pl, false] spawn AP_fnc_MP; };
        private _old = [_uid] call _ndSelect;
        private _ok = false;
        private _new = _old;
        if (_old isNotEqualTo "" && { [[_old] call _ndPad, [_amt] call _ndPad] call _ndGE }) then {
            // SQL-side guard is the atomic authority; the lock + old/new compare just make the
            // result detection exact (extDB3 UPDATE reports no row count through this pipe)
            [format ["UPDATE players SET new_drachma = new_drachma - %1 WHERE playerid='%2' AND new_drachma >= %1", _amt, _uid], 2] call DB_fnc_asyncQuery;
            _new = [_uid] call _ndSelect;
            _ok = (_new isNotEqualTo "") && { _new isNotEqualTo _old };};
        [_uid] call _lockRelease;
        // Audit 2026-09-26 (mints, review): a spend the SERVER saw is the receipt APS_fnc_vehicleCreate needs before
        // it registers an ND-only vehicle (the ND vehicle shop debits here, then sends vehicleCreate separately).
        // One receipt per debit, 120 s life, consumed there. localNamespace, so a client cannot forge one.
        if (_ok) then {
            private _rc = localNamespace getVariable "AP_ndReceipts";
            if (isNil "_rc") then { _rc = createHashMap; localNamespace setVariable ["AP_ndReceipts", _rc]; };
            _rc set [_uid, ((_rc getOrDefault [_uid, []]) select { serverTime - (_x select 1) < 120 }) + [[parseNumber _amt, serverTime]]];
        };
        if (_new isEqualTo "") then { _new = _old; };
        diag_log format ["[LooneyBin][ND] debit -%1 tok %2 %3 -> %4 = %5", _amt, _tok, _uid, ["DENIED", "OK"] select _ok, _new];
        [[_ok, _new, _tok], "AP_fnc_ndResult", _pl, false] spawn AP_fnc_MP;};};
