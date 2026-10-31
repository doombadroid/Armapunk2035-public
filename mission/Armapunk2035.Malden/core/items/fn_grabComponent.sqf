/*
    AP_fnc_grabComponent  (client) -- pick a crypto component out of a federal-event hardware case.
*/
params [["_crate", objNull, [objNull]]];
if (isNull _crate) exitWith {};
if ((_crate getVariable ["AP_componentCrate", ""]) isEqualTo "") exitWith {};
[["grab", player, _crate], "APS_fnc_miningSRV", 2] spawn AP_fnc_MP;
