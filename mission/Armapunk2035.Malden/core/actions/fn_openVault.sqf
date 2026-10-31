/*
    AP_fnc_openVault -- crack the Federal Reserve dome from the terminal at its side door.

    Was the Altis flow: hack a Land_Dome_Big_F's electrical panel, then hold a 2-minute pylon-disarm
    bar, then the doors open immediately. Malden's dome is a terrain object with no named door
    selections to stand next to, and the owner's flow is different: the terminal STARTS a ten-minute
    clock, and the doors open when it runs out. So there is no progress bar here at all -- the wait IS
    the bar, it runs server-side, and it does not care whether the hacker stays.

    WHERE THE PLAYER STANDS IS A COORDINATE, NOT THE DOME. The terminal is at the side door --
    AP_FED_TERMPOS, [11218.9, 4471.06, 18.16], the spot named in the brief -- and it is 24 m from the
    dome object's own model centre. This refusal used to measure to AP_fedDome at 12 m, so a player
    standing exactly where he had been told to stand was 26 m out: the scroll option never appeared and
    the function would have turned him away if it had. The 8 m below is fn_setupActions' own offer
    bound, so the option and the function agree by construction rather than by two numbers that happen
    to overlap; APS_fnc_maldenFedSRV "dome" is the looser 10 m outer bound and is meant to be.

    The alarm has already fired: the gate breach is what wakes MaxSec (phase 1), which gives them the
    ten minutes to arrive.
*/
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need ICEBREAKER firmware to breach the dome."] call AP_fnc_broadcast};

private _state = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
if ((_state param [0, 0]) isNotEqualTo 1) exitWith {
    [2, "Cut the perimeter gate first."] call AP_fnc_broadcast};
private _term = missionNamespace getVariable ["AP_FED_TERMPOS", []];
if (_term isEqualTo [] || {(player distance _term) > 8}) exitWith {
    [2, "You are not at the terminal by the dome's side door."] call AP_fnc_broadcast};
if (!isNil "AP_fedHackCooldown" && {AP_fedHackCooldown > serverTime}) exitWith {
    [2, format ["Your deck is still cooling down -- %1s left.", ceil (AP_fedHackCooldown - serverTime)]] call AP_fnc_broadcast};

AP_action_in_use = true;
private _r = [3] call AP_fnc_cyberdeckTerm;   // difficulty 3 = 9 commands, the Fed tier
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {AP_fedHackCooldown = serverTime + 120;
        [2, "The trace locked your deck out for two minutes."] call AP_fnc_broadcast;};
};

// Two rewards the Altis flow granted on a successful breach and the Malden rewrite dropped. Both are
// existing systems and the loss was not intended, so they fire at the same point they always did:
// the moment the breach succeeds, not when the doors finally open ten minutes later.
[["fed", player], "APS_fnc_qhLootSRV", 2] spawn AP_fnc_MP;   // deck-loot roll (server-side, throttled)
AP_side_exp = AP_side_exp + 50;

[["dome"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
