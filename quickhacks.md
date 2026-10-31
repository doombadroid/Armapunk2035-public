# Quickhacks — swappable modules + random drops

Backlog spec (owner 2026-07-20, "address later"). Companion to `cyberdeck.md` / `cdfeatures.md`.
Everything below reuses an EXISTING system — the hook column is the code that already does the work.

Current ring (built, live on dev): Wardrive / Unlock / Ignition / ATM / House / Rig / Proxy / Breach Kit.
Bound SHIFT+Y. **Ungated as of 2026-09-05** -- the VR-goggles hardware check and the illegal-firmware
flash are both gone; the ring is side-gated only (civ ring / TAL OS ring). See `core/items/fn_cyberdeckRing.sqf`.

---

## Framework

**Slots.** Ring is 8 wedges. Lock **3 core** (Wardrive / Unlock / Ignition), leave **5 swappable** —
own many, equip 5. Swap at Kabuki Electronics or from ICEBREAKER OS. Makes drops matter instead of
piling up.

**Tiers.** Common = shop. Rare = heist/event drop. **Prototype** = single-source, brag item.

**Optional: deck HEAT.** Every hack adds heat, heat decays over time, overheat = lockout + a wanted
ping to MaxSec. One number to implement; the ring already renders state, so it's nearly free. Turns
"which 5 do I carry" into a real decision and hands cops a counter.

---

## Vehicle / traffic

| Quickhack | Does | Hook | Tier |
|---|---|---|---|
| Killswitch Ping | Remote-kill the engine of a vehicle you tagged earlier | `AP_engineKillSwitch` | Common |
| Alarm Cascade | Sets off every car alarm within ~50m as a distraction | `caralarm` / `airalarm` | Common |
| Robotaxi Divert (replaced by SUMMON VEHICLE 2026-09-02) | Hijack a robotaxi mid-route — steal a ride or summon one free | `fn_robotaxi` | Rare |
| Plate Lookup | Aim at a car -> owner name + stolen status | `vehicles` table / keychain | Common |
| Convoy Beacon | Tag a convoy truck, track it for 10 min | convoy robbery | Rare |

## Cop / counter-surveillance

| Quickhack | Does | Hook | Tier |
|---|---|---|---|
| Drone Hijack | Take over a deployed MaxSec UAV and fly it yourself | `fn_copUAV` (already built) | Prototype |
| Scanner Leech | 60s of MaxSec dispatch piped into your messages | `copalert` handleMessage | Rare |
| ~~Bodycam Loop~~ | **DEAD 2026-09-05** — the cop search no longer reports firmware and Factory Reset is gone, so there is nothing left for this to beat | was: firmware flag (id 0) | Cut |
| APB Jammer | Drop off cop tracking for 60s | `trackAPB` | Rare |
| Evidence Wipe | Shave one charge off your wanted list | wanted system | Rare (balance risk) |

## Economy

| Quickhack | Does | Hook | Tier |
|---|---|---|---|
| Skimmer Uplink | Remote-collect every ATM skimmer you've planted | `fn_atmSkimSRV` | Common |
| Rig Uplink | Remote-collect LoonyCoin from your rigs | `APS_fnc_miningSRV` | Common |
| Porch Pirate | Track Loonazon vans (removed 2026-09-02; was talent 250-series; perfect module now) | van tracking | Common |
| Market Sniffer | Best current prices + which way they're drifting | dynamic market | Common |
| Fence Line | Sell illegal goods anywhere at 70% | drug dealer sell path | Rare |

## Infiltration

| Quickhack | Does | Hook | Tier |
|---|---|---|---|
| Blackout Local | Kill streetlights in a radius for 2 min | blackout event | Rare |
| Door Ghost | Next house breach skips the owner alarm | house breach | Rare |
| Turf Sniffer | Reveal turf/cartel timers + who holds them | turf / cartel state | Common |
| Vault Pre-Load | Fed pylon disarm starts 25% filled | `fn_openVault` | Prototype |
| Deep Sonar | Players/bodies through walls, 5s, 90s cooldown | — | Prototype (strong) |

## Drop sources (thematic, not random-random)

- **Fed vault / jewelry / evidence** -> Prototype tier (Drone Hijack, Bodycam Loop, Vault Pre-Load)
- **Cartel + turf captures** -> Rare combat/recon
- **Loonazon van robbery** -> Rare economy (it's a tech delivery — fits perfectly)
- **Prison break** -> Bodycam Loop / APB Jammer
- **Loot crates** -> Common dupes, tradeable player-to-player

## Suggested first batch

All reuse finished systems, ~zero new plumbing: Skimmer Uplink, Rig Uplink, Porch Pirate,
Alarm Cascade, Killswitch Ping. Then **Drone Hijack** as the marquee Prototype drop (UAV code exists;
"steal the cops' own drone" is the best story on the list).

Open question: build the slot/swap + heat system first, or ship the first batch as always-on wedges
and add slots when the ring runs out of room?


---

# TIER 1 — BUILT + LIVE ON DEV (2026-07-21)

Five civilian quickhacks, five authorisation-gated MaxSec counterparts, four firewall chips, and the three
universal levers that make the whole category fair.

## Universal levers
- **Upload channel** — 1-3s per hack. The victim sees `INTRUSION DETECTED` for the whole channel.
  **The SERVER runs the clock** (`APS_fnc_qhSRV`) and re-validates range/target/authorisation on
  completion, so a modified client cannot skip or shorten it.
- **Trace window** — 10s after being hit the victim gets a `TRACE INTRUSION` scroll action that pings the
  hacker's position (20s marker + bearing) and tells the hacker they were traced. A live **Proxy Chain**
  reroutes the trace and is burned doing it.
- **Firewall slots** — chips are owned permanently but only **TWO** may be equipped (Quickhacks app ->
  MODE: FIREWALL). Nobody is immune to everything.

## The five (civ / MaxSec counterpart / counter-chip)
| Hack | Effect | MaxSec version (authorisation) | Chip |
|---|---|---|---|
| Ping.exe | Target on your map 10s, 60s cd | Pursuit Tag (target must be WANTED) | Scrambler — feeds a position 100-200m off |
| Distract.exe | Alarm/ringtone at your position, heard ~120m | PA Override (speak through vehicle) | none by design |
| Static Burst | 3s of heavy visual noise, LOS | Dazzle Protocol (WANTED only) | Optic Filter — 1s light fuzz |
| Whiteout | Deafened 8s | Silence Cell (RESTRAINED only) | Audio Limiter — 3s, softer |
| Sticky Fingers | Forced holster, no re-draw 3s, LOS | Safety Interlock (WANTED **and** armed) | Hardened Firmware — immune |

Cop gating is **authorisation, not rarity** — server-enforced, so an officer cannot dazzle a random
civilian. Civ quickhacks route through **ICE TRACE**, so hacking a player pings nearby TAL officers
unless a Proxy Chain is burned.

## Implementation notes
- Catalogue: `core/config/fn_qhCfg.sqf` — adding a hack is one row; the ring builds its wedge entry,
  gating and cooldown generically, so new hacks are drop-in.
- `AP_fnc_qhCast` (caster) -> `APS_fnc_qhSRV` (authority) -> `AP_fnc_qhEffect` (victim).
- Ping position is streamed BY THE SERVER, which is what lets the Scrambler Chip lie — if the hacker's
  own client read the position, no counter-chip could ever work.
- Chips are ids 101-104 in the existing `AP_cdMods` persistence; $250k-$400k at Kabuki, issued free to MaxSec.
- Ring pools now hold 12 tools per side for 5 swappable slots.
