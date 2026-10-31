/*
    fn_bjTable.sqf — receive half of APS_fnc_bjTableSRV.

    The server rebuilds the whole table snapshot per viewer and sends it here;
    this only forwards it onto the page's channel. It decides nothing, and it
    must not, because every other seat is looking at the same round.

    Args: ["table"|"you"|"event", _payload]
*/

params [["_kind", "", [""]], ["_payload", createHashMap, [createHashMap, []]]];
if (remoteExecutedOwner != 2) exitWith {};          // server-origin only

private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
if (isNull _c) exitWith {};
if (isNull (findDisplay 930420)) exitWith {};       // the table dialog is not up

private _chan = switch (_kind) do {
    // DOTS, NOT COLONS (owner 2026-09-03, "blackjack won't let either of us sit"): the webui audit sweep
    // of 2026-08-29 made fn_push refuse any channel outside [A-Za-z_][A-Za-z0-9_.-]* -- a name is spliced
    // into a JavaScript string literal, so player-derived text in one was an injection path. These three
    // were "bj:table" / "bj:you" / "bj:event"; every table snapshot was refused on the client ("[WEBUI]
    // push refused 'bj:table'") and the page never saw a seat to take. The page subscribes by these names.
    case "table": { "bj.table" };
    case "you":   { "bj.you" };
    case "event": { "bj.event" };
    default       { "" };
};
if (_chan isEqualTo "") exitWith {};

[_c, _chan, _payload] call webui_fnc_push;

// The page subscribes to "casino" for the bank figure but SQF only pushed it at
// open, so the header froze at whatever the balance was when the table loaded --
// through every bet, double and payout. AP_atmcash itself was always right; it
// was only ever the display. Mirrored on the table snapshot because that is the
// one message every state change already sends.
if (_kind isEqualTo "table") then {
    [_c, "casino", ([] call AP_fnc_casinoData)] call webui_fnc_push;
};
