// extDB3 (LooneyBin): config rows -> AP_configuration
private ["_query","_ret"];

_query = "SELECT value FROM config ORDER BY index";
_ret = [_query,2,true] call DB_fnc_asyncQuery;
if !(_ret isEqualTo []) then {
    for "_i" from 0 to ((count _ret) - 1) do   // LooneyBin: was hardcoded 0..10; the config table has fewer rows -> select out-of-range -> "Zero divisor" boot spam. Bound to actual row count.
    {if (typeName (_ret select _i) == "ARRAY") then { _ret set [_i, (_ret select _i) select 0] };
        switch (_i) do {case 9;
            case 2: { _ret set [_i, [format ["%1", _ret select _i], 1] call DB_fnc_bool] };
            case 3;
            case 5;
            case 6;
            case 7;
            case 10;
            // extDB3 auto-types numeric-looking text -> value may ALREADY be a number ("parsenumber:
            // Type Number" boot error after the config seed). Coerce via format either way.
            case 8: { _ret set [_i, parseNumber format ["%1", _ret select _i]] };};};};

// 2026-09-26: the server reads and writes its config ONLY through localNamespace (no client publicVariable can
// reach it); AP_configuration is the display copy clients read (lottery jackpot in fn_lottoTix).
localNamespace setVariable ["APS_configuration", _ret];
localNamespace setVariable ["APS_configurationLast", +_ret];   // DB_fnc_updateConfig writes only what changed
AP_configuration = +_ret;
publicVariable "AP_configuration";
