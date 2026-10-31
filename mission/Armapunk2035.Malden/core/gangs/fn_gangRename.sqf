/*
    fn_gangRename.sqf  (AP_fnc_gangRename)  -- Armapunk 2035 2026-08-14

    Ask the server to rename the player's gang. There was no rename path before
    this; the deck's gang-name field is what asked for one (owner: build it, and
    charge for it -- AP_gangRenameFee comes out of the GANG BANK).

    Everything here is a courtesy check so the player gets an instant, specific
    refusal. APS_fnc_gangRenameSRV re-checks all of it, resolves the caller from
    remoteExecutedOwner and owns the charge.

    Usage:  ["NEW NAME"] call AP_fnc_gangRename;   // true = sent to the server
*/
params [["_name", "", [""]]];

if (AP_gang_data isEqualTo []) exitWith {
    ["You are not in a gang.", "basic"] spawn AP_fnc_handleMessage; false};
if ((AP_gang_data param [2, 5]) isNotEqualTo 1) exitWith {
    ["Only the gang leader can rename the gang.", "basic"] spawn AP_fnc_handleMessage; false};

private _clean = trim _name;
if (count _clean < 3) exitWith {
    ["The minimum character limit for a gang name is 3.", "basic"] spawn AP_fnc_handleMessage; false};
if (count _clean > 25) exitWith {
    ["The maximum character limit for a gang name is 25.", "basic"] spawn AP_fnc_handleMessage; false};
if (_clean isEqualTo (AP_gang_data param [1, ""])) exitWith {
    ["That is already your gang's name.", "basic"] spawn AP_fnc_handleMessage; false};

[[AP_gang_data param [0, -1], _clean], "APS_fnc_gangRenameSRV", 2] spawn AP_fnc_MP;
true
