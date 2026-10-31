/*
    APS_fnc_miningSRV  (LooneyBin) -- New Drachma mining rigs, PHYSICAL PLACEABLE edition (owner 2026-07-18).
    (Currency renamed LoonyCoin -> New Drachma 2026-07-22, DISPLAY ONLY: the item key stays "loonycoin"
    everywhere -- DB inventories, sell lists and CLANKR reference the key.)
    MULTI-RIG (owner 2026-07-22): max 5 rigs per PLAYER, spread across owned houses however they like
    (all 5 in one house is fine). Each rig is a house_rigs row (id, oid, owner, pos "x:y:z:dir", since,
    last_collect) with its OWN accrual; the old single-slot houses.rig/miner columns are retired.
    Assemble the 8 crypto COMPONENTS -> a cryptoRig item -> USE it in an owned house -> place the physical
    CryptoMiningRig composition (compositions\cryptorig.sqf). Spawned SERVER-SIDE so everyone sees it,
    up 24/7 (shed-helipad model). Scroll it to Collect / Move / Delete. Mines LoonyCoin on server time;
    collect + sell at Blackmarket. Collect = ALL your rigs in that house at once (one scroll, 5 stamps).

    Cases:
      ["assemble", _player]                 consume all 8 components -> grant 1 cryptoRig
      ["place", _player,_house,_pos,_dir]    place a rig in an owned house (item already client-consumed) ->
                                             insert + spawn; rejects (cap/own) REFUND the cryptoRig
      ["collect", _player,_rig]              grant accrued LoonyCoin from EVERY rig you own in that house
      ["delete", _player,_rig]               despawn + delete THAT rig's row + REFUND the cryptoRig item
      ["reload"]                             boot: spawn every saved rig row (after houses exist)
*/
if (!isServer) exitWith {};
params [["_case", "", [""]], ["_a1", objNull], ["_a2", objNull], ["_a3", [0,0,0], [[]]], ["_a4", 0, [0]]];
// CALLER BINDING (the one caller-resolution block -- houses review + cdsql audit, 2026-09-26): the acting player is
// whoever remoteExec'd this, never the payload's _a1. Every client caller passes `player` as _a1 (fn_miningRig,
// fn_placeObject, fn_miningAssemble), so a remote call naming anyone else (deleting someone's rig "as" the house owner)
// is refused, and "reload" is boot-only -- a client-triggered reload respawned every rig composition on top of the old
// one (AUDIT.md A26). Server calls (init.sqf's direct call, or a server-origin remoteExec) pass.
private _caller = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2} && {(toLower _case) isEqualTo "reload" || {_a1 isNotEqualTo _caller}}) exitWith {
    ["-SEC-", _caller, format ["BLOCKED miningSRV %1: remote reload or actor is not the caller", _case]] call APS_fnc_logIt;};

#define MINE_COMPONENTS ["cryptoCPU","cryptoGPU","cryptoPSU","cryptoStorage","cryptoMotherboard","cryptoRam","cryptoCooler","cryptoCase"]
#define MINE_RATE_HR    1      // New Drachma mined per hour, per rig (owner 2026-07-23: 2 -> 1; passive rig income dwarfed the active economy -- 5 rigs was ~10/hr AFK. Coin also floats on the dynamic market now so mass supply self-corrects.)
#define MINE_CAP        96     // per-rig accrual cap (48h at 2/hr) -- rigs aren't a log-off-forever printer
#define MINE_MAX_RIGS   5      // max PLACED rigs per player, across all their houses

private _nowUnix = (missionNamespace getVariable ["AP_bootUnix", 0]) + serverTime;
// SERVER-ONLY STATE, localNamespace: as missionNamespace globals one client publicVariable replaced them on the server --
// forged records took over, collected or deleted any player's rig by id, and forged busy flags lifted the locks.
if (isNil {localNamespace getVariable "APS_cryptoRigs"}) then { localNamespace setVariable ["APS_cryptoRigs", createHashMap]; };   // rigId(str) -> [houseObj, ownerUID, [spawnedObjs], oid]
if (isNil {localNamespace getVariable "APS_rigBusy"}) then { localNamespace setVariable ["APS_rigBusy", createHashMap]; };   // rigId -> true while a place/collect/delete is mid-flight; serializes per-rig -> kills the double-collect TOCTOU
private _rigs = localNamespace getVariable "APS_cryptoRigs";   // live references: set/deleteAt write through
private _busy = localNamespace getVariable "APS_rigBusy";

// grant an item to an online player (refund path); durable so the client can't lose it
private _fnGive = {params ["_player", "_item", ["_n", 1]];
    if (isNull _player) exitWith {};
    [[true, _item, _n], "AP_fnc_handleInv", _player, false, false] spawn AP_fnc_MP;};

// count of rigs this UID currently owns (live map is authoritative -- every placed rig has a record)
private _fnRigCount = {params ["_uid"];
    private _n = 0;
    { if ((_y param [1, ""]) isEqualTo _uid) then { _n = _n + 1; }; } forEach _rigs;
    _n};

// spawn the composition at [pos,dir] server-side (global -> everyone sees), tagged for scroll/cleanup.
// Reads compositions\cryptorig.sqf: [[class, [ox,oy,oz], relDir], ...]; offsets rotate with _dir, upright.
private _spawnRig = {params ["_pos", "_dir", "_rigId", "_ownerUID", ["_homeUID", ""]];
    private _comp = localNamespace getVariable ["APS_cryptoRigComp", []];   // localNamespace: a published comp made the server createVehicle any class
    if (_comp isEqualTo []) then {_comp = call compile preprocessFileLineNumbers "compositions\cryptorig.sqf";
        localNamespace setVariable ["APS_cryptoRigComp", _comp];};
    // Invisible STATIC anchor, everything attached to it. Client-side PhysX settles/depenetrates the
    // thingX pieces on RENDERING machines (servers sank into the floor, desk floated ~0.1-0.2 on players'
    // screens while server/HC positions stayed mm-exact -- PLBPROBE3, 2026-07-22). A "house"-sim helipad
    // never simulates anywhere, and attachTo renders the exact model-space offset on every machine, so the
    // comp draws the Eden layout verbatim for everyone. attachTo also does the dir rotation for us.
    private _anchor = createVehicle ["Land_HelipadEmpty_F", _pos, [], 0, "CAN_COLLIDE"];
    _anchor setPosATL _pos;
    _anchor setDir _dir;
    _anchor setVectorUp [0,0,1];
    _anchor setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup sweep
    _anchor setVariable ["owner", "cryptorig", true];     // ownerless-reap spare
    private _objs = []; {_x params ["_cls", "_off", "_rel", ["_anims", []]];
        // spawn 5m up in clear air so creation-instant physics never contacts the floor, then pin
        private _o = createVehicle [_cls, [_pos select 0, _pos select 1, (_pos select 2) + 5], [], 0, "CAN_COLLIDE"];
        _o attachTo [_anchor, [_off select 0, _off select 1, _off param [2, 0]]];
        _o setDir _rel;   // attached: relative to the anchor's facing
        // Eden animation phases (e.g. "Server_Move_Source" = 1 -> server slid out of its case). Keep simulation
        // ON for animated pieces -- with sim OFF the model never re-renders the new phase (the source is set but
        // the animation stays visually at 0). Land_ props are static so sim-on costs no physics. animateSource
        // same-frame as createVehicle doesn't take (model not ready) -> apply after a short delay. (dev-verified)
        if (_anims isEqualTo []) then {_o enableSimulationGlobal false;} else {
            [_o, _anims] spawn { params ["_o", "_anims"]; uiSleep 0.5; { _o animateSource [_x select 0, _x select 1, true]; } forEach _anims; };
        };
        _o allowDamage false;
        _o setVariable ["AP_furniture", true, true];     // exempt from fn_cleanup sweep
        _o setVariable ["owner", "cryptorig", true];       // ownerless-reap spare
        _o setVariable ["AP_cryptoRig", true, true];      // scroll-action gate
        _o setVariable ["AP_rigId", _rigId, true];        // house_rigs.id -- the rig's identity
        _o setVariable ["AP_rigOwner", _ownerUID, true];
        // house owner at spawn time -- Move/Delete scroll gates key on THIS (server delete-gate = house
        // owner), so a hijack flipping AP_rigOwner can't lock the victim out of reclaiming their hardware.
        // Never stale: a sale deletes the rigs, and hijack doesn't change who owns the house.
        _o setVariable ["AP_rigHomeOwner", _homeUID, true];
        _objs pushBack _o;} forEach _comp;
    _objs pushBack _anchor;   // last: despawn deletes it with the pieces; invisible, never cursor-targeted
    _objs};

private _despawnRig = {params ["_rigId"];
    private _rec = _rigs getOrDefault [_rigId, []];
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach (_rec param [2, []]);
    _rigs deleteAt _rigId;};

// resolve the scrolled rig object -> its house_rigs id (string). "" if not a placed rig.
private _ridOf = {params ["_obj"];
    if (isNull _obj) exitWith { "" };
    format ["%1", _obj getVariable ["AP_rigId", ""]]};

switch (toLower _case) do {

    case "assemble": {private _player = _a1;
        if (isNull _player) exitWith {};
        // client already validated + consumed the 8 components; grant the rig (refund-safe).
        [[true, "cryptoRig", 1], "AP_fnc_handleInv", _player, false, false] spawn AP_fnc_MP;
        [["<t color='#f2c14e'>MINING RIG</t> assembled. Use it inside a house you own to place it.", "info"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        ["-MINING-", _player, name _player, "assembled a mining rig"] call APS_fnc_logIt;};

    case "place": {private _player = _a1; private _house = _a2; private _pos = _a3; private _dir = _a4;
        if (isNull _player || {isNull _house}) exitWith { [_player, "cryptoRig"] call _fnGive; };
        // audit TONc-0-2 / AUDIT.md A22: _a3's ELEMENTS were never typed, so a string element rode format into the
        // INSERT and SELECT below. The client always sends getPosATL; anything else is not a placement (no refund).
        if !(count _pos isEqualTo 3 && {_pos isEqualTypeAll 0}) exitWith {
            ["-SEC-", _caller, format ["BLOCKED miningSRV place: malformed position %1", _pos]] call APS_fnc_logIt;};
        private _uid = getPlayerUID _player;
        // server-authoritative gates: must own THIS house; max MINE_MAX_RIGS placed rigs per player
        // owner 2026-09-26 SECURITY (houses review, TONd-0-0 class): owner + oid from the houses ROW (APS_fnc_houseRights),
        // never the client-writable AP_homeOwner / AP_houseID object vars
        private _rights = [_house] call APS_fnc_houseRights;
        if ((_rights select 1) isEqualTo "" || {(_rights select 1) isNotEqualTo _uid}) exitWith {[_player, "cryptoRig"] call _fnGive;
            [["Only the house owner can place a rig here.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        private _oid = _rights select 0;
        if (_oid in ["", "-1"]) exitWith {[_player, "cryptoRig"] call _fnGive;
            [["The realtor has no record of this building -- can't register a rig.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        if (([_uid] call _fnRigCount) >= MINE_MAX_RIGS) exitWith {[_player, "cryptoRig"] call _fnGive;
            [[format ["Rig limit reached -- you already run %1 rigs. Pack one up first.", MINE_MAX_RIGS], "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        // persist the new rig row (BLOCKING so the id exists before we spawn), then fetch its id by its
        // unique pos string (extDB3 pools connections -> LAST_INSERT_ID() isn't guaranteed our session)
        private _rigStr = format ["%1:%2:%3:%4", _pos select 0, _pos select 1, _pos select 2, _dir];
        // toFixed 0: format %1 renders 8-digit stamps in scientific notation (8.47713e+07) -- that is what
        // "corrupted" the legacy houses.miner strings. toFixed keeps the SQL literal exact and plain.
        // PARAMETERISED: no value here is formatted into the SQL (_oid is the houses row APS_fnc_houseRights read above).
        ["INSERT INTO house_rigs (oid, owner, pos, since, last_collect) VALUES (%s,%s,%s,%s,%s)", 2, true, [_oid, _uid, _rigStr, _nowUnix toFixed 0, _nowUnix toFixed 0]] call DB_fnc_asyncQuery;
        // blocking asyncQuery returns ROWS-OF-ARRAYS: [[id]] -- unwrap row THEN cell (param [0] alone
        // grabs the row array and format renders it "[2]" -> WHERE id=[2] = SQL syntax error; live-bitten)
        private _idRows = ["SELECT id FROM house_rigs WHERE oid=%s AND pos=%s ORDER BY id DESC LIMIT 1", 2, true, [_oid, _rigStr]] call DB_fnc_asyncQuery;
        private _rigId = format ["%1", _idRows param [0, []] param [0, ""]];
        if (_rigId isEqualTo "" || {_rigId isEqualTo "-1"}) exitWith {[_player, "cryptoRig"] call _fnGive;
            [["The rig didn't register -- try placing again.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        private _objs = [_pos, _dir, _rigId, _uid, _uid] call _spawnRig;   // placer owns the house (gated above)
        _rigs set [_rigId, [_house, _uid, _objs, _oid]];
        [["<t color='#f2c14e'>MINING RIG</t> installed + humming. Scroll it to collect New Drachma. (Loud enough that a nosy cop might notice.)", "info"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        ["-MINING-", _player, name _player, format ["placed rig %1 in house %2 at %3 (%4/%5)", _rigId, _oid, _pos, [_uid] call _fnRigCount, MINE_MAX_RIGS]] call APS_fnc_logIt;
    };

    case "collect": {private _player = _a1;
        if (isNull _player) exitWith {};
        private _rid = [_a2] call _ridOf;
        if (_rid isEqualTo "") exitWith {};
        private _rec = _rigs getOrDefault [_rid, []];
        if (_rec isEqualTo []) exitWith {};
        private _uid = getPlayerUID _player;
        // ONLY a rig's current owner may collect from it. Keyholders get NO rig access (owner rule
        // 2026-07-18); a Cyberdeck hijacker is reassigned AP_rigOwner and collects what they stole.
        // Collect-all: one scroll sweeps EVERY rig this player owns in the same house (owner 2026-07-22).
        if !((_rec param [1, ""]) isEqualTo _uid) exitWith {
            [["Only the rig's owner can collect from it.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        private _oid = _rec param [3, ""];
        private _mine = [];   // rigIds: this player's rigs in this house
        { if ((_y param [1, ""]) isEqualTo _uid && {(_y param [3, ""]) isEqualTo _oid}) then { _mine pushBack _x; }; } forEach _rigs;
        private _total = 0; private _nRigs = 0; {private _rigId = _x;
            if !(_busy getOrDefault [_rigId, false]) then {_busy set [_rigId, true];
                private _rows = ["SELECT (last_collect)::text AS last_collect FROM house_rigs WHERE id=%s", 2, true, [_rigId]] call DB_fnc_asyncQuery;
                private _last = parseNumber (format ["%1", _rows param [0, []] param [0, "0"]]);
                private _coins = 0;
                if (_last > 0) then {_coins = floor ((((_nowUnix - _last) max 0) / 3600) * MINE_RATE_HR) min MINE_CAP;};
                if (_coins >= 1) then {
                    // BLOCKING update: the new last-collect stamp MUST commit before we release the lock, else a
                    // second collect fired in the same window re-reads the old stamp and mints the coins twice.
                    ["UPDATE house_rigs SET last_collect=%s WHERE id=%s", 2, true, [_nowUnix toFixed 0, _rigId]] call DB_fnc_asyncQuery;
                    // fail-CLOSED (live b0182 dupe): asyncQuery returns [] for write success AND write error, so a
                    // rejected UPDATE (the live varchar(48) overflow) froze the stamp while the grant below still
                    // fired -- every collect re-minted the full accrual. Prove the stamp actually moved; no proof,
                    // no coins. A withheld legit collect just retries next scroll (stamp unchanged).
                    private _chk = ["SELECT (last_collect)::text AS last_collect FROM house_rigs WHERE id=%s", 2, true, [_rigId]] call DB_fnc_asyncQuery;
                    if ((format ["%1", _chk param [0, []] param [0, ""]]) isEqualTo (_nowUnix toFixed 0)) then {_total = _total + _coins;
                        _nRigs = _nRigs + 1;} else {
                        diag_log format ["[LooneyBin][mining] collect stamp-verify FAILED rig %1 uid %2 -- coins withheld", _rigId, _uid];
                    };};
                _busy set [_rigId, false];};} forEach _mine;
        if (_total < 1) exitWith {
            [["The rigs are still warming up -- nothing to collect yet.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        // NEW DRACHMA: rigs now deposit straight to the wallet (1 mined coin = 1 ND). Server-trusted
        // credit -- the server computed _total, so no rate cap. No more coin item to carry/sell.
        [_player, format ["%1", _total], "mining"] call APS_fnc_ndCreditSrv;
        ["-MINING-", _player, name _player, format ["collected %1 ND from %2 rigs (house %3)", _total, _nRigs, _oid]] call APS_fnc_logIt;};

    case "delete": {private _player = _a1;
        if (isNull _player) exitWith {};
        private _rid = [_a2] call _ridOf;
        if (_rid isEqualTo "") exitWith {};
        private _rec = _rigs getOrDefault [_rid, []];
        if (_rec isEqualTo []) exitWith {};
        // owner 2026-09-26 SECURITY (houses review, TONd-0-0 class): the house owner is the houses row the rig's house_rigs
        // row points at -- never the house object's client-writable AP_homeOwner (a forged tag deleted a victim's rig and
        // paid its pending New Drachma to the forger), nor the in-memory rig record (a hijack reassigns its owner)
        private _hOwn = format ["%1", (["SELECT COALESCE(h.owners,'') AS owners FROM house_rigs r JOIN houses h ON h.oid = r.oid WHERE r.id = %s", 2, false, [parseNumber _rid]] call DB_fnc_asyncQuery) param [0, ""]];
        if (_hOwn in ["", "0", "NULL"] || {_hOwn isNotEqualTo getPlayerUID _player}) exitWith {
            [["Only the house owner can remove the rig.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        if (_busy getOrDefault [_rid, false]) exitWith {
            [["The rig is busy -- try again in a moment.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;};
        _busy set [_rid, true];
        // read the pending accrual, then kill the row BEFORE any payout. Fail-closed like collect: a
        // silently-failed DELETE would leave the row to respawn on reboot (old stamp intact) -- the pending
        // coins re-mint AND the refunded cryptoRig item dupes. COUNT(*) must come back a literal "0";
        // an error/empty result aborts too (never assume gone on no evidence).
        private _mRows = ["SELECT (last_collect)::text AS last_collect FROM house_rigs WHERE id=%s", 2, true, [_rid]] call DB_fnc_asyncQuery;
        private _last = parseNumber (format ["%1", _mRows param [0, []] param [0, "0"]]);
        ["DELETE FROM house_rigs WHERE id=%s", 2, true, [_rid]] call DB_fnc_asyncQuery;
        private _chk = ["SELECT (COUNT(*))::text AS n FROM house_rigs WHERE id=%s", 2, true, [_rid]] call DB_fnc_asyncQuery;
        if ((format ["%1", _chk param [0, []] param [0, ""]]) isNotEqualTo "0") exitWith {_busy set [_rid, false];
            diag_log format ["[LooneyBin][mining] delete row-verify FAILED rig %1 uid %2 -- aborted, nothing granted", _rid, getPlayerUID _player];
            [["The rig's firmware refused the shutdown -- try again in a moment.", "basic"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        };
        // row is provably gone -> safe to pay out and refund
        if (_last > 0) then {private _coins = floor ((((_nowUnix - _last) max 0) / 3600) * MINE_RATE_HR) min MINE_CAP;
            if (_coins >= 1) then {
                // NEW DRACHMA: deposit to wallet (server-trusted, server-computed amount).
                [_player, format ["%1", _coins], "mining"] call APS_fnc_ndCreditSrv;};};
        [_rid] call _despawnRig;
        _busy deleteAt _rid;
        [_player, "cryptoRig"] call _fnGive;   // refund the assembled rig
        [["<t color='#f2c14e'>MINING RIG</t> packed up -- the rig is back in your inventory.", "info"], "AP_fnc_handleMessage", _player, false, false] spawn AP_fnc_MP;
        ["-MINING-", _player, name _player, format ["removed rig %1 (refunded)", _rid]] call APS_fnc_logIt;};

    case "reload": {   // boot-only (init.sqf): a client-sent one is refused by the CALLER BINDING block at the top
        // pass _spawnRig INTO the spawn -- a spawned code block does NOT inherit the function-body privates, so
        // the bare `[] spawn` left _spawnRig undefined and every saved rig failed to respawn on boot (rigs vanished).
        [_spawnRig, _rigs] spawn {params ["_spawnRig", "_rigs"];
            // QUOTE(): unquoted, `call compile` reads varchars as NUMBERS -> large oids render scientific
            // (1.40682e+09) -> lookups silently break after any restart. Quoting keeps them strings.
            private _rows = ["SELECT hr.id, hr.oid, hr.owner, hr.pos, COALESCE(h.worldspace,'') AS worldspace, COALESCE(h.owners,'') AS owners FROM house_rigs hr LEFT JOIN houses h ON h.oid = hr.oid", 2, true] call DB_fnc_asyncQuery;
            if (!(_rows isEqualType [])) exitWith {};
            private _n = 0; {_x params [["_id", ""], ["_oid", ""], ["_owner", ""], ["_rigStr", ""], ["_ws", ""], ["_homeOwner", ""]];
                private _p = (format ["%1", _rigStr]) splitString ":";
                if (count _p >= 4) then {private _pos = [parseNumber (_p select 0), parseNumber (_p select 1), parseNumber (_p select 2)];
                    private _dir = parseNumber (_p select 3);
                    // resolve the owning house object by its worldspace (like fn_greenhouseSRV / the old reload)
                    private _hpos = parseSimpleArray _ws;
                    private _house = objNull;
                    if (_hpos isEqualType [] && {count _hpos >= 2}) then {
                        private _cands = (nearestObjects [_hpos, ["House_F", "Land_i_Shed_Ind_F"], 15]) select { !isObjectHidden _x };
                        _house = _cands param [0, objNull];};
                    private _idS = format ["%1", _id];
                    private _objs = [_pos, _dir, _idS, format ["%1", _owner], format ["%1", _homeOwner]] call _spawnRig;
                    _rigs set [_idS, [_house, format ["%1", _owner], _objs, format ["%1", _oid]]];
                    _n = _n + 1;};} forEach _rows;
            diag_log format ["[LooneyBin][mining] spawned %1 placed rig(s) from DB", _n];};};};
