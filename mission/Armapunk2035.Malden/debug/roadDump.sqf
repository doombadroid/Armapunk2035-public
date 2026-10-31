/*
    debug/roadDump.sqf  (LooneyBin, owner 2026-07-12)
    ROAD GRAPH DUMP -- one-shot, LoonyDev only. Sweeps the whole terrain, dumps every road segment
    (endpoints, width, type, bridge flag, connectivity) plus every CfgWorlds Names POI to the RPT as
    -ROADDUMP- / -NAMEDUMP- lines. tools/roadgraph_build.py parses those into the routing graph the
    GPS / website / autopilot stack rides on.

    Runs unscheduled in one giant isNil{} block -- freezes the dev server for a minute, which is fine:
    nobody lives there. NEVER wire this into a live boot path.
*/
if (!isServer) exitWith {};
[] spawn {uiSleep 25;   // let the mission finish booting first
    diag_log format ["-ROADDUMP- START world=%1 size=%2", worldName, worldSize];
    private _t0 = diag_tickTime;
    isNil {private _cell = 500;
        private _rad = 360;                       // covers the 500m cell diagonal (354) with margin
        private _seen = createHashMap;            // "x_y" -> true
        private _fnKey = {private _p = getPosWorld _this;
            format ["%1_%2", round (_p select 0), round (_p select 1)]};
        private _total = 0;
        private _ws = worldSize;
        private _row = 0;
        for [{private _cx = _cell / 2}, {_cx < _ws}, {_cx = _cx + _cell}] do {
            for [{private _cy = _cell / 2}, {_cy < _ws}, {_cy = _cy + _cell}] do {{private _road = _x;
                    private _k = _road call _fnKey;
                    if !(_k in _seen) then {_seen set [_k, true];
                        // getRoadInfo: [type, width, isPedestrian, texture, textureEnd, material, begPos, endPos, isBridge]
                        private _i = getRoadInfo _road;
                        private _conn = (roadsConnectedTo [_road, true]) apply { _x call _fnKey };
                        private _beg = _i param [6, [0,0,0]];
                        private _end = _i param [7, [0,0,0]];
                        diag_log format ["-ROADDUMP- [""%1"",""%2"",%3,%4,%5,[%6,%7],[%8,%9],[""%10""]]",
                            _k, _i param [0, ""], _i param [1, 0], [0, 1] select (_i param [2, false]), [0, 1] select (_i param [8, false]),
                            (_beg select 0) toFixed 1, (_beg select 1) toFixed 1, (_end select 0) toFixed 1, (_end select 1) toFixed 1,
                            _conn joinString ""","""];
                        _total = _total + 1;};} forEach ([_cx, _cy] nearRoads _rad);};
            _row = _row + 1;
            if (_row mod 10 isEqualTo 0) then {
                diag_log format ["-ROADDUMP- progress row %1/%2, %3 segments", _row, ceil (_ws / _cell), _total];};};
        diag_log format ["-ROADDUMP- ROADS DONE %1 segments in %2s", _total, (diag_tickTime - _t0) toFixed 1];
        // CfgWorlds Names -- towns, capitals, hills, POIs: the search index seed
        {diag_log format ["-NAMEDUMP- [""%1"",""%2"",""%3"",%4,%5,%6]", configName _x, getText (_x >> "name"), getText (_x >> "type"),
                (getArray (_x >> "position")) param [0, 0], (getArray (_x >> "position")) param [1, 0], getNumber (_x >> "radiusA")];
        } forEach configProperties [configFile >> "CfgWorlds" >> worldName >> "Names", "isClass _x", true];};
    diag_log format ["-ROADDUMP- END elapsed=%1s", (diag_tickTime - _t0) toFixed 1];};
