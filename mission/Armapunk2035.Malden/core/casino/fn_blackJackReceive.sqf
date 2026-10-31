/*
    File: fn_blackJackReceive.sqf  (LooneyBin -- Casino phone app, blackjack)
    Receiver half of APS_fnc_blackJackSRV. Runs on the betting player's client when the SERVER settles a
    blackjack game and credits the total RETURN (bet back + winnings) to BANK. Server-initiated only (not
    in the CfgRemoteExec whitelist -- the server is exempt from mode=1). The table result is shown by the
    render path (AP_fnc_blackJack); this fn only moves money. Args: [_return]
*/
params [["_return", 0, [0]]];
// Server-origin gate: APS_fnc_blackJackSRV (server, owner 2) is the ONLY legit caller. Credits bank cash,
// so a local / non-server call must never self-award a payout (mirrors AP_fnc_copSplitReceive).
if (remoteExecutedOwner != 2) exitWith {};
if (_return <= 0) exitWith {};

private _before = AP_atmcash;
AP_atmcash = AP_atmcash + _return;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial;
["credit", _return, _before] call AP_fnc_bjLedgerNote;
