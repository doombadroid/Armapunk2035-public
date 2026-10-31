// armapunk_menu\menu.sqf — main-menu state machine (design v2).
// Spawned by the preInit watcher (fn_menuWatch.sqf) with [_display]; one run
// per RscDisplayMain instance. Spec: repo mainmenu.md.
//
// v3 flow: per aspect, a 10 s background-only intro (boot -> logo -> settled,
// plays once per game session, skippable) hands off to a 60 s engineered
// held loop that stays on the lit logo state; loop restarts are script-driven
// (VideoStopped re-arms the texture — the engine's loops property proved
// unreliable for scripted videos, observed 2026-08-04) and hide inside a
// baked glitch burst. The three live rows + hint fade in on the design's
// own type-in timing. Aspect picked nearest the screen, letterboxed.
// All geometry derives from the generated layout include.
#include "\armapunk_menu\layout.hpp"

params ["_display"];
if (isNull _display) exitWith {};
disableSerialization;
// Reentry guard AND the watcher's success marker: only code that actually
// EXECUTED can set this, so a spawn killed in a scheduler transition never
// blocks the retry (the v1-v3 silent-boot root cause).
if (_display isEqualTo (uiNamespace getVariable ["AP35_bootedDisplay", displayNull])) exitWith {};
uiNamespace setVariable ["AP35_bootedDisplay", _display];
diag_log "AP35: menu.sqf boot (display loaded)";

// ---------------------------------------------------------------- geometry
// Pick the shipped aspect nearest the screen, then fit that canvas into the
// largest box inside the safezone; pixelW/pixelH give exact square-pixel
// mapping on any panel (16:10 laptop letterboxes the 16:9 master).
private _szPxW = safezoneW / pixelW;
private _szPxH = safezoneH / pixelH;
private _screenAspect = _szPxW / _szPxH;
private _a169 = AP35_CANVAS_169_W / AP35_CANVAS_H;
private _a219 = AP35_CANVAS_219_W / AP35_CANVAS_H;
private _use219 = abs (_screenAspect - _a219) < abs (_screenAspect - _a169);
private _canvasW = [AP35_CANVAS_169_W, AP35_CANVAS_219_W] select _use219;
private _canvasA = [_a169, _a219] select _use219;
diag_log format ["AP35: screen aspect %1 -> %2 video", _screenAspect toFixed 3, ["16:9", "21:9"] select _use219];

private _boxPxW = _szPxW min (_szPxH * _canvasA);
private _boxPxH = _boxPxW / _canvasA;
private _s = _boxPxW / _canvasW;
private _oxPx = (_szPxW - _boxPxW) / 2;
private _oyPx = (_szPxH - _boxPxH) / 2;
uiNamespace setVariable ["AP35_mapBox", [_oxPx, _oyPx, _s]];
uiNamespace setVariable ["AP35_map", {
    params ["_x", "_y", "_w", "_h"];
    (uiNamespace getVariable "AP35_mapBox") params ["_ox", "_oy", "_s"];
    [
        safezoneX + (_ox + _x * _s) * pixelW,
        safezoneY + (_oy + _y * _s) * pixelH,
        _w * _s * pixelW,
        _h * _s * pixelH
    ]
}];

// Vanilla buttons live inside controls groups (1001-1005), where displayCtrl
// can't always reach them — walk the groups when the direct lookup misses.
uiNamespace setVariable ["AP35_findCtrl", {
    params ["_idc"];
    private _display = uiNamespace getVariable "AP35_display";
    private _ctrl = _display displayCtrl _idc;
    if (isNull _ctrl) then {
        {
            private _grp = _display displayCtrl _x;
            if (!isNull _grp) then {
                private _c = _grp controlsGroupCtrl _idc;
                if (!isNull _c) exitWith { _ctrl = _c; };
            };
        } forEach [1001, 1002, 1003, 1004, 1005];
    };
    _ctrl
}];

private _place = {
    params ["_ctrl", "_box"];
    _ctrl ctrlSetPosition (_box call (uiNamespace getVariable "AP35_map"));
    _ctrl ctrlCommit 0;
};

// ---------------------------------------------------------------- controls
private _vidIntro = _display displayCtrl 941601;
private _vidLoop  = _display displayCtrl 941602;
private _hint  = _display displayCtrl 941630;
private _rows = []; private _hits = [];
{ _rows pushBack (_display displayCtrl (941610 + _x)); } forEach [0, 1, 2];
{ _hits pushBack (_display displayCtrl (941620 + _x)); } forEach [0, 1, 2];

uiNamespace setVariable ["AP35_display", _display];

[_vidIntro, [0, 0, _canvasW, AP35_CANVAS_H]] call _place;
[_vidLoop,  [0, 0, _canvasW, AP35_CANVAS_H]] call _place;
{ [_rows select _forEachIndex, _x] call _place; } forEach AP35_ROW_BOXES;
{ [_hits select _forEachIndex, _x] call _place; } forEach AP35_ROW_HITS;
[_hint, AP35_HINT_BOX] call _place;

// Bury the vanilla menu. Config z-order is not enough: BIS init scripts
// ctrlCreate spotlight/news controls at runtime (they float above config
// controls — observed 2026-08-03), so hide everything that isn't ours.
// Hidden vanilla buttons still respond to ctrlActivate. Re-sweep twice
// because display init keeps creating controls for a while after load.
uiNamespace setVariable ["AP35_hideVanilla", {
    private _display = uiNamespace getVariable "AP35_display";
    if (isNull _display) exitWith {};
    {
        private _idc = ctrlIDC _x;
        if (_idc < 941600 || _idc > 941699) then { _x ctrlShow false; };
    } forEach (allControls _display);
}];
call (uiNamespace getVariable "AP35_hideVanilla");
[] spawn {
    uiSleep 1;
    call (uiNamespace getVariable "AP35_hideVanilla");
    uiSleep 4;
    call (uiNamespace getVariable "AP35_hideVanilla");
};

// ------------------------------------------------------------------- state
uiNamespace setVariable ["AP35_sel", 0];
uiNamespace setVariable ["AP35_armed", false];
uiNamespace setVariable ["AP35_pulseId", 0];

// Selection renderer: baked strip per state; EXIT's sel strip is the red
// armed style by design. _pulse repaints with the glow-pulse bake for 150 ms.
uiNamespace setVariable ["AP35_setSel", {
    params ["_sel", ["_pulse", true]];
    private _display = uiNamespace getVariable "AP35_display";
    if (isNull _display) exitWith {};
    private _old = uiNamespace getVariable "AP35_sel";
    uiNamespace setVariable ["AP35_sel", _sel];
    if (_old != _sel) then { uiNamespace setVariable ["AP35_armed", false]; };
    private _armed = uiNamespace getVariable "AP35_armed";
    for "_i" from 0 to 2 do {
        private _state = if (_i == _sel) then { "sel" } else { "dim" };
        (_display displayCtrl (941610 + _i)) ctrlSetText
            format ["\armapunk_menu\ui\row_%1_%2.paa", _i, _state];
    };
    (_display displayCtrl 941630) ctrlSetText (
        if (_armed) then { "\armapunk_menu\ui\hint_armed.paa" }
        else { format ["\armapunk_menu\ui\hint_%1.paa", _sel] }
    );
    (_display displayCtrl 941630) ctrlSetTextColor [1, 1, 1, 1];
    if (_pulse && {_old != _sel}) then {
        private _id = (uiNamespace getVariable "AP35_pulseId") + 1;
        uiNamespace setVariable ["AP35_pulseId", _id];
        [_sel, _id] spawn {
            params ["_sel", "_id"];
            private _display = uiNamespace getVariable "AP35_display";
            (_display displayCtrl (941610 + _sel)) ctrlSetText
                format ["\armapunk_menu\ui\row_%1_pulse.paa", _sel];
            uiSleep 0.15;
            if (isNull _display || _id != uiNamespace getVariable "AP35_pulseId") exitWith {};
            if ((uiNamespace getVariable "AP35_sel") == _sel) then {
                (_display displayCtrl (941610 + _sel)) ctrlSetText
                    format ["\armapunk_menu\ui\row_%1_sel.paa", _sel];
            };
        };
    };
}];

// EXIT armed blink: 5 Hz alpha square wave on the hint strip (design dims to
// 0.25, never fully off). Dies with disarm, selection change or display.
uiNamespace setVariable ["AP35_armExit", {
    uiNamespace setVariable ["AP35_armed", true];
    [2, false] call (uiNamespace getVariable "AP35_setSel"); // repaint armed hint
    [] spawn {
        private _display = uiNamespace getVariable "AP35_display";
        private _hint = _display displayCtrl 941630;
        private _on = true;
        while {!isNull _display && {uiNamespace getVariable "AP35_armed"}} do {
            _hint ctrlSetTextColor [1, 1, 1, [0.25, 1] select _on];
            _on = !_on;
            uiSleep 0.1;
        };
        if (!isNull _display) then { _hint ctrlSetTextColor [1, 1, 1, 1]; };
    };
}];

// -------------------------------------------------------------- activation
// Vanilla RscDisplayMain buttons, activated by IDC (read from a ui_f derap):
// 105 server browser, 301 video options, 106 Exit.
uiNamespace setVariable ["AP35_activate", {
    params ["_sel"];
    private _display = uiNamespace getVariable "AP35_display";
    if (isNull _display) exitWith {};
    switch (_sel) do {
        case 0: { // DEPLOY — jack into the configured server, else browse
            private _srv = getArray (configFile >> "ArmapunkMenu" >> "deployServer");
            private _ovr = profileNamespace getVariable ["AP35_deployServer", []];
            if (count _ovr == 3) then { _srv = _ovr; };
            if (count _srv == 3) then {
                connectToServer [_srv select 0, _srv select 1, _srv select 2];
            } else {
                ctrlActivate ([105] call (uiNamespace getVariable "AP35_findCtrl"));
            };
        };
        case 1: { ctrlActivate ([301] call (uiNamespace getVariable "AP35_findCtrl")); };
        case 2: {
            if (uiNamespace getVariable "AP35_armed") then {
                ctrlActivate ([106] call (uiNamespace getVariable "AP35_findCtrl"));
            } else {
                call (uiNamespace getVariable "AP35_armExit");
            };
        };
    };
}];

// ------------------------------------------------------------------- input
{
    private _i = _forEachIndex;
    _x ctrlAddEventHandler ["MouseEnter", format [
        "[%1] call (uiNamespace getVariable 'AP35_setSel');", _i]];
    _x ctrlAddEventHandler ["ButtonClick", format [
        "[%1] call (uiNamespace getVariable 'AP35_setSel'); [%1] call (uiNamespace getVariable 'AP35_activate');", _i]];
} forEach _hits;

_display displayAddEventHandler ["KeyDown", "
    params ['', '_key'];
    if !(uiNamespace getVariable ['AP35_loopUp', false]) exitWith {
        call (uiNamespace getVariable 'AP35_startLoop'); true
    };
    private _sel = uiNamespace getVariable 'AP35_sel';
    private _armed = uiNamespace getVariable 'AP35_armed';
    switch (true) do {
        case (_key in [200, 17]): { [(_sel + 2) mod 3] call (uiNamespace getVariable 'AP35_setSel'); true };
        case (_key in [208, 31]): { [(_sel + 1) mod 3] call (uiNamespace getVariable 'AP35_setSel'); true };
        case (_key in [28, 156]): { [_sel] call (uiNamespace getVariable 'AP35_activate'); true };
        case (_key == 21 && _armed): { [2] call (uiNamespace getVariable 'AP35_activate'); true };
        case (_key in [49, 1] && _armed): {
            uiNamespace setVariable ['AP35_armed', false];
            [_sel, false] call (uiNamespace getVariable 'AP35_setSel');
            true
        };
        default { false };
    };
"];

// -------------------------------------------------------------- intro/loop
private _suffix = ["169", "219"] select _use219;
uiNamespace setVariable ["AP35_loopPath", format ["\armapunk_menu\video\loop_%1.ogv", _suffix]];
uiNamespace setVariable ["AP35_introPath", format ["\armapunk_menu\video\intro_%1.ogv", _suffix]];
uiNamespace setVariable ["AP35_loopUp", false];

// Loop stage: script-driven video swap (ctrl ops only — safe in unscheduled
// EH context). Idempotent per display.
uiNamespace setVariable ["AP35_startLoop", {
    if (uiNamespace getVariable ["AP35_loopUp", false]) exitWith {};
    uiNamespace setVariable ["AP35_loopUp", true];
    private _display = uiNamespace getVariable "AP35_display";
    if (isNull _display) exitWith {};
    private _loop = _display displayCtrl 941602;
    _loop ctrlSetText (uiNamespace getVariable "AP35_loopPath");
    _loop ctrlShow true;
    (_display displayCtrl 941601) ctrlShow false;
    {
        private _c = _display displayCtrl _x;
        _c ctrlShow true;
        _c ctrlSetTextColor [1, 1, 1, 1];
    } forEach [941610, 941611, 941612, 941620, 941621, 941622, 941630];
    [0, false] call (uiNamespace getVariable "AP35_setSel");
    diag_log "AP35: loop stage up";
}];

// The engine's own loop restart proved unreliable for scripted videos —
// re-arm the texture ourselves every time the loop video ends. The restart
// gap lands inside the baked glitch burst at the seam.
_vidLoop ctrlAddEventHandler ["VideoStopped",
    "(_this select 0) ctrlSetText (uiNamespace getVariable 'AP35_loopPath');"];
_vidIntro ctrlAddEventHandler ["VideoStopped",
    "call (uiNamespace getVariable 'AP35_startLoop');"];
_vidIntro ctrlAddEventHandler ["MouseButtonDown",
    "call (uiNamespace getVariable 'AP35_startLoop');"];

if (uiNamespace getVariable ["AP35_introPlayed", false]) then {
    call (uiNamespace getVariable "AP35_startLoop");
} else {
    uiNamespace setVariable ["AP35_introPlayed", true];
    _vidIntro ctrlSetText (uiNamespace getVariable "AP35_introPath");
    _vidIntro ctrlShow true;
    // Rows/hint fade in on the design's own type-in timing (6.35+0.18i,
    // 0.32 s each; hint with the bar at ~7.7 s; selector pulse at 8.2 s).
    // Fallback switch at 10.15 s in case VideoStopped never fires.
    [] spawn {
        private _t0 = diag_tickTime;
        private _fade = {
            params ["_idc", "_dur"];
            private _display = uiNamespace getVariable "AP35_display";
            private _c = _display displayCtrl _idc;
            _c ctrlSetTextColor [1, 1, 1, 0];
            _c ctrlShow true;
            for "_k" from 1 to 8 do {
                if (uiNamespace getVariable ["AP35_loopUp", false]) exitWith {};
                _c ctrlSetTextColor [1, 1, 1, _k / 8];
                uiSleep (_dur / 8);
            };
            _c ctrlSetTextColor [1, 1, 1, 1];
        };
        {
            _x params ["_at", "_idc", "_dur"];
            private _wait = _at - (diag_tickTime - _t0);
            if (_wait > 0) then { uiSleep _wait; };
            if (uiNamespace getVariable ["AP35_loopUp", false]) exitWith {};
            [_idc, _dur] spawn _fade;
        } forEach [
            [6.35, 941610, 0.32], [6.53, 941611, 0.32], [6.71, 941612, 0.32],
            [7.7, 941630, 0.4]
        ];
        private _wait = 8.2 - (diag_tickTime - _t0);
        if (_wait > 0) then { uiSleep _wait; };
        if !(uiNamespace getVariable ["AP35_loopUp", false]) then {
            [0, true] call (uiNamespace getVariable "AP35_setSel");
        };
        _wait = 10.15 - (diag_tickTime - _t0);
        if (_wait > 0) then { uiSleep _wait; };
        call (uiNamespace getVariable "AP35_startLoop");
    };
};
diag_log "AP35: menu up";
