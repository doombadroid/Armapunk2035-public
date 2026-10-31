/*
    File: fn_factionWarSRV.sqf  (APS_fnc_factionWarSRV)

    The weekly fixer war: who is fighting whom this week, and the contract score
    that decides next week's matchup.

        ["tick"]                    call APS_fnc_factionWarSRV   // the scheduler
        ["publish"]                 call APS_fnc_factionWarSRV   // re-broadcast
        ["score", ["f_neon", 150]]  call APS_fnc_factionWarSRV   // credit a contract

    THE RULE. Every week the three territorial factions are ranked by the contract
    score their ALIGNED gangs earned. The top scorer is the DEFENDER -- being the
    most effective is what paints the target -- the runner-up is the AGGRESSOR, and
    the lowest sits the week out NEUTRAL. That is deliberately a rubber band: doing
    well buys you a war, not a rest, so a faction cannot win the server by winning
    every week.

    THE WEEK COMES FROM THE DATABASE, NOT FROM SQF. The key is built by
    concatenation -- to_char(NOW(),'IYYY') || '-W' || to_char(NOW(),'IW') -- rather
    than by the single to_char format string that would express the same thing,
    because that one needs literal double quotes inside it and SQF escapes a double
    quote by DOUBLING it, not with a backslash. A backslash there terminates the
    string early and the file stops compiling, which is the footgun CLAUDE.md's
    pre-deploy check exists for. Concatenating sidesteps the quoting entirely.
    It is one cheap call on a tick that is already talking to the database, and it
    sidesteps three things SQF is bad at: ISO week arithmetic, a mission clock that
    restarts with the server, and the box/database timezone split this project
    already has (box CST, database UTC). One clock, and it is the one the row is
    stamped with.

    AND THE ROLLOVER COMPARES KEYS, NEVER ELAPSED TIME. "Is the stored week the
    current week" has the same answer however long the process has been up, so a
    restart, a server that was down across midnight Sunday, or a tick that was
    missed entirely all resolve correctly on the next tick. An elapsed-time
    rollover would have to be told what it missed; this one cannot miss anything.
    An empty stored key can never equal the current week, which is what makes a
    fresh database schedule its first war with no separate bootstrap path.

    SCORING IS ONE STATEMENT. jsonb_set with a COALESCE'd read-modify-write keeps
    the accumulator in the database rather than in a server variable, so a crash
    between contracts loses nothing, and no flush is needed. Contracts are not
    frequent enough for the write to matter.

    THE FACTION ID REACHES SQL, so every entry point validates it against
    AP_fnc_factionCfg FIRST. That is an allowlist of four literal strings compiled
    into the mission -- not an escape -- which is the only form of "safe
    interpolation" this file is willing to rely on.

    AP_factionWar is [aggressor, defender, neutral, weekKey], public. Empty strings
    mean "no war scheduled yet"; clients must render that state rather than assume
    three ids are always present.
*/
params [["_mode", "", [""]], ["_arg", [], [[], ""]]];
if (!isServer) exitWith { false };

// The factions that can actually be at war: the ones holding ground. A faction
// with an empty polygon (f_maxsec, reserved) is not a belligerent, is not ranked,
// and is not scored -- derived from the config rather than listed here, so adding
// the fourth faction to the war is a matter of giving it a territory.
private _live = (["all"] call AP_fnc_factionCfg) select { (_x param [5, []]) isNotEqualTo [] } apply { _x select 0 };

private _publish = {
    private _r = ["SELECT COALESCE(aggressor,'') AS a, COALESCE(defender,'') AS d, COALESCE(neutral,'') AS n, COALESCE(week_key,'') AS w FROM faction_war WHERE id=1", 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {count _r < 4}) exitWith {
        diag_log "[AP][war] publish: faction_war row unreadable; leaving AP_factionWar as it is.";
        false
    };
    AP_factionWar = [_r param [0, ""], _r param [1, ""], _r param [2, ""], _r param [3, ""]];
    publicVariable "AP_factionWar";
    diag_log format ["[AP][war] week %4: %1 (aggressor) vs %2 (defender); %3 neutral.",
        AP_factionWar select 0, AP_factionWar select 1, AP_factionWar select 2, AP_factionWar select 3];
    true
};

switch (toLower _mode) do {

    case "publish": { call _publish };

    // ------------------------------------------------------------------ score
    // Called from AP_fnc_aqAddRep, which has already established that the gain is
    // positive AND that the earning player's gang is aligned with the credited
    // faction. Both conditions belong there, not here: that function is the only
    // place that knows who earned it, and re-deriving it would mean a second
    // database round trip on a path that already did one.
    case "score": {
        _arg params [["_faction", "", [""]], ["_points", 0, [0]]];
        if (_points <= 0) exitWith { false };
        if !(_faction in _live) exitWith { false };
        [format [
            "UPDATE faction_war SET scores = jsonb_set(scores, '{%1}', to_jsonb(COALESCE((scores->>'%1')::numeric, 0) + %2), true), updated = NOW() WHERE id=1",
            _faction, round _points], 1] call DB_fnc_asyncQuery;
        true
    };

    // ------------------------------------------------------------------- tick
    case "tick": {
        if (count _live < 3) exitWith {
            diag_log format ["[AP][war] tick: only %1 faction(s) hold territory; a war needs 3. Nothing scheduled.", count _live];
            false
        };

        // One statement: the current week, the stored week, and every live
        // faction's score. Ranking three numbers is SQF's job; knowing what week
        // it is and where the counters live is the database's.
        // EVERY generated column IS ALIASED, and it is not cosmetic. PySQF returns a
        // row as an OBJECT keyed by column name, so three unaliased COALESCE(...)
        // columns all arrive named "coalesce" and the transport refuses the whole
        // result set -- "the result has repeated column name(s)". The same rule
        // fn_queryRequest.sqf's NULL placeholders carry, and it fails the entire
        // query rather than dropping a column, so the tick reads [] and never rolls
        // over. Observed on b0802 before the aliases went in.
        private _cols = (_live apply { format ["COALESCE((scores->>'%1')::numeric, 0)::float8 AS s_%1", _x] }) joinString ", ";
        private _r = [format [
            "SELECT to_char(NOW(),'IYYY') || '-W' || to_char(NOW(),'IW') AS wk_now, COALESCE(week_key,'') AS wk_row, %1 FROM faction_war WHERE id=1", _cols], 2] call DB_fnc_asyncQuery;
        if (!(_r isEqualType []) || {count _r < (2 + count _live)}) exitWith {
            diag_log format ["[AP][war] tick: faction_war row unreadable (got %1). No rollover; the current matchup stands.", _r];
            false
        };

        private _wkNow = format ["%1", _r param [0, ""]];
        private _wkRow = format ["%1", _r param [1, ""]];
        if (_wkNow isEqualTo "") exitWith {
            diag_log "[AP][war] tick: the database returned no week key. Refusing to roll over on a value I do not have.";
            false
        };

        // Same week: nothing to do. Publish only if the client-facing variable has
        // not been built yet (first tick after a boot), so the steady state is one
        // read and nothing else.
        if (_wkNow isEqualTo _wkRow) exitWith {
            if (isNil "AP_factionWar") then { call _publish };
            true
        };

        // ---------------------------------------------------------- rollover
        // Rank by score, descending. Sorted as pairs of NUMBERS -- [score, -index]
        // -- rather than as [score, index, id] triples: SQF's `sort` on arrays of
        // arrays compares element by element and wants them uniformly typed, and a
        // mixed number/number/string triple is the kind of thing that works until
        // the day two scores tie.
        //
        // The index is NEGATED so that `sort false` (descending) breaks a tie
        // toward the EARLIER config entry. Ties are not an edge case here: a fresh
        // database has every score at zero, so the very first war is decided
        // entirely by the tie-break. A random draw there would make the opening
        // matchup unreproducible for anyone trying to work out why the server
        // picked it.
        private _pairs = [];
        { _pairs pushBack [parseNumber (format ["%1", _r param [2 + _forEachIndex, 0]]), -_forEachIndex]; } forEach _live;
        _pairs sort false;
        private _order = _pairs apply { _live select (-(_x select 1)) };

        private _defender  = _order select 0;   // top scorer -- the target
        private _aggressor = _order select 1;   // runner-up  -- comes for them
        private _neutral   = _order select 2;   // sits it out

        [format [
            "UPDATE faction_war SET week_key='%1', aggressor='%2', defender='%3', neutral='%4', started=NOW(), scores='{}'::jsonb, updated=NOW() WHERE id=1",
            _wkNow, _aggressor, _defender, _neutral], 1] call DB_fnc_asyncQuery;

        // _pairs, not _ranked: an earlier draft ranked [score, index, id] triples and
        // this line still named that variable after the sort was rewritten to number
        // pairs. SQF resolves an undefined local to `any` and formats it happily, so
        // the first real rollover logged "Scores were any" -- a diagnostic that
        // silently stopped diagnosing. Pairs read [score, -configIndex].
        diag_log format ["[AP][war] ROLLOVER %1 -> %2. Ranked %3 over %7. New matchup: %4 attacks %5; %6 neutral.",
            _wkRow, _wkNow, _pairs, _aggressor, _defender, _neutral, _live];
        call _publish
    };

    default {
        diag_log format ["[AP][war] factionWarSRV: unknown mode '%1'", _mode];
        false
    };
};
