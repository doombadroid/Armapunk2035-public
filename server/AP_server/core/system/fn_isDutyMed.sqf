/*
    APS_fnc_isDutyMed -- the Trauma Team half of APS_fnc_isDutyCop. Same shape, same reasoning, same
    pre-flip compatibility clause; read that file's header for why each part is there.

        [unit] call APS_fnc_isDutyMed   ->   true / false

    Kept as its own function rather than a faction argument because every call site reads as a predicate
    and a `[_caller, "maxsec"] call APS_fnc_isDutyFaction` at 38 gates is harder to scan for correctness
    than a name that says which faction it is. There is no server-side medic authority gate today (the
    grep that produced this PR's gate table found none), so this exists for PR6+ and for symmetry: a
    Trauma Team gate that appears later must not be tempted to re-derive the roster test by hand.
*/
params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith { false };
if !(localNamespace getVariable ["AP_dutyEnabled", false]) exitWith { (side _unit) isEqualTo independent };   // localNamespace: the network cannot write it (Lsec-0-1)

((side _unit) isEqualTo independent) && {((_unit call APS_fnc_dutyLookup) param [0, ""]) isEqualTo "trauma"}
