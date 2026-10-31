/*
    fn_casinoBanConfirm.sqf  (AP_fnc_casinoBanConfirm) -- Casino SELF-EXCLUSION.
    Run from the phone Settings "Casino Ban" row. Confirms, then permanently blocks this player from the
    casino: persists players.casino_banned=1 server-side (APS_fnc_blackJackSRV "ban", UID derived from
    remoteExecutedOwner -- never trusts the client) + flips the client gate var so the Casino app
    disappears from the phone immediately (its {condition} is only evaluated at phone-open, so we
    re-render the phone). The server ALSO enforces the ban in APS_fnc_blackJackSRV (AP_bjBanned), so a
    tampered client that forces the button still cannot deal. Undo is admin-only (loonybot:
    UPDATE players SET casino_banned=0 WHERE playerid=... -> applies on the player's next connect).
*/
if (player getVariable ["AP_casinoBanned", false]) exitWith {
    ["You are already excluded from the casino.","basic"] spawn AP_fnc_handleMessage;};

private _ok = [
    "<t align='center'>This setting is for those who lack self control. If you click ""Ban me"" you will be permanently blocked from using the casino app. You will need an admin to un-do it.</t>",
    "Casino Ban","Ban me","LET IT RIDE"] call BIS_fnc_guiMessage;
if (!_ok) exitWith {};

// apply: optimistic client gate (immediate phone hide) + server-side persist & enforcement
player setVariable ["AP_casinoBanned", true];
[["ban", []], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;
["You've excluded yourself from the casino. An admin can lift it.","info"] spawn AP_fnc_handleMessage;

// The self-exclusion has to make the Casino tile disappear. The native phone
// evaluated app conditions once at open, so this used to close and re-open it;
// the deck re-evaluates every gate on its 2s "phone" push, so dropping the
// Settings dialog is enough and the tile is gone by the next tick.
closeDialog 0;                                            // close the Settings dialog
waitUntil { isNull (findDisplay 2900) };                  // Settings torn down
