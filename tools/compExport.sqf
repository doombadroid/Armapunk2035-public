// LooneyBin :: COMPOSITION EXPORT -- selected 3DEN objects -> a complete compositions/zone_<name>.sqf
// on the clipboard (and RPT, between AP_COMP_EXPORT markers).
//
//   1) open the mission in the 3DEN editor
//   2) SELECT the composition's objects (drag-box or the whole 'comp_<name>' layer if you imported one)
//   3) edit _zoneName below (and _radius / flags if you care), then Tools -> Debug Console:
//        if you copied this file into the editor mission folder:
//            call compile preprocessFileLineNumbers "compExport.sqf"
//        or just paste this whole file's text into the console and LOCAL EXEC.
//   4) paste the clipboard into mission/Armapunk2035.Malden/compositions/zone_<name>.sqf
//      and add that path to compositions/zones.sqf. Done -- the loader streams it.
//   5) if you imported a comp_* layer for this edit: DELETE the layer before saving the mission,
//      or Eden bakes a second copy of the composition into mission.sqm.
//
// TRANSFORMS: getPosWorld + vectorDir/vectorUp -- the ENGINE's raw world frame. No ATL/ASL conversion,
// no terrain math, so land-vs-sea elevation can never skew a piece and full tilt/bank round-trips.

if (!is3DEN) exitWith { systemChat "compExport: open the mission in the 3DEN editor, run from its Debug Console."; };

// -- knobs -------------------------------------------------------------------------------------
private _zoneName   = "my_zone";      // <-- EDIT: file becomes compositions/zone_<this>.sqf
private _radius     = -1;             // -1 = auto (max spread + 60m, rounded up to 10); <= 0 in the FILE means always-on
                                      // the loader streams zones at the reference distances derived from this:
                                      // r<=200 -> IN r+400/OUT r+550; r>200 -> IN r+1000/OUT r+1250
private _enabled    = true;
private _serverSide = false;          // true only if server-side logic must collide with / find the pieces
private _exclude    = ["Logic", "Module", "SoundSource", "EmptyDetector"];   // class PREFIX skip list
private _needSim    = [];             // classes that need working doors/anim -> exported with simple=false
// ----------------------------------------------------------------------------------------------

private _sel = get3DENSelected "object";
if (_sel isEqualTo []) exitWith { systemChat "compExport: select the composition's objects first."; };

private _fmtN = { params ["_v", ["_d", 3]]; _v toFixed _d };   // fixed decimals, never scientific notation

private _rows = [];
private _cx = 0; private _cy = 0;
{
    private _cls = typeOf _x;
    if ((_exclude findIf { (_cls find _x) isEqualTo 0 }) isEqualTo -1 && {_cls isNotEqualTo ""}) then {
        private _pw = getPosWorld _x;
        private _vd = vectorDir _x;
        private _vu = vectorUp _x;
        _rows pushBack [_cls, _pw, _vd, _vu, !(_cls in _needSim)];
        _cx = _cx + (_pw select 0); _cy = _cy + (_pw select 1);
    };
} forEach _sel;
if (_rows isEqualTo []) exitWith { systemChat "compExport: everything selected was excluded (logics/modules)."; };

_cx = _cx / count _rows; _cy = _cy / count _rows;
if (_radius < 0) then {
    private _max = 0;
    { private _d = [_cx, _cy] distance2D (_x select 1); if (_d > _max) then { _max = _d; }; } forEach _rows;
    _radius = 10 * ceil ((_max + 60) / 10);
};

private _q  = toString [34];        // "
private _bs = toString [92];        // backslash
private _nl = toString [10];
private _ss = toString [47, 47];    // "//" -- NEVER write // inside a string literal: the Arma preprocessor
                                    // strips comments EVEN INSIDE STRINGS, mangling the rest of the line
                                    // ("invalid number in expression" when this file is compiled).
private _out = format ["%1 compositions%2zone_%3.sqf -- exported from 3DEN (%4 objects)%5[%6    %7%3%7, [%8, %9], %10, %11, %12,%13    [",
    _ss, _bs, _zoneName, count _rows, _nl, _nl, _q,
    [_cx] call _fmtN, [_cy] call _fmtN, [_radius, 0] call _fmtN, str _enabled, str _serverSide, _nl];
{
    _x params ["_cls", "_pw", "_vd", "_vu", "_simple"];
    _out = _out + format ["%1        [%2%3%2, [%4, %5, %6], [%7, %8, %9], [%10, %11, %12]%13],",
        _nl, _q, _cls,
        [_pw select 0] call _fmtN, [_pw select 1] call _fmtN, [_pw select 2] call _fmtN,
        [_vd select 0, 4] call _fmtN, [_vd select 1, 4] call _fmtN, [_vd select 2, 4] call _fmtN,
        [_vu select 0, 4] call _fmtN, [_vu select 1, 4] call _fmtN, [_vu select 2, 4] call _fmtN,
        if (_simple) then { "" } else { ", false" }];
} forEach _rows;
_out = (_out select [0, (count _out) - 1]) + _nl + "    ]" + _nl + "]" + _nl;   // strip the trailing comma

copyToClipboard _out;
diag_log "===AP_COMP_EXPORT_BEGIN===";
diag_log _out;
diag_log "===AP_COMP_EXPORT_END===";
systemChat format ["compExport: zone '%1' -> clipboard (%2 objects, centre [%3,%4], r=%5). Paste into compositions/zone_%1.sqf.",
    _zoneName, count _rows, round _cx, round _cy, _radius];
