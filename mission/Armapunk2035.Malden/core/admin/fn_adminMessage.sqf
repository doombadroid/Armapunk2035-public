#include "..\..\macro.h"
/*
    AP_fnc_adminMessage  (LooneyBin: admin -> ALL players message)
    The display side (clientMessage / handleMessage "adminall") existed, but nothing ever SENT it
    (deobf gap -- clientMessage type 5 had no caller). This wires the send: prompt the admin, then
    broadcast through AP_fnc_broadcast (client->all, already CfgRE-whitelisted via the death-message
    path) using new broadcast type 3 -> handleMessage "adminall" (big red box + ping). Staff-gated.
*/
if ((call AP_adminLevel) < 2) exitWith { ["Admin Message is staff-only.", "basic"] spawn AP_fnc_handleMessage; };
closeDialog 0;
uiSleep 0.2;
["<t align='center'>Enter the message to send to ALL players.</t>", "Admin Message", "Send"] call AP_fnc_inputMenu;
private _msg = AP_input_response;
AP_input_response = "";
if (_msg isEqualTo "") exitWith {};
[[profileName, _msg], "APS_fnc_adminMsg", 2] spawn AP_fnc_MP;   // server relays it as a privileged "Admin Message" (server-origin -> passes handleMessage's adminall anti-spoof gate; client broadcast would be blocked/spoofable)
[format ["Admin message sent to all players: %1", _msg], "basic"] spawn AP_fnc_handleMessage;
