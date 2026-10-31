// SPDX-License-Identifier: MIT
/*
    config/CfgFunctions.hpp
    The function manifest: every ArmaQuest function the engine compiles at mission load.

    WHY THIS EXISTS
        A function that is not listed here does not exist at runtime. The symptom is
        an "undefined variable" error deep inside an unrelated call, minutes into a
        session, with nothing pointing back at the real cause. Keeping one manifest —
        one line per file, grouped by directory — means the answer to "why is
        aq_fnc_x nil?" is always "look in this file" and never a search of the repo.

        The mirror of that rule matters just as much: a line here whose file does NOT
        exist produces a script-file-not-found at mission load and leaves the name
        nil, which is the same undefined-variable failure with an extra step. So this
        file is exactly one line per file that exists — no aspirational entries, no
        placeholders for work in progress.

        The second failure this file guards against is the include site. This file
        declares the tag class `aq` and MUST be included directly inside the mission's
        root `class CfgFunctions`. If it is nested one level deeper — inside another
        project's tag class, which is the usual mistake when a host already has a
        CfgFunctions block — the engine happily compiles everything under THAT tag
        instead. Every function is then called `<theirtag>_fnc_...`, every
        `aq_fnc_...` reference in this library is nil, and the config parses without a
        single warning. It is a silent, total failure that looks like "the mod did not
        load".

    WHAT IT DOES
        Declares tag class `aq`, one category class per source directory, and one class
        per function. Function class `foo` in a category whose `file` is `dir` loads
        `dir\fn_foo.sqf` and defines the global `aq_fnc_foo`. A function class may also
        carry its own `file = ` naming an exact path, which is how the one file whose
        name does not follow the `fn_` convention is registered.

        Four entries carry engine hooks:
          - `profileDefault`  preInit = 1   (declared FIRST — see ORDERING below)
          - `preInit`         preInit = 1
          - `postInit`        postInit = 1
          - `srvInit`         postInit = 1

    Usage (in the mission's description.ext, at root level):

        #include "ArmaQuest\config\CfgArmaQuest.hpp"

        class CfgFunctions {
            #include "ArmaQuest\config\CfgFunctions.hpp"
        };

    INSTALL PATH
        Every `file = ` line below is written relative to the mission root and assumes
        the library sits in `<mission>\ArmaQuest\`. If you install it somewhere else,
        change those `file = ` lines and nothing else. They are deliberately literal
        strings rather than a preprocessor macro: config paths built by macro expansion
        fail by producing a path that does not exist, and a path that does not exist is
        reported once, early, in a log nobody is reading yet.

    ORDERING
        `profileDefault` is declared before `preInit` because `aq_fnc_preInit` validates
        the profile mapping (DESIGN.md section 9) and must find the default stubs already
        defined. UNVERIFIED: preInit functions are executed in config declaration order
        within a tag class. Confirm by launching with -showScriptErrors and checking the
        RPT: `[AQ] profile stubs defined` must appear before `[AQ] preInit`. If it does
        not, `aq_fnc_preInit` calls `aq_fnc_profileDefault` itself when
        `aq_life_fnc_playerUid` is nil, so the order is a performance detail, not a
        correctness one.

    SERVER-ONLY FUNCTIONS
        CfgFunctions has no "compile on server only" switch. Every function listed here
        is compiled on every machine, including the `aq_fnc_srv*` set. That is fine and
        intended: compilation is cheap, and having the name defined everywhere means a
        misrouted call fails with a clear "not the server" log line instead of an
        undefined-variable error that says nothing about what went wrong. The actual
        guard is the first line of each server file (`if (!isServer) exitWith {}`) and
        the remoteExec target it is called on. Do not try to express authority here.

    ADDING A FUNCTION
        Add the file, add one line here, done. Do not pre-declare functions you have
        not written.
*/

class aq {

    // ------------------------------------------------------------------
    // config/  — the host-editable profile stubs.
    // Declared first so the mapping table in AQ_Profile resolves during preInit
    // validation. See ORDERING above.
    // ------------------------------------------------------------------
    // (Category class names only group functions and supply the path; they generate
    // no variable of their own. This one is NOT called `profile` because the engine
    // has a function of that name below, and two identically named classes in this
    // file — even in different scopes — is a confusion nobody needs at 3am.)
    class hostProfile {
        file = "ArmaQuest\config";
        // The one file in the library not named fn_<name>.sqf: it is the file a host
        // edits, so it is named for what it is rather than for what registers it.
        // The explicit `file =` is what reconciles the two.
        class profileDefault {
            file    = "ArmaQuest\config\profile_default.sqf";
            preInit = 1;
        };
    };

    // ------------------------------------------------------------------
    // functions/  — the engine. Runs on client and server; the split of authority
    // is enforced by which machine a function is called on, not by this list.
    // ------------------------------------------------------------------
    class engine {
        file = "ArmaQuest\functions";

        // lifecycle
        class preInit  { preInit  = 1; };   // index config, register shipped types/triggers, validate
        class postInit { postInit = 1; };   // client: arm the givers, ask the server for this player's quests

        // plumbing every other function leans on
        class text    { };                  // resolve a config string: literal or $STR_ key, plus %SLOT%
        class setting { };                  // read one AQ_Settings key with a typed default
        class cfgGet  { };                  // read one member from a CONFIG or a HashMap alike
        class profile { };                  // resolve an AQ_Profile entry to a name, or call it
        class cfgQuest { };                 // the only way the runtime reads the quest catalogue

        // extension points (DESIGN.md sections 4 and 8)
        class registerType    { };          // ["gather", aq_fnc_typeGather] call aq_fnc_registerType
        class registerTrigger { };          // ["phone", myFnc] call aq_fnc_registerTrigger
        class registerWorld   { };          // ["fed_robbed", {...}] call aq_fnc_registerWorld

        // event bus (DESIGN.md section 5)
        class event       { };              // host entry point: ["aq_sold", ["copper", 10]] call aq_fnc_event
        class subscribe   { };              // called by a type during `arm`
        class unsubscribe { };              // called by a type during `disarm`; must be idempotent
        class report      { };              // a type's fact channel; wraps `fact`
        class fact        { };              // client -> server: report one fact, never a verdict

        // objective lifecycle on the client
        class armObjective    { };          // arm one objective of one active quest
        class disarmObjective { };          // tear it down
        class task            { };          // mirror quest state onto the native task list

        // giver / offer flow
        class openOffers { };               // a trigger driver's job: [_giverId] call aq_fnc_openOffers
        class accept     { };               // request acceptance of an offer (server decides)
        class abandon    { };               // request abandonment

        // journal bridge (arma-webui) and the server's push
        class journal { };                  // the client's inbound door and the page bridge
        class sync    { };                  // SERVER -> CLIENT: wire payload -> quest records

        // radiant generation (DESIGN.md section 7). Compiled everywhere, called on
        // the server; the client never generates a quest.
        class genOffer     { };             // template -> concrete quest instance
        class fillSlots    { };             // resolve every slot, then substitute
        class pickFromPool { };             // one slot, under its constraints
        class scaleReward  { };             // apply scaleWith at generation time
    };

    // ------------------------------------------------------------------
    // types/  — objective type plugins. One file, one type, five verbs and an
    // optional sixth (`events`, which must still be answered).
    // Registration happens in aq_fnc_preInit; a type missing `progress` or
    // `describe` fails registration loudly rather than reaching players.
    // ------------------------------------------------------------------
    class types {
        file = "ArmaQuest\types";
        class typeGather   { };   // hold N of an item
        class typeSell     { };   // sell N of an item
        class typeCraft    { };   // craft N of an item
        class typeDeliver  { };   // carry N of an item to a place, consumed on arrival
        class typeZoneHold { };   // stand in a radius, on foot, for N seconds
        class typeVisit    { };   // reach a place
        class typeKill     { };   // N kills matching a filter
        class typeTalk     { };   // interact with a giver
        class typeAction   { };   // count N occurrences of a named host event
    };

    // ------------------------------------------------------------------
    // server/  — authority. State machine, board, payout, store drivers.
    // Compiled everywhere (see SERVER-ONLY FUNCTIONS above); guarded inside.
    // ------------------------------------------------------------------
    class server {
        file = "ArmaQuest\server";

        class srvInit { postInit = 1; };     // exits immediately unless isServer

        // state machine (DESIGN.md section 11)
        class srvFact     { };               // receive a client fact, rate-limited, decide if it satisfies
        class srvAccept   { };               // offered -> active
        class srvComplete { };               // active  -> completed, then payout, then chain
        class srvFail     { };               // active  -> failed | expired | abandoned
        class srvPayout   { };               // the only place a reward is granted

        // board and givers (DESIGN.md sections 7 and 8)
        class srvBoard       { };            // maintain K offers per giver, answer an offers request
        class srvSpawnGivers { };            // spawn giver objects at their markers and publish them

        // store facade (DESIGN.md section 10) — write-behind
        class srvStore { };

        // store drivers, selected by AQ_Settings >> store
        class storeProfile { };              // default; profileNamespace, fine for coop
        class storeExtDB   { };              // stub with the query shape documented
        class storeNone    { };              // quests reset each session
        class storeSql     { };              // generic SQL driver behind a host-named sqlExec
    };

    // ------------------------------------------------------------------
    // diagnostics/  — validators and probes (DESIGN.md section 13).
    // These ship as part of the library, not as scaffolding, because silent
    // failure is the failure mode this whole system is written against.
    // ------------------------------------------------------------------
    class diagnostics {
        file = "ArmaQuest\diagnostics";
        class validate     { };   // every quest, template, pool, giver and profile entry resolves
        class reachability { };   // which quests can no player ever reach?
        class dryRun       { };   // generate N radiant instances and print them
        class dumpState    { };   // one player's quest state, decoded
    };
};
