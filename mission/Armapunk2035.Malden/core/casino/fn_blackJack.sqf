/*
    fn_blackJack.sqf  (AP_fnc_blackJack)  -- LooneyBin Casino phone app, blackjack CLIENT controller.
    Single multi-mode fn: it is BOTH the phone-app opener/handler AND the server's "render" callback.
    dialog: dialog/blackjack.hpp  (idd 930000).  Engine: server APS_fnc_blackJackSRV.

    SECURITY: the client NEVER decides a win or credits a payout. It only
      (a) debits the bet from BANK locally via AP_fnc_uC before deal/double/split,
      (b) sends the player's INTENT to APS_fnc_blackJackSRV (server owner 2),
      (c) RENDERS the _view the server returns.
    All payouts arrive server-gated via AP_fnc_blackJackReceive. See fn_blackJackSRV.sqf for the protocol.

    Dispatch: AP_fnc_blackJack receives _this = ["<mode>", <args>].
      "open"                        open the app (gates jailed/restrained/downed/combat/non-civ)
      "betui"                       show the betting screen (chips + DEAL)
      "deal"/"hit"/"stand"/"double"/"split"   button handlers (deal/double/split debit locally first)
      "render"  (server-sent)       args = _view = [_handsView,_dealerView,_activeIdx,_actions,_phase]
      "playagain"                   back to the betting screen
      "exit"                        forfeit any in-progress game (send "quit") then closeDialog

    _view (from server): _handsView = [[cardNames,bet,statusStr,value],...]; _dealerView = [cardNames,shownValue];
      _activeIdx; _actions = [canHit,canStand,canDouble,canSplit]; _phase = "player"|"resolved".
      cardNames are bare ("H10","SA","backside") -> images\casino\<name>.paa.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
disableSerialization;
params [["_mode", "open", [""]], ["_args", [], [[]]]];

private _display = findDisplay 930000;

// ── helpers ──────────────────────────────────────────────────────────────────────────────────────
private _fnNum = { params ["_n"]; [_n] call AP_fnc_numberText };                       // comma format
private _fnBetK = { params ["_b"]; format ["$%1k", round (_b / 1000)] };                  // compact chip label

// gate: returns "" when the player may gamble, else a rejection message (wanted IS allowed)
private _fnGate = {
    if ((AP_is_arrested isEqualType []) && {(AP_is_arrested param [0, 0]) > 0}) exitWith { "You can't gamble from a cell." };
    if (player getVariable ["AP_restrained", false]) exitWith { "Your hands are restrained." };
    if (!alive player || {AP_isDowned} || {AP_knockout}) exitWith { "You're in no state to gamble." };
    if (AP_inCombat) exitWith { "You can't gamble while in combat." };
    if !(AP_effSide in [civilian, west, independent]) exitWith { "You can't play at the casino right now." };   // owner 2026-07-10: blackjack was the one casino game still civ-only (cops/TT could open the rest); match fn_casino/fn_casinoApp
    ""};

// paint a card slot from a bare card name and reveal it
private _fnCard = { params ["_ctrl", "_name"]; _ctrl ctrlSetText format ["images\casino\%1.paa", _name]; _ctrl ctrlShow true };

// hide every dynamic table control (dealer cards + value, all 4 hands' panel/cards/value/bet, banner, play-again)
private _fnReset = {
    { (_display displayCtrl _x) ctrlShow false } forEach [930020, 930021, 930022, 930023, 930024, 930025, 930026, 930027, 930012, 930230]; {
        private _base = _x;
        { (_display displayCtrl (_base + _x)) ctrlShow false } forEach [0, 1, 2, 3, 4, 5, 10, 11];
    } forEach [930100, 930120, 930140, 930160];};

switch (toLower _mode) do {

    // ── OPEN: gate, create the dialog, wire buttons once, show the betting screen ──
    case "open": {private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };
        if (isNil "AP_bjBet") then { AP_bjBet = 10000 };
        AP_bjInGame = false;

        private _newLoad = if (isNull (findDisplay 930000)) then {createDialog "AP_blackjack_menu";
            waitUntil { !isNull (findDisplay 930000) };
            // (no phone status bar here -- blackjack.hpp declares none of ctrls 90300-90303,
            //  so the fn_p_updateMenu call this replaces was a no-op that spun a 1s loop.)
            true} else { false };
        _display = findDisplay 930000;
        if (isNull _display) exitWith {};

        if (_newLoad) then {   // wire game buttons ONCE (fn_money _newLoad guard)
            (_display displayCtrl 930210) ctrlAddEventHandler ["ButtonClick", { ['deal']      call AP_fnc_blackJack }];
            (_display displayCtrl 930220) ctrlAddEventHandler ["ButtonClick", { ['hit']       call AP_fnc_blackJack }];
            (_display displayCtrl 930221) ctrlAddEventHandler ["ButtonClick", { ['stand']     call AP_fnc_blackJack }];
            (_display displayCtrl 930222) ctrlAddEventHandler ["ButtonClick", { ['double']    call AP_fnc_blackJack }];
            (_display displayCtrl 930223) ctrlAddEventHandler ["ButtonClick", { ['split']     call AP_fnc_blackJack }];
            (_display displayCtrl 930230) ctrlAddEventHandler ["ButtonClick", { ['playAgain'] call AP_fnc_blackJack }];
            // < LOBBY: close (onUnload forfeits any in-progress hand) then reopen the casino game-select landing.
            // owner 2026-07-08: two-tap forfeit confirm when a hand is IN PROGRESS -- surfaces the stake so a mis-click
            // on the top-left button doesn't silently destroy the already-debited bet.
            (_display displayCtrl 930240) ctrlAddEventHandler ["ButtonClick", {
                if (missionNamespace getVariable ["AP_bjInGame", false]) then {
                    private _last = missionNamespace getVariable ["AP_bjLeaveConfirm", -999];
                    if ((diag_tickTime - _last) > 4) exitWith {AP_bjLeaveConfirm = diag_tickTime;   // FIRST tap: warn + arm, don't close
                        [format ["Leaving forfeits your $%1 blackjack stake. Tap < LOBBY again to confirm.", [AP_bjBet] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                    };};
                AP_bjLeaveConfirm = -999;   // SECOND tap (or not in a hand): leave
                closeDialog 0; [] spawn { uiSleep 0.05; ['landing', []] call AP_fnc_casino };}]; {private _amt = _x;
                (_display displayCtrl (930200 + _forEachIndex)) ctrlAddEventHandler ["ButtonClick", compile format ["AP_bjBet = %1; ['betUI'] call AP_fnc_blackJack", _amt]];
            } forEach [10000, 50000, 100000, 250000, 500000];
            // capture each hand-control's BASE x once (for split-centering in render)
            private _bx = [];
            { private _b = _x; { _bx pushBack [_b + _x, (ctrlPosition (_display displayCtrl (_b + _x))) select 0]; } forEach [0,1,2,3,4,5,10,11]; } forEach [930100,930120,930140,930160];
            uiNamespace setVariable ["AP_bjBaseX", _bx];};

        ['betUI'] call AP_fnc_blackJack;};

    // ── BET UI: chips + DEAL visible; hide the action/result/dealer controls; highlight selected chip ──
    case "betui": {if (isNull _display) exitWith {};
        if (missionNamespace getVariable ["AP_bjInGame", false]) exitWith {};   // a stray chip click can't re-open the betting screen mid-hand
        if (isNil "AP_bjBet") then { AP_bjBet = 10000 };
        AP_bjBet = (AP_bjBet max 10000) min 500000;
        AP_bjInGame = false;

        call _fnReset;
        { (_display displayCtrl _x) ctrlShow true } forEach [930200, 930201, 930202, 930203, 930204, 930206, 930210];
        { (_display displayCtrl _x) ctrlEnable true } forEach [930200, 930201, 930202, 930203, 930204, 930210];   // re-enable the full betting group (deal disables it)
        { (_display displayCtrl _x) ctrlShow false } forEach [930220, 930221, 930222, 930223, 930012, 930230, 930020];
 {   // chip highlight (gold = selected)
            (_display displayCtrl (930200 + _forEachIndex)) ctrlSetBackgroundColor (if (_x isEqualTo AP_bjBet) then { [0.72, 0.55, 0.15, 1] } else { [0.15, 0.22, 0.35, 1] });
        } forEach [10000, 50000, 100000, 250000, 500000];

        (_display displayCtrl 930206) ctrlSetStructuredText parseText format ["<t size='1.15' align='center'>Bet:  $%1</t>", [AP_bjBet] call _fnNum];
        (_display displayCtrl 930010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call _fnNum];
        (_display displayCtrl 930011) ctrlSetStructuredText parseText format ["<t size='1.0' align='right'>BET  $%1</t>", [AP_bjBet] call _fnNum];
    };

    // ── DEAL: re-gate, debit the bet locally, then send intent (server owns the deal) ──
    case "deal": {if (isNull _display) exitWith {};
        private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };
        private _bet = (AP_bjBet max 10000) min 500000;
        AP_bjBet = _bet;
        if !(["atm", "take", _bet] call AP_fnc_uC) exitWith { ["Not enough bank funds for that bet.", "basic"] spawn AP_fnc_handleMessage };
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;   // keep AC cash cache in sync (uC does NOT)
        { (_display displayCtrl _x) ctrlEnable false } forEach [930200, 930201, 930202, 930203, 930204, 930210];   // debounce the ENTIRE betting group -- a chip re-click must not resurrect DEAL mid-deal (double-debit)
        AP_bjInGame = true;
        [["deal", [_bet]], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;};

    // ── HIT / STAND: no debit, just send intent (debounce the action pad) ──
    case "hit": {if (isNull _display) exitWith {};
        { (_display displayCtrl _x) ctrlEnable false } forEach [930220, 930221, 930222, 930223];
        [["hit", []], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;};
    case "stand": {if (isNull _display) exitWith {};
        { (_display displayCtrl _x) ctrlEnable false } forEach [930220, 930221, 930222, 930223];
        [["stand", []], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;};

    // ── DOUBLE: debit the ACTIVE hand's current bet (cached from the last render) then send ──
    case "double": {if (isNull _display) exitWith {};
        private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };
        private _bet = AP_bjActiveBet;
        if !(["atm", "take", _bet] call AP_fnc_uC) exitWith { ["Not enough bank to double.", "basic"] spawn AP_fnc_handleMessage };
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        { (_display displayCtrl _x) ctrlEnable false } forEach [930220, 930221, 930222, 930223];
        [["double", []], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;};

    // ── SPLIT: debit the active hand's base bet (== its bet field on an untouched 2-card hand) then send ──
    case "split": {if (isNull _display) exitWith {};
        private _gate = call _fnGate;
        if (_gate isNotEqualTo "") exitWith { [_gate, "basic"] spawn AP_fnc_handleMessage };
        private _bet = AP_bjActiveBet;
        if !(["atm", "take", _bet] call AP_fnc_uC) exitWith { ["Not enough bank to split.", "basic"] spawn AP_fnc_handleMessage };
        AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
        [1] call AP_fnc_ClupdatePartial;
        { (_display displayCtrl _x) ctrlEnable false } forEach [930220, 930221, 930222, 930223];
        [["split", []], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;};

    // ── RENDER (server-sent): draw the table. NEVER credits money -- just draws _view. ──
    case "render": {if (isNull _display) exitWith {};
        _args params [["_handsView", []], ["_dealerView", [[], -1]], ["_activeIdx", -1], ["_actions", [false, false, false, false]], ["_phase", "player"]];
        AP_bjLastView = _args;
        AP_bjActiveBet = if (_activeIdx >= 0 && {_activeIdx < count _handsView}) then { (_handsView select _activeIdx) select 1 } else { AP_bjBet };

        call _fnReset;
        { (_display displayCtrl _x) ctrlShow false } forEach [930200, 930201, 930202, 930203, 930204, 930206, 930210];   // hide betting group

        // card-fan helper: lay N cards centered on _cxPx within _budgetPx (side-by-side for 2, tighter fan for more)
        private _fnFan = {params ["_slots", "_names", "_cxPx", "_budgetPx"];
            private _n = count _names; if (_n == 0) exitWith {};
            private _cw = 5.573 * pixelGrid * pixelW;                                  // 0.072*77.4 card width
            private _step = (_cw * 0.94) min ((_budgetPx - _cw) / (1 max (_n - 1)));
            private _startX = _cxPx - (((_n - 1) * _step + _cw) / 2); {
                private _cc = _slots select (_forEachIndex min ((count _slots) - 1));
                private _cp = ctrlPosition _cc;
                _cc ctrlSetPosition [_startX + _forEachIndex * _step, _cp select 1, _cw, _cp select 3];
                _cc ctrlCommit 0;
                [_cc, _x] call _fnCard;} forEach _names;};
        // dealer row (centered on the phone)
        _dealerView params ["_dCards", "_dShown"];
        [([930021,930022,930023,930024,930025,930026,930027] apply {_display displayCtrl _x}), _dCards, (safezoneX + 0.5*safezoneW), (0.34 * 77.4 * pixelGrid * pixelW)] call _fnFan;
        (_display displayCtrl 930020) ctrlShow true;
        (_display displayCtrl 930020) ctrlSetStructuredText parseText (if (_dShown < 0) then { "<t size='1.1' align='center'>Dealer</t>" } else { format ["<t size='1.1' align='center'>Dealer: %1</t>", _dShown] });

        // player hands (up to 4 columns)
        private _bases = [930100, 930120, 930140, 930160];
        // split-centering: shift the whole hand group left so N hands sit centered (panel step 0.143 phone-frac, PW=77.4)
        private _dx = -((count _handsView) - 1) * 5.535 * pixelGrid * pixelW;
        private _bxArr = uiNamespace getVariable ["AP_bjBaseX", []];
        private _fnShiftX = {params ["_c", "_idc"];
            private _i = _bxArr findIf { (_x select 0) isEqualTo _idc };
            if (_i < 0) exitWith {};
            private _p = ctrlPosition _c;
            _c ctrlSetPosition [((_bxArr select _i) select 1) + _dx, _p select 1, _p select 2, _p select 3];
            _c ctrlCommit 0;}; {_x params ["_cards", "_bet", "_status", "_value"];
            private _base  = _bases select _forEachIndex;
            private _panel = _display displayCtrl _base;
            _panel ctrlShow true;
            { private _off = _x; [(_display displayCtrl (_base + _off)), (_base + _off)] call _fnShiftX; } forEach [0,10,11];   // shift panel+value+bet; cards fanned below
            private _col = switch (true) do {
                case (_phase isEqualTo "player" && {_forEachIndex isEqualTo _activeIdx}): { [0, 0, 0, 0] };   // active = no box (owner 2026-07-06)
                case (_status in ["win", "blackjack"]): { [0.15, 0.45, 0.20, 0.55] };   // win = green
                case (_status in ["lose", "busted"]):   { [0.45, 0.10, 0.10, 0.55] };   // lose = red
                case (_status isEqualTo "push"):        { [0.28, 0.28, 0.28, 0.55] };   // push = grey
                default { [0, 0, 0, 0.28] };};
            _panel ctrlSetBackgroundColor _col;

            // fan this hand's cards centered on its (shifted) panel; narrower budget when split so hands don't collide
            private _handCx = (ctrlPosition _panel select 0) + (ctrlPosition _panel select 2) / 2;
            private _pbudget = (if ((count _handsView) <= 1) then { 0.22 } else { 0.135 }) * 77.4 * pixelGrid * pixelW;
            [([1,2,3,4,5] apply {_display displayCtrl (_base + _x)}), _cards, _handCx, _pbudget] call _fnFan;

            private _vCtrl = _display displayCtrl (_base + 10);
            _vCtrl ctrlShow true;
            _vCtrl ctrlSetStructuredText parseText format ["<t size='1.0' align='center'>%1</t>", _value];

            private _word = switch (_status) do {case "blackjack": { "BLACKJACK" };
                case "win":       { "WIN" };
                case "lose":      { "LOSE" };
                case "push":      { "PUSH" };
                case "busted":    { "BUST" };
                case "stood":     { "STAND" };
                default { "" };};
            private _bCtrl = _display displayCtrl (_base + 11);
            _bCtrl ctrlShow true;
            _bCtrl ctrlSetStructuredText parseText format ["<t size='0.85' align='center'>%1%2</t>", [_bet] call _fnBetK, (if (_word isEqualTo "") then { "" } else { format [" - %1", _word] })];
        } forEach _handsView;

        if (_phase isEqualTo "player") then {_actions params ["_cH", "_cS", "_cD", "_cP"];
            { (_display displayCtrl _x) ctrlShow true } forEach [930220, 930221, 930222, 930223];
            (_display displayCtrl 930220) ctrlEnable _cH;
            (_display displayCtrl 930221) ctrlEnable _cS;
            (_display displayCtrl 930222) ctrlEnable _cD;
            (_display displayCtrl 930223) ctrlEnable _cP;
            (_display displayCtrl 930012) ctrlShow false;
            (_display displayCtrl 930230) ctrlShow false;
            AP_bjInGame = true;} else {
            // resolved: hide the action pad, show the result banner (display-only net) + DEAL AGAIN
            { (_display displayCtrl _x) ctrlShow false } forEach [930220, 930221, 930222, 930223];
            private _net = 0; {_x params ["", "_bet", "_status"];
                switch (_status) do {case "win":       { _net = _net + _bet };
                    case "blackjack": { _net = _net + round (_bet * 1.5) };   // 3:2 natural -- MATCH the server credit (fn_blackJackSRV.sqf:139 pays _bet + round(_bet*1.5)); the old 1.2 (6:5) under-reported every natural on-screen
                    case "push":      { };
                    default { _net = _net - _bet };   // lose / busted
                };} forEach _handsView;
            private _bText = switch (true) do {
                case (_net > 0): { format ["<t size='1.6' color='#4fcf6a' align='center'>YOU WIN  +$%1</t>", [_net] call _fnNum] };
                case (_net < 0): { format ["<t size='1.6' color='#e05555' align='center'>DEALER WINS  -$%1</t>", [abs _net] call _fnNum] };
                default { "<t size='1.6' color='#dddddd' align='center'>PUSH</t>" };};
            (_display displayCtrl 930012) ctrlShow true;
            (_display displayCtrl 930012) ctrlSetStructuredText parseText _bText;
            (_display displayCtrl 930230) ctrlShow true;
            (_display displayCtrl 930230) ctrlEnable true;
            AP_bjInGame = false;};

        (_display displayCtrl 930010) ctrlShow true;
        (_display displayCtrl 930011) ctrlShow true;
        (_display displayCtrl 930010) ctrlSetStructuredText parseText format ["<t size='1.0' align='left'>BANK  $%1</t>", [AP_atmcash] call _fnNum];
        (_display displayCtrl 930011) ctrlSetStructuredText parseText format ["<t size='1.0' align='right'>BET  $%1</t>", [AP_bjBet] call _fnNum];
    };

    // ── PLAY AGAIN: clear the table, back to the betting screen ──
    case "playagain": {if (isNull _display) exitWith {};
        ['betUI'] call AP_fnc_blackJack;};

    // ── EXIT: forfeit any in-progress game (server clears AP_bjGames) then close ──
    case "exit": {[["quit", []], "APS_fnc_blackJackSRV", 2] spawn AP_fnc_MP;   // no-op server-side if no game exists
        AP_bjInGame = false;
        closeDialog 0;};

    default { diag_log format ["[LooneyBin][blackjack] unhandled client mode: %1", _mode]; };};
