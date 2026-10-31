/*
    AP_fnc_parkourCfg -- every number, every animation name and every spike toggle the parkour
    feature reads, in one place (owner 2026-09-16: parkour = vault + mantle + drop, wall run
    behind the Reflex Tuning implant, chip id 5). Same [mode] lookup idiom as fn_fastRopeCfg.

        ["reachFwd"] call AP_fnc_parkourCfg                 -> 1.6
        ["anim", "hang", "rfl"] call AP_fnc_parkourCfg      -> "LadderRifleStatic"
        ["weaponSet"] call AP_fnc_parkourCfg                -> "rfl" | "non" | "pst"
        ["animDuration", "AmovPercMevaSnonWnonDf"] call ... -> seconds (x0.9, fn_autoRun idiom)

    EVERY KEY HAS A LIVE OVERRIDE, AND THAT IS THE POINT OF THIS FILE. Nobody has run the
    engine assumptions this feature stands on (plan SPIKE P1-P6: do chain-link fences have a GEOM
    face, does a cycling animation keep cycling on an attached unit, does a 1.2 m push-off landing
    hurt or drop you prone). The owner measures those on the dev server AFTER this ships, so
    every spike-dependent choice has to be flippable from the debug console without a repack:

        P1  which LODs the face rays try, in order    AP_parkourCfg_faceLods = ["FIRE"];
        P4  "cycle" (plan anims) or "static"          AP_parkourCfg_animHold = "static";
        P5  push-off vertical m/s                     AP_parkourCfg_pushUp = 1.2;
        P5  wall-run arc height, m                    AP_parkourCfg_wallArc = 0.5;
        any animation slot, per weapon set            AP_parkourCfg_anim_hang_non = "LadderCivilStatic";
        attach origin fudge if feet float or sink     AP_parkourCfg_attachZ = 0.05;
        corpse hangs in the air after a death mid-move AP_parkourCfg_wakeCorpse = true;
        pistol holders back on the unarmed set (plan) AP_parkourCfg_pistolSet = false;
        held V chains moves again (no per-press latch) AP_parkourCfg_latchRepeatGap = 0;
        no step-over guard at ledges (engine V again)  AP_parkourCfg_stepGuardFwd = [];
        no "get closer" notice behind a ledge          AP_parkourCfg_dropCloserMsg = "";
        drop edge ray back at the plan's 0.25 m        AP_parkourCfg_dropEdgeNear = 0.25;
        wall-run low (knee) corner ray off             AP_parkourCfg_wallKneeAboveStep = -1;
        back to the shipped value                     AP_parkourCfg_pushUp = nil;

    Paste only the part from AP_ to the semicolon: the debug console flattens a paste to one line,
    so a trailing // comment would comment out everything after it.

    The override is read as missionNamespace getVariable ["AP_parkourCfg_" + key, default] and is
    IGNORED when its type differs from the default's, so a typo'd string where a number belongs
    falls back to the shipped value instead of throwing inside a mover. Set the variable to nil
    to go back to the default. Movers and the probe read their keys once at the start of each
    move / keypress, so an override takes effect on the NEXT V press, never mid-move.

    ANIMATIONS ARE VALIDATED ONCE PER SESSION. The first "anim" lookup checks every default state
    name in both sets with isClass against CfgMovesMaleSdr >> States and caches the table in
    missionNamespace (AP_parkourAnimTable -- not seeded in configuration.sqf on purpose: it is a
    cache, nil means "not built yet"). A missing pistol state logs "[AP-PROBE] parkour cfg: missing
    anim" and falls back to the UNARMED name, a missing unarmed state to the RIFLE name (plan rule);
    a missing rifle state logs and becomes "", which every caller treats as "do not switchMove". To
    re-run the validation, AP_parkourAnimTable = nil. An animation OVERRIDE is checked with isClass on
    every lookup (it is one config read) and ignored with a log line when the state does not exist.

    WEAPON SETS. "rfl" when the weapon in hand is the primary; "pst" when it is the handgun; "non"
    for empty hands and everything else (launcher, binoculars). owner 2026-09-16 (review round 1):
    the plan said handguns use the unarmed set, but the unarmed Snon/Wnon states have showHandGun 0
    and an unarmed action class (anims_f config), so every stance snap hid the pistol and made the
    player redraw it mid-chase; the repo already picks Wpst states for this case
    (fn_dragBodyStop.sqf, fn_revivePlayer.sqf, fn_autoRun.sqf). AP_parkourCfg_pistolSet = false puts
    pistol holders back on the plan's unarmed set without a repack. Every name in the "pst" column is
    a CfgMovesMaleSdr state (checked against the derapified anims_f config). The empty-hands test runs
    FIRST: a player with no handgun and nothing in hand has currentWeapon "" == handgunWeapon "".
    This deliberately never reads or writes AP_holstered / hideWeapon -- core/items/fn_qhEffect.sqf
    owns the weapon lock and fights anything else that touches it.

    Units: metres, seconds, m/s, except wallRunMinSpeed which is km/h because it is compared with
    `speed`. Heights are relative to the player's feet (getPosASL player).
*/
params [["_mode", "", [""]], ["_a", "", [""]], ["_b", "", [""]]];

// [slot, rifle set, unarmed set, pistol set]. Vanilla states only (plan: Animations table).
// owner 2026-09-16 (review round 1): runOver has NO running unarmed or pistol step-over in anims_f -- the
// plan's "AovrPercMrunSnonWnonDf" does not exist, so every session logged "missing anim" and fell back to the
// rifle one anyway. The standing ones are the wrong length for a 0.85 s vault (unarmed speed 0.6 = 1.67 s,
// pistol 0.347 = 2.9 s; the rifle running one is 1.258 = 0.79 s), so the running rifle step-over -- what the old
// fn_jump hop already played for everyone -- is the explicit default for all three sets. Try another live with
// AP_parkourCfg_anim_runOver_non / _pst.
private _animDefaults = [
    ["runOver",   "AovrPercMrunSrasWrflDf",   "AovrPercMrunSrasWrflDf",   "AovrPercMrunSrasWrflDf"],   // running step-over (vault start)
    ["standOver", "AovrPercMstpSrasWrflDf",   "AovrPercMstpSnonWnonDf",   "AovrPercMstpSrasWpstDf"],   // standing step-over (mantle top, drop start)
    ["hang",      "LadderRifleStatic",        "LadderCivilStatic",        "LadderCivilStatic"],        // hang / climb (the fast-rope pose)
    ["sprint",    "AmovPercMevaSrasWrflDf",   "AmovPercMevaSnonWnonDf",   "AmovPercMevaSrasWpstDf"],   // wall run
    ["stop",      "AmovPercMstpSrasWrflDnon", "AmovPercMstpSnonWnonDnon", "AmovPercMstpSrasWpstDnon"], // stance snap, standing
    ["run",       "AmovPercMrunSrasWrflDf",   "AmovPercMrunSnonWnonDf",   "AmovPercMrunSrasWpstDf"]    // stance snap after a vault (carry-over)
];

if (_mode isEqualTo "weaponSet") exitWith {
    private _cw = currentWeapon player;
    call {
        if (_cw isEqualTo "") exitWith {"non"};
        if (_cw isEqualTo (primaryWeapon player)) exitWith {"rfl"};
        if ((_cw isEqualTo (handgunWeapon player)) && {["pistolSet"] call AP_fnc_parkourCfg}) exitWith {"pst"};
        "non"
    }
};

if (_mode isEqualTo "animDuration") exitWith {
    // fn_autoRun.sqf's idiom: one cycle of the state, shortened by 10% so a re-issue lands before the
    // engine's own transition. 0 for a state with no speed entry (the caller must not loop on 0).
    private _spd = getNumber (configFile >> "CfgMovesMaleSdr" >> "States" >> _a >> "speed");
    if (_spd isEqualTo 0) then {0} else {(abs (1 / _spd)) * 0.9}
};

if (_mode isEqualTo "anim") exitWith {
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _table = missionNamespace getVariable ["AP_parkourAnimTable", []];
    if !(_table isEqualType []) then {_table = []};
    if (_table isEqualTo []) then {
        {
            _x params ["_slot", "_rfl", "_non", "_pst"];
            if !(isClass (_states >> _rfl)) then {
                diag_log format ["[AP-PROBE] parkour cfg: missing anim %1 (slot %2, rifle set) -- slot disabled for that set", _rfl, _slot];
                _rfl = "";
            };
            if !(isClass (_states >> _non)) then {
                diag_log format ["[AP-PROBE] parkour cfg: missing anim %1 (slot %2, unarmed set) -- falling back to the rifle set", _non, _slot];
                _non = _rfl;
            };
            if !(isClass (_states >> _pst)) then {
                diag_log format ["[AP-PROBE] parkour cfg: missing anim %1 (slot %2, pistol set) -- falling back to the unarmed set", _pst, _slot];
                _pst = _non;
            };
            _table pushBack [_slot, _rfl, _non, _pst];
        } forEach _animDefaults;
        missionNamespace setVariable ["AP_parkourAnimTable", _table];
    };
    private _row = _table param [_table findIf {(_x select 0) isEqualTo _a}, []];
    private _col = ["rfl", "non", "pst"] find _b;
    if (_col < 0) then {_col = 1};        // an unknown set reads as unarmed, as before the pistol column existed
    private _anim = if (_row isEqualTo []) then {
        diag_log format ["[AP-PROBE] parkour cfg: unknown anim slot %1", _a];
        ""
    } else {
        _row param [_col + 1, _row select 2]
    };
    private _ov = missionNamespace getVariable [format ["AP_parkourCfg_anim_%1_%2", _a, _b], ""];
    if ((_ov isEqualType "") && {!(_ov isEqualTo "")}) then {
        if (isClass (_states >> _ov)) then {_anim = _ov} else {
            diag_log format ["[AP-PROBE] parkour cfg: override AP_parkourCfg_anim_%1_%2 = %3 is not a state -- ignored", _a, _b, _ov];
        };
    };
    _anim
};

private _return = switch (_mode) do {
    // ---- mover clock -------------------------------------------------------------------------
    case "tick":            {0.05};   // s. 20 Hz, the fastRope step. SPIKE P6: attachTo re-issued per tick
    case "dtClamp":         {0.1};    // s. a hitch slows the move, never jumps it
    case "attachZ":         {0};      // m added to every attach offset. Man origin = feet (fn_handleChair precedent); tune if the glide floats or sinks
    case "moveTimeout":     {3};      // s beyond the planned duration before a move is torn down as stuck
    case "wakeCorpse":      {false};  // owner 2026-09-16 (review r1): true = `awake true` a body released mid-move. Unmeasured (plan D7-style): flip it only if a death mid-mantle leaves the corpse hanging in the air

    // ---- keypress ----------------------------------------------------------------------------
    // owner 2026-09-16 (review r2): the per-press latch ends on a RELEASE, not on a timing gap (fn_parkour.sqf, "ONE
    // MOVE PER PHYSICAL PRESS"). The r1 gap test (0.15 s) read the OS repeat DELAY -- 250-1000 ms before the first
    // repeat, 600-660 ms on X11/Hyprland -- as a new press, so a held V retried an aborted move every ~1.2 s.
    // latchRepeatGap: a V KeyUp followed by a KeyDown less than this apart is the OS repeating a held key (X11 without
    // detectable autorepeat sends a release+press pair per repeat), not a new press. 0 = no latch at all.
    case "latchRepeatGap":  {0.05};
    // latchStaleTime: no V KeyDown for this long = a new press even though no KeyUp was seen (a release made while a
    // dialog or the map had focus never reaches display 46). Longer than the longest OS repeat delay (Windows 1 s).
    case "latchStaleTime":  {1.2};
    case "msgRepeatTime":   {7};      // s. the same refusal notice ("Too far down to drop.") is not re-queued within this ("basic" notices stay up >= 7 s)
    case "pistolSet":       {true};   // true = a handgun in hand uses the "pst" animation column; false = the plan's unarmed set

    // ---- probe frame -------------------------------------------------------------------------
    case "fwdFromVelSpeed": {6};      // km/h of HORIZONTAL speed. above this, "forward" is the velocity direction, else facing
    case "fwdFromVelMinDot": {-0.2};  // ...but only when that direction . facing is above this, so a backpedal keeps facing (no 180 degree snap onto the helper)
    case "vehMaxSpeed":     {1};      // km/h. a vehicle faster than this is never an obstacle

    // ---- forward scan (vault / mantle) ------------------------------------------------------
    case "faceLods":        {["GEOM", "FIRE"]};        // SPIKE P1: GEOM first, FIRE only when GEOM finds no face
    case "reachFwd":        {1.6};
    case "rayHeights":      {[0.35, 0.8, 1.25, 1.75]}; // knee, waist, chest, head. The first two are "knee/waist" for the drop test
    case "faceMaxNz":       {0.35};   // |nz| below this = a vertical face
    case "faceFacing":      {-0.5};   // n . f below this = the face looks at the player
    case "faceMinDist":     {0.25};   // closer than this = already pressed in, refuse
    case "topInset":        {0.15};   // top ray drops this far behind the face
    case "topRayUp":        {2.8};    // top ray starts this high above the feet...
    case "topRayDown":      {0.3};    // ...and ends this high
    case "topMinNz":        {0.7};    // a floor/top must be at least this flat
    case "vaultMin":        {0.5};    // below: none (engine step-over / AP_fnc_jump)
    case "vaultMax":        {1.1};
    case "vaultMaxThick":   {1.6};    // thicker (or no far face) = mantle onto it
    case "thickReach":      {2.6};
    case "thickDown":       {0.2};    // thickness ray height below the top
    case "vaultClearUp":    {0.35};   // over-the-top clearance ray height above the top
    case "vaultClearExtra": {0.8};    // ...and its length beyond T
    case "vaultLandFwd":    {0.7};    // landing ray this far past the far face
    case "vaultLandUp":     {0.3};
    case "vaultLandDepth":  {4};
    case "vaultMaxDrop":    {1.5};    // landing at most this far below the take-off feet
    case "vaultHeadroom":   {2.0};
    // owner 2026-09-16 (review r1): body/head room over the obstacle, at these heights above top + vaultLift, from
    // vaultK1Back in front of the face to T + vaultK2Over + sweepLead past it. Catches a lintel over a window sill.
    case "vaultOverHeights": {[0.9, 1.6, 1.9]};
    case "waterASL":        {0.5};    // a hit on a water surface position below this ASL is "in the water"
    case "waterFeetZ":      {0.1};    // player "standing in water" when getPosASLW z is below this over water
    case "mantleMax":       {2.5};
    case "mantleHeadroom":  {1.9};
    case "mantleStandFwd":  {1.0};
    case "mantleStandZ":    {0.9};
    case "mantleNeedsSurface": {true}; // a floor must exist under the mantle's end point (false = thin walls climb-and-drop)

    // ---- drop -------------------------------------------------------------------------------
    case "dropNearClear":   {1.0};    // drop is tested only when nothing is at knee/waist within this
    // owner 2026-09-16 (review r3): the "still on the ledge" edge ray is cast at dropEdgeNear, not dropEdgeFwd. At the
    // plan's 0.25 m a player standing toes-at-the-lip (feet origin ~0.1-0.2 m back) got "no-edge", so a drop only
    // worked from a 45 cm band 0.25-0.7 m back and the step-over guard swallowed V everywhere else. dropEdgeFwd stays
    // the lip the drop keyframes were tuned for (a lip nearer than it uses them unshifted, which clears the face by more).
    case "dropEdgeNear":    {0.05};
    case "dropEdgeFwd":     {0.25};
    case "dropEdgeUp":      {0.3};
    case "dropEdgeMax":     {0.5};
    case "dropFwd":         {0.7};
    case "dropDepth":       {4.0};
    case "dropMin":         {1.2};
    case "dropMax":         {3.5};
    case "dropHeadroom":    {1.9};
    case "dropLipBelow":    {0.08};   // owner 2026-09-16 (review r1): the lip-finding ray runs this far below the edge hit, back toward the player. review r4: its hit is the lip only when it is a face (|nz| < faceMaxNz), else the lip is taken at dropFwd

    // ---- step-over guard --------------------------------------------------------------------
    // owner 2026-09-16 (review r2): a standing "none" hands V to the engine step-over, which walks ~1.5 m along FACING
    // (AovrPercMstpSrasWrflDf root motion), not along the probe's frame. Before that happens, ground columns along
    // facing at these distances look from stepGuardUp above the feet down to stepGuardDepth below them; one that finds
    // no footing swallows V instead (a strafer, or a ledge the drop test refused silently). [] = no guard.
    case "stepGuardFwd":    {[0.5, 1.0, 1.5]};
    case "stepGuardUp":     {1.0};
    case "stepGuardDepth":  {1.2};
    // owner 2026-09-16 (review r3): a player standing too far back from a real drop (the drop test read the floor at
    // dropFwd, "drop-shallow") had V swallowed with no word. When the guard trips there and a dropDepth column at the
    // failing distance lands inside [dropMin, dropMax] on a dry floor, this notice is shown instead (msgRepeatTime
    // throttle, only when not running). "" = the silent swallow again.
    // owner 2026-09-16 (review r4): and only when that landing is dropMin below the floor at dropFwd (a real edge, not a
    // steep slope), nothing is at knee / waist / sweepHeights along facing out past the lip, and dropHeadroom is clear.
    case "dropCloserMsg":   {"Get closer to the edge to drop."};

    // ---- wall run probe ---------------------------------------------------------------------
    case "wallRunMinSpeed": {16};     // km/h
    case "wallReach":       {1.4};
    case "wallRayHeights":  {[0.9, 1.6]};
    case "wallPairTol":     {0.3};
    case "wallMaxNz":       {0.3};
    case "wallMaxNf":       {0.5};
    case "wallContAhead":   {[2.5, 5.0]};
    case "wallContLen":     {1.7};
    case "wallClearLen":    {2.0};
    case "wallGroundAhead": {4.0};
    case "wallGroundUp":    {0.5};
    case "wallGroundMax":   {2.5};

    // ---- keyframes (helper model space: x side, y along f, z up) ----------------------------
    case "vaultK1Back":     {0.30};
    case "vaultLift":       {0.15};
    case "vaultK1Time":     {0.30};
    case "vaultK2Over":     {0.45};
    case "vaultK2Time":     {0.30};
    case "vaultK3Over":     {0.75};
    case "vaultLandLift":   {0.06};
    case "vaultK3Time":     {0.25};
    case "vaultCarry":      {3.0};    // m/s along f at release
    case "mantleK1Back":    {0.35};
    case "mantleLift":      {0.08};
    case "mantleRiseBase":  {0.30};
    case "mantleRisePerM":  {0.16};
    case "mantleK2Fwd":     {0.55};
    case "mantleTopTime":   {0.35};
    // owner 2026-09-16 (review r1): the two drop y values are for a lip at dropEdgeFwd (0.25 m). The probe now measures
    // the real lip and both keyframes shift forward by (lip - dropEdgeFwd), so a lip 0.6 m out no longer glides the
    // body down through the ledge's own wall.
    case "dropK1Fwd":       {0.50};
    case "dropK1Down":      {0.20};
    case "dropK1Time":      {0.20};
    case "dropK2Fwd":       {0.62};
    case "dropEndAbove":    {0.10};
    case "dropRate":        {4.5};    // m/s
    case "dropSnapDelay":   {0.1};
    case "surfaceInset":    {0.15};   // traverse surface re-check only once the feet are this far over the obstacle

    // ---- per-tick sweeps --------------------------------------------------------------------
    case "sweepLead":       {0.5};
    // owner 2026-09-16 (review r1): a sweep hit on the probed obstacle is ignored only at or below (its top + this)
    // (drop: the ledge's top = the feet). A building is ONE object, so ignoring it whole also ignored the lintel over
    // the window being vaulted and let the glide carry the player through solid wall into a locked house.
    case "sweepIgnoreMargin": {0.15};
    case "sweepHeights":    {[0.9, 1.6]};
    case "headZ":           {1.75};
    // owner 2026-09-16 (review r3): a keyframed rise (vault / mantle K1) tests ONE line, the planned head chord from the
    // take-off (feet + headZ + riseHeadTop) to the K1 head (+ riseHeadTop), and the probe casts that whole chord once
    // ("rise"). Each tick the mover casts the next piece of it, riseRayLen further ALONG the chord, never above it: the
    // r2 lead went straight up, so over the approach it tested up to 0.4 m above anything the probe had looked at and a
    // porch roof / lintel / awning passed the probe and aborted every V. riseHeadTop is the head-top margin the straight-up
    // lead used to supply; 0.15 = the probe's top vaultOverHeights ray (1.9) minus headZ. owner 2026-09-16 (review r4): the
    // wall run's head ray is no longer riseRayLen straight up: it is headZ + riseHeadTop over the arc, along the run's path
    // (wallCornerLen lead), and the probe casts that line out to wallRunTime / 2 plus the lead (review r5: never past
    // wallClearLen along the run).
    case "riseRayLen":      {0.4};
    case "riseHeadTop":     {0.15};
    case "surfaceUp":       {0.3};
    case "surfaceLen":      {0.6};

    // ---- wall run ---------------------------------------------------------------------------
    case "wallHoldDist":    {0.45};
    case "wallEaseTime":    {0.25};   // s to close the gap to the hold distance (no one-tick sideways snap)
    // owner 2026-09-20: WALL-RUN CLIP. The optional client mod (@Armapunk2035, ap_anims.pbo) carries a real wall-run
    // animation, one rtm per wall side and one state per weapon set: AP_WallRun<L|R>_<rfl|non|pst>. It is a ONE-SHOT of
    // wallClipRunTime seconds (leap on, three steps, tuck off), so with it the run lasts that long; the probe and the
    // mover both read wallRunTime here, so they still plan the same path. Without the mod: the vanilla sprint, 1.75 s.
    // AP_parkourCfg_wallClip = false; = vanilla even with the mod. wallClipRunTime must equal `speed` in the addon config.
    case "wallClip":        {isClass (configFile >> "CfgMovesMaleSdr" >> "States" >> "AP_WallRunL_rfl")};
    case "wallClipRunTime": {1.1};
    case "wallRunTime":     {[1.75, ["wallClipRunTime"] call AP_fnc_parkourCfg] select (["wallClip"] call AP_fnc_parkourCfg)};
    case "wallSpeedMin":    {4.5};
    case "wallSpeedMax":    {6.5};
    case "wallArc":         {0.9};    // SPIKE P5: reduce to 0.5 if the landing hurts
    case "wallChestZ":      {1.25};
    case "wallContactLen":  {1.2};
    case "wallCornerLen":   {0.6};
    case "wallGroundRay":   {4.0};
    // owner 2026-09-16 (review r1): the run FOLLOWS the ground under the planned feet instead of holding the take-off
    // height (uphill sank the legs into the slope, downhill left the runner up to 2.5 m in the air). Each tick the
    // ground ray starts wallStepUp above last tick's ground; a fall of more than wallStepDown in one tick (a lip, a
    // quay edge) or water ends the run as "ground", which pushes off with pushCornerFwd, not over the edge.
    case "wallStepUp":      {0.4};
    case "wallStepDown":    {0.6};
    // owner 2026-09-16 (review r2): the LOW corner ray. The corner rays sit at sweepHeights above the PLANNED feet and
    // the ground ray starts wallStepUp above the ground, so a bench / planter / bin / low fence between the two was
    // seen by nothing and the legs glided through it. One more ray per tick at (ground + wallStepUp +
    // wallKneeAboveStep), never lower than wallFeetClear above the planned feet (the arc lifts the feet mid-run);
    // terrain never counts for it (the ground ray follows terrain). The probe casts the same height along the mover's
    // eased path (owner 2026-09-16, review r3: it used to run along the player's own line, dWall out, and missed a planter
    // against the wall that the run then hit 0.45 m out). owner 2026-09-16 (review r4): the mover's ray now leads along that
    // path too, and each of its ends sits at its own ground + wallStepUp + wallKneeAboveStep (never below its own feet +
    // wallFeetClear), so it no longer dips under the probe's knee height while the arc rises.
    // owner 2026-09-16 (review r3): below 0 = OFF, in the probe and the mover alike. A large value only lifted the ray
    // (5 put it at ~5.4 m, into eaves and balconies), it never switched it off.
    case "wallKneeAboveStep": {0.05};
    case "wallFeetClear":   {0.15};
    case "maxLandingDrop":  {2.5};    // total descent from the take-off feet that still ends the run (owner cap)

    // ---- push-off / landing (SPIKE P5) ------------------------------------------------------
    case "pushFwd":         {3.5};
    case "pushOut":         {2.5};
    case "pushUp":          {2.0};
    case "pushCornerFwd":   {0};      // forward push when the run ended at a corner or a ground edge (do not throw them into / over it)
    case "pushLandAhead":   {1.5};    // owner 2026-09-16 (review r1): before a forward push, ground this far ahead along the run must be within wallStepDown, else pushCornerFwd. 0 = no check
    // owner 2026-09-18 (codex review): seconds of push-off flight at which the ground under the push-off's own horizontal
    // velocity (pushFwd along the run + pushOut off the wall) must be usable (wallStepDown / maxLandingDrop / water, as
    // in the run). 0.35 ~ a run that ended at ground level, 0.7 ~ one that ended at the top of wallArc. Any miss = no
    // out-push and pushCornerFwd. [] = no check
    case "pushLandTimes":   {[0.35, 0.7]};
    case "landTimeout":     {1.5};
    case "landMinTime":     {0.2};    // s airborne before isTouchingGround counts (the run ends at ground level)
    case "landAtl":         {0.25};
    case "landVz":          {-0.2};

    // ---- cooldowns, broadcast ---------------------------------------------------------------
    case "cdVault":         {0.6};
    case "cdMantle":        {0.8};
    case "cdDrop":          {0.5};
    case "cdWallrun":       {1.5};
    case "cdAbort":         {1.0};
    case "broadcastRange":  {30};

    // ---- SPIKE P4 ---------------------------------------------------------------------------
    // "cycle": the plan's animations (step-over / sprint re-issued). "static": ladder-static for any
    // rise, the static stand for any traverse, and the wall-run sprint issued once and never re-issued.
    case "animHold":        {"cycle"};

    default {
        diag_log format ["[AP-PROBE] parkour cfg: unknown key %1", _mode];
        0
    };
};

private _ov = missionNamespace getVariable ["AP_parkourCfg_" + _mode, _return];
if (_ov isEqualType _return) then {_ov} else {_return}
