/*
    fn_deckSettings.sqf — everything the native settings panel owns, as one payload.

    PARITY IS THE POINT. The old phone is being deleted, so the deck has to hold
    every switch it held, writing the same slots. The store is
    profileNamespace "PLBClientSettings" (25 entries) and "PLBMarkerSettings"
    (13), and the index of each one is NOT a preference -- fn_settingsInit reads
    them back by position at every login, so a value written to the wrong slot
    turns up as an unrelated setting changing by itself. The map below is copied
    from fn_settingsInit, which is the authority.

        0 wallpaper      1 vd foot     2 vd car      3 vd air      4 volume
        5 ringer         6 envSounds   7 mapTier     8 hexes       9 titles
       10 earplugs+     11 ignoreCall 12 ignoreGang 13 ambient    14 customHex
       15 domHud        16 domIcons   17 flagIcons  18 plusIcon   19 killNotif
       20 nightBright   21 groupHud   22 lockpick   23 compass    24 streamer

    Note 18/21/22/23 are REAL settings that the native panel never drew -- they
    are read at login and were only ever settable by editing the profile. They
    are here because the deck replaces the panel, not because the panel had them.

    Usage:  private _p = [] call AP_fnc_deckSettings;
*/

private _cs = profileNamespace getVariable ["PLBClientSettings", AP_clientDefaultSettings];
private _ms = profileNamespace getVariable ["PLBMarkerSettings", AP_markerDefaultSettings];

private _num = { params ["_i", "_d"]; private _v = _cs param [_i, _d]; if (_v isEqualType 0) then { _v } else { _d } };
private _bool = { params ["_i"]; ((_cs param [_i, 0]) isEqualTo 1) || {(_cs param [_i, false]) isEqualTo true} };

private _row = {
    params ["_id", "_idx", "_label", "_type", ["_min", 0], ["_max", 1], ["_note", ""]];
    private _v = if (_type isEqualTo "toggle") then { [_idx] call _bool } else { [_idx, _min] call _num };
    createHashMapFromArray [
        ["id", _id], ["label", _label], ["type", _type], ["value", _v],
        ["min", _min], ["max", _max], ["note", _note]
    ]
};

private _view = [
    ["vdFoot", 1, "On foot",        "range", 100, 12000, "m"],
    ["vdCar",  2, "In a vehicle",   "range", 100, 12000, "m"],
    ["vdAir",  3, "In the air",     "range", 100, 12000, "m"],
    // mapdb: detail tier of the streamed map objects (1 buildings + props, 2 + decor, 3 everything)
    ["mapTier", 7, "Map detail",    "range", 1, 3, "tier"]
] apply { _x call _row };

private _audio = [
    ["volume",    4, "Earplug volume",   "pct", 0.01, 1, ""],
    ["nightBright", 20, "Night brightness", "pct", 0.01, 1, ""],
    ["earplugs", 10, "Extra earplug level", "toggle"],
    ["envSounds", 6, "Environment sounds",  "toggle"],
    ["ambient",  13, "Ambient life",        "toggle"]
] apply { _x call _row };

private _social = [
    ["ringer",      5, "Phone ringer",        "toggle"],
    ["ignoreCall", 11, "Ignore incoming calls","toggle"],
    ["ignoreGang", 12, "Ignore gang invites",  "toggle"],
    ["titles",      9, "Show player titles",   "toggle"],
    ["killNotif",  19, "Kill notifications",   "toggle"],
    ["streamer",   24, "Streamer mode",        "toggle"]
] apply { _x call _row };

private _hud = [
    ["hexes",     8, "Coloured group hexes",  "toggle"],
    ["customHex",14, "Custom hexes",          "toggle"],
    ["groupHud", 21, "Group HUD",             "toggle"],
    ["compass",  23, "Compass HUD",           "toggle"],
    ["plusIcon", 18, "Medic plus icon",       "toggle"],
    ["domHud",   15, "Domination HUD",        "toggle"],
    ["domIcons", 16, "Domination HUD icons",  "toggle"],
    ["flagIcons",17, "Domination flag icons", "toggle"],
    ["lockpick", 22, "Interactive lockpicking","toggle"]
] apply { _x call _row };

// HUD UI EDITOR (hudeditor.md). An ACTION row -- the third type after toggle and range/pct.
// It has no stored value and no slot: it opens a screen. Built here rather than in the page for
// the same reason every other row is, so the deck keeps drawing whatever the payload describes.
private _interface = [
    createHashMapFromArray [
        ["id", "hudEdit"], ["label", "Rearrange HUD"], ["type", "action"],
        ["value", 0], ["min", 0], ["max", 1],
        ["note", "Drag the vitals plates, the status chips and the minimap anywhere on screen. Saved to your account."]
    ]
];

// Markers are their own store and their own scale: 0 hides the marker, 1 shows
// it solid, anything between is a real alpha.
private _markerNames = ["Marker_Town","Marker_Cop","Marker_Race","Marker_Illegal","Marker_Reb","Marker_DMV",
                        "Marker_Gas","Marker_Legal","Marker_DPs","Marker_Turfs","Marker_Garage","Marker_PlayerHouse","Marker_Misc"];
private _markerLabels = ["Towns","Police","Races","Illegal","Rebel","DMV","Fuel","Legal","Drop points","Turfs","Garages","Your houses","Misc"];
private _markers = [];
{
    _markers pushBack (createHashMapFromArray [
        ["id", _x], ["label", _markerLabels param [_forEachIndex, _x]], ["type", "pct"],
        ["value", _ms param [_forEachIndex, 1]], ["min", 0], ["max", 1], ["note", ""]
    ]);
} forEach _markerNames;

// Same ceiling the deckScaleGet verb computes -- from the safezone, never a
// hardcoded number, because UI_GRID is a physical size that moves with the
// player's interface-size setting.
private _gw = 2.5 * pixelW * pixelGrid;
private _gh = 2.5 * pixelH * pixelGrid;
private _scaleMax = ((((safezoneW * 0.98) / (40 * _gw)) min ((safezoneH * 0.98) / (20 * _gh))) min 2.5) max 1;

createHashMapFromArray [
    ["groups", [
        createHashMapFromArray [["name", "VIEW DISTANCE"], ["rows", _view]],
        createHashMapFromArray [["name", "AUDIO"],         ["rows", _audio]],
        createHashMapFromArray [["name", "SOCIAL"],        ["rows", _social]],
        createHashMapFromArray [["name", "HUD"],           ["rows", _hud]],
        createHashMapFromArray [["name", "INTERFACE"],     ["rows", _interface]],
        createHashMapFromArray [["name", "MAP MARKERS"],   ["rows", _markers]]
    ]],
    ["scale", profileNamespace getVariable ["AP_deckScale", 1]],
    ["min",   1],
    ["max",   _scaleMax]
]
