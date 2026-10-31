# House Weed — Offline Grow System (design spec, owner-approved 2026-06-13)

Passive, offline weed-growing in player houses. Goal: a player can make a good living growing while
offline, without printing money (dynamic-market floor caps inflation).

## Core loop
1. Buy a **Greenhouse** (house menu, one-time upgrade, 1 per house).
2. Buy **seeds** (Indica or Sativa) from a dealer.
3. **Plant** seeds into the greenhouse (consumes seed, adds a plant entry with a `planted_at` timestamp).
4. Plants **mature by REAL TIME**: 1 stage/hour, 3 stages → **3 hours** seed→mature. Grows while offline.
5. **Harvest** mature plants → Weed / High-Potency Weed items.
6. Sell raw at a **drug dealer**, or take to the **Weed Processor** → Wax / Golden Wax, then sell.

## Growth (ROCK-SOLID persistence — the critical requirement)
- Each greenhouse batch persisted in the DB: new `houses.greenhouse` TEXT column =
  `[[strain, planted_at_unix, count], ...]` (one entry per planting).
- **Stage = floor((now_unix - planted_at) / 3600).** Pure function of wall-clock time. 1 stage/hour.
- Per-strain MATURE stage (owner 2026-06-13: Sativa faster for the speed-vs-value tradeoff):
  - **Sativa: matures at stage 2 (2 hours)** — quick cash, lower value.
  - **Indica: matures at stage 3 (3 hours)** — slow, premium (Golden Wax).
- Evaluated on **server boot AND on player login** (whenever the house/greenhouse is read). NO per-restart
  tick to miss → restarts, crashes, irregular reboots cannot desync growth. Caps at the strain's mature
  stage (no rot for now).
  - Stage 0 = Seed · 1 = Seedling · 2 = Juvenile (Sativa MATURE) · 3 = MATURE (Indica).

## Strains (same 3h grow, differ by VALUE vs VOLUME)
| | Sativa (fast / quick cash) | Indica (slow / premium) |
|---|---|---|
| Seed cost | **$100** (any drug dealer) | **$100** (any drug dealer) |
| **Grow time** | **2 hours** (matures stage 2) | **3 hours** (matures stage 3) |
| Matures to | **Weed** | **High-Potency Weed** |
| Raw sell (drug dealer) | **$500** | **$700** |
| Process → | **Wax** ($800) | **Golden Wax** ($1,200) |
| Golden Wax? | NO | **YES (only Indica)** |
- Yield: **1 seed → 1 plant → 1 harvested unit** (both strains).
- Seeds sold at **every drug dealer**, $100 each.
- BALANCE RESOLVED (owner 2026-06-13): **Sativa grows faster (2h)** = quick, lower-value turnover; Indica
  slower (3h) = higher value + Golden Wax. Speed-vs-value tradeoff → both viable. Sativa $/hr ≈ 500/2h=250/plant/h
  raw; Indica ≈ 700/3h≈233 raw but 1200/3h=400/plant/h as Golden Wax. Roughly balanced; tune from live data.

## Capacity & weights
- **Greenhouse plant capacity = floor(house max virtual-inventory cap / 10).** A 3C house at max Y upgrade
  (3000 vinv) → **300 plants**. Smaller houses proportionally fewer.
- A **growing plant costs 10** greenhouse capacity (this is the /10).
- **Harvested products weigh 1 Y unit each** (Weed, High-Potency Weed, Wax, Golden Wax) — light for transport
  and selling. (Seeds: small weight, normal carry item.)

## Items
| Item | classname | weight | notes |
|---|---|---|---|
| Sativa Seed | `weed_seed_sativa` (NEW) | small | buy at any drug dealer, $100 |
| Indica Seed | `weed_seed_indica` (NEW) | small | buy at any drug dealer, $100 |
| Weed | `marijuana` (EXISTS) | **1** | Sativa harvest, sell $500 |
| High-Potency Weed | `marijuanam` (EXISTS) | **1** | Indica harvest, sell $700 |
| Wax | `weed_wax` (NEW) | **1** | Sativa-Weed processed, sell $800 |
| Golden Wax | `canna_dab` (EXISTS) | **1** | Indica-HP processed, sell $1,200 |
- Reuse existing `marijuana`/`marijuanam`/`canna_dab`; add 2 seeds + normal Wax. Re-weight the 4 products to 1.

## Processing
- Extend `fn_processAction` / weed processor NPC:
  - Weed (`marijuana`) → Wax (`weed_wax`), 1:1.
  - High-Potency Weed (`marijuanam`) → Golden Wax (`canna_dab`), 1:1. **Indica-line only.**

## Selling (dealer + dynamic market, floored)
- Sell at existing **drug dealers** (virtual shop sell).
- Prices feed the **two-sided dynamic market** (`AP_price_index`): dumping volume drops the price, but
  **clamp the drop at −50%** (price floor = 50% of base) for these items. Never below half. Recovers over time.
- Base sell prices: Weed 500, HP Weed 700, Wax 800, Golden Wax 1200.

## Income math (full house, one 3h cycle, before market crash)
- Sativa: 300 → 300 Weed × $500 = **$150k** raw, or → Wax × $800 = **$240k**.
- Indica: 300 → 300 HP × $700 = **$210k** raw, or → Golden Wax × $1200 = **$360k** (dumping all → −50% floor ≈ $180k).
- Spread your sales to beat the floor. Offline-friendly: it grows while you sleep; selling is the active part.

## Cop raiding — STUBBED
- Leave a hook (`AP_fnc_greenhouseRaid` / a flag) but OFF for now. Possible later balance lever: cops search a
  house → seize the growing crop.

## EXISTING INFRASTRUCTURE (audit 2026-06-13 — most of it is already here, just dead-wired)
- **Items EXIST**: `cannas_0/1/2/3` (Sativa Seed→Sprout→Adult Plant→Bud), `cannai_0/1/2/3` (Indica), plus
  `marijuana`/`marijuanam`/`canna_dab` (Golden Wax). All in `fn_virtItemCfg`. The bud (`_3`) is the harvest.
- **Greenhouse upgrade EXISTS**: `fn_upgradeProperty` "greenhouse" case ($45k) sets `AP_greenhouse_unaged`
  + writes the houses DB `greenhouse` column (`fn_updateProperty`). House menu shows "Add/Installed Greenhouse".
  BUT it's just a FLAG — "allows you to grow cannabis" with NO actual grow logic behind it. Dead feature.
- **Smoking/consumption EXISTS** (`fn_cannabisItems`: bong/rig/joint/vape consuming buds + dab).
- **Processing EXISTS** (`fn_processAction`: cannabis→marijuana etc — extend for bud→wax/golden wax).
- **Selling EXISTS** (drug dealers + two-sided dynamic market — add the −50% floor for these items).
- **MISSING = the grow loop**: plant seed → time-based stage transition (rock-solid persistence) → harvest.
  Map the existing `_0.._3` items to the stage chain. Add a `greenhouse_crop` DB column for per-plant
  [strain, planted_at] (the existing `greenhouse` column is the 0/1 install flag — keep it, add a new one).

## BUILD STATUS (2026-06-13, staged → next reboot)
DONE (MVP grow loop, all bracket-checked):
- `APS_fnc_greenhouseSRV` (server, authoritative crop + DB persist + boot `reload`) — `houses.greenhouse_crop` col.
- `AP_fnc_greenhouse` (client: plant / harvest / status) + 4 scroll actions in `fn_setupActions` (gated on owned
  house + greenhouse upgrade): Plant Sativa, Plant Indica, Harvest, Check.
- Boot: `AP_bootUnix` wall-clock ref + crop reload. Registered: config.cpp, CfgRE, Functions.h.
- Items re-weighted to 1 + re-priced: Weed `cannas_3` 500 (floor 250), HP `cannai_3` 700 (floor 350),
  Golden Wax `canna_dab` 1200 (floor 600). Seeds `cannas_0`/`cannai_0` $100, buyable at drug dealer; harvest
  sellable at drug dealer. The −50% floor = the item's `lowest` price (idx8) = 50% of base (market floors there).
- Capacity = floor(house AP_vcap / 10). Sativa matures 2h (stage 2), Indica 3h (stage 3).

DEFERRED (folds into the processing-overhaul work):
- Bud → Wax / Golden-Wax PROCESSING recipe at the weed processor (Indica Bud → Golden Wax; Sativa → normal Wax).
- Normal "Wax" item for the Sativa line (needs a new virtual item).
- Cop-raid hook (spec'd, not built — design lever for later).

## Build order (MVP first, then layer)
1. Items + weights (2 seeds, Wax; re-weight products to 1) + `houses.greenhouse` DB column.
2. Greenhouse buy in house menu (extend existing `AP_greenhouse` upgrade) + 1-per-house gate.
3. Plant action (seed → greenhouse entry w/ planted_at) + capacity = vinv/10 gate.
4. Server growth/persistence: boot + login stage recompute from timestamps (rock-solid).
5. Harvest action (mature → product weight 1).
6. Processor recipes (Weed→Wax, HP→Golden Wax) + dealer sell + dynamic-market −50% floor.
7. Stub the raid hook.
