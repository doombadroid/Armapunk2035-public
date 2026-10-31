/*
    File: fn_factionCfg.sqf  (AP_fnc_factionCfg)

    The four NPC factions. Three hold a town; the fourth is defined and holds
    nothing. See FACTION_REP_SPEC.md for standing, and the faction/war design for
    territory and the weekly war.

    Row shape:

        [_id, _name, _territoryMarker, _fixerId, _blurb, _poly, _town]

    _id     stable, referenced by code, content and the database. NEVER renamed --
            a stored standing array keys off it, so renaming an id orphans every
            player's reputation with that faction silently. The ids below read as
            placeholders (f_neon, f_dock, f_pharma) and were KEPT anyway when the
            factions were named, precisely because renaming them is the one edit
            this file must not take. Read them as opaque handles, not as
            descriptions -- f_dock is the Crusaders and has nothing to do with a
            dock.
    _name   display only. Expected to change; that is the whole reason _id exists
            separately.
    _fixerId  the ArmaQuest giver that speaks for this faction (aq_content.hpp,
            class AQ_Givers). Content references the giver id, never a position,
            which is why the Fixers can be moved in 3DEN without touching code.
    _territoryMarker  the map LABEL marker for this territory, and the prefix the
            corner markers share: the polygon is drawn in Eden as
            <_territoryMarker>_p1 .. _pN. It is always "aq_terr_" + _id, with the
            id's own "f_" intact -- the two used to disagree (aq_terr_neon for
            f_neon), which reads fine until someone places aq_terr_neon_p1 for
            f_neon and aq_terr_f_neon_p1 for something else and neither bakes.

    _poly   the territory, as an ARRAY OF [x,y] POINTS in map coordinates, tested
            with inPolygon. Pairs, not triples: this is what tools/bake_territory.py
            writes and what the web map draws. inPolygon itself demands Position3D
            on both sides (Z ignored in value, required in arity -- a pair throws
            "2 elements provided, 3 expected"), so every consumer that TESTS a point
            lifts vertices and point to [x,y,0] first: "territoryOf" below and the
            cache in fn_factionTerritory. [] means "this faction holds no ground", which is a
            supported state and must stay supported: f_maxsec is reserved for a
            fourth faction that does not exist yet, and every consumer has to cope
            with a faction that can never be entered.
    _town   the town the territory covers, for player-facing text only.

    WHY A POLYGON AND NOT A MARKER. _territoryMarker is still here and is still the
    marker a map label hangs off, but it is NOT the authority for containment. An
    ELLIPSE marker cannot follow a coastline or a ridge, and a marker that only
    approximates the tested area is worse than no marker at all -- it tells the
    player one thing while the code does another, and the disagreement only ever
    surfaces as "I got shot in a safe zone". The polygon is the authority; anything
    drawn for the player is generated FROM it (core/web/fn_mapOpen.sqf), so the two
    cannot drift.

    THE POLYGONS BELOW ARE DEFAULTS, NOT DESIGN. They are octagons sized from the
    real anchors already in mission.sqm -- Chapoi from cop_spawn_4/med_spawn_3,
    Larche from civ_spawn_2, La Port from cop_spawn_3/med_spawn_2 -- so the system
    is testable today rather than blocked on map work. They are meant to be
    redrawn: place a ring of markers named aq_terr_<id>_p1..pN in an AP_* layer of
    MaldenEdit.Malden and run tools/bake_territory.py, which rewrites the _poly
    arrays in this file from them. Do that through tools/edit-map.sh; never save
    the shipped mission.sqm from 3DEN.

    Usage:
        ["all"]                    call AP_fnc_factionCfg  -> [[id,name,...], ...]
        ["byId",   "f_neon"]       call AP_fnc_factionCfg  -> the row, or []
        ["byFixer","fixer_1"]      call AP_fnc_factionCfg  -> the row, or []
        ["ids"]                    call AP_fnc_factionCfg  -> ["f_neon", ...]
        ["territoryOf", [x,y]]     call AP_fnc_factionCfg  -> faction id, or ""
*/
params [["_mode", "", [""]], ["_arg", "", ["", [], 0]]];

private _factions = [
    // ---- Lightrunners -- Larche. Netrunners; the town nearest the northern
    // cartel belt, which is where their work goes.
    ["f_neon",   "Lightrunners",    "aq_terr_f_neon",   "fixer_1",
     "Nero's crew. They do not carry the town so much as listen to it -- every camera in Larche answers to somebody, and lately it is them.",
     [[6424.3,8793.1],[6191.6,9009.6],[5862.4,9009.6],[5629.7,8793.1],[5629.7,8486.9],[5862.4,8270.4],[6191.6,8270.4],[6424.3,8486.9]],
     "Larche"],

    // ---- Crusaders -- Chapoi. Pope's congregation. Hits and grand theft, with
    // a confession on the way out.
    ["f_dock",   "Crusaders",       "aq_terr_f_dock",   "fixer_2",
     "Pope keeps a church in Chapoi and a ledger under the altar. He will absolve almost anything, once, and he counts.",
     [[6300.4,4129.3],[6019,4432.4],[5621,4432.4],[5339.6,4129.3],[5339.6,3700.7],[5621,3397.6],[6019,3397.6],[6300.4,3700.7]],
     "Chapoi"],

    // ---- Silent Partners -- La Port. Corporate money, no corporate name. The
    // port is theirs because everything that leaves the island goes through it.
    ["f_pharma", "Silent Partners", "aq_terr_f_pharma", "fixer_4",
     "Nobody has met the Administrator. The contracts arrive anyway, they pay on time, and they are always someone else's idea.",
     [[8695.2,3396.7],[8440.9,3624],[8081.1,3624],[7826.8,3396.7],[7826.8,3075.3],[8081.1,2848],[8440.9,2848],[8695.2,3075.3]],
     "La Port"],

    // ---- Reserved. Defined so standing, perks and content can reference it, but
    // it holds no ground and takes no part in the weekly war. La Pessagne is the
    // town kept back for it. An empty _poly is the marker of "not in the world
    // yet" and every consumer must read it that way rather than crashing or
    // treating [] as "everywhere".
    ["f_maxsec", "Unaffiliated",    "aq_terr_f_maxsec", "fixer_3",
     "Reserved. No territory, no fixer of record, no place in the war.",
     [],
     ""]
];

// postgis (2026-09-04): the polygons live in faction_territory. The server publishes
// AP_factionPolys = [[id, [[x,y],...]], ...] at boot (APS_fnc_territoryLoad) and on the bot verb
// territoryreload; the literals above are the fallback for a boot without the table.
if (!isNil "AP_factionPolys" && {AP_factionPolys isEqualType []}) then {
    {
        _x params [["_pid", "", [""]], ["_ppoly", [], [[]]]];
        private _i = _factions findIf { (_x select 0) isEqualTo _pid };
        if (_i > -1 && {count _ppoly >= 3}) then { (_factions select _i) set [5, _ppoly]; };
    } forEach AP_factionPolys;
};

switch (toLower _mode) do {
    case "all": { _factions };
    case "ids": { _factions apply { _x select 0 } };
    case "byid": {
        private _i = _factions findIf { (_x select 0) isEqualTo _arg };
        if (_i isEqualTo -1) then { [] } else { _factions select _i }
    };
    case "byfixer": {
        private _i = _factions findIf { (_x select 3) isEqualTo _arg };
        if (_i isEqualTo -1) then { [] } else { _factions select _i }
    };

    // Position -> the faction holding that ground, or "" for neutral. La Trinite,
    // the redzone and everything between them are neutral by simply not being
    // inside any polygon -- neutrality is the absence of an owner, never an entry
    // of its own, which is the same discipline the standing blobs use for zero.
    //
    // Takes [x,y] or a full [x,y,z] position. inPolygon ignores Z in value but wants
    // three elements on both sides (see _poly above), so the point is rebuilt as
    // [x,y,0] and the pair-vertices are lifted per call -- the guard keeps a
    // malformed argument returning neutral rather than throwing inside a render loop.
    case "territoryof": {
        if (!(_arg isEqualType []) || {count _arg < 2}) exitWith { "" };
        private _p = [_arg select 0, _arg select 1, 0];
        private _hit = "";
        {
            private _id   = _x select 0;
            private _poly = _x param [5, []];
            if (_poly isNotEqualTo [] && {_p inPolygon (_poly apply { [_x select 0, _x select 1, 0] })}) exitWith { _hit = _id; };
        } forEach _factions;
        _hit
    };

    default {
        diag_log format ["[AP][faction] factionCfg: unknown mode '%1'", _mode];
        []
    };
};
