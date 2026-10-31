 
private["_unit","_chan","_dispatch","_flush"]; 
_unit = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
_chan = [_this,1,-1,[-1]] call BIS_fnc_param; 
_dispatch = [_this,2,false,[false]] call BIS_fnc_param; 
_flush = [_this,3,false,[false]] call BIS_fnc_param; 
 
if (_flush && _dispatch) exitWith {if ((getPlayerUID _x) in AP_dispatchUsers) then { AP_radio_dispatch radioChannelRemove [_x]; };
AP_radio_dispatch radioChannelAdd [AP_dispatcher]; 
AP_dispatchUsers = [getPlayerUID AP_dispatcher]; 
(AP_dispatcher getVariable ["ownerID", -1]) publicVariableClient "AP_dispatchUsers";};
 
if(isNull _unit) exitWith {}; 
 
if (_dispatch) then { AP_radio_dispatch radioChannelRemove [_unit]; AP_dispatchUsers = AP_dispatchUsers - [getPlayerUID _unit]; } 
else {{_x radioChannelRemove [_unit];} forEach AP_radio_RF;};
 
if(_chan > -1) then {if (_dispatch) then { AP_radio_dispatch radioChannelAdd [_unit]; AP_dispatchUsers pushBack (getPlayerUID _unit); }
else { (AP_radio_RF select _chan) radioChannelAdd [_unit]; };};
 
if (_dispatch) then {
[[[0,2],format["You have been %1 the MaxSec dispatch radio channel!",if (_chan > -1) then { "added to" } else { "removed from" }]],"AP_fnc_broadcast",_unit,false] spawn AP_fnc_MP; 
if (!isNull AP_dispatcher) then {(AP_dispatcher getVariable ["ownerID", -1]) publicVariableClient "AP_dispatchUsers";};};