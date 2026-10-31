/*
    AP_fnc_deathWebOpen -- take the death screen with ui\html\death.html (938800), or decline.

        AP_deathWeb = [] call AP_fnc_deathWebOpen;
        if (!AP_deathWeb) then { createDialog "DeathScreen"; ... };   // fn_onPlayerKilled

    Returns TRUE when the web screen is up and the caller must NOT create the native
    dialog. Returns FALSE for every failure, and the caller then opens dialog 7300
    exactly as it always has. Unlike the spawn screen's opener this does NOT block:
    fn_onPlayerKilled owns both death clocks and must keep running them whichever
    screen is drawing, so this returns the moment the display exists.

    IT DOES NOT CLOSE AN OPEN DIALOG FIRST. fn_onPlayerKilled has already waited for
    `!dialog` before calling this -- that wait is what stops a shop or inventory
    screen swallowing the death dialog -- and closing something here would race it.

    ESCAPE IS BLOCKED THE SAME WAY THE NATIVE SCREEN BLOCKS IT: a KeyDown handler on
    the DISPLAY that swallows DIK 1. core\web\README.md says not to build a
    page-level Esc handler because Esc closes a web dialog, and that is exactly the
    behaviour being suppressed here -- a player must not be able to dismiss the
    death screen and stand in a dead body with no UI. The handler is on the display,
    not in the page, so it cannot be disabled by anything the page does.
    UNVERIFIED IN GAME AT THE TIME OF WRITING: whether a display-level KeyDown fires
    while a type-106 browser control holds focus. If it does not, Esc closes this
    dialog and fn_onPlayerKilled's loops keep running with no screen -- the clocks,
    the auto-respawn and the revive path all still work, so the failure mode is a
    missing screen, not a stuck player. Verify it before this is considered done.

    THE KILL SWITCH is SRV_deathWebEnabled, server-owned and publicVariable'd, read
    through a getVariable default of true so a client that has not received the
    publish behaves like one that has. False = dialog 7300 and the native flow, with
    no repack and nothing else to unwind.
*/
if (isDedicated || {!hasInterface}) exitWith { false };
// The bounded wait below suspends. fn_onPlayerKilled calls this from its spawned
// screen thread so this always holds; an unscheduled caller declines to the native
// dialog rather than throwing inside a death handler.
if (!canSuspend) exitWith {
    diag_log "[DEATHWEB] open: unscheduled caller -- native death screen";
    false
};

if !(missionNamespace getVariable ["SRV_deathWebEnabled", true]) exitWith {
    diag_log "[DEATHWEB] open: SRV_deathWebEnabled is false -- native death screen";
    false
};
if (isNil "webui_fnc_init") exitWith {
    diag_log "[DEATHWEB] open: the webui library is not loaded -- native death screen";
    false
};

if !(createDialog "AP_web_death") exitWith {
    diag_log "[DEATHWEB] open: createDialog AP_web_death failed -- native death screen";
    false
};
// createDialog returns before the display exists. Bounded wait, same shape as
// AP_fnc_landingOpen's and AP_fnc_spawnWebOpen's: fn_onPlayerKilled calls this from
// a spawned thread, so suspending here is legal, and 3 s is far longer than the
// engine has ever taken while still being a bounded failure rather than a hang on a
// screen the player cannot escape from.
private _up = diag_tickTime + 3;
waitUntil { uiSleep 0.05; !isNull (findDisplay 938800) || {diag_tickTime > _up} };
if (isNull (findDisplay 938800)) exitWith {
    diag_log "[DEATHWEB] open: display 938800 never appeared in 3s -- native death screen";
    false
};

(findDisplay 938800) displaySetEventHandler ["KeyDown", "(_this select 1) isEqualTo 1"];
diag_log "[DEATHWEB] open: display up";
true
