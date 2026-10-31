/*
    AP_fnc_hudToast  (LooneyBin, STRONGBOX) -- HUD notification "receipt slip". Non-interactive RscTitles
    (dialog\toastHUD.hpp: AP_Toast_0..4). A cool-graphite slab (NOT an accent-coloured card): a small
    semantic glyph on the left, a light title line, an optional mono-ish amount in the semantic colour, and
    an optional muted sub. Colour lives ONLY in the glyph + amount (green money / coral spend+danger /
    blue cop / teal medic / brass neutral+event+phone). Up to 5 stack top-right; each fades+slides in, holds
    ~5s, fades+slides out and frees its slot.

    _this = [ _type, _title, _amount, _sub ]
      _type    "money" | "debit" | "danger" | "cop" | "medic" | "event" | "phone" | "neutral"
      _title   headline (light ink)
      _amount  optional figure, drawn in the semantic colour (e.g. "+$42,000", "-$45,000", "$18,500")
      _sub     optional muted detail line
*/
params [["_type", "neutral", [""]], ["_title", "", [""]], ["_amount", "", [""]], ["_sub", "", [""]]];
disableSerialization;
if (!hasInterface) exitWith {};

// ── type -> [ glyph, semanticHex, barTintRGBA ] ──────────────────────────────────────────────────
private _glyph = ">"; private _hex = "#d8a24c"; private _bg = [0.118,0.137,0.180,0.96];
switch (toLower _type) do {case "money":  { _glyph = "+"; _hex = "#5cb877"; _bg = [0.105,0.150,0.120,0.96]; };
    case "debit":  { _glyph = "-"; _hex = "#e0705c"; _bg = [0.170,0.128,0.120,0.96]; };
    case "danger": { _glyph = "!"; _hex = "#e0705c"; _bg = [0.170,0.128,0.120,0.96]; };
    case "cop":    { _glyph = "#"; _hex = "#6c86c4"; _bg = [0.118,0.137,0.180,0.96]; };
    case "medic":  { _glyph = "+"; _hex = "#57a3ab"; _bg = [0.118,0.137,0.180,0.96]; };
    case "event":  { _glyph = "*"; _hex = "#d8a24c"; _bg = [0.118,0.137,0.180,0.96]; };
    case "phone":  { _glyph = "@"; _hex = "#d8a24c"; _bg = [0.118,0.137,0.180,0.96]; };
    default        { _glyph = ">"; _hex = "#d8a24c"; _bg = [0.118,0.137,0.180,0.96]; };};

// ── slot allocation: 5 stacked slots. Drop (don't queue) if all busy. ──
private _slots = uiNamespace getVariable ["AP_toastSlots", [false,false,false,false,false]];
private _slot = _slots findIf { !_x };
if (_slot < 0) exitWith {};
_slots set [_slot, true];
uiNamespace setVariable ["AP_toastSlots", _slots];

private _layer = (format ["AP_toast_%1", _slot]) call BIS_fnc_rscLayer;
_layer cutRsc [format ["AP_toast_%1", _slot], "PLAIN", 0, false];
private _d = uiNamespace getVariable [format ["AP_toast_%1", _slot], displayNull];
if (isNull _d) exitWith {private _s = uiNamespace getVariable ["AP_toastSlots", _slots];
    _s set [_slot, false]; uiNamespace setVariable ["AP_toastSlots", _s];};

private _bar  = _d displayCtrl 100;
private _logo = _d displayCtrl 400;
private _body = _d displayCtrl 500;

// geometry: TOP-RIGHT, small inset, stacks DOWN. Fade + 12px slide-in from the right.
private _fullW = 0.238;
private _logoW = 0.030;
private _h     = 0.062;
private _rightX = 0.992;
private _leftX  = _rightX - _fullW;
private _y      = 0.15 + (_slot * 0.072);
private _off    = 0.012;   // slide distance

_bar ctrlSetBackgroundColor _bg;
_logo ctrlSetStructuredText parseText format ["<t align='center' shadow='0' color='%1' font='PuristaBold' size='1.9'>%2</t>", _hex, _glyph];
_body ctrlSetStructuredText parseText format [
    "<t align='left' shadow='0'><t size='0.98' font='PuristaBold' color='#eef1f7'>%1</t>%2%3</t>", _title,
    (if (_amount != "") then { format ["<br/><t size='0.90' font='PuristaBold' color='%1'>%2</t>", _hex, _amount] } else { "" }),
    (if (_sub != "") then { format ["<br/><t size='0.72' font='PuristaLight' color='#98a1b2'>%1</t>", _sub] } else { "" })];

// place offset-right + faded, then settle to rest + fade in
{_x params ["_c","_cx","_cw"];
    _c ctrlSetPosition [(_cx + _off)*safezoneW+safezoneX, _y*safezoneH+safezoneY, _cw*safezoneW, _h*safezoneH];
    _c ctrlSetFade 1; _c ctrlCommit 0;} forEach [[_bar,  _leftX,                  _fullW], [_logo, _leftX + 0.006,          _logoW],
    [_body, _leftX + _logoW + 0.010, _fullW - _logoW - 0.018]]; {_x params ["_c","_cx","_cw"];
    _c ctrlSetPosition [_cx*safezoneW+safezoneX, _y*safezoneH+safezoneY, _cw*safezoneW, _h*safezoneH];
    _c ctrlSetFade 0; _c ctrlCommit 0.18;} forEach [[_bar,  _leftX,                  _fullW], [_logo, _leftX + 0.006,          _logoW],
    [_body, _leftX + _logoW + 0.010, _fullW - _logoW - 0.018]];

// hold ~5s -> fade out in place -> drop layer -> free slot
[_layer, _bar, _logo, _body, _slot] spawn {params ["_layer","_bar","_logo","_body","_slot"];
    uiSleep 5;
    { if (!isNull _x) then { _x ctrlSetFade 1; _x ctrlCommit 0.22; }; } forEach [_bar, _logo, _body];
    uiSleep 0.35;
    _layer cutText ["", "PLAIN"];
    private _s = uiNamespace getVariable ["AP_toastSlots", [false,false,false,false,false]];
    _s set [_slot, false];
    uiNamespace setVariable ["AP_toastSlots", _s];};
