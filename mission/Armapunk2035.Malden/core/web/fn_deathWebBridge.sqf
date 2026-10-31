/*
    AP_fnc_deathWebBridge -- dialog\web_death.hpp (938800) onLoad: wire the death page.

        [_display] spawn AP_fnc_deathWebBridge;

    THE PAGE DEFINES THE CONTRACT (ui\html\death.html's header); this matches it:

        deathReady    []        -> answered with the first "death" PUSH, not a return
                                   value. The page discards this call's result.
        deathRequest  []        -> { ok, msg }. Pages Trauma Team. Called only after
                                   the page's own inline confirmation.
        deathAllow    []        -> { ok, msg }. Revivable, pages nobody.
        deathRespawn  []        -> { ok, msg }. Manual respawn, after confirmation.

    NOTHING NEW IS AUTHORISED. Both medical verbs are AP_fnc_deathWebMedical, which
    is fn_deathScreenMedicalButtonClick's work with the engine confirmation and the
    native control writes removed (its header lists every decision). Respawn is
    AP_fnc_doRespawn, the SAME function the automatic bleedout respawn already calls.

    WHY RESPAWN GOES THROUGH doRespawn AND NOT THE NATIVE BUTTON'S ONE-LINER. The
    native button is `closeDialog 0; AP_respawned = true; [] spawn AP_fnc_spawnMenu`,
    which skips two things fn_doRespawn does and the automatic path therefore always
    did: it flags the abandoned body AP_respawnedOrphan so fn_cleanup can reap it
    (without the flag the corpse sits for the full ~31 min immunity window, which is
    what that flag exists to prevent -- see fn_doRespawn's own note), and it tells
    every responding medic to stand down via AP_fnc_medicRespondDone. A player who
    pressed the button left a medic walking to a body that was never coming back.
    One path, the complete one, for both manual and automatic respawn.

    NO DOUBLE RESPAWN. fn_doRespawn sets AP_respawned, and fn_onPlayerKilled's
    bleedout loop exits on AP_respawned and then runs its own respawn only
    `if (!AP_respawned)`. So the manual route ends the loop and the loop declines to
    repeat it. The verb also re-checks the stage, so a click that arrives before the
    first timer expired is refused rather than respawning early.

    THE PUSH IS 1 Hz, the same cadence AP_fnc_deathScreen uses to refresh the native
    dialog's medic counts, and it dies with the display. The page interpolates the
    clock between pushes; every push overwrites it.

    A VERB MUST RETURN IMMEDIATELY. It runs inside the JSDialog handler, which is an
    alert() -- the browser is blocked until it returns (core\web\README.md). Both
    medical verbs are unscheduled-safe. Respawn is `spawn`ed because fn_doRespawn
    ends in AP_fnc_spawnMenu, which blocks on the player for as long as they take to
    pick a spawn point.
*/
params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[DEATHWEB] bridge: null display"; };
disableSerialization;

private _ctrl = _display displayCtrl 938801;          // idc is idd + 1
if (isNull _ctrl) exitWith { diag_log "[DEATHWEB] bridge: control 938801 missing"; };
if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[DEATHWEB] bridge: init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher.
[_ctrl, "ui\html\death.html"] call webui_fnc_serve;

[_ctrl, "deathReady", {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "death", ([] call AP_fnc_deathState)] call webui_fnc_push; };
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "deathRequest", {
    ([true] call AP_fnc_deathWebMedical) params ["_ok", "_msg"];
    diag_log format ["[DEATHWEB] request ok=%1 (%2)", _ok, _msg];
    createHashMapFromArray [["ok", _ok], ["msg", _msg]]
}] call webui_fnc_on;

[_ctrl, "deathAllow", {
    ([false] call AP_fnc_deathWebMedical) params ["_ok", "_msg"];
    diag_log format ["[DEATHWEB] allow ok=%1 (%2)", _ok, _msg];
    createHashMapFromArray [["ok", _ok], ["msg", _msg]]
}] call webui_fnc_on;

[_ctrl, "deathRespawn", {
    // Re-checked here, not trusted from the page: the first timer is what locks
    // respawn and a click can arrive from a page that has not yet had the push
    // telling it so.
    if !((missionNamespace getVariable ["AP_deathStage", "lock"]) isEqualTo "bleed") exitWith {
        createHashMapFromArray [["ok", false], ["msg", "RESPAWN NOT AVAILABLE YET"]]
    };
    if (AP_respawned) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "ALREADY RESPAWNING"]]
    };
    diag_log "[DEATHWEB] respawn (manual)";
    // fn_doRespawn ends in AP_fnc_spawnMenu, which blocks until the player picks a
    // spawn point, so this cannot run inside the blocked JSDialog handler.
    [] spawn AP_fnc_doRespawn;
    createHashMapFromArray [["ok", true], ["msg", "LEAVING THE BODY"]]
}] call webui_fnc_on;

// The 1 Hz push. Dies with the display; never outlives it.
[_ctrl] spawn {
    params ["_c"];
    while { !isNull (findDisplay 938800) } do {
        uiSleep 1;
        if (isNull (findDisplay 938800)) exitWith {};
        [_c, "death", ([] call AP_fnc_deathState)] call webui_fnc_push;
    };
    diag_log "[DEATHWEB] push loop ended with the display";
};
