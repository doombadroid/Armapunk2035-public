/*
    AP_fnc_gpsHud  (LooneyBin, owner 2026-07-12)
    Turn-by-turn banner (dialog\gpsHUD.hpp). v2: driven by an EachFrame mission EH throttled to
    2Hz -- the v1 uiSleep loop lived in the scheduler, which this mission saturates, so "0.7s"
    ticks stretched to many seconds. Unscheduled = the banner and reroute react instantly.

    Modes:
        ["start"]   (re)install the EachFrame driver + show the banner layer
        ["stop"]    remove the driver + fade the banner
        ["tick"]    one update: banner text, arrival auto-clear, off-route auto-reroute
                    (>60m off for >2.5s)
*/
if (!hasInterface) exitWith {};
params [["_mode", "", [""]]];
// breadcrumb surface probe for the "start" Draw3D (cache and rationale there). Defined at top level so
// core\init.sqf's "boot" call makes it final at client init (security 2026-09-26).
if !(isFinal "AP_fnc_gpsSurfZ") then {AP_fnc_gpsSurfZ = compileFinal {
    params ["_x", "_y"];
    private _key = format ["%1:%2", round _x, round _y];
    private _c = AP_gpsZCache getOrDefault [_key, -1e9];
    if (_c > -1e8) exitWith { _c };
    private _t = getTerrainHeightASL [_x, _y];
    private _is = lineIntersectsSurfaces [[_x, _y, _t + 80], [_x, _y, _t - 2],
                                          objNull, objNull, true, 1, "GEOM", "NONE"];
    private _z = if (_is isEqualTo []) then { _t } else { ((_is select 0) select 0) select 2 };
    if (_z < _t) then { _z = _t };   // never below ground
    AP_gpsZCache set [_key, _z];
    _z
}};
if (_this isEqualTo "boot") exitWith {};

switch (toLower _mode) do {case "start": {["stop"] call AP_fnc_gpsHud;
        (("AP_GpsHud" call BIS_fnc_rscLayer)) cutRsc ["AP_GpsHud", "PLAIN", 0.2, false];
        AP_gpsHudNext = 0;
        AP_gpsOffSince = -1;
        AP_gpsHudEF = addMissionEventHandler ["EachFrame", {
            if (diag_tickTime >= (missionNamespace getVariable ["AP_gpsHudNext", 0])) then {AP_gpsHudNext = diag_tickTime + 0.5;
                ["tick"] call AP_fnc_gpsHud;};}];
        // in-world guidance: faint cyan breadcrumbs + occasional chevrons hugging the road ahead,
        // local to this client only (drawIcon3D renders nothing for anyone else)
        // Route points are 2D, so drawing a breadcrumb at TERRAIN height puts it on the SEABED wherever
        // the route crosses the designer's bridge -- the deck is a mission object, not terrain, and
        // getTerrainHeightASL cannot see it. Probe downward for the first real surface (deck, road or
        // ground) instead. Cached per rounded metre because Draw3D runs every frame and raycasting ~30
        // crumbs per frame uncached is not free; bridges do not move, so the cache never goes stale.
        AP_gpsZCache = createHashMap;
        AP_gpsD3D = addMissionEventHandler ["Draw3D", {private _pts = missionNamespace getVariable ["AP_gpsRoutePts", []];
            if (_pts isEqualTo []) exitWith {};
            private _n = count _pts;
            private _i0 = (missionNamespace getVariable ["AP_gpsProgressIdx", 0]) min (_n - 1);
            private _acc = 0;
            private _next = 10;   // first crumb 10m along
            private _k = 0;
            for "_i" from (_i0 max 0) to (_n - 2) do {private _a = _pts select _i;
                private _b = _pts select (_i + 1);
                private _sl = (_a distance2D _b) max 0.01;
                while {_next <= _acc + _sl && {_acc < 240}} do {private _t = (_next - _acc) / _sl;
                    private _wx = (_a select 0) + ((_b select 0) - (_a select 0)) * _t;
                    private _wy = (_a select 1) + ((_b select 1) - (_a select 1)) * _t;
                    private _pos = [_wx, _wy, ([_wx, _wy] call AP_fnc_gpsSurfZ) + 0.9];
                    private _fade = (1 - _next / 260) max 0.15;
                    if (_k mod 3 isEqualTo 0) then {
                        // world-anchored chevron: arms built from overlapping dot icons (drawLine3D
                        // is locked to 1px) -- thick neon ">" that points down the road in real 3D
                        private _dx = ((_b select 0) - (_a select 0)) / _sl;
                        private _dy = ((_b select 1) - (_a select 1)) / _sl;
                        private _tx = _wx + _dx * 1.6; private _ty = _wy + _dy * 1.6;
                        private _col = [0.0, 0.83, 1.0, 0.9 * _fade]; {_x params ["_ex", "_ey"];   // wing endpoint of this arm
                            for "_s" from 0 to 13 do {   // 0.2m dot pitch = reads as one thick stroke
                                private _f2 = _s / 13;
                                private _px2 = _tx + (_ex - _tx) * _f2;
                                private _py2 = _ty + (_ey - _ty) * _f2;
                                drawIcon3D ["\A3\ui_f\data\map\markers\military\dot_CA.paa",
                                    _col, ASLToAGL [_px2, _py2, ([_px2, _py2] call AP_fnc_gpsSurfZ) + 0.9], 0.42, 0.42, 0, "", 0];};
                        } forEach [[_wx - _dx * 1.0 - _dy * 1.4, _wy - _dy * 1.0 + _dx * 1.4],
                            [_wx - _dx * 1.0 + _dy * 1.4, _wy - _dy * 1.0 - _dx * 1.4]];} else {
                        drawIcon3D ["\A3\ui_f\data\map\markers\military\dot_CA.paa",
                            [0.0, 0.83, 1.0, 0.45 * _fade], ASLToAGL _pos, 0.55, 0.55, 0, "", 0];};
                    _k = _k + 1;
                    _next = _next + 16;};
                _acc = _acc + _sl;
                if (_acc >= 240) exitWith {};};}];};
    case "stop": {if (!isNil "AP_gpsHudEF") then {removeMissionEventHandler ["EachFrame", AP_gpsHudEF];
            AP_gpsHudEF = nil;};
        if (!isNil "AP_gpsD3D") then {removeMissionEventHandler ["Draw3D", AP_gpsD3D];
            AP_gpsD3D = nil;};
        (("AP_GpsHud" call BIS_fnc_rscLayer)) cutText ["", "PLAIN", 0.3];};
    case "tick": {private _pts = missionNamespace getVariable ["AP_gpsRoutePts", []];
        if (_pts isEqualTo []) exitWith { ["stop"] call AP_fnc_gpsHud; };
        private _n = count _pts;
        private _me = getPosATL player;

        // progress = nearest route vertex, searched in a window around last progress so a
        // self-crossing route can't teleport you forward; the draw EH consumes this to trim
        // the already-driven tail (no more mile-long leg back to the original start)
        private _prevIdx = (missionNamespace getVariable ["AP_gpsProgressIdx", 0]) min (_n - 1);
        private _best = _prevIdx;
        private _bd = 1e12;
        for "_i" from (0 max (_prevIdx - 25)) to ((_n - 1) min (_prevIdx + 120)) do {private _d = _me distance2D (_pts select _i);
            if (_d < _bd) then { _bd = _d; _best = _i; };};
        AP_gpsProgressIdx = _best;

        private _remain = _bd;
        for "_i" from _best to (_n - 2) do {_remain = _remain + ((_pts select _i) distance2D (_pts select (_i + 1)));};

        private _dest = missionNamespace getVariable ["AP_gpsDest", []];
        if (_dest isNotEqualTo [] && {(_me distance2D _dest) < 40 || {_remain < 40}}) exitWith {
            ["<t color='#00d4ff'>GPS:</t> you have arrived.", "basic"] spawn AP_fnc_handleMessage;
            AP_gpsRoutePts = [];
            AP_gpsDest = [];
            ["stop"] call AP_fnc_gpsHud;};

        // off-route -> recalc fast ("set" reinstalls this driver, so state resets cleanly)
        if (_bd > 60) then {if ((missionNamespace getVariable ["AP_gpsOffSince", -1]) < 0) then { AP_gpsOffSince = time; };
            if (time - AP_gpsOffSince > 2.5) exitWith {AP_gpsOffSince = -1;
                ["<t color='#00d4ff'>GPS:</t> recalculating...", "basic"] spawn AP_fnc_handleMessage;
                ["set", _dest] call AP_fnc_gps;};} else { AP_gpsOffSince = -1; };

        // next turn: first 22deg+ bearing change ahead (severity classified from the angle)
        private _turnDist = -1;
        private _turnDir = 0;
        private _acc = _bd;
        for "_i" from (_best max 1) to (_n - 2) do {private _p0 = _pts select (_i - 1);
            private _p1 = _pts select _i;
            private _p2 = _pts select (_i + 1);
            _acc = _acc + (_p0 distance2D _p1);
            if (_acc > 1200) exitWith {};
            private _b1 = ((_p1 select 0) - (_p0 select 0)) atan2 ((_p1 select 1) - (_p0 select 1));
            private _b2 = ((_p2 select 0) - (_p1 select 0)) atan2 ((_p2 select 1) - (_p1 select 1));
            private _dv = ((_b2 - _b1 + 540) mod 360) - 180;
            if (abs _dv > 22 && {_acc > 15}) exitWith {_turnDist = _acc;
                _turnDir = _dv;};};

        // U-turn: the route continues BEHIND you (dead-end starts, wrong-way driving)
        private _uturn = false;
        if (_bd < 60 && {_best < _n - 2}) then {private _tgt = _pts select ((_best + 2) min (_n - 1));
            private _acc2 = 0;
            for "_i" from _best to ((_n - 2) min (_best + 20)) do {   // aim ~25m ahead
                _acc2 = _acc2 + ((_pts select _i) distance2D (_pts select (_i + 1)));
                if (_acc2 > 25) exitWith { _tgt = _pts select (_i + 1); };};
            private _brg = ((_tgt select 0) - (_me select 0)) atan2 ((_tgt select 1) - (_me select 1));
            private _dd = ((_brg - getDir vehicle player + 540) mod 360) - 180;
            _uturn = abs _dd > 120;};

        private _kmTxt = if (_remain >= 1000) then { format ["%1 km", (_remain / 1000) toFixed 1] } else { format ["%1 m", round _remain] };
        private _line = if (_uturn) then {
            "<t size='1.2' color='#00d4ff'>((</t>  <t size='1.1'>MAKE A U-TURN</t>"} else { if (_turnDist < 0) then {
            "<t size='1.2' color='#00d4ff'>/\</t>  <t size='1.1'>FOLLOW THE ROAD</t>"} else {
            // severity bands: 22-45 bear, 45-110 turn, 110+ sharp
            private _mag = abs _turnDir;
            private _sev = if (_mag < 45) then { 0 } else { if (_mag < 110) then { 1 } else { 2 } };
            private _verb = ["BEAR", "TURN", "SHARP"] select _sev;
            private _way = if (_turnDir < 0) then {
                format ["<t size='1.2' color='#00d4ff'>%1</t>  <t size='1.1'>%2 LEFT</t>", ["&lt;", "&lt;&lt;", "&lt;&lt;&lt;"] select _sev, _verb]
            } else {
                format ["<t size='1.1'>%2 RIGHT</t>  <t size='1.2' color='#00d4ff'>%1</t>", ["&gt;", "&gt;&gt;", "&gt;&gt;&gt;"] select _sev, _verb]
            };
            private _dTxt = if (_turnDist >= 1000) then { format ["%1 km", (_turnDist / 1000) toFixed 1] } else { format ["%1 m", 10 * ceil (_turnDist / 10)] };
            format ["%1  <t color='#9fb2c2'>in %2</t>", _way, _dTxt]} };
        private _ctrl = (uiNamespace getVariable ["AP_GpsHud", displayNull]) displayCtrl 91510;
        if (!isNull _ctrl) then {
            _ctrl ctrlSetStructuredText parseText format ["%1<br/><t size='0.85' color='#7c8a98'>%2 to destination</t>", _line, _kmTxt];};
    };};
