/*
    AP_fnc_spawnWebOpen -- take the spawn screen with ui\html\spawn.html (dialog 938700), or decline.

        if ([_isRedeploy] call AP_fnc_spawnWebOpen) exitWith {};   // it took the screen and has finished
        // ...native dialog 38500 as before

    Returns TRUE when it took the screen AND has already blocked until the player deployed. Returns
    FALSE when it declined or when the player dismissed the screen without deploying -- in both cases
    the caller opens the native menu exactly as it always did. Every decline is a fall-through, never
    a dead end: a player who cannot see this screen must still be able to spawn.

    IT MUST RUN SCHEDULED, for the same reason AP_fnc_landingOpen must: it blocks on the player. An
    unscheduled caller is declined rather than re-spawned, because a re-spawned copy could not hand
    its answer back to a caller that has already moved on to the native dialog.

    WHY "DISMISSED WITHOUT DEPLOYING" FALLS THROUGH INSTEAD OF REOPENING. On the first-spawn path the
    player is frozen at map centre at 50 km (fn_spawnMenu's hold), so a closed screen with nothing
    behind it is a stranded session until initPlayerLocal's watchdog rescues them 120 s later. Handing
    the screen to the native menu costs one dialog and strands nobody. On the redeploy path they are
    standing in the world and the native menu is equally harmless.

    THE LOADING LAYER IS CUT, and only once the display is actually up. fn_spawnMenu cuts
    AP_loadingScreen immediately before calling this, and the page carries its own WAKE PROTOCOL
    overlay, so leaving the layer up would mean two loading screens racing -- and native controls do
    not composite above a browser surface (core\web\README.md), so which one the player sees is not
    something this code gets to decide. Cutting it after the display exists means a decline leaves the
    layer exactly as it found it.

    THE WATCHDOG KNOWS ABOUT THIS DISPLAY. initPlayerLocal.sqf's spawn-hold backstop treats "display
    38500 is open" as "the player is deliberately picking a spawn" and rescues them to a spawn point
    after 120 s otherwise. 938700 is in that test now; without it, a player who read the 3D map for
    two minutes would be teleported out from under it.
*/
params [["_isRedeploy", false, [false]]];

if (!canSuspend) exitWith {
    diag_log "[SPAWNWEB] open: unscheduled caller -- declining to the native menu";
    false
};
if (isDedicated || {!hasInterface}) exitWith { false };

// The kill switch. Server-owned like SRV_landingEnabled, read through a default of true so a client
// that has not yet received the publish behaves like one that has. false = the native dialog 38500,
// i.e. the world as it was before this feature, with nothing else to roll back and no repack needed.
if !(missionNamespace getVariable ["SRV_spawnWebEnabled", true]) exitWith {
    diag_log "[SPAWNWEB] open: SRV_spawnWebEnabled is false -- native spawn menu";
    false
};
if (isNil "webui_fnc_init") exitWith {
    diag_log "[SPAWNWEB] open: the webui library is not loaded -- native spawn menu";
    false
};

AP_spawnWebRedeploy = _isRedeploy;
AP_spawnWebDeployed = false;

// Same two-step AP_fnc_landingOpen and fn_casinoOpen use to swap one web dialog for another: the
// browser control binds A3API at creation, so a stacked create is not a navigation.
if (dialog) then { closeDialog 0; uiSleep 0.15; };

if !(createDialog "AP_web_spawn") exitWith {
    diag_log "[SPAWNWEB] open: createDialog AP_web_spawn failed -- native spawn menu";
    false
};
private _up = diag_tickTime + 5;
waitUntil { uiSleep 0.1; !isNull (findDisplay 938700) || {diag_tickTime > _up} };
if (isNull (findDisplay 938700)) exitWith {
    diag_log "[SPAWNWEB] open: display 938700 never appeared in 5s -- native spawn menu";
    false
};

"loadingScreen" cutText ["", "PLAIN"];
diag_log format ["[SPAWNWEB] open: display up, redeploy=%1, waiting on the player", _isRedeploy];

// fn_spawnConfirm closes the dialog on every path that commits -- the teleport, and the redeploy
// abort, which closes FIRST and then decides. So "the display is gone" is the one signal that covers
// both, and AP_spawnWebDeployed (set by the bridge's deploy verb, only after the row passed its own
// checks) is what separates a commit from an Esc.
waitUntil { uiSleep 0.2; isNull (findDisplay 938700) };

diag_log format ["[SPAWNWEB] closed: deployed=%1", AP_spawnWebDeployed];
AP_spawnWebDeployed
