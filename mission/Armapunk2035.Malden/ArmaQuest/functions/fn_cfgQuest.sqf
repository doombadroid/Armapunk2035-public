// SPDX-License-Identifier: MIT
/*
    fn_cfgQuest.sqf -- the only way the runtime reads the catalogue.

    WHY THIS EXISTS
      Everything the runtime asks of the config is asked on a hot path: an
      event arriving, a watcher ticking, a journal repaint. The natural way to
      answer -- walk missionConfigFile until the class name matches -- costs
      more the more quests exist, so a server with a large catalogue runs
      slower than one with three quests, for every player, all the time. The
      indexes are built once at preInit and this is the accessor over them, so
      every lookup here is a HashMap hit regardless of catalogue size.

      It is also the one place that knows how a radiant instance id maps back
      to config. A generated quest has no class of its own; its id is
      "<templateId>#<serial>" and its objective definitions live in the
      template. Putting that convention in one function means the rest of the
      engine never has to care whether a quest was authored or generated.

    WHAT IT DOES
        [_id]                        -> CONFIG   the quest (or template) class
        [_id, "objectives"]          -> ARRAY    [[objId, CONFIG], ...], in
                                                 declaration order
        [_id, "objective", _objId]   -> CONFIG   one objective, configNull if
                                                 there is no such objective
        [_id, "rewards"]             -> CONFIG   the rewards class
        [_id, "text", _field]        -> STRING   a field resolved through
                                                 aq_fnc_text, with the quest
                                                 record's slot substitutions
                                                 applied when it has any

      An unknown id answers configNull / [] / "" and logs once per call rather
      than throwing, because the callers are watchers and event handlers where
      an exception costs the whole loop.

    Usage:
        private _objs = ["copper_run", "objectives"] call aq_fnc_cfgQuest;
        private _title = ["bounty#41", "text", "title"] call aq_fnc_cfgQuest;
*/

params [
    ["_id",    "", [""]],
    ["_what",  "", [""]],
    ["_key",   "", [""]]
];

if (_id isEqualTo "") exitWith {
    diag_log "[AQ] cfgQuest: refused, empty id";
    switch (toLower _what) do {
        case "objectives": { [] };
        case "text":       { "" };
        default            { configNull };
    }
};

if (isNil "aq_idxQuest") exitWith {
    diag_log "[AQ] cfgQuest: indexes do not exist -- aq_fnc_preInit has not run";
    configNull
};

// A radiant instance carries its template in its id; everything to the left
// of the separator is the class that actually exists in config.
private _base = _id;
private _sep  = _id find "#";
if (_sep > 0) then { _base = _id select [0, _sep]; };

private _cfg = aq_idxQuest getOrDefault [_base, configNull];
if (isNull _cfg) then { _cfg = aq_idxTemplate getOrDefault [_base, configNull]; };

if (isNull _cfg) exitWith {
    diag_log format ["[AQ] cfgQuest: no quest or template '%1' (asked for '%2')", _base, _id];
    switch (toLower _what) do {
        case "objectives": { [] };
        case "text":       { "" };
        default            { configNull };
    }
};

switch (toLower _what) do {

    case "": { _cfg };

    case "objectives": {
        aq_idxObj getOrDefault [_base, []]
    };

    case "objective": {
        private _map = aq_idxObjMap getOrDefault [_base, createHashMap];
        private _hit = _map getOrDefault [_key, configNull];
        if (isNull _hit) then {
            diag_log format ["[AQ] cfgQuest: quest '%1' has no objective '%2'", _base, _key];
        };
        _hit
    };

    case "rewards": {
        private _r = _cfg >> "rewards";
        if (isClass _r) then { _r } else { configNull }
    };

    case "text": {
        // Slot substitutions come from the live quest record when there is
        // one, so an authored quest and a generated instance are read the
        // same way by every caller.
        private _rec   = (localNamespace getVariable "aq_quests") getOrDefault [_id, createHashMap];
        private _subst = _rec getOrDefault ["subst", createHashMap];
        [_cfg >> _key, _subst] call aq_fnc_text
    };

    default {
        diag_log format ["[AQ] cfgQuest: unknown request '%1' for quest '%2'", _what, _id];
        configNull
    };
}
