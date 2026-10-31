# Detonate — Tier 4 apex quickhack

Owner spec, 2026-08-03. Built and deployed to dev the same day as `Armapunk2035_b0249`; untested in
game at time of writing.

## What it is

A drop-only Tier 4 quickhack that destroys a targeted vehicle and everyone inside it. It is the
**only lethal quickhack in the catalogue**, which is why almost every design decision below differs
from the rest of the tier.

| | |
|---|---|
| id / chip | `detonate` / 220 (`detonatechip`) |
| upload | 4s standard channel |
| fuse | further 3s ARMED |
| range | 20m |
| cooldown | 7200s (2h), server-owned and persisted |
| target kind | `anyveh` — Car, Air, Ship, Tank |
| counter chip | none — the counter is positional |
| drop | 0.25 weight on the Fed roll, ~1 per 400 completed Feds |

## Decisions and why

**Occupants die.** Not an empty-vehicle sabotage tool and not a warning shot. A cast that completes
kills the crew, the same as a speedbomb detonating under them.

**The fuse is the counterplay.** The upload runs as normal, then the cell is ARMED for 3 more
seconds. Through those 3 seconds the server re-checks every 0.25s that the hacker is alive, within
20m, and still has line of sight. Break any of the three and the charge fizzles. This is why the
catalogue row has an empty `counterChip`: the counter is positional and available to everyone —
shoot the hacker, break line of sight, or drive out of 20m — rather than an item you had to be
carrying beforehand. A fizzle still costs the full cooldown.

**Two limits emerge from the numbers rather than from rules.** Range is 20m and the blast radius is
10m, so casting close kills the caster too — a real risk/reward dial that needed no extra mechanic.
And while a helicopter is a legal target, holding 20m *and* line of sight on one for three seconds
means in practice it must be landed or hovering low. The range limit is what keeps this off aircraft;
no aircraft exclusion was needed.

**The explosion is the speedbomb's.** `Bo_Mk82` at the vehicle's `getPosATL`, then `setDamage 1` on
Car/Truck/Air/Ship within 10m. It reads identically to anyone who has seen a speedbomb go off. The
difference is that this one runs server-side; `fn_speedbomb.sqf` runs its whole detonation on the
planter's client, which the standing rule ("server owns anything that pays, punishes or times") says
it should not.

**Charge 2, Explosive Terrorism**, scaled by body count — the charge speedbomb already applies for
the same act. The crew list is captured *before* the blast, because after `setDamage` they are dead
men and `crew` no longer reports who was killed.

## The cooldown is the one real piece of new infrastructure

Every other quickhack keys its cooldown off `diag_tickTime` in the **client's** `missionNamespace`
(`fn_qhCast`), and `fn_qhSRV` never checks it. That means a relog clears it and a modified client
never had it. Tolerable for an 18-minute non-lethal hack; not tolerable for a 2-hour gate on the one
hack that kills people — a cooldown a relog clears is not a cooldown.

So Detonate is gated server-side against `players.qh_detonate_cd` (`sql/qh_cooldowns.sql`).

**The database owns the clock.** The server writes `DATE_ADD(NOW(), INTERVAL 7200 SECOND)` and reads
`TIMESTAMPDIFF(SECOND, NOW(), qh_detonate_cd)`. There is no epoch arithmetic in SQF — Arma has no
clean epoch and `serverTime` resets every restart — and because both sides of every comparison come
from the same `NOW()`, the box/DB timezone split (box America/Chicago, DB UTC) cannot skew it.

**The stamp is written before the fuse runs**, so disconnecting mid-fuse does not dodge the cost.

**The result read accepts both extDB3 shapes.** The two precedents in this codebase disagree about
what a mode-2 scalar `SELECT` returns — `fn_queryRequest` destructures `_r select 0` as a row,
`fn_gangBHistory` reads the same expression as a scalar. Guessing wrong fails *open*: the read yields
0, the gate never trips, and the cooldown silently does nothing while appearing to work. Both shapes
are unwrapped rather than trusting either precedent.

One column for one hack, deliberately. If a second hack ever needs a real cooldown, generalise into a
`qh_cooldowns(playerid, hackid, expires_at)` table rather than adding a second column.

## Drop

`detonatechip` at weight **0.25** on the Fed guaranteed-chip roll — three times rarer than
`chauffeurchip` and `puppetchip` at 0.75, roughly one per 400 completed Feds. The weight came out of
the T3 block (`valetchip` 6.5 → 6.25) so the table still sums to exactly 100, which is verified
arithmetically rather than assumed.

Absent from the cartel table on purpose: cartels are farmed far harder than Feds, and this is the
only lethal hack.

## Deliberately not done

**No stat call.** `fn_statArrUpdate` maps slots up to 147, while `fn_titleCfg` seeds
`APV_statTotals` with `for "_i" from 0 to 144` — 145 slots. Three already-mapped stats therefore
write past the end of the array. That is a live lead on the open stat/title corruption bug and not a
foundation to build on. The `-DETONATE-` log is the audit trail until the bound and the slot map
agree.

## Files touched

| File | Change |
|---|---|
| `core/config/fn_qhCfg.sqf` | catalogue row |
| `core/configuration.sqf` | `AP_chipItemMap` 220, `AP_ringPool` entry |
| `core/config/fn_virtItemCfg.sqf` | `detonatechip` item, never sold |
| `TON/fn_qhSRV.sqf` | cooldown gate + the `detonate` case |
| `TON/fn_qhLootSRV.sqf` | loot weight + T3 rebalance |
| `sql/qh_cooldowns.sql` | `qh_detonate_cd` migration |
| `scratchpad/render_ring_icons.py` | `qh_detonate` glyph |

No new functions, so no `Functions.h` / `config.cpp` / `CfgRE.hpp` registrations were needed — the
five remoteExec'd functions used are all already whitelisted at `allowedTargets = 1`. This was
checked rather than assumed, because the three-registration footgun has bitten this codebase twice.

## Test plan

Needs two players; most of it only manifests on the victim's client.

1. Chip gate — without chip 220 installed, Detonate is absent from the loadout pool and a forged cast
   is refused server-side.
2. Empty vehicle — cast, hold the link, confirm detonation and the `-DETONATE-` log naming "nobody".
3. Occupied vehicle — confirm the crew get DEVICE ARMED, that bailing inside 3s saves them, and that
   staying does not.
4. Each of the three fizzle paths — walk past 20m, break line of sight, and have the hacker killed
   mid-fuse. Each should fizzle, log, and still burn the cooldown.
5. Cooldown — cast, confirm refusal with minutes remaining, **relog and confirm it is still refused**
   (this is the whole point of the DB column), then confirm it survives a server restart.
6. Charge — confirm Explosive Terrorism lands and scales with the number killed.
7. Self-damage — cast at ~8m and confirm the caster dies too.
