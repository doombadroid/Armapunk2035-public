/*
    fn_holdemReceive.sqf  (AP_fnc_holdemReceive) -- receive half of APS_fnc_holdemSRV.

    The server rebuilds the whole table PER VIEWER -- what you may see differs from what the seat
    next to you may see -- and sends the result here. This file forwards it onto the page's channel
    and keeps a copy. It decides nothing, and it must not: five other people are looking at the same
    hand and only the server knows what is in it.

    THE COPY IS NOT DECORATION. AP_fnc_holdemBridge answers hSit / hAct / hLeave synchronously
    (webui handlers are `call`ed and must return a value now), so its local refusals -- "it is not
    your turn", "that raise is under the minimum" -- are read off the LAST STATE THE SERVER SENT.
    Nothing here is an authority; every one of those checks is re-run server-side against the
    server's own table, and the server's answer arrives as the next push. This only makes the common
    refusals instant instead of a round trip.

    Args: ["table", _state]
*/

params [["_kind", "", [""]], ["_payload", createHashMap, [createHashMap, []]]];
// Server-origin gate, the AP_fnc_casinoReceive idiom: APS_fnc_holdemSRV (server, owner 2) is the
// only legitimate caller. This pushes the table a player acts on, so a local or client-forged call
// would let a modified client paint itself a hand -- and then the bridge's local pre-checks, which
// read this state, would agree with it. The server would still refuse every action, but the player
// would be looking at a table that does not exist.
if (remoteExecutedOwner != 2) exitWith {};
if (_kind isNotEqualTo "table") exitWith {};

// Kept whether or not the page is up, so a snapshot that lands a frame before the control binds is
// still the state the bridge reads.
uiNamespace setVariable ["AP_holdemState", _payload];

private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
if (isNull _c) exitWith {};
if (isNull (findDisplay 930422)) exitWith {};        // the hold'em dialog is not up

[_c, "holdem", _payload] call webui_fnc_push;

// The page subscribes to "casino" for the bank figure in its header, and SQF only pushes that at
// open -- so without this the header freezes at whatever the balance was when the table loaded,
// through the buy-in and through cashing out. AP_atmcash itself is always right; it is only ever
// the display. Mirrored on the table snapshot because that is the one message every state change
// already sends. Exactly what fn_bjTable.sqf does, and for the same reason.
[_c, "casino", ([] call AP_fnc_casinoData)] call webui_fnc_push;
