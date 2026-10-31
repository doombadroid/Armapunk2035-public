# Armapunk 2035 — fork status

Forked from LooneyBin (Altis) on 2026-07-25. Full history preserved: `git log` before the fork point is
the LooneyBin codebase. Map layer comes from the external designer's `ProjectMaldenMerge.Malden`.

## What the map layer is, and how it is assembled

The designer authors placement in Eden and exports a **binarized** `mission.sqm`. Custom buildings are
placed there as `Land_HelipadEmpty_F` anchor objects. The pipeline is:

1. `sqm_strip_anchors.py` (from `doombadroid/v2`) deletes the 39 anchors from the sqm and renumbers the
   surviving `ItemN` classes. It refuses to write unless a parse→serialize round-trip reproduces the
   source byte-for-byte first.
2. `custom_p3ds/malden_buildings.sqf` re-creates them with `createSimpleObject`, using
   `getMissionPath ""` so the `.p3d` resolves inside the packed PBO.

**Both steps are required.** The raw sqm still contains the anchors — shipping it together with
`malden_buildings.sqf` places every custom building twice. Verified at import: 39 anchors in the raw sqm,
0 after stripping, 39 placements in the sqf. The 16 bridge pieces were never sqm anchors; they are
sqf-only.

## Where the map scripts are called from, and why

`malden_buildings.sqf` runs from **both** `initServer.sqf` and `initPlayerLocal.sqf`, matching how
`custom_p3ds/load.sqf` already works. It is deliberately **not** in `init.sqf`: that runs before the
world is ready on clients, so `createSimpleObject` silently no-ops and the buildings exist server-side
only. The designer's original file placed them in `init.sqf`; LooneyBin had already learned this the hard
way and left a note about it in `init.sqf`.

`custom_p3ds/malden_atmosphere.sqf` (client only) carries the permanent-dusk identity — Halloween
2035, `setDate [2035,10,31,16,0]` — plus the mine/cave lighting and teleports. Three fixes over the
designer's version: definitions moved above the `spawn` loop that calls them, each `addAction` hook is
presence-checked, and the cave loop only starts if `caveArea` exists.

## Player slots

The designer's sqm shipped **no playable units**, so the server booted with `Number of roles (0)` and
nobody could join. Roles are assigned from the lobby before any script runs, so they cannot be created at
runtime — they have to exist in mission.sqm.

**Current state (2026-08 faction rework).** The mission ships **60 identical civilian slots and nothing
else**. There is no cop or medic slot to pick: MaxSec and Trauma Team are entered in-world at an HQ duty
terminal, which writes a server-side roster entry for the length of the shift. `description.ext`'s
`maxPlayers` is 60 to match, so the boot line to expect is a bare `Number of roles (60)` with no
`is different from maxPlayer` warning after it. **The flag and this layout are one deployable unit** —
see `DUTY_SOAK.md` §0.

**How it got here.** `tools/sqm_add_roles.py` originally copied the 201 playable units (138 groups) out of
the Altis sqm, which was a format conversion: Altis ships a TEXT sqm and Malden shipped a binarized one.
They were copied rather than generated because the slot names were load-bearing — `core/fn_initCop.sqf:17`
gated the SGT+ slot on `(str player) in ["cop_17"]`, and the lobby descriptions ("WhiteListed - Cop",
"Whitelisted - Trauma Team (TT)", …) were what staff whitelisted against. The script still asserts
`cop_17` survives the round-trip; that check (and this whole tool) predates the rework, which retired the
lobby slots and moved SGT+ ("all") authority to the duty terminal off `players_global`
(`core/duty/fn_dutyCfg.sqf`'s "all" role: `AP_copLevel >= 6` or `AP_adminLevel >= 3`). **Do not re-run
it** — it re-adds the retired layout; it now refuses early and says so instead of crashing.

The imported Altis slots sat on that map's northmost islet, which is off-map on Malden (12.8km vs
30.7km), so the cluster was translated away from it — every object in the designer's sqm was binned into
1km cells and that corner held 0 of 13,202, and boot confirmed water at -10.5m ASL, so the units floated
rather than spawning underground. The 60 that survive the trim sit at `[5826.9, 6873.6]` already parked
at 50324m ASL. Either way they are only there for the seconds before `fn_spawnMenu` does
`player setPosASL [worldSize/2, worldSize/2, 50000]; player enableSimulation false` and holds them there
until they pick a spawn. **That hold needed no porting** — `worldSize` resolves per world (12800 here).

## Known gaps

- **TODO: custom building footstep sound.** Walking inside the custom buildings sounds like soft
  sand and does not match a stock building's floor. Pre-existing and map-wide -- all ten designer
  models ship a Roadway LOD with an EMPTY material (MADGrandPalace 284 faces, RebelRig 204,
  JewelryBuildingModel 185, Bank 151, HQMesh 70, PalaceShop 31, ShopBuildingTrini 31,
  mentalasylum13 49, BridgeStraight 2, BridgeMiddle 1).

  The palace currently carries `a3\data_f\penetration\concrete.rvmat` on its roadway, applied with
  `tools/p3d_set_roadway_surface.py`. That is what BI's own buildings use -- structures_f.pbo
  references it 118 times -- and it loads without error, but it does NOT make the floor match a
  stock building. Left applied because it is closer to correct than empty and costs nothing.

  Ruled out with evidence: `createSimpleObject` (a stock house spawned that way sounds right);
  `soundEnviron` (all 81 A3 .bisurf files set it to Empty, yet BI buildings sound correct, and
  forcing it to "metal" on ours changed nothing); roadway coverage (three roadway faces sit directly
  under the tested position); and the model itself (LODs are intact, the rebuild is byte-identical
  to the designer's outside LOD0).

  Not yet tried: the roadway face TEXTURE rather than the material (`--texture` on that tool), and
  reading a stock building's roadway out of structures_f.pbo, which needs an ODOL parser.

  **Gotcha that cost several rounds:** Arma caches models BY PATH and `__cur_mp.<WORLD>` is identical
  on every build, so swapping a .p3d in place keeps rendering the cached copy. Rename the file (the
  palace is on `MaldenGrandPalaceBuilding.p3d` for this reason) or fully exit Arma. Otherwise a correct fix
  looks like no fix.

- **`a3_characters_f` reported as deleted content at startup.** Pre-existing — an A/B boot against the
  pre-roles sqm reproduces it with `roles (0)`, so it is the designer's `addons[]`, not the added slots.
  Non-fatal: one warning, one `Reading mission`, roles assigned, and `characters_f.pbo` is present in the
  dev install. Worth re-checking the first time a real client tries to join, since the message is the one
  a client shows when it refuses a mission.
- **`exitMine` is not in mission.sqm.** `enterMine`, `escapeJail` and `caveArea` are. The Exit Mine action
  is therefore skipped at runtime with a `diag_log` line instead of throwing. Either the designer adds the
  object or the action should be dropped.
- **`fn_mapData.sqf` still holds ALTIS coordinates** — ~7,100 lines, every shop, NPC, dealer and marker.
  Nothing in this fork has moved them to Malden positions. The world will boot; the economy furniture will
  be in the sea. This is the actual remaining migration work and it is the bulk of it.
- **Asylum-branded asset names** survive in the map layer (the Grand Palace was renamed to
  `MaldenGrandPalaceBuilding.p3d` 2026-07-25 and its old copies superseded; the rest remain):
  `asylumincreptionwall.paa`, `mentalasylum13.p3d`. The `.p3d` names are safe to rename (only
  `malden_buildings.sqf` references them); the `.paa` names may be baked into the models' texture paths,
  so those need checking before renaming.
- **No live server, no deploy target.** `deploy/` paths were repointed to `Armapunk2035.Malden` and
  `Armapunk2035_bNNNN.Malden.pbo`, and the mission packs (2,147 files), but nothing has been run.

## Architecture note

LooneyBin's own Malden plan (`malden.md`, PR #70, still open there) deliberately chose an **overlay**
architecture — one code tree, Malden assembled at pack time — specifically so fixes would not have to land
twice. This repo is the opposite call: a hard fork. That is the right shape if Armapunk 2035 is its
own server with its own identity, and the wrong one if it is meant to be a map rotation of LooneyBin.
Worth being deliberate about, because every future LooneyBin fix now has to be ported by hand.
