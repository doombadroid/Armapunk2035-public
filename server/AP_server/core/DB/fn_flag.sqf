/*
    DB_fnc_flag -- the ONE reader of the DB layer's control flags.

        "AP_db_postgres" call DB_fnc_flag   -> its value; false when unset

    DB_Async_Active (the query mutex), AP_db_postgres / AP_db_engineDecided (the engine
    decision, init.sqf) and AP_server_training (the DB-writer kill switch, vars.sqf) live in
    localNamespace and are written only by the server: vars.sqf, init.sqf and the
    asyncQuery/asyncExec mutex, each with `localNamespace setVariable`.

    Never move them back to plain missionNamespace globals. publicVariable is not disabled and
    BattlEye is off, so any client can overwrite a missionNamespace global on the server:
    DB_Async_Active=true froze every query, AP_db_postgres=false sent every write down the
    removed extDB3 path (which answers true and writes nothing), AP_server_training=true made
    every DB writer skip. publicVariable cannot reach localNamespace (audit srvdb-0-0).
*/
localNamespace getVariable [_this, false]
