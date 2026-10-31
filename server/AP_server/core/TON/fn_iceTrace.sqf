// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_iceTrace.sqf  (APS_fnc_iceTrace)
    LooneyBin 2026-07-20: ICE TRACE -- the MaxSec counter to the civilian deck (talos.md).

    THE SINGLE AUTHORITY on "was this hack quiet?". Every hack routes through here, and this fn:
      1. reads the hacker's armed Proxy Chain -> if armed, BURNS it and the hack is silent
      2. otherwise traces: every MaxSec officer wearing TAL goggles within range gets a bearing + marker
      3. otherwise lets the caller fire its own alarm (the returned flag)

    Before this existed the proxy was checked ad-hoc in two places and NEVER consumed for house /
    ignition / crypto hacks -- an armed proxy sat unspent forever. One consumer fixes that.

    Returns TRUE when the hack was quiet (proxy burned) -- callers must skip their own MaxSec alert.
      [_hacker, _label, _pos, _fedRobbery] call APS_fnc_iceTrace
*/
params [["_hacker", objNull, [objNull]], ["_label", "ILLEGAL SIGNAL", [""]], ["_pos", [], [[]]], ["_fed", false, [false]]];
if (isNull _hacker) exitWith { false };
if (_pos isEqualTo []) then { _pos = getPosATL _hacker };

private _quiet = _hacker getVariable ["AP_proxyActive", false];

if (_quiet) then {_hacker setVariable ["AP_proxyActive", false, true];        // one hack per charge
    [["<t color='#33ffbb'>PROXY BURNED</t> -- that hack left no trace on the MaxSec net.", "basic"],
        "AP_fnc_handleMessage", _hacker, false, false] spawn AP_fnc_MP;
    ["-CYBERDECK-", _hacker, name _hacker, format ["proxy chain burned on %1 -- no trace", _label]] call APS_fnc_logIt;} else {
    // Trace goes ONLY to officers actually carrying the kit: west + TAL goggles + in range. They get a
    // location and what was hit -- never the hacker's name. They still have to find the person.
    private _cops = allPlayers select {
        (_x call APS_fnc_isDutyCop) && {alive _x} && {(_x distance _pos) < 650} && {(goggles _x) isEqualTo "G_Goggles_VR"}}; {
        [[_pos, _label], "AP_fnc_talTrace", _x, false] spawn AP_fnc_MP;} forEach _cops;
    if !(_cops isEqualTo []) then {
        ["-TALOS-", _hacker, name _hacker, format ["ICE trace fired on %1 -> %2 officer(s) pinged", _label, count _cops]] call APS_fnc_logIt;
    };};

// the Federal breach fires its own robbery event server-side -- gated on the same quiet check
if (_fed && {!_quiet}) then { [_hacker] call APS_fnc_fedRobbery; };

_quiet
