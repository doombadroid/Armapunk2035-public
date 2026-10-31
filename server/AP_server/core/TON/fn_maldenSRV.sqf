/*
    APS_fnc_maldenSRV  (LooneyBin, owner 2026-07-11)
    MALDEN MAKEOVER -- owner-toggleable Malden look for eligible houses. The Malden "_b_" houses are
    separate baked MODELS (recon: no hiddenSelectionsTextures in the whole house tree), so this is the
    replace_sheds technique generalized: hide + sim-off + BANISH the terrain original to the ocean corner
    (a hidden original left on the spot still answers the position-keyed house lookups -- the Jeff-owned-
    a-derelict lesson), createVehicle the Malden variant on the exact transform, move the identity vars
    over, then re-run APS_fnc_tagHousesSRV (idempotent) to re-affirm/broadcast everything from the DB.

    Persistence: houses.malden TINYINT (ensured here, mode 2 -- the storage_vault CREATE race lesson).
    Terrain originals are pristine again every restart, so the boot pass just re-swaps every malden=1 row.
    Sold/transferred houses revert (hooks in fn_srvSellHouse / fn_transferHouse).

    Modes:
        ["boot"]                       initServer (+9s): swap every malden=1 row
        ["toggle", _player, _house]    house-menu toggle (CfgRE targets=2; owner-verified server-side)
        ["revert", _house, _oid]       server-internal: sale/transfer -- restore the original look (token-gated, see below)
*/
#define MALDEN_BANISH [2, 2, -80]
// EXPLOSIVES-ONLY destructibility (owner decision 2026-07-11): dynamically spawned buildings are outside the
// engine's projectile-damage pipeline entirely (probe: point-blank 155mm = 0 damage, HandleDamage never fires
// on the building). Parity trick: two HIDDEN sensor barrels in the attic void. Bullets stop at the shell's
// collision and never reach them (gunfire stays no-op = spec); explosive BLAST penetrates walls and damages
// the sensors. Points accumulate per detonation (ammo `hit` >= MALDEN_MIN_HIT filters small frags, matching
// how terrain houses shrug grenades); at MALDEN_DESTROY_PTS the ORIGINAL building is restored and setDamage-1'd
// -- a REAL terrain ruin, feeding the existing fn_civRepairBuilding flow. ~1 satchel or 2-3 HE rockets.
#define MALDEN_MIN_HIT      60
#define MALDEN_DESTROY_PTS  400
// HEAVY-CALIBER parity (owner retune 2026-07-11: "make it 100 50 cal rounds"): bullets are shooter-local so
// the client reports hits (AP_fnc_maldenBullets) and the server scores them here. pts = sumHit * 0.15 ->
// .50 ball (hit 27) = ~4 pts/round = ~100 rounds to MALDEN_DESTROY_PTS; .338 = ~140; rifle calibers never
// report (client gate hit>=15). The client is a sensor, NOT an authority: range + rate + size caps below
// keep a spoofed reporter from insta-deleting houses (closed-beta stance; re-check at public launch).
#define MALDEN_BLT_SCALE    0.15
#define MALDEN_BLT_MAXSUM   900
#define MALDEN_BLT_MAXN     35
#define MALDEN_BLT_RANGE    350
// _a3 is untyped on purpose: number for "bullets" (round count), string for "apply" (color key)
params [["_mode", "", [""]], ["_a1", objNull], ["_a2", objNull], ["_a3", 0], ["_a4", 0, [0]]];
if (!isServer) exitWith {};

// one-time column ensure -- synchronous (mode 2) so the boot SELECT below can't race it
if (isNil "AP_maldenColReady") then {
    ["ALTER TABLE houses ADD COLUMN IF NOT EXISTS malden smallint NOT NULL DEFAULT 0", 2] call DB_fnc_asyncQuery;
    ["ALTER TABLE houses ADD COLUMN IF NOT EXISTS malden_skin varchar(16) NOT NULL DEFAULT ''", 2] call DB_fnc_asyncQuery;
    AP_maldenColReady = true;};
// oid -> [orig, posASL, vd, vu, shell, [sensors], dmgPts, dead]. owner 2026-09-26 SECURITY (houses review): localNamespace,
// which the network cannot write -- bullets / blasts / fire resolve WHICH makeover was hit from this registry, and a
// missionNamespace global is one client publicVariable away from a forged one.
if (isNil {localNamespace getVariable "APS_maldenSwaps"}) then { localNamespace setVariable ["APS_maldenSwaps", createHashMap]; };

// vars every house system reads off the object -- moved onto the shell at swap so nothing breaks between
// the swap and the tag pass that re-affirms them from the DB. GLOBAL ones broadcast; inv caches stay LOCAL.
private _VARS_GLOBAL = ["AP_homeOwner", "AP_houseID", "AP_buildID", "houseId", "AP_buildingLocked", "AP_vcap",
    "AP_phys_cap", "AP_keycap", "AP_house_keys", "AP_houseName", "AP_house_tax", "AP_house_gang",
    "AP_barrel_unaged", "AP_greenhouse_unaged", "AP_leadcontainer_unaged", "AP_invGen", "AP_house_price","AP_restricted_house"];
private _VARS_LOCAL = ["AP_vinv", "AP_pinv", "AP_invHydrated"];

// ── swap: base object -> Malden shell in the requested color. Returns the shell (objNull on failure).
//    Blast sensors + heavy-caliber scoring key off the registry, so EVERY color gets the same
//    damage model automatically. ─────────────────────────────────────────────────────────────────
private _fnSwap = {params ["_orig", "_oid", ["_color", "whiteblue", [""]]];
    private _cls = typeOf _orig;
    private _variant = ["variant", _cls, _color] call AP_fnc_maldenMap;
    if (_variant isEqualTo "") exitWith { objNull };
    private _pos = getPosASL _orig;
    private _vd  = vectorDir _orig;
    private _vu  = vectorUp  _orig;
    // clear + banish the original (replace_sheds idiom: hide is not enough, position-keyed lookups
    // still find it). KNOWN ENGINE LIMIT (2026-07-11, "one house works the other doesn't"): BIG terrain
    // houses silently REFUSE setPosASL (the u_sheds moved fine) -- the hidden original then STAYS 0.2m
    // from the shell, so every resolver in the chain (tagHousesSRV / CLinitHouses / vault) filters
    // isObjectHidden instead of relying on the banish. The attempt stays for the types that do move.
    _orig hideObjectGlobal true;
    _orig enableSimulationGlobal false;
    _orig setPosASL MALDEN_BANISH;
    if (((getPosASL _orig) select 2) > -50) then {
        diag_log format ["[LooneyBin][malden] banish refused by %1 (oid %2) -- staying hidden in place (resolvers filter hidden)", _cls, _oid];
    };
    private _shell = createVehicle [_variant, ASLToATL _pos, [], 0, "CAN_COLLIDE"];
    _shell setPosASL _pos;
    _shell setVectorDirAndUp [_vd, _vu];
    _shell setVariable ["owner", "AP_customBuilding", true];   // fn_cleanup ownerless-reap exemption
    _shell setVariable ["AP_malden", true, true];
    // carry the identity over NOW (the tag pass re-affirms from the DB moments later)
    { private _v = _orig getVariable _x; if (!isNil "_v") then { _shell setVariable [_x, _v, true]; }; } forEach _VARS_GLOBAL;
    { private _v = _orig getVariable _x; if (!isNil "_v") then { _shell setVariable [_x, _v]; }; }       forEach _VARS_LOCAL;
    // door locks are per-door object vars -- re-apply so a locked house stays locked through the swap
    for "_i" from 1 to 8 do {private _d = _orig getVariable [format ["bis_disabled_Door_%1", _i], -1];
        if (_d isEqualType 0 && {_d > -1}) then { _shell setVariable [format ["bis_disabled_Door_%1", _i], _d, true]; };};
    // explosive-damage sensors: 2 hidden barrels along the building's long axis in the attic void (out of
    // player/bullet paths). HandleDamage returns 0 = pure sensor (never actually breaks); the "" structural
    // selection fires once per detonation so points don't multiply across hitpoint selections.
    private _proxies = [];
    private _bb = boundingBoxReal _shell;
    private _zTop = ((_bb select 1) select 2) - 1.2; {private _px = createVehicle ["Land_MetalBarrel_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _px setPosASL (AGLToASL (_shell modelToWorld [0, _x, _zTop max 2.5]));
        _px hideObjectGlobal true;
        _px setVariable ["owner", "AP_customBuilding", true];   // cleanup-reap exemption
        _px addEventHandler ["HandleDamage", {params ["_u", "_sel", "_dmg", "", "_ammo"];
            if (_sel isEqualTo "" && {_ammo isNotEqualTo ""}) then {private _hit = getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit");
                // owner 2026-09-26 SECURITY (houses review): the oid is the registry entry owning THIS sensor, and the tally
                // lives in that entry -- never object vars (a client's public setVariable overwrites a server-local one)
                if (_hit >= MALDEN_MIN_HIT) then {private _sw = localNamespace getVariable ["APS_maldenSwaps", createHashMap];
                    private _oid = ((keys _sw) select { _u in ((_sw get _x) param [5, []]) }) param [0, ""];
                    private _e = _sw getOrDefault [_oid, []];
                    private _sh = _e param [4, objNull];
                    if (!isNull _sh) then {private _pts = (_e param [6, 0]) + (_hit min 600);
                        _e set [6, _pts];
                        diag_log format ["[LooneyBin][malden] blast on oid %1: +%2 pts (%3) = %4/%5", _oid, _hit min 600, _ammo, _pts, MALDEN_DESTROY_PTS];
                        if (_pts >= MALDEN_DESTROY_PTS && {!(_e param [7, false])}) then {
                            _e set [7, true];
                            [_oid] spawn (localNamespace getVariable "APS_maldenDestroy");};};};};
            0   // sensor takes no real damage
        }];
        _proxies pushBack _px;} forEach [-3, 3];
    (localNamespace getVariable "APS_maldenSwaps") set [format ["%1", _oid], [_orig, _pos, _vd, _vu, _shell, _proxies, 0, false]];
    // clients built their house registries at login (AP_vehicles = the fn_lockHouse ownership gate) --
    // point them at the new object or the owner can't lock/unlock doors until relog.
    [_orig, _shell] remoteExec ["AP_fnc_maldenSync", 0];
    _shell};

// blown up: restore the ORIGINAL and kill it properly -> real terrain ruin + the normal repair flow.
// owner 2026-09-26 SECURITY (houses review): localNamespace, not a missionNamespace AP_fnc_ global -- a client
// publicVariable of that name replaced the code the server spawns here.
if (isNil {localNamespace getVariable "APS_maldenDestroy"}) then {localNamespace setVariable ["APS_maldenDestroy", {params ["_oid"];
        private _e = (localNamespace getVariable "APS_maldenSwaps") getOrDefault [_oid, []];
        if (_e isEqualTo []) exitWith {};
        _e params ["_orig"];
        // unswap via the shared registry logic: delete shell + sensors, restore the original in place
        private _shell = _e param [4, objNull];
        { if (!isNull _x) then { deleteVehicle _x; }; } forEach (_e param [5, []]);
        if (!isNull _shell && {!isNull _orig}) then { [_shell, _orig] remoteExec ["AP_fnc_maldenSync", 0]; };   // before the shell ref dies
        if (!isNull _shell) then { deleteVehicle _shell; };
        if (!isNull _orig) then {_orig setPosASL (_e select 1);
            _orig setVectorDirAndUp [(_e select 2), (_e select 3)];
            _orig enableSimulationGlobal true;
            _orig hideObjectGlobal false;
            _orig setDamage 1;   // terrain destruction -> ruin model, fn_civRepairBuilding can fix it
        };
        (localNamespace getVariable "APS_maldenSwaps") deleteAt _oid;
        [format ["UPDATE houses SET malden=0 WHERE oid='%1'", (_oid splitString "\'""") joinString ""]] call DB_fnc_asyncQuery;
        ["-VAULT-", objNull, format ["MALDEN DESTROYED oid %1 (explosives) -- original restored + ruined", _oid]] call APS_fnc_logIt;
        call APS_fnc_tagHousesSRV;}];};

// ── unswap: delete the shell, restore the original to its spot ───────────────────────────────
private _fnUnswap = {params ["_oid"];
    private _e = (localNamespace getVariable "APS_maldenSwaps") getOrDefault [format ["%1", _oid], []];
    if (_e isEqualTo []) exitWith { false };
    _e params ["_orig", "_pos", "_vd", "_vu", "_shell"];
    { if (!isNull _x) then { deleteVehicle _x; }; } forEach (_e param [5, []]);   // blast sensors
    if (!isNull _shell) then { deleteVehicle _shell; };
    if (!isNull _orig) then {_orig setPosASL _pos;
        _orig setVectorDirAndUp [_vd, _vu];
        _orig enableSimulationGlobal true;
        _orig hideObjectGlobal false;
        [_shell, _orig] remoteExec ["AP_fnc_maldenSync", 0];   // client registries back onto the original
    };
    (localNamespace getVariable "APS_maldenSwaps") deleteAt (format ["%1", _oid]);
    true};

// ── BOOT: swap every persisted makeover in its saved skin ───────────────────────────────────────
// owner 2026-09-26 SECURITY (houses review): CfgRE lets any client reach every mode. A client-sent boot re-swapped every
// makeover (duplicate shells) or cleared malden flags server-wide; boot only ever comes from initServer (not remoteExec).
if (_mode isEqualTo "boot") exitWith {if (isRemoteExecuted) exitWith {
        ["-SEC-", (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull], "BLOCKED malden boot from a client"] call APS_fnc_logIt;};
    private _rows = ["SELECT oid, worldspace, COALESCE(classname,'') AS classname, COALESCE(malden_skin,'') AS malden_skin FROM houses WHERE malden=1", 2, true] call DB_fnc_asyncQuery;
    if (isNil "_rows" || {!(_rows isEqualType [])}) exitWith { diag_log "[LooneyBin][malden] boot: no rows / query failed"; };
    private _n = 0; {_x params [["_oid", ""], ["_ws", ""], ["_cls", ""], ["_skin", ""]];
        private _s = format ["%1", _ws];
        if ((_s select [0, 1]) isEqualTo "[") then {private _t = parseSimpleArray _s;
            if ((_t param [0, 0]) isEqualType []) then { _t = _t param [0, [0,0,0]]; };
            private _cands = nearestObjects [_t, ["House_F"], 14];
            private _orig = (_cands select { (typeOf _x) isEqualTo (format ["%1", _cls]) }) param [0, objNull];
            if (isNull _orig) then { _orig = (_cands select { (["stem", typeOf _x] call AP_fnc_maldenMap) isNotEqualTo "" }) param [0, objNull]; };
            private _color = format ["%1", _skin];
            if (_color isEqualTo "" || {_color isEqualTo "NULL"}) then { _color = "whiteblue"; };
            if (!isNull _orig) then {if (isNull ([_orig, format ["%1", _oid], _color] call _fnSwap)) then {
                    diag_log format ["[LooneyBin][malden] boot: oid %1 class %2 has no variant -- clearing flag", _oid, _cls];
                    [format ["UPDATE houses SET malden=0 WHERE oid='%1'", _oid]] call DB_fnc_asyncQuery;} else { _n = _n + 1; };};};
    } forEach _rows;
    if (_n > 0) then { call APS_fnc_tagHousesSRV; };   // re-affirm identity onto the shells (idempotent)
    diag_log format ["[LooneyBin][malden] boot: %1 makeover(s) applied", _n];};

// ── REVERT (server-internal: sale/transfer). RETURNS the restored ORIGINAL object -- the caller's
//    _house ref is the shell, which this deletes; sell/transfer must continue on the original. ─────
// owner 2026-09-26 SECURITY (houses review): any client could revert any makeover (and the oid came from the
// client-writable AP_houseID, so a forged tag on your own house reverted someone else's on your sale). Only
// srvSellHouse / transferHouse, after their ownership checks, arm the one-shot localNamespace token (the network can't
// write it) naming this house, and pass the row oid APS_fnc_houseRights authorised.
if (_mode isEqualTo "revert") exitWith {private _house = _a1;
    if (isNull _house || {!((localNamespace getVariable ["APS_maldenRevertOk", objNull]) isEqualTo _house)}) exitWith { objNull };
    localNamespace setVariable ["APS_maldenRevertOk", objNull];
    private _oid = format ["%1", _a2];
    private _orig = ((localNamespace getVariable "APS_maldenSwaps") getOrDefault [_oid, []]) param [0, objNull];
    if ([_oid] call _fnUnswap) then {
        [format ["UPDATE houses SET malden=0 WHERE oid='%1'", (_oid splitString "\'""") joinString ""]] call DB_fnc_asyncQuery;
        diag_log format ["[LooneyBin][malden] reverted oid %1 (sale/transfer)", _oid];};
    _orig};

// ── BULLETS (client sensor report -> score heavy-caliber hits; see header block) ─────────────
if (_mode isEqualTo "bullets") exitWith {private _house = _a2;
    private _n     = _a3;
    private _sum   = _a4;
    private _src = remoteExecutedOwner;
    if (_src isEqualTo 0) exitWith {};   // server never self-reports
    private _shooter = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    // owner 2026-09-26 SECURITY (houses review, TONd-0-0 class): WHICH makeover was hit is the registry entry whose shell
    // IS this object. AP_malden / AP_houseID / AP_maldenDmg / AP_maldenDead were object vars any client can setVariable
    // publicly -- one forged report from anywhere ruined any makeover on the map. The tally lives in the entry.
    private _sw = localNamespace getVariable ["APS_maldenSwaps", createHashMap];
    private _oid = ((keys _sw) select { ((_sw get _x) param [4, objNull]) isEqualTo _house }) param [0, ""];
    if (isNull _shooter || {isNull _house} || {_oid isEqualTo ""}) exitWith {};
    if ((_shooter distance _house) > MALDEN_BLT_RANGE) exitWith {
        ["-SEC-", _shooter, format ["malden bullet report from out of range (%1m)", round (_shooter distance _house)]] call APS_fnc_logIt;
    };
    // rate cap: the legit client batches every 2s -- refuse faster senders
    if (isNil "AP_maldenBltLast") then { AP_maldenBltLast = createHashMap; };
    private _uid = getPlayerUID _shooter;
    private _now = diag_tickTime;
    if ((_now - (AP_maldenBltLast getOrDefault [_uid, -10])) < 1.5) exitWith {
        ["-SEC-", _shooter, "malden bullet report rate-capped"] call APS_fnc_logIt;};
    AP_maldenBltLast set [_uid, _now];
    // size caps: one report can never carry more than a ~2s full-auto HMG burst
    _n   = (_n   max 0) min MALDEN_BLT_MAXN;
    _sum = (_sum max 0) min MALDEN_BLT_MAXSUM;
    if (_n isEqualTo 0 || {_sum <= 0}) exitWith {};
    private _pts = _sum * MALDEN_BLT_SCALE;
    private _e = _sw getOrDefault [_oid, []];
    if (_e isEqualTo []) exitWith {};   // unswapped since the lookup
    private _tot = (_e param [6, 0]) + _pts;
    _e set [6, _tot];
    diag_log format ["[LooneyBin][malden] %1 rounds on oid %2 by %3: +%4 pts = %5/%6", _n, _oid, _uid, _pts toFixed 1, _tot toFixed 1, MALDEN_DESTROY_PTS];
    if (_tot >= MALDEN_DESTROY_PTS && {!(_e param [7, false])}) then {_e set [7, true];
        [_oid] spawn (localNamespace getVariable "APS_maldenDestroy");};};

// ── APPLY (client picker -> server, owner-verified): _a3 = color key, or "off" to restore Altis ──
if (_mode isEqualTo "apply") exitWith {private _player = _a1;
    private _house  = _a2;
    private _color  = format ["%1", _a3];
    private _src = remoteExecutedOwner;
    if (_src isNotEqualTo 0) then { _player = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]; };
    if (isNull _player || {isNull _house}) exitWith {};
    private _uid = getPlayerUID _player;
    // owner 2026-09-26 SECURITY (houses audit, TONd-0-0 class): owner + oid from the houses ROW, not the
    // client-writable AP_homeOwner / AP_houseID object vars (APS_fnc_houseRights).
    private _rights = [_house] call APS_fnc_houseRights;
    if ((_rights select 1) isEqualTo "" || {(_rights select 1) isNotEqualTo _uid}) exitWith {
        ["-SEC-", _player, format ["BLOCKED malden apply (not owner) by %1", _uid]] call APS_fnc_logIt;};
    private _oid = _rights select 0;
    if (_oid isEqualTo "-1" || {_oid isEqualTo ""}) exitWith {
        ["The property isn't registered yet -- try again in a minute.", "basic"] remoteExec ["AP_fnc_handleMessage", _src];};
    // dupe guard: never swap the object identity while its storage session is open
    if (_house getVariable ["AP_invHydrated", false]) exitWith {
        ["Close the property's storage first.", "basic"] remoteExec ["AP_fnc_handleMessage", _src];};
    private _oidSql = (_oid splitString "\'""") joinString "";
    private _cls = typeOf _house;
    private _isVariant = (["base", _cls] call AP_fnc_maldenMap) isNotEqualTo "";

    // OFF: restore the Altis original
    if (_color isEqualTo "off") exitWith {if (!_isVariant) exitWith {};
        // terrain originals are per-boot pristine, so a missing swap entry can only mean a manual DB
        // edit -- clear the flag and let the next restart sort the visuals.
        if !([_oid] call _fnUnswap) then {if (!isNull _house && {_house getVariable ["AP_malden", false]}) then { deleteVehicle _house; };
            diag_log format ["[LooneyBin][malden] apply-off oid %1 had no swap entry -- flag cleared, restart restores", _oid];};
        [format ["UPDATE houses SET malden=0, malden_skin='' WHERE oid='%1'", _oidSql]] call DB_fnc_asyncQuery;
        call APS_fnc_tagHousesSRV;
        ["-VAULT-", _player, format ["MALDEN OFF oid %1 by %2", _oid, _uid]] call APS_fnc_logIt;
        ["Makeover removed -- back to the classic Altis look.", "basic"] remoteExec ["AP_fnc_handleMessage", _src];};

    // sanity: a real color key
    if ((["variant", "Land_i_House_Big_01_V1_F", _color] call AP_fnc_maldenMap) isEqualTo "") exitWith {
        ["-SEC-", _player, format ["malden apply with bogus color '%1' by %2", _color, _uid]] call APS_fnc_logIt;};

    // RESKIN: variant -> another color. Grab the ORIGINAL from the registry BEFORE unswap (unswap deletes
    // the shell _house points at), restore, then swap fresh in the new color. Damage points reset with the
    // new shell -- a repaint re-scaffolds the building, fair enough. Refuse if the skin is unchanged.
    if (_isVariant) exitWith {if ((["colorOf", _cls] call AP_fnc_maldenMap) isEqualTo _color) exitWith {
            ["That's already this property's look.", "basic"] remoteExec ["AP_fnc_handleMessage", _src];};
        private _orig = ((localNamespace getVariable "APS_maldenSwaps") getOrDefault [_oid, []]) param [0, objNull];
        if (isNull _orig) exitWith {
            diag_log format ["[LooneyBin][malden] reskin oid %1 had no swap entry -- skin saved, restart applies", _oid];
            [format ["UPDATE houses SET malden_skin='%1' WHERE oid='%2'", _color, _oidSql]] call DB_fnc_asyncQuery;};
        [_oid] call _fnUnswap;
        private _shell = [_orig, _oid, _color] call _fnSwap;
        if (isNull _shell) exitWith {};
        [format ["UPDATE houses SET malden=1, malden_skin='%1' WHERE oid='%2'", _color, _oidSql]] call DB_fnc_asyncQuery;
        call APS_fnc_tagHousesSRV;
        ["-VAULT-", _player, format ["MALDEN RESKIN oid %1 -> %2 by %3", _oid, _color, _uid]] call APS_fnc_logIt;
        ["Fresh coat of paint applied.", "basic"] remoteExec ["AP_fnc_handleMessage", _src];};

    // ON: base -> chosen color
    private _shell = [_house, _oid, _color] call _fnSwap;
    if (isNull _shell) exitWith {};
    [format ["UPDATE houses SET malden=1, malden_skin='%1' WHERE oid='%2'", _color, _oidSql]] call DB_fnc_asyncQuery;
    call APS_fnc_tagHousesSRV;
    ["-VAULT-", _player, format ["MALDEN ON oid %1 (%2 -> %3) by %4", _oid, _cls, _color, _uid]] call APS_fnc_logIt;
    ["Malden Makeover applied. Enjoy the new look.", "basic"] remoteExec ["AP_fnc_handleMessage", _src];};
