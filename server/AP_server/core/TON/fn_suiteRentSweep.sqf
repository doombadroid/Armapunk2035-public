/*
    File: fn_suiteRentSweep.sqf  (APS_fnc_suiteRentSweep)
    Luxe Suites 2026-08-06 -- the rent clock. See suites.md §4.

    Registered on the scheduler wheel in server/AP_server/init.sqf:
        ["suiteRent", { params ["_st"]; call APS_fnc_suiteRentSweep; }, 300, false, true] call AP_fnc_schedule;

    Every pass:
      1. charge every lease whose next_due has passed
      2. repossess every lease that has been overdue for 10 days

    WORKS OFFLINE. That is the whole point of "automatic": rent is a server-side
    SQL debit against players.new_drachma, so a tenant who never logs in still
    pays, still falls behind, and still loses the suite. Nothing here needs the
    player to be present, and nothing here trusts a client.

    FAIL-CLOSED, in both directions:
      * next_due only advances after the debit VERIFIES (APS_fnc_ndDebitSrv
        re-reads the balance and reports false if the proof read is empty). A
        failed proof read is treated as non-payment, never as payment -- the
        mining system's pattern. Worst case the tenant is charged nothing and the
        next pass tries again; the opposite bias would give away free months.
      * overdue_since is only stamped when it is currently 0, so a tenant who
        misses three passes still has one 10-day clock, not three.

    NOT in CfgRE -- server-internal.
*/
if (!isServer) exitWith {};

private _nowRow = ["SELECT extract(epoch from now())::bigint AS u", 2] call DB_fnc_asyncQuery;
// Never `parseNumber` this raw and never `parseNumber format ["%1", ...]` it
// either: the value's TYPE depends on its magnitude (apdb.py _to_sqf) and
// `format` renders a large Number in six significant digits. AP_fnc_dbNum is
// the one coercion that is correct for both shapes.
private _now = [_nowRow param [0, 0]] call AP_fnc_dbNum;
if (_now <= 0) exitWith { diag_log "[SUITE] rent sweep: no clock from the DB, skipping"; };
missionNamespace setVariable ["AP_suiteNow", _now, true];   // clients render days-remaining from this

// ---------------------------------------------------------------- due rents
private _due = ["SELECT oid, floor, COALESCE(owner,'') AS owner, next_due, overdue_since FROM suites WHERE owner IS NOT NULL AND next_due <= extract(epoch from now())::bigint", 2, true] call DB_fnc_asyncQuery;
if !(_due isEqualType []) then { _due = []; };

{
    _x params [["_oid", ""], ["_floor", 0], ["_uid", ""], ["_nextDue", 0], ["_over", 0]];
    // apdb types an integer by MAGNITUDE: overdue_since is Number 0 while the
    // lease is current and a STRING once it holds a real epoch (>16,777,216 --
    // apdb.py _to_sqf). Untyped, `_over > 0` below threw the moment a tenant
    // actually fell behind, aborting this whole function: the rest of _due, the
    // repossession pass, and the summary. See AP_fnc_dbNum's header.
    _over    = [_over] call AP_fnc_dbNum;
    _nextDue = [_nextDue] call AP_fnc_dbNum;
    if (_oid isNotEqualTo "" && {_uid isNotEqualTo ""}) then {

        private _pay = [_uid, (localNamespace getVariable "APS_suiteRentND"), "suiteRent"] call APS_fnc_ndDebitSrv;

        if (_pay param [0, false]) then {
            // Advance from the OLD deadline, not from now: a tenant whose payment
            // lands late must not silently gain the days they were behind.
            [format ["UPDATE suites SET next_due = next_due + %1, overdue_since = 0 WHERE oid='%2' AND owner='%3'", (localNamespace getVariable "APS_suiteTermS"), _oid, _uid], 2] call DB_fnc_asyncQuery;
            diag_log format ["[SUITE] rent PAID %1 by %2 (-%3 ND)", _oid, _uid, (localNamespace getVariable "APS_suiteRentND")];

            private _pl = (allPlayers select { getPlayerUID _x isEqualTo _uid }) param [0, objNull];
            if (!isNull _pl) then {
                [[_oid, "paid", 0], "AP_fnc_suiteRentNotice", _pl, false] spawn AP_fnc_MP;
            };
        } else {
            if (_over isEqualTo 0) then {
                [format ["UPDATE suites SET overdue_since = extract(epoch from now())::bigint WHERE oid='%1' AND owner='%2' AND overdue_since = 0", _oid, _uid], 2] call DB_fnc_asyncQuery;
                diag_log format ["[SUITE] rent MISSED %1 by %2 -- 10 day clock started", _oid, _uid];
            };
            private _pl = (allPlayers select { getPlayerUID _x isEqualTo _uid }) param [0, objNull];
            if (!isNull _pl) then {
                private _sinceD = if (_over > 0) then { floor ((_now - _over) / 86400) } else { 0 };
                [[_oid, "overdue", (10 - _sinceD) max 0], "AP_fnc_suiteRentNotice", _pl, false] spawn AP_fnc_MP;
            };
        };
    };
} forEach _due;

// ------------------------------------------------------------ repossessions
// Deliberately a SEPARATE query rather than a branch inside the loop above: a
// suite falls due and gets repossessed on different passes, and reading the
// arrears state fresh means a payment that landed seconds ago (Pay Now) is
// already reflected and cannot be evicted out from under the tenant.
private _dead = [format ["SELECT oid, COALESCE(owner,'') AS owner FROM suites WHERE owner IS NOT NULL AND overdue_since > 0 AND (extract(epoch from now())::bigint - overdue_since) >= %1", (localNamespace getVariable "APS_suiteGraceS")], 2, true] call DB_fnc_asyncQuery;
if !(_dead isEqualType []) then { _dead = []; };

{
    _x params [["_oid", ""], ["_uid", ""]];
    if (_oid isNotEqualTo "") then {
        diag_log format ["[SUITE] REPOSSESSING %1 from %2 (10 days in arrears)", _oid, _uid];
        [_oid, _uid, "arrears"] call APS_fnc_suiteRelease;
    };
} forEach _dead;

if ((count _due) + (count _dead) > 0) then {
    diag_log format ["[SUITE] rent sweep: %1 due, %2 repossessed", count _due, count _dead];
};

// ---- furniture presence prune -----------------------------------------------
// Suite furniture is presence-spawned (suites.md §8): it exists only while the
// tenant is around. This runs here rather than off a disconnect handler because
// the sweep already ticks every 300 s, and the disconnect path is the busiest
// and most incident-scarred one in the mission -- it is already carrying the
// house-inventory save, and adding to it has cost us data before.
// Keyed on the oid's owner still being connected; the client re-asks for a
// spawn (AP_fnc_suitePresence) the next time it walks into the suite.
if (!isNil {localNamespace getVariable "APS_suiteFurnCache"}) then {
    private _cache = localNamespace getVariable "APS_suiteFurnCache";   // server-private (APS_fnc_suiteFurnitureSRV)
    private _online = allPlayers apply { getPlayerUID _x };
    // The cache entry already carries the owner uid (oid -> [uid, objects]), so
    // this needs no query at all -- and it uses the SAME registry and the SAME
    // despawn that eviction uses, rather than a private copy of either.
    private _gone = (keys _cache) select {
        !(((_cache getOrDefault [_x, []]) param [0, ""]) in _online)
    };
    { [_x] call APS_fnc_suiteFurnitureDespawn; } forEach _gone;
    if (count _gone > 0) then {
        diag_log format ["[SUITE][FURN] presence prune: despawned %1 suite(s)", count _gone];
    };
};
