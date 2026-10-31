/*
    AP_fnc_openGate -- breach the Federal Reserve's perimeter gate.

    Malden's Fed has no boltcutter path: the gate is locked at boot, locked after every reset, and the
    Sequence Breach is the only way through. Buffer 10, the asylum-laptop tier -- this is the first
    move of a Federal event, not a car door.

    Everything this decides is re-decided on the server (APS_fnc_maldenFedSRV "gate"). What happens
    here is the minigame and the local feedback; the gate itself, the alarm and the phase are the
    server's.
*/
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need ICEBREAKER firmware to breach the gate."] call AP_fnc_broadcast};

private _state = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
if ((_state param [0, 0]) isNotEqualTo 0) exitWith {
    [2, "The Reserve is already breached."] call AP_fnc_broadcast};
if ((_state param [4, -1]) > serverTime) exitWith {
    [2, format ["Security is high at the Reserve. Try again in %1 minute(s).",
        ceil (((_state param [4, -1]) - serverTime) / 60)]] call AP_fnc_broadcast};
if (["fed"] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage};
// 6 m, matching the scroll action's offer radius in fn_setupActions exactly: the option must never be
// visible at a range this refuses. The server re-checks at 8 m, looser on purpose.
if (isNull AP_fedGate || {(player distance AP_fedGate) > 6}) exitWith {
    [2, "You are not at the Reserve gate."] call AP_fnc_broadcast};

AP_action_in_use = true;
private _r = [10] call AP_fnc_cyberdeckSeq;
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {[2, "The trace caught you -- the gate stays shut."] call AP_fnc_broadcast;};
};

[["gate"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
