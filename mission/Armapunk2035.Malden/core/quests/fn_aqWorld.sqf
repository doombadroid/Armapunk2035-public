/*
    File: fn_aqWorld.sqf  (AP_fnc_aqWorld)

    Registers this mission's world-state resolvers with ArmaQuest, so content can
    gate on what the server looks like right now:

        requires[] = { "world:fed_robbed" };
        requires[] = { "world:cartel_arms:50056" };

    See WORLD_STATE_SPEC.md. Called once, server-side, from postInit.

    WHY A REGISTRY AND NOT A VARIABLE NAME. Content names a key; this file maps the
    key to code. The library therefore learns nothing about what a cartel is -- the
    same discipline as sqlExec, the profile and the trigger drivers -- an
    unregistered key is a NAMED problem at preInit rather than a quest that can
    never appear, and every mission-specific global lives in this one file rather
    than scattered through a config that a web quest editor will eventually
    generate for people who have never heard of AP_fed_robbed.

    RESOLVERS MUST BE CHEAP AND MUST NOT BLOCK. Each is called during offer
    building, per candidate quest, for every player who opens a giver. Anything
    that would query a database belongs behind a cached published variable, not in
    here. Every resolver below reads a variable some other system already
    maintains; none does work of its own.

    THEY MUST ALSO NOT MUTATE ANYTHING. Prerequisite evaluation is a pure function
    of (player, quest, world-at-this-instant), which is what stops the order offers
    are built in from changing what is reachable. A resolver with a side effect
    breaks that quietly.
*/

if (!isServer) exitWith {};
if (isNil "aq_fnc_registerWorld") exitWith {
    diag_log "[AP][world] aq_fnc_registerWorld is not defined; ArmaQuest is not armed. No world resolvers registered.";
};

// ---------------------------------------------------------------- events
// Truthy while a heist or event is live. Each of these globals is already
// maintained and published by the system that owns it; this only reads them.
["fed_robbed",    { !isNil "AP_fed_robbed"        && {AP_fed_robbed} }]         call aq_fnc_registerWorld;
["bank_active",   { !isNil "AP_bank_inProgress"   && {AP_bank_inProgress} }]    call aq_fnc_registerWorld;
["prison_active", { !isNil "AP_prison_inProgress" && {AP_prison_inProgress} }]  call aq_fnc_registerWorld;
["purge",         { !isNil {localNamespace getVariable "AP_purgeZone"} }]        call aq_fnc_registerWorld;   // server's own copy (Lsec-0-1)

// ---------------------------------------------------------------- cartels
// Two forms, because content wants to ask two different questions:
//
//   world:cartel_arms:50056     held by that GANG
//   world:cartelf_arms:f_neon   held by a gang aligned with that FACTION
//
// Returning the holder rather than a boolean is what makes the value form work
// at all -- a resolver answering true/false could only ever express "somebody
// holds it".
//
// AP_<name>Cartel is [held, ?, gangId]; index 2 is what fn_virtualShopMenu.sqf
// actually sets (`AP_wongsCartel set[2, _flagGangID]`), read there rather than
// inferred from the shape.
//
// The faction form resolves through AP_gangFactions, the published gang->faction
// mirror maintained by APS_fnc_gangAlignSRV. In memory, deliberately: these run
// during offer building, per candidate quest, for every player who opens a giver,
// so a database query here would be a query per quest per player. That is why the
// mirror exists at all rather than this doing the lookup itself.
// Two separate loops, one key family each, deliberately. Registering both from a
// single loop body works at runtime but defeats static analysis: tools/aq_check.py
// resolves a forEach's generated keys by reading the ONE format registration it
// finds, so a second one in the same body falls back to prefix matching -- and a
// prefix match silently accepts any key sharing it, so "cartel_gold" would pass
// while being registered nowhere. One registration per loop keeps every generated
// key statically known, which is what lets the offline checker catch a typo'd
// cartel name before a deploy rather than after one.
{
    private _cartel = _x;
    [format ["cartel_%1", _cartel], {
        private _v = missionNamespace getVariable [format ["AP_%1Cartel", _cartel], []];
        if (!(_v isEqualType []) || {count _v < 3}) exitWith { "" };
        if !(_v param [0, false]) exitWith { "" };   // unheld -> "" -> matches nothing, and is falsey
        str (_v param [2, ""])
    }] call aq_fnc_registerWorld;
} forEach ["wongs", "arms", "drug", "oil"];

{
    private _cartel = _x;
    [format ["cartelf_%1", _cartel], {
        private _v = missionNamespace getVariable [format ["AP_%1Cartel", _cartel], []];
        if (!(_v isEqualType []) || {count _v < 3}) exitWith { "" };
        if !(_v param [0, false]) exitWith { "" };
        private _gid = _v param [2, -1];
        private _map = missionNamespace getVariable ["AP_gangFactions", []];
        private _i = _map findIf { (_x param [0, -1]) isEqualTo _gid };
        // An unaligned holder answers "" -- the cartel IS held, but by nobody a
        // faction gate can match. Different from unheld; both correctly falsey.
        if (_i isEqualTo -1) then { "" } else { (_map select _i) param [1, ""] }
    }] call aq_fnc_registerWorld;
} forEach ["wongs", "arms", "drug", "oil"];

// ---------------------------------------------------------------- the war
// This week's matchup, so content can be written against it:
//
//   requires[] = { "world:war_defender:f_neon" };   only while the Lightrunners
//                                                   are the ones being hunted
//   requires[] = { "world:war_neutral:f_dock" };    only on Pope's quiet week
//
// Each returns a faction id, never a boolean, because the value form is what makes
// them useful -- a resolver answering true/false could only ever say "somebody is
// the defender", which is true every week and gates nothing.
//
// Reads the published AP_factionWar, which APS_fnc_factionWarSRV maintains. In
// memory, like every other resolver here: these run during offer building, per
// candidate quest, for every player who opens a giver, and a database read on that
// path is the thing this whole file exists to avoid.
//
// Before the first tick has published, AP_factionWar is nil and every one of these
// answers "" -- matching nothing, which is the correct reading of "no war is
// scheduled yet" and the same failure direction as an unheld cartel above.
//
// One registerWorld call per forEach body, per the rule below: tools/aq_check.py
// resolves a loop's generated keys by reading the single format registration it
// finds, and a second one in the same body drops it to prefix matching -- which
// would silently accept "war_anything".
{
    private _slot = _x;
    [format ["war_%1", _slot], {
        private _w = missionNamespace getVariable ["AP_factionWar", []];
        if (!(_w isEqualType []) || {count _w < 3}) exitWith { "" };
        _w param [["aggressor", "defender", "neutral"] find _slot, ""]
    }] call aq_fnc_registerWorld;
} forEach ["aggressor", "defender", "neutral"];

// ---------------------------------------------------------------- turf
// DELIBERATELY ABSENT. An earlier draft registered "turf_active" against
// AP_turf_active -- a variable that exists nowhere in this mission. It would have
// resolved to -1 forever, so every turf-gated quest would simply never have
// appeared, with nothing in any log to say why. Turf state lives in the
// turf_state table and has no published mirror; registering a key for it means
// publishing one first. A resolver reading a variable nobody sets is worse than
// no resolver, because content can be written against it.

diag_log "[AP][world] resolvers registered: fed_robbed, bank_active, prison_active, purge, cartel_/cartelf_{wongs,arms,drug,oil}, war_{aggressor,defender,neutral}";
