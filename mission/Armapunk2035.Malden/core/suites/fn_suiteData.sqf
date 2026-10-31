/*
    File: fn_suiteData.sqf  (AP_fnc_suiteData)
    Luxe Suites 2026-08-06 -- shared identity + lookup helpers. See suites.md.

    Defines AP_fnc_suite* inline helpers (the project's convention for small
    shared logic, same as AP_fnc_* in core/configuration.sqf). Called once from
    core/init.sqf so both the kiosk UI and the door lock use ONE definition of a
    suite's identity.

    IDENTITY IS LOAD-BEARING. The oid must be derived identically on the client
    and the server or every lookup silently misses -- that is exactly how house
    tax double-charged for weeks (#374: the client sent `oid`, the server keyed
    on `id`, the UPDATE hit no row, DATEDIFF stayed high, and it charged again on
    every relog). Both sides call AP_fnc_suiteOid; nothing hand-formats it.
*/

// Tower geometry, in the object's SCRIPT model frame (what worldToModel returns:
// [lateral, depth, up]). Both values are GENERATED facts, not guesses -- they are
// cross-checked against two independent artifacts:
//   * lux-doors-manifest.json: floor 2's door sill sits at p3d y 6.32, floor 3 at
//     9.92 -> a uniform 3.6 m pitch.
//   * lux_doors_data.sqf, which the generator emits as [x, z-ZC, y-YC] with
//     YC 58.46: every floor-2 hinge reads z -52.14 = 6.32 - 58.46.
// Floor 1 is a DOUBLE-height lobby, which is why floor 2's datum is not one pitch
// above ground. If the tower is ever regenerated with a different floor height,
// these are the two numbers to re-derive.
// Macros, not globals: the server's furniture check runs through AP_fnc_suiteFloorAt, and a global here is one
// client publicVariable away from collapsing every floor into one (a huge pitch makes every floor 2).
// floor 2's finished floor level
#define SUITE_F2Z (-52.14)
// uniform pitch, floors 2..30
#define SUITE_FLOOR_H 3.6
// Rent, term + grace live in localNamespace FIRST, and the server reads them there: a client's publicVariable
// overwrites a missionNamespace global on the server too (a lease term of 1e10 s, SQL text, a 0.0001 ND rent),
// localNamespace it cannot. The globals are display copies taken FROM it, never the other way round.
localNamespace setVariable ["APS_suiteRentND", "120.0000"];   // 4dp string -- ND amounts never travel as numbers
localNamespace setVariable ["APS_suiteTermS", 2592000];   // 30 days
localNamespace setVariable ["APS_suiteGraceS", 864000];   // 10 days from first missed payment to repossession
AP_suiteRentND = localNamespace getVariable "APS_suiteRentND";
AP_suiteTermS  = localNamespace getVariable "APS_suiteTermS";
AP_suiteGraceS = localNamespace getVariable "APS_suiteGraceS";

// The helpers are compileFinal and this file runs TWICE on a machine that is both server and client (hosted/SP:
// initServer.sqf, then core/init.sqf): the second pass keeps the first pass's finals instead of erroring on each.
if (isFinal "AP_fnc_suiteOid") exitWith {};

// oid for a floor of a given tower object: LUX<roundX><roundY>F<floor>
AP_fnc_suiteOid = compileFinal {
    params ["_tower", "_floor"];
    if (isNull _tower) exitWith { "" };
    private _p = getPosWorld _tower;
    format ["LUX%1%2F%3", round (_p select 0), round (_p select 1), _floor]
};

// the <roundX><roundY> tower key on its own (sweeping a whole tower)
AP_fnc_suiteTowerKey = compileFinal {
    params ["_tower"];
    if (isNull _tower) exitWith { "" };
    private _p = getPosWorld _tower;
    format ["%1%2", round (_p select 0), round (_p select 1)]
};

// every lux tower instance in the world. NEVER assume index 0 -- the owner
// already runs more than one, and the door system wires each of them.
AP_fnc_suiteTowers = compileFinal {
    (allSimpleObjects []) select { "skyscraper30_r" in toLower ((getModelInfo _x) select 0) }
};

// nearest lux tower to a position (the kiosk serves the tower it stands in)
AP_fnc_suiteTowerNear = compileFinal {
    params ["_pos", ["_maxDist", 120]];
    private _best = objNull; private _bestD = _maxDist;
    { private _d = _x distance _pos; if (_d < _bestD) then { _bestD = _d; _best = _x; }; } forEach (call AP_fnc_suiteTowers);
    _best
};

// which floor of _tower is _pos standing on? -1 when outside the tower.
// Floor N's slab top sits at model-space y = FLOOR_Y0 + (N-1)*FLOOR_H (measured
// from the generated tower: F01 lobby is DOUBLE height, so floor 2 starts higher
// than one storey up and every floor above is a uniform 3.6 m pitch).
AP_fnc_suiteFloorAt = compileFinal {
    params ["_tower", "_pos"];
    if (isNull _tower) exitWith { -1 };
    private _m = _tower worldToModel (ASLToAGL _pos);
    // model frame: x lateral, y depth(z north), z up  -- see suites.md
    private _up = _m select 2;
    private _lat = _m select 0;
    private _dep = _m select 1;
    if (abs _lat > 18.5 || {abs _dep > 22}) exitWith { -1 };          // outside the footprint
    if (_up < SUITE_F2Z - 0.3) exitWith { 1 };                        // lobby / below
    // +0.3 tolerance only: a bigger one would push someone standing near the top
    // of their own floor into the floor above (pitch is 3.6, headroom ~3.0).
    private _f = 2 + floor ((_up - SUITE_F2Z + 0.3) / SUITE_FLOOR_H);
    if (_f > 30) exitWith { -1 };                                      // roof
    _f
};

// Which suite is _unit standing in? -> [tower, floor, oid], or [] if none.
// Geometry and identity ONLY -- ownership is deliberately not checked here so
// that both sides can use it and each can apply its own authority: the client
// checks the door stamp for a friendly refusal, the server checks the DB row.
// Takes a unit rather than reading `player` because the SERVER calls it too
// (initServer.sqf loads this file), which is what makes a real server-side
// floor check possible instead of trusting the client's claim.
AP_fnc_suiteAt = compileFinal {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith { [] };
    // distance2D, not distance: the towers sit on ~171 m terrain, so any check
    // mixing ASL and AGL heights would be off by the whole hill.
    private _best = objNull; private _bd = 60;
    { private _d = _x distance2D _unit; if (_d < _bd) then { _bd = _d; _best = _x; }; }
        forEach (call AP_fnc_suiteTowers);
    if (isNull _best) exitWith { [] };
    private _f = [_best, getPosASL _unit] call AP_fnc_suiteFloorAt;
    if (_f < 2) exitWith { [] };            // 1 = lobby, -1 = outside/roof
    [_best, _f, [_best, _f] call AP_fnc_suiteOid]
};

// Does THIS player hold the suite they are standing in? Client-side friendly
// check only -- read off the front door leaf, which AP_fnc_suiteDoorSync
// stamps, for the same reason AP_fnc_suiteMayOpen does: the AP_suiteRows cache
// only fills when the kiosk is opened, so a player who relogged and walked
// upstairs would look like a stranger in their own home.
AP_fnc_suiteMine = compileFinal {
    params ["_tower", "_floor"];
    if (isNull _tower) exitWith { false };
    private _idx = [_floor, _tower getVariable ["ap_luxDoorBase", 0]] call AP_fnc_suiteFrontDoorIdx;
    private _leaf = ((missionNamespace getVariable ["AP_LUXDOOR_LEAVES", []]) param [_idx, []]) param [0, objNull];
    if (isNull _leaf) exitWith { false };
    (_leaf getVariable ["ap_suiteOwner", ""]) isEqualTo (getPlayerUID player)
};

// May THIS player open THIS leaf? The single authority for suite door access,
// called from lux_doors.sqf's Open action.
//
// b0350: the lease used to lock the front door with nothing anywhere able to
// unlock it -- the tenant was shut out of their own suite permanently, and the
// door had opened fine before they leased. A lock with no unlock is not "a
// feature that isn't finished", it is a broken lifecycle.
//
// Ownership is read off the LEAF (stamped by AP_fnc_suiteDoorSync), not from
// the client's AP_suiteRows cache -- that cache only fills when the kiosk is
// opened, so a player who relogged and walked straight upstairs would have been
// locked out by an empty cache.
AP_fnc_suiteMayOpen = compileFinal {
    params ["_leaf"];
    if (isNull _leaf) exitWith { false };
    if !(_leaf getVariable ["ap_doorLocked", false]) exitWith { true };
    if ((_leaf getVariable ["ap_suiteOwner", ""]) isEqualTo (getPlayerUID player)) exitWith { true };
    if ((AP_effSide isEqualTo west) && ((call AP_copLevel) >= 5)) exitWith { true };     // MaxSec force entry (spec: cops can, hackers cannot)
    false
};

// flat index of a floor's FRONT door in AP_LUXDOOR_LEAVES: three doors per floor
// in lux_doors_data.sqf order (front off the stair core, then bath, then bedroom),
// floors 2..30, so floor F's front door is (F-2)*3. Verified against the manifest:
// door_1 (floor 2) is the stair-core door at x[-4.27,-3.33] z~3.0.
AP_fnc_suiteFrontDoorIdx = compileFinal {
    params ["_floor", ["_base", 0]];
    _base + (_floor - 2) * 3
};
