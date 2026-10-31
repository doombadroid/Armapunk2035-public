// SPDX-License-Identifier: MIT
/*
    config/CfgArmaQuest.hpp
    The single config file: settings, authored quests, radiant templates, pools, givers.

    WHY THIS EXISTS
        Content that lives in code gets edited by programmers only, and every content
        change becomes a code review. Content that lives in a dozen files gets edited by
        nobody, because finding the right file is harder than writing the quest. One
        readable config file, with named members and no expression language, is the
        difference between a quest system that accumulates content and one that ships
        with three demo quests forever.

        The second thing this file prevents is positional-array config. Every value here
        is a named member. Inserting a field into a named block cannot shift the meaning
        of any other field, and a reader can tell what a value means without counting
        commas against a table in another document.

    WHAT IT DOES
        Defines five root config classes, read once at preInit and indexed:

            AQ_Settings    engine behaviour
            AQ_Quests      authored quests
            AQ_Templates   radiant quest templates
            AQ_Pools       the values templates draw slot fills from
            AQ_Givers      who offers quests, and how the player reaches them

        and includes profile_default.hpp, which defines AQ_Profile — the mapping onto
        the host's money, items and licences.

    Usage (in the mission's description.ext, at ROOT level, NOT inside any class):

        #include "ArmaQuest\config\CfgArmaQuest.hpp"

    HOW TO AUTHOR YOUR FIRST QUEST
        Copy the `aq_haul_intro` block below, give it a new class name, change the
        strings, the giver and the objectives, and reload the mission. Then run
        `[] call aq_fnc_validate;` — it reports every unresolved reference by name.
        Nothing else needs editing: quests are found by scanning this class, not by
        being listed somewhere a second time.

    A NOTE ON TEXT
        Any string in this file may be a literal ("Copper Run") or a stringtable key
        ("$STR_AQ_COPPER_RUN"). Resolution is one call at read time, so a one-file demo
        stays one file and a localised mission stays localised. There is no third
        option and no per-field switch to get wrong.

    A NOTE ON THINGS THIS FILE REFERS TO BUT DOES NOT CREATE
        Marker names (`aq_depot`, `aq_yard`, `aq_giver_depot`, and everything in
        AQ_Pools) must exist in the mission. Item classes (`aq_scrap`, `aq_crate`,
        `aq_toolkit`) and licence ids (`aq_hauling`) must mean something to the
        functions named in AQ_Profile. The shipped profile stubs in profile_default.sqf
        implement a small self-contained demo inventory so this content is playable
        before you have wired anything, and `aq_fnc_validate` names any marker it
        cannot find rather than letting a quest quietly become impossible.
*/


// =====================================================================
//  AQ_Settings — engine behaviour
// =====================================================================
#ifndef AQ_HOST_CONTENT   // see the note above AQ_Quests
class AQ_Settings {

    // Persistence driver (DESIGN.md section 10). One of:
    //   "profileNamespace"  default. Client-side. Correct for coop and singleplayer,
    //                       WRONG for a persistent server: the client owns the file,
    //                       so the client owns its own quest history.
    //   "extDB"             stub with the query shape documented; you complete it.
    //   "none"              quests reset each session. Useful while authoring.
    //   "sql"               host database, reached through the function named in
    //                       `sqlExec`. Nothing is persisted until that is wired.
    // Resolved to aq_fnc_store<Name>. An unknown value is a validation PROBLEM at
    // preInit, named, and the store facade then falls back to "none" and says so in the
    // RPT — because a store that forgets everything and a store that is misconfigured
    // must not be indistinguishable from a database outage. Two lines, both loud.
    store = "profileNamespace";

    // Only read when store = "sql" — host function NAME with the contract
    // [_sql, _mode] -> result.
    //   mode 1  fire and forget
    //   mode 2  first row, as an array
    // Empty means the sql store is unusable, which is a loud init failure
    // rather than a silent fallback to forgetting everything.
    sqlExec = "";

    // Radiant board behaviour (DESIGN.md section 7).
    //   "shared"    the server keeps K offers per giver, visible to everyone. Players
    //               compete over a real job board and expiry creates real pressure.
    //   "onDemand"  a fresh quest is rolled when a player interacts. No competition, no
    //               expiry pressure — usually what a coop mission wants.
    boardMode = "shared";

    // How often the server sweeps for expired offers, expired quests and refills the
    // board, in seconds. This is the heartbeat, not the expiry clock; an offer can sit
    // expired for up to this long before it is replaced.
    sweepInterval = 60;

    // How long a generated offer stays on the board before it expires, in seconds.
    // 0 disables expiry, which also disables the pressure the board exists to create.
    // A giver may override this with its own `offerLifetime`.
    offerLifetime = 1800;

    // Default number of radiant offers a giver holds, for a giver that does not declare
    // its own `boardSize`. 0 is the deliberate default: a giver quietly holding offers
    // its author never asked for is content appearing where nobody put it.
    boardSize = 0;

    // Write-behind interval for the store, in seconds. Quest progress ticks far more
    // often than quest state meaningfully changes; writing on every tick is how a
    // quest system takes a database down. Lower is safer against a crash, higher is
    // cheaper. Values below 5 are ignored.
    flushInterval = 30;

    // Most simultaneously active quests one player may hold. 0 = no limit.
    maxActive = 10;

    // Maximum facts one client may report per TEN SECONDS (DESIGN.md section 3: the
    // client reports facts, never verdicts). A client that lies can already claim it
    // stood in a circle; without a rate limit it can also claim it a thousand times a
    // second and spend the server's frame budget for it. Excess facts are dropped and
    // logged once per window, not once per fact — the log must not become the
    // amplifier. The client applies the same number over the same window before
    // sending, so one key governs both halves.
    factRateLimit = 60;

    // Largest quantity accepted inside a single reported fact. A ceiling on the
    // absurd, not on the plausible: it turns an unbounded exploit into a grind-speed
    // one, which is the most a clamp can honestly do.
    factMaxCount = 10000;

    // Multiplier applied to an objective's radius when the server re-checks a position
    // fact, allowing for the frames between the client's report and the server's copy
    // of where that player is. It is latency budget, not a tolerance for being wrong.
    factGeoSlack = 1.5;

    // How a quest's `side` is mapped onto an engine side. Quests are written in the
    // host's vocabulary ("civ", "cop"); the engine knows only CIV / WEST / EAST / GUER,
    // and forks disagree about which is which. One line to override, and it is the only
    // place that disagreement lives.
    sideMap[] = { {"civ","CIV"}, {"cop","WEST"}, {"med","GUER"}, {"reb","EAST"} };

    // The dialog the HTML journal opens, and the two idcs inside it. The dialog is the
    // HOST's to supply, because the browser control belongs to the journal dependency
    // rather than to this library — see INSTALL.md. Leave these alone unless your own
    // dialog uses different numbers; the journal falls back to native tasks when the
    // dialog will not open, and says so once.
    journalDialog = "AQ_Journal";
    journalIdd    = 8100;
    journalCtrl   = 8101;

    // 0 = errors only. 1 = lifecycle tracing to the RPT with an [AQ] prefix.
    // 2 = per-event tracing; extremely noisy, for reproducing one bad objective only.
    debug = 0;
};


// =====================================================================
//  AQ_TypeProbe — the class every objective type is registered against
//
//  aq_fnc_registerType refuses a type that cannot render itself, and it
//  proves that by calling the type's `describe` and `progress` verbs before
//  letting it into the registry. Those calls need something to read, and
//  reading nothing is not the same test: every shipped type would exit down
//  its "this config has no `item`" path, and the probe would only ever prove
//  that a type's ERROR branch returns the right shapes.
//
//  So this class holds one plausible value for every member the shipped types
//  read. A host adding its own type adds the members that type needs here;
//  adding members can only make the probe stricter.
// =====================================================================
#endif  // AQ_HOST_CONTENT -- AQ_Settings

class AQ_TypeProbe {
    type         = "probe";
    item         = "aq_probe_item";
    itemLabel    = "probe item";
    label        = "probe";
    count        = 1;
    marker       = "aq_probe_marker";
    radius       = 25;
    seconds      = 30;
    giver        = "aq_probe_giver";
    station      = "aq_probe_station";
    to           = "aq_probe_buyer";
    verb         = "aq_probe_verb";
    faction      = "EAST";
    vehicleClass = "";
    onFoot       = 0;
    anyKiller    = 0;
    consume      = 1;
    auto         = 1;
    reportEvery  = 1;
    resetOnAbort = 1;
};


// =====================================================================
//  AQ_Quests — authored quests
//
//  The demo below is a three-quest chain that exercises every objective
//  type shipped in v1: gather, deliver, craft, sell, talk, visit, kill,
//  zoneHold. Read it top to bottom once; it is the tutorial.
// =====================================================================
#ifndef AQ_HOST_CONTENT
// ---------------------------------------------------------------------
// SAMPLE CONTENT, and everything below is optional.
//
// This file doubles as the starter kit: the quests, givers, templates and
// pools below exist to be copied and edited in place, which is the fastest
// way to a first working quest.
//
// A host that outgrows that authors its content in its OWN file instead, so
// re-vendoring this library cannot overwrite its quests. That host ends up
// including both files, both declare AQ_Settings / AQ_Quests / AQ_Templates /
// AQ_Pools / AQ_Givers / AQ_Profile, and the engine throws
// "Member already defined" -- as a WARNING MESSAGE BOX the player has to click
// past at every single startup. It is not fatal (the classes merge), which is
// worse: it looks like a broken mission and nothing actually breaks.
//
// So: define AQ_HOST_CONTENT before including this file and the samples step
// aside. AQ_TypeProbe above stays defined either way -- it is a type-probe
// fixture aq_fnc_registerType reads, not content, and a host has no reason to
// supply one.
//
//     #define AQ_HOST_CONTENT
//     #include "my_quests.hpp"
//     #include "ArmaQuest\config\CfgArmaQuest.hpp"
// ---------------------------------------------------------------------
class AQ_Quests {

    // -----------------------------------------------------------------
    // 1/3 — the fully commented one. Every member a quest can have appears
    // here, including the ones that are usually left at their default.
    // -----------------------------------------------------------------
    class aq_haul_intro {

        // Shown in the offer screen, the journal and the task HUD.
        title       = "First Haul";

        // One line. Appears in lists, where there is no room for description.
        summary     = "Bring 20 scrap to the depot.";

        // The long text, shown when the player opens the offer. Newlines with \n.
        description = "The depot is running its yard down to nothing again. Pull twenty units of scrap together and get it through the gate. Nobody is going to ask where it came from.";

        // Which giver offers it. Must be a class in AQ_Givers.
        giver       = "depot_clerk";

        // Optional. Restricts the quest to one side. Omit for everyone.
        // The value is a key in AQ_Settings >> sideMap, which is what maps the
        // host's own vocabulary onto an engine side. Forks disagree about which
        // engine side a civilian or a police officer sits on, so the mapping is
        // one config line to change rather than an engine edit — and the quest
        // stays written in words the author uses.
        side        = "civ";

        // Prerequisites. Each entry is "<kind>:<id>". Evaluation is a pure function
        // of this one quest (DESIGN.md section 2) — no prerequisite can depend on
        // which other quests were checked first, so declaration order here and in
        // this file cannot change what is reachable.
        //   quest:<id>              that quest is completed
        //   license:<id>            hasLicense via the profile
        //   item:<class>[:<qty>]    countItem via the profile; qty defaults to 1.
        //                           The item is CHECKED, never taken — a gate, not
        //                           a price. Charging for a quest is a `deliver` or
        //                           a zoneHold `consume[]`, where the player can see
        //                           what it cost them.
        // An empty list means always available.
        requires[]  = { };

        // 0  = once ever
        // -1 = always repeatable, no cooldown
        // N  = repeatable after N seconds, measured from completion
        repeatable  = 0;

        // Seconds from acceptance to automatic failure. 0 = no limit.
        timeLimit   = 0;

        // Quest offered immediately on completion, by the same giver. "" = end of chain.
        chain       = "aq_haul_fabricate";

        // setSimpleTaskType value for the HUD marker. Cosmetic.
        icon        = "run";

        // Objectives are ordered by declaration. All of them must be satisfied.
        // `type` selects the plugin (DESIGN.md section 4); every other member is read
        // by that plugin and by nothing else, which is why adding a type needs no
        // engine edit and no change to this file's structure.
        class objectives {

            // gather — hold N of an item. Evaluated by event: the host fires
            // ["aq_gathered", ["aq_scrap", 1]] at its gather site, and the type
            // re-reads the true count through the profile before agreeing.
            class collect {
                type  = "gather";
                item  = "aq_scrap";
                count = 20;
            };

            // deliver — carry N of an item to a place, consumed on arrival.
            // Event plus watcher: the item count is an event fact, the arrival is a
            // position fact. The server consumes the items; the client only reports.
            class dropoff {
                type   = "deliver";
                item   = "aq_scrap";
                count  = 20;
                marker = "aq_depot";
                radius = 25;
            };
        };

        // Rewards are granted by the server, in one place, once (DESIGN.md section 2).
        // Any reward the profile cannot deliver is a preInit validation error naming
        // the quest and the missing profile entry — never a runtime half-payment.
        class rewards {
            money      = 2500;
            xp         = 5;                 // ignored when AQ_Profile >> awardXp is ""
            items[]    = { };               // { {"class", qty}, ... }
            licenses[] = { };
        };
    };

    // -----------------------------------------------------------------
    // 2/3 — a make-and-sell job. Shows craft, sell and talk, a prerequisite,
    // a cooldown, and rewards that are not just money.
    // -----------------------------------------------------------------
    class aq_haul_fabricate {
        title       = "Fabrication Order";
        summary     = "Build five crates, sell them, then report in.";
        description = "Scrap is only worth something once it is a box. Run five crates off the bench, move them at any buyer, and come back so the paperwork matches.";
        giver       = "depot_clerk";
        side        = "civ";
        requires[]  = { "quest:aq_haul_intro" };
        repeatable  = 3600;                 // once an hour
        timeLimit   = 0;
        chain       = "aq_haul_secure";
        icon        = "container";

        class objectives {

            // craft — event only. The host fires ["aq_crafted", ["aq_crate", 1]] from
            // its crafting bench. Nothing here knows what a bench is.
            class build {
                type  = "craft";
                item  = "aq_crate";
                count = 5;
            };

            // sell — event only. ["aq_sold", ["aq_crate", 5]] from the shop code.
            // Deliberately not "have money": selling is the fact, the price is the
            // host's business.
            class move {
                type  = "sell";
                item  = "aq_crate";
                count = 5;
            };

            // talk — interact with a giver. This is what makes a quest end at a
            // person rather than in mid-air. `giver` may name a different giver from
            // the one who offered the quest.
            class report {
                type  = "talk";
                giver = "depot_clerk";
            };
        };

        class rewards {
            money      = 6000;
            xp         = 10;
            items[]    = { { "aq_toolkit", 1 } };
            licenses[] = { "aq_hauling" };  // granted through AQ_Profile >> grantLicense
        };
    };

    // -----------------------------------------------------------------
    // 3/3 — the dangerous one. Shows visit, kill, zoneHold, a licence
    // prerequisite, a time limit, and a second giver.
    // -----------------------------------------------------------------
    class aq_haul_secure {
        title       = "Secure The Yard";
        summary     = "Clear the outer yard and hold it long enough to matter.";
        description = "Something has moved into the outer yard and the drivers have stopped going near it. Get out there, clear it, and stand in it long enough that the next convoy believes you.";
        giver       = "contract_board";
        requires[]  = { "quest:aq_haul_fabricate", "license:aq_hauling" };
        repeatable  = -1;                   // always available once unlocked
        timeLimit   = 1800;                 // 30 minutes from acceptance, then failed
        chain       = "";
        icon        = "attack";

        class objectives {

            // visit — watcher only. Reach a place. The cheapest possible objective and
            // the right way to start a quest that happens somewhere else.
            class scout {
                type   = "visit";
                marker = "aq_yard";
                radius = 40;
            };

            // kill — event only, from the host's kill instrumentation. `faction` and
            // the marker/radius pair are a filter, not a spawner: ArmaQuest does not
            // create the enemies, it counts them. What lives in the yard is the
            // mission's business.
            class clear {
                type    = "kill";
                faction = "EAST";
                marker  = "aq_yard";
                radius  = 150;
                count   = 6;
            };

            // zoneHold — watcher only. Stand in a radius, on foot, for N seconds.
            // This is the objective that turns arriving somewhere into gameplay: the
            // player ends up stationary, out of the vehicle, visible and committed for
            // a known length of time. `onFoot` is the whole point; leaving it 1 is what
            // stops the hold being completed from a moving truck.
            class secure {
                type    = "zoneHold";
                marker  = "aq_yard";
                radius  = 15;
                seconds = 60;
                onFoot  = 1;
            };
        };

        class rewards {
            money      = 12000;
            xp         = 25;
            items[]    = { };
            licenses[] = { };
        };
    };
};


// =====================================================================
//  AQ_Templates — radiant quests
//
//  A template declares typed slots; the generator fills them from pools
//  under constraints and emits a concrete quest instance. Substitution is
//  textual and total: %NAME% is replaced in every string and number field.
//  An unfilled slot is a hard error at generation time — a blank in a
//  quest title is a bug that reaches players, so it must not be possible.
// =====================================================================
class AQ_Templates {

    // -----------------------------------------------------------------
    // Courier work. Two slots from pools, one numeric, rewards scaled by
    // the numeric slot.
    // -----------------------------------------------------------------
    class courier_contract {

        // Relative likelihood when the board picks a template for a giver.
        // Not a percentage: weights are summed and rolled against.
        weight   = 10;

        // Which givers can offer instances of this template.
        givers[] = { "depot_clerk" };

        title       = "Courier run to %PLACE%";
        summary     = "%COUNT% units of %CARGO% wanted at %PLACE%.";
        description = "Standing order. Take %COUNT% units of %CARGO% out to %PLACE% and hand it over there. Payment on delivery, nothing up front.";

        icon        = "run";
        timeLimit   = 2700;

        class slots {

            // A pool slot draws one entry from AQ_Pools >> <pool>.
            class PLACE {
                pool         = "settlements";

                // Distance constraint. `distanceFrom` is one of:
                //   "giver"        the giver offering the quest
                //   "player"       the player the offer is generated for
                //   "slot:<NAME>"  another slot filled earlier in this template
                // min/max are METRES here. On a numeric slot (see COUNT) the same two
                // member names mean the value range. The distinction is `pool`:
                // a slot with a pool measures distance, a slot without one picks a
                // number. Nothing else about a slot changes.
                distanceFrom = "giver";
                min          = 500;
                max          = 6000;

                // Do not offer this pool entry to this player again for N seconds.
                // Per player, persisted, so nobody is sent to the same place twice in
                // an evening even across a relog. This is the single constraint that
                // separates radiant content from a slot machine.
                notUsedWithin = 3600;
            };

            class CARGO {
                pool = "cargo";
                // No distance constraint: an item has no position. Omitting
                // distanceFrom is the normal case for non-place pools.
            };

            // A numeric slot: no pool, so min/max are the value range, inclusive.
            class COUNT {
                min = 5;
                max = 15;
            };
        };

        // Objectives are written exactly as in AQ_Quests. The only difference is that
        // any value may contain %SLOT%. Note count = "%COUNT%" is quoted: substitution
        // is textual, so a substituted number is written as a string here and converted
        // when the instance is emitted.
        class objectives {
            class load {
                type  = "gather";
                item  = "%CARGO%";
                count = "%COUNT%";
            };
            class run {
                type   = "deliver";
                item   = "%CARGO%";
                count  = "%COUNT%";
                marker = "%PLACE%";
                radius = 30;
            };
        };

        class rewards {
            money     = 400;

            // Multiply every numeric reward by the value of this numeric slot.
            // Deliberately a slot name and not an expression: the moment config can
            // compute, config is code, and code in config is code nobody reviews.
            scaleWith = "COUNT";

            xp         = 2;
            items[]    = { };
            licenses[] = { };
        };
    };

    // -----------------------------------------------------------------
    // Clearing work. Same machinery, different shape: one pool slot, one
    // numeric slot, three objectives, distance measured from the player.
    // -----------------------------------------------------------------
    class sweep_contract {
        weight   = 6;
        givers[] = { "contract_board" };

        title       = "Clear hostiles near %PLACE%";
        summary     = "%COUNT% reported around %PLACE%. Clear them and hold the ground.";
        description = "Reports out of %PLACE% put roughly %COUNT% hostiles in and around the place. Go and make that number zero, then stay a minute so we know it stuck.";

        icon        = "attack";
        timeLimit   = 3600;

        class slots {
            class PLACE {
                pool          = "settlements";
                distanceFrom  = "player";     // generated relative to whoever asks
                min           = 800;
                max           = 5000;
                notUsedWithin = 7200;
            };
            class COUNT {
                min = 3;
                max = 8;
            };
        };

        class objectives {
            class approach {
                type   = "visit";
                marker = "%PLACE%";
                radius = 120;
            };
            class clear {
                type    = "kill";
                faction = "EAST";
                marker  = "%PLACE%";
                radius  = 250;
                count   = "%COUNT%";
            };
            class hold {
                type    = "zoneHold";
                marker  = "%PLACE%";
                radius  = 20;
                seconds = 45;
                onFoot  = 1;
            };
        };

        class rewards {
            money      = 900;
            scaleWith  = "COUNT";
            xp         = 4;
            items[]    = { };
            licenses[] = { };
        };
    };
};


// =====================================================================
//  AQ_Pools — the values slots are filled from
//
//  A pool is a named list of entries, ONE CLASS PER ENTRY. There is no array
//  form: the generator reads subclasses and nothing else. Each entry may have
//    value       the text substituted into %SLOT% outside player-facing text
//                (default: the class name)
//    label       what a human sees in the title, summary, description and an
//                objective's `text` (default: the class name)
//    marker      optional; a map marker giving the entry a position, which is
//                what makes distance constraints possible. An entry with no
//                position can still fill a slot, but only a slot with no
//                distanceFrom — and the generator says so by name when it skips it.
//    position[]  a literal [x, y] or [x, y, z], when the entry has no marker
//    tags[]      free-form labels a slot can filter on with tags / excludeTags
//    weight      relative likelihood within the pool (default 1; 0 = never drawn)
//
//  value and label are separate on purpose, and WHICH ONE A TOKEN EXPANDS TO
//  DEPENDS ON THE FIELD IT SITS IN: the label in text a player reads, the value
//  everywhere else. Either half can be named explicitly with %NAME.label%,
//  %NAME.value% or %NAME.marker%. Collapsing them would mean either the quest
//  text reads like a variable name or the marker lookup fails.
// =====================================================================
class AQ_Pools {

    // Places. Every `marker` here must exist in the mission.
    class settlements {
        class north_depot  { value = "aq_place_north_depot";  label = "the north depot";  marker = "aq_place_north_depot"; };
        class quarry       { value = "aq_place_quarry";       label = "the quarry";       marker = "aq_place_quarry"; };
        class coast_road   { value = "aq_place_coast_road";   label = "the coast road";   marker = "aq_place_coast_road"; };
        class old_airfield { value = "aq_place_old_airfield"; label = "the old airfield"; marker = "aq_place_old_airfield"; };
    };

    // Things worth hauling. No markers: an item has no position, and a slot that
    // draws from this pool must not declare distanceFrom.
    class cargo {
        class scrap    { value = "aq_scrap";    label = "scrap"; };
        class crate    { value = "aq_crate";    label = "crates"; };
        class fuel     { value = "aq_fuel";     label = "fuel cans"; };
        class supplies { value = "aq_supplies"; label = "supplies"; };
    };
};


// =====================================================================
//  AQ_Givers — who offers quests, and how the player reaches them
//
//  A giver is config, not code. `trigger` names a driver; a driver's only
//  job is to call [_giverId] call aq_fnc_openOffers. That indirection is
//  what lets the same giver be an addAction on an NPC in one mission and a
//  phone app entry in another, with no change to any quest.
// =====================================================================
class AQ_Givers {

    class depot_clerk {
        name      = "Depot Clerk";

        // Driver name. "addAction" ships. Register your own with
        //   ["phone", myFnc] call aq_fnc_registerTrigger;
        // An unknown trigger is a preInit error naming the giver — a giver nobody can
        // reach is content that exists and cannot be played, which is worse than a
        // giver that does not exist.
        trigger   = "addAction";

        // Spawned at `marker` if both are set. Leave `object` empty to attach the
        // trigger to something the mission already placed; the host then calls
        // aq_fnc_registerTrigger's driver against its own object.
        object    = "C_man_polo_1_F";
        marker    = "aq_giver_depot";

        // How many radiant offers this giver holds on the shared board.
        // 0 means authored quests only.
        boardSize = 2;
    };

    class contract_board {
        name      = "Contract Board";
        trigger   = "addAction";
        object    = "Land_MapBoard_F";
        marker    = "aq_giver_board";
        boardSize = 3;
    };
};


// =====================================================================
//  AQ_Profile — the mapping onto the host's money, items and licences.
//  Kept in its own file because it is the one file a host edits.
// =====================================================================
#include "profile_default.hpp"

#endif  // AQ_HOST_CONTENT -- sample content