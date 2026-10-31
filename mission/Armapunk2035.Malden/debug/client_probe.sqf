/*
    debug\client_probe.sqf   --  CLIENT-SIDE TELEMETRY PROBE  (dev instrumentation)

    Reports the state of the world as a PLAYER'S CLIENT actually sees it. The server and a headless
    client can only measure their own copies; since custom_p3ds\* now creates buildings with
    local=true, "the server looks fine" says nothing about what a player has. This closes that gap
    without anyone having to drive a client: you just play, and the probe reports.

    Results go through APS_fnc_logIt (CfgRE-whitelisted, allowedTargets=2) which mirrors to the
    server RPT as [LB-LOG] and persists to the `log` table under tag -PROBE-, so they are readable
    from loonydev.log or with:
        SELECT ts,name,message FROM log WHERE tag='-PROBE-' ORDER BY ts DESC LIMIT 40;

    Runs once ~25s after join. Re-runnable at any time from the debug console with:
        [] call AP_fnc_probe;

    DEV INSTRUMENTATION -- remove the initPlayerLocal.sqf call before any live deploy.
*/
if (!hasInterface) exitWith {};

AP_fnc_probe = {
    private _say = {
        params ["_msg"];
        diag_log format ["[PROBE] %1", _msg];
        [["-PROBE-", player, name player, _msg], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
    };

    // what a healthy client should have: 55 placements from malden_buildings.sqf, plus the one
    // RebelRig from load.sqf. Any model reading DOUBLE here means a createSimpleObject call lost
    // its local=true and is replicating again.
    private _expect = [
        ["policehqwalllong", 41], ["bridgestraight", 15], ["hqmesh", 4], ["palaceshop", 2],
        ["rebelrig", 1], ["bridgemiddle", 1], ["bank", 1], ["mentalasylum13_r24", 1],
        ["evidencesign", 1], ["federalreservesign", 1], ["jewelrybuildingmodel", 1],
        ["maldengrandpalacebuilding_r4", 1]
    ];

    private _all = allSimpleObjects [];
    private _models = _all apply { toLower ((getModelInfo _x) select 0) };
    [format ["build=%1 fps=%2 simpleObjects=%3 pos=%4",
        missionName, round diag_fps, count _all, mapGridPosition player]] call _say;

    private _bad = [];
    {
        _x params ["_needle", "_want"];
        private _got = count (_models select { _needle in _x });
        if (_got != _want) then { _bad pushBack format ["%1 %2/%3", _needle, _got, _want] };
    } forEach _expect;
    if (count _bad isEqualTo 0) then {
        [format ["buildings OK -- all %1 models at expected counts", count _expect]] call _say;
    } else {
        [format ["BUILDING COUNT MISMATCH: %1", _bad joinString ", "]] call _say;
    };

    // scale + collision smoke test on the two models we have actually edited
    {
        _x params ["_needle", "_wantScale"];
        private _o = _all param [_models findIf { _needle in _x }, objNull];
        if (isNull _o) then {
            [format ["%1 MISSING on this client", _needle]] call _say;
        } else {
            private _bb = boundingBoxReal _o;
            private _sc = getObjectScale _o;
            (_bb select 0) params ["_bx0","_by0","_bz0"];
            (_bb select 1) params ["_bx1","_by1","_bz1"];
            // one ray straight through at head height above the base -- does GEOM stop it?
            private _h = _bz0 + 2.5;
            private _b = AGLToASL (_o modelToWorldVisual [_bx0 - 8, 0, _h]);
            private _e = AGLToASL (_o modelToWorldVisual [_bx1 + 8, 0, _h]);
            private _hits = (lineIntersectsSurfaces [_b, _e, objNull, objNull, true, -1, "GEOM", "NONE", false])
                            select { (_x select 2) isEqualTo _o };
            [format ["%1 scale=%2 (want %3) size=%4x%5x%6 GEOM-crossings=%7 %8",
                _needle, _sc, _wantScale,
                round (_bx1 - _bx0), round (_by1 - _by0), round (_bz1 - _bz0),
                count _hits,
                if (count _hits >= 2) then {"SOLID"} else {"NO COLLISION"}]] call _say;
        };
    } forEach [["mentalasylum13_r24", 1], ["maldengrandpalacebuilding_r4", 0.7]];
};

[] spawn { uiSleep 25; [] call AP_fnc_probe; };
