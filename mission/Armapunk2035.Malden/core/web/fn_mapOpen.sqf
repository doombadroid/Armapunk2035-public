/*
    fn_mapOpen.sqf — boot MALDEN GRID (dialog 930430).

    The whole point of this screen is that it needs NOTHING outside the game.
    Tiles are the engine's own satellite layer read via A3API.RequestTexture;
    live data rides the same push channel as every other page. No website, no
    external agent, no RPT tailing.

    ESP GUARD — the one rule that matters here. This pushes ONLY what this
    client already knows: the player's own position, the player's own group
    (whose members the engine syncs to group clients anyway), and mission
    markers at the alpha the player's OWN marker settings already display.
    Pushing any other player's position would hand a wallhack to anyone who
    reads the channel. Widening this payload is a design decision for the
    owner, not a convenience.
*/

// THE DESTINATION CHANNEL, "mapDest" = { wp, nav }. The page used to hold WP and NAV
// in its own variables, set optimistically on click and lost on every close, reopen
// or served-document rewrite -- while the game kept both. Now the page draws ONLY
// what this reports:
//   wp   [x, y] from AP_mapWaypoint, or [] -- the personal waypoint (AP_fnc_mapWpHud)
//   nav  {x, y, route, len} from AP_gpsDest / AP_gpsRoutePts, or {} -- the GPS route
//        the autopilot actually rides, decimated exactly as the mapNav reply always was
// It is pushed once at open, after every waypoint/GPS action, and whenever the
// pusher sees the state change underneath (the GPS clearing itself on arrival, say).
// NOT on the 1 Hz tick: a road route across the island is hundreds of points and it
// only changes when a destination does.
// Globals, not opener privates, for the _vehKind reason below: the handlers and the
// pusher run long after this scope has gone.
if !(isFinal "AP_fnc_mapRouteDecimate") then {AP_fnc_mapRouteDecimate = compileFinal {
    params [["_pts", [], [[]]]];
    // ~30 m vertices plus both ends. The drawn line cannot tell the difference, and
    // the length is summed over EVERY point so it stays the true road length.
    private _route = [];
    private _len = 0;
    private _last = [-999, -999];
    {
        if (_forEachIndex > 0) then { _len = _len + (_x distance2D (_pts select (_forEachIndex - 1))); };
        if (_forEachIndex isEqualTo 0 || { _forEachIndex isEqualTo (count _pts - 1) }
            || { _x distance2D _last > 30 }) then {
            _route pushBack [(round ((_x select 0) * 10)) / 10, (round ((_x select 1) * 10)) / 10];
            _last = _x;
        };
    } forEach _pts;
    [_route, _len]
}};
if !(isFinal "AP_fnc_mapDestSig") then {AP_fnc_mapDestSig = compileFinal {
    [missionNamespace getVariable ["AP_mapWaypoint", []],
     missionNamespace getVariable ["AP_gpsDest", []],
     count (missionNamespace getVariable ["AP_gpsRoutePts", []])]
}};
if !(isFinal "AP_fnc_mapDestState") then {AP_fnc_mapDestState = compileFinal {
    private _wp   = missionNamespace getVariable ["AP_mapWaypoint", []];
    private _dest = missionNamespace getVariable ["AP_gpsDest", []];
    private _pts  = missionNamespace getVariable ["AP_gpsRoutePts", []];
    private _nav  = createHashMap;
    // A destination with no stored route is not a route: nothing is drawn rather than
    // a straight line that would read as one.
    if (_dest isNotEqualTo [] && { _pts isNotEqualTo [] }) then {
        ([_pts] call AP_fnc_mapRouteDecimate) params ["_route", "_len"];
        _nav = createHashMapFromArray [
            ["x", _dest select 0], ["y", _dest select 1], ["route", _route], ["len", _len]];
    };
    createHashMapFromArray [
        ["wp",  if (_wp isEqualTo []) then { [] } else { [_wp select 0, _wp select 1] }],
        ["nav", _nav]
    ]
}};
if !(isFinal "AP_fnc_mapPushDest") then {AP_fnc_mapPushDest = compileFinal {
    // The map's OWN control, parked at open -- not WEBUI_ctrl, which is simply
    // whichever control was wired last and belongs to the HUD layer as often as not.
    private _c = uiNamespace getVariable ["AP_mapCtrl", controlNull];
    if (isNull _c) exitWith {};
    uiNamespace setVariable ["AP_mapDestSig", call AP_fnc_mapDestSig];
    [_c, "mapDest", (call AP_fnc_mapDestState)] call webui_fnc_push;
}};
// THE MODIFIER BRIDGE (below) pushes through this.
if !(isFinal "AP_fnc_mapPushMods") then {AP_fnc_mapPushMods = compileFinal {
    params ["_s", "_c", "_a"];
    private _st = [[0, 1] select _s, [0, 1] select _c, [0, 1] select _a];
    if (_st isEqualTo (uiNamespace getVariable ["AP_mapMods", []])) exitWith {};
    uiNamespace setVariable ["AP_mapMods", _st];
    private _cc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (isNull _cc) exitWith {};
    [_cc, format ["window.__mods={s:%1,c:%2,a:%3}", _st select 0, _st select 1, _st select 2]] call webui_fnc_exec;
}};

// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[MAP] open: null display" };
disableSerialization;

private _ctrl = _display displayCtrl 930431;
if (isNull _ctrl) exitWith { diag_log "[MAP] control 930431 missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[MAP] bridge init failed" };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\map.html"] call webui_fnc_serve;
[_ctrl] call AP_fnc_casinoFit;   // fills the safezone; the fn is generic despite the name

private _liveData = {
    // Defined INSIDE the builder: this code runs from the pusher spawn and the
    // channel handlers, long after the opener's scope is gone, and SQF resolves
    // privates from the CALLER's scope at call time. As an opener-level private
    // it was undefined on every push -- which killed the whole payload, which is
    // why the map had markers but no self, no group and no env.
    private _vehKind = {
        params ["_u"];
        private _v = vehicle _u;
        if (_v isEqualTo _u) exitWith { "none" };
        switch (true) do {
            case (_v isKindOf "Helicopter"): { "heli" };
            case (_v isKindOf "Plane"):      { "air" };
            case (_v isKindOf "Ship"):       { "boat" };
            case (_v isKindOf "Truck_F");
            case (_v isKindOf "Tank"):       { "truck" };
            default                          { "car" };
        }
    };
    private _units = (units group player) - [player];
    private _grp = _units apply {
        private _v = vehicle _x;
        private _kind = [_x] call _vehKind;
        private _row = createHashMapFromArray [
            // A stable identity, so the page can keep a squadmate selected while they
            // move and notice when they leave, instead of re-finding them by display
            // name (two players can share one). netId is the engine's own object id;
            // it carries nothing the group channel does not already expose.
            ["id",     netId _x],
            ["name",   name _x],
            ["x",      (getPosATL _x) select 0],
            ["y",      (getPosATL _x) select 1],
            ["alive",  alive _x],
            ["leader", _x isEqualTo (leader group player)],
            ["veh",    _kind],
            // crew counted among GROUP members only: two squadmates in one car
            // stack to one glyph. Counting strangers in the same vehicle would
            // leak presence the ESP guard exists to keep out of the channel.
            ["crew",   { (vehicle _x) isEqualTo _v && { _x in units group player } } count crew _v]
        ];
        // The holo heli hangs off a real altitude; the page hovers a stylised
        // 120 m and hides the AGL readout when the field is absent, so it is
        // only sent when it means something.
        if (_kind in ["heli", "air"]) then { _row set ["alt", (getPosASL _v) select 2] };
        _row
    };
    private _out = createHashMapFromArray [
        ["self", createHashMapFromArray [
            ["x",   (getPosATL player) select 0],
            ["y",   (getPosATL player) select 1],
            ["dir", getDir player],
            ["name", name player],
            ["veh",  [player] call _vehKind]
        ]],
        ["group", _grp],
        // in-game light, for the terrain: hour as a float, overcast 0-1
        ["env", createHashMapFromArray [["hour", daytime], ["overcast", overcast]]]
    ];

    // ADMIN LAYER -- every player, live. This is the ESP guard's documented
    // owner-decision carve-out, made deliberately and gated on adminLevel. No
    // new data leaves the machine to build it: player objects and their
    // positions are already engine-synced to every client; this only chooses to
    // DRAW them for staff. AP_adminLevel is server-assigned, and a client that
    // could fake it could read allPlayers itself anyway.
    if ((call AP_adminLevel) >= 2) then {
        _out set ["admin", true];
        _out set ["all", (allPlayers select { alive _x && { !(_x isEqualTo player) } }) apply {
            createHashMapFromArray [
                ["name", name _x],
                ["x", (getPosATL _x) select 0],
                ["y", (getPosATL _x) select 1],
                ["side", switch (side group _x) do { case west: {"cop"}; case independent: {"med"}; default {"civ"} }],
                ["veh", [_x] call _vehKind]
            ]
        }];
    };
    _out
};

private _staticData = {
    // The player's own marker settings decide visibility: settingsInit has
    // already applied the per-category alphas with setMarkerAlphaLocal, so
    // markerAlpha here IS the player's preference. Zero-alpha never leaves SQF.
    private _out = [];
    {
        private _a = markerAlpha _x;
        if (_a > 0.05 && { (markerText _x isNotEqualTo "") || { markerType _x isNotEqualTo "" } }) then {
            _out pushBack (createHashMapFromArray [
                // The marker's own name. The page needs it for two things only: to
                // keep a selection pinned to THIS marker when several share a text
                // ("Boat Shop" appears seven times on Malden), and to recognise its
                // own local AP_mapwp / AP_mapnav markers, which it already draws from
                // the mapDest channel -- by id, never by their "WP"/"NAV" text.
                ["id",    _x],
                ["x",     (markerPos _x) select 0],
                ["y",     (markerPos _x) select 1],
                ["text",  markerText _x],
                ["type",  markerType _x],
                ["color", markerColor _x],
                ["alpha", _a]
            ]);
        };
        if (count _out >= 500) exitWith {};   // a map, not a firehose
    } forEach allMapMarkers;
    // Search fodder: every named place the engine knows. Static per session.
    private _locs = (nearestLocations [[6400, 6400, 0],
        ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "NameMarine", "Hill", "Airport"], 9500]) apply {
        createHashMapFromArray [
            ["name", text _x],
            ["x", (locationPosition _x) select 0],
            ["y", (locationPosition _x) select 1],
            ["kind", type _x]
        ]
    };
    _locs = _locs select { (_x get "name") isNotEqualTo "" };

    // Cartel ownership, live off each flag's published capData -- [tier, gangName,
    // progress]. "Neutral" means nobody holds it. mine = the player's own gang,
    // compared by name because that is what capData stores.
    private _myGang = if (AP_gang_data isEqualTo []) then { "" } else { AP_gang_data param [1, ""] };
    private _cartels = [];
    {
        _x params ["_id", "_name", "_flagVar", "", "_pos"];
        private _flag = missionNamespace getVariable [_flagVar, objNull];
        private _cap = if (isNull _flag) then { [0, "Neutral", 0.5] } else { _flag getVariable ["AP_capData", [0, "Neutral", 0.5]] };
        private _gang = _cap param [1, "Neutral"];
        _cartels pushBack (createHashMapFromArray [
            ["id", _id], ["n", toUpper _name],
            ["x", _pos select 0], ["y", _pos select 1],
            ["r", if (_id isEqualTo "boomtown") then { 95 } else { 60 }],
            ["gang", _gang],
            ["mine", (_gang isNotEqualTo "Neutral") && { _gang isEqualTo _myGang }]
        ]);
    } forEach (call AP_fnc_cartelCfg);

    // Fixer territory. The POLYGON is shipped, not a centre and a radius, because
    // the polygon is what the game tests -- fn_factionTerritory reads the same
    // array from the same config. A circle approximating it would be a drawing
    // that disagrees with the rule, and the disagreement only ever surfaces as
    // "I got shot in a safe zone".
    //
    // `war` carries this week's matchup so the page can tint the two belligerents
    // differently from the fixer sitting it out; `mine` is the player's own
    // allegiance, resolved off the published mirror rather than anything local so
    // it is right for a member who was offline when their leader swore.
    private _myFaction = missionNamespace getVariable ["AP_myFaction", ""];
    private _war = missionNamespace getVariable ["AP_factionWar", []];
    private _pair = if (_war isEqualType [] && {count _war >= 2}) then { [_war select 0, _war select 1] } else { [] };
    private _terr = [];
    {
        private _poly = _x param [5, []];
        if (_poly isNotEqualTo []) then {
            _terr pushBack (createHashMapFromArray [
                ["id",   _x select 0],
                ["n",    toUpper (_x select 1)],
                ["town", _x param [6, ""]],
                ["poly", _poly],
                ["war",  (_x select 0) in _pair],
                ["mine", (_x select 0) isEqualTo _myFaction]
            ]);
        };
    } forEach (["all"] call AP_fnc_factionCfg);

    createHashMapFromArray [["markers", _out], ["locations", _locs], ["cartels", _cartels], ["territories", _terr]]
};

// pages re-ask after a reload; both answer the same builders the pusher uses
[_ctrl, "map",       _liveData]   call webui_fnc_on;
[_ctrl, "mapStatic", _staticData] call webui_fnc_on;

uiNamespace setVariable ["AP_mapCtrl", _ctrl];
[_ctrl, "mapDest", { call AP_fnc_mapDestState }] call webui_fnc_on;

// SEARCH FOCUS. The page's search field takes typed text, and the dialog's own
// KeyDown below closes the map on the ShowMap key -- M -- which is a letter in
// half the place names on Malden. stopPropagation in the page cannot help: the
// dialog sees the key at the engine level, not through the DOM. So the page says
// when a text field has focus and the close-on-M is skipped for exactly that long.
// Escape is untouched and still closes. Reset on every open, so a page that died
// mid-typing cannot leave M disabled for the next one.
uiNamespace setVariable ["AP_mapTyping", false];
[_ctrl, "mapTyping", {
    params [["_on", false, [false]]];
    uiNamespace setVariable ["AP_mapTyping", _on];
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

// THE MODIFIER BRIDGE. The browser control delivers LMB and wheel only, and it
// strips modifier state from its events -- shift-drag reached the page as a
// plain drag (probed 2026-08-13). The DIALOG's key handlers, meanwhile, see
// every key including modifiers (Esc has always worked). So SQF is the modifier
// source of truth: both handlers mirror the state into window.__mods, and the
// page reads that instead of the event's dead flags. Global fn because these
// handlers outlive this scope (the _vehKind lesson).
uiNamespace setVariable ["AP_mapMods", []];

_display displayAddEventHandler ["KeyDown", {
    params ["", "_k", "_s", "_c", "_a"];
    [_s, _c, _a] call AP_fnc_mapPushMods;
    // Esc closes, and so does M -- the key that opened it. The native map
    // toggles on its key; this one should feel no different.
    // ...except while the page's search field has focus (mapTyping above).
    if (_k isEqualTo 1 || { _k in (actionKeys "ShowMap") && {!_s} && {!_c} && {!_a}
        && {!(uiNamespace getVariable ["AP_mapTyping", false])} }) then { closeDialog 0 };
    false
}];
_display displayAddEventHandler ["KeyUp", {
    params ["", "_k", "_s", "_c", "_a"];
    [_s, _c, _a] call AP_fnc_mapPushMods;
    false
}];

// ADMIN TELEPORT -- the grid replaces the paper-map click. Level re-checked
// here because the page's admin flag is display state, not authority; the
// confirm lives on the page. Same action log line as the old path.
[_ctrl, "mapTeleport", {
    params [["_x", -1, [0]], ["_y", -1, [0]]];
    if ((call AP_adminLevel) <= 1) exitWith { createHashMapFromArray [["ok", false], ["msg", "no"]] };
    if (_x < 0 || { _y < 0 }) exitWith { createHashMapFromArray [["ok", false], ["msg", "bad pos"]] };
    (vehicle player) setPos [_x, _y, 0];
    private _near = (allPlayers select { _x distance (vehicle player) < 800 }) apply { name _x };
    [["-ADMINACTION-", player, profileName, format ["Tped to Grid Pos: %1 - Near Players: %2.", [_x, _y], _near]],
        "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["msg", format ["teleported to %1, %2", round _x, round _y]]]
}] call webui_fnc_on;

// CTRL+click on the map: one personal waypoint, drawn in-world with live
// distance by AP_fnc_mapWpHud. Empty array clears it.
[_ctrl, "mapWaypoint", {
    params [["_x", -1, [0]], ["_y", -1, [0]]];
    if (_x < 0) then { [[]] call AP_fnc_mapWpHud } else { [[_x, _y]] call AP_fnc_mapWpHud };
    call AP_fnc_mapPushDest;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

// ALT+click: navigation coordinates. This is the SAME thing as ALT+click on the
// native map, so it goes through AP_fnc_gps "set"/"clear" -- which is what stores
// AP_gpsRoutePts, the road route the autopilot actually follows, alongside
// AP_gpsDest (what Autopilot reads) and the turn-by-turn HUD.
//
// Until 2026-09-02 this handler set AP_gpsDest and ran AP_fnc_routeFind for the
// page's drawing only; AP_gpsRoutePts was never written, so the TAB-radial
// autopilot answered "set a GPS destination first" after a nav set from this
// map (fn_gpsAutopilot refuses without >= 4 route points). Owner: "setting the
// AP marker in the map doesn't allow AP to work".
[_ctrl, "mapNav", {
    params [["_x", -1, [0]], ["_y", -1, [0]]];
    if (_x < 0) exitWith {
        ["clear"] call AP_fnc_gps;
        deleteMarkerLocal "AP_mapnav";
        call AP_fnc_mapPushDest;
        createHashMapFromArray [["ok", true], ["msg", "nav cleared"]]
    };
    ["set", [_x, _y, 0]] call AP_fnc_gps;
    // "set" leaves the old state alone when no road route exists; report that
    // rather than pretending a destination was taken.
    private _pts = missionNamespace getVariable ["AP_gpsRoutePts", []];
    private _dest = missionNamespace getVariable ["AP_gpsDest", []];
    if (_pts isEqualTo [] || { _dest isEqualTo [] } || { _dest distance2D [_x, _y, 0] > 1 }) exitWith {
        // "set" leaves the PRIOR route in place on failure, so push what is actually
        // stored: the page keeps drawing the old route rather than a new one it never got.
        call AP_fnc_mapPushDest;
        createHashMapFromArray [["ok", false], ["msg", "no road route found to there"]]
    };
    if (getMarkerColor "AP_mapnav" isEqualTo "") then {
        createMarkerLocal ["AP_mapnav", [_x, _y]];
        "AP_mapnav" setMarkerTypeLocal "mil_pickup";
        "AP_mapnav" setMarkerColorLocal "ColorGUER";
        "AP_mapnav" setMarkerTextLocal "NAV";
    } else { "AP_mapnav" setMarkerPosLocal [_x, _y] };

    // THE ROUTE the page draws IS the route the autopilot rides -- the very
    // points "set" just stored -- decimated to ~30 m verts before the trip
    // across the bridge; a full graph polyline across the island is thousands
    // of points and the drawn line cannot tell. One decimator, shared with the
    // mapDest channel, so the reply and the channel cannot draw different lines.
    ([_pts] call AP_fnc_mapRouteDecimate) params ["_route", "_len"];
    call AP_fnc_mapPushDest;

    private _out = createHashMapFromArray [["ok", true],
        ["msg", format ["nav set -- %1 km by road", (_len / 1000) toFixed 1]]];
    _out set ["route", _route];
    _out set ["routeLen", _len];
    _out
}] call webui_fnc_on;

[_ctrl, "mapStatic", (call _staticData)] call webui_fnc_push;
[_ctrl, "map",       (call _liveData)]   call webui_fnc_push;
call AP_fnc_mapPushDest;

// armed from the admin menu's Teleport button: the page starts in TP mode once
if (uiNamespace getVariable ["AP_mapTpArm", false]) then {
    uiNamespace setVariable ["AP_mapTpArm", false];
    [_ctrl, "window.__tpArm=1"] call webui_fnc_exec;
};

// The pusher. 1Hz for positions, markers every 15s -- they change rarely and
// the payload is two orders of magnitude bigger.
[_ctrl, _liveData, _staticData] spawn {
    params ["_ctrl", "_liveData", "_staticData"];
    private _n = 0;
    while { !isNull _ctrl && { !isNull (findDisplay 930430) } } do {
        [_ctrl, "map", (call _liveData)] call webui_fnc_push;
        // Destination state changed underneath the page (arrival cleared the GPS, a
        // route was set from somewhere else): one push, not one per second.
        if !((call AP_fnc_mapDestSig) isEqualTo (uiNamespace getVariable ["AP_mapDestSig", []])) then {
            call AP_fnc_mapPushDest;
        };
        _n = _n + 1;
        if (_n % 15 isEqualTo 0) then { [_ctrl, "mapStatic", (call _staticData)] call webui_fnc_push };
        uiSleep 1;
    };
};

diag_log format ["[MAP] grid ready t=%1", diag_tickTime toFixed 1];
