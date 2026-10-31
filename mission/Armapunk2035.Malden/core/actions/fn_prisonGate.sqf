/*
    AP_fnc_prisonGate -- breach the Malden prison's inner sally-port gate.

    This is the prison break's TRIGGER. There has never been one on this map: AP_fnc_doPrisonBreak, the
    laptop virus-upload path, has no callers anywhere in the tree, no scroll action offers it, and there is
    no laptop-class object within 170 m of the prison.

    Everything this decides is re-decided on the server (APS_fnc_prisonGateSRV "gatehack", which then hands
    off to APS_fnc_handlePrisonBreak mode 1 and its five guards). What happens here is the minigame and the
    local feedback; the gates, the window, the alarm and the dispatch are the server's.

    The refusals below are MESSAGING, not security -- they exist so a player learns why the option did
    nothing, and they are deliberately the same bounds the scroll action offers on.
*/
if !(AP_effSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need ICEBREAKER firmware to breach the gate."] call AP_fnc_broadcast};
// A prisoner escapes through the query dialog, not by hacking his own cell door from the inside.
if (player getVariable ["AP_restrained", false] || {player getVariable ["AP_arrested", false]}) exitWith {};

// 6 m, matching the scroll action's offer radius in fn_setupActions exactly: the option must never be
// visible at a range this refuses. The server re-checks at 8 m, looser on purpose.
private _gate = missionNamespace getVariable ["AP_prisonGateIn", objNull];
if (isNull _gate || {(player distance _gate) > 6}) exitWith {
    [2, "You are not at the prison gate."] call AP_fnc_broadcast};

if ((missionNamespace getVariable ["SRV_prisonData", [0, false]]) param [1, false]) exitWith {
    [2, "There is already a prison break in progress!"] call AP_fnc_broadcast};
if (["prison"] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage};

AP_action_in_use = true;
private _r = [10] call AP_fnc_cyberdeckSeq;
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {[2, "The trace caught you -- the gate stays shut."] call AP_fnc_broadcast;};
};

[["gatehack"], "APS_fnc_prisonGateSRV", 2] spawn AP_fnc_MP;
