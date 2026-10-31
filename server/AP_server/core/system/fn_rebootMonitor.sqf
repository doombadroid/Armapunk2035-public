 
private["_shell","_bootTime","_bootString","_callUser"]; 
_callUser = [_this,0,objNull,[objNull]] call BIS_fnc_param; 
 
if (AP_isRebooting) exitWith{ 
[[1,"The server is already running a restart sequence and will ignore your request."],"AP_fnc_broadcast",_callUser,false] spawn AP_fnc_MP; 
[["The server is already running a restart sequence and will ignore your request."],"AP_fnc_localChatMessage",_callUser,false] spawn AP_fnc_MP; 
}; 
AP_isRebooting = true; 
 
_bootString = "<t align='center' size='2' color='#ff0000'>Server Maintenance</t><br />The server will reboot for maintenance in <t underline='true'>%1 minute(s)</t>! We recommend that you press Y and click ""SYNC DATA"".  Reboot lasts less than a minute."; 
[[1, format[_bootString, 30]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 30]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 300; 
[[1, format[_bootString, 25]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 25]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 300; 
[[1, format[_bootString, 20]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 20]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 300; 
[[1, format[_bootString, 15]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 15]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 300; 
[[1, format[_bootString, 10]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 10]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 300; 
[[1, format[_bootString, 5]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 5]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 240; 
[[1, format[_bootString, 1]],"AP_fnc_broadcast",nil,false] spawn AP_fnc_MP; 
[[format["Server Maintenance: The server will reboot for maintenance in %1 minute(s)! We recommend that you press Y and click ""SYNC DATA"". Reboot lasts less than a minute.", 1]],"AP_fnc_localChatMessage",true,false] spawn AP_fnc_MP; 
sleep 45; 
 
AP_shuttingDown = true; 
publicVariableServer "AP_shuttingDown"; 
 
if (isServer && AP_UsingHeadless) then {[[],"DB_fnc_saveVehicles", HC1, false] spawn BIS_fnc_MP;}
else {_hand = [] spawn DB_fnc_saveVehicles;};
sleep 35; 
 
[] call APS_fnc_doRestart;