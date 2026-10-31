// SPDX-License-Identifier: MIT
/*
    fn_registerWorld.sqf -- register a world-state resolver.

    WHY THIS EXISTS
      The mission already maintains server-wide state -- tables, published
      globals, a key/value store -- and none of it means anything to this
      library. requires[] = { "world:fed_robbed" } needs to ask "is the Fed
      down right now?" without this engine ever learning what a Fed is, in
      the same way it asks "does this player have a licence?" without
      learning what a licence is.

      A key does NOT map straight to a variable name. It maps to a
      host-registered resolver, for three reasons worth keeping straight:

        - The library stays ignorant. It knows a key and a piece of code,
          never what a cartel or a purge is -- the same discipline as
          sqlExec, the profile, and the trigger drivers.
        - An unregistered key is a validation problem at preInit, named by
          aq_fnc_validate, and aq_fnc_reachability treats it as making the
          quest unreachable to everyone -- the only claim either diagnostic
          can honestly make about a resolver's eventual TRUTH is whether one
          was registered at all; see the reasoning in that file for why.
        - The mapping stays in one place instead of being scattered through
          every quest that wants to read a published global directly.

    WHAT IT DOES
      Validates and stores key -> CODE in aq_worlds. Unlike an objective
      type, a resolver is NOT probed by calling it: the whole point of a
      resolver is to read state the MISSION maintains, and this call can run
      before that state exists -- srvInit has not necessarily run yet, and a
      resolver reading a published global is reading a variable that may not
      be defined for another several lines of the host's own init. Calling
      it here to test it would not prove the resolver works; it would either
      throw against a world that has not booted, or return a value that
      means nothing yet. That is also why aq_fnc_reachability cannot evaluate
      one either, and why it settles for the same weaker, honest claim this
      file does: registered, or not.

      This makes registerWorld structural-only, like registerTrigger, but
      for a different reason than registerTrigger has: a trigger driver is
      not probed because probing it would leave a side effect behind (an
      action hung on a giver that does not exist); a world resolver is not
      probed because there is nothing yet to correctly probe it against.

      A resolver takes no arguments and is called as:  call <resolver>
      It must be cheap and must not block -- it runs during offer building,
      per candidate quest, for every player who opens a giver (see
      fn_srvAccept.sqf, requires[] evaluation). Anything that queries a
      database belongs behind a cached published variable, not inside a
      resolver. It must also be READ-ONLY: requires[] evaluation is a pure
      function of one player, one quest and the world at that instant, and a
      resolver that mutates anything breaks the property that keeps the
      order offers are built in from changing what is reachable.

      A resolver that throws is caught where it is called (fn_srvAccept.sqf,
      the "world" case), not here -- registration cannot catch a failure
      that has not happened yet. It is reported once per key there, not once
      per evaluation, which matters because a resolver runs on every offer
      build: a log line with no throttle on a call site that busy is the
      amplifier this library designs against elsewhere (AQ_Settings >>
      factRateLimit is the other place that same lesson is applied).

    Usage:  ["fed_robbed", { !isNil "AP_fed_robbed" && {AP_fed_robbed} }] call aq_fnc_registerWorld;
            ["cartel_arms", { ["arms"] call AP_fnc_cartelOwner }]        call aq_fnc_registerWorld;
*/

params [
    ["_key",  "", [""]],
    ["_code", {}, [{}]]
];

if (_key isEqualTo "") exitWith {
    diag_log "[AQ] registerWorld: refused, empty world key";
    false
};
if (_code isEqualTo {}) exitWith {
    diag_log format ["[AQ] registerWorld: refused '%1', empty implementation", _key];
    false
};

if (isNil {localNamespace getVariable "aq_worlds"}) then { localNamespace setVariable ["aq_worlds", createHashMap]; };

if (!(isNil { (localNamespace getVariable "aq_worlds") get _key })) then {
    diag_log format ["[AQ] registerWorld: '%1' replaced an existing registration", _key];
};

(localNamespace getVariable "aq_worlds") set [_key, _code];

// A re-registered key gets a clean slate on the "reported once" throttle
// (see fn_srvAccept.sqf): the new resolver has not thrown yet, and letting
// a fixed problem stay silent because the OLD resolver already used up this
// key's one log line would hide the very fix this call is making.
if (!isNil "aq_worldErrLogged") then { aq_worldErrLogged deleteAt _key; };

diag_log format ["[AQ] registerWorld: '%1' registered", _key];
true
