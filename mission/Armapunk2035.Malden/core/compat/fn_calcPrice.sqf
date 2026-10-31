/*
    AP_fnc_calcPrice  (LooneyBin Economy — owner request 2026-06-11)
    Called by server fn_vehicleDelete:  [_type, _basePrice, _qty, _buy] call AP_fnc_calcPrice
    Returns the price the caller passes in, with a light sanity clamp against a tampered client.
    (Was a stub returning 0 -> any vehicleDelete payout was $0.) Personal garage selling uses
    APS_fnc_srvSellVehicle, NOT this path; this just keeps vehicleDelete correct. _qty unused.
*/
params [["_type", "", [""]], ["_basePrice", 0, [0]], ["_qty", 0, [0]], ["_buy", false, [false]]];
(round _basePrice) max 0 min 25000000
