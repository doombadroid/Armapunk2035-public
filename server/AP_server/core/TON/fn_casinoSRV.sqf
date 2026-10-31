/*
    APS_fnc_casinoSRV  (LooneyBin -- Casino phone app: Coin Flip / Wheel / Slots / Roulette / Hi-Lo.
    SERVER-AUTHORITATIVE. One engine for all five "simple" casino games; blackjack keeps its own
    APS_fnc_blackJackSRV (multi-hand state). Modeled 1:1 on that engine's security spine.)

    Client dispatcher: mission core/casino/fn_casino.sqf sends only the player's INTENT
    ([_game, _action, _data]); this server fn owns every RNG roll and every payout amount. For the
    stateful game (Hi-Lo) the run STATE lives here (AP_casinoHiLo, keyed by uid) so a client can't
    forge a streak or re-roll until it wins. CfgRE: this fn is allowedTargets=2 (client->server). The
    result callbacks (AP_fnc_casino render / AP_fnc_casinoReceive credit) are server->client =
    exempt from mode=1.

    MONEY MODEL (identical to blackjack -- security.md 2.4 / gambling.md 8): AP_atmcash is a CLIENT
    cache; the client debits the bet locally BEFORE each play/deal (can't be server-enforced -- same
    limit as all LB cash). So the server NETS the game: it only ever CREDITS the server-computed return
    via the owner-2-gated receiver, NEVER echoes a bet, and LOGS every game (-CASINOBET- wager +
    -CASINO<GG>- net) so CLANKR mass-balances wager-in vs payout-out. A cheater who skips the client
    debit shows up as anomalous casino net-gain -> CLANKR.

    HOUSE EDGE (owner 2026-07-07: aggressive inflation-sink posture):
      Coin Flip  ~8%   (win prob 0.46, pays 2x)
      Wheel      ~11%  (weighted, RTP 0.89)
      Slots      ~12%  (3-of-a-kind paytable, RTP ~0.881)
      Roulette   ~5.26% (American double-zero, standard payouts)
      Hi-Lo      ~10% per step (0.90 fair-mult factor -- compounds the longer they push)

    PROTOCOL (client -> APS_fnc_casinoSRV, target 2): [_game, _action, _data]
      ["coinflip","play",[_bet,_pick]]         _pick 0=heads 1=tails
      ["wheel",   "play",[_bet]]
      ["slots",   "play",[_bet]]
      ["roulette","play",[_bet,_betType,_val]] _betType straight/red/black/odd/even/high/low/dozen1..3;
                                               _val = number 0..37 (37="00") for straight, else ignored
      ["hilo",    "deal",[_bet]]               start a run (client debited _bet)
      ["hilo",    "guess",[_dir]]              _dir "hi"/"lo"
      ["hilo",    "cashout",[]]                bank the current return and end the run
      ["hilo",    "quit",[]]                   abandon in-progress run (no payout; bet already debited)

    RESULT (server -> client):
      [["result", _game, _payload], "AP_fnc_casino", _caller, false] spawn AP_fnc_MP
      [[_return], "AP_fnc_casinoReceive", _caller, false] spawn AP_fnc_MP   (owner-2-gated bank credit)
*/
params [["_game", "", [""]], ["_action", "", [""]], ["_data", [], [[]]]];

private _MIN_BET = 10000;
private _MAX_BET = 500000;

// -- identity (non-spoofable): derive the actor from remoteExecutedOwner, never from the payload --
private _src = remoteExecutedOwner;
if (_src isEqualTo 0) exitWith {};                        // no server-internal path -- every case is player-driven
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};                         // spoofed / vanished caller
private _uid = getPlayerUID _caller;
if (_uid isEqualTo "") exitWith {};

// -- self-exclusion (casino-wide; same map/column blackjack uses) --
if ((!isNil "AP_bjBanned") && {AP_bjBanned getOrDefault [_uid, false]}) exitWith {
    ["-CASINOBAN-", _caller, format ["blocked %1 (self-excluded)", _game]] call APS_fnc_logIt;};

// -- anti-spam: light per-uid cooldown (a human can't click faster than ~4/s; blocks auto-clickers) --
// owner 2026-07-08: EXEMPT terminal actions (hilo cashout/quit). A teardown fired <0.20s after the prior guess
// was being DROPPED here, orphaning AP_casinoHiLo[uid] -> the next deal silently exitWith'd and ATE the bet
// with a frozen table. Only "play"/"deal"/"guess"/"spin" (money-placing or roll-advancing) need the throttle.
private _cdVar = format ["AP_casinoCD_%1", _uid];
private _now = diag_tickTime;
if (!(_action in ["cashout","quit"]) && {(_now - (missionNamespace getVariable [_cdVar, -999])) < 0.20}) exitWith {};
// owner 2026-07-08: only STAMP the clock for throttled actions. If a terminal cashout/quit reset it, the very next
// "deal" (carrying a fresh client-debited bet) would be the one dropped -- the same eaten-bet symptom, shifted to the
// cashout->deal / quit->deal order via a "deal again" click.
if (!(_action in ["cashout","quit"])) then { missionNamespace setVariable [_cdVar, _now]; };

// -- shared helpers --
private _clampBet = { params ["_b"]; _b = round _b; if (_b < _MIN_BET) then { -1 } else { _b min _MAX_BET } };
private _credit   = { params ["_ret"]; if (_ret > 0) then { [[_ret], "AP_fnc_casinoReceive", _caller, false] spawn AP_fnc_MP; }; };
private _render   = { params ["_g", "_payload"]; [["result", [_g, _payload]], "AP_fnc_casino", _caller, false] spawn AP_fnc_MP; };   // _this = ["result",[game,payload]] -> client _mode="result", _args=[game,payload]
private _san      = { (format ["%1", _this]) splitString "\'""" joinString "" };   // SQLi guard for unparameterized asyncQuery (_uid is a Steam64 anyway)
private _uidSql   = _uid call _san;

// -- OWNER-MODE RIG (secret; NOT in patchnotes) -- the owner's FIRST play of each casino game this session
// is a guaranteed MAX win. In-memory, per-game (resets every restart), owner-UID gated (server-derived, not
// spoofable). AP_casinoOwnerRig is shared with blackjack (distinct game keys, no collision).
private _OWNER_UID = "76561190000000001";
if (isNil "AP_casinoOwnerRig") then { AP_casinoOwnerRig = createHashMap; };
private _rigFirst = {params ["_g"];
    if (_uid isNotEqualTo _OWNER_UID) exitWith { false };
    if (AP_casinoOwnerRig getOrDefault [_g, false]) exitWith { false };
    AP_casinoOwnerRig set [_g, true];
    true};

switch (toLower _game) do {

    // ============================================================ COIN FLIP ============================================================
    // Even-money look, 8% edge: win probability 0.46, correct guess returns 2x the bet. _pick 0=heads 1=tails.
    case "coinflip": {if (_action isNotEqualTo "play") exitWith {};
        private _bet = [_data param [0, 0]] call _clampBet;
        if (_bet < 0) exitWith {};
        private _pick = (_data param [1, 0]) call { params ["_p"]; if (_p isEqualType 0 && {_p in [0,1]}) then {_p} else {0} };
        ["-CASINOBET-", _caller, format ["$%1 coinflip", _bet]] call APS_fnc_logIt;

        // server owns the flip: win with prob 0.46. The SHOWN face is the outcome the player experiences:
        // if they win, the coin landed on their pick; if they lose, it landed on the other side.
        private _win  = (random 1) < 0.46;
        if (["coinflip"] call _rigFirst) then { _win = true; };   // owner first coinflip = win
        private _face = if (_win) then { _pick } else { 1 - _pick };
        private _ret  = if (_win) then { _bet * 2 } else { 0 };
        private _net  = _ret - _bet;
        ["-CASINOCF-", _caller, format ["net $%1 (coinflip, wagered $%2, returned $%3, pick %4, face %5)", _net, _bet, _ret, _pick, _face]] call APS_fnc_logIt;

        ["coinflip", [_win, _pick, _face, _bet, _ret, _net]] call _render;
        [_ret] call _credit;   // credit the server-computed return only (0 on a loss); bet was debited client-side
    };

    // ============================================================ WHEEL SPIN (daily PRIZE wheel) ============================================================
    // Owner 2026-07-07: NOT a bet game. One FREE spin per 24h (players.wheel_last_free), then $50k/spin (client-debited).
    // Prize pool (weighted /1000): cash 1k-200k (skew-low) | 1k-10k civ XP | Ifrit | Qilin | Blackfish (to garage).
    // 12 visual segments map to prize types; the server rolls the PRIZE by weight, then lands the wheel on a
    // matching segment (visual only). Vehicles are INSERTed into the personal garage (fn_loginBonusSRV pattern).
    //   ["wheel","checkfree",[]]   -> render ["status", isFree, cost]
    //   ["wheel","spin",[wantFree]] -> deliver + render ["spin", seg, prize, cash, xp, label, wasFree]
    case "wheel": {private _COST = 50000;
        private _freeSql = format ["SELECT (wheel_last_free IS NULL OR wheel_last_free < (NOW() - interval '24 hour')) AS wheel_last_free FROM players WHERE playerid='%1'", _uidSql];

        switch (toLower _action) do {case "checkfree": {private _r = [_freeSql, 2] call DB_fnc_asyncQuery;
                private _free = if (_r isEqualType [] && {count _r > 0}) then { ((_r select 0) param [0, 0]) isEqualTo 1 } else { false };
                ["wheel", ["status", _free, _COST]] call _render;};

            case "spin": {
                // authoritative free/paid (never trust the client's wantFree). TOCTOU GUARD (owner 2026-07-08):
                // two spins in the same tick both pass the cooldown and both read the still-uncommitted
                // wheel_last_free -> both resolve "free" -> a repeatable $0 spin. Close it with an in-memory claim
                // stamped SYNCHRONOUSLY right after the DB read (no suspension between check and set), so the second
                // concurrent spin sees the first's claim and resolves PAID even before the DB write commits.
                if (isNil "AP_casinoWheelFreeMem") then { AP_casinoWheelFreeMem = createHashMap; };
                private _r = [_freeSql, 2] call DB_fnc_asyncQuery;
                private _dbFree = if (_r isEqualType [] && {count _r > 0}) then { ((_r select 0) param [0, 0]) isEqualTo 1 } else { false };
                private _memClaim = AP_casinoWheelFreeMem getOrDefault [_uid, -99999];
                private _free = _dbFree && {(_now - _memClaim) > 5};   // in-memory claim covers the DB write-lag window
                private _cost = if (_free) then { 0 } else { _COST };
                if (_free) then {AP_casinoWheelFreeMem set [_uid, _now];   // claim synchronously, BEFORE the async UPDATE can suspend
                    [format ["UPDATE players SET wheel_last_free = NOW() WHERE playerid='%1'", _uidSql]] call DB_fnc_asyncQuery;};
                ["-CASINOBET-", _caller, format ["$%1 wheel (%2)", _cost, if (_free) then {"free daily"} else {"paid"}]] call APS_fnc_logIt;

                // roll the prize by weight (tunable). owner 2026-07-08: the old "xp" slot is now "bust" -- a server-wide
                // DRUG BUST event (all illegal drugs +12% sell for 5 min) instead of a personal civ-XP payout.
                private _prizes  = ["cash", "bust", "ifrit", "qilin", "blackfish"];
                private _weights = [700, 225, 40, 25, 10];
                private _prize = _prizes selectRandomWeighted _weights;   // BINARY syntax (arr selectRandomWeighted weights); the [arr,weights] form is invalid

                // owner 2026-07-08 (anti-mint): cap per-uid daily VEHICLE jackpots. Otherwise a farmer spinning $50k
                // mints unlimited Ifrit/Qilin/Blackfish -- invisible to the cash-only -CASINOWH- net (which goes MORE
                // negative on a vehicle win, so CLANKR reads the farmer as a loser). Over the daily cap the win
                // DOWNGRADES to a normal cash prize; decided HERE (before _seg) so the wheel lands on a cash segment.
                if (_prize in ["ifrit","qilin","blackfish"]) then {
                    if (isNil "AP_casinoVehDay") then { AP_casinoVehDay = createHashMap; };
                    private _dayKey = format ["%1-%2-%3", date select 0, date select 1, date select 2];
                    private _rec = AP_casinoVehDay getOrDefault [_uid, ["", 0]];
                    private _cnt = if ((_rec select 0) isEqualTo _dayKey) then { _rec select 1 } else { 0 };
                    if (_cnt >= 3) then {
                        ["-CASINOVEH-", _caller, format ["net $0 (daily vehicle-jackpot cap %1 hit -> %2 downgraded to cash)", _cnt, _prize]] call APS_fnc_logIt;
                        _prize = "cash";} else {AP_casinoVehDay set [_uid, [_dayKey, _cnt + 1]];};};

                if (["wheel"] call _rigFirst) then { _prize = "blackfish"; };   // owner first wheel = top jackpot (bypasses the daily veh cap)

                // pick a wheel SEGMENT of that prize type (visual landing target) -- MUST match gen_wheel_art.py SEG
                private _segMap = ["cash","bust","cash","ifrit","cash","bust","cash","qilin","cash","bust","cash","blackfish"];
                private _segs = []; { if (_x isEqualTo _prize) then { _segs pushBack _forEachIndex; }; } forEach _segMap;
                private _seg = selectRandom _segs;

                private _cashWon = 0; private _xpWon = 0; private _veh = ""; private _label = "";
                switch (_prize) do {
                    case "cash":      { _cashWon = 1000 + floor (((random 1) ^ 3) * 199000); _label = format ["$%1", _cashWon]; };   // skew-low (avg ~50k)
                    case "bust": {
                        // owner 2026-07-08: server-wide DRUG BUST -- all illegal drugs +12% sell for 5 min. NON-STACKING:
                        // if a bust is already running, a new BUST win does NOT extend it, re-apply the 12%, or notify --
                        // it's a no-op for the event (only this player is told it's already active). A fresh bust can only
                        // start once the previous one has expired. The 12% is a flat boolean in marketFactor, never doubled.
                        // the window lives server-only in localNamespace (APS_fnc_marketTick); AP_drugBustUntil is the
                        // client display copy, which any client can publicVariable over.
                        if (serverTime >= (localNamespace getVariable ["APS_drugBustUntil", 0])) then {
                            localNamespace setVariable ["APS_drugBustUntil", serverTime + 300];
                            AP_drugBustUntil = localNamespace getVariable "APS_drugBustUntil";
                            publicVariable "AP_drugBustUntil";
                            ["<t size='1.35' color='#e0b000'>DRUG BUST!</t><br/>All drug prices are +12% server-wide for 5 minutes -- sell now!", "servernotice"] remoteExec ["AP_fnc_handleMessage", -2];
                            ["-CASINOWH-", _caller, "triggered a server-wide DRUG BUST (+12% drug sell, 5min)"] call APS_fnc_logIt;
                            // announce the end -- but only if it wasn't superseded/extended (guard against a handoff bust)
                            private _endAt = localNamespace getVariable "APS_drugBustUntil";
                            [_endAt] spawn { params ["_e"]; uiSleep 300; private _u = localNamespace getVariable ["APS_drugBustUntil", 0]; if (serverTime >= (_u - 1) && {_u isEqualTo _e}) then { ["<t size='1.2' color='#c0c0c0'>The Drug Bust has ended.</t>", "servernotice"] remoteExec ["AP_fnc_handleMessage", -2]; }; };
                            _label = "DRUG BUST";} else {
                            ["-CASINOWH-", _caller, "won wheel BUST during an active bust -- not stacked"] call APS_fnc_logIt;
                            _label = "DRUG BUST ACTIVE";   // already running -> tell only this player, no global notify
                        };};
                    case "ifrit":     { _veh = "O_MRAP_02_F";            _label = "IFRIT"; };
                    case "qilin":     { _veh = "O_LSV_02_armed_F";       _label = "QILIN"; };
                    case "blackfish": { _veh = "B_T_VTOL_01_infantry_F"; _label = "BLACKFISH"; };   // owner 2026-07-08: was O_T_VTOL_02_infantry_F (CSAT Y-32 Xi'an) -- the real Blackfish is B_T_VTOL_01_infantry_F (matches fn_vehicleConfig cop_air)
                };

                // deliver: cash -> bank (server-gated credit); vehicle -> garage INSERT (active=0); XP -> client-side
                if (_cashWon > 0) then { [_cashWon] call _credit; };
                if (_veh isNotEqualTo "") then {
                    private _type = switch (true) do { case (_veh isKindOf "Air"): {"Air"}; case (_veh isKindOf "Ship"): {"Ship"}; default {"Car"} };
                    private _plate = round (random [100000, 550000, 999999]);
                    [format ["INSERT INTO %1 (side, classname, type, pid, alive, active, inventory, color, plate, fuel, damage, alarm) VALUES ('civ', '%2', '%3', '%4', '1', '0', '[]', '0', '%5', '100', '0', '0')", "vehicles", _veh, _type, _uidSql, _plate]] call DB_fnc_asyncQuery;
                    // owner 2026-07-08: book the vehicle's ASSESSED asset value as a distinct faucet row so CLANKR's
                    // casino mass-balance actually SEES it (the -CASINOWH- row below only carries the cash side = -cost).
                    private _vehVal = switch (_prize) do { case "ifrit": {1250000}; case "qilin": {2000000}; case "blackfish": {5000000}; default {0} };
                    ["-CASINOVEH-", _caller, format ["net $%1 (wheel jackpot %2 to garage, assessed asset value; $%3 cost booked in -CASINOWH-)", _vehVal, _label, _cost]] call APS_fnc_logIt;
                };

                private _net = _cashWon - _cost;   // money side only (vehicle/XP aren't cash); paid spins net negative = economy sink
                ["-CASINOWH-", _caller, format ["net $%1 (wheel, cost $%2, won %3, free %4)", _net, _cost, _label, _free]] call APS_fnc_logIt;
                ["wheel", ["spin", _seg, _prize, _cashWon, _xpWon, _label, _free]] call _render;};

            default {};};};

    // ============================================================ SLOTS ============================================================
    // 3 independent weighted reels, pay 3-of-a-kind only. Symbols 0..4 = cherry/lemon/bell/bar/seven.
    // Reel weights [6,5,4,3,2]/20. Return multiples (3-oak): cherry 8x, lemon 12x, bell 22x, bar 45x, seven 150x.
    // RTP ~= 0.881 (11.9% edge). Independent reels give authentic near-miss feel.
    case "slots": {if (_action isNotEqualTo "play") exitWith {};
        private _bet = [_data param [0, 0]] call _clampBet;
        if (_bet < 0) exitWith {};
        // owner 2026-07-08: slots $100k cap REMOVED -- $250k/$500k bets restored (bet already clamped to _MAX_BET $500k by _clampBet).
        ["-CASINOBET-", _caller, format ["$%1 slots", _bet]] call APS_fnc_logIt;

        private _syms    = [0, 1, 2, 3, 4];
        private _weights = [6, 5, 4, 3, 2];
        private _pay     = [8, 12, 22, 45, 150];   // 3-of-a-kind return multiple, indexed by symbol
        private _r1 = _syms selectRandomWeighted _weights;
        private _r2 = _syms selectRandomWeighted _weights;
        private _r3 = _syms selectRandomWeighted _weights;
        private _rigged = ["slots"] call _rigFirst;
        if (_rigged) then { _r1 = 4; _r2 = 4; _r3 = 4; };   // owner first slots = jackpot 777 (150x)
        // owner 2026-07-14: natural 777 nerfed ~100x (too many players getting rich). The owner rig above is
        // EXEMPT. Tunable live via AP_slotsJackpotNerf (1 = off, 100 = 100x harder). On a NATURAL triple-seven,
        // keep it only 1/nerf of the time; otherwise reroll the last reel to a NON-seven (weighted) -> near-miss.
        // It is a localNamespace variable (server exec: localNamespace setVariable ["AP_slotsJackpotNerf", N]):
        // as a missionNamespace global any client could publicVariable it to 1 (audit Lsec-0-1).
        private _jackpotNerf = localNamespace getVariable ["AP_slotsJackpotNerf", 100];
        if (!_rigged && {_r1 isEqualTo 4} && {_r2 isEqualTo 4} && {_r3 isEqualTo 4} && {_jackpotNerf > 1} && {random 1 >= (1 / _jackpotNerf)}) then {
            _r3 = _syms selectRandomWeighted [6, 5, 4, 3, 0];};
        private _mult = if (_r1 isEqualTo _r2 && {_r2 isEqualTo _r3}) then { _pay select _r1 } else { 0 };
        private _ret  = _bet * _mult;
        private _net  = _ret - _bet;
        ["-CASINOSL-", _caller, format ["net $%1 (slots, wagered $%2, returned $%3, reels [%4,%5,%6], mult %7x)", _net, _bet, _ret, _r1, _r2, _r3, _mult]] call APS_fnc_logIt;

        ["slots", [[_r1, _r2, _r3], _mult, _bet, _ret, _net]] call _render;
        [_ret] call _credit;};

    // ============================================================ ROULETTE ============================================================
    // American double-zero wheel: 38 pockets (0, 00, 1..36). TWO green pockets (0 and 00) -> uniform 5.26% house
    // edge on every bet type (owner 2026-07-08: restored the documented double-zero design; the impl had drifted to
    // single-zero ~2.7%, half the intended edge and the cheapest game). Protocol: _betVal 0..36 for a number, 37="00".
    //   straight 35:1 (return 36x) | red/black/odd/even/high/low 1:1 (2x) | dozen 2:1 (3x)
    case "roulette": {if (_action isNotEqualTo "play") exitWith {};
        private _bet = [_data param [0, 0]] call _clampBet;
        if (_bet < 0) exitWith {};
        private _betType = toLower (_data param [1, ""]);
        private _betVal  = round (_data param [2, -1]);
        ["-CASINOBET-", _caller, format ["$%1 roulette %2 %3", _bet, _betType, _betVal]] call APS_fnc_logIt;

        // owner 2026-07-08 (guard): a straight bet MUST name a real pocket (0..37; 37="00"). Post fix #4/#10 a LEGIT
        // client can no longer emit a malformed straight, so this path is only reachable by a TAMPERED client ->
        // resolve it as a normal LOSS (the bet was debited client-side like any wager; the house keeps it) and render
        // a defined outcome so the table doesn't soft-lock. NEVER credit here: a refund would be a cheater-only money
        // faucet, and (logged as net $0) invisible to CLANKR's mass-balance.
        if (_betType isEqualTo "straight" && {!(_betVal in [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37])}) exitWith {
            ["-CASINORL-", _caller, format ["net $-%1 (roulette LOSS -- malformed straight val %2, no payout)", _bet, _betVal]] call APS_fnc_logIt;
            ["roulette", [0, false, true, false, _bet, 0, (0 - _bet), _betType]] call _render;};

        private _spin = floor (random 38);                                        // 0..37 (37 = "00")
        if (["roulette"] call _rigFirst) then {
            // owner first roulette: whatever they bet LANDS and wins (straight = 36x)
            _spin = switch (_betType) do {case "straight": { _betVal };
                case "black":    { 2 };  case "even":   { 2 };
                case "high":     { 19 }; case "dozen2": { 13 }; case "dozen3": { 25 };
                default          { 1 };};};
        private _redNums = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
        private _isGreen = (_spin isEqualTo 0) || {_spin isEqualTo 37};            // two green pockets: 0 and 00
        private _isRed   = (_spin in _redNums);
        private _dozen = switch (true) do {case (_spin >= 1 && {_spin <= 12}):  { 1 };
            case (_spin >= 13 && {_spin <= 24}): { 2 };
            case (_spin >= 25 && {_spin <= 36}): { 3 };
            default { 0 };                                                         // 0 and 00 -> no dozen
        };
        private _win = false; private _mult = 0;
        if (_betType isEqualTo "straight") then {
            _win = (_betVal isEqualTo _spin); _mult = 36;                          // a straight on 0 or 00 (37) wins on its own pocket
        } else {if (!_isGreen) then {                                                  // every outside bet loses on 0 AND 00
                switch (_betType) do {case "red":    { _win = _isRed;                    _mult = 2; };
                    case "black":  { _win = !_isRed;                   _mult = 2; };
                    case "odd":    { _win = (_spin % 2) isEqualTo 1;   _mult = 2; };
                    case "even":   { _win = (_spin % 2) isEqualTo 0;   _mult = 2; };
                    case "low":    { _win = (_spin <= 18);             _mult = 2; };   // 1-18
                    case "high":   { _win = (_spin >= 19);            _mult = 2; };   // 19-36
                    case "dozen1": { _win = (_dozen isEqualTo 1);      _mult = 3; };
                    case "dozen2": { _win = (_dozen isEqualTo 2);      _mult = 3; };
                    case "dozen3": { _win = (_dozen isEqualTo 3);      _mult = 3; };
                    default {};};};};
        private _ret = if (_win) then { _bet * _mult } else { 0 };
        private _net = _ret - _bet;
        ["-CASINORL-", _caller, format ["net $%1 (roulette, wagered $%2, returned $%3, spin %4, bet %5 %6)", _net, _bet, _ret, _spin, _betType, _betVal]] call APS_fnc_logIt;

        ["roulette", [_spin, _isRed, _isGreen, _win, _bet, _ret, _net, _betType]] call _render;
        [_ret] call _credit;};

    // ============================================================ HI-LO ============================================================
    // Server keeps the run in AP_casinoHiLo[_uid] = [_curCard(0..51), _mult(accumulated return multiple), _bet].
    // Each correct guess grows _mult by (0.90 / P(correct)) -- a 10% edge per step that compounds. Cash out any
    // time to bank _bet*_mult; a wrong guess OR a tie (equal rank) ends the run with nothing.
    // ============================================================ CRASH (aviator) ============================================================
    // Multiplier climbs on a shared exp curve mult = e^(K*t). The server pre-rolls the bust point (NEVER told to the
    // client), stores the round, and owns a single bust timer. Cash out before the bust -> bank bet*mult; miss it -> lose
    // the bet. 7% instant-bust + a 1/(1-r) tail (cap 20x) = a ~7% house edge. Client render loop uses serverTime + the same
    // K, so both agree on the live multiplier without the server streaming ticks.
    case "crash": {if (isNil "AP_casinoCrash") then { AP_casinoCrash = createHashMap; };
        private _K = 0.1386;   // growth rate (2x ~5s, 10x ~17s) -- MUST match the client render loop in fn_casino.sqf
        private _run = AP_casinoCrash getOrDefault [_uid, []];
        switch (toLower _action) do {case "deal": {private _bet = [_data param [0, 0]] call _clampBet;
                if (_bet < 0) exitWith {};
                if (_run isNotEqualTo []) exitWith {};   // one round at a time
                ["-CASINOBET-", _caller, format ["$%1 crash", _bet]] call APS_fnc_logIt;
                private _r = random 1;
                private _bust = if (_r < 0.07) then { 1.0 } else { (0.93 / (1 - _r)) min 20 };   // 7% edge, 20x cap
                if (["crash"] call _rigFirst) then { _bust = 20.0; };   // owner first crash = 20x ceiling
                _bust = (round (_bust * 100)) / 100;
                if (_bust <= 1.0) exitWith {
                    ["-CASINOCR-", _caller, format ["net $-%1 (crash, wagered $%2, returned $0, insta-bust @1.00x)", _bet, _bet]] call APS_fnc_logIt;
                    ["crash", ["bust", 1.0, _bet, 0]] call _render;};
                private _start = serverTime;
                AP_casinoCrash set [_uid, [_bet, _bust, _start]];
                ["crash", ["start", _bet, _start]] call _render;
                // server-owned bust timer -- a cashout/quit deletes the state (timer then no-ops); a new round moves _start
                [_uid, _start, _bet, _bust, (((ln _bust) / _K) max 0.1), _caller] spawn {
                    params ["_uid", "_start", "_bet", "_bust", "_ttb", "_caller"];
                    uiSleep _ttb;
                    private _cur = AP_casinoCrash getOrDefault [_uid, []];
                    if (_cur isEqualTo [] || {(_cur param [2, -1]) isNotEqualTo _start}) exitWith {};   // cashed out / new round
                    AP_casinoCrash deleteAt _uid;
                    ["-CASINOCR-", _caller, format ["net $-%1 (crash, wagered $%2, returned $0, busted @%3x)", _bet, _bet, _bust]] call APS_fnc_logIt;
                    [["result", ["crash", ["bust", _bust, _bet, 0]]], "AP_fnc_casino", _caller, false] spawn AP_fnc_MP;};};
            case "cashout": {if (_run isEqualTo []) exitWith {};
                _run params ["_bet", "_bust", "_start"];
                private _m = (round ((2.718281828 ^ (_K * ((serverTime - _start) max 0))) * 100)) / 100;
                if (_m >= _bust) exitWith {};    // too late -- the bust timer resolves it
                AP_casinoCrash deleteAt _uid;   // cancels the pending bust timer
                private _ret = round (_bet * _m);
                private _net = _ret - _bet;
                ["-CASINOCR-", _caller, format ["net $%1 (crash, wagered $%2, returned $%3, cashed @%4x)", _net, _bet, _ret, _m]] call APS_fnc_logIt;
                [_ret] call _credit;
                ["crash", ["cashout", _m, _bet, _ret]] call _render;};
            case "quit": {if (_run isEqualTo []) exitWith {};
                AP_casinoCrash deleteAt _uid;   // abandon: bet already debited, no payout; the bust timer no-ops
            };};};

    case "hilo": {if (isNil "AP_casinoHiLo") then { AP_casinoHiLo = createHashMap; };
        private _rank = { params ["_c"]; _c mod 13 };   // 0..12 (2..A). Suits ignored for probability.
        private _run  = AP_casinoHiLo getOrDefault [_uid, []];
        // owner 2026-07-07: cash-out value. FIRST-round (no guess yet, mult 1.0) cash-outs are PENALISED to 50% --
        // otherwise you could deal, peek the card, guess only on a near-sure card and bail with a full refund on a
        // risky one = a risk-free +EV peek. After any correct guess mult>=1.05, so the penalty only bites pre-guess.
        private _cashOf = { params ["_m", "_b"]; if (_m <= 1.0) then { round (_b * 0.5) } else { round (_b * _m) } };

        switch (toLower _action) do {case "deal": {private _bet = [_data param [0, 0]] call _clampBet;
                if (_bet < 0) exitWith {};
                if (_run isNotEqualTo []) exitWith {};   // finish the run in progress first
                private _c = floor (random 52);
                private _startMult = 1.0;
                if (["hilo"] call _rigFirst) then { _startMult = 30; };   // owner first hi-lo = max 30x pot off the deal
                AP_casinoHiLo set [_uid, [_c, _startMult, _bet]];
                ["-CASINOBET-", _caller, format ["$%1 hilo", _bet]] call APS_fnc_logIt;
                ["hilo", ["play", _c, _startMult, _bet, ([_startMult, _bet] call _cashOf), -1, ""]] call _render;};

            case "guess": {if (_run isEqualTo []) exitWith {};
                _run params ["_cur", "_mult", "_bet"];
                private _dir = toLower (_data param [0, ""]);
                if !(_dir in ["hi", "lo"]) exitWith {};
                private _curR = [_cur] call _rank;
                // P(correct) by RANK over the remaining conceptual deck (fresh 52 each draw; suits ignored):
                //   higher = strictly greater rank; lower = strictly lower rank. Equal rank = tie = LOSE.
                private _higherCount = 12 - _curR;   // ranks strictly above (0..12 scale)
                private _lowerCount  = _curR;         // ranks strictly below
                private _pCorrect = (if (_dir isEqualTo "hi") then { _higherCount } else { _lowerCount }) / 13;
                private _next = floor (random 52);
                private _nextR = [_next] call _rank;
                private _correct = if (_dir isEqualTo "hi") then { _nextR > _curR } else { _nextR < _curR };

                if (!_correct || {_pCorrect <= 0}) then {
                    // wrong guess or a tie (or an impossible call, e.g. "higher" on an Ace) -> run over, no payout
                    private _lostBet = _bet;
                    ["-CASINOHL-", _caller, format ["net $-%1 (hilo, wagered $%2, returned $0, busted at mult %3)", _lostBet, _lostBet, _mult]] call APS_fnc_logIt;
                    AP_casinoHiLo deleteAt _uid;
                    ["hilo", ["bust", _next, _mult, _bet, 0, _cur, "lose"]] call _render;} else {
                    // step = fair(1/p) * 0.90 house factor, FLOORED at 1.05 so every correct guess ALWAYS grows the
                    // pot (>1). Without the floor a very-safe guess (p>0.90, e.g. "higher" on a 2) gave 0.90/0.92<1 --
                    // you'd win the round yet LOSE money on cash-out. Edge holds (floor 1.05 < fair 1/0.92 = 1.08).
                    private _step = (0.90 / _pCorrect) max 1.05;
                    // owner 2026-07-08: CAP the accumulated multiplier at 30x. Uncapped, a chained lucky streak minted
                    // tens of millions in one run (the only game without a payout ceiling); 30x = max $15M on the $500k
                    // max bet, matching the slots single-spin cap. Once at 30x, further correct guesses stop growing it.
                    _mult = (_mult * _step) min 30;
                    AP_casinoHiLo set [_uid, [_next, _mult, _bet]];
                    private _pot = [_mult, _bet] call _cashOf;
                    ["hilo", ["play", _next, _mult, _bet, _pot, _cur, "win"]] call _render;};};

            case "cashout": {if (_run isEqualTo []) exitWith {};
                _run params ["_cur", "_mult", "_bet"];
                private _ret = [_mult, _bet] call _cashOf;   // pre-guess cash-out (mult 1.0) -> 50% penalty; else bet*mult
                private _net = _ret - _bet;
                ["-CASINOHL-", _caller, format ["net $%1 (hilo, wagered $%2, returned $%3, cashed out at mult %4)", _net, _bet, _ret, _mult]] call APS_fnc_logIt;
                AP_casinoHiLo deleteAt _uid;
                [_ret] call _credit;
                ["hilo", ["cashout", _cur, _mult, _bet, _ret, -1, "cashout"]] call _render;};

            case "quit": {if (_run isNotEqualTo []) then {_run params ["_cur", "_mult", "_bet"];
                    ["-CASINOHL-", _caller, format ["net $-%1 (hilo, abandoned in-progress run at mult %2)", _bet, _mult]] call APS_fnc_logIt;
                    AP_casinoHiLo deleteAt _uid;};};

            default {};};};

    default { diag_log format ["[LooneyBin][casino] unhandled game: %1", _game]; };};
