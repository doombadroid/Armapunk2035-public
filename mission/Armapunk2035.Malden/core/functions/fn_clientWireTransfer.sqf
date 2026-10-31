#include "..\..\macro.h"
// owner 2026-06-23 (#503): REMOVED the receiver-side `scriptAvailable(4)` cooldown. It SILENTLY DROPPED a 2nd/3rd
// wire that arrived within 4s -> sender debited, receiver NEVER credited = money vanished (player099 sent kiosk
// 3x $999,999 in 10s; kiosk got only 2, $999,999 lost). The receiver must NEVER be rate-limited on INCOMING money.
// This fn is already server-gated (remoteExecutedOwner != 2 below = only the server can trigger it), so there's no
// client-spam vector to guard against here.
params[["_val", 0, [0]], ["_from", objNull, [objNull]]];
if (remoteExecutedOwner != 2) exitWith {};
if ((isNull _from) || !(_from in allPlayers)) exitWith {};
if (!alive player || player distance(getMarkerPos "respawn_civilian") < 1000) exitWith {
    ["You cannot conduct wiretransfers while dead. Please try again.", "basic"] spawn AP_fnc_handleMessage;};
if !([str _val] call AP_fnc_isNumber) exitWith {};
if ((name _from) isEqualTo "") exitWith {};
if (_val <= 0) exitWith {};
if (_val > 9999999) exitWith {};
AP_atmcash = (round(AP_atmcash + _val)) max 0;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
[1] call AP_fnc_ClupdatePartial; [
    ["-BANKRECEIVE-", player, (profileName), format["was wiretransfered $%1 from %2 (%3).", [_val] call AP_fnc_numberText, (name _from), (getPlayerUID _from)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
[format["%1 has wire transferred $%2 to you.", (name _from), [_val] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;