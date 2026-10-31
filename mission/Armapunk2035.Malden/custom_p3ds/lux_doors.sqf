/*
    custom_p3ds\lux_doors.sqf — no-addon door system for the
    Skyscraper30 lux (owner spec, handoff v9 pivot 2026-08-05).

    Runs on EVERY machine (called from malden_buildings.sqf right after the
    building spawns, same as the buildings themselves): each machine creates
    its own LOCAL leaf simple objects, so collision is local and free, exactly
    like the custom buildings. What syncs is only the door STATE — a public
    setVariable on the (server-created? no: every machine's own local building
    object is different!) — state therefore lives in a mission-global public
    array AP_LUXDOOR_STATE, server-owned, JIP-safe by publicVariable
    semantics: index = door index, value = 0 closed / 1 open.

    MULTI-INSTANCE (2026-08-06, owner cloned the tower via composition): the
    sweep calls this once PER BUILDING, serialized (waitUntil scriptDone), and
    each call appends its leaves to the shared flat arrays at offset _base.
    Door index = flat index across all instances; the scanner, actions and
    watcher already iterate the flat arrays so they see every instance.
    Calibration is per-machine, not per-building — the first instance
    measures, later instances wait on AP_LUXDOOR_CALDONE and re-place
    their own range with the shared constants.

    The leaf p3ds are re-origined (hinge = local Y axis at 0,0,0) but the
    engine AUTOCENTERS simple objects on their bbox — so rotation is done in
    script: every animation frame sets BOTH setDir and setPosASL, placing the
    leaf's center at hinge + R(yaw)·centerOffset. That makes the swing pivot
    the true hinge regardless of autocentering.

    Toggle: addAction on the leaf (radius 2.2). The action publishes the new
    state; every machine's watcher loop sees the change and animates its own
    local leaf (0.6 s lerp) with a vanilla door sound. Locked doors
    (_leaf getVariable ["ap_doorLocked", true-ish]) refuse to open.
*/
params ["_bld"];

if (isNil "AP_LUXDOOR_DATA") then {
    AP_LUXDOOR_DATA = call compile preprocessFileLineNumbers
        "custom_p3ds\lux_doors_data.sqf";
};
private _base = count (missionNamespace getVariable ["AP_LUXDOOR_LEAVES", []]);
// b0348: stamp this instance's slice offset ON THE BUILDING. The suite system
// needs to map "floor N of THIS tower" to a flat leaf index, and reading the
// offset off the object avoids both a second global and a duplicated copy of the
// tower-key format (which would drift the moment either side changed).
_bld setVariable ["ap_luxDoorBase", _base, false];
if (isServer) then {
    if (isNil "AP_LUXDOOR_STATE") then { AP_LUXDOOR_STATE = []; };
    private _need = _base + count AP_LUXDOOR_DATA;
    while { count AP_LUXDOOR_STATE < _need } do { AP_LUXDOOR_STATE pushBack 0; };
    publicVariable "AP_LUXDOOR_STATE";
};

private _MALDEN = getMissionPath "custom_p3ds\";   // models live here since 2026-08-19
private _paths = [_MALDEN + "lux_leaf_106_r11.p3d", _MALDEN + "lux_leaf_94_r11.p3d", _MALDEN + "lux_leaf_92_r11.p3d"];
private _spans = [1.06, 0.94, 0.92];      // lux metal leaves, x 0..span, y 0..2.16
private _bd = getDir _bld;

// PER-MACHINE PLACEMENT CALIBRATION. Different machines resolved the leaf's
// origin differently (owner's client: +halfHeight with setPosASL, sunk-half
// with setPosWorld; this box: flush either way) — so no fixed policy is
// trusted. Instead: spawn a probe leaf at a known point, RAY-SCAN where its
// body actually sits relative to that point (lineIntersectsSurfaces = a
// reader independent of the position API), and derive this machine's local
// corrections. Every leaf is then placed with the measured constants, and
// leaf 0 is ray-verified after placement.
private _place = {
    params ["_leaf", "_hingeASL", "_yaw", "_span"];
    _leaf setDir _yaw;
    // b0341: horizontal policy is center-at-point (autocentered origin lands
    // on the set position — measured), so the geometric shift is HALF THIS
    // LEAF'S span; AP_LUXDOOR_DXL holds only the machine residual (~0). The
    // old single DXL=0.40 came from a 0.1-step edge scan quantizing 0.46-0.53
    // halfspans down — every leaf sat 3-7 cm hinge-ward (owner-visible gap
    // on the handle side).
    private _dx = _span / 2 + AP_LUXDOOR_DXL;
    // b0356 owner call: every leaf sits 2 inches LEFT of dead centre in its
    // frame. Geometry says the leaves ARE centred (the frame openings are
    // 1.00/1.00/1.10 m against 0.94/0.92/1.06 m leaves, so the reveals come out
    // even), so this is a deliberate look, not a correction -- which is why it
    // is one tunable world-space constant rather than something folded into the
    // leaf models. 87 of the 88 doors lie along world X, so "left" is a single
    // direction for effectively all of them; the one cross-wall door shifts with
    // its own wall instead.
    private _nudge = if (abs (sin _yaw) > 0.7) then { [0, AP_LUXDOOR_NUDGE, 0] } else { [AP_LUXDOOR_NUDGE, 0, 0] };
    _leaf setPosASL ((_hingeASL vectorAdd
        [_dx * cos _yaw, -_dx * sin _yaw, AP_LUXDOOR_DZL]) vectorAdd _nudge);
};

if (isNil "AP_LUXDOOR_LEAVES") then {
    AP_LUXDOOR_LEAVES = []; AP_LUXDOOR_DZL = 0; AP_LUXDOOR_DXL = 0;
};
// Lateral offset of every leaf within its frame, metres; 0.05 = 2 inches.
// SIGN: positive shifts +x (and +z for the one cross-wall door). The first
// attempt went the other way and the owner reported the gap got wider, so this
// is the direction that closes it. One constant, two readers -- the placement
// and the calibration below MUST use the same vector, or the calibration reads
// the shift as a machine error and corrects it straight back out.
AP_LUXDOOR_NUDGE = 0.05;
{
    _x params ["_hingeModel", "_yawAdd", "_kind", "_openDeg"];
    private _hingeASL = AGLToASL (_bld modelToWorld _hingeModel);
    private _yaw0 = _bd + _yawAdd;
    private _leaf = createSimpleObject [_paths select _kind, [0, 0, 0], true];
    [_leaf, _hingeASL, _yaw0, _spans select _kind] call _place;
    _leaf setVariable ["ap_luxDoorIdx", _base + _forEachIndex];
    AP_LUXDOOR_LEAVES pushBack [_leaf, _hingeASL, _yaw0, _spans select _kind, _openDeg, 0];
} forEach AP_LUXDOOR_DATA;

// IN-SITU CALIBRATION off leaf 0 (an ocean-spawned probe has no collision —
// engine law from the asylum saga — so measure a real leaf at the building).
// Ray-scan finds where this machine actually put the body relative to the
// hinge; every leaf is then re-placed with the measured corrections.
// First instance measures; later instances wait for the constants.
if (_base isEqualTo 0) then {
[_place] spawn {
    params ["_place"];
    sleep 1.5;
    (AP_LUXDOOR_LEAVES select 0) params ["_l0", "_h0", "_y0"];
    private _bot = 1e9; private _dxAlong = 0;
    private _try = 0;
    while { _bot > 1e8 && _try < 6 } do {
    if (_try > 0) then { sleep 1; };
    _try = _try + 1;
    {
        private _ot = _x;
        for "_k" from -1.1 to 1.1 step 0.1 do {
            if (_bot > 1e8) then {
                private _o = [_k * cos _y0 + _ot * sin _y0, -_k * sin _y0 + _ot * cos _y0, 0];
                {
                    if ((_x select 2) isEqualTo _l0) then {
                        _bot = _bot min ((_x select 0) select 2);
                        _dxAlong = _k;
                    };
                } forEach lineIntersectsSurfaces [(_h0 vectorAdd _o) vectorAdd [0, 0, 2.6], (_h0 vectorAdd _o) vectorAdd [0, 0, -0.6], objNull, objNull, false, 24];
            };
        };
    } forEach [0.02, 0.12, -0.12];
    };
    if (_bot > 1e8) exitWith {
        diag_log "[APDOORS] CALIBRATION FAILED (leaf0 body not found after retries)";
        AP_LUXDOOR_CALDONE = true;   // release waiters (constants stay 0)
    };
    // horizontal edge: walk k toward the hinge until rays stop hitting
    // (b0341: FINE steps — the 0.1 grid quantized the halfspan and left a
    // visible handle-side gap; 0.02 resolves the edge to +-1 cm)
    private _edge = _dxAlong;
    for "_k" from (_dxAlong * 50) to -56 step -1 do {
        private _kk = _k / 50;
        private _o2 = [_kk * cos _y0 + 0.02 * sin _y0, -_kk * sin _y0 + 0.02 * cos _y0, 0];
        private _hit = false;
        {
            if ((_x select 2) isEqualTo _l0) then { _hit = true; };
        } forEach lineIntersectsSurfaces [(_h0 vectorAdd _o2) vectorAdd [0, 0, 2.6], (_h0 vectorAdd _o2) vectorAdd [0, 0, -0.6], objNull, objNull, false, 24];
        if (_hit) then { _edge = _kk; };
    };
    // b0339 METER FIX: a downward ray reports only ENTRY surfaces — the hit
    // is the leaf's TOP face, never its bottom. The old code read it as the
    // bottom, so on every machine it "measured" dz = leaf height on an
    // already-correct bottom-at-point placement and sank every leaf by
    // exactly its own height (lux 2.160, 20F 2.198 — both "policy constants"
    // were just the leaf heights). Interpret the hit as the TOP: the body is
    // correct when top sits at hinge + height.
    private _bbC = boundingBoxReal _l0;
    private _Hc = ((_bbC select 1) select 2) - ((_bbC select 0) select 2);
    AP_LUXDOOR_DZL = -(_bot - (_h0 select 2) - _Hc);
    // b0341: DXL is the RESIDUAL on top of the geometric halfspan shift that
    // _place already applies (center-at-point policy). b0342: the r6 leaves
    // are OVERSIZED per kind to cover the frame reveals — the hinge stile
    // extends past the hinge by 0.016/0.026/0.036 (k106/k94/k92) BY DESIGN,
    // so the expected measured edge is -ext(kind of leaf0), not 0.
    private _exts = [0.016, 0.026, 0.036];   // by kind idx (0=1.06, 1=0.94, 2=0.92)
    private _e0 = _exts select ((AP_LUXDOOR_DATA select 0) select 2);
    // b0356: the calibration must know about the deliberate nudge, or it reads
    // that 5 cm shift as a machine origin error and quietly corrects it away --
    // two things steering one placement, and the nudge loses. Project the nudge
    // onto the leaf's own across-the-opening axis (+u is [cos yaw, -sin yaw])
    // and expect the hinge edge there instead.
    private _nv = if (abs (sin _y0) > 0.7) then { [0, AP_LUXDOOR_NUDGE, 0] } else { [AP_LUXDOOR_NUDGE, 0, 0] };
    private _nu = ((_nv select 0) * cos _y0) - ((_nv select 1) * sin _y0);
    private _raw = -_edge - _e0 + _nu;
    // b0346: the edge scan can only resolve to its own STEP (0.02), and it
    // always reports the last grid point that still hit — i.e. it rounds the
    // leaf SHORT, and the "residual" it derives then nudges every leaf that
    // far toward the hinge (owner: gap on the handle side, same direction
    // each time). Within one step the measurement cannot distinguish a real
    // machine offset from its own quantization, so snap it to zero; only a
    // deviation LARGER than the step is a genuine policy difference worth
    // correcting, and it says so loudly.
    private _step = 0.02;
    AP_LUXDOOR_DXL = if (abs _raw <= _step) then { 0 } else { _raw };
    diag_log format ["[APDOORS] calibration: TOP %1 above hinge (H=%2), hinge-edge %3 (want %4) -> dz=%5 dxRaw=%6 dxApplied=%7%8",
        (_bot - (_h0 select 2)) toFixed 3, _Hc toFixed 3, _edge toFixed 3,
        (_nu - _e0) toFixed 3, AP_LUXDOOR_DZL toFixed 3, _raw toFixed 3,
        AP_LUXDOOR_DXL toFixed 3,
        if (abs _raw <= _step) then { " (within ray step, snapped)" } else { " (REAL OFFSET)" }];
    {
        _x params ["_leaf", "_hingeASL", "_yaw0", "_span", "_openDeg", "_cur"];
        [_leaf, _hingeASL, _yaw0 + _openDeg * _cur, _span] call _place;
    } forEach AP_LUXDOOR_LEAVES;
    AP_LUXDOOR_CALDONE = true;
};
} else {
    // later instance: wait for the first instance's constants, re-place own range
    [_place, _base, count AP_LUXDOOR_DATA] spawn {
        params ["_place", "_b", "_n"];
        waitUntil { sleep 0.5; missionNamespace getVariable ["AP_LUXDOOR_CALDONE", false] };
        for "_i" from _b to (_b + _n - 1) do {
            (AP_LUXDOOR_LEAVES select _i) params ["_leaf", "_h", "_y", "_s", "_od", "_cur"];
            [_leaf, _h, _y + _od * _cur, _s] call _place;
        };
        diag_log format ["[APDOORS] instance at base %1: re-placed %2 leaves with shared calibration", _b, _n];
    };
};

// post-placement self-check by ray (independent reader): leaf 0's body bottom
// must sit on its hinge within 5 cm on THIS machine
if (_base isEqualTo 0) then {
[] spawn {
    sleep 12;   // strictly after calibration incl. retries
    (AP_LUXDOOR_LEAVES select 0) params ["_l", "_h", "_y"];
    private _bot = 1e9;
    for "_k" from 0.1 to 0.9 step 0.2 do {
        if (_bot > 1e8) then {
            private _o = [_k * cos _y, -_k * sin _y, 0];
            {
                if ((_x select 2) isEqualTo _l) then { _bot = _bot min ((_x select 0) select 2); };
            } forEach lineIntersectsSurfaces [(_h vectorAdd _o) vectorAdd [0, 0, 2.6], (_h vectorAdd _o) vectorAdd [0, 0, -0.6], objNull, objNull, false, 24];
        };
    };
    if (_bot < 1e8) then {
        // b0339: the ray reports the TOP face (entry surface) — the leaf sits
        // right when TOP = hinge + height. The old bottom-read passed a leaf
        // sunk by its full height (its top edge grazed the floor at "0.000").
        private _bbV = boundingBoxReal _l;
        private _Hv = ((_bbV select 1) select 2) - ((_bbV select 0) select 2);
        private _d = _bot - (_h select 2) - _Hv;
        diag_log format ["[APDOORS] leaf0 ray check: top-(hinge+H) delta %1 m (%2)",
            _d toFixed 3, ["OK", "FAIL"] select (abs _d > 0.05)];
    } else {
        diag_log "[APDOORS] leaf0 ray check: no hit (ray missed leaf body)";
    };
};
};

// Scroll actions live on the PLAYER, not the leaves: addAction attached to a
// simple object never reaches the action menu (confirmed in-game). A cheap
// scanner keeps AP_LUXDOOR_NEAR = index of the closest leaf within reach; the
// two player actions condition on it. Once per machine — the flat-array scan
// covers every instance's leaves automatically. Keyed on the (final) helper, not on the scanner's data var,
// which any client could publicVariable to make a joiner skip this block (security 2026-09-26).
if (hasInterface && {!isFinal "AP_LUXDOOR_ADDACTS"}) then {
    AP_LUXDOOR_NEAR = -1;
    [] spawn {
        waitUntil { !isNull player };
        while { true } do {
            private _best = -1;
            private _bestD = 2.4;
            private _eye = getPosASL player;
            {
                private _d = _eye vectorDistance getPosASL (_x select 0);
                if (_d < _bestD) then { _bestD = _d; _best = _forEachIndex; };
            } forEach AP_LUXDOOR_LEAVES;
            AP_LUXDOOR_NEAR = _best;
            sleep 0.25;
        };
    };
    [] spawn {
        waitUntil { !isNull player && { !isNil "AP_LUXDOOR_STATE" } };
        // b0341: re-add whenever OUR action ids are gone from the unit — a
        // sticky "added once" flag missed the life framework's
        // removeAllActions during the spawn flow (measured: flag true,
        // actionIDs empty, scanner+conditions all fine → no menu entry).
        // Polling the live id list self-heals after respawn, unit swap AND
        // any framework wipe.
        while { true } do {
            if (!isNil "AP_LUXDOOR_ADDACTS") then {
                private _ids = player getVariable ["ap_luxDoorActIds", []];
                private _live = actionIDs player;
                if (count _ids == 0 || {_ids findIf { !(_x in _live) } >= 0}) then {
                    player setVariable ["ap_luxDoorActIds", call AP_LUXDOOR_ADDACTS];
                };
            };
            sleep 3;
        };
    };
    AP_LUXDOOR_ADDACTS = compileFinal {
        private _a = player addAction [
            "<t color='#9fdf9f'>Open Door</t>",
            {
                private _i = AP_LUXDOOR_NEAR;
                if (_i < 0) exitWith {};
                private _lf = (AP_LUXDOOR_LEAVES select _i) select 0;
                // b0350: suite doors gate on WHO you are, not just on the flag.
                // Falls back to the plain flag check if the suite helpers are not
                // loaded, so a load-order problem can never make a door unopenable.
                private _may = if (isNil "AP_fnc_suiteMayOpen")
                    then { !(_lf getVariable ["ap_doorLocked", false]) }
                    else { [_lf] call AP_fnc_suiteMayOpen };
                if (!_may) exitWith { hint "This suite is locked."; };
                AP_LUXDOOR_STATE set [_i, 1];
                publicVariable "AP_LUXDOOR_STATE";
            },
            nil, 1.6, true, true, "",
            "AP_LUXDOOR_NEAR >= 0 && {(AP_LUXDOOR_STATE param [AP_LUXDOOR_NEAR, 1]) isEqualTo 0}"
        ];
        private _b = player addAction [
            "<t color='#dfb89f'>Close Door</t>",
            {
                private _i = AP_LUXDOOR_NEAR;
                if (_i < 0) exitWith {};
                AP_LUXDOOR_STATE set [_i, 0];
                publicVariable "AP_LUXDOOR_STATE";
            },
            nil, 1.6, true, true, "",
            "AP_LUXDOOR_NEAR >= 0 && {(AP_LUXDOOR_STATE param [AP_LUXDOOR_NEAR, 0]) isEqualTo 1}"
        ];
        [_a, _b]
    };
};

// (client-diagnostic aid: log the first leaf's real placement to the client
// RPT so a joined client's numbers can be compared against the server probe)
if (hasInterface && _base isEqualTo 0) then {
    [] spawn {
        waitUntil { count AP_LUXDOOR_LEAVES > 0 };
        sleep 5;
        (AP_LUXDOOR_LEAVES select 0) params ["_l", "_h"];
        diag_log format ["[APDOORS client] leaf0 hinge=%1 pos=%2 bb=%3",
            _h, getPosASL _l, boundingBoxReal _l];
    };
};

// b0350: a joining/relogging client starts with every leaf unlocked and unowned.
// Ask the server to replay the real lock state for every leased suite once our
// leaves exist. Cheap (one query, only leased rows) and idempotent.
if (hasInterface && {isNil "AP_suiteDoorStateAsked"}) then {
    AP_suiteDoorStateAsked = true;
    [] spawn {
        waitUntil { sleep 1; !isNil "AP_LUXDOOR_LEAVES" && {count AP_LUXDOOR_LEAVES > 0} };
        sleep 4;   // after calibration re-places them
        [["doorState", ""], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    };
};

// watcher: reconcile local leaves to the shared state, animating each change
// (one per machine — iterates the flat array, so it animates every instance)
if (!isNil "AP_LUXDOOR_WATCH") exitWith {};
AP_LUXDOOR_WATCH = true;
[_place] spawn {
    params ["_place"];
    waitUntil { !isNil "AP_LUXDOOR_STATE" };
    while { true } do {
        {
            _x params ["_leaf", "_hingeASL", "_yaw0", "_span", "_openDeg", "_cur"];
            private _i = _leaf getVariable ["ap_luxDoorIdx", -1];
            private _want = AP_LUXDOOR_STATE param [_i, 0];
            if (_want != _cur) then {
                AP_LUXDOOR_LEAVES set [_forEachIndex,
                    [_leaf, _hingeASL, _yaw0, _span, _openDeg, _want]];
                [_leaf, _hingeASL, _yaw0, _span, _openDeg, _cur, _want, _place] spawn {
                    params ["_leaf", "_hingeASL", "_yaw0", "_span", "_openDeg", "_from", "_to", "_place"];
                    if (_to == 1) then {
                        playSound3D ["a3\sounds_f\structures\doors\genericdoors\squeak1.wss",
                            _leaf, false, getPosASL _leaf, 2, 1, 25, 0, true];
                    };
                    private _t0 = diag_tickTime;
                    while { diag_tickTime - _t0 < 0.6 } do {
                        private _k = ((diag_tickTime - _t0) / 0.6) min 1;
                        private _ph = _from + (_to - _from) * _k;
                        [_leaf, _hingeASL, _yaw0 + _openDeg * _ph, _span] call _place;
                        sleep 0.02;
                    };
                    [_leaf, _hingeASL, _yaw0 + _openDeg * _to, _span] call _place;
                    if (_to == 0) then {
                        playSound3D ["a3\sounds_f\structures\doors\genericdoors\slam1.wss",
                            _leaf, false, getPosASL _leaf, 2, 1, 25, 0, true];
                    };
                };
            };
        } forEach AP_LUXDOOR_LEAVES;
        sleep 0.4;
    };
};
