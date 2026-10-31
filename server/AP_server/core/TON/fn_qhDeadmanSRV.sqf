// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_qhDeadmanSRV.sqf  (APS_fnc_qhDeadmanSRV)
    LooneyBin 2026-07-21: DEAD MAN'S CLUTCH. Called server-side the instant a Chauffeur or Puppet hijack is about
    to take hold. If the would-be victim has the chip equipped, the hijack is severed before it starts and the
    chip is consumed (single-use) -- persisted, so a modified client can't keep it. Returns true if it fired.

      [_victim, _hacker] -> bool
*/
params [["_victim", objNull, [objNull]], ["_hacker", objNull, [objNull]]];
if (isNull _victim) exitWith { false };
private _eq = _victim getVariable ["AP_fwChips", []];
if !("deadman" in _eq) exitWith { false };

// consume chip 110 from owned + equipped, persist to the DB
private _owned = (_victim getVariable ["AP_cdMods", []]) - [110];
_victim setVariable ["AP_cdMods", _owned, true];
_victim setVariable ["AP_fwChips", _eq - ["deadman"], true];
[_victim, [], [110]] spawn APS_fnc_cdModsSave;   // persists the SERVER's copy, never the public var

[["<t color='#33ffbb'>DEAD MAN'S CLUTCH</t> -- it caught the hijack and burned out. Your car stayed yours.", "cyberjackpot"], "AP_fnc_handleMessage", _victim, false, false] spawn AP_fnc_MP;
if (!isNull _hacker) then {
    [["<t color='#ff3b1e'>HIJACK REJECTED</t> -- they were running a Dead Man's Clutch. Your session never took.", "basic"], "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
    ["-QUICKHACK-", _hacker, name _hacker, format ["hijack severed by %1's Dead Man's Clutch", name _victim]] call APS_fnc_logIt;};
true
