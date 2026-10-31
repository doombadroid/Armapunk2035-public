/*
    APS_fnc_houseTaxSRV  (LooneyBin -- implemented from stub 2026-06-09)
    House tax backend. DB: houses.tax_playtime (minutes the owner was online, +5/5min loop in init.sqf)
    + houses.tax_paid (last payment). Boot loop in init.sqf tags every owned house with
        AP_house_tax = [overdue(bool), canPayTax(bool), playtime(min), lastPayed(days)]
    which is all the client menu reads. Client cases (core/housing/fn_manageHouseTax.sqf):
      ["paySingleHouse", [player, houseObj, houseID]]
      ["payAllHouses",   [player, [[houseObj, houseID], ...]]]
    Price = client formula re-computed server-side (days * upkeep * playtime-reduction); charged via
    AP_fnc_uC atm-take on the client (client pre-checks affordability); AP_houseTxn cleared via
    netSetVar when done (the menu waits on it).
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];
// owner 2026-06-23 SECURITY (security.md §2.3 — SQLi): the client _houseID flows into `WHERE oid='%1'` and the
// derived _ownerUID into `WHERE owners='%1'` RAW. Money/authz here is already SAFE (§2.1); this only adds SQL
// escaping. Strip quotes/backslash before every interpolation.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };

private _calcTax = {params [["_house", objNull, [objNull]], ["_ownerUID", "", [""]]];
    if (isNull _house) exitWith { 0 };
    private _hd = _house getVariable ["AP_house_tax", []];
    if (_hd isEqualTo []) exitWith { 0 };
    _hd params ["_overdue", "_canPay", "_playtime", "_lastPayed"];
    if (_lastPayed <= 0) exitWith { 0 };
    private _cfg = [typeOf _house] call AP_fnc_houseConfig;
    if (_cfg isEqualTo []) exitWith { 0 };
    private _upkeep = _cfg select 4;
    private _cnt = 1;
    private _r = [format ["SELECT COUNT(*) AS c0 FROM houses WHERE owners='%1'", _ownerUID call _san], 2] call DB_fnc_asyncQuery;
    if (_r isEqualType []) then { _cnt = ((parseNumber format ["%1", _r param [0, 1]]) max 1) min 5; };
    private _tbl = [[1.0, 0.9, 0.8, 0.6, 0.4, 0.25], [1.2, 1.2, 1.1, 1.1, 1.0, 1.0, 0.8, 0.6, 0.5, 0.4, 0.25],
        [1.3, 1.3, 1.2, 1.2, 1.1, 1.1, 1.0, 0.9, 0.8, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
        [1.5, 1.5, 1.5, 1.4, 1.4, 1.4, 1.3, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25],
        [2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 1.9, 1.8, 1.7, 1.6, 1.5, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.4, 0.3, 0.3, 0.25]
    ] select (_cnt - 1);
    private _idx = floor (_playtime / 60);
    private _red = if (_idx > ((count _tbl) - 1)) then { 0.25 } else { _tbl select _idx };
    _red = (_red max 0.25) min 2.0;
    if (_overdue && _lastPayed > 32) then { _red = _red + 0.2; };
    round (_lastPayed * _upkeep * _red)};

private _payOne = {params ["_unit", "_house", "_houseID"];
    private _uid = getPlayerUID _unit;
    // REFUSE, DON'T DEFAULT (2026-09-04). params substitutes its default silently when an
    // argument fails its type check, so a caller passing the wrong variable arrived here as
    // _houseID = -1 and the UPDATE below ran as `WHERE oid='-1'` -- matching nothing, AFTER
    // the take order below had already moved the money. Charge-then-write-to-nothing is the
    // worst ordering available, so the id is validated FIRST and a bad one costs the player
    // nothing. An oid is a positive integer stored as varchar -- validated as DIGITS, never
    // through parseNumber: oids are 8 digits, SQF numbers are float32 (exact only to 16,777,216)
    // and str prints six significant figures, so `str (parseNumber "50474717")` is "5.04747e+07"
    // and a round-trip check refused every house on the map (owner, 2026-09-04 22:22).
    private _idStr = _houseID call _san;
    private _idOk = (_idStr isNotEqualTo "") && {count _idStr <= 20} && {_idStr regexMatch "[1-9][0-9]*"};
    if (!_idOk) exitWith {
        diag_log format ["[LooneyBin][houseTax] REFUSED: unusable houseID %1 (type %2) from %3 -- nothing charged, nothing written", _houseID, typeName _houseID, _uid];
        [["A problem with that house's record stopped the payment. Nothing was charged.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        0 };
    private _price = [_house, _uid] call _calcTax;
    if (_price <= 0) exitWith { 0 };
    // owner 2026-06-18 (#374 house-tax double-charge on relog): the client passes _houseID = AP_houseID = the
    // house OID (init.sqf:444 sets AP_houseID to the `oid` column), NOT the `id` PK. The old `WHERE id='%1'`
    // therefore matched the WRONG row / nothing -> tax_paid never updated -> on relog DATEDIFF(NOW(),tax_paid)
    // stayed high -> house showed unpaid + charged AGAIN (money lost every relog). `oid` is UNIQUE and is the
    // house-identity key the rest of the system uses (fn_bldgUpdateKeys writes `WHERE oid=...`). Use it here too.
    [format ["UPDATE houses SET tax_paid=NOW(), tax_playtime='0' WHERE oid='%1'", _idStr]] call DB_fnc_asyncQuery;
    // ONE debit, ordered by the server AFTER the row is written: the client paths no longer subtract
    // locally (they used to, AND this take ran -- every payment cost double), and a refusal above
    // costs nothing. AP_fnc_uC keeps AP_atmcashCacheB in step. The price is the server's.
    [["atm", "take", _price], "AP_fnc_uC", _unit, false, false] spawn AP_fnc_MP;
    _house setVariable ["AP_house_tax", [false, false, 0, 0], true];
    ["-HOUSETAX-", _unit, name _unit, format ["paid $%1 house tax for house id: %2", [_price] call AP_fnc_numberText, _idStr]] call APS_fnc_logIt;
    _price};

switch (_caseType) do {case "paySingleHouse": {
        _data params [["_unit", objNull, [objNull]], ["_house", objNull, [objNull]], ["_houseID", -1, [0, ""]]];
        if (isNull _unit || {isNull _house}) exitWith {};
        private _paid = [_unit, _house, _houseID] call _payOne;
        if (_paid > 0) then {
            [[format ["You paid $%1 house tax.", [_paid] call AP_fnc_numberText], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        };
        [["AP_houseTxn", false], "AP_fnc_netSetVar", _unit, false, false] spawn AP_fnc_MP;};
    case "payAllHouses": {_data params [["_unit", objNull, [objNull]], ["_taxHouses", [], [[]]]];
        if (isNull _unit) exitWith {};
        private _total = 0;
        { _x params ["_house", "_houseID"]; if (!isNull _house) then { _total = _total + ([_unit, _house, _houseID] call _payOne); }; } forEach _taxHouses;
        if (_total > 0) then {
            [[format ["You paid $%1 house tax for %2 house(s).", [_total] call AP_fnc_numberText, count _taxHouses], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
        };
        [["AP_houseTxn", false], "AP_fnc_netSetVar", _unit, false, false] spawn AP_fnc_MP;};
    default { diag_log format ["[LooneyBin][houseTax] unhandled case: %1", _this]; };};
