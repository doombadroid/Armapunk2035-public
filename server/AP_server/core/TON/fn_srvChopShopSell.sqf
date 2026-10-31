/*
    APS_fnc_srvChopShopSell  (LooneyBin rename layer)  ->  APS_fnc_chopShopSell [2017]
    2020 client args : [player, _vehicle, _price, _price2]
    2017 fn params   : _unit(@0), _vehicle(@1), _price(@2)
    VERIFY (best-guess passthrough; confirm arg order + behaviour)

    owner 2026-06-23 SECURITY (security.md §2.1/2.2/2.3): this is a thin passthrough -- all hardening
    (non-spoofable caller derivation, server-recompute of the chop price, chop-zone gate, SQL escaping)
    lives in APS_fnc_chopShopSell (server/AP_server/core/system/fn_chopShopSell.sqf). remoteExecutedOwner
    is preserved across this plain `call` (same execution context), so the caller-derivation there is valid.
*/
_this call APS_fnc_chopShopSell;
