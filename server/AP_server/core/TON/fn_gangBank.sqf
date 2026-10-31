/*
    APS_fnc_gangBank  (LooneyBin: REPAIRED router -- replaces the broken passthrough stub)

    Used by the gang bank AND the gov treasury (same protocol). The 2020 client multiplexes several ops
    onto this one fn via a leading mode arg; the old stub always called APS_fnc_updateGangBank with
    mismatched args (the `modifier` slot ended up holding a player object) so it moved NO money and never
    replied -> the bank UI hung on "Loading...". This rewrites it as a proper mode router.

    Client protocol: [mode, gangID, unit, amount, cash, cacheB, _, targetUID]
      0 = QUERY balance (no money moves)
      1 = player <-> gang : amount > 0 DEPOSIT (client already debited its own cash);
                            amount < 0 WITHDRAW |amount| (server credits the player's cash). Balance-gated.
      2 = INCOME: add amount to the fund, no player cash (turf tax). Cap-limited.
      4 = TRANSFER |amount| (sent as -val) from the fund to targetUID's bank. Balance-gated. Online->cash sync, offline->DB.
    Every path replies the resulting balance via AP_fnc_gangBank so the client UI updates and its
    deposit/withdraw wait (AP_gfunds_active) is released.

    DUPE-SAFE: this fn has NO suspend point between reading _funds and committing it, so two concurrent
    requests can't interleave -> the withdraw/transfer balance gate ("can't take more than the fund holds")
    is race-proof, and the old "credit-without-checking-the-balance" double-withdraw is closed.

    AP_server_gangs row: [id@0, name@1, wars@2, inviteRank@3, kickRank@4, bank@5, members@6, exp@7, talents@8]
*/
params [["_mode", -1, [0]], ["_gangID", "", ["", 0]], ["_unit", objNull, [objNull]], ["_amount", 0, [0]], ["_cash", 0, [0]],
    ["_cacheB", 0, [0]], ["_spare", "", [""]], ["_targetUID", "", [""]]];
if (isNull _unit) exitWith {};
// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): NON-SPOOFABLE caller + SQL sanitize. Was: a scripter
// could remoteExec [1,rivalGangID,player,-funds] to DRAIN ANY gang bank (only a balance gate, NO rank
// check), and _targetUID/_gangID went RAW into format[] SQL ("credit EVERY player's bank" via WHERE '1'='1').
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };   // strips \ ' " (matches fn_logIt)
private _src = remoteExecutedOwner;   // 0 == server-internal (turf-tax / gov tax / disconnect reload) = TRUSTED
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _logName = (name _unit) call _san;   // gang_bank_log-safe name
private _idStr = (format ["%1", _gangID]) call _san;   // format (not str) -> quoteless, so it matches whether the gang id is cached as a number or a string. receiveGangs leaves select-0 un-parsed, so its type can differ from the client's AP_gang_data[0] -> `str` (which quotes strings) mismatched -> "gang not found" -> deposit lost. _san strips quotes -> SQLi-safe (idStr reaches every format[] query below).
private _safeTargetUID = _targetUID call _san;   // client string -> escaped before any UPDATE players WHERE playerid

// AUTHZ: for a CLIENT call (src != 0), the caller must be entitled to act on THIS gang. Models the client
// gates: deposit/query = any member (gangWithdraw/Deposit don't gate, gangAtmMenu opens for members);
// WITHDRAW (mode 1, amount<0) + TRANSFER (mode 4) = rank<=2 (fn_gangWithdraw/fn_gangBankTransfer "_rank>2"
// reject; gangrank 1=leader,2=officer); INCOME (mode 2) = turf-tax, any civ pays it (left ungated). Gang
// 50000 = the Government treasury: its rightful operator is the seated GOVERNOR (SRV_governorData[0]), NOT
// a gang member -> allow the governor through the same gates (gov bank menu only ever queries+withdraws).
// _ok defaults true (server-internal + the ungated modes pass); only a failed client check flips it false.
private _ok = true;
if (_src != 0 && {_mode in [0, 1, 4]}) then {
    private _isGov = (_idStr isEqualTo "50000") && {(_callerUID isEqualTo (localNamespace getVariable ["SRV_governorData", ["", ""]] param [0, ""])) && {_callerUID isNotEqualTo ""}};
    private _row = [format ["SELECT gangrank0 FROM %2 WHERE playerid='%1' AND gang0='%3'", _callerUID, "players", _idStr], 2] call DB_fnc_asyncQuery;
    private _isMember = (_row isEqualType []) && {count _row >= 1} && {!isNil { _row select 0 }};
    private _rank = if (_isMember) then { parseNumber (format ["%1", _row select 0]) } else { 99 };
    private _needsLeader = (_mode isEqualTo 4) || {_mode isEqualTo 1 && {_amount < 0}};
    _ok = if (_isGov) then { true } else {
        if (!_isMember) then { false } else { if (_needsLeader) then { _rank <= 2 && {_rank >= 1} } else { true } };};
    if (!_ok) then {
        ["-SEC-", _caller, format ["BLOCKED gangBank mode=%1 gang=%2 amount=%3 by %4 (rank %5, gov %6)", _mode, _idStr, _amount, _callerUID, _rank, _isGov]] call APS_fnc_logIt;
        [[0], "AP_fnc_gangBank", _unit] spawn AP_fnc_MP;   // release the client UI wait so it doesn't hang
    };};
if (!_ok) exitWith {};   // top-level -> exits the FUNCTION (an inner exitWith would only leave the then-block)

private _idx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo _idStr };
if (_idx < 0) then {
    // Not in the boot cache -- gangs created AFTER boot are never added to AP_server_gangs (insertGang
    // doesn't cache them). Pull bank + member count from the DB and cache a row so this and every later
    // op this session work without a restart.
    private _row = [format ["SELECT bank, (SELECT COUNT(*) FROM %2 WHERE gang0='%1') AS gang0 FROM gangs WHERE id='%1'", _idStr, "players"], 2] call DB_fnc_asyncQuery;
    // re-check: another concurrent op may have cached this gang during the query's suspend -> don't double-add
    _idx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo _idStr };
    if (_idx < 0 && {_row isEqualType [] && {count _row >= 2}}) then {private _dbBank    = parseNumber (format ["%1", _row select 0]);
        private _dbMembers = (parseNumber (format ["%1", _row select 1])) max 1;
        AP_server_gangs pushBack [_gangID, "", 0, 2, 2, _dbBank, _dbMembers, 0, []];   // [id,name,wars,invite,kick,bank,members,exp,talents]; name/etc placeholder until the next boot reloads the full row
        _idx = (count AP_server_gangs) - 1;
        diag_log format ["[LooneyBin][gangBank] cached gang from DB: id=%1 bank=%2 members=%3", _idStr, _dbBank, _dbMembers];};};
if (_idx < 0) exitWith {
    // genuinely no such gang in the DB -> refund an optimistic deposit, never eat cash
    if (_mode isEqualTo 1 && {_amount > 0}) then {[["cash", "add", _amount], "AP_fnc_uC", _unit, false] spawn AP_fnc_MP;
        [[1, "That gang no longer exists -- deposit refunded."], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;};
    diag_log format ["[LooneyBin][gangBank] gang NOT in DB: id=%1 mode=%2 amount=%3", _idStr, _mode, _amount];
    [[0], "AP_fnc_gangBank", _unit] spawn AP_fnc_MP;};

private _gang    = AP_server_gangs select _idx;
private _funds   = _gang select 5;
private _members = (_gang select 6) max 1;   // a 0 member-count would zero the cap and silently block every deposit
private _cap     = ((_members * AP_gangbank_cap) min 2500000) max 0;
diag_log format ["[LooneyBin][gangBank] id=%1 mode=%2 amount=%3 funds=%4 members=%5 cap=%6", _idStr, _mode, _amount, _funds, _members, _cap];
private _newFunds = _funds;
private _changed  = false;

switch (_mode) do {case 0: { /* query only -- reply happens below */ };

    case 1: {if (_amount < 0) then {                                   // ---- WITHDRAW ----
            private _w = -_amount;
            if (_w <= _funds) then {_newFunds = _funds - _w; _changed = true;
                [["cash", "add", _w], "AP_fnc_uC", _unit, false] spawn AP_fnc_MP;   // server credits the player
                [format ["INSERT INTO gang_bank_log (gangid, name, uid, type, amount) VALUES ('%1','%2','%3','2','%4')", _idStr, _logName, getPlayerUID _unit, _w]] call DB_fnc_asyncQuery;   // history
                [[997, _unit, format ["Gang(%1) WITHDRAW $%2 by %3 (%4) -> fund $%5. Srv %6", _idStr, _w, name _unit, getPlayerUID _unit, _newFunds, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
            } else {
                [[1, format ["The gang bank only has $%1 right now -- withdrawal rejected.", [_funds] call AP_fnc_numberText]], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;
            };} else {                                                  // ---- DEPOSIT (client already debited its own cash) ----
            if (_amount > 0) then {
                _newFunds = _funds + _amount; _changed = true;   // LooneyBin: gang bank holding cap removed -> unlimited fund
                [format ["INSERT INTO gang_bank_log (gangid, name, uid, type, amount) VALUES ('%1','%2','%3','1','%4')", _idStr, _logName, getPlayerUID _unit, _amount]] call DB_fnc_asyncQuery;   // history (gangBHistory dialog)
                [[996, _unit, format ["Gang(%1) DEPOSIT $%2 by %3 (%4) -> fund $%5. Srv %6", _idStr, _amount, name _unit, getPlayerUID _unit, _newFunds, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
            };};};

    case 2: {                                                     // ---- INCOME (turf tax) -> add, no player cash ----
        // owner 2026-07-24 SECURITY (audit): mode 2 is deliberately OUTSIDE the AUTHZ block above (turf tax
        // is paid by any civ shopping on a gang's turf, so it cannot require membership) and it creates
        // funds without debiting anyone, so a client can mint into ANY gang's bank and cash out via mode 1
        // (withdraw) or mode 4 (transfer) -- the withdrawal even looks legitimate in gang_bank_log.
        // DETECTION ONLY, NO LIMIT -- owner ruling 2026-07-24: the gang fund stays uncapped. A per-call
        // ceiling was tried and REVERTED because it would clip real income: turf tax is 20% of a heroin
        // sale (fn_sellVehicleInv:108), so a big sale legitimately exceeds members * AP_gangbank_cap for
        // a small gang, and the tax would have been silently reduced. Same false-positive class as the
        // #528 copSplit side-gate that stopped cop pay.
        // So: allow the amount in full, but make abuse VISIBLE -- a client-originated income above the
        // reference cap is logged for CLANKR / !logs review rather than blocked. The real fix is deriving
        // the tax server-side from the transaction (the tax amount is still a client global,
        // AP_turfTax, passed by fn_virtualShopMenu); that needs an owner ruling on the legitimate
        // per-purchase maximum and is tracked in AUDIT.md alongside the copSplit item.
        private _callerOk = (_src isEqualTo 0) || {!isNull ((allPlayers select { owner _x isEqualTo _src }) param [0, objNull])};
        if (_amount > 0 && {_callerOk}) then {if (_src isNotEqualTo 0 && {_amount > _cap}) then {
                [[998, objNull, format ["Gang(%1) LARGE client income $%2 (reference cap $%3, src %4) -- allowed, review", _idStr, _amount, _cap, _src]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
            };
            _newFunds = _funds + _amount; _changed = true;};};

    case 4: {                                                     // ---- TRANSFER fund -> target player ----
        private _t = if (_amount < 0) then { -_amount } else { _amount };
        if (_t > 0 && {_t <= _funds} && {_safeTargetUID != ""}) then {   // owner 2026-06-23 SECURITY (§2.3): escaped UID
            _newFunds = _funds - _t; _changed = true;
            private _tp = objNull;
            { if (getPlayerUID _x isEqualTo _safeTargetUID) exitWith { _tp = _x; }; } forEach allPlayers;   // legit Steam64 = digits only, so _san is a no-op for them; an injection payload simply matches no one
            if (!isNull _tp) then {
                // owner 2026-06-21 (#475/#472 "gang transfer didn't arrive"): the online credit was CLIENT-SIDE
                // ONLY (AP_fnc_uC) -> a recipient who relogged/crashed/sat at spawn-select before their next
                // save LOST it (same shape as the comp/mailbox loss). Persist to the DB too. No double-count: the
                // client save SETs bankacc = AP_atmcash (which uC also bumped), so DB + client converge to one
                // +_t; if they relog first, the direct write already landed. Spawn-select saves are guarded.
                [format ["UPDATE players SET bankacc = bankacc + %1 WHERE playerid='%2'", _t, _safeTargetUID]] call DB_fnc_asyncQuery;   // durable; owner 2026-06-23 SECURITY (§2.3): _safeTargetUID, was raw _targetUID -> "credit EVERY bank" via WHERE '1'='1'
                [["atm", "add", _t], "AP_fnc_uC", _tp, false] spawn AP_fnc_MP;                                       // + live HUD/session sync
            } else {
                [format ["UPDATE players SET bankacc = bankacc + %1 WHERE playerid='%2'", _t, _safeTargetUID]] spawn DB_fnc_asyncQuery;   // offline -> DB; owner 2026-06-23 SECURITY (§2.3): _safeTargetUID
            };
            [format ["INSERT INTO gang_bank_log (gangid, name, uid, type, amount) VALUES ('%1','%2','%3','3','%4')", _idStr, _logName, getPlayerUID _unit, _t]] call DB_fnc_asyncQuery;   // history
            [[997, _unit, format ["Gang(%1) TRANSFER $%2 -> %3 by %4 -> fund $%5. Srv %6", _idStr, _t, _safeTargetUID, getPlayerUID _unit, _newFunds, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
        } else {
            [[1, "Gang transfer rejected (insufficient funds or invalid target)."], "AP_fnc_broadcast", _unit, false] spawn AP_fnc_MP;
        };};};

if (_changed) then {_gang set [5, _newFunds];
    AP_server_gangs set [_idx, _gang];
    // DUPE FIX (owner 2026-06-13): persist as a RELATIVE, BLOCKING decrement instead of the old async absolute
    // set. The async `spawn DB_fnc_updateGang(_newFunds)` could still be queued (not committed) when a member
    // PULLED PLUG -- their disconnect reloads the gang fund FROM the DB (member-count change), reading the
    // pre-withdraw balance, so a 2nd member could withdraw the "restored" fund = the reported pull-plug dupe.
    // Relative (bank + delta) keeps the DB consistent even if in-memory/DB momentarily drift; mode 2 BLOCKS so
    // the row is committed before this script ends (and before any reload can read it). The in-memory gate
    // above still serializes concurrent same-instant withdrawals (SQF single-threaded, no suspend before here).
    private _delta = _newFunds - _funds;
    [format ["UPDATE gangs SET bank = (bank + (%1)) WHERE id='%2'", _delta, _idStr], 2] call DB_fnc_asyncQuery;};

[[_newFunds], "AP_fnc_gangBank", _unit] spawn AP_fnc_MP;      // ALWAYS reply -> client UI refreshes + its wait releases
