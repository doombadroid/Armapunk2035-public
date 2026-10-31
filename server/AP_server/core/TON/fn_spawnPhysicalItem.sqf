/*
    APS_fnc_spawnPhysicalItem  (LooneyBin rename layer)  ->  APS_fnc_placeStorage [2017]
    2020 client args : (direct remoteExec — verify call site)
    2017 fn params   : _unit(@0), _item(@1), _house(@2)
    ADAPT (known behaviour drift — passthrough is a stub)
*/
// TODO ADAPT: 2017 APS_fnc_placeStorage differs from what 2020 expects -- align args/return.
_this call APS_fnc_placeStorage;
