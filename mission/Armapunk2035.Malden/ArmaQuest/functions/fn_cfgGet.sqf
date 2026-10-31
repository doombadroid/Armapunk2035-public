// SPDX-License-Identifier: MIT
/*
    fn_cfgGet.sqf -- read one member from an objective, quest or reward source,
    whether that source is a CONFIG class or a HashMap.

    WHY THIS EXISTS
      An authored quest's objective is a config class. A generated quest's
      objective is a HashMap, because substitution produced values that exist
      only in memory and there is no way to materialise a config class at
      runtime. Every reader in the library therefore has to handle both, and
      before this function existed every one of them handled both in its own
      private copy -- eight objective types and four server files, each with its
      own idea of what a missing key means and its own coercion rules. Twelve
      copies of a rule is twelve chances for one of them to drift, and the
      symptom of a drifted copy is a quest that works when authored and fails
      when generated.

      The numeric coercion is the second reason. Radiant substitution is
      textual, so a template writing `count = "%COUNT%"` produces the STRING
      "12". A type comparing its progress against "12" never completes, and
      nothing errors. So when the caller's default is a number, a string answer
      is parsed into one here, once, rather than in every caller.

    WHAT IT DOES
        [_src, _key, _default]          -> the member, or _default
        [_src, _key, _default, _subst]  -> the same, with %SLOT% substitution
                                           applied to STRING results

      _src may be a CONFIG (isNumber/isText/isArray are tried in that order),
      a HashMap (read by key), or configNull / an empty map (always _default).

      The substitution argument matters only for a CONFIG source: a radiant
      instance's HashMap is already substituted, while a radiant instance whose
      objective is resolved back through the TEMPLATE's config still carries raw
      %SLOT% tokens. Passing the quest record's `subst` map is what makes the
      client read the same text the server generated. An authored quest carries
      an empty map and nothing happens.

    Usage:
        private _need = [_ctx get "cfg", "count", 1] call aq_fnc_cfgGet;
        private _item = [_ctx get "cfg", "item", "", _ctx get "subst"] call aq_fnc_cfgGet;
*/

params [
    ["_src",     configNull, [configNull, createHashMap]],
    ["_key",     "",         [""]],
    ["_default", ""],                                       // untyped: the shape contract
    ["_subst",   createHashMap, [createHashMap]]
];

if (_key isEqualTo "") exitWith {
    diag_log "[AQ] cfgGet: refused, empty key";
    _default
};

private _value = nil;

switch (true) do {
    case (_src isEqualType createHashMap): {
        if !(isNil { _src get _key }) then { _value = _src get _key; };
    };
    case (_src isEqualType configNull): {
        if !(isNull _src) then {
            private _entry = _src >> _key;
            switch (true) do {
                case (isNumber _entry): { _value = getNumber _entry };
                case (isText   _entry): { _value = getText   _entry };
                case (isArray  _entry): { _value = getArray  _entry };
            };
        };
    };
};

if (isNil "_value") exitWith { _default };

// Substitution first, so a numeric slot token becomes "12" before the numeric
// coercion below turns it into 12.
if (_value isEqualType "" && {count _subst > 0} && {!isNil "aq_fnc_text"}) then {
    _value = [_value, _subst] call aq_fnc_text;
};

if (_default isEqualType 0 && {_value isEqualType ""}) then {
    _value = if (_value isEqualTo "") then { _default } else { parseNumber _value };
};

_value
