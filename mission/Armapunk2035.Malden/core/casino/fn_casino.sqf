/*
    fn_casino.sqf  (AP_fnc_casino)  -- LooneyBin Casino: game-select LANDING + the five simple games'
    CLIENT controller (Coin Flip / Wheel / Slots / Roulette / Hi-Lo) + the server's "result" render
    callback. Blackjack keeps its own AP_fnc_blackJack. Engine: server APS_fnc_casinoSRV.

    SECURITY (identical to blackjack): the client NEVER decides a win or credits a payout. It only
      (a) debits the bet from BANK locally via AP_fnc_uC before a play/deal,
      (b) sends the player's INTENT to APS_fnc_casinoSRV (server owner 2),
      (c) RENDERS the _payload the server returns.
    All payouts arrive server-gated via AP_fnc_casinoReceive.

    Dispatch: _this = ["<mode>", <args>]
      ["landing", []]                 open the game-select screen
      ["open", [_game]]               open a game dialog (coinflip/wheel/hilo) + show its betting screen
      ["bet",  [_amt]]                set the shared bet + refresh the current game's betting screen
      ["play", [_game, _sub]]         a game action (flip / spin / deal / hi / lo / cashout)
      ["result", [_game, _payload]]   (server-sent) draw the outcome
      ["back", []]                    return to the landing
      ["exit", []]                    close the casino

    Dialogs: casino_landing.hpp (930300), casino_coinflip.hpp (930310), casino_wheel.hpp (930320),
    casino_hilo.hpp (930350). Shared IDC scheme per dialog (separate displays -> numbers may repeat):
      1010 BANK  1011 BET  1012 result-banner  1006 bet-selected
      1200..1204 chips ($10k/50k/100k/250k/500k)   1210 primary action   1230 play-again   1240 back
      coinflip: 1220 HEADS  1221 TAILS  1250 coin-face
      wheel:    1250 result-multiplier
      hilo:     1250 card  1220 HIGHER  1221 LOWER  1231 CASHOUT  1252 multiplier/pot  1253 last-card
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
disableSerialization;
params [["_mode", "landing", [""]], ["_args", [], [[]]]];

// owner 2026-08-12: the HTML casino. Hooked HERE because every entry point and
// every server result already funnels through this one function -- the landing,
// each table, and the "result" render the engines push back. AP_webCasino
// flips the whole thing back to the native dialogs.
// owner 2026-08-20: these guards were INSIDE `if (webCasino) then { ... }`, so their exitWith left
// the BLOCK, not the function -- execution fell through and createDialog "AP_casino_landing" ran
// anyway. That is the native menu the owner saw flash before the page appeared (and a "result"
// was mirrored to the page AND rendered natively). Same scope trap as the hold'em cooldown gate:
// exitWith exits the innermost code block that owns it. Function scope now.
private _webCasino = missionNamespace getVariable ["AP_webCasino", true];
// _args carries the table on "open" ("landing" sends none), so the NPC and the
// native landing buttons both land on the right page rather than the floor.
if (_webCasino && {_mode in ["landing", "open"]}) exitWith { [_args param [0, ""]] spawn AP_fnc_casinoOpen; };
// A result arriving while the web casino is up is mirrored to the page and
// the native render is skipped; with it closed, nothing changes.
if (_webCasino && {_mode isEqualTo "result"} && {(allDisplays findIf { (ctrlIDD _x) in [930400,930410,930411,930412,930413,930414,930415] }) > -1}) exitWith {
    // The native "status" render below is skipped here, but casPlay charges a paid spin
    // against these two, so the web wheel's status has to land in them too.
    if ((_args param [0, ""]) isEqualTo "wheel" && {((_args param [1, []]) param [0, ""]) isEqualTo "status"}) then {
        (_args select 1) params ["", ["_free", false, [false]], ["_cost", 50000, [0]]];
        AP_wheelFree = _free;
        AP_wheelCost = (_cost max 0) min 500000;
    };
    // this table's answer is in: casPlay may take its next stake
    if (((uiNamespace getVariable ["AP_casPend", ["", 0]]) select 0) isEqualTo (_args param [0, ""])) then { uiNamespace setVariable ["AP_casPend", ["", 0]] };
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then {
        [_c, "casResult", createHashMapFromArray [
            ["game",    _args param [0, ""]],
            ["payload", _args param [1, []]]
        ]] call webui_fnc_push;
    };
};

if (isNil "AP_casBet")  then { AP_casBet = 10000 };
if (isNil "AP_cfPick")  then { AP_cfPick = 0 };        // coinflip pick: 0 heads, 1 tails
if (isNil "AP_casGame") then { AP_casGame = "" };
if (isNil "AP_wheelFree") then { AP_wheelFree = false };   // wheel: is the free daily spin available (set from server status)
if (isNil "AP_rlBet") then { AP_rlBet = ["", -1] };        // roulette: current selection [type, value]
if (isNil "AP_wheelCost") then { AP_wheelCost = 50000 };   // wheel: server-authoritative spin cost, synced from the "status" render (no client-side literal that can drift from the server _COST)

private _chips = [10000, 50000, 100000, 250000, 500000];

// ── shared helpers ─────────────────────────────────────────────────────────────────────────────
private _fnNum  = { params ["_n"]; [_n] call AP_fnc_numberText };
private _fnClamp = { AP_casBet = (AP_casBet max 10000) min 500000; AP_casBet };
private _fnGate = {
    if ((AP_is_arrested isEqualType []) && {(AP_is_arrested param [0, 0]) > 0}) exitWith { "You can't gamble from a cell." };
    if (player getVariable ["AP_restrained", false]) exitWith { "Your hands are restrained." };
    if (!alive player || {AP_isDowned} || {AP_knockout}) exitWith { "You're in no state to gamble." };
    if (AP_inCombat) exitWith { "You can't gamble while in combat." };
    if !(AP_effSide in [civilian, west, independent]) exitWith { "You can't play at the casino right now." };""};
private _iddOf = { params ["_g"]; switch (_g) do { case "coinflip": {930310}; case "wheel": {930320}; case "slots": {930330}; case "roulette": {930340}; case "hilo": {930350}; case "crash": {930360}; default {-1} } };
private _curDisp = { findDisplay ([AP_casGame] call _iddOf) };
private _cardName = { params ["_c"]; (["C","D","H","S"] select (floor (_c / 13))) + (["2","3","4","5","6","7","8","9","10","J","Q","K","A"] select (_c mod 13)) };

// debit a bet from BANK (returns true on success); keeps the AC cash cache in sync (uC does not)
private _fnDebit = {params ["_bet"];
    if !(["atm", "take", _bet] call AP_fnc_uC) exitWith { ["Not enough bank funds for that bet.", "basic"] spawn AP_fnc_handleMessage; false };
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;
    true};

// paint the shared BANK/BET readouts + bet-selected chip label on a display
private _fnReadouts = {params ["_disp"];
    (_disp displayCtrl 1010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call _fnNum];
    (_disp displayCtrl 1011) ctrlSetStructuredText parseText format ["<t size='1.0' align='right'>BET  $%1</t>", [AP_casBet] call _fnNum];
    private _bs = _disp displayCtrl 1006;
    if (!isNull _bs) then { _bs ctrlSetStructuredText parseText format ["<t size='1.15' align='center'>Bet:  $%1</t>", [AP_casBet] call _fnNum]; };
};

// highlight the selected chip (gold) on a display
private _fnChipHi = {params ["_disp"];
    { (_disp displayCtrl (1200 + _forEachIndex)) ctrlSetBackgroundColor (if (_x isEqualTo AP_casBet) then { [0.72, 0.55, 0.15, 1] } else { [0.15, 0.22, 0.35, 1] }); } forEach _chips;
};

// wire the chips + BACK once on a freshly-created game dialog (SHARED across games)
private _fnWireShared = {params ["_disp", "_game"]; {private _amt = _x;
        (_disp displayCtrl (1200 + _forEachIndex)) ctrlAddEventHandler ["ButtonClick", compile format ["AP_casBet = %1; ['bet', [%1]] call AP_fnc_casino", _amt]];
    } forEach _chips;
    (_disp displayCtrl 1240) ctrlAddEventHandler ["ButtonClick", { ['back', []] call AP_fnc_casino }];};

switch (toLower _mode) do {

    // ── LANDING: game-select ─────────────────────────────────────────────────────────────────────
    case "landing": {private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };
        AP_casGame = "";
        if (isNull (findDisplay 930300)) then {
            createDialog "AP_casino_landing";   // synchronous; no waitUntil (unscheduled -> could busy-loop on a failed create)
        };
        private _disp = findDisplay 930300;
        if (isNull _disp) exitWith {};
        (_disp displayCtrl 930301) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; ["open", []] call AP_fnc_blackJack }];
        (_disp displayCtrl 930302) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; ["open", ["coinflip"]] call AP_fnc_casino }];
        (_disp displayCtrl 930303) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; ["open", ["wheel"]]    call AP_fnc_casino }];
        (_disp displayCtrl 930304) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; ["open", ["slots"]] call AP_fnc_casino }];
        (_disp displayCtrl 930305) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; ["open", ["roulette"]] call AP_fnc_casino }];
        (_disp displayCtrl 930306) ctrlAddEventHandler ["ButtonClick", { ["open", ["hilo"]]     call AP_fnc_casino }];
        (_disp displayCtrl 930308) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; ["open", ["crash"]] call AP_fnc_casino }];
        (_disp displayCtrl 930307) ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];   // owner 2026-07-20: app Close returns to phone HOME (ESC still fully exits)
        (_disp displayCtrl 930310) ctrlSetStructuredText parseText format ["<t size='1.0' align='center'>BANK  $%1</t>", [AP_atmcash] call _fnNum];
    };

    // ── OPEN a game: create its dialog, wire buttons, show the betting screen ──────────────────────
    case "open": {private _game = _args param [0, ""];
        private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };
        private _idd = [_game] call _iddOf;
        if (_idd < 0) exitWith {};
        AP_casGame = _game;
        private _class = switch (_game) do { case "coinflip": {"AP_casino_coinflip"}; case "wheel": {"AP_casino_wheel"}; case "slots": {"AP_casino_slots"}; case "roulette": {"AP_casino_roulette"}; case "hilo": {"AP_casino_hilo"}; case "crash": {"AP_casino_crash"}; default {""} };
        if (_class isEqualTo "") exitWith {};
        createDialog _class;
        // createDialog is synchronous -- the display exists immediately. NO waitUntil: this fn runs UNSCHEDULED
        // (button-EH context), so a waitUntil that never satisfies (createDialog fails mid-transition when you
        // rapid-switch games) busy-loops FOREVER = frozen input until you Escape. Just grab it + null-guard.
        private _disp = findDisplay _idd;
        if (isNull _disp) exitWith {};

        [_disp, _game] call _fnWireShared;
        switch (_game) do {case "coinflip": {
                (_disp displayCtrl 1220) ctrlAddEventHandler ["ButtonClick", { AP_cfPick = 0; ['bet', [AP_casBet]] call AP_fnc_casino }];
                (_disp displayCtrl 1221) ctrlAddEventHandler ["ButtonClick", { AP_cfPick = 1; ['bet', [AP_casBet]] call AP_fnc_casino }];
                (_disp displayCtrl 1210) ctrlAddEventHandler ["ButtonClick", { ['play', ['coinflip', 'flip']] call AP_fnc_casino }];
                (_disp displayCtrl 1230) ctrlAddEventHandler ["ButtonClick", { ['bet', [AP_casBet]] call AP_fnc_casino }];   // FLIP AGAIN: repaint the betting screen (never recreate the dialog)
                // capture the coin's un-squashed box once (the flip animation restores to this)
                uiNamespace setVariable ["AP_cfCoinPos", ctrlPosition (_disp displayCtrl 1250)];};
            case "wheel": {
                (_disp displayCtrl 1210) ctrlAddEventHandler ["ButtonClick", { ['play', ['wheel', 'spin']] call AP_fnc_casino }];
                (_disp displayCtrl 1230) ctrlAddEventHandler ["ButtonClick", { ['wheelui', []] call AP_fnc_casino }];   // SPIN AGAIN: reset + re-check free status (never recreate the dialog)
            };
            case "slots": {
                (_disp displayCtrl 1210) ctrlAddEventHandler ["ButtonClick", { ['play', ['slots', 'spin']] call AP_fnc_casino }];
                (_disp displayCtrl 1230) ctrlAddEventHandler ["ButtonClick", { ['bet', [AP_casBet]] call AP_fnc_casino }];   // SPIN AGAIN: repaint the betting screen
            };
            case "roulette": {
                // bet buttons: each sets AP_rlBet=[type,val], clears the straight-# field, repaints. type/val are constants.
                {_x params ["_bidc", "_type", "_bval"];
                    (_disp displayCtrl _bidc) ctrlAddEventHandler ["ButtonClick", compile format ["AP_rlBet = ['%1', %2]; ((findDisplay 930340) displayCtrl 1270) ctrlSetText ''; ['bet', [AP_casBet]] call AP_fnc_casino", _type, _bval]];
                } forEach [[1260,"red",-1],[1261,"black",-1],[1262,"odd",-1],[1263,"even",-1],[1264,"low",-1],[1265,"high",-1],[1266,"dozen1",-1],[1267,"dozen2",-1],[1268,"dozen3",-1],[1269,"straight",0],[1271,"straight",37]];
                // owner 2026-07-08: typing a valid number IS the bet -> deselect any outside bet + repaint, so the single
                // visible selection always equals what SPIN will wager (before, a typed # silently overrode a highlighted
                // outside bet while the UI still showed the outside bet). Mirrors the outside buttons clearing the field.
                (_disp displayCtrl 1270) ctrlAddEventHandler ["KeyUp", {params ["_ctrl"];
                    private _t = ctrlText _ctrl;
                    private _n = parseNumber _t;
                    if (_t isNotEqualTo "" && {_n >= 0 && {_n <= 36} && {_n isEqualTo floor _n}}) then {AP_rlBet = ["straight", floor _n];
                    } else {if (_t isEqualTo "") then { AP_rlBet = ["", -1]; };};
                    ['bet', [AP_casBet]] call AP_fnc_casino;}];
                (_disp displayCtrl 1210) ctrlAddEventHandler ["ButtonClick", { ['play', ['roulette', 'spin']] call AP_fnc_casino }];
                (_disp displayCtrl 1230) ctrlAddEventHandler ["ButtonClick", { ['bet', [AP_casBet]] call AP_fnc_casino }];   // SPIN AGAIN: repaint
                AP_rlBet = ["", -1];
                // capture the 9 strip cells' base X (relative to the clip group 1259) once
                private _grp = _disp displayCtrl 1259;
                private _bx = []; { _bx pushBack ((ctrlPosition (_grp controlsGroupCtrl _x)) select 0); } forEach [1250,1251,1252,1253,1254,1255,1256,1257,1258];
                uiNamespace setVariable ["AP_rlCellX", _bx];};
            case "hilo": {
                (_disp displayCtrl 1210) ctrlAddEventHandler ["ButtonClick", { ['play', ['hilo', 'deal']] call AP_fnc_casino }];
                (_disp displayCtrl 1220) ctrlAddEventHandler ["ButtonClick", { ['play', ['hilo', 'hi']] call AP_fnc_casino }];
                (_disp displayCtrl 1221) ctrlAddEventHandler ["ButtonClick", { ['play', ['hilo', 'lo']] call AP_fnc_casino }];
                (_disp displayCtrl 1231) ctrlAddEventHandler ["ButtonClick", { ['play', ['hilo', 'cashout']] call AP_fnc_casino }];
                (_disp displayCtrl 1230) ctrlAddEventHandler ["ButtonClick", { ['bet', [AP_casBet]] call AP_fnc_casino }];   // PLAY AGAIN: repaint (never recreate the dialog)
                AP_casHiloInGame = false;};
            case "crash": {
                (_disp displayCtrl 1210) ctrlAddEventHandler ["ButtonClick", { ['play', ['crash', 'deal']]    call AP_fnc_casino }];
                (_disp displayCtrl 1231) ctrlAddEventHandler ["ButtonClick", { ['play', ['crash', 'cashout']] call AP_fnc_casino }];
                (_disp displayCtrl 1230) ctrlAddEventHandler ["ButtonClick", { ['bet', [AP_casBet]] call AP_fnc_casino }];};};
        // wheel is a fixed-cost daily prize wheel (not a bet game) -> its own init/status path
        if (_game isEqualTo "wheel") then { ['wheelui', []] call AP_fnc_casino } else { ['bet', [AP_casBet]] call AP_fnc_casino };};

    // ── BET: set the shared bet + repaint the current game's betting screen ────────────────────────
    case "bet": {[] call _fnClamp;
        private _game = AP_casGame;
        private _disp = call _curDisp;
        if (isNull _disp) exitWith {};

        // shared: chips + action visible, banner/again hidden; readouts + chip highlight
        { (_disp displayCtrl _x) ctrlShow true;  } forEach [1200,1201,1202,1203,1204,1006,1010,1011];
        { (_disp displayCtrl _x) ctrlEnable true; } forEach [1200,1201,1202,1203,1204,1210];
        (_disp displayCtrl 1210) ctrlShow true;
        (_disp displayCtrl 1012) ctrlShow false;
        (_disp displayCtrl 1230) ctrlShow false;
        [_disp] call _fnChipHi;
        [_disp] call _fnReadouts;

        switch (_game) do {case "coinflip": {{ (_disp displayCtrl _x) ctrlShow true; } forEach [1220, 1221, 1250];
                { (_disp displayCtrl _x) ctrlEnable true; } forEach [1220, 1221];   // re-enable picks (a flip disabled them)
                // coin previews the currently-picked face; restore full (un-squashed) geometry
                private _coin = _disp displayCtrl 1250;
                _coin ctrlSetText format ["images\casino\coin_%1.paa", (if (AP_cfPick isEqualTo 0) then {"heads"} else {"tails"})];
                _coin ctrlSetPosition (uiNamespace getVariable ["AP_cfCoinPos", ctrlPosition _coin]);
                _coin ctrlCommit 0;
                (_disp displayCtrl 1012) ctrlShow false;
                // pick highlight (gold = selected)
                (_disp displayCtrl 1220) ctrlSetBackgroundColor (if (AP_cfPick isEqualTo 0) then { [0.72,0.55,0.15,1] } else { [0.15,0.22,0.35,1] });
                (_disp displayCtrl 1221) ctrlSetBackgroundColor (if (AP_cfPick isEqualTo 1) then { [0.72,0.55,0.15,1] } else { [0.15,0.22,0.35,1] });
                (_disp displayCtrl 1210) ctrlSetText "FLIP";};
            case "slots": {{ (_disp displayCtrl _x) ctrlShow true; } forEach [1250, 1251, 1252];
                (_disp displayCtrl 1250) ctrlSetText "images\casino\slot_0.paa";
                (_disp displayCtrl 1251) ctrlSetText "images\casino\slot_1.paa";
                (_disp displayCtrl 1252) ctrlSetText "images\casino\slot_2.paa";
                (_disp displayCtrl 1210) ctrlSetText "SPIN";
                // owner 2026-07-08: $250k/$500k chips RESTORED on slots (the shared bet block already shows 1200-1204).
            };
            case "roulette": {
                { (_disp displayCtrl _x) ctrlShow true; } forEach [1260,1261,1262,1263,1264,1265,1266,1267,1268,1269,1271,1270];
                { (_disp displayCtrl _x) ctrlEnable true; } forEach [1260,1261,1262,1263,1264,1265,1266,1267,1268,1269,1271];
                (_disp displayCtrl 1210) ctrlSetText "SPIN";
                private _order = [0,28,9,26,30,11,7,20,32,17,5,22,34,15,3,24,36,13,1,37,27,10,25,29,12,8,19,31,18,6,21,33,16,4,23,35,14,2];   // American double-zero wheel order (38 pockets; 37 = "00")
                private _redNums = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
                private _bx = uiNamespace getVariable ["AP_rlCellX", []];
                private _grp = _disp displayCtrl 1259;
                // static strip preview: center cell (index 4) shows 0, neighbours = wheel order
                {private _i = _forEachIndex;
                    private _num = _order select (((_i - 4) mod (count _order) + (count _order)) mod (count _order));
                    private _cc = _grp controlsGroupCtrl _x;
                    _cc ctrlSetStructuredText parseText format ["<t size='2.0' align='center' color='#ffffff'>%1</t>", (if (_num isEqualTo 37) then {"00"} else {str _num})];
                    _cc ctrlSetBackgroundColor (if (_num isEqualTo 0 || {_num isEqualTo 37}) then {[0.15,0.5,0.2,1]} else { if (_num in _redNums) then {[0.7,0.13,0.13,1]} else {[0.12,0.12,0.14,1]} });
                    if (count _bx > _i) then { private _cp = ctrlPosition _cc; _cc ctrlSetPosition [_bx select _i, _cp select 1, _cp select 2, _cp select 3]; _cc ctrlCommit 0; };
                } forEach [1250,1251,1252,1253,1254,1255,1256,1257,1258];
                // highlight the selected bet (gold text); label the selection
                AP_rlBet params ["_bt", "_bv"];
                { (_disp displayCtrl _x) ctrlSetTextColor [1,1,1,1]; } forEach [1260,1261,1262,1263,1264,1265,1266,1267,1268,1269,1271];
                private _selIdc = switch (_bt) do { case "red":{1260}; case "black":{1261}; case "odd":{1262}; case "even":{1263}; case "low":{1264}; case "high":{1265}; case "dozen1":{1266}; case "dozen2":{1267}; case "dozen3":{1268}; case "straight": { switch (_bv) do { case 0: {1269}; case 37: {1271}; default {-1} } }; default {-1} };
                if (_selIdc > 0) then { (_disp displayCtrl _selIdc) ctrlSetTextColor [1,0.85,0.2,1]; };
                private _lbl = switch (true) do { case (_bt isEqualTo ""): {"Pick a bet, or type a number 0-36"}; case (_bt isEqualTo "straight"): {format ["Bet: STRAIGHT #%1", (if (_bv isEqualTo 37) then {"00"} else {str _bv})]}; default {format ["Bet: %1", toUpper _bt]} };
                (_disp displayCtrl 1006) ctrlSetStructuredText parseText format ["<t size='1.0' align='center' color='#cfe6d6'>%1</t>", _lbl];
            };
            case "hilo": {{ (_disp displayCtrl _x) ctrlShow false; } forEach [1220, 1221, 1231, 1250, 1252, 1253];
                (_disp displayCtrl 1210) ctrlSetText "DEAL";
                AP_casHiloInGame = false;};
            case "crash": {{ (_disp displayCtrl _x) ctrlShow false; } forEach [1231, 1252, 1012];
                { (_disp displayCtrl _x) ctrlShow true;  } forEach [1200,1201,1202,1203,1204,1210,1006];
                (_disp displayCtrl 1230) ctrlShow false;
                (_disp displayCtrl 1210) ctrlEnable true; (_disp displayCtrl 1210) ctrlSetText "DEAL";
                (_disp displayCtrl 1006) ctrlSetStructuredText parseText "<t size='1.4' align='center' color='#9fb3c8'>place a bet, then DEAL</t>";
                AP_crashRound = [false, 0, 0];};};};

    // ── WHEELUI: the daily prize wheel's betting-equivalent screen (fixed cost, no chips). Queries free status. ──
    case "wheelui": {private _disp = findDisplay 930320;
        if (isNull _disp) exitWith {};
        private _wheel = _disp displayCtrl 1250;
        _wheel ctrlShow true;
        _wheel ctrlSetText "images\casino\wheel_00.paa";
        (_disp displayCtrl 1012) ctrlShow false;       // banner
        (_disp displayCtrl 1230) ctrlShow false;       // SPIN AGAIN
        (_disp displayCtrl 1210) ctrlShow true;        // SPIN
        (_disp displayCtrl 1210) ctrlEnable false;     // disabled until the server returns free/paid status
        (_disp displayCtrl 1210) ctrlSetText "checking...";
        (_disp displayCtrl 1010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call _fnNum];
        [["wheel", "checkfree", []], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};

    // ── PLAY: a game action. Debit locally where a NEW bet is placed, then send intent. ────────────
    case "play": {private _game = _args param [0, ""];
        private _sub  = _args param [1, ""];
        private _disp = call _curDisp;
        if (isNull _disp) exitWith {};
        private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };

        switch (_game) do {case "coinflip": {private _bet = [] call _fnClamp;
                if !([_bet] call _fnDebit) exitWith {};
                { (_disp displayCtrl _x) ctrlEnable false; } forEach [1200,1201,1202,1203,1204,1210,1220,1221];
                [["coinflip", "play", [_bet, AP_cfPick]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};
            case "wheel": {
                // paid spin ($50k) unless the free daily is available. FLAT exitWith (a nested exitWith in then{} only leaves the block).
                if (!(missionNamespace getVariable ["AP_wheelFree", false]) && {!([missionNamespace getVariable ["AP_wheelCost", 50000]] call _fnDebit)}) exitWith {};
                (_disp displayCtrl 1210) ctrlEnable false;
                (_disp displayCtrl 1210) ctrlSetText "spinning...";
                [["wheel", "spin", [missionNamespace getVariable ["AP_wheelFree", false]]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};
            case "slots": {private _bet = [] call _fnClamp;
                if !([_bet] call _fnDebit) exitWith {};
                { (_disp displayCtrl _x) ctrlEnable false; } forEach [1200,1201,1202,1203,1204,1210];
                [["slots", "play", [_bet]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};
            case "roulette": {
                // a valid straight-# entry (native parseNumber -- RCE-safe) overrides the selected outside bet
                private _txt = ctrlText (_disp displayCtrl 1270);
                private _num = -1;
                if (_txt isNotEqualTo "") then {private _n = parseNumber _txt;
                    if (_n >= 0 && {_n <= 36} && {_n isEqualTo (floor _n)}) then { _num = floor _n; };};
                private _type = ""; private _val = -1;
                // owner 2026-07-08: carry AP_rlBet's VALUE in the else branch too. Without it the GREEN 0 / GREEN 00
                // buttons (which set AP_rlBet = ["straight", 0/37]) sent val -1 -> could NEVER match a spin = a silent
                // guaranteed loss on an otherwise valid-looking bet.
                if (_num >= 0) then { _type = "straight"; _val = _num; } else { _type = AP_rlBet select 0; _val = AP_rlBet select 1; };
                if (_type isEqualTo "") exitWith { ["Pick a bet, or type a number 0-36 first.", "basic"] spawn AP_fnc_handleMessage };
                private _bet = [] call _fnClamp;
                if !([_bet] call _fnDebit) exitWith {};
                { (_disp displayCtrl _x) ctrlEnable false; } forEach [1200,1201,1202,1203,1204,1210,1260,1261,1262,1263,1264,1265,1266,1267,1268,1269,1271];
                (_disp displayCtrl 1210) ctrlSetText "spinning...";
                [["roulette", "play", [_bet, _type, _val]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};
            case "hilo": {switch (_sub) do {case "deal": {private _bet = [] call _fnClamp;
                        if !([_bet] call _fnDebit) exitWith {};
                        { (_disp displayCtrl _x) ctrlEnable false; } forEach [1200,1201,1202,1203,1204,1210];
                        AP_casHiloInGame = true;
                        [["hilo", "deal", [_bet]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};
                    case "hi": { { (_disp displayCtrl _x) ctrlEnable false; } forEach [1220,1221,1231]; [["hilo", "guess", ["hi"]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP; };
                    case "lo": { { (_disp displayCtrl _x) ctrlEnable false; } forEach [1220,1221,1231]; [["hilo", "guess", ["lo"]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP; };
                    case "cashout": { { (_disp displayCtrl _x) ctrlEnable false; } forEach [1220,1221,1231]; [["hilo", "cashout", []], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP; };
                };};
            case "crash": {switch (_sub) do {case "deal": {private _bet = [] call _fnClamp;
                        if !([_bet] call _fnDebit) exitWith {};
                        { (_disp displayCtrl _x) ctrlEnable false; } forEach [1200,1201,1202,1203,1204,1210];
                        [["crash", "deal", [_bet]], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;};
                    case "cashout": { (_disp displayCtrl 1231) ctrlEnable false; [["crash", "cashout", []], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP; };
                };};};};

    // ── RESULT (server-sent): draw the outcome. NEVER credits money -- just draws _payload. ────────
    case "result": {private _game    = _args param [0, ""];
        private _payload = _args param [1, []];
        private _disp = [_game] call _iddOf;
        _disp = findDisplay _disp;
        if (isNull _disp) exitWith {};

        switch (_game) do {

            case "coinflip": {_payload params [["_win",false],["_pick",0],["_face",0],["_bet",0],["_ret",0],["_net",0]];
                // hide every control except the coin; a 3s spin animation then reveals the server's result
                { (_disp displayCtrl _x) ctrlShow false; } forEach [1200,1201,1202,1203,1204,1006,1012,1210,1220,1221,1230];
                (_disp displayCtrl 1250) ctrlShow true;
                private _basePos = uiNamespace getVariable ["AP_cfCoinPos", ctrlPosition (_disp displayCtrl 1250)];
                [_disp, _face, _win, _net, _basePos] spawn {params ["_disp","_face","_win","_net","_basePos"];
                    disableSerialization;
                    _basePos params ["_bx","_by","_bw","_bh"];
                    private _cx = _bx + _bw/2;
                    private _coin = _disp displayCtrl 1250;
                    private _fnFaceImg = { format ["images\casino\coin_%1.paa", (if (_this isEqualTo 0) then {"heads"} else {"tails"})] };
                    private _t0 = time; private _dur = 3;
                    while { (time - _t0) < _dur } do {if (isNull _disp || {isNull _coin}) exitWith {};
                        private _p    = (time - _t0) / _dur;
                        private _ease = 1 - ((1 - _p) ^ 2);          // ease-out: fast -> slow
                        private _theta = 8 * 360 * _ease;            // 8 rotations (DEGREES -- Arma cos/sin are degrees)
                        private _wf   = abs (cos _theta);            // width factor 0..1 (edge-on at 0)
                        // shown face flips each half-rotation; parity is EVEN at the end -> lands on the true _face
                        private _shown = if (((floor (_theta / 180)) % 2) isEqualTo 0) then { _face } else { 1 - _face };
                        _coin ctrlSetText (_shown call _fnFaceImg);
                        private _w = _bw * (0.06 max _wf);
                        _coin ctrlSetPosition [_cx - _w/2, _by, _w, _bh];
                        _coin ctrlCommit 0;
                        uiSleep 0.03;};
                    if (isNull _disp || {isNull _coin}) exitWith {};
                    // settle on the true face at full size
                    _coin ctrlSetText (_face call _fnFaceImg);
                    _coin ctrlSetPosition _basePos; _coin ctrlCommit 0;
                    // reveal the result banner + FLIP AGAIN (the bank credit has landed during the 3s spin)
                    private _bText = if (_win) then { format ["<t size='1.6' color='#4fcf6a' align='center'>YOU WIN  +$%1</t>", [_net] call AP_fnc_numberText] }
                                     else { format ["<t size='1.6' color='#e05555' align='center'>YOU LOSE  -$%1</t>", [abs _net] call AP_fnc_numberText] };
                    (_disp displayCtrl 1012) ctrlShow true;
                    (_disp displayCtrl 1012) ctrlSetStructuredText parseText _bText;
                    (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;
                    (_disp displayCtrl 1010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call AP_fnc_numberText];
                    (_disp displayCtrl 1011) ctrlSetStructuredText parseText format ["<t size='1.0' align='right'>BET  $%1</t>", [AP_casBet] call AP_fnc_numberText];
                };};

            case "wheel": {private _kind = _payload param [0, ""];
                switch (_kind) do {
                    // free/paid status from the server -> label the SPIN button
                    case "status": {_payload params ["", ["_free", false], ["_cost", 50000]];
                        AP_wheelFree = _free;
                        AP_wheelCost = _cost;   // sync the authoritative cost so the local debit can never drift from the server

                        (_disp displayCtrl 1210) ctrlEnable true;
                        (_disp displayCtrl 1210) ctrlSetText (if (_free) then { "SPIN  -  FREE DAILY" } else { format ["SPIN  -  $%1", [_cost] call _fnNum] });
                        (_disp displayCtrl 1011) ctrlSetStructuredText parseText (if (_free) then { "<t size='1.0' align='right' color='#4fcf6a'>FREE SPIN</t>" } else { format ["<t size='1.0' align='right'>COST  $%1</t>", [_cost] call _fnNum] });
                    };
                    // the spin result -> flipbook-animate the wheel landing on _seg, then reveal the prize
                    case "spin": {
                        _payload params ["", ["_seg",0], ["_prize",""], ["_cash",0], ["_xp",0], ["_label",""], ["_wasFree",false]];
                        if (_xp > 0) then { AP_side_exp = AP_side_exp + _xp; };   // civ XP is a client var (persists on normal save)
                        [_disp, _seg, _prize, _cash, _xp, _label] spawn {params ["_disp","_seg","_prize","_cash","_xp","_label"];
                            disableSerialization;
                            private _wheel = _disp displayCtrl 1250;
                            private _fnPad = { if (_this < 10) then { "0" + str _this } else { str _this } };
                            private _land  = (2 * _seg) mod 24;                 // frame that puts segment _seg under the top pointer
                            private _total = 7 * 360 + (_land * 15);            // 7 full spins + the landing angle
                            private _t0 = time; private _dur = 5.5;
                            while { (time - _t0) < _dur } do {if (isNull _disp || {isNull _wheel}) exitWith {};
                                private _p    = (time - _t0) / _dur;
                                private _ease = 1 - ((1 - _p) ^ 3.5);          // ease-out: fast start -> long smooth slow-down
                                private _frame = (floor ((_total * _ease) / 15)) mod 24;
                                _wheel ctrlSetText format ["images\casino\wheel_%1.paa", _frame call _fnPad];
                                uiSleep 0.02;};
                            if (isNull _disp || {isNull _wheel}) exitWith {};
                            _wheel ctrlSetText format ["images\casino\wheel_%1.paa", _land call _fnPad];   // exact landing
                            // decide the banner by what was ACTUALLY won (robust vs the prize string)
                            private _col = switch (true) do {case (_prize isEqualTo "bust"): { "#e0b000" };   // drug bust = amber
                                case (_cash > 0): { "#4fcf6a" };   // cash = green
                                case (_xp > 0):   { "#6db3ff" };   // xp = blue (legacy; wheel no longer awards xp)
                                default { "#e7c757" };             // vehicle jackpot = gold
                            };
                            private _msg = switch (true) do {
                                case (_prize isEqualTo "bust"): { if (_label isEqualTo "DRUG BUST ACTIVE") then { "DRUG BUST already running!" } else { "DRUG BUST!  DRUG PRICES +12% (5 MIN)" } };
                                case (_cash > 0): { format ["YOU WON  $%1", [_cash] call AP_fnc_numberText] };
                                case (_xp > 0):   { format ["YOU WON  %1 CIV XP", [_xp] call AP_fnc_numberText] };
                                default { format ["JACKPOT!  %1  ->  GARAGE", _label] };};
                            (_disp displayCtrl 1012) ctrlShow true;
                            (_disp displayCtrl 1012) ctrlSetStructuredText parseText format ["<t size='1.45' align='center' shadow='1' color='%1'>%2</t>", _col, _msg];
                            (_disp displayCtrl 1210) ctrlShow false;
                            (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;
                            (_disp displayCtrl 1010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call AP_fnc_numberText];
                            AP_wheelFree = false;   // owner 2026-07-08: post-spin the daily free is always consumed -- drop the redundant checkfree DB round-trip (SPIN AGAIN -> wheelui re-queries authoritatively before the next spin)
                        };};};};

            case "slots": {_payload params [["_reels",[0,0,0]],["_mult",0],["_bet",0],["_ret",0],["_net",0]];
                { (_disp displayCtrl _x) ctrlShow false; } forEach [1200,1201,1202,1203,1204,1006,1012,1210];
                [_disp, _reels, _net] spawn {params ["_disp","_reels","_net"];
                    disableSerialization;
                    private _r = [_disp displayCtrl 1250, _disp displayCtrl 1251, _disp displayCtrl 1252];
                    private _stops = [1.4, 2.1, 2.9];             // staggered per-reel stop time
                    private _t0 = time; private _dur = 2.9;
                    while { (time - _t0) < _dur } do {if (isNull _disp) exitWith {};
                        private _el   = time - _t0;
                        private _tick = floor (_el / 0.06); {
                            private _sym = if (_el < (_stops select _forEachIndex)) then { (_tick + _forEachIndex * 2) mod 5 } else { _reels select _forEachIndex };
                            _x ctrlSetText format ["images\casino\slot_%1.paa", _sym];} forEach _r;
                        uiSleep 0.06;};
                    if (isNull _disp) exitWith {};
                    { _x ctrlSetText format ["images\casino\slot_%1.paa", _reels select _forEachIndex]; } forEach _r;   // lock final
                    private _msg = if (_net > 0) then { format ["<t size='1.7' color='#4fcf6a' align='center' shadow='1'>WIN  +$%1</t>", [_net] call AP_fnc_numberText] }
                                   else { "<t size='1.5' color='#e05555' align='center'>NO MATCH</t>" };
                    (_disp displayCtrl 1012) ctrlShow true;
                    (_disp displayCtrl 1012) ctrlSetStructuredText parseText _msg;
                    (_disp displayCtrl 1210) ctrlShow false;
                    (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;
                    (_disp displayCtrl 1010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call AP_fnc_numberText];
                };};

            case "roulette": {
                _payload params [["_spin",0],["_isRed",false],["_isGreen",false],["_win",false],["_bet",0],["_ret",0],["_net",0],["_betType",""]];
                { (_disp displayCtrl _x) ctrlShow false; } forEach [1200,1201,1202,1203,1204,1006,1012,1210,1260,1261,1262,1263,1264,1265,1266,1267,1268,1269,1271,1270];
                [_disp, _spin, _win, _net] spawn {params ["_disp","_spin","_win","_net"];
                    disableSerialization;
                    private _grp = _disp displayCtrl 1259;
                    private _cells = [1250,1251,1252,1253,1254,1255,1256,1257,1258] apply { _grp controlsGroupCtrl _x };
                    private _center = 4;
                    private _order = [0,28,9,26,30,11,7,20,32,17,5,22,34,15,3,24,36,13,1,37,27,10,25,29,12,8,19,31,18,6,21,33,16,4,23,35,14,2];   // American double-zero wheel order (38 pockets; 37 = "00")
                    private _len = count _order;
                    private _redNums = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
                    private _fnCol = { params ["_n"]; if (_n isEqualTo 0 || {_n isEqualTo 37}) then {[0.15,0.5,0.2,1]} else { if (_n in _redNums) then {[0.7,0.13,0.13,1]} else {[0.12,0.12,0.14,1]} } };
                    private _bx = uiNamespace getVariable ["AP_rlCellX", (_cells apply { (ctrlPosition _x) select 0 })];
                    private _cellW = if (count _bx > 1) then { (_bx select 1) - (_bx select 0) } else { 0.1 };
                    private _spinIdx = _order find _spin;
                    private _target = 6 * _len + _spinIdx;                 // ~6 revolutions + landing
                    private _fnPaint = {params ["_base", "_frac"]; {private _i = _forEachIndex;
                            private _num = _order select ((((_base + _i - _center) mod _len) + _len) mod _len);
                            _x ctrlSetStructuredText parseText format ["<t size='2.0' align='center' color='#ffffff'>%1</t>", (if (_num isEqualTo 37) then {"00"} else {str _num})];
                            _x ctrlSetBackgroundColor ([_num] call _fnCol);
                            private _cp = ctrlPosition _x;
                            _x ctrlSetPosition [(_bx select _i) - _frac * _cellW, _cp select 1, _cp select 2, _cp select 3];
                            _x ctrlCommit 0;} forEach _cells;};
                    private _t0 = time; private _dur = 5.5;
                    while { (time - _t0) < _dur } do {if (isNull _disp) exitWith {};
                        private _p    = (time - _t0) / _dur;
                        private _pos  = _target * (1 - ((1 - _p) ^ 3.5));   // ease-out (fast -> long smooth slow-down)
                        [floor _pos, (_pos - floor _pos)] call _fnPaint;
                        uiSleep 0.02;};
                    if (isNull _disp) exitWith {};
                    [_target, 0] call _fnPaint;                            // settle exactly: center cell = _spin
                    private _spinTxt = if (_spin isEqualTo 37) then {"00"} else {str _spin};
                    private _msg = if (_win) then { format ["<t size='1.5' color='#4fcf6a' align='center'>%1  -  WIN  +$%2</t>", _spinTxt, [_net] call AP_fnc_numberText] }
                                   else { format ["<t size='1.4' color='#e05555' align='center'>%1  -  LOSE  -$%2</t>", _spinTxt, [abs _net] call AP_fnc_numberText] };
                    (_disp displayCtrl 1012) ctrlShow true;
                    (_disp displayCtrl 1012) ctrlSetStructuredText parseText _msg;
                    (_disp displayCtrl 1210) ctrlShow false;
                    (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;
                    (_disp displayCtrl 1010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call AP_fnc_numberText];
                };};

            case "hilo": {_payload params [["_phase","play"],["_card",-1],["_mult",1],["_bet",0],["_pot",0],["_last",-1],["_result",""]];
                // draw the current card
                private _cc = _disp displayCtrl 1250;
                if (_card >= 0) then { _cc ctrlShow true; _cc ctrlSetText format ["images\casino\%1.paa", [_card] call _cardName]; };
                // hide the betting group once a run is live
                { (_disp displayCtrl _x) ctrlShow false; } forEach [1200,1201,1202,1203,1204,1006];

                switch (_phase) do {case "play": {AP_casHiloInGame = true;
                        (_disp displayCtrl 1210) ctrlShow false;                      // hide DEAL
                        { (_disp displayCtrl _x) ctrlShow true;  } forEach [1220, 1221, 1231, 1252];
                        { (_disp displayCtrl _x) ctrlEnable true; } forEach [1220, 1221, 1231];
                        (_disp displayCtrl 1012) ctrlShow false;
                        (_disp displayCtrl 1230) ctrlShow false;
                        // owner 2026-07-08: pre-guess (mult 1.0) the pot is HALVED by the early-quit penalty, so showing
                        // "1.00x  Cash out: $<half>" openly contradicts itself. Label the penalty explicitly instead;
                        // after a guess (mult > 1.0) show the real multiplier.
                        if (_mult <= 1.0) then {
                            (_disp displayCtrl 1252) ctrlSetStructuredText parseText format ["<t size='1.1' align='center' color='#e7c757'>Early cash-out (½ penalty):  <t color='#4fcf6a'>$%1</t>  —  guess to remove it</t>", [_pot] call _fnNum];
                        } else {
                            (_disp displayCtrl 1252) ctrlSetStructuredText parseText format ["<t size='1.25' align='center'>%1x   Cash out:  <t color='#4fcf6a'>$%2</t></t>", (_mult toFixed 2), [_pot] call _fnNum];
                        };};
                    case "bust": {AP_casHiloInGame = false;
                        { (_disp displayCtrl _x) ctrlShow false; } forEach [1210, 1220, 1221, 1231, 1252];
                        (_disp displayCtrl 1012) ctrlShow true;
                        (_disp displayCtrl 1012) ctrlSetStructuredText parseText format ["<t size='1.6' color='#e05555' align='center'>BUSTED  -$%1</t>", [_bet] call _fnNum];
                        (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;};
                    case "cashout": {AP_casHiloInGame = false;
                        private _net = _pot - _bet;
                        { (_disp displayCtrl _x) ctrlShow false; } forEach [1210, 1220, 1221, 1231, 1252];
                        (_disp displayCtrl 1012) ctrlShow true;
                        (_disp displayCtrl 1012) ctrlSetStructuredText parseText format ["<t size='1.6' color='#4fcf6a' align='center'>CASHED OUT  +$%1</t>", [_net] call _fnNum];
                        (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;};};
                [_disp] call _fnReadouts;};
            case "crash": {private _phase = _payload param [0, ""];
                { (_disp displayCtrl _x) ctrlShow false; } forEach [1200,1201,1202,1203,1204];
                switch (_phase) do {case "start": {_payload params ["", ["_bet",0], ["_start",0]];
                        AP_crashRound = [true, _start, _bet];
                        { (_disp displayCtrl _x) ctrlShow false; } forEach [1210, 1230, 1012];
                        { (_disp displayCtrl _x) ctrlShow true;  } forEach [1006, 1252, 1231];
                        (_disp displayCtrl 1231) ctrlEnable true;
                        [] spawn {while { (AP_crashRound param [0, false]) && {!isNull (findDisplay 930360)} } do {
                                private _d = findDisplay 930360;
                                private _t = (serverTime - (AP_crashRound param [1, serverTime])) max 0;
                                private _m = (round ((2.718281828 ^ (0.1386 * _t)) * 100)) / 100;
                                (_d displayCtrl 1006) ctrlSetStructuredText parseText format ["<t size='3.2' align='center' font='PuristaBold' color='#e7c757'>%1x</t>", _m toFixed 2];
                                (_d displayCtrl 1252) ctrlSetStructuredText parseText format ["<t size='1.35' align='center' color='#4fcf6a'>Cash Out:  $%1</t>", [round ((AP_crashRound param [2,0]) * _m)] call AP_fnc_numberText];
                                uiSleep 0.07;};};};
                    case "cashout": {_payload params ["", ["_m",1], ["_bet",0], ["_ret",0]];
                        AP_crashRound set [0, false];
                        (_disp displayCtrl 1006) ctrlSetStructuredText parseText format ["<t size='3.2' align='center' font='PuristaBold' color='#4fcf6a'>%1x</t>", _m toFixed 2];
                        { (_disp displayCtrl _x) ctrlShow false; } forEach [1252, 1231];
                        (_disp displayCtrl 1012) ctrlShow true;
                        (_disp displayCtrl 1012) ctrlSetStructuredText parseText format ["<t size='1.6' align='center' color='#4fcf6a'>CASHED OUT  +$%1</t>", [_ret - _bet] call _fnNum];
                        (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;
                        [_disp] call _fnReadouts;};
                    case "bust": {_payload params ["", ["_bust",1], ["_bet",0]];
                        AP_crashRound set [0, false];
                        (_disp displayCtrl 1006) ctrlSetStructuredText parseText format ["<t size='2.6' align='center' font='PuristaBold' color='#e05555'>CRASH @ %1x</t>", _bust toFixed 2];
                        { (_disp displayCtrl _x) ctrlShow false; } forEach [1252, 1231];
                        (_disp displayCtrl 1012) ctrlShow true;
                        (_disp displayCtrl 1012) ctrlSetStructuredText parseText format ["<t size='1.6' align='center' color='#e05555'>BUSTED  -$%1</t>", [_bet] call _fnNum];
                        (_disp displayCtrl 1230) ctrlShow true; (_disp displayCtrl 1230) ctrlEnable true;
                        [_disp] call _fnReadouts;};};};};};

    // ── BACK to the landing ────────────────────────────────────────────────────────────────────────
    case "back": {
        // owner 2026-07-08: leaving an IN-PROGRESS hi-lo run forfeits the already-debited stake. Guard the mis-click
        // with a two-tap confirm surfacing the amount (< LOBBY sits top-left, right where players reach to close/drag).
        if (AP_casGame isEqualTo "hilo" && {missionNamespace getVariable ["AP_casHiloInGame", false]}) then {
            private _last = missionNamespace getVariable ["AP_casLeaveConfirm", -999];
            if ((diag_tickTime - _last) > 4) then {AP_casLeaveConfirm = diag_tickTime;   // FIRST tap: warn + arm, do NOT leave yet
                [format ["Leaving forfeits your $%1 hi-lo stake. Tap < LOBBY again to confirm.", [AP_casBet] call _fnNum], "basic"] spawn AP_fnc_handleMessage;
            } else {AP_casLeaveConfirm = -999;            // SECOND tap within 4s: forfeit + leave
                [["hilo", "quit", []], "APS_fnc_casinoSRV", 2] spawn AP_fnc_MP;
                AP_casHiloInGame = false;
                closeDialog 0;
                [] spawn { uiSleep 0.05; ["landing", []] call AP_fnc_casino; };};} else {AP_casHiloInGame = false;
            closeDialog 0;
            // defer one frame so the close fully settles before recreating the landing (else it falls through to the phone)
            [] spawn { uiSleep 0.05; ["landing", []] call AP_fnc_casino; };};};

    default { diag_log format ["[LooneyBin][casino] unhandled mode: %1", _mode]; };};
