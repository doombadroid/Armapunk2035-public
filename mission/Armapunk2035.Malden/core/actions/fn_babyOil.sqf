#include "..\..\macro.h"
/*
    AP_fnc_babyOil  (LooneyBin, owner 2026-06-25) -- use a Baby Oil (virtual Y item) on a RESTRAINED player to
    strip them down to their underwear. Runs on the USER's client (the "Cover in Baby Oil" scroll action). Validates
    the target is restrained + close, consumes 1 Baby Oil, then asks the TARGET's own client to do the strip + show
    the message (AP_fnc_babyOilStrip -- a remote unit's own client owns its gear), through APS_fnc_victimSRV,
    which re-checks restrained + range from the server.
*/
params [["_unit", objNull, [objNull]]];
if (isNull _unit || {player isEqualTo _unit} || {!(_unit isKindOf "CAManBase")} || {!(isPlayer _unit)}) exitWith {};
if !(_unit getVariable ["AP_restrained", false]) exitWith {["They need to be restrained first.", "basic"] spawn AP_fnc_handleMessage;};
if (player distance _unit > 5) exitWith {};
if (AP_inv_babyoil < 1) exitWith {["You don't have any Baby Oil.", "basic"] spawn AP_fnc_handleMessage;};
if !([false, "babyoil", 1] call AP_fnc_handleInv) exitWith {};   // consume 1 (false = remove)
[["babyoil", _unit], "APS_fnc_victimSRV", 2] spawn AP_fnc_MP;   // strip + message the target on their own client (via the server)
["You slathered them in baby oil — they're stripped down to their underwear.", "basic"] spawn AP_fnc_handleMessage;
[["-BABYOIL-", player, profileName, format ["baby-oiled %1 (%2) -> stripped to underwear at %3", name _unit, getPlayerUID _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
