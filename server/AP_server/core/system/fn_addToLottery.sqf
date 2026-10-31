 
private ["_unit","_ticket","_jackpot"]; 
 
_unit = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
if (isNull _unit) exitWith {}; 
 
// LooneyBin: config table only had 1 row -> select 8 = "Zero divisor", _jackpot undefined, and
// set[8,nil] punched nil holes that made DB_fnc_updateConfig spam "_x undefined" on every ticket.
// DB rows 0-10 now seeded; param + scalar coercion keeps the lottery alive even if config is short.
// 2026-09-26: server-only config (localNamespace, fn_queryConfig); AP_configuration is the client display copy
// and any client can publicVariable over it -- it used to set this jackpot and, through updateConfig, the DB.
private _cfg = localNamespace getVariable ["APS_configuration", []];
_jackpot = _cfg param [8, 25];
if !(_jackpot isEqualType 0) then { _jackpot = (parseNumber format ["%1", _jackpot]) max 25; };
_ticket = floor (random 1000);
 
if (_ticket == 0) then {[[_jackpot * 1000],"AP_fnc_jackpot",_unit,false] spawn AP_fnc_MP;
[777, _unit, format["Won lottery for $%1", [_jackpot * 1000] call AP_fnc_numberText]] call APS_fnc_logIt; 
_jackpot = 25;}
else {[[[0,1,2],"Sorry, try again."],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP;
_jackpot = _jackpot + 1;};
 
_cfg set [8, _jackpot];
localNamespace setVariable ["APS_configuration", _cfg];   // no-op unless config never loaded (then _cfg was the default)
AP_configuration = +_cfg;
publicVariable "AP_configuration";
[] spawn DB_fnc_updateConfig;