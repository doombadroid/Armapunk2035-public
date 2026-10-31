/*
    fn_bjLedger.sqf — prove where the money went at DEALERBOT'S TABLE.

    Blackjack is the one table where the client moves money in three places -- the
    bet, the double, the split -- and the server moves it back in one. If any of
    those four is wrong the balance drifts quietly, and "I think my bank is not
    updating" is impossible to settle by watching a number that was, in fact,
    never being repainted (see fn_bjTable: the header froze at open).

    So this keeps its own books. Every debit and every credit is stamped with the
    bank before and after, and a running wagered/returned pair, into the RPT:

        [BJLEDGER] bet      -500000  bank 4500000 -> 4000000  W=500000 R=0
        [BJLEDGER] double   -500000  bank 4000000 -> 3500000  W=1000000 R=0
        [BJLEDGER] credit  +2000000  bank 3500000 -> 5500000  W=1000000 R=2000000
        [BJLEDGER] --- round net +1000000 (wagered 1000000, returned 2000000)

    A drift shows up as a bank delta that does not match the amount on the line;
    a missing debit shows up as a round whose wagered total is short of the bets
    the table logged server-side. Both are then one grep apart.

        [] call AP_fnc_bjLedger;          toggle
        [true] call AP_fnc_bjLedger;      on
        ["reset"] call AP_fnc_bjLedger;   zero the running totals

    Off by default -- it is a debugging instrument, not telemetry.
*/

params [["_arg", -1, [false, 0, ""]]];

if (_arg isEqualTo "reset") exitWith {
    AP_bjLedgerW = 0; AP_bjLedgerR = 0;
    diag_log "[BJLEDGER] totals reset";
    true
};

private _on = if (_arg isEqualType false) then { _arg } else { !(missionNamespace getVariable ["AP_bjLedgerOn", false]) };
AP_bjLedgerOn = _on;
if (isNil "AP_bjLedgerW") then { AP_bjLedgerW = 0; AP_bjLedgerR = 0; };
diag_log format ["[BJLEDGER] %1 -- bank now %2", if (_on) then {"ON"} else {"off"}, AP_atmcash];
_on
