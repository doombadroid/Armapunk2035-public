// SPDX-License-Identifier: MIT
/*
    types/fn_typeKill.sqf

    Objective type "kill" — N kills matching an optional filter.

    WHY THIS EXISTS
        A kill objective that hooks the engine's killed event directly ends up
        counting things nobody meant it to: a roadkill during the drive there, a
        teammate's shot on a target the player never saw, a unit that died to
        the terrain. It also has no way to know what the host considers a
        faction, because on a roleplay-economy server "the gang" is usually a variable
        the host set on a spawned unit rather than anything in the config. So
        this type counts only what the host chose to fire, and applies its
        filter to facts the host can actually supply.

        The filter is deliberately a set of independent tests rather than an
        expression. Config that can compute is config that has become code, and
        the point of a plugin contract is that a designer can read an objective
        and know what it counts without opening a script.

    WHAT IT DOES
        arm       subscribes to the kill event and zeroes the accumulator.
        event     applies the filter, adds one, reports the kill as a fact,
                  answers whether the running total has reached the target.
        disarm    drops every subscription. Idempotent, no watcher to kill.
        progress  [killed, needed, "Targets down 3/8"]
        describe  "Kill 8 Raiders near the Foundry"

    CONFIG
        count        NUMBER  how many kills are needed.            default 1
        faction      STRING  only kills matching this count. Matched, in order,
                             against the victim's `aq_faction` object variable,
                             its CfgVehicles faction, and its side. The object
                             variable is listed first because a host that spawns
                             its own factions can set it, and nothing else
                             reliably identifies a hostile group on a Life map.
        vehicleClass STRING  only kills of a unit in (or of) a vehicle of this
                             CfgVehicles class or any class descended from it.
        marker       STRING  only kills inside this marker count.  optional
        radius       NUMBER  metres, used with `marker`.           default 200
        anyKiller    NUMBER  1 = a kill by anyone counts; 0 = only the owning
                             player's kills count.                 default 0
        label        STRING  display name for the target ($STR_ ok). optional
        text         STRING  overrides the generated describe line. optional
        events[]     ARRAY   kill event names. default { "aq_killed" }

    EVENTS CONSUMED
        "aq_killed", args [ _victim, _killer, _meta ]
            _victim  OBJECT   the unit that died.
            _killer  OBJECT   who killed it.
            _meta    HASHMAP  optional overrides the host already knows:
                              "faction" STRING, "vehicleClass" STRING,
                              "pos" ARRAY. Supplied values win over anything
                              read off the object, because by the time a kill
                              event is handled the corpse may already be gone.
        Host call site:  ["aq_killed", [_victim, _killer]] call aq_fnc_event;

    ENGINE API (owned by functions/ — called by name, per DESIGN.md 4, 5)
        [_ctx, _event]       call aq_fnc_subscribe    route _event to this objective
        [_ctx, ""]           call aq_fnc_unsubscribe  "" = every subscription
        [_ctx, _fact, _args] call aq_fnc_report       client->server fact; the
                                                      server re-validates and decides
        [_string, _subst]    call aq_fnc_text         literal or $STR_, plus %SLOT%

    THE SIXTH VERB
        `events` is optional and returns an ARRAY of event names to route here,
        declared before `arm` runs. This type builds its list from config, so it
        answers with an empty array — but it must answer, because a type that
        falls through to its unknown-verb branch writes a line to the RPT every
        time an objective arms.

    Usage:
        ["kill", aq_fnc_typeKill] call aq_fnc_registerType;
        ["progress", _ctx] call aq_fnc_typeKill;   // -> [3, 8, "Targets down 3/8"]
*/

params [
    ["_verb", "", [""]],
    ["_ctx", createHashMap, [createHashMap]]
];

private _qid = _ctx getOrDefault ["quest", "?"];
private _oid = _ctx getOrDefault ["objective", "?"];

private _fail = {
    params ["_msg"];
    diag_log format ["[AQ] typeKill %1/%2: %3", _qid, _oid, _msg];
    switch (toLower _verb) do {
        case "progress": { [0, 0, ""] };
        case "describe": { "" };
        default { false };
    };
};

private _cfg    = _ctx getOrDefault ["cfg", configNull];
private _state  = _ctx getOrDefault ["state", 0];
private _player = _ctx getOrDefault ["player", objNull];
// Radiant slot fills. Empty for an authored quest, and empty is a no-op.
private _subst  = _ctx getOrDefault ["subst", createHashMap];

if !(_state isEqualType createHashMap) exitWith { ["no state HashMap in context"] call _fail };

// `cfg` is a CONFIG for authored quests and a HashMap for generated (radiant)
// ones, and radiant substitution is textual — a template writing count = "%COUNT%"
// has to read back as a number here.
private _cfgGet = {
    params ["_key", "_def"];
    private _v = _def;
    switch (typeName _cfg) do {
        case "HASHMAP": { _v = _cfg getOrDefault [_key, _def]; };
        case "CONFIG": {
            private _e = _cfg >> _key;
            if (isNumber _e) then { _v = getNumber _e }
            else {
                if (isText _e) then {
                    _v = getText _e;
                    // Substitution happens on the way out of config: a bounty
                    // read back through its TEMPLATE must resolve %PLACE% to the
                    // marker it was filled with, or the area filter points at
                    // nothing and rejects every kill.
                    if (!isNil "aq_fnc_text") then { _v = [_v, _subst] call aq_fnc_text };
                }
                else { if (isArray _e) then { _v = getArray _e } };
            };
        };
    };
    if (_def isEqualType 0 && {_v isEqualType ""}) then {
        _v = if (_v isEqualTo "") then { _def } else { parseNumber _v };
    };
    _v
};

private _txt = {
    params [["_s", "", [""]]];
    if (_s isEqualTo "") exitWith { "" };
    if (!isNil "aq_fnc_text") exitWith { [_s, _subst] call aq_fnc_text };
    // UNVERIFIED: `localize` takes the stringtable key without the leading '$'.
    if ((_s select [0,1]) isEqualTo "$") then { localize (_s select [1]) } else { _s }
};

private _need      = ["count", 1] call _cfgGet;
private _faction   = ["faction", ""] call _cfgGet;
private _vehClass  = ["vehicleClass", ""] call _cfgGet;
private _marker    = ["marker", ""] call _cfgGet;
private _radius    = ["radius", 200] call _cfgGet;
private _anyKiller = (["anyKiller", 0] call _cfgGet) > 0;

if (_need < 1) then { _need = 1 };
if (_radius < 1) then { _radius = 200 };

private _pos = if (_marker isEqualTo "") then { [] } else { getMarkerPos _marker };
if (_marker != "" && {_pos isEqualTo [0,0,0]}) then {
    // Loud, but not fatal: an area filter pointing at the map origin would
    // silently reject every kill, which reads in play as a broken quest.
    diag_log format ["[AQ] typeKill %1/%2: marker '%3' does not exist, the area filter is ignored", _qid, _oid, _marker];
    _pos = [];
};

private _place = "";
if (_marker != "") then {
    _place = markerText _marker;
    if (_place isEqualTo "") then { _place = _marker };
    _place = [_place] call _txt;
};

private _label = ["label", ""] call _cfgGet;
if (_label isEqualTo "") then { _label = if (_faction != "") then { _faction } else { "targets" } };
_label = [_label] call _txt;

private _events = ["events", []] call _cfgGet;
if (!(_events isEqualType []) || {_events isEqualTo []}) then { _events = ["aq_killed"] };

switch (toLower _verb) do {

    case "arm": {
        // Re-arming after an abandon-and-retake must start from zero, or the
        // second attempt completes on the first attempt's kills.
        _state set ["cur", 0];
        {
            [_ctx, _x] call aq_fnc_subscribe;
        } forEach _events;
        // "events" is the engine's spelling: aq_fnc_armObjective indexes what it
        // finds under that key into the bus. A second spelling leaves it empty.
        _state set ["events", _events];
        [_ctx, "kill", [0, _need]] call aq_fnc_report;
        true
    };

    case "disarm": {
        [_ctx, ""] call aq_fnc_unsubscribe;
        _state set ["events", []];
        true
    };

    // Optional sixth verb: subscriptions come from config, so nothing is
    // declared here — but the verb must be answered rather than fall through.
    case "events": { [] };

    case "event": {
        (_ctx getOrDefault ["event", ["", []]]) params [["_name", "", [""]], ["_args", [], [[]]]];
        if !(_name in _events) exitWith { false };

        private _victim = _args param [0, objNull, [objNull]];
        private _killer = _args param [1, objNull, [objNull]];
        private _meta   = _args param [2, createHashMap, [createHashMap]];

        if (!_anyKiller && {!(_killer isEqualTo _player)}) exitWith { false };

        // The filter is one flag carried through independent tests rather than
        // an early exit per test: `exitWith` inside a nested block leaves only
        // that block, which is the quiet way a filter ends up not filtering.
        private _ok = true;

        // faction: the host's own label first, because on a roleplay-economy map a
        // hostile group is something the host spawned and tagged, not a
        // CfgVehicles faction.
        if (_ok && {_faction != ""}) then {
            private _vf = _meta getOrDefault ["faction", ""];
            if (_vf isEqualTo "" && {!isNull _victim}) then { _vf = _victim getVariable ["aq_faction", ""] };
            if (_vf isEqualTo "" && {!isNull _victim}) then { _vf = faction _victim };
            _ok = (toLower _vf) isEqualTo (toLower _faction);
            if (!_ok && {!isNull _victim}) then {
                _ok = (toLower str (side _victim)) isEqualTo (toLower _faction);
            };
        };

        if (_ok && {_vehClass != ""}) then {
            private _vc = _meta getOrDefault ["vehicleClass", ""];
            if (_vc isEqualTo "" && {!isNull _victim}) then { _vc = typeOf (vehicle _victim) };
            // UNVERIFIED: `isKindOf` with an explicit CfgVehicles context so a
            // base class such as "Car" or "Air" matches every descendant.
            // Confirm with:  "B_Truck_01_transport_F" isKindOf ["Car", configFile >> "CfgVehicles"]
            _ok = _vc != "" && {_vc isKindOf [_vehClass, configFile >> "CfgVehicles"]};
        };

        if (_ok && {!(_pos isEqualTo [])}) then {
            private _at = _meta getOrDefault ["pos", []];
            if (_at isEqualTo [] && {!isNull _victim}) then { _at = getPosATL _victim };
            _ok = !(_at isEqualTo []) && {_at distance2D _pos <= _radius};
        };

        if (!_ok) exitWith { false };

        private _cur = (_state getOrDefault ["cur", 0]) + 1;
        _state set ["cur", _cur];
        [_ctx, "kill", [_cur, _need]] call aq_fnc_report;
        _cur >= _need
    };

    case "progress": {
        private _cur = _state getOrDefault ["cur", 0];
        [_cur min _need, _need, format ["%1 down %2/%3", _label, _cur min _need, _need]]
    };

    case "describe": {
        private _t = ["text", ""] call _cfgGet;
        if (_t != "") exitWith { [_t] call _txt };
        private _what = if (_vehClass != "") then { format ["%1 (%2)", _label, _vehClass] } else { _label };
        if (_place != "") exitWith { format ["Kill %1 %2 near %3", _need, _what, _place] };
        format ["Kill %1 %2", _need, _what]
    };

    default { [format ["unknown verb '%1'", _verb]] call _fail };
};
