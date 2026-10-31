 
private["_unit","_ret"];
_unit = [_this,0,Objnull,[Objnull]] call BIS_fnc_param;
_jailSpawn = [_this,1,"",[""]] call BIS_fnc_param;
_jailRelease = [_this,2,"",[""]] call BIS_fnc_param;
// owner 2026-06-23 SECURITY (security.md §2.2): self-only. Only caller = fn_jailPlayer (a civ turning THEMSELVES
// in -- passes `player` as arg0), so a stray/malicious [objNull, victim] could run AP_fnc_jailMe on anyone.
// Require the jailed unit to BE the real caller (remoteExecutedOwner, non-spoofable); server-internal passes.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {!(_unit isEqualTo _caller)}) exitWith { ["-SEC-", _caller, format ["BLOCKED jailSys by %1 on %2", getPlayerUID _caller, getPlayerUID _unit]] call APS_fnc_logIt; };
if(isNull _unit) exitWith {};
_ret = [_unit] call AP_fnc_wantedPerson; 
[[_ret,_jailSpawn,_jailRelease],"AP_fnc_jailMe",_unit,false] spawn AP_fnc_MP; 
