// SPDX-License-Identifier: MIT
/*
    config/profile_default.hpp
    AQ_Profile — the mapping table from what ArmaQuest needs to what the host calls it.

    WHY THIS EXISTS
        Every Life-derived mission has money, virtual items, licences and a player
        identity, and no two of them agree on what any of those are called. A quest
        system that calls the host's functions directly is a quest system that must be
        forked to be installed, and a forked install never takes an upstream fix again.

        One table of function NAMES, resolved once at preInit, keeps the engine free of
        host identifiers entirely. It also makes an unwired install detectable: a name
        that resolves to nothing is caught at preInit, by quest, with the missing entry
        named — instead of at payout time, after the player has already done the work.

    WHAT IT DOES
        Maps eleven capabilities onto global function names. Each name is looked up once
        and cached as code. An entry left as "" means "this host cannot do this", which
        is a legitimate answer: the capability is treated as unavailable, any quest that
        needs it is rejected at preInit with a named error, and nothing crashes at
        runtime. The stubs referenced below are defined in profile_default.sqf, which is
        the ONLY file a host edits.

    Usage: included by CfgArmaQuest.hpp; no separate include needed.

    THE CONTRACT
        Everything that PAYS, GRANTS or CONSUMES is called ON THE SERVER, with a player
        UID string rather than an object, because the server is the only machine allowed
        to decide that a reward happened (DESIGN.md section 2) and because a UID survives
        a unit the object reference does not. If the host's real implementation needs the
        unit, resolve it from the UID inside the stub — profile_default.sqf ships a
        helper that does.

        TWO ENTRIES ARE ALSO READ ON THE CLIENT. `playerUid` and `countItem` are called
        by the objective watchers, on the machine the player is on: the whole reason a
        watcher lives on the client is that only the client knows where the player is
        standing and what they are carrying. Those reads feed the local display and the
        watcher's own gating, they never grant anything, and the server re-reads
        `countItem` itself before it agrees with any of it. Write both so they answer
        correctly on either machine. Everything else here runs on the server only.

        Every function returns a value and must return it truthfully. A payMoney that
        returns true without paying turns a payout failure into a completed quest with
        no reward, which is the single worst outcome this system can produce: the player
        cannot repeat the quest and has nothing to show for it. Return false and let the
        server log it and retry.
*/

class AQ_Profile {

    // [uid, amount] -> BOOL   Credit the player. false if it could not be done.
    payMoney     = "aq_life_fnc_payMoney";

    // [uid, amount] -> BOOL   Debit the player. false if they could not afford it.
    takeMoney    = "aq_life_fnc_takeMoney";

    // [uid, class, qty] -> BOOL   Add virtual items. false if there was no room.
    giveItem     = "aq_life_fnc_giveItem";

    // [uid, class, qty] -> BOOL   Remove virtual items. false if they did not have them.
    // This is the one `deliver` calls to consume cargo on arrival, so a false here
    // must mean "nothing was taken", never "some of it was taken".
    takeItem     = "aq_life_fnc_takeItem";

    // [uid, class] -> NUMBER   How many they hold right now. The server re-reads this
    // before agreeing with any client-reported count, which is what makes a lying
    // client harmless rather than profitable.
    countItem    = "aq_life_fnc_countItem";

    // [uid, license] -> BOOL   Used by requires[] = { "license:..." }.
    hasLicense   = "aq_life_fnc_hasLicense";

    // [uid, license] -> BOOL   Used by rewards >> licenses[].
    grantLicense = "aq_life_fnc_grantLicense";

    // [object] -> STRING   The stable identity a player's quest state is stored under.
    // The one entry that must never be "": without it there is no key to persist under
    // and the store cannot function. preInit fails loudly if it is empty.
    playerUid    = "aq_life_fnc_playerUid";

    // [uid, amount] -> BOOL   Optional. "" is the shipped default because most hosts
    // have no experience system, and inventing one for them would be a second, worse
    // progression system competing with theirs. When this is "", every rewards >> xp
    // value in the config is ignored silently and deliberately — it is declared
    // content that this host has no way to deliver, not an error.
    awardXp      = "";

    // [uid] -> STRING   The faction this player's ORGANISATION is aligned with, or
    // "" for none. Optional; "" is the shipped default because most hosts have no
    // notion of a player belonging to a group that itself takes sides, and the
    // library deliberately has none either -- it asks the host a question and
    // compares the answer to a string.
    //
    // This is what separates ALLEGIANCE from STANDING. getRep answers "how much does
    // this faction like you", which an individual earns; this answers "whose side is
    // your crew on", which an individual does not decide alone. Content that should
    // reach only a committed organisation gates on requires[] = { "align:<factionId>" },
    // and content that merely wants somebody with a patron uses "align:any".
    //
    // When this is "", every align: token is unsatisfied rather than ignored -- the
    // same direction every other missing profile entry fails in, because a gate the
    // host cannot answer must not become an open door.
    factionOf    = "";

    // [uid, factionId] -> NUMBER   Standing with that faction right now. A faction
    // absent from wherever the host stores standing reads as 0 -- neutral -- which
    // must never be a written row: absence and neutrality are the same state, and
    // storing both invites them to disagree. Used by
    // requires[] = { "rep:<factionId>:<n>" }.
    getRep       = "aq_life_fnc_getRep";

    // [uid, factionId, delta] -> BOOL   Move standing by delta, which MAY BE
    // NEGATIVE — standing below zero is hostile and is not an error case. false if
    // it could not be applied. Used by rewards >> rep[]. Any gang-alignment
    // multiplier or hostility-floor damping is this implementation's business to
    // apply; no caller of addRep has to know either rule.
    addRep       = "aq_life_fnc_addRep";
};
