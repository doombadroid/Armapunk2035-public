/*
    AP_fnc_dutyTermOpen -- the MaxSec HQ tablet's sign-on screen: open dialog 938200 and hand it over.

        ["maxsec"] spawn AP_fnc_dutyTermOpen;

    Called from fn_setupActions.sqf's tablet block in place of `["maxsec"] spawn AP_fnc_dutyTerminal`, and
    ONLY while the player is off duty. Clocking off is still the terminal's own turnaround, unchanged --
    there is no page for it and none is wanted: the off-ramp is one click where the on-ramp was.

    THIS MUST RUN SCHEDULED. It waits on the display and on the bridge's bind signal; an unscheduled arrival
    re-spawns itself, the same shape fn_dutyTerminal.sqf:31 uses, because nothing is waiting on its answer.

    IT NEVER LEAVES A DEAD TABLET. Every failure below falls through to AP_fnc_dutyTerminal -- the
    GUIMessage picker that has been the sign-on path all along -- rather than ending the interaction:

      * createDialog failing: a missing class, or an already-open exclusive display.
      * the display never appearing inside 5s.
      * the display appearing but the bridge never binding. This one is the reason the check exists at all
        and is NOT the landing's check: ui\html\duty_maxsec.html's shim defines window.AP synchronously so
        the designer's demo mode (which fakes {ok:true} 450 ms after every dutyStart) can never arm in game.
        That is correct -- a demo "success" would be a player believing they were on duty when nothing had
        left their client -- but it means an unbound page is a screen whose GO button spins forever. The
        bridge sets AP_dutyTermBound only after every verb is registered, so waiting on it distinguishes
        "rendered" from "can answer".

    THE GATES ARE THE SCROLL PATH'S, RUN IN THE SAME TWO PIECES AND THE SAME ORDER (AP_fnc_dutyGate's
    "state" then "signon"), so a player who could not have signed on gets the same refusal in the same
    words they got before, instantly, without a screen opening in front of them first. They are convenience
    only -- AP_fnc_dutyTermBridge re-runs the whole gate at dutyStart because a terminal can sit open for
    minutes, and APS_fnc_dutySRV re-runs everything from its own DB read regardless.
*/
if (!canSuspend) exitWith { _this spawn AP_fnc_dutyTermOpen; };
if (isDedicated || {!hasInterface}) exitWith {};
if !(missionNamespace getVariable ["AP_dutyEnabled", false]) exitWith {};

params [["_faction", "maxsec", [""]]];
// One faction has a page. Trauma keeps the picker outright rather than being routed through a MaxSec
// screen that has none of its roles on it.
if (_faction isNotEqualTo "maxsec") exitWith { [_faction] spawn AP_fnc_dutyTerminal; };

private _fnc_fallback = {
    diag_log format ["[DUTYTERM] open: %1 -- falling back to AP_fnc_dutyTerminal's picker", _this];
    if (dialog) then { closeDialog 0; uiSleep 0.15; };
    [_faction] spawn AP_fnc_dutyTerminal;
};

private _gate = ["", "state"] call AP_fnc_dutyGate;
if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage; };

private _signOn = [_faction, "signon"] call AP_fnc_dutyGate;
if (_signOn isNotEqualTo "") exitWith { [_signOn, "basic"] spawn AP_fnc_handleMessage; };

AP_dutyTermBound = false;
if !(createDialog "AP_web_dutyMaxsec") exitWith {
    "createDialog AP_web_dutyMaxsec failed" call _fnc_fallback;
};

// The dialog may not exist for a frame or two, and the bridge binds a beat after that. One deadline covers
// both, because the fallback for either is the same.
private _up = diag_tickTime + 5;
waitUntil {
    uiSleep 0.1;
    (!isNull (findDisplay 938200) && {missionNamespace getVariable ["AP_dutyTermBound", false]})
    || {diag_tickTime > _up}
};
if (isNull (findDisplay 938200)) exitWith { "display 938200 never appeared in 5s" call _fnc_fallback; };
if !(missionNamespace getVariable ["AP_dutyTermBound", false]) exitWith {
    "display 938200 is up but the bridge never bound in 5s" call _fnc_fallback;
};
diag_log "[DUTYTERM] open: display up and bound";
