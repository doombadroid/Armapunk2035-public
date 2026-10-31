/*
    DB_fnc_updateConfig -- SERVER-ONLY: write the server's config array back to the config table.

    2026-09-26: the source is localNamespace APS_configuration (fn_queryConfig), which no client publicVariable
    can reach. It used to be the published AP_configuration, and a client-triggered "AP_configuration" PV
    handler ran this on any broadcast, formatting each element raw into value='%1' (SQL injection into any
    table, republished to every client by fn_queryConfig at the next boot). Now parameterised, and each
    position must still hold the type fn_queryConfig loaded it as, or it is skipped.
    Positions 0..10 map 1:1 to config.index (ORDER BY index); later positions are rows like index 200, never
    written here. Only changed positions are written (APS_configurationLast).
*/
if (!isServer) exitWith {};   // not in CfgRE, so no client can remoteExec it; its callers are server fns
private _cfg  = localNamespace getVariable ["APS_configuration", []];
private _last = localNamespace getVariable ["APS_configurationLast", []];
{   if (_forEachIndex <= 10 && {!isNil "_x"}) then {   // nil hole (short config array) -- skip it, keep going
        private _v = _x;
        private _types = switch (true) do { case (_forEachIndex in [2, 9]): {[true, 0]}; case (_forEachIndex in [0, 1, 4]): {["", 0]}; default {[0]}; };
        if (_v isEqualTypeAny _types && {!(_v isEqualTo (_last param [_forEachIndex, objNull]))}) then {
            if (_forEachIndex in [2, 9]) then { _v = [_v, 0] call DB_fnc_bool; };
            ["UPDATE config SET value = %s WHERE index = %s", 1, false, [format ["%1", _v], _forEachIndex]] call DB_fnc_asyncQuery;};};
} forEach _cfg;
localNamespace setVariable ["APS_configurationLast", +_cfg];
