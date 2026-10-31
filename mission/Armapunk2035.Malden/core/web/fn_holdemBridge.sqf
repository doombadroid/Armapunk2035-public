/*
    AP_fnc_holdemBridge -- the four verbs ui\html\casino\holdem.html calls. Registered by
    AP_fnc_holdemOpen on the control it has already initialised.

        [_ctrl] call AP_fnc_holdemBridge;

    THE PAGE DEFINES THE CONTRACT (its header comment); this file matches it and adds nothing:

        AP.call("hSit",  [seat, buyIn], cb) -> { ok, err }   err: taken / bank / gate
        AP.call("hLeave",[],            cb) -> { ok }        the stack banks server-side
        AP.call("hAct",  [act, raiseTo],cb) -> { ok, err }   raiseTo is a STREET TOTAL
        AP.call("casTable", ["landing"])    -> the BACK link; SQF swaps the dialog

    WHICH ANSWER PATH, AND WHY. There were two precedents to copy and neither fits whole:

      * AP_fnc_dutyTermBridge answers dutyStart WITH THE REAL RESULT, because a duty request is
        decided by a chain of local reads plus one synchronous AP_fnc_dutyRequest. Nothing waits on
        the server.
      * AP_fnc_casinoOpen's casPlay answers {ok:true} and calls that "deliberately optimistic": the
        server settles later and the result arrives on its own channel.

    A webui handler is `call`ed and must return a value in the same frame (webui\functions\fn_on.sqf
    -- "its return value is sent back"), and APS_fnc_holdemSRV is a remoteExec away on another
    machine. So the duty shape is not available here at all: there is nothing to wait on that would
    not block the client's frame. This file therefore takes casPlay's shape and closes the gap
    casPlay left open -- A SERVER REFUSAL MUST STILL SURFACE:

      * Everything the CLIENT can decide on its own is decided here and refused instantly, with the
        page's own {ok:false, err} shape: the casino gate, the bank balance, the buy-in band, and
        the cheap turn/seat/raise checks read off the last state the server pushed. This is the
        twin-gate pattern -- fn_bjOpen does the same for bjSit/bjBet -- and it exists for the
        latency, not for the security. Every one of these is re-run server-side.
      * Everything else forwards and answers {ok:true}, and THE SERVER'S REFUSAL COMES BACK IN THE
        NEXT PUSH'S `msg` -- APS_fnc_holdemSRV's _refuse builds that viewer's own snapshot with the
        reason in it. The page renders msg verbatim in its status strip. A refusal is never dropped;
        it simply arrives a round trip after the optimistic ok rather than instead of it.

    NOTHING HERE IS AN AUTHORITY. The state these checks read is a copy of the last server push
    (AP_fnc_holdemReceive stores it), which is by definition one round trip old, and a modified
    client can call every verb below with anything it likes -- exactly as it could from the debug
    console. The server re-derives the caller from remoteExecutedOwner and re-checks the seat, the
    turn, the amount and the minimum raise against its own table. Read the refusals below as
    "answer the obvious cases without a round trip", not as a gate.

    THE BRIDGE NEVER MOVES MONEY. That is the one place hold'em departs from every other table in
    the casino: fn_bjOpen debits AP_atmcash before it sends, this file does not touch it. The bank
    read in hSit is a look, not a withdrawal -- the server orders the debit through
    AP_fnc_holdemCash once it has granted the seat. See APS_fnc_holdemSRV's header.
*/

params [["_ctrl", controlNull, [controlNull]]];
if (isNull _ctrl) exitWith { diag_log "[HOLDEM] bridge: null control"; false };

// The bank figure and the gate string, from the casino's single source. Registered as a CALLABLE
// as well as pushed, so a page that asks gets a fresh read rather than the one from open time.
[_ctrl, "casino", { [] call AP_fnc_casinoData }] call webui_fnc_on;

// BACK to the floor. There is no navigation inside a browser control, so leaving is closeDialog +
// createDialog, same as arriving. Identical to every other table's handler.
[_ctrl, "casTable", {
    params [["_t", "", [""]]];
    [_t] spawn AP_fnc_casinoOpen;
    createHashMapFromArray [["ok", true], ["err", ""], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "hSit", {
    params [["_seat", -1, [0]], ["_amt", 0, [0]]];
    private _fnc_no = { createHashMapFromArray [["ok", false], ["err", _this], ["msg", _this]] };
    private _S = uiNamespace getVariable ["AP_holdemState", createHashMap];

    // fn_casino's own gate, re-read at the moment of the click rather than trusted from whatever
    // the page last rendered. This is the half of AP_fnc_casinoData's gate the SERVER cannot see:
    // arrested, restrained, downed, in combat, wrong side are all client-side facts. The server
    // enforces the half it owns -- casino self-exclusion -- on its side.
    private _gate = ([] call AP_fnc_casinoData) get "gate";
    if (_gate isNotEqualTo "") exitWith { (toUpper _gate) call _fnc_no };

    if !(_seat >= 0 && {_seat < 6}) exitWith { "NO SUCH SEAT" call _fnc_no };
    _amt = round _amt;
    private _band = _S getOrDefault ["buyIn", []];
    // FLAT exitWiths: nested in `if (count _band == 2) then {}` they only left that block and the
    // refusal was thrown away (the server re-checks the band either way).
    if ((count _band) isEqualTo 2 && {_amt < (_band select 0)}) exitWith { (format ["MINIMUM BUY-IN IS $%1", _band select 0]) call _fnc_no };
    if ((count _band) isEqualTo 2 && {_amt > (_band select 1)}) exitWith { (format ["MAXIMUM BUY-IN IS $%1", _band select 1]) call _fnc_no };
    // A LOOK, NOT A WITHDRAWAL. AP_atmcash is the only copy of the bank this machine has and the
    // server cannot read it, so somebody has to check it -- but nothing is debited here. The server
    // grants the seat and then orders the debit; if this read was stale the debit floors at zero
    // and says so (AP_fnc_holdemCash).
    if (AP_atmcash < _amt) exitWith { "NOT ENOUGH IN THE BANK" call _fnc_no };

    private _seats = _S getOrDefault ["seats", []];
    private _mine = _seats findIf { _x isEqualType createHashMap && {_x getOrDefault ["me", false]} };
    if (_mine > -1) exitWith { "YOU ARE ALREADY SEATED" call _fnc_no };
    // An empty seat arrives as objNull -- _snap pushes objNull so toJSON renders the page's `null` --
    // so "is this a HashMap" is the occupancy test on both sides of the wire.
    if ((_seats param [_seat, 0]) isEqualType createHashMap) exitWith { "SEAT TAKEN" call _fnc_no };

    [["sit", [_seat, _amt]], "APS_fnc_holdemSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["err", ""], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "hLeave", {
    // NO GATE. Standing up and taking your stack back is the one thing that must never be refused
    // for being arrested or in combat -- the gate exists to stop people STARTING to gamble.
    [["leave", []], "APS_fnc_holdemSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["err", ""], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "hAct", {
    params [["_act", "", [""]], ["_raiseTo", 0, [0]]];
    private _fnc_no = { createHashMapFromArray [["ok", false], ["err", _this], ["msg", _this]] };
    _act = toLower _act;
    if !(_act in ["fold", "check", "call", "raise", "allin"]) exitWith { "NO SUCH ACTION" call _fnc_no };

    // NO GATE HERE EITHER, and that is a decision rather than an omission. The page already hides
    // the action bar while the gate string is set, so a gated player cannot press these -- and if
    // they somehow could, the worst move available to them is folding, which costs them nothing
    // they had not already committed. Refusing a FOLD because somebody got arrested mid-hand would
    // hold five other players on the clock and then fold them anyway on the timeout.
    private _S = uiNamespace getVariable ["AP_holdemState", createHashMap];
    private _seats = _S getOrDefault ["seats", []];
    private _me = _seats findIf { _x isEqualType createHashMap && {_x getOrDefault ["me", false]} };
    if (_me < 0) exitWith { "YOU ARE NOT SEATED" call _fnc_no };
    if ((_S getOrDefault ["acting", -1]) isNotEqualTo _me) exitWith { "IT IS NOT YOUR TURN" call _fnc_no };

    private _s = _seats select _me;
    private _lvl = _S getOrDefault ["toCall", 0];
    private _bet = _s getOrDefault ["bet", 0];
    private _shove = _bet + (_s getOrDefault ["stack", 0]);
    _raiseTo = round _raiseTo;

    // One reason variable, returned as itself. An exitWith inside a case block exits THE CASE, so a
    // refusal built in there and returned from there is thrown away and the caller sees whatever the
    // switch happened to leave behind -- which is how a specific message turns into a bare "REFUSED".
    private _err = "";
    switch (_act) do {
        case "check": { if ((_lvl - _bet) > 0) then { _err = format ["YOU OWE $%1 — CALL OR FOLD", _lvl - _bet] } };
        case "raise": {
            // A shove is allowed to be short; nothing else is. Mirrors the engine's own test, and
            // the page computes its MIN button from the same two numbers.
            if (_raiseTo < _shove) then {
                private _min = _lvl + (_S getOrDefault ["minRaise", 0]);
                if (_raiseTo < _min) then { _err = format ["MINIMUM RAISE IS TO $%1", _min] };
            };
        };
    };
    if (_err isNotEqualTo "") exitWith { _err call _fnc_no };

    [["act", [_act, _raiseTo]], "APS_fnc_holdemSRV", 2] spawn AP_fnc_MP;
    createHashMapFromArray [["ok", true], ["err", ""], ["msg", ""]]
}] call webui_fnc_on;

true
