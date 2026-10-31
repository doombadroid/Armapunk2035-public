# Jewelry Emporium heist — redesign Q&A (un-deferred, owner wants it FIXED)

Half-built feature. Need owner design intent before implementing. Blockers found (2026-06-16):

- **#306 safe:** `fn_jewelryEmporiumSRV` `weldSafe` case ONLY sets state slot 3 (`safeWelded`) true — it NEVER
  swaps the closed safe (`AP_jewerlySafe`) for the open `Fridge_01_open_F` that the client `takeSafeContents`
  action targets, and never spawns the safe loot. So the safe can never be looted. (Compare `createCase`, which
  correctly spawns a `Land_Trophy_01_gold_F` on each smashed case.)
- **#306 "Qilin":** there is NO Qilin / reward-vehicle spawn ANYWHERE in the jewelry code. Reporter (player071)
  expected: "after finishing all basic reqs the qullin didn't spawn in with any of the goods" — i.e. a Qilin
  loaded with the loot should appear on completion. Not built.
- **#304 sequence:** `robberyStarted` sets slot 2 (`safeDrilled`) true the instant the event goes active, so
  case-break + safe-weld unlock together — no enforced drill→cases→safe order.
- **#303 back gate:** emporium back gate has no blocking collision (vehicles drive through). Near [20720,16620].

## OPEN QUESTIONS for owner (was mid-ask when interrupted by the live ebola dupe):

1. **Reward (#306):** loaded Qilin spawns on finish? / carry bags to container+dealer (no Qilin)? / Qilin =
   empty getaway you load yourself?
2. **Safe loot (#306):** open safe + 1 high-value bag? / open safe + several bags? / gold bars or cash?
3. **Sequence (#304):** cases first then safe unlocks? / keep simultaneous (mark by-design)? / staged multi-drill?
4. **Back gate (#303):** script invisible barrier now (b0070, no map edit)? / Eden map edit next batch? /
   block vehicles only (walk-through ok)?

Files: client `mission/.../core/actions/fn_jewelryEmporium.sqf`, server `server/.../core/TON/fn_jewelryEmporiumSRV.sqf`.
