/*
    AP_fnc_routeFind  (LooneyBin, owner 2026-07-12)
    A* over the road graph. Pure computation, no UI, runs anywhere (client GPS, server taxi later).

    In:  [fromPos, toPos]   any position-ish arrays ([x,y] or [x,y,z])
    Out: [pts, totalLen]    pts = world-space polyline [[x,y],...]; [] on failure/no path.

    Start/dest snap to the nearest polyline VERTEX on any edge (300m spatial hash, ring search) --
    NOT to the nearest junction. The route enters the graph via BOTH endpoints of that edge
    (multi-source / multi-target A*), so it starts on the road beside you and exits exactly at the
    destination's road, with partial-edge slices stitched onto the A* spine. Costs are the
    road-class-weighted values from gpsInit (highway preference); displayed length is rebuilt from
    the final polyline.

    Binary heap open list (parallel arrays _hf/_hn).
*/
#define GPS_CELL 300
if !(call AP_fnc_gpsInit) exitWith { [] };
params [["_from", [0, 0], [[]]], ["_to", [0, 0], [[]]]];

private _nodes = AP_gpsNodes;
private _adj = AP_gpsAdj;
private _edges = AP_gpsEdges;
private _cells = AP_gpsCells;
private _n = count _nodes;

// nearest polyline vertex to a position -> [edgeIdx, vertIdx] (expanding ring search)
private _fnSnap = {private _p = _this;
    private _cx = floor ((_p select 0) / GPS_CELL);
    private _cy = floor ((_p select 1) / GPS_CELL);
    private _best = [];
    private _bd = 1e12;
    private _r = 0;
    private _hit = -1;
    while {_r < 9 && {_hit < 0 || _r <= _hit + 1}} do {   // one extra ring after the first hit
        for "_dx" from -_r to _r do {for "_dy" from -_r to _r do {
                if (abs _dx isEqualTo _r || {abs _dy isEqualTo _r}) then {   // ring shell only
                    {_x params ["_ei", "_vi"];
                        private _d = _p distance2D (((_edges select _ei) select 5) select _vi);
                        if (_d < _bd) then { _bd = _d; _best = [_ei, _vi]; if (_hit < 0) then { _hit = _r; }; };
                    } forEach (_cells getOrDefault [format ["%1_%2", _cx + _dx, _cy + _dy], []]);};};};
        _r = _r + 1;};
    _best};
private _s = _from call _fnSnap;
private _t = _to call _fnSnap;
if (_s isEqualTo [] || {_t isEqualTo []}) exitWith { [] };
_s params ["_sEi", "_sVi"];
_t params ["_tEi", "_tVi"];

// polyline slice + its length (inclusive indices, auto-direction)
private _fnSlice = {params ["_poly", "_i0", "_i1"];
    private _out = [];
    if (_i0 <= _i1) then {for "_i" from _i0 to _i1 do { _out pushBack (_poly select _i); };} else {
        for "_i" from _i0 to _i1 step -1 do { _out pushBack (_poly select _i); };};
    _out};
private _fnPolyLen = {private _sum = 0;
    for "_i" from 0 to (count _this - 2) do {_sum = _sum + ((_this select _i) distance2D (_this select (_i + 1)));};
    _sum};

// both on the SAME edge -> just slice it
if (_sEi isEqualTo _tEi) exitWith {private _pts = [((_edges select _sEi) select 5), _sVi, _tVi] call _fnSlice;
    if (count _pts < 2) then { _pts = [((_edges select _sEi) select 5) select _sVi]; };
    [_pts, _pts call _fnPolyLen]};

private _sPoly = (_edges select _sEi) select 5;
private _tPoly = (_edges select _tEi) select 5;
private _sEdge = _edges select _sEi;
private _tEdge = _edges select _tEi;

// entry/exit costs = true polyline distance from the snapped vertex to each edge end
private _sToA = ([_sPoly, _sVi, 0] call _fnSlice) call _fnPolyLen;
private _sToB = ([_sPoly, _sVi, count _sPoly - 1] call _fnSlice) call _fnPolyLen;
private _tToA = ([_tPoly, _tVi, 0] call _fnSlice) call _fnPolyLen;
private _tToB = ([_tPoly, _tVi, count _tPoly - 1] call _fnSlice) call _fnPolyLen;

private _tp = _to;
private _dist = []; _dist resize _n;
private _prev = []; _prev resize _n;      // [cameFromNode, viaEdgeIdx]; [-1,-1] = source seed
private _closed = []; _closed resize [_n, false];
private _hf = []; private _hn = [];

private _fnPush = {params ["_f", "_node"];
    _hf pushBack _f; _hn pushBack _node;
    private _i = count _hf - 1;
    while {_i > 0} do {private _par = floor ((_i - 1) / 2);
        if ((_hf select _par) <= (_hf select _i)) exitWith {};
        private _tmp = _hf select _par; _hf set [_par, _hf select _i]; _hf set [_i, _tmp];
        _tmp = _hn select _par; _hn set [_par, _hn select _i]; _hn set [_i, _tmp];
        _i = _par;};};
private _fnPop = {private _node = _hn select 0;
    private _last = count _hf - 1;
    _hf set [0, _hf select _last]; _hn set [0, _hn select _last];
    _hf resize _last; _hn resize _last;
    private _i = 0;
    while {true} do {private _l = 2 * _i + 1;
        private _r = _l + 1;
        private _m = _i;
        if (_l < _last && {(_hf select _l) < (_hf select _m)}) then { _m = _l; };
        if (_r < _last && {(_hf select _r) < (_hf select _m)}) then { _m = _r; };
        if (_m isEqualTo _i) exitWith {};
        private _tmp = _hf select _m; _hf set [_m, _hf select _i]; _hf set [_i, _tmp];
        _tmp = _hn select _m; _hn set [_m, _hn select _i]; _hn set [_i, _tmp];
        _i = _m;};
    _node};

// Seed the ends of the start edge. Normally BOTH (skip a seed if that whole half-edge is the worse
// duplicate), but a start point sitting on a ONE-WAY edge can only leave it downstream -- seeding the
// forbidden end would plot a route that sets off against the flow, which on the Malden bridge means
// starting down the opposite carriageway.
private _sOne = _sEdge param [6, 0];
private _seeds = [];
if (_sOne != -1) then { _seeds pushBack [_sEdge select 1, _sToB]; };   // may run a->b: leave via b
if (_sOne != 1) then { _seeds pushBack [_sEdge select 0, _sToA]; };    // may run b->a: leave via a
{_x params ["_node", "_cost"];
    private _od = _dist select _node;
    if (isNil "_od" || {_cost < _od}) then {_dist set [_node, _cost];
        _prev set [_node, [-1, -1]];
        [_cost + ((_nodes select _node) distance2D _tp), _node] call _fnPush;};
} forEach _seeds;

private _tA = _tEdge select 0;
private _tB = _tEdge select 1;
// ...and the same restriction at the far end: a destination sitting on a one-way edge can only be
// reached by entering that edge at its UPSTREAM node, so the other endpoint is not a valid exit.
private _tOne = _tEdge param [6, 0];
private _tAok = (_tOne != -1);
private _tBok = (_tOne != 1);
while {count _hn > 0} do {private _c = call _fnPop;
    if ((!_tAok || {_closed select _tA}) && {!_tBok || {_closed select _tB}}) exitWith {};   // exits settled
    if !(_closed select _c) then {_closed set [_c, true];
        private _dc = _dist select _c; {_x params ["_nb", "_cost", "_ei"];
            if !(_closed select _nb) then {private _nd = _dc + _cost;
                private _od = _dist select _nb;
                if (isNil "_od" || {_nd < _od}) then {_dist set [_nb, _nd];
                    _prev set [_nb, [_c, _ei]];
                    [_nd + ((_nodes select _nb) distance2D _tp), _nb] call _fnPush;};};} forEach (_adj select _c);};};

private _dA = _dist select _tA;
private _dB = _dist select _tB;
private _viaA = if (!_tAok || {isNil "_dA"}) then { 1e12 } else { _dA + _tToA };
private _viaB = if (!_tBok || {isNil "_dB"}) then { 1e12 } else { _dB + _tToB };
if (_viaA >= 1e12 && {_viaB >= 1e12}) exitWith { [] };
private _exit = [_tA, _tB] select (_viaB < _viaA);

// spine: walk prev back from the chosen dest-edge endpoint to whichever source seed it reached
private _spine = [];
private _cur = _exit;
while {true} do {(_prev select _cur) params ["_from2", "_ei"];
    if (_ei < 0) exitWith {};   // hit a source seed
    private _poly = (_edges select _ei) select 5;
    private _oriented = +_poly;
    if (((_oriented select 0) distance2D (_nodes select _from2)) > ((_oriented select 0) distance2D (_nodes select _cur))) then {
        reverse _oriented;   // make it run _from2 -> _cur
    };
    reverse _oriented;       // we're walking backwards: append as _cur -> _from2
    if (_spine isNotEqualTo []) then { _oriented deleteAt 0; };
    _spine append _oriented;
    _cur = _from2;};
reverse _spine;              // now source-seed -> ... -> _exit

// start partial: snapped vertex -> whichever source endpoint the spine begins at
private _entry = _cur;       // source seed node the walk ended on
private _startSeg = if (_entry isEqualTo (_sEdge select 0)) then {[_sPoly, _sVi, 0] call _fnSlice} else {
    [_sPoly, _sVi, count _sPoly - 1] call _fnSlice};
// dest partial: chosen dest endpoint -> snapped dest vertex
private _endSeg = if (_exit isEqualTo _tA) then {[_tPoly, 0, _tVi] call _fnSlice} else {[_tPoly, count _tPoly - 1, _tVi] call _fnSlice};

private _pts = _startSeg;
if (_spine isNotEqualTo []) then {if (_pts isNotEqualTo []) then { _spine deleteAt 0; };
    _pts append _spine;};
if (_endSeg isNotEqualTo []) then {_endSeg deleteAt 0;
    _pts append _endSeg;};
if (count _pts < 2) exitWith { [] };
[_pts, _pts call _fnPolyLen]
