/*
    AP_fnc_dragBodyStop -- the one release path for a body drag (owner 2026-09-16).

    [reason] call AP_fnc_dragBodyStop            any caller: "Release Body", fn_onPlayerKilled ("killed"),
                                                 fn_handleDowned ("downed")
    [reason, token] call AP_fnc_dragBodyStop     the watchdog in AP_fnc_dragBody: acts only if the drag it
                                                 was watching (token = AP_dragMeta select 1) is still the
                                                 current one, so a late watchdog can never end a newer drag

    CONTRACT. Idempotent: safe to call when nothing is being dragged (returns false, does nothing). Safe
    UNSCHEDULED: no sleep, no uiSleep, no waitUntil -- fn_onPlayerKilled and fn_handleDowned call it
    inline, and everything that has to reach another machine is spawned. The whole body runs inside
    isNil { }, so a scheduled caller cannot be interleaved with the watchdog or a death hook halfway
    through a release.

    SYMMETRIC INTERLOCK (owner 2026-09-16). A body is either being revived or being dragged, never both.
    Whichever started first holds it; the other is refused with a message. The sub-second race is
    resolved in the revive's favour: the drag's watchdog re-checks AP_reviving and self-releases
    ("revive-won"). Admin/drone/hospital revives, which bypass fn_revivePlayer, are covered by a detach
    guard in fn_revived (the watchdog then ends here as "detached-externally").

    ORDER, and why:
      1. AP_dragging = objNull and AP_dragMeta = [] FIRST. Parkour and the scroll actions key on
         AP_dragging, and the watchdog keys on the meta token; clearing them first is what makes a second
         call a no-op.
      2. detach only if the body hangs off THIS client's dragger. respawnDelay=0 means that inside the
         spawned fn_onPlayerKilled `player` is already the new unit while the body is still attached to
         the old one, so both `player` and the meta's dragger unit count as "ours". Detach is argument-
         and effect-global; one machine is enough. setVelocity [0,0,0] afterwards is best-effort only:
         it is argument-LOCAL and the body is usually remote (SPIKE D4).
         TWO-DRAGGER RACE (owner 2026-09-16). The "nobody holds it" gate in fn_dragBody is local, so two
         players who commit within one network round trip both attach; each then receives the other's
         attach last, sees the body on the OTHER player and stops as "detached-externally". Detaching
         only when the holder is ours left the body welded to a living player with no watchdog, no
         Release Body, and every medic refused. So a "detached-externally" stop whose holder is a LIVING
         CAManBase that is not ours detaches too, and clears AP_draggedBy. Only the race produces a living
         foreign holder mid-drag (the Drag Body gate refuses an attached body), so a normal drag never
         takes this branch.
         LATE DETACH (owner 2026-09-16). The CONTINUOUS CLAMP lets a racer send more attaches (re-welds)
         after his first, and nothing orders a re-weld ahead of the other racer's detach. A racer whose
         machine already reads the body unattached (the other's attach and detach both landed between two
         of his ticks) would send nothing, leaving his late re-weld as the last word everywhere else. So a
         "detached-externally" stop of a drag that actually started (meta non-empty) that finds the body
         unattached HERE detaches anyway (AP_dragCfg_raceDetach), and the row notes " lateDetach=true".
         So every "detached-externally" stop of a started drag that finds the body unattached here, or on a
         living foreign man, ends with this client's own detach, sent after all of its re-welds. Stops for
         other reasons (released, killed, downed, vehicle ...) send no late detach; a re-weld that lands
         after the other racer's detach in that narrower window is an accepted residual. On fn_revived's
         guard and an admin detach the late detach is a no-op where the body is already free and clears
         a late re-weld of ours where one landed; every such revive therefore also logs " lateDetach=true".
         A third player who attached in that gap loses his drag ("pulled out of your grip") and can retry.
         FINAL CLAMP (owner 2026-09-16). Before the detach from OUR dragger (never before the late detach,
         which only runs on a body that already reads unattached), while the body still hangs off OUR dragger and he
         is alive and on foot, the CONTINUOUS CLAMP runs once more with no hysteresis (["clamp", ...] call
         AP_fnc_dragBody, see its header): the rays from his rendered position and facing, and a re-attach at
         the needed y, then the detach. Nothing is setPos'd: the corpse is local to its owner, not here, and a
         remote setPos on a ragdoll is what desyncs corpses or drops them under the map. A dead dragger
         ("killed"), a seated one ("vehicle": the last on-foot tick already clamped), a race detach of the
         other player's hold and a late detach get the detach alone. Whether a re-attach and a detach in the same frame land the
         body at the new offset is SPIKE D4; the row's " clamp=..." note says what was asked for. Escort
         (fn_escortAction / fn_stopEscorting) has the same attach-through-walls shape and is NOT covered.
         VEHICLE: the GetInMan hook that would release on the entry frame instead of the next watchdog tick
         belongs in evh\fn_getInMan.sqf (not part of this feature's files).
      3. AP_draggedBy is cleared only if its element 0 is ours. A newer dragger's name is never wiped.
      4. Pose reset only while the dragger is still `player`, alive, on foot, the reason is not in the
         no-reset list, and the unit is STILL in a drag state. Each of those protects another flow's
         animation: killed (the new unit must not be touched), downed (a remote stand-idle mirror would
         arrive after setUnconscious and stand a downed player up on observers' screens), restrained
         (the cuff animation already replaced ours), anim-break (the player already left the drag pose:
         prone, carry, stance or weapon change), vehicle / underwater (not a standing pose to return to).
         "switchMove" pose: local switchMove "" (fn_execute.sqf's idiom) and a weapon-appropriate STAND
         idle mirrored to <= 30 m through AP_fnc_animSync (never "", fn_animSync exits on it).
         "action" pose: playActionNow "released" (global effect by BIKI, no mirror needed).
      5. -DRAG- stop row, only if the drag had actually started (meta non-empty): straight and path
         metres from the dragger's positions, seconds, reason; the logged position is the body's where it
         was let go (the dragger's if the body is gone). The server stamps @CTX and @SRC. The row ends with
         " clamp=<y>/<nominal> m hit=<what> at <d> m" when the final clamp held the body short of nominal,
         and " holder=... raceDetach=..." (or " lateDetach=true" when the body was already unattached and AP_dragCfg_raceDetach
         is on) on a detached-externally stop, so the owner can see whether any of them ever fires in play.
         A lateDetach row next to a -REVIVE- row for the same body is the revive path, not a race.

    REASONS: released, body-gone, disabled, killed, revive-won, downed, restrained, vehicle, underwater,
    detached-externally, desync, anim-break (see AP_fnc_dragBody's header).

    LIVE TOGGLES (missionNamespace, debug console):
      AP_dragCfg_zeroVel       (true)  setVelocity [0,0,0] on the body after detach (SPIKE D4)
      AP_dragCfg_noPoseReset   (["restrained","vehicle","underwater","anim-break"])  reasons that skip
                               the pose reset; "killed" and "downed" always skip and cannot be removed
      AP_dragCfg_raceDetach    (true)  step 2's two-dragger race detach and late detach; false = only ever
                               detach from ours
      AP_dragCfg_clamp / clampHeights / clampMargin / clampMinY / clampTerrain  the final clamp's rays and
                               bounds, shared with AP_fnc_dragBody's watchdog (see its header; clampHyst is not
                               used here, the final clamp has none)
      AP_dragDebug             (false) one [AP-PROBE] line per stop
*/
params [["_reason", "released", [""]], ["_token", -1, [0]]];

private _did = false;
isNil {
    private _body = missionNamespace getVariable ["AP_dragging", objNull];
    private _meta = missionNamespace getVariable ["AP_dragMeta", []];
    if !(_body isEqualType objNull) then {_body = objNull};
    if !(_meta isEqualType []) then {_meta = []};
    // Nothing held and nothing started: not dragging.
    if (isNull _body && {_meta isEqualTo []}) exitWith {};
    // A watchdog whose drag has already been replaced or released.
    if ((_token isNotEqualTo -1) && {(_meta param [1, -2]) isNotEqualTo _token}) exitWith {};

    // 1.
    AP_dragging = objNull;
    AP_dragMeta = [];
    _did = true;

    // A deleted body reads objNull from both places; the meta copy only helps if AP_dragging was cleared
    // by something that is not this function.
    if (isNull _body) then {_body = _meta param [6, objNull]};
    private _dragger = _meta param [8, objNull];
    if !(_dragger isEqualType objNull) then {_dragger = objNull};
    if (isNull _dragger) then {_dragger = player};
    private _ours = [player, _dragger];

    private _endPos = [];
    private _note = "";
    if !(isNull _body) then {
        // 2.
        private _att = attachedTo _body;
        // owner 2026-09-16: TWO-DRAGGER RACE (header step 2).
        private _raced = (_reason isEqualTo "detached-externally")
            && {!(isNull _att)} && {!(_att in _ours)} && {_att isKindOf "CAManBase"} && {alive _att}
            && {missionNamespace getVariable ["AP_dragCfg_raceDetach", true]};
        if (!(isNull _att) && {(_att in _ours) || {_raced}}) then {
            // owner 2026-09-16: FINAL CLAMP (header step 2) -- our living, on-foot dragger only. The clamp re-welds
            // the body at the needed y whenever it differs from the current one (no hysteresis); unknown current
            // (no meta) counts as 0 so the re-weld still happens. No suspension in there, safe inside this isNil.
            if ((_att in _ours) && {alive _att} && {isNull objectParent _att}) then {
                private _cur = _meta param [11, 0];
                if !(_cur isEqualType 0) then {_cur = 0};
                (["clamp", _body, _att, _cur max 0, 0] call AP_fnc_dragBody) params ["_needY", "", "_hitD", "_hitO", "", "_nomY"];
                if (_needY < _nomY) then {
                    _note = format [" clamp=%1/%2 m hit=%3 at %4 m", _needY toFixed 2, _nomY toFixed 2,
                        if (isNull _hitO) then {"terrain"} else {typeOf _hitO}, _hitD toFixed 2];
                };
            };
            detach _body;
            if (missionNamespace getVariable ["AP_dragCfg_zeroVel", true]) then {_body setVelocity [0, 0, 0];};
        };
        // owner 2026-09-16: LATE DETACH (header step 2). A started drag broken from outside whose body already reads
        // unattached here still sends a detach, so this client's last message about the body is a detach and not
        // an earlier clamp re-weld that could reach other machines after the other racer's detach.
        if ((_meta isNotEqualTo []) && {_reason isEqualTo "detached-externally"} && {isNull _att}
            && {missionNamespace getVariable ["AP_dragCfg_raceDetach", true]}) then {
            detach _body;
            _note = _note + " lateDetach=true";
        };
        if (_raced) then {_body setVariable ["AP_draggedBy", nil, true];};
        if ((_reason isEqualTo "detached-externally") && {!(isNull _att)}) then {
            _note = _note + format [" holder=%1 raceDetach=%2", if (_att isKindOf "CAManBase") then {name _att} else {typeOf _att}, _raced];
        };
        // 3.
        private _db = _body getVariable ["AP_draggedBy", []];
        if ((_db isEqualType []) && {(_db param [0, objNull]) in _ours}) then {_body setVariable ["AP_draggedBy", nil, true];};
        _endPos = getPosATL _body;
    };

    // 4.
    private _pose = _meta param [7, ""];
    if ((_pose isNotEqualTo "")
        && {player isEqualTo _dragger}
        && {alive player}
        && {isNull objectParent player}
        && {!(_reason in ["killed", "downed"])}
        && {!(_reason in (missionNamespace getVariable ["AP_dragCfg_noPoseReset", ["restrained", "vehicle", "underwater", "anim-break"]]))}) then {
        private _anim = toLower (animationState player);
        private _list = _meta param [9, []];
        private _subs = _meta param [10, []];
        if ((_anim in _list) || {(_subs findIf {(_anim find _x) > -1}) > -1}) then {
            if (_pose isEqualTo "action") then {
                player playActionNow "released";
            } else {
                player switchMove "";
                private _cw = currentWeapon player;
                private _idle = call {
                    if (_cw isEqualTo "") exitWith {"AmovPercMstpSnonWnonDnon"};
                    if (_cw isEqualTo (primaryWeapon player)) exitWith {"AmovPercMstpSrasWrflDnon"};
                    if (_cw isEqualTo (handgunWeapon player)) exitWith {"AmovPercMstpSrasWpstDnon"};
                    "AmovPercMstpSnonWnonDnon"
                };
                [[player, _idle], "AP_fnc_animSync", allPlayers select {!(_x isEqualTo player) && {(_x distance player) <= 30}}, false] spawn AP_fnc_MP;
            };
        };
    };

    // 5. (and the player-facing line) -- only for a drag that actually started
    if (_meta isNotEqualTo []) then {
        private _here = getPosATL _dragger;
        if (_endPos isEqualTo []) then {_endPos = _here};
        private _secs = diag_tickTime - (_meta param [1, diag_tickTime]);
        private _path = (_meta param [2, 0]) + (_here vectorDistance (_meta param [5, _here]));
        private _straight = _here vectorDistance (_meta param [0, _here]);
        [["-DRAG-", player, profileName, format ["released %1 (%2) at %3 after %4 s, moved %5 m (path %6 m), reason=%7%8",
            _meta param [3, "?"], _meta param [4, "?"], _endPos apply {round _x}, round _secs, _straight toFixed 1, _path toFixed 1, _reason, _note]],
            "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;

        private _msg = switch (_reason) do {
            case "released": {"You let go of the body."};
            case "anim-break": {"You let go of the body."};
            case "body-gone": {"The body is gone."};
            case "revive-won": {"Someone is reviving this person -- you let go."};
            case "detached-externally": {"The body was pulled out of your grip."};
            case "desync": {"You lost your grip on the body."};
            case "disabled": {"Body dragging was switched off -- you let go."};
            case "underwater": {"You let go of the body in the water."};
            default {""};
        };
        if (_msg isNotEqualTo "") then {[_msg, "basic"] spawn AP_fnc_handleMessage;};

        if (missionNamespace getVariable ["AP_dragDebug", false]) then {
            diag_log format ["[AP-PROBE] dragBodyStop reason=%1 body=%2 attachedTo=%3 pose=%4 anim=%5 player=%6 dragger=%7 secs=%8 path=%9",
                _reason, _body, (if (isNull _body) then {objNull} else {attachedTo _body}), _pose, animationState player, player, _dragger, round _secs, _path toFixed 1];
        };
    };
};

_did
