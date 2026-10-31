/*
    AP_fnc_dutyTerminal -- the player-facing end of the duty system: the HQ terminal action body.

        ["maxsec"] spawn AP_fnc_dutyTerminal

    Every check here is CONVENIENCE. APS_fnc_dutySRV re-runs all of them from the server's own DB read and
    its own roster, and it is the only thing that can actually put someone on duty. Nothing in this file is
    trusted; it exists so a refusal comes back instantly with a reason instead of as silence.

    THE GATE LIST LIVES IN AP_fnc_dutyGate (PR9). It is called here in two pieces, either side of the on/off
    branch, for the ordering reason spelled out below; the landing screen calls it in one. Same checks, same
    order, same wording -- one copy.

    Clocking off is the same action: standing at your own faction's terminal while on duty turns the request
    into a release. That keeps one scroll entry per HQ instead of two, and it means the off-ramp is always
    exactly where the on-ramp was.

    THE STATE GATES RUN BEFORE THE ON/OFF BRANCH, NOT AFTER IT. They used to sit below it, so the clock-OFF
    path reached the server having checked nothing at all -- restrained, blindfolded, being escorted, jailed,
    mid-event, and (worst) mid-clothing-store or with a broken firing pin, which is the state where the duty
    save silently no-ops and the shift's kit is lost on the way out. Both directions are a persist + a side
    change; both need the same preconditions.

    ROLE PICKER. There is no generic list-select helper in this tree (core\functions has only fn_inputMenu,
    a free-text box, and every list UI is a bespoke dialog with its own idd). Rather than add a 106th dialog
    for what was then a feature shipping dark, this chains BIS_fnc_GUIMessage in offer order -- the same pattern
    fn_medicFireClient.sqf's "toggleFirefighter" uses for its own duty-state confirmation, which is the
    closest thing in the codebase to this prompt. A single eligible role skips the prompt entirely, so the
    common case is one click. A proper picker can replace this without touching anything else.
*/
if (!canSuspend) exitWith { _this spawn AP_fnc_dutyTerminal; };
if !(missionNamespace getVariable ["AP_dutyEnabled", false]) exitWith {};

params [["_faction", "", [""]]];
private _row = [_faction] call AP_fnc_dutyCfg;
if (_row isEqualTo []) exitWith {};

// --- state gates, applied to BOTH directions ---------------------------------------------------------
// The list itself moved to AP_fnc_dutyGate (PR9) so the landing screen runs the SAME gates rather than a
// second copy of them; the three nil seeds moved with it. Nothing here changed shape: "state" is exactly
// the block that used to sit between the swap guard and the on/off branch, in the same order, returning
// each refusal's own line instead of spawning it.
private _gate = ["", "state"] call AP_fnc_dutyGate;
if (_gate isNotEqualTo "") exitWith {
    [_gate, "basic"] spawn AP_fnc_handleMessage;
};

// On duty HERE -> this is the clock-off request. On duty ELSEWHERE -> refuse; one faction at a time.
if (AP_onDuty) exitWith {
    if (AP_dutyFaction isEqualTo _faction) then {
        [["release"], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP;
    } else {
        [format ["You are on duty with %1. Clock off there first.", toUpper AP_dutyFaction], "basic"] spawn AP_fnc_handleMessage;
    };
};

// Side + whitelist, the rest of the way IN. Same move as the state gates above: the block lives in
// AP_fnc_dutyGate ("signon") now, unchanged, so the landing screen and this terminal cannot drift.
private _signOn = [_faction, "signon"] call AP_fnc_dutyGate;
if (_signOn isNotEqualTo "") exitWith {
    [_signOn, "basic"] spawn AP_fnc_handleMessage;
};

private _roles = (_row select 7) select { call (_x select 1) };
if (_roles isEqualTo []) exitWith {
    ["No duty role is open to you at your current standing.", "basic"] spawn AP_fnc_handleMessage;
};

private _roleId = "";
if ((count _roles) isEqualTo 1) then {
    _roleId = (_roles select 0) select 0;
} else {
    {
        private _rid = _x select 0;
        private _ok = [format ["Sign on as %1?", toUpper _rid], format ["%1 Duty Terminal", toUpper _faction], "Yes", "No"] call BIS_fnc_GUIMessage;
        if (_ok) exitWith { _roleId = _rid; };
    } forEach _roles;
};
if (_roleId isEqualTo "") exitWith {};

// THE SEND GOES THROUGH AP_fnc_dutyRequest NOW, and the reason is the bounty buyout below. This used to
// be a bare fire-and-forget `[["request", _faction, _roleId], "APS_fnc_dutySRV", 2] spawn AP_fnc_MP` plus
// a "Request sent. Stand by." line, which is fine right up until the picker needs to KNOW whether the
// server said no and why -- and correlating a fire-and-forget duty request is the exact problem
// AP_fnc_dutyRequest already solves for the landing screen and the web terminal. Same payload, same
// wording, same gates; the only difference is that this path now waits for the answer instead of walking
// away from it.
// "Request sent. Stand by." IS BACK, review minor, AS "shortwarning" AND NOT "basic". Dropping it left a
// several-second wait with nothing on screen; re-adding it verbatim would have reopened the exact race it
// was pulled for, because this line runs right as the call below arms fn_handleMessage's refusal tap,
// which copies the FIRST "basic" message to arrive while a request is in flight and treats it as the
// server's answer. "shortwarning" is a different _type, so the tap's own
// `(toLower _type) isEqualTo "basic"` clause never matches it, independent of timing -- the same dodge
// fn_dutyPayoff.sqf already uses twice (its own "in flight" notice and its "Bounty settled" toast).
["Request sent. Stand by.", "shortwarning"] spawn AP_fnc_handleMessage;
private _err = [_faction, _roleId, "DUTYSCROLL"] call AP_fnc_dutyRequest;
if (_err isEqualTo "") exitWith {};   // granted -- AP_fnc_dutyClient's apply has already said so

// REFUSED. The server's own line is already on screen (fn_handleMessage's tap is a read, not a hook, so
// nothing was consumed on the way past), so nothing is re-shown here.
// THE BOUNTY REFUSAL IS THE ONE THAT HAS A SECOND MOVE. Owner ruling 2026-08-20: an officer with an
// outstanding bounty may settle it at the terminal rather than go and find another cop willing to pardon
// them. AP_dutyBuyout is the SERVER's quote, published on this unit with that refusal and with no other
// -- so it is both the marker that says "this refusal was the wanted one" and the number to put in front
// of the player. AP_fnc_dutyPayoff owns the confirm and the spend.
if ((round (player getVariable ["AP_dutyBuyout", 0])) <= 0) exitWith {};
if !([_faction, "DUTYSCROLL"] call AP_fnc_dutyPayoff) exitWith {};

// PAID. ONE retry, never a loop: the payoff cleared the wanted state through APS_fnc_wantedPardon, so the
// gate that refused this sign-on cannot refuse it again -- and if something else does (a cooldown that
// started ticking, a whitelist read that failed), the player sees that refusal and the terminal is still
// right there. A retry that re-entered on its own refusal would be a spend loop.
private _err2 = [_faction, _roleId, "DUTYSCROLL-RETRY"] call AP_fnc_dutyRequest;
if (_err2 isNotEqualTo "") then {
    diag_log format ["[DUTYSCROLL] sign-on still refused after a paid buyout: faction=%1 role=%2 -- %3", _faction, _roleId, _err2];
};
