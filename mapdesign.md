# Map Design / Geometry Backlog

Issues that need a MAP edit (Eden / mission.sqm objects, collision/blocking geometry, object placement) rather
than a script change. Worked via the map-data / Eden pipeline (see tools/mapdata_to_eden.py, edenExport.sqf).

---

## #293 — players glitch INTO the furnaces to hide

**From BUGS.md #293** (player006, 2026-06-16). Players clip into the smelting **furnace** model and sit
inside it to hide (as long as they don't go too far in). Video: https://medal.tv/games/arma-3/clips/mVFPPvHVfd9ANI2EK?invite=cr-MSxrY2gsNDI5MjIwNTM1

**Why it's a map fix:** the furnace prop has a hollow/penetrable section in its collision LOD — a script can't
patch model geometry. Options:
- Drop an invisible **blocking object** (e.g. `Land_InvisibleWall` / a thin `Land_HBarrier`/clutter cutter with
  `enableSimulation false`) inside/over the furnace opening so a body can't enter.
- Or swap the furnace prop for one with solid collision, or rotate/reposition so the exploitable face is against
  a wall.
- Confirm WHICH furnace(s) — the gold/ore smelter at the processing area(s). Get the exact position from the
  reporter's clip, then place the blocker via the Eden pipeline.

**Status:** deferred here from the bug queue; do with the next batch of map edits.

---

## #298 / #299 — jewelry emporium "door opened without drilling"

**From BUGS.md #298 + #299** (same reporter/time, 2026-06-16). The emporium back door can be opened without
placing the drill.

**Investigation (2026-06-16):** the LOOT is fully script-gated — `SRV_jewelryEmporiumSRV` slot 2 (safeDrilled)
inits `false` and only `robberyStarted` (after the 10s drill) sets it `true`; case-break, safe-weld, and
safe-loot all gate on it, and there are NO pre-placed trophies (loot only spawns on a legit case smash). So
opening the building's native door without drilling yields **no loot** — it's a building-geometry/access issue,
not a loot exploit. Severity LOW.

**Fix path (map):** the emporium building's native Arma doors aren't locked. Either block/lock the back door
(needs the building object near `[20720,16620]` + its door selection name -> a `bis_disabled_Door_N`+animate
lock like the bank vault uses, set/cleared by the robbery state), or drop a blocking object. Confirm from the
reporter's setup which door + whether there's a loot path I missed before investing the door-lock work.

**Charge (#301) — FIXED in script** (`fn_jewelryEmporiumSRV` robberyStarted now applies charge 76 to the
driller + civs within 90m); that part was a code bug, not map.

---

## Jewelry Emporium heist — INCOMPLETE feature (cluster: #303 / #304 / #306)

Investigated 2026-06-16. The emporium heist (`fn_jewelryEmporium.sqf` client + `fn_jewelryEmporiumSRV.sqf`
server, both built from stub 2026-06-09) is functional for the **display cases** but the **safe** and **reward**
halves are unfinished. Needs a focused design+code pass, not a one-line patch. Concrete findings:

- **#306 "safe doesn't open"** — the server `weldSafe` case ONLY sets state slot 3 (`safeWelded`) true; it
  NEVER swaps the closed safe (`AP_jewerlySafe`) for the open `Fridge_01_open_F` that the client's "Take Safe
  Loot" action (`takeSafeContents`) targets, and never spawns the safe's loot bag. Compare `createCase`, which
  correctly spawns a `Land_Trophy_01_gold_F` on each smashed case. **Fix:** in `weldSafe` SRV, hide/replace the
  closed safe with `Fridge_01_open_F` at the same pos/dir (tag it so cleanup skips it), so the loot action has
  an object to hit. Mirror the case-loot pattern.
- **#306 "Qilin didn't spawn with goods"** — there is NO reward-vehicle spawn anywhere in the jewelry code. The
  heist's only payout path is `loadOutsideContainer` (carry `jewelBag`s to `AP_jewerlyContainer`). If a
  loaded-Qilin reward is intended, it must be DESIGNED + built (spawn the vehicle + populate its cargo on
  completion). Confirm with owner whether the Qilin reward is a planned feature or the reporter's expectation.
- **#304 "break cases / cut safe before drilling done"** — `robberyStarted` sets slot 2 (`safeDrilled`) true at
  the SAME instant it sets the event active, so case-break and safe-weld unlock together the moment the 10s
  back-door drill finishes — there's no enforced drill→cases→safe sequence. If a staged sequence is wanted,
  split the unlocks (e.g. safe-weld gates on "all/N cases looted") and add a real safe-drill step before
  `safeDrilled`. This is a DESIGN decision (what's the intended order), so deferred for owner direction.
- **#303 "drive through the back gate"** (player039, gyazo e96bf23d) — emporium back gate has no blocking
  collision; a vehicle drives through it. Same class as #298/#299 above: map-geometry/door fix (block or lock
  the gate object near `[20720,16620]`), do with the next map-edit batch.

**Status:** deferred — needs owner's design intent for the safe-open swap + whether a Qilin reward exists, then
a combined code+map pass. The case-smash loot path works today.
