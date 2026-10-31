/*
    fn_deckFx.sqf — turn the phone's always-on chrome animation off, live, so the
    cost of it can be measured against Arma's own frame rate instead of argued about.

    WHY THIS EXISTS. The chassis has three full-bleed layers that animate forever:

        .scanlines  position:absolute; inset:0    apScan 5.5s + apFlicker 6.1s, infinite
        .glowband   full width, 26% height        apDrift 11s, infinite
        LEDs / matrix columns                     apPulse, mut — infinite

    Frame delivery out of the browser control is DIRTY-driven: a still page costs
    almost nothing and a full-bleed animation marks the whole surface dirty every
    frame. .scanlines covers 100% of the screen and never stops, so the phone is
    never still -- not on the home screen, not while reading a list, not ever. Every
    one of those frames is a texture upload into Arma on top of whatever the game is
    already drawing.

    That is a hypothesis until it is measured, which is what this is for. It injects
    a stylesheet that kills those animations and nothing else -- no layout change, no
    reload, no page edit -- so the same session can be compared with them on and off.

        [] spawn AP_fnc_deckFx;        toggle
        [true]  spawn AP_fnc_deckFx;   chrome animation OFF  (still page)
        [false] spawn AP_fnc_deckFx;   back to normal

    Read the FPS off the overlay both ways. If it does not move, the phone is not
    what is costing you the frames and the answer is upstream -- this box currently
    runs Arma inside gamescope with an FSR upscale, which composites every one of
    those frames a second time.
*/

params [["_off", -1, [false, 0]]];
disableSerialization;

private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
if (isNull _c) exitWith { diag_log "[DECKFX] no page is open"; };

if (_off isEqualTo -1) then { _off = !(uiNamespace getVariable ["AP_deckFxOff", false]) };
uiNamespace setVariable ["AP_deckFxOff", _off];

private _js = if (_off) then {
"(function(){var s=document.getElementById('__nofx');if(s)return;" +
"s=document.createElement('style');s.id='__nofx';" +
"s.textContent='.scanlines,.glowband,.led,.qh .led,.trace,.mx span,#wp span,.spool-spindle{animation:none !important}';" +
"document.head.appendChild(s);})()"
} else {
"(function(){var s=document.getElementById('__nofx');if(s)s.remove();})()"
};

[_c, _js] call webui_fnc_exec;   // queued: raw ExecJS before PageLoaded is dropped silently
diag_log format ["[DECKFX] chrome animation %1 -- read the FPS overlay now", if (_off) then {"OFF"} else {"ON"}];
