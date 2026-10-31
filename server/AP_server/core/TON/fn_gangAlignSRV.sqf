/*
    File: fn_gangAlignSRV.sqf  (APS_fnc_gangAlignSRV)

    Aligns a gang with an NPC faction, and maintains the published gang -> faction
    mirror everything else reads. See FACTION_REP_SPEC.md.

        ["f_neon"] remoteExec ["APS_fnc_gangAlignSRV", 2];
        ["publish"] call APS_fnc_gangAlignSRV;      // server-internal, boot + on change

    SERVER-AUTHORITATIVE, and it re-derives everything rather than trusting the
    caller. The client sends a faction id and nothing else: the gang, the rank and
    the right to change it are all read from the database here. A client that lies
    can only ask for a faction it is not allowed to pick, and be refused.

    IDENTITY COMES FROM remoteExecutedOwner, NEVER FROM THE PAYLOAD. This used to
    take a player OBJECT as its first argument and call getPlayerUID on it. The
    function is remoteExec-able by clients (CfgRE.hpp: allowedTargets = 2), so that
    argument was attacker-chosen: passing someone else's object realigned THEIR
    gang, and the -SEC- log would have named the victim as the actor. Same class as
    the disband hole fixed in fn_removeGang.sqf on 2026-06-23 (security.md
    2.2/2.3), and the same remedy -- resolve the caller from the owner id, treat
    owner 0 as server-internal, and refuse anything that does not resolve.

    A player object is still ACCEPTED in slot 0 so the older call shape does not
    silently become the "publish" string, but it is used only as the fallback
    notification target when the owner lookup cannot find a unit. It never
    establishes identity.

    RANK 1 IS THE LEADER. Ranks in this codebase are inverted -- 1 = LEADER,
    2 = OFFICER, 3 = RECRUITER, 5 = RECRUIT (core/web/fn_deckData.sqf) -- and every
    other leader-only gate reads `_rank != 1` (fn_removeGang.sqf, fn_gangRenameSRV.sqf).
    This function shipped with `_rank < 4`, which is the OPPOSITE test: it refused
    the leader, the officer and the recruiter, and admitted the recruits. It also
    compared the DB value bare rather than coercing it, where both sibling gates do
    `parseNumber (format ["%1", ...])` because the column can arrive as a string.

    WHY THE MIRROR EXISTS. ArmaQuest's world resolvers (core/quests/fn_aqWorld.sqf)
    run during offer building -- per candidate quest, for every player who opens a
    giver -- so they must not query a database. Cartel state records the holding
    GANG, but content wants to gate on the FACTION. Publishing the mapping once,
    here, is what lets a resolver answer that in memory. Without it, faction-level
    cartel gating is impossible without putting a query somewhere it must never go.

    AP_gangFactions is [[gangId, factionId], ...], public.
*/
params [["_a", objNull, [objNull, ""]], ["_faction", "", [""]]];
if (!isServer) exitWith { false };

// Three call shapes reach this one entry point, so slot 0 is normalised before
// anything reads it:
//     ["publish"]                  server-internal mirror rebuild
//     ["f_neon"]                   the current client shape -- faction in slot 0
//     [<obj>, "f_neon"]            the historical shape, still accepted
// Without this, the one-argument client form puts the faction id in _a, leaves
// _faction empty, and is refused as "that faction does not exist" -- a refusal
// that describes the argument list rather than anything the player did.
if (_a isEqualType "" && {!(toLower _a isEqualTo "publish")} && {_faction isEqualTo ""}) then {
    _faction = _a;
    _a = objNull;
};

// ------------------------------------------------------------------ publish
// Rebuild the mirror from the database and publish it. Cheap and infrequent:
// boot, and any time an alignment actually changes.
private _publish = {
    private _rows = ["SELECT id,COALESCE(faction,'') AS faction FROM gangs WHERE faction IS NOT NULL AND faction <> ''", 2, true] call DB_fnc_asyncQuery;
    private _map = [];
    if (_rows isEqualType []) then {
        { if (_x isEqualType [] && {count _x >= 2}) then { _map pushBack [_x select 0, _x select 1]; }; } forEach _rows;
    };
    AP_gangFactions = _map;
    publicVariable "AP_gangFactions";
    diag_log format ["[AP][faction] gang->faction mirror published: %1 aligned gang(s)", count _map];
    true
};

if (_a isEqualType "" && {toLower _a isEqualTo "publish"}) exitWith { call _publish };

// ------------------------------------------------------------------ align
// The caller, derived and not asserted. owner 0 is the server calling itself,
// which only the "publish" arm above does -- reaching here with owner 0 means a
// server-internal align, which nothing does today, so it is refused rather than
// given blanket trust.
private _src = remoteExecutedOwner;
if (_src isEqualTo 0) exitWith {
    diag_log "[AP][faction] gangAlign: server-internal align has no caller to authorise; refused.";
    false
};
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {
    diag_log format ["[AP][faction] gangAlign: owner %1 resolved to no unit; refused.", _src];
    false
};
private _uid = getPlayerUID _caller;
if !(_uid regexMatch "\d{17}") exitWith { false };

// Every message below goes to the CALLER, never to the object the payload named.
_a = _caller;

if (([("byId"), _faction] call AP_fnc_factionCfg) isEqualTo []) exitWith {
    diag_log format ["[AP][faction] gangAlign: '%1' asked for unknown faction '%2'; refused.", _uid, _faction];
    [["That faction does not exist.", "basic"], "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
    false
};

// Gang and rank come from the DATABASE, never from the client. gangrank0 is the
// player's rank; only the top rank may set alignment -- the same authority that
// governs the gang bank and invites.
private _pr = [format ["SELECT gang0,gangrank0 FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
if (!(_pr isEqualType []) || {count _pr < 2}) exitWith { false };
private _gid  = _pr param [0, 0];
// Coerced, not read bare: the column can arrive as a string on this transport,
// and a string compared against a number is not the comparison it looks like.
// 99 = "no readable rank", which fails the leader test below.
private _rank = if (!isNil { _pr select 1 }) then { parseNumber (format ["%1", _pr select 1]) } else { 99 };

if (_gid <= 0) exitWith {
    [["You are not in a gang.", "basic"], "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
    false
};
if (_rank != 1) exitWith {
    ["-SEC-", _caller, format ["BLOCKED gangAlign gang=%1 faction=%2 by %3 (rank %4)", _gid, _faction, _uid, _rank]] call APS_fnc_logIt;
    [["Only the gang leader can change alignment.", "basic"], "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
    false
};

// Realigning is destructive to the members' perks, because a faction perk is held
// only while its faction is primary (AP_fnc_hasFactionPerk). The refusal to do it
// silently is deliberate: this is logged, and the UI that calls it is required to
// warn first.
private _prev = [format ["SELECT COALESCE(faction,'') AS faction FROM gangs WHERE id='%1'", _gid], 2] call DB_fnc_asyncQuery;
private _prevF = if (_prev isEqualType [] && {count _prev > 0}) then { _prev param [0, ""] } else { "" };
if (_prevF isEqualTo _faction) exitWith {
    [["Your gang is already aligned with them.", "basic"], "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
    false
};

// ------------------------------------------------------------- defection
// Swearing to a fixer for the FIRST time is free and instant: a gang that has
// never chosen has nothing to be punished for, and charging them for the act the
// whole system is trying to encourage would be perverse. Everything below applies
// only to LEAVING one patron for another.
// Fee and cooldown are server literals, mirroring AP_FACTION_DEFECT_FEE / _DAYS in core/configuration.sqf.
// That file runs on CLIENTS only, so the globals are nil here -- and a nil global is one a client can
// publicVariable in, straight into the SQL below (SQL text, or a negative fee that mints gang money).
// Nil also broke the defection itself ('any days', 'bank - any'). Change both copies together.
private _defectFee = 500000;
private _defectDays = 7;
if (_prevF isNotEqualTo "") then {

    // 1. NOT DURING YOUR OWN WAR. A gang cannot walk out the week its fixer is a
    //    belligerent. Without this, the dominant move every Monday is to read the
    //    matchup and defect to whoever is sitting the week out, and the war stops
    //    being a thing that happens to anyone. It is also the cheapest possible
    //    rule -- one in-memory read -- compared with trying to correct for
    //    war-dodging after the fact in the scoring.
    private _w = missionNamespace getVariable ["AP_factionWar", []];
    if (_w isEqualType [] && {count _w >= 2} && {_prevF in [_w select 0, _w select 1]}) exitWith {
        [[format ["%1 is at war this week. You do not get to leave in the middle of it.",
            (["byId", _prevF] call AP_fnc_factionCfg) param [1, _prevF]], "basic"],
         "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
        _uid = "";   // flag: the tail below is skipped
    };

    // 2. COOLDOWN. Checked as its own read rather than folded into the guarded
    //    UPDATE below, because if both conditions rode on one statement a refusal
    //    could not say WHICH one refused -- and "you cannot do that" without a
    //    reason is the single most infuriating thing a UI can say.
    if (_uid isNotEqualTo "") then {
        private _cd = [format [
            "SELECT COALESCE(CEIL(EXTRACT(EPOCH FROM (faction_changed + INTERVAL '%2 days' - NOW())) / 86400.0), 0)::int AS days_left FROM gangs WHERE id='%1'",
            _gid, _defectDays], 2] call DB_fnc_asyncQuery;
        private _left = if (_cd isEqualType [] && {count _cd > 0}) then { parseNumber (format ["%1", _cd select 0]) } else { 0 };
        if (_left > 0) exitWith {
            [[format ["Your gang realigned too recently. %1 more day(s) before you can switch again.", _left], "basic"],
             "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
            _uid = "";
        };
    };
};
if (_uid isEqualTo "") exitWith { false };

// The write. For a defection this is ONE guarded statement -- the balance test and
// the alignment change cannot be separated, or two officers realigning at once
// could each pass a balance check and both be charged against the same funds. For
// a first alignment there is nothing to guard.
//
// The transport cannot report rows affected (mode 1 always returns true), so
// success is established by READING THE ROW BACK and comparing, which is the same
// discipline APS_fnc_ndCreditSrv uses. A statement whose WHERE clause did not match
// is indistinguishable from one that did, right up until you look.
if (_prevF isEqualTo "") then {
    [format ["UPDATE gangs SET faction='%1' WHERE id='%2'", _faction, _gid], 1] call DB_fnc_asyncQuery;
} else {
    [format [
        "UPDATE gangs SET faction='%1', faction_changed=NOW(), bank = bank - %3 WHERE id='%2' AND bank >= %3",
        _faction, _gid, _defectFee], 1] call DB_fnc_asyncQuery;
};

private _after = [format ["SELECT COALESCE(faction,'') AS faction FROM gangs WHERE id='%1'", _gid], 2] call DB_fnc_asyncQuery;
private _now = if (_after isEqualType [] && {count _after > 0}) then { format ["%1", _after select 0] } else { "" };
if (_now isNotEqualTo _faction) exitWith {
    diag_log format ["[AP][faction] gang %1 defection '%2' -> '%3' by %4 did NOT apply (bank short, or the row moved).", _gid, _prevF, _faction, _uid];
    [[format ["Breaking with %1 costs $%2 from the gang bank, and it is not there.",
        (["byId", _prevF] call AP_fnc_factionCfg) param [1, _prevF],
        [_defectFee] call AP_fnc_numberText], "basic"],
     "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
    false
};

// The abandoned faction's GANG standing is dropped. Deliberately the gang's and not
// the members': standing a player earned is theirs, and confiscating it because a
// leader changed patrons would punish people for a decision they did not make. The
// gang pool is what the gang built together under that patron, and it does not
// follow them out the door.
//
// Done after the alignment rather than inside it, and its failure is not fatal: an
// orphaned standing row is cosmetic, whereas refusing an alignment that has already
// been paid for would not be.
if (_prevF isNotEqualTo "") then {
    private _gr = [format ["SELECT faction_rep FROM gangs WHERE id='%1'", _gid], 2] call DB_fnc_asyncQuery;
    private _arr = [if (_gr isEqualType [] && {count _gr > 0}) then { _gr select 0 } else { "" }] call AP_fnc_aqRepDecode;
    private _i = _arr findIf { (_x param [0, ""]) isEqualTo _prevF };
    if !(_i isEqualTo -1) then {
        _arr deleteAt _i;
        [format ["UPDATE gangs SET faction_rep='%1' WHERE id='%2'", ([_arr] call DB_fnc_mresArray), _gid], 1] call DB_fnc_asyncQuery;
    };
};

diag_log format ["[AP][faction] gang %1 aligned '%2' -> '%3' by %4", _gid, _prevF, _faction, _uid];

call _publish;

[[format ["Your gang is now aligned with %1.", (["byId", _faction] call AP_fnc_factionCfg) param [1, _faction]], "info"],
 "AP_fnc_handleMessage", _a, false] spawn AP_fnc_MP;
true
