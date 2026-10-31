/*
    APS_fnc_bankMove -- the ONE guarded server-side bank movement primitive, both directions.

        [uid, delta, why]                        call APS_fnc_bankMove   ->   [ok, before, after]
        [uid, delta, why, tag, prefix, ctx]      call APS_fnc_bankMove

    delta > 0 credits, delta < 0 debits. Returns [ok, before, after] where `ok` means the read-back
    PROVED the balance moved by exactly `delta`.

    THIS IS fn_holdemSRV.sqf's `_bankMove`, LIFTED VERBATIM. It was written for hold'em (C-2, the money
    spine inversion: the shipped shape granted the seat and then ORDERED the player's own client to debit
    itself, so a client that dropped the order sat down for free and the `log` row was an audit trail of
    INTENT). Its review is signed off, and the duty bounty payoff needs exactly the same guarantees --
    server writes the row, refuse an unbacked debit BEFORE the write, confirm by read-back, one `log` row
    per movement written on CONFIRMATION -- so it is one primitive with two callers rather than two copies
    that can drift. fn_holdemSRV's `_bankMove` is now a three-line forwarder into this file and its
    behaviour is unchanged; see the equivalence note there.

    NOTHING HERE IS A NEW MONEY PRIMITIVE, which was the one thing hold'em's fix was not allowed to invent
    and is not allowed to be invented here either. The write is the shape APS_fnc_gangBank has used for
    server-ordered bank movement since 2026-06-21 (fn_gangBank.sqf:138/141, and identically
    fn_processMailbox.sqf:47, fn_medicSplit.sqf:27):
        UPDATE players SET bankacc = bankacc + N WHERE playerid='<uid>'
    and the read is APS_fnc_adminPlayerQuerySRV's (fn_adminPlayerQuerySRV.sqf:24):
        SELECT bankacc FROM players WHERE playerid='<uid>'
    This pairs those two, signs the write, and confirms it.

    UID-ADDRESSED, AND THAT IS THE WHOLE POINT. There is no unit anywhere in this primitive. A hold'em seat
    whose player disconnected, and an officer paying a bounty off at a terminal, bank by the same path.

    THE DEBIT IS CONDITIONAL IN SQL AS WELL AS IN SQF (`AND bankacc >= N`). The read and the write are two
    round trips and a second debit can land between them; the WHERE clause is what makes the race lose
    rather than overdraw, and the read-back is what makes the loss visible instead of silent.

    Log rows are this function's job, not the caller's, so "one row per movement, written on confirmation"
    is an invariant of the primitive rather than a discipline every call site has to remember.

    THE CALLER'S LOG IDENTITY, in three optional args, and they exist ONLY so hold'em's rows come out
    byte-for-byte as they did before the lift:
      _tag     the APS_fnc_logIt tag            ("-CASINO-HOLDEM-" / "-DUTY-")
      _prefix  the diag_log bracket             ("HOLDEM" -> "[HOLDEM] ...")
      _ctx     extra context appended to `why` in the `log` rows only, never in the diag_log lines.
               STRING for a constant, or CODE evaluated AT EACH LOG SITE -- hold'em's rows carry
               `hand #<n>` read from the live table at the moment the row is composed, and this function
               suspends across up to three DB round trips, so a hand that advances mid-movement has to be
               able to change the answer exactly as it did when the closure was inline. A precomputed
               string would freeze it at call time and that is NOT the same function.
               The CODE form resolves its own privates up the SQF call stack (the same mechanism by which
               the inline closure could see hold'em's `_T` and `_san` at all), which is why every private
               in this file is `_bm`-prefixed: a bare `_T` or `_why` here would shadow the caller's.
*/
params [["_bmUid", "", [""]], ["_bmDelta", 0, [0]], ["_bmWhy", "", [""]],
        ["_bmTag", "-BANK-", [""]], ["_bmPrefix", "BANK", [""]], ["_bmCtx", "", ["", {}]]];

// `why` as the `log` rows spell it: the caller's reason plus its context, resolved HERE and not before.
private _bmFncWhy = {
    private _bmC = if (_bmCtx isEqualType {}) then { format ["%1", call _bmCtx] } else { _bmCtx };
    if (_bmC isEqualTo "") then { _bmWhy } else { format ["%1, %2", _bmWhy, _bmC] }
};

// params' own type filter on _bmDelta (line above) already turned any non-Number into the default 0 --
// silently, and indistinguishable from a caller that genuinely meant $0 -- so a bad type used to fall
// straight into the exitWith below and come back [true, 0, 0], a false "ok". This is the one place the
// header's "LIFTED VERBATIM" claim wasn't literally true: the original inline `_bankMove` had no params
// type filter and would have thrown on a non-Number delta instead of laundering it into a silent success.
// Checked against the RAW second arg, not _bmDelta, because params has already filtered that one by the
// time execution reaches here.
private _bmRawDelta = _this param [1, 0];
if (!(_bmRawDelta isEqualType 0)) exitWith {
    diag_log format ["[%1] !! bank move delta for %2 (%3) is not a Number (got %4) -- refused", _bmPrefix, _bmUid, _bmWhy, typeName _bmRawDelta];
    [_bmTag, _bmUid, format ["FAILED bad delta type %1: %2", typeName _bmRawDelta, call _bmFncWhy]] call APS_fnc_logIt;
    [false, 0, 0]
};

private _bmAmt = round _bmDelta;
if (_bmAmt isEqualTo 0) exitWith { [true, 0, 0] };
if (_bmUid isEqualTo "") exitWith {
    diag_log format ["[%1] !! bank move $%2 (%3) has no uid -- refused", _bmPrefix, _bmAmt, _bmWhy];
    [_bmTag, objNull, format ["FAILED $%1 (%2): no uid", abs _bmAmt, call _bmFncWhy]] call APS_fnc_logIt;
    [false, 0, 0]
};
private _bmSan = { (format ["%1", _this]) splitString "\'""" joinString "" };   // APS_fnc_casinoSRV's, verbatim
private _bmSafe = _bmUid call _bmSan;                        // SQLi guard; a real Steam64 is digits, so a no-op for them
private _bmN = (abs _bmAmt) call DB_fnc_numberSafe;          // M-7: every money interpolation goes through it, digits only
private _bmDir = if (_bmAmt > 0) then { "CREDIT" } else { "DEBIT" };
private _bmRead = format ["SELECT bankacc FROM players WHERE playerid='%1'", _bmSafe];
// NUMBERS COME BACK AS NUMBERS -- never through `parseNumber format ["%1", n]` (owner 2026-09-03, hold'em
// "isn't taking money from the bank"). SQF prints a Number with SIX significant digits, so that round trip
// turned 1,765,349 into "1.76535e+06" = 1,765,350 and the read-back "disagreed" by a dollar: the debit had
// landed, the seat was refused, the player was out $1,000,000. Every balance over $999,999 was exposed.
private _bmNum = { params ["_v"]; if (_v isEqualType 0) then { _v } else { if (_v isEqualType "") then { parseNumber _v } else { 0 } } };
private _bmBefore = (([_bmRead, 2] call DB_fnc_asyncQuery) param [0, 0]) call _bmNum;

// Refused before the write, so an unbacked movement moves nothing at all -- not a debit that gets floored,
// not a row that has to be reconciled later. Nothing happened.
if (_bmAmt < 0 && {_bmBefore < (abs _bmAmt)}) exitWith {
    diag_log format ["[%1] debit $%2 refused for %3 (%4): bank $%5", _bmPrefix, abs _bmAmt, _bmUid, _bmWhy, _bmBefore];
    [false, _bmBefore, _bmBefore]
};

private _bmSql = if (_bmAmt > 0) then {
    format ["UPDATE players SET bankacc = bankacc + %1 WHERE playerid='%2' RETURNING bankacc", _bmN, _bmSafe]
} else {
    format ["UPDATE players SET bankacc = bankacc - %1 WHERE playerid='%2' AND bankacc >= %1 RETURNING bankacc", _bmN, _bmSafe]
};
// CONFIRMED BY THE DATABASE, NOT BY ARITHMETIC (owner 2026-09-03). DB_fnc_asyncExec answers with the row
// count the UPDATE hit -- 1 = the guarded write applied, 0 = the `bankacc >= N` guard refused it (a
// concurrent debit won the race; nothing moved) -- and RETURNING hands back the balance it wrote. The
// old shape re-SELECTed and compared floats: SQF Numbers are 32-bit, so above $16.7M a balance cannot
// even hold every dollar, and the six-digit print above made it worse. A row count has no precision.
private _bmRes = [_bmSql, []] call DB_fnc_asyncExec;
private _bmHit = (_bmRes param [0, 0]) isEqualTo 1 && {(_bmRes param [1, 0]) isEqualTo 1};
private _bmFirst = (_bmRes param [2, []]) param [0, []];
private _bmAfter = if (_bmHit) then {
    (if (_bmFirst isEqualType []) then { _bmFirst param [0, _bmBefore + _bmAmt] } else { _bmFirst }) call _bmNum
} else { _bmBefore };
private _bmOk = _bmHit;

if (_bmOk) then {
    [_bmTag, _bmUid, format ["%1 $%2 (%3) bank $%4 -> $%5", _bmDir, abs _bmAmt, call _bmFncWhy, _bmBefore, _bmAfter]] call APS_fnc_logIt;
    // DISPLAY SYNC, HERE AND NOWHERE ELSE (owner 2026-09-03, "hold'em isn't taking money from the bank").
    // AP_atmcash is the client's cached copy of the row just written. Hold'em's credits moved it behind
    // this primitive; its buy-in called the primitive directly and did not, and the duty payoff never
    // did either. A cache that is not moved shows the old balance AND is what the client's next absolute
    // save (ATM, periodic) writes back over the row -- the buy-in was debited and then silently refunded.
    // So the primitive moves the cache itself, for whichever of its callers moved the money, addressed by
    // the uid the money moved on: an offline player has no cache to move and reads the row at login.
    // AP_fnc_holdemCash is the owner-2-gated cache mover (it does not save; the client's own cycle does).
    private _bmUnit = (allPlayers select { (getPlayerUID _x) isEqualTo _bmUid }) param [0, objNull];
    if (!isNull _bmUnit) then { [[_bmAmt, _bmWhy], "AP_fnc_holdemCash", _bmUnit, false] spawn AP_fnc_MP; };
} else {
    if ((_bmRes param [0, 0]) isEqualTo 1) exitWith {
        // the guard refused: the row was drained between the pre-read and the write. Nothing moved.
        diag_log format ["[%1] debit $%2 refused by the row guard for %3 (%4): bank read $%5 a moment earlier", _bmPrefix, abs _bmAmt, _bmUid, _bmWhy, _bmBefore];
        [false, _bmBefore, _bmBefore]
    };
    // NOT a silent drop and NOT a retry: a second attempt is how a credit becomes a double credit when the
    // first one actually landed and only the read-back was late. The row is the deliverable -- it names the
    // uid, the amount and both balances, so a human can settle it.
    diag_log format ["[%1] !! bank move UNCONFIRMED %2 $%3 for %4 (%5): $%6 -> $%7", _bmPrefix, _bmDir, abs _bmAmt, _bmUid, _bmWhy, _bmBefore, _bmAfter];
    [_bmTag, _bmUid, format ["UNCONFIRMED %1 $%2 (%3) bank $%4 -> $%5 -- expected $%6", _bmDir, abs _bmAmt, call _bmFncWhy, _bmBefore, _bmAfter, _bmBefore + _bmAmt]] call APS_fnc_logIt;
};
[_bmOk, _bmBefore, _bmAfter]
