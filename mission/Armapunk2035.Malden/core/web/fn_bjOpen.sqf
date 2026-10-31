/*
    fn_bjOpen.sqf — boot DEALERBOT'S TABLE (dialog 930420).

    The shared blackjack table. Unlike the six reskins, this one is not a
    re-plumb of an existing dialog: APS_fnc_bjTableSRV is a new engine and it
    owns a table that exists whether or not anyone is looking at it. This fn
    registers the client as a viewer, forwards intent, and closes the seat when
    the dialog goes away.

    THE CLIENT DEBITS ITS OWN BET. That is not a choice made here -- AP_atmcash
    is a client cache and every casino game in the mod works this way
    (security.md 2.4). The server never echoes a bet back; it only credits the
    return it computed itself, through the owner-2-gated receiver. So the debit
    below has to happen, and it has to happen before the intent is sent, or a
    won round pays out against a bet that was never taken.
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[BJ] open: null display" };
disableSerialization;

private _ctrl = _display displayCtrl 930421;
if (isNull _ctrl) exitWith { diag_log "[BJ] control 930421 missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[BJ] bridge init failed" };
[_ctrl] call AP_fnc_casinoFit;

private _send = { params ["_case", ["_args", []]]; [[_case, _args], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP; };
uiNamespace setVariable ["AP_bjSend", _send];

[_ctrl, "casino", { [] call AP_fnc_casinoData }] call webui_fnc_on;

[_ctrl, "casTable", {
    params [["_t", "", [""]]];
    [_t] spawn AP_fnc_casinoOpen;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "bjSit", {
    params [["_seat", -1, [0]]];
    private _gate = ([] call AP_fnc_casinoData) get "gate";
    if (_gate isNotEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", _gate]] };
    [["sit", [_seat]], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "bjLeave", {
    [["leave", []], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "bjBet", {
    params [["_amt", 0, [0]]];
    private _gate = ([] call AP_fnc_casinoData) get "gate";
    if (_gate isNotEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", _gate]] };
    _amt = ((round _amt) max 10000) min 500000;
    if (AP_atmcash < _amt) exitWith { createHashMapFromArray [["ok", false], ["msg", "not enough in the bank"]] };
    AP_bjBet = _amt;
    private _before = AP_atmcash;
    AP_atmcash = AP_atmcash - _amt;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;
    ["bet", -_amt, _before] call AP_fnc_bjLedgerNote;
    [["bet", [_amt]], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["casino", ([] call AP_fnc_casinoData)];
    _r
}] call webui_fnc_on;

[_ctrl, "bjAct", {
    params [["_act", "", [""]]];
    if !(_act in ["hit", "stand", "double", "split"]) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "no such action"]]
    };
    // double and split each put a second bet down, so each is a second debit --
    // the server assumes it has already happened, exactly as the solo engine does.
    // The refusal is a FLAT exitWith: inside the then-block it only left the block,
    // so a short bank skipped the debit and the action went out anyway.
    private _extra = if (_act in ["double", "split"]) then { missionNamespace getVariable ["AP_bjBet", 0] } else { 0 };
    if (_extra > 0 && {AP_atmcash < _extra}) exitWith { createHashMapFromArray [["ok", false], ["msg", "not enough in the bank"]] };
    if (_act in ["double", "split"]) then {
        private _before = AP_atmcash;
        AP_atmcash = AP_atmcash - _extra;
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        [_act, -_extra, _before] call AP_fnc_bjLedgerNote;
    };
    [["act", [_act]], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

// TEST RIG. Push, double, split and split-aces are the four rules that are
// tedious to reach by playing and are exactly where a money bug would hide.
// The server gates this on the owner UID; the bar below is only injected for
// the same UID, so a player never sees a button they cannot press.
[_ctrl, "bjRig", {
    params [["_what", "", [""]]];
    [["rig", [_what]], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

if ((getPlayerUID player) isEqualTo "76561190000000001") then {
    // Injected rather than added to the page, so the delivered file stays the
    // designer's and a re-drop does not have to carry a dev control.
    //
    // THROUGH webui_fnc_exec, NOT ctrlWebBrowserAction. This runs at onLoad, and
    // the BIKI is explicit that ExecJS before PageLoaded "may be dropped" --
    // silently, which is why the bar simply never appeared. fn_exec queues it and
    // the readiness drain runs it. The other probes get away with a raw call only
    // because they are invoked by hand, minutes after the page is up.
    [_ctrl,
    "(function(){if(document.getElementById('__bjrig'))return;" +
    "var b=document.createElement('div');b.id='__bjrig';" +
    "b.style.cssText='position:fixed;left:.6rem;bottom:.6rem;z-index:99998;display:flex;gap:.3rem;" +
    "font:10px ui-monospace,monospace;opacity:.75';" +
    "['push','double','split','splitaces'].forEach(function(n){" +
    "var x=document.createElement('button');x.textContent=n.toUpperCase();" +
    "x.style.cssText='background:#1a0f00;color:#ffb020;border:1px solid #ffb020;border-radius:.25rem;" +
    "padding:.2rem .45rem;cursor:pointer;font:inherit;letter-spacing:.08em';" +
    "x.onclick=function(){AP.call('bjRig',[n]);};b.appendChild(x);});" +
    "document.body.appendChild(b);})()"] call webui_fnc_exec;
    diag_log "[BJ] rig bar queued (owner)";
};

// The chip goes to the server and nothing is decided here -- not the phase, not
// the target, not whether the player actually owns one. The page offers; the
// engine spends and rules. Untargeted chips arrive as [id], targeted as [id, seat].
[_ctrl, "bjChip", {
    params [["_id", "", [""]], ["_seat", -1, [0]]];
    if (_id isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "no chip"]] };
    [["chip", [_id, _seat]], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];

[_ctrl, "casino", ([] call AP_fnc_casinoData)] call webui_fnc_push;
[["watch", []], "APS_fnc_bjTableSRV", 2] spawn AP_fnc_MP;
diag_log format ["[BJ] table ready t=%1", diag_tickTime toFixed 1];
