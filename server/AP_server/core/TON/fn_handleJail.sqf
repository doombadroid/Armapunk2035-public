/*
    APS_fnc_handleJail  (LooneyBin: send a player to prison) -- runs on the SERVER.
    2020 caller (fn_arrestAction): [_cop, _offender, [_isLaser, _isSkiptracer, _isInterrogate]]
    The old passthrough fed these straight into 2017 AP_fnc_jailSys, which expects
    [_offender, _jailSpawnMarker, _jailReleaseMarker] -- so it read arg#0 = the COP as the offender, looked
    up the cop's (empty) wanted data and ran AP_fnc_jailMe on the COP's client. The actual offender never
    got jailed. Map it right: look up the OFFENDER's wanted entry (jailMe reads index 3 for the bail amount)
    and run jailMe on the OFFENDER's client. jailMe defaults its own markers ("jail_marker2" /
    "jail_release2") and derives the sentence length from the offender's A_stats_crimes.
*/
params [["_cop", objNull, [objNull]], ["_unit", objNull, [objNull]]];
// owner 2026-06-23 SECURITY (security.md §2.2): cop-only. Was gated ONLY by the client UX in fn_arrestAction
// /fn_adminJail -- any civ could remoteExec [objNull, victim] to jail anyone. Derive the REAL caller from the
// non-spoofable remoteExecutedOwner (never the passed _cop object) and require server-set side==west. Server-
// internal (_src==0, e.g. an admin-jail relay) always passes.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
// owner 2026-06-24: allow civ BOUNTY HUNTERS (AP_isBountyHunter) too -- fn_arrestAction calls this for them when
// they bring in a bounty; the cop-only gate was a FALSE POSITIVE that blocked the actual jailing (target never went
// to prison) + spammed -SEC-. west cop OR bounty hunter; block everyone else.
if (_src isNotEqualTo 0 && {!(_caller call APS_fnc_isDutyCop)} && {!(_caller getVariable ["AP_isBountyHunter", false])}) exitWith { ["-SEC-", _caller, format ["BLOCKED handleJail by %1", _callerUID]] call APS_fnc_logIt; };
if (isNull _unit) exitWith {};
// LooneyBin (owner): jailMe reads the BAIL amount from _ret index 3 (the offender's bounty) and DEFAULTS to a
// flat $1500 when _ret is [] (offender not yet in the wanted list). The admin-jail path (fn_adminJail) fires a
// wantedAdd (charge 57 "Admin Jailed", bounty 999999) AND this handleJail in PARALLEL, so wantedPerson here can
// run BEFORE the charge lands -> _ret=[] -> the prisoner bails for $1500 instead of their real bounty. Run in a
// scheduled thread and re-fetch once after a short settle so the bail = the offender's ACTUAL current bounty.
[_unit] spawn {params ["_unit"];
    private _ret = [_unit] call AP_fnc_wantedPerson;   // [name, uid, [crimes], bounty, jail] or []
    if ((_ret isEqualTo []) || {(_ret param [3, 0]) <= 0}) then {uiSleep 1;
        _ret = [_unit] call AP_fnc_wantedPerson;};
    [[_ret], "AP_fnc_jailMe", _unit, false] spawn AP_fnc_MP;};

// LooneyBin: drop standing bounty-hunter bounties on this offender. The cop-arrest / admin-jail path
// (arrestAction / adminJail -> handleJail -> jailMe) bypasses jailPlayer, which was the ONLY place clearing
// bounties on jail -> BH bounties never dropped after an arrest. Server-side mirror of jailPlayer's block.
private _ouid = getPlayerUID _unit;
if (_ouid isNotEqualTo "") then {
    private _bhs = allPlayers select { !(((_x getVariable ["AP_myBounties", []]) findIf { _ouid in _x }) isEqualTo -1) };
    if !(_bhs isEqualTo []) then { [_ouid, false] remoteExec ["AP_fnc_removeBounty", _bhs]; };};
