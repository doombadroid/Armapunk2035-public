/*
    AP_fnc_hudWebPush -- put one "hud" payload into the STATUS HUD layer page (ui\html\hud.html).

        [] call AP_fnc_hudWebPush;          // the full payload, channel "hud"
        ["fast"] call AP_fnc_hudWebPush;    // pos + dir only, channel "hudmap"

    THE PAGE DEFINES THE CONTRACT and this file matches it, adding nothing:

        AP.on("hud", { hp, h2o, food,     // 0-100
                       wanted,            // bounty in dollars, 0 = the plate is hidden
                       paused, regen,     // booleans, the two status chips
                       map: { dir,        // heading in degrees, 0 = north
                              pos,        // [x, y] in world metres
                              zoom,       // metres across the 13rem box
                              marks,      // [{ x, y, kind, name? }] ("veh" may add dir)
                              tiles } })  // { base, ext, tileMeters, worldSize,
                                          //   grid, flipRow, pad, ov, res, hf }

        AP.on("hudmap", { dir, pos })       // PR15: the fast lane, and nothing else

    ---- PR15: TWO LANES, BECAUSE ONE RATE CANNOT SERVE BOTH HALVES ------------------------

    The owner's report was that the panel does not track him one to one. It could not: every
    part of the payload moved at ONE rate, and that rate was set by the slowest thing in it.
    Vitals change on an event; a heading changes continuously.

    So pos and dir have their OWN channel and their own change gate now, and the keeper offers
    them between the full pushes (fn_hudWebInit's inner loop). The numbers, measured rather
    than guessed -- one full payload with four group members, four med sites and a waypoint
    against one fast payload, both through the toJSON + ToBase64 + format[] that
    webui_fnc_push actually emits:

        full   802 B JSON -> 1072 B base64 -> 1110 B ExecJS statement   at 4 Hz
        fast    30 B JSON ->   40 B base64 ->   81 B ExecJS statement   at 8 Hz

    4440 B/s becomes 5088 B/s and 4 calls/s becomes 12: +14.6% bytes for THREE TIMES the
    motion resolution, and still a fifth of what a 60 fps per-frame push would cost. The full
    payload's own rate is UNCHANGED at 4 Hz, so nothing that was proven at that rate is being
    re-bet -- the change is purely the eight small ones added between them.

    THE TWO GATES ARE KEPT IN STEP. A full push that goes out also stamps the fast gate, so
    the fast lane never re-sends a position the full payload just carried, and a standing
    player still costs zero ExecJS on both channels.

    EVERY PUSH IS A FULL PAYLOAD, and that is a requirement of the page, not a style choice.
    Its handler reads the vitals defensively (`if typeof d[k] === 'number'`) but assigns the
    chips flatly -- `S.paused = !!d.paused` -- so a partial push that left them out would turn
    both chips off. There is no such thing as a partial "hud" payload -- which is exactly why
    the fast lane is a SEPARATE CHANNEL with its own handler rather than a thinner "hud".

    DISPLAY ONLY. Nothing here reads a player's input, writes a variable the game acts on, or
    reaches the server; it is a second rendering of state the client already has locally.

    EVERY VITAL COMES FROM THE SAME PLACE THE NATIVE HUD READS IT, deliberately, so the two
    HUDs can never disagree while they are both on screen:

      hp      ceil(round((1 - damage player) * 100))        -- fn_hudUpdate.sqf:12, verbatim
      h2o     APV_thirst                                    -- fn_hudUpdate.sqf's H2O bar
      food    APV_hunger                                    -- fn_hudUpdate.sqf's FOOD bar
      wanted  civilians only: A_stats_crimes select 0        -- fn_hudUpdate.sqf, verbatim,
              and 0 for anyone on a MaxSec or Trauma shift, exactly as the native WANTED bar
              hides itself for them.
      dir     getDir vehicle player  -- the same expression fn_hudUpdate already persists as
              profileNamespace "AP_playerDir", so the compass and that slot cannot disagree.

    APV_thirst AND APV_hunger ARE CLAMPED HERE, and that is not defensive noise: fn_survival's
    walk-distance branch subtracts 5 from each with no selectMax, so both genuinely go
    negative. The native bars clamp the same way when they draw ("(0 max _val) min 100"), so
    this clamp makes the pushed contract match what the player is already looking at rather
    than inventing a value.

    PAUSED is the meters ACTUALLY being paused, not a guess at it. fn_survival gates both drain
    ticks on `isNull (findDisplay 38500) && !(player getVariable "AP_restrained")` -- the
    spawn-select map being open, or being cuffed. Those two clauses are what the chip reports,
    so it lights exactly when hunger and thirst have genuinely stopped falling.

    REGEN IS READ, NOT RECOMPUTED. The health-regen tick's seven-clause predicate lives in
    fn_survival's _fnc_regen and now publishes AP_regenActive from that one evaluation. Copying
    those clauses into this file was the alternative and was rejected: a second copy of a
    predicate is the drift this repo keeps paying for, and a status chip that lies about a
    state the player cannot otherwise see is worse than no chip.

    ---- THE MINIMAP, AND EXACTLY HOW FAR IT IS WIRED ----------------------------------------

    The minimap arrived in a REVISION of the designer's page part-way through this work; the
    brief it was written against specified the six vitals fields only. What is wired here is
    the half that can be fed correctly from state this client already holds, and the rest is
    left visibly empty rather than filled with a guess. Specifically:

      WIRED   dir / pos / zoom, so the compass, the 100 m grid, the range rings and the north
              marker are all truthful and live.
      WIRED   marks of kind "group" (living members of the player's group, which the client
              knows locally) and kind "wp" (AP_mapWaypoint, the one custom waypoint
              AP_fnc_mapWpHud already maintains and already draws in 3D and on the M map).
      WIRED   marks of kind "med", the four med_spawn_* hospital sites, resolved ONCE per
              session -- see the block below for why a fourth copy of that name list is the
              least-bad option and how it is made self-invalidating.
      WIRED   a `name` on every mark that HAS a source for one (PR14), which the page draws
              beside the icon when the player is within 500 m of it:
                group   name _x, cleaned through AP_fnc_cleanName exactly as fn_hudUpdate's
                        bounty row cleans a player name, and cached on the unit.
                med     the site names that already sit BESIDE those four marker names in
                        dialog\function\fn_spawnPointCfg.sqf's independent case -- Main
                        Hospital / La Port / Chapoi / La Pessagne. NOT markerText: the four
                        med_spawn_* markers are captioned "Garage" (they name the vehicle garage
                        at the site), so reading the engine here would label every hospital
                        "Garage". This makes the fourth copy a PAIRED list rather than a longer
                        one; the same four pairs are already spelled out in
                        core\medical\fn_medicFireClient.sqf, so the pairing is not new either.
                wp      NOTHING, deliberately. AP_mapWaypoint is [x, y] and carries no label;
                        the local marker fn_mapWpHud creates is captioned "WP", which is what
                        the page's own diamond glyph already says. A nameless mark renders
                        exactly as it did before, so this one just has no label.
              The 500 m test is done in the PAGE, not here, and that is the cheap way round: the
              page already computes each mark's distance for its own edge-clamp, while gating it
              here would make the payload flip at the boundary and defeat the change gate --
              a player walking a 500 m line would push on every tick.
      NOT WIRED  marks of kind shop / gas / garage / atm / gang / quest / enemy / veh. This is
              a finding, not a shortcut: THIS MISSION HAS NO POI SYSTEM. There is no
              AP_hospitals, AP_atmLocations, AP_fuelStations, AP_garages or AP_shops anywhere
              in mission\ or server\, and no getMarkerPos "atm_*" / "gas_*" / "med_*" call
              either. What each kind would have had to come from, and why it does not:
                gas     nothing at all. One NPC, zero markers. The engine's own
                        nearestTerrainObjects [..., ["FUELSTATION"], ...] is never called
                        anywhere in this repo, so wiring it would mean introducing an untested
                        source, not reading an existing one.
                garage  six markers carry text "Garage" -- but four of them ARE med_spawn_1..4,
                        because the text names the vehicle garage AT the site, not the site.
                        Categorising on it would print a garage pin on every hospital.
                atm     one marker on the whole map, against ten placed ATM objects, and
                        fn_setupActions' own ATM gate names Altis classes that do not exist on
                        Malden. "Where are the ATMs" has no correct answer in-game today.
                shop    fn_virt_shops has the type catalogue but no positions; edenNPC_data.sqf
                        has 61 positioned NPCs but is GENERATED tooling input and is not loaded
                        at runtime at all.
                gang    AP_gangMembersList rows are [uid, name, rank] with NO position, filled
                        by a 10 s rate-limited server round-trip. Group blips are free because
                        the engine syncs group members; gang blips are simply not available.
              A HUD that shows a hospital where there is none is worse than one that shows no
              hospitals, so each of these draws nothing rather than something invented.

    THE med LIST IS A FOURTH COPY OF FOUR MARKER NAMES, AND THAT IS DELIBERATE. The same four
    live in core\duty\fn_dutyCfg.sqf, dialog\function\fn_spawnPointCfg.sqf and
    core\medical\fn_medicFireClient.sqf, each with a comment asking the next person to keep
    them in step -- so adding a fourth is not free. The two alternatives are worse:

      * calling [independent] call AP_fnc_spawnPointCfg would read the list from the one place
        that owns it, but that function does not return it cleanly to a caller who is not a
        medic: it then filters by AP_disabled_spawns when AP_effSide is west or civilian, and
        pushes an "Evidence Lockup" row into the SAME array when AP_effSide is west and the
        evidence laptop is up. A cop looking at this HUD would get the evidence lockup drawn
        as a hospital.
      * sweeping markerType "loc_Hospital" reads the engine instead of a list, but Malden has
        only three of them, they sit on med_spawn_2/3/4 and not on the main hospital, and all
        three are captioned "Fire Station". Three-quarters of the sites, mislabelled.

    So the copy stays, and it is made SELF-INVALIDATING instead: getMarkerPos returns [0,0,0]
    for a marker that does not exist, which is the exact trap all three sibling comments were
    written about, so a name that stops resolving is DROPPED rather than drawn at the map
    origin. Rename or delete the markers and this HUD shows fewer hospitals, never a wrong one.
    It is resolved once per session and cached, because markers do not move and re-resolving
    four of them at 4 Hz would be pure waste.
      NOT WIRED  zoom control. It is pushed as a constant 500 because the page has no verb to
              change it and this shim gives it no way to call SQF.

    ---- TILES: THE ENGINE'S OWN SATELLITE LAYER, ADDRESSED DIRECTLY. NO BAKE. ----------------

    PR13 shipped tile-LESS and said a bake was a separate follow-up. PR14 found that no bake is
    needed, because the imagery the owner asked for -- "the 3d map from the main map" -- is not
    generated by the 3D map at all. The 3D map READS it, out of the game's own PBOs:

        map.html:673-675   tilePath(c,r) = "a3\map_malden\data\layers\s_"+pad3(c)+"_"+pad3(r)+"_lco.paa"
        map.html:703       A3API.RequestTexture(tilePath(c,r), res).then(...)
        warm.html:14-17    the SAME 169 paths, pre-converted at every connect, at maxSize 128 and 256

    That is an existing, addressable asset set, so the minimap is pointed straight at it and
    tiles ship ON. Three things make it nearly free rather than merely possible:

      * warm.html ALREADY PAID FOR IT. core\init.sqf:60 cuts AP_map_warm eight seconds into the
        session and it pulls all 169 tiles through RequestTexture at 128 and 256. This asks for
        256, so on a warmed client the conversion is a cache hit.
      * IT IS PROVEN IN A TITLE LAYER. AP_map_warm is itself an RscTitles webview calling
        RequestTexture, which is the same host leg this HUD runs on. Nothing new is being bet on.
      * THE PANEL IS TINY. 13 rem across at zoom 500 is 750 m of ground against a 984.6 m tile
        step, so the pool holds 1-4 images and the page evicts the rest itself.

    THE FIVE NUMBERS THE PAGE NEEDS, and why each one is a real field rather than a constant:

      grid     13. Tiles per side, stated rather than divided back out of worldSize. It replaces
               the page's Math.ceil(worldSize/tileMeters)-1, which is a float round-trip through
               a number this file just divided: measured over 54 plausible worldSize x grid
               pairs it lands one row PAST the map edge on two of them. Malden's 12800/13 is NOT
               one of them -- both forms give 12 -- so this removes a dependence on that luck
               rather than fixing a live off-by-one. Said plainly because the alternative was to
               claim a bug that is not there.
      flipRow  true. The page's ty counts NORTH from 0 at the south edge; the game's layer rows
               count from the NORTH edge (s_012_000_lco.paa is the north-EAST corner). Without
               the flip the island renders upside down and every blip is wrong.
      pad      3. The layer names are zero-padded and the page was not padding at all.
      ov       16/512. Terrain Builder cuts the layer with a 16 px overlap per edge on a 512 px
               tile, so ONE IMAGE COVERS MORE GROUND THAN ONE TILE STEP -- 1050.3 m, not 984.6.
               Drawn at tileMeters it would sit ~6.7% small under the blips, which at this zoom
               is a ~33 m error at the tile seams. The page inflates and offsets by it instead.
               map.html does the same crop the other way round (its `ov = OV_PX*sc`, line 719).
      res      256. The mip RequestTexture is asked for -- and the one warm.html preconverts.
      hf       ui\html\malden_hf.txt. PR15, and it is the whole of "show water instead of
               sand". THE SATELLITE LAYER HAS NO SEA IN IT: Arma composites the water surface
               at draw time, so s_*_lco.paa paints the SEABED, and on Malden the seabed is
               sand. A page that draws the layer raw paints every square metre of ocean
               sand-coloured, which is precisely what the owner was looking at. THE TILE
               MAPPING WAS NEVER WRONG -- it fetches and places the same tile map.html does,
               at every position; map.html simply does not draw the layer raw either, it draws
               its own water pass over it (map.html:334 buildWater / :257 watP).
               This is the path to the heightfield map.html ALREADY reads (map.html:1392), so
               the page can mask the sea from the one source that knows where it is. No bake
               and no new asset: the file is already in the PBO, and it is fetched through the
               same A3API.RequestFile leg the page's own shim uses for webui.js. Empty = no
               water layer, and the panel is exactly what PR14 shipped.

    All five are OPTIONAL in the page and all five default to the old behaviour, so an unpadded,
    south-first custom bake still works exactly as PR13 documented it.

    EVERY ONE IS A PLAIN MISSION VARIABLE, so the console overrides any of them live, and
    AP_hudWebTileBase = "" is still the off switch back to the marks-only panel:

        AP_hudWebTileBase / Ext / Grid / FlipRow / Pad / Ov / Res / Meters / Hf

    WORLD-GATED. The defaults resolve once, and only on Malden -- worldName is the gate. Another
    world has no known layer path, so it emits no `tiles` member at all and the panel degrades to
    exactly what PR13 shipped rather than to a pool of broken images. Same shape as the med
    resolver above: an unknown source draws nothing instead of something invented.

    THE TWO PAGE-SIDE DEFECTS PR13 DOCUMENTED ARE FIXED, IN THE PAGE. Byte-preservation of the
    designer's file was waived for the HUD page by the owner in favour of function, so both are
    repaired at source rather than worked around:
      1. tileURL() assigned A3API.RequestTexture(name) straight into img.src, but that call is a
         PROMISE in this host -- so the src stringified to "[object Promise]" and no tile could
         ever have loaded. It is tileSrc(img,...) now and resolves the promise.
      2. It did not zero-pad. It does, when `pad` is set.

    worldSize IS THE ENGINE'S OWN, from the `worldSize` command, and tileMeters is DERIVED from
    it (worldSize / grid) rather than written down, so the imagery and the blips cannot disagree
    about how big the island is.

    THE CHANGE GATE AND THE RATE. Two callers offer a payload: AP_fnc_hudUpdate's tail
    (immediately, on every native refresh -- every damage / eat / drink / wanted event in the
    mission) and the keeper's 5 Hz tick. 5 Hz is set by the COMPASS, not by the vitals: a
    heading that updates once a second is unreadable while turning. Nothing is sent when the
    payload is identical to the last one that went out, and dir is rounded to the degree and
    positions to the metre precisely so that a standing player's payload really is identical
    and really does cost zero ExecJS. A moving player costs at most five one-way ExecJS calls a
    second, which is the deck's own push-loop order of magnitude and nothing like per-frame.

    SAFE TO CALL UNSCHEDULED. AP_fnc_hudUpdate is `call`ed from ~30 sites, plenty of them
    unscheduled event handlers, so nothing on this path may suspend: webui_fnc_push is a
    toJSON, a ToBase64 and a webui_fnc_exec, and webui_fnc_exec either issues ExecJS or pushes
    onto the control's queue. No uiSleep, no waitUntil, no spawn.
*/
disableSerialization;
// "fast" = pos and dir only. Defaulted through params so the ~30 `[] call` sites -- and
// fn_hudUpdate's tail, the only one outside this feature -- keep meaning "full", unchanged.
//
// PR-HUDEDIT: a third mode, "edit", and an optional TARGET CONTROL. The HUD UI EDITOR
// (hudeditor.md) shows the same page in a dialog, and it needs the WANTED plate and the status
// chips visible so both can be placed -- #wplate is display:none until the page is told there is
// a bounty, and #chips is empty until it is told about regen or a pause, so a player with a clean
// record would find two of the seven handles simply absent. "edit" forces all three on and skips
// the change gate. It is built HERE rather than in the editor so that the tile configuration, the
// marker kinds and the zoom stay in the one file that knows about them.
params [["_mode", "full", [""]], ["_ctrlIn", controlNull, [controlNull]]];
private _c = if (isNull _ctrlIn) then {
    uiNamespace getVariable ["AP_hudWebCtrl", controlNull]                // uiNamespace: controls do not serialize
} else { _ctrlIn };
if (isNull _c) exitWith { false };            // layer not up: the native HUD is the HUD
if (!alive player) exitWith { false };
private _edit = (_mode isEqualTo "edit");

// ---- position and heading, read FIRST because the fast lane is only these two ------------
private _p = getPosATL player;                 // x and y ARE world metres; only z is relative
private _dir = round (getDir vehicle player);
if (_dir >= 360) then { _dir = 0 };            // round(359.7) is 360, which the page renders as 360 deg
private _pos = [round (_p select 0), round (_p select 1)];
// Its own gate, its own variable, and rounded exactly as the full payload rounds them -- so a
// standing player's fast payload is identical to the last one and costs zero ExecJS too.
private _fastSig = str [_dir, _pos];

if (_mode isEqualTo "fast") exitWith {
    if (_fastSig isEqualTo (missionNamespace getVariable ["AP_hudWebLastPos", ""])) then { false } else {
        AP_hudWebLastPos = _fastSig;
        [_c, "hudmap", createHashMapFromArray [["dir", _dir], ["pos", _pos]]] call webui_fnc_push
    }
};
// The four globals below are read BARE, the same way fn_hudUpdate reads them, because reading
// them any other way would be a second definition of what the native HUD shows. They are all
// set during client init, well before the keeper starts -- but an undefined-variable throw in
// here would be raised inside the keeper's `while {true}`, which kills the loop for the rest of
// the session, so the one tick where that could happen exits instead.
if (isNil "APV_thirst" || {isNil "APV_hunger"} || {isNil "AP_effSide"} || {isNil "A_stats_crimes"}) exitWith { false };

private _hp = ceil (round ((1 - (damage player)) * 100));
private _h2o = (0 max APV_thirst) min 100;
private _food = (0 max APV_hunger) min 100;
private _wanted = if (AP_effSide isEqualTo civilian) then { (A_stats_crimes param [0, 0]) max 0 } else { 0 };
private _paused = !(isNull (findDisplay 38500)) || { player getVariable ["AP_restrained", false] };
private _regen = missionNamespace getVariable ["AP_regenActive", false];

// The editor's three forced values. Not a fake payload -- the vitals, the position and the whole
// minimap half below are the player's real ones, so what is being arranged is the real HUD; only
// the three things that HIDE elements are overridden.
if (_edit) then {
    _wanted = _wanted max 125000;   // four of the five bounty pips lit, so the plate is at full width
    _paused = true;
    _regen  = true;
};

// ---- the minimap half ---------------------------------------------------------------------
// _p / _dir / _pos are already read, at the top: the fast lane needs them and nothing else.
private _marks = [];
private _markSig = [];                         // flat and ordered, for the change gate below
// PR14: every mark that HAS a name carries one, and the page draws it beside the icon inside
// 500 m. The clean is the same call fn_hudUpdate already uses to put a player name into markup
// (its bounty row: [_bountyName] call AP_fnc_cleanName), which replaces < > " & with "-" --
// exactly the characters that would otherwise reach the page's innerHTML. The page escapes as
// well, because a page must not trust its payload, but this keeps both HUDs printing one name.
// CACHED ON THE UNIT, local setVariable, no network: AP_fnc_cleanName walks the string a
// character at a time and this loop runs at 4 Hz, while a player's name cannot change
// mid-session. First sight is the only cost, and the cache dies with the object.
{
    if (!(_x isEqualTo player) && { alive _x }) then {
        private _mp = getPosATL _x;
        private _mx = round (_mp select 0);
        private _my = round (_mp select 1);
        private _cn = _x getVariable ["AP_hudWebName", ""];
        if (_cn isEqualTo "") then {
            _cn = [name _x] call AP_fnc_cleanName;
            _x setVariable ["AP_hudWebName", _cn];
        };
        _marks pushBack (createHashMapFromArray [["x", _mx], ["y", _my], ["kind", "group"], ["name", _cn]]);
        _markSig append [_mx, _my, "group", _cn];
    };
} forEach (units group player);

// Static marks: resolved ONCE per session and cached, because markers do not move. The
// [0,0,0] guard is the self-invalidation described in the header -- a marker that is renamed
// away resolves to the map origin, and a hospital pin in the sea is exactly the failure the
// three sibling copies of this name list were commented about.
if (isNil "AP_hudWebStatic") then {
    private _st = [];
    {
        _x params ["_mkr", "_nm"];
        private _mp = getMarkerPos _mkr;
        if (!(((_mp select 0) isEqualTo 0) && { (_mp select 1) isEqualTo 0 })) then {
            _st pushBack [round (_mp select 0), round (_mp select 1), "med", _nm];
        };
    } forEach [["med_spawn_1", "Main Hospital"], ["med_spawn_2", "La Port"],
               ["med_spawn_3", "Chapoi"], ["med_spawn_4", "La Pessagne"]];
    AP_hudWebStatic = _st;
    diag_log format ["[HUDWEB] static marks resolved: %1 of 4 med sites", count _st];
};
{
    _marks pushBack (createHashMapFromArray [["x", _x select 0], ["y", _x select 1], ["kind", _x select 2], ["name", _x select 3]]);
    _markSig append _x;
} forEach AP_hudWebStatic;

private _wp = missionNamespace getVariable ["AP_mapWaypoint", []];
if (_wp isNotEqualTo []) then {
    private _wx = round (_wp select 0);
    private _wy = round (_wp select 1);
    _marks pushBack (createHashMapFromArray [["x", _wx], ["y", _wy], ["kind", "wp"]]);
    _markSig append [_wx, _wy, "wp"];
};

private _map = createHashMapFromArray [
    ["dir",   _dir],
    ["pos",   _pos],
    ["zoom",  500],
    ["marks", _marks]
];

// Tiles are emitted only when a bake has been pointed at, and BOTH halves have to be set --
// see the header. Off by default, which is what this PR ships, and what drawTiles() treats as
// its defined empty state rather than as an error.
// The defaults are resolved ONCE and are world-gated: a world with no known layer emits no
// tiles at all rather than a pool of images that can never load. Every field is still a plain
// mission variable, so the console overrides all of them, and AP_hudWebTileBase = "" is still
// the off switch that returns the panel to PR13's marks-only state.
if (isNil "AP_hudWebTileDef") then {
    AP_hudWebTileDef = if ((toLower worldName) isEqualTo "malden") then {
        //  base                             ext          grid  flipRow  pad  ov         res  hf
        ["a3\map_malden\data\layers\s_", "_lco.paa",  13,   true,    3,   16 / 512,  256, "ui\html\malden_hf.txt"]
    } else {
        ["", "", 0, false, 0, 0, 0, ""]
    };
    diag_log format ["[HUDWEB] tiles: %1",
        if ((AP_hudWebTileDef select 0) isEqualTo "") then {
            format ["OFF -- world %1 has no known satellite layer", worldName]
        } else {
            // Review-minor: worldSize and the tileMeters it derives are IN this line now -- a
            // wrong worldSize misaligns the imagery under the blips with nothing else to show it.
            format ["%1<col>_<row>%2, %3x%3, worldSize %4, tileMeters %5", AP_hudWebTileDef select 0, AP_hudWebTileDef select 1, AP_hudWebTileDef select 2, worldSize, worldSize / (AP_hudWebTileDef select 2)]
        }];
};
AP_hudWebTileDef params ["_dBase", "_dExt", "_dGrid", "_dFlip", "_dPad", "_dOv", "_dRes", "_dHf"];

private _tileBase = missionNamespace getVariable ["AP_hudWebTileBase", _dBase];
private _tileGrid = missionNamespace getVariable ["AP_hudWebTileGrid", _dGrid];
// tileMeters is DERIVED from the engine's own worldSize and the grid, not written down: the two
// have to agree or the imagery walks out from under the blips, and worldSize is already emitted
// below from the same command.
private _tileMeters = missionNamespace getVariable ["AP_hudWebTileMeters",
    if (_tileGrid > 0) then { worldSize / _tileGrid } else { 0 }];
private _tileRes = missionNamespace getVariable ["AP_hudWebTileRes", _dRes];
private _tileHf = missionNamespace getVariable ["AP_hudWebTileHf", _dHf];
private _tileSig = "";
if (_tileBase isNotEqualTo "" && { _tileMeters > 0 }) then {
    // Review-minor: res is IN the signature now. The page's tilePool is keyed tx_ty_res the
    // same way, so a live AP_hudWebTileRes console edit invalidates the pool on its very next
    // render instead of waiting on tiles to scroll out and get evicted.
    // hf is in the signature for the same reason res is: a live console edit has to reach the
    // page, and the page only asks for the heightfield once per session.
    _tileSig = format ["%1|%2|%3|%4", _tileBase, _tileMeters, _tileRes, _tileHf];
    _map set ["tiles", createHashMapFromArray [
        ["base",       _tileBase],
        ["ext",        missionNamespace getVariable ["AP_hudWebTileExt", _dExt]],
        ["tileMeters", _tileMeters],
        ["worldSize",  worldSize],
        ["grid",       _tileGrid],
        ["flipRow",    missionNamespace getVariable ["AP_hudWebTileFlipRow", _dFlip]],
        ["pad",        missionNamespace getVariable ["AP_hudWebTilePad", _dPad]],
        ["ov",         missionNamespace getVariable ["AP_hudWebTileOv", _dOv]],
        ["res",        _tileRes],
        ["hf",         _tileHf]
    ]];
};

private _payload = createHashMapFromArray [
    ["hp",     _hp],
    ["h2o",    _h2o],
    ["food",   _food],
    ["wanted", _wanted],
    ["paused", _paused],
    ["regen",  _regen],
    ["map",    _map]
];

// The signature is built from ARRAYS, not from `str _payload`: SQF does not promise a stable
// iteration order for a HashMap, so a signature taken off the map could differ from itself
// between two ticks with identical values and push on every single one of them.
private _sig = str [_hp, _h2o, _food, _wanted, _paused, _regen, _dir, _pos, _markSig, _tileSig];
// The editor pushes ONCE into a page that has never been pushed to, and it must not be gated:
// the gate's memory belongs to the LIVE layer, and a signature that happened to match would
// leave the editor looking at an empty HUD with nothing to arrange. It also must not WRITE the
// gate, or the layer's first real tick after the editor closes would compare against the
// synthetic payload -- fn_hudEditClose clears both slots for the same reason, belt and braces.
// A FLAG AND NOT AN exitWith INSIDE THE then BLOCK. `exitWith` exits the scope it is written
// in, and a `then {}` body is a scope: written the obvious way, the gate would skip the two
// stamps and then carry straight on to the push it was supposed to prevent -- an unchanged
// payload sent every single tick, with the code reading as though it could not happen.
private _gated = false;
if (!_edit) then {
    if (_sig isEqualTo (missionNamespace getVariable ["AP_hudWebLast", ""])) then {
        _gated = true;
    } else {
        AP_hudWebLast = _sig;
        // This payload carries pos and dir too, so stamp the fast gate with them: the next fast
        // tick then has nothing new to say and skips, instead of re-sending what just went out.
        AP_hudWebLastPos = _fastSig;
    };
};
if (_gated) exitWith { false };

[_c, "hud", _payload] call webui_fnc_push
