 
_unit = [_this,0,objNull,[objNull]] call BIS_fnc_param;
// owner 2026-06-23 SECURITY (security.md §2.2): cop-only, self-only. Reached from the client via
// APS_fnc_registerMaxTac (fn_maxtacDispatched's "Join MaxTac" action, west-gated client-side) -> a plain `call` here,
// so remoteExecutedOwner is preserved. Ungated, any civ could remoteExec [anyObj] to inject themselves/others
// into the MaxTac deployment roster. Require the real caller (remoteExecutedOwner, non-spoofable) to be a west cop
// registering THEMSELVES; server-internal passes.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {!((_caller call APS_fnc_isDutyCop) && {_unit isEqualTo _caller})}) exitWith { ["-SEC-", _caller, format ["BLOCKED maxtacRegistered by %1", getPlayerUID _caller]] call APS_fnc_logIt; };
if (isNull _unit) exitWith {};
AP_maxtac_active pushBack _unit;