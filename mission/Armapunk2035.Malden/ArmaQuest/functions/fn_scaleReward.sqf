// SPDX-License-Identifier: MIT
/*
    functions/fn_scaleReward.sqf

    Purpose: multiply a generated quest's numeric rewards by the value of one
    numeric slot, as named by the template's `scaleWith`.

    WHY THIS EXISTS
    A radiant quest that rolls "kill 3" and "kill 8" for the same money is either
    insulting at one end or free at the other, so the payout has to follow the
    roll. The tempting way to express that in config is an expression —
    "money * COUNT * 1.5" — and the moment config can compute, config is code:
    it must be parsed, it must be compiled, it can call anything the engine
    exposes, and every mission that ships a config file becomes a place to hide
    a payload. So this function performs exactly one operation, multiplication by
    one named slot, and refuses anything that even looks like an expression.
    A template that needs a different curve declares a different reward.

    WHAT IT DOES
      1. Rejects a `scaleWith` that is not a bare slot name — any space, sign or
         punctuation is treated as an attempted expression and reported loudly.
      2. Looks the slot up in the resolved slot values; it must exist and be a
         number, or the whole generation fails rather than silently paying the
         unscaled amount. A pool slot holds an entry, not a number, so naming one
         here is rejected by the same check — "money times the name of a town" is
         a mistake worth stopping at the template rather than at the payout.
      3. Multiplies the scalar reward fields (money, xp) and rounds them, because
         currency and experience are whole numbers.
      4. Leaves items[] and licenses[] alone. Scaling a physical reward would
         change what a reward *is* — six emblems is not a bigger version of one —
         so quantity scaling is a template's job to declare explicitly.
      5. Removes `scaleWith` from the reward map, since it is a generation-time
         instruction and not something the payout should ever see.

    Returns  [true, REWARDS]   the same map, mutated in place
             [false, "reason"]

    Usage:
        private _r = [_rewards, "COUNT", _slots] call aq_fnc_scaleReward;
        if !(_r select 0) then { diag_log text ("[AQ] " + (_r select 1)) };
*/

// _scaleWith is deliberately untyped in params: a wrong type must be reported,
// not quietly replaced by the default.
params [
    ["_rewards",   createHashMap, [createHashMap]],
    ["_scaleWith", ""],
    ["_slots",     createHashMap, [createHashMap]]
];

if (!(_scaleWith isEqualType "")) exitWith {
    diag_log text "[AQ] scaleReward: scaleWith must be a single slot name (a string)";
    [false, "scaleWith must be a string naming one numeric slot"]
};

if (_scaleWith isEqualTo "") exitWith { [true, _rewards] };   // nothing to do

// A slot name is a config class name: letters, digits, underscore, not starting
// with a digit. Everything else — "COUNT * 2", "COUNT+1", "2*COUNT" — is an
// expression, and this is not an expression evaluator.
private _codes = toArray _scaleWith;
private _okName = count _codes > 0;
{
    private _c = _x;
    private _isAlpha = (_c >= 65 && {_c <= 90}) || {(_c >= 97 && {_c <= 122})} || {_c == 95};
    private _isDigit = (_c >= 48 && {_c <= 57});
    if (!_isAlpha && {!_isDigit}) exitWith { _okName = false };
    if (_forEachIndex == 0 && {!_isAlpha}) exitWith { _okName = false };
} forEach _codes;

if (!_okName) exitWith {
    diag_log text ("[AQ] scaleReward: scaleWith '" + _scaleWith + "' is not a slot name. scaleWith multiplies by one numeric slot; it is not an expression.");
    [false, "scaleWith '" + _scaleWith + "' is not a bare slot name"]
};

if (!(_scaleWith in (keys _slots))) exitWith {
    diag_log text ("[AQ] scaleReward: scaleWith names slot '" + _scaleWith + "', which this template does not declare");
    [false, "scaleWith names undeclared slot '" + _scaleWith + "'"]
};

private _factor = _slots get _scaleWith;
if (!(_factor isEqualType 0)) exitWith {
    diag_log text ("[AQ] scaleReward: slot '" + _scaleWith + "' holds a non-numeric value, so it cannot scale a reward");
    [false, "slot '" + _scaleWith + "' is not numeric"]
};
if (_factor < 0) exitWith {
    diag_log text ("[AQ] scaleReward: slot '" + _scaleWith + "' is negative (" + str _factor + "); a reward cannot be scaled below zero");
    [false, "scale factor is negative"]
};
if (_factor == 0) then {
    // Legal but almost always a mistake in a slot range, so it is worth a line
    // in the log rather than a quest that silently pays nothing.
    diag_log text ("[AQ] scaleReward: slot '" + _scaleWith + "' rolled 0; this quest pays nothing");
};

{
    private _k = _x;
    private _v = _rewards getOrDefault [_k, ""];   // "" cannot be mistaken for a
                                                   // reward, so an absent field
                                                   // is simply skipped
    if (_v isEqualType 0) then {
        _rewards set [_k, round (_v * _factor)];
    };
} forEach ["money", "xp"];

_rewards deleteAt "scaleWith";

[true, _rewards]
