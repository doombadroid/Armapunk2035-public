/*
    AP_fnc_dutyPayoff -- offer the MaxSec bounty buyout, send ONE ["payoff", faction] to APS_fnc_dutySRV,
    and BLOCK until the answer can be attributed to it. Returns TRUE only when money actually moved and
    the bounty is clear.

        if ([ "maxsec" ] call AP_fnc_dutyPayoff) then { ...retry the sign-on... };

    THIS MUST RUN SCHEDULED -- it suspends, and it opens a modal. Every caller is already a `spawn`ed
    scroll-action body; an unscheduled arrival is refused rather than self-respawned, because a respawned
    copy could not hand its answer back to the caller that is waiting to retry on it.

    WHY IT IS A SEPARATE FUNCTION AND NOT A BRANCH IN fn_dutyTerminal. Two entry points need the identical
    dance -- the HQ picker (refused while wanted -> offer -> pay -> retry) and the scroll action that
    stands in for the web terminal's missing button -- and a second copy of a confirm-then-spend sequence
    is the drift AP_fnc_dutyGate and AP_fnc_dutyRequest were both factored out to prevent.

    THE ONE CONFIRMATION IN THE WHOLE DUTY TREE, and it is warranted: this SPENDS MONEY. The owner's
    no-confirmation ruling (2026-08-20) was about clocking OFF, which costs nothing and undoes itself.

    THE CLIENT NEVER PRICES ANYTHING. AP_dutyBuyout is the SERVER's quote, published on the player's unit
    at the moment it refused a wanted sign-on, and it is used for ONE thing: putting a number in front of
    the player before they agree to spend it. The payload below carries the faction and nothing else, and
    APS_fnc_dutySRV re-reads the wanted row and re-applies SRV_dutyBuyoutMult itself -- so an edited or
    replayed quote changes what the prompt SAYS and never what the bank does. With no quote in hand (the
    scroll action reached without a refusal first) the prompt now falls back to the client's own
    AP_wantedAmt -- the offender's own published figure (AP_fnc_wantedListAdd), not a guess -- and says so
    explicitly, labelled as an estimate: the server still prices it authoritatively, so a stale or edited
    AP_wantedAmt only ever changes what the prompt SAYS, same as a stale AP_dutyBuyout would.

    CORRELATION IS AP_fnc_dutyRequest's, SLOT FOR SLOT, and deliberately not a second mechanism:
      * SUCCESS is read off client state the server's push wrote -- AP_dutyPaid, the amount actually
        debited, published like AP_wantedAmt. Same idiom as testing AP_onDuty for a granted shift.
      * REFUSAL arrives as a "basic" message and is copied into AP_dutyReqErr by fn_handleMessage's tap
        while, and only while, AP_dutyReqWait names something in flight. This function owns those three
        slots for the length of its own send, which is also what makes "one duty request at a time" hold
        across both functions rather than per-function.
      * SUCCESS IS TESTED FIRST, and that ordering is load-bearing here for the same reason it is there:
        the pardon's own client push (AP_fnc_wantedListAdd 999) and anything else the server says can land
        in either order, and reading the paid amount first means a completed payoff can never be reported
        as a refusal.
    The server sends NO success message on purpose -- the tap cannot tell a congratulation from a refusal
    -- so the confirmation the player sees is toasted here, locally, off the amount the server published.

    NOTHING NEW IS AUTHORISED. "payoff" rides the EXISTING APS_fnc_dutySRV entry (CfgRE.hpp:26,
    allowedTargets = 2), so there is no new remoteExec whitelist entry and no new server function. The
    server re-runs every sign-on gate from its own DB read before it takes a cent -- alive, civilian, not
    restrained, not rostered, not inside the release cooldown, not incarcerated, and on the MaxSec
    whitelist -- because money must not move for a shift that cannot then start.
*/
params [["_faction", "maxsec", [""]], ["_tag", "DUTYPAY", [""]]];
if (!canSuspend) exitWith {
    diag_log format ["[%1] payoff: unscheduled caller -- refusing", _tag];
    false
};
if (_faction isNotEqualTo "maxsec") exitWith { false };

// One at a time, against the SAME slot AP_fnc_dutyRequest uses -- a payoff racing a sign-on would have
// two answers arriving into one tap with no way to tell whose is whose.
// "shortwarning" AND NOT "basic", and the reason is the tap itself -- see the toast at the bottom of
// this file. This line is emitted precisely WHEN a request is in flight, i.e. exactly when the tap is
// armed, so as a "basic" message it would be copied into AP_dutyReqErr and answer somebody else's
// sign-on with it.
if ((missionNamespace getVariable ["AP_dutyReqWait", ""]) isNotEqualTo "") exitWith {
    ["A duty request is already in flight.", "shortwarning"] spawn AP_fnc_handleMessage;
    false
};

private _quote = round (player getVariable ["AP_dutyBuyout", 0]);
// NO REFUSAL QUOTE IN HAND (the scroll action reached this function without a wanted sign-on refusing
// it first, so AP_dutyBuyout never got published) -- fall back to AP_wantedAmt, the offender's own
// figure, published the same way (AP_fnc_wantedListAdd) and already public. LABELLED AN ESTIMATE and
// not stated as the price: the server prices this authoritatively from its own wanted row at payoff
// time (see the header note), so a stale or edited AP_wantedAmt can only mislabel the prompt, never
// the charge.
private _est = round (player getVariable ["AP_wantedAmt", 0]);
private _prompt = if (_quote > 0) then {
    format ["Pay off your $%1 bounty and sign on?", [_quote] call AP_fnc_numberText]
} else {
    if (_est > 0) then {
        format ["Pay off your bounty (about $%1 on your record) and sign on?", [_est] call AP_fnc_numberText]
    } else {
        "Pay off your outstanding bounty and sign on? The terminal charges the amount on your record."
    }
};
if !([_prompt, format ["%1 Duty Terminal", toUpper _faction], "Pay", "Cancel"] call BIS_fnc_GUIMessage) exitWith { false };

// ARM THE TAP, THEN SEND -- never the other way round. Several of the payoff's gates are in-memory and
// answer inside the frame the send returns on, so arming afterwards is a race this loses by hanging.
AP_dutyReqErr = "";
AP_dutyReqWait = _faction;
// Seeded LOCAL (no third argument, so no broadcast): this is the slot the server's publish will
// overwrite, and it has to start at 0 or a previous payoff's amount would read as this one's success
// before the answer arrives.
player setVariable ["AP_dutyPaid", 0];
// Stamped self-heal, the same shape and the same reason as AP_fnc_dutyRequest's: SQF has no `finally`,
// so a runtime error between here and the clear below would leave fn_handleMessage's tap armed for the
// rest of the session. The stamp is what makes the timer safe. 25s, comfortably past the 18s deadline.
AP_dutyReqAt = diag_tickTime;
[AP_dutyReqAt, _tag] spawn {
    params ["_t0", "_tag"];
    uiSleep 25;
    if ((missionNamespace getVariable ["AP_dutyReqWait", ""]) isNotEqualTo ""
        && {(missionNamespace getVariable ["AP_dutyReqAt", 0]) isEqualTo _t0}) then {
        AP_dutyReqWait = "";
        diag_log format ["[%1] payoff: wait self-cleared 25s after the send that set it (t0 %2)", _tag, _t0];
    };
};
[["payoff", _faction], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
diag_log format ["[%1] payoff sent: faction=%2 quote=$%3", _tag, _faction, _quote];

// 18s, above AP_fnc_dutyRequest's 15s because a payoff is a longer round trip: two whitelist reads, then
// APS_fnc_bankMove's read + write + read-back, then the pardon's DELETE, all through the serialized
// extDB3 mutex. Still bounded, because the server has refusal paths that deliberately send no message at
// all (a nonnumeric uid, an unknown faction, a state change mid-validation) plus a silent throttle.
private _deadline = diag_tickTime + 18;
waitUntil {
    uiSleep 0.2;
    ((player getVariable ["AP_dutyPaid", 0]) > 0)
    || {(missionNamespace getVariable ["AP_dutyReqErr", ""]) isNotEqualTo ""}
    || {diag_tickTime > _deadline}
};
AP_dutyReqWait = "";

private _paid = round (player getVariable ["AP_dutyPaid", 0]);
if (_paid > 0) exitWith {
    AP_dutyReqErr = "";
    player setVariable ["AP_dutyPaid", 0];
    // "lottoinfo" AND NOT "basic", and this is a correctness requirement rather than a style pick.
    // fn_handleMessage's tap copies the FIRST "basic" message that arrives while AP_dutyReqWait names
    // something in flight, and the caller's very next move on this branch is to re-send the sign-on --
    // which arms that tap. A "basic" toast spawned here is asynchronous, so it would land INSIDE the
    // retry's window and be read back as the server refusing the shift with the words "Bounty settled".
    // The tap tests the type, so any non-basic type is immune; "lottoinfo" is this tree's money toast
    // (dollar-sign icon, 15s), which is what this line is.
    [format ["Bounty settled -- $%1 paid. Your record is clear.", [_paid] call AP_fnc_numberText], "lottoinfo"] spawn AP_fnc_handleMessage;
    diag_log format ["[%1] payoff confirmed: faction=%2 paid=$%3", _tag, _faction, _paid];
    true
};

// REFUSED, or no answer. The server's own refusal line has ALREADY been shown to the player -- the tap in
// fn_handleMessage is a read and not a hook, so nothing was consumed on the way past -- which is why this
// says nothing on that branch and only speaks up when nothing arrived at all.
private _msg = missionNamespace getVariable ["AP_dutyReqErr", ""];
AP_dutyReqErr = "";
// AND IT DOES NOT CLAIM NOTHING WAS CHARGED, because from here that is not knowable. Almost every way
// to reach this branch is a refusal that happened before the bank was touched -- but the server could
// also have debited and then failed on the way to the pardon, and a client that says "nothing was
// charged" would be asserting a fact it cannot see. Retrying is safe either way: a payoff that landed
// cleared the wanted row, so the next one is refused with "no outstanding bounty" rather than charging
// twice, and the `-DUTY- DEBIT` row in `log` is the record if the two ever disagree.
if (_msg isEqualTo "") then {
    ["The terminal did not answer. Check your bank balance before trying again.", "basic"] spawn AP_fnc_handleMessage;
};
diag_log format ["[%1] payoff refused: faction=%2 -- %3", _tag, _faction, if (_msg isEqualTo "") then { "no answer" } else { _msg }];
false
