// DEV INSTRUMENTATION -- body drag spike recorder and live tuner (owner 2026-09-16).
// Nothing registers or execVMs this file; it runs only when started from the debug console. Every line it
// writes is tagged [AP-PROBE] drag. RPT (client): the Proton path in CLAUDE.md, newest *.rpt by mtime:
//   grep '\[AP-PROBE\] drag' <rpt>
//
// WHY. The drag (core\actions\fn_dragBody.sqf) is built on eight engine assumptions nobody has measured
// (plan "Feature B", spikes D1-D8). Every spike-dependent choice is a live AP_dragCfg_* override, so a
// spike is: record with this file, flip an override, record again. No repack.
//
// MODES (paste ONE line into the debug console, LOCAL EXEC; these one-liners carry no // comments):
//   ["trace"] execVM "debug\probe_drag.sqf";
//       Waits up to 60 s (["trace", 120] for longer) for YOUR drag to start, then samples once per watchdog
//       tick (AP_dragCfg_tick, default 0.1 s) while AP_dragging is non-null, then keeps sampling the released
//       body for 3 s (D4 settle). One line per sample: t anim att bodyATL dragATL dist dirBody dirDrag rel local,
//       then the CONTINUOUS CLAMP (owner 2026-09-16): y = the attach y the watchdog last applied (AP_dragMeta
//       slot 11), need = the y the clamp rays want right now, hit = the nearest counted hit as <what>@<metres>
//       ("-" = nothing in reach, "terrain@..." = the ground on the lowest ray). need is measured by this probe
//       with the same rays a moment apart from the watchdog, and never attaches anything.
//   ["offset", [0, 1.1, 0.092], 180] execVM "debug\probe_drag.sqf";
//       Sets AP_dragCfg_offset / AP_dragCfg_dir for every later drag AND re-attaches the current body with
//       them right now (SPIKE D2). A negative dir skips setDir. The new y is the NOMINAL drag distance: the
//       watchdog's next tick clamps it again if something is in front of you.
//   ["watch"] execVM "debug\probe_drag.sqf";
//       OBSERVER side (second client, or the dead player): for 60 s (["watch", 300] for longer), 5 Hz, every
//       dead body within 60 m that carries AP_draggedBy or is attached to something: how THIS machine sees
//       it (D6/D7/D8). While this client is dead the 60 m are measured from its own body (AP_corpse), not
//       from `player` -- respawnDelay=0 makes `player` the new unit at the respawn marker -- and the own
//       body is always included. The DEAD PLAYER MUST START IT BEFORE DYING: both death screens block Esc,
//       so the debug console cannot be opened after death.
//   ["cfg"] execVM "debug\probe_drag.sqf";      dumps every AP_dragCfg_* override currently set
//   ["reset"] execVM "debug\probe_drag.sqf";    clears every AP_dragCfg_* override (file defaults again)
//
// SPIKE BODY. There is no single-tester AI body on .96: createUnit and createAgent are disabled on every
// machine (CfgDisabledCommands.hpp targets {0,0,0}) and the debug console's SERVER EXEC is off there
// (deploy/live/reload-live.sh). The spike body is a SECOND CLIENT that dies in front of you; its body carries
// AP_steamid, so AP_dragDebug is not needed. AP_dragDebug = true still relaxes the rule to any dead
// CAManBase if some other dead unit (mission AI) is at hand, and adds [AP-PROBE] start/stop lines.
//
// WHAT EACH SPIKE LOOKS FOR
//   D1 attach freezes the ragdoll, no jitter/clipping. trace while walking backwards on flat ground and on
//      a slope: dist stays ~constant (about the offset) while y= stays at nominal, att=true every line, bodyATL
//      z never goes negative (buried) or jumps. Fallback: raise z with the offset mode. On a slope rising in
//      front of you y= may drop (terrain counts on the lowest clamp ray); if that looks wrong,
//      AP_dragCfg_clampTerrain = false;
//   D2 offset/dir look right (body in front, feet toward you). Tune with the offset mode until it looks
//      right; the final numbers go into AP_dragCfg_offset / AP_dragCfg_dir defaults in fn_dragBody.sqf.
//   D3 the drag animation set. trace with RIFLE in hand, then HANDGUN, then UNARMED, pressing S, W, A, D
//      and sprint in turn. Expected from the animation config (owner 2026-09-16): W, A, D and sprint hold the
//      static drag state (the body does not move and the drag does NOT end), S walks backwards; going prone,
//      standing up (carry) and switching weapon leave the set and end it as anim-break. Record every anim=
//      value that appears while you are still dragging. If one is missing from the default list:
//        AP_dragCfg_validAnims = [<the recorded lowercase names>];
//      (AP_dragCfg_validAnimSubs is [] by default; a broad substring like "acinpknl" also accepts the prone
//      and carry transitions, so do not bring it back.)
//      A weapon set with no movement states: blank its pose, e.g. for unarmed
//        AP_dragCfg_poseAnims = [["rfl","AcinPknlMstpSrasWrflDnon"],["pst","AcinPknlMstpSnonWpstDnon"],["non",""]];
//      To compare the vanilla weapon-aware action path instead:  AP_dragCfg_pose = "action";
//      A missing configured state logs "[AP-PROBE] dragBody: pose anim ... is not in CfgMovesMaleSdr".
//   D4 detach settles, no fling. Release (scroll) while walking, on a slope, against a wall; the trace
//      runs 3 s past the release: bodyATL should settle within ~1 s with no metre-scale jump. Compare with
//      AP_dragCfg_zeroVel = false;  (setVelocity is argument-local, best-effort on a remote body).
//      CONTINUOUS CLAMP (owner 2026-09-16), with ["trace"] running:
//        WALL: stand about 1 m from a wall with the body hanging away from it, turn in place until you face the
//        wall. y= must drop toward need= within a tick or two and hit= must name the wall; the body's centre
//        stays on your side (limbs may still clip -- accepted). Turn away: y= grows back to nominal. Release
//        while facing the wall: the -DRAG- stop row ends " clamp=<y>/<nominal> m hit=..." and the body lies on
//        your side. Body past the wall after release = the fail (write down the row and the last trace lines;
//        whether a re-attach and a detach in one frame keep the new offset is part of this spike).
//        DOORWAY: drag a body out through a door, then turn in the doorway: the frame may shorten y (expected).
//        Watch for y= flicking up and down every tick against a flat wall: raise AP_dragCfg_clampHyst (it also
//        applies near the wall; only a body within 0.05 m of the hit re-welds regardless).
//        A body pulled in on open ground: read hit= (a prop, a fence post, terrain) and tune
//        AP_dragCfg_clampHeights / AP_dragCfg_clampMargin, or AP_dragCfg_clamp = false to compare without it.
//        a wrong refusal "You can't reach the body from there." is AP_dragCfg_reachLos = false;
//      STAIRS: drag a body DOWN a house staircase walking backwards and release mid-flight, then on the bottom
//        step. Expected: y= drops to clampMinY (0.5), or toward hit - 0.1 (0 at the least) when hit= is under 0.6 -- y= may
//        sit up to AP_dragCfg_clampHyst above need= but never within 0.05 m of hit= --, while the next
//        riser is in front of you. Record whether the
//        body lies ON the steps or sunk into them, flung, or fell through, and whether you can still aim Drag
//        Body / a defib at it. Then have a drone revive a body held mid-stairs: record where the player stands.
//        Height is NOT corrected by design; write down what happens.
//      VEHICLE: get in a car while dragging. Nothing extra runs on a "vehicle" stop (the last on-foot tick
//        clamped); record where the body lands (left outside, carried into the hull, flung), whether the car is
//        bumped, and the -DRAG- stop row.
//      Held body revived by a drone or an admin: face a fence first so the clamp holds the body short. The
//      player must stand up on YOUR side (fn_revived detaches and places him at the body; nothing moves it).
//   D5 the dead player's camera is not blocked by the dragger: judged by eye on the dead client during a
//      30 m drag. If the dragger fills the frame: ["offset", [0, 1.1, 0.092], 0] execVM ... and recheck.
//   D6 observers see the frozen body and the dragger pose: second client runs ["watch"] during a drag;
//      look at dragAnim (the dragger as the observer sees it) and att.
//   D7 dragger Alt-F4 mid-drag: the dead player (BEFORE dying, e.g. ["watch", 300]) or a third client runs
//      ["watch"] first. After the disconnect look for att=<NULL-object> with the body still present (good)
//      versus the body gone or bodyATL frozen in the air (float). The dead player's web screen stale sweep logs a [DEATHWEB] RPT
//      line and a -DRAG- row when it clears the flag (fn_deathState.sqf); the server log has
//      SELECT * FROM log WHERE tag='-DRAG-' ORDER BY ts DESC LIMIT 20;
//      Face a wall so the clamp holds the body short, then Alt-F4 (owner 2026-09-16): the body must stay on the
//      dragger's side -- nothing on the dead player's machine moves it any more, the sweep only detaches and
//      clears the flag. Body past the wall afterwards is the fail.
//   D8 setDir after a remote attachTo is global: dragger's trace rel= versus the observer's watch rel=
//      at the same moment. If they differ: AP_dragCfg_dirSync = true; re-drag and compare again; if still
//      different, AP_dragCfg_dir = -1; (drop setDir, cosmetic).
//   Every drag also leaves a -DRAG- start and stop row (server log) with reason= for the stop.
params [["_mode", "trace", [""]], ["_arg1", nil], ["_arg2", nil]];

private _keys = ["startDist", "offset", "dir", "dirSync", "selectPrimary", "selectWait", "pose", "poseAnims",
    "validAnims", "validAnimSubs", "grace", "desync", "tick", "zeroVel", "noPoseReset", "ownerStaleTicks", "ownerForceDetach",
    "reachLos", "losLift", "raceDetach", "flagNear",
    "clamp", "clampHeights", "clampMargin", "clampMinY", "clampHyst", "clampTerrain"];

switch (_mode) do {
    case "trace": {
        private _waitFor = if (isNil "_arg1") then {60} else {_arg1};
        private _t0 = diag_tickTime;
        diag_log format ["[AP-PROBE] drag trace armed, waiting up to %1 s for a drag (AP_dragDebug=%2)", _waitFor, missionNamespace getVariable ["AP_dragDebug", false]];
        waitUntil {uiSleep 0.1; !(isNull (missionNamespace getVariable ["AP_dragging", objNull])) || {(diag_tickTime - _t0) > _waitFor}};
        private _body = missionNamespace getVariable ["AP_dragging", objNull];
        if (isNull _body) exitWith {diag_log "[AP-PROBE] drag trace: no drag started, giving up";};
        // AP_dragging is the mutex from the first gate; the attach lands after the weapon wait.
        _t0 = diag_tickTime;
        private _fnc_line = {
            params ["_tag"];
            private _att = attachedTo _body;
            // owner 2026-09-16: CONTINUOUS CLAMP columns. currentY -1 = measure only, the probe never attaches.
            private _y = (missionNamespace getVariable ["AP_dragMeta", []]) param [11, -1];
            (["clamp", _body, player, -1, 0] call AP_fnc_dragBody) params ["_need", "", "_hitD", "_hitO"];
            private _hit = if (_hitD < 0) then {"-"} else {format ["%1@%2", if (isNull _hitO) then {"terrain"} else {typeOf _hitO}, _hitD toFixed 2]};
            diag_log format ["[AP-PROBE] drag %1 t=%2 anim=%3 att=%4 bodyATL=%5 dragATL=%6 dist=%7 dirBody=%8 dirDrag=%9 rel=%10 local=%11 y=%12 need=%13 hit=%14",
                _tag, (diag_tickTime - _t0) toFixed 2, toLower (animationState player), _att isEqualTo player,
                (getPosATL _body) apply {parseNumber (_x toFixed 2)}, (getPosATL player) apply {parseNumber (_x toFixed 2)},
                (player distance _body) toFixed 2, round (getDir _body), round (getDir player),
                round (((getDir _body) - (getDir player) + 360) % 360), local _body,
                if (_y isEqualType 0) then {_y toFixed 2} else {"?"}, _need toFixed 2, _hit];
        };
        while {!(isNull _body) && {(missionNamespace getVariable ["AP_dragging", objNull]) isEqualTo _body}} do {
            ["tick"] call _fnc_line;
            uiSleep ((missionNamespace getVariable ["AP_dragCfg_tick", 0.1]) max 0.05);
        };
        diag_log format ["[AP-PROBE] drag trace: drag over after %1 s, body %2", (diag_tickTime - _t0) toFixed 2, ["present", "gone"] select (isNull _body)];
        private _t1 = diag_tickTime;
        while {!(isNull _body) && {(diag_tickTime - _t1) < 3}} do {
            ["settle"] call _fnc_line;
            uiSleep 0.2;
        };
        diag_log "[AP-PROBE] drag trace done";
    };
    case "offset": {
        private _offset = if (isNil "_arg1") then {[0, 1.1, 0.092]} else {_arg1};
        private _dir = if (isNil "_arg2") then {180} else {_arg2};
        AP_dragCfg_offset = _offset;
        AP_dragCfg_dir = _dir;
        private _body = missionNamespace getVariable ["AP_dragging", objNull];
        // owner 2026-09-16: check and re-attach in one unscheduled block, so a Release Body landing in between
        // cannot have this weld the released body back on (the watchdog's clamp tick has the same guard).
        isNil {
            if (!(isNull _body) && {(attachedTo _body) isEqualTo player}) then {
                _body attachTo [player, _offset];
                if (_dir >= 0) then {
                    _body setDir _dir;
                    if (missionNamespace getVariable ["AP_dragCfg_dirSync", false]) then {_body setPosWorld (getPosWorld _body);};
                };
                // owner 2026-09-16: tell the clamp where the body hangs now (AP_dragMeta slot 11), so its next tick
                // measures from this y and re-welds if something is in front.
                private _meta = missionNamespace getVariable ["AP_dragMeta", []];
                if ((_meta isNotEqualTo []) && {(_offset param [1, -1]) isEqualType 0}) then {_meta set [11, _offset param [1, -1]];};
                diag_log format ["[AP-PROBE] drag offset applied live: offset=%1 dir=%2 dist=%3 rel=%4", _offset, _dir,
                    (player distance _body) toFixed 2, round (((getDir _body) - (getDir player) + 360) % 360)];
            } else {
                diag_log format ["[AP-PROBE] drag offset stored for the next drag: offset=%1 dir=%2 (no body attached now)", _offset, _dir];
            };
        };
        systemChat format ["drag offset=%1 dir=%2", _offset, _dir];
    };
    case "watch": {
        private _dur = if (isNil "_arg1") then {60} else {_arg1};
        private _t0 = diag_tickTime;
        diag_log format ["[AP-PROBE] drag watch start (%1 s, 60 m)", _dur];
        while {(diag_tickTime - _t0) < _dur} do {
            // owner 2026-09-16: while dead, `player` is the respawned unit at the base marker (respawnDelay=0),
            // so centre the scan on the own body and always include it.
            private _corpse = missionNamespace getVariable ["AP_corpse", objNull];
            private _ctr = if ((missionNamespace getVariable ["AP_isDead", false]) && {!(isNull _corpse)}) then {_corpse} else {player};
            private _set = allDeadMen select {(_x distance _ctr) <= 60};
            if ((missionNamespace getVariable ["AP_isDead", false]) && {!(isNull _corpse)}) then {_set pushBackUnique _corpse;};
            {
                private _b = _x;
                private _db = _b getVariable ["AP_draggedBy", []];
                private _att = attachedTo _b;
                if ((_db isNotEqualTo []) || {!(isNull _att)}) then {
                    private _holder = _att;
                    if ((isNull _holder) && {_db isEqualType []} && {(count _db) > 0} && {(_db select 0) isEqualType objNull}) then {_holder = _db select 0;};
                    private _bPos = (getPosATL _b) apply {parseNumber (_x toFixed 2)};
                    private _hPos = [];
                    private _hAnim = "";
                    private _hDir = -1;
                    private _rel = -1;
                    if !(isNull _holder) then {
                        _hPos = (getPosATL _holder) apply {parseNumber (_x toFixed 2)};
                        _hAnim = toLower (animationState _holder);
                        _hDir = round (getDir _holder);
                        _rel = round (((getDir _b) - (getDir _holder) + 360) % 360);
                    };
                    diag_log format ["[AP-PROBE] drag watch t=%1 body=%2 name=%3 att=%4 flag=%5 bodyATL=%6 holderATL=%7 dragAnim=%8 dirBody=%9 dirHolder=%10 rel=%11 local=%12",
                        (diag_tickTime - _t0) toFixed 2, _b, _b getVariable ["AP_name", ""], _att, _db,
                        _bPos, _hPos, _hAnim, round (getDir _b), _hDir, _rel, local _b];
                };
            } forEach _set;
            uiSleep 0.2;
        };
        diag_log "[AP-PROBE] drag watch done";
    };
    case "cfg": {
        {
            private _v = missionNamespace getVariable [format ["AP_dragCfg_%1", _x], nil];
            if !(isNil "_v") then {diag_log format ["[AP-PROBE] drag cfg AP_dragCfg_%1 = %2", _x, _v];};
        } forEach _keys;
        diag_log format ["[AP-PROBE] drag cfg SRV_dragBodyEnabled=%1 AP_dragDebug=%2 AP_dragging=%3 AP_dragMeta=%4",
            missionNamespace getVariable ["SRV_dragBodyEnabled", true], missionNamespace getVariable ["AP_dragDebug", false],
            missionNamespace getVariable ["AP_dragging", objNull], missionNamespace getVariable ["AP_dragMeta", []]];
        systemChat "drag cfg written to the RPT";
    };
    case "reset": {
        {missionNamespace setVariable [format ["AP_dragCfg_%1", _x], nil];} forEach _keys;
        diag_log "[AP-PROBE] drag cfg overrides cleared";
        systemChat "drag cfg overrides cleared";
    };
    default {systemChat format ["probe_drag: unknown mode %1 (trace | offset | watch | cfg | reset)", _mode];};
};
