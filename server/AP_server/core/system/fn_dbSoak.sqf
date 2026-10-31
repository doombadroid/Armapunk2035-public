/*
    APS_fnc_dbSoak -- in-game database soak: every DB fn class, on scratch rows.

    The plan's H5+H6 in one place (H5's "conformance group" cannot live in
    core/pysqf/ -- those files are VENDORED transport, regenerated from the
    PySQF repo, and game schema knowledge does not belong upstream).

    [] spawn APS_fnc_dbSoak;              // everything
    ["codec"] spawn APS_fnc_dbSoak;       // one section
    Sections: codec, players, vehicles, gangs, wanted, houses, storage.

    Output: one `[DBSOAK] PASS|FAIL <section>/<case> ...` RPT line per case,
    a per-section tally, and a final verdict. Grep `\[DBSOAK\]`. FAIL lines
    carry got-vs-want. Everything runs against SOAK_* fixture rows and a
    dbsoak_probe scratch table; both are removed at the end, pass or fail.

    This is the runtime gate for the statements prepare_gate.py reports as
    UNREALISABLE (dynamic table/column): the calls here realise them with
    live arguments through the real DB fns.
*/
if (!isServer) exitWith {};
params [["_only", "", [""]]];

private _pass = 0;
private _fail = 0;
private _section = "";
private _t = {
    // [name, got, want] -> one PASS/FAIL line. Arrays compared by isEqualTo.
    params ["_name", "_got", "_want"];
    if (_got isEqualTo _want) then {
        _pass = _pass + 1;
        diag_log format ["[DBSOAK] PASS %1/%2", _section, _name];
    } else {
        _fail = _fail + 1;
        diag_log format ["[DBSOAK] FAIL %1/%2  got=%3  want=%4", _section, _name, _got, _want];
    };
};
private _dec = {
    // the login path's decode chain, verbatim shape (fn_queryRequest _dec)
    params [["_v", ""]];
    if (isNil "_v") exitWith {[]};
    if (_v isEqualType []) exitWith {_v};
    if (_v isEqualTo "" || {_v isEqualTo "NULL"}) exitWith {[]};
    private _a = [_v] call DB_fnc_mresToArray;
    if (typeName _a == "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
    if (isNil "_a") then { _a = []; };
    _a
};
private _run = { params ["_name"]; (_only isEqualTo "") || {_only isEqualTo _name} };

private _uid = "SOAK_765000000001";   // 17 chars -- playerid is varchar(17), PG REFUSES longer (MariaDB truncated)
diag_log format ["[DBSOAK] start (filter='%1') engine=%2", _only,
    ["extDB3/MariaDB", "PySQF/PostgreSQL"] select ("AP_db_postgres" call DB_fnc_flag)];

// ---------------------------------------------------------------- codec ----
if (["codec"] call _run) then {
    _section = "codec";
    // scratch table via the runtime-DDL path (the same class the boot DDL uses)
    ["DROP TABLE IF EXISTS dbsoak_probe", 1] call DB_fnc_asyncQuery;
    ["CREATE TABLE IF NOT EXISTS dbsoak_probe (id INT NOT NULL PRIMARY KEY, blob TEXT, note VARCHAR(64), n INT)", 1] call DB_fnc_asyncQuery;

    private _fixtures = [
        [],
        [[], 0],
        [[["marijuana", 40], ["smashpowder", 25]], 215],
        [[[], [], [], ["U_C_Poloshirt_blue", []], [], [], "", "", [],
          ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", ""]],
         [[["apple", 1]], 0], [-1, -1]],
        [["license_civ_boat", true], ["license_civ_bounty", false]]
    ];
    {
        private _orig = _x;
        private _blob = [_orig] call DB_fnc_mresArray;
        [format ["DELETE FROM dbsoak_probe WHERE id=1"], 1] call DB_fnc_asyncQuery;
        [format ["INSERT INTO dbsoak_probe (id, blob) VALUES (1,'%1')", _blob], 1] call DB_fnc_asyncQuery;
        private _row = ["SELECT blob FROM dbsoak_probe WHERE id=1", 2] call DB_fnc_asyncQuery;
        private _back = [_row param [0, ""]] call _dec;
        // booleans render as engine literals and parse back as booleans; the
        // fixtures avoid asserting boolean spelling beyond round-trip equality
        [format ["roundtrip_%1", _forEachIndex], _back, _orig] call _t;
    } forEach _fixtures;

    // NULL column -> the decode chain must yield [] and never raise
    ["DELETE FROM dbsoak_probe WHERE id=2", 1] call DB_fnc_asyncQuery;
    ["INSERT INTO dbsoak_probe (id, note) VALUES (2,'nullrow')", 1] call DB_fnc_asyncQuery;
    private _nullRow = ["SELECT blob FROM dbsoak_probe WHERE id=2", 2] call DB_fnc_asyncQuery;
    ["null_blob_decodes_empty", [_nullRow param [0, ""]] call _dec, []] call _t;

    // ::text position (the ported form of QUOTE): a number cast to text must arrive as a STRING
    ["UPDATE dbsoak_probe SET n=42 WHERE id=2", 1] call DB_fnc_asyncQuery;
    private _q = ["SELECT (n)::text AS n FROM dbsoak_probe WHERE id=2", 2] call DB_fnc_asyncQuery;
    ["quote_is_string", (_q param [0, 0]) isEqualType "", true] call _t;
    ["quote_value", format ["%1", _q param [0, ""]], "42"] call _t;

    // no rows is [], not an error
    ["no_rows_is_empty", ["SELECT blob FROM dbsoak_probe WHERE id=999", 2, true] call DB_fnc_asyncQuery, []] call _t;

    // multiarr shape
    private _all = ["SELECT id FROM dbsoak_probe ORDER BY id", 2, true] call DB_fnc_asyncQuery;
    ["multiarr_two_rows", count _all, 2] call _t;
};

// -------------------------------------------------------------- players ----
if (["players"] call _run) then {
    _section = "players";
    [format ["DELETE FROM players WHERE playerid='%1'", _uid], 1] call DB_fnc_asyncQuery;
    [format ["DELETE FROM players_global WHERE playerid='%1'", _uid], 1] call DB_fnc_asyncQuery;
    [format ["INSERT INTO players_global (playerid) VALUES('%1') ON CONFLICT DO NOTHING", _uid], 1] call DB_fnc_asyncQuery;
    [format ["INSERT INTO players (playerid, name, instance, new_player) VALUES('%1','dbsoak','%2', '1') ON CONFLICT DO NOTHING", _uid, 1], 1] call DB_fnc_asyncQuery;
    private _exists = [format ["SELECT playerid FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["insert_ignore_lands", format ["%1", _exists param [0, ""]], _uid] call _t;

    // updatePartial mode 10: position (civ). Server-local call, owner 0.
    private _pos = [4242.5, 8181.25, 0.5];
    [objNull, civilian, _uid, 10, _pos] call DB_fnc_updatePartial;
    private _prow = [format ["SELECT position FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["mode10_position", [_prow param [0, ""]] call _dec, _pos] call _t;

    // mode 10 death sentinel []
    [objNull, civilian, _uid, 10, []] call DB_fnc_updatePartial;
    _prow = [format ["SELECT position FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["mode10_sentinel", [_prow param [0, ""]] call _dec, []] call _t;

    // mode 3: gear blob through the real writer
    private _gear = [[[], [], [], ["U_C_Poloshirt_blue", []], [], [], "", "", [], []], [[], 0], [-1, -1]];
    [objNull, civilian, _uid, 3, _gear] call DB_fnc_updatePartial;
    private _grow = [format ["SELECT civ_gear FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["mode3_civ_gear", [_grow param [0, ""]] call _dec, _gear] call _t;

    // mode 6: money as numberSafe strings
    [objNull, civilian, _uid, 6, 12345, 67890] call DB_fnc_updatePartial;
    private _mrow = [format ["SELECT cash, bankacc FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["mode6_cash", parseNumber format ["%1", _mrow param [0, 0]], 12345] call _t;
    ["mode6_bank", parseNumber format ["%1", _mrow param [1, 0]], 67890] call _t;

    // mode 5: arrested blob
    [objNull, civilian, _uid, 5, [[1, 500, 10]]] call DB_fnc_updatePartial;
    private _arow = [format ["SELECT arrested FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["mode5_arrested", [_arow param [0, ""]] call _dec, [[1, 500, 10]]] call _t;
};

// ------------------------------------------------------------- vehicles ----
if (["vehicles"] call _run) then {
    _section = "vehicles";
    [format ["DELETE FROM vehicles WHERE pid='%1'", _uid], 1] call DB_fnc_asyncQuery;
    // the real writer: side, classname, type, pid, color, plate
    // fn_insertVehicle params: [uid, side, type, className, color, plate]
    [_uid, "civ", "Car", "C_Offroad_01_F", 3, 424242] call DB_fnc_insertVehicle;
    uiSleep 1;
    private _vrow = [format ["SELECT classname, plate, alive, active FROM vehicles WHERE pid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["insert_classname", format ["%1", _vrow param [0, ""]], "C_Offroad_01_F"] call _t;
    // fractional fuel/damage at integer columns: the class the translator now
    // rounds half-away-from-zero instead of PostgreSQL refusing the statement
    [format ["UPDATE vehicles SET active='0', fuel='99.9228', damage='0.4' WHERE pid='%1' AND plate='424242'", _uid], 1] call DB_fnc_asyncQuery;
    private _frow = [format ["SELECT fuel, damage FROM vehicles WHERE pid='%1' AND plate='424242'", _uid], 2] call DB_fnc_asyncQuery;
    ["fractional_fuel_rounds", parseNumber format ["%1", _frow param [0, -1]], 100] call _t;
    ["fractional_damage_rounds", parseNumber format ["%1", _frow param [1, -1]], 0] call _t;
};

// ---------------------------------------------------------------- gangs ----
if (["gangs"] call _run) then {
    _section = "gangs";
    ["DELETE FROM gangs WHERE name='SOAK_GANG'", 1] call DB_fnc_asyncQuery;
    private _gid = ["SELECT COALESCE(MAX(id),0)+1 FROM gangs", 2] call DB_fnc_asyncQuery;
    private _newId = parseNumber format ["%1", _gid param [0, 0]];
    ["max_id_numeric", _newId > 0, true] call _t;
    [format ["INSERT INTO gangs (id, name, inviterank, kickrank, bank, experience, instance) VALUES ('%1','SOAK_GANG','2','2','0','0','%2')", _newId, 1], 1] call DB_fnc_asyncQuery;
    private _grow = ["SELECT id, name FROM gangs WHERE name='SOAK_GANG'", 2] call DB_fnc_asyncQuery;
    ["insert_readback", format ["%1", _grow param [1, ""]], "SOAK_GANG"] call _t;
    [format ["DELETE FROM gangs WHERE ctid IN (SELECT ctid FROM gangs WHERE id='%1' LIMIT 1)", _grow param [0, -1]], 1] call DB_fnc_asyncQuery;
    private _gone = ["SELECT id FROM gangs WHERE name='SOAK_GANG'", 2, true] call DB_fnc_asyncQuery;
    ["delete_limit1", _gone, []] call _t;
};

// --------------------------------------------------------------- wanted ----
if (["wanted"] call _run) then {
    _section = "wanted";
    [format ["DELETE FROM wanted WHERE playerid='%1'", _uid], 1] call DB_fnc_asyncQuery;
    // the ON DUPLICATE KEY upsert, twice: insert then update
    // fn_insertWanted params: [name, uid, crimes, bounty, jail]
    ["dbsoak", _uid, [[1]], 1000, 5] call DB_fnc_insertWanted;
    uiSleep 1;
    ["dbsoak", _uid, [[1], [3]], 2500, 8] call DB_fnc_insertWanted;
    uiSleep 1;
    private _wrow = [format ["SELECT bounty, crimes FROM wanted WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    ["upsert_bounty", parseNumber format ["%1", _wrow param [0, 0]], 2500] call _t;
    ["upsert_crimes", [_wrow param [1, ""]] call _dec, [[1], [3]]] call _t;
    [format ["DELETE FROM wanted WHERE playerid='%1'", _uid], 1] call DB_fnc_asyncQuery;
};

// --------------------------------------------------------------- houses ----
if (["houses"] call _run) then {
    _section = "houses";
    private _ws = [7777.7, 8888.8, 0.42];
    ["DELETE FROM houses WHERE owners='SOAK_OWNER'", 1] call DB_fnc_asyncQuery;
    private _wsBlob = [_ws] call DB_fnc_mresArray;
    [format ["INSERT INTO houses (oid, owners, locked, worldspace) VALUES (990001,'SOAK_OWNER','1','%1')", _wsBlob], 1] call DB_fnc_asyncQuery;
    private _hrow = ["SELECT worldspace, locked FROM houses WHERE owners='SOAK_OWNER'", 2] call DB_fnc_asyncQuery;
    // worldspace is stored WRAPPED (mres) and selected with QUOTE() at real
    // call sites -- the read must come back decodable either way
    ["worldspace_roundtrip", [_hrow param [0, ""]] call _dec, _ws] call _t;
    ["DELETE FROM houses WHERE owners='SOAK_OWNER'", 1] call DB_fnc_asyncQuery;
};

// -------------------------------------------------------------- storage ----
if (["storage"] call _run) then {
    _section = "storage";
    ["DELETE FROM storage WHERE houseid=990001", 1] call DB_fnc_asyncQuery;
    [format ["INSERT INTO storage (houseid, worldspace, container, classname, contents, virtual, houseworldspace) VALUES (990001,'%1','1','Land_Cargo20_blue_F','%2','%3','%1')",
        [[1234.5, 5678.9, 0]] call DB_fnc_mresArray,
        [[[["copperore", 12]], 0]] call DB_fnc_mresArray,
        [[[], 0]] call DB_fnc_mresArray], 1] call DB_fnc_asyncQuery;
    private _srow = ["SELECT contents, virtual FROM storage WHERE houseid=990001", 2] call DB_fnc_asyncQuery;
    ["contents_roundtrip", [_srow param [0, ""]] call _dec, [[["copperore", 12]], 0]] call _t;
    ["virtual_roundtrip", [_srow param [1, ""]] call _dec, [[], 0]] call _t;
    ["DELETE FROM storage WHERE houseid=990001", 1] call DB_fnc_asyncQuery;
};

// -------------------------------------------------------------- cleanup ----
["DROP TABLE IF EXISTS dbsoak_probe", 1] call DB_fnc_asyncQuery;
[format ["DELETE FROM players WHERE playerid='%1'", _uid], 1] call DB_fnc_asyncQuery;
[format ["DELETE FROM players_global WHERE playerid='%1'", _uid], 1] call DB_fnc_asyncQuery;
[format ["DELETE FROM vehicles WHERE pid='%1'", _uid], 1] call DB_fnc_asyncQuery;

diag_log format ["[DBSOAK] verdict: %1 pass, %2 fail -- %3", _pass, _fail,
    ["ALL GREEN", "FAILURES ABOVE"] select (_fail > 0)];
[_pass, _fail]
