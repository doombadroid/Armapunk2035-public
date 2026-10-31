/*
    AP_fnc_alamoFed -- start an Alamo Fed on the Reserve's centre building.

    The second, bigger score, and only for a crew that already holds the ground: it needs the dome
    open (phase 3), and it runs a twenty-minute clock on top of a robbery that is already live and
    already has MaxSec driving at it. What it buys is ten more bars in the centre and the getaway
    boat.
*/
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need ICEBREAKER firmware for this."] call AP_fnc_broadcast};

private _state = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
if ((_state param [0, 0]) isNotEqualTo 3) exitWith {
    [2, "Open the Reserve vault first."] call AP_fnc_broadcast};
if ((_state param [2, 0]) isNotEqualTo 0) exitWith {
    [2, "An Alamo Fed is already running."] call AP_fnc_broadcast};
if (isNull AP_fedCentre || {(player distance AP_fedCentre) > 12}) exitWith {
    [2, "You are not at the centre building."] call AP_fnc_broadcast};
// owner 2026-07-28: the deck cooldown, matching fn_openVault. This runs the SAME difficulty-3 terminal
// trace the dome breach does, but a failed trace here set no cooldown and this function never checked
// one -- so Alamo retries were free and a caught hacker could simply re-run the minigame until it
// landed. Both halves are needed: setting AP_fedHackCooldown without reading it would only have
// throttled the dome, and reading it without setting it would only have inherited the dome's.
if (!isNil "AP_fedHackCooldown" && {AP_fedHackCooldown > serverTime}) exitWith {
    [2, format ["Your deck is still cooling down -- %1s left.", ceil (AP_fedHackCooldown - serverTime)]] call AP_fnc_broadcast};

AP_action_in_use = true;
private _r = [3] call AP_fnc_cyberdeckTerm;
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {AP_fedHackCooldown = serverTime + 120;
        [2, "The trace caught you -- the Alamo stays sealed, and your deck is locked out for two minutes."] call AP_fnc_broadcast;};
};

[["alamo"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
