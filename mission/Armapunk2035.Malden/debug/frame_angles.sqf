/*
    debug\frame_angles.sqf  --  ROTATION-FRAME PROBE  (dev instrumentation)

    Companion to debug\frame_probe.sqf, which settled the POSITION half: getPosWorld reads back the
    sqm's position[] elevation exactly, so mission.sqm stores the model centre and placing an object
    from it needs no terrain height. This one settles the ROTATION half.

    The sqm stores orientation as angles[]={rx,ry,rz} in radians. The spawn arrays store
    [[dirX,dirY,dirZ],[upX,upY,upZ]]. Which Euler convention connects them has never been proven
    here, and guessing wrong is silent -- objects come out subtly or completely mis-aimed.

    Rather than assume an order, this measures GROUND TRUTH: for each sampled sqm row it finds the
    REAL object the engine built from that row and logs the engine's own vectorDir/vectorUp. The
    convention is then solved offline (tools/frame_solve.py) by testing every axis order and sign
    combination against these measurements and keeping the one that reproduces them.

    Rows come from tools/sqm_frame_sample.py, biased towards tilt -- a flat object is satisfied by
    almost any convention and proves nothing.

    Resolution is by class + 2D position (the sqm's x/y are exact in every frame). Rows with more
    than one candidate are reported AMBIGUOUS and skipped rather than guessed at; the sampler
    already excludes same-class neighbours within 1.5 m, so this should not fire.

    Output: diag_log -> loonydev.log. grep [FRAMEANG].  Creates and deletes nothing.

    DEV INSTRUMENTATION -- remove the initServer.sqf call before any live pack.
*/
if (worldName != "Malden") exitWith {};

private _tag = "[FRAMEANG]";
call compile preprocessFileLineNumbers "debug\frame_angles_data.sqf";
if (isNil "AP_frameRows") exitWith {
    diag_log format ["%1 ABORT -- frame_angles_data.sqf did not define AP_frameRows", _tag];
};

private _f = { (_this select 0) toFixed (_this select 1) };
private _v3 = { format ["%1,%2,%3",
    (_this select 0) toFixed 6, (_this select 1) toFixed 6, (_this select 2) toFixed 6] };

diag_log format ["%1 ==== start  rows=%2 world=%3 isDedicated=%4 ====",
    _tag, count AP_frameRows, worldName, isDedicated];

private _hit = 0; private _miss = 0; private _amb = 0;

/*
    MOST OF THE DESIGNER'S PROPS ARE EDEN *SIMPLE OBJECTS*, and that dictates how they are found.

    The first run of this probe lost 52 of 59 rows. The diagnostic showed nearestObjects returning
    nothing for a class while the same call WITHOUT a type filter returned that exact class, and a
    second run showed allMissionObjects reporting 372 objects against the sqm's 4260. Both are the
    same cause: a simple object is excluded from allMissionObjects and is not matched by
    nearestObjects' type filter, though an unfiltered search still returns it and typeOf still names
    it. The 7 rows that did resolve were Land_HelipadEmpty_F -- anchors, not simple objects.

    So: search unfiltered, then filter on typeOf ourselves.
*/
diag_log format ["%1 allMissionObjects=%2 (sqm holds far more -- simple objects are excluded)",
    _tag, count (allMissionObjects "All")];

{
    _x params ["_id", "_cls", "_pos", "_ang"];
    _pos params ["_px", "_py", "_pz"];

    private _raw = (nearestObjects [[_px, _py], [], 3]) select { typeOf _x == _cls };
    // keep only the ones whose model centre is at the sqm's height -- separates stacked copies
    private _cands = _raw select { abs (((getPosWorld _x) select 2) - _pz) < 0.5 };

    switch (true) do {
        case (count _cands == 0): {
            _miss = _miss + 1;
            // report WHY, rather than leaving "missing" ambiguous between "no such object" and
            // "found it but rejected it": log the pre-filter candidates and anything else nearby.
            private _why = if (count _raw > 0) then {
                format ["zfilter n=%1 z=%2 want=%3", count _raw,
                    _raw apply { ((getPosWorld _x) select 2) toFixed 3 }, _pz toFixed 3]
            } else {
                private _any = nearestObjects [[_px, _py], [], 4];
                format ["noclass n=%1 near=%2", count _any,
                    (_any select [0, 4]) apply { typeOf _x }]
            };
            diag_log format ["%1 MISS  id=%2 cls=%3 xy=%4,%5 %6", _tag, _id, _cls,
                [_px, 3] call _f, [_py, 3] call _f, _why];
        };
        case (count _cands > 1): {
            _amb = _amb + 1;
            diag_log format ["%1 AMBIG id=%2 cls=%3 n=%4", _tag, _id, _cls, count _cands];
        };
        default {
            private _o = _cands select 0;
            private _w = getPosWorld _o;
            _hit = _hit + 1;
            // one line, machine-parseable: sqm truth on the left, engine truth on the right
            diag_log format ["%1 ROW id=%2 cls=%3 sqmpos=%4 sqmang=%5 pos=%6 dir=%7 up=%8 getdir=%9",
                _tag, _id, _cls,
                [_px, _py, _pz] call _v3,
                _ang call _v3,
                _w call _v3,
                (vectorDir _o) call _v3,
                (vectorUp _o) call _v3,
                (getDir _o) toFixed 6];
        };
    };
} forEach AP_frameRows;

diag_log format ["%1 ==== end  resolved=%2 missing=%3 ambiguous=%4 ====", _tag, _hit, _miss, _amb];
