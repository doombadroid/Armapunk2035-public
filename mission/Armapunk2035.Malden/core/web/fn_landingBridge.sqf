/*
    AP_fnc_landingBridge -- dialog\web_landing.hpp (938100) onLoad: wire the landing page's three verbs.

        [_display] spawn AP_fnc_landingBridge;

    THE PAGE DEFINES THE CONTRACT (ui\html\landing.html's header); this file matches it and adds nothing:

        landingReady  []                 -> answered with the first "landing" PUSH, not a return value.
                                            The page discards this call's result on purpose.
        landingDeploy ["solo"|"maxsec"|"trauma"] -> { ok, err }.  ok: SQF closes the display and the login
                                            flow carries on.  err: the page prints the line under the deploy
                                            bar and re-enables DEPLOY.

    NOTHING NEW IS AUTHORISED HERE. "solo" changes no state at all -- it just records the pick and lets
    fn_initCiv resume the flow it would have run anyway. "maxsec"/"trauma" re-run AP_fnc_dutyGate (the HQ
    terminal's own client gates, factored out so the two cannot drift) and then send the SAME
    ["request", faction, role] to APS_fnc_dutySRV that fn_dutyTerminal.sqf:118 sends. No new CfgRE entry, no
    new server function, and no path by which the page can grant itself a shift: the server re-runs every
    gate from its own DB read and the roster, and the only thing that can move AP_effSide is the server's
    push into AP_fnc_dutyClient.

    ROLE IS THE FACTION'S DEFAULT, NOT A PICK. patrol / ttmedic are the two rows in fn_dutyCfg's role list
    whose gate is {true}, i.e. the one every whitelisted member can take. Role refinement (warrant / medic /
    scd / all) stays at the HQ terminal, which is where the player can also read what they are choosing.

    CORRELATING THE ANSWER IS THE WHOLE PROBLEM, and as of PR11 the answer to it lives in ONE place:
    AP_fnc_dutyRequest. A duty request is fire-and-forget -- the grant comes back as a server push into
    AP_fnc_dutyClient and a refusal comes back as a server push into AP_fnc_handleMessage, neither of which
    knows a page is waiting -- so that function arms fn_handleMessage's refusal tap, sends, polls both halves
    under one bounded deadline, and answers "" for a grant or the refusal line for anything else. It was this
    file's landingDeploy body verbatim; the MaxSec duty terminal page now runs the same dance with a
    different role id, and a second copy of it would be exactly the drift AP_fnc_dutyGate exists to prevent.
*/
params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[LANDING] bridge: null display"; };
disableSerialization;

private _idd = ctrlIDD _display;
private _ctrl = _display displayCtrl (_idd + 1);          // idc is idd + 1 (see web_landing.hpp)
if (isNull _ctrl) exitWith { diag_log format ["[LANDING] control %1 missing", _idd + 1]; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[LANDING] bridge init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships without a client repack.
// No-op unless AP_fnc_webServeInit registered a fetcher and the server actually has the file.
[_ctrl, "ui\html\landing.html"] call webui_fnc_serve;

// The page fires this once on boot and throws the result away -- the answer is the push.
[_ctrl, "landingReady", {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "landing", ([] call AP_fnc_landingData)] call webui_fnc_push; };
    createHashMapFromArray [["ok", true], ["err", ""]]
}] call webui_fnc_on;

[_ctrl, "landingDeploy", {
    params [["_id", "", [""]]];
    private _fnc_no = { createHashMapFromArray [["ok", false], ["err", _this]] };

    if !(_id in ["solo", "maxsec", "trauma"]) exitWith { "UNKNOWN DEPLOYMENT" call _fnc_no };

    // ONE REQUEST AT A TIME is enforced inside AP_fnc_dutyRequest now, against the shared AP_dutyReqWait
    // slot, so it covers both web pages rather than just this one. The page's own state.deploying already
    // blocks a second click; that check is for anything that can talk to a bridge without going through a
    // page. It costs an ordering change here and nothing else: the gate below now runs FIRST, so a click
    // arriving while a request is in flight gets the gate's own reason (usually the better one -- "You are
    // already on duty with this faction" once the grant has landed) rather than the in-flight line.

    // SOLO CHANGES NOTHING. fn_landingOpen sees the pick, closes the display, and fn_initCiv resumes at the
    // exact branch it would have taken before the landing interposed -- relog teleport, spawn menu or jail.
    if (_id isEqualTo "solo") exitWith {
        AP_landingPick = "solo";
        diag_log "[LANDING] deploy solo";
        createHashMapFromArray [["ok", true], ["err", ""]]
    };

    // The terminal's client gates, verbatim, via the shared predicate.
    private _gate = [_id] call AP_fnc_dutyGate;
    if (_gate isNotEqualTo "") exitWith {
        diag_log format ["[LANDING] deploy %1 refused locally: %2", _id, _gate];
        (toUpper _gate) call _fnc_no
    };

    private _role = if (_id isEqualTo "maxsec") then { "patrol" } else { "ttmedic" };

    // THE SEND, THE TAP AND THE 15s CORRELATION ARE AP_fnc_dutyRequest (PR11) -- this file's own body,
    // moved out whole so the MaxSec terminal page runs one copy of it instead of a second. "" is a granted
    // shift; anything else is the exact line to put under the deploy bar. It blocks, which is why the
    // handler blocks, which is the whole reason landingDeploy is a suspending verb.
    private _err = [_id, _role, "LANDING"] call AP_fnc_dutyRequest;
    if (_err isEqualTo "") exitWith {
        AP_landingPick = _id;
        diag_log format ["[LANDING] deploy %1 granted", _id];
        createHashMapFromArray [["ok", true], ["err", ""]]
    };
    diag_log format ["[LANDING] deploy %1 refused: %2", _id, _err];
    (toUpper _err) call _fnc_no
}] call webui_fnc_on;

// NO KeyDown HANDLER, deliberately -- see fn_landingOpen's ESC note. Esc must reach the engine's default
// (close the dialog), because that is the fallback that keeps a player from being stranded pre-spawn.

// Same tail push the casino uses: webui_fnc_push queues until the page is up, and webui.js's on() replays
// the last value on a channel, so the page gets this whether it subscribes before or after it lands.
[_ctrl, "landing", ([] call AP_fnc_landingData)] call webui_fnc_push;
diag_log format ["[LANDING] bridge ready t=%1", diag_tickTime toFixed 1];
