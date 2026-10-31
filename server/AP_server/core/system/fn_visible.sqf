 
_unit = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
_vis = [_this,1,false] call BIS_fnc_param; 
_adminlvl = [_this, 2, 0] call BIS_fnc_param;
// owner 2026-07-24 SECURITY (audit): the ONLY authorisation here was `_adminlvl < 1`, where _adminlvl is
// argument index 2 -- a number supplied by the CALLER. This fn is CfgRE-whitelisted allowedTargets=2, so
// any client could remoteExec it with a 2 and hand itself hideObjectGlobal + allowDamage false, i.e.
// permanent global invisibility AND god mode. Re-query the level from the DB for the NON-SPOOFABLE caller
// (pattern copied from fn_createAdminVeh); server-internal calls (_src == 0) stay trusted. The required
// level is unchanged (>= 1) -- this only makes the existing gate real.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0) then {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", getPlayerUID _caller], 2, true] call DB_fnc_asyncQuery;
    _adminlvl = parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]];};
if(_adminlvl < 1) exitWith { if (_src isNotEqualTo 0) then { ["-SEC-", _caller, format ["BLOCKED visible/godmode by %1", getPlayerUID _caller]] call APS_fnc_logIt; }; };
if(_vis) then {_unit hideObjectGlobal true;
_unit allowDamage false;} else {_unit hideObjectGlobal false;
_unit allowDamage true;};