/*
    AP_fnc_deathState -- ONE payload for the death page's "death" channel.

        [_ctrl, "death", ([] call AP_fnc_deathState)] call webui_fnc_push;

    Shape, exactly what ui\html\death.html's header declares:

        { stage, remain, paused, canRespawn, canRequest, canAllow, reqCd, allowCd,
          allowed, requested, restricted, online, nearest, responder, reason, dragger }

    SQF OWNS EVERY DEADLINE AND EVERY PERMISSION IN HERE. The page counts seconds
    down between pushes so the clock does not stutter at 1 Hz, and it disables its
    own buttons so a click cannot be wasted -- but it decides nothing. Each push
    overwrites whatever the page interpolated, and every verb re-checks its own gate
    on arrival (AP_fnc_deathWebMedical, and the respawn verb in fn_deathWebBridge).
    A page that lied about its remaining time would get a correct number 1 s later
    and a refusal from the verb immediately.

    THE CLOCKS ARE NOT MERGED, and that is the whole shape of the death flow:
      stage "lock"  -- fn_onPlayerKilled's FIRST timer, AP_respawn_timer * 60.
                       Respawn is locked. Bleedout has not started.
      stage "bleed" -- the SECOND timer, AP_death_timer * 60, started only after the
                       first expired. This is the bleedout deadline.
    fn_onPlayerKilled owns both and publishes the current one as AP_deathDeadline;
    this function only reports what is left of it. Reading one clock here and
    inferring the other would be the merge the design forbids.

    `remain` IS SECONDS LEFT, NOT A TIMESTAMP, deliberately. The page has no access
    to the engine's `time` and no way to align its own clock to it, so handing it a
    deadline would make it subtract two numbers from different clocks. Seconds-left
    is self-correcting: the page's own interpolation drifts at most one push.

    PAUSED MEANS THE DEADLINE IS MEANINGLESS, not that it is zero. While the corpse
    carries AP_reviving, fn_onPlayerKilled holds the bleedout deadline and pushes it
    forward by the treatment time afterwards, so `remain` keeps its last real value
    and the page shows PAUSED instead of a number. It must not render a countdown
    from a frozen deadline.

    nearest IS -1 FOR "NONE", not 0 and not a large number: AP_fnc_deathMedics
    answers 99999 for "no eligible live responder anywhere" and that sentinel is
    translated here so the page never has to know it. Distance is NOT an ETA.

    dragger IS A DISPLAY NAME, "" = NOBODY IS MOVING THE BODY (owner 2026-09-16, body
    dragging, AP_fnc_dragBody). The death camera already follows a moving AP_corpse, so
    the only thing the dead player lacked was WHY the shot is moving; the page prints
    "YOUR BODY IS BEING MOVED BY <NAME>". Three rules shape the read:
      - attachedTo IS THE TRUTH, the public AP_draggedBy flag only supplies the name.
        The dragger publishes the flag and then attaches, and the two can arrive here
        in either order: flag without attach = "" (not moving yet), attach without
        flag = the fallback `name` of whatever holds the body.
      - Only a LIVING CAManBase counts. A player killed while attached to a helper
        (chair, tag, fast-rope, a parkour move) may leave the corpse attached to a
        ClutterCutter, which `alive` calls alive and `name` calls "Error: No unit".
        That is not a drag and must not print one.
      - The flag's name is used only when the flag's object IS the attached unit, so a
        stale flag from an earlier drag can never put the wrong name on a live one.

    THE BODY OWNER'S STALE SWEEP also lives here, because this is the one piece of the
    dead player's own code that runs at 1 Hz for exactly as long as the body matters.
    A dragger who Alt-F4s takes his watchdog and his AP_fnc_dragBodyStop with him, so
    nobody on his side clears the flag. Here: a non-empty AP_draggedBy whose object is
    null or is not what the body is attached to, for AP_dragCfg_ownerStaleTicks
    (default 3) consecutive calls, is cleared publicly -- and if the body is still
    attached to something while the recorded dragger is gone (SPIKE D7: the body stays
    welded after the dragger is deleted), the owner detaches it (detach is argument-
    and effect-global, one machine is enough). Three calls, not one, because the
    dragger's setVariable and attachTo propagate independently and a single mismatched
    read is the normal start and stop of every drag. The counter is
    AP_deathDragStale; anything that is not stale resets it. The sweep logs one
    [DEATHWEB] RPT line and one -DRAG- row when it acts, so a dragger disconnect
    still leaves a row where his stop row would have been.
    THE SWEEP NEVER MOVES THE BODY (owner 2026-09-16). The dragger's CONTINUOUS CLAMP
    (fn_dragBody) kept the body's position on his side of walls on every tick up to his
    last one, so where he left it needs no repair here, and a sweep that guessed where
    he had stood could only move it somewhere worse.
    The SWEEP runs only while the web screen pushes. On the native screen a stale flag
    stays set until the next drag attempt's own hygiene (plan step 2: fn_dragBody clears
    a flag whose dragger is gone); fn_revived's detach guard still unwelds a held body.

    LIVE TOGGLES, no repack (debug console):
      AP_dragCfg_ownerStaleTicks  (3)     consecutive stale calls before the sweep acts
      AP_dragCfg_ownerForceDetach (false) SPIKE D7 variant: also detach when the body
                                          reads unattached but the recorded dragger is
                                          gone (the body "floats" with attachedTo null)
      AP_dragDebug                (false) one [AP-PROBE] line per call while a flag or
                                          an attachment exists on the body
    An older client that never sends `dragger` is fine: the page treats a missing key
    as "". A newer client against an older served page just sends a key nobody reads.
*/
private _now = time;
private _stage      = missionNamespace getVariable ["AP_deathStage", "lock"];
private _deadline   = missionNamespace getVariable ["AP_deathDeadline", -1];
private _restricted = player getVariable ["AP_suicideVestDeath", false];

// The corpse is what a medic works on, so the pause flag is read off the BODY, not
// off the player -- the same read fn_onPlayerKilled's bleedout loop uses.
private _paused = !isNull (AP_corpse getVariable ["AP_reviving", objNull]);

private _remain = 0;
if (_deadline > 0) then { _remain = (_deadline - _now) max 0; };

([] call AP_fnc_deathMedics) params ["_online", "_nearest"];
if (_nearest isEqualTo 99999) then { _nearest = -1 } else { _nearest = round _nearest };

// The responder label mirrors fn_onPlayerKilled's own MaxSec/TT distinction. The
// LOGIC that clears a dead responder lives in that file's bleedout loop and runs on
// both screens; this is only how the same fact is worded for this one.
private _responder = "";
if (!isNull AP_medic_enroute) then {
    _responder = if (side AP_medic_enroute isEqualTo west)
        then { format ["MaxSec Medic %1", name AP_medic_enroute] }
        else { format ["TT Medic %1", name AP_medic_enroute] };
};

// WHO IS MOVING THE BODY, and the owner's stale sweep. See the header: attachedTo is
// the truth, the flag is only the name. objNull-safe throughout -- attachedTo objNull
// is objNull and getVariable on objNull answers the default -- so the first frames of
// a death, before AP_corpse is set, read as "nobody".
private _att   = attachedTo AP_corpse;
private _flag  = AP_corpse getVariable ["AP_draggedBy", []];
private _fObj  = objNull;
private _fName = "";
// The flag is a public variable any client can write, so its parts are trusted only
// in the contract shape [object, string, ...]; anything else non-empty is read as a
// flag with no dragger, which the sweep clears. _fOk gates the DETACH: only a flag
// that really recorded a dragger object, which has since gone null, may unweld the
// body. A malformed flag is cleared and never detaches, so a shape mismatch between
// this reader and fn_dragBody's writer fails soft (fallback name) instead of dropping
// every body 3 s into its drag.
private _fOk = _flag isEqualType [] && {count _flag >= 2} && {(_flag select 0) isEqualType objNull} && {(_flag select 1) isEqualType ""};
if (_fOk) then { _fObj = _flag select 0; _fName = _flag select 1; };

private _dragDetached = false;
private _dragStale = !(_flag isEqualTo []) && {isNull _fObj || {!(_att isEqualTo _fObj)}};
if (_dragStale) then {
    private _n = (missionNamespace getVariable ["AP_deathDragStale", 0]) + 1;
    if (_n >= (missionNamespace getVariable ["AP_dragCfg_ownerStaleTicks", 3])) then {
        if (_fOk && {isNull _fObj} && {!isNull _att || {missionNamespace getVariable ["AP_dragCfg_ownerForceDetach", false]}}) then {
            detach AP_corpse;
            _dragDetached = true;
        };
        // owner 2026-09-16: detach only, never a reposition (header THE SWEEP NEVER MOVES THE BODY).
        AP_corpse setVariable ["AP_draggedBy", nil, true];
        diag_log format ["[DEATHWEB] drag sweep: cleared stale AP_draggedBy on own body (flag=%1 attachedTo=%2 detached=%3)", _flag, _att, _dragDetached];
        [["-DRAG-", player, profileName, format ["owner-sweep cleared a stale drag flag on own body: dragger=%1 draggerGone=%2 attached=%3 detached=%4", _fName, isNull _fObj, !isNull _att, _dragDetached]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        _n = 0;
    };
    AP_deathDragStale = _n;
} else {
    AP_deathDragStale = 0;
};

private _dragger = "";
if (!_dragDetached && {!isNull _att} && {alive _att} && {_att isKindOf "CAManBase"}) then {
    _dragger = if (_fName isNotEqualTo "" && {_fObj isEqualTo _att}) then { _fName } else { name _att };
};
if ((missionNamespace getVariable ["AP_dragDebug", false]) && {!(_flag isEqualTo []) || {!isNull _att}}) then {
    diag_log format ["[AP-PROBE] deathState drag: attachedTo=%1 flag=%2 stale=%3/%4 dragger=%5 detached=%6",
        _att, _flag, missionNamespace getVariable ["AP_deathDragStale", 0],
        missionNamespace getVariable ["AP_dragCfg_ownerStaleTicks", 3], _dragger, _dragDetached];
};

private _reqCd   = ((missionNamespace getVariable ["AP_deathReqUntil",   -1]) - _now) max 0;
private _allowCd = ((missionNamespace getVariable ["AP_deathAllowUntil", -1]) - _now) max 0;

// WHY THE MEDICAL ACTIONS ARE OFF, in words the page prints instead of leaving a
// dead button with no explanation. Order matters: the restriction outranks a
// cooldown, because a suicide-vest death is never getting a medic at all.
private _reason = "";
if (_restricted) then { _reason = "NO REMAINS TO TREAT -- MEDICAL CHANNEL CLOSED"; };

// Respawn stays available during a revive. The approved screen disables it then,
// and that affordance is NOT implemented -- see ui\html\death.html's header for the
// soft-lock that made it unsafe. The page shows the medic's status and warns in the
// confirmation instead.
private _canRespawn = (_stage isEqualTo "bleed");

createHashMapFromArray [
    ["stage",      _stage],
    ["remain",     round _remain],
    ["paused",     _paused],
    ["canRespawn", _canRespawn],
    ["canRequest", !_restricted && {_reqCd   isEqualTo 0}],
    ["canAllow",   !_restricted && {_allowCd isEqualTo 0}],
    ["reqCd",      round _reqCd],
    ["allowCd",    round _allowCd],
    ["allowed",    AP_corpse getVariable ["AP_revivable", false]],
    ["requested",  player getVariable ["AP_medRequest", false]],
    ["restricted", _restricted],
    ["online",     _online],
    ["nearest",    _nearest],
    ["responder",  _responder],
    ["reason",     _reason],
    ["dragger",    _dragger]
]
