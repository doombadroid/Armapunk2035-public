/*
    AP_fnc_removeFiringPin  (LooneyBin, owner 2026-06-11)
    MaxSec (all ranks) scroll option on a RESTRAINED civilian -> disables their weapons ("firing pin removed").
    Runs on the COP. Validates, then tells the suspect's machine to break their guns (AP_fnc_breakGuns).
    The civ repairs it themselves via "Fix Firing Pin" (only while UNRESTRAINED, 60s) -- see fn_fixFiringPin.
*/
params [["_civ", objNull, [objNull]]];
if (isNull _civ || {!isPlayer _civ} || {!(side _civ isEqualTo civilian)}) exitWith {};
if !(_civ getVariable ["AP_restrained", false]) exitWith {
    ["The suspect has to be in restraints first.", "basic"] spawn AP_fnc_handleMessage;};
if (_civ getVariable ["AP_gunBroken", false]) exitWith {
    ["This suspect's firing pin is already removed.", "basic"] spawn AP_fnc_handleMessage;};
if ((player distance _civ) > 5) exitWith {};
[["firingpin", _civ], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;   // server re-checks, runs AP_fnc_breakGuns on the suspect's client (their weapons are local there)
[["-FIRINGPIN-", _civ, name _civ, format ["firing pin REMOVED by MaxSec %1 (%2)", profileName, getPlayerUID player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[format ["You removed %1's firing pin -- their weapons are disabled until they repair it.", [name _civ] call AP_fnc_cleanName], "basic"] spawn AP_fnc_handleMessage;
