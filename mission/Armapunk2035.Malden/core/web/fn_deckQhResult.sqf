/*
    fn_deckQhResult.sqf  (AP_fnc_deckQhResult) — how a quickhack ended, on the
    channel the ICEBREAKER OS / TAL OS screen listens to.

    CfgRE allowedTargets = 1 (server -> client only). Pushed by APS_fnc_qhSRV the
    moment its upload clock finishes.

    WHY THIS EXISTS AT ALL. Everything else the deck needs is already client-side:
    the cooldown, the loadout, the target list, even the victim's trace window.
    The one thing that is not is whether the cast died on an ICE FIREWALL --
    chip 108 is resolved on the server because the chip has to be destroyed and
    persisted, so the caster's client has no way to know. Without this push the
    screen would show a successful hack that quietly did nothing.

    The native path still reports through handleMessage as it always did; this is
    the same news on a second channel, not a replacement.

    Usage (server):  [[_id, _name, _iced], "AP_fnc_deckQhResult", _hacker, false] spawn AP_fnc_MP;
*/

if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_id", "", [""]], ["_name", "", [""]], ["_iced", false, [false]]];
if (_id isEqualTo "") exitWith {};

// Remember it regardless of whether the phone is open — the screen shows LAST
// CAST when it next opens, and "what happened to the hack I just fired" is the
// first thing a player looks for after closing the handset to watch the result.
AP_qhLastResult = createHashMapFromArray [
    ["hackId", _id],
    ["name",   _name],
    ["iced",   _iced],
    ["ok",     !_iced],
    ["t",      diag_tickTime],
    ["msg",    if (_iced) then { "ICE FIREWALL -- the hack died on it" } else { "UPLOAD COMPLETE" }]
];

private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
if (isNull _c) exitWith {};
if (isNull (findDisplay 937500)) exitWith {};      // deck is not open; the value is stored above

[_c, "qhResult", AP_qhLastResult] call webui_fnc_push;
