/*
    APS_fnc_checkPlayer  (LooneyBin rename layer)  ->  APS_fnc_getGuid [2017]
    2020 client args : (direct remoteExec — verify call site)
    2017 fn params   : _uid(@0)
    ADAPT (known behaviour drift — passthrough is a stub)
*/
// TODO ADAPT: 2017 APS_fnc_getGuid differs from what 2020 expects -- align args/return.
_this call APS_fnc_getGuid;
