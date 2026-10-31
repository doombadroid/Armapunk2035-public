/*
    NPC_fnc_nearSpawns -- resolve a vehicle NPC's spawn pads from NEARBY CONVENTION MARKERS.

    [getPosATL _npc, ["car_spawn","air_spawn"]] call NPC_fnc_nearSpawns;
    -> up to 6 marker NAMES starting with any given prefix, nearest first, within 150 m.

    WHY (owner 2026-07-31): every vehicle NPC used to carry its pad markers by name in its init
    ("['civ_g_31','civ_g_32']"), which is the one thing about placing a garage that cannot be
    pre-wired into a drag-in composition -- only the placer knows the site. With this, an EMPTY
    spawns argument means "use the nearby markers whose names start with car_spawn, air_spawn
    or boat_spawn", so placing a working garage is: drag the NPC composition, drag pad markers
    next to it, done. (No asterisks in this comment: a star-slash inside a block comment ends
    it early -- the ATM-skimmer file was bitten by exactly that.)
    Explicit marker lists in existing inits keep working exactly as before -- the resolution only
    runs when the list is empty.

    Ground garages ask for ["car_spawn","air_spawn"] -- a car can spawn on an air pad (big and
    flat) but never the reverse, so air garages ask for ["air_spawn"] alone.

    Loud on failure by design: an empty result upstream means the actions get no pads, and the
    caller logs it. Silent would look exactly like the [0,0,0]-spawn bug this replaces.
*/
params ["_pos", "_prefixes", ["_radius", 150], ["_cap", 6]];
private _found = [];
{
    private _m = _x;
    if ((_prefixes findIf { (_m select [0, count _x]) isEqualTo _x }) > -1) then {
        private _d = _pos distance2D (getMarkerPos _m);
        if (_d <= _radius) then { _found pushBack [_d, _m]; };
    };
} forEach allMapMarkers;
_found sort true;
(_found select [0, _cap]) apply { _x select 1 }
