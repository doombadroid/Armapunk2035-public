/*
    APS_fnc_holdemEval  (Armapunk 2035) -- the HOLD'EM hand evaluator, and its own self-test.

    SERVER-LOCAL. It is not in CfgRE and must never be: it decides who wins a pot, so the only
    caller is APS_fnc_holdemSRV running on this machine. It is NOT remote-executable (absent from
    == 0 for that reason -- mode = 1 already makes it unreachable from the wire, and the assert is
    the belt to that brace.

    THE PAGE'S EVALUATOR IS THE SPECIFICATION. ui\html\casino\holdem.html carries the designer's
    own ev5 / best7 / cmp / handLabel as its offline demo engine, and the labels it prints are the
    ones players will have seen in review. This file is a line-for-line port of those four
    functions, deliberately -- including the label punctuation ("TWO PAIR · KS & 9S", the middot
    and the plural S). A server that scored a hand differently from the page's demo would look
    like the table cheating, and a label the page never produced would look like a different game.

    CARDS are ints 0-51, the page's encoding: suit = floor(c / 13) in C,D,H,S order, rank = c mod
    13 running 2..A (so rank 12 is the ace and rank 3 is the five -- the wheel's high card).

    A SCORE is [category, tiebreak…], comparable lexicographically, longer-is-not-better:
        0 high card   1 pair   2 two pair   3 trips   4 straight
        5 flush       6 full house   7 quads   8 straight flush
    For a STRAIGHT (or straight flush) the tail is a single element, the straight's high rank; for
    everything else it is the distinct ranks ordered by count descending then rank descending, so
    a pair's tail is [pairRank, k1, k2, k3] and a flush's is its five ranks. That shape is the
    page's, not a preference -- see ev5's `return [cat].concat(st ? [sh] : g)`.

    API
        ["score", _cards]        _cards = 5, 6 or 7 ints  -> the BEST five-card score
        ["label", _score]        a score                  -> the page's hand name
        ["cmp",   [_a, _b]]      two scores               -> 1 / 0 / -1
        ["test"]                 run the 16 fixed vectors, PASS/FAIL to the RPT, -> [passed, total]

    THE SELF-TEST IS THE POINT OF THE FILE BEING SEPARATE. Poker scoring is exactly the kind of
    code that is wrong in one corner and looks right for weeks -- the wheel, a short flush that is
    also a straight, a full house whose PAIR is the higher rank, an odd chip in a split. The
    sixteen vectors below were produced by running the page's own reference implementation, so a
    FAIL means this port drifted from the file the owner reviewed, not that poker changed.

        Dev, on the server (debug console, server exec):   ["test"] call APS_fnc_holdemEval;
        RPT:  [HOLDEM-EVAL] PASS  wheel A-5 straight  score [4,3]  "STRAIGHT · 5 HIGH"
              [HOLDEM-EVAL] 16/16 PASS
*/

if (!isServer) exitWith { [] };
params [["_case", "score", [""]], ["_data", [], [[]]]];
// NO ORIGIN GATE HERE, DELIBERATELY -- and it cost a live table to learn why. This is a pure
// helper called synchronously from fn_holdemSRV's settle, which runs inside the ACTING CLIENT's
// remote-exec frame: remoteExecutedOwner is that player's id for the whole frame, nested calls
// included. Any owner check therefore refuses every real showdown while passing the self-test
// (which runs server-local), and settle then compared empty scores -- the highest-numbered seat
// won every pot (owner report + [HOLDEM-EVAL] refused: remote caller 6, 2026-08-20).
// The real protection is CfgRE: this function is not whitelisted under mode = 1, so no client can
// invoke it remotely at all. isServer below is the only guard this needs.

private _RN = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"];

// ── cmp ──────────────────────────────────────────────────────────────────────
// No exitWith. `exitWith` inside a for/forEach body exits the LOOP, which is the idiom this
// codebase uses elsewhere -- but a comparator is read far more often than it is written, and a
// while-with-a-flag needs no reader to know that rule.
private _cmp = {
    params ["_x", "_y"];
    private _r = 0;
    private _n = (count _x) max (count _y);
    private _i = 0;
    while { _r isEqualTo 0 && {_i < _n} } do {
        private _d = (_x param [_i, 0]) - (_y param [_i, 0]);
        if (_d > 0) then { _r = 1 } else { if (_d < 0) then { _r = -1 } };
        _i = _i + 1;
    };
    _r
};

// ── ev5: score exactly five cards ────────────────────────────────────────────
private _ev5 = {
    params ["_cs"];
    private _rs = [];
    { _rs pushBack (_x mod 13) } forEach _cs;
    _rs sort false;                                     // ranks, descending -- the page's sort

    private _s0 = floor ((_cs select 0) / 13);
    private _fl = true;
    { if (floor (_x / 13) isNotEqualTo _s0) then { _fl = false } } forEach _cs;

    private _u = [];                                    // distinct ranks, still descending
    { _u pushBackUnique _x } forEach _rs;

    private _st = false; private _sh = -1;
    if ((count _u) isEqualTo 5) then {
        if (((_u select 0) - (_u select 4)) isEqualTo 4) then { _st = true; _sh = _u select 0 }
        else {
            // THE WHEEL. A,5,4,3,2 is a five-high straight, and the ace plays LOW: the tail is 3,
            // the rank index of the five. Nothing else in the file treats an ace as anything but
            // the top card, so this is the one place the exception lives.
            if ((_u select 0) isEqualTo 12 && {(_u select 1) isEqualTo 3}) then { _st = true; _sh = 3 };
        };
    };

    private _cnt = createHashMap;
    { _cnt set [_x, (_cnt getOrDefault [_x, 0]) + 1] } forEach _rs;

    // _g: distinct ranks ordered by COUNT descending, then RANK descending. Selection sort over at
    // most five entries -- `sort` on an array of pairs would work but its ordering rules are one
    // more thing to be right about, and this is five elements.
    private _g = [];
    private _pool = +_u;
    while { (count _pool) > 0 } do {
        private _bi = 0;
        for "_i" from 1 to ((count _pool) - 1) do {
            private _a = _pool select _i;
            private _b = _pool select _bi;
            private _ca = _cnt get _a;
            private _cb = _cnt get _b;
            if (_ca > _cb || {_ca isEqualTo _cb && {_a > _b}}) then { _bi = _i };
        };
        _g pushBack (_pool deleteAt _bi);
    };

    private _shape = "";
    { _shape = _shape + str (_cnt get _x) } forEach _g;   // "41" quads, "32" boat, "221" two pair…
    private _s1 = _shape select [0, 1];

    private _cat = switch (true) do {
        case (_st && _fl):              { 8 };
        case (_s1 isEqualTo "4"):       { 7 };
        case (_shape isEqualTo "32"):   { 6 };
        case (_fl):                     { 5 };
        case (_st):                     { 4 };
        case (_s1 isEqualTo "3"):       { 3 };
        case (_shape isEqualTo "221"):  { 2 };
        case (_s1 isEqualTo "2"):       { 1 };
        default                         { 0 };
    };

    private _score = [_cat];
    if (_st) then { _score pushBack _sh } else { { _score pushBack _x } forEach _g };
    _score
};

// ── best five of five/six/seven ──────────────────────────────────────────────
private _best = {
    params ["_cards"];
    private _n = count _cards;
    if (_n < 5) exitWith { [0] };
    if (_n isEqualTo 5) exitWith { [_cards] call _ev5 };
    private _bs = [];
    // Drop every combination of (_n - 5) cards. For seven that is the page's 21 pairs; for six it
    // is the six single drops.
    if (_n isEqualTo 6) then {
        for "_a" from 0 to 5 do {
            private _five = [];
            for "_k" from 0 to 5 do { if (_k isNotEqualTo _a) then { _five pushBack (_cards select _k) } };
            private _s = [_five] call _ev5;
            if (_bs isEqualTo [] || {([_s, _bs] call _cmp) > 0}) then { _bs = _s };
        };
    } else {
        for "_a" from 0 to (_n - 2) do {
            for "_b" from (_a + 1) to (_n - 1) do {
                private _five = [];
                for "_k" from 0 to (_n - 1) do {
                    if (_k isNotEqualTo _a && {_k isNotEqualTo _b}) then { _five pushBack (_cards select _k) };
                };
                if ((count _five) isEqualTo 5) then {
                    private _s = [_five] call _ev5;
                    if (_bs isEqualTo [] || {([_s, _bs] call _cmp) > 0}) then { _bs = _s };
                };
            };
        };
    };
    _bs
};

// ── label: the page's handLabel, character for character ─────────────────────
private _label = {
    params ["_s"];
    if ((count _s) < 2) exitWith { "" };
    private _c = _s select 0;
    private _r1 = _RN param [(_s param [1, 0]), "?"];
    private _r2 = _RN param [(_s param [2, 0]), "?"];
    switch (_c) do {
        case 8: { if ((_s select 1) isEqualTo 12) then { "ROYAL FLUSH" } else { format ["STRAIGHT FLUSH · %1 HIGH", _r1] } };
        case 7: { format ["QUADS · %1S", _r1] };
        case 6: { format ["FULL HOUSE · %1S OVER %2S", _r1, _r2] };
        case 5: { format ["FLUSH · %1 HIGH", _r1] };
        case 4: { format ["STRAIGHT · %1 HIGH", _r1] };
        case 3: { format ["TRIPS · %1S", _r1] };
        case 2: { format ["TWO PAIR · %1S & %2S", _r1, _r2] };
        case 1: { format ["PAIR OF %1S", _r1] };
        default { format ["%1 HIGH", _r1] };
    };
};

switch (toLower _case) do {

    case "score": { [_data] call _best };
    case "label": { [_data] call _label };
    case "cmp":   { [(_data param [0, []]), (_data param [1, []])] call _cmp };

    // ── the self-test ────────────────────────────────────────────────────────
    // Vectors are written in card notation and parsed here, so the table reads as poker rather
    // than as 112 integers. "As" = ace of spades; T is the ten. The expected score and label came
    // out of the page's own evaluator, run over these exact hands.
    case "test": {
        private _su = createHashMapFromArray [["c", 0], ["d", 1], ["h", 2], ["s", 3]];
        private _rk = createHashMapFromArray [
            ["2",0],["3",1],["4",2],["5",3],["6",4],["7",5],["8",6],["9",7],["T",8],["J",9],["Q",10],["K",11],["A",12]];
        private _parse = {
            params ["_str"];
            private _out = [];
            {
                if (_x isNotEqualTo "") then {
                    private _r = _rk getOrDefault [(_x select [0, 1]), -1];
                    private _s = _su getOrDefault [(_x select [1, 1]), -1];
                    if (_r < 0 || {_s < 0}) then { diag_log format ["[HOLDEM-EVAL] bad card token '%1'", _x] }
                    else { _out pushBack (_s * 13 + _r) };
                };
            } forEach (_str splitString " ");
            _out
        };

        // [name, handA, expectedScoreA, expectedLabelA, handB|"", expectedScoreB, expectedLabelB, expectedCmp]
        private _vectors = [
            ["wheel A-5 straight",           "Ac 2d 3h 4s 5c Kd 9h", [4,3],              "STRAIGHT · 5 HIGH",       "", [], "", 0],
            ["broadway straight",            "Ac Kd Qh Js Tc 3d 8h", [4,12],             "STRAIGHT · A HIGH",       "", [], "", 0],
            ["flush beats straight",         "2h 5h 9h Jh Kh 3c 4d", [5,11,9,7,3,0],     "FLUSH · K HIGH",          "Ac Kd Qh Js Tc 3s 8h", [4,12],  "STRAIGHT · A HIGH",       1],
            ["full house, trips rank wins",  "9c 9d 9h 4s 4d 2c 7h", [6,7,2],            "FULL HOUSE · 9S OVER 4S", "8c 8d 8h Ks Kd 2s 7d", [6,6,11], "FULL HOUSE · 8S OVER KS", 1],
            ["full house, pair rank breaks", "9c 9d 9h Ks Kd 2c 3h", [6,7,11],           "FULL HOUSE · 9S OVER KS", "9s 9c 9d 4s 4d 2s 3d", [6,7,2],  "FULL HOUSE · 9S OVER 4S", 1],
            ["board plays -- split",         "2c 3d 7h Jc Qd Kh As", [0,12,11,10,9,5],   "A HIGH",                  "2s 3h 7d Jc Qd Kh As", [0,12,11,10,9,5], "A HIGH",        0],
            ["pair, kicker chain",           "Ac Ad Kh 9s 4c 3d 2h", [1,12,11,7,2],      "PAIR OF AS",              "As Ah Qh 9c 4d 3s 2c", [1,12,10,7,2], "PAIR OF AS",       1],
            ["straight flush",               "5s 6s 7s 8s 9s 2c Kd", [8,7],              "STRAIGHT FLUSH · 9 HIGH", "", [], "", 0],
            ["royal beats straight flush",   "Ah Kh Qh Jh Th 2c 3d", [8,12],             "ROYAL FLUSH",             "9s 8s 7s 6s 5s 2d 3c", [8,7],   "STRAIGHT FLUSH · 9 HIGH", 1],
            ["quads beat full house",        "7c 7d 7h 7s Kd 2c 3h", [7,5,11],           "QUADS · 7S",              "Ac Ad Ah Ks Kh 2d 3s", [6,12,11], "FULL HOUSE · AS OVER KS", 1],
            ["quads, kicker breaks",         "7c 7d 7h 7s Ad 2c 3h", [7,5,12],           "QUADS · 7S",              "7c 7d 7h 7s Kd 2d 3s", [7,5,11], "QUADS · 7S",             1],
            ["two pair, kicker breaks",      "Kc Kd 9h 9s Ad 2c 3h", [2,11,7,12],        "TWO PAIR · KS & 9S",      "Ks Kh 9c 9d Qd 2d 3s", [2,11,7,10], "TWO PAIR · KS & 9S",  1],
            ["trips beat two pair",          "5c 5d 5h Kd 9s 2c 3h", [3,3,11,7],         "TRIPS · 5S",              "Ac Ad Kh Ks 9d 2d 3s", [2,12,11,7], "TWO PAIR · AS & KS",  1],
            ["steel wheel straight flush",   "As 2s 3s 4s 5s Kd 9h", [8,3],              "STRAIGHT FLUSH · 5 HIGH", "9c 8c 7c 6c 5c 2d 3h", [8,7],   "STRAIGHT FLUSH · 9 HIGH", -1],
            ["high card, 5th kicker",        "Ac Kd Qh Js 9c 3d 2h", [0,12,11,10,9,7],   "A HIGH",                  "As Kh Qc Jd 8s 3h 2c", [0,12,11,10,9,6], "A HIGH",        1],
            ["straight on board -- split",   "9c 8d 7h 6s 5c 2d 3h", [4,7],              "STRAIGHT · 9 HIGH",       "9s 8h 7d 6c 5d 2s 3c", [4,7],   "STRAIGHT · 9 HIGH",       0]
        ];

        private _pass = 0;
        {
            _x params ["_nm", "_ha", "_ea", "_la", "_hb", "_eb", "_lb", "_ec"];
            private _sa = [([_ha] call _parse)] call _best;
            private _ga = [_sa] call _label;
            private _ok = (_sa isEqualTo _ea) && {_ga isEqualTo _la};
            private _detail = format ["score %1 %2", _sa, str _ga];
            if (_hb isNotEqualTo "") then {
                private _sb = [([_hb] call _parse)] call _best;
                private _gb = [_sb] call _label;
                private _gc = [_sa, _sb] call _cmp;
                _ok = _ok && {_sb isEqualTo _eb} && {_gb isEqualTo _lb} && {_gc isEqualTo _ec};
                _detail = format ["%1 vs %2 %3 -> cmp %4 (want %5)", _detail, _sb, str _gb, _gc, _ec];
            };
            if (_ok) then { _pass = _pass + 1 };
            diag_log format ["[HOLDEM-EVAL] %1  %2  %3", (["FAIL", "PASS"] select _ok), _nm, _detail];
        } forEach _vectors;

        diag_log format ["[HOLDEM-EVAL] %1/%2 PASS", _pass, count _vectors];
        [_pass, count _vectors]
    };

    default { diag_log format ["[HOLDEM-EVAL] unknown case '%1'", _case]; [] };
};
