# Cyberdeck — Completed Work

Record of what is **built and deployed to DEV** on branch `doomba`, as of **2026-07-21**.

- Design spec + backlog: `docs/quickhacks-design.md` (tagged LIVE / PARTIAL / BACKLOG)
- MaxSec tool spec: `talos.md`
- Current-state snapshot: `docs/HANDOFF.md`
- PR: **#90** (`doomba` → `main`), open
- Session commits: `96acf37`, `427ee3f`, `ba21d77`, `c4d1df3`, `3d5014b`, `b181c57`

> **Nothing here has shipped to LIVE.** Everything is DEV-only. Items marked **UNTESTED** compiled
> and deployed cleanly but no human has exercised them in-game yet.

---

## 1. Quickhack core — LIVE, tested in-game

The Tier 1 system, verified working by the owner on dev 2026-07-21.

**Architecture.** Catalogue row (`core/config/fn_qhCfg.sqf`) → client cast
(`core/items/fn_qhCast.sqf`: cooldown, range, LOS, chip gate) → **server authority**
(`server/AP_server/core/TON/fn_qhSRV.sqf`: owns the upload clock, re-validates on completion,
applies the effect) → victim side (`core/items/fn_qhEffect.sqf`: effect + firewall mitigation +
arms the trace window). A modified client cannot skip the channel.

**Universal levers**

| Lever | State |
|---|---|
| Upload channel (server-timed, victim sees INTRUSION DETECTED + bar) | LIVE |
| Trace window — 10s to trace back the hacker; a live Proxy Chain reroutes it and burns | LIVE |
| Firewall slots — own many chips, equip exactly 2 | LIVE |
| Cop authorisation gating (`wanted` / `restrained` / `wantedArmed`) | LIVE |
| ICE Trace — single authority on whether a hack is quiet | LIVE |

**Tier 1 hacks**

| Civ | Cop counterpart | Counter chip |
|---|---|---|
| Ping.exe — position 10s, 60s CD | Pursuit Tag (wanted only) | Scrambler (feeds a false position 100–200m off) |
| Static Burst — 3s heavy static | Dazzle Protocol (wanted only) | Optic Filter (→1s light fuzz) |
| Whiteout — deafen 8s | Silence Cell (see §2) | Audio Limiter |
| Sticky Fingers — forced holster 3s | Safety Interlock (wanted + armed) | Hardened Firmware (immune) |
| Distract.exe — see §2 | PA Override | none, by design |

Ping's position is streamed **from the server** — that is what lets the Scrambler lie. Do not
"optimise" it into a client-side read.

**Also live:** Ghost Key (`unlock`), Killswitch (`ignition`), ATM Jackpot, Breach House, Hijack Rig
(`cryptoTakeover`), Wardrive, Turf/Market Sniffer, consumables (Proxy Chain, Breach Kit).

---

## 2. Built 2026-07-21 — UNTESTED

### Silence Cell — real comms mute
Replaced the placeholder (which just re-used Whiteout's deafen). Now a genuine outgoing-comms jam:
`AP_qhSilencedUntil` gates **every** send path — `fn_sendText` (all modes: DM, police, medic, gang)
and `fn_cellphone_call`. **60s**, or **20s** against an Audio Limiter.

Deliberate: the mute **outlives an unrestrain**. A suspect who wriggles free still can't call backup.
Voice/side chat can't be gated client-side — that stays an RP rule.

### Distract / PA Override — target selection + real audio
The caster's ring lock (`AP_cdTarget`) now picks the noise source:

- locked **vehicle** → car alarm *or* `hornBattle.ogg` at **that vehicle** (50/50)
- locked **player** → `phonering.ogg` at **them**, suppressed if their ringer is off
- **no lock** → alarm at the caster (old behaviour)

Bystanders no longer receive the INTRUSION DETECTED banner for area hacks — a distraction that
announces itself defeats its own purpose.

### Plate Ghost — new hack, new target kind
Ring-lock a vehicle **you hold keys to** → 5-minute registry spoof. Introduced a `"vehicle"`
targetKind wired through cfg → cast → ring → server, with a server-side keyholder check against
`AP_vehOwners`.

Against TAL Plate Scan a live ghost reads as either a **fake owner who is a clean keyholder**, or
**PLATE MISMATCH**. The 50% roll is **fixed at cast time** and stored with the ghost, so a cop
cannot spam-scan until it flips — one ghost, one verdict.

*Deviation from spec:* no separate "Deep ALPR scan" action. The roll rides the existing Plate Scan.
One wedge instead of two.
*Known, accepted:* the verdict sits in a public object var, so a modified client could read its own
outcome. Harden via a `talSRV` round-trip if it ever matters.

### Quickhack loot drops
`APS_fnc_qhLootSRV` — server-rolled, per-UID **per-source 5-minute throttle**.

| Source | Roll | Hook |
|---|---|---|
| Fed vault success | 2× Proxy Chain (guaranteed), Breach Kit 60%, chip 35% | `fn_openVault` |
| Cartel capture | Proxy 50%, Breach Kit 30%, chip 10% | `fn_captureCartel` |
| Rogue van | +1 Proxy always, Breach Kit 40%, chip 20% | `fn_eventRogueVanSRV` cart |

The van rides its existing crate — `loonazonBox` already sorts virtual classes into `AP_vinv` (Loonazon removed 2026-09-02; this row and `fn_eventRogueVanSRV` are historical).

### Ghost Plate Chip — rare installable
Drop-only item. **USE** installs the Plate Ghost quickhack **permanently** (id `201` in
`AP_cdMods`, persisted through the existing `cyberdeck_modules` column — **no migration**).
Plate Ghost is chip-gated: the wedge reads `CHIP NOT INSTALLED` until you loot one.

The gate is a new optional `reqMod` field on the catalogue row, enforced **client and server**.
Future drop-only hacks are one catalogue row plus one whitelist id.

### Killswitch rename
Owner's call: rename, don't build a remote-start. Wedge and toasts now read **Killswitch.dll** /
KILLSWITCH DEPLOYED. Internal id stays `"ignition"`, so icons, CfgRE and the server case are
untouched. Mechanics unchanged (~20s engine kill).

---

## 3. MaxSec counter-tools — built 2026-07-21, UNTESTED

All Captain+ (`copLevel >= 6`), all in `AP_ringPoolCop`. Built by extending `talAction` / `talSRV`
rather than adding functions — **no new registrations were needed**.

### Deck Jammer (`talAction 8` → `talSRV "jammer"`)
80m / 60s no-intrusion bubble, 180s cooldown. Park it on the Fed mid-heist.

`AP_deckJam` is **server-only state on purpose** — criminals discover the field by their cast
failing, not by seeing a marker. Enforced in **both** `APS_fnc_qhSRV` (quickhacks) and
`APS_fnc_cyberdeckSRV` (house breach / rig hijack / Killswitch / ATM Jackpot), so every civilian
hack path funnels through one check. Never jams the officers running it.

### Honeypot ATM (`talAction 9` → `talSRV "honeypot"`)
Rig the machine you're facing; it stays hot for an hour. The next ATM Jackpot against it fails
**one-shot**: the hacker still eats the full deck cooldown, gets a HONEYPOT toast, and MaxSec
receive a located `copalert` plus a map marker.

A **Proxy Chain does not suppress it** — the alert comes from the bank's own hardware, not from
tracing the intruder.

### Drone Uplink
Ring wedge onto the existing `AP_fnc_copUAV`. Its own Captain+/$10k gate is unchanged.

---

## 4. Skim Daemon rebalance — built 2026-07-21, UNTESTED

- Cut **10% → 3%** (spec band 2–4%) in `fn_bankDeposit` / `fn_bankWithdraw`, toast text included.
- **Silent alarm** rolls **server-side** in `atmSkimSRV "credit"`: 30% per skimmed transaction,
  throttled 120s per machine. MaxSec get a located alert; the planter gets a "SKIMMER EXPOSED"
  warning; **the victim is told nothing** — that is what makes it silent.

Still open: Asset Freeze, Bank ICE.

---

## 5. Bugs found and fixed along the way

| Bug | Impact | Fix |
|---|---|---|
| Five qh client fns never registered in `Functions.h` (`qhCast`, `qhEffect`, `qhTrace`, `qhTraceResult`, `qhPing`) | **All ten quickhacks dead client-side** — `Undefined variable AP_fnc_qhCast`. Deploy "succeeded" silently. | Registered all five |
| `fn_qhCast` validation used `exitWith` inside the kind branch | Only exited that block — a failed "no target" cast still fired **and burned the cooldown** | Collect the reason, `exitWith` at file scope |
| `APS_fnc_qhSRV` never checked `isPlayer` on player-kind targets | AI passed server validation | Added the check |
| Distract's ringer check read `AP_clientDefaultSettings` | Read the immutable **defaults array**, not the player's saved setting — muted phones still rang | Read `AP_isRingEnabled` |
| Kabuki Deck Skin (module id 4) | Sold for **$2M with no wired effect** | Removed from `AP_cdModules` + the server buy-whitelist |

**Two verified footguns worth remembering**

1. **Three registrations.** A new cross-machine fn needs `Functions.h` (client) or `config.cpp`
   (server) **plus** a `CfgRE.hpp` entry. Miss one and it fails **silently**. This was already
   documented in `CLAUDE.md` and it still bit — prose warnings decay, a lint rule would not.
2. **The client caches the mission PBO.** Disconnect + rejoin does **not** load a new build; the RPT
   says `Flushing file ... not possible - still open`. Players must **fully exit Arma to desktop**.
   This masked the registration fix as "still broken" for a full retest cycle.

---

## 6. Merge reconciliation (`427ee3f`)

`origin/main` had evolved the same cyberdeck files via PRs #87/#88 — 26 conflicted files.
Resolution policy: **doomba's firmware/module model wins** (`AP_fnc_hasDeck`, `AP_cdMods`,
Hacker talent tree removed, ABORT buttons removed, deck phone registry) over main's older
item/talent model.

**Main's fixes preserved:** `fn_miningSRV` TOCTOU hardening (`AP_rigBusy` lock, blocking anti-dupe
DB writes, owner-only collect), house furniture-hide during breach, rig insider-hack rejection,
and the locked-house gate on the rig hack scroll action.

---

## 7. Still open

**Owner decision needed**

- **Warrant Request** — the last unbuilt `talos.md` wedge. Deliberately **not** guessed. Needs an
  approval workflow *and* a ruling on what "lawful" changes mechanically: does a warranted breach
  skip the Cyber Crime charge? Skip the ICE trace? Is the homeowner still notified?

**Design/build backlog**

- Asset Freeze, Bank ICE (Skim Daemon's cop counters)
- PA Override's actual voice/text broadcast
- Tier 2+: Leech, Eye Spy (needs a CCTV network first — largest hidden cost)
- Tier 3/4 and the whole Autopilot Hijack Suite (see `docs/quickhacks-design.md`)

**Before anything ships to LIVE**

```sql
ALTER TABLE players ADD COLUMN IF NOT EXISTS cyberdeck_modules VARCHAR(255) NOT NULL DEFAULT '[]';
```

Applied to `looneybin_test` only. Without it **every live login errors on the column.**
Then: review and merge PR #90, and follow `update.md` for the live deploy.
