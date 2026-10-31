// SPDX-License-Identifier: MIT
/*
    fn_task.sqf -- mirror quest state onto the engine's own task system.

    WHY THIS EXISTS
      A quest system whose only display is a custom UI is a quest system that
      is invisible for the first ten minutes of every install, and unusable
      the moment that UI is not available -- no page, no browser control, no
      web layer, or simply a player who never opens it. The engine already
      ships a task list, a map marker, a waypoint and a diary entry, and every
      player already knows how to read them.

      So the native task list is not a nicety, it is the floor: with no UI at
      all, the player still sees what they accepted, what is left, and where
      to go. The HTML journal is then an improvement on a working baseline
      rather than a dependency the whole feature rests on.

    WHAT IT DOES
      Verbs:
        ["init"]                reset the mirror for this client
        ["sync",   _records]    make the task list match the given quest set
        ["select", _questId]    make that quest the current task
        ["remove", _questId]    drop one mirrored task
        ["clear"]               drop all of them

      Only quests the player actually holds are mirrored. An offer is not a
      task: putting a job board on the map as tasks would fill the map with
      work nobody has taken.

      Destination is taken from the quest record's "dest" when the server
      supplied one, otherwise from the first unfinished objective that names a
      marker -- read through aq_fnc_text so a radiant "%PLACE%" slot resolves
      to the marker it was filled with.

    UNVERIFIED, all four load-bearing and all checkable in one session:
      - createSimpleTask names are per player and reusing one returns a
        distinct task, so ids are namespaced with "aq_" here.
      - setSimpleTaskDescription accepts the three-string form and renders
        "<br/>" as a line break in the task list.
      - setTaskState accepts "CREATED"/"ASSIGNED"/"SUCCEEDED"/"FAILED"/
        "CANCELED".
      - removeSimpleTask on an already-removed task is harmless.
      Confirm by accepting a quest, watching the task appear with its
      objective lines, then abandoning it and watching it go.

    Usage:  ["sync", _records] call aq_fnc_task;
*/

params [
    ["_verb", "", [""]],
    ["_arg",  [],  ["", []]]
];

if (!hasInterface) exitWith { false };
if (isNil "aq_tasks") then { aq_tasks = createHashMap; };

// ------------------------------------------------------------- helpers
private _dropTask = {
    params ["_questId"];
    private _t = aq_tasks getOrDefault [_questId, taskNull];
    if !(isNull _t) then { player removeSimpleTask _t; };
    aq_tasks deleteAt _questId;
};

// Where the arrow points. The server's own answer wins, because only the
// server knows where a generated quest actually sent the player.
private _destination = {
    params ["_rec"];
    private _dest = _rec getOrDefault ["dest", []];
    if (_dest isEqualType [] && {count _dest >= 2}) exitWith { _dest };

    private _questId = _rec getOrDefault ["id", ""];
    private _subst   = _rec getOrDefault ["subst", createHashMap];
    private _found   = [];
    {
        if (_found isEqualTo []) then {
            private _marker = [(_x select 1) >> "marker", _subst] call aq_fnc_text;
            if !(_marker isEqualTo "") then {
                private _pos = getMarkerPos _marker;
                // A marker that does not exist reads as the map origin, which
                // would silently point every task at the corner of the world.
                if !(_pos isEqualTo [0,0,0]) then { _found = _pos; };
            };
        };
    } forEach ([_questId, "objectives"] call aq_fnc_cfgQuest);
    _found
};

// The task body: the quest's summary, then one line per objective, straight
// from each type's own progress renderer.
private _describe = {
    params ["_rec"];
    private _questId = _rec getOrDefault ["id", ""];
    private _lines   = [];

    private _summary = _rec getOrDefault ["summary", ""];
    if !(_summary isEqualTo "") then { _lines pushBack _summary; };

    private _order = _rec getOrDefault ["order", []];
    if (_order isEqualTo []) then {
        _order = ([_questId, "objectives"] call aq_fnc_cfgQuest) apply { _x select 0 };
    };

    {
        private _cfg = [_questId, "objective", _x] call aq_fnc_cfgQuest;
        if !(isNull _cfg) then {
            private _type = (localNamespace getVariable "aq_types") getOrDefault [getText (_cfg >> "type"), {}];
            if !(_type isEqualTo {}) then {
                private _ctx = [_questId, _x] call aq_fnc_ctx;
                if !(count _ctx isEqualTo 0) then {
                    private _p = ["progress", _ctx] call _type;
                    if (!isNil "_p" && {_p isEqualType []} && {count _p >= 3}) then {
                        _lines pushBack format ["%1 (%2/%3)", _p select 2, _p select 0, _p select 1];
                    };
                };
            };
        };
    } forEach _order;

    _lines joinString "<br/>"
};

// --------------------------------------------------------------- verbs
switch (toLower _verb) do {

    case "init": {
        { [_x] call _dropTask; } forEach (keys aq_tasks);
        aq_tasks = createHashMap;
        true
    };

    case "clear": {
        { [_x] call _dropTask; } forEach (keys aq_tasks);
        true
    };

    case "remove": {
        [if (_arg isEqualType "") then { _arg } else { "" }] call _dropTask;
        true
    };

    case "select": {
        private _questId = if (_arg isEqualType "") then { _arg } else { "" };
        private _t = aq_tasks getOrDefault [_questId, taskNull];
        if (isNull _t) exitWith { false };
        player setCurrentTask _t;
        true
    };

    case "sync": {
        private _records = if (_arg isEqualType []) then { _arg } else { [] };

        private _seen = [];
        {
            private _rec   = _x;
            if (_rec isEqualType createHashMap) then {
                private _id    = _rec getOrDefault ["id", ""];
                private _state = _rec getOrDefault ["state", ""];

                // An offer is not a task.
                if (!(_id isEqualTo "") && {!(_state isEqualTo "offered")}) then {
                    _seen pushBack _id;

                    private _t = aq_tasks getOrDefault [_id, taskNull];
                    if (isNull _t) then {
                        _t = player createSimpleTask [format ["aq_%1", _id]];
                        aq_tasks set [_id, _t];
                    };

                    _t setSimpleTaskDescription [
                        [_rec] call _describe,
                        _rec getOrDefault ["title", _id],
                        _rec getOrDefault ["title", _id]
                    ];

                    private _icon = _rec getOrDefault ["icon", ""];
                    if !(_icon isEqualTo "") then { _t setSimpleTaskType _icon; };

                    private _dest = [_rec] call _destination;
                    if !(_dest isEqualTo []) then { _t setSimpleTaskDestination _dest; };

                    _t setTaskState (switch (toLower _state) do {
                        case "active":    { "ASSIGNED" };
                        case "completed": { "SUCCEEDED" };
                        case "failed":    { "FAILED" };
                        case "expired":   { "FAILED" };
                        case "abandoned": { "CANCELED" };
                        default           { "CREATED" };
                    });
                };
            };
        } forEach _records;

        // Anything the server no longer mentions is gone, not stale. A task
        // left behind for a quest that no longer exists is the same lie as a
        // watcher left running for it.
        { if !(_x in _seen) then { [_x] call _dropTask; }; } forEach (keys aq_tasks);
        true
    };

    default {
        diag_log format ["[AQ] task: unknown verb '%1'", _verb];
        false
    };
}
