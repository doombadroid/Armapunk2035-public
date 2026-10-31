/*
    AP_fnc_fabJobFill -- draw the machine panel: every slot on this printer and what is in it.

    AP_fabJobs is whatever the server last pushed (AP_fnc_fabReceive), one entry per printer:

        [printerId, tier, slots, [[jobId, recipe, qty, remainingSeconds, ready], ...]]

    DISPLAY DATA ONLY. The remaining time is a snapshot taken when the server built the row and
    "ready" is its answer at that instant. Neither is re-derived here and neither is trusted on the
    way back -- the server recomputes both from the database on every collect, so a client that
    edits this array into all-ready gets a refusal rather than an item.
*/
disableSerialization;
private _d = findDisplay 1810;
if (isNull _d) exitWith {};
private _panel = _d displayCtrl 1861;
lbClear _panel;

private _id = (missionNamespace getVariable ["AP_fabAnchor", objNull]) getVariable ["AP_fabId", -1];
private _me = (missionNamespace getVariable ["AP_fabJobs", []]) param [
    (missionNamespace getVariable ["AP_fabJobs", []]) findIf { (_x select 0) isEqualTo _id }, []];
private _slots = _me param [2, 1];
private _jobs = _me param [3, []];
private _ready = false;

{
    _x params ["", "_recipe", "_qty", "_remaining", "_isReady"];
    private _name = if ((["getItemRow", _recipe] call AP_fnc_virtItemCfg) isNotEqualTo []) then {
        ["getName", _recipe] call AP_fnc_virtItemCfg
    } else {
        private _n = [configFile >> "CfgWeapons" >> _recipe] call BIS_fnc_displayName;
        if (_n isEqualTo "") then { _n = [configFile >> "CfgVehicles" >> _recipe] call BIS_fnc_displayName; };
        if (_n isEqualTo "") then { _n = [configFile >> "CfgMagazines" >> _recipe] call BIS_fnc_displayName; };
        if (_n isEqualTo "") then { _recipe } else { _n }
    };
    private _i = _panel lbAdd (if (_isReady) then { format ["READY:  %1 x %2", _qty, _name] }
                               else { format ["%1 x %2  -  %3 min left", _qty, _name, (_remaining / 60) toFixed 1] });
    _panel lbSetColor [_i, if (_isReady) then {[0.33, 0.85, 0.55, 1]} else {[0.35, 0.72, 0.86, 1]}];
    if (_isReady) then { _ready = true; };
} forEach _jobs;

// Show the empty slots too. A machine that says "2 of 3 slots free" is a machine whose tier is
// legible without a tooltip; one that just lists two jobs is not.
for "_i" from (count _jobs) to (_slots - 1) do {
    private _k = _panel lbAdd "-- slot free --";
    _panel lbSetColor [_k, [0.72, 0.75, 0.78, 0.45]];
};

ctrlEnable [1831, _ready];
