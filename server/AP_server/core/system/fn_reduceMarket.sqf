 
// LooneyBin 2026-06-12: SUPERSEDED by APS_fnc_marketTick, which owns the (now two-sided) demand
// index + autonomous drift/events. Left as a no-op so the turf-loop call + CfgFunctions reg stay valid.
if (true) exitWith {};
private ["_x","_i","_toReduce"];

_toReduce = [];

for "_i" from 0 to ((count AP_price_index) - 1) do {_x = AP_price_index select _i;
_value = _x select 1;
// LooneyBin dynamic market: recover ANY good that has accumulated sell-pressure (was limited to
// the hardcoded _toReduce list, which left player-sold goods outside it stuck at a crashed price).
if (_value isEqualType 0 && {_value > 0}) then {_demand = (_x select 0) call AP_fnc_itemDemand;
_percent = (_value * 50) / _demand;  
if (_percent > 70) then { _percent = 70; }; 
if (_percent < 30) then { _percent = 30; }; 
_value = floor (_value - (_value * (_percent / 100))); 
_x set [1, _value];  
AP_price_index set [_i, _x];};};
 
publicVariable "AP_price_index";