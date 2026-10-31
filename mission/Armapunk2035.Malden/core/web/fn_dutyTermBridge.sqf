/*
    AP_fnc_dutyTermBridge -- dialog\web_duty_maxsec.hpp (938200) onLoad: wire the MaxSec duty terminal's
    two verbs.

        [_display] spawn AP_fnc_dutyTermBridge;

    THE PAGE DEFINES THE CONTRACT (ui\html\duty_maxsec.html); this file matches it and adds nothing:

        AP.on("duty", { station, officer:{name,rank,scd}, counts:{patrol,warrant,medic,scd,all} })
                                         -> pushed once, at the tail of this file. There is no ready verb:
                                            the page subscribes and waits, and webui.js's on() replays the
                                            last value on a channel, so the push lands whether it arrives
                                            before or after the subscription.
        AP.call("dutyStart", [roleId], cb) -> { ok, err }. ok: the shift is granted and this closes the
                                            screen a beat later. err: the page toasts the line and
                                            re-enables GO.
        AP.call("dutyClose", [])         -> closes the display. The page's own X button and its Esc branch.

    NO LIVE COUNT TICKER, AND THAT IS A CONTRACT DECISION, NOT AN OMISSION. The page's "duty" handler ends
    with `S.armed=false;S.busy=false;render()` -- it treats every push as a fresh boot. A 10s repush loop
    would therefore disarm a player's confirm under their finger and, worse, clear S.busy mid-request so GO
    came back live while a sign-on was still in flight. Counts are a snapshot taken when the screen opens,
    which is what the roster row honestly is.

    ROLE COMES FROM THE PAGE, and that is the whole difference from the landing screen (which sends the
    faction's default role because it has no picker). Three convenience gates run before the send -- the
    role must be one of fn_dutyCfg's maxsec rows, AP_fnc_dutyGate must pass in full, and the row's own
    OFFER filter must pass -- and then AP_fnc_dutyRequest sends the SAME ["request","maxsec",role] that
    fn_dutyTerminal.sqf:81 sends. Every one of those is re-run server-side from the server's own DB read
    and roster (fn_dutySRV.sqf:356-367 is the role table); nothing here is trusted, and there is no new
    CfgRE entry and no new server function.

    THE FULL GATE RE-RUNS AT dutyStart, not just the sign-on half the opener already checked. A terminal
    screen can sit open for minutes; being restrained, downed, arrested or mid-clothing-store between
    opening it and pressing GO is exactly the case the state gates exist for.
*/
params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[DUTYTERM] bridge: null display"; };
disableSerialization;

private _idd = ctrlIDD _display;
private _ctrl = _display displayCtrl (_idd + 1);          // idc is idd + 1 (see web_duty_maxsec.hpp)
if (isNull _ctrl) exitWith { diag_log format ["[DUTYTERM] control %1 missing", _idd + 1]; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[DUTYTERM] bridge init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships without a client repack.
// No-op unless AP_fnc_webServeInit registered a fetcher and the server actually has the file.
[_ctrl, "ui\html\duty_maxsec.html"] call webui_fnc_serve;

[_ctrl, "dutyStart", {
    params [["_role", "", [""]]];
    private _fnc_no = { createHashMapFromArray [["ok", false], ["err", _this]] };
    private _faction = "maxsec";

    private _row = [_faction] call AP_fnc_dutyCfg;
    if (_row isEqualTo []) exitWith { "UNKNOWN FACTION" call _fnc_no };
    private _roles = _row select 7;
    private _i = _roles findIf {(_x select 0) isEqualTo _role};
    if (_i < 0) exitWith { "UNKNOWN DUTY ROLE" call _fnc_no };

    // The terminal's client gates in full -- state AND sign-on, the same predicate and the same wording
    // fn_dutyTerminal and the landing screen use. Uppercased because the page prints err into its toast,
    // which is the designer's letterspaced mono row.
    private _gate = [_faction] call AP_fnc_dutyGate;
    if (_gate isNotEqualTo "") exitWith {
        diag_log format ["[DUTYTERM] start %1 refused locally: %2", _role, _gate];
        (toUpper _gate) call _fnc_no
    };

    // The row's own OFFER filter from fn_dutyCfg -- the predicate fn_dutyTerminal's picker uses to decide
    // what to put in front of the player. Here it is the twin of the page's own row lock, so a verb call
    // that did not come from a click gets the same answer a click would have.
    if !(call ((_roles select _i) select 1)) exitWith {
        diag_log format ["[DUTYTERM] start %1 refused locally: role not offered", _role];
        (format ["YOU ARE NOT CLEARED FOR THE %1 ROLE.", toUpper _role]) call _fnc_no
    };

    private _err = [_faction, _role, "DUTYTERM"] call AP_fnc_dutyRequest;
    // THE BOUNTY REFUSAL GETS A POINTER, AND THE PAGE GETS NO NEW UI. Owner ruling 2026-08-20 lets an
    // officer settle their own bounty at the terminal instead of hunting for a cop to pardon them --
    // but this page cannot express that offer. Its refusal surface is one line, `toast((res&&res.err)||
    // 'DUTY START FAILED')` at duty_maxsec.html:260: a string, shown for a moment, with no button, no
    // second verb and no confirm anywhere in its state machine. Giving it one means editing the
    // designer's markup and its render loop, which is a design change and not ours to make. So the
    // refusal text carries the route instead, and the action it points at is the scroll entry
    // fn_setupActions.sqf hangs on the same tablets (AP_fnc_dutyPayoff).
    // AP_dutyBuyout is the server's own quote, published with that refusal and with no other, so it is
    // also the marker that says WHICH refusal this was -- the page never has to read the English.
    // AP_fnc_dutyRequest has already let it settle before returning.
    if (_err isNotEqualTo "") exitWith {
        if ((round (player getVariable ["AP_dutyBuyout", 0])) > 0) then {
            // The server's own line already ends "Clear it or pay it off."; this adds the WHERE, and
            // says it without repeating the verb, because the page prints the two run together.
            _err = _err + " Use this tablet's scroll menu.";
        };
        (toUpper _err) call _fnc_no
    };

    // GRANTED. Take the screen down, but a beat late: the page toasts "ON DUTY -- <ROLE>" for 2.2s off the
    // back of this answer, and closing in the same frame would swallow the only confirmation the player
    // gets. Guarded on the display still being 938200 so a player who Esc'd during the request -- and has
    // since opened something else -- does not get that dialog closed out from under them instead.
    [] spawn { uiSleep 1.6; if (!isNull (findDisplay 938200)) then { closeDialog 0; }; };
    createHashMapFromArray [["ok", true], ["err", ""]]
}] call webui_fnc_on;

[_ctrl, "dutyClose", {
    if (!isNull (findDisplay 938200)) then { closeDialog 0; };
    createHashMapFromArray [["ok", true], ["err", ""]]
}] call webui_fnc_on;

// NO KeyDown HANDLER, deliberately. Esc reaches the engine, which closes the dialog -- and the page ALSO
// sends dutyClose on Esc, so the two agree. Leaving the engine's default in place is what keeps a deaf
// page (one whose bridge never bound) dismissable instead of trapping the player at the tablet.

// THE BIND SIGNAL. AP_fnc_dutyTermOpen clears this before createDialog and waits on it: a page that
// rendered but never bound is worse than one that never opened, because the shim disarms the designer's
// demo mode -- GO would spin forever with nothing behind it. Set only once every verb above is registered,
// so the flag means "this screen can answer", not "this screen exists".
AP_dutyTermBound = true;

// Same tail push the casino and the landing use: webui_fnc_push queues until the page is up, and webui.js's
// on() replays the last value on a channel, so the page gets this whether it subscribes before or after.
[_ctrl, "duty", ([] call AP_fnc_dutyTermData)] call webui_fnc_push;
diag_log format ["[DUTYTERM] bridge ready t=%1", diag_tickTime toFixed 1];
