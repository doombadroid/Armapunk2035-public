/*
    File: fn_casinoReceive.sqf  (AP_fnc_casinoReceive)  -- LooneyBin Casino, generic payout credit.
    Receiver half of APS_fnc_casinoSRV (Coin Flip / Wheel / Slots / Roulette / Hi-Lo). Runs on the
    betting player's client when the SERVER settles a game and credits the total RETURN to BANK.
    Server-initiated only (CfgRE allowedTargets=1). Game-agnostic -- it just moves money; the table
    result is drawn by AP_fnc_casino. Mirror of AP_fnc_blackJackReceive. Args: [_return]
*/
params [["_return", 0, [0]]];
// Server-origin gate: APS_fnc_casinoSRV (server, owner 2) is the ONLY legit caller. Credits bank cash,
// so a local / non-server call must never self-award a payout (mirrors AP_fnc_blackJackReceive).
if (remoteExecutedOwner != 2) exitWith {};
if (_return <= 0) exitWith {};

AP_atmcash = AP_atmcash + _return;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial;
