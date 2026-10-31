/*
    debug\frame_verify.sqf  --  POST-MIGRATION CHECK (dev instrumentation)

    Closes the one gap the offline verification could not: setPosWorld had never been measured as a
    SETTER. debug/frame_probe.sqf only ever used getPosWorld to READ, and the migration's numbers
    were checked offline against those reads -- so "the array holds the right numbers" is proven,
    while "the loader puts objects where the numbers say" is not. If some class snapped to ground
    or was nudged on placement, every offline check would still pass and the map would be wrong.

    So this replays a sample of rows through the loader's own function and compares the object's
    own getPosWorld against the array value it was built from. Anything but ~0 means setPosWorld is
    not a faithful inverse of getPosWorld for that class, which is a stop-everything result.

    Samples evenly across the array rather than taking the first N: the first rows are one castle
    and prove nothing about the other 8,000.

    Output: the client RPT. grep [FRAMEVERIFY].  Objects are deleted again.

    DEV INSTRUMENTATION -- delete the initPlayerLocal.sqf call before any live pack.
*/
if (!hasInterface) exitWith {};
if (isNil "allLocalMapEntities") then { [] call AP_fnc_mapData; };

private _tag = "[FRAMEVERIFY]";
private _n = count allLocalMapEntities;
private _sample = 400;
private _stride = round (_n / _sample) max 1;

private _worst = 0; private _worstCls = ""; private _checked = 0; private _bad = 0;

for "_i" from 0 to (_n - 1) step _stride do {
    (allLocalMapEntities select _i) params
        ["_cls", "_pos", "_dir", ["_code", ""], ["_srv", false], ["_loadout", []]];

    private _o = _pos call {
        // the loader's own client branch and its own placement command
        private _v = if (_code isEqualTo "" && {_loadout isEqualTo []}) then {
            createSimpleObject [_cls, [0, 0, 0], true]
        } else {
            _cls createVehicleLocal [0, 0, 0]
        };
        if (isNull _v) exitWith { objNull };
        _v enableSimulation false;
        _v allowDamage false;
        if (_dir isEqualType []) then { _v setVectorDirAndUp _dir } else { _v setDir _dir };
        _v setPosWorld _this;
        _v
    };
    if (isNull _o) then { continue };

    private _w = getPosWorld _o;
    private _e = 0;
    { _e = _e max (abs ((_w select _x) - (_pos select _x))) } forEach [0, 1, 2];
    _checked = _checked + 1;
    if (_e > 0.01) then {
        _bad = _bad + 1;
        if (_bad <= 10) then {
            diag_log format ["%1 OFF  i=%2 cls=%3 want=%4 got=%5 err=%6", _tag, _i, _cls,
                _pos, _w, _e toFixed 4];
        };
    };
    if (_e > _worst) then { _worst = _e; _worstCls = _cls };
    deleteVehicle _o;
};

diag_log format ["%1 ==== checked=%2 of %3 rows | off-by->1cm=%4 | worst=%5 m (%6) ====",
    _tag, _checked, _n, _bad, _worst toFixed 4, _worstCls];
