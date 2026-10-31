// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckSeq.sqf
    LooneyBin 2026-07-18: SEQUENCE BREACH minigame (Cyberdeck, light targets).
    Baked deck art (dialog cyberdeck_seq, backdrop.paa) + live hex cells / 4x4 grid / radar flipbook / daemon.
    Match the BUFFER by clicking the matching code in the highlighted row before the trace drains.
    BLOCKING -- returns: 1 = breach, 0 = trace/timeout fail, -1 = aborted.
    Layout coords mirror scratchpad/build_cyberdeck_art.py (regenerate both together).
*/
params [["_bufLen", 4]];   // the buffer length IS the difficulty: 4 default, 6 basic, 10 medium/asylum, 12 advanced
disableSerialization;
// owner 2026-07-20: Breach Kit consumable -- if armed, auto-solve this breach (skip the minigame) and spend the charge.
if (AP_breachKitArmed) exitWith {AP_breachKitArmed = false;
    ["<t color='#c9e21a'>BREACH KIT</t> -- sequence auto-solved.", "basic"] spawn AP_fnc_handleMessage;
    1};

private _cols = 4;
private _rows = 4;
_bufLen = _bufLen max 3;
_bufLen = _bufLen max 3 min 12;
private _timeLimit = round (_bufLen * 5 * (2/3));   // ~5s per code base, cut by 1/3 (owner 2026-07-21)
if (1 in (player getVariable ["AP_cdMods", []])) then { _timeLimit = _timeLimit + 4; };   // Overclock Module: +time

private _codes = ["1C","55","BD","E9","7A","FF","0A","3D","C4","9B"];
private _grid = [];
for "_i" from 0 to ((_cols * _rows) - 1) do { _grid pushBack (selectRandom _codes); };
private _allCols = []; for "_c" from 0 to (_cols - 1) do { _allCols pushBack _c; };

// CRITICAL: plant each buffer code into its ACTIVE row (idx % rows) in a DISTINCT column, so the required
// code is ALWAYS clickable in that row. A buffer longer than 4 wraps rows -- two codes in the same row must
// NEVER share a cell (the later plant would overwrite the earlier -> that code vanishes -> unhackable).
private _buffer = [];
private _usedCols = createHashMap;
for "_r" from 0 to (_bufLen - 1) do {private _row = _r % _rows;
    private _taken = _usedCols getOrDefault [_row, []];
    private _avail = _allCols - _taken;
    if (_avail isEqualTo []) then { _avail = +_allCols; };   // safety: rows are 4 wide, <=3 codes/row -> never hit
    private _col = selectRandom _avail;
    _taken pushBack _col;
    _usedCols set [_row, _taken];
    private _code = selectRandom _codes;
    _grid set [(_row * _cols) + _col, _code];
    _buffer pushBack _code;};
// belt-and-suspenders: guarantee every buffer code is findable in its row (force-place if somehow missing)
{private _row = _forEachIndex % _rows;
    private _inRow = false;
    for "_c" from 0 to (_cols - 1) do { if ((_grid select ((_row * _cols) + _c)) isEqualTo _x) exitWith { _inRow = true; }; };
    if (!_inRow) then { _grid set [(_row * _cols) + (floor random _cols), _x]; };} forEach _buffer;

// ---- HTML SURFACE (2026-08-14) ------------------------------------------------
// The grid and the buffer above are the game; the dialog below was only ever the
// paint. ui\html\breach.html draws the same run in CSS -- and takes 2.67 MB of
// baked backdrop, a 16-frame radar flipbook and a daemon sprite out of the PBO
// with it. The contract to the nine callers is untouched: this still BLOCKS and
// still answers 1 / 0 / -1.
//
// AP_webBreach = false falls back to the native dialog until the port has had a
// playtest; delete the flag and cyberdeck_seq.hpp together once it has.
AP_cbWebCfg = createHashMapFromArray [
    ["grid",   _grid],
    ["buffer", _buffer],
    ["cols",   _cols],
    ["rows",   _rows],
    ["time",   _timeLimit]
];
AP_breachResult = nil;
if (!createDialog "AP_web_breach") exitWith { -1 };
// The page owns the clock, so the wait is bounded by it plus the verdict hold.
// A player who closes the dialog gets the abort the callers already handle.
waitUntil { !isNil "AP_breachResult" || { isNull (findDisplay 937700) } };
private _r = missionNamespace getVariable ["AP_breachResult", -1];
AP_breachResult = nil;
waitUntil { isNull (findDisplay 937700) };
_r
