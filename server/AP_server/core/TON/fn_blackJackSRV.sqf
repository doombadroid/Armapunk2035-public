/*
    APS_fnc_blackJackSRV  (LooneyBin -- Casino phone app, blackjack. SERVER-AUTHORITATIVE.)
    Client dispatcher: mission core/casino/fn_blackJack.sqf (dialog) sends only the player's INTENT
    (deal/hit/stand/double/split); this server fn owns the shuffle, the deal, the dealer AI, and the
    payout amount. The player's hand STATE lives here (AP_bjGames, keyed by uid) -- the client only
    renders what the server tells it, so a client can't forge a hand, re-deal until it wins, or claim a
    win. CfgRE: this fn is allowedTargets=2 (client->server). The result callbacks (AP_fnc_blackJack
    render / AP_fnc_blackJackReceive credit) are server->client = exempt from mode=1.

    MONEY MODEL (security.md §2.4 + gambling.md §8): AP_atmcash is a CLIENT cache; the client debits the
    bet locally BEFORE each deal/double/split (it can't be server-enforced -- same limit as all LB cash).
    So the server NETS the game: it only ever CREDITS the server-computed return (bet back + winnings) via
    the owner-2-gated receiver, NEVER echoes a bet, and LOGS every game's net so CLANKR mass-balances
    wager-in vs payout-out (the compensating control). A cheater who skips the client debit shows up as
    anomalous casino net-gain -> CLANKR.

    Owner spec 2026-07-05/06: BANK-funded, bet $10k-$500k (blackjack pays 3:2, dealer stands on
    17 incl. soft-17), full actions (hit/stand/double/split, up to 4 hands). Playable except jailed/
    restrained/downed/in-combat (client-gated in the dialog; the server just runs the game).

    PROTOCOL (client -> APS_fnc_blackJackSRV, target 2):
      ["deal",  [_bet]]   start a hand (client already debited _bet)
      ["hit",   []]       hit the active hand
      ["stand", []]       stand the active hand
      ["double",[]]       double the active hand (client already debited another equal bet); 1 card, auto-stand
      ["split", []]       split the active hand (client already debited another base bet)
      ["quit",  []]       abandon (forfeits the in-progress bet; no payout) -- e.g. dialog closed

    RESULT (server -> client):
      ["render", _view] -> AP_fnc_blackJack   (draw the table; _view below)
      [_return, _summary] -> AP_fnc_blackJackReceive   (owner-2-gated: AP_atmcash += _return)

    _view = [ _handsView, _dealerView, _activeIdx, _actions, _phase ]
      _handsView  = [[cardNames, bet, statusStr, value], ...]     (statusStr: active/stood/busted/blackjack/win/lose/push)
      _dealerView = [cardNames, shownValue]                       (hole card = "backside" until reveal; shownValue=-1 hidden)
      _actions    = [canHit, canStand, canDouble, canSplit]       (for the active hand; all false when resolved)
      _phase      = "player" | "resolved"

    GAME STATE  AP_bjGames get _uid = [_deck, _hands, _dealer, _activeIdx, _phase, _baseBet]
      _hand = [_cards, _bet, _status, _doubled, _splitAce]        (_status: "active"/"stood"/"busted"/"done")
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];

private _MIN_BET  = 10000;
private _MAX_BET  = 500000;
private _MAX_HANDS = 4;

// ── identity (non-spoofable): derive the actor from remoteExecutedOwner, never from the payload ──
private _src = remoteExecutedOwner;
if (_src isEqualTo 0) exitWith {};                         // no server-internal path -- every case is player-driven
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};                          // spoofed / vanished caller
private _uid = getPlayerUID _caller;
if (_uid isEqualTo "") exitWith {};

if (isNil "AP_bjGames") then { AP_bjGames = createHashMap; };

// -- OWNER-MODE RIG (secret; NOT in patchnotes) -- owner's FIRST blackjack this session = instant natural 21.
// Shared session map with the other casino games (key "blackjack"); owner-UID gated (server-derived).
private _OWNER_UID = "76561190000000001";
if (isNil "AP_casinoOwnerRig") then { AP_casinoOwnerRig = createHashMap; };
private _rigFirst = {params ["_g"];
    if (_uid isNotEqualTo _OWNER_UID) exitWith { false };
    if (AP_casinoOwnerRig getOrDefault [_g, false]) exitWith { false };
    AP_casinoOwnerRig set [_g, true];
    true};

// ── anti-spam: light per-uid action cooldown (a human can't click faster than ~4/s; blocks auto-clickers) ──
private _cdVar = format ["AP_bjCD_%1", _uid];
private _now = diag_tickTime;
// owner 2026-07-08: exempt "quit" too (was "ban" only). A quit fired <0.20s after the last action was being
// DROPPED here, orphaning AP_bjGames[uid] -> the next deal silently exitWith'd and ate the bet, table frozen.
if (!(_caseType in ["ban","quit"]) && {(_now - (missionNamespace getVariable [_cdVar, -999])) < 0.20}) exitWith {};   // "ban" is a persistence write, "quit" is a teardown -- never anti-spam-drop them
// owner 2026-07-08: only STAMP the clock for throttled actions -- a terminal quit/ban must not reset it, else the
// next "deal" (fresh client-debited bet) is the one silently dropped (eaten bet, frozen table).
if (!(_caseType in ["ban","quit"])) then { missionNamespace setVariable [_cdVar, _now]; };

// ── card / value helpers ──
private _cardName = {   // int 0..51 -> "H10","SA",... matching images\casino\<name>.paa
    params ["_c"];
    (["C","D","H","S"] select (floor (_c / 13))) + (["2","3","4","5","6","7","8","9","10","J","Q","K","A"] select (_c mod 13))};
private _handVal = {   // best value: aces 11 then reduced to 1 while > 21
    params ["_cards"];
    private _sum = 0; private _aces = 0; {private _r = _x mod 13;
        if (_r isEqualTo 12) then { _sum = _sum + 11; _aces = _aces + 1; }
        else { _sum = _sum + ((_r + 2) min 10); };} forEach _cards;
    while { _sum > 21 && _aces > 0 } do { _sum = _sum - 10; _aces = _aces - 1; };
    _sum};
private _cardVal10 = { params ["_c"]; private _r = _c mod 13; if (_r isEqualTo 12) then {11} else {(_r + 2) min 10} };  // for split-eligibility (equal value)

// ── fetch the caller's game (may be nil) ──
private _game = AP_bjGames getOrDefault [_uid, []];

// forward-declared handles filled below (SQF: privates are visible to the {} blocks that call them)
private _fnRender  = {};
private _fnResolve = {};
private _fnAdvance = {};

// send the current table view to the client
_fnRender = {params ["_reveal"];   // true = show dealer hole + values (resolved)
    _game params ["_deck", "_hands", "_dealer", "_activeIdx", "_phase", "_baseBet"];
    private _handsView = _hands apply {_x params ["_cards", "_bet", "_status"];
        [(_cards apply { [_x] call _cardName }), _bet, _status, ([_cards] call _handVal)]};
    private _dealerView = if (_reveal) then {[(_dealer apply { [_x] call _cardName }), ([_dealer] call _handVal)]} else {
        // hole hidden: show first card + a backside
        [[([_dealer select 0] call _cardName), "backside"], -1]};
    private _actions = [false, false, false, false];
    if (_phase isEqualTo "player") then {private _h = _hands select _activeIdx;
        _h params ["_c", "_b", "_st", "_dbl", "_splitAce"];
        private _n = count _c;
        private _canDouble = (_n isEqualTo 2) && {!_splitAce};
        private _canSplit  = (_n isEqualTo 2) && {!_splitAce} && {(count _hands) < _MAX_HANDS}
                             && {([_c select 0] call _cardVal10) isEqualTo ([_c select 1] call _cardVal10)};
        _actions = [true, true, _canDouble, _canSplit];};
    [["render", [_handsView, _dealerView, _activeIdx, _actions, (if (_reveal) then {"resolved"} else {"player"})]],
        "AP_fnc_blackJack", _caller, false] spawn AP_fnc_MP;};

// dealer plays out + score every hand + credit + log + clear
_fnResolve = {_game params ["_deck", "_hands", "_dealer", "_activeIdx", "_phase", "_baseBet"];
    // dealer draws to 17 (stands on 17, incl. soft 17)
    while { ([_dealer] call _handVal) < 17 } do { _dealer pushBack (_deck deleteAt 0); };
    private _dVal = [_dealer] call _handVal;
    private _dealerBJ = (count _dealer isEqualTo 2) && {_dVal isEqualTo 21};
    private _dealerBust = _dVal > 21;

    private _totalReturn = 0;
    private _wagered = 0; {_x params ["_cards", "_bet", "_status", "_dbl", "_splitAce"];
        _wagered = _wagered + _bet;
        private _pVal = [_cards] call _handVal;
        private _natBJ = (count _cards isEqualTo 2) && {_pVal isEqualTo 21} && {!_splitAce} && {(count _hands) isEqualTo 1};
        private _ret = 0; private _res = "lose";
        if (_status isEqualTo "busted" || {_pVal > 21}) then { _ret = 0; _res = "lose"; }
        else {if (_natBJ) then {if (_dealerBJ) then { _ret = _bet; _res = "push"; }
                else { _ret = _bet + round (_bet * 1.5); _res = "blackjack"; };   // 3:2 (owner 2026-07-06: natural blackjack pays 1.5x)
            } else {if (_dealerBJ) then { _ret = 0; _res = "lose"; }
                else {if (_dealerBust || {_pVal > _dVal}) then { _ret = _bet * 2; _res = "win"; }
                    else {if (_pVal isEqualTo _dVal) then { _ret = _bet; _res = "push"; }
                        else { _ret = 0; _res = "lose"; };};};};};
        _x set [2, _res];
        _totalReturn = _totalReturn + _ret;} forEach _hands;

    private _net = _totalReturn - _wagered;
    ["-CASINOBJ-", _caller, format ["net $%1 (wagered $%2, returned $%3, hands %4, dealer %5)", _net, _wagered, _totalReturn, count _hands, _dVal]] call APS_fnc_logIt;

    _game set [4, "resolved"];
    [true] call _fnRender;                                  // reveal + show per-hand results
    if (_totalReturn > 0) then {[[_totalReturn], "AP_fnc_blackJackReceive", _caller, false] spawn AP_fnc_MP;};
    AP_bjGames deleteAt _uid;                               // game over -- clear server state
};

// advance to the next actionable hand; if none, dealer plays + resolve
_fnAdvance = {_game params ["_deck", "_hands", "_dealer", "_activeIdx", "_phase", "_baseBet"];
    private _next = -1;
    for "_i" from 0 to (count _hands) - 1 do {if (((_hands select _i) select 2) isEqualTo "active") exitWith { _next = _i; };};
    if (_next isEqualTo -1) then { call _fnResolve; }
    else { _game set [3, _next]; [false] call _fnRender; };};

switch (_caseType) do {

    // ── DEAL: validate bet, shuffle, deal, check naturals, else hand control to the player ──
    case "deal": {
        if ((!isNil "AP_bjBanned") && {AP_bjBanned getOrDefault [_uid, false]}) exitWith {   // self-excluded -> server refuses (defense-in-depth; the phone app is already gated client-side)
            ["-CASINOBAN-", _caller, "blocked deal (self-excluded)"] call APS_fnc_logIt;};
        if (_game isNotEqualTo [] && {(_game param [4,""]) isEqualTo "player"}) exitWith {};   // finish the hand in progress
        private _bet = round (_data param [0, 0]);
        if (_bet < _MIN_BET) exitWith {};
        _bet = _bet min _MAX_BET;

        // fresh single-deck shuffle each hand (no counting)
        private _deck = []; for "_i" from 0 to 51 do { _deck pushBack _i; };
        for "_i" from 51 to 1 step -1 do {private _j = floor random (_i + 1);
            private _t = _deck select _i; _deck set [_i, _deck select _j]; _deck set [_j, _t];};
        private _p = [_deck deleteAt 0, _deck deleteAt 0];
        private _dealer = [_deck deleteAt 0, _deck deleteAt 0];
        private _hands = [[_p, _bet, "active", false, false]];
        _game = [_deck, _hands, _dealer, 0, "player", _bet];
        AP_bjGames set [_uid, _game];

        if (["blackjack"] call _rigFirst) then {
            // owner first blackjack: natural 21 (Ace+10) vs a non-blackjack dealer -> instant win (3:2)
            _p = [12, 8];                                  // CA + C10 = 21
            _dealer = [0, 1];                              // C2 + C3 = 5 (not a blackjack)
            _hands = [[_p, _bet, "active", false, false]];
            _game = [_deck, _hands, _dealer, 0, "player", _bet];
            AP_bjGames set [_uid, _game];};

        ["-CASINOBET-", _caller, format ["$%1 blackjack deal", _bet]] call APS_fnc_logIt;

        private _pBJ = ([_p] call _handVal) isEqualTo 21;
        private _dBJ = ([_dealer] call _handVal) isEqualTo 21;
        if (_pBJ || {_dBJ}) then { call _fnResolve; }        // natural on either side -> settle now (dealer peek)
        else { [false] call _fnRender; };};

    // ── BAN: player self-excludes from the casino (Settings "Casino Ban"). _uid is server-derived (non-spoofable). ──
    case "ban": {if (isNil "AP_bjBanned") then { AP_bjBanned = createHashMap };
        AP_bjBanned set [_uid, true];
        AP_bjGames deleteAt _uid;                                        // abort any hand in progress
        private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };   // SQLi guard (asyncQuery is unparameterized) -- _uid is a Steam64 anyway
        [format ["UPDATE players SET casino_banned = true WHERE playerid='%1'", _uid call _san]] call DB_fnc_asyncQuery;
        ["-CASINOBAN-", _caller, "self-excluded from casino"] call APS_fnc_logIt;};

    // ── HIT ──
    case "hit": {if (_game isEqualTo [] || {(_game param [4,""]) isNotEqualTo "player"}) exitWith {};
        _game params ["_deck", "_hands", "_dealer", "_activeIdx"];
        private _h = _hands select _activeIdx;
        if ((_h select 2) isNotEqualTo "active") exitWith {};
        (_h select 0) pushBack (_deck deleteAt 0);
        if (([_h select 0] call _handVal) > 21) then { _h set [2, "busted"]; call _fnAdvance; }
        else { [false] call _fnRender; };};

    // ── STAND ──
    case "stand": {if (_game isEqualTo [] || {(_game param [4,""]) isNotEqualTo "player"}) exitWith {};
        _game params ["_deck", "_hands", "_dealer", "_activeIdx"];
        private _h = _hands select _activeIdx;
        if ((_h select 2) isNotEqualTo "active") exitWith {};
        _h set [2, "stood"];
        call _fnAdvance;};

    // ── DOUBLE: 2-card hand only, +1 card, auto-stand. Client already debited the extra bet. ──
    case "double": {if (_game isEqualTo [] || {(_game param [4,""]) isNotEqualTo "player"}) exitWith {};
        _game params ["_deck", "_hands", "_dealer", "_activeIdx"];
        private _h = _hands select _activeIdx;
        if ((_h select 2) isNotEqualTo "active" || {(count (_h select 0)) isNotEqualTo 2} || {_h select 4}) exitWith {};
        _h set [1, (_h select 1) * 2];                       // double the bet
        _h set [3, true];
        (_h select 0) pushBack (_deck deleteAt 0);
        if (([_h select 0] call _handVal) > 21) then { _h set [2, "busted"]; } else { _h set [2, "stood"]; };
        call _fnAdvance;};

    // ── SPLIT: 2 equal-value cards, < MAX hands. New hand = base bet. Split aces get 1 card + auto-stand. ──
    case "split": {if (_game isEqualTo [] || {(_game param [4,""]) isNotEqualTo "player"}) exitWith {};
        _game params ["_deck", "_hands", "_dealer", "_activeIdx", "_phase", "_baseBet"];
        private _h = _hands select _activeIdx;
        _h params ["_cards", "_bet", "_status", "_dbl", "_splitAce"];
        if (_status isNotEqualTo "active" || {(count _cards) isNotEqualTo 2} || {_splitAce}
            || {(count _hands) >= _MAX_HANDS}
            || {([_cards select 0] call _cardVal10) isNotEqualTo ([_cards select 1] call _cardVal10)}) exitWith {};
        private _isAce = (((_cards select 0) mod 13) isEqualTo 12);
        private _c2 = _cards deleteAt 1;                     // second card starts the new hand
        (_h select 0) pushBack (_deck deleteAt 0);           // deal to the first hand
        private _new = [[_c2, _deck deleteAt 0], _baseBet, "active", false, _isAce];   // and to the new hand
        _hands set [_activeIdx, _h];
        _hands insert [_activeIdx + 1, [_new]];              // keep play order
        if (_isAce) then {                                    // split aces: one card each, both auto-stand
            _h set [2, "stood"]; _h set [4, true];
            (_hands select (_activeIdx + 1)) set [2, "stood"];
            call _fnAdvance;} else {[false] call _fnRender;};};

    // ── QUIT: abandon the in-progress game (bet already debited client-side; no payout) ──
    case "quit": {if (_game isNotEqualTo []) then {
            ["-CASINOBJ-", _caller, format ["net $-%1 (abandoned in-progress blackjack)", _game param [5, 0]]] call APS_fnc_logIt;
            AP_bjGames deleteAt _uid;};};

    default { diag_log format ["[LooneyBin][blackjack] unhandled case: %1", _caseType]; };};
