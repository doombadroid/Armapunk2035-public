/*
    AP_fnc_dutyRequest -- send ONE ["request", faction, role] to APS_fnc_dutySRV and BLOCK until the answer
    can be attributed to it. Returns "" when the shift was granted, otherwise the refusal line to show.

        private _err = ["maxsec", "patrol", "DUTYTERM"] call AP_fnc_dutyRequest;

    THIS MUST RUN SCHEDULED -- it suspends. Both callers are webui verb handlers, which fn_init.sqf:178
    `spawn`s, so both arrive scheduled; an unscheduled arrival is refused rather than self-respawned,
    because a re-spawned copy could not hand its answer back to the page that is waiting for it.

    WHY IT EXISTS. It was fn_landingBridge's landingDeploy body (PR9), and it is the most subtle code in the
    duty tree: three interacting deadlines, a tap that has to be armed before the send, a stamped self-heal,
    and an ordering rule that decides whether a granted shift can be reported as a refusal. The MaxSec duty
    terminal page (PR11) needs exactly the same dance with a different role id, and a second copy of this
    would be the drift AP_fnc_dutyGate was factored out to prevent. One copy, two callers, same wording.

    CORRELATING THE ANSWER IS THE WHOLE PROBLEM. A duty request is fire-and-forget: the GRANT comes back as
    a server push into AP_fnc_dutyClient and a REFUSAL comes back as a server push into
    AP_fnc_handleMessage, neither of which knows a page is waiting. fn_casino.sqf:42-50 is this tree's idiom
    for the grant half (read the outcome off the client state the push wrote, mirror it to the page) -- the
    refusal half has no state to read, so fn_handleMessage.sqf carries a four-line tap that copies the
    refusal text into AP_dutyReqErr while, and only while, AP_dutyReqWait names a request in flight. Both
    halves are polled below under one bounded deadline, so a refusal that never arrives at all
    (APS_fnc_dutySRV has three refusal paths that deliberately send no message, plus a silent request
    throttle) still answers the page instead of leaving its button stuck mid-spinner.

    THE THREE SLOTS ARE SHARED CLIENT STATE, NOT PER-PAGE STATE, and the rename from AP_landingWait /
    AP_landingErr / AP_landingWaitAt is the whole of that change: the tap's condition, the self-heal and the
    poll are byte-for-byte the landing's. One request at a time per client is enforced below rather than
    per-caller, which is what makes one pair of slots correct.

    NOTHING NEW IS AUTHORISED HERE. This sends the SAME ["request", faction, role] that
    fn_dutyTerminal.sqf:81 sends. No new CfgRE entry, no new server function, and no path by which a page can
    grant itself a shift: APS_fnc_dutySRV re-runs every gate from its own DB read and its own roster
    (including the per-role table at fn_dutySRV.sqf:356-367), and the only thing that can move AP_effSide is
    the server's push into AP_fnc_dutyClient.
*/
params [["_faction", "", [""]], ["_role", "", [""]], ["_tag", "DUTY", [""]]];
if (!canSuspend) exitWith {
    diag_log format ["[%1] request: unscheduled caller -- refusing", _tag];
    "This terminal cannot reach the server right now. Try again."
};
if (_faction isEqualTo "" || {_role isEqualTo ""}) exitWith { "Unknown faction or role." };

// One request at a time. Each page's own busy state already blocks a second click, so this is for anything
// that can talk to a bridge without going through the page -- and for the two pages reaching the bridge in
// the same session, which is why the slots are shared rather than per-caller.
if ((missionNamespace getVariable ["AP_dutyReqWait", ""]) isNotEqualTo "") exitWith {
    "A duty request is already in flight."
};

// ARM THE TAP, THEN SEND -- never the other way round. A refusal can be back inside the same frame the send
// returns on (every gate above the first DB read in APS_fnc_dutySRV's "request" is in-memory), so arming
// afterwards is a race the page loses by hanging.
AP_dutyReqErr = "";
AP_dutyReqWait = _faction;
// THE BUYOUT QUOTE IS PART OF THE ANSWER, so it is seeded with the rest of the tap. AP_dutyBuyout is
// what APS_fnc_dutySRV publishes on this unit when it refuses a MaxSec sign-on for an outstanding
// bounty -- the price it would charge to settle it -- and it is the marker every caller keys on to
// decide whether a buyout is on the table (fn_dutyTerminal offers it, fn_dutyTermBridge points at the
// scroll menu). Seeded LOCAL (two-element setVariable, no broadcast) so a quote left over from an
// earlier refusal can never be read as this one's.
player setVariable ["AP_dutyBuyout", 0];
// Stamped self-heal, the same shape and the same reason as fn_dutyClient's swap guard: SQF has no
// `finally`, so a runtime error anywhere between here and the clear below would leave the tap in
// fn_handleMessage armed for the rest of the session. The stamp is what makes the timer safe -- a later
// attempt that is still running when an earlier attempt's timer fires is protected because the stamp no
// longer matches. 20s, comfortably past this function's own 15s deadline.
AP_dutyReqAt = diag_tickTime;
[AP_dutyReqAt, _tag] spawn {
    params ["_t0", "_tag"];
    uiSleep 20;
    if ((missionNamespace getVariable ["AP_dutyReqWait", ""]) isNotEqualTo ""
        && {(missionNamespace getVariable ["AP_dutyReqAt", 0]) isEqualTo _t0}) then {
        AP_dutyReqWait = "";
        diag_log format ["[%1] request: wait self-cleared 20s after the request that set it (t0 %2)", _tag, _t0];
    };
};
[["request", _faction, _role], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
diag_log format ["[%1] request sent: faction=%2 role=%3", _tag, _faction, _role];

// 15s. Each page's own promise gives up at 20s (the shim's timeout), APS_fnc_dutySRV's grant watchdog rolls
// an unacked grant back at 10s, and the request itself is up to three round-trips through the serialized
// extDB3 mutex -- so this sits above the watchdog and below the page.
private _deadline = diag_tickTime + 15;
private _fnc_granted = {
    (missionNamespace getVariable ["AP_onDuty", false])
    && {(missionNamespace getVariable ["AP_dutyFaction", ""]) isEqualTo _faction}
};
waitUntil {
    uiSleep 0.2;
    (call _fnc_granted)
    || {(missionNamespace getVariable ["AP_dutyReqErr", ""]) isNotEqualTo ""}
    || {diag_tickTime > _deadline}
};
AP_dutyReqWait = "";

// SUCCESS IS TESTED FIRST, and that ordering is load-bearing: AP_fnc_dutyClient's apply sets AP_onDuty at
// :276 and then messages "You are on duty: ..." at :335, which the tap would happily copy into
// AP_dutyReqErr. Reading the grant first means a granted shift can never be reported as a refusal.
if (call _fnc_granted) exitWith {
    diag_log format ["[%1] request granted: faction=%2 role=%3", _tag, _faction, _role];
    ""
};

// LET THE QUOTE SETTLE BEFORE ANSWERING, but only for someone it can possibly apply to. The server
// publishes AP_dutyBuyout immediately BEFORE it sends the refusal, but a public setVariable and a
// remoteExec'd message are two different transports and nothing guarantees they land in that order --
// so a caller that read the slot the instant this returned could miss a quote by a frame and offer no
// buyout at all. Bounded at 1s, and entered ONLY when this client already believes it is wanted
// (AP_wantedAmt is the offender's own published figure, set by AP_fnc_wantedListAdd), so no other
// refusal -- cooldown, whitelist, roster -- pays anything for it.
if ((player getVariable ["AP_wantedAmt", 0]) > 0 && {(player getVariable ["AP_dutyBuyout", 0]) <= 0}) then {
    private _qd = diag_tickTime + 1;
    waitUntil { uiSleep 0.1; (player getVariable ["AP_dutyBuyout", 0]) > 0 || {diag_tickTime > _qd} };
};

private _msg = missionNamespace getVariable ["AP_dutyReqErr", ""];
if (_msg isEqualTo "") then { _msg = "No answer from the server -- try again" };
AP_dutyReqErr = "";
diag_log format ["[%1] request refused: faction=%2 role=%3 -- %4", _tag, _faction, _role, _msg];
_msg
