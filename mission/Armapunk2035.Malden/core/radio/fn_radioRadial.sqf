/*
    fn_radioRadial.sqf  (AP_fnc_radioRadial) -- TAB-in-vehicle HALF-PIE car radio (idd 515500).
    v3 (owner 2026-07-09): five 36-degree station wedges fan a HALF circle over the top
    (left -> right), fully opaque in each station's own color (dim shade at rest, brighter on
    hover, full on active), logos riding the wedges; OFF is its OWN wedge sitting alone at the
    bottom with a power icon. Selection is mouse-angle based (whole sector = hit zone), LMB
    commits, TAB/ESC closes. Readout column (station name / ON AIR / OFF, outlined text over a
    soft void plate) sits to the right. Anchored bottom-left, above the chat window.
    Driver/pilot-only mutations; primitives identical to fn_autoRadio (AP_radioOn/-Station).
*/
#define IDD_RADIAL 515500
// ---- shared refresh: wedge brightness (rest / hover / active) + readout (state AP_radialGeom etc. set below) ----
if !(isFinal "AP_radialRefresh") then {AP_radialRefresh = compileFinal {disableSerialization;
    private _d = findDisplay IDD_RADIAL;
    if (isNull _d) exitWith {};
    AP_radialGeom params ["_cx", "_cy", "_R", "_sq", "_centers", "_n"];
    private _cfg = missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio";
    private _v  = vehicle player;
    private _on = _v getVariable ["AP_radioOn", false];
    private _st = _v getVariable ["AP_radioStation", 0];
    // NC treatment: wedges are GRAPHITE GLASS tinted toward the station neon -- mix rises with state
    // (rest 0.38 / hover 0.62 / active = full neon). The white logo glows in the station color and flips to
    // void-dark when its wedge goes full neon. (Neon rim overlay removed -- its texture never shipped.)
    private _gra = [0.118, 0.153, 0.208];
    private _apModes = ["madmax", "normal", "sloth"];
    private _apCur = missionNamespace getVariable ["AP_gpsAPMode", ""];
    private _apOn = missionNamespace getVariable ["AP_gpsAP", false];
    for "_i" from 0 to (count AP_radialBase - 1) do {private _w    = _d displayCtrl (8000 + _i);
        if (isNull _w) then { continue };
        private _icon = _d displayCtrl (8200 + _i);
        private _base = AP_radialBase select _i;
        private _active = call {if (_i < _n) exitWith { _on && {_st isEqualTo _i} };
            if (_i isEqualTo _n) exitWith { !_on };
            _apOn && {_apCur isEqualTo (_apModes param [_i - _n - 1, ""])}};
        private _hover  = _i isEqualTo AP_radialHover;
        private _t = if (_active) then { 1 } else { if (_hover) then { 0.62 } else { 0.38 } };
        _w ctrlSetTextColor [(_gra select 0) + ((_base select 0) - (_gra select 0)) * _t,
            (_gra select 1) + ((_base select 1) - (_gra select 1)) * _t, (_gra select 2) + ((_base select 2) - (_gra select 2)) * _t, 1];
        if (_active) then {_icon ctrlSetTextColor [0.035, 0.051, 0.082, 1];      // void-dark glyph on the lit wedge
        } else {_icon ctrlSetTextColor [(_base select 0), (_base select 1), (_base select 2), 1];   // neon glyph on graphite
        };};
    private _stateTxt = _d displayCtrl 8301;
    private _hovTxt   = _d displayCtrl 8302;
    private _labels = ["ORIGIN", "KHR", "PULSE", "CLASSICO", "ANARCHY"];
    private _fnHex = { params ["_rc"]; ((_rc select [0,3]) apply { private _v255 = floor ((_x * 255) min 255); format ["%1%2", "0123456789ABCDEF" select [floor (_v255 / 16), 1], "0123456789ABCDEF" select [_v255 mod 16, 1]] }) joinString "" };
    if (AP_radialHover >= 0 && {AP_radialHover < _n}) then {
        private _rc = parseSimpleArray ((getArray (_cfg >> "AUTORADIO_RadioColor")) select AP_radialHover);
        _hovTxt ctrlSetStructuredText parseText format ["<t shadow='2' align='left' font='PuristaBold' size='1.5' color='#%1'>%2</t>", [_rc] call _fnHex, _labels param [AP_radialHover, ""]];
    } else {if (AP_radialHover > _n) then {private _apLbl = ["MAD MAX", "NORMAL", "SLOTH"] param [AP_radialHover - _n - 1, ""];
            private _apHex = ["FF4729", "00D4FF", "59D973"] param [AP_radialHover - _n - 1, "00D4FF"];
            _hovTxt ctrlSetStructuredText parseText format ["<t shadow='2' align='left' font='PuristaBold' size='1.5' color='#%1'>%2</t>", _apHex, _apLbl];
        } else {if (AP_radialHover isEqualTo _n) then {
            _hovTxt ctrlSetStructuredText parseText "<t shadow='2' align='left' font='PuristaBold' size='1.5' color='#8993A0'>RADIO OFF</t>";
        } else {if (_on) then {private _rc = parseSimpleArray ((getArray (_cfg >> "AUTORADIO_RadioColor")) select _st);
                _hovTxt ctrlSetStructuredText parseText format ["<t shadow='2' align='left' font='PuristaBold' size='1.5' color='#%1'>%2</t>", [_rc] call _fnHex, _labels param [_st, ""]];
            } else {
                _hovTxt ctrlSetStructuredText parseText "<t shadow='2' align='left' font='PuristaBold' size='1.5' color='#8993A0'>RADIO</t>";
            };};};};
    if (_on) then {private _rc = parseSimpleArray ((getArray (_cfg >> "AUTORADIO_RadioColor")) select _st);
        _stateTxt ctrlSetStructuredText parseText format ["<t shadow='2' align='left' font='PuristaMedium' size='0.95' color='#%1'>%2 ON AIR</t>", [_rc] call _fnHex, "&#9679;"];
    } else {
        _stateTxt ctrlSetStructuredText parseText "<t shadow='2' align='left' font='PuristaMedium' size='0.95' color='#53616F'>OFF</t>";};
}};

// ---- mouse-angle hit testing via a fullscreen invisible catch button + getMousePosition ----
if !(isFinal "AP_radialPick") then {AP_radialPick = compileFinal {private _m = getMousePosition;
    AP_radialGeom params ["_cx", "_cy", "_R", "_sq", "_centers", "_n"];
    private _dx = ((_m select 0) - _cx) / _sq;
    private _dy = (_m select 1) - _cy;
    private _dist = sqrt (_dx * _dx + _dy * _dy);
    private _hover = -1;
    if (_dist < (1.06 * _R)) then {private _ang = _dx atan2 (-_dy);          // 0 = up, clockwise positive
        private _half = 90 / _n;                  // half wedge width (36/2 deg for 5 stations)
        {private _diff = abs ((((_ang - _x) + 540) mod 360) - 180);
            if (_diff <= _half) exitWith { _hover = _forEachIndex; };} forEach _centers;};
    _hover}};
// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};
private _veh = vehicle player;
if (_veh isEqualTo player) exitWith {};
// owner 2026-07-09: aircraft allowed -- TAB is unbound in helis/planes, so the radial IS the aircraft radio UI
if (!isNull (findDisplay IDD_RADIAL)) exitWith { closeDialog 0; };

createDialog "AP_RadialRadio";
disableSerialization;
private _d = findDisplay IDD_RADIAL;
if (isNull _d) exitWith {};

_d displayAddEventHandler ["KeyDown", {params ["", "_code"];
    if (_code in [15, 1]) then { closeDialog 0; true } else { false }}];

private _cfg    = missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio";
private _n      = count getArray (_cfg >> "AUTORADIO_Radio");
private _cols   = getArray (_cfg >> "AUTORADIO_RadioColor");
private _logos  = getArray (_cfg >> "AUTORADIO_RadioLogo");

// ---- geometry: half-pie anchored bottom-left (above chat), square via the pixel grid ----
private _sq = pixelW / pixelH;
private _R  = 0.13 * safezoneH;
private _cx = safezoneX + (_R * _sq) + 0.012;
private _cy = safezoneY + 0.72 * safezoneH - _R;
private _pw = 2 * _R * _sq;
private _ph = 2 * _R;

// slot centers (degrees, 0 = up, clockwise): stations span the TOP half left->right in 36-deg
// wedges (-72, -36, 0, 36, 72); OFF sits ALONE at the bottom (180).
private _step = 180 / _n;
private _centers = [];
for "_i" from 0 to (_n - 1) do { _centers pushBack (-90 + (_step / 2) + _i * _step); };
_centers pushBack (90 + (_step / 2));   // owner: OFF wedge TOUCHES Anarchy -- continues the fan past 3 o'clock
// owner 2026-07-12: AUTOPILOT driving modes (garage module + driver only) -- 3 more wedges
// continuing the fan around the bottom: MAD MAX / NORMAL / SLOTH
private _apOk = (driver _veh isEqualTo player) && {(_veh isKindOf "LandVehicle") || {[_veh] call AP_fnc_isRotorcraft}} && {_veh getVariable ["AP_autopilot", false]};
private _apBase = count _centers;   // first mode index (= _n + 1)
if (_apOk) then {{ _centers pushBack (90 + (_step / 2) + _step * (_x + 1)); } forEach [0, 1, 2];};

for "_i" from 0 to (count _centers - 1) do {private _c = _centers select _i;
    private _w = _d ctrlCreate ["AP_RadialPic", 8000 + _i];
    _w ctrlSetText "images\ui\radial_wedge.paa";
    _w ctrlSetPosition [_cx - _pw/2, _cy - _ph/2, _pw, _ph];
    _w ctrlSetAngle [_c, 0.5, 0.5, false];
    _w ctrlCommit 0;
    // logo/icon at the wedge centroid (upright)
    private _lx = _cx + (0.66 * _R * _sq) * sin _c;
    private _ly = _cy - (0.66 * _R) * cos _c;
    private _iw = 0.23 * _R * _sq; private _ih = 0.23 * _R;
    // owner 2026-07-10: removed the never-shipped neon rim overlay (idc 8500+_i). images\ui\radial_rim.paa was
    // never created/committed, so hitting TAB flashed a "missing texture" on the active wedge. The wedge itself
    // already ramps to full brightness on active (below), so the rim was redundant -- re-add with a real
    // rim.paa if the extra neon outline is ever wanted.
    private _whiteLogos =["images\ui\radial_ic_origin.paa", "images\ui\radial_ic_khr.paa", "images\ui\radial_ic_pulse.paa", "images\ui\radial_ic_classico.paa", "images\ui\radial_ic_anarchy.paa"];   // owner: clean bold glyphs (sunrise/mic/EKG/note/bolt) -- brand logos were mud at 40px
    private _icon = _d ctrlCreate ["AP_RadialPicKA", 8200 + _i];
    private _apIcons = ["images\ui\ap_madmax.paa", "images\ui\ap_normal.paa", "images\ui\ap_sloth.paa"];
    _icon ctrlSetText (call {if (_i < _n) exitWith { _whiteLogos param [_i, _logos select _i] };
        if (_i isEqualTo _n) exitWith { "images\ui\radial_power.paa" };
        _apIcons param [_i - _n - 1, "images\ui\radial_power.paa"]});
    _icon ctrlSetPosition [_lx - _iw, _ly - _ih, _iw * 2, _ih * 2];
    _icon ctrlCommit 0;};

// per-slot base colors (full alpha -- states are BRIGHTNESS shades, owner: 100% opaque)
AP_radialBase = [];
private _apColors = [[1, 0.28, 0.16, 1], [0, 0.83, 1, 1], [0.35, 0.85, 0.45, 1]];   // madmax ember / normal cyan / sloth moss
for "_i" from 0 to (count _centers - 1) do {private _rc = call {if (_i < _n) exitWith { parseSimpleArray (_cols select _i) };
        if (_i isEqualTo _n) exitWith { [0.549, 0.627, 0.706, 1] };   // OFF = NC steel
        +(_apColors param [_i - _n - 1, [0, 0.83, 1, 1]])};
    _rc set [3, 1];
    AP_radialBase pushBack _rc;};

// ---- readout column to the RIGHT of the pie ----
private _tx = _cx + _pw/2 + 0.012;
// owner 2026-07-09: readout was unreadable over bright ground -- soft void plate + outlined text
private _plate = _d ctrlCreate ["AP_RadialPic", -1];
_plate ctrlSetText "#(argb,8,8,3)color(0.035,0.051,0.082,0.6)";
_plate ctrlSetPosition [_tx - 0.008, _cy - 0.085, 0.245, 0.185]; _plate ctrlCommit 0;
private _hovTxt = _d ctrlCreate ["AP_RadialTxt", 8302];
_hovTxt ctrlSetPosition [_tx, _cy - 0.075, 0.30, 0.05]; _hovTxt ctrlCommit 0;
private _stateTxt = _d ctrlCreate ["AP_RadialTxt", 8301];
_stateTxt ctrlSetPosition [_tx, _cy - 0.022, 0.30, 0.04]; _stateTxt ctrlCommit 0;
private _hint = _d ctrlCreate ["AP_RadialTxt", -1];
_hint ctrlSetStructuredText parseText "<t shadow='2' align='left' font='PuristaLight' size='0.8' color='#8993A0'>LMB — SELECT<br/>TAB / ESC — CLOSE</t>";
_hint ctrlSetPosition [_tx, _cy + 0.028, 0.30, 0.06]; _hint ctrlCommit 0;

// ---- shared refresh state, read by AP_radialRefresh / AP_radialPick (defined at the top) ----
AP_radialGeom = [_cx, _cy, _R, _sq, _centers, _n];
AP_radialApBase = _apBase;
AP_radialHover = -1;
private _catch = _d ctrlCreate ["AP_RadialBtn", 8400];
_catch ctrlSetPosition [safezoneX, safezoneY, safezoneW, safezoneH]; _catch ctrlCommit 0;
_catch ctrlSetEventHandler ["MouseMoving", "
    private _h = call AP_radialPick;
    if !(_h isEqualTo AP_radialHover) then { AP_radialHover = _h; call AP_radialRefresh; };
"];
_catch ctrlSetEventHandler ["ButtonClick", "
    AP_radialHover = call AP_radialPick;
    call AP_radialRefresh;
    if (AP_radialHover >= 0) then {
        private _v = vehicle player;
        if !(driver _v isEqualTo player) then { ['Only the driver controls the radio.', 'basic'] spawn AP_fnc_handleMessage; } else {
            AP_radialGeom params ['', '', '', '', '', '_n'];
            if (AP_radialHover < _n) then {
                _v setVariable ['AP_radioStation', AP_radialHover, true];
                if !(_v getVariable ['AP_radioOn', false]) then { _v setVariable ['AP_radioOn', true, true]; };
            } else {
                if (AP_radialHover isEqualTo _n) then {
                    if (_v getVariable ['AP_radioOn', false]) then { _v setVariable ['AP_radioOn', false, true]; };
                } else {
                    private _mode = ['madmax', 'normal', 'sloth'] param [AP_radialHover - _n - 1, 'normal'];
                    closeDialog 0;
                    ['start', _mode] call AP_fnc_gpsAutopilot;
                };
            };
            call AP_radialRefresh;
        };
    };
"];

call AP_radialRefresh;
