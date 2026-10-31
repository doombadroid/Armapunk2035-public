/*
    AP_fnc_uC (LooneyBin compat -- reverse-drift; real impl)
*/
// LooneyBin compat: LoonyBin money helper  ['cash'|'atm','take'|'add'|'set',amount]
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_account","",[""]],["_op","",[""]],["_amount",0,[0]]];
private _ret = true;
// Every other money mutation in the mission refreshes the matching *CacheB next to the write
// (41 cash sites use /4+9, 105 atm sites use /4+11); a server-ordered take through here that did
// not would desync it (house tax, 2026-09-04).
switch (toLower _account) do {case "cash": { switch (toLower _op) do {
        case "take": { if (AP_cash < _amount) exitWith {_ret=false}; AP_cash = AP_cash - _amount; };
        case "add": { AP_cash = AP_cash + _amount; };
        case "set": { AP_cash = _amount; }; };
        AP_cashCacheB = ((AP_cash / 4) + 9); };
    case "atm": { switch (toLower _op) do {
        case "take": { if (AP_atmcash < _amount) exitWith {_ret=false}; AP_atmcash = AP_atmcash - _amount; };
        case "add": { AP_atmcash = AP_atmcash + _amount; };
        case "set": { AP_atmcash = _amount; }; };
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11); };};
_ret
