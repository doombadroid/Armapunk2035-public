#include "..\..\macro.h"
/*
    AP_fnc_medSupplyEarn — credit the local player (a med-supply crate / revive-drone owner) for a sale.
    Pushed by APS_fnc_medSupplyPay (server) to the owner's client. Money goes to BANK (AP_atmcash).
*/
params [["_amt", 0, [0]]];
// Server-origin guard: APS_fnc_medSupplyPay (server, owner 2) is the only legit caller; this credits
// bank cash, so a local call must not self-award a med-supply sale.
if (remoteExecutedOwner != 2) exitWith {};
if (_amt <= 0) exitWith {};
AP_atmcash = AP_atmcash + _amt;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[0] call AP_fnc_ClupdatePartial;
[format ["Your medical drone sold supplies — earned $%1 (bank).", [_amt] call AP_fnc_numberText], "info"] spawn AP_fnc_handleMessage;
