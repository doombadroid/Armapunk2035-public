// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckWardrive.sqf  (AP_fnc_cyberdeckWardrive)
    LooneyBin 2026-07-19 (cdfeatures.md #8): Cyberdeck "Wardrive Scan" -- pings nearby hackable targets (locked
    vehicles you don't own, crypto mining rigs, ATMs) as temporary local map markers for ~30s. Purely client-side
    (local markers + local nearestObjects), no server load.
*/
if (!(call AP_fnc_hasDeck)) exitWith { ["You need a Cyberdeck for that.", "basic"] spawn AP_fnc_handleMessage; };
if (diag_tickTime < (missionNamespace getVariable ["AP_wardriveCd", 0])) exitWith {
    ["Wardrive antenna still recharging.", "basic"] spawn AP_fnc_handleMessage;};
AP_wardriveCd = diag_tickTime + 90;

private _radius = if (3 in (player getVariable ["AP_cdMods", []])) then { 700 } else { 350 };   // Signal Amp module doubles range
private _hits = [];   // [pos, "ColorX", "label"]

// locked vehicles you don't own
{if ((locked _x > 1) && {!(_x in AP_vehicles)} && {alive _x}) then {_hits pushBack [getPosATL _x, "ColorBlue", "Locked Vehicle"];};
} forEach (nearestObjects [player, ["Car", "Air", "Ship"], _radius]);

// placed crypto mining rigs (stacked pieces overlap -> reads as one marker)
{if (_x getVariable ["AP_cryptoRig", false]) then {_hits pushBack [getPosATL _x, "ColorOrange", "Mining Rig"];};
} forEach (nearestObjects [player, ["Land_PortableServer_01_olive_F", "Land_PortableServer_01_black_F"], _radius]);

// ATMs
{_hits pushBack [getPosATL _x, "ColorGreen", "ATM"];} forEach (nearestObjects [player, ["Land_Atm_01_F", "Land_Atm_02_F"], _radius]);

if (_hits isEqualTo []) exitWith { ["Wardrive: no hackable targets in range.", "basic"] spawn AP_fnc_handleMessage; };

private _markers = []; {_x params ["_pos", "_col", "_label"];
    private _m = createMarkerLocal [format ["AP_wardrive_%1_%2", round diag_tickTime, _forEachIndex], _pos];
    _m setMarkerTypeLocal "hd_dot";
    _m setMarkerColorLocal _col;
    _m setMarkerTextLocal _label;
    _markers pushBack _m;} forEach _hits;

[format ["<t color='#00e5ff'>WARDRIVE</t> -- %1 target(s) pinged on your map for 30s.", count _hits], "info"] spawn AP_fnc_handleMessage;
[_markers] spawn { params ["_ms"]; uiSleep 30; { deleteMarkerLocal _x; } forEach _ms; };
