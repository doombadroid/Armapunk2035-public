/*
    edenOracle.sqf  --  Eden as the oracle for the in-game map editor.

    Run in the 3DEN debug console, with MaldenEdit.Malden open:
        call compile preprocessFileLineNumbers "edenOracle.sqf";

    WHY THIS EXISTS. The in-game editor's only real output is a transform:
    [posWorld, [vectorDir, vectorUp]]. Every other part of it -- the gizmo, the
    catalogue, the undo ring -- is judged by eye and forgiving. The transform is
    not: a wrong one is invisible until objects sit centimetres into the pavement,
    and by then it is in the database and replicated to every client.

    3DEN is a running Arma instance, so its entities are REAL objects with real
    engine transforms. That makes it the only available ground truth for "what
    does this placement actually mean" -- better than the .sqm, which stores
    Euler angles the pipeline has to reconstruct, and better than the baked array,
    which was produced BY that reconstruction and so cannot test it.

    It emits, per entity, the engine's own posWorld / vectorDir / vectorUp and the
    entity's stored 3DEN position and rotation. tools/oracle_check.py checks frame
    agreement and orthonormality. Identity is an integer id since the v2 migration and
    needs no oracle; the bake-key check this probe used to carry is gone with the key.

    Output goes to the 3DEN RPT, tagged [AP-ORACLE]. The wire separator is ~, NOT |,
    because the bake key contains | as its own internal separator -- splitting the
    line on | tears the key into four fields and every row reads as a mismatch. (It
    did, on the parser's first self-test.)
*/
private _ents = (all3DENEntities select 0);
private _n = 0;

diag_log "[AP-ORACLE] BEGIN";
diag_log format ["[AP-ORACLE] META~%1~%2", worldName, count _ents];

{
    private _o = _x;
    if (isNull _o) then { continue };

    private _cls = typeOf _o;
    if (_cls isEqualTo "") then { _cls = (getModelInfo _o) param [0, ""]; };

    private _pw = getPosWorld _o;
    private _vd = vectorDir _o;
    private _vu = vectorUp _o;

    // 3DEN's stored attributes, for comparison against what the engine reports.
    // If an attribute id is wrong for this build, get3DENAttribute returns [] and the
    // param default would hand the checker a [0,0,0] rotation -- which reads as a huge
    // frame disagreement rather than as "the probe could not read it". Flag it instead,
    // so the first run cannot produce a confident wrong verdict.
    private _spRaw = _o get3DENAttribute "position";
    private _saRaw = _o get3DENAttribute "rotation";
    private _attrOk = (_spRaw isEqualType []) && {count _spRaw > 0}
                   && {_saRaw isEqualType []} && {count _saRaw > 0};
    private _sp = _spRaw param [0, [0,0,0]];
    private _sa = _saRaw param [0, [0,0,0]];

    // The bake key, computed the way SQF computes it everywhere else. This must
    // match mapkey.bake_key(cls, x, y, z) character for character.
    diag_log format ["[AP-ORACLE] ROW~%1~%2~%3~%4~%5~%6~%7~%8",
        get3DENEntityID _o, _cls, _pw, _vd, _vu, _sp, _sa, _attrOk];
    _n = _n + 1;
} forEach _ents;

diag_log format ["[AP-ORACLE] END~%1", _n];
systemChat format ["Oracle: dumped %1 entities to the RPT. Now run tools/oracle_check.py", _n];
