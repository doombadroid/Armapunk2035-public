/*
    fn_holdemOpen.sqf — boot TEXAS HOLD'EM (dialog 930422, control 930423).

    The second table in the casino that is not a reskin. Like DEALERBOT'S TABLE it talks to its own
    engine -- APS_fnc_holdemSRV -- which owns a table that exists whether or not anyone is looking
    at it, so this file's job is to bind the control, register the verbs, subscribe as a VIEWER, and
    get out of the way.

        [_display] spawn AP_fnc_holdemOpen;      // dialog\web_casino.hpp onLoad

    THE VIEWER SUBSCRIPTION IS THE POINT. Every other casino page is a private conversation between
    one player and the server; this one renders five other people's chips. "open" registers this
    client so the server's fan-out reaches it and answers immediately with the current state, and
    the dialog's own onUnload sends "close". A player who never sends "close" -- alt-F4, a crash --
    is picked up by fn_playerDisconnected instead.

    CLOSING THE VIEW LEAVES THE TABLE, and that decision lives server-side in the "close" case
    rather than here, deliberately: a bridge that sent hLeave itself would be one more thing that
    has to fire, and the case it exists for is exactly the one where the client stopped cooperating.
    The reasoning is in the engine -- nobody can act on a table they cannot see, so a kept seat
    would hold five people on a 20 s clock every orbit and then fold anyway.

    THIS FILE MOVES NO MONEY. See AP_fnc_holdemBridge's header for why hold'em inverts the casino's
    client-debits model, and APS_fnc_holdemSRV's for the money spine itself.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[HOLDEM] open: null display" };
disableSerialization;

private _ctrl = _display displayCtrl 930423;          // idc is idd + 1, the DEALERBOT'S TABLE convention
if (isNull _ctrl) exitWith { diag_log "[HOLDEM] control 930423 missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[HOLDEM] bridge init failed" };

// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships without a client
// repack. No-op unless AP_fnc_webServeInit registered a fetcher and the server actually has the
// file -- otherwise the PBO page that just loaded stands.
[_ctrl, "ui\html\casino\holdem.html"] call webui_fnc_serve;
[_ctrl] call AP_fnc_casinoFit;

// A stale snapshot from a previous visit would let the bridge's local pre-checks answer off a table
// that has moved on -- "it is not your turn" about a hand that finished ten minutes ago. The
// server's answer to "open" replaces it within a round trip; until then there is nothing to read,
// which is the honest state.
uiNamespace setVariable ["AP_holdemState", createHashMap];

[_ctrl] call AP_fnc_holdemBridge;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];

// The tail push, same as every other table: webui_fnc_push queues until the page is up and
// webui.js's on() replays the last value on a channel, so the page gets this whether it subscribed
// before or after. "casino" carries the bank and the gate; "holdem" comes back from the server.
[_ctrl, "casino", ([] call AP_fnc_casinoData)] call webui_fnc_push;
[["open", []], "APS_fnc_holdemSRV", 2] spawn AP_fnc_MP;
diag_log format ["[HOLDEM] table ready t=%1", diag_tickTime toFixed 1];
