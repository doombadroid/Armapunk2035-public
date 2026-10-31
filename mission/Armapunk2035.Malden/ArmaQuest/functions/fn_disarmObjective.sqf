// SPDX-License-Identifier: MIT
/*
    fn_disarmObjective.sqf -- tear one objective down completely, twice if
    asked.

    WHY THIS EXISTS
      Disarm runs on the messy paths: abandon, expiry, failure, a disconnect,
      a server correction that says this quest is no longer yours. Those paths
      overlap, so disarm gets called twice for the same objective more often
      than it gets called once -- and they are also the paths where the quest
      record may already be gone, so a teardown that depends on the record
      existing tears nothing down at all.

      A surviving watcher is not a cosmetic leak: it still reports facts for a
      quest the player no longer holds. So this function assumes nothing about
      what still exists, kills every handle itself rather than trusting the
      type to have done it, and does the same thing whether it is the first
      call or the fourth.

    WHAT IT DOES
      - Calls the type's `disarm` when the type and context can still be
        resolved; carries on regardless.
      - Terminates every handle recorded in the objective's state.
      - Removes every bus subscription naming this objective, falling back to
        a full sweep of the bus index when the state map is gone.
      - Clears the armed flag.

      Handle vocabulary recorded in state "handles" -- a type may push any of:
        SCRIPT                              a spawn handle, terminated
        CODE                                a teardown closure, called
        ["eh", _obj, "EventName", _id]      removeEventHandler
        ["mission", "EventName", _id]       removeMissionEventHandler
        ["action", _obj, _id]               removeAction
      Anything else is logged and ignored, because a handle the engine cannot
      classify is a leak that should be visible.

    Usage:  ["copper_run", "have"] call aq_fnc_disarmObjective;
*/

params [
    ["_questId", "", [""]],
    ["_objId",   "", [""]]
];

if (_questId isEqualTo "" || {_objId isEqualTo ""}) exitWith {
    diag_log "[AQ] disarmObjective: refused, empty id";
    false
};

if (isNil "aq_subs")     then { aq_subs     = createHashMap; };
if (isNil "aq_armedObj") then { aq_armedObj = createHashMap; };
if (isNil {localNamespace getVariable "aq_quests"})   then { localNamespace setVariable ["aq_quests", createHashMap]; };
if (isNil {localNamespace getVariable "aq_types"})    then { localNamespace setVariable ["aq_types", createHashMap]; };

private _key = format ["%1|%2", _questId, _objId];

// --------------------------------------------------- state, if there is any
private _state = createHashMap;
private _rec   = (localNamespace getVariable "aq_quests") getOrDefault [_questId, createHashMap];
if !(count _rec isEqualTo 0) then {
    private _objs = _rec getOrDefault ["objectives", createHashMap];
    _state = _objs getOrDefault [_objId, createHashMap];
};

// ---------------------------------------------------------- type teardown
// Best effort: the type gets its chance to clean up state only it understands,
// but nothing below depends on it having succeeded.
private _cfg = [_questId, "objective", _objId] call aq_fnc_cfgQuest;
if (!isNull _cfg) then {
    private _type = (localNamespace getVariable "aq_types") getOrDefault [getText (_cfg >> "type"), {}];
    if !(_type isEqualTo {}) then {
        private _ctx = createHashMapFromArray [
            ["quest",     _questId],
            ["objective", _objId],
            ["cfg",       _cfg],
            ["state",     _state],
            ["player",    if (hasInterface) then { player } else { objNull }],
            ["subst",     _rec getOrDefault ["subst", createHashMap]]
        ];
        ["disarm", _ctx] call _type;
    };
};

// ------------------------------------------------------------- kill handles
// Done by the engine even though `disarm` was just given the chance, because
// "the type promised" is not a guarantee, and the cost of terminating an
// already-dead handle is nothing.
{
    private _h = _x;
    switch (true) do {
        case (_h isEqualType scriptNull): { terminate _h; };
        case (_h isEqualType {}):         { call _h; };
        case (_h isEqualType []): {
            switch (toLower (_h param [0, ""])) do {
                case "eh": {
                    _h params ["", ["_o", objNull, [objNull]], ["_ev", "", [""]], ["_id", -1, [0]]];
                    if (!isNull _o && {_id >= 0}) then { _o removeEventHandler [_ev, _id]; };
                };
                case "mission": {
                    _h params ["", ["_ev", "", [""]], ["_id", -1, [0]]];
                    if (_id >= 0) then { removeMissionEventHandler [_ev, _id]; };
                };
                case "action": {
                    _h params ["", ["_o", objNull, [objNull]], ["_id", -1, [0]]];
                    if (!isNull _o && {_id >= 0}) then { _o removeAction _id; };
                };
                default {
                    diag_log format ["[AQ] disarmObjective: %1/%2 left an unrecognised handle: %3", _questId, _objId, _h];
                };
            };
        };
        default {
            diag_log format ["[AQ] disarmObjective: %1/%2 left an unrecognised handle: %3", _questId, _objId, _h];
        };
    };
} forEach (_state getOrDefault ["handles", []]);

_state set ["handles", []];

// ----------------------------------------------------------- unsubscribe
// Prefer the recorded event names; fall back to sweeping the whole index when
// the state map did not survive, because a subscription left behind is the
// one leak that keeps reporting facts.
private _names = _state getOrDefault ["events", []];
if (_names isEqualTo []) then { _names = keys aq_subs; };

{
    private _ev   = _x;
    private _list = aq_subs getOrDefault [_ev, []];
    private _kept = _list select { !((_x param [0, ""]) isEqualTo _questId) || {!((_x param [1, ""]) isEqualTo _objId)} };
    if (_kept isEqualTo []) then {
        aq_subs deleteAt _ev;
    } else {
        aq_subs set [_ev, _kept];
    };
} forEach _names;

_state set ["events", []];
aq_armedObj deleteAt _key;

true
