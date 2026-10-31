/*
    APS_fnc_processMailbox  (LooneyBin -- implemented 2026-06-09; was a passthrough into the 2017
    WRITE-half (KBW_fnc_updateMailbox) with mismatched args -> "Error Type Object, expected Array"
    every time anyone checked their mailbox, and nothing was ever read or paid.)
    Client (core/functions/fn_checkMailbox.sqf, 10-min client cooldown) sends [player, uid].
    players_global.mailbox format (canonical, write from admin tools / loonybot):
        [["cash", 50000], ["bank", 100000], ["item", "goldbar", 3], ...]
    Pays everything out, clears the mailbox, tells the player, logs -MAILBOX-.
*/
params [["_unit", objNull, [objNull]], ["_uid", "", [""]]];

// owner 2026-06-23 SECURITY (security.md §2.3 — cross-account read/wipe + SQLi): the client _uid was used raw
// to SELECT/UPDATE the mailbox and to credit cash/bank, so a scripter could read or wipe ANY player's mailbox
// and mass-credit accounts. Force the actor to the NON-SPOOFABLE caller's OWN account (the legit caller --
// fn_checkMailbox -- always passes getPlayerUID player). Server-internal (_src==0) keeps the passed _uid/_unit.
private _src = remoteExecutedOwner;
if (_src != 0) then {private _rc = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    _unit = _rc;
    _uid  = getPlayerUID _rc;};
if (isNull _unit || {_uid isEqualTo ""}) exitWith {};
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_uid = _uid call _san;   // defence-in-depth (a real Steam64 is digits-only, but escape anyway)

private _r = [format ["SELECT COALESCE(mailbox,'[]') AS mailbox FROM players_global WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
private _box = [];
if (_r isEqualType []) then {private _raw = format ["%1", _r param [0, "[]"]];
    _box = parseSimpleArray _raw;
    if !(_box isEqualType []) then { _box = []; };};
if (_box isEqualTo []) exitWith {[["Your mailbox is empty.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};

// clear FIRST (one payout even if they spam-check during the handout)
[format ["UPDATE players_global SET mailbox=NULL WHERE playerid='%1'", _uid]] call DB_fnc_asyncQuery;

private _summary = []; {if (_x isEqualType []) then {_x params [["_kind", "", [""]], ["_a", 0], ["_b", 0]];
        switch (toLower _kind) do {
            // owner 2026-06-21 (comp money LOST on logout -- player108): the mailbox is cleared FIRST (L25), then the
            // payout was credited CLIENT-SIDE ONLY (AP_fnc_uC). If the player disconnected (or crashed) before
            // their NEXT save persisted AP_cash/atmcash, the credit never reached the DB and the mailbox was
            // already gone = money vanished (e.g. 547k comp collected, logged off 2 min later, never saved). Fix:
            // persist the credit to the DB DIRECTLY here. No double-count -- the client's saves SET cash/bankacc to
            // AP_cash/atmcash (which we also bump via AP_fnc_uC), so DB + client converge to the same value.
            case "cash": {if (_a isEqualType 0 && {_a > 0}) then {
                    [format ["UPDATE players SET cash = cash + %1 WHERE playerid='%2'", _a, _uid]] call DB_fnc_asyncQuery;
                    [["cash", "add", _a], "AP_fnc_uC", _unit, false, false] spawn AP_fnc_MP;
                    _summary pushBack format ["$%1 cash", _a];};};
            case "bank": {if (_a isEqualType 0 && {_a > 0}) then {
                    [format ["UPDATE players SET bankacc = bankacc + %1 WHERE playerid='%2'", _a, _uid]] call DB_fnc_asyncQuery;
                    [["atm", "add", _a], "AP_fnc_uC", _unit, false, false] spawn AP_fnc_MP;
                    _summary pushBack format ["$%1 bank", _a];};};
            case "item": {if (_a isEqualType "" && {_b isEqualType 0} && {_b > 0}) then {
                    [[true, _a, _b], "AP_fnc_handleInv", _unit, false, false] spawn AP_fnc_MP;
                    _summary pushBack format ["%1x %2", _b, _a];};};};};} forEach _box;
if (_summary isEqualTo []) exitWith {
    [["Your mailbox is empty.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;};
[[format ["Mailbox delivery: %1", _summary joinString ", "], "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
["-MAILBOX-", _unit, format ["collected: %1", _summary joinString ", "]] call APS_fnc_logIt;
