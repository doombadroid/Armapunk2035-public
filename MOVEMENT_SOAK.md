# MOVEMENT_SOAK.md — owner playtest script for parkour, wall running and body drag

Built 2026-09-16 from the approved movement plan. Every line was checked by reading
code, by the repo's static checkers and by several rounds of adversarial review.
**None of it has run in the engine yet.** This file is the script that closes that gap.

Work top to bottom. Section 1 needs one client. Section 2 needs one client, plus a
second account for the MaxSec install. Section 3 needs two clients, three for the
medic steps. Section 4 lists what the build knowingly leaves alone.

---

## 0. Before you start

### What the player sees

| Feature | How it is used |
|---|---|
| Parkour | **V** (the GetOver key). Facing a 0.5–1.1 m obstacle = vault. A 1.1–2.5 m ledge with a floor on top = mantle. At a 1.2–3.5 m ledge edge = controlled drop. Nothing in front and running above 10 km/h = the old running hop. |
| Wall run | Needs the **Reflex Tuning Implant** chip. Kabuki Electronics (tech vending) sells it to **civilians only**, for 250 New Drachma before market and tax (catalogue 1,500,000 at 6000:1). USE it from the inventory; any side can install it. Then sprint alongside a wall and press **V**. |
| Body drag | Scroll action **Drag Body** within 2.5 m of a dead player's body. If you carry a rifle it is raised first. **S** walks backwards with the body. **W, A, D and sprint hold still**, because that is the engine's own drag animation set. **Release Body** lets go; going prone, standing up to carry or switching weapon also lets go. |
| Dead player | The FLATLINED screen shows `● YOUR BODY IS BEING MOVED BY <NAME>` (name upper-cased) while someone drags the body. The native fallback screen (display 7300) appends ` -- body being moved by <name>` to its "Nearest TT Medic:" line. |

### Debug console on .96

Use **LOCAL EXEC**. SERVER EXEC is switched off on .96 (`deploy/live/reload-live.sh`).
`createUnit` and `createAgent` are disabled on every machine (`CfgDisabledCommands.hpp`),
so there is no spawned AI body: every drag test body is a second client that dies.

Both death screens block Esc, so a dead client cannot open the console. Start
anything the dead player must run **before** that player dies.

### Kill switches (no repack)

All three live in `server/AP_server/server_init.sqf` and are read on every use.
Flip one for everybody from LOCAL EXEC; `publicVariable` from your client reaches
the server and every other client:

```sqf
SRV_parkourEnabled = false; publicVariable "SRV_parkourEnabled";
SRV_wallRunEnabled = false; publicVariable "SRV_wallRunEnabled";
SRV_dragBodyEnabled = false; publicVariable "SRV_dragBodyEnabled";
```

Parkour off gives V back its old running hop exactly. Wall run off leaves vault,
mantle and drop working. Drag off hides the action and releases any active drag
on its next watchdog tick. A restart restores the file values, so edit
`server_init.sqf` too if a switch must stay off.

### Probes and live tuning

Two debug files do all the spike work. They are packed into the mission. Their
headers are the reference for every mode, expected RPT line and live toggle:

- `mission/Armapunk2035.Malden/debug/probe_parkour.sqf`
- `mission/Armapunk2035.Malden/debug/probe_drag.sqf`

Paste only the command line, from `[` to the semicolon. Everything lands in the
client RPT tagged `[AP-PROBE]`. The RPT path is in `CLAUDE.md`.

Every unmeasured engine assumption is a live override you can set from the console
and clear with `nil`:

- Parkour: `AP_parkourCfg_<key>`, read through `AP_fnc_parkourCfg`. All keys and defaults are in `core/config/fn_parkourCfg.sqf`.
- Drag: `AP_dragCfg_<key>`, listed in the `fn_dragBody.sqf` and `fn_dragBodyStop.sqf` headers. The drag probe's `["cfg"]` and `["reset"]` modes dump or clear them.

When a tuned value turns out right, write it into the file default in a commit.
An override set in the console dies with the client session.

---

## 1. Parkour (one client)

Start the sampler first and leave it running for the whole section:

```sqf
["trace", 600] execVM "debug\probe_parkour.sqf";
```

### 1a. Spikes, in this order

| Spike | Command | Pass | If it fails |
|---|---|---|---|
| P1 fence faces | stand facing each fence type near a town, `["fence"] execVM "debug\probe_parkour.sqf";` | a verdict other than `none` for every fence you can see over | `AP_parkourCfg_faceLods`, `AP_parkourCfg_topInset` (the probe prints which LOD works) |
| Attach origin | `["glide"] execVM "debug\probe_parkour.sqf";` in the open | on every `glide hang` line, posATL z ≈ that line's `off` z (the first tick is already about 0.13 m up) | set `AP_parkourCfg_attachZ` to minus (posATL z − off z) |
| P4 anim while attached | same glide run | the step-over's move progress keeps advancing | `AP_parkourCfg_animHold = "static";` |
| P3 smoothness | same glide run, **second client** 10 m away | motion looks continuous, like a fast-rope descent | vault/mantle/drop are short enough to live with it; note it for the wall run |
| P5 push-off landing | `["pushoff", 1.2] execVM "debug\probe_parkour.sqf";` | ddmg 0, no prone, no halofreefall | lower `AP_parkourCfg_pushUp` and repeat; for a lower arc repeat with a lower lift, e.g. `["pushoff", 0.5] execVM "debug\probe_parkour.sqf";`, then set `AP_parkourCfg_wallArc` to the height that passes |
| V key repeat | `["keys", 20] execVM "debug\probe_parkour.sqf";` then tap, hold 3 s, double-tap V | one move per press, a held V does not chain moves | the probe header says which latch key to raise |

### 1b. Obstacle checklist

One RPT line per V press. Try each with a rifle, empty hands and a pistol.

- [ ] Sandbag or kerb about 0.4 m, running → `none` and the old hop.
- [ ] Each fence type → vault or `none`, never a glide through it.
- [ ] Parked car, engine off → mantle onto it. Same car with the engine on → `none`.
- [ ] A 1.5 m and a 2.4 m ledge with a floor on top at least 0.6 m deep (container, loading dock, thick wall) → mantle. A thin 1.5 m wall → `none` (no floor on top; `AP_parkourCfg_mantleNeedsSurface = false;` allows climb-and-drop). A 3 m wall → `none`.
- [ ] **Window with an open or broken pane, sill about 1 m, in a locked house → refused. You must never end up inside.**
- [ ] Doorway lintel or low ceiling above an obstacle → refused.
- [ ] Ledge under a balcony / stair underside that starts just past the lip, 1.7–1.9 m above the ledge → refused (`mantle-overhead`). Your head must never end inside it.
- [ ] 2 m and 3 m ledges → drop. 4 m → "Too far down to drop."
- [ ] Ledge over shallow water, sea floor 1.2–3.5 m below your feet → "You would land in the water." Rays do not hit the sea surface, so over deeper water the same ledge says "Too far down to drop."
- [ ] V twice quickly → one move. V during a move → nothing, and no engine step-over on top of it.
- [ ] Death mid-move: LOCAL EXEC the line below, close the console, mantle onto a 2 m ledge → corpse on the ground (not hanging in the air), helper gone, V works after respawn.

```sqf
[] spawn {waitUntil {uiSleep 0.02; (missionNamespace getVariable ["AP_parkourState", "idle"]) isEqualTo "mantle"}; uiSleep 0.3; player setDamage 1;};
```

- [ ] Restrained, surrendered, escorted, seated, in a vehicle or dragging a body → V does nothing new.
- [ ] Client RPT: no `[LB-SPAWNHOLD] rescue` lines. be.log: only level-1 lines.

---

## 2. Wall run (one client, implant)

- [ ] As a **civilian**, buy the implant at Kabuki, USE it → `-CYBERDECK-` row "installed drop-only hack chip 5". Relog → still installed.
- [ ] On a second account that has never installed it, clock on as **MaxSec**. A civilian buys one and gives it to the officer (Y menu → Give). The officer USEs it → installs; this is the bioware exemption. Give a second chip and USE it → "Reflex Tuning is already installed on your deck.", and the chip stays in the inventory.
- [ ] Without the implant, sprint along a wall and press V → the old hop.
- [ ] With it, sprint along a long wall and press V → a short run with an arc, then a push away from the wall. No damage, no prone.
- [ ] Run into a building corner → the run ends at the corner without pushing you into it.
- [ ] Run toward a lamp post or column a few metres ahead → the run starts and ends at the post. It must not be refused outright.
- [ ] Run along a wall on a slope, up and down → you follow the ground, no sinking, no launch at the end.
- [ ] Run along a low wall of 1.7–2.1 m → the run is not cut short after a few ticks.
- [ ] **Wall-run clip (client mod only).** Build the mod (`radio/build_addon.sh`), launch with it, RPT start line shows `set=` and the run lasts 1.1 s. Check on BOTH wall sides, with rifle / pistol / empty hands: feet on the wall not inside it (`AP_parkourCfg_wallHoldDist = 0.6;` moves you out), rifle stays in the right hand, no T-pose, no snap at the end, a second client WITHOUT the mod sees the vanilla sprint. `AP_parkourCfg_wallClip = false;` = vanilla.
- [ ] Run along a wall on a pier, catwalk or roof edge with a drop (or water) 1–2 m out from the wall → the run ends with a hop in place, no push off the side. RPT `endReason=…+side`. `AP_parkourCfg_pushLandTimes = [];` turns the check off.
- [ ] LOCAL EXEC `SRV_wallRunEnabled = false; publicVariable "SRV_wallRunEnabled";` → V along a wall does the hop; vault still works. Set it back to `true` the same way.

---

## 3. Body drag

Dragger **D**, dead player **P**, medic **M** (Trauma Team on duty).

The drag trace follows **one** drag plus a 3 s settle and then stops. Its number is
how long it waits for that drag to start. Paste it again before each drag:

```sqf
["trace", 300] execVM "debug\probe_drag.sqf";
```

### 3a. Spikes (D and P)

P runs `["watch", 300] execVM "debug\probe_drag.sqf";` **before dying**, then dies in front of D.

| Spike | What to do | Pass |
|---|---|---|
| D1 attach | Drag Body, walk backwards on flat ground and on a slope | body follows, `att=true`, no jitter, bodyATL never negative |
| D2 offset | look at it | body in front, feet toward you; tune with the probe's `offset` mode |
| D3 animations | rifle in hand; then pistol and unarmed with no rifle carried (or `AP_dragCfg_selectPrimary = false;` first, because Drag Body raises a carried rifle) — press S, W, A, D, sprint | S walks back, W/A/D/sprint hold still, the drag does not end; prone, carry or a weapon switch ends it |
| D4 release | Release Body while walking, on a slope, against a wall | body settles within about 1 s, no fling |
| D5 camera | P watches a 30 m drag | P's camera follows and D does not fill the frame |
| Clamp: wall | stand 1 m from a wall, turn to face it | `y=` drops, `hit=` names the wall, body stays on your side; release → body on your side |
| Clamp: stairs | drag down a staircase backwards, release mid-flight | write down where the body lies; height is not corrected by design |
| Clamp: vehicle | get in a car mid-drag | write down where the body ends up |
| D6, D8 | a third client runs `["watch"]` during a drag | D's pose and the body's facing look the same as on D's screen (the probe header has the toggles if not) |

### 3b. Full script (D, P, M)

1. [ ] Kill P. P presses **Allow revive** (or Request Trauma Team). The defib in steps 3–4 and the body marker in step 8 only exist for a revivable body. D drags → P's FLATLINED strip shows "BEING MOVED BY D" within 1 s. `-DRAG-` start row.
2. [ ] D Release Body → body settles, P's line clears within 1 s, stop row `reason=released` with sane metres.
3. [ ] M defibs P at the new spot → P stands up there.
4. [ ] Drag again. M tries the defib mid-drag → "That body is being moved -- the dragger must release it first", and no revive starts. D releases, M starts a revive, D looks at the body → no Drag Body action while the revive runs.
5. [ ] Drag again. P respawns → D's pose resets, no RPT error, stop row `reason=body-gone`.
6. [ ] Drag again. Kill D → body released where D fell, `reason=killed`, D's own death screen normal.
7. [ ] Drag again. D gets in a car → released. A cop restrains D → released.
8. [ ] M opens the **vanilla** map mid-drag with LOCAL EXEC `openMap true;` (plain M opens MALDEN GRID, which has no medic body markers) → the red "P Unconscious" marker moves with the body.
9. [ ] Drag again **facing a wall**, then D Alt-F4 → body stays on D's side of the wall; P's line clears within about 3 s; another player can drag it afterwards (D7).
10. [ ] Admin revive of P mid-drag, with D facing a fence → P stands up on D's side.
11. [ ] Two players press Drag Body on the same body at the same moment → exactly one ends up dragging, and the body is never left stuck to a player who has no Release Body.
12. [ ] `SELECT * FROM log WHERE tag='-DRAG-' ORDER BY ts DESC LIMIT 40;` → a `started dragging` row and a `released ... reason=` row per drag, each with `@SRC` = that dragger's uid. The step 9 Alt-F4 drag has no released row, only P's `owner-sweep cleared a stale drag flag` row with `@SRC` = P's uid, and only while the web death screen is up. A `lateDetach=true` note next to a `-REVIVE-` row for the same body is the revive path, not a race.

---

## 4. Known and accepted

These were found in review and left alone on purpose. Each one is visible in the
probe output if it turns out to matter.

- **Drag limbs can clip walls.** Only the body's attach point is clamped to the dragger's side of geometry, so legs may poke through a wall while the centre stays on the dragger's side. Revives use the centre.
- **Drag on stairs.** The body is held at the dragger's foot height, so on stairs it can sit partly inside the steps. Nothing moves the body after release.
- **A turn the last clamp tick did not see** can leave the body up to one 0.1 s tick of turning into geometry: a very fast turn in the same frame as Release Body, or any stop that skips the final clamp (killed, vehicle, the two-dragger race).
- **Wall run near awnings.** An awning whose underside sits between the 1.6 m and 1.9 m check lines can end a run early as a corner.
- **Wall run beyond the forward clearance.** A post or overhang more than about 2 m ahead is not refused; the run simply ends there.
- **Drop notice.** "Get closer to the edge to drop." can still be followed by a silent refusal when something is fixed to the facade below the edge.
- **Orphaned parkour helper.** A player who disconnects mid-move leaves an invisible helper; the server junk sweep removes it within about 300 s. A helper in use is never swept.
- **forceWalk is not a parkour guard** (plan decision): a player forced to walk can still vault, mantle and drop, but cannot wall run.
- **No drag cooldown and no vehicle loading** (owner decisions); every drag is logged.
