# Resource Extractor + Processor (traded in, 2026-08-27)

Two HEMTT-flatbed working vehicles built from a traded implementation contract.
The truck is the networked, authoritative entity; every drill/processor part is
a CLIENT-LOCAL simple object attached to it -- nothing custom is networked or
simulated, which is what keeps traffic and collision cost at zero.

## Files
| piece | where |
|---|---|
| Models | `custom_p3ds/ap_rig_{pivot,arm,bit,processor}.p3d` (MLOD, single LOD) |
| Textures | `images/rig/rig_hemtt{1,2,3}.jpg` (HEMTT slots 0/1/2) |
| Client | `core/vehicle/fn_rigClient.sqf` -- parts, orbit math, animation driver |
| Server | `server/AP_server/core/TON/fn_rigSRV.sqf` -- spawn/state/validation/ticks |
| Actions | `core/fn_setupActions.sqf` -- Deploy / Pack Up / Start / Stop |

## The state machine (server-owned, clients render)
    compact -> deploying(5s) -> deployed -> startingMining(1.15s) -> mining
    mining -> stoppingMining(1.15s) -> deployed -> folding(5s) -> compact
Engine is forced off whenever the drill is not compact. Transitions ride
serverTime + smoothstep so every client sees the same motion; >350m snaps.
The arm and bit ORBIT a shared hinge ([0,-5.35,-0.32] + global add) -- the
tuned offsets table lives in the client file; the formulas are the authority.

## Mining
Park inside an existing gather field (the SAME markers fn_gather reads:
mine_* 70m, oil_*/rock_*/salt_* 150m). Tick = 1.3s, one unit of the zone's
loot roll into the TRUCK'S OWN virtual trunk (AP_vinv, extractor cap 220),
weight-capped by AP_fnc_vehicleWeight. Hopper full -> drill auto-stops to
deployed. What it pulls is already in the economy: deck Trunk app moves it,
the Exchange SELL tab lists it, processors/fabricators consume it.

## Spawning (v1 -- no economy placement yet, owner decides)
Server console / debug:
    [["spawn", ["extractor", getPosATL player, getDir player, "<uid>"]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP;
    [["spawn", ["processor", getPosATL player, getDir player, "<uid>"]], "APS_fnc_rigSRV", 2] spawn AP_fnc_MP;

## Phase 2 (landed 2026-08-27)
- **Factory recipes**: `rig_extractor` / `rig_processor` sentinels in
  fn_recipeDetail, built at the vehicle factory pads via APS_fnc_rigSRV
  "craft"; blocked-pad refunds the materials.
- **Garage persistence**: `vehicles.rig_kind` column (boot DDL); written by
  insertVehicle via vehicleCreate reading the truck's own var; re-adopted at
  pull inside APS_fnc_vehicleSetActive -- one copy of the adoption ("adopt"),
  whatever door the truck came through. Hopper contents ride the existing
  trunk persistence untouched.
- **RIG CONSOLE deck app**: state pill, deposit offer as target chips (pick
  what to mine -- server validates the pick against the zone's own loot),
  hopper bar + manifest, the four verbs. One scroll action opens it.

## Processor (phase 2, landed 2026-08-27)
Donor linkage defaults kept: **35 m feed range, max 2 extractors per
processor, one processor per extractor**, links stored by netId (runtime-only
-- netIds die at restart, re-link from the console after a pull; presentation
parts never own state). States ride `AP_rigState`: `idle <-> processing`.
Engine forced off while refining; rolling or a full hopper auto-idles it.

Refine loop (`procStart`): one raw unit per 2.6 s tick -- linked extractor
hoppers FIRST, the processor's own trunk second (hand-loaded raw refines too).
1:1 conversions, the same pairs the processing plants run:
ironore->iron_r, copperore->copper_r, sand->glass, diamond->diamondc,
oilu->oilp, salt->salt_r. Redshift is already refined -- it only hauls.
All hopper mutation is server-side published AP_vinv with weights re-derived
from AP_fnc_virtItemCfg; capacity via AP_fnc_vehicleWeight.

Deck RIG CONSOLE processor view: state pill, linked feeds (dist/state/raw
count/UNLINK), in-range linkable extractors (LINK), hopper bar+manifest,
START/STOP REFINING. Extractor view gains a FEEDING PROCESSOR pill.
Kill of either truck clears the link on both sides (donor contract 13.6).

## Still open
- Processor sound (drill pair delivered; no processor loop yet)
- Link persistence across restart (would need DB ids instead of netIds)

## needstest

**2026-08-27 owner playtest: processor loop CONFIRMED working in-game** (link +
auto-refine, first try, b0770). Remaining rows below unticked stay worth a
pass -- especially R12 (garage round-trip) and the adversarial ones (R10/R17/
R18/R23).

**2026-08-27 pull-bug fixes (b0769):** R12 blockers root-caused. (1) setActive read the mode-2
row wrong (asyncQuery returns the first row FLAT; the legacy string branch ate the inventory cell
and never read rig_kind) -> adopt never fired on pulls; script spawns worked because they call
adopt directly. Fixed the unwrap. (2) `civ_air_hs_1` RPT error in both garage pulls = Altis ghost
objects in `_boatSpawns`; NON-fatal (array literal recovers, -VEHSPAWN- proved positioning ran) --
pure noise, list trimmed to the two string markers. (3) "Skin texturing error occured!" = color 0
paint broadcast for a class with no texture rows; prepareVehicle now skips the paint path for the
flatbed (rig skin comes from adopt), test rows set color=-1. (4) restoreVehicles now SELECTs
rig_kind (index 14) and re-adopts, so a rig left OUT across a restart no longer restores bare.
| # | Test | Pass looks like |
|---|---|---|
| R1 | Spawn extractor, walk around it | Truck skinned, pivot+arm+bit visible, drill compact on the bed |
| R2 | Deploy | 5s smooth raise, arm+bit stay JOINED at the hinge, engine refuses to start |
| R3 | Start Extracting outside any field | Refused with the message |
| R4 | Drive into mine_1, deploy, start | Bit drops 1.5m, spins; trunk gains ore every ~1.3s |
| R5 | Second client watches deploy | Same timing, same geometry (serverTime sync) |
| R6 | JIP while deployed/mining | Late joiner sees the correct state, ONE assembly, no dupes |
| R7 | Hopper to cap | Auto-stops to deployed; trunk at cap |
| R8 | Pack Up, drive off | Compact again, engine starts |
| R9 | Blow the truck up | All parts vanish on every client |
| R10| Forged remoteExec (wrong owner / moving / crewed) | Refused server-side, -SEC-/-RIG- logged |
| R11| Craft extractor at the Factory | Materials consumed, truck on the pad, skinned, drill visible, keys work |
| R12| Store crafted rig, restart server, pull from garage | Comes back AS a rig -- skin, drill, console; hopper contents intact |
| R13| Rig Console: pick IRON ORE in a mine field, START | Hopper fills with iron ore only |
| R16| Park processor <35m from mining extractor, LINK, START REFINING | Extractor raw drains, processor gains refined 1:1, every ~2.6s |
| R17| Link a 2nd extractor, then try a 3rd | 3rd refused "already feeds from two" |
| R18| Link an extractor already feeding another processor | Refused |
| R19| Drive processor away while refining | Auto-idles; link prunes past 40m |
| R20| Load raw ore into processor trunk by hand, no links, START | Own trunk refines in place (raw count down, refined up) |
| R21| Processor hopper to cap | Auto-idles, extractor hopper keeps its raw |
| R22| Blow up a linked extractor | Processor link list drops it; no errors |
| R23| Keys check: player without extractor keys tries LINK | Refused "keys to that extractor too" |
| R14| Pick a resource, drive to a SALT field, START | Target invalid there -> deposit mix (salt); console re-offers |
| R15| Blocked factory pad | Materials refunded, message says so |
