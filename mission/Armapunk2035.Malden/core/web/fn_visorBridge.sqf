// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only.
/*
    File: fn_visorBridge.sqf  (AP_fnc_visorBridge)  -- dialog AP_web_visor (941700) onLoad

    The VR-goggle visor HUD. Was built alongside the native vr_dock /
    fn_qhDockFill.sqf, not over them -- this is a second, independent
    presentation of the same quickhack loadout so a human can compare the two
    in-game before the native one retires. Neither vr_dock.hpp nor
    fn_qhDockFill.sqf is touched here.

    NOTHING NEW DECIDES WHETHER A QUICKHACK MAY BE CAST. This file only reads
    the catalogue (AP_fnc_qhCfg / AP_qhUtil) and the cooldown vars the existing
    system already maintains (for display only), and routes every fire through
    the SAME functions vr_dock's own catcher uses:
      - loadout hacks -> AP_fnc_qhCast -> APS_fnc_qhSRV (server runs the
        upload clock and re-validates range/target/authorisation -- see
        fn_qhSRV.sqf; a modified client cannot skip that channel)
      - civ breach tools -> the identical dispatch table
        fn_qhDockFill.sqf's MouseButtonDown handler uses (AP_fnc_cyberdeck /
        AP_fnc_cyberdeckATM / AP_fnc_qhCuffHack)
      - firewall editor -> the deck's QH app (ring_loadout is gone; see fwEdit below)
    Cooldowns, gating and eligibility all come from the catalogue row; none of
    it is recomputed here.

    CONTRACT (ui/html/visor.html):
      AP.on("visor", { side, cash, trace, deckPct, lock, items[], running[], fw })
      AP.call("qhFire",     [id])  -> { ok }
      AP.call("fwEdit",     [])    -> opens the ring-loadout firewall editor
      AP.call("visorClose", [])    -> closes the dialog
*/
// GLOBAL on purpose, not a private closure: it is read from inside _data,
// which is itself called much later from other scopes (the qhFire handler,
// the refresh loop below) via uiNamespace. A private var from THIS scope is
// not something later code should depend on reaching into -- same pattern
// fn_qhDockFill.sqf uses for AP_fnc_vrMag (a global defined inline, no
// Functions.h entry; defined once, at client init via "boot").
if !(isFinal "AP_fnc_visorCdText") then {AP_fnc_visorCdText = compileFinal {
    params ["_cd"];
    if (_cd <= 0) exitWith { "--" };
    if (_cd >= 60) exitWith { format ["%1m", round (_cd / 60)] };
    format ["%1s", _cd]
}};
// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helper above is
// defined (final) before another client can publicVariable a final copy of it first.
if (_this isEqualTo "boot") exitWith {};

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;

private _ctrl = _display displayCtrl 941701;
if (isNull _ctrl) exitWith { diag_log "[VISOR] control missing" };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[VISOR] bridge init failed" };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\visor.html"] call webui_fnc_serve;

AP_visorOpen = true;

private _data = {
    private _cop = AP_effSide isEqualTo west;
    private _tgt = missionNamespace getVariable ["AP_cdTarget", objNull];
    private _cat = [if (_cop) then { "cop" } else { "civ" }] call AP_fnc_qhCfg;
    if (!_cop) then { _cat = _cat + AP_qhUtil; };

    // ---- loadout plates: the console's saved 6, breach ids pulled out below
    // (matches fn_qhDockFill.sqf's own split of _cat into offense vs breach) ----
    private _items = [];
    private _running = [];
    {
        private _id = _x;
        if !(_id in ["unlock", "house", "atm", "cuffs"]) then {
            private _row = (_cat select { (_x select 0) isEqualTo _id }) param [0, []];
            if (_row isNotEqualTo []) then {
                _row params ["", "_nm", "", "", "", "_up", "_cd", "_rng"];
                private _cdLeft = (missionNamespace getVariable [("AP_qhCd_" + _id), 0]) - diag_tickTime;
                if (_cdLeft > 0) then { _running pushBack _id; };
                _items pushBack (createHashMapFromArray [
                    ["id", _id], ["name", _nm],
                    ["tone", AP_qhTone getOrDefault [_id, "acc"]],
                    ["kind", "cast"],
                    ["cost", _up],   // the mock's "RAM" pip; there is no RAM resource in this build (PATTERNS.md's
                                      // own Pattern-G correction: "No RAM, no heat") -- repurposed to the upload
                                      // seconds, a real catalogue lever, rather than inventing one. Matches the
                                      // mock's own fake data exactly for every breach tool (upload 0 -> cost 0).
                    ["stat", format ["%1s up · %2 cd · %3m", _up, [_cd] call AP_fnc_visorCdText, _rng]]
                ]);
            };
        };
    } forEach (call AP_fnc_qhConsoleGet);

    // ---- civ breach tools: same 4 ids AP_qhUtil / the old dock use ----
    if (!_cop) then {
        {
            private _bid = _x;
            private _row = (_cat select { (_x select 0) isEqualTo _bid }) param [0, []];
            if (_row isNotEqualTo []) then {
                _items pushBack (createHashMapFromArray [
                    ["id", _bid], ["name", _row select 1],
                    ["tone", AP_qhTone getOrDefault [_bid, "util"]],
                    ["kind", "breach"], ["cost", 0],
                    ["stat", "breach tool · free"]
                ]);
            };
        } forEach ["unlock", "house", "atm", "cuffs"];
    };

    private _pairs = [
        ["side",    if (_cop) then { "cop" } else { "civ" }],
        ["cash",    AP_cash],
        // fn_qhDockFill.sqf's own HUD strip hardcodes both of these too (no
        // live trace-window var and no deck-battery meter exist client-side
        // yet) -- matched here rather than inventing either subsystem.
        ["trace",   "CLEAR"],
        ["deckPct", 64],
        ["items",   _items],
        ["running", _running],
        ["fw",      format ["%1/2", count (call AP_fnc_fwEquipped)]]
    ];
    // lock is OMITTED (not nulled) when there is no gaze target, so the page's
    // own `L ? ... : ...` check (visor-quickhacks.html) sees it as falsy --
    // matches the mock's own null-lock contract.
    if (!isNull _tgt) then {
        private _isMan = _tgt isKindOf "CAManBase";
        private _los = (count (lineIntersectsSurfaces [eyePos player, aimPos _tgt, player, _tgt, true, 1, "VIEW", "GEOM"])) isEqualTo 0;
        private _status = if (_isMan) then {
            if ((vehicle _tgt) isEqualTo _tgt) then { "on foot" } else { "in vehicle" }
        } else {
            if (isNull (driver _tgt)) then { "empty" } else { format ["driver: %1", name (driver _tgt)] }
        };
        _pairs pushBack ["lock", createHashMapFromArray [
            ["name",    if (_isMan) then { name _tgt } else { getText (configOf _tgt >> "displayName") }],
            ["kind",    if (_isMan) then { "person" } else { "vehicle" }],
            ["dist",    round (player distance _tgt)],
            ["status",  _status],
            ["los",     _los],
            ["inRange", true]   // fn_qhDockFill.sqf's own lock card hardcodes this too -- there is no single
                                 // "visor range" to check (range is per-hack, already in each plate's stat line)
        ]];
    };
    createHashMapFromArray _pairs
};

[_ctrl, "visor", _data] call webui_fnc_on;

// ---- qhFire: identical dispatch table to vr_dock's catcher (fn_qhDockFill.sqf
// MouseButtonDown). Cast hacks go through AP_fnc_qhCast unmodified; breach
// tools go through the same three functions, same target, same grace sleep. ----
[_ctrl, "qhFire", {
    params [["_id", "", [""]]];
    if (_id in ["unlock", "house", "atm", "cuffs"]) then {
        [_id] spawn {
            params ["_id"];
            uiSleep 0.1;
            private _bt = missionNamespace getVariable ["AP_cdTarget", objNull];
            switch (_id) do {
                case "atm":   { [_bt] spawn AP_fnc_cyberdeckATM; };
                case "cuffs": { [] spawn AP_fnc_qhCuffHack; };
                default       { [_bt] spawn AP_fnc_cyberdeck; };
            };
        };
    } else {
        [_id] call AP_fnc_qhCast;
    };
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "visor", (call (uiNamespace getVariable "AP_visorData"))] call webui_fnc_push; };
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

[_ctrl, "fwEdit", {
    // Chip slotting lives in the deck QH app's DECK card. ring_loadout (941400)
    // was the old destination and was DELETED 2026-09-04 with the rest of the
    // retired cyberdeck cluster. Close the visor first: every web bridge here
    // assumes exactly one WEBUI_ctrl singleton is live at a time.
    closeDialog 0;
    [] spawn {
        closeDialog 0;
        uiSleep 0.12;
        [["TAL OS", "ICEBREAKER OS"] select (AP_effSide isEqualTo civilian)] call AP_fnc_deckOpenApp;
    };
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

[_ctrl, "visorClose", {
    closeDialog 0;
    createHashMapFromArray [["ok", true]]
}] call webui_fnc_on;

uiNamespace setVariable ["AP_visorData", _data];

_display displayAddEventHandler ["KeyDown", { params ["", "_k"]; if (_k isEqualTo 1) then { closeDialog 0; }; false }];
_display displayAddEventHandler ["Unload", { AP_visorOpen = false; }];

[_ctrl, "visor", (call _data)] call webui_fnc_push;

// ---- TARGET BOX: a reticle that tracks the locked target in screen space -----
// Its own channel, and its own loop, because it has to be FAST. The "visor"
// payload below refreshes every 1.5s -- correct for distance and cooldowns, and
// hopeless for a box meant to sit on a moving target. A box lagging a second and
// a half behind reads as broken, not as a HUD.
//
// So: a small dedicated payload at ~25 Hz on the "lockbox" channel, while the
// heavy one stays slow. Nothing else about the existing push changes.
//
// SIZE comes from projecting the target's own bounding box, not from a fixed
// radius scaled by distance. Eight corners, min/max in screen space, and the box
// is then correct for a man, a hatchback and a helicopter without a per-class
// table -- and it shrinks with distance for free because the projection does it.
//
// COORDINATES are converted to page percentages HERE rather than in the page.
// worldToScreen returns SCREEN space, and the browser control covers the
// SAFEZONE, which is not the same rectangle -- on a 21:9 display it is visibly
// not. Converting where safezoneX/W are already in scope keeps the page ignorant
// of Arma's screen model, which is the whole point of the bridge.
//
// The box hides on: no target, dead target, target off-screen or behind the
// camera (worldToScreen returns []), and LOS broken -- the last being what was
// asked for. LOS uses the same lineIntersectsSurfaces call the lock card above
// already makes, so the card and the box can never disagree about visibility.
[] spawn {
    private _lastVis = false;
    while { !isNull (findDisplay 941700) } do {
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        private _tgt = missionNamespace getVariable ["AP_cdTarget", objNull];
        private _show = false;
        private _box = [0, 0, 0, 0];

        if (!isNull _c && {!isNull _tgt} && {alive _tgt}) then {
            // Same visibility test as the lock card. VIEW+GEOM, ignoring both
            // ends, so the target's own hull does not count as an occluder.
            private _los = (count (lineIntersectsSurfaces
                [eyePos player, aimPos _tgt, player, _tgt, true, 1, "VIEW", "GEOM"])) isEqualTo 0;
            if (_los) then {
                (boundingBoxReal _tgt) params ["_bmin", "_bmax"];
                private _xs = []; private _ys = [];
                {
                    private _w = _tgt modelToWorldVisual _x;
                    private _s = worldToScreen _w;
                    if (count _s isEqualTo 2) then {
                        _xs pushBack (_s select 0); _ys pushBack (_s select 1);
                    };
                } forEach [
                    [_bmin select 0, _bmin select 1, _bmin select 2], [_bmax select 0, _bmin select 1, _bmin select 2],
                    [_bmin select 0, _bmax select 1, _bmin select 2], [_bmax select 0, _bmax select 1, _bmin select 2],
                    [_bmin select 0, _bmin select 1, _bmax select 2], [_bmax select 0, _bmin select 1, _bmax select 2],
                    [_bmin select 0, _bmax select 1, _bmax select 2], [_bmax select 0, _bmax select 1, _bmax select 2]
                ];
                // Every corner off-screen means the target is behind the camera or
                // past its edge. Partially-visible is fine and still tracks.
                if (count _xs > 1) then {
                    private _x0 = selectMin _xs; private _x1 = selectMax _xs;
                    private _y0 = selectMin _ys; private _y1 = selectMax _ys;
                    // screen -> the control's own rectangle, as percentages
                    private _px = { ((_this - safezoneX) / safezoneW) * 100 };
                    private _py = { ((_this - safezoneY) / safezoneH) * 100 };
                    _box = [_x0 call _px, _y0 call _py,
                            ((_x1 - _x0) / safezoneW) * 100, ((_y1 - _y0) / safezoneH) * 100];
                    // A box that fills the screen is a projection artefact from a
                    // target the camera is inside of; drop it rather than draw it.
                    _show = ((_box select 2) < 90) && {(_box select 3) < 90};
                };
            };
        };

        if (!isNull _c) then {
            if (_show || _lastVis) then {   // one final push to hide it, then go quiet
                [_c, "lockbox", createHashMapFromArray [
                    ["on", _show], ["x", _box select 0], ["y", _box select 1],
                    ["w", _box select 2], ["h", _box select 3]
                ]] call webui_fnc_push;
            };
            _lastVis = _show;
        };
        uiSleep 0.04;   // ~25 Hz: smooth enough to read as tracking, cheap enough
                        // that it is not a per-frame ExecJS
    };
};

// ---- live refresh while open: distance/LOS/cash/cooldowns move even though
// the gaze target itself is a freeze-frame -- same 1.5s idiom
// AP_fnc_qhConsole's own refresh loop already uses for its tiles/scope. ----
[] spawn {
    while { !isNull (findDisplay 941700) } do {
        uiSleep 1.5;
        if (isNull (findDisplay 941700)) exitWith {};
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "visor", (call (uiNamespace getVariable "AP_visorData"))] call webui_fnc_push; };
    };
};

diag_log "[VISOR] ready";
