// SPDX-License-Identifier: MIT
/*
    fn_registerType.sqf -- register an objective type, but only if it answers
    the whole contract.

    WHY THIS EXISTS
      An objective type that implements `arm` and `event` but not `progress`
      or `describe` looks finished: quests using it can be accepted and can be
      completed. What is missing is everything the player sees -- the offer
      screen shows a blank line, the journal shows no counter, the task HUD
      shows nothing. That is a bug with no error and no crash, and it is found
      by a player, weeks later, on a live server.

      So registration is a gate, not a bookkeeping call. A type is probed with
      a dummy context before it is allowed into the registry, and a type that
      does not answer `progress` and `describe` with values of the right shape
      is rejected loudly and is simply not available. Quests using it then
      fail validation by name at preInit -- which is the whole point of the
      plugin contract: an incomplete type cannot reach players.

    WHAT IT DOES
      - Validates the name and the code.
      - Probes `describe` (must answer a STRING) and `progress` (must answer
        [SCALAR, SCALAR, STRING]) against an empty context.
      - Registers into aq_types on success, refuses and logs on failure.

      The probe context carries a REAL config class, `AQ_TypeProbe`, holding one
      plausible value for every member the shipped types read, and an empty
      state map. An earlier version probed against a path that resolves to
      nothing, and it did not do the job it was written for: every shipped type
      exited early down its "this config has no `item`" path, so the probe only
      ever proved that a type's ERROR branch returned the right shapes. A type
      whose real renderer was missing or malformed passed. Probing against a
      class that satisfies the type is what makes the probe test the renderer.

      The state map stays empty on purpose: `describe` is called on the offer
      screen, before any state exists, so a type that cannot render itself from
      config alone is a type that shows a blank line to every player looking at
      the board.

    Usage:  ["gather", aq_fnc_typeGather] call aq_fnc_registerType;
*/

params [
    ["_name", "", [""]],
    ["_code", {},  [{}]]
];

if (_name isEqualTo "") exitWith {
    diag_log "[AQ] registerType: refused, empty type name";
    false
};
if (_code isEqualTo {}) exitWith {
    diag_log format ["[AQ] registerType: refused '%1', empty implementation", _name];
    false
};

if (isNil {localNamespace getVariable "aq_types"}) then { localNamespace setVariable ["aq_types", createHashMap]; };

// ------------------------------------------------------------ probe context
// AQ_TypeProbe ships in config\CfgArmaQuest.hpp. A mission may override it to
// add members its own types read; adding members can only make the probe
// stricter, never weaker.
private _probeCfg = missionConfigFile >> "AQ_TypeProbe";
if (!isClass _probeCfg) then { _probeCfg = configFile >> "AQ_TypeProbe"; };
if (!isClass _probeCfg) then {
    // Missing probe class: fall back to a path that resolves to nothing. The
    // gate still catches a type with no `progress` or `describe` case at all
    // (SQF `switch` yields nil, which is refused below), but it can no longer
    // tell a working renderer from an error branch that happens to return the
    // right shapes. Say so rather than let a weaker check look like the real one.
    // UNVERIFIED: reading a property of a non-existent config class returns
    // ""/0/[] rather than raising.
    diag_log format ["[AQ] registerType: no AQ_TypeProbe class in config, so '%1' is being probed against an empty config. Only the shape of its answers is checked, not that it renders from real values. Is config\\CfgArmaQuest.hpp included?", _name];
    _probeCfg = configFile >> "AQ_TypeProbe_NoSuchClass" >> _name;
};

private _ctx = createHashMapFromArray [
    ["quest",     "__aq_probe"],
    ["objective", "__aq_probe"],
    ["cfg",       _probeCfg],
    ["state",     createHashMap],
    ["player",    objNull],
    ["subst",     createHashMap]
];

// -------------------------------------------------------------- describe
private _desc = ["describe", _ctx] call _code;
if (isNil "_desc") exitWith {
    diag_log format ["[AQ] registerType: REFUSED '%1' -- `describe` returned nothing. Every type must render one line for the offer screen from config alone.", _name];
    false
};
if !(_desc isEqualType "") exitWith {
    diag_log format ["[AQ] registerType: REFUSED '%1' -- `describe` returned %2, expected STRING.", _name, typeName _desc];
    false
};

// -------------------------------------------------------------- progress
private _prog = ["progress", _ctx] call _code;
if (isNil "_prog") exitWith {
    diag_log format ["[AQ] registerType: REFUSED '%1' -- `progress` returned nothing. Expected [cur, max, ""text""].", _name];
    false
};
if (!(_prog isEqualType []) || { count _prog < 3 }) exitWith {
    diag_log format ["[AQ] registerType: REFUSED '%1' -- `progress` returned %2, expected [cur, max, ""text""].", _name, _prog];
    false
};
if (!((_prog select 0) isEqualType 0) ||
    {!((_prog select 1) isEqualType 0)} ||
    {!((_prog select 2) isEqualType "")}) exitWith {
    diag_log format ["[AQ] registerType: REFUSED '%1' -- `progress` shape is wrong: %2. Expected [SCALAR, SCALAR, STRING].", _name, _prog];
    false
};

// --------------------------------------------------------------- register
if (!(isNil { (localNamespace getVariable "aq_types") get _name })) then {
    diag_log format ["[AQ] registerType: '%1' replaced an existing registration", _name];
};
(localNamespace getVariable "aq_types") set [_name, _code];
diag_log format ["[AQ] registerType: '%1' registered", _name];
true
