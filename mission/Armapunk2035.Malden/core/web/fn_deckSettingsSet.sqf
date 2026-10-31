/*
    fn_deckSettingsSet.sqf — change one setting, apply it, persist it.

    The native panel did these in two halves that had to agree: a handler that
    set the live global, and fn_settingsInit that read the profile slot back at
    login. This does both in one place off a single id -> slot table, so the two
    cannot drift.

    THE SLOT IS NOT A PREFERENCE. fn_settingsInit reads PLBClientSettings by
    position; a value in the wrong slot is a different setting silently changing
    for the player at their next login, and it would look like corruption rather
    than a bug. The table below is the one in fn_settingsInit.

        ["ringer", 1] call AP_fnc_deckSettingsSet;
        ["vdFoot", 3500] call AP_fnc_deckSettingsSet;
        ["Marker_Cop", 0.4] call AP_fnc_deckSettingsSet;
*/

params [["_id", "", [""]], ["_v", 0, [0, false]]];
if (_id isEqualTo "") exitWith { false };
if (_v isEqualType false) then { _v = if (_v) then { 1 } else { 0 } };

// ── map markers live in their own store ──────────────────────────────────────
private _markerNames = ["Marker_Town","Marker_Cop","Marker_Race","Marker_Illegal","Marker_Reb","Marker_DMV",
                        "Marker_Gas","Marker_Legal","Marker_DPs","Marker_Turfs","Marker_Garage","Marker_PlayerHouse","Marker_Misc"];
private _mIdx = _markerNames findIf { _x isEqualTo _id };
if (_mIdx > -1) exitWith {
    _v = (_v max 0) min 1;
    missionNamespace setVariable [_id, _v];
    private _ms = profileNamespace getVariable ["PLBMarkerSettings", AP_markerDefaultSettings];
    _ms set [_mIdx, _v];
    profileNamespace setVariable ["PLBMarkerSettings", _ms];
    saveProfileNamespace;
    // Colour is how the native path finds the markers this alpha applies to; the
    // house one is keyed by name instead, which is why it gets its own flag.
    private _colour = ["ColorGreen","ColorWEST","ColorBrown","ColorRed","ColorEAST","ColorBlue",
                       "ColorGUER","ColorYellow","ColorKhaki","ColorUNKNOWN","ColorOrange","","ColorBlack"] param [_mIdx, ""];
    [_colour, _v, (_id isEqualTo "Marker_PlayerHouse")] spawn AP_fnc_updateMarkers;
    true
};

// ── client settings ──────────────────────────────────────────────────────────
// id -> [slot, kind]. kind decides clamping, nothing else.
private _map = createHashMapFromArray [
    ["vdFoot",     [1,  "dist"]],  ["vdCar",      [2,  "dist"]],  ["vdAir",     [3,  "dist"]],
    ["mapTier",    [7,  "tier"]],
    ["volume",     [4,  "pct"]],   ["nightBright",[20, "pct"]],
    ["ringer",     [5,  "bool"]],  ["envSounds",  [6,  "bool"]],  ["hexes",     [8,  "bool"]],
    ["titles",     [9,  "bool"]],  ["earplugs",   [10, "bool"]],  ["ignoreCall",[11, "bool"]],
    ["ignoreGang", [12, "bool"]],  ["ambient",    [13, "bool"]],  ["customHex", [14, "bool"]],
    ["domHud",     [15, "bool"]],  ["domIcons",   [16, "bool"]],  ["flagIcons", [17, "bool"]],
    ["plusIcon",   [18, "bool"]],  ["killNotif",  [19, "bool"]],  ["groupHud",  [21, "bool"]],
    ["lockpick",   [22, "bool"]],  ["compass",    [23, "bool"]],  ["streamer",  [24, "bool"]]
];
if !(_id in _map) exitWith { diag_log format ["[DECKSET] unknown setting '%1'", _id]; false };
(_map get _id) params ["_slot", "_kind"];

_v = switch (_kind) do {
    case "dist": { (round _v max 100) min 12000 };
    case "tier": { (round _v max 1) min 3 };
    case "pct":  { (_v max 0.01) min 1 };
    default      { if (_v isEqualTo 0) then { 0 } else { 1 } };
};

private _cs = profileNamespace getVariable ["PLBClientSettings", AP_clientDefaultSettings];
if (count _cs < 25) then { _cs = +AP_clientDefaultSettings };
_cs set [_slot, _v];
profileNamespace setVariable ["PLBClientSettings", _cs];
saveProfileNamespace;

// ── live effect. Copied from the native handlers, not re-imagined. ───────────
private _on = (_v isEqualTo 1);
switch (_id) do {
    case "vdFoot": { tawvd_foot = _v; [] call AP_fnc_updateViewDistance };
    case "vdCar":  { tawvd_car  = _v; [] call AP_fnc_updateViewDistance };
    case "vdAir":  { tawvd_air  = _v; [] call AP_fnc_updateViewDistance };
    case "mapTier": { AP_mapDetail = _v };   // the next streamer tick (2 s) drops or adds the affected objects
    case "volume": { AP_volume = _v; [] spawn { 0 fadeSound AP_volume } };
    case "nightBright": { AP_nightBrightness = _v; ["update"] call AP_fnc_brightNight };

    case "ringer":     { AP_isRingEnabled = _on };
    case "envSounds":  { AP_envSounds = _on; enableEnvironment [AP_ambientLifeEnabled, AP_envSounds] };
    case "ambient":    { AP_ambientLifeEnabled = _on; enableEnvironment [AP_ambientLifeEnabled, AP_envSounds] };
    case "hexes":      { AP_hexMode = _on; if (_on) then { [] spawn AP_fnc_coloredHexes } };
    // the tag cache holds the rendered name plate, so it has to go or the old
    // one keeps being drawn
    case "titles":     { AP_showTitle = _on; AP_tag_cache = [] };
    case "earplugs":   { AP_earplugsToggle = _on };
    case "ignoreCall": { AP_incomingCallsIgnored = _on };
    case "ignoreGang": { AP_gangInvitesIgnored = _on };
    case "customHex":  { AP_isCustomHexesEnabled = _on };
    case "domHud":     { AP_enableDomHUD = _on };
    case "domIcons":   { AP_enableDomHUDIcons = _on };
    case "flagIcons":  { AP_enableFlagIcons = _on };
    case "groupHud":   { AP_enableGroupHud = _on };
    case "compass":    { AP_compassHudToggle = _on };
    case "lockpick":   { AP_enableInteractiveLockpicking = _on };
    // both of these are read off the PLAYER by other clients, so they publish
    case "plusIcon":   { AP_enablePlusIcon = _on; player setVariable ["AP_ShowPlusIcon", _on, true] };
    case "killNotif":  { AP_enableKillNotifications = _on; player setVariable ["AP_ShowPlusIcon", _on, true] };
    case "streamer":   { AP_streamerMode = _on; player setVariable ["AP_unitStreamerMode", _on, true] };
    default {};
};
true
