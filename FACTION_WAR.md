# Fixer territories, alignment and the weekly war

**Date:** 2026-08-30
**Status:** built, boots clean on dev (b0805), **playtested by nobody**
**Builds on:** `FACTION_REP_SPEC.md` (standing), `WORLD_STATE_SPEC.md` (world gates),
`ARMAQUEST_SPEC.md` (the quest layer)

---

## 1. The shape

Malden splits five ways.

| Zone | Who |
|---|---|
| The north cartel belt | The redzone. Unchanged — six cartels, already live |
| **La Trinite** | Neutral. Belongs to nobody and never will |
| **Larche** | **Lightrunners** — Nero — netrunners — `f_neon` / `fixer_1` |
| **Chapoi** | **Crusaders** — Pope — hits and grand theft — `f_dock` / `fixer_2` |
| **La Port** | **Silent Partners** — The Administrator — corporate — `f_pharma` / `fixer_4` |
| La Pessagne | Held back for a fourth faction (`f_maxsec` / `fixer_3`), which exists in config and holds nothing |

**The ids are placeholders and are kept that way on purpose.** A stored standing
array keys off them, so renaming `f_dock` to something that reads like "Crusaders"
would orphan every player's reputation silently. Read them as handles. `f_dock` is
the Crusaders and has nothing to do with a dock.

## 2. Alignment

A gang picks a fixer in the Gang Command deck app. Leader only, and every rule is
re-derived server-side in `APS_fnc_gangAlignSRV` — the page is honesty, not security.

- **First alignment is free and instant.** A gang that has never chosen has nothing
  to be punished for.
- **At five members, an unaligned gang is told once** that the best work is closed
  to them. Nothing is locked. That is the whole of the pressure.
- **Defecting costs** `AP_FACTION_DEFECT_FEE` from the gang bank, and starts a
  `AP_FACTION_DEFECT_DAYS` cooldown. Faction perks are lost, because the perk gate
  is evaluated live against your primary faction.
- **You cannot defect during a week your own fixer is a belligerent.** Without this
  the dominant move every Monday is to read the matchup and run to whoever is
  sitting the week out.

Solos are never aligned and never hostile. What they lose is access, not safety.

## 3. The weekly war

Every week two fixers fight and one sits out. The matchup is decided by the
**contract score** each fixer's aligned gangs earned the previous week:

- highest → **defender** (being effective is what paints the target)
- runner-up → **aggressor**
- lowest → **neutral**

A rubber band on purpose: doing well buys you a war, not a rest.

**Scoring has no hook of its own.** It rides inside `AP_fnc_aqAddRep`, at the branch
that already knows the gain is positive and the earner's gang is aligned with the
credited faction. It credits the pre-multiplier value — the aligned 1.5x is a reward
to the player, and letting it into the score would count aligned work one and a half
times toward a matchup meant to measure work done.

**The week comes from the database** (`to_char(NOW(),'IYYY') || '-W' || to_char(NOW(),'IW')`),
and the rollover compares week KEYS, never elapsed time. A restart, a missed tick, or
a server down across the boundary all resolve on the next fire.

## 4. What hostility means

Only the engagement-rules layer:

- **red name tag** — icon, person colour, vehicle-crew colour, and chat, all four
- **a banner** on entering a territory, and again if a war starts while you stand still
- **KOS-legal by server rule** — the diary says so in words

Damage, sides and group relations are untouched. There is no engine relations layer
in this mission to conflict with (`setFriend`, `getFriend`, `BIS_fnc_sideIsFriendly`:
zero call sites anywhere). `fn_enterActiveTurf` set the precedent — warn, enforce nothing.

**No map marker reveals an enemy position.** A red name is the whole signal.
`fn_trackMarkers` is deliberately untouched.

Hostility requires BOTH belligerents involved: you are aligned to one, and you are
standing on ground belonging to one. The neutral fixer's town is not a war zone.
Neither is La Trinite, the open road, or an unaligned gang anywhere.

## 5. Where it lives

| Path | What |
|---|---|
| `deploy/faction_war.sql` | the columns (four of which were never delivered) + `faction_war` |
| `core/config/fn_factionCfg.sqf` | names, blurbs, **polygons**, towns |
| `core/config/fn_factionPerkCfg.sqf` | perks — **none of them wired to anything yet** |
| `core/functions/fn_factionTerritory.sqf` | position → faction, cached |
| `core/functions/fn_factionHostile.sqf` | the predicate the tag ladder calls |
| `core/functions/fn_factionBanner.sqf` | the 3s loop; owns `AP_warHere` / `AP_myFaction` |
| `server/.../fn_factionWarSRV.sqf` | matchup, scoring, rollover |
| `server/.../fn_gangAlignSRV.sqf` | alignment, defection fee/cooldown/war block |
| `aq_content.hpp` | six contracts across the three fixers |
| `tools/bake_territory.py` | Eden markers → the polygons |

## 6. Owner work still owed

**These are map decisions, and they need eyes in the game.**

1. **Redraw the territories.** The shipped polygons are octagons sized off existing
   spawn anchors so the system is testable — they are not design. Place
   `aq_terr_<factionId>_p1..pN` around each town's real perimeter in an `AP_*` layer
   of `MaldenEdit.Malden`, then `python3 tools/bake_territory.py <sqm>`. Work through
   `tools/edit-map.sh`; never save the shipped `mission.sqm` from 3DEN.
2. **Move the Fixers to their towns.** `aq_giver_fixer_1/2/4` are still at their
   original placeholder spots near La Trinite and Larche. This was left alone
   deliberately: an unverified coordinate can put an NPC inside a rock or in the sea,
   and content references the giver id and not the position, so the move is free
   whenever you make it.
3. **Decide the fourth faction**, or leave `f_maxsec` reserved. It works either way.

## 7. Playtest — none of this has been played

Boot gates are green on dev b0805 and the rollover was proven by forcing it. What
follows needs a person.

**One client**
- Cross each of the three territories: the banner fires once per crossing and names
  the right fixer. Leaving prints NEUTRAL GROUND.
- A solo sees the plain territory notice everywhere and is never red to anyone.
- Gang Command → FIXER: swear to a fixer. It applies, and `gangs.faction` changes.
- The board at that fixer gains the align-gated contract; it is absent before.
- Try to defect: refused with a stated reason for each of not-leader, bank short,
  inside cooldown, and fixer-at-war.

**Two clients — the parts nothing else can prove**
- Two gangs aligned to the two belligerents, both inside a belligerent territory:
  each renders the other's name RED, and normal once outside it.
- **No map marker appears for the enemy at any point.**
- Chat colour matches the tag colour.
- Vehicle crews render on the same rule as men on foot.
- A gang aligned to the NEUTRAL fixer is not red to either belligerent anywhere.

**Not verifiable without players:** whether five is the right threshold, whether
losing perks on defection reads as a cost or a bug, and whether a red name with no
map marker is enough to fight on. Playtest questions, not config ones.

## 8. Known-not-done

- **Faction perks do nothing.** `AP_fnc_hasFactionPerk` has zero call sites; points
  accrue, perks are bought and persisted, and no rule reads them. Do not surface the
  tree to players until the gates exist, or it takes their points and gives nothing.
- **Contract templates have no `slots`**, so they do not randomise — the same as
  every pre-existing template. `[AQ-VALIDATE]` warns about it on every boot.
- **`aq_fnc_validate` / `aq_fnc_reachability` have not been run on demand** after
  mission start, only at preInit — which defers all 13 marker checks. Run them from
  a client once the world is up.

## 2026-09-04: territories live in PostGIS

`faction_territory` (deploy/postgis.sql) is the authority; `tools/bake_territory.py` writes it from
the Eden markers, the server publishes `AP_factionPolys` at boot and on the bot verb
`territoryreload`, and `fn_factionCfg` overlays the polygons over its literals (which remain the
fallback). Redraw = markers → bake → `INSERT INTO bot_commands (command) VALUES ('territoryreload')`.
See `postgis.md`.
