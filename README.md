# Armapunk 2035

A cyberpunk **Arma 3** life RPG on **Malden 2035** — gangs, cartels, police and medics, a deep
criminal economy, and a hacking layer built on top of it all. Current build: **Beta 0.2.1**.

Forked from LooneyBin (Altis) on 2026-07-25 and renamed on 2026-08-03. Full history is preserved —
everything before the fork point is the LooneyBin codebase, which Armapunk inherits wholesale.
The map layer is authored by an external designer; see `MALDEN.md`.

> **Status:** private beta, dev server only. There is no public live server yet.
> While in closed beta every player loads maxed (progression and trees unlocked) — see `launch.md`
> for the pre-public revert list.

---

## The client mod — `@Armapunk2035`

An optional client-side mod that adds what the mission alone cannot. Built from `radio/`, signed,
and distributed via the Steam Workshop.

**Live streaming radio.** Five stations — ORIGIN FM, KHR, PULSE, CLASSICO and ANARCHY — streamed
from an icecast/liquidsoap backend rather than packed into the mission. Now-playing titles surface
on the HUD, volume ducks with distance from the vehicle, and bystanders hear it at a quarter volume.
The audio player is a Rust extension (`radio/extension`), so no music files ship in the mission PBO
at all. Without the mod the dial still works — you get a promo loop instead of the stream.

**Female character heads.** 166 faces across Caucasian, Asian and Black variants with eye and hair
combinations, registered against the vanilla female identity so they appear in the normal face
picker.

**Panoramic night vision.** GPNVG-18 quad-tube NVGs in tan and black, each in plain, thermal, and
full-screen "Overwatch" thermal variants.

The last two are third-party work included with their creators' permission — see
[`radio/addon/PROVENANCE.md`](radio/addon/PROVENANCE.md) for full attribution and licence detail.

---

## What's new since Altis

Everything below landed after the Malden fork. The inherited systems are listed further down.

**A whole new map.** 8,656 designer-authored objects imported and 7,070 inherited Altis objects
removed. Custom buildings ship inside the mission PBO and are spawned client-side, so no map mod is
required. Terrain deformation ships modless too. The designer's bridge is a real dual carriageway —
both decks are routed in the road graph, with one-way support added for it.

**A map-editing pipeline.** Save in 3DEN and the change is applied, packed and deployed to dev about
90 seconds later. The shipped mission is never opened in the editor; a generated edit mission carries
every code-spawned object as a draggable entity. Full design in `mapedit.md`, rules in `CLAUDE.md`.

**Every heist rebuilt for Malden.**
- **Federal Reserve** — gate sequence-breach, a dome cracked on a ten-minute clock, an alarm that can
  veto the breach it answers, ten ring safes, and a getaway boat delivered with the crew's keys.
- **Bank** — opened through its back-alley gate, sealed at boot.
- **Jewelry Emporium** — redesigned around deck breaches, six sealed gates, display cases owned by
  the server, the Hope Diamond in the safe, and a crane as the getaway.
- **Prison break** — a ten-minute clock instead of a hold radius, a gate hack, containment, and an
  escapee who can actually walk out of the gate he opened.
- **The Loony Bin** — rebuilt around the Malden compound and hardened after its first live run.
- A **cross-heist lockout** is enforced server-side, from every heist that obeys it.

**Cartels and turf, reworked.** Six Malden cartel sites driven from a single config table, each with
one flag and one map icon, with accrual, collection, payout routing and perks. The Altis turf
rotation is retired on Malden.

**Police and medical relocated.** The MaxSec HQ is now the Malden County Sheriff's Office, with signs
cut as real recesses into the building skin. Cop side got working spawn points for the first time on
this map; ER HQ has its own spawn layout with pads that raycast the real surface, so vehicles stop
spawning underground and cars never take an air pad.

**World detail.** Placed lamps emit real light, lamps and power poles are indestructible, doors work
on every building and gate in the map array, and shop NPCs are drawn as visible local units.

**The cyberpunk layer** — cyberdeck firmware, quickhacks, the ICEBREAKER and TAL OS phone apps, the
quickhack console and the VR-goggle lock bracket — carried over and continues here.

---

## Inherited systems

Everything the Altis codebase brought with it, still in game.

**Police (MaxSec)** — seven ranks from Cadet to Chief, MaxTac, a prestige tree (Warrant Squad, Combat
Medicine, Undercover, Mobile HQ, Leadership), arrest / restrain / escort / jail / ticketing, wanted
list and warrants, search and seizure with an evidence vault, radar and traffic cams, deployables,
spike strips, non-lethals, marked and undercover vehicles, saved loadouts.

**Medics (TT)** — six ranks, prestige tree, revive, bloodbags, adrenaline, painkillers and rehab,
**revive drones** that fly and treat, dispatch and requests, and a **firefighter division** with
hoses and building fires.

**Civilian life** — gangs (ranks, gang house, gang garage, bank, perks, wars, Gang Fortress),
bounty hunting with an honour and skiptracer system, the rebel infamy tree, an elected **Governor**
with elections, laws, pardons and taxation, courthouse **trials with a jury**, bail, the
player-to-player **Exchange**, houses with storage, upgrades, keys and spirit aging barrels, quests,
achievements, titles, and a daily login bonus.

**The criminal economy** — cannabis, smash, heroin, black lace and more, with gathering, processing,
drug runners by ground and air, addiction, overdose and rehab; mining across copper through
uranium; oil, fishing, hunting, logging and treasure hunting; chop shops; and a **dynamic market**
where cartel control moves prices.

**Money** — cash, bank, **New Drachma**, paychecks, ATMs, wire transfers and debit cards.

---

## Live ops and tooling

| Tool | What it does |
|---|---|
| `loonybot` | Discord ops bot — reports, bug intake, account linking, server control |
| `clankr` | anti-cheat and exploit detection |
| `lagwatch` | lag-switch detection |
| `officer-maggot` | MaxSec whitelist applications |
| `enrique` | offline weed-harvest bot |

---

## Layout

| Path | What |
|---|---|
| `mission/Armapunk2035.Malden/` | the mission (client + shared SQF) |
| `server/AP_server/` | the server PBO source |
| `radio/` | the `@Armapunk2035` client mod — addon sources, Rust extension, stream configs |
| `tools/` | map and asset pipelines (⚠ copies also live in `deploy/`; edit `tools/`) |
| `deploy/` | build / deploy scripts + server & BattlEye config |
| `loonybot/` | the Discord bots |
| `sql/` | database schema |

Key docs: `CLAUDE.md` (conventions and standing rules), `MALDEN.md` (fork and map-layer status),
`mapedit.md` (map pipeline), `security.md` (audit findings), `update.md` (live deploy).

---

## Build and deploy

Arma 3 dedicated server on Linux, Malden. `@AP_server` packed from `server/AP_server/`, plus the
mission PBO, against `@extDB3` and MariaDB.

```sh
bash /home/timb/arma3server_dev/reload-armapunk2035.sh   # packs + restarts dev
```

Each deploy packs to a build-numbered `Armapunk2035_bNNNN.Malden` rather than overwriting one
filename, which is what lets the client mission cache be seeded instead of downloading ~149 MB.
Confirm a deploy landed by **name**, not by a generic marker:

```sh
grep 'read from bank' /home/timb/arma3server_dev/loonydev.log
```

The client mod builds separately:

```sh
bash radio/build_addon.sh && bash radio/sign_addon.sh    # -> radio/dist/@Armapunk2035
```

> **Secrets stay local.** Files with live credentials — `server/extdb3-conf.ini`,
> `loonybot/*config.json`, BattlEye `beserver*.cfg`, and the addon signing keys — are git-ignored.
> Copy the `.example` templates and fill in your own.

---

## Credits

The map layer is the work of an external designer. The client mod redistributes two third-party
addons with their creators' permission — **Zeealex** (Fifty Shades of Female heads) and
**SweetJason / ColdJason** (GPNVG-18 night vision). Full attribution in
[`radio/addon/PROVENANCE.md`](radio/addon/PROVENANCE.md).
