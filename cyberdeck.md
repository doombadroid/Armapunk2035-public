# CYBERDECK — Canonical Spec

*Owner-approved build spec. This is the source of truth. Renderings: Cyberdeck design artifact (device frame + Sequence Breach + Terminal Breach + fed pylon-disarm).*

Status: **greenlit — building**. Started 2026-07-18.

**Progress:**
- **Phase 1-2 DONE (dev).** Cyberdeck item (Rebel $10k, placeholder usb.paa icon), Hacker talent tree (Hackerman→Black ICE, 8 nodes), Hackerman spawn-grant, `AP_fnc_cyberdeck` launcher. **Sequence Breach** (vehicles) — owner-approved custom PAA art (deck bezel + radar-sweep flipbook + daemon), aspect-correct via UI_GRID units, wired into `fn_lockpick` `_useDeck` mode, car-alarm on trace-fail.
- **Phase 3a DONE (dev): Terminal Breach + house doors + crypto hack + charges.** `fn_cyberdeckTerm`/`fn_cyberdeckSubmit` + `cyberdeck_term.hpp` idd 941000 (cyan deck PAA `backdrop_term.paa`, feed/copybox/typed-edit/trace). House hack → root opens ALL doors 3 min; crypto rig "Hack Mining Rig" action (non-owner) → full takeover. `APS_fnc_cyberdeckSRV` cases `houseBreach` (relock 3min + owner toast + MaxSec alert, ALWAYS win/fail) + `cryptoTakeover` (reassign AP_rigOwner + hashmap + notify old owner). **Auto-charges (stackable, both mission+server copies): #111 "Breaking & Entering" $10k (every house attempt), #112 "Cyber Crime" $10k (every rig hack).** Black ICE talent (257) deleted. CfgRE whitelisted, config.cpp registered.
  - Phase-5 TODO (2-player): crypto collect-exclusivity — `miningSRV` collect still falls back to the house owner; hijack should lock old owner out. Also confirm rig hack visuals/takeover with a 2nd player.
- **ART PIPELINE:** `scratchpad/build_cyberdeck_art.py` — SVG→rsvg→PNG→`tools/make_paa.py`→PAA + emits both dialog hpps. Palette `#c9e21a` acid / `#33ffbb` cyan. Regenerate hpp+art together. Native flipbook animation (no A3AnimatePAA — keeps CfgRE locked).
- NOTE: vehicle + house hacks are client-side minigames (parity w/ legacy lockpick/boltcutter); the server SRV handles only relock+notify. Fed/bank (Phase 4) get server-authoritative validation.
- **Fed-dome inner SAFE crack** (`fn_openSafe`, "Crack Safe" action) → **Sequence Breach diff 2 (6-slot)** (owner 2026-07-18: "car hacking menu, 6 chars not 4"). Demo-charge path (talent 43) unchanged. Gated on `AP_inv_cyberdeck`.
- **Phase 4a DONE (dev): FED pylon-disarm.** `fn_openVault` reworked — scroll "Break Into Dome" now gates on `AP_inv_cyberdeck` (setupActions:4050). Flow: Terminal Breach (9 cmds, diff 3) → MaxSec alarm at root (`APS_fnc_fedRobbery`, Ghost Protocol delays 30s) → 2:00 pylon-disarm hold at the panel (stay in range; Overclock → 96s) → existing unlock + `APS_fnc_fedGoldSpawn`. Fail (trace/leave range) → `AP_fedHackCooldown` 2-min (Cooldown Bypass → 60s). Old 10s-delayed alarm removed (alarm now at start = cops get the disarm window).
- **Phase 4b DONE (dev): BANK vault.** Scroll "Hack Bank Vault" (setupActions:4551, gate → `AP_inv_cyberdeck`) → Terminal Breach (6 cmds, diff 2) → on root, existing `APS_fnc_bankRobbery`; server drill loop shortened 900s→**120s** (the minigame is the crack, loop is now the 2-min hold/cop-response window — MaxTac/dispatch/alarm/Disable-Drill all reused). Cop gate still server-authoritative (4 cops OR AP_betaZeroCops).
- **DEV NOTE:** `server_control.fedoverride=1` set in dev DB `looneybin_test` (docker `looneybin-db`) → AP_betaZeroCops on boot = solo fed/bank testing without cops. Owner can also toggle live via phone → Admin → Fed Control. (Live server: leave OFF / owner-controlled.)
- **Icon DONE:** `icons/cyberdeck.paa` = #5 "glyph" (big `>_`; owner swapped from #4). Generator `scratchpad/cyberdeck_icons.py`.
- **Fed-dome SAFE crack** = Sequence Breach diff 2 (6-slot). **Mental Asylum laptops** (`fn_loonyBin` uploadLaptopVirusHack) = Sequence Breach **diff 3 (10-slot)**; gate now `AP_inv_cyberdeck` (was USB). Sequence Breach dialog extended to 10 buffer+injected cells.
- **RETIRED (owner 2026-07-18): lockpick, drill, usb (Trojan USB) items** — removed from catalog + all shops + `.paa` icons deleted. Refs repointed to `AP_inv_cyberdeck`: `fn_lockpick` gate (deck/boltcut only), setupActions "Lockpick Handcuffs" + "Pick Vehicle Lock" (now `_useDeck`), `fn_jewelryEmporium` drill gate, `fn_openVault`/`fn_openSafe`/bank action, asylum laptop gate. LIVE MIGRATION TODO: strip lockpick/drill/usb from existing player virtual inventories (DB) before live deploy.
- **Bank robbery bar** cyan (`fn_handleMessage` bank_robbery `_color`); **z-order fix in `fn_createMessage`** (dark track was built AFTER the progress bar, covering it → "cyan flash then dark"). Now track first, bar on top = all message bars render their colour.
- Next: **crypto collect-exclusivity** (2-player); wire Root Kit 255 talent; live DB migration; PR + deploy.

---

## Concept

One Y-inventory item, the **Cyberdeck**, retires the **lockpick** and the **drill**. Aiming it at a target opens a hacking minigame; success runs the target's existing unlock/open path; failure notifies the target's owner (see penalties). A dedicated **Hacker talent tree** grants the deck on spawn and improves it.

**Two minigames, chosen by target:**
- **Sequence Breach** — acid-green "match the buffer" letter game. Light targets (vehicles).
- **Terminal Breach** — cyan Linux "copy the commands fast" game. Heavy targets (fed, bank, house doors, crypto miners).

---

## OWNER DECISIONS (locked)

1. **Fail penalty = notify the target's owner** (not deck loss):
   - **House** → toast notification to the house owner.
   - **Vehicle** → the car alarm goes off.
   - **Fed** → 2-minute cooldown before you can attempt again.
   - (Bank / crypto: follow the same spirit — see §Targets.)
2. **Fed pylon disarm = must stay in range** the full 2:00. Leave range → uplink drops.
3. **Crypto miner hack = FULL TAKEOVER** (ownership of the placed rig transfers to the hacker).
4. **Cop counter-hack duel = V2** (not this build).
5. **Deck acquisition:**
   - Sold in the **Rebel market** for **$10,000**.
   - A **new talent tree** whose first node **"Hackerman"** grants a Cyberdeck **on spawn**.
   - Later nodes down that tree improve ease of use (timers, shorter puzzles, delayed traces, etc.).

---

## The item

| | |
|---|---|
| Class | `cyberdeck` virtual item (`AP_inv_cyberdeck`), PAA icon |
| Buy | Rebel market, **$10,000** |
| Grant | Hackerman talent → 1 on spawn |
| Replaces | `lockpick` + `drill`. Old classes retained/deprecated; new content routes to the deck |
| Consumed | No (tool). Fail cost = owner-notify per target, not item loss |
| Use | Y menu "use" → `AP_fnc_cyberdeck` routes by target (cursorObject / nearest) |

---

## Minigame 1 — Sequence Breach (vehicles)

Match a target buffer sequence by picking letters from a grid before the timer drains.

- Server rolls sequence (length `L`) + grid; **server owns the answer** (validate picks server-side).
- One active row highlighted; click the letter matching the next buffer slot.
- Correct → advance. Wrong → time penalty + row reshuffle.
- Clear before `T`s → success.

Scaling: civ car `L`3-4 / `T`20s; armored/cop `L`6-8 / `T`10s. Talents shorten `L`, add time.

**Fail → car alarm sounds** (alerts nearby, pings owner). No cooldown on vehicles.

---

## Minigame 2 — Terminal Breach (heavy)

Copy a chain of Linux commands exactly + fast before the trace lands.

- Server generates `N` commands from a themed pool (`nmap`, `nc -zv`, `traceroute`, `hydra`, `sudo mount`…), holds expected strings.
- Next command shown in a highlighted box; player types it → Enter → server validates (exact, authoritative) → next drops.
- Typos cost time; trace bar drains.
- Complete all `N` before trace → root → target success path.

Scaling: house `N`3 / retries 2; bank `N`6 / retry 1; fed `N`8-10 / retry 0.

---

## Target integration

| Target | Game | Hook (real fn) | Success | Fail penalty |
|---|---|---|---|---|
| **Vehicle** | Sequence Breach | `core/items/fn_lockpick.sqf` (`AP_inv_lockpick`→`AP_inv_cyberdeck`) | unlock veh (existing) | **car alarm** |
| **Fed door** | Terminal Breach → Pylon Disarm | `core/actions/fn_openVault.sqf` (drop `AP_inv_drill` gate + 105s loop; keep `AP_vaultlocked`, `AP_fed_robbed`) | disarm → `AP_vaultlocked`→0 + door anim + `APS_fnc_fedGoldSpawn` | **2-min cooldown** before retry |
| **Bank vault** | Terminal Breach | `server/.../fn_bankDrillVault.sqf` (deck-hack = the drill) | existing `_success` payout (cash + rig component) | 2-min cooldown (match fed) |
| **House door** | Terminal Breach (short) | house break-in / keyholder gate (`fn_setupActions`, `fn_lockHouse`) | temporary unlock / entry | **toast to house owner** |
| **Crypto miner** | Terminal Breach (short) | scroll on placed rig (`AP_cryptoRig`, `APS_fnc_miningSRV`), non-owner option | **FULL TAKEOVER**: rig ownership → hacker (update `AP_rigOwner` + `houses.owners`/DB) | toast to rig owner ("someone hacked your rig") |

**Principle:** minigame = front-end gate. On server-side success, run the *exact* existing success path. Don't re-plumb payouts.

---

## Fed pylon-disarm flow

1. Aim deck at fed dome side-door → Terminal Breach (`N`8-10).
2. Root → screen: **"HACK UPLOADED — PYLONS DISARMING"** + **2:00 progress bar**.
3. **Must stay in range** the full hold. Leave → uplink drops (progress lost). MaxSec alerted at hack start (`APS_fnc_createDispatch` + fed alarm).
4. 2:00 → door opens: `AP_vaultlocked`→0 + door anim + `APS_fnc_fedGoldSpawn` (unchanged).
5. Server-authoritative timer + range check. Client bar cosmetic.
6. Fail (trace lands / leave range) → 2-min cooldown before re-attempt.

---

## Talent tree — "Hacker"

New tree in `fn_talentCfg.sqf` (format `[id, side, prereqId, tier, "Name", "Desc"]`). Civilian side.

| Tier | Name | Effect |
|---|---|---|
| 0 | **Hackerman** | Root node. Grants 1 Cyberdeck on spawn. +2s on every timer. |
| 1 | **Cache Injection** | Sequence Breach buffer 1 slot shorter. |
| 1 | **Autocomplete** | Terminal Breach: first char of each command pre-typed. |
| 2 | **Cooldown Bypass** | Fed/bank fail cooldown halved. |
| 2 | **Ghost Protocol** | Fed/bank MaxSec alert delayed 30s. |
| 3 | **Root Kit** | One command auto-solves per Terminal Breach. |
| 3 | **Overclock** | −20% all disarm/hold timers (incl. 2-min pylon hold). |

*(Black ICE capstone DELETED per owner 2026-07-18 — B&E/Cyber Crime are always charged + always notify, so a "silent" node contradicts.)*

Gate upper tiers behind existing infamy/rebel prereqs. Talent-point system already exists.

---

## Countermeasures (this build)

- **Owner notify on fail** (per target, above) — the core deterrent.
- **Fed/bank 2-min cooldown** on fail.
- **Stay-in-range** requirement on the 2-min fed hold.
- **MaxSec dispatch** ping on fed/bank hack start (delayable via Ghost Protocol).
- **Crypto takeover** alerts the previous owner.
- **V2 (deferred):** cop counter-hack duel at the fed during the 2-min hold.

**Anti-cheat (non-negotiable):** puzzle answer + timer + success flag are **server-owned**. Client dialog = renderer + input only. Server validates every pick/line + the deadline + range. No `AP_inv_*` self-grant, no trusted client "I won" flag. remoteExec via mode-1 CfgRE allowlist.

---

## Architecture

- **Client:** dialogs `cyberdeck_seq` + `cyberdeck_term` (add to `MasterHandler.h` — mind the all-dialogs-in-one-include footgun); launcher `AP_fnc_cyberdeck` routes by target; rendering + input only.
- **Server:** `APS_fnc_cyberdeckSRV` — generate puzzle, hold answer/timer, validate progress, fire target success. One SRV, cases per target (mirrors `miningSRV`).
- **Config:** `fn_cyberdeckCfg` — puzzle pools + per-target difficulty. Talent hooks read `AP_side_talents` / infamy.
- **PAA:** one bezel frame + item icon (make_paa). Screen = dialog controls, not baked art.

---

## Build phases (ship to dev incrementally)

1. **Item + Hackerman talent + launcher** — `cyberdeck` item, rebel $10k, on-spawn grant, Y-use dispatch, stub dialogs.
2. **Sequence Breach** — dialog + `cyberdeckSRV` puzzle/validate; wire `fn_lockpick`; car-alarm fail. **← first testable slice.**
3. **Terminal Breach** — dialog + command-chain validate; wire bank vault first (lowest-risk heavy).
4. **Fed door + Pylon Disarm** — 2-min in-range hold + door open + cooldown.
5. **House doors** (toast fail) **+ crypto full-takeover.**
6. **Talent effects** — wire the 8 nodes.
7. **Countermeasure polish** — dispatch delay, cooldowns.
8. Retire lockpick/drill from shops.

---

## Open / V2

- Cop counter-hack duel at fed (V2).
- Do old lockpick/drill get removed from existing inventories on launch, or just stop being sold? (default: stop selling, leave existing.)
