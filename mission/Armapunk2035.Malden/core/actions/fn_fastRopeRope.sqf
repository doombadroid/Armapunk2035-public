params [["_heli", objNull, [objNull]], ["_add", true, [true]]];
// FAST ROPE -- the visible half: the ropes and the doors. Runs on whoever owns the
// helicopter, because ropeCreate and animate are locality-bound. Refcounted so a stack of
// people going out one after another hangs one set of ropes, not one set each: the first
// caller creates them and opens up, the last one off destroys them.
//
// The doors are deliberately left open afterwards -- shutting them under a man still on
// the second rope would be worse than a helicopter that lands with its doors open.
if (isNull _heli) exitWith {};
if !(_heli isKindOf "Air") exitWith {};
// Ownership can change under us mid-flight (JIP, a pilot swap); bounce to the new owner.
if !(local _heli) exitWith {_this remoteExec ["AP_fnc_fastRopeRope", _heli]};

// SECURITY. This is remoteExec'd client -> client (CfgRE allowedTargets = 1), so the sender is
// untrusted and both arguments are attacker-controlled. Everything the caller could gain by
// lying is on the ADD branch -- hanging ropes off an airframe in flight to drag or block it,
// or popping someone's doors and ramp open -- so the add is re-validated here against state
// only this machine can see, and the same envelope fn_fastRope already gates the action on.
// The REMOVE branch is deliberately NOT gated: a spurious remove can only decrement a counter
// that clamps at zero, while a rejected one would leak ropes onto the airframe for good.
if (_add) then {
    private _alt = (getPosATL _heli) select 2;
    if !((typeOf _heli) in (["classes"] call AP_fnc_fastRopeCfg)) exitWith {};
    if (_alt < (["minAltitude"] call AP_fnc_fastRopeCfg)) exitWith {};
    if (_alt > (["maxAltitude"] call AP_fnc_fastRopeCfg)) exitWith {};
    if (abs (speed _heli) > (["maxSpeed"] call AP_fnc_fastRopeCfg)) exitWith {};
    if ((count (crew _heli)) < 2) exitWith {};   // a pilot holding the hover, and someone to rope
};

private _count = _heli getVariable ["ap_fastRopeCount", 0];

if (_add) then {
    if (_count isEqualTo 0) then {
        // Long enough to still touch ground from the top of the envelope.
        private _length = (["maxAltitude"] call AP_fnc_fastRopeCfg) + 5;

        // Every door and every ramp, by animation name -- the airframes in the table do
        // not agree on what those are called, and this way the table stays the only list.
        {_heli animate [_x, 1, false];} forEach ((animationNames _heli) select {
            private _name = toLower _x;
            (_name find "door" > -1) || {_name find "ramp" > -1}
        });

        // Ropes hang 0.35 m outboard of the man's station so he is not descending
        // through the rope geometry the whole way down.
        private _ropes = (["anchors", typeOf _heli] call AP_fnc_fastRopeCfg) apply {
            _x params ["_anchorX", "_anchorY"];
            private _outboard = _anchorX + (0.35 * ([-1, 1] select (_anchorX >= 0)));
            ropeCreate [_heli, [_outboard, _anchorY, -0.4], _length]
        };
        _heli setVariable ["ap_fastRopeRopes", _ropes];
    };
    _heli setVariable ["ap_fastRopeCount", _count + 1];
} else {
    _count = (_count - 1) max 0;
    _heli setVariable ["ap_fastRopeCount", _count];
    if (_count isEqualTo 0) then {
        {if !(isNull _x) then {ropeDestroy _x};} forEach (_heli getVariable ["ap_fastRopeRopes", []]);
        _heli setVariable ["ap_fastRopeRopes", []];
    };
};
