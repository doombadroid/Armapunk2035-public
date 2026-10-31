// LooneyBin :: selected 3DEN objects -> allLocalMapEntities array entries. THE ENGINE GIVES HEIGHTS
// (getPosATL), so no offline terrain math. Output: clipboard + RPT (between markers).
//
// In the 3DEN editor: select the objects you want, then Tools -> Debug Console:
//        call compile preprocessFileLineNumbers "edenExport.sqf"
// Then:  wl-paste > /tmp/eden_export.sqf      (or just say "logged" and I read the RPT)
// Apply: python3 tools/eden_region.py apply /tmp/eden_export.sqf
//
// RULE: select the WHOLE 'ArrayImport' layer (+ anything you added) before exporting -- an
//       imported object you don't re-export is treated as deleted.
// NOTE: in object Init fields use  _this  (not  this ) -- the spawn array runs each init with _this.

if (!is3DEN) exitWith { systemChat "edenExport: open the mission in the 3DEN editor, run from its Debug Console."; };

private _sel = get3DENSelected "object";
if (_sel isEqualTo []) exitWith { systemChat "edenExport: select some objects first."; };

private _q = toString [34];                                         // a double-quote char
private _out = "";
diag_log "===AP_EDEN_EXPORT_BEGIN===";
{
    private _o = _x;
    private _cls = typeOf _o;
    private _p = getPosATL _o;
    private _d = vectorDir _o;
    private _u = vectorUp _o;
    private _init = _o get3DENAttribute "init";
    if (_init isEqualType []) then { _init = _init param [0,""] };
    if (!(_init isEqualType "")) then { _init = "" };
    private _ie = "";                                               // double every quote for the SQF string literal
    { _ie = _ie + (if (_x == 34) then {_q+_q} else {toString [_x]}); } forEach (toArray _init);
    private _entry = format ["[%1%2%1,[%3,%4,%5],[[%6,%7,%8],[%9,%10,%11]],%1%12%1,false]",
        _q, _cls, _p select 0, _p select 1, _p select 2,
        _d select 0, _d select 1, _d select 2,
        _u select 0, _u select 1, _u select 2, _ie];
    _out = _out + _entry + ",";
    diag_log _entry;
} forEach _sel;
diag_log "===AP_EDEN_EXPORT_END===";
copyToClipboard _out;

systemChat format ["edenExport: %1 entries -> clipboard + RPT (between AP_EDEN_EXPORT markers).", count _sel];
