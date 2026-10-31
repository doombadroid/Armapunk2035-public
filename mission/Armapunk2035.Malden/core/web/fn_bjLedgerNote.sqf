/*
    fn_bjLedgerNote.sqf — one line in the blackjack ledger. See AP_fnc_bjLedger.

    Called with the bank reading taken BEFORE the change, so the line can show the
    move rather than just the result -- a debit that silently did not happen is
    then a bank delta of zero next to a non-zero amount, which is the whole point.

        [_what, _amount, _bankBefore] call AP_fnc_bjLedgerNote;
    _amount is signed: negative is money leaving the player.
*/

params [["_what", "", [""]], ["_amt", 0, [0]], ["_before", 0, [0]]];
if !(missionNamespace getVariable ["AP_bjLedgerOn", false]) exitWith {};

if (isNil "AP_bjLedgerW") then { AP_bjLedgerW = 0; AP_bjLedgerR = 0; };
if (_amt < 0) then { AP_bjLedgerW = AP_bjLedgerW + (abs _amt) } else { AP_bjLedgerR = AP_bjLedgerR + _amt };

private _delta = AP_atmcash - _before;
private _flag = if (_delta isEqualTo _amt) then { "" } else { format ["   <<< DRIFT: bank moved %1, expected %2", _delta, _amt] };
diag_log format ["[BJLEDGER] %1 %2  bank %3 -> %4  W=%5 R=%6%7",
    _what, _amt, _before, AP_atmcash, AP_bjLedgerW, AP_bjLedgerR, _flag];

if (_amt > 0) then {
    diag_log format ["[BJLEDGER] --- round net %1 (wagered %2, returned %3)",
        AP_bjLedgerR - AP_bjLedgerW, AP_bjLedgerW, AP_bjLedgerR];
};
