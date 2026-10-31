/*
    APS_fnc_tagHousesSRV  (LooneyBin, owner 2026-07-10)
    THE house tag pass: stamps every DB-registered house building with its identity + state vars
    (AP_homeOwner / AP_houseID / AP_house_keys / AP_house_tax / caps / upgrade flags / lock / custom name).

    Extracted from the two identical `_tagHouses` closures inside init.sqf's houseTax job so it can ALSO be
    called by custom_p3ds\replace_sheds.sqf the moment the buyable sheds exist. Why that matters:
    fn_receiveHouses (the boot tagger) runs BEFORE replace_sheds createVehicles the intact sheds (+6s), and
    the houseTax scheduler job is registered runAtStart=false -> its first tag pass fired at ~+5min. Every
    owned shed therefore spent the first ~5 minutes of every restart with NO ownership vars: the House Menu
    offered to SELL you your own shed, the keychain missed it, and a rename during the window hit the
    AP_houseID=-1 guard in fn_renameHouseSRV and was refused. replace_sheds now calls this at ~+7s.

    NEW here vs the old closures: re-applies the player-set house name (houses.custom_name -> AP_houseName,
    col 15) every pass. fn_receiveHouses already did this for normal houses, but sheds never got a working
    receiveHouses pass (see above), so SHED renames silently un-applied on every restart even though the DB
    row kept them.

    Returns: the number of buildings tagged.
    Callers: init.sqf houseTax job (first fire + every 300s, both scheduler/legacy branches), replace_sheds.sqf.
*/

// decode an mres-encoded keyholders blob the same way fn_receiveHouses does
private _decKeys = {params [["_v", "", [""]]];
    if (_v isEqualTo "" || {_v isEqualTo "NULL"}) exitWith {[]};
    private _a = [_v] call DB_fnc_mresToArray;
    if (typeName _a == "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
    if (isNil "_a" || {!(_a isEqualType [])}) then { _a = []; };
    _a};

// owner 2026-06-20 (mres decode spam -- 76 errors/5min): keyholders is an mres/str2-encoded blob whose
// OWN outer double-quotes are the string delimiters asyncQuery's call-compile consumes (the project RULE,
// see fn_queryRequest:56-58). QUOTE()-ing it added a SECOND quote layer -> mresToArray got `"[[``...``]]"`
// with literal outer quotes -> its inner `call compile` went nil -> "Undefined variable: _array" x76 every
// 5-min tag pass AND the keyholder list never decoded -> shared-house keys never restored after a restart
// (#307). fn_receiveHouses reads keyholders BARE (fn_queryHouses:15) and decodes fine with 0 errors -> match
// it exactly: bare column, no QUOTE/COALESCE (the _decKeys guard already handles ""/"NULL").
// owner 2026-07-04: classname MUST be QUOTE()'d. extDB3 returns varchars BARE and DB_fnc_asyncQuery
// call-compiles the whole result string, so an unquoted `Land_u_Shed_Ind_F` compiled as an UNDEFINED
// VARIABLE -> that result slot nil'd -> _x param [7,""] fell back to "" for EVERY shed row -> _dbCls=""
// -> _isShedRow=false -> the entire shed-resolution branch below was DEAD (the b0125 fix never ran).
// Same footgun the code documents at fn_getVehicles (QUOTE(classname) / QUOTE(COALESCE(mods,'[]'))).
// keyholders stays BARE on purpose -- it is an mres blob that carries its own quotes.
private _rows = ["SELECT id, worldspace, tax_playtime, COALESCE((now()::date - tax_paid::date), 0) AS tax_paid, owners, oid, keyholders, COALESCE(classname,'') AS classname, vcap, phys_cap, keycap, barrel, greenhouse, leadcontainer, locked, COALESCE(custom_name,'') AS custom_name FROM houses", 2, true] call DB_fnc_asyncQuery;
if !(_rows isEqualType []) exitWith { 0 };
private _n = 0; {private _ws = parseSimpleArray format ["%1", _x param [1, "[]"]];
    if (_ws isEqualType [] && {count _ws >= 2}) then {
        // owner 2026-07-04: resolve the House_F whose TYPE matches the DB classname (param 7), not just
        // the nearest. Some worldspaces have MULTIPLE House_F -- most notably a buyable industrial shed
        // (Land_i_Shed_Ind_F, createVehicle'd by replace_sheds) whose spot ALSO holds the banished derelict
        // Land_u_Shed_Ind_F. A bare `param [0]` grabbed the wrong one, so the owned shed never got
        // AP_homeOwner -> "buy your own shed" while inventory (keyed on AP_house_keys / AP_vehicles)
        // still worked. Fall back to the nearest House_F for old rows with no stored classname.
        private _dbCls = format ["%1", _x param [7, ""]];
        // owner 2026-07-04: SHED rows are special. The derelict Land_u_Shed_Ind_F lingers at every buyable
        // shed spot (terrain object -- can't be deleted, hideObjectGlobal only hides it, setPos won't move
        // a static map object), so a bought shed's worldspace sits ON the hidden derelict while the intact,
        // createVehicle'd Land_i_Shed_Ind_F stands at the SAME spot (both House_F, both dist 0). A plain
        // nearest-House_F grab is a coin-flip that keeps landing on the derelict. For a shed row, resolve
        // the intact by its EXACT class (NOT a "House_F" filter -- Land_i_Shed_Ind_F is not reliably
        // isKindOf "House_F" per the gang-tagger #208 note) and force the classname write to intact so
        // the DB self-heals (683/684/685/686/689/692). Never tag/write the derelict for a shed row.
        // owner 2026-07-10: ALSO detect a shed row BY POSITION when the classname column is empty/NULL --
        // fn_addHouse's INSERT never wrote classname, so a freshly-bought shed's first restart had
        // _dbCls="" -> fell to the House_F fallback below -> industrial sheds aren't House_F -> the row
        // NEVER resolved and never self-healed its classname (chicken-and-egg; dev row 488 "Test" proved it).
        // The lazy position probe only runs for rows with no classname, and the shed branch then forces the
        // classname write, so each such row heals itself on its first tag pass.
        private _isShedRow = (_dbCls isEqualTo "Land_i_Shed_Ind_F") || {_dbCls isEqualTo "Land_u_Shed_Ind_F"}
            || {(_dbCls isEqualTo "" || {_dbCls isEqualTo "NULL"}) && {(nearestObjects [_ws, ["Land_i_Shed_Ind_F"], 18]) isNotEqualTo []}};
        private _cands = nearestObjects [_ws, ["House_F"], 10];
        private _b = objNull;
        if (_isShedRow) then {_b = (nearestObjects [_ws, ["Land_i_Shed_Ind_F"], 18]) param [0, objNull];
            if (!isNull _b) then { _dbCls = "Land_i_Shed_Ind_F"; };} else {
            // owner 2026-07-11 (Malden Makeover, "one house works the other doesn't"): big terrain houses
            // silently REFUSE setPosASL (unlike the u_sheds), so a maldened house's hidden original still
            // STANDS at the spot 0.2m from its Argo shell -- and this exact-classname match kept re-tagging
            // the INVISIBLE original, leaving login binding to 2D-sort luck. A hidden object is never a
            // legit tag target: filter them out everywhere here.
            if (_dbCls isNotEqualTo "" && {_dbCls isNotEqualTo "NULL"}) then {
                _b = (_cands select { (typeOf _x) isEqualTo _dbCls && {!isObjectHidden _x} }) param [0, objNull];
                // maldened row: the visible object is the Argo variant of the SAME FAMILY (stem match -- the
                // skin picker means any of 6 colors can be standing there).
                if (isNull _b) then {private _stem = ["stem", _dbCls] call AP_fnc_maldenMap;
                    if (_stem isNotEqualTo "") then {
                        _b = (_cands select { (_x getVariable ["AP_malden", false]) && {(["stem", typeOf _x] call AP_fnc_maldenMap) isEqualTo _stem} }) param [0, objNull];
                    };};};
            if (isNull _b) then { _b = (_cands select { !isObjectHidden _x }) param [0, objNull]; };};
        if (!isNull _b) then {private _pt   = parseNumber format ["%1", _x param [2, 0]];
            private _days = parseNumber format ["%1", _x param [3, 0]];
            _b setVariable ["AP_house_tax", [_days > 14, _days >= 1, _pt, _days], true];
            // owner 2026-06-16 (#305/#307/#310): fn_receiveHouses tags house OWNERSHIP/ID/KEYS at boot, but it
            // resolves the building with nearestObjects and the map buildings stream in ~20s AFTER it runs ->
            // it tagged nothing -> AP_homeOwner="" (gang houses died for members whenever the owner was
            // offline, #305/#310) AND AP_houseID=-1 so fn_bldgUpdateKeys SKIPPED its `WHERE oid=...` write
            // -> given house keys NEVER persisted (#307; keyholders column was NULL for every row). This pass
            // runs after buildings exist, so re-establish the identity tags (keyed on `oid`, exactly
            // like fn_receiveHouses) + restore the keyholder list. owner/oid don't change in-session; keys
            // come straight from the DB (bldgUpdateKeys writes them immediately) so re-reading stays correct.
            private _oid = format ["%1", _x param [5, ""]];
            private _own = format ["%1", _x param [4, ""]];
            if (_own isNotEqualTo "" && {_own isNotEqualTo "NULL"}) then {_b setVariable ["AP_homeOwner", _own, true];
                // owner 2026-06-20: a registered house sitting within 10m of a shop NPC was getting wrongly
                // flagged AP_restricted_house=true by fn_shops' nearest-building grab (before/around this
                // tagging), killing the owner's House Menu + grab-ID. Clear it on every owned house here (this
                // pass re-runs every 5min, so it also self-heals an early-connect race). Shops aren't in the
                // `houses` table so their flag is never touched. Pairs with the fn_shops/fn_copShops fix.
                _b setVariable ["AP_restricted_house", false, true];};
            if (_oid isNotEqualTo "" && {_oid isNotEqualTo "NULL"}) then {_b setVariable ["AP_houseID", _oid, true];
                _b setVariable ["AP_buildID", _oid, true];
                _b setVariable ["houseId", _oid, true];};
            // owner 2026-06-21 (Latoya IRS bot): persist the house TYPE so the offline Discord tax bot can
            // compute exact upkeep (the houses table only stored worldspace). Write only when missing/changed.
            // owner 2026-07-11 (Malden Makeover): a maldened house resolves to its SWAPPED-IN Argo variant --
            // NEVER self-heal that into classname (the stored BASE class is the restore/eligibility source;
            // writing the variant would corrupt the record + break the revert). Variants skip the write.
            if (_oid isNotEqualTo "" && {_oid isNotEqualTo "NULL"}) then {private _cls = typeOf _b;
                if (_cls isNotEqualTo "" && {(format ["%1", _x param [7, ""]]) isNotEqualTo _cls}
                    && {(["base", _cls] call AP_fnc_maldenMap) isEqualTo ""}) then {
                    [format ["UPDATE houses SET classname='%1' WHERE oid='%2'", _cls, _oid]] call DB_fnc_asyncQuery;};};
            private _kh = [format ["%1", _x param [6, ""]]] call _decKeys;
            if (_kh isEqualType [] && {count _kh > 0}) then {_b setVariable ["AP_house_keys", _kh, true];};
            // owner 2026-07-06: SHED 100-CAP FIX. fn_receiveHouses (the only boot cap-restorer) resolves houses
            // via nearestObjects["House_F"] at init, but buyable sheds are createVehicle'd ~6s LATER
            // (replace_sheds) so the intact shed doesn't exist yet -> its AP_vcap/phys_cap/keycap/upgrade-flags
            // are never stamped -> reads fall to the 100 fallback + fn_upgradeProperty treats the NIL cap as
            // maxed and refuses to expand. This pass runs after the shed exists + already re-resolves
            // the intact shed, so restore the storage state receiveHouses missed (mirrors fn_receiveHouses:49-54).
            // Self-heals ANY house the boot race skipped, sheds included. The DB row still holds the correct
            // values (fn_addHouse INSERT + fn_upgradeProperty writes) -> no data loss.
            private _shedVcap = parseNumber format ["%1", _x param [8, -1]];   // guard NULL/empty -> don't zero the cap
            if (_shedVcap > 0) then { _b setVariable ["AP_vcap", _shedVcap, true]; };
            private _shedPcap = parseNumber format ["%1", _x param [9, -1]];
            if (_shedPcap > 0) then { _b setVariable ["AP_phys_cap", _shedPcap, true]; };
            _b setVariable ["AP_keycap",               parseNumber format ["%1", _x param [10, 0]],   true];
            _b setVariable ["AP_barrel_unaged",        (parseNumber format ["%1", _x param [11, 0]]) isEqualTo 1, true];
            _b setVariable ["AP_greenhouse_unaged",    (parseNumber format ["%1", _x param [12, 0]]) isEqualTo 1, true];
            _b setVariable ["AP_leadcontainer_unaged", (parseNumber format ["%1", _x param [13, 0]]) isEqualTo 1, true];
            _b setVariable ["AP_buildingLocked",               (parseNumber format ["%1", _x param [14, 0]]) isEqualTo 1, true];
            // owner 2026-07-10: player-set house name (houses.custom_name, col 15). GLOBAL so markers/keychain/
            // spawn list read it everywhere. Re-applied every pass; the DB is the source of truth (renameHouseSRV
            // writes it there first). Empty/NULL -> "" and the clients fall back to the building display name.
            private _cn = format ["%1", _x param [15, ""]];
            if (_cn isEqualTo "NULL") then { _cn = ""; };
            _b setVariable ["AP_houseName", _cn, true];
            _n = _n + 1;};};} forEach _rows;
_n
