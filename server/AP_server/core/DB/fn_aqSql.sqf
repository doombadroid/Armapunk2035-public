/*
    File: fn_aqSql.sqf  (APS_fnc_aqSql)
    The host side of ArmaQuest's `sql` store: AQ_Settings >> sqlExec names this.

    ArmaQuest hands us MariaDB-flavoured SQL and a mode, and wants rows back. That
    is exactly DB_fnc_asyncQuery's contract, so this is a pass-through — and it is
    a pass-through ON PURPOSE. Pointing the library at DB_fnc_asyncQuery rather
    than at apdb.query means ArmaQuest follows the mission's transport wherever it
    goes (extDB3 yesterday, PySQF+Postgres today) with no library change.

    Server-only: it is a database call, and the library never calls it elsewhere.

    FAILURE SIGNAL (Task 3 Part 2 -- decided and measured, not assumed; live-tested
    2026-08-16 against server/AP_server/core/DB/fn_asyncQuery.sqf, this host's actual
    DB_fnc_asyncQuery transport today: extDB3 -> MariaDB. See task-3-report.md for the
    boot-log evidence.)
      mode 1  ALWAYS returns `true`, whether the write landed or not -- extDB3's own
              fn_asyncQuery.sqf exits with `true` for mode 1 without ever reading the
              extension's reply. No caller can learn anything from a mode-1 result.
      mode 2  returns the row(s) on a successful read with data. On every other
              outcome measured -- zero matching rows, a query against a table that
              does not exist, a write that affected zero rows, and a write that
              affected one -- it returns the exact same bare []. The one place the
              two differ is a diag_log line ("extDB3: Protocol Error: ...") written
              only on failure, and that is a server-log side channel, not part of
              the return value; nothing in SQF reads it back.
    This function does not interpret either shape. It is a lossless pass-through:
    whatever DB_fnc_asyncQuery returns for [_sql, _mode] is exactly what is returned
    here, unchanged, on every path. There is nothing to inspect here that would add a
    distinction mode 2 does not already carry -- the flattening happens one layer
    down, inside extDB3, before this function is ever called, so "propagate the
    distinction rather than flattening it" means propagate it exactly as-is, which is
    what the pass-through below already does.
    A caller that must be SURE a write landed cannot get that from the write call's
    own result on this transport, in any mode -- proven, not merely undocumented.
    It has to read the row back afterwards (mode 2) and compare, which is what
    aq_fnc_storeSql's `save` now does (ArmaQuest server/fn_storeSql.sqf, upstream).
    "Absent or unreachable" (`""` / `[]`) versus "present, with matching content" is
    the one distinction this transport draws reliably, and only a read observes it.
*/
params [["_sql", "", [""]], ["_mode", 2, [0]]];
if (!isServer) exitWith { [] };
if (_sql isEqualTo "") exitWith { [] };
[_sql, _mode] call DB_fnc_asyncQuery
