/*
    File: fn_aqProfile.sqf  (AP_fnc_aqProfile)

    Registered preInit=1 (Functions.h, category "quests"). Its only job is to
    run once, early, and leave nine global functions behind in
    missionNamespace -- the ArmaQuest capability table (aq_content.hpp, class
    AQ_Profile) names them by string, and the library's own preInit
    validation (ArmaQuest\diagnostics\fn_validate.sqf) looks each name up and
    refuses to arm (aq_ready = false) if one resolves to nothing. So these
    names must exist before that validation runs. Functions.h places this
    whole tag (AP_Client_Core) textually ahead of ArmaQuest's own `aq` tag in
    the merged CfgFunctions body for exactly that reason -- verified by
    reading Functions.h, not assumed. Confirm empirically after any reorder:
    grep the RPT for "[AQ]" and make sure no profile entry is reported
    unresolved (see aq_content.hpp for the exact grep).

    THE CONTRACT (ArmaQuest/config/profile_default.hpp, not itself vendored
    edited -- read only): everything that pays, grants or consumes is called
    ON THE SERVER, with a player UID STRING, never an object -- the server is
    the only machine allowed to decide a reward happened, and a UID survives
    a disconnect an object reference does not. playerUid and countItem are
    also read on the CLIENT, because the objective watchers that gate quest
    progress live there.

    Do NOT wire any of this inside ArmaQuest/ -- that whole tree is a
    byte-identical vendored copy (scratchpad/vendor_armaquest.py), replaced
    wholesale on the next re-vendor with no error. This file, and the
    AQ_Profile override in aq_content.hpp that points at it, are the seam.
*/

// ---------------------------------------------------------------- helpers
// The library calls everything that pays or grants with a UID, because the
// server is the only machine allowed to decide a reward happened. The host's
// own functions want a unit, so the resolution happens here, once, shared by
// every capability below. Deliberately a BARE global, not a `private` local:
// SQF has no closure over a private declared in this file's own top-level
// run -- a nested code block only sees a `private` that is still on the
// current call stack, and by the time the library calls one of the
// capabilities below, this file's own top-level execution is long over.
AP_fnc_aqUnitFromUid = compileFinal {
    params [["_uid", "", [""]]];
    if (_uid isEqualTo "") exitWith { objNull };
    private _hit = allPlayers select { getPlayerUID _x isEqualTo _uid };
    _hit param [0, objNull]
};

// ---------------------------------------------------------------- money
// New Drachma is decimal(20,4) and stays a STRING end to end: SQF numbers are
// 32-bit floats, exact only to 16,777,216, and rounding money is how a
// duplication bug starts. AP_fnc_aqNd (below) already returns a STRING (its
// last expression is `_r toFixed 4`)
// -- never wrap it in str(), which would double-encode the amount and
// ndCreditSrv's own regex would reject the result.
//
// payMoney and takeMoney call two DIFFERENT existing functions with two
// DIFFERENT calling conventions -- confirmed by reading both sources, not
// assumed from the symmetry of their names:
//   APS_fnc_ndCreditSrv  wants the PLAYER OBJECT,  now returns a plain BOOL
//                        (server/AP_server/core/TON/fn_ndCreditSrv.sqf, fixed
//                        alongside this file so a failed credit cannot read
//                        as a completed, unpaid quest).
//   APS_fnc_ndDebitSrv   wants the UID STRING, returns [_ok, _newBalance].
// ndDebitSrv is explicitly uid-based so it can charge an offline player (see
// its own header comment); resolving a unit for it first would only make
// takeMoney fail for exactly the players it was written to still reach.
//
// Legacy $ -> 4dp ND string, ON THE SERVER (audit 2026-09-26, r2gangmap). AP_fnc_ndFromLegacy / AP_fnc_ndText
// live in core\configuration.sqf, which only a player's machine runs, so on the dedicated server both were nil:
// every Number reward handed ndCreditSrv nothing (it refused, the quest never completed) and the cap toast
// printed "any". Same 6000:1 ratio, 4dp rounding and 0.0001 floor as ndFromLegacy.
AP_fnc_aqNd = compileFinal {
    private _r = (round ((_this / 6000) * 10000)) / 10000;
    if (_this > 0 && {_r <= 0}) then { _r = 0.0001; };
    _r toFixed 4
};
AP_fnc_aqPayMoney = compileFinal {
    params [["_uid", "", [""]], ["_amt", 0, [0, ""]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    // Offline is a real answer, not an error: report it truthfully so the
    // server can retry rather than record a payout that never landed.
    if (isNull _unit) exitWith { false };
    // HOURLY CAP (audit 2026-09-26). Radiant boards refill on every take, so any
    // objective a client can still satisfy by itself (serverFacts[] in
    // aq_content.hpp lists the ones it cannot) was an unbounded, server-credited
    // payout. Legacy $ per UID per hour; ArmaQuest always passes a Number here
    // (srvPayout coerces it), so a String amount is server-authored and uncapped.
    // Over the cap this pays what is left and returns TRUE, against the profile
    // contract's "never true without paying": on this host a false leaves the
    // quest active with nothing that ever retries it, and abandoning a once-only
    // quest retires it and breaks its chain. The player is told what was withheld.
    // localNamespace, because a client's publicVariable can reset a mission global.
    // ponytail: fixed window (up to 2x cap across a boundary) and a credit that
    // fails still counts against the hour; go rolling/refunding if either bites.
    if (_amt isEqualType 0) then {
        private _cap = 50000;
        private _want = _amt;
        isNil {   // unscheduled: two payouts for one UID must not both read the old total
            private _led = localNamespace getVariable ["AP_aqPayLedger", createHashMap];
            (_led getOrDefault [_uid, [0, 0]]) params ["_since", "_paid"];
            if (diag_tickTime - _since >= 3600) then { _since = diag_tickTime; _paid = 0; };
            _amt = (_want min (_cap - _paid)) max 0;
            _led set [_uid, [_since, _paid + _amt]];
            localNamespace setVariable ["AP_aqPayLedger", _led];
        };
        if (_amt < _want) then {
            // NOT -SEC-: honest play reaches the cap, and clankr turns every -SEC- row into a ban signal.
            ["-AQCAP-", _unit, format ["ArmaQuest payout cap: paid %1 of %2 (cap %3 per hour)", _amt, _want, _cap]] call APS_fnc_logIt;
            [[format ["Contract pay is capped at %1 ND an hour. %2 ND of this payout was withheld.", _cap call AP_fnc_aqNd, (_want - _amt) call AP_fnc_aqNd], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        };
    };
    if (_amt isEqualTo 0) exitWith { true };
    private _str = if (_amt isEqualType "") then { _amt } else { _amt call AP_fnc_aqNd };
    [_unit, _str, "armaquest"] call APS_fnc_ndCreditSrv
};

AP_fnc_aqTakeMoney = compileFinal {
    params [["_uid", "", [""]], ["_amt", 0, [0, ""]]];
    if (!isServer) exitWith { false };
    if (_uid isEqualTo "") exitWith { false };
    private _str = if (_amt isEqualType "") then { _amt } else { _amt call AP_fnc_aqNd };
    ([_uid, _str, "armaquest"] call APS_fnc_ndDebitSrv) param [0, false]
};

// ---------------------------------------------------------------- items
// There is no server-side write path for virtual items in this mission: every
// server-side grant in the codebase asks the owning client to apply it via
// AP_fnc_handleInv (params [_add(true)/_remove(false), _class, _qty]). So
// this does the same thing rather than inventing a second mechanism that
// would disagree with the first.
//
// LIMITATION, accepted and documented rather than solved here: the dispatch
// below is `spawn` (fire-and-forget), matching every other server -> client
// grant in this codebase. If the client-side handleInv refuses the change
// (no carry-weight room for giveItem; not enough of the item for takeItem),
// that failure never reaches the server -- these two report true once the
// request is DISPATCHED, not once it is confirmed APPLIED. profile_default.hpp's
// "takeItem: false must mean nothing was taken, never some of it" therefore
// holds for the "player offline" case on this host, but not for a client-side
// refusal. Fixing that needs a client -> server acknowledgement path, which
// does not exist anywhere else in this codebase either, so it is not invented
// here -- flagged as a real gap, not silently papered over.
AP_fnc_aqGiveItem = compileFinal {
    params [["_uid", "", [""]], ["_class", "", [""]], ["_qty", 1, [0]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    if (isNull _unit) exitWith { false };
    [[true, _class, _qty], "AP_fnc_handleInv", _unit, false] spawn AP_fnc_MP;
    true
};

// 2026-08-22: grant a Fabricator schematic as a quest reward. Server-side, and routed through the
// one funnel that grants schematics anywhere -- APS_fnc_fabGrantSRV dedupes, persists, notifies and
// logs, so a quest cannot create a second path to a permanent unlock with different rules.
// "" for _key means "roll one from the quest pool" rather than a named schematic.
AP_fnc_aqGiveSchematic = compileFinal {
    params [["_uid", "", [""]], ["_key", "", [""]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    if (isNull _unit) exitWith { false };
    if (_key isEqualTo "") then {
        ["roll", [_unit, "quest", ""]] spawn APS_fnc_fabGrantSRV;
    } else {
        ["give", [_unit, _key, "quest"]] spawn APS_fnc_fabGrantSRV;
    };
    true
};

AP_fnc_aqTakeItem = compileFinal {
    params [["_uid", "", [""]], ["_class", "", [""]], ["_qty", 1, [0]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    if (isNull _unit) exitWith { false };
    [[false, _class, _qty], "AP_fnc_handleInv", _unit, false] spawn AP_fnc_MP;
    true
};

/*
    countItem is called on BOTH machines, and answers differently on each --
    which is not a shortcut, it is the honest shape of this host.

    On the CLIENT it reads the live AP_inv_<class> variable -- the "AP_inv_"
    prefix confirmed against core/actions/fn_handleInv.sqf (which reads and
    writes exactly that format) and core/session/fn_saveGear.sqf (which reads
    the same prefix when it builds the save packet). The bare class name is
    NOT the variable name; using it would silently read nothing.

    On the SERVER there is no live read available: virtual items live in
    client variables and reach the database only when that client next runs a
    mode-3 save (core/session/fn_ClupdatePartial.sqf). So the server's answer
    is the last SAVED value, and it is therefore STALE by up to one save
    interval. Item objectives on this host are client-reported with a lagging
    server check, not server-verified. This is a documented, scoped
    limitation -- the fix (e.g. asking the live client and waiting for an
    answer) is separate work, not attempted here.

    The gear column is mres-encoded (str2, backtick-delimited), so it is
    selected BARE. A QUOTE() around it adds a second quote layer, the decoder
    produces malformed SQF, and the value silently decodes to nothing --
    confirmed against server/AP_server/core/DB/fn_queryRequest.sqf's own
    comment ("licenses col is UNQUOTED, exactly like the gear col... QUOTE-ing
    it would double-wrap"). This codebase has been bitten by that twice.

    The gear column is also SIDE-specific (civ_gear / cop_gear / med_gear), so
    the unit's side is resolved before selecting.
*/
AP_fnc_aqCountItem = compileFinal {
    params [["_uid", "", [""]], ["_class", "", [""]]];

    if (hasInterface && {_uid isEqualTo (getPlayerUID player)}) exitWith {
        missionNamespace getVariable [format ["AP_inv_%1", _class], 0]
    };
    if (!isServer) exitWith { 0 };
    if !(_uid regexMatch "\d{17}") exitWith { 0 };

    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    private _col = switch (side group _unit) do {
        case west:        { "cop_gear" };
        case independent: { "med_gear" };
        default           { "civ_gear" };
    };
    private _r = [format ["SELECT %1 AS c0 FROM players WHERE playerid='%2'", _col, _uid], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { 0 };
    // DB_fnc_mresToArray returns the INTERMEDIATE STRING, not an array -- its own
    // closing comment says so, and the canonical consumer (fn_queryRequest's _dec)
    // does the second step explicitly. Without it the isEqualType [] test below is
    // false on every single call and this function returns its zero/false exit
    // unconditionally -- which for countItem means the SERVER re-check in
    // fn_srvFact never advances a gather or deliver objective, while the client
    // shows correct progress from the live variable. The player watches the
    // counter fill and the quest never completes, with nothing in any log.
    //
    // parseSimpleArray, never `call compile`: a poisoned free-text column would
    // otherwise execute as SQF on this path (the Lystic compile-RCE class that
    // fn_queryRequest's own comment flags).
    private _gear = [_r param [0, ""]] call DB_fnc_mresToArray;
    if (typeName _gear isEqualTo "STRING") then { _gear = parseSimpleArray (format ["%1", _gear]); };
    if !(_gear isEqualType []) exitWith { 0 };
    // gear shape (core/session/fn_saveGear.sqf): [loadout, [[[class,qty], ...], weight], uniformSkins]
    private _virt = (_gear param [1, []]) param [0, []];
    private _hit = _virt param [_virt findIf { (_x param [0, ""]) isEqualTo _class }, []];
    _hit param [1, 0]
};

// ---------------------------------------------------------------- licences
// license_<side>_<name> variables -- confirmed against core/actions/fn_buyLicense.sqf
// and core/config/fn_licenseCfg.sqf, both of which build the name as
// format["license_%1_%2", _side, _type] with _side one of "civ"/"cop"/"med".
// NOT civ-only, so both capabilities below branch on side the way countItem does.
AP_fnc_aqHasLicense = compileFinal {
    params [["_uid", "", [""]], ["_lic", "", [""]]];

    if (hasInterface && {_uid isEqualTo (getPlayerUID player)}) exitWith {
        private _sideTag = switch (AP_effSide) do { case west: {"cop"}; case independent: {"med"}; default {"civ"} };
        missionNamespace getVariable [format ["license_%1_%2", _sideTag, _lic], false]
    };
    if (!isServer) exitWith { false };
    if !(_uid regexMatch "\d{17}") exitWith { false };

    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    private _sideTag = switch (side group _unit) do {
        case west:        { "cop" };
        case independent: { "med" };
        default           { "civ" };
    };
    // BARE select -- same mres reasoning as countItem's gear column above.
    private _r = [format ["SELECT %1_licenses AS _licenses FROM players WHERE playerid='%2'", _sideTag, _uid], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { false };
    // DB_fnc_mresToArray returns the INTERMEDIATE STRING, not an array -- its own
    // closing comment says so, and the canonical consumer (fn_queryRequest's _dec)
    // does the second step explicitly. Without it the isEqualType [] test below is
    // false on every single call and this function returns its zero/false exit
    // unconditionally -- which for hasLicense means every licence gate reads as unheld,
    // so a requires[] license: token can never pass.
    //
    // parseSimpleArray, never `call compile`: a poisoned free-text column would
    // otherwise execute as SQF on this path (the Lystic compile-RCE class that
    // fn_queryRequest's own comment flags).
    private _lics = [_r param [0, ""]] call DB_fnc_mresToArray;
    if (typeName _lics isEqualTo "STRING") then { _lics = parseSimpleArray (format ["%1", _lics]); };
    if !(_lics isEqualType []) exitWith { false };
    // stored shape (core/session/fn_ClupdatePartial.sqf mode 2): [[fullVarName, bool], ...]
    private _full = format ["license_%1_%2", _sideTag, _lic];
    private _i = _lics findIf { (_x param [0, ""]) isEqualTo _full };
    if (_i isEqualTo -1) exitWith { false };
    ((_lics select _i) param [1, false]) isEqualTo true
};

// grantLicense is the profile-facing capability the library calls on the
// server with (uid, licence). It dispatches to AP_fnc_handleLicense
// (core/actions/fn_handleLicense.sqf), the CLIENT-side primitive that
// actually sets the variable and persists it -- deliberately a DIFFERENT
// name: CfgRE.hpp already whitelisted a server->client hop for the licence
// grant ahead of this task (Task 6 prep), and giving the dispatcher below and
// the applier the same name would mean one Functions.h registration silently
// overwrites the other in missionNamespace -- both compile under the same AP
// tag, so there is no cross-prefix collision to save it, unlike AP_ vs APS_.
AP_fnc_aqGrantLicense = compileFinal {
    params [["_uid", "", [""]], ["_lic", "", [""]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    if (isNull _unit) exitWith { false };
    [[_lic], "AP_fnc_handleLicense", _unit, false] spawn AP_fnc_MP;
    true
};

// ---------------------------------------------------------------- identity
AP_fnc_aqPlayerUid = compileFinal {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith { "" };
    getPlayerUID _unit
};

// Not one of the eight keys ArmaQuest's own fn_validate.sqf checks by name
// (payMoney/takeMoney/giveItem/takeItem/countItem/hasLicense/grantLicense/
// playerUid/awardXp -- notify is not in that list). It is a mission-side
// addition ahead of any library version that calls it, so on this vendored
// snapshot it shows only as a benign preInit WARNING ("is not a profile key;
// check the spelling"), never a PROBLEM, and nothing in the vendored tree
// invokes it yet (grepped functions/, server/, types/, diagnostics/: zero
// hits for "notify"). Wired anyway, per aq_content.hpp, so it is ready the
// day something calls ["notify", [uid, text]] call aq_fnc_profile.
AP_fnc_aqNotify = compileFinal {
    params [["_uid", "", [""]], ["_text", "", [""]]];
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    if (isNull _unit) exitWith { false };
    [[_text, "basic"], "AP_fnc_handleMessage", _unit, false] spawn AP_fnc_MP;
    true
};


// ------------------------------------------------------------------- xp
// ArmaQuest's ninth profile capability: [uid, amount] -> BOOL.
//
// It was never mapped, and eight authored quests in aq_content.hpp carry an
// `xp = N` that has therefore been silently discarded since the content landed.
// The library says so at every boot -- ArmaQuest/diagnostics/fn_validate.sqf:468
// emits "awards xp but AQ_Profile >> awardXp is empty; xp will be ignored" -- so
// this was a warning nobody was reading rather than a hidden fault.
//
// The grant itself has to happen on the rewarded player's own machine: AP_side_exp
// is a client variable persisted by the client's ClupdatePartial case 4, so a
// server-side column write is overwritten by the owner's next save. See
// fn_aqAwardXpClient.sqf for the full reasoning.
//
// Returns false for an offline player rather than reporting a grant that did not
// happen -- the same rule payMoney follows, and for the same reason: a `true` that
// awarded nothing marks the quest complete and leaves the player with neither the
// reward nor a way to earn it again.
AP_fnc_aqAwardXp = compileFinal {
    params [["_uid", "", [""]], ["_amount", 0, [0]]];
    if (!isServer) exitWith { false };
    if (_amount <= 0) exitWith { false };
    private _unit = [_uid] call AP_fnc_aqUnitFromUid;
    if (isNull _unit) exitWith { false };
    [[floor _amount], "AP_fnc_aqAwardXpClient", _unit, false] spawn AP_fnc_MP;
    true
};


// ------------------------------------------------------------- allegiance
// ArmaQuest's factionOf capability: [uid] -> STRING, "" when this player's gang
// has no patron. Backs requires[] = { "align:f_dock" } / { "align:any" }, which is
// how the fixers' best-paying work is kept for crews that have picked a side.
//
// TWO IN-MEMORY LOOKUPS AND NO QUERY, because of where this is called from:
// prerequisite evaluation runs per candidate quest, for every player who opens a
// giver. A database round trip on that path is the thing fn_aqWorld.sqf's header
// spends four paragraphs forbidding, and it would be no more acceptable here.
//
//   APS_gangOfUid    uid -> gang id. Server-owned, in localNamespace (a client's publicVariable
//                    cannot reach it), never published, seeded from the
//                    DATABASE at login (fn_queryRequest) and maintained on every
//                    join/kick/leave (fn_updateGangMem).
//   AP_gangFactions  gang id -> faction. Published, maintained by APS_fnc_gangAlignSRV.
//
// AND IT MUST NOT READ `gang_data`. That object variable carries the same gang id
// and is right there on the unit -- but it is written by the observed player's OWN
// client, so a modified client can claim any gang it likes. That is harmless for a
// name tag and fatal for a gate whose whole purpose is to decide who sees the
// lucrative contracts. The server keeps its own copy precisely so this function has
// something it is allowed to believe.
//
// Server-only. A client asking gets "", which fails every align: token closed --
// the same direction every other unanswerable gate fails in. Nothing client-side
// calls it today; srvAccept is the only consumer and runs on the server.
AP_fnc_aqFactionOf = compileFinal {
    params [["_uid", "", [""]]];
    if (!isServer) exitWith { "" };
    if (_uid isEqualTo "") exitWith { "" };
    private _gid = (localNamespace getVariable ["APS_gangOfUid", createHashMap]) getOrDefault [_uid, 0];
    if (_gid <= 0) exitWith { "" };
    private _map = missionNamespace getVariable ["AP_gangFactions", []];
    if !(_map isEqualType []) exitWith { "" };
    private _i = _map findIf { (_x param [0, -1]) isEqualTo _gid };
    if (_i isEqualTo -1) then { "" } else { format ["%1", (_map select _i) param [1, ""]] }
};
