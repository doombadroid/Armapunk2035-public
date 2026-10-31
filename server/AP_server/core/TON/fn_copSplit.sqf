/*
    APS_fnc_copSplit  (LooneyBin) -- distribute a cop payout evenly among the active
    on-duty police, crediting each officer's bank. Runs on the SERVER.
    2020 client args: [_cop, _amount]   (_cop = initiating officer, _amount = total pool)

    Was a no-op stub, so cops were NEVER paid for tickets, money/vehicle/inventory seizures,
    impounds, illegal tents, or arrest bounties. Civilian bounty hunters were unaffected (they bypass this and
    credit AP_atmcash directly), which is why only police reported missing pay.
    ARREST shares no longer come from a client: APS_fnc_wantedBounty / APS_fnc_claimBodybagSRV price a duty
    cop's share on the server and remoteExec this AT THE SERVER (owner 2 = server-internal) with arg 3 = the
    arrester/claimer to CHARGE. That bounty is still offender-client-authoritative (APS_fnc_wantedSyncList /
    the bodybag's AP_bbBounty) and only capped at $1M per pay, so internal arrest pays count against the
    charged player's rolling budget below (no 2s cooldown: one arrest can pay several friend shares at once).
    A client cannot use arg 3: for a client call the charged player is always its remoteExecutedOwner.

    Pairs with AP_fnc_copSplitReceive (client). Server->client MP is exempt from the
    CfgRemoteExec mode=1 whitelist, so the receiver needs no CfgRE.hpp entry.
*/
params [["_cop", objNull, [objNull]], ["_amount", 0, [0]], ["_charge", objNull, [objNull]]];

// owner 2026-06-24 SECURITY + #528 FIX: CfgRE-whitelisted -> a client could remoteExec [player, 9.9e8] to split an
// arbitrary pool among cops. The 2026-06-23 hardening required the CALLER be a COP (side west) -- but that was a FALSE
// POSITIVE: fn_ticketPay runs on the CIVILIAN payer's client, so the legit ticket-payout caller is the paying civ, not
// a cop -> every paid ticket logged "-SEC- BLOCKED copSplit (caller not a cop)" and cops went UNPAID (#528). The side
// gate was also pointed the wrong way for abuse: a COP caller (the old ALLOWED case) is a payee and can pay THEMSELVES,
// while a civilian caller is NOT a payee (payees are server-filtered to west+alive below) and gains nothing. So the real
// defenses are: (1) a non-spoofable caller (remoteExecutedOwner, model fn_seizeLock:22); (2) the per-call pool ceiling;
// (3) a short per-caller cooldown so copSplit can't be spam-minted. server-internal (below) skips the cooldown; the arrest
// bounty paths pass arg 3 so their pays still count against the arrester's rolling budget.
private _src = remoteExecutedOwner;
// owner 2026-09-26 SECURITY (AUDIT A6): SERVER-INTERNAL = a local call (0) OR the server's own AP_fnc_MP round-trip
// (2 = the server's machine id; no client can hold it). A plain `call` from inside a client-remoteExecuted server fn
// reads THAT CLIENT's id (see fn_dutyLookup's header), which is why the arrest payers remoteExec this at owner 2.
private _internal = _src in [0, 2];
private _caller = if (_internal) then { _charge } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (!_internal && {isNull _caller}) exitWith {};   // spoofed / vanished caller
private _MAX_POOL = 5000000;   // generous per-call ceiling (owner 2026-07-24: a $5M single payout is legitimate)
_amount = (round _amount) min _MAX_POOL;
if !(_amount > 0) exitWith {};   // non-positive pool, or a client NaN (fails every comparison, would pay NaN shares)
if (!isNull _caller) then {isNil {   // isNil = unscheduled: the book read-check-write below can't interleave with a burst
    // anti-spam: a legit ticket-pay / seize / impound is seconds+ apart -- a 2s per-caller cooldown can't block a real
    // action but stops a client minting the capped pool to cops in a tight loop. (CLANKR also watches copSplit volume.)
    // owner 2026-09-26 (AUDIT A6): the pool is still CLIENT-priced for tickets/searches/seizes/impounds, so a caller also
    // gets a ROLLING BUDGET per 10 min: 2 max pools for a duty cop, 2 max tickets ($1.5M, fn_ticketGive) for anyone
    // else (the only legit non-cop caller is fn_ticketPay's payer). Was $5M per 2s. Over budget -> pay what is left.
    // State lives in localNamespace: the old missionNamespace AP_copSplitCD_<uid> could be reset by a client publicVariable.
    // NOTE: exitWith here would only leave THIS then-block (SQF scope trap), so signal a throttle via _amount=-1 and
    // let the TOP-LEVEL `_amount <= 0` guard below exit the whole function.
    private _cUid = getPlayerUID _caller;
    private _budget = if (_caller call APS_fnc_isDutyCop) then {2 * _MAX_POOL} else {2 * 1500000};
    private _book = localNamespace getVariable "APS_copSplitBook";
    if (isNil "_book") then {_book = createHashMap; localNamespace setVariable ["APS_copSplitBook", _book];};
    (_book getOrDefault [_cUid, [-999, -999, 0]]) params ["_last", "_winAt", "_spent"];
    private _now = diag_tickTime;
    if (!_internal && {(_now - _last) < 2}) then {
        ["-SEC-", _caller, format ["throttled copSplit (rapid repeat) by %1", _cUid]] call APS_fnc_logIt;
        _amount = -1;} else {
        if ((_now - _winAt) >= 600) then {_winAt = _now; _spent = 0;};
        private _left = (_budget - _spent) max 0;
        if (_amount > _left) then {
            ["-SEC-", _caller, format ["copSplit over budget by %1: asked $%2, $%3 left of $%4 per 10 min", _cUid, _amount toFixed 0, _left toFixed 0, _budget toFixed 0]] call APS_fnc_logIt;
            _amount = _left;};
        _book set [_cUid, [[_now, _last] select _internal, _winAt, _spent + (_amount max 0)]];};};};
if (_amount <= 0) exitWith {};   // throttled (_amount=-1) / budget spent / non-positive pool -> no payout (top-level exit)

private _cops = allPlayers select { isPlayer _x && {_x call APS_fnc_isDutyCop} && {alive _x} };
if (_cops isEqualTo []) exitWith {diag_log format ["[LooneyBin][copSplit] no active cops to pay (pool $%1)", _amount];};

private _share = round (_amount / (count _cops));
if (_share <= 0) exitWith {}; {[[_share], "AP_fnc_copSplitReceive", _x, false] spawn AP_fnc_MP;} forEach _cops;
diag_log format ["[LooneyBin][copSplit] paid $%1 each to %2 cop(s) (pool $%3)", _share, count _cops, _amount];
