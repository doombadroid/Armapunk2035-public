/*
    fn_webBridgeOpen.sqf — opens the web UI harness (dialog 937400).

    Exercises every direction the bridge has, so a change to it can be checked
    in game rather than reasoned about:

        JS  -> SQF call    the ping / playerInfo / serverTime buttons
        JS  -> SQF bool    "isCop", answered by the event handler's return value
        SQF -> JS  call    "callPage" asks the page for its own state
        SQF -> JS  push    the player / screen / tick channels below
        game filesystem    WEBUI.texture() pulling a .paa in as a data URL
        StopBrowser        freeze, then resume 3s later

    Usage:  [_this select 0] spawn AP_fnc_webBridgeOpen;
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[WEBBRIDGE] open: null display"; };

disableSerialization;
private _ctrl = _display displayCtrl 937401;
if (isNull _ctrl) exitWith { diag_log "[WEBBRIDGE] open: control 937401 missing"; };

if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[WEBBRIDGE] open: init failed"; };

// Needs the -debug start parameter, or this is a no-op.
if (!isNil "AP_devMode" && { AP_devMode }) then { _ctrl ctrlWebBrowserAction ["OpenDevConsole"]; };

// ---- demo handlers ---------------------------------------------------------
// ASK runs UNSCHEDULED and its return value is the reply, so it must be cheap
// and must never suspend. Anything heavier belongs on a CALL.
[_ctrl, "isCop", { AP_effSide isEqualTo west }] call webui_fnc_on;

// SQF -> JS. The page registered the other half with WEBUI.handle("pageState").
[_ctrl, "callPage", {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    private _state = [_c, "pageState", ["from SQF"]] call webui_fnc_call;
    diag_log format ["[WEBBRIDGE] the page answered: %1", _state];
    _state
}] call webui_fnc_on;

// Freeze the browser: the last drawn frame stays on screen and the browser's
// CPU and memory are released. Resuming reloads the page, which fires
// PageLoaded again -- bridge.js is re-injected there and the channels re-push.
[_ctrl, "freeze", {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    [_c] spawn {
        params ["_c"];
        [_c, false] call webui_fnc_freeze;
        uiSleep 3;
        if (!isNull _c) then { [_c, true] call webui_fnc_freeze; };
    };
    "frozen for 3s -- the image stays, the browser does not"
}] call webui_fnc_on;

// ---- push loop -------------------------------------------------------------
// Push on open, then whenever the underlying state changes; the page re-renders
// itself from what it receives. Never poll per frame.
[_ctrl] spawn {
    params ["_ctrl"];
    uiSleep 1;
    private _n = 0;
    while { !isNull _ctrl && { !isNull (findDisplay 937400) } } do {
        _n = _n + 1;
        [_ctrl, "player", [name player, getPlayerUID player, str (side player)]] call webui_fnc_push;
        [_ctrl, "screen", getResolution select [0, 2]]                          call webui_fnc_push;
        [_ctrl, "tick",   [_n, round diag_fps, round dayTime, round serverTime]] call webui_fnc_push;
        if (_n isEqualTo 1) then { diag_log format ["[WEBBRIDGE] first push sent t=%1", diag_tickTime toFixed 1]; };
        uiSleep 1;
    };
};

// idle cost of the embedded browser, for the phone-deck decision
[] spawn {
    private _n = 0; private _sum = 0;
    private _end = diag_tickTime + 10;
    while { diag_tickTime < _end && { !isNull (findDisplay 937400) } } do {
        _sum = _sum + diag_fps; _n = _n + 1;
        uiSleep 0.25;
    };
    if (_n > 0) then {
        diag_log format ["[WEBBRIDGE] mean FPS over %1 samples with browser open: %2",
            _n, (_sum / _n) toFixed 1];
    };
};

diag_log "[WEBBRIDGE] harness page opened";
