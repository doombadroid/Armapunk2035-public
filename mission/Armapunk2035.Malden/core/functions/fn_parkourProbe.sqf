/*
    AP_fnc_parkourProbe -- "what would the V key do from here?" A pure classifier: rays and maths,
    no side effects, no state (owner 2026-09-16, plan "Feature A: Parkour + Wall Run" > Probing).

        private _r = [] call AP_fnc_parkourProbe;   // [kind, data, message]

    kind     "none" | "vault" | "mantle" | "drop" | "wallrun"
    data     HashMap. Always: "f" (horizontal unit forward), "P" (feet PositionASL), "speed" (FORWARD
             km/h, `speed player`), "speedH" (horizontal km/h), "why" (short debug reason). Per kind:
               vault    "d" face distance, "H" top height, "T" thickness, "zLandRel" landing z - P.z,
                        "obj" the obstacle
               mantle   "d", "H", "obj"
               drop     "D" depth below the feet at the K2 landing spot, "lip" distance to the lip
                        along f, "dropShift" how far past dropEdgeFwd the lip lies, "obj" the ledge
               wallrun  "n" wall normal pointing away from the wall (horizontal), "t" run tangent,
                        "dWall" horizontal distance to the wall, "xSign" +1/-1 = the wall's side in
                        helper model space (helper dir = t), "obj" the wall
               none     "stepUnsafe" (only when the step-over guard below failed): the distance along
                        facing of the first ground column with no footing; "dropAhead" true (review
                        round 3) when that was a "drop-shallow" and a drop there looks reachable
                        (the notice gate at the end of this file)
    message  "" or a line for the player (only "Too far down to drop." / water today). The caller
             shows it; this function never talks to the player.

    THE STEP-OVER GUARD (owner 2026-09-16, review round 2). A "none" with no message sends a standing
    player's V to the engine step-over, which walks ~1.5 m along FACING -- not along f. Nothing had
    checked that path: a strafer's frame is sideways, and several drop refusals that come AFTER a real
    ledge was measured (slope, headroom, overhead, someone at the landing) are silent. So a silent
    "none" also casts ground columns along facing (stepGuardFwd [0.5, 1.0, 1.5] m, from stepGuardUp
    1.0 above the feet down to stepGuardDepth 1.2 below; a person is not footing), and the first with
    no footing sets "stepUnsafe"; AP_fnc_parkour then swallows V. AP_parkourCfg_stepGuardFwd = [] = off.
    owner 2026-09-16 (review round 3): that made V a silent dead key at a real drop unless the lip was
    0.25-0.7 m ahead. The edge ray now sits at dropEdgeNear (0.05), so toes-at-the-lip drops, and a player
    too far back ("drop-shallow") whose guard column lands on a valid drop gets "dropAhead", which
    AP_fnc_parkour turns into the "Get closer to the edge to drop." notice (cfg dropCloserMsg). owner
    2026-09-16 (review round 4): only past a real edge with nothing in the way and room at the landing
    (parapets, railings and steep slopes stay silent), so the notice rarely points at a refused drop. It
    does not replay the later drop-sweep refusal (review round 5), which depends on where the lip is; a
    facade object in the drop path can still follow the notice with a silent refusal.

    WHY IT IS CALLED, NOT SPAWNED. AP_fnc_parkour runs inside the display KeyDown handler and has to
    return true/false to the engine in the same frame: true swallows V, false lets the engine's own
    step-over run. So classification must be synchronous, and nothing here may sleep. It is also
    why the probe is budgeted per keypress (~17-40 rays, more only when the FIRE retry runs) and costs
    nothing while idle -- no per-frame scanning anywhere.

    THE FRAME. P = feet ASL; f = horizontal velocity direction when the HORIZONTAL speed is above
    fwdFromVelSpeed (6 km/h) and that direction is not behind the facing (dot > fwdFromVelMinDot), so a
    strafing runner vaults the way they are moving and a backpedaller keeps facing; else facing.
    owner 2026-09-16 (review round 1): this used `speed player`, which is the model-forward component
    only (BIKI: 3.6 * velocityModelSpace Y), so a pure A/D strafe read ~0 and never got the velocity
    frame. `speed` (forward) still gates the wall run and sets its glide speed -- a wall run is a
    forward sprint. s = f rotated 90 degrees clockwise (the right).
    Every ray is lineIntersectsSurfaces [from, to, player, objNull, true, 3, LOD, "NONE"], nearest
    first, rows [posASL, normal, object, parent, ...] -- the fn_fastRope.sqf:107 shape.

    REJECTION (applied to the nearest hit of every ray): a CAManBase, or a vehicle that is moving,
    crewed or has its engine on, turns the WHOLE probe into "none". You never vault a person or a
    car somebody is about to drive away, and a parked car is fair game. Terrain (objNull) is a
    floor and never a face.

    SPIKE P1 (unmeasured): vanilla chain-link / wire fences may have no GEOM face. The forward scan
    therefore walks the LOD list from the cfg (default GEOM then FIRE; FIRE runs only when GEOM found
    no face at all), and the LOD that found the face is the one the top and thickness rays use --
    a fence that only exists in FIRE has no GEOM top either. Every other ray (clearance, landing,
    headroom, drop, wall) is GEOM, because GEOM is what the walking capsule collides with. Known
    gap for the spike to answer: a face thinner than topInset (0.15 m) lets the top ray fall behind
    it, H reads ~0 and the probe says none. `debug\probe_parkour.sqf "fence"` prints what each LOD
    sees; AP_parkourCfg_topInset / AP_parkourCfg_faceLods are the live levers.

    PRIORITY: vault/mantle > wallrun > drop > none. A face taller than mantleMax (or with no top the
    top ray can find) is never a wall-run trigger -- a wall in front is not a wall beside you.

    Interpretations the plan left open (owner can overrule; each is one cfg key):
      - vault "drop <= 1.5 m" is measured from the take-off feet to the landing (P.z - zLand), since
        the glide carries the player down to zLand and the drop is what K3 has to cover.
      - drop "column must have exactly the ground hit" is checked as: the first hit below is a floor
        (nz > topMinNz) and passes rejection; a floor slab over terrain is not a second "ground".
      - "clear standing room" for a mantle includes a floor under the K2 end point (mantleNeedsSurface,
        default true), so a thin wall is "none" rather than "climb it and fall off the far side".
      - owner 2026-09-16 (review round 1): a vault also needs BODY ROOM OVER THE TOP (vaultOverHeights,
        "overhead"): rays at top + vaultLift + 0.9 / 1.6 / 1.9 from vaultK1Back in front of the face to
        T + vaultK2Over + sweepLead past it. They start in front of the face on purpose -- the top ray
        starts behind it and, inside the wall above a window, sees nothing but the sill. A failure
        demotes to the mantle check, whose headroom column refuses a window. A drop needs the same at
        sweepHeights out to where its sweeps reach ("drop-overhead"), and finds the real lip first.
      - owner 2026-09-16 (review round 2): vault and mantle also need HEAD ROOM ON THE WAY UP ("rise"):
        one ray from feet + headZ + riseHeadTop to the rise keyframe's head (K1Back in front of the face,
        top + lift + headZ + riseHeadTop); an awning or porch roof over the approach. owner 2026-09-16
        (review round 3): the mover's head sweep casts only pieces of this same segment (riseRayLen is its
        lead ALONG it), with the same obstacle rule, so whatever this ray passes the mover passes too.
      - owner 2026-09-16 (review round 2): a wall run also needs knee room (wallStepUp + wallKneeAboveStep,
        non-terrain hits only; below 0 = off), the mover's low corner ray: benches, planters, bins.
        owner 2026-09-16 (review round 3): it and the 0.9 / 1.6 clearance rays follow the MOVER'S PATH --
        P to the hold line (wallHoldDist from the wall) over the ease, then along t on it to wallClearLen --
        and the ground-ahead ray starts from the hold line, not from the player's own line dWall out.
      - owner 2026-09-16 (review round 4): a wall run also needs HEAD ROOM along that path, at headZ +
        riseHeadTop over the arc out to wallRunTime / 2 plus the corner lead -- the line the mover's "head"
        ray now casts pieces of (it was 0.4 m straight up, above anything tested: awnings, balconies).
        owner 2026-09-16 (review round 5): only out to wallClearLen along the run, like the other lane rays.
        Residual (accepted): an overhang this line only meets past wallClearLen, or a low awning whose underside
        sits between the mover's arc-riding 1.6 m corner ray and this line, still starts a run the mover ends
        early under it as "head" / "corner" (pushCornerFwd, no forward throw).
      - owner 2026-09-16 (review round 4): a drop's lip is a FACE (|nz| < faceMaxNz); a lip ray that meets
        the surface falling toward the lip instead assumes the lip is at dropFwd (full keyframe shift).
      - owner 2026-09-16 (review round 3): the drop's "still on the ledge" ray is at dropEdgeNear (0.05),
        not the plan's 0.25, so a player with toes at the lip is not "no-edge"; dropEdgeFwd remains the lip
        the drop keyframes are tuned for.
      - the thickness ray only counts a far face on the SAME object as the near face; anything else
        (a car parked behind a fence, a ray starting inside a platform) reads as "no far face" and
        the candidate becomes mantle-onto, whose own checks then decide.

    With AP_parkourDebug true, one "[AP-PROBE] parkour probe:" line per call.
*/
private _cfg = {_this call AP_fnc_parkourCfg};

private _P = getPosASL player;
private _Pz = _P select 2;
private _spd = speed player;                                  // forward component: wall-run gate + glide speed
private _vel = velocity player;
private _hv = [_vel select 0, _vel select 1, 0];
private _spdH = 3.6 * (vectorMagnitude _hv);                  // real ground speed: decides the frame
private _dir = getDir player;
private _facing = [sin _dir, cos _dir, 0];
private _f = _facing;
if ((_spdH > (["fwdFromVelSpeed"] call _cfg)) && {(vectorMagnitude _hv) > 0.1}) then {
    private _vn = vectorNormalized _hv;
    if ((_vn vectorDotProduct _facing) > (["fwdFromVelMinDot"] call _cfg)) then {_f = _vn};
};
private _s = [_f select 1, -(_f select 0), 0];

// ---- tunables, read once per keypress ------------------------------------------------------
private _vehMaxSpeed   = ["vehMaxSpeed"] call _cfg;
private _lods          = ["faceLods"] call _cfg;
private _reach         = ["reachFwd"] call _cfg;
private _heights       = ["rayHeights"] call _cfg;
private _faceMaxNz     = ["faceMaxNz"] call _cfg;
private _faceFacing    = ["faceFacing"] call _cfg;
private _faceMinDist   = ["faceMinDist"] call _cfg;
private _topInset      = ["topInset"] call _cfg;
private _topRayUp      = ["topRayUp"] call _cfg;
private _topRayDown    = ["topRayDown"] call _cfg;
private _topMinNz      = ["topMinNz"] call _cfg;
private _vaultMin      = ["vaultMin"] call _cfg;
private _vaultMax      = ["vaultMax"] call _cfg;
private _vaultMaxThick = ["vaultMaxThick"] call _cfg;
private _thickReach    = ["thickReach"] call _cfg;
private _thickDown     = ["thickDown"] call _cfg;
private _clearUp       = ["vaultClearUp"] call _cfg;
private _clearExtra    = ["vaultClearExtra"] call _cfg;
private _landFwd       = ["vaultLandFwd"] call _cfg;
private _landUp        = ["vaultLandUp"] call _cfg;
private _landDepth     = ["vaultLandDepth"] call _cfg;
private _vaultMaxDrop  = ["vaultMaxDrop"] call _cfg;
private _vaultHeadroom = ["vaultHeadroom"] call _cfg;
private _waterASL      = ["waterASL"] call _cfg;
private _mantleMax     = ["mantleMax"] call _cfg;
private _mantleHead    = ["mantleHeadroom"] call _cfg;
private _standFwd      = ["mantleStandFwd"] call _cfg;
private _standZ        = ["mantleStandZ"] call _cfg;
private _needSurface   = ["mantleNeedsSurface"] call _cfg;
private _k2Fwd         = ["mantleK2Fwd"] call _cfg;
private _headZ         = ["headZ"] call _cfg;
private _headTop       = ["riseHeadTop"] call _cfg;
private _ignMargin     = ["sweepIgnoreMargin"] call _cfg;

if !(_lods isEqualType []) then {_lods = ["GEOM"]};
if (_lods isEqualTo []) then {_lods = ["GEOM"]};

private _data = createHashMapFromArray [["f", _f], ["P", _P], ["speed", _spd], ["speedH", _spdH], ["why", ""]];
private _rejected = false;
private _rejectedBy = objNull;

// ---- helpers --------------------------------------------------------------------------------
private _fnc_bad = {
    params ["_o"];
    if (isNull _o) then {false} else {
        if (_o isKindOf "CAManBase") then {true} else {
            if ((_o isKindOf "LandVehicle") || {_o isKindOf "Air"} || {_o isKindOf "Ship"} || {_o isKindOf "Tank"}) then {
                ((abs (speed _o)) > _vehMaxSpeed) || {isEngineOn _o} || {((crew _o) findIf {alive _x}) > -1}
            } else {false};
        };
    };
};

// Nearest row of one ray ([] for no hit). Sets _rejected (the caller's local) when that row is a
// person or a live vehicle.
private _fnc_cast = {
    params ["_from", "_to", ["_lod", "GEOM"]];
    private _rows = lineIntersectsSurfaces [_from, _to, player, objNull, true, 3, _lod, "NONE"];
    private _first = _rows param [0, []];
    if !(_first isEqualTo []) then {
        if (([_first select 2] call _fnc_bad) || {[_first select 3] call _fnc_bad}) then {
            _rejected = true;
            _rejectedBy = _first select 2;
        };
    };
    _first
};

private _fnc_clear = {
    params ["_from", "_to"];
    ([_from, _to, "GEOM"] call _fnc_cast) isEqualTo []
};

private _fnc_inWater = {
    params ["_posASL"];
    (surfaceIsWater _posASL) && {(_posASL select 2) < _waterASL}
};

// ---- the classification, as one block so every exit path reaches the debug line below -------
private _result = call {
    // ================= forward scan =================
    private _face = [];          // [d, posASL, normal, object, lod, parent]
    private _kneeWaistNear = 1e9;
    {
        private _lod = _x;
        private _firstPass = _forEachIndex isEqualTo 0;
        {
            private _hIdx = _forEachIndex;
            private _from = _P vectorAdd [0, 0, _x];
            private _hit = [_from, _from vectorAdd (_f vectorMultiply _reach), _lod] call _fnc_cast;
            if !(_hit isEqualTo []) then {
                private _d = ((_hit select 0) vectorDiff _from) vectorDotProduct _f;
                if (_firstPass && {_hIdx < 2}) then {_kneeWaistNear = _kneeWaistNear min _d};
                private _n = _hit select 1;
                if (!(isNull (_hit select 2)) && {(abs (_n select 2)) < _faceMaxNz} && {(_n vectorDotProduct _f) < _faceFacing}) then {
                    if ((_face isEqualTo []) || {_d < (_face select 0)}) then {
                        _face = [_d, _hit select 0, _n, _hit select 2, _lod, _hit select 3];
                    };
                };
            };
        } forEach _heights;
        if (_rejected || {!(_face isEqualTo [])}) exitWith {};
    } forEach _lods;
    if (_rejected) exitWith {["none", "", "rejected"]};

    private _tallFace = false;
    private _pressedIn = false;
    if !(_face isEqualTo []) then {
        _face params ["_d", "_fp", "_fn", "_fObj", "_fLod", "_fPar"];
        _data set ["d", _d];
        _data set ["obj", _fObj];
        _data set ["lod", _fLod];
        if (_d < _faceMinDist) exitWith {_pressedIn = true};

        private _isFaceObj = {
            params ["_row"];
            private _o = _row select 2;
            !(isNull _o) && {(_o isEqualTo _fObj) || {(!(isNull _fPar)) && {_o isEqualTo _fPar}} || {(_row select 3) isEqualTo _fObj}}
        };

        // top of the obstacle
        private _txy = _fp vectorAdd (_f vectorMultiply _topInset);
        private _top = [[_txy select 0, _txy select 1, _Pz + _topRayUp], [_txy select 0, _txy select 1, _Pz + _topRayDown], _fLod] call _fnc_cast;
        if (_rejected) exitWith {};
        if (_top isEqualTo []) exitWith {_tallFace = true; _data set ["why", "no-top"]};
        if (((_top select 1) select 2) <= _topMinNz) exitWith {_data set ["why", "top-slope"]};
        private _topZ = (_top select 0) select 2;
        private _H = _topZ - _Pz;
        _data set ["H", _H];
        if (_H > _mantleMax) exitWith {_tallFace = true; _data set ["why", "tall"]};
        if (_H < _vaultMin) exitWith {_data set ["why", "low"]};

        // owner 2026-09-16 (review round 2): THE RISE. The horizontal overhead rays alone only sampled three heights of
        // the head's way up, so an awning / porch roof / eave over the approach passed the probe and every V rose and
        // snapped home. owner 2026-09-16 (review round 3): the mover's "head" sweep now casts only pieces of ONE segment,
        // (feet + headZ + riseHeadTop) -> (K1Back in front of the face, top + lift + headZ + riseHeadTop), and this ray is
        // that whole segment, so the two agree for any riseRayLen and any tick. The obstacle rule is the MOVER'S
        // (fn_parkourMove _fnc_hit: the obstacle itself or a row whose parent it is, at or below top + sweepIgnoreMargin),
        // not _isFaceObj: that one also skips the face's parent object, which the mover does not.
        private _fnc_riseClear = {
            params ["_k1Back", "_lift"];
            private _k1 = _fp vectorAdd (_f vectorMultiply -_k1Back);
            private _hz = _headZ + _headTop;
            private _rows = lineIntersectsSurfaces [_P vectorAdd [0, 0, _hz], [_k1 select 0, _k1 select 1, _topZ + _lift + _hz], player, objNull, true, 3, "GEOM", "NONE"];
            (_rows findIf {!(((_x select 2) isEqualTo _fObj) || {(_x select 3) isEqualTo _fObj}) || {((_x select 0) select 2) > (_topZ + _ignMargin)}}) < 0
        };

        // Headroom above the top, standing room along f, and (mantleNeedsSurface) something to stand ON where
        // the mantle ends (K2, mantleK2Fwd past the face). Without that last ray a thin fence passes -- there is
        // air above it -- and a vault that failed on its landing would demote into "mantle onto the fence",
        // leaving the player over its far side with the drop the landing check had just refused.
        // owner 2026-09-16 (review round 5): "mantle-overhead" -- the mover's K2 body sweep. K1 and K2 share z (top +
        // mantleLift), so every K2 tick of fn_parkourMove _fnc_bodySweep casts a piece of one horizontal line per sweep
        // height, from K1 (mantleK1Back in front of the face) to K2 + sweepLead along f. The mover ignores nothing that
        // high (the obstacle only at or below top + sweepIgnoreMargin), so a plain _fnc_clear matches it while mantleLift
        // + each sweep height > sweepIgnoreMargin (stricter than the mover otherwise). Before this only the headroom column
        // at the face and the standing ray looked there, and a sign / beam just past the lip dropped the player off the hang.
        private _mantleWhy = "mantle-room";
        private _fnc_mantleOk = {
            private _sxy = _fp vectorAdd (_f vectorMultiply _k2Fwd);
            ([(_top select 0) vectorAdd [0, 0, 0.1], (_top select 0) vectorAdd [0, 0, 0.1 + _mantleHead]] call _fnc_clear)
            && {[[_fp select 0, _fp select 1, _topZ + _standZ], [_fp select 0, _fp select 1, _topZ + _standZ] vectorAdd (_f vectorMultiply _standFwd)] call _fnc_clear}
            && {!_needSurface || {!([[_sxy select 0, _sxy select 1, _topZ + 0.3], [_sxy select 0, _sxy select 1, _topZ - 0.3]] call _fnc_clear)}}
            && {
                private _sa = _fp vectorAdd (_f vectorMultiply -(["mantleK1Back"] call _cfg));
                private _sb = _fp vectorAdd (_f vectorMultiply (_k2Fwd + (["sweepLead"] call _cfg)));
                private _mz = _topZ + (["mantleLift"] call _cfg);
                // owner 2026-09-18 (codex review): and the HEAD TOP (headZ + riseHeadTop) along the same line. The sweep heights
                // stop at 1.6 and the headroom column stands at the lip (topInset), so a ceiling / balcony 1.7-1.9 m over the
                // ledge that begins past the lip passed everything and the mantle ended with the head inside it at K2.
                private _swClear = (((["sweepHeights"] call _cfg) + [_headZ + _headTop]) findIf {!([[_sa select 0, _sa select 1, _mz + _x], [_sb select 0, _sb select 1, _mz + _x]] call _fnc_clear)}) < 0;
                if (!_swClear) then {_mantleWhy = "mantle-overhead"};
                _swClear
            }
            && {[["mantleK1Back"] call _cfg, ["mantleLift"] call _cfg] call _fnc_riseClear}
        };

        if (_H <= _vaultMax) then {
            // ---- vault candidate: thickness, clearance, landing ----
            private _T = -1;
            private _vaultWhy = "";
            private _thz = _topZ - _thickDown;
            private _thFrom = [_fp select 0, _fp select 1, _thz] vectorAdd (_f vectorMultiply _thickReach);
            private _thRows = lineIntersectsSurfaces [_thFrom, [_fp select 0, _fp select 1, _thz], player, objNull, true, 3, _fLod, "NONE"];
            if !(_thRows isEqualTo []) then {
                private _r0 = _thRows select 0;
                if (([_r0 select 2] call _fnc_bad) || {[_r0 select 3] call _fnc_bad}) then {_rejected = true; _rejectedBy = _r0 select 2};
            };
            private _farIdx = _thRows findIf {[_x] call _isFaceObj};
            if (_farIdx < 0) then {_vaultWhy = "no-far-face"} else {
                _T = 0 max ((((_thRows select _farIdx) select 0) vectorDiff _fp) vectorDotProduct _f);
                if (_T > _vaultMaxThick) then {_vaultWhy = "thick"};
            };
            if (_vaultWhy isEqualTo "") then {
                private _cFrom = [_fp select 0, _fp select 1, _topZ + _clearUp];
                if !([_cFrom, _cFrom vectorAdd (_f vectorMultiply (_T + _clearExtra))] call _fnc_clear) then {_vaultWhy = "clearance"};
            };
            if (_vaultWhy isEqualTo "") then {
                // owner 2026-09-16 (review round 1): body room over the top (header, "overhead"). The mover's sweeps
                // now see the obstacle above its top, so without this a window vault would abort mid-air instead.
                private _oBase = _topZ + (["vaultLift"] call _cfg);
                private _oFrom = _fp vectorAdd (_f vectorMultiply -((["vaultK1Back"] call _cfg) + 0.05));
                private _oTo = _fp vectorAdd (_f vectorMultiply (_T + (["vaultK2Over"] call _cfg) + (["sweepLead"] call _cfg)));
                {
                    if !([[_oFrom select 0, _oFrom select 1, _oBase + _x], [_oTo select 0, _oTo select 1, _oBase + _x]] call _fnc_clear) exitWith {_vaultWhy = "overhead"};
                } forEach (["vaultOverHeights"] call _cfg);
            };
            if ((_vaultWhy isEqualTo "") && {!([["vaultK1Back"] call _cfg, ["vaultLift"] call _cfg] call _fnc_riseClear)}) then {_vaultWhy = "rise"};
            if (_vaultWhy isEqualTo "") then {
                private _lxy = _fp vectorAdd (_f vectorMultiply (_T + _landFwd));
                private _lFrom = [_lxy select 0, _lxy select 1, _topZ + _landUp];
                private _land = [_lFrom, _lFrom vectorAdd [0, 0, -_landDepth]] call _fnc_cast;
                switch (true) do {
                    case (_land isEqualTo []): {_vaultWhy = "no-landing"};
                    case (((_land select 1) select 2) <= _topMinNz): {_vaultWhy = "landing-slope"};
                    case ((_Pz - ((_land select 0) select 2)) > _vaultMaxDrop): {_vaultWhy = "landing-deep"};
                    case ([_land select 0] call _fnc_inWater): {_vaultWhy = "landing-water"};
                    case (!([(_land select 0) vectorAdd [0, 0, 0.1], (_land select 0) vectorAdd [0, 0, 0.1 + _vaultHeadroom]] call _fnc_clear)): {_vaultWhy = "landing-headroom"};
                    default {_data set ["zLandRel", ((_land select 0) select 2) - _Pz]};
                };
            };
            if (_rejected) exitWith {};
            if (_vaultWhy isEqualTo "") then {
                _data set ["T", _T];
                _data set ["kind", "vault"];
            } else {
                // Demote: a platform / car roof / failed landing becomes a mantle onto the top.
                if (call _fnc_mantleOk) then {_data set ["kind", "mantle"]};
                _data set ["why", _vaultWhy];
            };
        } else {
            if (call _fnc_mantleOk) then {_data set ["kind", "mantle"]} else {_data set ["why", _mantleWhy]};
        };
    };
    if (_rejected) exitWith {["none", "", "rejected"]};
    if (_pressedIn) exitWith {["none", "", "pressed-in"]};    // plan: already pressed against it -> refuse outright
    private _fwdKind = _data getOrDefault ["kind", ""];
    if !(_fwdKind isEqualTo "") exitWith {[_fwdKind, "", _data get "why"]};

    // ================= side scan (wall run) =================
    if (!_tallFace
        && {missionNamespace getVariable ["SRV_wallRunEnabled", true]}
        && {5 in (player getVariable ["AP_cdMods", []])}
        && {_spd >= (["wallRunMinSpeed"] call _cfg)}
        && {!(isForcedWalk player)}) then {
        private _wReach   = ["wallReach"] call _cfg;
        private _wHeights = ["wallRayHeights"] call _cfg;
        private _pairTol  = ["wallPairTol"] call _cfg;
        private _wMaxNz   = ["wallMaxNz"] call _cfg;
        private _wMaxNf   = ["wallMaxNf"] call _cfg;
        private _contAt   = ["wallContAhead"] call _cfg;
        private _contLen  = ["wallContLen"] call _cfg;
        private _clearLen = ["wallClearLen"] call _cfg;
        private _gAhead   = ["wallGroundAhead"] call _cfg;
        private _gUp      = ["wallGroundUp"] call _cfg;
        private _gMax     = ["wallGroundMax"] call _cfg;
        private _h0 = _wHeights param [0, 0.9];
        private _h1 = _wHeights param [1, 1.6];
        private _best = [];
        {
            private _side = _x;
            private _sd = _s vectorMultiply _side;
            private _lo = [_P vectorAdd [0, 0, _h0], (_P vectorAdd [0, 0, _h0]) vectorAdd (_sd vectorMultiply _wReach)] call _fnc_cast;
            private _hi = [_P vectorAdd [0, 0, _h1], (_P vectorAdd [0, 0, _h1]) vectorAdd (_sd vectorMultiply _wReach)] call _fnc_cast;
            if (_rejected) exitWith {};
            if (!(_lo isEqualTo []) && {!(_hi isEqualTo [])}) then {
                private _o = _lo select 2;
                private _nLo = _lo select 1;
                private _nHi = _hi select 1;
                if (!(isNull _o)
                    && {_o isEqualTo (_hi select 2)}
                    && {((_lo select 0) distance2D (_hi select 0)) < _pairTol}
                    && {(abs (_nLo select 2)) < _wMaxNz} && {(abs (_nHi select 2)) < _wMaxNz}
                    && {(abs (_nLo vectorDotProduct _f)) < _wMaxNf}) then {
                    private _nh = vectorNormalized [_nLo select 0, _nLo select 1, 0];
                    private _ok = true;
                    {
                        private _base = _P vectorAdd (_f vectorMultiply _x);
                        private _c0 = [_base vectorAdd [0, 0, _h0], (_base vectorAdd [0, 0, _h0]) vectorAdd (_sd vectorMultiply _contLen)] call _fnc_cast;
                        private _c1 = [_base vectorAdd [0, 0, _h1], (_base vectorAdd [0, 0, _h1]) vectorAdd (_sd vectorMultiply _contLen)] call _fnc_cast;
                        if ((_c0 isEqualTo []) || {_c1 isEqualTo []}) exitWith {_ok = false};
                    } forEach _contAt;
                    private _t = vectorNormalized (_f vectorDiff (_nh vectorMultiply (_f vectorDotProduct _nh)));
                    private _dWall = abs (((_lo select 0) vectorDiff (_P vectorAdd [0, 0, _h0])) vectorDotProduct _nh);
                    // owner 2026-09-16 (review round 3): THE MOVER'S PATH, not the player's line. The mover eases the
                    // player to wallHoldDist from the wall over wallEaseTime (a straight line from P to _easeEnd) and then
                    // runs along t on that hold line, and its corner rays ride that path (review r4: they lead along the
                    // path now, not along t, so every one is a piece of this polyline). Rays along t from P, dWall out
                    // (up to wallReach), missed a planter / bin / electrical box standing against the wall, so the run
                    // started and ended ~0.25 s later at a "corner" with a sideways hop. Same v and ease as the mover.
                    private _v = ((_spd / 3.6) max (["wallSpeedMin"] call _cfg)) min (["wallSpeedMax"] call _cfg);
                    private _ease = (["wallEaseTime"] call _cfg) max 0.01;
                    private _hold = _P vectorDiff (_nh vectorMultiply (_dWall - (["wallHoldDist"] call _cfg)));
                    private _easeY = (_v * _ease) min _clearLen;
                    // review r4: when wallClearLen cuts the ease short, the mover is still only easeY / (v * ease) of the way over.
                    private _easeEnd = (_P vectorAdd ((_hold vectorDiff _P) vectorMultiply (_easeY / ((_v * _ease) max 0.001)))) vectorAdd (_t vectorMultiply _easeY);
                    private _farEnd = _hold vectorAdd (_t vectorMultiply _clearLen);
                    // [from, to] pairs at feet level; each is cast at a height. The second is skipped when the ease
                    // already covers wallClearLen.
                    private _path = [[_P, _easeEnd]];
                    if ((_clearLen - _easeY) > 0.01) then {_path pushBack [_easeEnd, _farEnd]};
                    if (_ok) then {
                        {
                            private _h = _x;
                            {
                                if !([(_x select 0) vectorAdd [0, 0, _h], (_x select 1) vectorAdd [0, 0, _h]] call _fnc_clear) exitWith {_ok = false};
                            } forEach _path;
                            if (!_ok) exitWith {};
                        } forEach [_h0, _h1];
                    };
                    private _kneeAbove = ["wallKneeAboveStep"] call _cfg;
                    if (_ok && {_kneeAbove >= 0}) then {
                        // owner 2026-09-16 (review round 2): knee height too, as the mover's low corner ray (fn_parkourCfg
                        // "wallKneeAboveStep"; review r3: below 0 = off here and in the mover). Terrain does not count:
                        // the run follows it, and an uphill run is meant to work.
                        private _kh = (["wallStepUp"] call _cfg) + _kneeAbove;
                        {
                            private _lowRows = lineIntersectsSurfaces [(_x select 0) vectorAdd [0, 0, _kh], (_x select 1) vectorAdd [0, 0, _kh], player, objNull, true, 3, "GEOM", "NONE"];
                            if ((_lowRows findIf {!(isNull (_x select 2))}) > -1) exitWith {_ok = false};
                        } forEach _path;
                    };
                    if (_ok) then {
                        // owner 2026-09-16 (review round 4): HEAD ROOM ALONG THE RUN, the mover's "head" ray: the head top
                        // (headZ + riseHeadTop) over the arc (wallArc * sin(180 t / wallRunTime)), along the path, while
                        // t < wallRunTime / 2, plus its wallCornerLen lead. Nothing above 1.6 m was tested, so an awning /
                        // canopy / balcony over the run started a run that ended ~0.4 s later under it. A chain through the
                        // end of the ease and three points of the rise (each chord sags <= ~2 cm under the arc, as the
                        // mover's pieces do). Every row counts, terrain too, as in the mover; a hit is only "no wall run".
                        // owner 2026-09-16 (review round 5): capped at wallClearLen along the run (_clearLen / v), the
                        // guaranteed forward clearance of every other ray here. Uncapped (4.5-6.3 m) it refused any post /
                        // tree / jutting front taller than the head line that the mover ends as "corner" anyway. Past
                        // wallClearLen the mover ends a run at a post as "corner" (as before round 4) and under an
                        // overhang as "head" (header residual).
                        private _runT = (["wallRunTime"] call _cfg) max 0.1;
                        private _arc = ["wallArc"] call _cfg;
                        private _tEnd = ((_runT / 2) + ((["wallCornerLen"] call _cfg) / (_v max 0.1))) min (_clearLen / (_v max 0.1));
                        private _times = [0, _ease min _tEnd, _tEnd * 0.5, _tEnd * 0.75, _tEnd];
                        _times sort true;
                        private _hPts = _times apply {
                            ((_P vectorAdd ((_hold vectorDiff _P) vectorMultiply ((_x / _ease) min 1))) vectorAdd (_t vectorMultiply (_v * _x)))
                                vectorAdd [0, 0, _headZ + _headTop + (_arc * (sin (180 * _x / _runT)))]
                        };
                        for "_i" from 1 to ((count _hPts) - 1) do {
                            private _a = _hPts select (_i - 1);
                            private _b = _hPts select _i;
                            if (((_a distance _b) > 0.01) && {!((lineIntersectsSurfaces [_a, _b, player, objNull, true, 1, "GEOM", "NONE"]) isEqualTo [])}) exitWith {_ok = false};
                        };
                    };
                    if (_ok) then {
                        // review r3: from the hold line too, where the mover's ground ray will look.
                        private _g = (_hold vectorAdd (_t vectorMultiply _gAhead)) vectorAdd [0, 0, _gUp];
                        private _gRow = [_g, [_g select 0, _g select 1, _Pz - _gMax]] call _fnc_cast;
                        // owner 2026-09-16 (review round 1): water there too is no run (the mover also ends on water).
                        if ((_gRow isEqualTo []) || {[_gRow select 0] call _fnc_inWater}) then {_ok = false};
                    };
                    if (_ok && {!_rejected}) then {
                        // Which side of the run the wall is on, in the helper's model space (x = right of t).
                        private _xSign = [-1, 1] select (((_nh vectorMultiply -1) vectorDotProduct [_t select 1, -(_t select 0), 0]) >= 0);
                        if ((_best isEqualTo []) || {_dWall < (_best select 0)}) then {_best = [_dWall, _nh, _t, _xSign, _o]};
                    };
                };
            };
        } forEach [1, -1];
        if (!_rejected && {!(_best isEqualTo [])}) then {
            _data set ["dWall", _best select 0];
            _data set ["n", _best select 1];
            _data set ["t", _best select 2];
            _data set ["xSign", _best select 3];
            _data set ["obj", _best select 4];
            _data set ["kind", "wallrun"];
        };
    };
    if (_rejected) exitWith {["none", "", "rejected"]};
    if ((_data getOrDefault ["kind", ""]) isEqualTo "wallrun") exitWith {["wallrun", "", "wall"]};

    // ================= drop =================
    if (_kneeWaistNear <= (["dropNearClear"] call _cfg)) exitWith {["none", "", _data get "why"]};
    private _edgeFwd = ["dropEdgeFwd"] call _cfg;
    private _edgeNear = ["dropEdgeNear"] call _cfg;
    private _edgeUp  = ["dropEdgeUp"] call _cfg;
    private _edgeMax = ["dropEdgeMax"] call _cfg;
    private _dropFwd = ["dropFwd"] call _cfg;
    private _depth   = ["dropDepth"] call _cfg;
    private _dropMin = ["dropMin"] call _cfg;
    private _dropMax = ["dropMax"] call _cfg;
    private _dropHead = ["dropHeadroom"] call _cfg;

    // owner 2026-09-16 (review round 3): the "still on the ledge" ray is at dropEdgeNear (0.05), not dropEdgeFwd (0.25).
    // Toes at the lip put the feet origin ~0.1-0.2 m back, so the 0.25 m ray found air, the probe said no-edge and the
    // step-over guard swallowed V without a word. Only 0.25-0.7 m back ever dropped. isTouchingGround (fn_parkour's
    // entry guard) already says the player stands on something, so this ray only has to prove the ledge reaches ahead.
    private _eFrom = (_P vectorAdd (_f vectorMultiply _edgeNear)) vectorAdd [0, 0, _edgeUp];
    private _edge = [_eFrom, _eFrom vectorAdd [0, 0, -_edgeMax]] call _fnc_cast;
    if (_rejected) exitWith {["none", "", "rejected"]};
    if (_edge isEqualTo []) exitWith {["none", "", "no-edge"]};     // already past the lip, or not at one

    // One landing column at distance _y along f: [] when it passes, else the probe result to return. Sets "D".
    private _fnc_dropColumn = {
        params ["_y"];
        private _cFrom = (_P vectorAdd (_f vectorMultiply _y)) vectorAdd [0, 0, _edgeUp];
        private _col = [_cFrom, _cFrom vectorAdd [0, 0, -_depth]] call _fnc_cast;
        if (_rejected) exitWith {["none", "", "rejected"]};
        if (_col isEqualTo []) exitWith {["none", "Too far down to drop.", "drop-deep"]};
        private _D = _Pz - ((_col select 0) select 2);
        _data set ["D", _D];
        if (_D < _dropMin) exitWith {["none", "", "drop-shallow"]};
        if (_D > _dropMax) exitWith {["none", "Too far down to drop.", "drop-deep"]};
        if (((_col select 1) select 2) <= _topMinNz) exitWith {["none", "", "drop-slope"]};
        if ([_col select 0] call _fnc_inWater) exitWith {["none", "You would land in the water.", "drop-water"]};
        if !([(_col select 0) vectorAdd [0, 0, 0.1], (_col select 0) vectorAdd [0, 0, 0.1 + _dropHead]] call _fnc_clear) exitWith {["none", "", "drop-headroom"]};
        if (_rejected) exitWith {["none", "", "rejected"]};
        []
    };
    // The column at dropFwd is the acceptance gate: it proves the lip lies before dropFwd.
    private _bad = [_dropFwd] call _fnc_dropColumn;
    if !(_bad isEqualTo []) exitWith {_bad};

    // owner 2026-09-16 (review round 1): FIND THE LIP. The two rays above only prove it lies somewhere in
    // [dropEdgeNear, dropFwd), and fixed keyframes built for a lip at dropEdgeFwd glid the body down through the
    // ledge's own face when it was 0.5-0.7 m out. A ray just under the edge surface, from dropFwd (proven open)
    // back toward the player, hits the lip face; no hit (a slab thinner than dropLipBelow) = assume dropFwd.
    // A lip nearer than dropEdgeFwd (review r3) keeps the keyframes unshifted: they land further past the face.
    // owner 2026-09-16 (review round 4): ONLY A FACE IS A LIP (|nz| < faceMaxNz). The ray's height comes from the edge hit
    // at the toes, so on a surface falling toward the lip (~8 degrees and up) it passes over the lip and meets that
    // surface from above, 0.2-0.45 m short of the real lip, and K2 landed on or inside the face again (a sloped roof's
    // eave, a bank above a retaining wall). A row that is not a face = assume dropFwd, the full shift; the K2 column
    // re-check below then validates that landing.
    private _lipZ = ((_edge select 0) select 2) - (["dropLipBelow"] call _cfg);
    private _lFrom = _P vectorAdd (_f vectorMultiply _dropFwd);
    private _lTo = _P vectorAdd (_f vectorMultiply ((_edgeNear - 0.05) max 0));
    private _lipRow = [[_lFrom select 0, _lFrom select 1, _lipZ], [_lTo select 0, _lTo select 1, _lipZ]] call _fnc_cast;
    if (_rejected) exitWith {["none", "", "rejected"]};
    private _lip = if ((_lipRow isEqualTo []) || {(abs ((_lipRow select 1) select 2)) >= _faceMaxNz}) then {_dropFwd} else {((((_lipRow select 0) vectorDiff _P) vectorDotProduct _f) max _edgeNear) min _dropFwd};
    private _shift = (_lip - _edgeFwd) max 0;
    _data set ["lip", _lip];
    _data set ["dropShift", _shift];

    // The mover lands at dropK2Fwd + shift: re-check the column there when that is past the one already tested.
    private _k1y = (["dropK1Fwd"] call _cfg) + _shift;
    private _k2y = (["dropK2Fwd"] call _cfg) + _shift;
    if (_k2y > (_dropFwd + 0.05)) then {_bad = [_k2y] call _fnc_dropColumn};
    if !(_bad isEqualTo []) exitWith {_bad};

    // owner 2026-09-16 (review round 5): THE MOVER'S K2 BODY SWEEP, REPLAYED. K2 is not a home keyframe, and every tick
    // of fn_parkourMove _fnc_bodySweep in it casts a piece of ONE line per sweep height: K1 + h -> K2 + h + sweepLead
    // along (K2 - K1). Nothing else here tested the band ~0.5-0.7 m (+ shift) along f below the ledge, so a separate prop
    // on the facade (AC unit, sign box) passed the column at dropFwd and aborted the drop with the legs inside it.
    // Same world points (D is the value the mover reads) and the mover's _fnc_hit rule: a row on the ledge object (or
    // whose parent it is) is skipped only at or below P.z + sweepIgnoreMargin, and only when that object is not null
    // (a terrain ledge ignores nothing). The line descends, so one row per object hides nothing the pieces would see;
    // 10 rows so ignored ledge / proxy rows cannot crowd out a real hit further along the long line.
    private _eObj = _edge select 2;
    private _ignZ = _Pz + _ignMargin;
    private _k1w = (_P vectorAdd (_f vectorMultiply _k1y)) vectorAdd [0, 0, -(["dropK1Down"] call _cfg)];
    private _k2w = (_P vectorAdd (_f vectorMultiply _k2y)) vectorAdd [0, 0, -((_data get "D") - (["dropEndAbove"] call _cfg))];
    private _k2End = _k2w vectorAdd ((vectorNormalized (_k2w vectorDiff _k1w)) vectorMultiply (["sweepLead"] call _cfg));
    private _swept = (["sweepHeights"] call _cfg) findIf {
        private _rows = lineIntersectsSurfaces [_k1w vectorAdd [0, 0, _x], _k2End vectorAdd [0, 0, _x], player, objNull, true, 10, "GEOM", "NONE"];
        (_rows findIf {!((!(isNull _eObj)) && {((_x select 2) isEqualTo _eObj) || {(_x select 3) isEqualTo _eObj}} && {((_x select 0) select 2) <= _ignZ})}) > -1
    };
    if (_swept > -1) exitWith {["none", "", "drop-sweep"]};

    // Body room out to where the mover's sweeps reach (they no longer ignore the ledge's building above its top).
    private _dReach = (_k1y max _k2y) + (["sweepLead"] call _cfg);
    private _overhead = false;
    {
        private _o = _P vectorAdd [0, 0, _x];
        if !([_o, _o vectorAdd (_f vectorMultiply _dReach)] call _fnc_clear) exitWith {_overhead = true};
    } forEach (["sweepHeights"] call _cfg);
    if (_rejected) exitWith {["none", "", "rejected"]};
    if (_overhead) exitWith {["none", "", "drop-overhead"]};
    _data set ["obj", _edge select 2];
    ["drop", "", "drop"]
};

_result params ["_kind", "_msg", "_why"];
if (isNil "_why") then {_why = ""};
_data set ["why", _why];

// owner 2026-09-16 (review round 2): THE STEP-OVER GUARD (header). A silent "none" lets a standing player's V fall
// through to the engine step-over, which walks along FACING. Ground columns along facing; the first that finds no
// footing within stepGuardDepth is recorded as "stepUnsafe" (its distance) and AP_fnc_parkour swallows V. A person
// down there is not footing.
if ((_kind isEqualTo "none") && {_msg isEqualTo ""}) then {
    private _gUp = ["stepGuardUp"] call _cfg;
    private _gDepth = ["stepGuardDepth"] call _cfg;
    private _gFwd = ["stepGuardFwd"] call _cfg;
    if !(_gFwd isEqualType []) then {_gFwd = []};
    {
        private _c = _P vectorAdd (_facing vectorMultiply _x);
        private _rows = lineIntersectsSurfaces [_c vectorAdd [0, 0, _gUp], _c vectorAdd [0, 0, -_gDepth], player, objNull, true, 3, "GEOM", "NONE"];
        if ((_rows findIf {!((_x select 2) isKindOf "CAManBase")}) < 0) exitWith {_data set ["stepUnsafe", _x]};
    } forEach _gFwd;

    // owner 2026-09-16 (review round 3): TOO FAR BACK FROM A REAL DROP. "drop-shallow" means the drop test read the
    // floor at dropFwd, i.e. the lip is further out; when the guard then finds no footing along facing, V used to do
    // nothing and say nothing. One full drop column at that distance: a dry floor within [dropMin, dropMax] sets
    // "dropAhead" and AP_fnc_parkour shows fn_parkourCfg "dropCloserMsg". Anything else (deeper, water, no floor, a
    // person) stays silent.
    // Only the FIRST column's "drop-shallow" (no "lip" measured yet; the K2 re-check can also say it, with the player
    // already at the lip) and only a failing column beyond dropFwd count as "too far back".
    // owner 2026-09-16 (review round 4): the column alone invited the player toward drops the drop test refuses from every
    // spot. Three more of that test's own conditions, still a hint and not a promise:
    //   - dropMin is measured from the floor at dropFwd ("D" above), not from the feet, so it takes a real edge: a
    //     continuous slope or stair ramp steep enough to trip the guard but flat enough for topMinNz (38-46 degrees)
    //     falls < 0.82 m over the 0.8 m from dropFwd to the last shipped guard column, never dropMin 1.2;
    //   - nothing at knee / waist (rayHeights 0-1, the dropNearClear rays) or sweepHeights (drop-overhead) along facing
    //     out to _unsafeAt + dropK2Fwd - dropEdgeFwd + sweepLead: the lip lies before _unsafeAt, and from any spot a drop
    //     can start at, its sweeps need that much clear past the lip. A parapet or balcony railing refuses the drop at
    //     every distance (knee / waist inside dropNearClear), so it gets no notice;
    //   - dropHeadroom above the landing (drop-headroom).
    // Raw lineIntersectsSurfaces, any row: _fnc_cast would set _rejected, and a person in the way is not an invitation.
    private _unsafeAt = _data getOrDefault ["stepUnsafe", -1];
    if ((_unsafeAt > (["dropFwd"] call _cfg)) && {_why isEqualTo "drop-shallow"} && {(_data getOrDefault ["lip", -1]) < 0}) then {
        private _c = (_P vectorAdd (_facing vectorMultiply _unsafeAt)) vectorAdd [0, 0, ["dropEdgeUp"] call _cfg];
        private _row = (lineIntersectsSurfaces [_c, _c vectorAdd [0, 0, -(["dropDepth"] call _cfg)], player, objNull, true, 1, "GEOM", "NONE"]) param [0, []];
        if !(_row isEqualTo []) then {
            private _D = _Pz - ((_row select 0) select 2);
            private _aheadLen = _unsafeAt + (["dropK2Fwd"] call _cfg) - (["dropEdgeFwd"] call _cfg) + (["sweepLead"] call _cfg);
            if (((_D - ((_data getOrDefault ["D", 0]) max 0)) >= (["dropMin"] call _cfg)) && {_D <= (["dropMax"] call _cfg)}
                && {((_row select 1) select 2) > _topMinNz}
                && {!((_row select 2) isKindOf "CAManBase")}
                && {!([_row select 0] call _fnc_inWater)}
                && {(lineIntersectsSurfaces [(_row select 0) vectorAdd [0, 0, 0.1], (_row select 0) vectorAdd [0, 0, 0.1 + (["dropHeadroom"] call _cfg)], player, objNull, true, 1, "GEOM", "NONE"]) isEqualTo []}
                && {(((_heights select [0, 2]) + (["sweepHeights"] call _cfg)) findIf {
                    private _o = _P vectorAdd [0, 0, _x];
                    !((lineIntersectsSurfaces [_o, _o vectorAdd (_facing vectorMultiply _aheadLen), player, objNull, true, 1, "GEOM", "NONE"]) isEqualTo [])
                }) < 0}) then {_data set ["dropAhead", true]};
        };
    };
};

if (missionNamespace getVariable ["AP_parkourDebug", false]) then {
    private _o = _data getOrDefault ["obj", objNull];
    diag_log format ["[AP-PROBE] parkour probe: kind=%1 why=%2 H=%3 T=%4 d=%5 D=%6 dWall=%7 lod=%8 obj=%9 (%10) spd=%11 rej=%12 spdH=%13 lip=%14 stepUnsafe=%15 dropAhead=%16",
        _kind, _why,
        (_data getOrDefault ["H", -1]) toFixed 2, (_data getOrDefault ["T", -1]) toFixed 2,
        (_data getOrDefault ["d", -1]) toFixed 2, (_data getOrDefault ["D", -1]) toFixed 2,
        (_data getOrDefault ["dWall", -1]) toFixed 2, _data getOrDefault ["lod", ""],
        _o, (if (isNull _o) then {""} else {typeOf _o}), _spd toFixed 1,
        (if (isNull _rejectedBy) then {""} else {typeOf _rejectedBy}),
        _spdH toFixed 1, (_data getOrDefault ["lip", -1]) toFixed 2, (_data getOrDefault ["stepUnsafe", -1]) toFixed 2,
        _data getOrDefault ["dropAhead", false]];
};

[_kind, _data, _msg]
