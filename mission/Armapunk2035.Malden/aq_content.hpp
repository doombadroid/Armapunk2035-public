/*
    aq_content.hpp — Armapunk's ArmaQuest configuration and content.

    Everything project-specific lives HERE, never in ArmaQuest/. That tree is a
    byte-identical vendored copy of the upstream library and is replaced wholesale
    by scratchpad/vendor_armaquest.py; anything authored inside it is destroyed on
    the next re-vendor, with no error.

    Included AFTER the library's own config so these definitions win.
*/

// This class is included BEFORE ArmaQuest\config\CfgArmaQuest.hpp (see
// description.ext) -- not after, despite that file's own header comment
// suggesting a host include its own config last. Measured directly on this
// engine: the mission previously declared this class alongside ArmaQuest's own
// and relied on the two merging -- ours parsed first to claim store/sqlExec, the
// library's parsed second to supply everything else. THAT WAS NOT WHAT HAPPENED.
// The first declaration wins the class outright and the second contributes
// nothing, which the boot log proves: flushInterval and sweepInterval came out as
// 60 and 5, ArmaQuest's own CODE defaults, not the 30 and 60 its config sets.
// Every other member was on a code default too, silently.
//
// So description.ext now defines AQ_HOST_CONTENT and the library's sample
// AQ_Settings is not declared at all. Behaviour is unchanged -- it was already
// inert -- and the "Member already defined" box the player clicked past at every
// startup is gone. Anything this class does not set falls through to the code
// default in ArmaQuest's own functions, which is now the only fallback there is.
// tools/aq_check.py fails the build if upstream adds a setting this file does not
// carry, so "silently on a code default" cannot happen again without being said
// out loud
class AQ_Settings {
    // The host database, reached through APS_fnc_aqSql -> DB_fnc_asyncQuery ->
    // whatever transport the mission currently resolves to.
    store   = "sql";
    sqlExec = "APS_fnc_aqSql";

    // Task 9: the journal's own dialog (dialog\web_journal.hpp). NOT the
    // library's own default idd/idc (8100/8101, see ArmaQuest\config\
    // CfgArmaQuest.hpp) -- those numbers are already spoken for. They belong
    // to dialog\quest_menu.hpp, Armapunk's OWN pre-ArmaQuest native quest
    // dialog, deleted in 8f5aec4e ("the app dialogs go, and the first PAAs
    // with them") when that app moved into the web deck's in-page list view.
    // core\quests\fn_questSel.sqf and fn_questAccept.sqf still open-code
    // `findDisplay 8100` / `displayCtrl 8101` against the now-deleted dialog
    // -- dead code today (zero call sites, checked by grep across the whole
    // mission), but a haunted address is still a landmine for whoever
    // resurrects one of them next. 937900/937901 is the next free slot after
    // this mission's other standalone web dialogs (937400-937800).
    journalDialog = "AQ_Journal";
    journalIdd    = 937900;
    journalCtrl   = 937901;

    // Action verbs a CLIENT may not report (local patch in aq_fnc_srvFact, see
    // ArmaQuest\VENDORED.txt). Each one counts only when server code that saw it
    // happen calls APS_fnc_aqFact: qhcast <- APS_fnc_qhSRV (upload landed),
    // chipinstall <- APS_fnc_cyberdeckSRV installHack, robstore <- APS_fnc_robStore
    // (the server's robbery clock: the caller's own unit on a non-player target with a
    // cop on duty, alive and never cuffed/downed for 55 s, once per UID per 30 min, a
    // robbery that advances nothing not counting against it -- soft checks on a
    // client-started robbery, so a cheat is held to the honest rate, not stopped; and
    // aq_fnc_srvAccept holds one live instance per template, so one fact is one payout).
    // execute and removewreck have NO server witness
    // yet, so Reckoning and Housekeeping cannot complete -- which they never could
    // legitimately (their client sites fire an event named "action"), but a forged
    // fact could. Both are weight = 0 (off the boards) until one exists;
    // tools/aq_verbcheck.py fails a serverFacts[] verb on a board with no
    // APS_fnc_aqFact site. proxyarm and qhbreach are still client-reported; the hourly cap
    // in AP_fnc_aqPayMoney bounds them.
    serverFacts[] = { "qhcast", "chipinstall", "robstore", "execute", "removewreck" };
};

// The nine capabilities ArmaQuest needs, mapped onto Armapunk's real economy
// instead of the vendored demo (ArmaQuest\config\profile_default.sqf, which
// this declaration makes unused -- its isNil guards mean a host definition
// wins, but here the win is by NAME (this class beats the library's own
// AQ_Profile on the first-parsed-member rule explained above), not by
// preInit ordering, so there is no dependency on load order between the two.
//
// Every function named below is a plain mission function (AP_fnc_*), defined
// in core/quests/fn_aqProfile.sqf and core/actions/fn_handleLicense.sqf, and
// registered in Functions.h like any other. None of this lives inside
// ArmaQuest/ -- see the header comment above and core/quests/fn_aqProfile.sqf
// for why.
//
// Gate: after a deploy, grep the RPT for "[AQ]" preInit/validate lines.
//   grep -aE "\[AQ\].*(profile|PROBLEM)" <rpt-or-log>
// A profile entry that resolves to nothing is reported BY NAME there; a
// "notify" WARNING ("is not a profile key") is expected and harmless -- see
// fn_aqProfile.sqf's own comment on that key.
class AQ_Profile {
    payMoney     = "AP_fnc_aqPayMoney";
    takeMoney    = "AP_fnc_aqTakeMoney";
    giveItem     = "AP_fnc_aqGiveItem";
    takeItem     = "AP_fnc_aqTakeItem";
    countItem    = "AP_fnc_aqCountItem";
    hasLicense   = "AP_fnc_aqHasLicense";
    grantLicense = "AP_fnc_aqGrantLicense";
    playerUid    = "AP_fnc_aqPlayerUid";
    // Mapped 2026-08-30. Was absent, which fn_validate.sqf reported at every boot
    // as "awards xp but AQ_Profile >> awardXp is empty" while eight quests below
    // carried an xp reward that went nowhere.
    awardXp      = "AP_fnc_aqAwardXp";
    // Allegiance, for requires[] = { "align:<factionId>" }. Distinct from getRep:
    // standing is what a player earns alone, alignment is what their gang swore to.
    factionOf    = "AP_fnc_aqFactionOf";

    // Faction reputation (FACTION_REP_SPEC.md). Server-side, UID-keyed, exactly
    // like the paying capabilities above. addRep applies the gang multiplier and
    // the hostile-standing damping internally, so no caller has to know either
    // rule -- a quest just says how much it is worth and to whom.
    getRep       = "AP_fnc_aqGetRep";
    addRep       = "AP_fnc_aqAddRep";
    notify       = "AP_fnc_aqNotify";
};

// Task 8: the six quest-giver NPCs. Ids are stable and are what quest/template
// content references (AQ_Quests >> giver, Task 10); display names are owner
// placeholders and are expected to change without touching a single quest.
//
// Givers carry NO side field -- only quests and templates gate by side. All six
// exist for every player; a player of the wrong side just sees an empty board
// when they open one (fn_srvBoard filters offers, not the giver itself).
//
// owner 2026-09-05: NO GIVER DECLARES `object` ANY MORE, SO NO QUEST NPC SPAWNS.
// Six C_man_polo_1_F clerks used to stand at the markers below, and because those
// markers are placeholders parked next to civ_spawn_1/2 and cop_spawn_1, the first
// thing a player saw on spawning in was a stranger offering quest work on the
// scroll wheel. Dropping `object` removes both halves at once: aq_fnc_srvSpawnGivers
// skips a giver with no object class ("A giver with no `object` is skipped, not
// failed"), and with nothing to attach to, the walk-up addAction driver never arms,
// so the scroll entry goes with the body.
//
// QUESTS ARE NOT REMOVED. `trigger` stays "addAction" on purpose: validation runs at
// preInit and ERRORS on a driver that is not registered yet, so naming any other one
// here would fail the catalogue and disarm the whole system. With no object to attach
// to, that driver simply refuses and arms nothing.
//
// THE ACCESS PATH IS NOW THE PHONE. The deck's "Quest Log" app opens the CONTRACTS
// picker (core/web/fn_aqContracts.sqf, dialog/aq_contracts.hpp): one list of every
// giver plus the player's own journal, and picking a giver calls the same
// aq_fnc_openOffers the scroll actions called. Every quest stays acceptable and
// completable; only the doorway moved.
//
// THE MARKERS STAY. They are not just spawn points -- quest objectives reference them
// as locations (the Pharma Technica delivery below targets aq_giver_pharma_technica),
// so deleting them would break content. Expect one validator WARNING per giver at
// boot ("a marker is set but no object class is given, so nothing will be spawned")
// -- that is the intended state, and a warning does not disarm the catalogue.
//
// `marker`: aq_fnc_srvSpawnGivers WOULD spawn `object` at `marker`'s position and
// publish it as aq_giverObj_<id> (server), if any giver still declared one.
// `trigger = "addAction"` is the shipped walk-up driver, wired automatically by
// aq_fnc_postInit; with no object it arms nothing, which is the point.
//
// HISTORY: there used to be a SECOND driver here, "deck", registered from mission code
// (fn_aqDeckBootstrap.sqf) with the driver itself in a separate file (fn_aqDeckTrigger.sqf)
// because ArmaQuest's dispatch only ever arms the one driver named in `trigger` per giver.
// It armed six permanent "Cyberdeck: Contact X" self-actions on the player. Both files were
// DELETED 2026-09-05 along with the NPCs -- the picker replaces them and needs no driver at
// all, because it calls aq_fnc_openOffers directly. If you ever reinstate a second driver,
// the reason those were two files and not one is worth knowing: one file dual-purposed as
// both the engine's postInit auto-call and the real per-giver driver call, told apart by
// inspecting `_this`, failed three different ways on this exact deploy before the split
// fixed it. The shape of `_this` on this engine's postInit auto-call is not reliably
// introspectable, so a postInit-tagged file must do one unconditional job and never ask.
//
// Marker positions are placeholders near the anchors CLAUDE.md's marker rule
// points at (civ_spawn_1/2, cop_spawn_1, and the Trauma Team compound gate),
// offset a few tens of metres so nothing stacks on the anchor or on a sibling
// giver. Placed in mission.sqm via tools/map_codegen.py (see that commit); the
// owner will drag them to real spots in 3DEN later -- content references the id,
// not the coordinate, so that move is free.
class AQ_Givers {
    // NERO -- the Lightrunners, Larche. Netrunners; the town nearest the northern
    // cartel belt, which is where their work goes.
    class fixer_1 {
        name      = "Nero";
        trigger   = "addAction";
        marker    = "aq_giver_fixer_1";
        boardSize = 3;
    };
    // POPE -- the Crusaders, Chapoi. A church, a ledger under the altar, and
    // absolution for almost anything once.
    class fixer_2 {
        name      = "Pope";
        trigger   = "addAction";
        marker    = "aq_giver_fixer_2";
        boardSize = 3;
    };
    // RESERVED. f_maxsec holds no territory and takes no part in the war, so this
    // giver has boardSize 0 -- it exists so content and standing can reference the
    // fourth faction, and offers nothing until somebody decides what it is. A giver
    // quietly holding offers nobody authored is content appearing where nobody put it.
    class fixer_3 {
        name      = "Unclaimed";
        trigger   = "addAction";
        marker    = "aq_giver_fixer_3";
        boardSize = 0;
    };
    // THE ADMINISTRATOR -- the Silent Partners, La Port. Nobody has met them; the
    // contracts arrive anyway and are always someone else's idea.
    class fixer_4 {
        name      = "The Administrator";
        trigger   = "addAction";
        marker    = "aq_giver_fixer_4";
        boardSize = 3;
    };
    class maxsec_command {
        name      = "MaxSec Command";
        trigger   = "addAction";
        marker    = "aq_giver_maxsec_command";
        boardSize = 3;
    };
    class pharma_technica {
        name      = "Pharma Technica";
        trigger   = "addAction";
        marker    = "aq_giver_pharma_technica";
        boardSize = 3;
    };
};

// The vendored library ships a matched demo set purely so a fresh install has
// something to validate and boot against -- AQ_Givers (depot_clerk,
// contract_board, market_trader) plus AQ_Quests/AQ_Templates that reference
// those ids by name, all in ArmaQuest\config\CfgArmaQuest.hpp.
//
// aq_fnc_preInit resolves AQ_Quests/AQ_Templates/AQ_Givers/AQ_Pools each
// INDEPENDENTLY -- missionConfigFile first, configFile only as the fallback
// for a root the mission does not declare at all (fn_preInit.sqf's own
// "config roots" comment: "Mission config wins"; verified by reading that
// resolution helper directly, not inferred). AQ_Givers above is now the
// mission's own, so it supersedes the demo's wholesale -- and the demo's
// AQ_Quests/AQ_Templates, still resolving from configFile because THIS file
// does not (yet) declare those two roots, are left pointing at giver ids that
// no longer exist. That is 5 AQ-VALIDATE problems ("'depot_clerk' is not a
// class in AQ_Givers", etc.) and ready=false -- observed on this exact
// deploy, not theoretical.
//
// Empty mission-owned overrides supersede the demo catalogue the same way
// AQ_Givers just did, restoring a clean validate. Task 10 fills these in with
// real content (mainline + radiant) referencing the six givers above; this is
// not that content -- it is the minimum needed so Task 8 does not ship
// ready=false in the meantime. AQ_Pools is left alone: nothing in the 5
// observed problems named it, and with AQ_Templates empty nothing looks at it.
// =====================================================================
//  Task 10 — the vertical slice.
//
//  A five-quest civ mainline spanning two Fixers (entry on fixer_1; the
//  handoff to fixer_2 is a `requires[]` prerequisite, never `chain` --
//  `chain` only ever offers to the SAME giver, so writing a cross-giver step
//  with it produces a quest nothing offers. It looks completely correct in
//  config; aq_fnc_reachability is what catches it by name), plus one radiant
//  template per side. Every item class and marker below was verified against
//  this mission before use (core/config/fn_virtItemCfg.sqf, mission.sqm) --
//  nothing here is invented.
//
//  SEQUENCING NOTE: objectives inside one quest are evaluated in declaration
//  order, one at a time -- server/fn_srvFact.sqf reads `_objIds select
//  _idx`, not "all armed simultaneously". aq_fx2_breach's two objectives
//  rely on that: `quiet` (arm the proxy) is declared before `breach`, so the
//  breach objective is not even live until the proxy is armed. That ordering
//  IS the in-fiction lesson (arm the proxy before you touch the door), not
//  an accident of authoring order.
//
//  MECHANISM COVERAGE: gather, deliver, talk and action all appear in the
//  mainline (the brief's minimum); visit and zoneHold appear in the cop
//  template, which needs no host instrumentation at all (both are
//  self-contained watchers). sell/craft/kill are not exercised in this
//  slice -- see the Task 10 report for why (no instrumented event source
//  for sell/craft, and no hostile-AI faction on this map for kill).
// =====================================================================
class AQ_Quests {

    // -----------------------------------------------------------------
    // Fixer One's stretch: gather -> deliver, chained (same giver, so
    // `chain` is the correct mechanism here -- contrast with the handoff
    // below).
    // -----------------------------------------------------------------
    // The opening quest was removed 2026-08-17: a new one is being written to
    // replace it, alongside the removal of Parole Papers (the old onboarding).
    // aq_fx1_haul below carries requires[] = {} of its own, so it is a valid
    // entry point in the meantime and the chain behind it stays reachable --
    // aq_fnc_reachability will confirm that rather than us assuming it.
    class aq_fx1_haul {
        title       = "The Run";
        summary     = "Get the ore to the market before the buy window closes.";
        description = "'Good. Now the part that actually matters -- timing. Get that copper to the market before the window shuts, and don't get clever about the route. I'm watching how you move, not just what you deliver.'";
        giver       = "fixer_1";
        side        = "civ";
        requires[]  = { };
        repeatable  = 0;
        timeLimit   = 0;
        chain       = "";
        icon        = "container";

        class objectives {
            // deliver is a self-contained watcher -- no host event needed.
            // It polls position, re-reads the carried count through the
            // profile, and consumes the goods itself on arrival.
            class dropoff {
                type      = "deliver";
                item      = "copperore";
                count     = 15;
                marker    = "lh_genstore";
                radius    = 30;
                itemLabel = "Copper Ore";
                label     = "the general store";
            };
        };

        class rewards {
            // ghostplatechip is DROP-ONLY in the shop catalogue (fed/cartel/
            // van loot only -- fn_virtItemCfg.sqf's own comment), so this is
            // a fixer favour money couldn't have bought anyway. That's why
            // it's an item reward here and not just a bigger number, and why
            // aq_fx2_breach's proxy chain (below) is NOT gifted the same
            // way -- that one is supposed to cost the player real money.
            money      = 2800;
            xp         = 8;
            items[]    = { { "ghostplatechip", 1 } };
            licenses[] = { };
        };
    };

    // -----------------------------------------------------------------
    // The handoff. aq_fx1_haul (above) does NOT chain here -- this is the
    // cross-giver step, so it is a `requires[]` prerequisite on a
    // DIFFERENT giver, never `chain`. See the file header note.
    // -----------------------------------------------------------------
    // Proves the two new gate kinds end to end. Deliberately gated on BOTH:
    // standing with a faction AND a live world condition, which is the
    // combination neither spec delivers alone (WORLD_STATE_SPEC.md section 6).
    //
    // rep:f_neon:250   -- only once the neon faction actually trusts you
    // world:fed_robbed -- and only while the Fed is down
    //
    // A player who qualifies on standing still cannot take it at a quiet moment,
    // which is the whole point: the world decides when, standing decides who.
    class aq_fx_opportunist {
        title       = "Opportunist";
        summary     = "The Fed is down and the neon faction owes you a hearing. Move while both are true.";
        giver       = "fixer_1";
        side        = "civ";
        requires[]  = { "rep:f_neon:250", "world:fed_robbed" };
        repeatable  = -1;
        timeLimit   = 1800;

        class objectives {
            class reach { type = "visit"; marker = "fed_reserve"; radius = 60; };
        };

        class rewards {
            money  = 4000;
            xp     = 8;
            // Moves two factions at once. Cross-faction consequence is authored
            // per quest rather than by a global rivalry matrix, so the
            // relationships stay tunable per piece of content.
            rep[]  = { {"f_neon", 150}, {"f_maxsec", -60} };
        };
    };

    class aq_fx2_flash {
        title       = "The Flash";
        summary     = "A new number, and a chip that isn't legal to own yet.";
        description = "Fixer One goes quiet the moment the ore clears -- no goodbye, just a new contact card sitting in your handset. 'One vouched for you. That chip they slipped you isn't a toy -- get it seated. You'll need a deck already flashed for that to take, so sort that first if you haven't. Then check back in -- I don't do business with ghosts I haven't met.'";
        giver       = "fixer_2";
        side        = "civ";
        requires[]  = { "quest:aq_fx1_haul" };
        repeatable  = 0;
        timeLimit   = 0;
        chain       = "aq_fx2_cast";
        icon        = "container";

        class objectives {
            // action -- counts one host-named event, nothing else. Fires
            // from core/pmenu/fn_useItem.sqf, both chip-install branches
            // (the dedicated ghostplatechip case and the generic
            // AP_chipItemMap one), so this is satisfied by seating ANY
            // chip, not only the one aq_fx1_haul rewarded.
            class seat {
                type  = "action";
                verb  = "chipinstall";
                count = 1;
                label = "Firmware seated";
            };
            // talk -- a SECOND interaction with fixer_2, after acceptance.
            // The interaction that accepted the quest doesn't count; the
            // player has to come back once the chip is in.
            class report {
                type  = "talk";
                giver = "fixer_2";
            };
        };

        class rewards {
            money      = 2000;
            xp         = 10;
            items[]    = { };
            licenses[] = { };
        };
    };

    class aq_fx2_cast {
        title       = "First Cast";
        summary     = "Point it at something and see what the deck can do.";
        description = "'Every hack you throw leaves a shape on the net, even the harmless ones. Cast something -- anything -- so you know what that shape feels like before it matters.'";
        giver       = "fixer_2";
        side        = "civ";
        requires[]  = { };
        repeatable  = 0;
        timeLimit   = 0;
        chain       = "aq_fx2_breach";
        icon        = "attack";

        class objectives {
            class first {
                type  = "action";
                verb  = "qhcast";
                count = 1;
                label = "Quickhack cast";
            };
        };

        class rewards {
            money      = 3000;
            xp         = 8;
            items[]    = { };
            licenses[] = { };
        };
    };

    class aq_fx2_breach {
        title       = "Under The Radar";
        summary     = "Arm the chain, then go through the door quiet.";
        description = "'This one's real. Buy a proxy chain and arm it before you touch anything -- MaxSec doesn't send a squad car for a quiet ATM, but a loud one gets you a Sequence-breach charge and a new roommate. The charge costs you; getting caught costs more. Burn it, take the job, and you're not nobody anymore.'";
        giver       = "fixer_2";
        side        = "civ";
        requires[]  = { };
        repeatable  = 0;
        timeLimit   = 0;
        chain       = "";
        icon        = "attack";

        class objectives {
            // Declaration order matters: only one objective is "current" at
            // a time (server/fn_srvFact.sqf), so `quiet` has to be satisfied
            // before `breach` is even live. See the file header note --
            // this is the in-fiction turn, not a coincidence.
            class quiet {
                type  = "action";
                verb  = "proxyarm";
                count = 1;
                label = "Proxy chain armed";
            };
            class breach {
                type  = "action";
                verb  = "qhbreach";
                count = 1;
                label = "Breach completed";
            };
        };

        class rewards {
            money      = 6500;
            xp         = 15;
            items[]    = { };
            licenses[] = { };
        };
    };
};


// =====================================================================
//  AQ_Templates — one radiant template per side, each with `side` set, so
//  side gating is demonstrably doing something (fn_srvBoard filters offers
//  by the requesting player's side).
// =====================================================================
class AQ_Templates {

    class civ_courier {
        side     = "civ";
        givers[] = { "fixer_1", "fixer_2", "fixer_3", "fixer_4" };
        weight   = 1;

        title       = "Copper Run";
        summary     = "Standing order: copper ore, no questions.";
        description = "Copper's always short somewhere on this island. Bring it in, get paid, no paperwork.";
        icon        = "run";
        timeLimit   = 1800;

        class objectives {
            class load {
                type     = "gather";
                item     = "copperore";
                count    = 12;
                events[] = { "aq_inventory" };
            };
            class run {
                type   = "deliver";
                item   = "copperore";
                count  = 12;
                marker = "lh_genstore";
                radius = 30;
            };
        };

        class rewards {
            money      = 800;
            xp         = 3;
            items[]    = { };
            licenses[] = { };
        };
    };

    // =================================================================
    //  THE THREE FIXER BOARDS.
    //
    //  Two templates each: one OPEN to anybody, and one gated on
    //  align:<their faction> -- which is the whole shape of the deal. A solo
    //  or an unaligned crew can always work, and always for less; the money
    //  is behind picking a side. Nothing is locked, which is what "soft
    //  pressure" means: the gate is on the offer, never on the gang.
    //
    //  Every one carries a rep[] block, because that is the ONLY thing the
    //  weekly war counts. A contract with no rep[] pays the player and moves
    //  no faction, so the matchup would never change -- see
    //  APS_fnc_factionWarSRV and the scoring hook in fn_aqRep.sqf.
    //
    //  The negative entries are authored per contract rather than coming from
    //  a global rivalry matrix (FACTION_REP_SPEC.md section 7): doing Pope's
    //  wet work costs you with the Administrator, and that is a content
    //  decision one can tune per piece, not a relationship fixed before any
    //  content existed to tune it against.
    //
    //  Every verb below is instrumented with a real aq_fnc_event call site
    //  (server-side APS_fnc_aqFact for the serverFacts[] verbs in AQ_Settings),
    //  and tools/aq_verbcheck.py fails the build if one is not -- which is
    //  what turns "silently missed a site" into a named build failure.
    // =================================================================

    // ---- POPE / CRUSADERS -- hits and grand theft --------------------
    class crusader_collection {
        side     = "civ";
        givers[] = { "fixer_2" };
        weight   = 1;

        title       = "The Collection";
        summary     = "A shop on Pope's list is behind on its tithe.";
        description = "'They have been told twice. Go and be the third telling. Take what is in the register and nothing off the shelves -- this is a debt being settled, not a robbery, and I would like the difference to be visible.'";
        icon        = "attack";
        timeLimit   = 1800;

        class objectives {
            class hit { type = "action"; verb = "robstore"; count = 1; label = "Register emptied"; };
        };

        class rewards {
            money   = 1400;
            xp      = 4;
            rep[]   = { {"f_dock", 45} };
        };
    };

    class crusader_reckoning {
        side     = "civ";
        givers[] = { "fixer_2" };
        weight   = 0;   // off the board: "execute" has no server witness (serverFacts[] above)
        // The gate. Pope does not hand this to somebody who has not knelt.
        requires[] = { "align:f_dock" };

        title       = "Reckoning";
        summary     = "Two names. Then come and say them to me.";
        description = "'Two names, and neither of them will be missed by anyone who matters. When it is done you come back here and you tell me yourself -- I will not have it said the Crusaders kill at a distance and confess by phone.'";
        icon        = "attack";
        timeLimit   = 3600;

        class objectives {
            // Declaration order is evaluation order (server/fn_srvFact.sqf reads
            // _objIds select _idx, one at a time), so the confession is not live
            // until the work is done. That ordering IS the fiction.
            class work    { type = "action"; verb = "execute"; count = 2; label = "Names settled"; };
            class confess { type = "talk";   giver = "fixer_2"; };
        };

        class rewards {
            money   = 9000;
            xp      = 18;
            rep[]   = { {"f_dock", 220}, {"f_pharma", -70} };
        };
    };

    // ---- NERO / LIGHTRUNNERS -- hacking ------------------------------
    class lightrunner_probe {
        side     = "civ";
        givers[] = { "fixer_1" };
        weight   = 1;

        title       = "Noise Floor";
        summary     = "Nero wants traffic on the net, and does not care whose.";
        description = "'I need the grid busy for twenty minutes and I do not care what you throw or at whom. Cast, keep casting, and do not get precious about targets -- you are weather tonight, not a burglar.'";
        icon        = "attack";
        timeLimit   = 1800;

        class objectives {
            class cast { type = "action"; verb = "qhcast"; count = 3; label = "Hacks cast"; };
        };

        class rewards {
            money   = 1300;
            xp      = 4;
            rep[]   = { {"f_neon", 45} };
        };
    };

    class lightrunner_blackout {
        side     = "civ";
        givers[] = { "fixer_1" };
        weight   = 1;
        requires[] = { "align:f_neon" };

        title       = "Blackout";
        summary     = "Chain up first. Then two doors, and neither of them screams.";
        description = "'Arm a proxy chain before you touch anything -- I am not paying for a trace that ends at my number. Then two breaches, quiet ones. If MaxSec hears the first you may as well go home, because they will be waiting at the second.'";
        icon        = "attack";
        timeLimit   = 2700;

        class objectives {
            // quiet is declared first, so the breaches are not even live until
            // the chain is armed -- the lesson is the sequence, not the text.
            class quiet   { type = "action"; verb = "proxyarm";  count = 1; label = "Proxy chain armed"; };
            class breaches{ type = "action"; verb = "qhbreach";  count = 2; label = "Doors opened"; };
        };

        class rewards {
            money   = 9500;
            xp      = 20;
            rep[]   = { {"f_neon", 230}, {"f_maxsec", -80} };
        };
    };

    // ---- THE ADMINISTRATOR / SILENT PARTNERS -------------------------
    class partner_freight {
        side     = "civ";
        givers[] = { "fixer_4" };
        weight   = 1;

        title       = "Freight";
        summary     = "Ore into Larche, on the clock, no questions asked or answered.";
        description = "'A quantity of copper is required at the general store in Larche within the hour. You will not be told why. You will not be met. Deliver it, and an amount consistent with the inconvenience will appear.'";
        icon        = "container";
        timeLimit   = 1800;

        class objectives {
            class load { type = "gather";  item = "copperore"; count = 14; events[] = { "aq_inventory" }; };
            class run  { type = "deliver"; item = "copperore"; count = 14; marker = "lh_genstore"; radius = 30; itemLabel = "Copper Ore"; label = "the general store"; };
        };

        class rewards {
            money   = 1500;
            xp      = 5;
            rep[]   = { {"f_pharma", 45} };
        };
    };

    class partner_housekeeping {
        side     = "civ";
        givers[] = { "fixer_4" };
        weight   = 0;   // off the board: "removewreck" has no server witness (serverFacts[] above)
        requires[] = { "align:f_pharma" };

        title       = "Housekeeping";
        summary     = "Three vehicles that were never anywhere.";
        description = "'Three wrecks are currently sitting where a MaxSec tow crew will eventually photograph them. That is an unacceptable amount of paperwork about vehicles which, as of this morning, were never purchased. Remove them. Do not read the plates.'";
        icon        = "container";
        timeLimit   = 3600;

        class objectives {
            class tidy { type = "action"; verb = "removewreck"; count = 3; label = "Wrecks removed"; };
        };

        class rewards {
            money   = 8500;
            xp      = 18;
            rep[]   = { {"f_pharma", 215}, {"f_dock", -60} };
        };
    };

    class cop_patrol {
        side     = "cop";
        givers[] = { "maxsec_command" };
        weight   = 1;

        title       = "Reserve Watch";
        summary     = "Hold a visible presence at the Federal Reserve.";
        description = "Command wants a uniform standing where people can see it. Get to the Reserve, hold position, make the cameras happy.";
        icon        = "attack";
        timeLimit   = 2400;

        class objectives {
            // visit + zoneHold are both self-contained watchers -- no host
            // instrumentation needed for either, so this template exercises
            // two more objective types at zero instrumentation risk.
            class approach {
                type   = "visit";
                marker = "fed_reserve";
                radius = 60;
            };
            class hold {
                type    = "zoneHold";
                marker  = "fed_reserve";
                radius  = 25;
                seconds = 45;
                onFoot  = 1;
            };
        };

        class rewards {
            money      = 1000;
            xp         = 4;
            items[]    = { };
            licenses[] = { };
        };
    };

    class med_supply {
        side     = "med";
        givers[] = { "pharma_technica" };
        weight   = 1;

        title       = "Cold Chain";
        summary     = "Get blood product into refrigeration before it turns.";
        description = "Product doesn't keep. Collect what's needed and get it into the dispensary's fridge before the clock runs out on it.";
        icon        = "container";
        timeLimit   = 1800;

        class objectives {
            class collect {
                type     = "gather";
                item     = "bloodbag";
                count    = 5;
                events[] = { "aq_inventory" };
            };
            class run {
                type   = "deliver";
                item   = "bloodbag";
                count  = 5;
                marker = "aq_giver_pharma_technica";
                radius = 25;
            };
        };

        class rewards {
            money      = 900;
            xp         = 3;
            items[]    = { };
            licenses[] = { };
        };
    };
};


// =====================================================================
//  AQ_Pools — empty override, deliberately.
//
//  Nothing above fills a template slot, so nothing needs a pool -- but
//  leaving this root UNDECLARED would fall back to the vendored library's
//  OWN AQ_Pools (configFile, per fn_preInit.sqf's "mission config wins,
//  else configFile" per-root resolution), whose entries carry marker names
//  from the library's own demo mission (aq_place_north_depot, aq_place_
//  quarry, ...) that do not exist here. That would go unnoticed through
//  preInit -- validation DEFERS every marker check when allMapMarkers is
//  empty, which it always is at preInit, before the mission world exists
//  (observed directly: Task 8's preInit log carried "10 marker reference(s)
//  were not checked because the map layer is not up yet") -- but an
//  ON-DEMAND `call aq_fnc_validate`, run after the mission is up, does NOT
//  defer, and would fail on them for real. Same fix Task 8 applied to
//  AQ_Quests/AQ_Templates for the identical reason: an empty mission-owned
//  override supersedes the demo root wholesale rather than merging with it.
class AQ_Pools {};
