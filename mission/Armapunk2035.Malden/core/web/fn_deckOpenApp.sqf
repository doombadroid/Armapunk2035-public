/*
    fn_deckOpenApp.sqf  (AP_fnc_deckOpenApp) -- open the phone ON a given app.

    The one door every native surface uses now. Keybinds, the player-settings
    panel, the cyberdeck ring, quests, talents and the dialer all used to open
    their own dialog; they ask for a deck app by name instead, and the name is
    the registry's own so there is a single vocabulary.

        ["Wanted"] call AP_fnc_deckOpenApp;

    Phone already up  -> the page switches view, no dialog churn.
    Phone closed      -> open it, leaving a flag the page consumes once on boot.
*/
params [["_app", "", [""]], ["_ctx", objNull, [objNull]]];
// World interacts carry the machine they were used on (an ATM, a trunk, a house
// terminal). Stored for the app's SQF handlers to read; the page never sees it.
AP_deckCtx = _ctx;
if (_app isEqualTo "") exitWith { false };
if (!alive player) exitWith { false };

// The name is interpolated into JavaScript source, so a quote in it would break
// the statement. Registry names have none; strip anyway rather than trust it.
private _safe = (_app splitString "\'""") joinString "";

if (!isNull (findDisplay 937500)) exitWith {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (isNull _c) exitWith { diag_log "[DECK] openApp: phone up but no bridge control"; false };
    [_c, format ["if (window.__deckGo) { window.__deckGo('%1'); }", _safe]] call webui_fnc_exec;
    true
};

uiNamespace setVariable ["AP_deckOpenApp", _safe];
[] spawn { closeDialog 0; uiSleep 0.1; [] call AP_fnc_deckPhone };
true
