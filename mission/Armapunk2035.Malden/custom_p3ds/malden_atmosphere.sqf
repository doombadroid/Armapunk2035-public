// Armapunk 2035 — atmosphere + cave system. Client-side.
//
// Ported from the map designer's initPlayerLocal.sqf (ProjectMaldenMerge). Three defects in the
// original are fixed here rather than carried over:
//
//   1. setDay / setCaveLighting were DEFINED at the bottom of the file but CALLED by a `spawn` loop
//      started further up. Whether that worked depended on scheduler timing. They are defined first now.
//   2. `exitMine addAction [...]` runs unconditionally, but `exitMine` does not exist in this
//      mission.sqm — enterMine, escapeJail and caveArea do, exitMine does not. Unguarded that is an
//      "Undefined variable" on every client, every join. Each hook is now presence-checked and logs
//      once instead of throwing.
//   3. It lived in initPlayerLocal directly; it is its own file so the designer can re-export theirs
//      without clobbering LooneyBin's initPlayerLocal.
//
// Called from initPlayerLocal.sqf. Server has no player, so there is nothing here for initServer.

if (!hasInterface) exitWith {};

// ---- time of day ---------------------------------------------------------------------------------
// The server's whole identity: permanent DUSK, Halloween 2035, 16:00. (The After-Dark pass moved
// this to 01:30 permanent night on 2026-08-04; reverted 2026-09-02 with the rest of that look.)
// `setDay` keeps its name because the cave hooks call it; it means "surface lighting".
setDay = compileFinal {
    setDate [2035, 10, 31, 16, 0];
    0 setFog 0;
};

setCaveLighting = compileFinal {
    setDate [2035, 10, 31, 6, 50];
    0 setFog [0.5, 0.02, 100];
};

playerTeleport = compileFinal {
    params ["_player", "_position"];
    titleText ["", "BLACK OUT", 1];
    sleep 2;
    _player setPos _position;
    titleText ["", "BLACK IN", 1];
};

forceDusk = true;

// ---- cave hooks ----------------------------------------------------------------------------------
// Guarded: a missing anchor is a map-authoring gap, not a reason to spam every client's RPT.
private _fnAdd = {
    // owner 2026-07-29: optional 5th arg = the addAction CONDITION string. Defaults to "" so the two rows
    // that do not pass one behave exactly as before.
    params ["_varName", "_label", "_dest", "_lightAfter", ["_cond", "", [""]]];
    if (isNil _varName) exitWith {
        diag_log format ["[Armapunk2035] map object '%1' not in mission.sqm — '%2' action skipped", _varName, _label];
    };
    private _obj = missionNamespace getVariable _varName;
    if (isNull _obj) exitWith {
        diag_log format ["[Armapunk2035] map object '%1' is null — '%2' action skipped", _varName, _label];
    };
    _obj addAction [_label, {
        params ["", "", "", "_args"];
        _args params ["_dest", "_lightAfter"];
        playSound3D ["A3\Sounds_F\structures\doors\MetalBigDoor_01_open", player];
        [player, _dest] call playerTeleport;
        if (_lightAfter isEqualTo "cave") then { [] call setCaveLighting } else { [] call setDay };
    }, [_dest, _lightAfter], 5, false, true, "", _cond, 5];
};

// owner 2026-07-29: enterMine sits INSIDE the prison's wall ring, 45.8 m from the prison marker, and had
// NO condition whatsoever -- so any prisoner could walk out of the prison through it with no hack at all,
// and once AP_jailPoly went live it became a 1 Hz teleport loop (cave -> fails inPolygon -> setPos back to
// the yard -> action still there). Gated on a live escape: anyone not currently jailed, or a prisoner who
// has accepted the breakout. The mine is the escape's SECOND exit, not a free door.
["enterMine",  "Enter Mine",  [2985.082, 7089.092, 17.600], "cave",
    "!(player getVariable ['AP_arrested', false]) || AP_breakout"] call _fnAdd;   // surface -> mine
["exitMine",   "Exit Mine",   [9797.093, 3864.503,  0.152], "day"]  call _fnAdd;   // mine -> surface
["escapeJail", "Escape Jail", [9893.784, 2809.292,  0.000], "day"]  call _fnAdd;   // jail break exit

// ---- keep it dark while underground --------------------------------------------------------------
// Only worth running if the trigger area actually exists, otherwise it is a pointless permanent loop.
// EDGE-TRIGGERED, not polled. The ported original called setDay every 5s whenever the player was
// above ground -- i.e. almost always. setDay is `setDate` + `setFog`, and setDate forces a full
// lighting/shadow recalculation: that was a visible screen flash and a hard frame dip on every
// client every ~5 seconds. Apply the lighting only when the player actually crosses in or out of
// the cave. Paired with the server freezing the time-of-day clock (AP_freezeTimeOfDay), so there
// is no drift for a re-assert to correct.
if (!isNil "caveArea") then {
    [] spawn {
        private _inCave = -1;   // -1 = unknown, so the first pass always applies once
        while {forceDusk} do {
            private _now = if (player inArea caveArea) then { 1 } else { 0 };
            if (_now != _inCave) then {
                _inCave = _now;
                if (_now isEqualTo 1) then { [] call setCaveLighting; } else { [] call setDay; };
            };
            sleep 2;
        };
    };
} else {
    [] call setDay;
    diag_log "[Armapunk2035] caveArea not in mission.sqm — cave lighting loop not started";
};
