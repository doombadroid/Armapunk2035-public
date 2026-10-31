// SPDX-License-Identifier: MIT
/*
    fn_setting.sqf -- read one AQ_Settings key, with a typed default.

    WHY THIS EXISTS
      Every part of this library needs a handful of numbers out of AQ_Settings,
      and every part of it would otherwise grow its own reader. Three readers
      means three different answers to "the key is absent", "the key is there
      but is a string where a number was wanted", and "AQ_Settings does not
      exist at all" -- and the wrong answer to any of those is a silent
      behaviour change nobody can trace back to config. One reader, one set of
      answers, one place to log the mistake.

      The typed default is the whole point. A caller says what shape it can use
      and gets exactly that shape back, so a config typo can never reach a
      caller as a value it will then use in arithmetic.

    WHAT IT DOES
      Resolves AQ_Settings (the index built at preInit first, then
      missionConfigFile, then configFile), reads the key as number, text or
      array, and returns it. Returns the default when the class or the key is
      absent, and returns the default WITH A LOG LINE when the key exists but
      is of a different type from the default -- an absent key is a legitimate
      authoring choice, a mistyped one is not.

    Usage:
        private _iv    = ["flushInterval", 60]      call aq_fnc_setting;
        private _mode  = ["boardMode", "shared"]    call aq_fnc_setting;
        private _sides = ["sideMap", [["civ","CIV"]]] call aq_fnc_setting;
*/

params [
    ["_key",     "", [""]],
    ["_default", 0]              // deliberately untyped: it is the shape contract
];

if (_key isEqualTo "") exitWith {
    diag_log "[AQ] setting: refused, empty key";
    _default
};

private _cfg = configNull;
_cfg = (localNamespace getVariable ["aq_cfg", createHashMap]) getOrDefault ["settings", configNull];   // LOCAL PATCH (VENDORED.txt): localNamespace
if (isNull _cfg) then {
    _cfg = missionConfigFile >> "AQ_Settings";
    if (!isClass _cfg) then { _cfg = configFile >> "AQ_Settings"; };
};
if (!isClass _cfg) exitWith { _default };

private _entry = _cfg >> _key;
private _value = switch (true) do {
    case (isNumber _entry): { getNumber _entry };
    case (isText   _entry): { getText   _entry };
    case (isArray  _entry): { getArray  _entry };
    default { nil };
};

if (isNil "_value") exitWith { _default };

// isEqualType compares the outer type only, so an ARRAY default accepts any
// array. That is intended: the shape inside an array is the caller's business.
if !(_value isEqualType _default) exitWith {
    diag_log format ["[AQ] setting: AQ_Settings >> %1 is a %2, expected %3; using the default %4",
        _key, typeName _value, typeName _default, _default];
    _default
};

_value
