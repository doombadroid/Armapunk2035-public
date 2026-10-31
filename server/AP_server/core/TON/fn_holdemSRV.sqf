/*
    APS_fnc_holdemSRV  (Armapunk 2035) -- TEXAS HOLD'EM. The six-seat multiplayer table.

    Sibling of APS_fnc_bjTableSRV (DEALERBOT'S TABLE), and built from it: one table that exists
    whether or not anyone is looking at it, a seat registry, a clock, and a snapshot rebuilt PER
    VIEWER because what each viewer may see differs. Where it departs from blackjack it departs on
    purpose, and each departure is written out where it happens.

    NO HOUSE HAND. Hold'em is player against player: the server deals, times, ranks and pays, and
    every chip that leaves one stack lands in another. There is no edge here and no sink -- see
    SRV_holdemRake below, which is the only lever that changes that and ships at 0.

    WHAT THE SERVER OWNS: the deck, the shuffle, the button, the blinds, whose turn it is, the
    clock, the legality of every action, the side pots, the ranking and the payout. A client sends
    INTENT. There is no path by which a page can name a card, a pot, a winner or an amount -- and
    no path by which it can see a card that is not its own, which is a stronger statement than the
    other tables need to make. The privacy line is one `if` in _snap and it is quoted in the PR.

    MONEY -- and this is where it differs from every other casino table, deliberately.
    The rest of the casino debits CLIENT-SIDE before telling the server (security.md 2.4:
    AP_atmcash is a client cache), and the server only ever credits. That model has one failure
    mode this table cannot afford: the debit happens BEFORE the server rules on the request, so a
    refusal after the money moved eats it -- exactly the "eaten bet" bug APS_fnc_casinoSRV's own
    comments record twice. A buy-in is 20-100 big blinds, not a 10k spin.
    THE SERVER WRITES THE BANK ROW ITSELF, in both directions, and only after it has decided
    (_bankMove). The first cut of this file had the server ORDER a debit that the player's own client
    then applied -- which fixed the eaten-bet direction and opened the opposite one: a client that
    dropped the order kept its money AND its seat, and the `log` row was written either way, so the
    audit trail recorded intent rather than movement. Now:
        sit    -> validated, the seat RESERVED, the bank debited server-side and the debit CONFIRMED
                  by reading the row back -- and only then does the reservation become chips
        leave  -> the seat is cleared first, then the stack is credited server-side and confirmed
        d/c    -> identical; the uid is the address, so the absent unit changes nothing
        drain  -> every seat, live hand aborted and refunded, offline seats included
    The write is APS_fnc_gangBank's (fn_gangBank.sqf:138/141, and the same statement in
    fn_processMailbox.sqf:47, fn_medicSplit.sqf:27); the read is
    APS_fnc_adminPlayerQuerySRV's (fn_adminPlayerQuerySRV.sqf:24). No new money primitive was
    invented for this table -- and there was none to borrow from APS_fnc_casinoSRV, which has no
    server-side bank write at all: it only ever credits, through the client.
    AP_fnc_holdemCash SURVIVES AS A DISPLAY SYNC. It moves the client's cached copy of the balance so
    the phone and the page's header agree with the row the server just wrote, and so the client's own
    next periodic save (which SETs bankacc = AP_atmcash) does not write the pre-movement balance back
    over it. It is not an authority and it is no longer load-bearing: drop it and the money is still
    right, only the display lags.
    The bridge (AP_fnc_holdemOpen) still checks the bank before it sends, because the client cannot
    read the row -- but that check MOVES NOTHING. It is an affordance, not an authority.
    Why not AP_fnc_casinoReceive: it refuses `_return <= 0` outright, and widening that to admit a
    debit would loosen the credit gate every other table in the casino stands on. Why not
    AP_fnc_uC: allowedTargets = 1 restricts the TARGET and not the sender, and uC carries no origin
    assertion at all, so any client can already call it at any client. Nothing new gets built on
    that.
    EVERY MOVEMENT IS ONE `log` ROW, tag -CASINO-HOLDEM-, carrying uid, amount, direction, handId and
    both balances -- and it is written ON CONFIRMATION, never on intent. A movement whose read-back
    disagrees writes an UNCONFIRMED row instead and is NOT retried, because a retry is how a late
    read-back becomes a double credit. Casino money is verified through that table; a table whose
    pots did not appear in it would be the one game CLANKR could not mass-balance.

    THE TABLE IS MEMORY, SO IT HAS A KILL-SWITCH. SRV_holdemEnabled false closes it and drains it --
    see the tunable below and server_init.sqf for the deploy procedure. A stack still sat on a seat
    when the process dies is money that came out of a real bankacc row and exists nowhere else.

    PROTOCOL (client -> here, CfgRE allowedTargets = 2):
        ["open",  []]                 subscribe this viewer; answers with the current state
        ["close", []]                 unsubscribe -- AND give the seat up, see the case
        ["sit",   [_seat, _buyIn]]    take seat 0-5
        ["leave", []]                 stand up; the stack banks
        ["act",   [_action, _raiseTo]] "fold"|"check"|"call"|"raise"|"allin"; _raiseTo is a STREET
                                      TOTAL, the page's contract, never a delta
    SERVER-LOCAL (remoteExecutedOwner == 0 asserted; none of these are reachable from the wire):
        ["tick"]                      the scheduler wheel, 1 s -- the turn clock and the hand pump
        ["expire"]                    force the acting seat's timeout action (tick's own arm)
        ["disconnect", [_uid]]        CALLed from fn_playerDisconnected, the duty precedent
        ["drain", [_why]]             empty the table and bank every chip -- the restart path. The
                                      case is server-local for the same reason "disconnect" is: it
                                      moves other people's money, and allowedTargets restricts the
                                      TARGET, not the sender.

    SNAPSHOT (here -> client, AP_fnc_holdemReceive, allowedTargets = 1):
        ["table", _state]             the whole table as ui\html\casino\holdem.html defines it

    THE CLOCK IS A PUMP, NOT ONLY A TIMER. Every client-reachable case runs _pump before it does
    anything else, so a table cannot deadlock on the scheduler alone: the wheel auto-disables a job
    after five consecutive failures (fn_scheduler.sqf), and if that ever happened to this one the
    only thing keeping six players from being stuck on a dead turn is that the next thing anybody
    does un-sticks it. try/catch would not have helped -- SQF's catch does not see runtime errors.

    TUNABLES (server_init.sqf; defaults here so the file stands alone on a box that missed them):
        SRV_holdemBlinds  [5000, 10000]        small / big blind
        SRV_holdemBuyIn   [200000, 1000000]    20 - 100 big blinds
        SRV_holdemActMs   20000                turn clock, milliseconds
        SRV_holdemNextMs  6000                 pause between hands
        SRV_holdemRake    0                    percent of each pot to the house, clamped 0-5
*/

private _src = remoteExecutedOwner;   // FIRST statement: the caller, before anything can suspend
if (!isServer) exitWith {};
params [["_case", "", [""]], ["_data", [], [[]]]];

#define H_SEATS 6

private _BLINDS = missionNamespace getVariable ["SRV_holdemBlinds", [5000, 10000]];
private _SB     = (_BLINDS param [0, 5000]) max 1;
private _BB     = (_BLINDS param [1, 10000]) max (_SB * 2);
private _BUYIN  = missionNamespace getVariable ["SRV_holdemBuyIn", [200000, 1000000]];
private _MINBUY = (_BUYIN param [0, 200000]) max _BB;
private _MAXBUY = (_BUYIN param [1, 1000000]) max _MINBUY;
private _ACTMS  = ((missionNamespace getVariable ["SRV_holdemActMs", 20000]) max 5000) min 120000;
private _NEXTMS = ((missionNamespace getVariable ["SRV_holdemNextMs", 6000]) max 1000) min 60000;
private _RAKE   = ((missionNamespace getVariable ["SRV_holdemRake", 0]) max 0) min 5;
// C-1(a). THE KILL-SWITCH, and it is a MONEY switch rather than a feature flag. Every other tunable
// above changes how the table plays; this one is the thing you flip before the process dies, because
// AP_holdemTable is memory and a stack sitting on a seat when it goes is money that came out of a
// real `players.bankacc` row and exists nowhere else.
//     false -> no sits, no actions, no new hands, and the very next entry into this file DRAINS the
//              table: every committed chip refunded, every stack banked, by UID so a seat whose
//              player is already gone banks exactly like one whose player is not
//     true  -> the table opens again, empty
// Read through a getVariable default of TRUE so a box that missed server_init behaves identically to
// one that did -- the SRV_landingEnabled / SRV_baseNoSaveRadius idiom, and the reason it is safe to
// deploy this file ahead of the server_init that declares the variable.
private _ENABLED = missionNamespace getVariable ["SRV_holdemEnabled", true];

// ── identity: derived from the connection, never from the payload ────────────
private _caller = objNull;
private _uid = "";
if (_src isNotEqualTo 0) then {
    _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (!isNull _caller) then { _uid = getPlayerUID _caller };
};
private _serverLocal = _src isEqualTo 0;
private _clientCases = ["open", "close", "sit", "leave", "act"];
private _localCases  = ["tick", "expire", "disconnect", "drain"];
private _c = toLower _case;

// A client-reachable case with no resolvable caller is a spoof or a player who vanished between
// the send and the receive; a server-local case reached from the wire is the thing allowedTargets
// cannot stop on its own, because it restricts the TARGET and not the sender.
if (_c in _clientCases && {_serverLocal || {isNull _caller} || {_uid isEqualTo ""}}) exitWith {
    diag_log format ["[HOLDEM] refused '%1': no caller (src %2)", _c, _src];
};
if (_c in _localCases && {!_serverLocal}) exitWith {
    diag_log format ["[HOLDEM] refused '%1': server-local case from owner %2", _c, _src];
};
if !(_c in (_clientCases + _localCases)) exitWith { diag_log format ["[HOLDEM] unknown case '%1'", _c] };

// ── table state ──────────────────────────────────────────────────────────────
if (isNil "AP_holdemTable") then {
    private _empty = []; for "_i" from 1 to H_SEATS do { _empty pushBack [] };
    AP_holdemTable = createHashMapFromArray [
        ["stage",     "wait"],   // wait | pre | flop | turn | river | showdown
        ["handId",    0],
        ["deck",      []],
        ["community", []],
        ["pot",       0],        // COLLECTED chips only; live street bets sit on the seats
        ["seats",     _empty],
        ["dealer",    0],
        ["acting",    -1],
        ["deadline",  0],        // diag_tickTime the acting seat's clock runs out
        ["bet",       0],        // the street's bet LEVEL (an absolute, matching the page's toCall)
        ["lastRaise", 0],        // size of the last full raise -- the page's minRaise
        ["viewers",   []],
        ["winners",   []],
        ["msg",       ""],
        ["ghosts",    []],       // [committed, uid, obj] per player who left mid-hand; see _buildPots
        ["nextAt",    0]         // diag_tickTime the next hand may start; 0 = not waiting on one
    ];
    diag_log "[HOLDEM] table created";
};
private _T = AP_holdemTable;
private _seats = _T get "seats";
private _now = diag_tickTime;


// ── seat helpers ─────────────────────────────────────────────────────────────
private _seatOf = {
    params ["_u"];
    private _r = -1;
    { if (_x isNotEqualTo [] && {(_x get "uid") isEqualTo _u}) exitWith { _r = _forEachIndex }; } forEach _seats;
    _r
};
// LIVE = holding cards in the current hand. A player who sat down mid-hand is occupied but not
// live (inHand false) and is dealt in on the next deal; that is why this is not `!folded` alone.
private _liveIdx = {
    private _r = [];
    { if (_x isNotEqualTo [] && {_x get "inHand"} && {!(_x get "folded")}) then { _r pushBack _forEachIndex }; } forEach _seats;
    _r
};
private _canActIdx = {
    private _r = [];
    { if (_x isNotEqualTo [] && {_x get "inHand"} && {!(_x get "folded")} && {!(_x get "allin")}) then { _r pushBack _forEachIndex }; } forEach _seats;
    _r
};
// Whose turn is it. The next seat clockwise that is live, has chips, and either has not acted on
// this street or is short of the bet. Plain "next live seat" would re-ask a player who has already
// called, which is how a street never ends.
private _nextToAct = {
    params ["_from"];
    private _r = -1;
    private _lvl = _T get "bet";
    for "_k" from 1 to H_SEATS do {
        private _n = (_from + _k) mod H_SEATS;
        private _s = _seats select _n;
        if (_r < 0 && {_s isNotEqualTo []} && {_s get "inHand"} && {!(_s get "folded")} && {!(_s get "allin")}
            && {!(_s get "acted") || {(_s get "bet") < _lvl}}) then { _r = _n };
    };
    _r
};
private _occupiedWithChips = {
    private _r = [];
    { if (_x isNotEqualTo [] && {(_x get "stack") > 0}) then { _r pushBack _forEachIndex }; } forEach _seats;
    _r
};

// ── money. ONE primitive, both directions, and the SERVER writes the row ─────
// C-2 INVERTED THIS FILE'S MONEY SPINE. The shipped shape granted the seat and then ORDERED the
// player's own client to debit itself through AP_fnc_holdemCash -- so a client that dropped the
// order sat down for free, and the `log` row was written whether or not a cent ever moved. It was
// an audit trail of INTENT. Now the database row is the authority: the bank write happens on the
// SERVER, addressed by UID, and the `log` row is written on CONFIRMATION -- a read-back that proves
// the balance actually changed -- with the client push demoted to a display sync.
//
// THE PRIMITIVE ITSELF NOW LIVES IN APS_fnc_bankMove (core\system\fn_bankMove.sqf), LIFTED VERBATIM
// out of this file, because the duty bounty payoff needs the identical guarantees and two copies of a
// money primitive is exactly the drift this one was written to end. Read that file's header for why
// nothing in it is a new primitive.
//
// EQUIVALENCE, and it is the whole of what this change is allowed to be. The lifted code is
// character-for-character the same arithmetic, the same SQL (`... AND bankacc >= N` on the debit
// side), the same pre-write refusal of an unbacked debit, the same blocking read-back and the same
// half-dollar tolerance. The three extra arguments below exist ONLY to keep this table's rows
// byte-identical to the ones it wrote before:
//   "-CASINO-HOLDEM-"  the APS_fnc_logIt tag, unchanged;
//   "HOLDEM"           the diag_log bracket, so `[HOLDEM] ...` still reads `[HOLDEM] ...`;
//   the CODE context   appended to `why` inside the `log` rows, so `(buy-in, hand #12)` is still
//                      `(buy-in, hand #12)`. It is CODE and not a string on purpose: the old inline
//                      closure read `_T get "handId"` at the moment each row was composed, and a bank
//                      move suspends across up to three DB round trips, so a hand that advances
//                      mid-movement could always change that number. APS_fnc_bankMove calls this
//                      block at each log site, which is the same read at the same instant; freezing
//                      it at call time would have been a different function.
// `_T` inside that block resolves up the SQF call stack, which is the same mechanism by which the
// closure this replaces could see `_T` at all. APS_fnc_bankMove prefixes every one of its own
// privates with `_bm` so nothing there can shadow it.
// The file-local `_san` this used to call went with it (verbatim, as `_bmSan`); it had no other
// caller here.
//
// UID-ADDRESSED, AND THAT IS THE WHOLE POINT FOR THE DRAIN. There is no unit anywhere in this
// primitive. A seat whose player disconnected, or whose player is mid-loading-screen when a restart
// is announced, banks by exactly the same path as one stood at the felt.
//
// Returns [ok, before, after].
private _bankMove = {
    params ["_uidFor", "_delta", "_why"];
    [_uidFor, _delta, _why, "-CASINO-HOLDEM-", "HOLDEM", {format ["hand #%1", _T get "handId"]}] call APS_fnc_bankMove
};

// _who is the seat's stored unit and is used for ONE thing: telling that client to move its cached
// copy of the balance. _uidFor is the identity the money actually moves on.
private _cash = {
    params ["_who", "_uidFor", "_amt", "_why"];
    if ((round _amt) isEqualTo 0) exitWith { true };
    // The DISPLAY SYNC (the client's cached AP_atmcash moved behind the row write) now lives INSIDE
    // APS_fnc_bankMove, addressed by uid (owner 2026-09-03): it used to be here, which is why every credit
    // in this file synced and the buy-in in case "sit" -- which calls _bankMove directly for its refusal
    // message -- did not. The cache never dropped on a buy-in, the cash-out credit lifted it ABOVE the row,
    // and the client's next absolute save wrote the buy-in back into the bank: "hold'em isn't taking money
    // from the bank". One primitive, one sync; no caller can forget it again. _who is kept for the callers.
    ([_uidFor, _amt, _why] call _bankMove) param [0, false]
};

// ── the snapshot. Built per viewer; the ONLY place a card becomes an int ─────
private _snap = {
    params ["_forUid", ["_msgOverride", ""]];
    private _stage  = _T get "stage";
    private _reveal = _stage isEqualTo "showdown";
    private _acting = _T get "acting";

    private _out = [];
    {
        private _s = _x;
        if (_s isEqualTo []) then {
            // toJSON turns an unsupported array element into JSON null (BIKI: toJSON), which is
            // exactly the `null` the page's `seats:[ null | {…} ]` contract asks for.
            _out pushBack objNull;
        } else {
            private _mine   = (_s get "uid") isEqualTo _forUid;
            private _folded = _s get "folded";
            private _hole   = _s get "hole";

            // ─────────────────────── THE PRIVACY LINE ───────────────────────
            // Hole cards leave this machine as INTS in exactly two cases: they are the viewer's
            // own, or the hand has reached showdown and the seat did not fold. Every other seat is
            // a COUNT. A folded hand is never serialised at all, at any stage, to anyone -- it is
            // mucked, and a muck the table can read is not a muck.
            private _cards = 0;
            if (!_folded && {(count _hole) isEqualTo 2}) then {
                _cards = if (_mine || {_reveal}) then { +_hole } else { 2 };
            };
            // ────────────────────────────────────────────────────────────────

            _out pushBack createHashMapFromArray [
                ["name",    _s get "name"],
                ["stack",   _s get "stack"],
                ["bet",     _s get "bet"],
                ["folded",  _folded],
                ["allin",   _s get "allin"],
                ["me",      _mine],
                ["cards",   _cards],
                ["lastAct", _s get "lastAct"]
            ];
        };
    } forEach (_T get "seats");

    private _wins = [];
    {
        _x params ["_ws", "_wa", "_wl"];
        _wins pushBack createHashMapFromArray [["seat", _ws], ["amount", _wa], ["label", _wl]];
    } forEach (_T get "winners");

    private _left = 0;
    if (_acting > -1 && {(_T get "deadline") > 0}) then { _left = round ((((_T get "deadline") - diag_tickTime) max 0) * 1000) };

    createHashMapFromArray [
        ["handId",    _T get "handId"],
        ["stage",     _stage],
        ["blinds",    [_SB, _BB]],
        ["buyIn",     [_MINBUY, _MAXBUY]],
        ["community", +(_T get "community")],
        ["pot",       _T get "pot"],
        ["dealer",    _T get "dealer"],
        ["acting",    _acting],
        ["actMs",     _left],
        ["actTotal",  _ACTMS],
        ["toCall",    _T get "bet"],
        ["minRaise",  _T get "lastRaise"],
        ["seats",     _out],
        ["winners",   _wins],
        ["msg",       if (_msgOverride isEqualTo "") then { _T get "msg" } else { _msgOverride }]
    ]
};

private _pushAll = {
    private _vs = (_T get "viewers") select { !isNull _x };
    _T set ["viewers", _vs];
    // _v is captured before _snap runs. _snap has forEach loops of its own, and reading the outer
    // _x back after a nested call is the kind of assumption that is right until it is not.
    { private _v = _x; [["table", ([getPlayerUID _v] call _snap)], "AP_fnc_holdemReceive", _v, false] spawn AP_fnc_MP; } forEach _vs;
};
// A refusal is personal, so it goes to one viewer as a state push with the reason in `msg` -- the
// strip the page already renders verbatim. It is never dropped: the answer to hSit/hAct is
// optimistic by construction (webui handlers are synchronous and the server is not), so THIS is
// where a server refusal becomes visible. See AP_fnc_holdemOpen's header for the whole argument.
private _refuse = {
    params ["_why"];
    diag_log format ["[HOLDEM] refuse %1 <%2>: %3", _c, _uid, _why];
    if (!isNull _caller) then {
        [["table", ([_uid, _why] call _snap)], "AP_fnc_holdemReceive", _caller, false] spawn AP_fnc_MP;
    };
};

// ── dealing ──────────────────────────────────────────────────────────────────
private _draw = {
    private _d = _T get "deck";
    if ((count _d) isEqualTo 0) exitWith { -1 };   // cannot happen: 6*2 + 3 burns + 5 board = 20 of 52
    private _card = _d deleteAt 0;
    _T set ["deck", _d];
    _card
};

// ── pot construction: layers of totalCommitted ───────────────────────────────
// The standard side-pot build. Every distinct commitment level is a layer; each layer's chips come
// from everyone who reached it (FOLDED PLAYERS INCLUDED -- their chips stay in the pot, which is
// the whole point of folding after betting), and are contested by the players at that level who
// are still live. Adjacent layers with an identical eligible set are merged so a split does not
// scatter odd chips across pots that are really one pot.
private _buildPots = {
    // CONTRIBUTORS, as [committed, eligible, seat, uid, obj]. Every seat with chips in the middle,
    // PLUS the GHOSTS -- chips committed by somebody who stood up or dropped out mid-hand. Those
    // chips stay in the pot, because you cannot take money off the table in the middle of a hand;
    // the player is simply never eligible to win them back. Leaving them out is how a pot ends up
    // smaller than the chips that were paid into it, and the conservation check below would then
    // fire on every hand somebody rage-quit.
    // THE UID AND THE UNIT RIDE ALONG (I-5) because an UNCONTESTED layer has to go back to whoever
    // put it there, and "whoever" may be a ghost -- a seat index of -1 that no longer identifies
    // anybody. A bare number cannot be refunded to a person.
    private _cons = [];
    {
        if (_x isNotEqualTo [] && {(_x get "committed") > 0}) then {
            _cons pushBack [(_x get "committed"), ((_x get "inHand") && {!(_x get "folded")}), _forEachIndex, (_x get "uid"), (_x get "obj")];
        };
    } forEach _seats;
    {
        _x params [["_gAmt", 0], ["_gUid", ""], ["_gObj", objNull]];
        if (_gAmt > 0) then { _cons pushBack [_gAmt, false, -1, _gUid, _gObj] };
    } forEach (_T getOrDefault ["ghosts", []]);

    private _levels = [];
    { _levels pushBackUnique (_x select 0) } forEach _cons;
    _levels sort true;

    // A layer is [amount, eligible seats, contributors] with contributors as [seat, uid, obj, slice].
    // EVERY CONTRIBUTOR TO A GIVEN LAYER PUTS IN THE SAME SLICE (_lvl - _prev) -- that is what makes
    // a layer a layer -- so "pro-rata by contribution" and "an equal split" are the same number here,
    // and a refund of an uncontested layer is exact with no odd chip to place.
    private _pots = [];
    private _prev = 0;
    {
        private _lvl = _x;
        private _slice = _lvl - _prev;
        private _amt = 0;
        private _elig = [];
        private _con = [];
        {
            if ((_x select 0) >= _lvl) then {
                _amt = _amt + _slice;
                _con pushBack [(_x select 2), (_x select 3), (_x select 4), _slice];
                if (_x select 1) then { _elig pushBack (_x select 2) };
            };
        } forEach _cons;
        if (_amt > 0) then {
            private _last = if ((count _pots) > 0) then { _pots select ((count _pots) - 1) } else { [] };
            if (_last isNotEqualTo [] && {(_last select 1) isEqualTo _elig}) then {
                _last set [0, (_last select 0) + _amt];
                // Merged layers merge their contributor lists too, or a merged uncontested layer
                // would know its total and not who is owed it. Keyed on seat AND uid: every ghost
                // carries seat -1, so the seat index alone would fold two departed players into one.
                private _lc = _last select 2;
                {
                    _x params ["_cSeat", "_cUid", "_cObj", "_cAmt"];
                    private _hit = -1;
                    { if ((_x select 0) isEqualTo _cSeat && {(_x select 1) isEqualTo _cUid}) exitWith { _hit = _forEachIndex }; } forEach _lc;
                    if (_hit < 0) then { _lc pushBack [_cSeat, _cUid, _cObj, _cAmt] }
                    else { (_lc select _hit) set [3, ((_lc select _hit) select 3) + _cAmt] };
                } forEach _con;
            } else {
                _pots pushBack [_amt, _elig, _con];
            };
        };
        _prev = _lvl;
    } forEach _levels;
    _pots
};

// Pay one pot out. Ties split; the ODD CHIP goes to the winner nearest the button on its LEFT --
// the standard rule, and the reason the order is built from (dealer + 1) clockwise rather than by
// seat index.
private _payPot = {
    params ["_amt", "_winners", "_awards"];
    private _n = count _winners;
    if (_n isEqualTo 0 || {_amt <= 0}) exitWith {};
    private _order = [];
    private _d = _T get "dealer";
    for "_k" from 1 to H_SEATS do {
        private _i = (_d + _k) mod H_SEATS;
        if (_i in _winners) then { _order pushBack _i };
    };
    private _share = floor (_amt / _n);
    private _odd = _amt - (_share * _n);
    {
        private _give = _share + (if (_forEachIndex < _odd) then { 1 } else { 0 });
        _awards set [_x, (_awards getOrDefault [_x, 0]) + _give];
    } forEach _order;
};

// ── settle: award every pot, seat the winners array, bank nothing (chips stay) ──
private _settle = {
    params [["_showdown", true]];
    private _live = call _liveIdx;
    private _pots = call _buildPots;
    private _awards = createHashMap;
    private _labels = createHashMap;
    private _scores = createHashMap;
    private _raked = 0;
    private _returned = 0;      // I-5: uncontested layers handed back to their contributors
    // DEFERRED BANK MOVEMENTS. An uncontested layer whose contributor has already left the table has
    // to go to a bank, and a bank movement is now a database round trip that may suspend. Nothing
    // suspends in the middle of a settle: the list is filled here and flushed at the very end, after
    // the last _T set, so the table is in one consistent state before anything can interleave.
    private _bankOut = [];

    if (_showdown && {(count _live) > 1}) then {
        private _board = _T get "community";
        {
            private _i = _x;
            private _s = _seats select _i;
            private _sc = ["score", ((_s get "hole") + _board)] call APS_fnc_holdemEval;
            _scores set [_i, _sc];
            _labels set [_i, (["label", _sc] call APS_fnc_holdemEval)];
        } forEach _live;
    } else {
        // Last man standing: no cards are shown and no hand is ranked, because none was made.
        { _labels set [_x, "LAST STANDING"] } forEach _live;
    };

    {
        _x params ["_amt", "_elig", ["_con", []]];
        private _best = [];
        private _win = [];
        private _evalFailed = false;
        if (_showdown && {(count _live) > 1}) then {
            {
                private _i = _x;
                private _sc = _scores get _i;
                // An empty score means the evaluator failed. Never rank on it: the old code read
                // `_best isEqualTo []` as "first contender", so every seat won in turn and the
                // highest-numbered one took the pot (the 2026-08-20 wrong-winner report). Bail to an
                // even split among the eligible -- chips are conserved and the fault is loud.
                if (_sc isEqualTo []) exitWith { _evalFailed = true };
                private _rel = if (_best isEqualTo []) then { 1 } else { ["cmp", [_sc, _best]] call APS_fnc_holdemEval };
                if !(_rel isEqualType 0) exitWith { _evalFailed = true };
                if (_rel > 0) then { _best = _sc; _win = [_i] }
                else { if (_rel isEqualTo 0) then { _win pushBack _i } };
            } forEach _elig;
        } else {
            _win = +_elig;
        };
        if (_evalFailed) then {
            _win = +_elig;
            diag_log format ["[HOLDEM] !! CRIT hand #%1: evaluator returned no score -- pot split %2 ways instead of ranked", _T get "handId", count _elig];
            [["-CASINO-HOLDEM-", objNull, "SERVER", format ["EVAL FAILURE hand #%1, pot split %2 ways", _T get "handId", count _elig]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
        };

        if ((count _win) isEqualTo 0) then {
            // I-5. A LAYER NOBODY IS ELIGIBLE FOR IS UNCALLED MONEY AND IT GOES BACK TO WHOEVER PUT
            // IT IN. The shipped fallback handed it to `_live` -- the players still holding cards --
            // which pays somebody money that nobody ever called. The shape that reaches it is the
            // blind under a short blind: the small blind is all-in for less than a big blind, the big
            // blind is the only live seat, and the sliver of the BB above the SB's stack was never
            // contested by anyone. Under the old fallback that sliver was "won"; it is simply the big
            // blind's own money coming home.
            //
            // AND IT IS NOT RAKED. The rake is a cut of the pot, and an uncalled bet was never in a
            // pot -- which is why the rake block now lives in the contested branch below rather than
            // at the top of this loop, where it used to take a percentage of a refund.
            //
            // BY CONSTRUCTION THE LAYER HAS EXACTLY ONE CONTRIBUTOR: an uncontested layer is a
            // commitment level only one player reached. That is asserted rather than assumed, and the
            // multi-contributor branch pays each of them back their own slice -- which IS pro-rata,
            // because every contributor to a layer put in the same slice -- instead of guessing.
            if ((count _con) isNotEqualTo 1) then {
                diag_log format ["[HOLDEM] !! uncontested layer $%1 on hand #%2 has %3 contributors, not 1 -- each refunded their own slice", _amt, _T get "handId", count _con];
            };
            {
                _x params ["_cSeat", "_cUid", "_cObj", "_cAmt"];
                if (_cAmt > 0) then {
                    private _cs = if (_cSeat > -1) then { _seats select _cSeat } else { [] };
                    if (_cs isNotEqualTo [] && {(_cs get "uid") isEqualTo _cUid}) then {
                        // Still sat there: the chips never left the table, so this is a stack move
                        // and not a bank movement. Logged as UNCALLED and not as POT, because it is
                        // not a win and a hand reconstructed from `log` must not read it as one.
                        _cs set ["stack", (_cs get "stack") + _cAmt];
                        ["-CASINO-HOLDEM-", (_cs get "obj"), format ["UNCALLED $%1 returned to seat %2 (hand #%3)", _cAmt, _cSeat, _T get "handId"]] call APS_fnc_logIt;
                    } else {
                        // A ghost, or a seat that has turned over since. They are not at the table to
                        // take chips back, so it goes to the bank -- deferred, see _bankOut above.
                        _bankOut pushBack [_cObj, _cUid, _cAmt, "uncalled bet returned"];
                    };
                    _returned = _returned + _cAmt;
                };
            } forEach _con;
        } else {
            // The rake, if the owner ever turns it on, comes off each CONTESTED pot before it is
            // shared and is its own log row -- so sum(awards) + rake + uncalled == the pot stays
            // checkable.
            private _cut = 0;
            if (_RAKE > 0) then { _cut = floor (_amt * _RAKE / 100); _amt = _amt - _cut; _raked = _raked + _cut };
            [_amt, _win, _awards] call _payPot;
        };
    } forEach _pots;

    // Built by seat index rather than by walking _awards, because HashMap iteration order is not
    // defined and the winners array is rendered in the order it arrives.
    private _wins = [];
    for "_i" from 0 to (H_SEATS - 1) do {
        private _amt = _awards getOrDefault [_i, 0];
        if (_amt > 0) then {
            private _s = _seats select _i;
            if (_s isNotEqualTo []) then {
                _s set ["stack", (_s get "stack") + _amt];
                _wins pushBack [_i, _amt, (_labels getOrDefault [_i, ""])];
            };
        };
    };

    // CONSERVATION, checked every hand rather than argued once. Everything committed to this hand
    // was collected into the pot before _settle ran, and every chip of it is now an award or rake.
    // A mismatch means chips were created or destroyed, which is the one bug this table must never
    // ship with quietly.
    private _paid = _raked + _returned;
    { _paid = _paid + (_x select 1) } forEach _wins;
    if (_paid isNotEqualTo (_T get "pot")) then {
        diag_log format ["[HOLDEM] !! CONSERVATION hand #%1: pot $%2 but $%3 paid (awards + rake + uncalled)", _T get "handId", _T get "pot", _paid];
        // M-6. AND A `log` ROW. LOG, DON'T HALT -- a table that stopped dealing would be a worse
        // outage than a table that is a dollar out and says so -- but an RPT line is gone at the next
        // restart, and this is the one failure that has to still be findable a week later, in the
        // same table every other movement on this felt is written to.
        ["-CASINO-HOLDEM-", objNull, format ["CONSERVATION-FAIL hand #%1 delta $%2 (pot $%3, paid $%4 = awards + rake $%5 + uncalled $%6)", _T get "handId", _paid - (_T get "pot"), _T get "pot", _paid, _raked, _returned]] call APS_fnc_logIt;
    };

    // Chips move BETWEEN STACKS here; nothing enters or leaves a bank, so this is a pot row rather
    // than a _cash movement. It is still one `log` row per award, which is what makes a hand
    // reconstructable from the table alone.
    {
        _x params ["_i", "_amt", "_lbl"];
        private _s = _seats select _i;
        ["-CASINO-HOLDEM-", (_s get "obj"), format ["POT $%1 seat %2 (%3, hand #%4)", _amt, _i, _lbl, _T get "handId"]] call APS_fnc_logIt;
    } forEach _wins;
    if (_raked > 0) then {
        ["-CASINO-HOLDEM-", objNull, format ["RAKE $%1 at %2% (hand #%3)", _raked, _RAKE, _T get "handId"]] call APS_fnc_logIt;
    };

    _T set ["winners", _wins];
    _T set ["pot", 0];
    _T set ["ghosts", []];
    // inHand goes false with the pot: the hand is over. Leaving it true made a player who stood up
    // during the showdown pause read as live, which sent _stand back into _advance and re-settled a
    // hand that was already paid -- wiping the winners strip and restarting the rest. `hole` and
    // `folded` are deliberately left alone so the reveal keeps rendering until the next deal.
    { if (_x isNotEqualTo []) then { _x set ["bet", 0]; _x set ["committed", 0]; _x set ["inHand", false] } } forEach _seats;

    private _msg = "";
    if ((count _wins) > 0) then {
        (_wins select 0) params ["_i0", "_a0", "_l0"];
        private _s0 = _seats select _i0;
        _msg = format ["%1%2 WINS $%3 — %4", (if ((count _wins) > 1) then { "SPLIT POT — " } else { "" }), toUpper (_s0 get "name"), _a0, _l0];
    };
    _T set ["msg", _msg];
    _T set ["stage", "showdown"];
    _T set ["acting", -1];
    _T set ["deadline", 0];
    _T set ["nextAt", diag_tickTime + (_NEXTMS / 1000)];

    // LAST, and deliberately after the final _T set: the table is now in one consistent, fully
    // settled state, so a bank round trip that suspends here cannot be observed half-done.
    { _x params ["_bObj", "_bUid", "_bAmt", "_bWhy"]; [_bObj, _bUid, _bAmt, _bWhy] call _cash; } forEach _bankOut;
};

// ── street end / next street. A loop, not recursion: the only exits are a hand that ends or a
// street on which two or more players can actually bet.
private _collect = {
    private _pot = _T get "pot";
    { if (_x isNotEqualTo []) then { _pot = _pot + (_x get "bet"); _x set ["bet", 0] } } forEach _seats;
    _T set ["pot", _pot];
    _T set ["bet", 0];
    _T set ["lastRaise", _BB];
};
// NO exitWith IN THIS LOOP. `exitWith` exits the innermost scope, which for a while body is the
// loop -- correct, and used elsewhere in this tree -- but a reader who has to know that rule to see
// where a hand ends is one misreading away from a table that never settles. One flag, one exit.
// The cap is a stamped self-heal, not decoration: this loop is the only thing that can end a hand,
// and SQF's try/catch would not catch a runtime error inside it if a stage ever went unreachable.
private _advance = {
    private _done = false;
    private _guard = 0;
    while { !_done && {_guard < 8} } do {
        _guard = _guard + 1;
        call _collect;
        private _live = call _liveIdx;
        if ((count _live) < 2) then { [false] call _settle; _done = true }
        else {
            private _stage = _T get "stage";
            if (_stage isEqualTo "river") then { [true] call _settle; _done = true }
            else {
                // Burn one, then the street. Burning is cosmetic at a server-shuffled table, but
                // the deck positions a counter would have to track are the point of doing it.
                private _com = _T get "community";
                switch (_stage) do {
                    case "pre":  { call _draw; _com pushBack (call _draw); _com pushBack (call _draw); _com pushBack (call _draw); _T set ["stage", "flop"] };
                    case "flop": { call _draw; _com pushBack (call _draw); _T set ["stage", "turn"] };
                    case "turn": { call _draw; _com pushBack (call _draw); _T set ["stage", "river"] };
                    default      { _T set ["stage", "river"] };   // unreachable; settles next pass
                };
                _T set ["community", _com];
                { if (_x isNotEqualTo []) then { _x set ["acted", false]; if (_x get "inHand") then { _x set ["lastAct", ""] } } } forEach _seats;

                // Two players with chips is what makes a betting round; anything less and the board
                // simply runs out -- one live player with chips has nobody to bet against.
                _T set ["acting", -1];
                _T set ["deadline", 0];
                if ((count (call _canActIdx)) >= 2) then {
                    private _a = [_T get "dealer"] call _nextToAct;
                    if (_a > -1) then {
                        _T set ["acting", _a];
                        _T set ["deadline", diag_tickTime + (_ACTMS / 1000)];
                        _done = true;
                    };
                };
            };
        };
    };
    if (!_done) then {
        diag_log format ["[HOLDEM] !! _advance hit its guard on hand #%1 stage %2", _T get "handId", _T get "stage"];
        [true] call _settle;
    };
};

// ── start a hand ─────────────────────────────────────────────────────────────
private _startHand = {
    private _eligible = call _occupiedWithChips;
    if ((count _eligible) < 2) exitWith {
        _T set ["stage", "wait"]; _T set ["acting", -1]; _T set ["deadline", 0]; _T set ["nextAt", 0];
    };

    _T set ["handId", (_T get "handId") + 1];
    private _deck = [];
    for "_i" from 0 to 51 do { _deck pushBack _i };
    // Fisher-Yates on the engine's own random. Shuffled ONCE per hand, so no reshuffle can land
    // mid-street and no street straddles two decks.
    for "_i" from (count _deck - 1) to 1 step -1 do {
        private _j = floor (random (_i + 1));
        private _t = _deck select _i; _deck set [_i, _deck select _j]; _deck set [_j, _t];
    };
    _T set ["deck", _deck];
    _T set ["community", []];
    _T set ["pot", 0];
    _T set ["ghosts", []];
    _T set ["winners", []];
    _T set ["msg", ""];

    {
        private _s = _seats select _x;
        _s set ["bet", 0]; _s set ["committed", 0]; _s set ["folded", false];
        _s set ["allin", false]; _s set ["acted", false]; _s set ["lastAct", ""];
        _s set ["inHand", true]; _s set ["hole", []];
    } forEach _eligible;
    // Anyone who sat down mid-hand, or is sat there broke, is present but not dealt in.
    { if (_x isNotEqualTo [] && {!(_forEachIndex in _eligible)}) then {
        _x set ["inHand", false]; _x set ["hole", []]; _x set ["bet", 0];
        _x set ["committed", 0]; _x set ["folded", false]; _x set ["allin", false]; _x set ["lastAct", ""];
    } } forEach _seats;

    // Move the button to the next seat that is actually in this hand.
    private _d = _T get "dealer";
    private _nd = _d;
    for "_k" from 1 to H_SEATS do {
        private _i = (_d + _k) mod H_SEATS;
        if (_nd isEqualTo _d && {_i in _eligible}) then { _nd = _i };
    };
    if !(_nd in _eligible) then { _nd = _eligible select 0 };
    _T set ["dealer", _nd];

    // HEADS-UP IS THE EXCEPTION AND IT IS THE ONE PEOPLE GET WRONG: with two players the BUTTON
    // posts the small blind and acts FIRST before the flop, then LAST on every street after it.
    // With three or more the small blind is the seat left of the button, as normal.
    private _ring = [];
    for "_k" from 1 to H_SEATS do { private _i = (_nd + _k) mod H_SEATS; if (_i in _eligible) then { _ring pushBack _i } };
    private _sbSeat = if ((count _eligible) isEqualTo 2) then { _nd } else { _ring select 0 };
    private _bbSeat = if ((count _eligible) isEqualTo 2) then { _ring select 0 } else { _ring select 1 };

    private _post = {
        params ["_i", "_amt", "_tag"];
        private _s = _seats select _i;
        private _pay = _amt min (_s get "stack");
        _s set ["stack", (_s get "stack") - _pay];
        _s set ["bet", _pay];
        _s set ["committed", _pay];
        _s set ["lastAct", _tag];
        if ((_s get "stack") isEqualTo 0) then { _s set ["allin", true] };
    };
    [_sbSeat, _SB, "SB"] call _post;
    [_bbSeat, _BB, "BB"] call _post;
    // The LEVEL is the nominal big blind even when the poster could not cover it -- everyone else
    // still has to put a full blind in to play.
    _T set ["bet", _BB];
    _T set ["lastRaise", _BB];

    // Dealt in ring order, two rounds, starting left of the button -- the way a dealer does it. The
    // deck is already shuffled so it changes no odds; it changes what the deck order says in a log.
    { private _s = _seats select _x; _s set ["hole", [call _draw]] } forEach _ring;
    { private _s = _seats select _x; _s set ["hole", ((_s get "hole") + [call _draw])] } forEach _ring;

    _T set ["stage", "pre"];
    _T set ["nextAt", 0];
    private _a = [_bbSeat] call _nextToAct;
    _T set ["acting", _a];
    _T set ["deadline", if (_a > -1) then { diag_tickTime + (_ACTMS / 1000) } else { 0 }];
    if (_a < 0) then { call _advance };
    diag_log format ["[HOLDEM] hand #%1 dealt, %2 seats, button %3", _T get "handId", count _eligible, _nd];
};

// ── apply one legal action. Legality is decided by the caller; this moves chips. ──
private _apply = {
    params ["_i", "_act", "_raiseTo"];
    private _s = _seats select _i;
    private _lvl = _T get "bet";
    private _owed = (_lvl - (_s get "bet")) max 0;

    switch (_act) do {
        case "fold": { _s set ["folded", true]; _s set ["lastAct", "FOLD"]; _s set ["acted", true] };
        case "check": { _s set ["lastAct", "CHECK"]; _s set ["acted", true] };
        case "call": {
            private _pay = _owed min (_s get "stack");
            _s set ["stack", (_s get "stack") - _pay];
            _s set ["bet", (_s get "bet") + _pay];
            _s set ["committed", (_s get "committed") + _pay];
            if ((_s get "stack") isEqualTo 0) then { _s set ["allin", true]; _s set ["lastAct", "ALL IN"] }
            else { _s set ["lastAct", "CALL"] };
            _s set ["acted", true];
        };
        case "raise";
        case "allin": {   // both resolve to a street TOTAL, which is the page's raiseTo
            private _target = _raiseTo min ((_s get "bet") + (_s get "stack"));
            private _pay = (_target - (_s get "bet")) max 0;
            _s set ["stack", (_s get "stack") - _pay];
            _s set ["bet", _target];
            _s set ["committed", (_s get "committed") + _pay];
            if ((_s get "stack") isEqualTo 0) then { _s set ["allin", true] };
            if (_target > _lvl) then {
                private _inc = _target - _lvl;
                _T set ["bet", _target];
                // A SHORT ALL-IN DOES NOT REOPEN THE BETTING. Standard rule: only a raise of at
                // least the last full raise gives players who have already acted a fresh option.
                if (_inc >= (_T get "lastRaise")) then {
                    _T set ["lastRaise", _inc];
                    { if (_x isNotEqualTo [] && {_forEachIndex isNotEqualTo _i}) then { _x set ["acted", false] } } forEach _seats;
                };
            };
            _s set ["lastAct", if (_s get "allin") then { "ALL IN" } else { format ["RAISE $%1", _target] }];
            _s set ["acted", true];
        };
        default {};
    };

    // After the action: does the hand end, does the street end, or is it somebody's turn?
    if ((count (call _liveIdx)) < 2) exitWith { call _advance };
    private _next = [_i] call _nextToAct;
    if (_next < 0) then { call _advance }
    else {
        _T set ["acting", _next];
        _T set ["deadline", diag_tickTime + (_ACTMS / 1000)];
    };
};

// ── stand a player up. Folds first if they are in a hand: the chips they have already committed
// stay in the pot (that is what committed MEANS), only the remaining stack goes back to a bank.
private _stand = {
    params ["_i", "_why", ["_offline", false]];
    private _s = _seats select _i;
    if (_s isEqualTo []) exitWith {};
    private _wasActing = (_T get "acting") isEqualTo _i;
    private _wasLive = (_s get "inHand") && {!(_s get "folded")};
    if (_wasLive) then { _s set ["folded", true]; _s set ["lastAct", "FOLD"]; _s set ["acted", true] };
    // Live street chips are collected before the seat goes, or they vanish from the pot.
    if ((_s get "bet") > 0) then { _T set ["pot", (_T get "pot") + (_s get "bet")]; _s set ["bet", 0] };
    // …and everything they had already committed becomes a ghost, so the side-pot layers still add
    // up to the pot after the seat itself is gone. This is the whole reason _buildPots takes a
    // contributor list rather than reading the seats. The ghost carries the UID and the unit as well
    // as the amount (I-5): an uncontested layer has to be refundable to the person who paid for it,
    // and a bare number is not refundable to anybody.
    if ((_s get "committed") > 0) then {
        private _gh = _T getOrDefault ["ghosts", []];
        _gh pushBack [(_s get "committed"), (_s get "uid"), (_s get "obj")];
        _T set ["ghosts", _gh];
        _s set ["committed", 0];
    };

    // I-4. THE SEAT IS CLEARED BEFORE A SINGLE CHIP MOVES, and the movement is the LAST thing this
    // function does. The shipped order was cash-out then wipe, which was survivable while the credit
    // was a fire-and-forget MP call -- but the credit is now a database round trip that can suspend,
    // and `leave` off the wire and `disconnect` off HandleDisconnect can resolve the same seat in the
    // same tick. Cash first and both of them read the same live stack and credit it twice. Seat
    // first and the second one re-enters here, finds [], and no-ops on the line above.
    private _stack = _s get "stack";
    private _uidFor = _s get "uid";
    // _offline forces the credit down the uid-only arm even when a unit is still resolvable: the
    // disconnect case is standing up a player whose object is being deleted around us, and the drain
    // may be emptying a seat whose owner is on a loading screen.
    private _objFor = if (_offline) then { objNull } else { _s get "obj" };
    _seats set [_i, []];
    diag_log format ["[HOLDEM] seat %1 stands (%2), $%3 owed", _i, _why, _stack];

    if (_wasLive) then {
        if ((count (call _liveIdx)) < 2) then { call _advance }
        else {
            if (_wasActing) then {
                private _next = [_i] call _nextToAct;
                if (_next < 0) then { call _advance }
                else { _T set ["acting", _next]; _T set ["deadline", diag_tickTime + (_ACTMS / 1000)] };
            };
        };
    } else {
        if ((count (call _occupiedWithChips)) < 2 && {(_T get "stage") isEqualTo "wait"}) then { _T set ["nextAt", 0] };
    };

    // …and the money last, with every table mutation -- including a settle that _advance may have
    // run -- already complete. Same rule as _settle's own deferred flush.
    [_objFor, _uidFor, _stack, _why] call _cash;
};

// ── the drain. C-1(b): empty the table and put every chip back where it came from ──
// AP_holdemTable IS MEMORY AND NOTHING ELSE. A stack sitting on a seat when the process dies is
// money that came out of a real `players.bankacc` row and now exists nowhere -- the players' side of
// a restart that "just" loses a table. This is the counterpart of the kill-switch: a restart is
// announced, so there is somewhere to put it.
//
// A DRAIN ABORTS THE HAND; IT DOES NOT SETTLE IT. Nobody wins an aborted pot, so no board is run, no
// hand is ranked and no pot is shared: every chip committed to the live hand is REFUNDED to whoever
// committed it (each contributor gets back exactly what they put in -- with no ranking there is
// nothing to share and nothing pro-rata to decide), and then the remaining stack is cashed out.
// Two movements per seat, two `log` rows, because they are two different things: one undoes a bet
// that will never be resolved, the other closes an account.
//
// OFFLINE-CAPABLE BY CONSTRUCTION, which is the requirement that shaped it. _cash addresses a UID
// and _bankMove is a plain UPDATE ... WHERE playerid, so a seat whose unit is objNull -- already
// disconnected, or mid-loading-screen -- banks by exactly the same path as one stood at the felt.
// There is no arm here that needs a unit.
private _drain = {
    params [["_why", "table drained", [""]]];
    // EVERYTHING IS COMPUTED AND THE TABLE IS TORN DOWN BEFORE THE FIRST BANK WRITE. The writes
    // suspend; a half-emptied table that a tick could walk into is the one state this must not have.
    private _owed = [];                          // [uid, obj, amount, reason]
    private _chips = _T get "pot";               // every chip on the felt: collected pot…
    {
        private _i = _forEachIndex;
        if (_x isNotEqualTo []) then {
            _chips = _chips + (_x get "stack") + (_x get "bet");     // …plus stacks and live street bets
            private _uidFor = _x get "uid";
            private _objFor = _x get "obj";
            // committed is the seat's WHOLE contribution to this hand and already contains its live
            // `bet`, so the refund is committed + stack and never committed + bet + stack. The
            // identity that makes the conservation check below hold is
            //     sum(committed) + sum(ghosts) == pot + sum(bets).
            private _c = _x get "committed";
            if (_c > 0) then { _owed pushBack [_uidFor, _objFor, _c, format ["refund, hand aborted (%1)", _why]] };
            private _st = _x get "stack";
            if (_st > 0) then { _owed pushBack [_uidFor, _objFor, _st, _why] };
            _seats set [_i, []];
        };
    } forEach _seats;
    // Ghosts are chips committed by somebody who already stood up mid-hand. They are inside `pot`
    // and, once the hand is aborted, they are nobody's to win -- so they go home too. This is the
    // second reason a ghost carries its uid.
    {
        _x params [["_gAmt", 0], ["_gUid", ""], ["_gObj", objNull]];
        if (_gAmt > 0) then { _owed pushBack [_gUid, _gObj, _gAmt, format ["refund, hand aborted (%1)", _why]] };
    } forEach (_T getOrDefault ["ghosts", []]);

    _T set ["ghosts", []];
    _T set ["pot", 0];
    _T set ["community", []];
    _T set ["deck", []];
    _T set ["winners", []];
    _T set ["stage", "wait"];
    _T set ["acting", -1];
    _T set ["deadline", 0];
    _T set ["nextAt", 0];
    _T set ["bet", 0];
    _T set ["lastRaise", _BB];
    _T set ["msg", toUpper (format ["TABLE CLOSED — %1. EVERY CHIP HAS BEEN BANKED.", _why])];

    private _sum = 0;
    { _sum = _sum + (_x select 2) } forEach _owed;
    // THE DRAIN'S OWN CONSERVATION CHECK, and it is the one that matters most: this is the path that
    // runs when nobody is watching. Log-don't-halt, plus a `log` row (M-6) -- refusing to refund
    // because the arithmetic disagreed would turn a discrepancy into a total loss.
    if (_sum isNotEqualTo _chips) then {
        diag_log format ["[HOLDEM] !! CONSERVATION drain hand #%1: $%2 on the table but $%3 refunded", _T get "handId", _chips, _sum];
        ["-CASINO-HOLDEM-", objNull, format ["CONSERVATION-FAIL drain hand #%1 delta $%2 (table $%3, refunds $%4)", _T get "handId", _sum - _chips, _chips, _sum]] call APS_fnc_logIt;
    };

    { _x params ["_dUid", "_dObj", "_dAmt", "_dWhy"]; [_dObj, _dUid, _dAmt, _dWhy] call _cash; } forEach _owed;
    diag_log format ["[HOLDEM] DRAIN (%1): %2 movements, $%3 returned", _why, count _owed, _sum];
    ["-CASINO-HOLDEM-", objNull, format ["DRAIN (%1): %2 movements, $%3 returned (hand #%4)", _why, count _owed, _sum, _T get "handId"]] call APS_fnc_logIt;
};

// ── the pump. Runs before every case, so the table self-heals off any interaction ──
private _pump = {
    // A CLOSED TABLE HAS NO CLOCK AND DEALS NOTHING. The drain has already emptied it by the time
    // anything gets here, so this is what stops the wait arm dealing a fresh hand into it.
    if (!_ENABLED) exitWith {};
    private _stage = _T get "stage";
    private _tnow = diag_tickTime;

    // A finished hand rests, then the next one deals. Busted seats leave first: a stack of zero has
    // nothing to bank, so this is a seat removal and not a money movement.
    if (_stage isEqualTo "showdown" && {(_T get "nextAt") > 0} && {_tnow >= (_T get "nextAt")}) then {
        {
            private _i = _forEachIndex;
            // …and NOT a seat that is only holding a place while its buy-in is confirmed with the
            // database. A reservation carries a zero stack on purpose (see case "sit"), which is
            // exactly the test this sweep uses, so it has to be told the difference.
            if (_x isNotEqualTo [] && {(_x get "stack") <= 0} && {!(_x getOrDefault ["pending", false])}) then {
                ["-CASINO-HOLDEM-", (_x get "obj"), format ["BUSTED seat %1 (hand #%2)", _i, _T get "handId"]] call APS_fnc_logIt;
                _seats set [_i, []];
            };
        } forEach _seats;
        _T set ["winners", []];
        _T set ["msg", ""];
        _T set ["stage", "wait"];
        // _tnow, not 0: the rest pause has already been served, so the wait arm below deals at once
        // instead of adding its own two seconds on top of SRV_holdemNextMs.
        _T set ["nextAt", _tnow];
        _stage = "wait";
    };

    if (_stage isEqualTo "wait") then {
        if ((count (call _occupiedWithChips)) >= 2) then {
            if ((_T get "nextAt") isEqualTo 0) then { _T set ["nextAt", _tnow + 2] }
            else { if (_tnow >= (_T get "nextAt")) then { call _startHand } };
        } else {
            _T set ["nextAt", 0];
        };
    } else {
        // The turn clock. Free -> check; otherwise fold. A player who is not there does not get to
        // hold five other people up, and folding is the only safe default when chips are owed.
        private _a = _T get "acting";
        if (_a > -1 && {(_T get "deadline") > 0} && {_tnow >= (_T get "deadline")}) then {
            private _s = _seats select _a;
            if (_s isEqualTo []) then { call _advance }
            else {
                private _owed = ((_T get "bet") - (_s get "bet")) max 0;
                diag_log format ["[HOLDEM] seat %1 timed out (owed $%2)", _a, _owed];
                [_a, (if (_owed <= 0) then { "check" } else { "fold" }), 0] call _apply;
            };
        };
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// C-1(a). THE KILL-SWITCH IS CHECKED ON EVERY ENTRY, and a flag that went false with chips still on
// the felt drains ONCE -- on the scheduler's next tick a second later, or on the very next thing
// anybody does if the wheel has auto-disabled the job. `drained` is cleared the moment the flag
// comes back, so re-opening the table does not re-drain an empty one, and flipping it off twice does
// not double-refund.
// This is a LOCAL call to _drain rather than a re-entrant ["drain"] call into this file: inside a
// case that arrived from the wire, remoteExecutedOwner still reads that client's owner id, so the
// re-entry would be refused by its own server-local assertion.
if (!_ENABLED) then {
    if !(_T getOrDefault ["drained", false]) then {
        _T set ["drained", true];
        // SRV_holdemCloseReason is what the players read on the felt as their chips leave it, so the
        // restart hooks set it before they flip the flag. Defaulted, because the lever is also a
        // debug-console one-liner and a bare `SRV_holdemEnabled = false` has to work on its own.
        [missionNamespace getVariable ["SRV_holdemCloseReason", "the table is closed"]] call _drain;
        call _pushAll;
    };
} else {
    _T set ["drained", false];
};
// sit / act / open refuse while it is closed. leave and close are deliberately NOT gated: a player
// must always be able to get up, and after a drain there is nothing left to get up from anyway.
if (!_ENABLED && {_c in ["sit", "act", "open"]}) exitWith {
    ["THE TABLE IS CLOSED"] call _refuse;
};

private _before = _T get "handId";
call _pump;

switch (_c) do {

    case "tick": {
        // _pump above IS the tick. A push only goes out when something actually moved, or six
        // clients would take a full table snapshot every second for nothing.
        if ((_T get "handId") isNotEqualTo _before || {(_T get "stage") isNotEqualTo (_T getOrDefault ["lastPushedStage", ""])}
            || {(_T get "acting") isNotEqualTo (_T getOrDefault ["lastPushedActing", -2])}) then {
            _T set ["lastPushedStage", _T get "stage"];
            _T set ["lastPushedActing", _T get "acting"];
            call _pushAll;
        };
    };

    case "expire": {
        // tick's arm, exposed so a stuck turn can be forced by hand on dev. _pump already ran it
        // if the clock was actually out; this makes it unconditional.
        private _a = _T get "acting";
        if (_a > -1) then {
            private _s = _seats select _a;
            if (_s isNotEqualTo []) then {
                private _owed = ((_T get "bet") - (_s get "bet")) max 0;
                [_a, (if (_owed <= 0) then { "check" } else { "fold" }), 0] call _apply;
                call _pushAll;
            };
        };
    };

    case "open": {
        private _v = _T get "viewers";
        if !(_caller in _v) then { _v pushBack _caller; _T set ["viewers", _v] };
        // A reconnect keeps the seat but arrives as a NEW unit; the stored object is what every
        // push targets, so refresh it before the first one goes out.
        private _mine = [_uid] call _seatOf;
        if (_mine > -1) then { (_seats select _mine) set ["obj", _caller] };
        [["table", ([_uid] call _snap)], "AP_fnc_holdemReceive", _caller, false] spawn AP_fnc_MP;
    };

    case "close": {
        _T set ["viewers", (_T get "viewers") - [_caller]];
        // CLOSING THE VIEW LEAVES THE TABLE. A seated player who cannot see the table cannot act on
        // it, so keeping the seat would hold five other people on a 20 s clock every orbit -- the
        // same reason DEALERBOT'S TABLE drops the seat on unwatch. hLeave's own contract (the
        // stack banks) is what happens, fold included, so nothing is lost by it being automatic.
        private _mine = [_uid] call _seatOf;
        if (_mine > -1) then { [_mine, "dialog closed"] call _stand };
        call _pushAll;
    };

    case "sit": {
        private _seat = _data param [0, -1, [0]];
        private _amt  = round (_data param [1, 0, [0]]);
        if !(_seat isEqualType 0 && {_seat >= 0} && {_seat < H_SEATS}) exitWith { ["NO SUCH SEAT"] call _refuse };
        if (!alive _caller) exitWith { ["YOU'RE IN NO STATE TO GAMBLE"] call _refuse };
        // Self-exclusion is the one gate the SERVER owns -- the same map and the same column
        // blackjack and APS_fnc_casinoSRV read. Everything else on AP_fnc_casinoData's gate is a
        // client-side fact (arrested, restrained, in combat) and is checked in the bridge, which
        // is the only machine that can see it.
        if ((!isNil "AP_bjBanned") && {AP_bjBanned getOrDefault [_uid, false]}) exitWith {
            ["-CASINOBAN-", _caller, "blocked holdem (self-excluded)"] call APS_fnc_logIt;
            ["YOU HAVE EXCLUDED YOURSELF FROM THE CASINO"] call _refuse;
        };
        if (([_uid] call _seatOf) > -1) exitWith { ["YOU ARE ALREADY SEATED"] call _refuse };
        if ((_seats select _seat) isNotEqualTo []) exitWith { ["SEAT TAKEN"] call _refuse };
        if (_amt < _MINBUY) exitWith { [format ["MINIMUM BUY-IN IS $%1", _MINBUY]] call _refuse };
        if (_amt > _MAXBUY) exitWith { [format ["MAXIMUM BUY-IN IS $%1", _MAXBUY]] call _refuse };

        // C-2. PAID FIRST, SEATED SECOND, AND NEVER THE OTHER WAY -- the inversion of what shipped.
        // The old order granted the seat and then ORDERED the player's client to debit itself, so a
        // client that dropped the order (a modified one, or one that crashed in the round trip) sat
        // down with a real stack it had not paid for, and the DEBIT row went into `log` regardless.
        // Chips now exist only after the bank has confirmed the money is gone.
        //
        // THE RESERVATION IS WHAT MAKES THE INVERSION SAFE. _bankMove goes to the database, and this
        // file is entered from the scheduler wheel in a SCHEDULED context as well as from the wire in
        // an unscheduled one -- so the round trip may suspend, and a seat that was free before it is
        // not necessarily free after it. A reservation is occupied for _seatOf and for the SEAT TAKEN
        // test, so nobody else can take it and this player cannot take a second one; it carries a
        // ZERO STACK, so _occupiedWithChips skips it and no hand can deal it in mid-payment. The one
        // thing that also reads a zero stack -- _pump's busted-seat sweep -- is taught about
        // "pending" for exactly this.
        _seats set [_seat, createHashMapFromArray [
            ["uid", _uid], ["name", ((name _caller) splitString "<>&""'") joinString ""], ["obj", _caller],   // every viewer's page prints this; no markup
            ["stack", 0], ["bet", 0], ["committed", 0],
            ["folded", false], ["allin", false], ["inHand", false],
            ["hole", []], ["lastAct", ""], ["acted", false], ["pending", true]
        ]];

        private _mv = [_uid, -_amt, "buy-in"] call _bankMove;
        if !(_mv param [0, false]) exitWith {
            // Nothing was granted and nothing moved. _bankMove refuses an unbacked debit BEFORE it
            // writes, so this is not a debit that has to be unwound -- it is a sit that did not
            // happen, and the only trace is the refusal.
            _seats set [_seat, []];
            private _bal = _mv param [1, 0];
            if (_bal < _amt) then { [format ["NOT ENOUGH IN THE BANK — YOU HAVE $%1", _bal]] call _refuse }
            else { ["THE BANK DID NOT ANSWER — TRY AGAIN"] call _refuse };
            // NO _pushAll behind a _refuse, here or anywhere. _refuse IS a push -- a snapshot built
            // for this one viewer with the reason in `msg` -- and a plain _pushAll landing after it
            // overwrites that snapshot with one whose msg is the table's, wiping the refusal off the
            // strip before the player reads it. The seat is exactly as it was, so nobody else needs
            // telling anything.
        };

        // The money is confirmed gone. Before it becomes chips, check the reservation is still ours:
        // a disconnect or a drain that landed during the round trip would have torn the seat down,
        // and seating into a hashmap that is no longer there is a runtime error on top of a debit.
        private _s = _seats select _seat;
        if (_s isEqualTo [] || {(_s get "uid") isNotEqualTo _uid} || {!(_s getOrDefault ["pending", false])}) exitWith {
            [_caller, _uid, _amt, "buy-in reversed (the seat was gone when the bank answered)"] call _cash;
            diag_log format ["[HOLDEM] seat %1 reservation lost mid-buy-in for %2 -- $%3 returned", _seat, _uid, _amt];
            ["THE SEAT WAS TAKEN DOWN WHILE THE BANK ANSWERED — YOUR BUY-IN WAS RETURNED"] call _refuse;
        };
        _s set ["stack", _amt];
        _s set ["pending", false];

        private _v = _T get "viewers";
        if !(_caller in _v) then { _v pushBack _caller; _T set ["viewers", _v] };
        diag_log format ["[HOLDEM] %1 sat seat %2 for $%3", _uid, _seat, _amt];
        call _pump;             // two seats with chips means a hand is now due
        call _pushAll;
    };

    case "leave": {
        private _mine = [_uid] call _seatOf;
        if (_mine < 0) exitWith { ["YOU ARE NOT SEATED"] call _refuse };
        [_mine, "left the table"] call _stand;
        call _pushAll;
    };

    case "act": {
        private _act = toLower (_data param [0, "", [""]]);
        private _raiseTo = round (_data param [1, 0, [0]]);
        if !(_act in ["fold", "check", "call", "raise", "allin"]) exitWith { ["NO SUCH ACTION"] call _refuse };

        private _mine = [_uid] call _seatOf;
        if (_mine < 0) exitWith { ["YOU ARE NOT SEATED"] call _refuse };
        if !((_T get "stage") in ["pre", "flop", "turn", "river"]) exitWith { ["THE HAND IS NOT LIVE"] call _refuse };
        if ((_T get "acting") isNotEqualTo _mine) exitWith { ["IT IS NOT YOUR TURN"] call _refuse };

        private _s = _seats select _mine;
        if (!(_s get "inHand")) exitWith { ["YOU ARE NOT IN THIS HAND"] call _refuse };
        if (_s get "folded") exitWith { ["YOU HAVE FOLDED"] call _refuse };
        if (_s get "allin") exitWith { ["YOU ARE ALL IN"] call _refuse };

        private _lvl = _T get "bet";
        private _owed = (_lvl - (_s get "bet")) max 0;
        private _shove = (_s get "bet") + (_s get "stack");

        switch (_act) do {
            case "check": { if (_owed > 0) exitWith { [format ["YOU OWE $%1 — CALL OR FOLD", _owed]] call _refuse; _act = "" } };
            case "call":  { if (_owed <= 0) exitWith { _act = "check" } };   // a call with nothing owed IS a check
            case "allin": { if ((_s get "stack") <= 0) exitWith { ["YOU HAVE NO CHIPS"] call _refuse; _act = "" } };
            case "raise": {
                if ((_s get "stack") <= 0) exitWith { ["YOU HAVE NO CHIPS"] call _refuse; _act = "" };
                if (_raiseTo >= _shove) exitWith { _act = "allin"; _raiseTo = _shove };
                if (_raiseTo <= _lvl) exitWith { [format ["A RAISE MUST BEAT $%1", _lvl]] call _refuse; _act = "" };
                // The minimum re-raise is the last full raise. Only a shove is allowed to be short,
                // and it is handled above -- so anything reaching here that is under the minimum is
                // a page that is out of date or a client that is lying.
                if ((_raiseTo - _lvl) < (_T get "lastRaise")) exitWith {
                    [format ["MINIMUM RAISE IS TO $%1", _lvl + (_T get "lastRaise")]] call _refuse; _act = "";
                };
            };
        };
        // I-3. THE RE-RAISE BAR OFF A SHORT ALL-IN, checked AFTER the switch above has normalised
        // _act -- a "raise" for the player's whole stack has become "allin" by this point, and it
        // has to be judged as what it actually is.
        //
        // TDA Rule 45 (Methods of Raising / Reopening the Betting), and the same rule in RRoP 15:
        //     "An all-in wager of less than a full raise does not reopen the betting to a player
        //      who has already acted and is not facing a full raise."
        // A player facing one may CALL or FOLD. They may not raise -- and their own all-in for more
        // than the current level IS a raise, so that is barred too; an all-in for the level or less
        // is a call for what they have and stays legal.
        //
        // The test is `acted`, and it is exact rather than a proxy. _apply clears `acted` on everyone
        // else only when the increment was at least the last full raise; _nextToAct returns a player
        // whose `acted` is still true only when they are short of the level. So `acted == true` at
        // your own turn means precisely "you have already acted this street and the betting was not
        // reopened to you" -- which is the rule's own condition, word for word.
        if ((_s get "acted") && {(_act isEqualTo "raise") || {(_act isEqualTo "allin") && {_shove > _lvl}}}) exitWith {
            [format ["BETTING IS NOT REOPENED TO YOU — CALL $%1 OR FOLD", _owed]] call _refuse;
        };

        if (_act isEqualTo "") exitWith {};   // refused above; the refusal push already went out

        if (_act isEqualTo "allin") then { _raiseTo = _shove };
        [_mine, _act, _raiseTo] call _apply;
        call _pushAll;
    };

    case "drain": {
        // C-1(b), the deliberate lever. Server-local, and CALLed -- never remoteExec'd -- for the
        // same reason "disconnect" is: it moves six other people's money at once.
        // Wired at the places a restart is actually announced on this codebase; see server_init.sqf's
        // SRV_holdemEnabled block for the list and the deploy procedure.
        // THE SAME LATCH THE FLAG USES. A restart hook flips SRV_holdemEnabled and then calls here,
        // and the flip alone already drained the table on the way into this file -- so without the
        // latch every restart would log a second, empty drain pass. It self-clears on any entry made
        // while the table is open, so an explicit drain of a LIVE table still works and still leaves
        // the table able to drain again when it is later closed.
        if (_T getOrDefault ["drained", false]) exitWith { diag_log "[HOLDEM] drain: the table is already empty"; };
        _T set ["drained", true];
        [_data param [0, "table drained", [""]]] call _drain;
        call _pushAll;
    };

    case "disconnect": {
        // CALLed locally from fn_playerDisconnected, never remoteExec'd -- the duty precedent, and
        // the reason the origin assert above insists on owner 0: allowedTargets = 2 restricts the
        // TARGET, so a wire-reachable "disconnect" would let any client stand any player up.
        private _duid = _data param [0, "", [""]];
        if (_duid isEqualTo "") exitWith {};
        private _mine = [_duid] call _seatOf;
        if (_mine < 0) exitWith {};
        private _s = _seats select _mine;
        _T set ["viewers", (_T get "viewers") - [_s get "obj"]];
        // The unit is being deleted around us, so there is no client cache left to sync -- the
        // `players` row IS the balance until they log in again. _stand's third argument forces the
        // uid-only arm rather than this case reaching in and nulling the seat's stored object, which
        // the drain and the reservation checks both read.
        [_mine, "disconnected", true] call _stand;
        call _pushAll;
    };
};
