// SPDX-License-Identifier: MIT
/*
    fn_text.sqf -- the one way a config value becomes a string a player sees.

    WHY THIS EXISTS
      Two audiences want opposite things from text. Someone trying the library
      out wants to type a sentence into the quest and see it in game; someone
      shipping to a mixed-language community needs every line to come from a
      stringtable. Picking one makes the library useless to the other half:
      hardcoding a language means a rewrite to translate, requiring a
      stringtable means the one-file example needs two files and a restart.

      Both cost exactly one call at read time, so both are supported, and
      every text read in the engine goes through here. Routing every read
      through one function is also what makes radiant substitution possible at
      all -- %SLOT% tokens are resolved in the same pass, so no caller has to
      remember to do it, and a caller that forgets is the bug that ships a
      quest titled "Clear %ENEMY% out of %PLACE%".

    WHAT IT DOES
      Accepts a STRING, a NUMBER, or a CONFIG entry (read for you, so callers
      can write [_cfg >> "title"] call aq_fnc_text and not care whether the
      author wrote a string or a number).

      - A string starting with "$" is a stringtable key and is localized.
        Nothing else is: a leading $ is unambiguous, whereas treating any
        "STR_"-looking string as a key would mangle real content.
      - %TOKEN% is then replaced from the substitution map, if one was given.
        Localization happens first, so a translated line may itself contain
        slot tokens.
      - A token left unfilled when a substitution map was supplied is logged.
        The generator is responsible for making unfilled slots a hard error;
        this is the second net, for the case where a token reaches a player.

      Always returns a STRING. Callers needing a number from a substituted
      field use parseNumber on the result -- deliberately not done here,
      because "" and "0" must stay distinguishable to the caller.

    Usage:
        private _title = [_questCfg >> "title", _ctx get "subst"] call aq_fnc_text;
        private _label = ["$STR_AQ_ACCEPT"] call aq_fnc_text;
*/

params [
    ["_value", "", ["", 0, configNull]],
    ["_subst", createHashMap, [createHashMap, []]]
];

// ------------------------------------------------------------ normalise in
private _str = switch (true) do {
    case (_value isEqualType 0): { str _value };
    case (_value isEqualType configNull): {
        switch (true) do {
            case (isText   _value): { getText   _value };
            case (isNumber _value): { str (getNumber _value) };
            case (isArray  _value): {
                // An array field read as text is almost always a mistake at
                // the call site, so say so rather than returning "[...]".
                diag_log format ["[AQ] text: %1 is an array field, not a text field", configName _value];
                ""
            };
            default { "" };   // missing entry: empty is a legitimate answer
        }
    };
    default { _value };
};

if (_str isEqualTo "") exitWith { "" };

if (_subst isEqualType []) then {
    _subst = createHashMapFromArray _subst;
};

// ------------------------------------------------------------- stringtable
if ((_str select [0, 1]) isEqualTo "$") then {
    private _key = _str select [1];
    // UNVERIFIED: localize accepts the key without the leading "$" and
    // returns the key unchanged when the entry is missing. Confirm by asking
    // for a key that does not exist and checking the RPT for the line below.
    private _loc = localize _key;
    if (_loc isEqualTo _key || {_loc isEqualTo ""}) then {
        diag_log format ["[AQ] text: stringtable key '%1' did not resolve -- is it in stringtable.xml?", _key];
        _loc = _key;
    };
    _str = _loc;
};

// ------------------------------------------------------------ substitution
if (count _subst > 0) then {
    {
        private _token = format ["%1%2%3", "%", _x, "%"];
        private _rep   = _subst get _x;
        if (isNil "_rep") then { _rep = ""; };
        if !(_rep isEqualType "") then { _rep = str _rep; };
        // UNVERIFIED: regexReplace treats "%" as a literal and "$" in the
        // replacement as a group reference, hence the doubling. Confirm with
        // a slot value containing a $ character.
        _str = _str regexReplace [_token, _rep regexReplace ["\$", "$$$$"]];
    } forEach (keys _subst);

    // Only a well-formed leftover token is reported, so a line containing
    // "50% off" does not fill the RPT with false alarms.
    if (_str regexMatch ".*%[A-Za-z_][A-Za-z0-9_]*%.*") then {
        diag_log format ["[AQ] text: unresolved token left in '%1' -- filled slots were %2", _str, keys _subst];
    };
};

_str
