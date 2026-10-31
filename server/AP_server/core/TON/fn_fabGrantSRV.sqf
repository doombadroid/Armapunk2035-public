/*
    APS_fnc_fabGrantSRV  (Armapunk -- the single funnel for every schematic a player ever gets)

        ["roll",  [player, "<source>", "<rarityOrEmpty>"]]  -- a drop; the SERVER rolls
        ["give",  [player, "<recipeKey>", "<reason>"]]      -- directed grant (quest, heist, admin)
        ["buy",   [player, "<recipeKey>"]]                  -- purchase, in New Drachma
        ["shard", [player, "<shardItemKey>"]]               -- decrypt a shard: a schematic of its rarity, then the shard is removed
        ["burn",  [player, "<recipeKey>"]]                  -- forget a schematic, get a tradeable shard

    NOTHING ELSE GRANTS A SCHEMATIC. One funnel means one place that dedupes, one place that
    persists and one place that logs -- and, more to the point, one place to audit. A schematic is
    a PERMANENT unlock, so a faucet is a mint: the forged-blueprint push is the single
    highest-leverage exploit in the feature this was ported from, where a client could hand the
    server its own list of 709 and have it stored.

    SO NO FAUCET ROLLS CLIENT-SIDE. A client reports that it finished a gather; the roll happens
    here. Same shape as APS_fnc_qhLootSRV.

    MONEY. The buy path charges New Drachma and nothing else. ND is the only server-owned wallet in
    this codebase -- cash and bank are client variables that the client persists itself -- so it is
    the only currency in which a permanent unlock cannot simply be forged. Three properties of
    APS_fnc_ndDebitSrv shape the code below:
      * it is deliberately ABSENT from CfgRE.hpp, which is its entire security model, so it can
        only ever be reached from server code like this;
      * the debit is atomic in SQL (the UPDATE carries its own `AND new_drachma >= amt`), so there
        is no read-then-write window to lose a race in;
      * it is FAIL-CLOSED -- an empty proof read is reported as failure. The schematic is therefore
        written only on a true _ok, never optimistically.
    It also uses a waitUntil lock, so the buy path must run scheduled; every entry here is spawned.
*/
params [["_case", "", [""]], ["_data", [], [[]]]];
if (!isServer) exitWith {};

// WHO A CLIENT CALL ACTS ON, AND WHICH VERBS IT GETS (audit 2026-09-26, mints/TONb-0-0). This is whitelisted
// (CfgRE allowedTargets 2) and used to trust its payload whole: any client could "give" itself any schematic,
// roll the "heist"/"quest" pools or force a rarity every 3 s from anywhere, and "burn"/"buy" with SOMEBODY
// ELSE's unit -- stripping their schematics or spending their New Drachma. A client-originated call now
//   * acts on the CALLER's own unit (resolved from remoteExecutedOwner), whatever unit the payload names, and
//   * gets the four client verbs only: "roll" (source "gather"/"mine", no rarity), "shard", "burn", "buy".
// "give" and every other roll source are server-only. fn_aqProfile and APS_fnc_qhLootSRV reach this with
// `spawn`, and remoteExecutedOwner does not survive a spawn (it reads 0 -- fn_dutySRV.sqf's respawn note), so
// their calls arrive as owner 0 and are trusted. That trust is only as good as those callers' own gates:
// qhLootSRV is itself client-reachable, so it binds its player to the caller and requires a fed breach / cartel
// capture the server can see before it ever reaches the "heist" roll here.
// "shard" is CONSERVED (see that case): a decrypt must take one burned shard of its tier off a DB counter that
// only "burn" adds to, so no client -- whatever shards it claims to hold -- can decrypt more than were burned.
private _src = remoteExecutedOwner;
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
private _blocked = _src isNotEqualTo 0 && {isNull _caller
    || {!(_case in ["roll", "shard", "burn", "buy"])}
    || {_case isEqualTo "roll" && {!((_data param [1, ""]) in ["gather", "mine"]) || {(_data param [2, ""]) isNotEqualTo ""}}}};
if (_blocked) exitWith {
    ["-SEC-", _caller, format ["BLOCKED fabGrantSRV '%1' %2", _case, (str _data) select [0, 160]]] call APS_fnc_logIt;
};
if (_src isNotEqualTo 0) then { _data set [0, _caller]; };

private _say = {
    params ["_p", "_msg"];
    [[_msg, "basic"], "AP_fnc_handleMessage", _p, false, false] spawn AP_fnc_MP;
};

// What each uid KNOWS -- the authority copy, uid -> [recipeKey...], in localNamespace (vars.sqf), filled at login by
// DB_fnc_queryRequest. Audit 2026-09-26 (mints2): it used to be the unit's unpublished AP_fabSchemSrv, but a client's
// `player setVariable ["AP_fabSchemSrv", <every key>, true]` overwrites that on the server too, and _learn / burn then
// wrote the forged list to players.fab_schematics -- every schematic, permanently. localNamespace is out of reach.
// AP_fabSchem on the unit stays the published display copy.
private _schemMap = localNamespace getVariable ["AP_fabSchemSrv", createHashMap];

// The shard CONSERVATION counters (see "shard") live in their own table, one row per tier (0 common, 1 rare,
// 2 epic). Not in `config`: DB_fnc_queryConfig reads that table POSITIONALLY into AP_configuration (8 = lottery
// jackpot, 10 = the house-rebuild flag), so extra rows there shift those slots on any database holding fewer than
// eleven. Created on first use, blocking (mode 2), the fn_fabSRV _ensure pattern. Seed: deploy/fab_shard_pool.sql.
private _ensurePool = {
    if (isNil {localNamespace getVariable "AP_fabShardPoolReady"}) then {
        ["CREATE TABLE IF NOT EXISTS fab_shard_pool (tier smallint NOT NULL, burned integer NOT NULL DEFAULT 0, CONSTRAINT fab_shard_pool_pkey PRIMARY KEY (tier))", 2] call DB_fnc_asyncQuery;
        localNamespace setVariable ["AP_fabShardPoolReady", true];
    };
};

// Write one schematic onto a player, dedupe first. Returns true if it was actually new.
private _learn = {
    params ["_p", "_key", "_reason"];
    private _uid = getPlayerUID _p;
    if !(_uid regexMatch "\d{17}") exitWith { false };
    if !(["hasRecipe", _key] call AP_fnc_fabCfg) exitWith { false };

    // The AUTHORITY copy, not the published one (see _schemMap). Not loaded this session -> refuse:
    // writing a list built from nothing would replace every schematic the DB holds for this uid.
    if !(_uid in _schemMap) exitWith { false };
    private _known = _schemMap get _uid;
    if (_key in _known) exitWith { false };

    _known pushBack _key;
    _p setVariable ["AP_fabSchem", +_known, true];
    [format ["UPDATE players SET fab_schematics='%1' WHERE playerid='%2'",
             [_known] call DB_fnc_mresArray, _uid]] call DB_fnc_asyncQuery;

    private _rarity = (["get", _key] call AP_fnc_fabSchemCfg) param [2, "common"];
    private _colour = switch (_rarity) do {
        case "epic": {"#b082e8"}; case "rare": {"#56d6e2"}; default {"#dceaf6"};
    };
    [[format ["<t size='1.1' color='%1'>SCHEMATIC LEARNED</t><br/>%2 <t size='0.8'>(%3)</t>",
              _colour, _key, _rarity], "basic"], "AP_fnc_handleMessage", _p, false, false] spawn AP_fnc_MP;
    ["-FAB-", _p, name _p, format ["learned schematic %1 (%2) via %3", _key, _rarity, _reason]] call APS_fnc_logIt;
    true
};

// The two-step roll the original used, kept because the shape is right: pick uniformly from the
// pool, THEN roll that entry's own 1-in-N. Anything already known is dropped from the pool first,
// so a player deep into the tree is not repeatedly told they found a duplicate.
private _roll = {
    params ["_p", "_pool"];
    private _known = _schemMap getOrDefault [getPlayerUID _p, []];
    private _avail = _pool select { !(_x in _known) };
    if (_avail isEqualTo []) exitWith { "" };
    private _pick = selectRandom _avail;
    private _chance = (["get", _pick] call AP_fnc_fabSchemCfg) param [0, 9999];
    if (_chance < 1) then { _chance = 1 };
    if ((floor random _chance) isEqualTo 0) then { _pick } else { "" }
};

switch (_case) do {

    // ------------------------------------------------------------------------ a drop
    case "roll": {
        _data params [["_p", objNull, [objNull]], ["_source", "", [""]], ["_rarity", "", [""]]];
        if (isNull _p || {_source isEqualTo ""}) exitWith {};

        // Per-UID throttle. A client controls how often it reports finishing a gather, so without
        // this the roll rate is whatever a script wants it to be. Same guard as qhLootSRV.
        // localNamespace (2026-09-26): a missionNamespace global is one client publicVariable from being reset.
        private _cd = localNamespace getVariable "AP_fabRollCd";
        if (isNil "_cd") then { _cd = createHashMap; localNamespace setVariable ["AP_fabRollCd", _cd]; };
        private _uid = getPlayerUID _p;
        if ((_cd getOrDefault [_uid, 0]) > diag_tickTime) exitWith {};
        _cd set [_uid, diag_tickTime + 3];

        private _pool = ["pool", _source] call AP_fnc_fabSchemCfg;
        if (_rarity isNotEqualTo "") then {
            private _byR = ["rarity", _rarity] call AP_fnc_fabSchemCfg;
            _pool = _pool select { _x in _byR };
        };
        if (_pool isEqualTo []) exitWith {};
        private _hit = [_p, _pool] call _roll;
        if (_hit isNotEqualTo "") then { [_p, _hit, _source] call _learn; };
    };

    // ------------------------------------------------------------------------ directed grant
    case "give": {
        _data params [["_p", objNull, [objNull]], ["_key", "", [""]], ["_reason", "grant", [""]]];
        if (isNull _p || {_key isEqualTo ""}) exitWith {};
        if !([_p, _key, _reason] call _learn) then { [_p, "You already know that schematic."] call _say };
    };

    // ------------------------------------------------------------------------ consume a shard
    case "shard": {
        _data params [["_p", objNull, [objNull]], ["_item", "", [""]]];
        if (isNull _p || {_item isEqualTo ""}) exitWith {};
        private _rarity = ["shard", _item] call AP_fnc_fabSchemCfg;
        if (_rarity isEqualTo "") exitWith {};
        private _tier = ["shard", "shard_rare", "shard_epic"] find _item;
        if (_tier < 0) exitWith {};
        // CONSERVATION (audit 2026-09-26, mints/TONb-0-0). Shards are client-held items the server cannot see,
        // so this used to be a guaranteed schematic per call for anyone who SAID they had one. "burn" is the only
        // source of shards in the tree, and it counts every shard it makes into fab_shard_pool's row for its tier
        // (common, rare, epic). A decrypt must take one off that counter -- an atomic guarded UPDATE, so two decrypts
        // racing for the last one cannot both win -- so decrypts can never outnumber burns, however shards
        // were traded, dropped or forged on the way.
        // The client no longer consumes the shard up front; it leaves the inventory only once the decrypt has
        // succeeded (below). A refusal therefore has nothing to refund -- and a refund is exactly what a client
        // could farm, since it pays back a shard the server never saw. One decrypt per uid per 5 s stops a
        // double-click spending one held shard twice before the removal lands.
        // And one SUCCESSFUL decrypt per tier per uid per hour: a client can claim shards it never held, so without
        // it one script could take every newly burned unit of a tier the moment it lands, and the honest holders of
        // that tier's shards would never decrypt. Stamped on success only; a refusal costs nothing.
        private _dcd = localNamespace getVariable "AP_fabRollCd";
        if (isNil "_dcd") then { _dcd = createHashMap; localNamespace setVariable ["AP_fabRollCd", _dcd]; };
        private _dk = (getPlayerUID _p) + "|shard";
        if ((_dcd getOrDefault [_dk, 0]) > diag_tickTime) exitWith {};
        _dcd set [_dk, diag_tickTime + 5];
        private _hk = _dk + str _tier;
        if ((_dcd getOrDefault [_hk, 0]) > diag_tickTime) exitWith {
            [_p, format ["The decryptor needs time -- one %1 shard per hour. The shard is untouched.", _rarity]] call _say;
        };

        private _known = _schemMap getOrDefault [getPlayerUID _p, []];
        private _pool = (["rarity", _rarity] call AP_fnc_fabSchemCfg) select { !(_x in _known) };
        if (_pool isEqualTo []) exitWith {
            [_p, format ["You already know every %1 schematic -- the shard is untouched.", _rarity]] call _say;
        };
        call _ensurePool;
        private _take = [format ["UPDATE fab_shard_pool SET burned = burned - 1 WHERE tier = %1 AND burned > 0", _tier], []] call DB_fnc_asyncExec;
        if !((_take param [0, 0]) isEqualTo 1 && {(_take param [1, 0]) isEqualTo 1}) exitWith {
            ["-FAB-", _p, name _p, format ["shard decrypt REFUSED: no burned %1 left in circulation (%2)", _item, _take]] call APS_fnc_logIt;
            [_p, format ["The %1 will not decrypt -- no %2 schematic is free to decrypt right now. The shard is untouched.",
                         ["getName", _item] call AP_fnc_virtItemCfg, _rarity]] call _say;
        };
        // A shard is a GUARANTEED unlock of its tier, not another 1-in-N roll. It is already the
        // rare thing; making the player win twice with one is how a reward stops reading as one.
        if !([_p, selectRandom _pool, "shard:" + _item] call _learn) exitWith {
            [format ["UPDATE fab_shard_pool SET burned = burned + 1 WHERE tier = %1", _tier], []] call DB_fnc_asyncExec;
        };
        _dcd set [_hk, diag_tickTime + 3600];
        [[false, _item, 1], "AP_fnc_handleInv", _p, false, false] spawn AP_fnc_MP;
    };

    // ------------------------------------------------------------------------ burn to trade
    // The other half of "shards + burn-to-trade": turn a schematic you KNOW back into a carryable,
    // Exchange-listable shard of its rarity. This is what makes schematics tradeable at all --
    // learned schematics are account state and account state cannot be listed on a marketplace,
    // but an item can.
    //
    // The shard rolls a RANDOM schematic of that tier when the buyer uses it, so this is not a
    // targeted transfer of the specific recipe. It cannot be: virtual items in this codebase are
    // bare counters (AP_inv_<name> mission variables) with no per-instance storage, so an item
    // physically cannot carry which recipe it encodes. Losing the specific identity is the price of
    // the schematic being tradeable at all, and the tier is preserved, which is the part that
    // carries the value.
    //
    // ORDER MATTERS: forget first, then grant. The reverse would let a disconnect between the two
    // leave the player holding both the schematic and a shard of it -- which is a mint, and the
    // only direction of failure that is not recoverable.
    case "burn": {
        _data params [["_p", objNull, [objNull]], ["_key", "", [""]]];
        if (isNull _p || {_key isEqualTo ""}) exitWith {};
        private _uid = getPlayerUID _p;
        if !(_uid regexMatch "\d{17}") exitWith {};

        private _row = ["get", _key] call AP_fnc_fabSchemCfg;
        if (_row isEqualTo []) exitWith { [_p, "That recipe has no schematic to burn."] call _say };
        private _rarity = _row param [2, "common"];
        private _item = switch (_rarity) do {
            case "epic": {"shard_epic"}; case "rare": {"shard_rare"}; default {"shard"};
        };

        // Check and drop in ONE unscheduled step (mints2 round 2). This runs scheduled, so two burns of one key could
        // otherwise both pass the check before either dropped it, both prove the forget below, and pay two shards.
        private _known = [];
        private _left = [];
        isNil {
            _known = _schemMap getOrDefault [_uid, []];
            if (_key in _known) then { _left = _known - [_key]; _schemMap set [_uid, _left]; };
        };
        if !(_key in _known) exitWith { [_p, "You have not learned that schematic."] call _say };
        _p setVariable ["AP_fabSchem", +_left, true];
        [format ["UPDATE players SET fab_schematics='%1' WHERE playerid='%2'",
                 [_left] call DB_fnc_mresArray, _uid]] call DB_fnc_asyncQuery;
        // Prove the forget committed before handing over the shard, for the same reason collect
        // proves its clear: asyncQuery reports a rejected write exactly like a successful one, and
        // an unproved forget plus a granted shard is a duplicated schematic.
        private _chk = [format ["SELECT COALESCE(fab_schematics,'') AS fab_schematics FROM players WHERE playerid='%1'", _uid], 2, true] call DB_fnc_asyncQuery;
        private _stored = format ["%1", (_chk param [0, []]) param [0, ""]];
        if (_stored find _key > -1) exitWith {
            // Put K back into the CURRENT list, not the pre-burn _known: a learn that landed meanwhile stays.
            private _cur = _schemMap get _uid;
            _cur pushBackUnique _key;
            _p setVariable ["AP_fabSchem", +_cur, true];
            diag_log format ["[Armapunk][fab] burn WITHHELD: %1 still stored for %2", _key, _uid];
            [_p, "The schematic could not be released. Nothing was lost."] call _say;
        };

        // CONSERVATION (see "shard"): count this shard into its tier's counter, so exactly one decrypt can follow it.
        call _ensurePool;
        private _put = [format ["INSERT INTO fab_shard_pool (tier, burned) VALUES (%1, 1) ON CONFLICT (tier) DO UPDATE SET burned = fab_shard_pool.burned + 1",
                                ["shard", "shard_rare", "shard_epic"] find _item], []] call DB_fnc_asyncExec;
        if ((_put param [0, 0]) isNotEqualTo 1) then {
            diag_log format ["[Armapunk][fab] burn: %1 counter NOT incremented for %2 (%3) -- one %1 will not decrypt", _item, _uid, _put];
        };
        [[true, _item, 1], "AP_fnc_handleInv", _p, false, false] spawn AP_fnc_MP;
        [_p, format ["Burned %1 to a %2 -- tradeable, and it rolls a random %3 schematic when used.",
                     _key, ["getName", _item] call AP_fnc_virtItemCfg, _rarity]] call _say;
        ["-FAB-", _p, name _p, format ["burned schematic %1 (%2) -> %3", _key, _rarity, _item]] call APS_fnc_logIt;
    };

    // ------------------------------------------------------------------------ purchase, in ND
    case "buy": {
        _data params [["_p", objNull, [objNull]], ["_key", "", [""]]];
        if (isNull _p || {_key isEqualTo ""}) exitWith {};
        private _uid = getPlayerUID _p;
        if !(_uid regexMatch "\d{17}") exitWith {};

        private _row = ["get", _key] call AP_fnc_fabSchemCfg;
        if (_row isEqualTo []) exitWith { [_p, "That schematic is not for sale."] call _say };
        if !("shop" in (_row select 1)) exitWith { [_p, "That schematic is not sold here."] call _say };
        if (_key in (_schemMap getOrDefault [_uid, []])) exitWith {
            [_p, "You already know that schematic."] call _say;
        };

        // Price is DERIVED: the recursive backbone count through the whole recipe tree, times a
        // config rate. Nothing is authored per schematic, so changing a recipe reprices its
        // schematic automatically and the two can never drift.
        private _fee = [_key] call AP_fnc_fabFee;
        private _amt = _fee param [1, ""];
        if (_amt isEqualTo "") exitWith { [_p, "That schematic has no price."] call _say };

        // Charge FIRST and only write on a true _ok. ndDebitSrv is atomic and fail-closed, so a
        // false here means the money definitely did not move.
        private _res = [_uid, _amt, "fab-schematic"] call APS_fnc_ndDebitSrv;
        if !(_res param [0, false]) exitWith {
            [_p, format ["Not enough New Drachma -- that schematic costs %1 ND.", _amt]] call _say;
        };
        if !([_p, _key, "shop"] call _learn) then {
            // Cannot happen (duplicate was checked above) but if it ever does, the player has paid
            // for nothing. Refund rather than pocket it.
            // NOTE the signature difference: ndDebitSrv takes a UID STRING (it must be able to
            // charge someone who is offline), ndCreditSrv takes the OBJECT. Passing the uid here
            // would silently credit nobody.
            [_p, _amt, "fab-schematic-refund"] call APS_fnc_ndCreditSrv;
            [_p, "Purchase reversed."] call _say;
        };
        ["-FAB-", _p, name _p, format ["bought schematic %1 for %2 ND (balance %3)",
                                       _key, _amt, _res param [1, "?"]]] call APS_fnc_logIt;
    };
};
