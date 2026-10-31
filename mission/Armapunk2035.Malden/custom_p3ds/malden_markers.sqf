// Malden spawn markers — created at runtime, server-side, global (JIP-persistent).
//
// The designer's mission.sqm carries NO spawn markers at all: no civ_spawn_*, cop_spawn_* or
// med_spawn_*. Rather than hand-place them in a binarized sqm, they are created here.
//
// Positions come from the WORLD'S OWN config (CfgWorlds >> Malden >> Names), not from coordinates
// typed in by hand. A town's config position cannot be wrong, and it survives the designer moving
// things around. The resolved position is logged so a boot can be checked against the map.

if (!isServer) exitWith {};

// name fragment -> [markerName, display label]. Fragment match so it works whether the world config
// spells it "La Trinite" or "La Trinité".
private _wanted = [
    ["Trinit", "civ_spawn_1", "La Trinite"]
];

private _names = configFile >> "CfgWorlds" >> worldName >> "Names";
private _found = createHashMap;

for "_i" from 0 to ((count _names) - 1) do {
    private _entry = _names select _i;
    if (!isClass _entry) then { continue };
    private _nm = getText (_entry >> "name");
    if (_nm isEqualTo "") then { continue };
    {
        _x params ["_frag", "_marker", "_label"];
        if (!(_marker in _found) && {(toLower _nm) find (toLower _frag) > -1}) then {
            private _p = getArray (_entry >> "position");
            if (count _p >= 2) then {
                _found set [_marker, [[_p select 0, _p select 1, 0], _nm, _label]];
            };
        };
    } forEach _wanted;
};

// The 201 player slots (mission.sqm, added by tools/sqm_add_roles.py) are parked in this empty
// corner at 0.5 ASL. They only sit there for the few seconds before fn_spawnMenu holds them at
// [worldSize/2, worldSize/2, 50000] with simulation off. Log the terrain height so a boot proves
// whether that corner is sea (float) or land (would mean spawning them below ground).
diag_log format ["[Armapunk2035] slot holding area [1000,500]: terrain %1m ASL (%2), worldSize %3",
                 (getTerrainHeightASL [1000, 500]) toFixed 1,
                 (if (surfaceIsWater [1000, 500]) then {"water"} else {"land"}), worldSize];

{
    _x params ["_frag", "_marker", "_label"];
    private _hit = _found getOrDefault [_marker, []];
    if (_hit isEqualTo []) then {
        diag_log format ["[Armapunk2035] no location matching '%1' in CfgWorlds >> %2 >> Names — marker '%3' NOT created",
                         _frag, worldName, _marker];
    } else {
        _hit params ["_pos", "_cfgName", "_lbl"];
        // owner 2026-07-30: markers live in the MAP LAYER now, so a marker placed in mission.sqm must
        // WIN. This block used to deleteMarker first and recreate unconditionally, which would have
        // silently clobbered the placed one every boot -- the one shape of runtime marker creation the
        // "place it in Eden and the code stands down" migration cannot tolerate. Guarded like every
        // other creator in the tree; delete this whole block once the sqm marker is confirmed in game.
        if ((getMarkerPos _marker) isNotEqualTo [0,0,0]) exitWith {
            diag_log format ["[Armapunk2035] spawn marker '%1' already in the map layer at %2 -- runtime creation skipped",
                             _marker, getMarkerPos _marker];
        };
        createMarker [_marker, _pos];
        _marker setMarkerType "mil_dot";
        _marker setMarkerColor "ColorCIV";
        _marker setMarkerText _lbl;
        diag_log format ["[Armapunk2035] spawn marker '%1' -> %2 (config name '%3') at %4",
                         _marker, _lbl, _cfgName, _pos];
    };
} forEach _wanted;

// ---- the designer's bridge, drawn on the map -----------------------------------------------------
// The crossing is 16 mission .p3d pieces, not terrain, so the engine's map renders open water where
// an 800m bridge is -- players and the GPS route both appear to cross the sea. Draw its real
// footprint instead of guessing: measured from the model with boundingBoxReal, each piece is 50.03m
// long and 37.06m wide (y -18.53..+18.53 about its origin). 16 pieces sit at y=3765 from x 8512.5 to
// 9262.5, so the deck spans x 8487.5..9287.5 = 800m by 37.06m.
// Drawn RAMP FOOT TO RAMP FOOT, not deck-piece to deck-piece. The 16 deck pieces only span
// x 8487.5..9287.5; the crossing continues past them down the ramps to ground level, so a marker
// covering just the pieces stopped ~40m offshore at BOTH ends with open water drawn between it and
// the land. Ramp feet, measured in game by the owner (z~0.0-0.1 = on the ground):
//   mainland  [8444.16,3752.61] and [8454.07,3777.11]   -> west edge 8444.0
//   island    [9332.16,3753.04] and [9334.85,3779.20]   -> east edge 9335.0
// The outer of each pair is used so the marker covers both carriageways' ramps.
//   span  x 8444.0 .. 9335.0  = 891.0m   ->  centre 8889.5, half-length 445.5
// A RECTANGLE marker is positioned by its CENTRE, so extending one end moves the centre too --
// growing the size alone would have pushed the opposite end out into the sea.
// setMarkerSize takes HALF extents, hence [445.5, 18.53].
// owner 2026-07-30: same as above -- the map layer owns markers now, so the placed AP_bridge must
// win. Was an unconditional deleteMarker + recreate, which would have overwritten it every boot.
// Delete this block once the sqm rectangle is confirmed in game.
if ((getMarkerPos "AP_bridge") isEqualTo [0,0,0]) then {
createMarker ["AP_bridge", [8889.5, 3765]];
"AP_bridge" setMarkerShape "RECTANGLE";
"AP_bridge" setMarkerBrush "Solid";
"AP_bridge" setMarkerSize [445.5, 18.53];
"AP_bridge" setMarkerDir 0;               // deck runs due east-west (constant y), so no rotation
"AP_bridge" setMarkerColor "ColorBlack";
"AP_bridge" setMarkerAlpha 0.85;
diag_log "[Armapunk2035] bridge map marker 'AP_bridge' drawn: x 8444.0..9335.0 (891.0m) x 37.06 m wide, ramp foot to ramp foot";
} else {
    diag_log format ["[Armapunk2035] AP_bridge already in the map layer at %1 -- runtime creation skipped", getMarkerPos "AP_bridge"];
};
