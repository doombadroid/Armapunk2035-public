// SPDX-License-Identifier: MIT
/*
    fn_fact.sqf -- report a fact to the server. The client never reports a
    verdict.

    WHY THIS EXISTS
      The whole trust model of the system passes through this one function. A
      client that can say "I finished quest X" is a client that can pay itself
      the entire reward table, and no amount of care elsewhere matters. So the
      client is only ever allowed to say what happened to it -- "I sold 10
      copper", "I am inside marker foundry" -- and the server holds the state
      machine, decides which objective (if any) that reaches, re-checks the
      claim against the objective's own rules, and decides what it means.

      A second, quieter reason: a modified client can also flood. A fact per
      frame from thirty players is a server that stops answering. The rate limit
      here is the honest client's share of self-restraint; the server limits
      again on the same key and the same window, because a limit that only
      exists on the client is not a limit.

    WHAT IT DOES
      - Drops facts while the system is disarmed, and on any machine with no
        interface: a type's `event` verb is also run BY THE SERVER, and the
        server has no fact to report to itself.
      - Applies a sliding-window rate limit, logging once per window when it
        bites rather than once per dropped fact.
      - Sends [player, name, args] to aq_fnc_srvFact on the server.

      The player object is sent so the server has something whose ownership it
      can check; it is not an identity the server takes on trust. Every server
      entry point re-derives the caller from remoteExecutedOwner and refuses to
      act for a unit the calling machine does not own, so a modified client
      naming somebody else's unit is logged as what it is.

      UNVERIFIED: for a hosted (non-dedicated) player, the call runs locally
      and remoteExecutedOwner reads 0 rather than that player's client id.
      Confirm on a listen server; the server side is expected to treat owner 0
      as the host player.

    Usage:  ["aq_sold", ["copper", 10]] call aq_fnc_fact;
*/

params [
    ["_name", "", [""]],
    ["_args", [],  [[]]]
];

if (_name isEqualTo "") exitWith {
    diag_log "[AQ] fact: refused, unnamed fact";
    false
};
if (!hasInterface) exitWith { false };
if (isNil "aq_ready" || {!aq_ready}) exitWith { false };

// ------------------------------------------------------------- rate limit
// One key, one window, shared with the server's own limiter: two caps under
// two names is how a client comes to be silently throttled at a rate no
// setting mentions. Read from config once and cached, because this is the hot
// path.
if (isNil "aq_factLimit") then {
    aq_factLimit  = ["factRateLimit", 60] call aq_fnc_setting;   // per ten seconds
    if (!(aq_factLimit isEqualType 0) || {aq_factLimit < 1}) then { aq_factLimit = 60; };
    aq_factWindow = 10;
    aq_factBucket = [0, 0, false];   // [windowStart, count, warned]
};
if (isNil "aq_factBucket") then { aq_factBucket = [0, 0, false]; };

private _now = diag_tickTime;
aq_factBucket params ["_start", "_count", "_warned"];

if (_now - _start > aq_factWindow) then {
    aq_factBucket = [_now, 0, false];
    aq_factBucket params ["_start", "_count", "_warned"];
};

if (_count >= aq_factLimit) exitWith {
    if (!_warned) then {
        aq_factBucket set [2, true];
        diag_log format ["[AQ] fact: rate limit hit (%1 facts in %2s), dropping until the window rolls. Latest '%3'. An instrumented site is probably firing per frame, or an objective's reportEvery is too low.", aq_factLimit, aq_factWindow, _name];
    };
    false
};

aq_factBucket set [1, _count + 1];

// ------------------------------------------------------------------ send
[player, _name, _args] remoteExec ["aq_fnc_srvFact", 2];
true
