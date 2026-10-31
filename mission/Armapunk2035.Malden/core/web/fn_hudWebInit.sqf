/*
    AP_fnc_hudWebInit -- bring up the STATUS HUD layer (dialog\hudWeb.hpp, class AP_web_hud,
    page ui\html\hud.html) and keep it up for the rest of the session.

        [] call AP_fnc_hudWebInit;      // core\init.sqf, right after AP_fnc_hudSetup

    A LAYER, NOT A DIALOG -- see dialog\hudWeb.hpp's header for why, and for the two shipped
    halves that prove a type=106 control works inside RscTitles (AP_map_warm) and that a
    transparent full-screen one shows the world through it (AP_web_visor).

    THE NATIVE HUD IS RETIRED AS OF PR14, AND THIS FILE IS WHERE THAT IS ENFORCED. PR13 ran
    both HUDs at once on purpose, so the owner's first look would be an unambiguous yes/no and
    so an unproven title-layer composite would fail SAFE. It drew (owner playtest, 2026-08-20),
    the owner said remove the old one, and DUTY_SOAK H18 is PROVEN. So: AP_fnc_hudUpdate's
    native drawing is now inside one flag-gated block, AP_fnc_hudSetup no longer cuts
    AP_playerHUD at init, and the keeper below cuts layer 2 down if anything else does -- which
    something does, on every death (evh\fn_onPlayerKilled.sqf). Nothing was deleted: every
    non-visual thing fn_hudUpdate did still runs on both paths.

    AP_webHudEnabled IS THE SWITCH, default TRUE, read through a getVariable default so it
    needs no server publish and no server change to exist. False at any moment: the keeper cuts
    the layer down within a second and stops re-cutting, leaving the native HUD as the HUD. It
    can be flipped live from the debug console, which is the fastest way to A/B the two.

    THE KEEPER IS THE WHOLE DESIGN. There is no "on respawn, re-cut" event hook anywhere in
    this feature. A 1 Hz loop asks one question -- should the layer be up, and is it -- and
    fixes the answer. That covers death and respawn (AP_isDead), the toggle, a layer lost to
    anything at all, and the case where the very first cut lost the race with mission init,
    with one piece of code instead of four hooks that each have to remember. It is the same
    self-healing shape AP_fnc_hudUpdate already uses for the native layer ("if (isNull _ui)
    exitWith { 2 cutRsc [...] }") and the same shape as AP_fnc_hudSetup's own 1 Hz watcher.

    WEBUI_ctrl IS SAVED AND RESTORED AROUND webui_fnc_init, AND THAT IS LOAD-BEARING.
    webui_fnc_init:47 publishes the control it just wired as uiNamespace "WEBUI_ctrl", and
    other bridges read that slot back to find "the page" -- AP_fnc_landingBridge's landingReady
    handler pushes into it, and webui_fnc_prompt resolves its overlay through it. Every other
    caller is a dialog, so last-one-wins is correct for them. This one is not a dialog: it can
    re-wire at any moment, including while a browser dialog is open, and a re-cut that stole
    that slot would send the landing page's own payload into the HUD instead. So the slot is
    put back exactly as it was found. The HUD never reads it -- it keeps its own handle.

    NO webui_fnc_serve HERE, unlike the landing and the casino. Serving replaces the live
    document with document.open()/write()/close(), which drops window.AP and does not fire
    PageLoaded to re-inject it. That is fine for a dialog that was just opened and is about to
    be pushed to anyway; on a layer that stays up all session it would silently deafen the HUD
    at an unpredictable moment. The HUD ships in the PBO like the rest of the mission.

    NO CfgRemoteExec ENTRY, NO SERVER FUNCTION, NO SERVER FILE. The page is display-only: its
    shim defines AP.on and nothing else, so there is no name a page-side script could call SQF
    through, and every value it draws is read locally on the client that draws it.

    THE CONTROL HANDLE LIVES IN uiNamespace, NOT missionNamespace. Controls are not
    serializable and missionNamespace is a namespace the engine saves, so a control stored there
    earns "Variable 'ap_hudwebctrl' does not support serialization and should not be stored in
    the mission namespace" in the RPT -- twice per occurrence, which is what the owner
    screenshotted after the first playtest. uiNamespace is the engine's own home for UI handles,
    is never serialized, and is already where this feature keeps its display (AP_web_hud) and
    where it finds the shared WEBUI_ctrl slot it borrows. AP_hudWebLast stays in missionNamespace
    on purpose: it is a STRING, it serializes fine, and moving it would be churn.

    THE PAGE GREW A MINIMAP part-way through this work, in a revision of the designer's file.
    It rides the SAME single "hud" channel as an optional `map` member, so nothing here changed
    shape for it -- only the rate did (see the inner loop below) and the payload did
    (fn_hudWebPush's header says exactly which of its marker kinds are fed and which are
    deliberately left empty). PR14 then pointed it at the game's own satellite layer, which
    this file's header used to say could not be fed at all; PR15 added the SECOND channel the
    inner loop below now alternates with, because pos and dir need a rate the vitals do not.
*/
disableSerialization;
if (!hasInterface) exitWith { false };
if (isNil "webui_fnc_init") exitWith {
    diag_log "[HUDWEB] init: the webui library is not loaded -- native HUD only";
    false
};

// One keeper per session. A second call (a re-run of core\init.sqf, a hand call from the
// console) must not start a second loop racing the first over the same layer.
if (!isNil "AP_hudWebKeeper" && { !isNull AP_hudWebKeeper && { !scriptDone AP_hudWebKeeper } }) exitWith {
    diag_log "[HUDWEB] init: keeper already running";
    true
};

AP_hudWebLast = "";        // last payload actually sent, for the change gate in fn_hudWebPush
AP_hudWebLastPos = "";     // and the fast lane's own gate -- see the inner loop below
uiNamespace setVariable ["AP_hudWebCtrl", controlNull];     // see the header: NOT missionNamespace

AP_hudWebKeeper = [] spawn {
    // Per SCRIPT, not per file: this body is a different script from the one above it, and it
    // is the one that handles a control at all (AP_hudWebCtrl, in uiNamespace). Without this the first
    // display-typed assignment in here errors out and takes the keeper with it.
    disableSerialization;
    private _layer = "AP_web_hud" call BIS_fnc_rscLayer;
    diag_log format ["[HUDWEB] keeper up on layer %1", _layer];

    while {true} do {
        // AP_isDead is the native HUD's own "do not draw" test (fn_hudUpdate:3), so the two
        // HUDs disappear and come back together rather than one of them freezing on the last
        // frame of a dead player's vitals behind the death camera.
        private _on = missionNamespace getVariable ["AP_webHudEnabled", true];
        private _want = _on
            && { !(missionNamespace getVariable ["AP_isDead", false]) }
            && { alive player }
            // PR-HUDEDIT: the HUD UI EDITOR (hudeditor.md) shows this same page in a focused
            // dialog, because a title layer is never sent a mouse event and therefore cannot be
            // dragged. Two copies of the HUD, one frozen and one being arranged, is not
            // something anybody can edit against -- so the layer stands down while the editor is
            // open, and this is the ONE place that is decided. AP_fnc_hudEdit sets the flag and
            // AP_fnc_hudEditClose clears it; the loop below puts the layer back within a second
            // either way, including after an Esc that closed the dialog without asking anyone.
            && { !(missionNamespace getVariable ["AP_hudEditActive", false]) };

        // ---- PR14: WHICH HUD IS THE HUD, ENFORCED IN ONE PLACE -------------------------------
        // The owner retired the native HUD once this one was confirmed drawing. AP_fnc_hudUpdate
        // and AP_fnc_hudSetup are both gated on this same flag, but layer 2 is cut from a THIRD
        // place -- evh\fn_onPlayerKilled.sqf, on every death -- and that file is a single
        // minified line that nothing should be threading a condition into. So the flag's effect
        // on layer 2 is enforced here instead, where the loop that already knows which HUD is
        // live runs anyway.
        //
        // It has to be the LAYER and not just the drawing: AP_playerHUD's class defaults are
        // visible. dialog\ui.hpp parks every bar track, fill, icon and overlay at 0.8 / 0.85
        // with real sizes and opaque colours, and AP_fnc_hudUpdate is the only thing that ever
        // moves them, so a layer that is cut and never drawn into is a heap of placeholder bars
        // in the middle of the screen -- which is exactly what the death screen shows today.
        // Clearing the uiNamespace slot is not optional either: the class fills it in onLoad and
        // has no onUnload, so a stale handle would make this branch fire once a second forever.
        if (_on) then {
            if (!isNull (uiNamespace getVariable ["AP_playerHUD", displayNull])) then {
                2 cutText ["", "PLAIN"];
                uiNamespace setVariable ["AP_playerHUD", displayNull];
                diag_log "[HUDWEB] native HUD layer cut down -- the web HUD is the HUD";
            };
        } else {
            // The escape hatch's other half. With the flag off the native HUD is the HUD again,
            // and AP_fnc_hudUpdate's own isNull self-heal is what cuts it back up -- but only
            // the next time something calls it, which is a survival tick away. One call here
            // makes the flip visible within a second, in both directions, from the console.
            if (!(missionNamespace getVariable ["AP_isDead", false]) && { alive player }
                && { isNull (uiNamespace getVariable ["AP_playerHUD", displayNull]) }) then {
                [] call AP_fnc_hudUpdate;
                diag_log "[HUDWEB] toggle off -- native HUD restored";
            };
        };

        private _d = uiNamespace getVariable ["AP_web_hud", displayNull];
        private _c = if (isNull _d) then { controlNull } else { _d displayCtrl 938301 };

        if (_want) then {
            if (isNull _c) then {
                // showInMap is TRUE, matching the native HUD (fn_hudSetup's 2 cutRsc takes the
                // default): the same numbers stay readable with the map open, as they are today.
                _layer cutRsc ["AP_web_hud", "PLAIN", 0, true];

                // The layer's display does not exist for a frame or two. onLoad fills the
                // uiNamespace slot; if it never does, say so and try again next tick rather
                // than wiring a null control.
                private _up = diag_tickTime + 5;
                waitUntil {
                    uiSleep 0.1;
                    !isNull (uiNamespace getVariable ["AP_web_hud", displayNull]) || { diag_tickTime > _up }
                };
                _d = uiNamespace getVariable ["AP_web_hud", displayNull];
                _c = if (isNull _d) then { controlNull } else { _d displayCtrl 938301 };

                if (isNull _c) then {
                    diag_log "[HUDWEB] cut AP_web_hud but control 938301 never appeared -- retrying";
                } else {
                    // See the header: this slot belongs to whichever dialog is open, not to us.
                    private _prev = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
                    private _ok = [_c] call webui_fnc_init;
                    uiNamespace setVariable ["WEBUI_ctrl", _prev];

                    if (_ok) then {
                        uiNamespace setVariable ["AP_hudWebCtrl", _c];
                        AP_hudWebLast = "";              // a fresh page has no last value to match
                        AP_hudWebLastPos = "";           // both gates, or the map starts frozen

                        // PR-HUDEDIT: the player's saved layout (hudeditor.md). Applied from the
                        // cache FIRST so a re-cut mid-session -- every death and respawn -- puts
                        // the HUD straight back where the player left it instead of snapping to
                        // the designer's corner for a round trip. AP_fnc_hudLayoutGet is
                        // throttled to one query per ten seconds precisely because this line
                        // lives inside a keeper that re-bridges on every re-cut.
                        //
                        // NOT part of the 32-element login load, deliberately: that array is read
                        // by INDEX in fn_requestReceived, and it is the same structure that
                        // produced the stat/title corruption. A cosmetic setting does not earn a
                        // seat in it. Worst case here is a HUD wearing the shipped layout, which
                        // is the right direction to fail in.
                        [_c] call AP_fnc_hudLayoutApply;
                        [] call AP_fnc_hudLayoutGet;

                        [] call AP_fnc_hudWebPush;
                        diag_log format ["[HUDWEB] layer up and bridged, ctrl %1 t=%2",
                            ctrlIDC _c, diag_tickTime toFixed 1];
                    } else {
                        diag_log "[HUDWEB] webui_fnc_init refused control 938301 -- retrying";
                    };
                };
            };
        } else {
            if (!isNull _d) then {
                _layer cutText ["", "PLAIN"];
                // Cleared here as well as in the class's onUnload/onDestroy. If the engine did
                // not fire either, the slot would still hold a handle next tick, this branch
                // would call cutText once a second forever, and the re-cut branch above would
                // never re-bridge because it only fires on a NULL control.
                uiNamespace setVariable ["AP_web_hud", displayNull];
                uiNamespace setVariable ["AP_hudWebCtrl", controlNull];
                AP_hudWebLast = "";
                AP_hudWebLastPos = "";
                diag_log "[HUDWEB] layer down (toggle off, dead, or not alive)";
            };
        };

        // Cheap second job, and the reason the inner loop exists. Most of the payload changes
        // only when AP_fnc_hudUpdate runs, but three parts of it do not: paused (the spawn map
        // opening, cuffs going on), regen (a 5 s tick in fn_survival) and the whole minimap
        // half, which moves whenever the player does.
        //
        // ---- PR15: TWELVE TICKS, AND ONLY EVERY THIRD ONE IS A FULL PAYLOAD ------------------
        // The owner reported that the panel does not track him one to one. It could not: the
        // whole payload moved at ONE rate, 4 Hz, and 4 Hz is 250 ms of dead time per step --
        // which the page then tried to paper over with CSS transitions that could only be
        // applied to SOME of the moving layers, so the grid glided while the tiles and blips
        // stepped. Both halves of that are fixed: the page eases nothing at all now, and this
        // loop carries the smoothness instead.
        //
        // 12 Hz, chosen for three reasons and not as a round number:
        //   * it is 83 ms a step, so a sprinting player (~5.5 m/s) moves 0.46 m between pushes
        //     -- 0.012 rem on a 13 rem / 500 m panel, which is sub-pixel at any UI scale;
        //   * 12 divides by 3, so the FULL payload lands on every third tick and its rate is
        //     EXACTLY the 4 Hz it already ran at. Nothing proven at 4 Hz is being re-bet;
        //   * 12 ticks is one second, so the outer layer bookkeeping stays at 1 Hz untouched.
        //
        // The eight added ticks are the fast lane: pos and dir only, on the "hudmap" channel,
        // 81 bytes of ExecJS against the full payload's 1110 (fn_hudWebPush's header carries
        // the measurement). 4 calls/s becomes 12 and 4440 B/s becomes 5088 -- +14.6% bytes for
        // three times the motion resolution, and a fifth of what a 60 fps per-frame push would
        // cost, which is the work core\web\README.md actually forbids.
        //
        // BOTH RATES ARE CEILINGS, NOT COSTS. Each lane has its own change gate and both round
        // -- heading to the degree, positions to the metre -- so a standing player produces an
        // identical payload on both channels and sends neither. Zero ExecJS at rest, unchanged.
        for "_i" from 1 to 12 do {
            if (!isNull (uiNamespace getVariable ["AP_hudWebCtrl", controlNull])) then {
                if ((_i mod 3) isEqualTo 0) then { [] call AP_fnc_hudWebPush }
                                            else { ["fast"] call AP_fnc_hudWebPush };
            };
            uiSleep (1 / 12);
        };
    };
};
true
