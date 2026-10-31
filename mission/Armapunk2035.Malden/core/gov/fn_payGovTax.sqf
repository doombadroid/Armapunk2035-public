/*
    AP_fnc_payGovTax  (LooneyBin, owner 2026-06-13)
    Route the GOVERNOR'S cut of a purchase into the treasury (gang 50000), which the governor withdraws via
    the gov bank menu. Call AFTER a purchase commits, passing the item's PRE-TAX base price.
    Only the governor's flat 0-15% is routed -- the progressive wealth "rich tax" in getGovTax stays a sink.
    No-op if there's no sitting governor or the rate is 0.
    Call:  [_basePrice] call AP_fnc_payGovTax;
*/
params [["_base", 0, [0]]];
if ((SRV_governorData param [0, ""]) isEqualTo "") exitWith {};      // no governor seated
private _rate = ((SRV_governorData param [2, 0]) max 0) min 15;
if (_rate <= 0) exitWith {};
private _cut = floor (_base * (_rate / 100));
if (_cut <= 0) exitWith {};
[["addTaxToCache", [_cut]], "APS_fnc_govSystemSRV", 2] spawn AP_fnc_MP;
