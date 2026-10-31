// SPDX-License-Identifier: MIT
/*
    fn_unsubscribe.sqf -- drop one objective's routing entries. Idempotent.

    WHY THIS EXISTS
      A subscription that outlives its objective is not a cosmetic leak: it
      still routes events, so it still reports facts for a quest the player no
      longer holds. Unsubscribing therefore has to work on the messy paths --
      called twice, called before `arm` ever ran, called after the quest record
      has already been replaced -- and it has to work when the state map that
      recorded the subscriptions is gone.

      Hence the "" form. A type tearing itself down says "all of mine" rather
      than repeating the list it subscribed to, so a type whose `arm` failed
      part way through its subscribe loop still unwinds completely.

    WHAT IT DOES
        [_ctx, "name"]  drop that one subscription
        [_ctx, ""]      drop every subscription this objective holds; when the
                        state map no longer lists them, sweep the whole index
                        instead, because a leftover entry is the one leak that
                        keeps firing

      Removes the [questId, objectiveId, ...] rows from aq_subs and updates the
      objective state's "events" list to match.

    Usage:  [_ctx, ""] call aq_fnc_unsubscribe;
*/

params [
    ["_ctx",   createHashMap, [createHashMap]],
    ["_event", "",            [""]]
];

if (isNil "aq_subs") then { aq_subs = createHashMap; };

private _questId = _ctx getOrDefault ["quest", ""];
private _objId   = _ctx getOrDefault ["objective", ""];
if (_questId isEqualTo "" || {_objId isEqualTo ""}) exitWith { true };

private _state = _ctx getOrDefault ["state", createHashMap];
private _known = if (_state isEqualType createHashMap) then { _state getOrDefault ["events", []] } else { [] };

private _names = if (_event isEqualTo "") then {
    // Nothing recorded is not "nothing to do": the state map may simply not
    // have survived, and the sweep is what makes this safe on the messy paths.
    if (_known isEqualTo []) then { keys aq_subs } else { _known }
} else {
    [_event]
};

{
    private _name = _x;
    private _list = aq_subs getOrDefault [_name, []];
    private _kept = _list select {
        !(((_x param [0, ""]) isEqualTo _questId) && {(_x param [1, ""]) isEqualTo _objId})
    };
    if (_kept isEqualTo []) then { aq_subs deleteAt _name } else { aq_subs set [_name, _kept] };
} forEach _names;

if (_state isEqualType createHashMap) then {
    if (_event isEqualTo "") then {
        _state set ["events", []];
    } else {
        _state set ["events", _known select { !(_x isEqualTo _event) }];
    };
};

true
