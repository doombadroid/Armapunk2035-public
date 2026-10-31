 
private["_vid","_sp","_pid","_query","_sql","_type"]; 
_vid = [_this,0,-1,[0]] call BIS_fnc_param; 
_pid = [_this,1,"",[""]] call BIS_fnc_param; 
_sp = [_this,2,2500,[0]] call BIS_fnc_param; 
_unit = [_this,3,ObjNull,[ObjNull]] call BIS_fnc_param; 
_type = [_this,4,"",[""]] call BIS_fnc_param; 
 
// Audit 2026-09-26 (mints/srvsys-0-3): the 07-24 hardening below kept the PAYOUT. A client could send any _vid
// (even one that does not exist) with _sp up to calcPrice's $25M clamp; the DELETE matched nothing and the ATM
// credit went out anyway, as often as it liked. There is no legitimate client caller (see NOTE below), so this is
// now OFF THE WIRE: APS_fnc_vehicleDelete is no longer listed in CfgRE.hpp, and anything remote-executed is
// refused here as well, so re-listing it cannot quietly reopen the mint. A server-internal `call` is unaffected.
if (isRemoteExecuted) exitWith {
    ["-SEC-", (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull], format ["BLOCKED remote vehicleDelete (vid %1, price %2, type %3)", _vid, _sp, _type]] call APS_fnc_logIt;
};
if(_vid == -1 OR _pid == "" OR _sp == 0 OR isNull _unit OR _type == "") exitWith {};

// owner 2026-07-24 SECURITY (audit: single call could wipe the vehicles table). Every argument here is
// client-supplied and _pid is a STRING interpolated unescaped into the DELETE below, so a crafted
// _pid (e.g. `' OR '1'='1`) terminated the literal and deleted EVERY row in the table. The payout was
// likewise billed to a client-named _unit. This fn is CfgRE allowedTargets=2.
// NOTE: it currently has NO working legitimate caller -- the only one, fn_gangGarageDestroy:30, passes
// just 3 args, so _unit is objNull and the guard above already exits. It is therefore reachable ONLY by
// a hand-crafted remoteExec. (Superseded 2026-09-26: it IS de-whitelisted now -- see the guard at the top.)
// Hardened rather than de-whitelisted so a future intended use still works:
// the row owner is now the NON-SPOOFABLE caller (never the client's _pid), the caller must be the unit
// being paid, and the uid is quote-stripped before it reaches SQL.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0) then {if (isNull _caller || {_caller isNotEqualTo _unit}) then {
        ["-SEC-", _caller, format ["BLOCKED vehicleDelete billed to another unit (pid arg '%1', vid %2)", _pid, _vid]] call APS_fnc_logIt;
        _vid = -1;   // signal: the TOP-LEVEL guard below exits the function (nested exitWith would only leave this block)
    } else {_pid = getPlayerUID _caller;   // ignore the client's pid entirely -- you may only delete your OWN row
    };};
_pid = (format ["%1", _pid] splitString "\'""") joinString "";   // SQL-escape (security.md 2.3), same idiom as DB_fnc_insertRequest
if (_vid == -1 OR _pid == "") exitWith {};

_query = format["DELETE FROM %3 WHERE id='%1' AND pid='%2'",_vid,_pid,"vehicles"];
[_query] call DB_fnc_asyncQuery;
 
_qty = _type call AP_fnc_getQuantity; 
_sp = [_type,_sp,_qty,false] call AP_fnc_calcPrice; 
 
[[[_sp,_type],{["atm","add",(_this select 0)] call AP_fnc_uC; hint format["You sold that vehicle for $%1",[(_this select 0)] call AP_fnc_numberText];}],"BIS_fnc_call",_unit,false] spawn AP_fnc_MP; 
 
[139, _unit, format["%1 sold %2 for %3", name _unit, _type, [_sp] call AP_fnc_numberText]] spawn APS_fnc_logIt;