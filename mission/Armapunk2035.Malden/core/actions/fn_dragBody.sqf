/*
    AP_fnc_dragBody -- drag a dead player's body until its owner respawns (owner 2026-09-16).

    [body] spawn AP_fnc_dragBody        (the "Drag Body" scroll action, core\fn_setupActions.sqf)

    WHAT IT DOES. The body is attachTo'd to the dragger at a fixed offset and the dragger is put in
    the vanilla drag pose; from then on the body goes wherever the dragger walks, and the dead player's
    death camera follows it with no change (fn_deathCamera recomputes from AP_corpse's visual position
    every frame). A watchdog on this client ends the drag. AP_fnc_dragBodyStop is the ONE release path.
    Nothing here pays, punishes or times anything, so it is client-local by design: no server function,
    no CfgRE entry. The server's part is the -DRAG- log row, whose @SRC it stamps from
    remoteExecutedOwner, so identity in the log is server-verified.

    THE SCROLL CONDITION IS UX; THIS FUNCTION IS THE GATE. Every condition is re-run here with a
    message, and re-run a second time (atomically, inside isNil) after the weapon wait, because two
    seconds is long enough for a medic to start a revive or for the body to be deleted.

    SYMMETRIC INTERLOCK (owner 2026-09-16). A body is either being revived or being dragged, never both.
    Whichever started first holds it; the other is refused with a message. The sub-second race is
    resolved in the revive's favour: the drag's watchdog re-checks AP_reviving and self-releases
    ("revive-won"). Admin/drone/hospital revives, which bypass fn_revivePlayer, are covered by a detach
    guard in fn_revived. The same sentence is in fn_revivePlayer's guard and fn_dragBodyStop's header.
    The watchdog checks AP_reviving on EVERY tick, not only the first: the medic's public flag can land
    here later than the first tick after the attach, and the rule it enforces is the same either way.

    PLAYER BODIES ONLY. The body must carry AP_steamid (stamped core\init.sqf and fn_onPlayerRespawn).
    Animals and NPC corpses are out of scope. AP_dragDebug = true relaxes this to any dead CAManBase (a
    dead mission AI, if one is at hand; createUnit is disabled everywhere, so a spike body is normally a second client).

    GROUND TRUTH. `attachedTo body` is the truth for "being dragged". The public AP_draggedBy flag on the
    body -- [draggerObject, draggerName] -- only supplies the name (fn_deathState, fn_deathScreen). The
    flag is published BEFORE the attach so a reader never sees an attached body with no name for long;
    fn_deathState's owner-side sweep and step 2 below clear a flag that outlived its drag.
    owner 2026-09-16: step 2 clears only a flag whose dragger is gone -- null, dead, not a man, this player,
    or further than AP_dragCfg_flagNear from the body. A flag naming a living man near the body may be a
    drag whose attach has not reached this machine yet (flag and attach propagate independently), and
    wiping it would switch off fn_revivePlayer's "being moved" refusal and the owner sweep for that whole
    drag. Such a flag is left alone; the commit re-checks attachedTo, refuses a flag that ARRIVED during
    the weapon wait, and otherwise overwrites it with this player's own.

    DRAGGER STATE. A drag does NOT set AP_action_in_use (that swallows keys and blocks vehicle entry);
    it is a free-move state. Mutual exclusion with other movers is by contract:
      - AP_dragging (objNull when not dragging) -- parkour entry refuses unless it is null.
      - AP_parkourState ("idle" when no parkour move runs) -- a drag refuses unless it is "idle".
      - AP_escort -- a player holds at most one of AP_escort / AP_dragging (mirror guard in
        fn_escortAction).
    AP_dragging is taken as the mutex IMMEDIATELY after the first gate, before the weapon wait, so a
    second activation during the wait is refused and parkour stays out. AP_dragMeta is filled only once
    the body is actually attached, and "meta empty" is how AP_fnc_dragBodyStop knows nothing was
    published and nothing needs logging (a release during the wait is a silent cancel).
    The lock records only the BODY, so two attempts on the same body (Release Body then Drag Body again
    inside the weapon wait) both look like its owner (owner 2026-09-16). Three rules keep a refused one
    from breaking the one that attached: the lock is taken check-and-set inside isNil; the commit stands
    down silently when AP_dragMeta is already filled; and a refused attempt gives the lock back only
    while AP_dragMeta is still empty.
    BUSY STATES (owner 2026-09-16): the same ones parkour refuses on -- seated on a chair, a timed emote
    (AP_inAnim), autorun, carrying a barrel. Each has its own key handler or timer that knocks the player
    out of the drag pose, which would end the drag as "anim-break" on the first step.

    AP_dragMeta LAYOUT (dragger-client global, local only):
      0 startPosATL (dragger)   1 startTick (diag_tickTime; also the drag's TOKEN)   2 pathMetres
      3 bodyName                4 bodyUID                                            5 lastPosATL (dragger)
      6 body object             7 pose applied: "" | "switchMove" | "action"         8 dragger unit
      9 valid anim list (snapshot, lowercase)                                        10 valid anim substrings
     11 current attach y -- the offset y the body is welded at right now: nominal, or shorter while the
        CONTINUOUS CLAMP holds it in. Written by the commit and by every clamp re-attach; the watchdog and
        fn_dragBodyStop hand it to the clamp as its currentY. owner 2026-09-16
    The dragger UNIT is kept because respawnDelay=0 (description.ext): by the time the spawned
    fn_onPlayerKilled runs, `player` is already the NEW unit and the body hangs off the OLD one. The stop
    matches either.

    WATCHDOG (spawned below, uiSleep AP_dragCfg_tick, while AP_dragMeta's token is this drag). Stops with a reason:
      body-gone            body deleted (owner respawned / revived / reaper / owner disconnect)
      disabled             SRV_dragBodyEnabled flipped false
      killed               dragger dead or `player` is no longer the dragging unit (also hooked directly)
      revive-won           AP_reviving appeared on the body
      downed / restrained / vehicle / underwater
      detached-externally  attachedTo body is no longer the player (fn_revived's guard, admin detach, or a
                           second dragger who committed in the same network round trip -- the stop then
                           detaches that one too, see fn_dragBodyStop step 2)
      desync               dragger further than AP_dragCfg_desync from the body while attached
      anim-break           after the grace, animationState left the drag set: going prone, Up into the carry
                           helper, a stance change, or a weapon change the drag set does not map. NOT W and NOT
                           sprint: the dragger action sets (CfgMovesMaleSdr MoveWithInjuredManDraggerRfl/Pst/Non)
                           map WalkF/SlowF/FastF and the side keys to the STATIC drag state, so they hold the
                           pose still, and S walks backwards. Skipped when no pose was applied
    Path metres accumulate from the dragger's position every tick; every clear tick then runs the clamp below.
    There is deliberately NO geometry stop reason: geometry is handled by keeping the body out of it.

    CONTINUOUS CLAMP (owner 2026-09-16). attachTo ignores walls, so a dragger who turns to face a wall swings
    the body, hung AP_dragCfg_offset's y metres ahead of him, into or through it -- and a revive stands the
    living player up wherever the body is (fn_revived), e.g. inside a locked house. The invariant is enforced
    where it originates, on this client, and nothing in the tree setPos'es a corpse for drag geometry:
      - RAYS. Every clear watchdog tick (the body hangs off us and we are on foot), one horizontal GEOM ray per
        AP_dragCfg_clampHeights entry, from the dragger's rendered position that many metres above his feet,
        along his rendered facing (getPosASLVisual / getDirVisual), out to nominal y + AP_dragCfg_clampMargin.
        needed y = nearest counted hit - margin, kept within [floor, nominal]; no hit = nominal. The floor is
        AP_dragCfg_clampMinY, lowered to (hit - 0.1) max 0 when that is shorter, so it never passes the hit.
      - WHAT COUNTS. Buildings, walls, fences, doors, windows, vehicles, props: any GEOM surface except the
        dragger, the body, every CAManBase (bystanders, other bodies), weapon holders (the body's own dropped
        gun) and anything attached to the dragger. TERRAIN (a hit with a null object) counts on the LOWEST ray
        only, and only when that ray starts above the ground. A slope rising ahead, which the body would sink
        into, shortens the drag the way a wall does; a higher ray never meets terrain the lowest one missed on
        open ground; and a ray that starts under the terrain (a floor sunk into a hillside) returns only the
        terrain crossing (BIKI lineIntersectsSurfaces), which is not a slope in front and must not pull the
        body in. AP_dragCfg_clampTerrain = false ignores terrain on every ray.
      - RE-ATTACH. When |needed - current| > AP_dragCfg_clampHyst the body is re-welded at needed y through
        _fnc_weld, the same helper as the first attach (x/z from AP_dragCfg_offset, then the same setDir /
        dirSync handling). A needed y sitting on a FIXED bound (nominal or clampMinY) is applied even inside the
        hysteresis, so a clear path always grows the body all the way back to nominal. The floor that follows
        a nearer hit (hit - 0.1) is not a bound; instead a safety rule re-welds at once whenever the current
        attach point is within 0.05 m of the hit, so the body never reaches it whatever the hysteresis is.
        Growing back has no rate limit and needs none: the rays just proved the space clear to margin beyond
        the new position. The hysteresis stops centimetre jitter from issuing an attachTo (global, networked)
        every tick, near a wall included.
      - WHEN. Before the first attach (the attach puts the body in front of the dragger whatever lay between),
        on every clear tick, and once more in AP_fnc_dragBodyStop right before its detach, with no hysteresis,
        while the body still hangs off our living on-foot dragger. The re-attach and the tick's token check
        run in one isNil, so a stop can never detach between them and have the tick weld the body back on.
      - WHY NOT FIX IT AT RELEASE. The corpse is local to its owner, not to this client; setPos on a remote
        ragdoll is what desyncs corpses or drops them under the map (ACE3 experience). A body that never
        crosses the wall needs no repair on any machine, so fn_revived, fn_deathState's sweep and the stop
        all leave the body exactly where the last clamp put it.
    ACCEPTED RESIDUALS: (1) a turn between two ticks -- at the 0.1 s default a mouse turn moves the body a few
    centimetres into geometry before the next tick pulls it back; a very fast turn in the frame of the release
    itself, and any stop that skips the final clamp (killed, vehicle, race), leaves at most that last tick's
    turn unclamped (a dragger killed mid-drag may also carry the body with his ragdoll before the stop's detach).
    (2) The clamp holds the body's ATTACH POINT -- its position, which is what a revive and every
    reader use -- on the dragger's side; the limbs reach further and can still clip into a wall visually.
    (3) clampMinY beats the margin but never the hit: a dragger closer than clampMinY + 0.1 m to a wall gets the
    body held 0.1 m short of it (0 at the least; never closer than 0.05 m once held), so the body may overlap the dragger himself -- it stays on his
    side of the wall, never past it. Whether that overlap upsets the dragger (BIKI attachTo note on attached
    objects intersecting their parent) is SPIKE D4. (4) Height is not clamped: backing DOWN stairs the lowest
    ray meets the next riser and holds the body at the floor (clampMinY, or short of a nearer riser), at the
    dragger's foot height, so part of it sits inside the steps. (5) A "vehicle" stop does nothing extra; the
    last on-foot tick clamped, and where the engine carries an attached body when its holder gets in is SPIKE D4.
    (6) Whether a re-attach immediately followed by detach (the stop) lands the body at the new offset in the
    same frame is SPIKE D4 too; the -DRAG- stop row logs the final clamp. debug\probe_drag.sqf trace logs
    current y, needed y and the nearest hit every tick.

    WHY THE POSE IS SPIKE-SWITCHABLE. No drag animation is used anywhere else in this tree, and the
    plan's SPIKE D1-D8 (attach on a ragdoll, offset, weapon sets, detach fling, camera, observer view,
    dragger disconnect, remote setDir) have not been measured in-engine. Every spike-dependent choice
    below is a live missionNamespace override with the plan's primary choice as default, so the owner
    can flip it from the debug console with no repack. debug\probe_drag.sqf records and tunes them.

    LIVE TOGGLES (missionNamespace, debug console; defaults in brackets):
      SRV_dragBodyEnabled        (true)  server kill switch; false refuses and the watchdog releases
      AP_dragDebug               (false) any dead CAManBase counts; [AP-PROBE] start/stop lines
      AP_dragCfg_startDist       (2.5)   metres, dragger to body, to start (the scroll condition reads it too)
      AP_dragCfg_offset          ([0, 1.1, 0.092])  attachTo offset in the dragger's model space (SPIKE D2); its y
                                         is the NOMINAL drag distance the clamp shortens (keep it > 0: a
                                         negative current y reads as "measure only" and is never re-welded).
                                         Not three numbers = the default is used
      AP_dragCfg_dir             (180)   setDir of the body relative to the dragger; negative = skip (D2/D5/D8)
      AP_dragCfg_dirSync         (false) after setDir, setPosWorld the body onto itself -- the BIKI MP
                                         idiom for attached direction; experimental (D8)
      AP_dragCfg_selectPrimary   (true)  raise the primary first if it exists and is not in hand (D3);
                                         never while AP_holstered or a quickhack weapon lock is active
      AP_dragCfg_selectWait      (2)     seconds to wait for that weapon switch
      AP_dragCfg_pose            ("switchMove")  "switchMove": local switchMove the static drag state for
                                         the weapon in hand + AP_fnc_animSync to <= 30 m (plan);
                                         "action": playActionNow "grabDrag" (weapon-state aware, global
                                         effect by BIKI, stop plays "released"); "none": attach only
      AP_dragCfg_poseAnims       ([["rfl","AcinPknlMstpSrasWrflDnon"],["pst","AcinPknlMstpSnonWpstDnon"],
                                   ["non","AcinPknlMstpSnonWnonDnon"]])  static state per weapon set;
                                         "" = no pose for that set (plan D3 fallback). Each is isClass-
                                         checked; a missing one logs [AP-PROBE] and drags without a pose
      AP_dragCfg_validAnims      (list below) lowercase states that count as "still dragging": for rifle,
                                         handgun and unarmed, the static drag state, the walk-backwards state
                                         and both grabDrag transition states (_1, _2)
      AP_dragCfg_validAnimSubs   ([])    a state CONTAINING any of these also counts (D3). Empty by default
                                         (owner 2026-09-16): the old "acinpknl" also matched the prone
                                         (..._AmovPpneMstp...), carry (..._AcinPercMrun...) and let-go
                                         (..._AmovPknlMstp...) transitions, so going prone or picking the body
                                         up never broke the drag
      AP_dragCfg_grace           (1)     seconds after the pose before anim-break can fire
      AP_dragCfg_desync          (3)     metres
      AP_dragCfg_tick            (0.1)   watchdog and clamp period, seconds (floor 0.05)
      AP_dragCfg_clamp           (true)  CONTINUOUS CLAMP; false = no rays, the body hangs at nominal y (one
                                         already held in grows back on the next tick)
      AP_dragCfg_clampHeights    ([0.3, 1.0])  metres above the dragger's feet, one horizontal ray each; the
                                         lowest also counts terrain
      AP_dragCfg_clampMargin     (0.35)  metres kept between the nearest hit and the body's attach point (0.1 at
                                         the least, so the 0.05 m safety rule never fires on a body at rest); also
                                         how far past nominal the rays reach
      AP_dragCfg_clampMinY       (0.5)   the shortest y the clamp sets (nominal wins if it is shorter), unless the
                                         nearest hit is closer than this + 0.1: then 0.1 m short of the hit, 0 at the least
      AP_dragCfg_clampHyst       (0.05)  metres a change must exceed before a re-attach (nominal / clampMinY and
                                         the within-0.05-m-of-the-hit safety rule excepted)
      AP_dragCfg_clampTerrain    (true)  terrain counts on the lowest ray; false = never
      AP_dragCfg_reachLos        (true)  refuse "You can't reach the body from there." when a GEOM surface
                                         (terrain, men and weapon holders ignored) lies between the
                                         dragger's eyes and the body's pelvis, so a body cannot be pulled
                                         out through bars, a window or a fence. false = distance only
      AP_dragCfg_losLift         (0.3)   metres added above the body's pelvis for that ray, so floor clutter
                                         and step edges do not count
      AP_dragCfg_flagNear        (5)     metres: step 2 leaves an AP_draggedBy naming a living man (not this
                                         player) within this distance of the body, see GROUND TRUTH
    AP_fnc_dragBodyStop reads AP_dragCfg_zeroVel, AP_dragCfg_noPoseReset and AP_dragCfg_raceDetach (see its
    header); its final clamp reads the clamp toggles above through the "clamp" call mode.

    ANIMATION NAMES were checked offline against the derapified CfgMovesMaleSdr (owner 2026-09-16): every
    state in the default lists exists, the grabDrag actions are AmovPercMstpSlowWrflDnon_AcinPknlMwlkSlowWrflDb_2
    (rifle), AmovPercMstpSrasWpstDnon_AcinPknlMwlkSnonWpstDb_2 (handgun) and
    AmovPercMstpSnonWnonDnon_AcinPknlMwlkSnonWnonDb_2 (unarmed), each reached from its _1, and "released" is
    AmovPknlMstp... per set. Not from play: SPIKE D3 still records what the engine really passes through.

    "clamp" CALL MODE (owner 2026-09-16), unscheduled-safe, used by the watchdog, AP_fnc_dragBodyStop and
    debug\probe_drag.sqf:
        ["clamp", body, dragger, currentY, hyst] call AP_fnc_dragBody
          -> [neededY, currentYAfter, hitDist, hitObject, reattached, nominalY]
    currentY < 0 measures only and never attaches. Otherwise the body is re-welded at neededY (see RE-ATTACH)
    only while it hangs off that dragger. hitDist -1 = nothing in reach; hitObject objNull with hitDist >= 0 =
    terrain.
*/
// call _fnc_offset -> a fresh copy of AP_dragCfg_offset, or the default when it is not three numbers.
private _fnc_offset = {
    private _o = missionNamespace getVariable ["AP_dragCfg_offset", [0, 1.1, 0.092]];
    if ((_o isEqualType []) && {(count _o) == 3} && {(_o findIf {!(_x isEqualType 0)}) < 0}) then {+_o} else {[0, 1.1, 0.092]}
};
// [body, dragger, y] call _fnc_weld -> the offset used. THE attach: x/z from AP_dragCfg_offset, the given y, then
// the setDir / dirSync handling. The first attach and every clamp re-attach go through it (header RE-ATTACH).
private _fnc_weld = {
    params ["_wBody", "_wDragger", "_wY"];
    private _wOff = call _fnc_offset;
    _wOff set [1, _wY];
    _wBody attachTo [_wDragger, _wOff];
    private _wDir = missionNamespace getVariable ["AP_dragCfg_dir", 180];
    if ((_wDir isEqualType 0) && {_wDir >= 0}) then {
        // setDir is argument-LOCAL (BIKI) and the body is usually remote: SPIKE D8 measures whether
        // observers see it. dirSync is the BIKI attachTo MP idiom, off until D8 says otherwise.
        _wBody setDir _wDir;
        if (missionNamespace getVariable ["AP_dragCfg_dirSync", false]) then {_wBody setPosWorld (getPosWorld _wBody);};
    };
    _wOff
};
// [body, dragger, currentY, hyst] call _fnc_clamp -> see "clamp" CALL MODE. No suspension anywhere in here.
private _fnc_clamp = {
    params [["_cBody", objNull, [objNull]], ["_cDragger", objNull, [objNull]], ["_cCur", -1, [0]], ["_cHyst", 0, [0]]];
    private _nom = (call _fnc_offset) select 1;
    private _need = _nom;
    private _best = -1;
    private _bestObj = objNull;
    private _minY = missionNamespace getVariable ["AP_dragCfg_clampMinY", 0.5];
    if !(_minY isEqualType 0) then {_minY = 0.5};
    // A negative clampMinY would store a negative current y, which the watchdog reads as "measure only".
    _minY = _minY max 0;
    // owner 2026-09-16: the floor actually used -- clampMinY, or 0.1 m short of a nearer hit (header RAYS). Only the
    // ray block reads it; the re-weld test below reads _minY and _best.
    private _floor = _minY;
    if ((missionNamespace getVariable ["AP_dragCfg_clamp", true]) isEqualTo true && {!(isNull _cDragger)}) then {
        private _margin = missionNamespace getVariable ["AP_dragCfg_clampMargin", 0.35];
        if !(_margin isEqualType 0) then {_margin = 0.35};
        // At least 0.1: a body at rest must sit outside the re-weld test's 0.05 m safety band, or every
        // millimetre of ray jitter re-welds it with a global attachTo.
        _margin = _margin max 0.1;
        private _heights = missionNamespace getVariable ["AP_dragCfg_clampHeights", [0.3, 1.0]];
        if !((_heights isEqualType []) && {_heights isNotEqualTo []} && {(_heights findIf {!(_x isEqualType 0)}) < 0}) then {_heights = [0.3, 1.0]};
        private _low = selectMin _heights;
        private _terrOn = missionNamespace getVariable ["AP_dragCfg_clampTerrain", true];
        private _dirV = getDirVisual _cDragger;
        private _fwd = [sin _dirV, cos _dirV, 0];
        private _feet = getPosASLVisual _cDragger;
        private _reach = _nom + _margin;
        {
            private _from = _feet vectorAdd [0, 0, _x];
            // Terrain counts on the lowest ray only, and only when that ray starts above the ground (header).
            private _terr = (_terrOn isEqualTo true) && {_x isEqualTo _low} && {(_from select 2) > (getTerrainHeightASL _from)};
            private _hits = lineIntersectsSurfaces [_from, _from vectorAdd (_fwd vectorMultiply _reach), _cDragger, _cBody, true, 8, "GEOM", "NONE"];
            private _i = _hits findIf {
                private _o = _x select 2;
                private _p = _x select 3;
                if (isNull _o) then {_terr} else {
                    !(_o isKindOf "CAManBase") && {!(_p isKindOf "CAManBase")}
                        && {!(_o isKindOf "WeaponHolder")} && {!(_o isKindOf "WeaponHolderSimulated")}
                        && {!((attachedTo _o) isEqualTo _cDragger)} && {!((attachedTo _p) isEqualTo _cDragger)}
                }
            };
            if (_i > -1) then {
                private _d = _from vectorDistance ((_hits select _i) select 0);
                if ((_best < 0) || {_d < _best}) then {_best = _d; _bestObj = (_hits select _i) select 2;};
            };
        } forEach _heights;
        // The floor never passes the nearest counted hit: clampMinY only while it is at least 0.1 m short of it.
        if (_best >= 0) then {
            _floor = _minY min ((_best - 0.1) max 0);
            _need = ((_best - _margin) max _floor) min _nom;
        };
    };
    private _curOut = _cCur;
    private _did = false;
    if ((_cCur >= 0) && {!(isNull _cBody)} && {!(isNull _cDragger)} && {(attachedTo _cBody) isEqualTo _cDragger}) then {
        private _delta = abs (_need - _cCur);
        // Fixed bounds (nominal, clampMinY) apply even inside the hysteresis. The floor that follows a closer hit is
        // NOT a bound: exempting it re-welded on every centimetre of jitter near a wall (a global attachTo each tick).
        // Instead a SAFETY rule re-welds at once whenever the current attach point is within 0.05 m of the hit.
        if ((_delta > (_cHyst max 0)) || {(_delta > 0) && {(_need isEqualTo _nom) || {_need isEqualTo _minY} || {(_best >= 0) && {_cCur > (_best - 0.05)}}}}) then {
            [_cBody, _cDragger, _need] call _fnc_weld;
            _curOut = _need;
            _did = true;
        };
    };
    [_need, _curOut, _best, _bestObj, _did, _nom]
};
// Checked before params: the normal call passes an object first, and params would log a type error on "clamp".
if ((_this isEqualType []) && {(_this param [0, objNull]) isEqualTo "clamp"}) exitWith {(_this select [1, 4]) call _fnc_clamp};

params [["_body", objNull, [objNull]]];

// The weapon wait suspends. A caller in unscheduled code (or a plain call) gets re-spawned.
if !(canSuspend) exitWith {_this spawn AP_fnc_dragBody; false};

private _fnc_say = {[_this, "basic"] spawn AP_fnc_handleMessage;};

// "" = allowed, "-" = refuse silently, anything else = refuse with that message.
private _fnc_draggerWhy = {
    if (!(alive player) || {AP_isDead} || {AP_isDowned} || {player getVariable ["AP_downed", false]}) exitWith {"-"};
    if ((player getVariable ["AP_restrained", false]) || {player getVariable ["AP_surrendered", false]}) exitWith {"You cannot drag a body right now."};
    if !(isNull objectParent player) exitWith {"-"};
    // Roping, mid-parkour: the player is already welded to something else. (A chair is NOT caught here:
    // fn_handleChair detaches the player straight away -- see the busy states below.)
    if !(isNull attachedTo player) exitWith {"You cannot drag a body right now."};
    if !(isNull AP_escort) exitWith {"You cannot drag a body while escorting someone"};
    // owner 2026-09-16: a body already hanging off this player with no lock must not get a second one. The
    // first drag's watchdog would exit silently on the new token and leave that body welded on.
    if (((attachedObjects player) findIf {_x isKindOf "CAManBase"}) > -1) exitWith {"You are already moving a body."};
    // owner 2026-09-16: the busy states parkour refuses on (see header BUSY STATES).
    if (!(isNull (missionNamespace getVariable ["AP_sittingChair", objNull]))
        || {player getVariable ["AP_inAnim", false]}
        || {missionNamespace getVariable ["AP_autoRun", false]}
        || {!(isNull (missionNamespace getVariable ["AP_holding_barrel", objNull]))}) exitWith {"You cannot drag a body right now."};
    if (AP_action_in_use) exitWith {"You cannot drag a body right now."};
    if (isWeaponDeployed player) exitWith {"You cannot drag a body right now."};
    if ((missionNamespace getVariable ["AP_parkourState", "idle"]) isNotEqualTo "idle") exitWith {"-"};
    ""
};

// owner 2026-09-16 (geometry): the first GEOM surface between two ASL points that a body could not pass; [] =
// clear. Terrain (null object), men (other bodies, bystanders) and weapon holders (the body's own dropped gun)
// never count: they are not walls, and counting them would refuse ordinary drags. Used only by the reach check
// (AP_dragCfg_reachLos); the clamp has its own filter because it counts terrain on its lowest ray.
private _fnc_blockHit = {
    params ["_from", "_to", "_ign1", "_ign2"];
    private _hits = lineIntersectsSurfaces [_from, _to, _ign1, _ign2, true, 8, "GEOM", "NONE"];
    private _i = _hits findIf {
        private _o = _x select 2;
        !(isNull _o) && {!(_o isKindOf "CAManBase")} && {!((_x select 3) isKindOf "CAManBase")}
            && {!(_o isKindOf "WeaponHolder")} && {!(_o isKindOf "WeaponHolderSimulated")}
    };
    if (_i < 0) then {[]} else {_hits select _i}
};

private _startDist = missionNamespace getVariable ["AP_dragCfg_startDist", 2.5];
private _fnc_bodyWhy = {
    if (isNull _body || {!(_body isKindOf "CAManBase")} || {alive _body}) exitWith {"-"};
    if (((_body getVariable ["AP_steamid", ""]) isEqualTo "") && {!(missionNamespace getVariable ["AP_dragDebug", false])}) exitWith {"You can only drag a dead player's body."};
    if !(isNull objectParent _body) exitWith {"-"};
    if ((player distance _body) >= _startDist) exitWith {"Get closer to the body."};
    private _rv = _body getVariable ["AP_reviving", objNull];
    if ((_rv isEqualType objNull) && {!isNull _rv}) exitWith {"Someone is reviving this person -- wait for them to finish"};
    private _ex = _body getVariable ["AP_executing", objNull];
    if ((_ex isEqualType objNull) && {!isNull _ex}) exitWith {"Someone is busy with this body"};
    if !(isNull attachedTo _body) exitWith {"Someone is already moving this body"};
    // owner 2026-09-16 (geometry): cursorObject and distance both reach through bars, windows and chain-link;
    // attachTo does not care what lies between. Without this a body could be pulled out through a fence.
    // Last, so the ray only runs once every cheap check has passed.
    if ((missionNamespace getVariable ["AP_dragCfg_reachLos", true])
        && {([eyePos player, (_body modelToWorldVisualWorld (_body selectionPosition "pelvis")) vectorAdd [0, 0, missionNamespace getVariable ["AP_dragCfg_losLift", 0.3]], player, _body] call _fnc_blockHit) isNotEqualTo []}) exitWith {"You can't reach the body from there."};
    ""
};

// ---- 1. gates -------------------------------------------------------------------------------------
if !(missionNamespace getVariable ["SRV_dragBodyEnabled", true]) exitWith {"Body dragging is switched off right now." call _fnc_say; false};
private _why = call _fnc_draggerWhy;
if (_why isNotEqualTo "") exitWith {if (_why isNotEqualTo "-") then {_why call _fnc_say}; false};
if !(isNull (missionNamespace getVariable ["AP_dragging", objNull])) exitWith {"You are already moving a body." call _fnc_say; false};
_why = call _fnc_bodyWhy;
if (_why isNotEqualTo "") exitWith {if (_why isNotEqualTo "-") then {_why call _fnc_say}; false};
// ---- 2. stale-flag hygiene: a name on a body nothing holds (dragger disconnected, sweep not run) ----
// Reaching here means attachedTo reads null HERE. owner 2026-09-16: that alone does not make the flag stale --
// another player's drag publishes it before its attach, and the two can reach this machine in separate frames.
// Only a flag whose dragger is gone is cleared (header GROUND TRUTH); a possibly-live one is kept as _flag0 so
// the commit can tell a flag that was already there from one that arrived during the weapon wait.
// _this = an AP_draggedBy value; true = it names a living man, not this player, near the body.
private _fnc_liveFlag = {
    private _fo = if (_this isEqualType []) then {_this param [0, objNull]} else {objNull};
    (_fo isEqualType objNull) && {!(isNull _fo)} && {alive _fo} && {_fo isKindOf "CAManBase"} && {!(_fo isEqualTo player)}
        && {(_fo distance _body) <= (missionNamespace getVariable ["AP_dragCfg_flagNear", 5])}
};
private _flag0 = _body getVariable ["AP_draggedBy", []];
if ((_flag0 isNotEqualTo []) && {!(_flag0 call _fnc_liveFlag)}) then {
    _body setVariable ["AP_draggedBy", nil, true];
    _flag0 = [];
};

// ---- 3. take the mutex (meta waits for the attach, see header) --------------------------------------
// owner 2026-09-16: check-and-set in one unscheduled block. Gate 1's check is scheduled, so two activations
// spawned in the same laggy frame could both pass it and both take the lock.
private _took = false;
isNil {
    if (isNull (missionNamespace getVariable ["AP_dragging", objNull])) then {AP_dragging = _body; _took = true;};
};
if !(_took) exitWith {"You are already moving a body." call _fnc_say; false};

// ---- 4. weapon: the vanilla drag set is best proven with a rifle in hand (SPIKE D3) ------------------
private _pw = primaryWeapon player;
if ((missionNamespace getVariable ["AP_dragCfg_selectPrimary", true])
    && {_pw isNotEqualTo ""}
    && {(currentWeapon player) isNotEqualTo _pw}
    && {!AP_holstered}
    && {!(missionNamespace getVariable ["AP_qhWeaponLock", false])}) then {
    player selectWeapon _pw;
    private _t0 = diag_tickTime;
    private _wait = missionNamespace getVariable ["AP_dragCfg_selectWait", 2];
    waitUntil {
        uiSleep 0.1;
        (((currentWeapon player) isEqualTo _pw) && {!isSwitchingWeapon player})
        || {(diag_tickTime - _t0) > _wait}
        || {!((missionNamespace getVariable ["AP_dragging", objNull]) isEqualTo _body)}
    };
};

// ---- 5-8. re-validate and commit in one unscheduled block, so no stop can interleave -----------------
private _refusal = "";
private _token = -1;
isNil {
    if !((missionNamespace getVariable ["AP_dragging", objNull]) isEqualTo _body) exitWith {_refusal = "-";};
    // owner 2026-09-16: a sibling attempt on this same body already attached it (see header). Stand down
    // silently -- no "Someone is already moving this body" about the player's own drag.
    if ((missionNamespace getVariable ["AP_dragMeta", []]) isNotEqualTo []) exitWith {_refusal = "-";};
    if !(missionNamespace getVariable ["SRV_dragBodyEnabled", true]) exitWith {_refusal = "Body dragging is switched off right now.";};
    _refusal = call _fnc_draggerWhy;
    if (_refusal isNotEqualTo "") exitWith {};
    _refusal = call _fnc_bodyWhy;
    if (_refusal isNotEqualTo "") exitWith {};
    // owner 2026-09-16: another player's drag whose flag landed during the weapon wait and whose attach has not
    // (step 2). Committing now would overwrite his name and start the two-dragger race. A flag step 2 already
    // saw and kept is not refused -- it may be a lost clear, and refusing on it could block the body for good.
    private _flagNow = _body getVariable ["AP_draggedBy", []];
    if ((_flagNow isNotEqualTo _flag0) && {_flagNow call _fnc_liveFlag}) exitWith {_refusal = "Someone is already moving this body";};

    private _bodyName = _body getVariable ["AP_name", ""];
    if !(_bodyName isEqualType "") then {_bodyName = ""};
    if (_bodyName isEqualTo "") then {_bodyName = format ["(%1)", typeOf _body]};
    private _bodyUid = _body getVariable ["AP_steamid", ""];
    if !(_bodyUid isEqualType "") then {_bodyUid = ""};
    if (_bodyUid isEqualTo "") then {_bodyUid = "none"};
    private _bodyPos0 = (getPosATL _body) apply {round _x};

    // 5. name first, then the weld (see GROUND TRUTH)
    _body setVariable ["AP_draggedBy", [player, profileName], true];

    // 6. attach even if no pose can be applied: function over cosmetics. owner 2026-09-16: the CONTINUOUS
    // CLAMP measures first (header WHEN), so the body is never welded into the wall in front of the dragger.
    private _clamp0 = [_body, player, -1, 0] call _fnc_clamp;
    private _y0 = _clamp0 select 0;
    private _offset = [_body, player, _y0] call _fnc_weld;
    private _dir = missionNamespace getVariable ["AP_dragCfg_dir", 180];

    // 7. pose
    private _poseMode = missionNamespace getVariable ["AP_dragCfg_pose", "switchMove"];
    private _applied = "";
    private _poseAnim = "";
    switch (_poseMode) do {
        case "switchMove": {
            private _cw = currentWeapon player;
            private _set = call {
                if (_cw isEqualTo "") exitWith {"non"};
                if (_cw isEqualTo (primaryWeapon player)) exitWith {"rfl"};
                if (_cw isEqualTo (handgunWeapon player)) exitWith {"pst"};
                "non"
            };
            private _sets = missionNamespace getVariable ["AP_dragCfg_poseAnims", [["rfl", "AcinPknlMstpSrasWrflDnon"], ["pst", "AcinPknlMstpSnonWpstDnon"], ["non", "AcinPknlMstpSnonWnonDnon"]]];
            _poseAnim = (_sets param [_sets findIf {(_x param [0, ""]) isEqualTo _set}, ["", ""]]) param [1, ""];
            if (_poseAnim isNotEqualTo "") then {
                if (isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> _poseAnim)) then {
                    player switchMove _poseAnim;
                    [[player, _poseAnim], "AP_fnc_animSync", allPlayers select {!(_x isEqualTo player) && {(_x distance player) <= 30}}, false] spawn AP_fnc_MP;
                    _applied = "switchMove";
                } else {
                    diag_log format ["[AP-PROBE] dragBody: pose anim %1 (set %2) is not in CfgMovesMaleSdr -- dragging without a pose", _poseAnim, _set];
                };
            };
        };
        case "action": {
            player playActionNow "grabDrag";
            _poseAnim = "grabDrag";
            _applied = "action";
        };
        default {};
    };

    private _validAnims = missionNamespace getVariable ["AP_dragCfg_validAnims", [
        "acinpknlmstpsraswrfldnon", "acinpknlmwlksraswrfldb",
        "acinpknlmstpsnonwpstdnon", "acinpknlmwlksnonwpstdb",
        "acinpknlmstpsnonwnondnon", "acinpknlmwlksnonwnondb",
        "amovpercmstpslowwrfldnon_acinpknlmwlkslowwrfldb_1", "amovpercmstpslowwrfldnon_acinpknlmwlkslowwrfldb_2",
        "amovpercmstpsraswpstdnon_acinpknlmwlksnonwpstdb_1", "amovpercmstpsraswpstdnon_acinpknlmwlksnonwpstdb_2",
        "amovpercmstpsnonwnondnon_acinpknlmwlksnonwnondb_1", "amovpercmstpsnonwnondnon_acinpknlmwlksnonwnondb_2"
    ]];
    // owner 2026-09-16: no substrings by default -- "acinpknl" also matched the prone, carry and let-go transitions
    // (header LIVE TOGGLES). The list above is every state of the three dragger sets, checked against the config.
    private _validSubs = missionNamespace getVariable ["AP_dragCfg_validAnimSubs", []];

    // 3 (deferred). meta -- the drag now exists
    _token = diag_tickTime;
    AP_dragMeta = [getPosATL player, _token, 0, _bodyName, _bodyUid, getPosATL player, _body, _applied, player, _validAnims, _validSubs, _y0];

    // 8. log
    [["-DRAG-", player, profileName, format ["started dragging %1 (%2) from %3", _bodyName, _bodyUid, _bodyPos0]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    if (missionNamespace getVariable ["AP_dragDebug", false]) then {
        diag_log format ["[AP-PROBE] dragBody start body=%1 local=%2 offset=%3 dir=%4 pose=%5/%6 applied=%7 anim=%8 attachedTo=%9 clamp=%10",
            _body, local _body, _offset, _dir, _poseMode, _poseAnim, _applied, animationState player, attachedTo _body, _clamp0];
    };
    if (_applied isEqualTo "") then {
        [format ["You are dragging %1. Use Release Body to let go.", _bodyName], "basic"] spawn AP_fnc_handleMessage;
    } else {
        // owner 2026-09-16: W and sprint hold the drag pose (header WATCHDOG anim-break); only S moves the body.
        [format ["You are dragging %1. Walk backwards (S) to move them. Use Release Body to let go.", _bodyName], "basic"] spawn AP_fnc_handleMessage;
    };
};

if (_token isEqualTo -1) exitWith {
    // Refused after the wait: give the mutex back if it is still ours (a stop may already have). owner
    // 2026-09-16: only while no drag has attached -- a sibling attempt on the same body may own the lock now --
    // and atomically, so a commit cannot land between the test and the clear.
    isNil {
        if (((missionNamespace getVariable ["AP_dragging", objNull]) isEqualTo _body)
            && {(missionNamespace getVariable ["AP_dragMeta", []]) isEqualTo []}) then {AP_dragging = objNull;};
    };
    if ((_refusal isNotEqualTo "") && {_refusal isNotEqualTo "-"}) then {_refusal call _fnc_say};
    false
};

// ---- 9. watchdog ------------------------------------------------------------------------------------
[_body, _token] spawn {
    params ["_body", "_token"];
    private _reason = "";
    while {_reason isEqualTo ""} do {
        uiSleep ((missionNamespace getVariable ["AP_dragCfg_tick", 0.1]) max 0.05);
        private _meta = missionNamespace getVariable ["AP_dragMeta", []];
        // Released elsewhere (Release Body, the killed/downed hooks): this drag is over, nothing to do.
        if !((_meta param [1, -1]) isEqualTo _token) exitWith {};
        private _dragger = _meta param [8, objNull];

        _reason = call {
            if (isNull _body) exitWith {"body-gone"};
            if !(missionNamespace getVariable ["SRV_dragBodyEnabled", true]) exitWith {"disabled"};
            if (!(alive _dragger) || {!(player isEqualTo _dragger)}) exitWith {"killed"};
            private _rv = _body getVariable ["AP_reviving", objNull];
            if ((_rv isEqualType objNull) && {!isNull _rv}) exitWith {"revive-won"};
            if (AP_isDowned || {player getVariable ["AP_downed", false]}) exitWith {"downed"};
            if (player getVariable ["AP_restrained", false]) exitWith {"restrained"};
            if !(isNull objectParent player) exitWith {"vehicle"};
            // `underwater` is unreliable on anything but a mini-sub (BIKI); head below sea level over water is.
            if ((surfaceIsWater (getPosASL player)) && {((eyePos player) select 2) < 0}) exitWith {"underwater"};
            if !((attachedTo _body) isEqualTo player) exitWith {"detached-externally"};
            if ((player distance _body) > (missionNamespace getVariable ["AP_dragCfg_desync", 3])) exitWith {"desync"};
            private _anim = toLower (animationState player);
            private _subs = missionNamespace getVariable ["AP_dragCfg_validAnimSubs", _meta param [10, []]];
            private _animOk = ((_meta param [7, ""]) isEqualTo "")
                || {(diag_tickTime - _token) <= (missionNamespace getVariable ["AP_dragCfg_grace", 1])}
                || {_anim in (missionNamespace getVariable ["AP_dragCfg_validAnims", _meta param [9, []]])}
                || {(_subs findIf {(_anim find _x) > -1}) > -1};
            if !(_animOk) exitWith {"anim-break"};
            ""
        };

        if (_reason isEqualTo "") then {
            private _pos = getPosATL player;
            _meta set [2, (_meta param [2, 0]) + (_pos vectorDistance (_meta param [5, _pos]))];
            _meta set [5, _pos];
            // owner 2026-09-16: CONTINUOUS CLAMP (header). One unscheduled block from the token check to the
            // re-attach, so a stop cannot detach the body in between and have this tick weld it back on.
            isNil {
                if ((((missionNamespace getVariable ["AP_dragMeta", []]) param [1, -1]) isEqualTo _token)
                    && {(attachedTo _body) isEqualTo player} && {alive player} && {isNull objectParent player}) then {
                    private _hyst = missionNamespace getVariable ["AP_dragCfg_clampHyst", 0.05];
                    if !(_hyst isEqualType 0) then {_hyst = 0.05};
                    private _c = ["clamp", _body, player, _meta param [11, -1], _hyst] call AP_fnc_dragBody;
                    _meta set [11, _c select 1];
                };
            };
        };
    };
    if (_reason isNotEqualTo "") then {[_reason, _token] call AP_fnc_dragBodyStop;};
};

true
