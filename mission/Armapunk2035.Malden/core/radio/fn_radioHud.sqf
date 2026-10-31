/*
    fn_radioHud.sqf  (AP_fnc_radioHud) -- slides the "now playing" widget in for ~6s then out (lower-left, from the screen edge, fully opaque).
    _this = [_songIndex]  (>=0 = playing that track of the current station; <0 = radio OFF/offline).
    RscTitles class AP_AutoRadioMenu (dialog\radioHUD.hpp). Uses a dedicated rsc layer so it never
    fights the other HUD title layers.
*/
params [["_song", -1, [0]], ["_st", 0, [0]], ["_text", "", [""]]];
disableSerialization;

private _cfg = missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio";
_st = _st max 0;
private _on  = (_song >= 0) || (_song in [-2, -3]);

private _layer = "AP_carRadio" call BIS_fnc_rscLayer;
_layer cutRsc ["AP_AutoRadioMenu", "PLAIN", 0, false];
private _d = uiNamespace getVariable ["AP_AutoRadioMenu", displayNull];
if (isNull _d) exitWith {};

private _bg   = _d displayCtrl 0100;   // colored bar
private _wb   = _d displayCtrl 0200;   // small side bar
private _tab  = _d displayCtrl 0300;   // tab-key hint icon
private _logo = _d displayCtrl 0400;   // station logo
private _txt  = _d displayCtrl 0500;   // song title

// collapsed start (zero width)
_bg ctrlSetPosition [0.0*safezoneW+safezoneX, 0.845*safezoneH+safezoneY, 0, 0.065*safezoneH]; _bg ctrlCommit 0;
_wb ctrlSetPosition [0.0*safezoneW+safezoneX, 0.810*safezoneH+safezoneY, 0, 0.035*safezoneH]; _wb ctrlCommit 0;
{ _x ctrlSetFade 1; _x ctrlCommit 0; } forEach [_tab, _logo, _txt];

if (_on) then {private _rc = parseSimpleArray ((getArray (_cfg >> "AUTORADIO_RadioColor")) select _st); _rc set [3, 1];   // fully opaque
    _bg   ctrlSetBackgroundColor _rc;
    _logo ctrlSetText ((getArray (_cfg >> "AUTORADIO_RadioLogo")) select _st);
    _txt  ctrlSetStructuredText parseText (call {
        if (_song isEqualTo -2) exitWith { format ["<t shadow='0' font='PuristaBold' color='#191919'>%1<br/><t font='PuristaLight' size='0.8'>ARMAPUNK 2035 — LIVE</t>", _text] };
        if (_song isEqualTo -3) exitWith { format ["<t shadow='0' font='PuristaBold' color='#191919'>%1<br/><t font='PuristaLight' size='0.8'>GET THE ARMAPUNK 2035 CLIENT MOD — STEAM WORKSHOP</t>", _text] };
        private _names = getArray (_cfg >> ((getArray (_cfg >> "AUTORADIO_RadioName")) select _st));
        _names select (_song min ((count _names) - 1))});} else {
    _bg   ctrlSetBackgroundColor [0.695, 0.695, 0.695, 1];
    _logo ctrlSetText "images\radio\CrossIcon.paa";
    _txt  ctrlSetStructuredText parseText "<t shadow='0' font='PuristaBold' color='#191919'>RADIO OFF<br/><t font='PuristaLight' size='0.8'>PRESS Q IN A VEHICLE</t>";
};

// slide in
_bg ctrlSetPosition [0.0*safezoneW+safezoneX, 0.845*safezoneH+safezoneY, 0.211*safezoneW, 0.065*safezoneH]; _bg ctrlCommit 0.25;
_wb ctrlSetPosition [0.0*safezoneW+safezoneX, 0.810*safezoneH+safezoneY, 0.031*safezoneW, 0.035*safezoneH]; _wb ctrlCommit 0.25;
{ _x ctrlSetFade 0; _x ctrlCommit 1; } forEach [_tab, _logo, _txt];

[_d, _layer] spawn {params ["_d", "_layer"];
    uiSleep 6;
    if (isNull _d) exitWith {};
    { (_d displayCtrl _x) ctrlSetFade 1; (_d displayCtrl _x) ctrlCommit 0.75; } forEach [0300, 0400, 0500];
    uiSleep 0.75;
    (_d displayCtrl 0100) ctrlSetPosition [0.0*safezoneW+safezoneX, 0.845*safezoneH+safezoneY, 0, 0.065*safezoneH]; (_d displayCtrl 0100) ctrlCommit 0.25;
    (_d displayCtrl 0200) ctrlSetPosition [0.0*safezoneW+safezoneX, 0.810*safezoneH+safezoneY, 0, 0.035*safezoneH]; (_d displayCtrl 0200) ctrlCommit 0.25;
    uiSleep 0.3;
    _layer cutText ["", "PLAIN"];};
