/*
    APS_fnc_initHouseInventory  (LooneyBin: GATED house-storage hydration -- security.md §"free house keys")
    2020 client args : [_house, _houseID, _mode]   (_mode default "hydrate"; "dehydrate" used by cop search/seize)

    owner 2026-06-23 (option B): house storage (AP_vinv/AP_pinv) is NO LONGER broadcast at rest -- fn_receiveHouses
    now sets it SERVER-LOCAL, so a client can't read another player's stash off the object (the publicly-bragged
    "free house keys" exploit). This fn is the single hydration chokepoint:
      * HYDRATE  -> verify the NON-spoofable caller (remoteExecutedOwner) is the owner / a keyholder / a gangmate of
                    a gang house / a cop, then broadcast the real contents GLOBAL for the open session. A non-authorized
                    caller is denied (-SEC-) and gets nothing. Server-internal calls (_src==0) are trusted.
      * DEHYDRATE-> broadcast EMPTY to every client, then restore the server-LOCAL cache from the DB (so the
                    disconnect-path save in fn_updateHouseTrunk still reads true contents server-side). fn_updateHouseTrunk
                    dehydrates the owner/keyholder close path; cop search/seize call this mode when done.
    The take/store/refresh machinery + the anti-dupe trunk-lock timing are UNTOUCHED (they operate on the hydrated
    global var during the session exactly as before) -- B deliberately avoids that fragile, dupe-prone code.
*/
params [["_house", objNull, [objNull]], ["_houseID", "", ["", 0]], ["_mode", "hydrate", [""]]];
if (isNull _house) exitWith {};
// owner 2026-07-24 SECURITY (audit): the hydrate gate below authorises against the HOUSE OBJECT, but the
// DB read keyed on _oid, which came from the SEPARATE client argument _houseID and was never compared to
// the authorised house. So: own a cheap house H, call with _house = H (auth passes) and _houseID = the
// VICTIM's oid -> _loadInv reads the victim's vinv/pinv and lines 69-70 broadcast them onto H, where the
// attacker simply takes them. The close then persists to H's own oid, so the items are duplicated out
// while the victim's row looks untouched. _oid was also interpolated unescaped into the SELECT (SQLi), and
// the "dehydrate" branch exits BEFORE the auth block, so it took the same foreign oid with no check.
// Fix: derive the oid from the house OBJECT (the same authoritative source fn_updateHouseTrunk uses), so
// the authorised house and the queried row can no longer differ. The client's _houseID is now only a
// fallback for server-internal callers (_src == 0), and the value travels as a query parameter.
// owner 2026-09-26 SECURITY (audit TONc-0-1 / TONd-0-0): the hydrate gate's exitWith sat INSIDE
// `if (_src != 0) then {...}`, so it only left that block -- the load, the GLOBAL broadcast of the stash and the
// AP_invGen bump still ran for ANY caller on ANY house (the "free house keys" leak reopened; the gen bump also made
// the owner's open session close as stale = their changes lost). It also authorised from AP_homeOwner /
// AP_house_keys / AP_house_gang / gang_data (client-writable object vars), and "dehydrate" had no gate at all
// (a forged dehydrate mid-session blanks the owner's view, and their next store persists over the real stash).
// Now ONE flat top-level gate covers both modes, rights come from the houses ROW (APS_fnc_houseRights), and the
// row that was authorised is the row that is loaded.
private _srcOid = remoteExecutedOwner;   // 0 == server-internal = trusted
private _oid = format ["%1", _house getVariable ["AP_houseID", -1]];
if (_srcOid isEqualTo 0 && {_oid in ["-1", ""]}) then { _oid = format ["%1", _houseID]; };
private _denied = false;
private _sesUid = "";
if (_srcOid isNotEqualTo 0) then {private _caller = (allPlayers select { owner _x isEqualTo _srcOid }) param [0, objNull];
    private _rights = [_house, _caller] call APS_fnc_houseRights;
    _oid = _rights select 0;
    _sesUid = getPlayerUID _caller;
    _denied = isNull _caller || {!(_rights select 2)};
    if (_denied) then {
        // text kept verbatim: loonybot/clankr.py SEC_FP_PATTERNS matches "blocked house-inv hydrate" (access denial, not a ban signal)
        ["-SEC-", _caller, format ["BLOCKED house-inv hydrate (not owner/keyholder/gang/cop) house %1 by %2 [%3]", _oid, getPlayerUID _caller, _mode]] call APS_fnc_logIt;};};
if (_denied) exitWith {};   // top-level -> exits the function

// load [vinv, pinv] from the houses row (the authoritative store; written on every trunk close).
private _loadInv = {private _v = [[], 0]; private _p = [[], 0];
    if (_oid != "" && {_oid != "-1"}) then {
        private _row = ["SELECT vinv,pinv FROM houses WHERE oid = %s", 2, false, [_oid]] call DB_fnc_asyncQuery;
        if (!isNil "_row" && {!(_row isEqualTo [])}) then {private _dec = {params [["_s", "", [""]]];
                if (isNil "_s" || {_s isEqualTo ""} || {_s isEqualTo "NULL"}) exitWith {[]};
                private _a = [_s] call DB_fnc_mresToArray;
                if (typeName _a == "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };
                if (isNil "_a") then { _a = []; };
                _a};
            private _vd = [_row select 0] call _dec; if !(_vd isEqualTo []) then { _v = _vd; };
            private _pd = [_row select 1] call _dec; if !(_pd isEqualTo []) then { _p = _pd; };};};
    [_v, _p]};

// owner 2026-09-26 SECURITY (houses review): open storage sessions are recorded HERE, server-side (localNamespace: the
// network can't write it), as uid -> [house, authorised oid]. fn_playerDisconnected persists only that session, so a
// leaver can no longer aim the disconnect save at any house/row via the client-writable AP_activeTrunk / AP_houseID.
private _ses = localNamespace getVariable ["APS_houseSessions", createHashMap];
localNamespace setVariable ["APS_houseSessions", _ses];
{ _ses deleteAt _x; } forEach ((keys _ses) select { ((_ses get _x) select 0) isEqualTo _house });   // a newer open / a dehydrate ends older sessions on this house

// DEHYDRATE: clear the broadcast (clients go empty), then re-assert the true contents SERVER-LOCAL only.
if (_mode isEqualTo "dehydrate") exitWith {
    _house setVariable ["AP_invHydrated", false, true];   // session over -> updateHouseTrunk's empty-write guard re-arms
    _house setVariable ["AP_vinv", [[], 0], true];
    _house setVariable ["AP_pinv", [[], 0], true];
    ([] call _loadInv) params ["_v", "_p"];
    _house setVariable ["AP_vinv", _v];   // server-LOCAL real (disconnect-path save reads this)
    _house setVariable ["AP_pinv", _p];};

// HYDRATE: the caller was authorised by the top-level gate above (server-internal _src == 0 is trusted).
([] call _loadInv) params ["_vinv", "_pinv"];
_house setVariable ["AP_vinv", _vinv, true];   // broadcast real contents for the open session
_house setVariable ["AP_pinv", _pinv, true];
// owner 2026-06-24: mark this house HYDRATED for the session. updateHouseTrunk refuses to persist an EMPTY client
// payload unless this flag is set -> a close that never actually loaded the contents (denied/failed hydrate, the
// display bug) can no longer wipe the stored row. Cleared on dehydrate (close/seize) so the guard re-arms each session.
_house setVariable ["AP_invHydrated", true, true];
// owner 2026-06-25 (#542 house wipe): bump a per-house SESSION token on every hydrate. A close carries the gen of
// the open it belongs to; if a NEWER open hydrated since (gen advanced), APS_fnc_updateHouseTrunk no-ops that stale
// close so its delayed dehydrate broadcast can't clobber the live session's contents to empty (= the wipe).
_house setVariable ["AP_invGen", (_house getVariable ["AP_invGen", 0]) + 1, true];
if (_sesUid isNotEqualTo "" && {_oid isNotEqualTo ""}) then { _ses set [_sesUid, [_house, _oid]]; };
