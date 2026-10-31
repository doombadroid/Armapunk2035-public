 
private["_unit","_x","_robber","_lastRobbed"]; 
_robber = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
_unit = [_this,1,ObjNull,[ObjNull]] call BIS_fnc_param; 
 
if(isNull _robber OR isNull _unit) exitWith {};  
 
// ArmaQuest "robstore" (The Collection) credit. This file is reached through the CfgRE-whitelisted
// APS_fnc_srvRobStore, so everything in the payload is the client's claim: the robbery itself (dispatch,
// marker) still runs on it, but the quest only counts a robbery the server can stand behind -- robber is
// the caller's own unit, target is not a player, a MaxSec officer is on (the client's own gate, counted
// here; AP_betaZeroCops is the same waiver every server heist gate honours). Untenured on purpose, so the
// _ignoreTenure opt-out in fn_robStoreAction stays right. Read here, in the remote frame, because the
// spawn below has no remoteExecutedOwner.
private _aqCredit = !isPlayer _unit && {_unit isNotEqualTo _robber}
    && {!isRemoteExecuted || {owner _robber isEqualTo remoteExecutedOwner}}
    && {(({_x call APS_fnc_isDutyCop} count allPlayers) > 0) || {localNamespace getVariable ["AP_betaZeroCops", false]}};
 
[_unit,_robber,_aqCredit,getPlayerUID _robber,time] spawn {private["_robSuccess","_x","_i","_unit","_cash","_duration","_dispatch","_aqCredit","_uid","_t0"];
_unit = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
_robber = [_this,1,ObjNull,[ObjNull]] call BIS_fnc_param; 
_aqCredit = _this select 2; _uid = _this select 3; _t0 = _this select 4; 
_robSuccess = true; 
_x = round(random 500); 
_marker = createMarker [format["robMarker%1",_x], position _unit]; 
_marker setMarkerShape "ICON"; 
_marker setMarkerType "mil_dot"; 
_marker setMarkerColor "ColorRed"; 
_marker setMarkerText format["Robbery %1",name _robber]; 
 
_i = 0; 
_unit setVariable["robProgress",true,true]; 
_unit setVariable["lastRobbed",time,true]; 
 
_dispatch = ceil (random 9000); 
[_dispatch, format["Store Robbery (%1)",name _robber], 2500, 4, 2, position _unit, ""] spawn AP_fnc_createDispatch; 
 
while {true} do {if (_i >= 300) exitWith {};
// quest credit only: cuffed or downed is not a robbery that paid (the client pays nothing then either);
// _robSuccess below keeps its legacy dispatch meaning. AP_downed/AP_restrained are the live vars.
if ((_robber getVariable ["AP_restrained", false]) || {_robber getVariable ["AP_downed", false]}) then { _aqCredit = false; }; 
if (!(alive _robber)) exitWith { _robSuccess = false; }; 
if (vehicle _robber != _robber) exitWith { _robSuccess = false; }; 
if (_robber getVariable ["restrained", false]) exitWith { _robSuccess = false; }; 
if ((_robber distance _unit) > 15) exitWith {}; 
_i = _i + 1; 
sleep 1;};
 
[[_dispatch, !_robSuccess],"AP_fnc_finishDispatch",west,false] spawn AP_fnc_MP; 
// ArmaQuest "robstore" (The Collection) is counted HERE, where the server sat the robbery out, not on the
// robber's own word. It follows the client's PAYOUT rule, not _robSuccess: the client pays a robber who drives
// off after the minute, so a vehicle exit still credits (_aqCredit already drops cuffed/downed). 55 s of server
// clock from the remote frame = the client's one-minute minimum less network lag (a count of `sleep 1` ticks
// runs short under scheduler load). One credit per UID per 1800 s, so a forged robbery is no faster than a real
// one: the slot is reserved in isNil so two can't race, and handed back when the fact advanced nothing (no
// Collection held), so a robbery before taking the job doesn't burn it. localNamespace: not publicVariable-able.
if (alive _robber && {_aqCredit} && {time - _t0 >= 55} && {_uid isNotEqualTo ""}) then {
    private _ok = false; private _prev = -1e9;
    isNil {
        private _led = localNamespace getVariable ["APS_aqRobCredit", createHashMap];
        _prev = _led getOrDefault [_uid, -1e9];
        if (diag_tickTime - _prev >= 1800) then { _led set [_uid, diag_tickTime]; _ok = true; };
        localNamespace setVariable ["APS_aqRobCredit", _led];
    };
    // scheduled here, so aqFact returns srvFact's "did anything advance"; The Collection is count = 1.
    if (_ok && {!([_robber, "robstore"] call APS_fnc_aqFact)}) then {
        isNil { (localNamespace getVariable ["APS_aqRobCredit", createHashMap]) set [_uid, _prev]; };
    };
};
 
_unit setVariable["robProgress",false,true]; 
deleteMarker _marker;};