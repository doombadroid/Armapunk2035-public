 
private["_ret"]; 
_ret = [_this,0,ObjNull,[ObjNull]] call BIS_fnc_param; 
if(isNull _ret) exitWith {}; 
 
[[localNamespace getVariable "APS_wantedList"],"AP_fnc_wantedList",_ret,false] spawn AP_fnc_MP;