/*
    AP_fnc_dutyGate -- the CLIENT-side "may this player change duty status right now" predicate, factored
    out of fn_dutyTerminal so the HQ terminal and the landing screen cannot drift apart.

        ["", "state"]         call AP_fnc_dutyGate    the gates BOTH directions share  (terminal)
        ["maxsec", "signon"]  call AP_fnc_dutyGate    the rest of the way IN           (terminal)
        ["maxsec"]            call AP_fnc_dutyGate    both, in order                   (landing)

    Returns "" when clear, otherwise the exact refusal line to show the player. It only reads state -- it
    never messages, never sends, never mutates anything except the three nil seeds every duty entry point
    already does.

    EVERY CHECK HERE IS CONVENIENCE, unchanged from fn_dutyTerminal's header: APS_fnc_dutySRV re-runs all of
    them from the server's own DB read and its own roster, and it is the only thing that can actually put
    someone on duty. Nothing here is trusted; it exists so a refusal comes back instantly with a reason
    instead of as silence.

    WHY THREE STAGES AND NOT ONE PREDICATE. fn_dutyTerminal's header records an ordering rule that is
    load-bearing and was once wrong: THE STATE GATES RUN BEFORE THE ON/OFF BRANCH, NOT AFTER IT, so the
    clock-OFF path is gated too (it is also a persist + a side change). A single all-in-one predicate would
    have to place the AP_onDuty test somewhere, and either placement breaks one of the two callers -- before
    the state gates it un-gates clock-off again, after them it refuses the terminal's own clock-off. So the
    shared half is its own stage, the terminal keeps its branch between the two, and a caller with no
    clock-off branch (the landing) asks for both at once.

    THE STATE GATES ARE NOT DEAD WEIGHT AT THE LANDING, even though a player at connect is alive, unbound
    and out of combat: AP_is_arrested is loaded from the DB before the landing opens, and a jailed player
    used to be exactly the case the server did not re-check. APS_fnc_dutySRV's "request" now re-checks
    arrest too (it tests alive / civilian / restrained / roster / cooldown / wanted / whitelist / arrested),
    so this is convenience, not the only lock, the same as the other checks above -- but it is still the
    fast one: fn_landingOpen declines outright for a jailed account so the screen never appears, and this
    catches it just as fast at an HQ terminal instead.
*/
params [["_faction", "", [""]], ["_stage", "all", [""]]];

if (isNil "AP_onDuty") then { AP_onDuty = false; };
if (isNil "AP_dutyFaction") then { AP_dutyFaction = ""; };
if (isNil "AP_dutySwapGuard") then { AP_dutySwapGuard = false; };

private _fnc_state = {
    if (AP_dutySwapGuard) exitWith { "Your duty status is still changing. Give it a second." };

    if (!alive player || AP_isDead || AP_isDowned || {player getVariable ["AP_downed", false]}) exitWith {
        "You cannot change duty status in this state."
    };
    if (player getVariable ["AP_restrained", false]) exitWith { "You are restrained." };
    if (player getVariable ["AP_blinded", false]) exitWith { "You cannot see the terminal." };
    if (player getVariable ["AP_escorting", false] || {!isNull AP_escort}) exitWith {
        "Not while you are escorting or being escorted."
    };
    if ((AP_is_arrested param [0, 0]) isEqualTo 1) exitWith { "You are serving a sentence." };
    if (AP_inEvent) exitWith { "Not during an event." };
    if (AP_isActiveFirefighter) exitWith { "Finish your firefighting callout first." };
    if (AP_activeMAXTAC) exitWith { "Stand down from MaxTac first." };
    // The rest of the persist blockers (broken firing pin, an open clothing store, an evidence spawn) in one
    // shared predicate -- see fn_dutyFlushBlock.sqf. A swap started in any of them silently persists nothing.
    private _blocked = call AP_fnc_dutyFlushBlock;
    if (_blocked isNotEqualTo "") exitWith {
        format ["Your kit cannot be saved right now (%1). Try again after.", _blocked]
    };
    ""
};

private _fnc_signOn = {
    if !(missionNamespace getVariable ["AP_dutyEnabled", false]) exitWith { "The duty system is offline." };
    private _row = [_faction] call AP_fnc_dutyCfg;
    if (_row isEqualTo []) exitWith { "Unknown faction." };

    // On duty ELSEWHERE -> refuse; one faction at a time. The terminal reaches this stage only with
    // AP_onDuty false (its own clock-off branch sits above the call), so this line is the LANDING's --
    // where there is no clock-off to offer and being on duty at all means the pick is not available.
    if (AP_onDuty) exitWith {
        if (AP_dutyFaction isEqualTo _faction) then { "You are already on duty with this faction." }
        else { format ["You are on duty with %1. Clock off there first.", toUpper AP_dutyFaction] }
    };

    if !(AP_effSide isEqualTo civilian) exitWith { "Only a civilian can sign on for a duty shift." };

    // Whitelist mirror of the two lobby gates PR7 deleted: maxsec = any cop rank OR any admin level, trauma =
    // a real mediclevel. Trauma drops the volunteer sentinel those gates carried -- 99 was injected at login for
    // a non-whitelisted player who took a medic SLOT, and with no slots left nothing produces it any more; the
    // test stays because 99 is still a legal DB value. The server enforces the same rule from
    // players_global.mediclevel.
    private _allowed = switch (_row select 0) do {
        case "maxsec": { ((call AP_copLevel) >= 1) || ((call AP_adminLevel) >= 1) };
        case "trauma": { ((call AP_medicLevel) >= 1) && {(call AP_medicLevel) != 99} };
        default { false };
    };
    if (!_allowed) exitWith { "You are not on this faction's roster. Contact a supervisor." };
    ""
};

// No `exitWith` inside a case body, deliberately: that is this repo's PHANTOM-ELSE class (fn_dutySRV.sqf's
// cooldown comment), and the value a switch returns is the value of the case block it ran. if..then..else
// says the same thing with no scope question at all.
private _out = switch (toLower _stage) do {
    case "state":  { call _fnc_state };
    case "signon": { call _fnc_signOn };
    default {
        private _s = call _fnc_state;
        if (_s isEqualTo "") then { call _fnc_signOn } else { _s }
    };
};
// A switch whose default cannot be reached still returns nil in SQF if no case matched and there is no
// default; there IS one here, so this is a belt on a brace -- but a nil leaking out of a predicate whose
// whole contract is "" or a reason would read as "clear" at every call site.
if (isNil "_out") then { _out = "" };
_out
