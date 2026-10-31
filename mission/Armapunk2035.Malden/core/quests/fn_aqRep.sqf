/*
    File: fn_aqRep.sqf  (AP_fnc_aqRep)

    Faction reputation: the host side of ArmaQuest's getRep / addRep capabilities,
    plus the primary-faction test the perk gates use. See FACTION_REP_SPEC.md.

    Registered preInit=1 alongside AP_fnc_aqProfile, for the same reason: the
    library's validation resolves AQ_Profile's names at preInit and refuses to arm
    if one resolves to nothing, so these must exist before that runs.

    STORAGE. players.faction_rep and gangs.faction_rep are mres blobs shaped
    [[factionId, value], ...]. A faction absent from the array reads as 0, and a
    zero is never written -- absence and neutrality are the same state, and storing
    both invites them to disagree.

    THE MRES RULE, which has drawn blood twice in this codebase: an mres column is
    read BARE, never QUOTE()-wrapped. QUOTE() adds a second quote layer, the
    decoder produces malformed SQF and returns nothing, and the value is lost with
    no error at all. DB_fnc_mresToArray then returns the INTERMEDIATE STRING, not
    an array -- the canonical consumer (fn_queryRequest's _dec) does a second
    parseSimpleArray step, and omitting it is what made every item objective in
    this mission unfinishable until it was caught in review. parseSimpleArray, and
    never `call compile`: a poisoned column would otherwise execute as SQF.

    Usage:
        [uid, "f_neon"]        call AP_fnc_aqGetRep   -> NUMBER
        [uid, "f_neon", 100]   call AP_fnc_aqAddRep   -> BOOL
        ["f_neon"]             call AP_fnc_isPrimaryFaction -> BOOL   (client)
*/

// ------------------------------------------------------------------ decode
// Shared by every read below. Deliberately a bare global rather than a private:
// SQF has no closure over a private declared in this file's own top-level run,
// and by the time the library calls one of these capabilities that run is long
// over. Same reasoning as AP_fnc_aqUnitFromUid in fn_aqProfile.sqf.
AP_fnc_aqRepDecode = compileFinal {
    params [["_raw", "", ["", []]]];
    if (_raw isEqualType []) exitWith { _raw };          // NULL column arrives pre-decoded
    if (_raw isEqualTo "" || {_raw isEqualTo "NULL"}) exitWith { [] };
    private _a = [_raw] call DB_fnc_mresToArray;
    if (typeName _a isEqualTo "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
    if !(_a isEqualType []) exitWith { [] };
    _a
};

AP_fnc_aqRepFind = compileFinal {
    params [["_arr", [], [[]]], ["_faction", "", [""]]];
    private _i = _arr findIf { (_x param [0, ""]) isEqualTo _faction };
    if (_i isEqualTo -1) then { 0 } else { (_arr select _i) param [1, 0] }
};

// ------------------------------------------------------------------ getRep
// Server-side, UID-keyed. Returns 0 for an unknown faction and for a player with
// no row at all -- both are neutral, and neither is an error.
AP_fnc_aqGetRep = compileFinal {
    params [["_uid", "", [""]], ["_faction", "", [""]]];
    if (!isServer) exitWith { 0 };
    if (_uid isEqualTo "" || {_faction isEqualTo ""}) exitWith { 0 };
    // BARE, not QUOTE(). See the header.
    private _r = [format ["SELECT faction_rep FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { 0 };
    private _arr = [_r param [0, ""]] call AP_fnc_aqRepDecode;
    [_arr, _faction] call AP_fnc_aqRepFind
};

// ------------------------------------------------------------------ addRep
// Applies the gang multiplier internally so no caller has to know the rule: a
// solo player is never blocked, only unmultiplied (FACTION_REP_SPEC.md 4.1).
//
// Accrual for a faction already at or below the hostility threshold is DAMPED,
// not zero. A player who wrecks their standing everywhere must still be able to
// climb back, or the system has produced an unplayable account it cannot undo.
AP_fnc_aqAddRep = compileFinal {
    params [["_uid", "", [""]], ["_faction", "", [""]], ["_delta", 0, [0]]];
    if (!isServer) exitWith { false };
    if (_uid isEqualTo "" || {_faction isEqualTo ""} || {_delta isEqualTo 0}) exitWith { false };
    if (([("byId"), _faction] call AP_fnc_factionCfg) isEqualTo []) exitWith {
        diag_log format ["[AP][faction] addRep: unknown faction '%1'; refusing rather than storing a value nothing can read.", _faction];
        false
    };

    private _r = [format ["SELECT faction_rep FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    if !(_r isEqualType []) exitWith { false };
    private _arr = [_r param [0, ""]] call AP_fnc_aqRepDecode;
    private _cur = [_arr, _faction] call AP_fnc_aqRepFind;

    private _gain = _delta;
    if (_gain > 0) then {
        // Gang multiplier: only ever a bonus, only on the aligned faction.
        // The player -> gang link is players.gang0 -> gangs.id. There is no
        // AP_gang_id object variable; the gang id lives in the login payload and
        // on the client, neither of which the server can trust or reach here for
        // an arbitrary uid. One join, verified against the live database.
        // faction is a plain VARCHAR, so it is QUOTE()d -- the inverse of the
        // mres rule above, and getting that backwards breaks call-compile on the
        // bare value (see fn_queryRequest's comment about the gang name).
        private _g = [format [
            "SELECT COALESCE(g.faction,'') AS faction FROM players p JOIN gangs g ON g.id = p.gang0 WHERE p.playerid='%1'", _uid
        ], 2] call DB_fnc_asyncQuery;
        private _aligned = if (_g isEqualType [] && {count _g > 0} && {(_g param [0, ""]) isEqualType ""}) then { _g param [0, ""] } else { "" };
        if (_aligned isEqualTo _faction) then {
            _gain = round (_gain * AP_FACTION_GANG_MULT);
            // THE WEEKLY WAR'S ONLY SCORING HOOK, and it is here rather than at
            // payout because this is the one place that already knows both halves
            // of the rule: the gain is positive, and the earner's gang is aligned
            // with the faction being credited. Anywhere else would have to re-read
            // the gang->faction join that the multiplier above just paid for.
            //
            // A solo, or a member of a gang aligned elsewhere, still earns standing
            // -- they simply do not move their fixer's war score, which is what
            // "points from contracts its aligned gangs completed" means.
            //
            // The pre-multiplier _delta is credited, not the multiplied _gain: the
            // 1.5x is a reward to the PLAYER for being aligned, and letting it into
            // the war score would mean an aligned gang's work counted one and a half
            // times toward a matchup that is supposed to measure work done.
            if (!isNil "APS_fnc_factionWarSRV") then {
                ["score", [_faction, _delta]] call APS_fnc_factionWarSRV;
            };
        };
        // Damped, never zero, while hostile -- always a way back.
        if (_cur <= AP_FACTION_HOSTILE_AT) then { _gain = 1 max (round (_gain * 0.5)); };
    };

    private _new = _cur + _gain;
    private _i = _arr findIf { (_x param [0, ""]) isEqualTo _faction };
    if (_new isEqualTo 0) then {
        // Never store a zero: absence IS neutrality.
        if !(_i isEqualTo -1) then { _arr deleteAt _i; };
    } else {
        if (_i isEqualTo -1) then { _arr pushBack [_faction, _new]; } else { (_arr select _i) set [1, _new]; };
    };

    [format ["UPDATE players SET faction_rep='%1' WHERE playerid='%2'", ([_arr] call DB_fnc_mresArray), _uid], 1] call DB_fnc_asyncQuery;
    true
};

// ------------------------------------------------- primary faction (client)
// A perk requires its faction to be the player's HIGHEST standing, not merely
// above a threshold -- that is what makes allegiance cost something while
// keeping the values independent and easy to reason about.
//
// A TIE resolves to NO primary, deliberately. A tie means the player has not
// chosen, and silently choosing for them is how a perk appears to flicker on and
// off as standing drifts.
AP_fnc_isPrimaryFaction = compileFinal {
    params [["_faction", "", [""]]];
    if (_faction isEqualTo "") exitWith { false };
    // Published on the player OBJECT at login (fn_queryRequest), the same way
    // AP_cdMods is -- not a missionNamespace global. Reading the wrong one would
    // silently return [] for everybody and quietly disable every faction perk.
    private _arr = player getVariable ["AP_faction_rep", []];
    if !(_arr isEqualType []) exitWith { false };
    private _mine = [_arr, _faction] call AP_fnc_aqRepFind;
    if (_mine <= 0) exitWith { false };
    private _best = _mine;
    private _tied = false;
    {
        private _v = _x param [1, 0];
        if !((_x param [0, ""]) isEqualTo _faction) then {
            if (_v > _best) exitWith { _best = _v; };
            if (_v isEqualTo _mine) then { _tied = true; };
        };
    } forEach _arr;
    (_best isEqualTo _mine) && {!_tied}
};
