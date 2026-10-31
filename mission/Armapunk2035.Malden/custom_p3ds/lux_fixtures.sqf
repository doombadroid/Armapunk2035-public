/*
    custom_p3ds\lux_fixtures.sqf — per-floor kitchen / shower / toilet for
    the Skyscraper30 lux tower (v18 model).

    The designer fits every suite (floors 2..30) with three fixtures. They are
    instanced 29x each in the viewer and account for 536k of the model's 666k
    triangles, so the handoff is explicit: do NOT bake 29 copies into the tower
    p3d — ship each fixture once and place the copies.

    So they spawn here, the same way the door leaves do: LOCAL simple objects on
    every machine (collision is local and free, no network traffic, JIP handles
    itself because each machine builds its own set).

    NO CALIBRATION NEEDED, unlike the leaves. The fixture p3ds are built with
    their geometry centred on their own bbox, so the engine's autocentre and ours
    agree and a plain setPosASL lands them exactly. The leaves could not do that:
    they must rotate about a hinge at their edge, which is what forced the
    ray-measured placement dance.

    Called from the model sweep in malden_buildings.sqf, once per tower instance.
*/
params ["_bld"];

if (isNil "AP_LUXFIX_DATA") then {
    AP_LUXFIX_DATA = call compile preprocessFileLineNumbers
        "custom_p3ds\lux_fixtures_data.sqf";
};
if (isNil "AP_LUXFIX_OBJS") then { AP_LUXFIX_OBJS = []; };

private _MALDEN = getMissionPath "custom_p3ds\";   // models live here since 2026-08-19
private _paths = createHashMapFromArray [
    ["kitchen", _MALDEN + "ap_kitchen_r1.p3d"],
    ["shower",  _MALDEN + "ap_shower_r1.p3d"],
    ["toilet",  _MALDEN + "ap_toilet_r1.p3d"]
];
private _bd = getDir _bld;
private _n = 0;

// floors 2..30; floor N sits (N-2) * 3.6 m above floor 2 (uniform pitch, the
// double-height lobby is why floor 2 is the datum rather than the ground)
for "_f" from 2 to 30 do {
    private _dy = (_f - 2) * 3.6;
    {
        _x params ["_kind", "_off"];
        private _p = _paths getOrDefault [_kind, ""];
        if (_p isNotEqualTo "") then {
            private _o = createSimpleObject [_p, [0, 0, 0], true];
            _o setDir _bd;                      // p3d is authored pre-rotated in tower space
            _o setPosASL (AGLToASL (_bld modelToWorld
                [_off select 0, _off select 1, (_off select 2) + _dy]));
            _o setVariable ["AP_luxFixture", [_kind, _f], false];
            AP_LUXFIX_OBJS pushBack _o;
            _n = _n + 1;
        };
    } forEach AP_LUXFIX_DATA;
};

diag_log format ["[LUXFIX] %1: placed %2 fixtures across floors 2-30", (getModelInfo _bld) select 0, _n];
