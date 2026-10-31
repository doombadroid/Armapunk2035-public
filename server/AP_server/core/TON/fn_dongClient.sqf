/*
    APS_fnc_dongClient  (LooneyBin: REPAIRED anti-cheat handler)
    Was a passthrough that fed [player, [report]] straight into APS_fnc_checkHacks, which forEach's its
    arg as a PLAYER LIST -> it scanned the player (ok) but treated the memhack-report element as a
    "player" (garbage scan). Now: scan the player's gear cleanly AND record the 2020 client's tamper
    report so it isn't silently dropped. Detection/action plan lives in CLANKR.md.

    Client args: [player, [code, varName, value]]   (code 50 = MAIN_RE remote-exec tamper)
*/
params [["_player", objNull, [objNull]], ["_report", [], [[]]]];
// owner 2026-06-23 SECURITY (anti-frame, prereq for any DONG auto-action): re-derive the SUBJECT from the
// NON-SPOOFABLE remoteExecutedOwner, NOT the passed _player. A client could remoteExec this carrying a VICTIM's
// object to frame them -> false -DONG- row attributed to the victim, and a griefing auto-ban once CLANKR wires
// action. 0 = server-internal -> keep the passed object.
private _src = remoteExecutedOwner;
if (_src != 0) then { _player = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]; };
if (isNull _player) exitWith {};

[_player] call APS_fnc_checkHacks;   // illegal-equipment scan on the REAL caller

if (count _report >= 1) then {_report params [["_code", -1, [0]], ["_var", "", [""]], ["_val", "", [""]]];
    // owner 2026-06-23 (#3): human-readable code labels so -DONG- rows are actionable (was bare "code=50").
    // Action plan (which codes kick/ban/ping) lives in CLANKR.md -> §"DONG action plan". Still log-only here.
    private _label = switch (_code) do {case 1:  { "filePatching enabled (modified client)" };
        case 3:  { "inventory item-count hack" };
        case 50: { "MAIN_RE cheat-menu signature" };
        case 51: { "admin-level changed mid-session" };
        case 52: { "malicious scroll-menu action" };
        case 55: { "admin-state vars tampered" };
        case 56: { "admin display open while non-admin" };
        case 60: { "spoofed client message (illegal handleMessage RE)" };
        case 61; case 62: { "illegal shop/cartel access" };
        case 63; case 64; case 65: { "netSetVar illegal var broadcast" };
        case 69: { "explosion near player (explosive/VDM)" };
        case 70: { "ticket-value tamper" };
        case 71: { "playtime-stat tamper" };
        case 75; case 76; case 77; case 78: { "money-receive anomaly" };
        default { "unknown" };};
    ["-DONG-", _player, format ["[%1] %2 | var=%3 val=%4", _code, _label, _var, _val]] call APS_fnc_logIt;};
