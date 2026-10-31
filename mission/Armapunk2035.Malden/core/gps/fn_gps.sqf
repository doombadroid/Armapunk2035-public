/*
    AP_fnc_gps  (LooneyBin, owner 2026-07-12)
    GPS routing UI -- phase 2: ALT+Click the map to plot a road route there; ALT+Click near the
    destination (or in the same spot) to clear. Route draws on the main map (neon cyan, Night City
    palette) with a live leg from the player to the route start. Search + HUD come next phases.

    Modes:
        ["hook"]         once per client (initPlayerLocal): installs the ALT+MapSingleClick handler
        ["set", _pos]    compute + display route from player to _pos
        ["clear"]        drop the route
*/
// Night City neon: cyan tube + hot core. drawLine is hard-locked to 1px and drawPolygon's color
// channel order is untrustworthy, so the tube is a chain of dot icons interpolated ALONG the route
// at 8px spacing (constant screen width at any zoom), view-culled per frame.
#define GPS_GLOW [0.00, 0.83, 1.00, 0.30]
#define GPS_BODY [0.10, 0.90, 1.00, 0.80]
#define GPS_CORE [0.75, 0.98, 1.00, 1.00]
params [["_mode", "", [""]], ["_a1", []]];
if (!hasInterface) exitWith {};

private _fnEnsureDraw = {if (!isNil "AP_gpsDrawEH") exitWith {};
    private _map = (findDisplay 12) displayCtrl 51;
    if (isNull _map) exitWith {};
    AP_gpsDrawEH = _map ctrlAddEventHandler ["Draw", {params ["_ctrl"];
        private _pts = missionNamespace getVariable ["AP_gpsRoutePts", []];
        if (_pts isEqualTo []) exitWith {};
        // world metres per screen pixel -> everything below is sized in constant SCREEN px
        private _wpu = ((_ctrl ctrlMapScreenToWorld [0, 0]) distance2D (_ctrl ctrlMapScreenToWorld [0.01, 0])) * 100;
        private _px = (_wpu / (getResolution select 0)) max 0.01;
        private _me = getPosASLVisual player;
        // trim the already-driven tail (progress index maintained by the HUD tick) --
        // the live leg connects to where you ARE on the route, not the original start
        private _start = (missionNamespace getVariable ["AP_gpsProgressIdx", 0]) min (count _pts - 1);
        private _path = [[_me select 0, _me select 1]] + (_pts select [_start, count _pts - _start]);
        // visible-world rect (+margin) -- offscreen route costs nothing at any zoom
        private _tl = _ctrl ctrlMapScreenToWorld [0, 0];
        private _br = _ctrl ctrlMapScreenToWorld [1, 1];
        private _pad = 40 * _px;
        private _minX = ((_tl select 0) min (_br select 0)) - _pad;
        private _maxX = ((_tl select 0) max (_br select 0)) + _pad;
        private _minY = ((_tl select 1) min (_br select 1)) - _pad;
        private _maxY = ((_tl select 1) max (_br select 1)) + _pad;
        // neon tube = dot chain interpolated ALONG the segments (not just vertices), 8px spacing
        private _step = 8 * _px;
        private _carry = 0;
        for "_i" from 0 to (count _path - 2) do {private _a = _path select _i;
            private _b = _path select (_i + 1);
            private _ax = _a select 0; private _ay = _a select 1;
            private _bx = _b select 0; private _by = _b select 1;
            private _dx = _bx - _ax; private _dy = _by - _ay;
            private _l = sqrt (_dx * _dx + _dy * _dy) max 0.01;
            if ((_ax < _minX && _bx < _minX) || {_ax > _maxX && _bx > _maxX}
                || {_ay < _minY && _by < _minY} || {_ay > _maxY && _by > _maxY}) then {
                _carry = 0;   // fully offscreen -- skip, restart spacing at re-entry
            } else {private _d = _carry;
                while {_d < _l} do {private _t = _d / _l;
                    _ctrl drawIcon ["\A3\ui_f\data\map\markers\military\dot_CA.paa",
                        GPS_BODY, [_ax + _dx * _t, _ay + _dy * _t], 22, 22, 0, "", 0];
                    _d = _d + _step;};
                _carry = _d - _l;};};
        for "_i" from 0 to (count _path - 2) do {                // 1px hot core, full route
            _ctrl drawLine [_path select _i, _path select (_i + 1), GPS_CORE];};
        _ctrl drawIcon ["\A3\ui_f\data\map\markers\military\objective_ca.paa",
            GPS_BODY, missionNamespace getVariable ["AP_gpsDest", [0, 0]], 27, 27, 0, "", 1];}];};

switch (toLower _mode) do {case "hook": {if (!isNil "AP_gpsClickEH") exitWith {};
        [] spawn {   // G on the map -> destination search (map display exists only after first open)
            waitUntil { uiSleep 1; !isNull findDisplay 12 };
            (findDisplay 12) displayAddEventHandler ["KeyDown", {params ["", "_key"];
                if (_key isEqualTo 34 && {visibleMap} && {isNull findDisplay 91500}) then {if ("ItemGPS" in assignedItems player) then {
                        ["open"] call AP_fnc_gpsSearch;} else {
                        ["<t color='#00d4ff'>GPS:</t> you need a GPS in your assigned items.", "basic"] spawn AP_fnc_handleMessage;};
                    true} else { false };}];};
        addMissionEventHandler ["EntityKilled", {   // dead men need no directions
            params ["_unit"];
            if (_unit isEqualTo player && {(missionNamespace getVariable ["AP_gpsRoutePts", []]) isNotEqualTo []}) then {
                AP_gpsRoutePts = [];
                AP_gpsDest = [];
                ["stop"] call AP_fnc_gpsHud;};}];
        AP_gpsClickEH = addMissionEventHandler ["MapSingleClick", {params ["_units", "_pos", "_alt", "_shift"];
            if (!_alt || _shift) exitWith { false };
            private _dest = missionNamespace getVariable ["AP_gpsDest", []];
            if (_dest isNotEqualTo [] && {_pos distance2D _dest < 200}) then {["clear"] call AP_fnc_gps;} else {
                ["set", _pos] call AP_fnc_gps;};
            true}];};
    case "set": {if (_a1 isEqualTo []) exitWith {};
        private _res = [];
        private _ms = 0;
        isNil {   // unscheduled: one short hitch beats a 3ms-sliced crawl
            private _t0 = diag_tickTime;
            _res = [getPosATL player, _a1] call AP_fnc_routeFind;
            _ms = (diag_tickTime - _t0) * 1000;};
        if (_res isEqualTo [] || {(_res select 0) isEqualTo []}) exitWith {
            ["GPS: no road route found to there.", "basic"] spawn AP_fnc_handleMessage;};
        _res params ["_pts", "_len"];
        AP_gpsProgressIdx = 0;
        AP_gpsRoutePts = _pts;
        AP_gpsDest = _a1;
        call _fnEnsureDraw;
        ["start"] call AP_fnc_gpsHud;   // turn-by-turn banner (EachFrame driver)
        diag_log format ["[LooneyBin][gps] route: %1 pts, %2m, %3ms", count _pts, round _len, _ms toFixed 0];
        [format ["<t color='#00d4ff'>GPS:</t> route plotted -- %1 km by road. ALT+Click near the flag to clear.",
            (_len / 1000) toFixed 1], "basic"] spawn AP_fnc_handleMessage;};
    case "clear": {AP_gpsRoutePts = [];
        AP_gpsDest = [];
        ["stop"] call AP_fnc_gpsHud;
        ["<t color='#00d4ff'>GPS:</t> route cleared.", "basic"] spawn AP_fnc_handleMessage;};};
