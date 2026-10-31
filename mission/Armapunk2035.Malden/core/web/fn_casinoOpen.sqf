/*
    fn_casinoOpen.sqf — boot a web casino table (dialogs 930400-930415).

    THE ENGINES DO NOT CHANGE. Every verb forwards the same intent the native
    dialog sends to APS_fnc_casinoSRV; the server settles, credits through its own
    gated receiver, and pushes the visual result back through AP_fnc_casino,
    which mirrors it onto the page. No new CfgRE entry, no new server function,
    and no path by which the page can decide an outcome or move money.

    ONE DIALOG PER TABLE. A browser control's `url` is static config and it is the
    only hand-over that binds A3API, so switching tables is closeDialog +
    createDialog rather than a navigation.

    Usage:  [] spawn AP_fnc_casinoOpen;                    open the floor
            ["wheel"] spawn AP_fnc_casinoOpen;             open a table
            [_display, "wheel"] spawn AP_fnc_casinoOpen;   dialog onLoad
*/

params [["_a", "", [displayNull, ""]], ["_table", "", [""]]];

private _class = {
    params ["_t"];
    // The landing's tile ids are the DESIGNER's ("coin", "bj"), not the engine's.
    // Anything unrecognised falls back to the floor rather than to nothing.
    // Blackjack and hold'em are the two tables with their own openers -- they
    // talk to shared engines, not to APS_fnc_casinoSRV -- but arriving at either
    // is the same trip.
    switch (toLower _t) do {
        case "wheel":    { "AP_wcas_wheel" };    case "crash":    { "AP_wcas_crash" };
        case "slots":    { "AP_wcas_slots" };    case "roulette": { "AP_wcas_roulette" };
        case "hilo":     { "AP_wcas_hilo" };
        case "coin";
        case "coinflip":  { "AP_wcas_coinflip" };
        case "bj";
        case "blackjack": { "AP_wcas_blackjack" };
        case "holdem";
        case "poker":     { "AP_wcas_holdem" };
        default          { "AP_wcas_landing" };
    }
};

if (_a isEqualType "") exitWith {
    if (!alive player) exitWith { diag_log "[CASINO] blocked: dead"; };
    private _c = [_a] call _class;
    // A dialog is already up when this is a table switch, so it has to go first.
    [_c] spawn { params ["_c"]; if (dialog) then { closeDialog 0; uiSleep 0.12; }; createDialog _c; };
    diag_log format ["[CASINO] open %1", _c];
};

private _display = _a;
if (isNull _display) exitWith { diag_log "[CASINO] open: null display"; };
disableSerialization;

// idc is idd + 100 for every table (see web_casino.hpp)
private _idd = ctrlIDD _display;
private _ctrl = _display displayCtrl (_idd + 100);
if (isNull _ctrl) exitWith { diag_log format ["[CASINO] control %1 missing", _idd + 100]; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[CASINO] bridge init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\casino\landing.html"] call webui_fnc_serve;
[_ctrl] call AP_fnc_casinoFit;

uiNamespace setVariable ["AP_casTable", _table];

[_ctrl, "casino", { [] call AP_fnc_casinoData }] call webui_fnc_on;

// Table switching. The landing's tiles and every table's BACK come through here.
[_ctrl, "casTable", {
    params [["_t", "", [""]]];
    [_t] spawn AP_fnc_casinoOpen;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

// The bet lives in AP_casBet, which fn_casino clamps to 10k-500k. Clamped here
// too so the page cannot widen its own limits by sending a number.
[_ctrl, "casBet", {
    params [["_v", 10000, [0]]];
    AP_casBet = ((round _v) max 10000) min 500000;
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["casino", ([] call AP_fnc_casinoData)];
    _r
}] call webui_fnc_on;

[_ctrl, "casPlay", {
    params [["_game", "", [""]], ["_action", "play", [""]], ["_args", [], [[]]]];
    // the pages call it "coin"; the engine calls it "coinflip"
    if (_game isEqualTo "coin") then { _game = "coinflip" };
    // HI-LO verb names. The page sends hi / lo / cash; the engine takes
    // guess ["hi"|"lo"] and cashout. My brief got this wrong, not the page --
    // translating here keeps the delivered file diffable against a re-drop.
    if (_game isEqualTo "hilo") then {
        if (_action isEqualTo "hi") then { _action = "guess"; _args = ["hi"] };
        if (_action isEqualTo "lo") then { _action = "guess"; _args = ["lo"] };
        if (_action isEqualTo "cash") then { _action = "cashout"; _args = [] };
    };
    if !(_game in ["coinflip", "wheel", "slots", "roulette", "crash", "hilo"]) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "no such table"]]
    };
    // fn_casino's own gate, re-read at the moment of the bet rather than trusted
    // from whatever the page last rendered
    private _gate = ([] call AP_fnc_casinoData) get "gate";
    if (_gate isNotEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", _gate]] };

    // THE BET IS TAKEN HERE, before the intent leaves (2026-09-26 audit). APS_fnc_casinoSRV
    // only ever CREDITS the return -- its money model needs the client to have debited
    // first, as fn_casino's native "play" does -- so a play forwarded without this was a
    // free bet. The bet travels in _args (casBet's clamp never saw it), so it is clamped
    // here and the clamped figure is what the server gets.
    private _spin = _game isEqualTo "wheel" && {_action isEqualTo "spin"};
    private _stake = 0;
    if ((_game in ["coinflip", "slots", "roulette"] && {_action isEqualTo "play"}) || {_game in ["hilo", "crash"] && {_action isEqualTo "deal"}}) then {
        _stake = ((round (_args param [0, 0, [0]])) max 10000) min 500000;
        _args set [0, _stake];
    };
    // A paid wheel spin is a debit too; the free daily is not. AP_wheelFree/AP_wheelCost
    // come from the server's status, asked for when the wheel opens (below) and
    // mirrored by fn_casino.
    if (_spin && {!(missionNamespace getVariable ["AP_wheelFree", false])}) then { _stake = missionNamespace getVariable ["AP_wheelCost", 50000] };
    // ONE STAKE IN FLIGHT PER TABLE. The server silently drops a stake inside its 0.2s
    // anti-spam window or while that table's round is still open, and a page only learns a
    // round is live when the result lands -- so a double-click on crash's PLACE BET took the
    // bank twice for one round. fn_casino clears the claim when this table's result arrives;
    // the 5s lapse covers a result that never comes. isNil runs check-and-claim unscheduled,
    // so two queued calls cannot both get through.
    private _held = false;
    if (_stake > 0 || _spin) then {
        isNil {
            private _p = uiNamespace getVariable ["AP_casPend", ["", -99]];
            _held = (_p select 0) isEqualTo _game && {diag_tickTime - (_p select 1) < 5};
            if (!_held) then { uiNamespace setVariable ["AP_casPend", [_game, diag_tickTime]] };
        };
    };
    if (_held) exitWith { createHashMapFromArray [["ok", false], ["msg", "one at a time"]] };
    // FLAT exitWith: inside a then-block it would only leave the block and the play would go out anyway
    if (_stake > 0 && {!(["atm", "take", _stake] call AP_fnc_uC)}) exitWith {
        uiNamespace setVariable ["AP_casPend", ["", 0]];
        createHashMapFromArray [["ok", false], ["msg", "not enough in the bank"]]
    };
    if (_stake > 0) then { [1] call AP_fnc_ClupdatePartial };
    if (_spin) then { AP_wheelFree = false };

    [[_game, _action, _args], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;
    // The page's balance (and the wheel's FREE label) follow the debit, as its own stub does.
    if (_stake > 0 || _spin) then { [_webuiCtrl, "casino", ([] call AP_fnc_casinoData)] call webui_fnc_push };
    // Deliberately optimistic: the server answers later on casResult. A table
    // that claimed a result here would be inventing one.
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0 }; false }];

[_ctrl, "casino", ([] call AP_fnc_casinoData)] call webui_fnc_push;
// The wheel page never asks whether today's free spin is up, and casPlay has to know
// before it charges for one -- so ask on its behalf. The status comes back through
// fn_casino, which mirrors it to the page and into AP_wheelFree/AP_wheelCost. It holds
// the wheel's in-flight claim too, so a spin cannot go out on a free/paid guess.
if (_table isEqualTo "wheel") then {
    uiNamespace setVariable ["AP_casPend", ["wheel", diag_tickTime]];
    [["wheel", "checkfree", []], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;
};
diag_log format ["[CASINO] %1 ready t=%2", _table, diag_tickTime toFixed 1];
