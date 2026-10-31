#include "..\..\macro.h"
// LooneyBin: owner-only server-wide News Broadcast. Reuses AP_fnc_broadcast (already client->all
// whitelisted via the death-message path) so no new server fn / CfgRE entry. No rate limit (owner tool).
if ((call AP_adminLevel) < 5) exitWith { ["News Broadcast is owner-only.", "basic"] spawn AP_fnc_handleMessage; };
closeDialog 0;
uiSleep 0.2;
["<t align='center'>Enter the news to broadcast to ALL players.</t>", "News Broadcast", "Send"] call AP_fnc_inputMenu;
private _msg = AP_input_response;
AP_input_response = "";
if (_msg isEqualTo "") exitWith {};
[[[0, 1], format ["SERVER NEWS: %1", _msg]], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
[["-NEWSBROADCAST-", player, profileName, _msg], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[format ["News broadcast sent: %1", _msg], "basic"] spawn AP_fnc_handleMessage;
