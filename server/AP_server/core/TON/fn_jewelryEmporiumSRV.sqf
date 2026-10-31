/*
    APS_fnc_jewelryEmporiumSRV  (LooneyBin -- implemented from stub 2026-06-09)
    Jewelry Emporium heist server half. Client (core/actions/fn_jewelryEmporium.sqf) drives all the
    progress bars + loot; this owns the shared state:
      SRV_jewelryEmporiumSRV = [lastBreach, active, safeDrilled, safeWelded, casesLootable, 0, copsRequired]
    Client cases sent here:
      ["robberyStarted", [player]]            the ANCHOR gate was breached -> authenticate the caller against
                                              AP_jewelGate, then run _fnc_jewelStart (below the trophy
                                              helpers, above the switch): event live, alarm on (client PFH
                                              keys on [1]), cases breakable ([4]), cop alert, 90 m wanted
                                              sweep, both cooldown stamps, the anchor swung open and the
                                              20-minute window spawned. safeDrilled ([2]) is NOT set here --
                                              the cases gate it (see "createCase").
      ["perimeterGate",  [_gate]]             one of the OTHER five gates was breached -> unlock and swing
                                              THAT gate, schedule its own 10-minute re-seal, AND THEN RUN THE
                                              SAME _fnc_jewelStart. 2026-07-29, owner: ANY sealed gate starts
                                              the job, so there is no silent way in any more and the sentence
                                              that used to sit here ("does NOT start the event and does NOT
                                              raise the alarm") is gone. The gate opens FIRST and stays open
                                              even when the start is refused -- ruling and reasoning in
                                              _fnc_jewelStart's header. It still refuses the breach anchor
                                              outright: the anchor has its own case, which is what opens it.
      ["weldSafe",       [safeObj, player]]   terminal breach done -> [3] true, the closed safe is swapped
                                              for a Fridge_01_open_F and 4 trophies spawn. The HOPE DIAMOND
                                              is delivered as a PUBLISHED FLAG on the open safe
                                              (AP_jewelHopeInSafe), and the ONLY thing that turns that flag
                                              into an item is case "takeSafeContents" below.
                                              IT DOES *NOT* GO INTO AP_droppedItems. f4b8900 deleted that
                                              route and the body of case "weldSafe" now forbids it in as
                                              many words: AP_fnc_pickupSelected re-derives the holder from
                                              a hard-coded two-class switch on cursorObject
                                              ("Land_Suitcase_F" / "Box_Syndicate_WpsLaunch_F"), a
                                              Fridge_01_open_F is neither, so an item hung there lists in
                                              the pickup menu and can never be taken out of it. This header
                                              described the deleted route until 2026-07-29.
                                              NO Qilin here any more -- see "loadJewelry".
      ["createCase",     [caseObj]]           a display case was smashed -> mark it looted (authoritative);
                                              when the last one falls, [2] flips and the safe unlocks.
                                              AP_jewelCaseLooted is ALSO THE PRODUCTION RECORD the load's
                                              claim cap is sized from -- see case "loadJewelry".
      ["takeSafeContents", [wantHope, wantBag]]  the open safe's two prizes, ARBITRATED HERE (2026-07-29).
                                              There used to be no server case at all: the client read
                                              AP_jewelHopeInSafe, granted the item on its own machine and
                                              cleared the flag with a client-broadcast setVariable, so two
                                              players scrolling "Take Safe Loot" inside the broadcast window
                                              each banked a $108,000 diamond. Both flags are now cleared
                                              server-side BEFORE anything is granted, which makes each prize
                                              takeable exactly once per run whatever the clients do.
      ["loadJewelry",    [bags, hope]]        the crane load (maldenjewelry2.md #3). ONE loader, ONCE per
                                              robbery: takes the numbers the client says it HAS ALREADY
                                              REMOVED from its own inventory, CLAMPS them to what THIS RUN
                                              IS RECORDED AS HAVING PRODUCED, REFUNDS anything it does not
                                              accept, adds 5 flat bonus bags and spawns the getaway Qilin
                                              loaded with the total. Done-flag is AP_jewelLoaded (below).
    Event auto-ends after 20 min: state reset, cases + safe restored for the next run (30-min cooldown
    on slot 0 is enforced server-side in case "robberyStarted", and mirrored client-side).

    ---------------------------------------------------------------------------------------------------
    CLIENT CONTRACT for "loadJewelry" -- read this before touching either half.
      SEND:  [["loadJewelry", [_bags, _hope]], "APS_fnc_jewelryEmporiumSRV", 2] spawn AP_fnc_MP;
             _bags = how many jewelBag the loader IS CARRYING and is offering to load (Number)
             _hope = how many jewelHope it is offering (Number; only ever 0 or 1 in a legitimate run)
             NOTHING ELSE. No player object: the subject is taken from remoteExecutedOwner, because a
             client-supplied name in a -SEC- row is a way to frame an innocent player in the table
             CLANKR auto-bans from.
      ORDER OF OPERATIONS -- settled 2026-07-29 after TWO wrong answers, and the reasoning is the whole
             point of this block. THE CLIENT REMOVES WHAT IT IS OFFERING *BEFORE* IT SENDS, AND THIS CASE
             REFUNDS WHATEVER IT DOES NOT ACCEPT.
               * Cut 1 removed first and sent, with NO refund. Every refusal here -- the window closing
                 under the two-minute bar, a second loader winning the race, the weld gate that used to
                 sit here -- destroyed the player's whole haul in silence. A LOSS bug.
               * Cut 2 inverted it: send the claim, wait for an accept, remove on arrival. That traded the
                 loss for a MINT. The Qilin was spawned and loaded BEFORE the items left the player, so a
                 client that disconnected, died or timed out in that window kept the haul AND left it in
                 the Qilin -- and a late accept landing after the client's own 15 s timeout duplicated it
                 every time, because the client had already given up and the server had already paid.
               * This cut removes first and REFUNDS. The asymmetry is deliberate and it is the only
                 correct one: a refund that fails to arrive costs the player items they had already
                 chosen to spend, which is the same LOSS as cut 1 at worst -- while a payment made before
                 the removal MINTS value out of nothing, which is unbounded and permanent. Getting a
                 refund wrong in the player's favour is a rounding error; getting a payment wrong in the
                 player's favour is an economy.
             So: EVERY refusal below refunds the full claim to the caller before it exits, and the clamp
             refunds the difference between the claim and what was accepted. _fnc_ljRefuse does both the
             refund and the message, so a refusal cannot be added later that forgets one.
             THERE IS NO ACCEPT MESSAGE AND NO WAIT. AP_jewelLoadAccept is GONE -- deleted with cut 2,
             along with its UID addressing, its serverTime stamp, its 5 s of clock slack, its re-seed in
             case "robberyStarted", its window-close clear and the client's 15 s waitUntil. All of that
             machinery existed only to tell a client what to remove after the server had already paid,
             which is the ordering this cut abandons. Do not reintroduce it: an accept channel is a
             payment that precedes a removal, whatever it is called.
             The REFUND is server -> client AP_fnc_handleInv through AP_fnc_MP, the route
             APS_fnc_greenhouseSRV case "plant" already uses for exactly this reason ("the client consumes
             the seeds BEFORE this call, so every reject below must hand them back"), and which
             APS_fnc_miningSRV, APS_fnc_barrelSRV, APS_fnc_qhLootSRV, APS_fnc_cyberdeckSRV,
             APS_fnc_houseFurnitureSRV and APS_fnc_processMailbox all use to grant virtual items. It needs
             NO CfgRE.hpp entry: CfgRemoteExec's rules "only apply to clients. The server is not subject
             to any limitations" (BIKI, Arma 3: CfgRemoteExec), so a server -> client remoteExec of an
             unlisted function still executes. A refund also cannot be clipped by weight: the player
             freed exactly that weight moments earlier, and AP_fnc_handleInv's add path clamps to the
             room available rather than overflowing.
      DONE-FLAG: AP_jewelLoaded, a published BOOLEAN in missionNamespace. Read it GUARDED --
             missionNamespace getVariable ["AP_jewelLoaded", false] -- because it does not exist at all
             until the first robbery of the session starts. It is deliberately NOT a slot on
             SRV_jewelryEmporiumSRV: server/AP_server/init.sqf:241 seeds slot 5 as the NUMBER 0, and
             `if (0) then` is a type error in SQF, so any client action condition built on that slot
             would raise on a fresh boot until somebody robbed the place. Slot 5 is UNUSED -- an earlier
             cut of the client read `param [5, false, [false]]` as the done-flag, a slot this file has
             never written, so all three of its repeat guards were dead and it logged an engine type
             error on every evaluation. ONE NAME, BOTH SIDES: AP_jewelLoaded.
      ANCHOR: AP_JEWEL_CRANEPOS, a published position (NOT an object -- the Land_RepairDepot_01_tan_F
             is a per-client createSimpleObject from fn_mapData with _xIsServer = false, so the server
             can never see it with nearestObjects and a cursorObject condition would bind the deck
             underfoot, which is the trap the Fed gate and the emporium gate have each fallen into).
             Gate the scroll option on distance2D to that COORDINATE, exactly the way fn_openVault.sqf
             reads AP_FED_TERMPOS. The offer radius, the action condition and the client's own refusal
             must all measure the same thing at the same radius -- the drill gate needed 10 m, not 6.
             The server refuses beyond 30 m, matching the slack the other three cases here already use.
      WHAT IS REQUIRED, and what is NOT: the robbery must be ACTIVE, the caller must be a CIVILIAN AT THE
             CRANE, and the claim must be MORE THAN NOTHING. There is NO weld requirement -- an earlier cut
             refused the load unless slot 3 (safe welded) was true, which the brief never asked for. The
             owner's rule is "whatever the loader is carrying" (maldenjewelry2.md #6).
      THE CAP IS SIZED BY THE RUN, NOT BY THE MAP -- 2026-07-29, and this is the other thing that changed.
             It used to be (count of Coffin_02_F inside AP_JEWEL_POLY) + 5, which is the CONSTANT 13 on
             this map whatever happened: the display cases are never deleted, only flagged, so that count
             reads 8 before a single pane is touched. With the weld gate gone the only server-side
             precondition left is "a robbery is active", so a modified client could breach one perimeter
             gate, walk to the crane having smashed NOTHING, and claim the full 13 bags plus the diamond.
             The cap is now read off the production this file itself RECORDED: the per-case
             AP_jewelCaseLooted flags case "createCase" sets, plus the safe's five and its one diamond
             only when slot 3 says the safe was actually opened. Nothing was produced -> the cap is 0 ->
             the claim is refunded in full and the Qilin is never minted.
    ---------------------------------------------------------------------------------------------------
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];
if (_caseType isEqualTo "robberyStarted") then { if (!isNil "AP_fnc_telemetryEvent") then { ["robbery_jewelry"] call AP_fnc_telemetryEvent; }; };   // telemetry event counter

// owner 2026-07-29 (maldenjewelry2.md #2b): THE TROPHY SETTLE READ, shared by the safe's four and by
// each smashed case's one. Modelled on the Fed's alamo-gold settle (fn_maldenFedSRV, "spawn -> uiSleep ->
// re-read -> log the difference against the thing it belongs to"), with the correction that log earned on
// 2026-07-29: A SETTLE READ THAT COMPARES A HEIGHT AGAINST THE VALUE IT JUST WROTE IS WORTHLESS.
// getPosATL and setPosATL address the SAME reference point, so reading getPosATL back after a setPosATL
// returns the number that was written, every time, whatever the frame -- it can only ever catch an object
// that MOVED, never one that was PUT in the wrong place. That is precisely the fault the owner reported
// here (trophies a metre above the case) and it is invisible to that shape of check.
// So this measures in a DIFFERENT frame from the one the placement writes in, and against the anchor
// object rather than against the target:
//   * getPosWorld returns the MODEL CENTRE in world/ASL (BIKI: "the model's centre, rather than the
//     transformed boundingCenter or LandContact vertices") -- it is not the reference setPosATL/setPosASL
//     drive, so it cannot echo the write back at us.
//   * boundingBoxReal is read at RUNTIME off each object rather than hard-coded, which makes the whole
//     read agnostic to where a given model puts its origin: `select 0 select 2` is the bottom face and
//     `select 1 select 2` the top face whether the origin sits mid-height (Coffin_02_F) or at the base.
//     It is model-space and ignores rotation, which is fine because every object here has yaw only.
// _rows = [[trophy, anchor, anchorFaceIdx, placedCentreASL], ...]
//   anchorFaceIdx  1 = the trophy should stand ON the anchor's TOP face (display case)
//                  0 = the trophy should stand ON THE SAME FLOOR as the anchor's BOTTOM face (the safe)
//   placedCentreASL  getPosWorld z sampled immediately after placement -- the MOVED baseline.
// GAP is the number that matters and it is reported on every line: trophy bottom face minus anchor face.
// 0 means it is sitting on it. Positive is floating, negative is sunk. The 0.10 band is not a spec: the
// placement below targets 0.000 and self-corrects to within a millimetre, and the one plausible residual
// (a setPos reference that turns out to be the bounding centre rather than the base -- half the trophy's
// 0.289 m height, 0.145) is comfortably outside it, as is the 0.672 m float the owner saw.
private _fnc_trophySettle = {
    params [["_rows", [], [[]]], ["_label", "", [""]]];
    if (_rows isEqualTo []) exitWith {};
    [_rows, _label] spawn {
        params ["_rows", "_label"];
        uiSleep 3;
        private _bad = 0;
        private _moved = 0;
        {
            _x params ["_t", "_anchor", "_faceIdx", "_placedZ"];
            if (isNull _t) then {
                diag_log format ["[LooneyBin][jewelry] %1 settle %2: GONE -- taken by a player already, or a reset swept it. Not drift.", _label, _forEachIndex];
            } else {
                private _centre   = (getPosWorld _t) select 2;
                private _bottom   = _centre + (((boundingBoxReal _t) select 0) select 2);
                private _anchorOk = !isNull _anchor;
                private _face     = if (_anchorOk) then {((getPosWorld _anchor) select 2) + (((boundingBoxReal _anchor) select _faceIdx) select 2)} else {0};
                private _gap      = _bottom - _face;
                private _drift    = _centre - _placedZ;
                private _wrong    = _anchorOk && {(abs _gap) > 0.10};
                private _slid     = (abs _drift) > 0.05;
                if (_wrong) then { _bad = _bad + 1; };
                if (_slid)  then { _moved = _moved + 1; };
                diag_log format ["[LooneyBin][jewelry] %1 settle %2: gap %3 m | trophy bottom %4 asl, centre %5 asl | anchor %6 face %7 asl | moved %8 m since placement%9%10",
                    _label,
                    _forEachIndex,
                    if (_anchorOk) then {_gap toFixed 3} else {"?"},
                    _bottom toFixed 3,
                    _centre toFixed 3,
                    if (_anchorOk) then {typeOf _anchor} else {"MISSING"},
                    if (_anchorOk) then {_face toFixed 3} else {"?"},
                    _drift toFixed 3,
                    if (_wrong) then {"   <<< WRONG HEIGHT"} else {""},
                    if (_slid) then {"   <<< MOVED"} else {""}];
            };
        } forEach _rows;
        if (_bad > 0) then {
            diag_log format ["[LooneyBin][jewelry] WARN %1: %2 of %3 trophy/trophies are at the WRONG HEIGHT -- the gap between the trophy's bottom face and the face of the case or safe it belongs to is more than 0.10 m, marked <<< WRONG HEIGHT on their line. READ THE GAP, NOT THE MOVED FIGURE. A gap near +0.67 with moved ~0.000 is the pre-2026-07-29 bug back again: a hard-coded modelToWorld z instead of the object's own boundingBoxReal face. A gap near -0.145 with moved ~0.000 means the self-correcting second placement pass below did not run or did not take, and the setPos reference is the bounding centre rather than the base. A gap that appears together with <<< MOVED is not a placement fault at all -- the freeze failed and the trophy is falling or being shoved; that has its own warning.",
                _label, _bad, count _rows];
        };
        if (_moved > 0) then {
            diag_log format ["[LooneyBin][jewelry] WARN %1: %2 of %3 trophy/trophies MOVED after placement -- more than 0.05 m from the model-centre height they were written to. Land_Trophy_01_gold_F inherits ThingX (simulation = ""thingX"") and is a live PhysX body, so this is the FREEZE fault, not the frame fault: enableSimulationGlobal false did not take. It is counted separately from WRONG HEIGHT on purpose -- a trophy can drift without leaving the gap band, and one can be at the wrong height having never moved at all.",
                _label, _moved, count _rows];
        };
    };
};

// owner 2026-07-29 (maldenjewelry2.md #2b): PLACE ONE TROPHY ON A FACE OF AN ANCHOR OBJECT, exactly.
// _this = [trophyClass, anchor, anchorFaceIdx, offsetX, offsetY, dir] -> [trophy, placedCentreASL]
// The XY offset stays HEADING-RELATIVE through modelToWorld, which is what the 2026-07-28 vectorAdd note
// on the safe's row was about: vectorAdd works in WORLD axes and put the row through the wall behind the
// safe for every heading but due south.
// FRAME: modelToWorld returns PositionAGL and setPosATL measures from the TERRAIN, and the two are only
// the same over land. The Fed lost a day to that. So the anchor point is converted with AGLToASL ONCE,
// here, and everything downstream is ASL -- never per-item inside the spread loop.
// SELF-CORRECTING SECOND PASS: setPos* positions "the transformed LandContact vertices (if present) or
// the boundingCenter", and which of those applies is a property of the p3d, not something this file can
// assert. Rather than guess, the first write is measured in the independent getPosWorld frame and the
// residual is added back. Two commands, no assumption, and the settle read above then verifies it from
// scratch. Costs nothing when the first pass was already right (the correction is skipped under 1 mm).
// The freeze happens BEFORE the placement, which is the shape the Fed proved: enableSimulationGlobal
// false does not stop setPos from moving an object, and freezing first is what makes the position stick.
private _fnc_placeTrophy = {
    params [["_cls", "Land_Trophy_01_gold_F", [""]], ["_anchor", objNull, [objNull]], ["_faceIdx", 1, [0]],
            ["_ox", 0, [0]], ["_oy", 0, [0]], ["_dir", 0, [0]]];
    if (isNull _anchor) exitWith {[objNull, 0]};
    private _faceZ   = ((boundingBoxReal _anchor) select _faceIdx) select 2;
    private _wantASL = AGLToASL (_anchor modelToWorld [_ox, _oy, _faceZ]);
    private _t = createVehicle [_cls, ASLToAGL _wantASL, [], 0, "CAN_COLLIDE"];
    _t allowDamage false;
    _t enableSimulationGlobal false;
    // setDir BEFORE the position writes and before the measurement. A heading change rotates the object
    // about its own origin, and the measurement below reads getPosWorld -- the model CENTRE -- so turning
    // it afterwards could move the very thing the correction was computed against.
    _t setDir _dir;
    _t setPosASL _wantASL;
    private _bmin = ((boundingBoxReal _t) select 0) select 2;
    private _delta = (_wantASL select 2) - (((getPosWorld _t) select 2) + _bmin);
    if ((abs _delta) > 0.001) then {
        _t setPosASL [_wantASL select 0, _wantASL select 1, (_wantASL select 2) + _delta];
    };
    _t setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup's sweep
    [_t, (getPosWorld _t) select 2];
};

// =====================================================================================================
// owner 2026-07-29 (owner report on b0131): STARTING THE ROBBERY -- ONE COPY, SIX DOORS.
// The owner's words were "breaching any of the 2 gate doors on the building should let you start cracking
// the coffins". Asked which of the six sealed gates he meant, he chose: ANY SEALED GATE. So a breach of any
// gate on this perimeter now runs the WHOLE start -- the alarm, the MaxSec broadcast, the 90 m wanted sweep,
// slot 4 (cases lootable), both cooldown stamps and the 20-minute window -- where until today only the
// anchor did and the other five opened a gate and touched nothing.
//
// WHY "STARTS THE JOB" AND NOT "QUIETLY UNLOCKS THE LOOT". The other reading of "lets you start cracking
// the coffins" is a far gate that sets slot 4 WITHOUT alarming, and that is the one thing this heist cannot
// have: it would hand a crew a silent robbery with no police response, and the police response is the event
// the whole heist is built around. The owner's rule that the back gate raises the alarm is kept by making
// EVERY gate raise it, not by carving out a quiet exception. Note the consequence, and that it is accepted:
// the two Land_ConcreteWall_01_l_gate_F at the owner's point B are 42.10 m and 43.98 m from the emporium
// centre (boot log, 2026-07-29), so the alarm can now be tripped from three times as far out as the
// anchor's 12.29 m.
//
// WHY THIS IS A FUNCTION AND NOT A SECOND COPY. Two entry points writing the same fifteen pieces of state
// is the exact shape that drifts: one of them gains a guard, the other does not, and a month later one door
// arms the cross-heist lockout and the other does not. Case "robberyStarted" and case "perimeterGate" both
// CALL THIS, so there is one copy of the guards, one copy of the state stamp, one copy of the wanted sweep
// and one copy of the window spawn. Declared here, above the switch, alongside _fnc_trophySettle and
// _fnc_placeTrophy -- a switch CALLS its case blocks, so every case reaches these by scope chain.
//
// WHAT DELIBERATELY STAYS IN THE CASES: CALLER AUTHENTICATION, because its geometry is per-door. The anchor
// case measures 30 m to AP_jewelGate; the perimeter case measures 30 m to the gate it was handed, requires
// membership in AP_jewelGates and refuses the anchor by object identity. Each case authenticates its own
// caller and hands the AUTHENTICATED subject in here.
// That reorder is the ONE observable change to the anchor path: its caller check now runs BEFORE the state
// guards instead of fifth. No honest client can tell -- it is always within 10 m of the anchor when it
// sends. For a FORGED call it is strictly better: a forged start now leaves a -SEC- row even while a robbery
// is already running (the active guard used to drop it silently first), and the fed-event, cop-count and
// cooldown refusals no longer message the CLIENT-SUPPLIED _robber, which was an unvalidated name a modified
// client could have pointed at any player on the server.
//
// DOES THE GATE STILL OPEN WHEN THE START IS REFUSED? For the PERIMETER gates, YES -- and because that is
// this function's contract rather than one caller's detail, the ruling is written here.
//   * The breach is a completed action with its own cost: a Sequence Breach the player can fail and be
//     traced on. Voiding its own effect after it succeeded, over state the player cannot see, is a silent
//     loss. Opening a fence arms NOTHING -- no event state, no spawn, no payout -- and the 10-minute
//     re-seal timer already bounds it, so a gate opened inside the 30-minute cooldown is shut again a
//     comfortable 20 minutes before anybody could use it.
//   * The decisive case is "a robbery is already running". That is the ORDINARY reason a perimeter breach
//     does not start a job -- a second crew member cutting a way in, or the crew opening a way out for the
//     getaway -- and refusing to open the gate there would be a straight functional regression. Any rule
//     that tied the gate to the start would break the one case that matters most.
//   * It also keeps this change purely ADDITIVE: in every state where the job cannot start, a perimeter
//     breach behaves exactly as it did before this commit.
// For the ANCHOR, NO, and the asymmetry is deliberate: the anchor's opening is PART of the start (the
// ["open"] call below sits inside this function, past every guard), so a refused anchor breach leaves it
// shut exactly as it does today. The anchor is the vault door, not a fence.
//
// _this = [_subject, _viaGate] -> Boolean
//   _subject  the AUTHENTICATED player this start is attributed to, and the one every refusal is spoken to.
//             objNull for a server-internal call, which has nobody to talk to -- _fnc_jsSay drops those.
//   _viaGate  the gate that was breached. FOR THE LOG ONLY. It is never what gets opened here: this
//             function always opens the ANCHOR, and case "perimeterGate" has already opened its own gate
//             before it calls.
//   returns   true  = the robbery is running because of this call.
//             false = it is not, and _subject has ALREADY been told why -- with exactly ONE exception, the
//                     already-active guard, which is SILENT BY DESIGN. That path is not a refusal: it means
//                     somebody else's job is live, which for a perimeter breach is the ordinary case and the
//                     player's gate opened exactly as they asked. The client refuses "hackGate" on the same
//                     state before it sends, so an anchor call reaching it is a race or a forgery.
// EVERY GUARD IS A FLAT TOP-LEVEL exitWith OF THIS FUNCTION'S OWN SCOPE. There is no then {} to hide inside
// and so no sentinel is needed here -- the _data = [] trick the cases use exists only because their caller
// checks have to sit inside a then {}.
// =====================================================================================================
private _fnc_jewelStart = {
    params [["_subject", objNull, [objNull]], ["_viaGate", objNull, [objNull]]];
    // Every refusal speaks through this, so a null subject can never be handed to AP_fnc_MP as a target.
    // It reads _subject out of the enclosing scope the way case "loadJewelry"'s _fnc_ljRefuse reads its
    // claim: there is exactly one subject per start, and parameterising it would only let a refusal added
    // later name the wrong player. Broadcast type 2 = titleText, the same channel every one of these
    // guards used before they were factored in here, so no player-facing wording or presentation changes.
    private _fnc_jsSay = {
        if (isNull _subject) exitWith {};
        [[2, _this], "AP_fnc_broadcast", _subject, false, false] spawn AP_fnc_MP;
    };
    // ALREADY ACTIVE. Silent, and returns false -- see the contract above. A perimeter breach during a live
    // robbery therefore opens its gate and says nothing, which is exactly what that player asked for.
    if (SRV_jewelryEmporiumSRV param [1, false]) exitWith {false};
    // owner 2026-06-16 (#302): server-authoritative one-federal-event-at-a-time gate (client check has a window).
    if (["jewelry"] call APS_fnc_fedEventActive) exitWith {
        "Another major crime is already in progress -- the Jewelry Emporium job is a no-go." call _fnc_jsSay;
        false
    };
    // owner 2026-06-13: SERVER-AUTHORITATIVE cop gate (copsRequired = slot 6, default 6). Was client-only;
    // a JIP client whose AP_betaZeroCops hadn't synced could trip it understaffed. exitWith here is THIS
    // FUNCTION's scope (mirrors the active-check above) -> stops the start before it activates, and returns
    // false to whichever case called it.
    // owner 2026-06-22 (#496): TENURED cop count (continuously on-duty >= AP_copTenureReq), anti soft-log.
    // owner 2026-07-03: floor the Jewelry Emporium cop requirement at 1 (beta data may hold 0).
    if ((([] call AP_fnc_tenuredCops) < ((SRV_jewelryEmporiumSRV param [6, 6]) max 1)) && {!(localNamespace getVariable ["AP_betaZeroCops", false])}) exitWith {
        format ["The Jewelry Emporium cannot be robbed with fewer than %1 police officer(s) online.", (SRV_jewelryEmporiumSRV param [6, 6]) max 1] call _fnc_jsSay;
        false
    };
    // owner 2026-07-28 SECURITY (audit): the 30-minute re-breach cooldown was CLIENT-ONLY -- slot 0 is
    // stamped below and the only check that read it lived in the client action. A completed run now
    // pays a loaded getaway Qilin plus fourteen loot bags, so a modified client could re-run the job
    // the moment the 20-min window closed. Mirrors the ANCHOR client action's check exactly
    // (fn_jewelryEmporium "hackGate":37, param [0, -1800] > serverTime - 1800). MUST read slot 0 BEFORE the
    // assignment below replaces the array, or it would test the value it is about to write.
    // 2026-07-29: the PERIMETER client action does NOT pre-check this, by design (see the ruling above), so
    // for five of the six gates this is the only layer that enforces the cooldown -- and it must, because
    // the perimeter breach is the cheaper one to spam.
    if ((SRV_jewelryEmporiumSRV param [0, -1800]) > (serverTime - 1800)) exitWith {
        format ["The Jewelry Emporium has recently been breached! Try again in %1 minute(s).",
            ceil ((((SRV_jewelryEmporiumSRV param [0, -1800]) + 1800) - serverTime) / 60)] call _fnc_jsSay;
        false
    };
    // NOTE where the CALLER CHECK went. It used to be the fifth guard in this sequence and it is now the
    // FIRST thing each calling case does, before it calls this function at all -- see the note in the
    // header above, and the two cases themselves. It cannot live here: its geometry is per-door (30 m to
    // AP_jewelGate for the anchor, 30 m to the handed gate plus a AP_jewelGates membership test and an
    // anchor-identity refusal for the perimeter), so there is nothing shared to factor. What this
    // function receives is an ALREADY-AUTHENTICATED subject, which is why every message below can be
    // sent to it without validating anything.
    // owner 2026-07-28 SECURITY (audit): SERVER-AUTHORITATIVE cross-heist "security is high" lockout.
    // The write below arms SRV_lastRobbery, but the only thing that ever READ it was the client -- six
    // sites across five heists, this heist's own being fn_jewelryEmporium "hackGate":34 -- so the
    // whole lockout was honour-system and a modified client drilled the emporium inside another
    // heist's window at will. Interval copied verbatim from those readers, (60 * 15) = 900s, so the
    // client gate and this one cannot drift apart.
    // PLACEMENT: last of the guards, and ABOVE the slot-0 state stamp -- NOT beside the arming write a
    // few lines further down. Between the two, SRV_jewelryEmporiumSRV is already [serverTime, true, ...]
    // and published while the 20-minute window spawn that clears slot 1 is still below: a refusal there
    // would leave the emporium permanently "active", so nobody could ever start it again until a
    // restart. This guard writes nothing and refuses before any state is stamped and before the gate is
    // opened. Since 2026-07-29 that "nothing is armed" property is what makes the perimeter ruling above
    // safe -- a refused start from a perimeter breach leaves the gate open and the event untouched.
    // FRESH BOOT is never blocked -- vars.sqf:66 seeds SRV_lastRobbery = -99999, so the test needs
    // serverTime below -99099 to fire; serverTime starts at 0. The first heist of a session runs.
    // Messaged with no -SEC- row, matching the fed-event and cop-count guards above: an honest client
    // that had not yet received the publicVariable of SRV_lastRobbery can pass its own gate and land
    // here, so a row would feed the auto-ban table a false positive for a network race. That goes double
    // for a perimeter breach, whose client action does not check this state at all before it sends.
    if (SRV_lastRobbery > (serverTime - (60 * 15))) exitWith {
        format ["Security is high due to a recent robbery and you cannot start the robbery. Try again in %1 minute(s).",
            ceil ((SRV_lastRobbery - (serverTime - (60 * 15))) / 60)] call _fnc_jsSay;
        false
    };
    // owner 2026-07-28: cases before the safe. Slot 2 (safeDrilled) is the SAFE's gate, and setting
    // it here unlocked the safe the instant the alarm went off -- there was no order to the job at
    // all (jewelry-redesign.md #304). It now flips only when every display case is done -- that count
    // runs inline at the end of case "createCase" below (there is no separate "casesDone" case).
    SRV_jewelryEmporiumSRV = [serverTime, true, false, false, true, 0, SRV_jewelryEmporiumSRV param [6, 6]];
    publicVariable "SRV_jewelryEmporiumSRV";
    // owner 2026-07-28: ARM the 15-minute cross-heist "security is high" lockout. The client action
    // that reaches this function through case "robberyStarted" (core/actions/fn_jewelryEmporium.sqf
    // "hackGate":34) refuses to start while SRV_lastRobbery is inside the window, but fn_bankDrillVault
    // was the only writer in the tree, so an emporium job locked nothing out. Armed at the START,
    // alongside the slot-0 stamp on the line above, and BELOW every guard in this function (active,
    // fed-event lock, cop count, 30-min re-breach, cross-heist lockout) and below each case's own caller
    // check: a refused breach must never arm a server-wide lockout, which would be a denial of service
    // any client could trigger by spamming a forged start it knows will be rejected.
    // 2026-07-29, and this now matters MORE: the perimeter gates reach this line too, and their client
    // action does NOT pre-check the lockout, the cop count or the cooldown before it sends. Every one of
    // those guards is above this write, so a perimeter breach that cannot start the job arms nothing --
    // it only opens its own gate. publicVariable is mandatory -- every reader is client-side.
    SRV_lastRobbery = serverTime;
    publicVariable "SRV_lastRobbery";
    SRV_jewelryComponentDropped = false;   // owner 2026-07-18: re-arm the mining-component drop for this event
    // owner 2026-07-29: re-arm the crane load for this run. AP_jewelLoaded is the load's done-flag
    // (case "loadJewelry"), and it is armed HERE as well as cleared at the window close so that a
    // load can never be inherited across runs by either route -- a window that closed without a load,
    // or a server that somehow missed the window-close reset. It is a separate published global
    // rather than the spare slot 5 of SRV_jewelryEmporiumSRV because init.sqf:241 seeds that slot as
    // the NUMBER 0 and `if (0) then` is a type error, which would raise on every client action
    // condition built on it until the first robbery of the session.
    AP_jewelLoaded = false;
    publicVariable "AP_jewelLoaded";
    // 2026-07-29: there is NO AP_jewelLoadAccept to re-seed here any more. It was the accept channel
    // of the strip-after-accept ordering, and that ordering is what duplicated the haul -- see the
    // ORDER OF OPERATIONS block in the header. The client now removes before it sends and this file
    // refunds, so there is nothing for the server to publish and nothing for a client to wait on.
    // owner 2026-07-28: OPEN THE ANCHOR GATE. The breach is what gets you in, and until this line
    // finishing it did not actually open anything -- the gate was never locked in the first place, so
    // the bar, the alarm, the wanted sweep and the cop requirement all hung off a door that already
    // stood open (owner in game: "everything is unlocked"). APS_fnc_maldenJewelSRV now seals it at boot,
    // so this is the only thing that opens it, and it sits below every guard above: a refused breach
    // (fed event live, understaffed, inside the 30-minute cooldown, inside the cross-heist lockout,
    // forged caller) never reaches this line and leaves the anchor shut. Same call the bank's drill
    // makes on success (fn_bankDrillVault:196).
    // ["open"] WITH NO GATE ARGUMENT MEANS THE ANCHOR, and only the anchor (APS_fnc_maldenJewelSRV
    // defaults its gate list to [AP_jewelGate]). 2026-07-29: that is now deliberately run for a
    // PERIMETER breach as well, and it is not an oversight -- once the job is live the client hides
    // "Breach Emporium Gate" (its condition requires slot 1 false) and this file's own already-active
    // guard refuses it, so without this line a job started at a far concrete gate would leave the anchor
    // welded shut for the entire 20-minute window. That would be a WORSE state than before the change.
    // The anchor is also the alarm emitter the client's per-frame say3D reads, and it is the one gate the
    // 10-minute perimeter re-seal timer can never touch, so opening it is what guarantees the crew a way
    // in and out for the whole window. It is self-guarding on a null anchor and idempotent.
    ["open"] call APS_fnc_maldenJewelSRV;
    [[0, "The Jewelry Emporium is being ROBBED! MaxSec must respond!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
    [["The Jewelry Emporium alarm has been tripped -- respond now!", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
    // owner 2026-06-16 (#301): robbing the emporium never applied a wanted charge. Charge the breacher and
    // any civilian within 90m with "Jewelry Emporium Robbery" (charge 76), mirroring the bank's 90m pass.
    // The radius is unchanged at 90 m and it is measured from AP_JEWEL_CENTRE, not from the gate, so a
    // perimeter breacher is inside it too: the furthest gate is 43.98 m out (boot log), which is half the
    // sweep. Nobody who breaches any of the six escapes the charge, and nobody NEW is caught by widening
    // the entry points, because the sweep never keyed off the gate in the first place.
    {if ((side _x isEqualTo civilian) && {(_x distance2D AP_JEWEL_CENTRE) < 90}) then { [76, _x] call APS_fnc_wantedAdd; };
    } forEach allPlayers;
    // WHICH DOOR started it, on the line. The anchor and the five perimeter gates are the same event now,
    // so the log has to say which one tripped it or a report of "the alarm went off and nobody was near
    // the back gate" is unreadable. _viaGate is for this and nothing else.
    private _jsAnchor = missionNamespace getVariable ["AP_jewelGate", objNull];
    private _jsVia = if (isNull _viaGate) then {"an UNIDENTIFIED gate (nothing was passed in)"} else {
        if (_viaGate isEqualTo _jsAnchor) then {"the ANCHOR gate"} else {"a PERIMETER gate"}};
    diag_log format ["[LooneyBin][jewelry] robbery started by %1 -- breached %2 (%3 at %4)",
        name _subject, _jsVia, typeOf _viaGate, getPosATL _viaGate];
    [] spawn {private _endAt = serverTime + 1200;   // 20-min window
        waitUntil { uiSleep 5; serverTime > _endAt };
        SRV_jewelryEmporiumSRV set [1, false];
        SRV_jewelryEmporiumSRV set [2, false];
        SRV_jewelryEmporiumSRV set [3, false];
        SRV_jewelryEmporiumSRV set [4, false];
        publicVariable "SRV_jewelryEmporiumSRV";
        // owner 2026-07-29: clear the crane load's done-flag with the rest of the run state, so the
        // next robbery starts from "not loaded". Unconditional, like every other line in this reset:
        // a window that closed on a crew who never loaded has to clear it just the same, because the
        // flag is only ever read as "has THIS run been loaded".
        AP_jewelLoaded = false;
        publicVariable "AP_jewelLoaded";
        // No accept row to clear with it: AP_jewelLoadAccept went with the ordering that needed it.
        // owner 2026-07-28: ARM THE LOCKOUT AT THE END TOO (owner decision). The start arm at :105 runs
        // for 900s while this window is 1200s, so by the time the job actually ends the start arm has
        // been expired for 300s and bought no cooling-off at all. Re-arming here delivers the intended
        // 15 quiet minutes; keeping the start arm preserves the anti-overlap behaviour it was added for.
        // DoS: unreachable by a refusal. This spawn is created at the very bottom of _fnc_jewelStart,
        // BELOW every guard in it -- already-active, the fed-event lock, the cop count, the 30-minute
        // re-breach and the cross-heist lockout are all FLAT exitWiths of that function's own scope --
        // and below each calling case's caller check, which runs before the function is called at all
        // (the anchor case's nested check refuses via the _data = [] sentinel that its flat check turns
        // into a real exit). A refused breach therefore never creates this spawn, so it can never arm
        // anything. 2026-07-29: that reasoning covers the five PERIMETER gates too, now that they reach
        // the same function -- a perimeter breach whose start is refused opens a gate and creates
        // nothing.
        // Inside the spawn there is exactly one path: the waitUntil above returns only on
        // serverTime > _endAt, and everything from there down runs unconditionally, once. The emporium
        // has no cop-stop path -- the window closing IS its end, welded or not -- and a window that
        // closed on a job the crew failed is still a heist that ran for 20 minutes, so it arms too.
        SRV_lastRobbery = serverTime;
        publicVariable "SRV_lastRobbery";
        // restore the scene for the next run: display cases + safe lootable again
        {_x setVariable ["AP_jewelCaseLooted", false, true];
            _x setVariable ["AP_droppedItems", [], true];   // owner 2026-07-18: clear any un-grabbed mining component
        } forEach (nearestObjects [AP_JEWEL_CENTRE, ["Coffin_02_F"], 120]);
        // owner 2026-07-28: sweep the un-grabbed loot. Per-case trophies (case "createCase" below) are
        // AP_furniture-exempt, so fn_cleanup never takes them and nothing else deleted them -- they
        // piled up across runs until restart while the re-arm above let every case spawn another one.
        // Exact class, and 120 m of the emporium centre (the same radius the case gate counts over) so
        // it cannot reach an unrelated prop. This also covers the welded safe's four trophies; the
        // tighter sweep below stays as a backstop for a safe that somehow sits outside this radius.
        { deleteVehicle _x; } forEach (nearestObjects [AP_JEWEL_CENTRE, ["Land_Trophy_01_gold_F"], 120]);
        // undo the weld: delete the open safe and its un-grabbed trophies, un-hide the closed one.
        if (!isNil "AP_jewelSafeOpen" && {!isNull AP_jewelSafeOpen}) then {
            { deleteVehicle _x; } forEach (nearestObjects [getPosATL AP_jewelSafeOpen, ["Land_Trophy_01_gold_F"], 6]);
            deleteVehicle AP_jewelSafeOpen;
        };
        AP_jewelSafeOpen = objNull;
        publicVariable "AP_jewelSafeOpen";
        // owner 2026-07-28: un-hide the closed safe AND drop the welder claim. The client writes
        // AP_jewelWelder onto this safe to reserve the cut and refuses anyone else who holds it; the
        // safe is persistent (hidden/un-hidden, never recreated), so without this the claim outlived
        // the window and from the second run on only the original welder could ever weld again -- it
        // self-healed only if that player disconnected.
        if (!isNil "AP_jewelSafe" && {!isNull AP_jewelSafe}) then { AP_jewelSafe hideObjectGlobal false;
            AP_jewelSafe setVariable ["AP_jewelWelder", objNull, true];
        };
        // owner 2026-07-28: RE-SEAL THE GATE, so the next run starts from a locked one exactly as a
        // fresh boot does. Part of the scene restore, alongside the cases and the safe above -- the
        // gate is the one piece of it a player can have changed by hand, because for the whole window
        // bis_disabled_Door_1 is 0 and the class's own "Open Door" action is live.
        // That hand-open is survived: ["seal"] disables the doors first and then drives the door
        // ANIMATION SOURCES back to phase 0, not just the animations. A source keeps driving its
        // animation, so an animate-only seal would be silently overridden by whatever BIS_fnc_Door
        // left behind and the gate would stand open into the next run -- the bug the Fed's test pass
        // step 25 exists to catch (maldenfed_testpass.md:90). See APS_fnc_maldenJewelSRV.
        // Unconditional: ["seal"] is idempotent and self-guards a null gate, so it is also the right
        // thing to run for a window that closed without the safe ever being welded.
        ["seal"] call APS_fnc_maldenJewelSRV;
        // the Qilin is deliberately NOT deleted here -- it is the crew's reward and survives the
        // window closing. It disappears at the next restart because it has no DB identity.
        diag_log "[LooneyBin][jewelry] event window closed, scene reset";};
    // The whole start ran. Everything below this line in the file is a switch case again.
    true
};

// =====================================================================================================
// owner 2026-07-29: THE ANCHOR GATE. This case is now CALLER AUTHENTICATION plus one call, and every state
// write it used to make inline lives in _fnc_jewelStart above, verbatim, so the anchor and the five
// perimeter gates cannot drift apart. The anchor's observable behaviour is unchanged: it authenticates, and
// on success it runs exactly the sequence it ran before, INCLUDING opening the anchor only after every guard
// has passed -- so a refused anchor breach still leaves the anchor shut.
//
// owner 2026-07-28 SECURITY (audit): this case was the ONLY one here with no caller authentication.
// The function is remoteExec-whitelisted with allowedTargets = 2, so a modified client could start the
// robbery from anywhere on the map -- skipping the Sequence Breach, the cyberdeck, the 10 m gate proximity
// and the on-foot check that the client action enforces. The part that reaches INNOCENT players is the 90 m
// sweep inside _fnc_jewelStart: wanted charge 76 is applied to every civilian near the emporium, people who
// may not even know a heist started. It also consumes the fed-event lock and stamps the 30-minute cooldown,
// so it doubles as a griefing tool against the whole server.
// Same shape the "weldSafe" and "createCase" cases carry, same _data = [] sentinel: an exitWith inside a
// then {} leaves only that block, which this codebase has shipped as a bug three times, so the flat
// top-level check underneath is what actually leaves the case.
// AP_jewelGate read GUARDED -- the bare form raises if APS_fnc_maldenJewelSRV never ran, and this is a
// security gate, so it must refuse rather than throw.
// Attributed to _rsCaller, not objNull: a null gate publishes objNull to the clients too, and the client
// action refuses on exactly that (fn_jewelryEmporium "hackGate" reads the same guarded global), so no
// legitimate breach can ever reach that refusal -- getting there requires a forged call. isNull _rsCaller
// logs against objNull on its own, which covers the caller-disconnected race.
// THE SUBJECT HANDED ON IS THE AUTHENTICATED PLAYER, not the payload's _robber, which nothing validates.
// _robber survives as the identity of last resort for a SERVER-INTERNAL call (remoteExecutedOwner 0), where
// there is no client to resolve -- the same shape case "weldSafe" uses for _welder. For a client call
// _robber is now ignored entirely, which closes a small spam vector: the fed-event, cop-count, cooldown and
// lockout refusals used to titleText a client-supplied name, so a modified client could have bounced those
// messages off any player on the server.
// =====================================================================================================
switch (_caseType) do {case "robberyStarted": {_data params [["_robber", objNull, [objNull]]];
        private _srcRS = remoteExecutedOwner;   // 0 == server-internal = trusted
        private _rsCaller = if (_srcRS isEqualTo 0) then { _robber } else {
            (allPlayers select { owner _x isEqualTo _srcRS }) param [0, objNull] };
        private _rsGate = missionNamespace getVariable ["AP_jewelGate", objNull];
        if (_srcRS isNotEqualTo 0) then {
            if (isNull _rsCaller || {isNull _rsGate} || {(_rsCaller distance _rsGate) > 30}) exitWith {
                ["-SEC-", _rsCaller, "BLOCKED jewelry robberyStarted (caller not at the gate)"] call APS_fnc_logIt;
                _data = [];   // signal for the flat guard below
            };};
        if (_data isEqualTo []) exitWith {};
        [_rsCaller, _rsGate] call _fnc_jewelStart;};
    // =================================================================================================
    // owner 2026-07-29 (maldenjewelry2.md #1): THE FIVE OTHER GATES. The client's per-gate sequence breach
    // (core/actions/fn_jewelryEmporium.sqf case "perimeterGate") has always sent HERE, and until this case
    // existed the send fell through to the `default` branch at the bottom of the file: the hack completed,
    // the server logged "unhandled case" and dropped the call, and the gate never opened.
    // That is a REGRESSION, not a half-built feature. Before APS_fnc_maldenJewelSRV started sealing the
    // whole perimeter these five gates stood open permanently -- the owner's "everything is unlocked" --
    // so a seal with no release welds them shut for the life of the server. The seal's own header says it:
    // "A SEALED GATE MUST HAVE A WAY OPEN, or it is welded for the life of the server."
    //
    // THE ANCHOR IS REFUSED HERE, not merely excluded by the client. AP_jewelGates contains the breach
    // anchor as well (the Fed's AP_fedGates does the same), and opening the anchor through this case
    // would swing the one gate whose job is to trip the alarm WITHOUT starting the event: no cop-count
    // check, no fed-event lock, no 30-minute cooldown, no wanted sweep, no alarm, and slot 4 never set --
    // every guard in case "robberyStarted" bypassed, and the crew walks into an emporium that never knew
    // it was robbed. The client already excludes it; the server must not rely on the client for that.
    // The refusal is by OBJECT IDENTITY against AP_jewelGate, and it refuses outright when the anchor is
    // objNull: a null anchor means the boot resolver published nothing, so this case cannot prove the gate
    // it was handed is not the anchor, and "cannot prove" has to mean "no".
    //
    // No event-state requirement on OPENING THE GATE, deliberately: breaching one before, during or after a
    // robbery is all legitimate, because it is a way through a fence. What has changed is what happens
    // AFTERWARDS -- see the block at the bottom of this case.
    //
    // 2026-07-29, OWNER REPORT ON b0131: THIS CASE NOW STARTS THE ROBBERY TOO.
    // It used to end at the gate, on the reading that "the back gate is what raises the alarm". The owner's
    // report was "breaching any of the 2 gate doors on the building should let you start cracking the
    // coffins", and asked which of the six he meant he answered ANY SEALED GATE. So after opening the gate
    // this case calls _fnc_jewelStart -- the same function case "robberyStarted" calls, subject to every one
    // of its guards -- and the sentence this note used to carry ("these gates do NOT start the job and do NOT
    // raise the alarm") is now WRONG and has been deleted rather than softened. The reasoning, the ruling on
    // whether a refused start still opens the gate, and the accepted consequence that the alarm can now be
    // tripped from 44 m out are all in the header of _fnc_jewelStart, not repeated here.
    // The gate still pays nothing BY ITSELF: every payout in this file gates on state only _fnc_jewelStart
    // writes, and if that function refuses, this case has opened a fence and done nothing else.
    // =================================================================================================
    case "perimeterGate": {_data params [["_gate", objNull, [objNull]]];
        // The subject comes from remoteExecutedOwner and NOTHING here is attributed to the payload -- the
        // payload carries no player object at all, so there is nothing in it that could name a third
        // party. A client-supplied name in a -SEC- row is how an innocent player gets framed into the
        // table CLANKR auto-bans from, and this server has already auto-banned legitimate players once.
        private _srcPG = remoteExecutedOwner;   // 0 == server-internal = trusted
        private _pgCaller = if (_srcPG isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _srcPG }) param [0, objNull] };
        private _pgGates  = missionNamespace getVariable ["AP_jewelGates", []];
        private _pgAnchor = missionNamespace getVariable ["AP_jewelGate", objNull];
        // Every guard below is a FLAT top-level exitWith of the case block. An exitWith nested in a
        // then {} leaves only that block and falls through into the code after it, which this codebase has
        // shipped as a bug three times -- the one guard here that has to sit inside a then {} (the client
        // range check) uses the _data = [] sentinel the other cases use, and the flat check under it is
        // what actually leaves.
        if (isNull _gate) exitWith {
            ["-SEC-", _pgCaller, "BLOCKED jewelry perimeterGate (null gate)"] call APS_fnc_logIt;};
        // MEMBERSHIP. The published list is the whitelist, so this case can only ever animate one of the
        // six gates the boot resolver found -- not whatever object a forged call hands it. Read guarded:
        // the bare form raises if APS_fnc_maldenJewelSRV never ran, and a security gate must refuse
        // rather than throw. (APS_fnc_maldenJewelSRV's own ["open", _gate] repeats this check for its own
        // reasons; it is not redundant here, because this is where the -SEC- row belongs.)
        if !(_gate in _pgGates) exitWith {
            ["-SEC-", _pgCaller, format ["BLOCKED jewelry perimeterGate (%1 is not in AP_jewelGates)", typeOf _gate]] call APS_fnc_logIt;};
        if (isNull _pgAnchor) exitWith {
            ["-SEC-", objNull, "jewelry perimeterGate: AP_jewelGate is objNull, so the breach anchor cannot be identified and no gate can be safely opened (server fault, not the caller)"] call APS_fnc_logIt;};
        if (_gate isEqualTo _pgAnchor) exitWith {
            ["-SEC-", _pgCaller, "BLOCKED jewelry perimeterGate (that is the BREACH ANCHOR -- opening it here would skip the whole heist)"] call APS_fnc_logIt;};
        // SIDE and RANGE, for a client caller only. 30 m, matching the slack the other cases in this file
        // allow between the client's 10 m offer radius and the server's refusal, so lag or a step sideways
        // cannot void a completed minigame. An honest client cannot reach either refusal: fn_jewelryEmporium
        // case "perimeterGate" tests civilian and 10 m to the same object before it sends.
        if (_srcPG isNotEqualTo 0) then {
            if (isNull _pgCaller || {!((side _pgCaller) isEqualTo civilian)} || {(_pgCaller distance _gate) > 30}) exitWith {
                ["-SEC-", _pgCaller, format ["BLOCKED jewelry perimeterGate (caller not a civilian at the gate, range %1)",
                    if (isNull _pgCaller) then {-1} else {round (_pgCaller distance _gate)}]] call APS_fnc_logIt;
                _data = [];   // signal for the flat guard below
            };};
        if (_data isEqualTo []) exitWith {};
        // Delegate. ["open", _gate] is the mode APS_fnc_maldenJewelSRV added for exactly this: it drives
        // bis_disabled_Door_N, the door animations AND their animation sources on that ONE gate, and it
        // re-checks membership itself. That function has no CfgRE.hpp entry, so this case is the only way
        // a client can ever reach it, and it lands here downstream of every guard above.
        ["open", _gate] call APS_fnc_maldenJewelSRV;
        diag_log format ["[LooneyBin][jewelry] perimeter gate breached by %1: %2 at %3", name _pgCaller, typeOf _gate, getPosATL _gate];
        // =============================================================================================
        // owner 2026-07-29: RE-SEAL THIS GATE ON A TIMER, INDEPENDENT OF THE ROBBERY.
        // The hole: this case deliberately requires no event state (a fence is a way through a fence,
        // before, during or after a job), and the only other thing that ever seals is ["seal"] -- which
        // runs at boot and at the CLOSE OF A ROBBERY'S 20-MINUTE WINDOW. On a server where no robbery is
        // ever started, or every one is abandoned before it starts, nothing closes that window and nothing
        // re-seals: hacking each of the five perimeter gates ONCE left all five standing open for the rest
        // of the session, and the perimeter the 2026-07-29 seal was written to create quietly stopped
        // existing after five breaches. One breach must not buy a permanent hole.
        //
        // TEN MINUTES, and the number is a judgement call the owner should see:
        //   * long enough to be worth hacking. A crew that breaches a perimeter gate to get in wants it
        //     open behind them: the robbery window is 20 min, the crane bar alone is 2 min, and a full run
        //     is eight case hacks plus the safe's terminal. 10 min covers getting in, working the shop and
        //     leaving through the same gate for the bulk of a run -- and it is FIVE times the 2-minute
        //     load, so the getaway is never cut off by it.
        //   * short enough that the seal means something. The next job cannot start for at least 30 min
        //     (the slot-0 re-breach cooldown), so a gate opened out of spite between runs is shut a
        //     comfortable 20 min before anybody could use it, and the no-robbery-ever case now self-heals
        //     within 10 min of the last breach instead of never.
        // Deliberately NOT tied to the event: tying it to the window close is the bug. This timer runs on
        // its own clock and does not read SRV_jewelryEmporiumSRV at all.
        // The ANCHOR is never scheduled here, and cannot be: this case refuses the anchor outright a few
        // lines above, so only perimeter gates ever reach this line. That matters -- the anchor is the gate
        // case "robberyStarted" opens, and re-sealing it under a live robbery would shut the way in.
        // RE-BREACH IS HANDLED BY A STAMP, not by hoping the timers do not overlap. Each breach writes
        // serverTime onto the gate and its own thread only seals if that stamp is still the one it wrote:
        // a player who re-breaches the same gate 9 minutes in gets a fresh 10 minutes, and the older
        // thread retires without touching it. Without this the first timer would slam the gate shut on a
        // crew who had legitimately just reopened it. The stamp is server-local (setVariable's third
        // argument is false): nothing on a client reads it, and the seal itself is what publishes state.
        // ["seal", _gate] re-checks AP_jewelGates membership itself and is idempotent, so a window close
        // that already sealed everything simply makes this a no-op.
        // =============================================================================================
        private _pgStamp = serverTime;
        _gate setVariable ["AP_jewelGateOpenAt", _pgStamp, false];
        [_gate, _pgStamp] spawn {
            params ["_g", "_st"];
            uiSleep 600;   // 10 minutes -- see the note above
            if (isNull _g) exitWith {};
            if ((_g getVariable ["AP_jewelGateOpenAt", -1]) isNotEqualTo _st) exitWith {
                diag_log format ["[LooneyBin][jewelry] perimeter re-seal for %1 stood down -- the gate was breached again since, and that newer breach owns the timer", typeOf _g];};
            ["seal", _g] call APS_fnc_maldenJewelSRV;
            diag_log format ["[LooneyBin][jewelry] perimeter gate RE-SEALED after 10 min: %1 at %2", typeOf _g, getPosATL _g];
        };
        // =============================================================================================
        // owner 2026-07-29 (report on b0131): AND NOW START THE JOB. Same function case "robberyStarted"
        // calls, same guards, one copy -- see its header for the ruling and the reasoning.
        // _pgCaller, not anything from the payload: it is the remoteExecutedOwner player this case has
        // already proved is a civilian within 30 m of a gate that is in AP_jewelGates and is not the
        // anchor. objNull for a server-internal call, which _fnc_jewelStart's own message helper drops.
        //
        // LAST, AFTER the gate is open and the re-seal timer is scheduled, and that order is the ruling in
        // action: the breach is a completed action that settles on its own terms, and the start is a
        // CONSEQUENCE of it. A refused start therefore cannot retroactively void a Sequence Breach the
        // player already won -- the gate is open before _fnc_jewelStart is ever asked. It refuses in five
        // ways (a job already running, a live fed event, too few tenured cops, the 30-minute re-breach
        // cooldown, the 15-minute cross-heist lockout); the first is silent because it is not a refusal at
        // all, and the other four titleText the reason to this player. None of them arms anything: every
        // guard sits above the first state write in that function.
        // THE RETURN VALUE IS DELIBERATELY DISCARDED. There is nothing left for this case to do either way,
        // and the one thing that must NOT happen is a second message: the gate visibly swings open, so
        // "your job did not start because X" is the only sentence this player needs.
        // THE RE-SEAL TIMER IS NOT CANCELLED WHEN THE START SUCCEEDS, on purpose. It would leave the
        // breached gate open for the full 20-minute window, which sounds kinder and is not needed: the
        // anchor is opened by _fnc_jewelStart and stays open until the window closes, so the crew always has
        // a way in and out. Keeping one unconditional timer per breach is also what keeps that whole
        // mechanism free of event state, which is the bug it was written to avoid.
        // =============================================================================================
        [_pgCaller, _gate] call _fnc_jewelStart;};
    case "weldSafe": {_data params [["_safe", objNull, [objNull]], ["_robber", objNull, [objNull]]];
        if !(SRV_jewelryEmporiumSRV param [1, false]) exitWith {};
        // owner 2026-07-24 SECURITY (audit): the active-event check above was the ONLY guard, so during any
        // live robbery any client could remoteExec this and instantly flip safeWelded -- which resolves the
        // LoonyBets "jewelry" market YES on demand, letting a bettor settle their own wager. Require the
        // safe to have actually been DRILLED first (index 2, the real prerequisite for welding) and a
        // client caller to be standing at it.
        // owner 2026-07-28, caught in review: resolve the AUTHENTICATED caller FIRST, and log every -SEC-
        // row in this case against that and never against _robber. _robber is client-supplied -- it is
        // whoever the caller SAID was welding -- so a modified client could name an innocent player in the
        // payload and manufacture ban-table evidence against them. remoteExecutedOwner is the engine's own
        // answer to "which machine actually sent this" and cannot be forged from the client. This server has
        // already auto-banned legitimate players off a false positive once, so a framing vector into that
        // table is worth more than the convenience of the caller-supplied name.
        private _srcWS = remoteExecutedOwner;   // 0 == server-internal = trusted
        private _wsCaller = if (_srcWS isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _srcWS }) param [0, objNull] };
        if !(SRV_jewelryEmporiumSRV param [2, false]) exitWith {
            ["-SEC-", _wsCaller, "BLOCKED jewelry weldSafe (safe not drilled)"] call APS_fnc_logIt;};
        if (_srcWS isNotEqualTo 0) then {
            if (isNull _wsCaller || {isNull _safe} || {(_wsCaller distance _safe) > 30}) exitWith {
                ["-SEC-", _wsCaller, "BLOCKED jewelry weldSafe (caller not at the safe)"] call APS_fnc_logIt;
                _data = [];   // signal for the guard below
            };};
        if (_data isEqualTo []) exitWith {};
        // owner 2026-07-28 SECURITY (audit): NOTHING read slot 3, so a repeat call ran the whole block
        // below again -- a SECOND loaded getaway Qilin (10x jewelBag = $25,000), four more gold trophies,
        // keys re-issued to everyone in 400 m -- and orphaned the previous open safe, which is
        // AP_furniture-exempt so fn_cleanup never sweeps it. The only thing preventing a repeat was the
        // client's own AP_jewelWelder claim, and client-only gating on THIS case is precisely what the
        // 2026-07-24 note above exists because of. Flat and top-level, before the set.
        // diag_log, not APS_fnc_logIt: two players finishing the cut in the same tick is a legitimate
        // race, and a -SEC- row here would be forged-looking evidence against an innocent player.
        if (SRV_jewelryEmporiumSRV param [3, false]) exitWith {
            diag_log format ["[LooneyBin][jewelry] weldSafe ignored -- the safe is already welded (caller %1)", name _wsCaller];};
        // owner 2026-07-28: everything from here on dereferences AP_jewelSafe, while only the RESET path
        // guarded it. objNull would make getPosATL return [0,0,0] and drop the open safe plus four
        // trophies on the map corner AFTER slot 3 is set -- a half-open
        // state nothing recovers; nil throws at the same point. Guard before the state changes.
        // Logged against objNull, not _robber: a missing safe is a SERVER fault (the boot resolver never
        // ran, or the object was deleted) and can never be the player's doing, yet it would fire on every
        // attempt for as long as the fault lasts. Attributing that to whoever finished the cut feeds
        // CLANKR's auto-ban table with a steady stream of false evidence. Same reasoning as :208/:210.
        if (isNil "AP_jewelSafe" || {isNull AP_jewelSafe}) exitWith {
            ["-SEC-", objNull, "jewelry weldSafe: no safe object (server fault, not the caller)"] call APS_fnc_logIt;};
        // owner 2026-07-28 SECURITY (audit): the range check above measured the CLIENT-SUPPLIED _safe,
        // which is never referenced again -- everything below uses AP_jewelSafe. A hostile caller could
        // therefore satisfy it by standing next to whatever object it passed in. Pin the two together:
        // past this line the range check provably measured the real safe.
        if (_safe isNotEqualTo AP_jewelSafe) exitWith {
            ["-SEC-", _wsCaller, "BLOCKED jewelry weldSafe (safe object mismatch)"] call APS_fnc_logIt;};
        SRV_jewelryEmporiumSRV set [3, true];
        publicVariable "SRV_jewelryEmporiumSRV";
        // owner 2026-07-28 (parity): record the COMPLETED heist. jewelryscompleted is a registered stat
        // slot (fn_statArrUpdate, slot 138) that NOTHING on either machine ever incremented, so the
        // emporium could never contribute to the "Completed 25 Jewelry Emporium heists" title, while
        // jewelrydrilled and jewelrycasesopened both recorded normally.
        // WELDING THE SAFE is what "completed" means here, and this file is what says so: the window
        // close resolves the LoonyBets market NO on exactly !(slot 3) (:91) and the line above resolves
        // it YES, so slot 3 already IS this codebase's own oracle for "the job came off". Looting the
        // contents is the wrong mark -- it is client-only with no server case behind it, it is up to
        // nineteen separate pickups rather than one moment, any passer-by can grab a trophy they did no
        // work for, and a crew that welds and runs from MaxSec has still done the heist by every other
        // measure in this file (market YES, "the safe is OPEN" broadcast). It stays the completion mark
        // after the 2026-07-29 redesign moved the Qilin to case "loadJewelry": the load is a REWARD stage
        // a crew can decline (drive off with the bags in hand and skip it), so hanging the completion stat
        // on it would stop counting heists that plainly came off.
        // ONCE PER RUN by construction: the repeat guard at :162 reads slot 3 and exits, and every other
        // failure path exits above it, so this line is reachable once per robbery. Deliberately NOT
        // re-testing slot 3 here -- the set above mutated the array in place, so a read now would always
        // return true and a guard built on it would be dead code.
        // Server-side rather than in the client action, matching convoysdone (fn_endConvoyRobbery:49),
        // the only other heist-COMPLETION stat in the codebase. fedsafeopened and jewelrydrilled sit
        // client-side because they count a per-ACTION attempt the actor's own client can see; a
        // once-per-run completion cannot be counted there, because two players finishing the cut in the
        // same tick -- the legitimate race the :160 note describes -- would each bump it on their own
        // machine before either call reached the guard above.
        // Credited to the AUTHENTICATED caller, not to _robber: _robber is a raw client-supplied
        // parameter that nothing validates (the range check at :149 measures the remoteExecutedOwner
        // player, not this one), so crediting it would let a modified client hand title progress to any
        // player it cared to name. _srcWS is 0 only for a server-internal call, where _robber is the
        // sole identity available. A null welder is dropped rather than logged: the caller having
        // disconnected between sending and processing is a race, not wrongdoing, and a -SEC- row here
        // would be false evidence against whoever finished the cut.
        private _welder = if (_srcWS isEqualTo 0) then {_robber} else {(allPlayers select {owner _x isEqualTo _srcWS}) param [0, objNull]};
        if !(isNull _welder) then {
            [["jewelryscompleted", 1], "AP_fnc_statArrUpdate", _welder, false, false] spawn AP_fnc_MP;
        };

        // owner 2026-07-28 (#306): the safe has never actually OPENED on either map -- this case set the
        // flag and stopped, so the Fridge_01_open_F that takeSafeContents targets never existed and no
        // loot was ever spawned. Swap the closed safe for the open one and put the prize in it.
        private _sp = getPosATL AP_jewelSafe;
        private _sd = getDir AP_jewelSafe;
        hideObjectGlobal AP_jewelSafe;
        AP_jewelSafeOpen = createVehicle ["Fridge_01_open_F", _sp, [], 0, "CAN_COLLIDE"];
        AP_jewelSafeOpen setPosATL _sp;
        AP_jewelSafeOpen setDir _sd;
        AP_jewelSafeOpen allowDamage false;
        AP_jewelSafeOpen enableSimulationGlobal false;
        AP_jewelSafeOpen setVariable ["AP_furniture", true, true];   // exempt from fn_cleanup
        AP_jewelSafeOpen setVariable ["AP_safeLooted", false, true];
        // owner 2026-07-29 (maldenjewelry2.md #4): THE HOPE DIAMOND. One per run, the jackpot, and the
        // only real variance in the job. It is delivered as a FLAG ON THE OPEN SAFE, and the client's
        // existing "Take Safe Loot" action (fn_jewelryEmporium case "takeSafeContents") grants it. That
        // flag is the whole contract and it is the ONLY delivery route: see the note there.
        //
        // IT USED TO RIDE AP_droppedItems, on the assumption that the generic "Pick Up Item(s)" path
        // would carry it. IT CANNOT, and the failure is silent and player-facing -- the item appears in
        // the menu and then cannot be taken. Verified 2026-07-29 by reading the path end to end:
        //   * fn_setupActions.sqf:100 offers the action on ANY object with a non-empty AP_droppedItems
        //     within 5 m, so the option DOES appear on a Fridge_01_open_F.
        //   * AP_fnc_menuPickupItems takes the holder as an ARGUMENT, claims AP_inUse on it and lists
        //     its contents, so the dialog DOES populate with "1x Hope Diamond".
        //   * the Pick Up button then calls AP_fnc_pickupSelected, which THROWS THAT ARGUMENT AWAY and
        //     re-derives the holder from a hard-coded two-class switch on cursorObject --
        //     "Land_Suitcase_F" and "Box_Syndicate_WpsLaunch_F", defaulting to
        //     nearestObject [player, "Land_Suitcase_F"]. A Fridge_01_open_F is neither, so _obj is some
        //     other object or objNull, and the `player distance _obj > 5` / AP_inUse-is-me checks then
        //     close the dialog and grant nothing.
        // Every WORKING AP_droppedItems holder in this build is one of those two classes: the Fed's gold
        // and component cases, the bank vault's cash and component cases, the Loony Bin's loot and
        // remains, APS_fnc_createItem's death drops. The two that are not are both this heist's --
        // this line as it stood, and the crypto mining component case "createCase" hangs on a Coffin_02_F
        // further down (unfixed, pre-dates this work, and out of this file's reach: the fix belongs in
        // AP_fnc_pickupSelected).
        // AP_questloot is KEPT even though nothing can now put an item on this safe. fn_pickupItem.sqf:82
        // deleteVehicle's a holder the moment its dropped-item list empties and its ONLY opt-out is that
        // flag -- it does NOT look at AP_furniture -- so if anything ever does hang loot here again, the
        // flag is what stops the take from destroying the open safe, taking "Take Safe Loot" and
        // AP_jewelSafeOpen with it and leaving the window-close restore reaching for a deleted object.
        // It also refuses a STORE into the safe (fn_storeInventory.sqf:37), which is wanted.
        AP_jewelSafeOpen setVariable ["AP_questloot", true, true];
        AP_jewelSafeOpen setVariable ["AP_jewelHopeInSafe", true, true];
        publicVariable "AP_jewelSafeOpen";

        // 4 grabbable trophies + the open safe's own single take = the agreed 5 bags. Trophies rather
        // than one big grant so a crew shares the prize instead of the first player taking all of it;
        // the existing trophy pickup action already converts each to a jewelBag.
        // owner 2026-07-29 (maldenjewelry2.md #2b): PLACED ON THE FLOOR THE SAFE STANDS ON, not floating.
        // The old row was `AP_jewelSafe modelToWorld [(_i - 1.5) * 0.7, 0.8, 0]` and the comment beside
        // it claimed "this row is placed at its base". It was not. modelToWorld [x, y, 0] returns the
        // MODEL CENTRE plane, and Fridge_01_closed_F has no LandContact LOD, so setPosATL had put the
        // safe's BASE at the authored 0.15 and its model centre 0.5185 higher -- every one of these four
        // trophies has been hanging half a metre in the air since the day the safe first opened. Anchor
        // on the safe's own BOTTOM face instead, read off boundingBoxReal at runtime so a class swap
        // cannot silently reintroduce the offset. The +-1.05 m spread and the 0.8 m forward stand-off are
        // unchanged and still heading-relative (half-width 0.291, half-depth 0.359 -- they clear the
        // fridge body).
        // The freeze reasoning from 2026-07-28 has not changed and now lives in _fnc_placeTrophy:
        // Land_Trophy_01_gold_F -> SportItems_base_F -> Items_base_F -> ThingX carries simulation =
        // "thingX" with no override on the path, so these are live PhysX bodies and this row IS the haul.
        // Freezing costs the pickup nothing -- the action reads cursorObject, which still returns an
        // object with simulation disabled.
        private _safeRows = [];
        for "_i" from 0 to 3 do {
            (["Land_Trophy_01_gold_F", AP_jewelSafe, 0, (_i - 1.5) * 0.7, 0.8, _sd] call _fnc_placeTrophy) params ["_t", "_placedZ"];
            if !(isNull _t) then { _safeRows pushBack [_t, AP_jewelSafe, 0, _placedZ]; };
        };
        [_safeRows, "safe trophy"] call _fnc_trophySettle;
        // =============================================================================================
        // owner 2026-07-29 (report on b0131): TELL THE PLAYER THE DIAMOND IS THERE.
        // The owner reported the Hope Diamond "didn't spawn". It did. The server flagged it on the open safe
        // (AP_jewelHopeInSafe, set above) and case "takeSafeContents" logs EVERY grant path, and the dev
        // log for that run has no takeSafeContents line at all -- no grant, no refusal, no race. The take
        // was never attempted. Two mechanical explanations were put up and both were refuted with evidence
        // (cursor occlusion cannot apply: the action is offered on PROXIMITY to AP_jewelSafeOpen and the
        // server never reads a client-named object; carry weight cannot apply: the claim path asks for room
        // first and would have logged a refusal). The timeline settles it -- the weld landed at 17:42:54 and
        // the crane bar started around 17:43:26, about thirty seconds later, and that run banked 11 of the
        // 12 gold trophies. The player was standing at the safe collecting its four trophies and walked away
        // with $108,000 still in it.
        // WHAT ACTUALLY FAILED IS MESSAGING: nothing anywhere told him a diamond existed, or that it is a
        // separate scroll action on the safe rather than one of the trophies he was already picking up.
        // TWO CHANGES, both wording, and between them the words HOPE DIAMOND now appear in the one place he
        // was already looking (see fn_setupActions for the third, the scroll label itself):
        //   1. THIS GLOBAL LINE. It said "The Jewelry Emporium safe is OPEN." and stopped. Broadcast type 0
        //      is systemChat (core/functions/network/fn_broadcast.sqf), a chat row that scrolls, so it is the
        //      right channel for the whole server and the wrong one to rely on for the player who has to act.
        //      It now names the prize. Everybody hears it, which is wanted: MaxSec learning a $108,000
        //      diamond is loose is the reason the owner kept it sellable on foot (maldenjewelry2.md #4).
        //   2. A DIRECT HINT TO THE WELDER. Broadcast type 1 -> AP_fnc_handleMessage "basic", the same
        //      prominent channel case "takeSafeContents" already uses for the grant messages, addressed to
        //      the ONE player who is standing at the safe and can act. This is the message that had to exist.
        // WHAT WAS CONSIDERED AND DECLINED, so it is not re-litigated: a map marker on the safe (the safe is
        // 5 m from the welder, a marker tells him nothing he cannot see), a proximity re-announcement to
        // everyone near the safe (a third channel repeating the same sentence), and a periodic reminder while
        // the flag is set (noise, and the scroll label now carries it permanently). NO NEW STAGE AND NO NEW
        // ITEM -- the diamond is delivered exactly as it was.
        // =============================================================================================
        [[0, "The Jewelry Emporium safe is OPEN -- and the HOPE DIAMOND is inside it."], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
        // _welder is the AUTHENTICATED caller resolved above, or the payload's _robber only for a
        // server-internal call. Null-guarded for the same reason the stat bump above is: a welder who
        // disconnected between sending and processing is a race, not a fault.
        if !(isNull _welder) then {
            [["The HOPE DIAMOND is sitting in the safe. It is NOT one of the gold trophies -- stand at the safe, scroll, and choose TAKE SAFE LOOT -- HOPE DIAMOND to lift it out. Nobody gets it unless somebody does that.", "basic"], "AP_fnc_handleMessage", _welder, false, false] spawn AP_fnc_MP;
        };
        // A note on the strings above and below: keep them free of a SECOND apostrophe. tools/sqf_balance.py
        // pairs ' characters, so two of them inside one string literal make it read the text between as a
        // nested single-quoted string and mis-tally any bracket in that span -- which it did, on the first
        // cut of this very line ("the safe's own bag ... the safe's own scroll action" + a parenthesis).
        diag_log format ["[LooneyBin][jewelry] safe welded open by %1 at %2 -- %3 trophies + the safe's own bag + 1 Hope Diamond flagged on the open safe (AP_jewelHopeInSafe, taken via the scroll action on the safe itself, which reads ""Take Safe Loot -- HOPE DIAMOND"" while the diamond is still in there). The welder has been told so directly, and the global line names the diamond too.", name _robber, _sp, count _safeRows];};
    case "createCase": {_data params [["_oldCase", objNull, [objNull]]];
        if (isNull _oldCase) exitWith {};
        // owner 2026-07-24 SECURITY (audit): this spawned a Land_Trophy_01_gold_F on EVERY call with the
        // only guard being isNull _oldCase. It SET AP_jewelCaseLooted without ever CHECKING it, and never
        // looked at the event state, so any client could remoteExec it repeatedly -- on the same display
        // case, with no robbery running -- for unlimited gold trophies. Gate on the state the robbery
        // already maintains: cases must be lootable (SRV_jewelryEmporiumSRV index 4, set true on
        // robberyStarted and cleared when the window closes), this case must not have been looted already,
        // and a client caller must be standing at it.
        if !(SRV_jewelryEmporiumSRV param [4, false]) exitWith {
            ["-SEC-", objNull, "BLOCKED jewelry createCase (cases not lootable / no robbery active)"] call APS_fnc_logIt;};
        if (_oldCase getVariable ["AP_jewelCaseLooted", false]) exitWith {
            ["-SEC-", objNull, "BLOCKED jewelry createCase (case already looted)"] call APS_fnc_logIt;};
        private _srcJC = remoteExecutedOwner;   // 0 == server-internal = trusted
        if (_srcJC isNotEqualTo 0) then {private _jcCaller = (allPlayers select { owner _x isEqualTo _srcJC }) param [0, objNull];
            if (isNull _jcCaller || {(_jcCaller distance _oldCase) > 30}) exitWith {
                ["-SEC-", _jcCaller, format ["BLOCKED jewelry createCase (range %1)",
                    if (isNull _jcCaller) then {-1} else {round (_jcCaller distance _oldCase)}]] call APS_fnc_logIt;
                _data = [];   // signal: the isNull guard re-checked below exits the case
            };};
        if (_data isEqualTo []) exitWith {};
        _oldCase setVariable ["AP_jewelCaseLooted", true, true];
        // owner 2026-07-18: 1 crypto MINING COMPONENT rides on ONE smashed display case (the same container as a
        // trophy), looted via the "Pick Up Item(s)" menu. Once per event (SRV_jewelryComponentDropped, reset on
        // robberyStarted + cleared on window-close). Attached to the persistent Coffin, NOT the trophy (the
        // trophy is deleteVehicle'd the instant it's grabbed -> would lose the component to a grab race).
        if !(missionNamespace getVariable ["SRV_jewelryComponentDropped", false]) then {SRV_jewelryComponentDropped = true;
            _oldCase setVariable ["owner", "jewelry_component", true];
            _oldCase setVariable ["AP_droppedItems", [[selectRandom ["cryptoCPU","cryptoGPU","cryptoPSU","cryptoStorage","cryptoMotherboard","cryptoRam","cryptoCooler","cryptoCase"], 1]], true];
        };
        // #149: spawn the grabbable jewelry loot on the smashed case. The client (takeJewelryContents)
        // grabs a Land_Trophy_01_gold_F off the case -> jewelBag. Without this, broken cases gave no loot.
        // owner 2026-07-29 (maldenjewelry2.md #2b): ON THE LID, not a metre over it. The old row was a
        // hard-coded `modelToWorld [0, 0, 0.9]`, and 0.9 was never measured against anything -- the
        // Coffin_02_F's model centre sits mid-height (boundingBoxReal z +-0.228), so 0.9 put the trophy
        // 0.9 m above the CENTRE and therefore 0.672 m above the LID. That is the owner's "about 1 m".
        // The replacement targets the case's own top face, read off boundingBoxReal at runtime rather
        // than written down here, so it survives a class swap and does not depend on where this
        // particular model puts its origin.
        // owner 2026-07-28: this is the one that actually falls. Land_Trophy_01_gold_F inherits ThingX
        // (simulation = "thingX"), so it is a PhysX body, and the old row spawned it 0.9 m above a
        // display case standing at z ~ 1.59 -- roughly 2.5 m up, over NOTHING. The emporium floor is a
        // client-local createSimpleObject and there is no server-side geometry within 13 m, so the
        // trophy would drop the full ~2.5 m to bare terrain and come to rest about 0.9 m BELOW the floor
        // the player is standing on: the case reads as smashed and its loot is nowhere the player can
        // see or point at. _fnc_placeTrophy freezes it BEFORE it writes the position, which is the shape
        // the Fed proved sticks; simulation-off does not affect the cursorObject pickup, and the
        // AP_furniture exemption from fn_cleanup's sweep (#152, which was deleting the loot) is set
        // there too.
        (["Land_Trophy_01_gold_F", _oldCase, 1, 0, 0, getDir _oldCase] call _fnc_placeTrophy) params ["_loot", "_lootZ"];
        [[[_loot, _oldCase, 1, _lootZ]], "case trophy"] call _fnc_trophySettle;
        diag_log format ["[LooneyBin][jewelry] case smashed -> loot trophy spawned at %1", getPosATL _loot];
        // owner 2026-07-28: all display cases smashed -> the safe unlocks. Counted from the world, not
        // from a tally, so a case that was already looted when the event started (or one the designer
        // adds later) cannot desynchronise the count.
        // owner 2026-07-28 (residuals): count the SAME SET the client can actually smash. The client
        // refuses any display case outside AP_jewelryEmporiumPoly (fn_jewelryEmporium case
        // "breakGlassCase"), a box roughly 37 x 47 m, while this counted every Coffin_02_F within 120 m.
        // A case in the ring between the two -- one the designer adds tomorrow, anywhere in that 120 m --
        // would be REQUIRED by this count and SMASHABLE BY NOBODY: _left never reaches zero, slot 2 never
        // flips, the safe never unlocks. That is the stage-one deadlock moved one stage later.
        // AP_JEWEL_POLY is the server's copy of that literal (APS_fnc_maldenJewelSRV -- keep the two in
        // step; boot warns if the polygon and the radius disagree about how many cases exist).
        // getPosATL to match how the client reads case positions; inPolygon ignores Z either way.
        // The typeOf clause is the other half of "the same set": nearestObjects filters by isKindOf and so
        // also returns SUBCLASSES of Coffin_02_F, which the client rejects outright (fn_setupActions makes
        // the same point about its own lookup). A subclass placed in the emporium would otherwise be
        // required here and refused there -- the identical deadlock by a different route.
        // Read GUARDED, and fall back to radius-only when the polygon is missing: that fallback is exactly
        // today's behaviour, whereas inPolygon against a missing/empty polygon would match nothing and
        // unlock the safe on the first case smashed -- failing open on the thing this gate exists to hold.
        private _poly  = missionNamespace getVariable ["AP_JEWEL_POLY", []];
        private _cases = (nearestObjects [AP_JEWEL_CENTRE, ["Coffin_02_F"], 120]) select {(typeOf _x) isEqualTo "Coffin_02_F"};
        if (_poly isNotEqualTo []) then { _cases = _cases select {(getPosATL _x) inPolygon _poly}; };
        private _left  = { !(_x getVariable ["AP_jewelCaseLooted", false]) } count _cases;
        diag_log format ["[LooneyBin][jewelry] case smashed -- %1 of %2 remaining", _left, count _cases];
        if (_left isEqualTo 0 && {!(SRV_jewelryEmporiumSRV param [2, false])}) then {
            SRV_jewelryEmporiumSRV set [2, true];
            publicVariable "SRV_jewelryEmporiumSRV";
            [[0, "Every display case at the Jewelry Emporium has been emptied -- the crew is going for the safe!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
            [["The emporium's display cases are all gone -- they are cutting the safe. Move NOW.", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
            diag_log "[LooneyBin][jewelry] all cases done -- safe unlocked";
        };};
    // =================================================================================================
    // owner 2026-07-29: THE SAFE'S TWO PRIZES, ARBITRATED SERVER-SIDE. This case did not exist, and its
    // absence was a duplication hole worth $108,000 PER TAKER.
    // How it failed: the client action (core/actions/fn_jewelryEmporium.sqf case "takeSafeContents") read
    // AP_jewelHopeInSafe off the open safe, granted the diamond with its own AP_fnc_handleInv, and then
    // cleared the flag with `setVariable [..., true]` -- a CLIENT-ORIGINATED broadcast. AP_safeLooted, the
    // jewelBag's one-shot, worked exactly the same way. A setVariable broadcast is not instantaneous and it
    // does not serialise: two players who scroll "Take Safe Loot" inside that window BOTH read the flag as
    // still set, both grant on their own machine, and both broadcast the clear. Two diamonds, one safe --
    // and the same for the bag. The window is the network, so it widens with ping and with pop, which is
    // the opposite of what you want from a jackpot.
    // The shape is the one case "createCase" above already uses for the trophies, and for the same reason:
    // ONE machine decides, and it is the one that cannot be modified. Authenticate the caller from
    // remoteExecutedOwner, check the run really opened the safe (slot 3), check the caller is a civilian in
    // range of the open safe, CLEAR THE FLAGS FIRST, and only then grant. Clearing before granting is what
    // makes the second caller's read fail: after this line the flag is false on the server, and the server's
    // copy is the only one this case ever reads.
    // WHY IT TAKES TWO NUMBERS. The client says what it has ROOM for, and the server clamps that to what is
    // actually in the safe. Weight is client-side state the server cannot see, and the ORDER MATTERS RULE
    // from the client half has to survive: the diamond is attempted first and the bag is not taken at all
    // if the diamond will not fit, because AP_safeLooted is a one-shot and a bag that fitted beside a
    // diamond that did not would flag the safe looted with $108,000 sealed inside it and no way back in.
    // A lying client can only ever hurt itself here -- both numbers are clamped to the 0-or-1 the flags
    // allow, so the most a forged claim can win is what the safe holds, once, which is what an honest one
    // wins. It cannot name a third party either: there is no player object in the payload.
    // Every -SEC- row takes its subject from remoteExecutedOwner and objNull for a server fault, never from
    // the payload, for the reason case "weldSafe" spells out at length: a client-supplied name in this
    // table is how an innocent player gets framed into the set CLANKR auto-bans from.
    // Every guard is a FLAT top-level exitWith of the case block -- no sentinel is needed, because there is
    // no legitimate server-internal caller to special-case: a call with no client behind it has nobody to
    // grant to, so `isNull _tsCaller` refuses both that and the caller-disconnected race in one line.
    // =================================================================================================
    case "takeSafeContents": {
        _data params [["_wantHope", 0, [0]], ["_wantBag", 0, [0]]];
        private _srcTS = remoteExecutedOwner;   // 0 == server-internal, which has nobody to pay
        private _tsCaller = if (_srcTS isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _srcTS }) param [0, objNull] };
        if (isNull _tsCaller) exitWith {
            ["-SEC-", objNull, "BLOCKED jewelry takeSafeContents (no client caller -- server-internal call, or the caller disconnected between sending and processing; there is nobody to grant to either way)"] call APS_fnc_logIt;};
        if !(SRV_jewelryEmporiumSRV param [3, false]) exitWith {
            ["-SEC-", _tsCaller, "BLOCKED jewelry takeSafeContents (the safe has not been breached this run)"] call APS_fnc_logIt;};
        if (isNil "AP_jewelSafeOpen" || {isNull AP_jewelSafeOpen}) exitWith {
            ["-SEC-", objNull, "jewelry takeSafeContents: AP_jewelSafeOpen is objNull, so there is no open safe to loot (server fault, not the caller)"] call APS_fnc_logIt;};
        // SIDE and RANGE. 30 m, the slack every case in this file allows between the client's offer radius
        // (5 m to the open safe) and the server's refusal, so lag or a step sideways cannot void a take.
        if !((side _tsCaller) isEqualTo civilian) exitWith {
            ["-SEC-", _tsCaller, format ["BLOCKED jewelry takeSafeContents (caller is %1, not a civilian)", side _tsCaller]] call APS_fnc_logIt;};
        if ((_tsCaller distance AP_jewelSafeOpen) > 30) exitWith {
            ["-SEC-", _tsCaller, format ["BLOCKED jewelry takeSafeContents (caller not at the open safe, range %1)", round (_tsCaller distance AP_jewelSafeOpen)]] call APS_fnc_logIt;};
        // What is actually left, read off the SERVER's copy of the flags.
        private _hopeHere = AP_jewelSafeOpen getVariable ["AP_jewelHopeInSafe", false];
        private _bagHere  = !(AP_jewelSafeOpen getVariable ["AP_safeLooted", false]);
        // The loser of a two-player race lands here, and that is a legitimate race rather than wrongdoing:
        // diag_log and a message, no -SEC- row. This is the line that used to pay a second diamond.
        if (!_hopeHere && {!_bagHere}) exitWith {
            [[2, "This safe has already been emptied."], "AP_fnc_broadcast", _tsCaller, false, false] spawn AP_fnc_MP;
            diag_log format ["[LooneyBin][jewelry] takeSafeContents: nothing left in the safe (caller %1) -- almost certainly the loser of a same-moment race with another looter", name _tsCaller];};
        private _giveHope = if (_hopeHere && {(floor (_wantHope max 0)) > 0}) then {1} else {0};
        private _giveBag  = if (_bagHere  && {(floor (_wantBag  max 0)) > 0}) then {1} else {0};
        if ((_giveHope + _giveBag) isEqualTo 0) exitWith {
            [[2, "You do not have room for what is in this safe -- drop something and come back."], "AP_fnc_broadcast", _tsCaller, false, false] spawn AP_fnc_MP;
            diag_log format ["[LooneyBin][jewelry] takeSafeContents: caller %1 asked for nothing it had room for (wanted hope %2 / bag %3; safe holds hope %4 / bag %5) -- nothing cleared, nothing granted", name _tsCaller, _wantHope, _wantBag, _hopeHere, _bagHere];};
        // CLEAR, THEN GRANT, in that order and never the other. A grant that precedes the clear is the
        // whole bug: it leaves a window in which the flag still reads true.
        if (_giveHope isEqualTo 1) then { AP_jewelSafeOpen setVariable ["AP_jewelHopeInSafe", false, true]; };
        if (_giveBag  isEqualTo 1) then { AP_jewelSafeOpen setVariable ["AP_safeLooted", true, true]; };
        // The grant. Same server -> client route the refund in case "loadJewelry" uses and the same one
        // APS_fnc_greenhouseSRV / APS_fnc_miningSRV grant virtual items through; no CfgRE.hpp entry needed
        // because CfgRemoteExec constrains clients only, never the server.
        // If the caller has filled its inventory between its own room check and this line -- a sub-second
        // window it can only reach by deliberately loading itself up -- AP_fnc_handleInv returns false
        // and the item is gone with the flag. That is a LOSS, self-inflicted and bounded to one item, and
        // it is the correct direction to fail: re-arming the flag on a failed grant would need the client
        // to report back, and a client-reported "put it back" on a one-shot jackpot flag is a mint channel.
        // owner 2026-07-29: THE WORDING. This message used to tell the player the diamond "only pays if it
        // goes in the Qilin", which was FALSE -- jewelHope has a sell price in fn_virtItemCfg.sqf like any
        // other virtual item and always could be walked out and sold on foot. The owner has now closed the
        // question in favour of the code rather than against it: the diamond STAYS sellable on foot,
        // pocketing it is an accepted second escape route, and it is a reason to frisk. maldenjewelry2.md
        // section 4 records the retraction. So the message says the two things that are true -- there is one
        // per job, and there are two ways to cash it -- and promises nothing the code does not enforce.
        if (_giveHope isEqualTo 1) then {
            [[true, "jewelHope", 1], "AP_fnc_handleInv", _tsCaller, false, false] spawn AP_fnc_MP;
            [["You have lifted the HOPE DIAMOND out of the safe -- one per job. Load it in the Qilin, or carry it out and sell it yourself.", "basic"], "AP_fnc_handleMessage", _tsCaller, false, false] spawn AP_fnc_MP;
        };
        if (_giveBag isEqualTo 1) then {
            [[true, "jewelBag", 1], "AP_fnc_handleInv", _tsCaller, false, false] spawn AP_fnc_MP;
            [["You have taken the heavy and expensive jewelry bag from this coveted safe!", "basic"], "AP_fnc_handleMessage", _tsCaller, false, false] spawn AP_fnc_MP;
        };
        diag_log format ["[LooneyBin][jewelry] safe looted by %1: granted %2 Hope Diamond + %3 jewelBag (wanted %4 / %5; safe held hope %6 / bag %7). Flags cleared server-side before either grant.",
            name _tsCaller, _giveHope, _giveBag, _wantHope, _wantBag, _hopeHere, _bagHere];};
    // =================================================================================================
    // owner 2026-07-29 (maldenjewelry2.md #3, #5, #6): THE CRANE LOAD -- the new last stage, and now the
    // ONLY thing that mints the getaway Qilin. Everything the Qilin block used to do in case "weldSafe"
    // moved here verbatim, including the previous-Qilin-still-on-the-pad cleanup: leaving that behind
    // would have reinstated the orphan-stacking bug it was written to fix, an unlocked armed LSV plus a
    // free load of bags for any passer-by.
    // THE CLIENT REPORTS WHAT IT IS CARRYING. That is a trust boundary and it is the whole reason this
    // case exists on the server at all -- the old "Load Container" entry (fn_setupActions.sqf "Load
    // Container" -> fn_jewelryEmporium case "loadOutsideContainer") did the inventory removal, the
    // counter and its publicVariable entirely on the caller's machine, with NO server case behind it. A
    // stage that spawns an armed O_LSV_02_armed_F cannot live there.
    // =================================================================================================
    case "loadJewelry": {
        _data params [["_bags", 0, [0]], ["_hope", 0, [0]]];
        // Resolve the AUTHENTICATED caller FIRST and log every -SEC- row in this case against it, never
        // against anything in the payload. remoteExecutedOwner is the engine's own answer to "which
        // machine sent this" and cannot be forged; a client-supplied name would let a modified client
        // manufacture ban-table evidence against an innocent player, and this server has already
        // auto-banned legitimate players off one false positive. That is also why this case takes NO
        // player object at all -- there is nothing in the payload that could name a third party.
        private _srcLJ = remoteExecutedOwner;   // 0 == server-internal = trusted
        private _ljCaller = if (_srcLJ isEqualTo 0) then { objNull } else {
            (allPlayers select { owner _x isEqualTo _srcLJ }) param [0, objNull] };
        // SANITISE THE CLAIM BEFORE ANYTHING ELSE, because every refusal below has to hand it back and the
        // refund must be in the same units the load is paid in. floor + max 0 first: a negative or
        // fractional claim would otherwise write a negative count and a negative weight into the Qilin's
        // AP_vinv and corrupt the trunk UI, and it would make a refund pay out items that never existed.
        private _bagsClaim = floor (_bags max 0);
        private _hopeClaim = floor (_hope max 0);
        // THE REFUND. The client has ALREADY removed what it is claiming (see ORDER OF OPERATIONS in the
        // header), so from here on this case is holding the player's property and every exit has to settle
        // it. Server -> client AP_fnc_handleInv through AP_fnc_MP, the route APS_fnc_greenhouseSRV
        // case "plant" uses for precisely this situation and that six other server functions use to grant
        // virtual items; it needs no CfgRE.hpp entry because CfgRemoteExec constrains clients only.
        // Guarded on isNull: a caller who disconnected between sending and processing cannot be paid, and
        // their inventory was saved on disconnect with the items already gone. That is a LOSS, it is the
        // one direction this design accepts, and it is bounded by the player having chosen to spend them.
        // Zero-guarded per item so a [item, 0] add is never sent.
        private _fnc_ljRefund = {
            params [["_who", objNull, [objNull]], ["_rBags", 0, [0]], ["_rHope", 0, [0]]];
            if (isNull _who) exitWith {};
            if (_rBags > 0) then { [[true, "jewelBag", _rBags], "AP_fnc_handleInv", _who, false, false] spawn AP_fnc_MP; };
            if (_rHope > 0) then { [[true, "jewelHope", _rHope], "AP_fnc_handleInv", _who, false, false] spawn AP_fnc_MP; };
        };
        // EVERY REFUSAL IN THIS CASE REFUNDS *AND* SPEAKS, and they are the same helper so that a refusal
        // added later cannot do one without the other -- that is the single most important property of this
        // block. It refunds the WHOLE sanitised claim, because it is only ever used for a total refusal;
        // the partial refund the clamp needs is an explicit second call further down.
        // It reads _ljCaller, _bagsClaim and _hopeClaim out of the enclosing scope rather than taking them
        // as parameters, which SQF's dynamic scoping makes safe for a `call` -- the same shape as
        // APS_fnc_greenhouseSRV's _fnRefund. The point of not parameterising them is that a future refusal
        // cannot pass the WRONG amount or the wrong subject: there is only one claim and one caller here.
        private _fnc_ljRefuse = {
            params [["_msg", "", [""]], ["_logLine", "", [""]]];
            diag_log format ["[LooneyBin][jewelry] loadJewelry refused: %1 (caller %2) -- refunding %3 jewelBag + %4 jewelHope",
                _logLine, name _ljCaller, _bagsClaim, _hopeClaim];
            [_ljCaller, _bagsClaim, _hopeClaim] call _fnc_ljRefund;
            if !(isNull _ljCaller) then {
                [[2, _msg], "AP_fnc_broadcast", _ljCaller, false, false] spawn AP_fnc_MP;
            };
        };
        // REPEAT GUARD. Flat, top-level, and BEFORE anything is mutated or spawned -- this is the exact
        // shape case "weldSafe" had to be given after it shipped without one and a repeat remoteExec
        // minted a SECOND loaded getaway Qilin. The owner closed this question on 2026-07-29: one loader,
        // one load, once per robbery.
        // No -SEC- row: a double-click, a duplicated send or the loser of a two-loader race is not
        // evidence of anything, and the whole point of the guard is that it costs nothing when it fires.
        if ((missionNamespace getVariable ["AP_jewelLoaded", false]) isEqualTo true) exitWith {
            ["The getaway has already been loaded -- one load per job. Your haul has been handed back.",
                "this robbery's load has already run"] call _fnc_ljRefuse;};
        // The run has to be LIVE. An honest client can trip this by finishing the two-minute bar in the
        // same moment the 20-minute window closes and resets slot 1, which is a race and not wrongdoing.
        // THERE IS NO WELD REQUIREMENT. An earlier cut of this case refused unless slot 3 (safe welded)
        // was true. The brief never asked for one -- the owner's rule is "whatever the loader is carrying"
        // (maldenjewelry2.md #6) -- and it fired through a bare diag_log AFTER the client had already
        // emptied the player's pockets, so a crew that hacked eight cases and went to the crane without
        // cutting the safe lost the whole haul and were told nothing. What replaces it -- corrected
        // 2026-07-29 -- is the PRODUCTION CAP further down, not the carrying-something check. That check
        // only ever asked whether the CLIENT SAID it held anything, and a modified client says whatever it
        // likes; the cap is measured from what this file recorded the crew actually doing, so a run that
        // smashed nothing has a cap of 0 and mints no getaway however much it claims to be carrying.
        if !(SRV_jewelryEmporiumSRV param [1, false]) exitWith {
            ["There is no Jewelry Emporium job running to load for -- the window closed. Your haul has been handed back.",
                "no robbery is active; the 20-minute window had almost certainly closed under the bar"] call _fnc_ljRefuse;};
        // PROXIMITY TO A COORDINATE, NOT TO AN OBJECT. The crane is a Land_RepairDepot_01_tan_F, and on
        // this map it is a core/config/fn_mapData.sqf row with _xIsServer = false: a per-client
        // createSimpleObject that the SERVER CAN NEVER SEE with nearestObjects and that a client only
        // creates while fn_dynamicMapSystem has that zone loaded. Copying the drill gate's boot resolver
        // here would publish objNull and make every layer of this stage refuse for ever, silently. The
        // Fed already solves this the right way -- fn_openVault.sqf reads AP_FED_TERMPOS and measures
        // against the coordinate -- and it also cannot break when the designer nudges the prop.
        // Read GUARDED with the surveyed position as the fallback so this stage still works if
        // APS_fnc_maldenJewelSRV has not yet been given the publish. The number is the crane's own ATL
        // position, 0.04 m from the owner's [7515.6, 10596.1, 3.84].
        // 30 m and 2D. 30 matches the slack the other three cases in this file already allow between the
        // client's offer radius and the server's refusal, which exists so that lag or a step sideways
        // during a two-minute bar cannot void a completed stage; the client is expected to offer at 10 m
        // (the drill gate's 6 -> 10 correction) and to refuse at the same 10 m it offers at. 2D because
        // the crane stands on the raised deck 3.65 m above the quay the Qilin pad sits on, so "at the
        // crane" is a horizontal question -- the same reading this file already gives the pad below.
        private _cranePos = missionNamespace getVariable ["AP_JEWEL_CRANEPOS", [7515.62, 10596.07, 3.838]];
        // NOT the `_data = []` sentinel the other three cases in this file use, and the difference is
        // deliberate. Those cases carry an object in _data, so an empty _data can only ever mean "the
        // guard above fired". THIS case carries two numbers, and ["loadJewelry", []] is a syntactically
        // fine send that params defaults to a claim of zero -- indistinguishable from the sentinel, so it
        // would be dropped by the wrong guard and logged as the wrong thing. A dedicated flag cannot
        // collide with a payload.
        // SIDE AS WELL AS RANGE -- owner 2026-07-29. case "perimeterGate" has always tested
        // `(side _pgCaller) isEqualTo civilian` and this case never did, so the only thing stopping a COP
        // from loading the emporium's haul into a getaway Qilin (and being handed a key to it by the 400 m
        // sweep below) was the client action's own `playerSide isEqualTo civilian`, which is a client-side
        // check on a server-side payout -- exactly the shape the 2026-07-24 audit note on case "weldSafe"
        // says is not a guard. Folded into the SAME -SEC- row as the range check rather than given its own:
        // both are "the caller is not someone who may load here", an honest client cannot reach either (it
        // tests side and 10 m before it sends), and one row per refusal keeps the table readable.
        private _ljRefused = false;
        if (_srcLJ isNotEqualTo 0) then {
            if (isNull _ljCaller || {!((side _ljCaller) isEqualTo civilian)} || {(_ljCaller distance2D _cranePos) > 30}) exitWith {
                ["-SEC-", _ljCaller, format ["BLOCKED jewelry loadJewelry (caller not a civilian at the crane -- side %1, range %2)",
                    if (isNull _ljCaller) then {"none"} else {str (side _ljCaller)},
                    if (isNull _ljCaller) then {-1} else {round (_ljCaller distance2D _cranePos)}]] call APS_fnc_logIt;
                ["You are not at the emporium's loading crane. Your haul has been handed back.",
                    "caller not a civilian at the crane"] call _fnc_ljRefuse;
                _ljRefused = true;   // signal for the flat guard below
            };};
        // An exitWith inside a then {} leaves only that block, which this codebase has shipped as a bug
        // three times. The flat check here is what actually leaves the case.
        if (_ljRefused) exitWith {};

        // CARRYING SOMETHING. The owner's rule is "whatever the loader is carrying", and nothing is not
        // something. It is a claim-based check because the server cannot read a virtual inventory -- the
        // client tests the same two counters in its offer condition and again before it sends, so an honest
        // player never sees it. Nothing to refund on this path by definition.
        if ((_bagsClaim + _hopeClaim) <= 0) exitWith {
            ["You are not carrying anything worth loading -- hack a display case or open the safe first.",
                "the claim was nothing at all"] call _fnc_ljRefuse;};
        // The Qilin pad, read GUARDED. The old block read AP_JEWEL_QILINPOS bare, which RAISES if
        // APS_fnc_maldenJewelSRV never ran. HOISTED ABOVE THE CAP as of 2026-07-29: it is a cheap read that
        // can refuse, so it belongs with the other cheap refusals and above the done-flag arm, not between
        // the arm and the spawn.
        private _qp = missionNamespace getVariable ["AP_JEWEL_QILINPOS", []];
        if (_qp isEqualTo []) exitWith {
            ["-SEC-", objNull, "jewelry loadJewelry: AP_JEWEL_QILINPOS never published (server fault, not the caller)"] call APS_fnc_logIt;
            ["The crane's loading pad is not configured -- your haul has been handed back.",
                "AP_JEWEL_QILINPOS never published (server fault)"] call _fnc_ljRefuse;};

        // ------------------------------------------------------------------------------------------
        // THE CAP -- SIZED BY THE RUN, NOT BY THE MAP. Rewritten 2026-07-29 because the old one was a
        // CONSTANT dressed up as a measurement.
        // It read `(count of Coffin_02_F inside AP_JEWEL_POLY) + 5`, and a display case is NEVER DELETED
        // by this heist -- case "createCase" only sets AP_jewelCaseLooted on it, and the window-close reset
        // clears that flag again. So that count is 8 the moment the server boots and 8 after a run in which
        // nobody touched a single pane: the cap was a flat 13 whatever happened. With the weld requirement
        // gone (correctly -- the owner's rule is "whatever the loader is carrying") the only server-side
        // precondition left on this whole stage is "a robbery is active", so a modified client could breach
        // ONE perimeter gate, walk to the crane having smashed NOTHING, claim 13 bags and a Hope Diamond,
        // and be paid a loaded armed O_LSV_02_armed_F worth 13 x $17,500 + $108,000 for it. The claim was
        // bounded by the shop's furniture instead of by the crew's work.
        // WHAT THE CAP IS NOW: the production THIS FILE ITSELF RECORDED, read back off the same world state
        // the rest of the case already trusts.
        //     one jewelBag per display case FLAGGED AP_jewelCaseLooted   (case "createCase" sets it,
        //                                                                 authoritatively, one trophy each)
        //   + 5 if and only if slot 3 says the safe was opened            (the 4 trophies case "weldSafe"
        //                                                                 spawns + the safe's own bag)
        //   and one jewelHope, again if and only if slot 3.
        // Every term is something the SERVER wrote in response to work the crew actually did, which is the
        // whole difference: smash nothing and the cap is 0, so the claim is refunded in full and no Qilin is
        // ever minted. Skip the safe and the diamond cannot be claimed at all, where the old cap allowed one
        // unconditionally.
        // The case SET is resolved exactly as case "createCase" resolves it -- same 120 m nearestObjects,
        // same typeOf filter against subclasses, same AP_JEWEL_POLY narrowing -- so the two cannot
        // disagree about which cases count.
        // THE OLD 13-WIDE FALLBACK IS DELIBERATELY GONE. It fired when the case lookup found nothing and
        // widened the cap to the authored 13 so as not to short an honest crew. Under a production cap that
        // is precisely the map-sized constant this rewrite exists to delete, and it would hand the full cap
        // to a forged claim on any server where the Coffin_02_F rows are not server-side. An empty case set
        // now yields a cap of 0 bags plus the safe's contribution, and says so loudly: if it fires, case
        // "createCase" cannot be counting cases either, so the safe never unlocks and the run is already
        // broken. Failing closed on a broken lookup costs an honest crew a refund; failing open costs the
        // economy a Qilin.
        // ------------------------------------------------------------------------------------------
        private _centre = missionNamespace getVariable ["AP_JEWEL_CENTRE", []];
        private _poly   = missionNamespace getVariable ["AP_JEWEL_POLY", []];
        private _cases  = [];
        if (_centre isNotEqualTo []) then {
            _cases = (nearestObjects [_centre, ["Coffin_02_F"], 120]) select {(typeOf _x) isEqualTo "Coffin_02_F"};
            if (_poly isNotEqualTo []) then { _cases = _cases select {(getPosATL _x) inPolygon _poly}; };
        };
        private _looted   = { _x getVariable ["AP_jewelCaseLooted", false] } count _cases;
        private _safeOpen = SRV_jewelryEmporiumSRV param [3, false];
        private _capBags  = _looted + (if (_safeOpen) then {5} else {0});
        private _capHope  = if (_safeOpen) then {1} else {0};
        if (_cases isEqualTo []) then {
            diag_log "[LooneyBin][jewelry] WARN loadJewelry found NO display case to size the claim cap with, so the case half of the cap is 0 and only the safe's contribution counts. Either AP_JEWEL_CENTRE never published or the Coffin_02_F rows are not server-side -- and if so, case ""createCase"" cannot be counting them either, which means the safe never unlocks and this run cannot have produced anything through the cases. The old 13-wide fallback was removed on purpose: it handed a forged claim the full cap on exactly this fault.";
        };
        // The -SEC- row for an over-claim. CLAMPED, not BLOCKED, and the wording matters: the load still
        // runs when there is anything to pay, so a row saying BLOCKED would describe something that did not
        // happen to whoever reads this table.
        // IT IS NOT PROOF OF A MODIFIED CLIENT, and the row says so, because this table feeds CLANKR's
        // auto-ban set and this server has already banned legitimate players off a false positive. An
        // HONEST way to trip it exists: jewelBags survive in a player's inventory between runs, so a player
        // who kept 6 bags from a previous job and walks to the crane during a fresh one offers 6 more than
        // this run produced. They are refunded the difference and keep them; nothing is lost and nothing is
        // minted. Read this row as "the claim exceeded the run's production", not as an accusation.
        if (_bagsClaim > _capBags || {_hopeClaim > _capHope}) then {
            ["-SEC-", _ljCaller, format ["CLAMPED jewelry loadJewelry over-claim -- claimed %1 jewelBag + %2 jewelHope; this run produced %3 + %4 (%5 of %6 display cases looted, safe opened = %7); paying the production cap and refunding the difference. NOT proof of a modified client: bags kept from an earlier run read as an over-claim here.",
                _bagsClaim, _hopeClaim, _capBags, _capHope, _looted, count _cases, _safeOpen]] call APS_fnc_logIt;
        };
        // NOTHING PRODUCED, NOTHING PAID. This is the guard that replaces the deleted weld requirement and
        // it is the one that makes the stage un-farmable: a crew that breaches a gate and walks to the crane
        // has produced nothing, so there is nothing to load and no getaway is minted. Refunds in full.
        // It MUST sit above the arm, and not merely for tidiness: if it refused after the flag were set, any
        // passer-by carrying leftover bags from an earlier run could walk to the crane during somebody
        // else's robbery, be refused, and have BURNED THE CREW'S ONE LOAD for the whole job. That griefing
        // vector is what fixes the arm's position, and it is why the cap is computed before the arm rather
        // than after it.
        if ((_capBags + _capHope) isEqualTo 0) exitWith {
            ["This job has not produced anything to load yet -- hack the display cases or open the safe first. Your haul has been handed back.",
                format ["the run produced nothing (%1 of %2 cases looted, safe opened = %3) so the cap was 0", _looted, count _cases, _safeOpen]] call _fnc_ljRefuse;};

        // ARM THE DONE-FLAG. Hoisted as early as the guards allow (2026-07-29): every refusal in this case
        // is above this line, so nothing below can turn the load down.
        // WHY IT HAS TO BE ARMED BEFORE THE SPAWN AT ALL: AP_fnc_MP sends this with remoteExec, NOT
        // remoteExecCall, so this case runs in the SCHEDULED environment and the engine may suspend it
        // between any two statements when it exceeds its time slice. Two sends landing in the same frame
        // could therefore both clear the repeat guard at the top and both reach createVehicle -- two loaded
        // armed Qilins -- unless the flag is set before anything is spawned.
        // WHAT CAN STILL REFUSE AFTER THIS LINE: nothing. Every exitWith in the case is above it. The only
        // thing below that changes the outcome is the CLAMP, and a clamp is not a refusal -- it pays the
        // production cap and refunds the difference, so the load always completes from here.
        // WHAT IS STILL NOT CLOSED, stated rather than left to be rediscovered: the window between the
        // repeat guard and this line is narrowed to the cap computation (a nearestObjects, a count and some
        // arithmetic -- no spawn, no sleep, no remoteExec, nothing that yields voluntarily), but SQF's
        // scheduler can still preempt it, so it is narrowed and not eliminated. It cannot be eliminated
        // while the cap has to be measured before the arm, and the griefing vector described above makes
        // that ordering mandatory. Two players finishing a two-minute bar inside the same frame is the only
        // way to reach it; the loser is refunded either way, so the cost of losing that race is one
        // duplicate Qilin, not a duplicated haul.
        AP_jewelLoaded = true;
        publicVariable "AP_jewelLoaded";

        // THE CLAMP, and the partial refund that goes with it. Applied AFTER the arm because it cannot
        // refuse -- it only decides how much of a load that is definitely happening gets paid.
        private _bagsTake   = _bagsClaim min _capBags;
        private _hopeTake   = _hopeClaim min _capHope;
        private _refundBags = _bagsClaim - _bagsTake;
        private _refundHope = _hopeClaim - _hopeTake;
        // THE CLAMP SPEAKS TOO. A silent partial refund is the same class of fault as a silent refusal: the
        // player watches items reappear in their inventory with no reason given and reads it as a bug. The
        // honest way an over-claim happens is bags kept from an earlier run, so the message names that.
        if ((_refundBags + _refundHope) > 0) then {
            [_ljCaller, _refundBags, _refundHope] call _fnc_ljRefund;
            if !(isNull _ljCaller) then {
                [[2, format ["The crane only took what this job produced -- %1 bag(s)%2. You have been handed back %3 bag(s)%4 (jewelry from an earlier job does not load into this one's getaway).",
                    _bagsTake, if (_hopeTake > 0) then {" and the Hope Diamond"} else {""},
                    _refundBags, if (_refundHope > 0) then {" and the Hope Diamond"} else {""}]],
                    "AP_fnc_broadcast", _ljCaller, false, false] spawn AP_fnc_MP;
            };
            diag_log format ["[LooneyBin][jewelry] loadJewelry clamped a claim of %1 bag(s) + %2 diamond(s) to the run's production of %3 + %4; refunded %5 bag(s) + %6 diamond(s) to %7",
                _bagsClaim, _hopeClaim, _capBags, _capHope, _refundBags, _refundHope, name _ljCaller];
        };

        // owner 2026-07-28, moved here 2026-07-29: the loaded getaway. Same pattern as the Fed's boat
        // (fn_maldenFedSRV) and the Loony Bin getaway Tempest (fn_loonyBinSRV).
        // NOTE the despawn mechanism: AP_eventVeh does NOT control persistence -- it only exempts the
        // vehicle from fn_cleanup's sweep. What keeps this from surviving a restart is having no DB
        // identity: fn_saveVehicles writes only vehicles carrying dbInfo/AP_dbInfo, so one with
        // neither is never written to vehicle_mem and does not come back. Do not "fix" that by
        // registering it.
        // owner 2026-07-28: clear a PREVIOUS getaway still sitting unclaimed on the pad before spawning.
        // createVehicle below uses "NONE" -- exact coordinate, no collision avoidance -- and this global is
        // simply overwritten, so run 1's Qilin was orphaned where it stood and AP_eventVeh exempts it from
        // fn_cleanup's sweep. Across a restart cycle that stacks armed LSVs on one pad: run 2 spawns INSIDE
        // run 1 and PhysX ejects one or both. Each orphan is lock 0 -- UNLOCKED -- so it is a free armed
        // technical plus a full load of jewelBag for any passer-by.
        // The radius is what keeps the intended case intact: a crew that drove off with their reward keeps
        // it (the window-close reset deliberately does not delete it, see the note there), and only one
        // still parked on the spawn pad is taken. Reaching a second load needs the 20-minute window to
        // close, the 30-minute cooldown to expire and a whole fresh run, so anything still on the pad ~50
        // minutes later is abandoned by any reasonable definition -- and the previous behaviour was to
        // spawn inside it regardless.
        // distance2D, not distance: _qp is an ATL triplet (z 0.19) while an object's distance is measured
        // from its own centre in world coordinates, and an 8 m sphere seeded from a ground-level z is
        // exactly the kind of mismatch that makes the guard silently fail to fire. "On the pad" is a
        // horizontal question; the codebase already reads this variable that way (fn_maldenJewelSRV:92).
        if (!isNil "AP_jewelQilin" && {!isNull AP_jewelQilin} && {(AP_jewelQilin distance2D _qp) < 8}) then {
            diag_log format ["[LooneyBin][jewelry] deleting the previous getaway Qilin still on the pad at %1", getPosATL AP_jewelQilin];
            deleteVehicle AP_jewelQilin;
        };
        AP_jewelQilin = createVehicle ["O_LSV_02_armed_F", _qp, [], 0, "NONE"];
        // THE LAST PLACE THE ACCEPTED HALF OF THE HAUL COULD VANISH. The client removed the items before it
        // sent, so between the clamp above and this line the server is holding them and the Qilin is the
        // only thing that pays them back. A createVehicle that returns objNull -- a missing or renamed class
        // after a mod change is the realistic way -- would otherwise leave the accepted bags nowhere at all:
        // gone from the player, never in a vehicle. Refund the accepted part too and stop.
        // The done-flag stays ARMED on this path, deliberately. Un-arming it to allow a retry would only
        // loop: if the class cannot be created once it cannot be created a second time either, and leaving
        // the flag set keeps the one-load-per-job invariant true no matter what happens here. The crew lose
        // the run's load to a server fault and lose nothing else -- the whole claim is back in their pockets.
        if (isNull AP_jewelQilin) exitWith {
            ["-SEC-", objNull, format ["jewelry loadJewelry: createVehicle O_LSV_02_armed_F returned objNull at %1, so the getaway could not be minted (server fault, not the caller). Refunded the full accepted load of %2 jewelBag + %3 jewelHope; AP_jewelLoaded stays armed, so this run gets no second attempt.", _qp, _bagsTake, _hopeTake]] call APS_fnc_logIt;
            [_ljCaller, _bagsTake, _hopeTake] call _fnc_ljRefund;
            if !(isNull _ljCaller) then {
                [[2, "The crane could not put a getaway on the quay -- your haul has been handed back. Tell an admin."], "AP_fnc_broadcast", _ljCaller, false, false] spawn AP_fnc_MP;
            };};
        AP_jewelQilin setPosATL _qp;
        AP_jewelQilin setDir 180;                       // facing south, per the owner
        AP_jewelQilin lock 0;
        AP_jewelQilin setFuel 1;
        AP_jewelQilin setVariable ["AP_eventVeh", true, true];
        AP_jewelQilin setVariable ["owner", "jewelry_qilin", true];
        AP_jewelQilin setVariable ["AP_vcap", 999999, true];              // unlimited T inventory
        // owner 2026-07-29: the load itself -- what the loader carried (clamped) plus 5 FLAT bonus bags.
        // Flat by the owner's decision: it does not scale with what was loaded.
        // AP_vinv is [[[item, count], ...], totalWeight] and the trunk UI reads that weight field rather
        // than recomputing it, so it has to be right or the vehicle disagrees with itself. The two item
        // weights are MIRRORED from core/config/fn_virtItemCfg.sqf (jewelBag 8 on line 173, jewelHope 10
        // on line 165) -- that file is client-side and the server cannot read it, so if either weight is
        // ever changed there it must be changed here too.
        // An empty entry is never pushed: a [item, 0] row would show as "0x Bag Of Jewelry" in the trunk.
        private _totalBags = _bagsTake + 5;
        private _inv = [];
        if (_totalBags > 0) then { _inv pushBack ["jewelBag", _totalBags]; };
        if (_hopeTake > 0) then { _inv pushBack ["jewelHope", _hopeTake]; };
        AP_jewelQilin setVariable ["AP_vinv", [_inv, (_totalBags * 8) + (_hopeTake * 10)], true];

        private _keyAnchor = if (_centre isEqualTo []) then { _cranePos } else { _centre };
        private _keys = [];
        {
            if ((side _x isEqualTo civilian) && {alive _x} && {(_x distance _keyAnchor) < 400}) then {
                _keys pushBack [getPlayerUID _x, name _x];
                [[AP_jewelQilin], "AP_fnc_addVehicle2Chain", _x, false, false] spawn AP_fnc_MP;
            };
        } forEach allPlayers;
        AP_jewelQilin setVariable ["AP_vehOwners", _keys, true];
        publicVariable "AP_jewelQilin";

        // THERE IS NO ACCEPT PUBLISH HERE ANY MORE, and its absence is the fix. AP_jewelLoadAccept used to
        // be written on this line -- [loaderUID, bagsAccepted, hopeAccepted, serverTime] -- as the loader's
        // instruction to strip its own inventory now that the Qilin existed. That ordering is what MINTED
        // the haul: the vehicle was already loaded and keyed by the time the client was told to remove
        // anything, so a client that disconnected, died, or hit its own 15 s timeout in the gap kept the
        // haul AND left a copy of it in the Qilin. The timeout case duplicated every single time, because
        // the client had given up waiting while the server had already paid.
        // The client now removes BEFORE it sends and this case refunds what it does not accept, so there is
        // nothing left to tell the client and nothing for it to wait on. Do not add an accept channel back:
        // by construction it is a payment that precedes a removal.

        // owner 2026-07-29: throw the doors open at the same moment (maldenjewelry2.md #3.4). Idempotent
        // and self-guarding on a null gate, so it is safe to call whatever state the gates are in -- the
        // same call case "robberyStarted" makes when the breach succeeds.
        ["open"] call APS_fnc_maldenJewelSRV;

        [[0, "The haul has been loaded at the emporium's crane -- a getaway Qilin is on the quay."], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        [["The emporium crew has loaded a getaway vehicle on the quay -- they are running NOW.", "copalert"], "AP_fnc_handleMessage", west, false, false] spawn AP_fnc_MP;
        diag_log format ["[LooneyBin][jewelry] crane load by %1: claimed %2 bag(s) + %3 Hope Diamond(s), accepted %4 + %5 (cap %6 + %7), loaded %8 bag(s) with the 5 flat bonus; Qilin at %9 dir 180, keys to %10 player(s)",
            name _ljCaller, _bagsClaim, _hopeClaim, _bagsTake, _hopeTake, _capBags, _capHope, _totalBags, getPosATL AP_jewelQilin, count _keys];};
    default { diag_log format ["[LooneyBin][jewelry] unhandled case: %1", _this]; };};
