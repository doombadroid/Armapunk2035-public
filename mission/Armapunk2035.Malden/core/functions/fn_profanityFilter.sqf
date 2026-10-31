/*
    File: fn_profanityFilter.sqf
    Author: LooneyBin

    Description:
    Client-side, opt-in (Streamer Mode). Masks any WHOLE WORD that matches
    AP_profanityList (slurs / Twitch-bannable terms) with an equal-length run
    of asterisks. WHOLE-word match (tokenize on spaces, strip surrounding
    punctuation) so a banned word embedded in an innocent word is NOT touched
    (Scunthorpe, fire-retardant, raccoon, Pakistan, etc. stay intact).
    AP_profanityList must be lower-case; it's owner-editable in
    core\configuration.sqf. Used by AP_streamerMode to censor chat + incoming
    phone text messages.

    Parameter(s):
    0: STRING - the text to filter

    Returns:
    STRING - the filtered text (unchanged if the list is missing)
*/
params[["_text", "", [""]]];
if (_text isEqualTo "" || {isNil "AP_profanityList"}) exitWith {_text};

private _alnum = "abcdefghijklmnopqrstuvwxyz0123456789" splitString "";

private _out = (_text splitString " ") apply {private _tok = _x;
    private _low = toLower _tok;
    // isolate the alphanumeric core, ignoring leading/trailing punctuation
    private _s = 0;
    private _e = count _low;
    while {_s < _e && {!((_low select [_s, 1]) in _alnum)}} do {_s = _s + 1};
    while {_e > _s && {!((_low select [_e - 1, 1]) in _alnum)}} do {_e = _e - 1};
    private _core = _low select [_s, _e - _s];
    if (_core in AP_profanityList) then {private _stars = "";
        for "_i" from 1 to (_e - _s) do {_stars = _stars + "*"};
        (_tok select [0, _s]) + _stars + (_tok select [_e])   // keep surrounding punctuation
    } else {_tok};};

_out joinString " "
