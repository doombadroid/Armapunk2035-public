/*
    APS_fnc_bjTableSRV  (Armapunk 2035) -- DEALERBOT'S TABLE. The SHARED blackjack
    table: five seats, one shoe, one dealer, everybody watching the same cards.

    This is a different animal from APS_fnc_blackJackSRV, which stays exactly where
    it is. That one is solo and per-uid -- one player, one hand, state keyed by
    getPlayerUID. This one owns a TABLE that exists whether or not anyone is sat at
    it, runs a clock, and broadcasts the same snapshot to every viewer. The solo
    engine remains the fallback for an empty casino and is untouched.

    WHAT THE SERVER OWNS: the shoe, the shuffle, the deal, the dealer's draw, the
    shot clock, and every payout amount. A client sends INTENT and nothing else.
    There is no path by which a page can name a card, a total, or a return.

    MONEY MODEL -- unchanged from the solo engine and from the rest of the casino
    (security.md 2.4): AP_atmcash is a CLIENT cache, so the client debits its own
    bet before telling us. The server NEVER echoes a bet; it only ever credits the
    server-computed return through AP_fnc_blackJackReceive, which is gated on
    remoteExecutedOwner == 2. Every round's net is logged so CLANKR can mass-balance
    wagered-in against paid-out; that is the compensating control for the debit we
    cannot enforce.

    PROTOCOL (client -> here, CfgRE allowedTargets = 2):
        ["watch",  []]          register this client as a viewer (dialog opened)
        ["unwatch",[]]          drop it (dialog closed) -- also leaves the seat
        ["sit",    [_seat]]     take seat 0-4, between rounds only
        ["leave",  []]          give the seat up
        ["bet",    [_amt]]      place/replace this round's bet (client already debited)
        ["act",    [_action]]   "hit" | "stand" | "double" | "split"

    SNAPSHOTS (here -> client, AP_fnc_bjTable, allowedTargets = 1):
        ["table", _t]   the whole table, rebuilt per viewer because "you" differs
        ["you",   _y]   seat + powerup wallet
        ["event", _e]   theatre: deals, turns, DEALERBOT's lines

    NOT YET WIRED, deliberately, and the page degrades cleanly without them:
    powerups (the wallet loads and renders, chips cannot be played), the tiered
    drop roll, and bonus rounds. Both need the chip economy signed off before the
    server starts handing out consumables; APS_fnc_bjChips already owns the DB side.
*/

if (!isServer) exitWith {};
params [["_case", "", [""]], ["_data", [], [[]]]];

#define BJ_SEATS      5
#define BJ_MAX_HANDS  4
#define BJ_MIN_BET    10000
#define BJ_MAX_BET    500000
#define BJ_BET_SECS   15
#define BJ_ACT_SECS   20
#define BJ_SHOE_DECKS 6

// ── table state ──────────────────────────────────────────────────────────────
if (isNil "AP_bjTable") then {
    AP_bjTable = createHashMapFromArray [
        ["phase",  "betting"],
        ["round",  0],
        ["until",  0],          // 0 = the table is resting; no countdown is running
        ["shoe",   []],
        ["dealer", []],
        ["seats",  []],         // BJ_SEATS entries: [] when empty, else a hashmap
        ["active", -1],         // index of the seat currently acting
        ["viewers",[]]          // player objects with the dialog open
    ];
    private _empty = []; for "_i" from 1 to BJ_SEATS do { _empty pushBack [] };
    AP_bjTable set ["seats", _empty];
};
private _T = AP_bjTable;

// ── card helpers. Cards are 0-51 and go to the page as ints; -1 is face-down. ─
private _handVal = {
    params ["_cards"];
    private _sum = 0; private _aces = 0;
    { if (_x >= 0) then {
      private _r = _x mod 13;
      if (_r isEqualTo 12) then { _sum = _sum + 11; _aces = _aces + 1 }
      else { _sum = _sum + ((_r + 2) min 10) };
      };
    } forEach _cards;
    while { _sum > 21 && _aces > 0 } do { _sum = _sum - 10; _aces = _aces - 1 };
    _sum
};
private _val10 = { params ["_c"]; private _r = _c mod 13; if (_r isEqualTo 12) then {11} else {(_r + 2) min 10} };

if !(isFinal "AP_fnc_bjDraw") then {AP_fnc_bjDraw = compileFinal {
    private _T = AP_bjTable;
    private _shoe = _T get "shoe";
    // Reshuffle at the cut card rather than at empty, so a round never straddles
    // two shoes -- that is the one thing a counter would actually notice.
    if (count _shoe < 60) then {
        _shoe = [];
        for "_d" from 1 to BJ_SHOE_DECKS do { for "_c" from 0 to 51 do { _shoe pushBack _c } };
        for "_i" from 0 to (count _shoe - 1) do {
            private _j = floor (random (count _shoe));
            private _t = _shoe select _i; _shoe set [_i, _shoe select _j]; _shoe set [_j, _t];
        };
        _T set ["shoe", _shoe];
        ["event", createHashMapFromArray [["kind","shuffle"],["text","SHOE RESHUFFLED"]]] call AP_fnc_bjSend;
    };
    private _c = _shoe deleteAt 0;
    _T set ["shoe", _shoe];
    _c
}};

// ── broadcast ────────────────────────────────────────────────────────────────
// Rebuilt per viewer: "you" differs, and it is the only thing the page keys its
// whole action bar off. One shared array with a mutated flag would race against
// the async send.
if !(isFinal "AP_fnc_bjSnapshot") then {AP_fnc_bjSnapshot = compileFinal {
    params ["_forUid"];
    private _T = AP_bjTable;
    private _dealer = _T get "dealer";
    private _phase  = _T get "phase";
    // The hole turns over when the dealer PLAYS, not when the phase says dealer.
    // If the whole table busts the house never plays the hand -- showing the card
    // anyway leaks a shoe position for nothing, and the point of skipping the
    // draw was to not show it.
    private _reveal = (_phase in ["dealer", "payout"]) && {_T getOrDefault ["revealed", false]};
    private _dCards = if (_reveal || {count _dealer < 2}) then { +_dealer } else { [_dealer select 0, -1] };

    private _seats = [];
    {
        private _s = _x;
        if (_s isEqualTo []) then {
            _seats pushBack createHashMapFromArray [
                ["seat", _forEachIndex], ["name",""], ["you",false], ["ghost",false],
                ["bet",0], ["chips",0], ["hands",[]], ["activeHand",0], ["state","empty"]
            ];
        } else {
            private _mine = (_s get "uid") isEqualTo _forUid;
            private _acting = (_T get "active") isEqualTo _forEachIndex && {_phase isEqualTo "acting"};
            private _hands = (_s get "hands") apply {
                createHashMapFromArray [
                    ["cards", +(_x get "cards")], ["total", ([_x] call AP_fnc_bjTotal)],
                    ["bet",   _x get "bet"],      ["state", _x get "state"]
                ]
            };
            private _seat = createHashMapFromArray [
                ["seat", _forEachIndex], ["name", _s get "name"], ["you", _mine],
                // GHOST.SYS hides the cards from everyone but their owner
                ["ghost", _s getOrDefault ["ghost", false]],
                ["played", +(_s getOrDefault ["played", []])],
                ["bet", _s get "bet"], ["chips", _s get "chips"], ["hands", _hands],
                ["activeHand", _s get "active"],
                ["state", if (_acting) then {"acting"} else { if ((_s get "bet") > 0) then {"bet"} else {"idle"} }]
            ];
            // "actions is the UI law" -- only ever on the seat that is actually up,
            // so a spectator's page finds none on its own seat and offers nothing.
            if (_acting && _mine) then { _seat set ["actions", [_s] call AP_fnc_bjActions] };
            _seats pushBack _seat;
        };
    } forEach (_T get "seats");

    private _secs = 0;
    if ((_T get "until") > 0) then { _secs = ((_T get "until") - serverTime) max 0 };

    createHashMapFromArray [
        ["phase",  _phase],
        ["round",  _T get "round"],
        ["minBet", BJ_MIN_BET],
        ["clock",  createHashMapFromArray [["seat", _T get "active"], ["secs", round _secs]]],
        ["dealer", createHashMapFromArray [
            ["cards", _dCards],
                        // Face-up total only. Showing the real one before the reveal would
            // hand the table the hole card in a number.
            ["total", if (_reveal) then { [_dealer] call AP_fnc_bjVal } else { [[_dealer param [0, -1]] select { _x >= 0 }] call AP_fnc_bjVal }],
            ["hole",  !_reveal]
        ]],
        ["seats",  _seats]
    ]
}};

// Published as globals because the snapshot builder and the phase driver both run
// outside this call's scope (the driver is a spawn that outlives it).
if !(isFinal "AP_fnc_bjVal") then {AP_fnc_bjVal = compileFinal _handVal};
if !(isFinal "AP_fnc_bjVal10") then {AP_fnc_bjVal10 = compileFinal _val10};

// A hand's worth is its cards PLUS whatever a chip did to it. Nudge and friends
// ride a server-side adj -- never client maths, and never a rewritten card, so
// the cards on screen stay the cards that were dealt.
// A seat's hand that is currently in play. Chips act on the active hand, the
// same one the action bar acts on, so a split seat is affected where it is
// looking rather than on some arbitrary half.
if !(isFinal "AP_fnc_bjHand") then {AP_fnc_bjHand = compileFinal {
    params ["_s"];
    (_s getOrDefault ["hands", []]) param [_s getOrDefault ["active", 0], createHashMap]
}};

// Bust a hand on purpose, honouring the victim's FIREWALL -- a chip that says it
// busts a seat should still lose to the chip that says it does not bust. The adj
// is what makes the total on screen read as over rather than the card values
// silently disagreeing with the state.
if !(isFinal "AP_fnc_bjWreck") then {AP_fnc_bjWreck = compileFinal {
    params ["_s", "_h", ["_why", "CHIP"]];
    if ((_h getOrDefault ["state", ""]) isNotEqualTo "") exitWith {};
    private _armed = _s getOrDefault ["armed", []];
    if ("firewall" in _armed) exitWith {
        _s set ["armed", _armed - ["firewall"]];
        _h set ["state", "stood"];
        ["event", createHashMapFromArray [["kind","powerup"],
            ["text", format ["FIREWALL HELD AGAINST %1", _why]]]] call AP_fnc_bjSend;
    };
    _h set ["adj", 22 - ([_h getOrDefault ["cards", []]] call AP_fnc_bjVal)];
    _h set ["state", "bust"];
}};

if !(isFinal "AP_fnc_bjTotal") then {AP_fnc_bjTotal = compileFinal {
    params ["_h"];
    (([_h getOrDefault ["cards", []]] call AP_fnc_bjVal) + (_h getOrDefault ["adj", 0])) max 0
}};

if !(isFinal "AP_fnc_bjActions") then {AP_fnc_bjActions = compileFinal {
    params ["_s"];
    private _hands = _s get "hands";
    private _h = _hands param [_s get "active", createHashMap];
    private _cards = _h getOrDefault ["cards", []];
    private _acts = ["hit", "stand"];
    if (count _cards isEqualTo 2 && {!(_h getOrDefault ["splitAce", false])}) then {
        _acts pushBack "double";
        if ((count _hands) < BJ_MAX_HANDS
            && {([_cards select 0] call AP_fnc_bjVal10) isEqualTo ([_cards select 1] call AP_fnc_bjVal10)}) then {
            _acts pushBack "split";
        };
    };
    _acts
}};

if !(isFinal "AP_fnc_bjSend") then {AP_fnc_bjSend = compileFinal {
    params ["_kind", "_payload"];
    private _T = AP_bjTable;
    // A viewer who disconnected is still in the list until we prune it here.
    private _live = (_T get "viewers") select { !isNull _x && {isPlayer _x} };
    _T set ["viewers", _live];
    if (_kind isEqualTo "table") then {
        { [["table", ([getPlayerUID _x] call AP_fnc_bjSnapshot)], "AP_fnc_bjTable", _x, false] spawn AP_fnc_MP; } forEach _live;
    } else {
        { [[_kind, _payload], "AP_fnc_bjTable", _x, false] spawn AP_fnc_MP; } forEach _live;
    };
}};

if !(isFinal "AP_fnc_bjPush") then {AP_fnc_bjPush = compileFinal { ["table", createHashMap] call AP_fnc_bjSend }};

if !(isFinal "AP_fnc_bjSay") then {AP_fnc_bjSay = compileFinal {
    params ["_text"];
    ["event", createHashMapFromArray [["kind","say"],["text",_text]]] call AP_fnc_bjSend;
}};

if !(isFinal "AP_fnc_bjWallet") then {AP_fnc_bjWallet = compileFinal {
    params ["_plr"];
    private _uid = getPlayerUID _plr;
    private _seatIdx = -1;
    { if (_x isNotEqualTo [] && {(_x get "uid") isEqualTo _uid}) exitWith { _seatIdx = _forEachIndex }; } forEach (AP_bjTable get "seats");
    private _rows = ["load", _uid] call APS_fnc_bjChips;
    private _wallet = _rows apply { createHashMapFromArray [["id", _x select 0], ["name", _x select 0], ["n", _x select 1]] };
    [["you", createHashMapFromArray [["seat", _seatIdx], ["wallet", _wallet]]], "AP_fnc_bjTable", _plr, false] spawn AP_fnc_MP;
}};

// ── round machinery ──────────────────────────────────────────────────────────
if !(isFinal "AP_fnc_bjDeal") then {AP_fnc_bjDeal = compileFinal {
    private _T = AP_bjTable;
    _T set ["phase", "dealing"];
    _T set ["round", (_T get "round") + 1];
    _T set ["dealer", []];
    private _betting = [];
    {
        if (_x isNotEqualTo [] && {(_x get "bet") > 0}) then {
            _x set ["hands", [createHashMapFromArray [
                ["cards", []], ["bet", _x get "bet"], ["state", ""], ["dbl", false], ["splitAce", false], ["adj", 0]
            ]]];
            _x set ["active", 0];
            _betting pushBack _forEachIndex;
        } else {
            if (_x isNotEqualTo []) then { _x set ["hands", []]; _x set ["active", 0] };
        };
    } forEach (_T get "seats");
    if (_betting isEqualTo []) exitWith { _T set ["phase", "betting"]; _T set ["until", 0]; call AP_fnc_bjPush };

    // TEST RIG. A stacked shoe for the next deal only, owner-gated at the verb.
    // Deal order is p1 d1 p2 d2, so the front of the shoe IS the round -- see
    // the "rig" case for the hands each scenario builds.
    private _rig = _T getOrDefault ["rig", []];
    if (_rig isNotEqualTo [] && {count _betting isEqualTo 1}) then {
        _T set ["shoe", _rig + (_T get "shoe")];
        _T set ["rig", []];
        diag_log format ["[BJTABLE] rigged deal: %1", _rig];
    };

    // two rounds of one card each, players then dealer -- the order a real shoe
    // deals in, and the page's ticker is driven off it
    for "_pass" from 1 to 2 do {
        {
            private _s = (_T get "seats") select _x;
            private _h = (_s get "hands") select 0;
            (_h get "cards") pushBack (call AP_fnc_bjDraw);
        } forEach _betting;
        (_T get "dealer") pushBack (call AP_fnc_bjDraw);
    };
    ["event", createHashMapFromArray [["kind","deal"]]] call AP_fnc_bjSend;
    ["DEALERBOT// cards are out. | B// try not to embarrass yourself."] call AP_fnc_bjSay;

    _T set ["active", _betting select 0];
    _T set ["phase", "acting"];
    _T set ["until", serverTime + BJ_ACT_SECS];
    call AP_fnc_bjPush;
    [(_T get "active")] call AP_fnc_bjTurn;
}};

if !(isFinal "AP_fnc_bjTurn") then {AP_fnc_bjTurn = compileFinal {
    params ["_idx"];
    private _s = (AP_bjTable get "seats") select _idx;
    if (_s isEqualTo []) exitWith {};
    private _plr = _s get "obj";
    if (!isNull _plr) then {
        [["event", createHashMapFromArray [["kind","turn"],["seat",_idx]]], "AP_fnc_bjTable", _plr, false] spawn AP_fnc_MP;
    };
}};

// Advance past the active hand: next unfinished hand on this seat, else next
// betting seat, else the dealer plays. The seat's exit is FLAT: nested in the
// if-then it left only that block, so a split's second hand was made active and
// then skipped on to the next seat unplayed. Finished hands are passed over
// (split aces stand on one card each), same as the page's findIndex(!state).
if !(isFinal "AP_fnc_bjNext") then {AP_fnc_bjNext = compileFinal {
    private _T = AP_bjTable;
    private _idx = _T get "active";
    private _s = (_T get "seats") select _idx;
    private _n = -1;
    if (_s isNotEqualTo []) then {
        private _hands = _s get "hands";
        for "_k" from ((_s get "active") + 1) to ((count _hands) - 1) do {
            if (_n < 0 && {((_hands select _k) getOrDefault ["state", ""]) isEqualTo ""}) then { _n = _k };
        };
    };
    if (_n > -1) exitWith {
        _s set ["active", _n];
        _T set ["until", serverTime + BJ_ACT_SECS];
        call AP_fnc_bjPush;
    };
    private _seats = _T get "seats";
    private _next = -1;
    for "_i" from (_idx + 1) to (BJ_SEATS - 1) do {
        private _c = _seats select _i;
        if (_next < 0 && {_c isNotEqualTo []} && {(_c get "hands") isNotEqualTo []}) then { _next = _i };
    };
    if (_next > -1) exitWith {
        _T set ["active", _next];
        _T set ["until", serverTime + BJ_ACT_SECS];
        call AP_fnc_bjPush;
        [_next] call AP_fnc_bjTurn;
    };
    call AP_fnc_bjDealerPlay;
}};

if !(isFinal "AP_fnc_bjDealerPlay") then {AP_fnc_bjDealerPlay = compileFinal { [] spawn AP_fnc_bjDealerRun }};
if !(isFinal "AP_fnc_bjDealerRun") then {AP_fnc_bjDealerRun = compileFinal {
    private _T = AP_bjTable;
    _T set ["active", -1];
    _T set ["phase", "dealer"];
    _T set ["until", 0];
    // Everyone bust means the hole never turns over -- the house does not have to
    // play a hand nobody can beat, and showing it would leak shoe information.
    // Anyone the dealer still has to BEAT -- which is every hand that did not
    // bust, standing included. The test was `state == ""` (still acting), so the
    // moment everybody stood the dealer decided it had nothing to play against
    // and sat on two cards. That is every ordinary round.
    private _live = 0;
    { if (_x isNotEqualTo []) then { { if ((_x get "state") isNotEqualTo "bust") then { _live = _live + 1 } } forEach (_x get "hands") } } forEach (_T get "seats");
    _T set ["revealed", _live > 0];
    call AP_fnc_bjPush;
    // BRICK freezes the house on two cards; OVERCLOCK forces it to hit its 17.
    private _brick = _T getOrDefault ["brick", false];
    private _stand = if (_T getOrDefault ["overclock", false]) then { 18 } else { 17 };
    if (_live > 0 && {!_brick}) then {
        private _dealer = _T get "dealer";
        if (_T getOrDefault ["flatline", false]) then { _stand = 99 };   // draws until it busts
        while { ([_dealer] call AP_fnc_bjVal) < _stand && {([_dealer] call AP_fnc_bjVal) <= 21} } do {
            _dealer pushBack (call AP_fnc_bjDraw);
            call AP_fnc_bjPush;
            uiSleep 0.7;
        };
    };
    call AP_fnc_bjPayout;
}};

// ── chip drops ───────────────────────────────────────────────────────────────
// Owner 2026-08-12: EVERY money win drops a chip, and a blackjack or a 21 has a
// better shot at a better one. So there is no drop rate to tune and no pity
// counter to keep -- the only question a win asks is which TIER.
//
// Note this is per WINNING HAND, which is what "every win" says. A four-way
// split that wins three hands drops three chips; that is a real faucet and the
// number to turn down first if the economy runs hot.
if !(isFinal "AP_fnc_bjDrop") then {AP_fnc_bjDrop = compileFinal {
    params ["_plr", "_quality"];   // "bj" natural | "21" | "win"
    private _cat = ["roster"] call APS_fnc_bjChips;
    if (_cat isEqualTo []) exitWith { diag_log "[BJTABLE] drop skipped: empty chip catalogue"; };

    // common / rare / LEGENDARY, out of 100
    private _w = switch (_quality) do {
        case "bj": { [25, 45, 30] };     // a natural is the best thing that can happen
        case "21": { [40, 40, 20] };
        default    { [60, 30, 10] };
    };
    private _r = random 100;
    private _tier = if (_r < (_w select 0)) then { 0 } else {
        if (_r < ((_w select 0) + (_w select 1))) then { 1 } else { 2 }
    };

    private _pool = _cat select { (_x select 2) isEqualTo _tier };
    if (_pool isEqualTo []) exitWith {};
    private _pick = selectRandom _pool;
    _pick params ["_id", "_name", "_t"];

    private _uid = getPlayerUID _plr;
    if !(["grant", _uid, _id, 1] call APS_fnc_bjChips) exitWith {
        diag_log format ["[BJTABLE] drop grant failed: %1 -> %2", _uid, _id];
    };
    ["-CASINOBJ-", _plr, format ["chip drop %1 (tier %2, %3)", _id, _t, _quality]] call APS_fnc_logIt;

    [["event", createHashMapFromArray [["kind","drop"],["text",_name],["tier",_t]]],
        "AP_fnc_bjTable", _plr, false] spawn AP_fnc_MP;
    [_plr] call AP_fnc_bjWallet;
}};

if !(isFinal "AP_fnc_bjPayout") then {AP_fnc_bjPayout = compileFinal {
    private _T = AP_bjTable;
    private _dealer = _T get "dealer";
    private _dVal = [_dealer] call AP_fnc_bjVal;
    private _dealerBJ = (count _dealer isEqualTo 2) && {_dVal isEqualTo 21};
    private _dealerBust = _dVal > 21;

    {
        private _s = _x;
        if (_s isNotEqualTo [] && {(_s get "hands") isNotEqualTo []}) then {
            private _plr = _s get "obj";
            private _ret = 0; private _wagered = 0;
            {
                private _h = _x;
                private _cards = _h get "cards";
                private _bet = _h get "bet";
                _wagered = _wagered + _bet;
                private _pVal = [_h] call AP_fnc_bjTotal;
                // Raw cards, deliberately: a 20 nudged to 21 is a win, not a
                // natural, and must not collect the 3:2.
                private _natural = (count _cards isEqualTo 2) && {([_cards] call AP_fnc_bjVal) isEqualTo 21}
                    && {!(_h get "splitAce")} && {(count (_s get "hands")) isEqualTo 1};
                switch (true) do {
                    // EJECT: out of the round with the stake back. Not a win, so
                    // it drops nothing.
                    case ((_h get "state") isEqualTo "eject"): { _ret = _ret + _bet };
                    case ((_h get "state") isEqualTo "bust"): { };
                    case (_natural && !_dealerBJ): { _h set ["state","blackjack"]; _ret = _ret + round (_bet * 2.5) };
                    case (_natural && _dealerBJ):  { _h set ["state","push"];      _ret = _ret + _bet };
                    case (_dealerBJ):              { _h set ["state","lose"] };
                    case (_dealerBust):            { _h set ["state","win"];  _ret = _ret + (_bet * 2) };
                    case (_pVal > _dVal):          { _h set ["state","win"];  _ret = _ret + (_bet * 2) };
                    case (_pVal isEqualTo _dVal):  { _h set ["state","push"]; _ret = _ret + _bet };
                    default                        { _h set ["state","lose"] };
                };
            } forEach (_s get "hands");

            // JACKPOT: the side bet on the two cards you were dealt. Same suit and
            // same rank -- possible because the shoe is six decks -- pays 20x the
            // stake, and it pays whether the hand itself went on to win or not.
            if (_s getOrDefault ["jackpot", false]) then {
                private _first = (_s get "hands") param [0, createHashMap];
                private _fc = _first getOrDefault ["cards", []];
                if (count _fc >= 2) then {
                    private _a = _fc select 0; private _b = _fc select 1;
                    if ((_a mod 13) isEqualTo (_b mod 13) && {(floor (_a / 13)) isEqualTo (floor (_b / 13))}) then {
                        private _jp = (_first getOrDefault ["bet", 0]) * 20;
                        _ret = _ret + _jp;
                        ["event", createHashMapFromArray [["kind","powerup"],
                            ["text", format ["JACKPOT — SUITED PAIR, %1x THE STAKE", 20]]]] call AP_fnc_bjSend;
                        ["-CASINOBJ-", _plr, format ["jackpot side bet paid $%1", _jp]] call APS_fnc_logIt;
                    };
                };
            };

            if (!isNull _plr) then {
                if (_ret > 0) then { [[_ret], "AP_fnc_blackJackReceive", _plr, false] spawn AP_fnc_MP; };
                // Rolled here rather than in the loop above so a hand is only ever
                // paid AND dropped once, off the state the settle actually wrote.
                {
                    private _st = _x get "state";
                    if (_st in ["win", "blackjack"]) then {
                        private _q = switch (true) do {
                            case (_st isEqualTo "blackjack"): { "bj" };
                            case (([_x get "cards"] call AP_fnc_bjVal) isEqualTo 21): { "21" };
                            default { "win" };
                        };
                        [_plr, _q] call AP_fnc_bjDrop;
                    };
                } forEach (_s get "hands");
                ["-CASINOBJ-", _plr, format ["net $%1 (dealerbot table r%2, wagered $%3, returned $%4, dealer %5)",
                    _ret - _wagered, _T get "round", _wagered, _ret, _dVal]] call APS_fnc_logIt;
            };
        };
    } forEach (_T get "seats");

    _T set ["phase", "payout"];
    _T set ["until", serverTime + 6];
    call AP_fnc_bjPush;
    [format ["DEALERBOT// house shows %1. | B// the shoe remembers.", _dVal]] call AP_fnc_bjSay;
}};

if !(isFinal "AP_fnc_bjClear") then {AP_fnc_bjClear = compileFinal {
    private _T = AP_bjTable;
    {
        if (_x isNotEqualTo []) then {
            _x set ["hands", []]; _x set ["bet", 0]; _x set ["active", 0];
            // Chip state is per ROUND and clears here rather than at the deal --
            // GHOST and JACKPOT are armed during betting and have to survive into
            // the hand they were bought for.
            _x set ["played", []]; _x set ["armed", []];
            _x set ["ghost", false]; _x set ["jackpot", false];
        };
    } forEach (_T get "seats");
    _T set ["dealer", []];
    _T set ["revealed", false];
    _T set ["brick", false];
    _T set ["overclock", false];
    _T set ["flatline", false];
    _T set ["active", -1];
    _T set ["phase", "betting"];
    _T set ["until", 0];
    call AP_fnc_bjPush;
}};

// ── identity: derived from the connection, never from the payload ────────────
// Sits BELOW the helper definitions on purpose: server init calls ["boot"] (owner 0) so the
// compileFinal'd AP_fnc_bj* exist before any client connects -- a client that published its own
// final copy first would otherwise have it run here on the first table action. Boot exits here.
private _src = remoteExecutedOwner;
if (_src isEqualTo 0) exitWith {};
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};
private _uid = getPlayerUID _caller;
if (_uid isEqualTo "") exitWith {};

// ── phase driver ─────────────────────────────────────────────────────────────
// One loop for the whole table. It owns exactly two things: closing the betting
// window and enforcing the shot clock. Everything else is driven by the actions
// themselves, so an idle table costs one comparison every half second.
if (isNil "AP_bjDriver") then {
    AP_bjDriver = [] spawn {
        while { true } do {
            uiSleep 0.5;
            private _T = AP_bjTable;
            if (isNil "_T") then { continue };
            private _until = _T get "until";
            private _phase = _T get "phase";

            // The clock is part of the picture, so a running one has to be pushed --
            // but only when the DISPLAYED second changes. Pushing at the tick rate
            // rebuilt the page's markup twice a second, and a button rebuilt between
            // mousedown and mouseup never fires a click. Half the traffic, and the
            // action bar stops moving under the cursor.
            if (_until > 0 && {_phase in ["betting","acting"]}) then {
                private _sec = ceil (_until - serverTime);
                if (_sec isNotEqualTo (_T getOrDefault ["lastSec", -1])) then {
                    _T set ["lastSec", _sec];
                    call AP_fnc_bjPush;
                };
            };

            if (_until > 0 && {serverTime >= _until}) then {
                switch (_phase) do {
                    case "betting": { call AP_fnc_bjDeal };
                    case "acting":  {
                        // timeout stands the hand -- the server does it, so a
                        // player who alt-tabs cannot hold four other people up
                        private _s = (_T get "seats") select (_T get "active");
                        if (_s isNotEqualTo []) then {
                            private _h = (_s get "hands") param [_s get "active", createHashMap];
                            _h set ["state", "stood"];
                            ["event", createHashMapFromArray [["kind","say"],
                                ["text","DEALERBOT// clock ran out. | B// stood for you. you're welcome."]]] call AP_fnc_bjSend;
                        };
                        call AP_fnc_bjNext;
                    };
                    default {};
                };
            };
            if (_phase isEqualTo "payout" && {_until > 0} && {serverTime >= _until}) then { call AP_fnc_bjClear };
        };
    };
};

// ── dispatch ─────────────────────────────────────────────────────────────────
private _seats = _T get "seats";
private _mySeat = -1;
{ if (_x isNotEqualTo [] && {(_x get "uid") isEqualTo _uid}) exitWith { _mySeat = _forEachIndex }; } forEach _seats;

switch (toLower _case) do {

    case "watch": {
        private _v = _T get "viewers";
        if !(_caller in _v) then { _v pushBack _caller; _T set ["viewers", _v] };
        [[ "table", ([_uid] call AP_fnc_bjSnapshot) ], "AP_fnc_bjTable", _caller, false] spawn AP_fnc_MP;
        [_caller] call AP_fnc_bjWallet;
    };

    case "unwatch": {
        _T set ["viewers", (_T get "viewers") - [_caller]];
        // Leaving with a live hand forfeits it, same as the solo engine's quit.
        // The alternative is a seat nobody can act on holding up the table.
        if (_mySeat > -1) then { _seats set [_mySeat, []]; call AP_fnc_bjPush };
    };

    case "sit": {
        private _seat = _data param [0, -1];
        if !(_seat isEqualType 0 && {_seat >= 0} && {_seat < BJ_SEATS}) exitWith {};
        if ((_T get "phase") isNotEqualTo "betting") exitWith {};
        if ((_seats select _seat) isNotEqualTo []) exitWith {};
        if (_mySeat > -1) then { _seats set [_mySeat, []] };
        _seats set [_seat, createHashMapFromArray [
            ["uid", _uid], ["name", ((name _caller) splitString "<>&""'") joinString ""], ["obj", _caller],   // every viewer's page prints this; no markup
            ["bet", 0], ["hands", []], ["active", 0], ["chips", 0]
        ]];
        call AP_fnc_bjPush;
        [_caller] call AP_fnc_bjWallet;
    };

    case "leave": {
        if (_mySeat < 0) exitWith {};
        _seats set [_mySeat, []];
        call AP_fnc_bjPush;
        [_caller] call AP_fnc_bjWallet;
    };

    case "bet": {
        if (_mySeat < 0) exitWith {};
        if ((_T get "phase") isNotEqualTo "betting") exitWith {};
        private _amt = round (_data param [0, 0]);
        if (_amt < BJ_MIN_BET) exitWith {};
        _amt = _amt min BJ_MAX_BET;
        private _s = _seats select _mySeat;
        _s set ["bet", _amt];
        ["-CASINOBET-", _caller, format ["$%1 dealerbot table", _amt]] call APS_fnc_logIt;
        // First bet of the round starts the window; later bets do not extend it,
        // or one seat could hold the table open indefinitely.
        if ((_T get "until") isEqualTo 0) then {
            _T set ["until", serverTime + BJ_BET_SECS];
            ["DEALERBOT// bets are open. | B// fifteen seconds. move."] call AP_fnc_bjSay;
        };
        call AP_fnc_bjPush;
    };

    case "act": {
        if (_mySeat < 0) exitWith {};
        if ((_T get "phase") isNotEqualTo "acting") exitWith {};
        if ((_T get "active") isNotEqualTo _mySeat) exitWith {};
        private _act = toLower (_data param [0, ""]);
        private _s = _seats select _mySeat;
        private _hands = _s get "hands";
        private _h = _hands param [_s get "active", createHashMap];
        // The action bar is generated from this same list, so a page sending
        // something that is not on it is either out of date or lying.
        if !(_act in ([_s] call AP_fnc_bjActions)) exitWith {};

        switch (_act) do {
            case "hit": {
                (_h get "cards") pushBack (call AP_fnc_bjDraw);
                if (([_h] call AP_fnc_bjTotal) > 21) then {
                    // FIREWALL eats one bust and is consumed doing it.
                    private _armed = _s getOrDefault ["armed", []];
                    if ("firewall" in _armed) then {
                        _s set ["armed", _armed - ["firewall"]];
                        _h set ["state", "stood"];
                        ["event", createHashMapFromArray [["kind","powerup"],
                            ["text","FIREWALL HELD — THE BUST BECAME A STAND"]]] call AP_fnc_bjSend;
                    } else {
                        _h set ["state", "bust"];
                        ["event", createHashMapFromArray [["kind","say"],
                            ["text","DEALERBOT// over. | B// predictable."]]] call AP_fnc_bjSend;
                    };
                    call AP_fnc_bjNext;
                } else {
                    _T set ["until", serverTime + BJ_ACT_SECS];
                    call AP_fnc_bjPush;
                };
            };
            case "stand": { _h set ["state", "stood"]; call AP_fnc_bjNext };
            case "double": {
                // the client has already debited the second bet, same as the solo engine
                _h set ["bet", (_h get "bet") * 2];
                _h set ["dbl", true];
                (_h get "cards") pushBack (call AP_fnc_bjDraw);
                if (([_h] call AP_fnc_bjTotal) > 21) then { _h set ["state","bust"] } else { _h set ["state","stood"] };
                call AP_fnc_bjNext;
            };
            case "split": {
                private _cards = _h get "cards";
                private _isAce = ((_cards select 0) mod 13) isEqualTo 12;
                private _moved = _cards deleteAt 1;
                private _new = createHashMapFromArray [
                    ["cards", [_moved]], ["bet", _h get "bet"], ["state", ""], ["dbl", false], ["splitAce", _isAce], ["adj", 0]
                ];
                _h set ["splitAce", _isAce];
                _hands insert [(_s get "active") + 1, [_new]];
                _cards pushBack (call AP_fnc_bjDraw);
                (_new get "cards") pushBack (call AP_fnc_bjDraw);
                // Split aces get one card each and stand -- the standard rule, and
                // the reason splitAce also blocks double on both halves.
                if (_isAce) then { _h set ["state","stood"]; _new set ["state","stood"]; call AP_fnc_bjNext }
                else { _T set ["until", serverTime + BJ_ACT_SECS]; call AP_fnc_bjPush };
            };
            default {};
        };
    };

    // ── POWERUP CHIPS ────────────────────────────────────────────────────────
    // The chip is SPENT FIRST and the effect only runs if the spend actually took
    // one out of the pocket -- APS_fnc_bjChips answers on the row delta, so a
    // player with none gets nothing no matter what the page offers.
    //
    // Phase and target are re-derived here, never trusted: the locker will happily
    // offer a chip the table is not in a position to accept.
    //
    // SLICE 1 is everything that touches only the player who played it. The chips
    // that reach across the table (siphon, handshake, mirror, backstab, feed,
    // rewire, spite, chipswap, gift, martyr) and the table-wide legendaries
    // (flatline, houseswap, cascade) refuse with a reason rather than pretending.
    case "chip": {
        private _id = toLower (_data param [0, ""]);
        private _tgt = _data param [1, -1];
        private _refuse = { params ["_m"]; [["event", createHashMapFromArray [["kind","powerup"],["text", _m]]],
            "AP_fnc_bjTable", _caller, false] spawn AP_fnc_MP; };

        if (_mySeat < 0) exitWith { ["TAKE A SEAT FIRST"] call _refuse };
        private _s = _seats select _mySeat;
        private _phase = _T get "phase";
        private _myTurn = (_phase isEqualTo "acting") && {(_T get "active") isEqualTo _mySeat};
        private _h = (_s get "hands") param [_s get "active", createHashMap];

        // what each chip needs before it can be played at all
        private _needsTurn = _id in ["peek","scramble","aceinject","nudge","hardnudge","stand19","eject","firewall","overclock","brick"];
        private _bettingOk = _id in ["ghost","jackpot","purge"];
        // Everything that touches a hand needs the hand to be live and yours to act on.
        private _reach = _id in ["siphon","handshake","mirror","backstab","feed","rewire","spite","gift","martyr","flatline","houseswap","cascade","chipswap"];
        if ((_needsTurn || _reach) && {!_myTurn}) exitWith { ["NOT YOUR TURN"] call _refuse };
        if (!_needsTurn && {!_bettingOk} && {!_reach}) exitWith { ["NO SUCH CHIP"] call _refuse };
        if (_bettingOk && {!(_phase in ["betting","acting"])}) exitWith { ["NOT NOW"] call _refuse };

        // Target resolution. TARGETED on the page says which chips take a seat and
        // which of those may name your own; both halves are re-checked here.
        private _selfOk = _id in ["nudge","hardnudge","purge","rewire"];
        private _wantsTarget = _id in ["nudge","hardnudge","purge","rewire","siphon","handshake","mirror","backstab","feed","spite","gift","chipswap"];
        private _tS = objNull; private _tSeat = [];
        if (_wantsTarget) then {
            if !(_tgt isEqualType 0 && {_tgt >= 0} && {_tgt < BJ_SEATS}) exitWith { ["PICK A SEAT"] call _refuse };
            if (_tgt isEqualTo _mySeat && {!_selfOk}) exitWith { ["NOT YOUR OWN SEAT"] call _refuse };
            _tSeat = _seats select _tgt;
            if (_tSeat isEqualTo []) exitWith { ["THAT SEAT IS EMPTY"] call _refuse };
        };
        if (_wantsTarget && {_tSeat isEqualTo []}) exitWith {};

        if !(["spend", _uid, _id, 1] call APS_fnc_bjChips) exitWith { ["YOU DO NOT HAVE THAT CHIP"] call _refuse };

        private _armed = _s getOrDefault ["armed", []];
        private _said = "";
        switch (_id) do {
            // ---- armed until something consumes them ----
            case "firewall":  { _armed pushBackUnique "firewall"; _said = "FIREWALL ARMED — THE NEXT BUST IS A STAND" };
            case "overclock": { _T set ["overclock", true];  _said = "OVERCLOCK — THE HOUSE MUST HIT ITS 17" };
            case "brick":     { _T set ["brick", true];      _said = "BRICK — THE HOUSE STANDS ON TWO" };
            case "ghost":     { _s set ["ghost", true];      _said = "GHOST.SYS — YOUR CARDS ARE OFF THE TABLE" };
            case "jackpot":   { _s set ["jackpot", true];    _said = "JACKPOT ARMED — A SUITED PAIR PAYS 20x" };

            // ---- immediate, on your own hand ----
            case "peek": {
                private _hole = (_T get "dealer") param [1, -1];
                [["event", createHashMapFromArray [["kind","peek"],["card",_hole],
                    ["text","PEEK.EXE — THE HOLE IS YOURS ALONE"]]], "AP_fnc_bjTable", _caller, false] spawn AP_fnc_MP;
            };
            case "scramble": {
                private _c = _h get "cards";
                if (count _c > 0) then { _c set [(count _c) - 1, call AP_fnc_bjDraw]; _said = "SCRAMBLE — LAST CARD REDRAWN" };
            };
            case "aceinject": {
                private _c = _h get "cards";
                if (count _c > 0) then {
                    // rank 12 is an ace; suit is whatever the shoe felt like
                    _c set [floor (random (count _c)), 12 + (13 * floor (random 4))];
                    _said = "ACE.INJECT — A CARD REMEMBERS BEING AN ACE";
                };
            };
            case "stand19": {
                // discard the maths: the hand is 19 and it is done
                _h set ["adj", 19 - ([_h getOrDefault ["cards", []]] call AP_fnc_bjVal)];
                _h set ["state", "stood"];
                _said = "STAND.19 — THE MATHS ARE OVER";
            };
            case "eject": { _h set ["state", "eject"]; _said = "EJECT — OUT, STAKE BACK" };
            case "nudge";
            case "hardnudge": {
                private _n = if (_id isEqualTo "hardnudge") then { 3 } else { 1 };
                // "helps you, hurts them" -- on your own hand it moves toward 21 if
                // that fits and away if it does not; on anyone else it always pushes
                // toward the edge, and takes them over if it can.
                private _mine = (_tSeat isEqualTo []) || {_tgt isEqualTo _mySeat};
                private _v = if (_mine) then { _h } else { [_tSeat] call AP_fnc_bjHand };
                private _t = [_v] call AP_fnc_bjTotal;
                private _d = if (_mine) then { if (_t + _n <= 21) then { _n } else { -_n } } else { _n };
                _v set ["adj", (_v getOrDefault ["adj", 0]) + _d];
                if (!_mine && {([_v] call AP_fnc_bjTotal) > 21}) then { [_tSeat, _v, toUpper _id] call AP_fnc_bjWreck };
                _said = format ["%1 — %2%3 ON %4", toUpper _id, if (_d > 0) then {"+"} else {""}, _d,
                    if (_mine) then {"YOUR HAND"} else {_tSeat get "name"}];
            };
            // ---- reaching across the table ----
            case "siphon": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                private _tc = _th getOrDefault ["cards", []];
                if (count _tc < 2) exitWith { _said = "NOTHING TO TAKE" };
                (_h get "cards") pushBack (_tc deleteAt ((count _tc) - 1));
                _said = format ["SIPHON — TOOK A CARD FROM %1", _tSeat get "name"];
            };
            case "handshake": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                private _mine = +(_h get "cards"); private _madj = _h getOrDefault ["adj", 0];
                _h set ["cards", +(_th getOrDefault ["cards", []])];
                _h set ["adj", _th getOrDefault ["adj", 0]];
                _th set ["cards", _mine]; _th set ["adj", _madj];
                _said = format ["HANDSHAKE — HANDS TRADED WITH %1", _tSeat get "name"];
            };
            case "mirror": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                _h set ["cards", +(_th getOrDefault ["cards", []])];
                _h set ["adj", _th getOrDefault ["adj", 0]];
                _said = format ["MIRROR — COPIED %1", _tSeat get "name"];
            };
            case "backstab": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                [_tSeat, _th, "BACKSTAB"] call AP_fnc_bjWreck;
                _said = format ["BACKSTAB — %1 IS OVER", _tSeat get "name"];
            };
            case "feed": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                (_th get "cards") pushBack (call AP_fnc_bjDraw);
                if (([_th] call AP_fnc_bjTotal) > 21) then { [_tSeat, _th, "FEED"] call AP_fnc_bjWreck };
                _said = format ["FEED — %1 TOOK ONE", _tSeat get "name"];
            };
            case "rewire": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                private _n = count (_th getOrDefault ["cards", []]);
                private _fresh = []; for "_i" from 1 to _n do { _fresh pushBack (call AP_fnc_bjDraw) };
                _th set ["cards", _fresh]; _th set ["adj", 0];
                if (([_th] call AP_fnc_bjTotal) > 21) then { [_tSeat, _th, "REWIRE"] call AP_fnc_bjWreck };
                _said = format ["REWIRE — %1 REDEALT", _tSeat get "name"];
            };
            case "spite": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                [_tSeat, _th, "SPITE"] call AP_fnc_bjWreck;
                [_s, _h, "SPITE"] call AP_fnc_bjWreck;
                _said = format ["SPITE — YOU AND %1, BOTH", _tSeat get "name"];
            };
            case "gift": {
                private _th = [_tSeat] call AP_fnc_bjHand;
                _th set ["cards", [12, 11]]; _th set ["adj", 0];   // ace + king, a real natural
                _said = format ["GIFT.EXE — %1 HAS A BLACKJACK", _tSeat get "name"];
            };
            case "chipswap": {
                private _tu = _tSeat get "uid";
                ["swap", _uid, _tu] call APS_fnc_bjChips;
                private _tp = _tSeat get "obj";
                if (!isNull _tp) then { [_tp] call AP_fnc_bjWallet };
                _said = format ["CHIP SWAP — POCKETS TRADED WITH %1", _tSeat get "name"];
            };
            case "houseswap": {
                private _dealer = _T get "dealer";
                private _mine = +(_h get "cards");
                _h set ["cards", +_dealer]; _h set ["adj", 0];
                _T set ["dealer", _mine];
                _said = "HOUSE SWAP — YOU ARE THE HOUSE NOW";
            };
            case "flatline": {
                // The house busts. The dealer routine keeps drawing while this is
                // set, which from any total always gets there.
                _T set ["flatline", true];
                _said = "FLATLINE — THE HOUSE IS GOING OVER";
            };
            case "martyr": {
                [_s, _h, "MARTYR"] call AP_fnc_bjWreck;
                {
                    if (_x isNotEqualTo [] && {_forEachIndex isNotEqualTo _mySeat}) then {
                        private _oh = [_x] call AP_fnc_bjHand;
                        if ((_oh getOrDefault ["state", ""]) isEqualTo "") then {
                            _oh set ["cards", [12, 11]]; _oh set ["adj", 0];
                        };
                    };
                } forEach _seats;
                _said = "MARTYR — YOU BURN, THEY ALL GET BLACKJACKS";
            };
            case "cascade": {
                // Every live hand at the table is redealt the same number of cards.
                // The dealer keeps its own -- HOUSE SWAP is the chip for that.
                {
                    if (_x isNotEqualTo []) then {
                        {
                            if ((_x getOrDefault ["state", ""]) isEqualTo "") then {
                                private _n = count (_x getOrDefault ["cards", []]);
                                private _fresh = []; for "_i" from 1 to _n do { _fresh pushBack (call AP_fnc_bjDraw) };
                                _x set ["cards", _fresh]; _x set ["adj", 0];
                            };
                        } forEach (_x get "hands");
                    };
                } forEach _seats;
                _said = "CASCADE — EVERY HAND ON THE TABLE, REDEALT";
            };
            case "purge": {
                // PURGE may be aimed at anyone, your own seat included.
                private _v = if (_tSeat isEqualTo []) then { _s } else { _tSeat };
                if (_v isEqualTo _s) then { _armed = [] } else { _v set ["armed", []] };
                _v set ["ghost", false]; _v set ["jackpot", false];
                { _x set ["adj", 0] } forEach (_v getOrDefault ["hands", []]);
                _said = if (_v isEqualTo _s) then { "PURGE — YOUR ARMED EFFECTS ARE GONE" }
                        else { format ["PURGE — %1 IS CLEAN", _v get "name"] };
            };
            default {};
        };
        _s set ["armed", _armed];

        private _played = _s getOrDefault ["played", []];
        _played pushBack _id;
        _s set ["played", _played];

        ["-CASINOBJ-", _caller, format ["chip played %1 (r%2, phase %3)", _id, _T get "round", _phase]] call APS_fnc_logIt;
        if (_said isNotEqualTo "") then {
            ["event", createHashMapFromArray [["kind","powerup"],["text",_said]]] call AP_fnc_bjSend;
        };
        [_caller] call AP_fnc_bjWallet;
        call AP_fnc_bjPush;
        // Anything that finished YOUR hand has to move the table on -- STAND.19 and
        // EJECT by design, SPITE and MARTYR by consequence. Checked off the hand's
        // own state rather than a list, so a chip that ends it some other way is
        // covered without being remembered here.
        if (((_h getOrDefault ["state", ""]) isNotEqualTo "") && {_myTurn}) then { call AP_fnc_bjNext };
    };

    // ── TEST RIG ─────────────────────────────────────────────────────────────
    // Push, double, split and split-aces are the four rules that are tedious to
    // reach by playing and are exactly where a money bug would hide, so they get
    // dealt on demand. OWNER UID ONLY, derived from the connection like every
    // other identity here, and it stacks the SHOE rather than writing hands --
    // the engine still deals, still scores, still pays. A rigged round is a real
    // round; that is the point of testing with it.
    //
    // Cards are 0-51: suit = floor(c/13) in C D H S, rank = c mod 13 in 2..A.
    // Deal order is player, dealer, player, dealer.
    case "rig": {
        if (_uid isNotEqualTo "76561190000000001") exitWith {};
        if ((_T get "phase") isNotEqualTo "betting") exitWith {};
        private _what = toLower (_data param [0, ""]);
        private _cards = switch (_what) do {
            //          player     dealer     player     dealer    [extra]
            case "push":      { [11, 24, 23, 10] };            // K+Q=20 vs K+Q=20 -> stand, push
            case "double":    { [3,  7,  4,  20, 24] };        // 5+6=11 vs 9+9=18; the double draws a K
            case "split":     { [6,  7,  19, 20, 4, 5, 17, 18] };   // 8+8 vs 18, then low cards for both hands
            case "splitaces": { [12, 7,  25, 20, 9, 22] };     // A+A vs 18, then a 10 to each -- one card, auto-stand
            default { [] };
        };
        if (_cards isEqualTo []) exitWith { diag_log format ["[BJTABLE] unknown rig '%1'", _what] };
        _T set ["rig", _cards];
        ["event", createHashMapFromArray [["kind","say"],
            ["text", format ["DEALERBOT// the shoe is cold. | B// %1 next hand.", toUpper _what]]]] call AP_fnc_bjSend;
        diag_log format ["[BJTABLE] rig armed: %1 -> %2", _what, _cards];
    };

    default { diag_log format ["[BJTABLE] unhandled case '%1'", _case] };
};
