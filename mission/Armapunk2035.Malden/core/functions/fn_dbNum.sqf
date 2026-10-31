/*
    fn_dbNum.sqf  (AP_fnc_dbNum)  --  one database integer, as a Number.

    WHY THIS EXISTS. apdb hands the SQF an integer's TYPE based on its
    MAGNITUDE (tools/pysqf_modules/apdb.py, _to_sqf):

        elif isinstance(value, int):
            out = str(value) if abs(value) > _FLOAT_EXACT else value   # 16_777_216

    An SQF number is a 32-bit float, exact only to 16,777,216, so anything past
    that travels as a STRING rather than arrive silently rounded. That rule is
    correct and must stay -- it is what keeps a bank balance from losing money
    on read -- but it means one column has two types depending on the value in
    the row:

        overdue_since = 0            -> Number 0
        overdue_since = 1788088000   -> String "1788088000"

    so `_over > 0` works for every row until the one it was written for, then
    throws "Type String, expected Number" and takes the whole script with it.
    That is how the suite rent sweep died at fn_suiteRentSweep.sqf:64 --
    aborting the loop, the repossession pass, and every tenant after the first
    overdue one (2026-09-04).

    Use this on ANY value read from a query that can exceed 16.7 million:
    epochs, ids, balances-as-integers, timers. Small values pass through
    untouched, so it is safe to wrap a column whose magnitude you are unsure of.

    NOT `parseNumber format ["%1", _v]`. That idiom is elsewhere in this
    codebase and it is a trap: `format` renders a NUMBER >= 1e6 in six
    significant digits ("1.78809e+09"), so wrapping an already-numeric value
    silently mangles it -- the bug that lost a $1M hold'em buy-in on 2026-09-03.
    This only ever calls parseNumber on something that is ALREADY a string.

    PRECISION. parseNumber "1788088000" lands on the nearest float32, which at
    that magnitude is a multiple of 128 -- up to ~64 seconds off. Every consumer
    of these epochs compares them against AP_suiteNow, which was parsed the same
    way, and divides into whole days. Consistent, and 64 seconds does not move a
    10-day clock. Do NOT use this for money: read Decimal columns as strings and
    keep them strings.

    Anything that is neither a Number nor a String (NULL arrives as "" and
    parseNumber "" is 0) returns 0 -- the same fail-closed value every caller
    already defaults to.
*/
params [["_v", 0]];
if (_v isEqualType 0) exitWith { _v };
if (_v isEqualType "") exitWith { parseNumber _v };
0
