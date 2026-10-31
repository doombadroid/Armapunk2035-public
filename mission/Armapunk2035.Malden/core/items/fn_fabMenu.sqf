params [["_anchor", objNull, [objNull]]];
/*
    AP_fnc_fabMenu -- open the Fabricator on the printer the player is standing at.

    Everything in here is ADVISORY. The list, the affordability colours and the greyed-out Print
    button exist so the player is told why something will not work before they try it; not one of
    them is a gate. APS_fnc_fabSRV re-reads the recipe, the level, the schematic, the tier cap and
    the proximity from its own copies and refuses on its own terms. That split is the whole point:
    the system this was ported from did all of this on the client and then told the server what to
    store.
*/
if (isNull _anchor) then { _anchor = call AP_fnc_fabNear; };
if (isNull _anchor) exitWith { ["No fabricator here.", "basic"] spawn AP_fnc_handleMessage; };
if (!isNull (findDisplay 1810)) exitWith {};

AP_fabAnchor = _anchor;
AP_fabJobs = [];
AP_fabMode = "print";   // always open on the machine, never on the shop
AP_fabRowCache = [];    // schematics learned since the last open change what belongs in the list

// Ask the server for this machine's state before drawing anything -- the job in it, and how long
// is left, are facts only the database has. A house the player has keys to is enough; the server
// checks that too.
private _house = ((nearestObjects [_anchor, ["House_F", "Land_i_Shed_Ind_F"], 12]) select { !isObjectHidden _x }) param [0, objNull];
AP_fabListReady = false;
if (!isNull _house) then {
    [["list", [player, _house]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
};

// DECK ROUTE (UI overhaul 2026-08-26): the machine opens as the deck FABRICATOR
// app. The list request above has already gone out, so the job panel warms via
// AP_fnc_fabReceive's push. Native dialog 1810 is the AP_deckApps=false fallback.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["Fabricator", _anchor] call AP_fnc_deckOpenApp;
};
["AP_fab_menu"] call AP_fnc_createDialog;
disableSerialization;
waitUntil { !isNull (findDisplay 1810) };

private _tier = _anchor getVariable ["AP_fabTier", 1];
private _cfg = ["tier", _tier] call AP_fnc_fabCfg;
((findDisplay 1810) displayCtrl 1811) ctrlSetText (_cfg param [5, "Fabricator"]);

[] call AP_fnc_fabMenuFill;
[] call AP_fnc_fabJobFill;
