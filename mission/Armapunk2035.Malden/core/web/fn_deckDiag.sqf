/*
    fn_deckDiag.sqf — ask the phone to measure its own chassis rendering cost.

    "Doesn't animate, buttons are laggy" is a rendering-cost report, and the
    design is smooth in a desktop browser — so the interesting variable is what
    CEF costs HERE. This runs the page's own bisect: real requestAnimationFrame
    frame rate with each candidate effect disabled in turn, plus a sampled read
    of the roll's computed width, which separates "the transition never runs"
    from "it runs but every frame is too expensive to see".

    ARM FIRST, THEN OPEN THE PHONE.
      Esc is what opens the debug console and Esc also closes any dialog, so a
      diagnostic that needs the phone already open cannot be started. This one
      waits for the phone instead:

          [] spawn AP_fnc_deckDiag;     <- run this, close the console
          ... then open the phone (CTRL+Y, or Y -> Deck OS) ...

    It gives you 60s to get the phone open, waits for the page to settle, then
    measures for ~12s. Leave it alone while it runs. Results land in the RPT as
    [PAGE] CHASSIS DIAG.
*/

if (!canSuspend) exitWith { diag_log "[DECKDIAG] use spawn"; };

diag_log "[DECKDIAG] armed — open the phone now (waiting up to 60s)";

private _deadline = diag_tickTime + 60;
private _ctrl = controlNull;
waitUntil {
    uiSleep 0.5;
    _ctrl = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    // the deck specifically, not the harness or the probe rig
    (!isNull _ctrl && { !isNull (findDisplay 937500) }) || { diag_tickTime > _deadline }
};

if (isNull _ctrl || { isNull (findDisplay 937500) }) exitWith {
    diag_log "[DECKDIAG] timed out — the phone never opened";
};

diag_log "[DECKDIAG] phone is up, letting it settle";
uiSleep 3;

diag_log "[DECKDIAG] measuring, ~12s — do not touch anything";
private _r = [_ctrl, "chassisDiag", [], 30] call webui_fnc_call;
if (isNil "_r") then {
    diag_log "[DECKDIAG] the page did not answer — was the phone closed mid-run?";
} else {
    diag_log "[DECKDIAG] done";
};
