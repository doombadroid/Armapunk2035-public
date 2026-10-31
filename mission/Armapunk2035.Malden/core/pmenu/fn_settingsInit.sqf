#include "..\..\macro.h"
private _clientSettings = profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings];
private _markerSettings = profileNamespace getVariable["PLBMarkerSettings", AP_markerDefaultSettings];
if !((count _clientSettings) isEqualTo(count AP_clientDefaultSettings)) then {
    private _missingSettings = AP_clientDefaultSettings select[count _clientSettings, (count AP_clientDefaultSettings) - 1];
    _clientSettings append _missingSettings;
    profileNamespace setVariable["PLBClientSettings", _clientSettings];};
if !((count _markerSettings) isEqualTo(count AP_markerDefaultSettings)) then {
    private _missingSettings = AP_markerDefaultSettings select[count _markerSettings, (count AP_markerDefaultSettings) - 1];
    _markerSettings append _missingSettings;
    profileNamespace setVariable["PLBMarkerSettings", _markerSettings];};
private _corruptSettings = []; {_x params["_value"];
    private _passed =
    switch (true) do {case (_forEachIndex isEqualTo 0): {(((localNamespace getVariable "AP_wallpapers") findIf {(_value isEqualTo(_x select 0)) && (call(_x select 3))
                }) >= 0)};
        // Slot 7 is the map detail tier since mapdb (2026-09-04): a Number 0..3. It used to be an
        // admin-only boolean, so an old profile still carries false here -- drift, not tampering.
        case (_forEachIndex isEqualTo 7): {(_value isEqualType 0) && {_value >= 0} && {_value <= 3}};
        default {true};}; private _passed =
    if (!isNil "_x" && {_value isEqualType(AP_clientDefaultSettings select _forEachIndex)}) then[{_passed}, {false}];
    if !(_passed) then {_corruptSettings pushBack[_forEachIndex, AP_clientDefaultSettings select _forEachIndex];
        // Index 0 is the wallpaper id, and a NUMBER that is simply no longer in the
        // catalogue is drift, not tampering: Matrix Rain (id 2) was removed 2026-08-14,
        // so every profile that had it selected would otherwise report ITSELF to the
        // anti-cheat on its next join. Reset those silently. Wrong TYPE, or any other
        // index, still reports.
        if !((_forEachIndex isEqualTo 0 && {_value isEqualType 0}) || {_forEachIndex isEqualTo 7 && {_value isEqualType true}}) then {
            [player, [303, "PLBClientSettings", _forEachIndex, str _value]] remoteExec["APS_fnc_wacClient", 2];};};}
forEach _clientSettings; {_clientSettings set[_x select 0, _x select 1]}
forEach _corruptSettings; {if (_x isEqualType 1) then {if ((_x > 1) || (_x < 0)) then {_markerSettings set[_forEachIndex, 1]};} else {
        _markerSettings set[_forEachIndex, 1]};}
forEach _markerSettings;
profileNamespace setVariable["PLBClientSettings", _clientSettings];
profileNamespace setVariable["PLBMarkerSettings", _markerSettings];
AP_wallpaper = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 0;
tawvd_foot = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 1;
tawvd_car = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 2;
tawvd_air = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 3;
AP_volume = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 4;
AP_isRingEnabled = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 5;
AP_envSounds = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 6;
AP_scrollDisabled = false;
AP_hexMode = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 8;
AP_showTitle = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 9;
AP_earplugsToggle = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 10;
AP_incomingCallsIgnored = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 11;
AP_gangInvitesIgnored = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 12;
AP_ambientLifeEnabled = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 13;
AP_isCustomHexesEnabled = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 14;
AP_enableDomHUD = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 15;
AP_enableDomHUDIcons = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 16;
AP_enableFlagIcons = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 17;
AP_enablePlusIcon = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 18;
AP_enableKillNotifications = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 19;
AP_nightBrightness = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 20;
AP_enableGroupHud = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 21;
AP_enableInteractiveLockpicking = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 22;
AP_compassHudToggle = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 23;
AP_streamerMode = (profileNamespace getVariable["PLBClientSettings", AP_clientDefaultSettings]) select 24;
player setVariable["AP_unitStreamerMode", AP_streamerMode, true];
["init"] call AP_fnc_brightNight;
tawvd_addon_disable = true;
AP_playerTags = true;
AP_sidechat = true;
if (AP_hexMode) then {[] spawn AP_fnc_coloredHexes;};
player setVariable["AP_ShowPlusIcon", AP_enablePlusIcon, true];
enableEnvironment[AP_ambientLifeEnabled, AP_envSounds]; {
    missionNamespace setVariable[_x, (profileNamespace getVariable['PLBMarkerSettings', AP_markerDefaultSettings]) select _forEachIndex];
}
forEach["Marker_Town", "Marker_Cop", "Marker_Race", "Marker_Illegal", "Marker_Reb", "Marker_DMV", "Marker_Gas", "Marker_Legal", "Marker_DPs", "Marker_Turfs", "Marker_Garage", "Marker_PlayerHouse", "Marker_Misc"];
[] spawn {{private _alpha =
        switch (MarkerColor _x) do {case ("ColorGreen");
            case ("ColorWhite"): {Marker_Town}; case ("ColorWEST"): {Marker_Cop};
                case ("ColorBrown"): {Marker_Race};
                case ("ColorRed"): {Marker_Illegal};
                case ("ColorEAST"): {Marker_Reb};
                case ("ColorBlue"): {Marker_DMV};
                case ("ColorGUER"): {Marker_Gas};
                case ("ColorYellow");
                case ("ColorCIV"): {Marker_Legal};
                case ("ColorKhaki"): {Marker_DPs};
                case ("ColorUNKNOWN"): {Marker_Turfs};
                case ("ColorOrange"): {Marker_Garage};
                case ("ColorBlack"): {Marker_Misc};
                default {0};}; if !((_x find "phouse_") >= 0) then {_x setMarkerAlphaLocal _alpha} else {
            _x setMarkerAlphaLocal Marker_PlayerHouse};}
    forEach allMapMarkers;};