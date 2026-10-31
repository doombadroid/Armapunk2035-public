# CLANKR — LooneyBin Anti-Cheat / Audit System (design notes)

> Status: DISCUSSION / not built. Captured 2026-06-06. Goal: flag duping + admin abuse
> from RPT logs + DB state. Review + decide scope before building.

## Core principle

Duping and admin abuse are **data/anomaly problems, not language problems.**
- **Deterministic rules + SQL = the detection engine.** Cheap, auditable, runs every minute, no hallucination. "Bank 50k → 5M in 2 min with no matching income event" is a query, not a prompt.
- **LLM = the garnish, on top.** Triage, cross-source correlation, plain-English reports, narrating anomalies that match no rule yet. Never the primary detector.

Build in that order. ~80% of the value is the rule engine on well-logged data; ~20% is LLM triage.

## Prerequisite (the real work)

Conservation-based dupe detection needs **every economy mutation logged** with a reason +
balance-after: `[uid, ±Δ, "drug_sale", new_balance, time]`. If grants aren't all logged,
deltas can't be explained → false-positive swamp.

- Already have `APS_fnc_logIt` (`-KILLED-`, `-ADMINACTION-`, `-VEHCLAIM-`, some money).
- **First step = audit pass:** instrument every credit/debit/item-spawn/trunk-write/trade to
  emit a structured audit line. ~1 day of SQF. Worth more than any model.

## Architecture

```
RPT tail + periodic DB snapshots
   → parse into structured `audit` events (own table: SQLite or MariaDB)
   → RULE engine (deterministic flags + evidence bundle)
   → LLM triage layer (rank / cluster / explain)
   → loonybot → private #audit Discord channel
   → human reviews. NEVER auto-punish on LLM output.
```

Fits as a **loonybot module** — loonybot already bridges Discord + the server.

## Detectors (deterministic — no LLM)

**Dupe**
- **Net-worth conservation** — snapshot `bank+cash+inv_value+veh_value+house+gangfund` per
  player over time; flag Δ that logged income can't explain. The gold standard.
- **Known Altis vectors** — relog/crash mid-transaction (trunk↔inventory desync), drop-pickup
  race w/ 2 clients, vehicle-sell-during-relog, simultaneous bank withdrawals. Each has a log
  signature.
- **Rate caps** — > X money/min, item-count jumps.

**Admin abuse**
- `ga_aMode` / `adminLevel ≥ 3` actions correlated with wealth gain.
- Admin position-jump (teleport) → nearby player dies / loses money.
- Admin-mode kills outside admin events.
- Off-hours admin DB writes.

## LLM role (the narrow slice it's good at)

1. **Triage** — 800 raw flags → "the 5 that matter and why," ranked.
2. **Fuzzy cross-source correlation** — link log + DB + chat events rigid rules miss.
3. **Narrate no-rule-yet anomalies** — the new dupe method before a detector exists. Real value.
4. **Readable Discord reports.**

Model choice: a local 7–14B (Ollama Qwen2.5 / Llama3.1) is weak at numeric + long-context log
parsing — only feed it **pre-digested, small, structured candidate bundles.** Honestly, a
**Haiku API call on the daily flag bundle** is cheaper to build + smarter; scrub UIDs first.
Local only if zero data egress is required (closed beta w/ trusted admins = lower stakes).

## Hard rules

- LLM output is **advisory only.** False positives + hallucination → it suggests, a human bans.
- Pre-filter logs to candidates with grep/rules BEFORE any model sees them (RPT files are MB-scale).
- Defense in depth: keep conservation checks even after prevention work (see DB write-through discussion).

## Open decisions

1. How complete is economy logging now? (audit `APS_fnc_logIt` coverage vs gaps — the prerequisite)
2. Dupe-only first, or admin-abuse too? (different log sources)
3. Triage layer: local model or Haiku API?

## Dupe-critical operations map (codebase audit, 2026-06-06)

**Persistence architecture**
- Single serialized DB chokepoint: `DB_fnc_asyncQuery`, global `DB_Async_Active` mutex (one query at
  a time). Mode 1 = fire-and-forget UPDATE/INSERT/DELETE. Mode 2 = blocking-spin for result.
- **Nothing uses DB transactions.** Every write is a single atomic statement. No BEGIN/COMMIT anywhere.
  (extDB3's pooled async makes multi-statement transactions unreliable — would need single-statement
  tricks or stored procs.)
- Two save paths:
  - `updatePartial` — **immediate**, per-field: cash(0), bankacc(1), gear(3), position(10), cash+bank(6)…
  - `update` → `AP_update_buffer` → flushed **every 420s (7 min)** or on disconnect — full row, **lazy**.
- Dupe mechanism here is **temporal, not transactional**: source state (player inv, in the gear blob)
  persists lazily; dest state (trunk/storage) is server-RAM-authoritative and survives a player relog.
  Relog before the inv decrement hits the DB → inv reloads stale (still has the item) while the trunk
  still has it → **item in both = dupe**.

**Operation status**

| Operation | Source→Dest | Persist pattern | Atomic | Dupe/loss risk | Status |
|-----------|-------------|-----------------|--------|----------------|--------|
| Store to trunk/storage (`storeInventory`→`handleInv`) | inv→container | inv lazy / container RAM | no | **HIGH dupe** (≤7min window) | **FIXED** — write-through |
| Take from trunk/storage (`takeInventory`→`handleInv`) | container→inv | container RAM / inv lazy | no | item **loss** on relog | **FIXED** — write-through |
| Drop to ground (`dropPlayerInventory`→`handleInv`) | inv→world | inv lazy | no | dupe | **FIXED** — write-through |
| ATM cash↔bank | cash↔bank | `updatePartial` mode 6 (one stmt) | **yes** | low | OK as-is |
| Player→player cash (`giveMoney`) | A.cash→B.cash | both sides write-through (`[0]`) | n/a | low | SAFE (already) |
| Wire transfer | bank→bank | receive server-gated (`remoteExecutedOwner==2`) + `[1]` | n/a | low | SAFE receive · SEND handler not located |
| Player↔gang fund (+ gov treasury) | player↔gangs row | REPAIRED `APS_fnc_gangBank` router (modes 0/1/2/4) + client receive; balance-gated, atomic (no suspend pts) | race-proof | — | **FIXED** |
| **Vehicle sell** | deleteVehicle + credit | server-side; now 5s in-flight lock + row-exists gate (fail-open) | idempotent | — | **FIXED** |
| Buy / sell-to-shop (item+money) | cash↔inv | inv write-through + debounce now syncs cash+bank `[6]` | — | — | **FIXED** |
| Vehicle buy | debit + insertVehicle | separate | no | low (insert single stmt) | low-pri |
| Vehicle claim (chop, bug #44) | pid swap | single UPDATE | **yes** | low | OK (fixed earlier) |

**Implemented (2026-06-06)**
- **Inventory write-through** in `AP_fnc_handleInv`: on any real inv change, debounced ~2s, runs the
  canonical `[true] call AP_fnc_saveGear` (rebuild gear from `AP_inv_*` + `ClupdatePartial[3]`) AND
  `ClupdatePartial[6]` (cash+bank). Closes the inv↔trunk/storage/drop dupe class AND the buy/sell-item
  money dupe (paired ops persist together). Window 7min → ~2s. Session-gated.
- **Vehicle sell idempotency** (`APS_fnc_srvSellVehicle`): per-(uid,plate) 5s in-flight lock + row-exists
  pre-check (both fail-open) so a double-fire can't credit the sale price twice.
- **Gang/gov bank repaired** (`APS_fnc_gangBank` router + `AP_fnc_gangBank` receive): was a no-op stub
  (UI hung on "Loading...", moved no money). Now handles query/deposit/withdraw/income/transfer; the
  withdraw is **balance-gated and atomic** (the fn has no suspend point, so concurrent withdraws can't
  interleave -> no double-spend), and an over-cap deposit refunds the optimistic client-side debit.
- Verified already-safe: `giveMoney` (debit write-throughs `[0]`), wire-receive (server-gated + `[1]`).

**Still open / deferred**
- **Wire-transfer SEND handler not located** — receive side is safe; confirm the sender debits+write-throughs.
- Gov treasury shares `APS_fnc_gangBank`; works IF the gov "gang" is cached in `AP_server_gangs`
  (else the router replies 0 safely). Verify, or give the treasury its own source later.
- Backstop everything with CLANKR conservation detection.

## In-game anti-cheat signal (DONG / `APS_fnc_dongClient`) — was WAC

The client ships a lightweight in-game AC, **DONG** (renamed from WAC, owner 2026-06-23 — SpyGlass removed
same day). Client tripwires report tamper events to `APS_fnc_dongClient` (server) as
`[player, [code, var, val]]`; the server runs an illegal-gear scan (`APS_fnc_checkHacks`) and logs a
**`-DONG-`** row. **Advisory log only — no auto-action.** Codes are now LABELLED in `fn_dongClient.sqf`
(owner 2026-06-23 #3) → a row reads `[50] MAIN_RE cheat-menu signature | var=… val=…`. CLANKR matches
both `-DONG-` and `-WAC-` (transition: live b0091 still logs `-WAC-` until the rename PBO deploys).

### Code map (confidence / false-positive risk)
| code | label | conf | FP risk |
|---|---|---|---|
| 1  | filePatching enabled (modified client) | HIGH | low (devs/curious) |
| 3  | inventory item-count hack | MED | **HIGH** (known FP — BUGS #79/#80 @130 items) |
| 50 | MAIN_RE cheat-menu signature | HIGH | MED (stale sig persists; client-side = bypassable) |
| 51 | admin-level changed mid-session | **VERY HIGH** | low (unless a live admin-grant) |
| 52 | malicious scroll-menu action (Teleport/Kill/ESP/Spawn…) | HIGH | low-MED (a legit "Spawn …" label?) |
| 55 | admin-state vars tampered | MED-HIGH | low |
| 56 | admin display open while non-admin | HIGH | low |
| 60 | spoofed client message (illegal handleMessage RE) | MED | MED |
| 61/62 | illegal shop/cartel access | MED | MED (edge cases) |
| 63/64/65 | netSetVar illegal var broadcast | MED-HIGH | low-MED |
| 69 | explosion near player (explosive/VDM) | LOW | **HIGH** (legit combat) |
| 70 | ticket-value tamper | MED | MED |
| 71 | playtime-stat tamper | LOW | MED |
| 75–78 | money-receive anomaly | LOW-MED | **HIGH** (legit big txns / comps) |

60, 64/65 and 76–78 are filed by the RECEIVER of another client's remoteExec, so the row's subject is the
victim (the sender's owner id is only in var/val, as the receiver reports it). 53/55 can be forced the same
way: any client can set a public `AP_invisOn` on another unit and the victim's 5 s tripwire files it. clankr
keeps all of them out of the watchdog burst (2026-09-26); never wire an action to the subject of these codes.

### DRAFT action plan (owner review — NOT yet wired)
Tier per code, applied AFTER a watch window confirms the FP rate:
- **LOG only** (noisy / leads only): 3, 69, 71, 75–78, 60, 61/62.
- **PING owner+admins** (verify, then decide): 1, 50, 55, 63/64/65, 70.
- **KICK → BAN** (high-confidence, low-FP): 51, 52, 56. (50 → BAN once baselined.)

**Prerequisites before ANY auto-action (load-bearing):**
1. **Anti-frame — CRITICAL.** `fn_dongClient` trusts the passed `_player` object → a client can remoteExec
   a report carrying a *victim's* object → frame them → auto-ban becomes a griefing weapon. MUST derive the
   reporter from `remoteExecutedOwner` (ignore the passed object) FIRST. Also fixes current log-attribution
   spoofing. (Same class as the §2 audit's "trust the passed object" bug.)
2. **Baseline `MAIN_RE`** on a clean client so code 50 isn't noisy.
3. **Watch window:** run labeled LOG-ONLY a few days, measure per-code FP, then flip the KICK/BAN tier.
4. **Where action lives:** in **CLANKR** (Python), NOT the SQF sink — CLANKR already has the bans table +
   BattleMetrics mirror + per-pid cooldowns, and can correlate `-DONG-` (client tripwire = a lead) with
   `-SEC-` (server-side blocked exploit = near-certain) + `-FNCALL-` bursts. `-DONG- 50` + a `-SEC-` block
   on the same pid = auto-ban-grade.

This is the **client-side** layer (bypassable); pair with server-side `-SEC-` / conservation detectors + BE.

## Related

- CLANKR = **detection/backstop**; the inventory write-through above = **prevention**. Layer both.
- Disconnect/reconnect-in-place (position capture in `fn_playerDisconnected`, mode-10 save) shipped the
  same day — same "harvest server RAM at the right moment" principle.
