// SPDX-License-Identifier: MIT
/*
    config/profile_default.sqf
    The stub implementations behind AQ_Profile. THE ONE FILE A HOST EDITS.

    WHY THIS EXISTS
        The alternative to a stub file is an install guide that says "now go and edit
        the engine". Every host that follows it has a forked engine and can never take
        an upstream fix again. Every host that half-follows it has a quest system that
        completes quests and pays nothing, discovered by a player rather than by the
        admin.

        So the seam is a real file with real, runnable implementations. An unedited
        install works end to end against a small self-contained demo economy, which
        means the first thing a new host sees is a working quest rather than a stack of
        undefined-variable errors. And because that demo economy is loudly named, it is
        obvious that it is a placeholder — unlike a stub that returns true and does
        nothing, which is indistinguishable from a correct install right up until an
        audit.

    WHAT IT DOES
        Defines the eleven aq_life_fnc_* globals named by AQ_Profile in
        profile_default.hpp, plus one internal helper. Each definition is guarded by
        isFinal, so anything the host has already defined with compileFinal wins and this
        file becomes a fallback rather than an overwrite. Each one carries a HOST EDIT
        banner naming exactly what to substitute.
        LOCAL EDIT (Armapunk 2035, security 2026-09-26): compileFinal + isFinal, was a
        plain {} guarded by isNil. Any client's publicVariable replaces a plain global on
        every machine, the server included, so a plain definition is remote code.

    Usage: registered in CfgFunctions.hpp as aq_fnc_profileDefault with preInit = 1;
           it runs itself at mission load. To reload it by hand while authoring:
               call aq_fnc_profileDefault;

    THE DEMO ECONOMY
        Money, items and licences are stored as public object variables on the player
        unit:
            aq_demo_cash            NUMBER
            aq_demo_item_<class>    NUMBER
            aq_demo_lic_<license>   BOOL
        They are public so a client-side journal can display them without asking the
        server. They live on the unit, so they are gone when the player disconnects.
        That is correct for a demo and wrong for a server, which is the point: replace
        them before you run this in front of anyone.

    EVERYTHING THAT PAYS, GRANTS OR CONSUMES RUNS ON THE SERVER
        with a UID string, not an object (see profile_default.hpp, THE CONTRACT).
        `playerUid` and `countItem` are the two exceptions: the objective watchers read
        them on the client as well, for the local display and their own gating, so both
        must answer correctly on either machine. The stubs below do, because they resolve
        the unit through allPlayers rather than through anything server-only. If
        your host's real call must run on the owning client, remoteExec it from inside
        the stub and return whether the request was DISPATCHED — but understand what
        you have given up: the server can no longer tell that the payment happened, and
        a client that drops the call keeps the completed quest. Prefer a server-side
        implementation for anything that pays.
*/

// Written straight to the RPT with the library's own prefix. This file runs at
// preInit, before anything else in the library exists, so it cannot lean on any
// of it -- that independence is the point: an install where nothing else loaded
// must still say that the profile stubs were defined.
private _log = {
    params [["_msg", "", [""]]];
    diag_log ("[AQ] " + _msg)
};


// ---------------------------------------------------------------------
// Internal helper — UID to unit.
// Not an AQ_Profile entry: the profile table is exactly the capabilities in
// DESIGN.md section 9, and growing it here would make every host's table diverge
// from the documented one. This is an implementation detail of the stubs.
//
// Returns objNull when the player is not online. Every caller below treats objNull
// as "cannot do this" and says so, rather than acting on a null object — an
// operation on objNull is silently discarded by the engine, which would turn an
// offline player into a payout that reports success and does nothing.
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_unitFromUid") then {
    aq_life_fnc_unitFromUid = compileFinal {
        params [["_uid", "", [""]]];
        if (_uid isEqualTo "") exitWith { objNull };
        private _hit = allPlayers select { getPlayerUID _x isEqualTo _uid };
        if (_hit isEqualTo []) exitWith { objNull };
        _hit select 0
    };
};


// ---------------------------------------------------------------------
// payMoney   [uid, amount] -> BOOL
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_payMoney") then {
    aq_life_fnc_payMoney = compileFinal {
        params [["_uid", "", [""]], ["_amount", 0, [0]]];
        if (_amount <= 0) exitWith { true };   // paying nothing succeeds trivially

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith {
            diag_log format ["[AQ] payMoney: uid %1 is not online, %2 not paid", _uid, _amount];
            false
        };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's credit call. It must be authoritative and it must
        // report failure honestly. Two shapes are usual:
        //   1. a server-side bank write followed by a sync to the owning client
        //   2. a client-side wallet update via remoteExec (see the warning in the
        //      header — the server then cannot confirm the payment landed)
        // Return true only if the money is actually there afterwards.
        private _cash = _unit getVariable ["aq_demo_cash", 0];
        _unit setVariable ["aq_demo_cash", _cash + _amount, true];
        // ---------------------------------------------------------------

        true
    };
};


// ---------------------------------------------------------------------
// takeMoney   [uid, amount] -> BOOL   false when they cannot afford it
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_takeMoney") then {
    aq_life_fnc_takeMoney = compileFinal {
        params [["_uid", "", [""]], ["_amount", 0, [0]]];
        if (_amount <= 0) exitWith { true };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith {
            diag_log format ["[AQ] takeMoney: uid %1 is not online, %2 not taken", _uid, _amount];
            false
        };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's debit call. Check affordability and debit in the
        // same place: a check here and a debit somewhere else is a race a player
        // will find. Return false without taking anything if they are short.
        private _cash = _unit getVariable ["aq_demo_cash", 0];
        if (_cash < _amount) exitWith { false };
        _unit setVariable ["aq_demo_cash", _cash - _amount, true];
        // ---------------------------------------------------------------

        true
    };
};


// ---------------------------------------------------------------------
// giveItem   [uid, class, qty] -> BOOL   false when there was no room
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_giveItem") then {
    aq_life_fnc_giveItem = compileFinal {
        params [["_uid", "", [""]], ["_class", "", [""]], ["_qty", 0, [0]]];
        if (_class isEqualTo "") exitWith {
            diag_log "[AQ] giveItem: empty item class"; false
        };
        if (_qty <= 0) exitWith { true };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith {
            diag_log format ["[AQ] giveItem: uid %1 is not online, %2 x %3 not given", _uid, _qty, _class];
            false
        };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's virtual-inventory add. If your inventory has a
        // weight or slot limit, enforce it HERE and return false when it will not
        // fit — the caller handles a refused reward, but it cannot detect a reward
        // that vanished into a full inventory.
        private _key = "aq_demo_item_" + _class;
        _unit setVariable [_key, (_unit getVariable [_key, 0]) + _qty, true];
        // ---------------------------------------------------------------

        true
    };
};


// ---------------------------------------------------------------------
// takeItem   [uid, class, qty] -> BOOL   all or nothing
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_takeItem") then {
    aq_life_fnc_takeItem = compileFinal {
        params [["_uid", "", [""]], ["_class", "", [""]], ["_qty", 0, [0]]];
        if (_class isEqualTo "") exitWith {
            diag_log "[AQ] takeItem: empty item class"; false
        };
        if (_qty <= 0) exitWith { true };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith {
            diag_log format ["[AQ] takeItem: uid %1 is not online, %2 x %3 not taken", _uid, _qty, _class];
            false
        };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's virtual-inventory remove. This MUST be all or
        // nothing. A partial take is how a delivery objective eats half a player's
        // cargo and then reports that the delivery did not happen.
        private _key = "aq_demo_item_" + _class;
        private _have = _unit getVariable [_key, 0];
        if (_have < _qty) exitWith { false };
        _unit setVariable [_key, _have - _qty, true];
        // ---------------------------------------------------------------

        true
    };
};


// ---------------------------------------------------------------------
// countItem   [uid, class] -> NUMBER
// The server re-reads this before agreeing with a client-reported count.
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_countItem") then {
    aq_life_fnc_countItem = compileFinal {
        params [["_uid", "", [""]], ["_class", "", [""]]];
        if (_class isEqualTo "") exitWith {
            diag_log "[AQ] countItem: empty item class"; 0
        };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith { 0 };   // offline holds nothing; not an error

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's virtual-inventory read. Return 0 for an unknown
        // item class rather than erroring: an objective naming an item this host
        // does not have is caught by aq_fnc_validate at preInit, and doing it again
        // here on every progress tick would cost more than it catches.
        _unit getVariable ["aq_demo_item_" + _class, 0]
        // ---------------------------------------------------------------
    };
};


// ---------------------------------------------------------------------
// hasLicense   [uid, license] -> BOOL
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_hasLicense") then {
    aq_life_fnc_hasLicense = compileFinal {
        params [["_uid", "", [""]], ["_license", "", [""]]];
        if (_license isEqualTo "") exitWith {
            diag_log "[AQ] hasLicense: empty license id"; false
        };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith { false };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's licence lookup. Note this is read on the server
        // for requires[] evaluation, so it must not depend on any client-only
        // variable; if your licences live on the client, mirror them to the server
        // on connect and read the mirror here.
        _unit getVariable ["aq_demo_lic_" + _license, false]
        // ---------------------------------------------------------------
    };
};


// ---------------------------------------------------------------------
// grantLicense   [uid, license] -> BOOL
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_grantLicense") then {
    aq_life_fnc_grantLicense = compileFinal {
        params [["_uid", "", [""]], ["_license", "", [""]]];
        if (_license isEqualTo "") exitWith {
            diag_log "[AQ] grantLicense: empty license id"; false
        };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith {
            diag_log format ["[AQ] grantLicense: uid %1 is not online, %2 not granted", _uid, _license];
            false
        };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's licence grant, including whatever persistence it
        // needs. Granting a licence that is not saved produces a player who was paid
        // once and locked out of the chain after the next restart.
        _unit setVariable ["aq_demo_lic_" + _license, true, true];
        // ---------------------------------------------------------------

        true
    };
};


// ---------------------------------------------------------------------
// playerUid   [object] -> STRING
// The one entry that must never be empty: it is the key everything persists under.
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_playerUid") then {
    aq_life_fnc_playerUid = compileFinal {
        params [["_unit", objNull, [objNull]]];
        if (isNull _unit) exitWith { "" };

        // ---- HOST EDIT ------------------------------------------------
        // getPlayerUID is correct for almost every host and is the shipped default.
        // Substitute only if your fork keys players on something else (a database id,
        // a character slot). Whatever you return must be STABLE ACROSS SESSIONS and
        // UNIQUE PER CHARACTER; if it is neither, quest progress will be attributed
        // to the wrong player and the store will look corrupt.
        //
        // UNVERIFIED: getPlayerUID returns "" for a headless client or a unit that is
        // not a player. Confirm by calling aq_fnc_dumpState against a headless client
        // slot — it must report an empty uid and refuse, not persist under "".
        getPlayerUID _unit
        // ---------------------------------------------------------------
    };
};


// ---------------------------------------------------------------------
// awardXp is intentionally NOT defined.
//
// AQ_Profile >> awardXp is "" in profile_default.hpp, which the engine reads as
// "this host cannot award experience". Every rewards >> xp value in the config is
// then ignored. To enable it: define aq_life_fnc_awardXp here with the signature
// [uid, amount] -> BOOL, and set awardXp = "aq_life_fnc_awardXp" in
// profile_default.hpp. Defining the function without setting the config entry does
// nothing — the table is the switch, deliberately, so that one edit in one file
// decides what this host can do.
// ---------------------------------------------------------------------


// ---------------------------------------------------------------------
// getRep   [uid, factionId] -> NUMBER
// A faction absent from the player's standing reads as 0 -- neutral -- which is
// this demo store's natural default and needs no special case, exactly like
// countItem reading an item nobody has.
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_getRep") then {
    aq_life_fnc_getRep = compileFinal {
        params [["_uid", "", [""]], ["_factionId", "", [""]]];
        if (_factionId isEqualTo "") exitWith {
            diag_log "[AQ] getRep: empty faction id"; 0
        };

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith { 0 };   // offline reads as neutral; not an error

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's standing read. FACTION_REP_SPEC.md section 3.1
        // stores this as one mres-encoded column, players.faction_rep, read BARE
        // and never QUOTE()-wrapped -- the mres rule this codebase has already
        // been bitten by twice. This demo has no database and keeps standing on
        // the unit instead, which is why it does not survive a relog; that is
        // correct for a demo and wrong for a server, exactly like aq_demo_cash.
        _unit getVariable ["aq_demo_rep_" + _factionId, 0]
        // ---------------------------------------------------------------
    };
};


// ---------------------------------------------------------------------
// addRep   [uid, factionId, delta] -> BOOL   delta MAY BE NEGATIVE
// ---------------------------------------------------------------------
if !(isFinal "aq_life_fnc_addRep") then {
    aq_life_fnc_addRep = compileFinal {
        params [["_uid", "", [""]], ["_factionId", "", [""]], ["_delta", 0, [0]]];
        if (_factionId isEqualTo "") exitWith {
            diag_log "[AQ] addRep: empty faction id"; false
        };
        if (_delta isEqualTo 0) exitWith { true };   // moving nothing succeeds trivially

        private _unit = [_uid] call aq_life_fnc_unitFromUid;
        if (isNull _unit) exitWith {
            diag_log format ["[AQ] addRep: uid %1 is not online, %2 vs '%3' not applied", _uid, _delta, _factionId];
            false
        };

        // ---- HOST EDIT ------------------------------------------------
        // Substitute your fork's standing write. FACTION_REP_SPEC.md section 4.1
        // applies a gang-alignment multiplier to gains HERE, internally, so no
        // caller of addRep has to know that rule; section 4.3 damps rather than
        // zeroes accrual at or below the hostility floor, so a wrecked standing
        // can always climb back. Neither rule is implemented in this demo, which
        // just adds the delta.
        private _key = "aq_demo_rep_" + _factionId;
        _unit setVariable [_key, (_unit getVariable [_key, 0]) + _delta, true];
        // ---------------------------------------------------------------

        true
    };
};


["profile stubs defined (demo economy — replace before running this on a server)"] call _log;
