/*
    AP_fnc_lbScene  --  CLIENT. Applies the Loony Bin heist scene to THIS machine's local props.

    Every prop in the compound (bomb trolley, door satchel, hotel, church) is a mapData row spawned
    by fn_createVehicleLocal with _xIsServer = false: each client builds its own private copy and the
    server has none. So the server can never hide the trolley or unlock the hotel for everybody --
    it publishes state (AP_lbState) and remoteExecs this, and every client edits its own scene.
    Also called from initPlayerLocal so a late joiner walks into the correct scene.

    AP_lbState = [trolleyBlown, doorFuseEndsAt, doorBlown, dbEndsAt, dbDone, tombOpen, firewall,
                   trolleyArming]

    Hiding uses hideObject AND a sink to -500: these props are createSimpleObject statues for which
    hideObject alone is not reliable, and the sink is exactly reversible because the server publishes
    the delivered position (AP_lbPos_*, read out of the mapData array, not guessed).
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
if (!hasInterface) exitWith {};

private _st = missionNamespace getVariable ["AP_lbState", [false, 0, false, 0, false, false, false, false]];
_st params [["_trolleyBlown", false], "", ["_doorBlown", false], "", "", ["_tombOpen", false]];

private _pTrolley = missionNamespace getVariable ["AP_lbPos_trolley", [4201.07, 3940.99, 27.78]];
private _pSatchel = missionNamespace getVariable ["AP_lbPos_satchel", [4245.98, 3911.65, 28.07]];
private _pHotel   = missionNamespace getVariable ["AP_lbPos_hotel",   [4254.58, 3909.33, 30.30]];
private _pChurch  = missionNamespace getVariable ["AP_lbPos_church",  [4278.21, 3933.19, 32.38]];

// Find a delivered prop. THIS IS THE PART THAT BIT US (owner 2026-08-01: the blown trolley and the
// spent door charge both stayed standing): most mapData rows are createSimpleObject statues, and
// **nearestObjects does not return simple objects** -- allSimpleObjects is the only command that
// sees them. The door-bearing rows (hotel, church) go the createVehicleLocal path instead and are
// real local objects, which allSimpleObjects does NOT see. So ask both, every time, and pick by
// exact delivered position: the props are metres apart and their position is known to the
// centimetre, so the nearest match inside a 3 m tolerance can only be the prop itself.
// The result is cached per prop, which also keeps the reference alive once we sink it out of sight.
private _fnc_find = {
    params ["_class", "_pos", ["_tol", 3]];
    private _best = objNull; private _bestD = _tol;
    {
        private _d = (getPosWorld _x) distance _pos;
        if (_d < _bestD) then { _bestD = _d; _best = _x; };
    } forEach ((allSimpleObjects [_class]) + (nearestObjects [[_pos select 0, _pos select 1, 0], [_class], 30]));
    _best
};
private _fnc_get = {
    params ["_key", "_class", "_pos"];
    private _o = missionNamespace getVariable [_key, objNull];
    if (!isNull _o) exitWith { _o };
    _o = [_class, _pos] call _fnc_find;
    // It may already be parked underground from an earlier cycle (or a JIP into a live event).
    if (isNull _o) then { _o = [_class, [_pos select 0, _pos select 1, (_pos select 2) - 500]] call _fnc_find; };
    if (isNull _o) then {
        // Last resort: a simple object built from a model path rather than a class carries no class
        // name at all, so no filtered query can ever match it. Sweep the unfiltered list once and
        // take whatever sits at the delivered position; the result is cached, so this runs once.
        private _bestD = 3;
        {
            private _d = (getPosWorld _x) distance _pos;
            if (_d < _bestD) then { _bestD = _d; _o = _x; };
        } forEach (allSimpleObjects []);
    };
    if (isNull _o) then {
        diag_log format ["[LooneyBin][heist][client] prop %1 not found near %2 -- it cannot be hidden or restored", _class, _pos];
    };
    missionNamespace setVariable [_key, _o];
    _o
};

// Sink or restore a local prop. The position we restore to is the one the map actually delivered,
// so this is lossless however many times the event cycles.
private _fnc_setHidden = {
    params ["_key", "_class", "_pos", "_hidden"];
    private _o = [_key, _class, _pos] call _fnc_get;
    if (isNull _o) exitWith { false };
    if (_hidden) then {
        _o hideObject true;
        _o setPosWorld [_pos select 0, _pos select 1, (_pos select 2) - 500];
    } else {
        _o hideObject false;
        _o setPosWorld _pos;
    };
    true
};

// Lock/unlock EVERY door on the building nearest _pos. numberOfDoors is the engine's own marker for
// "this class has doors"; a lock alone leaves a door a player already swung open standing open, so
// shut it too -- both animation schemes, the same pair the rest of this codebase uses.
private _fnc_setDoors = {
    params ["_key", "_class", "_pos", "_locked"];
    // Same finder as the props: a raw nearestObjects against a world-frame position can miss by the
    // frame offset alone, and these two buildings only exist as local copies on each client.
    private _b = [_key, _class, _pos] call _fnc_get;
    if (isNull _b) exitWith { false };
    private _nd = getNumber (configFile >> "CfgVehicles" >> _class >> "numberOfDoors");
    if (_nd < 1) exitWith { false };
    for "_i" from 1 to _nd do {
        _b setVariable [format ["bis_disabled_Door_%1", _i], (if (_locked) then { 1 } else { 0 })];
        if (_locked) then {
            _b animateDoor [format ["Door_%1", _i], 0];
            {
                _b animateSource [format [_x, _i], 0];
            } forEach ["Door_%1_source", "Door_%1_sound_source", "Door_%1_noSound_source"];
        };
    };
    true
};

["AP_lbObj_trolley", "Land_Bomb_Trolley_01_F", _pTrolley, _trolleyBlown] call _fnc_setHidden;
["AP_lbObj_satchel", "DemoCharge_F",           _pSatchel, _doorBlown]    call _fnc_setHidden;
["AP_lbObj_hotel",  "Land_Hotel_02_F",  _pHotel,  !_doorBlown] call _fnc_setDoors;
["AP_lbObj_church", "Land_Church_05_F", _pChurch, !_tombOpen]  call _fnc_setDoors;
