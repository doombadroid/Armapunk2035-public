// Per-frame dispatcher: fire each registered handler when its own interval has elapsed.
//
// _x is a LIVE REFERENCE into AP_eachFrameHandlerArray, which is what makes `_x set [3, ...]`
// below advance that handler's next-fire time. Do NOT wrap the array in `+` here: that is a DEEP
// copy (sub-arrays included), so the timestamp would land in a throwaway clone and every handler
// would fire every frame -- roughly 50 DB-writing saves per second per client.
{
    _x params ["_function", "_args", "_delay", "_delta", "", "_handle"];
    if (diag_tickTime > _delta) then {
        _x set [3, _delta + _delay];
        [_args, _handle] call _function;
    };
} forEach AP_eachFrameHandlerArray;
