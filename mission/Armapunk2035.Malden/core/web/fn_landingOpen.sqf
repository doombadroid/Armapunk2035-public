/*
    AP_fnc_landingOpen -- the landing screen: welcome splash + deployment picker, shown once at connect.

        private _took = [] call AP_fnc_landingOpen;

    Called from fn_initCiv.sqf:1, in place of the lobby welcome's PLAY gate. Returns TRUE when it took the
    screen (and it has already blocked until the player deployed or closed it), FALSE when it declined --
    in which case the caller runs ["waitForPlay"] call AP_fnc_welcomeUI exactly as before. Every decline is
    a fall-through to the pre-PR9 flow, never a dead end.

    THIS MUST RUN SCHEDULED. It blocks on the player, which is the whole point; fn_initCiv is spawned, so a
    plain `call` from there is scheduled. An unscheduled arrival declines rather than trying to re-spawn
    itself, because a re-spawned copy could not hand its answer back to a caller that has already moved on.

    WHAT IT DECLINES FOR, and why each one:
      * SRV_landingEnabled false -- phase 9's own kill-switch. Server-owned, publicVariable'd from
        server_init.sqf, read here through a getVariable default of true so a client that has not yet
        received the publish behaves like one that has. Off = the lobby welcome and the spawn menu, i.e.
        the world as it was before this PR, with no other moving part to roll back.
      * AP_intakePath == 0 -- a fresh account. THE INTAKE OWNS THAT LOGIN, and interposing here would be
        the wrong shape twice over. Mechanically: fn_intake is the ONE path that releases the 50 km slot
        hold itself (fn_intake.sqf:75-79), fn_initCiv `spawn`s it without waiting, and it ends by simply
        returning -- there is no completion signal to hang a "landing after intake" on, so ordering it
        second would mean inventing one. Editorially: the intake is the game introducing itself; a
        deployment picker in front of it asks a question the player has no way to answer yet. They meet
        MaxSec and Trauma at an HQ terminal like everyone else, from their second login onwards.
      * a jailed account -- fn_initCiv:14 sends them straight to fn_jailPlayer, no menu and no choice.
        APS_fnc_dutySRV's "request" now re-checks arrest too (it tests alive / civilian / restrained /
        roster / cooldown / wanted / whitelist / arrested), so this decline is not the only lock any more --
        but not opening the screen is still the cheapest way to skip a deployment picker for someone about
        to be teleported straight to a cell. AP_fnc_dutyGate blocks it a second time anyway.
      * createDialog failing -- a missing class or an already-open exclusive display. Falling back beats
        a login that hangs on a screen that never appeared.

    ESC. The page handles welcome<->select itself, but Esc also reaches the engine, which closes the
    dialog -- and this file deliberately adds no KeyDown handler to stop it (compare fn_casinoOpen.sqf:109,
    which closes on Esc on purpose). Closing is SAFE, not a strand: the wait below ends, this returns true,
    and fn_initCiv carries on into the branch it always had -- relog teleport or spawn menu. The player
    lands in the world as a civilian, which is exactly what "solo" would have given them. Reopening on
    unload was the alternative and was rejected: a screen a player cannot dismiss is a worse failure than
    a screen they can skip, and skipping it costs them nothing they cannot get at an HQ terminal.

    AP_quitWelcomeUI IS SET WHEN THIS TAKES OVER. It is not just the welcome dialog's own flag: it is the
    tree's "the player is past the welcome screen" signal, and two things wait on it --
    fn_manageHouseTax.sqf:109 blocks until it is true, and fn_onGameInterrupt.sqf:76 uses it to fire the
    session's first ClupdateRequest. Leaving it false because the player pressed PLAY on a different screen
    would hang house tax for the whole session.
*/
if (!canSuspend) exitWith {
    diag_log "[LANDING] open: unscheduled caller -- declining to the lobby welcome";
    false
};
if (isDedicated || {!hasInterface}) exitWith { false };

if !(missionNamespace getVariable ["SRV_landingEnabled", true]) exitWith {
    diag_log "[LANDING] open: SRV_landingEnabled is false -- lobby welcome + spawn menu";
    false
};
if ((missionNamespace getVariable ["AP_intakePath", -1]) isEqualTo 0) exitWith {
    diag_log "[LANDING] open: fresh account on the intake path -- intake owns this login";
    false
};
if (((missionNamespace getVariable ["AP_is_arrested", [0,0,0]]) param [0, 0]) isEqualTo 1) exitWith {
    diag_log "[LANDING] open: account is serving a sentence -- straight to the cell";
    false
};

AP_landingPick = "";      // "" until a deploy is granted; then "solo" / "maxsec" / "trauma"
// The other two slots are SHARED with the MaxSec duty terminal page as of PR11 and live in
// AP_fnc_dutyRequest now -- AP_dutyReqWait is the faction of a duty request currently in flight (arming
// fn_handleMessage's refusal tap) and AP_dutyReqErr is the text that tap captured. Seeded here as well as
// there because the waitUntil below reads the wait slot before any request has been made.
AP_dutyReqWait = "";
AP_dutyReqErr  = "";

// The lobby welcome (dialog 17000) is still up and is still spinning its own thread. Release that thread
// and take the display, the same two-step fn_casinoOpen.sqf:41 uses to swap one web dialog for another --
// closeDialog first, a beat, then createDialog, because the browser control's `url` binds A3API at
// creation and a stacked create is not a navigation.
AP_quitWelcomeUI = true;
if (dialog) then { closeDialog 0; uiSleep 0.15; };

if !(createDialog "AP_web_landing") exitWith {
    diag_log "[LANDING] open: createDialog AP_web_landing failed -- falling through to the spawn flow (AP_quitWelcomeUI is already true and the welcome dialog already closed, so there is no welcome screen left to return to)";
    false
};
// The dialog may not exist for a frame or two. If it never appears, decline rather than wait forever.
private _up = diag_tickTime + 5;
waitUntil { uiSleep 0.1; !isNull (findDisplay 938100) || {diag_tickTime > _up} };
if (isNull (findDisplay 938100)) exitWith {
    diag_log "[LANDING] open: display 938100 never appeared in 5s -- falling through to the spawn flow (AP_quitWelcomeUI is already true and the welcome dialog already closed, so there is no welcome screen left to return to)";
    false
};
diag_log "[LANDING] open: display up, waiting on the player";

// Three ways out, and the second clause is the one that matters: a player who Escs the dialog WHILE a duty
// request is in flight must not be released until that request settles, or the grant would land on top of
// the spawn menu with fn_initCiv already committed to the civilian branch.
waitUntil {
    uiSleep 0.2;
    (AP_landingPick isNotEqualTo "")
    || {isNull (findDisplay 938100) && {AP_dutyReqWait isEqualTo ""}}
};

if (!isNull (findDisplay 938100)) then { closeDialog 0; };
diag_log format ["[LANDING] closed: pick=%1 onDuty=%2", AP_landingPick,
    missionNamespace getVariable ["AP_onDuty", false]];
true
