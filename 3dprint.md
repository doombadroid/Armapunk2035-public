# 3D Printing — Pending Weapon Re-Adds

Weapons pulled from shops to be re-introduced as **3D-printable** items once the 3D printing
feature ships. Until then they are NOT purchasable anywhere on the civ/rebel side.

## Removed from REBEL armory (2026-06-13, owner)

Implemented as a rebel-only filter in `mission/LooneyBin.Altis/core/config/fn_weaponShopCfg.sqf`
(`_plb3dPrint` prefix list, right before the price-override loop). MaxSec keeps its own access.

| Weapon | Classname prefix | Notes |
|--------|------------------|-------|
| MAR-10 (.338) | `srifle_DMR_02_` | `srifle_DMR_02_F`, `_camo_F`, `_sniper_F`. MaxSec still gets it at rank 5 (LT). |
| SPMG (.338 MG) | `MMG_02_` | `MMG_02_F`, `_black_F`, `_camo_F`, `_sand_F`. Not a MaxSec gun. |

### To re-add when 3D printing is in
1. Remove the matching prefix(es) from `_plb3dPrint` in `fn_weaponShopCfg.sqf` (un-gates the rebel shop), OR
2. Better: wire them into the 3D-printer recipe table instead of the cash shop, and leave the
   `_plb3dPrint` filter in place so they can't be bought outright.

---

## Also removed 2026-06-13 (NOT a 3D-print re-add — just cut)
- **Full Titan AA** (`launch_*_Titan_F`, non-compact) — dropped from the rebel launcher catalog
  (`fn_weaponShopCfg.sqf` case 4). Only the **Titan Compact** (`launch_*_Titan_short_F`) sells now,
  @ $70,000; compact ammo (`Titan_AT` / `Titan_AP`) @ $190,000 via `fn_weaponAddons.sqf`.
