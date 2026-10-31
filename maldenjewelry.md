# Jewelry Emporium — Malden design

Owner brief 2026-07-28. Wire the Jewelry Emporium heist for Malden, and finish the parts of it that
have never worked on either map.

This is not a fresh build. The heist exists and most of it runs: the drill, the alarm, the display
cases, the loot bags, the 20-minute window and both cooldowns. What it has never had is a working
safe, an enforced order, or a reward — and on Malden it additionally points at Altis coordinates and
an object that does not exist here.

Related: `maldenfed.md`, `maldenbank.md`. The prior Q&A that stalled is `jewelry-redesign.md`; this
document supersedes it and answers all four of its open questions.

---

## 1. What is already here

**Working, untouched by this design:** the 10-second back-door drill, the alarm and MaxSec alert, the
`Coffin_02_F` display cases, the gold-trophy → `jewelBag` loot, the once-per-event crypto mining
component, the 20-minute window with scene reset, the 30-minute re-breach cooldown and the 15-minute
cross-heist cooldown, and the server-side security gates added in the 2026-07-24 audit.

**State** — `SRV_jewelryEmporiumSRV = [lastBreach, active, safeDrilled, safeWelded, casesLootable, 0, copsRequired]`

**Already placed on Malden:**

| Thing | Position | Notes |
|---|---|---|
| Emporium building | `[7545.757, 10570.099, 35.734]` | `JewelryBuildingModel.p3d`, `createSimpleObject` from `custom_p3ds/malden_buildings.sqf`, run on **both** server and clients with `local = true` |
| 8 display cases | 3.7–11.5 m from the building | `Coffin_02_F` in `fn_mapData.sqf` (Altis has 14) |
| 3 back-alley gates | 13–18 m out | `Land_BackAlley_01_l_gate_F`, in `mission.sqm` |

The building is a **simple object** — no doors, no animations, no interaction. That is fine: nothing
in this heist interacts with the building itself. The drill goes on a gate, the cases and safe are
separate objects.

## 2. What is broken or missing

**Broken on both maps — the safe has never been lootable.** `fn_jewelryEmporiumSRV`'s `weldSafe`
case sets state slot 3 and nothing else. It never swaps the closed safe for the open model the client
action targets, and never spawns loot. Welding "succeeds" and the safe stays shut. (`jewelry-redesign.md` #306.)

**Broken on both maps — no enforced order.** `robberyStarted` sets `safeDrilled` (slot 2) true the
instant the event goes live, so cases and safe unlock together. (#304.)

**Missing on both maps — no reward vehicle.** A player reported expecting "the Qilin to spawn in with
the goods"; there is no such spawn anywhere in either repo. The closest real thing is a **craft
recipe** — `O_LSV_02_armed_F` from 20 `diamondf` + iron + oil + rubber (`fn_recipeDetail.sqf:91`) —
which is diamond-linked and reads as jewelry-adjacent but is unconnected to the heist.

**Malden-specific:**

- **Three Eden-named objects are missing, not one.** Altis binds them from `mission.sqm` init lines,
  which is why none of them has an assignment anywhere in the tree:

  | Variable | Altis class | Role |
  |---|---|---|
  | `AP_jewerlySafe` | `Fridge_01_closed_F` | the safe; welding it should yield the `Fridge_01_open_F` the client loots |
  | `AP_jewerlyEmporium` | `Land_House_2B02_F` | the building whose back door the drill goes on |
  | `AP_jewerlyContainer` | `Land_RepairDepot_01_green_F` | loot deposit container |

  Malden's `mission.sqm` has none of them, and `Fridge_01_open_F` appears zero times on the map.

- **All three are read inside scroll-menu conditions** (`fn_setupActions.sqf:689`, `:695`, `:701`).
  An undefined variable in an expression does not warn in SQF — it raises. Every one of those
  conditions therefore throws whenever the scroll menu is built near the emporium. This is the same
  fault class that was silently killing `initPlayerLocal` before the Fed work, and it means all three
  must be bound — even to `objNull` — regardless of what the heist ends up doing.
- **`AP_jewelryEmporiumPoly` holds Altis coordinates**, so the `inPolygon` gate that validates a
  smashed case can never pass here.
- **`fn_jewelryEmporiumSRV` hardcodes `[20720, 16620]` twice** — the 90 m wanted-charge sweep and the
  120 m scene-reset search.

## 3. Anchors

```sqf
AP_JEWEL_SAFEPOS  = [7538.99, 10583.70, 0.15];    // owner-clipboarded; the safe
AP_JEWEL_QILINPOS = [7515.07, 10599.30, 0.19];    // owner-clipboarded; getaway, facing south (dir 180)
AP_JEWEL_GATEPOS  = [7535.70, 10578.80];          // nearest back-alley gate; the drill point
```

**Object bindings.** All three Eden variables get bound at boot on **both** the server and clients:

- `AP_jewerlySafe` → a `Fridge_01_closed_F` spawned at `AP_JEWEL_SAFEPOS`
- `AP_jewerlyEmporium` → the resolved back-alley gate at `AP_JEWEL_GATEPOS`, which is what the
  drill targets here. Altis points this at the emporium building; Malden's building is a client-local
  simple object, and the Fed's gate proved that `cursorObject` on a large flat structure returns the
  paving underfoot rather than the object — so the Malden drill gates on **proximity** to this anchor,
  not on cursor identity.
- `AP_jewerlyContainer` → **`objNull`.** No deposit container is placed: the owner's reward is the
  loaded Qilin, so the container stage has no role here. Binding it to `objNull` is what stops its
  scroll condition throwing; the condition then simply never matches and the action never offers.

The drill anchors on the **nearest back-alley gate**, `[7535.7, 10578.8]`, resolved at boot by
proximity and logged with class and distance — the same approach the Fed's anchors use, so the owner
can confirm it is the right door from the boot log rather than by guessing.

The owner's two coordinates carry z values of 0.15 and 0.19, consistent with the ATL frame the
display cases use (z 1.59). Both resolved positions are logged at boot so a frame mismatch shows up
immediately rather than as a safe buried in the floor.

A Malden `AP_jewelryEmporiumPoly` replaces the Altis one — a box around the site enclosing the
building and all 8 cases with a working margin.

## 4. The flow

1. **Drill the back gate.** 10-second bar. Gates unchanged: civilian, ICEBREAKER firmware, on foot,
   no other federal event live, cop requirement (slot 6, floored at 1), the 15-minute cross-heist
   cooldown and the 30-minute own re-breach cooldown.
2. **Alarm.** MaxSec broadcast and cop alert; wanted charge 76 to every civilian within 90 m **of the
   Malden site**; cases become lootable. **`safeDrilled` is no longer set here.**
3. **Smash all 8 display cases.** Each spawns a `Land_Trophy_01_gold_F` that grabs as a `jewelBag`.
   One case also carries the crypto mining component, as now.
4. **All 8 cases → the safe unlocks** (`safeDrilled` true), with a broadcast so MaxSec knows the
   crew is committing to the vault rather than leaving.
5. **Weld the safe.** Butane torch within 3 m, existing torch loop sound. On success the closed safe
   is **swapped for `Fridge_01_open_F` and the loot is spawned inside** — the #306 fix, which repairs
   Altis at the same time because both maps run this code.
6. **Loot the open safe.** The safe is the **big prize**: several `jewelBag`s, not one, so the extra
   stage is worth committing to.
7. **Completion → the getaway.**
8. **20-minute window**, then the scene resets: cases and safe restored, 30-minute cooldown armed.

## 5. The getaway Qilin

An **armed Qilin** (`O_LSV_02_armed_F`) spawns loaded at `[7515.07, 10599.30]` facing **south**
(dir 180) when the safe is looted.

Owner's call: the armed version as-is, accepting that it overlaps the 20-diamond craft recipe — the
heist becomes the fast path to one, the recipe stays the slow path.

It follows the Fed boat and asylum Tempest pattern exactly:

- `AP_vcap = 999999` — unlimited virtual (T) inventory
- preloaded with the haul
- keys to every alive civilian on site, via `AP_fnc_addVehicle2Chain`
- `AP_eventVeh = true`
- **no `dbInfo` and no `AP_dbInfo`**

That last point is what makes it despawn at restart, and it is worth stating plainly because the
obvious guess is wrong: **`AP_eventVeh` does not control persistence** — it only exempts a vehicle
from `fn_cleanup`'s sweep, i.e. it stops the vehicle being despawned *during* the session.
`fn_saveVehicles` iterates the world's vehicles and writes only those carrying DB identity; anything
with neither `dbInfo` nor `AP_dbInfo` is skipped, never lands in `vehicle_mem`, and therefore does
not come back. The boat and the Tempest already behave this way.

## 6. Files

| File | Change |
|---|---|
| `server/AP_server/core/TON/fn_jewelryEmporiumSRV.sqf` | Malden anchors instead of the two hardcoded Altis coords; stop setting `safeDrilled` at start; new case to unlock the safe when all 8 cases are done; finish `weldSafe` (swap to the open model + spawn loot); spawn the Qilin |
| `mission/Armapunk2035.Malden/core/actions/fn_jewelryEmporium.sqf` | drill anchored on the resolved gate; safe actions target the bound `AP_jewerlySafe` |
| `mission/Armapunk2035.Malden/core/configuration.sqf` | Malden `AP_jewelryEmporiumPoly` |
| `mission/Armapunk2035.Malden/core/fn_mapData.sqf` *or* a boot resolver | place `Fridge_01_closed_F` at the safe position |
| `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` | scroll conditions against the Malden anchors |
| `TODO.md` | anything deferred |

`AP_jewerlySafe` must be bound on **both** the server and clients — the server owns the state and
the swap, the client actions read the variable directly. Altis gets it free from the sqm init; Malden
needs an explicit bind at boot.

## 7. Deferred, deliberately

- **Back-gate collision (#303).** On Altis the emporium's back gate has no blocking collision and
  vehicles drive through it. Malden's gates are ordinary `mission.sqm` objects and are expected to
  collide normally — to be confirmed in game rather than pre-emptively scripted around.
- **Cop requirement** stays at whatever `SRV_jewelryEmporiumSRV` slot 6 holds, floored at 1, matching
  the Fed and bank during testing.
- **The 14-vs-8 case count.** Altis has 14 display cases, Malden 8. No attempt to equalise; the
  design gates on "all cases at this site", so both maps work from their own count.

## 8. Test plan

1. Boot: the gate, the safe and the Qilin spawn position all resolve and log with class and distance.
   The safe exists and is a `Fridge_01_closed_F`.
2. Before the drill: cases cannot be smashed, safe cannot be welded.
3. Drill the back gate → alarm, MaxSec alert, charge applied within 90 m, cases become lootable.
4. Smash 7 of 8 → the safe still refuses. Smash the 8th → the safe unlocks and the broadcast fires.
5. Weld the safe → it visibly opens and the loot is inside.
6. Loot it → the Qilin appears at the stated position facing south, loaded, keyed to everyone on
   site, with unlimited T inventory.
7. Leave it 20 minutes → the scene resets and the 30-minute cooldown blocks a retry.
8. Restart the server → the Qilin is gone.
