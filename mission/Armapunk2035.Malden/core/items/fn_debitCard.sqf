params[["_amount", 0, [0]]];
private _success = false;
if (AP_cash >= _amount) then {AP_cash = (round(AP_cash - _amount)) max 0;
    AP_cashCacheB = ((AP_cash / 4) + 9);
    systemChat format["You paid $%1 from cash on hand.", [_amount] call AP_fnc_numberText];
    _success = true;} else {
        // owner 2026-09-02: the debit card item is gone. Every player spends from the bank
        // as if they always carried one; cash on hand is still tried first.
        if (AP_atmcash < _amount) then {
            [format["You do not have $%1 in cash or in your bank account.", [_amount] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
        } else {AP_atmcash = (round(AP_atmcash - _amount)) max 0;
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            systemChat format["You paid $%1 from your bank account.", [_amount] call AP_fnc_numberText];
            _success = true;};
        if (((A_stats_crimes param[0, 0]) > 500) && ((time - AP_last_wanted) > 240)) then {AP_last_wanted = time;
            private _toSend = allPlayers - [allDeadMen] select {
                ((side _x isEqualTo civilian && !(((_x getVariable["AP_myBounties", []]) findIf {getPlayerUID player in _x
                }) isEqualTo - 1)) || side _x isEqualTo west)};
            if !(_toSend isEqualTo[]) then {[
                    [9, profileName, str(A_stats_crimes select 0), player], "AP_fnc_clientMessage", _toSend, false, false] spawn AP_fnc_MP;
            };};
    };
_success;