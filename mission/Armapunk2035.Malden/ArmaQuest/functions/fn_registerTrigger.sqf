// SPDX-License-Identifier: MIT
/*
    fn_registerTrigger.sqf -- register a giver interaction driver.

    WHY THIS EXISTS
      How a player reaches a giver is a property of the host, not of the quest
      system: a scroll action, a phone app, a radio menu and a terminal screen
      are all the same event as far as quests are concerned. Hardcoding one of
      them into the engine means every host that wants a different one edits
      the engine, and every edit is lost at the next update.

      A driver is therefore named in config (`trigger = "addAction"`) and
      resolved through this registry, so a host adds an interaction style with
      one call and no engine edit -- and a giver naming a driver nobody
      registered is reported by name at validation instead of being a giver
      that silently cannot be talked to.

    WHAT IT DOES
      Validates and stores driverName -> CODE in aq_triggers. Unlike an
      objective type, a driver is NOT probed by calling it: a driver's whole
      job is to have side effects on the world (attach an action, add a phone
      entry), so invoking one to test it would leave that side effect behind
      on a giver that does not exist. Objective types are probed because their
      `describe` and `progress` verbs are required to be pure; there is no
      equivalent pure verb here, so validation is structural only.

      A driver is called as:  [_giverId, _giverObject, _giverConfig] call <driver>
      and it has exactly two obligations when the player interacts:

          ["aq_talked", [_giverId, _giverObject]] call aq_fnc_event;
          [_giverId] call aq_fnc_openOffers;

      The second is the offer screen. The FIRST is easy to leave out and its
      absence is silent: `talk` is the objective type that ends a chain at a
      person, it completes on the interaction event and on nothing else, so a
      driver that skips that line produces quests that can be accepted and can
      never be finished. Nothing else in the library fires aq_talked.

      A driver must be idempotent -- it may be called again for the same giver
      after a respawn or a re-init.

      It is called on the CLIENT, once the giver's object exists there (see
      aq_fnc_postInit). A driver that hangs an action on an object must
      therefore expect the object argument, and a driver that does not need one
      -- a phone app, a radio menu -- is called with objNull and should ignore
      it rather than refuse.

    Usage:  ["phone", myPhoneGiverDriver] call aq_fnc_registerTrigger;
*/

params [
    ["_name", "", [""]],
    ["_code", {},  [{}]]
];

if (_name isEqualTo "") exitWith {
    diag_log "[AQ] registerTrigger: refused, empty driver name";
    false
};
if (_code isEqualTo {}) exitWith {
    diag_log format ["[AQ] registerTrigger: refused '%1', empty implementation", _name];
    false
};

if (isNil {localNamespace getVariable "aq_triggers"}) then { localNamespace setVariable ["aq_triggers", createHashMap]; };

if (!(isNil { (localNamespace getVariable "aq_triggers") get _name })) then {
    diag_log format ["[AQ] registerTrigger: '%1' replaced an existing registration", _name];
};

(localNamespace getVariable "aq_triggers") set [_name, _code];
diag_log format ["[AQ] registerTrigger: '%1' registered", _name];
true
