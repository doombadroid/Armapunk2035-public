# Drug rework — cyberpunk renames, LSD/PCP strip, Boost adulterant

Design spec. Owner-approved 2026-08-21.

The drug economy still reads as stock Altis Life: crystal meth, cocaine bricks,
Heisenberg blue, LSD tabs, PCP sheets. This pass renames the hard-drug catalogue
into the Armapunk 2035 fiction, deletes two whole chains, gives each surviving
drug a real mechanical trade-off, and adds one new economy lever — an adulterant
that doubles yield.

Cannabis and alcohol are **out of scope** for the rename. Cannabis products are
in scope for cutting (see §4).

---

## §1 Renames

Item **keys** change, not just display names. There is no live Armapunk server,
no SQL schema references any item key, and the bot does not read this project's
logs — so the ~320 references across the tree are a mechanical sweep with no
migration risk. Keeping `AP_inv_meth` as the variable that means Black Lace
would leave the code lying about itself permanently.

| Old key | Old display name | New key | New display name |
|---|---|---|---|
| `ephedrau` | Ephedra plant | `sparkdust` | Sparkdust |
| `phos` | Phosphorus | `redshift` | Redshift |
| `hydro` | Hydrogen Sulfate | `toxicslurry` | Toxic Slurry |
| `ephedra` | Meth Cocktail | `lacebase` | Lace Base |
| `meth` | Crystal Meth | `blacklace` | Black Lace |
| `bluemeth` | Heisenberg Meth | `blacklaceprime` | Black Lace Prime |
| `cocaine` | Unprocessed Cocaine | `smashpowder` | Smash Powder |
| `cocainep` | Cocaine | `smash` | Smash |
| `cokebrick` | Cocaine Brick | `smashbrick` | Smash Bricks |
| `crank` | Crank Cocktail | `glitterbase` | Glitter Base |
| `crankp` | Crank | `glitter` | Glitter |
| `fentanylu` | Raw Fentanyl | `boost` | Boost |

Prices, weights and illegal values are unchanged by the rename.

**Art:** the existing `.paa` files are kept, renamed to match the new keys
(`icons/meth.paa` → `icons/blacklace.paa`, etc.) with the paths in
`fn_virtItemCfg.sqf` updated. The pixels are still cocaine and crystal meth
art — a visual reskin is a separate pass and is not part of this work.

**Recipe keys** in `AP_processMap` / `fn_processVehicle` rename alongside their
outputs (`meth` → `blacklace`, `methcocktail` → `lacebase`, `cocaine` →
`smash`, `cokebrick` → `smashbrick`, `crank` → `glitterbase`, `crankp` →
`glitter`, `bluemeth` → `blacklaceprime`). The `addAction` captions at the
processor NPCs rename to match.

---

## §2 Deletions — LSD and PCP, total strip

Both chains go entirely: items, code, recipes, shop rows, charges, assets.

### Items removed

`lsd_0` · `lsd_1` · `pcpu` · `pcp` · `pcpp` · `fungi` · `henbane`

Fungi and henbane exist only to feed LSD and PCP respectively, so they go with
them.

### Files deleted outright

```
mission/Armapunk2035.Malden/core/drugs/fn_lsd.sqf
mission/Armapunk2035.Malden/core/drugs/fn_pcp.sqf
mission/Armapunk2035.Malden/core/drugs/fn_heroin.sqf
mission/Armapunk2035.Malden/core/actions/fn_mineFungi.sqf
mission/Armapunk2035.Malden/core/actions/fn_fungiActions.sqf
mission/Armapunk2035.Malden/npcs/fn_civFungi.sqf
```

Each also loses its `Functions.h` registration. `fn_heroin.sqf` goes because
its item was deleted in a previous pass and the hook was only being kept for
fentanyl to inherit — Boost has no effect, so nothing inherits it (§3).

### Files edited

| File | What |
|---|---|
| `core/config/fn_virtItemCfg.sqf` | 7 item rows removed |
| `core/actions/fn_processAction.sqf` | `fungi`, `lsd_1`, `pcpu`, `pcp`, `pcpp` recipes; `lsd_0` process sound; `pcp*` in the infamy-talent and tax lists |
| `core/actions/fn_processVehicle.sqf` | `fungi` recipe, `heroin` recipe |
| `core/actions/fn_gather.sqf` | `illegal_marker_8_0` henbane zone; henbane from the two talent clauses |
| `core/fn_setupActions.sqf` | "Gather Henbane" action (L489) |
| `core/pmenu/fn_useItem.sqf` | `lsd_0`/`lsd_1`, `pcp`, `heroinp` cases |
| `core/drugs/fn_drugUsed.sqf` | `heroinp` and `lsd` arms |
| `npcs/fn_civProcessItem.sqf` | `case "heroin"`; the `purificationfactory` comment's stale references |
| `core/config/fn_virt_shops.sqf` | `pcp`, `pcpp`, `lsd_0`, `lsd_1` rows |
| `core/config/fn_exchangeCfg.sqf` | `lsd_0`, `lsd_1`, `pcp` |
| `core/config/fn_loginBonusCfg.sqf` | `pcp` (L27), `lsd_0` (L35) |
| `core/config/fn_prestigeCfg.sqf` | henbane (L11, L95) |
| `core/config/fn_talentCfg.sqf` | talent 223 "Rockhound" — drop the fungi clause, keep uranium, reword the description |
| `core/config/fn_wantedChargesConfig.sqf` | PCP (L26), Fungi (L36), LSD/PCP (L37) |
| `server/AP_server/core/TON/fn_wantedChargesConfig.sqf` | same charges — **this second copy must stay in sync** |
| `core/compat/fn_itemDemand.sqf` | `lsd_0`, `lsd_1` (L25) |
| `core/functions/fn_statArrUpdate.sqf` | henbane (L35), `pcpu`/`pcp`/`pcpp` (L36) |
| `core/shops/fn_sellVehicleInv.sqf` | `lsd_0`, `lsd_1`, `pcp` (L44) |
| `core/actions/fn_metalDetector.sqf` | `lsd_0` (L31) |
| `core/vehicle/fn_deviceMine.sqf` | henbane (L25) |
| `core/vehicle/fn_tractorMine.sqf` | henbane (L23) |
| `evh/fn_onPlayerRespawn.sqf` | `AP_inFungiDen` clear (L19–21) |
| `core/configuration.sqf` | `pcp` reference (L2) — append-only file, do not reformat |
| `core/radio/fn_plbInvDemo.sqf` | LSD reference (L14) |
| `debug/npcprobe.sqf` | pcp/PCP references |
| `initServer.sqf` | the `illegal_marker_8_0` comment block (L70) |
| `server/AP_server/core/system/fn_marketTick.sqf` | `lsd_0`, `lsd_1` (L38, L46) |
| `server/AP_server/eventhandlers.sqf` | pcp/PCP (L116) |
| `CfgSounds.hpp` | `gatherLsd`, `makeLsd` classes |
| `website/src/lib/compItems.ts`, `houseItems.ts` | generated item lists — regenerate or hand-edit |
| `tools/make_compositions.py`, `npc_move.py`, `npc_place.py` | fungi/PCP references |

### Assets deleted

```
icons/lsdpill.paa  icons/lsdpurify.paa  icons/pcp.paa  icons/pcpp.paa
icons/pcpu.paa     icons/darkmushroom.paa  icons/henbane.paa
sounds/gatherLsd.ogg  sounds/makeLsd.ogg
```

### Map

**Nothing.** `mission.sqm` contains zero references to any of these. The Fungi
Den is an NPC placed from `edenNPC_data.sqf`, and the henbane field's marker
`illegal_marker_8_0` **does not exist in the Malden .sqm at all** — the gather
action is gated on `markerType != ""`, so that field has never been reachable
on this map. Deleting it removes dead code, not content.

The Fungi Den NPC entry is removed from the NPC data; the Den's physical
buildings and elevator are map-layer objects and are left in place for the
designer to repurpose or remove separately.

---

## §3 Effects

Arma has no max-HP stat. Health is the engine's `damage` scalar, `0.0` = full,
`1.0` = dead; the HUD renders `(1 - damage) * 100`. Every "HP" number below is
therefore defined as an operation on that scalar.

All three active drugs run for **3 minutes**. Health lost is **permanent** — it
does not come back when the effect expires.

### Black Lace — `blacklace`, `blacklaceprime`

| | |
|---|---|
| Health | `setDamage (damage player + 0.5)`, clamped to **0.95** — maims, never lethal on its own |
| Healing | blocked for the full 3 minutes |
| Sway | `setCustomAimCoef 0.1` — 10% of normal |
| Speed | `setAnimSpeedCoef 1.15` — +15% sprint |
| Addiction | **instant** — `AP_addiction set [3, 1]` |
| Visuals | existing meth ColorInversion + chromAberration, unchanged |

The heal block is a new mission variable `AP_healBlock` holding an expiry time.
Every heal path checks it and refuses: `fn_survival`'s passive regen, the
bloodbag, the medkit, the first-aid kit, the defibrillator, the adrenaline shot,
and the medic heal action. This is the one genuinely new gate in the design and
it must be applied to **all** of them — a single missed path makes Black Lace's
downside optional.

### Smash — `smashpowder`, `smash`, `smashbrick`

| | |
|---|---|
| Health | `setDamage (damage player + 0.3)`, clamped to 0.95 |
| Speed | `setAnimSpeedCoef 1.20` — +20% |
| Visuals | Black-Lace-style ColorInversion + chromAberration (cocaine currently has none) |
| Addiction | slot 1, +0.10 per use — not instant |
| Duration | 6 minutes, unchanged from cocaine |

### Glitter — `glitter`

| | |
|---|---|
| Shield | 0.5 absorb pool, **non-decaying**; drains before health; ends when spent or at 3 min |
| Healing | none — does **not** repair existing damage |
| Speed | `setAnimSpeedCoef 0.85` — −15% |
| Addiction | **instant** — `AP_addiction set [4, 1]` |

The shield lives in the existing `evh/fn_handleDamage.sqf` event handler: while
a pool is active, incoming damage is subtracted from the pool first and only the
remainder reaches the health bar. Because it never decays, Glitter is a
pre-fight commitment — you trade mobility for one extra half-bar of survival.

### Boost — `boost`

No effect when taken. `fn_useItem` returns an explicit message saying it is a
cutting agent, rather than falling through to the generic "This item is not
usable" default. Its only purpose is §4.

### Addiction slots

`AP_addiction` stays **5 wide**, so nothing about its persistence changes and no
profileNamespace or DB migration is needed.

| Slot | Was | Now |
|---|---|---|
| 0 | cannabis | cannabis (unchanged) |
| 1 | cocainep | Smash |
| 2 | heroinp | **unused** |
| 3 | meth | Black Lace (instant) |
| 4 | crank | Glitter (instant) |

Deleting LSD also fixes a live bug in passing: `fn_lsd.sqf` called
`["lsd"] call AP_fnc_drugUsed`, and `fn_drugUsed` mapped `"lsd"` to index 1 —
so taking LSD accrued **cocaine** addiction. The arm goes with the chain.

---

## §4 Cutting with Boost

### Why this needs a code change

`fn_processAction.sqf` is structurally 1:1. It computes
`_inputCount = selectMin _inputVals` — the smallest stock across all inputs —
consumes `_inputCount` of *each* input, and emits exactly `_inputCount` of the
output. There is no yield term anywhere in the function. A naive cut recipe
`[["smash","boost"], "smash", ...]` would consume N Smash and N Boost to produce
N Smash: a net loss. Doubling is not expressible as a data row today.

### The change

Add a **sixth column to `AP_processMap` rows: `_yield`, defaulting to 1.**
Consumption still uses `_inputCount`; output becomes `_inputCount * _yield`.
Roughly four lines in `fn_processAction.sqf`, mirrored in
`fn_processVehicle.sqf`. Every existing row keeps its current behaviour by
omitting the column.

### The recipes

Key `cut_<drug>`, inputs `[<drug>, "boost"]`, output `<drug>`, yield 2. Eleven
of them:

| Recipe key | Drug |
|---|---|
| `cut_smashpowder` | Smash Powder |
| `cut_smash` | Smash |
| `cut_smashbrick` | Smash Bricks |
| `cut_blacklace` | Black Lace |
| `cut_blacklaceprime` | Black Lace Prime |
| `cut_glitter` | Glitter |
| `cut_marijuana` | Reggie Cannabis |
| `cut_marijuanam` | Medicinal Cannabis |
| `cut_cannas_3` | Sativa Bud |
| `cut_cannai_3` | Indica Bud |
| `cut_canna_dab` | Golden Wax |

Each gets one `Cut <name> with Boost` scroll action at that drug's own
processor NPC, gated on holding both the drug and Boost. Cocktail/base tiers
(`lacebase`, `glitterbase`) are not cuttable — they have no shop sell price.
Alcohol is not cuttable.

**Hand-processing only this pass.** Cut recipes get no `Process Vehicle`
counterpart, so a trunk cannot be cut in bulk. That bounds the Boost sink to
something observable before the economy is tuned. The `_yield` column is still
added to `fn_processVehicle.sqf` alongside `fn_processAction.sqf` so the two
recipe-row formats stay identical — bulk cutting is then a data change, not a
code change, if the owner wants it later.

### Three rules that stop it becoming a farm loop

1. **No infamy and no `statArrUpdate` on cut recipes.** The drug already paid
   both when it was produced. Without this, cutting is an infinite infamy tap.
2. **The cartel tax applies to the doubled amount.** Cutting inside a
   rival-held Drug Cartel radius costs proportionally more, which keeps the
   cartel meaningful at the new volume.
3. **Weight guard: cap the output to what will actually fit, before consuming
   the inputs.** `fn_processAction` currently consumes inputs and *then* calls
   `handleInv` for the output, so a full inventory silently destroys the batch.
   Doubling the output makes that pre-existing bug fire constantly, so it has
   to be fixed as part of this work rather than left.

---

## §5 Verification

There is no SQF test harness, so verification is the project's standard chain:

1. Arma-aware brace/bracket balance check across every edited file (`""` is an
   escaped quote, not `\"`; skip `//` and `/* */`).
2. `grep -rn` sweep for every deleted key and every old key name across
   `mission/`, `server/`, `tools/`, `website/` — the sweep must come back empty.
   **`loonybot/` is excluded from this sweep by design** (see Known issues #1);
   it keeps the old names deliberately, so a sweep over the repo root would
   report a failure that is actually correct. This is the real gate on the
   rename: a missed `AP_inv_meth` fails silently at runtime as an undefined
   variable, not as an error.
3. `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`, then wait for
   `grep "read from bank" /home/timb/arma3server_dev/loonydev.log`.
4. Client RPT clean of new errors.
5. In-game pass: take each of Black Lace, Smash, Glitter and Boost; confirm the
   health delta, the speed change, the sway change, the heal block, the shield,
   and instant addiction where specified. Run at least one cut recipe and
   confirm the doubled output, the absent infamy, and the weight cap.

---

## Known issues left standing

Three things this work deliberately does not fix.

1. **`loonybot/clankr.py` is not updated, on purpose.** Its `_BAL_ITEMS`
   mass-balance detector keys on `("Hydrogen Sulfate", "hydro")`,
   `("Phosphorus", "phos")` and `("Ephedra plant", "ephedrau")` — all three
   renamed here. But it parses logs from the frozen LooneyBin Altis box, where
   those names are still correct. Changing it now would break the detector on
   the only server it actually watches. It becomes a launch blocker the moment
   Armapunk goes live, and belongs in `launch.md`.
2. **Boost is also a rifle-crafting material.** `fentanylu` feeds twelve weapon
   recipes in `fn_recipeDetail.sqf`. An adulterant doubling as gun feedstock is
   strange, but it predates this work; the rename carries it over unchanged.
3. **`sugar` does not exist.** The `rum` and `rumsalt` recipes in
   `AP_processMap` require an item with no row in `fn_virtItemCfg.sqf`, so both
   rum distillation paths are unreachable. Pre-existing, unrelated, still
   broken after this pass.
