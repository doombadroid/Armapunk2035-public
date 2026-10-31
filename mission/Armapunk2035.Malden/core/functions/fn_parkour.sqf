/*
    AP_fnc_parkour -- what the GetOver key (V by default) does on foot (owner 2026-09-16: parkour =
    vault + mantle + drop, wall run behind the Reflex Tuning implant; plan "Feature A").

        if (_code in (actionKeys "GetOver") && {[] call AP_fnc_parkour}) exitWith {true};

    CALLED, NEVER SPAWNED, and ALWAYS RETURNS A BOOL. It runs inside evh/fn_keyDownHandler.sqf, an
    unscheduled display KeyDown handler, and the engine reads the handler's result in the same frame:
    true swallows the key, false lets the engine run its own step-over. Nothing in here or in
    AP_fnc_parkourProbe may sleep or wait. The long-running part is AP_fnc_parkourMove, spawned.

    THE MUTEX IS SET HERE, SYNCHRONOUSLY. AP_parkourState goes from "idle" to the move name, and
    AP_action_in_use to true, in the same unscheduled frame as the keypress and BEFORE the mover is
    spawned -- a spawned script may not start for a frame or more, and a second V (key repeat fires
    KeyDown again while the key is held) or a scroll action landing in that gap would otherwise start
    a second move or grab the animation. AP_action_in_use is the fastRope pattern: the key handler's
    general gate and the action menu stay out for the whole move. That gate returns nil, NOT true, so
    it does not stop the engine's own GetOver: a V pressed mid-move is swallowed by its own line in
    fn_keyDownHandler.sqf, keyed on AP_parkourState, just above that gate. AP_parkourSerial ties the
    flags to this particular move (see fn_parkourMove.sqf's header, "THE SERIAL").

    THE PLAYER IS FROZEN HERE TOO (owner 2026-09-16, review round 1). The helper is created and the
    player attached at offset [0,0,attachZ] in this same frame, before the spawn. The probe measured
    every distance from the feet at the keypress; a spawned mover starts a frame or more later, and a
    sprinter covered 0.1-0.4 m in that gap, then was snapped back to the keypress spot when the mover
    attached him. The helper goes to the mover as its 4th argument and into AP_parkourHelper at once,
    so the mover's guard and the respawn reset can already delete it.

    ONE MOVE PER PHYSICAL PRESS (owner 2026-09-16, review round 1). OS key repeat fires KeyDown ~30x a
    second while V is held, and the cooldown alone let a held V start the next move the moment it ran
    out (and queue a notice per repeat at a refused ledge). AP_parkourLatch marks a press that was
    consumed (a move started, a notice shown, or the step-over guard below swallowed it), and every
    KeyDown of that same press returns true without probing.
    owner 2026-09-16, review round 2: WHAT ENDS A PRESS IS A RELEASE, NOT A GAP. Round 1 called any
    KeyDown more than 0.15 s after the previous one a new press, but the OS waits 250-1000 ms before
    the FIRST repeat (600-660 ms on X11/Hyprland under Proton), so a move that was idle again before
    that delay (an early abort, a short drop) had its first repeat read as a new press, and a held V
    retried the move every cooldown. Now a small display-46 KeyUp handler, added here on the first V
    press (AP_parkourUpEH), stamps AP_parkourUpV, and a KeyDown is a new press only when:
      - a V KeyUp came after the previous V KeyDown, at least latchRepeatGap before this one (X11
        without detectable autorepeat sends a release+press PAIR per repeat, in the same instant), or
      - no V KeyDown for latchStaleTime (a release made while a dialog or the map had focus never
        reaches display 46; longer than any OS repeat delay).
    The swallow line in fn_keyDownHandler.sqf refreshes AP_parkourLastV mid-move, so repeats held
    through a whole move are still the same press afterwards, and so is a V pressed mid-move and held.
    A new press during a cooldown clears the latch, so press-early-and-hold still fires when it ends.
    AP_parkourCfg_latchRepeatGap = 0 turns the latch off. Unmeasured (spike): whether Proton delivers
    one KeyUp per physical release -- `debug\probe_parkour.sqf "keys"` logs the V KeyDown/KeyUp stream.

    KILL SWITCH FIRST. SRV_parkourEnabled (server_init.sqf, publicVariable'd, read with a default of
    TRUE so a client that joins before the publish behaves as "on"). False = exactly the binding this
    replaced: running faster than 10 km/h -> AP_fnc_jump (the old 0.32 m running hop) and true,
    otherwise false.

    RETURN RULES
      - kill switch off                    -> old binding (above)
      - repeat of a consumed press         -> true  (the latch above)
      - a move is already running          -> true  (V mid-move is ignored). Normally unreachable: the
                                              GetOver swallow line in fn_keyDownHandler.sqf returns true
                                              for any V while AP_parkourState is not idle, before this call.
      - cooldown not over                  -> true  (no hop spam; a new press here clears the latch)
      - any entry guard fails              -> old binding. V behaves as it always did when parkour
                                              does not apply (in a dialog, carrying a barrel, ...).
      - probe "none"                       -> AP_fnc_jump + true above 10 km/h (the hop on open
                                              ground), else false so the engine step-over runs.
                                              When the probe has a message ("Too far down to
                                              drop.") it is shown (the same text at most once per
                                              msgRepeatTime) and latches the press, and a standing
                                              player gets true instead of false: the engine
                                              step-over at a refused ledge would walk them off it.
                                              owner 2026-09-16 (review round 2): the same for a
                                              silent "none" whose STEP-OVER GUARD failed (probe
                                              data "stepUnsafe"): the engine step-over walks ~1.5 m
                                              along FACING, which neither the strafe frame nor a
                                              silent drop refusal (slope, headroom, overhead,
                                              someone below) had checked. true + latched, no text,
                                              except (review round 3) a player standing too far
                                              back from a drop the probe found valid ("dropAhead"):
                                              "Get closer to the edge to drop." (cfg dropCloserMsg,
                                              same throttle; "" = silent).
      - probe found a move                 -> state + flags set, player frozen on the helper, mover
                                              spawned, press latched, true.

    ENTRY GUARDS, each against the variable's real storage (verified 2026-09-16):
      missionNamespace globals seeded in configuration.sqf: AP_isDead, AP_isDowned, AP_action_in_use,
        AP_fastRoping (:359), AP_autoRun, AP_sittingChair, AP_holding_barrel, AP_object_inhand,
        AP_escort, AP_dragging, AP_parkourState, AP_parkourNext, AP_parkourSerial (line 2, seeded 0)
        -- still read through getVariable defaults where a nil would throw, because a KeyDown
        handler that errors eats every key.
      missionNamespace, NOT seeded (nil until first set): AP_spawnHold (initPlayerLocal.sqf:8),
        AP_spawnSettling (fn_initCiv / fn_spawnConfirm), AP_parkourLatch, AP_parkourLastV,
        AP_parkourUpV, AP_parkourUpEH, AP_parkourMsgLast, AP_parkourMsgNext (the press latch, its KeyUp
        hook and the notice throttle; this file owns them).
      player object variables: AP_downed, AP_restrained, AP_civRestrained, AP_surrendered (public),
        AP_inAnim (local; the emote flag fn_handleAnim toggles).
    Added beyond the plan's list, each because the glide would break without it: attachedTo player
    must be null (being escorted / seated / roped -- a unit cannot be attached to two parents),
    AP_escort must be null (the escortee hangs off the player), and stance must be STAND or CROUCH
    (PRONE and UNDEFINED -- swimming, ladders -- have no parkour).

    Never touches enableSimulation, forceWalk, enableStamina, allowDamage or AP_holstered.
*/
private _legacy = {
    if ((speed player) > 10) then {[] call AP_fnc_jump; true} else {false}
};

if !(missionNamespace getVariable ["SRV_parkourEnabled", true]) exitWith {call _legacy};

// owner 2026-09-16 (review round 2): the per-press latch ends on a release (header, "ONE MOVE PER PHYSICAL PRESS").
// The KeyUp hook goes on display 46 once, on the first V press, so its own release is already seen. Display EHs run
// last-added first and a KeyUp return cannot override anything, so fn_keyUpHandler is unaffected. -1 = retry.
if ((missionNamespace getVariable ["AP_parkourUpEH", -1]) < 0) then {
    AP_parkourUpEH = (findDisplay 46) displayAddEventHandler ["KeyUp", {
        if ((_this select 1) in (actionKeys "GetOver")) then {AP_parkourUpV = diag_tickTime};
        false
    }];
};
private _vNow = diag_tickTime;
private _vLast = missionNamespace getVariable ["AP_parkourLastV", -1e9];
private _vUp = missionNamespace getVariable ["AP_parkourUpV", -1e9];
private _vRepeatGap = ["latchRepeatGap"] call AP_fnc_parkourCfg;
AP_parkourLastV = _vNow;
if ((_vRepeatGap <= 0)
    || {(_vUp > _vLast) && {(_vNow - _vUp) >= _vRepeatGap}}
    || {(_vNow - _vLast) >= (["latchStaleTime"] call AP_fnc_parkourCfg)}) then {AP_parkourLatch = false};
if (missionNamespace getVariable ["AP_parkourLatch", false]) exitWith {true};

if !((missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "idle") exitWith {true};
if (diag_tickTime < (missionNamespace getVariable ["AP_parkourNext", 0])) exitWith {true};

private _inHand = missionNamespace getVariable ["AP_object_inhand", objNull];
private _blocked = !(alive player)
    || {missionNamespace getVariable ["AP_isDead", false]}
    || {missionNamespace getVariable ["AP_isDowned", false]}
    || {player getVariable ["AP_downed", false]}
    || {player getVariable ["AP_restrained", false]}
    || {player getVariable ["AP_civRestrained", false]}
    || {player getVariable ["AP_surrendered", false]}
    || {!(isNull (objectParent player))}
    || {!(isNull (attachedTo player))}
    || {missionNamespace getVariable ["AP_action_in_use", false]}
    || {missionNamespace getVariable ["AP_fastRoping", false]}
    || {missionNamespace getVariable ["AP_autoRun", false]}
    || {player getVariable ["AP_inAnim", false]}
    || {!(isNull (missionNamespace getVariable ["AP_sittingChair", objNull]))}
    || {!(isNull (missionNamespace getVariable ["AP_holding_barrel", objNull]))}
    || {!(_inHand isEqualType objNull) || {!(isNull _inHand)}}
    || {!(isNull (missionNamespace getVariable ["AP_escort", objNull]))}
    || {!(isNull (missionNamespace getVariable ["AP_dragging", objNull]))}
    || {missionNamespace getVariable ["AP_spawnHold", false]}
    || {missionNamespace getVariable ["AP_spawnSettling", false]}
    || {!(simulationEnabled player)}
    || {dialog}
    || {visibleMap}
    || {!((stance player) in ["STAND", "CROUCH"])}
    || {(surfaceIsWater (getPosASL player)) && {((getPosASLW player) select 2) < (["waterFeetZ"] call AP_fnc_parkourCfg)}}
    || {!(isTouchingGround player)};
if (_blocked) exitWith {call _legacy};

private _res = [] call AP_fnc_parkourProbe;
_res params [["_kind", "none", [""]], ["_data", createHashMap, [createHashMap]], ["_msg", "", [""]]];

if (_kind isEqualTo "none") exitWith {
    // owner 2026-09-16 (review round 1): handleMessage has no dedupe and a "basic" notice stays >= 7 s, so
    // the same refusal is not re-queued while the last one is still on screen.
    private _fnc_notice = {
        params ["_text"];
        if (!((missionNamespace getVariable ["AP_parkourMsgLast", ""]) isEqualTo _text)
            || {diag_tickTime >= (missionNamespace getVariable ["AP_parkourMsgNext", 0])}) then {
            AP_parkourMsgLast = _text;
            AP_parkourMsgNext = diag_tickTime + (["msgRepeatTime"] call AP_fnc_parkourCfg);
            [_text, "basic"] spawn AP_fnc_handleMessage;
        };
    };
    if !(_msg isEqualTo "") then {
        [_msg] call _fnc_notice;
        AP_parkourLatch = true;
    };
    call {
        if ((speed player) > 10) exitWith {[] call AP_fnc_jump; true};
        if !(_msg isEqualTo "") exitWith {true};
        // owner 2026-09-16 (review round 2): the engine step-over would walk off the ledge the probe's guard found
        // along facing (header, RETURN RULES). Swallowed, latched so a held V does not re-probe per repeat.
        // owner 2026-09-16 (review round 3): no longer always silent. Standing too far back from a drop the probe
        // measured as valid ("dropAhead") shows fn_parkourCfg "dropCloserMsg" ("" = silent). Here, after the running
        // hop, so a runner never gets the notice with his hop.
        if ((_data getOrDefault ["stepUnsafe", -1]) >= 0) exitWith {
            private _hint = ["dropCloserMsg"] call AP_fnc_parkourCfg;
            if ((_data getOrDefault ["dropAhead", false]) && {!(_hint isEqualTo "")}) then {[_hint] call _fnc_notice};
            AP_parkourLatch = true;
            true
        };
        false
    }
};

private _serial = (missionNamespace getVariable ["AP_parkourSerial", 0]) + 1;
AP_parkourSerial = _serial;
AP_parkourState = _kind;
AP_action_in_use = true;
AP_parkourLatch = true;

// owner 2026-09-16 (review round 1): freeze the player on the helper in THIS frame (header, "THE PLAYER IS FROZEN
// HERE TOO"). Same five lines the mover used to run on its first slice; the helper faces the move (t for a wall run).
private _P = _data getOrDefault ["P", getPosASL player];
private _f = _data getOrDefault ["f", [0, 1, 0]];
private _dirVec = if (_kind isEqualTo "wallrun") then {_data getOrDefault ["t", _f]} else {_f};
private _helper = createVehicle ["Land_ClutterCutter_small_F", getPosATL player, [], 0, "CAN_COLLIDE"];
_helper setVectorDirAndUp [_dirVec, [0, 0, 1]];
_helper setPosASL _P;                     // after the direction, so the orientation is networked with it
AP_parkourHelper = _helper;
player setVelocity [0, 0, 0];
player attachTo [_helper, [0, 0, ["attachZ"] call AP_fnc_parkourCfg]];
player setDir 0;                          // attached: direction is relative to the helper, which faces the move

[_kind, _data, _serial, _helper] spawn AP_fnc_parkourMove;
true
