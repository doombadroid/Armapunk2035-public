# Faction reputation — design

**Date:** 2026-08-17
**Status:** design, decisions recorded; not implemented
**Depends on:** ArmaQuest (PR #24), which supplies the quest layer standing hangs off

---

## 1. Why this exists

The launch design puts four NPC factions on the map, one per territory, each with a
Fixer. Reputation with those factions is what everything else hangs off: perks,
gang alignment, which quests a player is offered, and eventually whether a
territory is hostile to them.

None of it exists today. `requires[]` has exactly four token kinds — `quest:`,
`license:`, `item:`, `item:qty` — and the library's only `faction` concept is a
kill-target filter. There is no notion of standing with anyone.

This spec adds one, in the shape the mission already uses for progression rather
than as a parallel system.

### Decisions on the record

| Question | Answer |
|---|---|
| Rival interaction | Values independent; **perks gated on relative standing** |
| Negative standing | **Allowed** — below zero is hostile |
| Gangs | Individual standing **and** gang alignment as a **multiplier** |
| Perks | **Reuse the existing talent system** |

---

## 2. The shape the mission already uses

Progression here is uniform and worth matching exactly:

```
exp accrues  ->  thresholds grant points  ->  points buy talents
             ->  talents are ids in an array  ->  gameplay checks `id in AP_side_talents`
```

`civ_exp`/`civ_talents`, `infamy_exp`/`infamy_talents`, and gang `experience`/`talents`
all follow it. `fn_calGangTalents.sqf` is the clearest example: `AP_gang_exp >= 1500`
→ 9 points. Talent rows are `[id, side, parent, tier, name, description]` in
`fn_talentCfg.sqf`, and gates are scattered `if (70 in AP_side_talents)` checks.

Reputation is the same machine with a different accrual source. It introduces no new
progression UI, no second currency, and nothing a player has to learn separately.

---

## 3. Storage

### 3.1 Player standing

One column, `players.faction_rep`, mres-encoded:

```
[["f_neon", 1240], ["f_dock", -80], ["f_maxsec", 0], ["f_pharma", 310]]
```

An mres blob rather than four columns, because the faction count is a content
decision and should not be schema. This matches how `talents`, `licenses` and
`crimes` are already stored, and it is read **bare, never `QUOTE()`-wrapped** — the
mres rule this codebase has been bitten by twice.

A faction absent from the array reads as `0`. Never write a zero row; absence and
neutrality are the same state and storing both invites them to disagree.

### 3.2 Gang alignment

Two additions to `gangs`:

- `faction` — `VARCHAR(32)`, the aligned faction id, empty for unaligned
- `faction_rep` — mres blob, same shape as the player column

A gang holds standing only with the faction it is aligned to, but the column is
shaped identically so realignment does not need a migration.

### 3.3 Faction catalogue

`core/config/fn_factionCfg.sqf`, following `fn_talentCfg.sqf`'s row idiom:

```sqf
[_id, _name, _territoryMarker, _fixerId, _blurb]
```

`_fixerId` ties a faction to its ArmaQuest giver (`fixer_1`…`fixer_4`), which is why
those ids were kept stable and abstract. Renaming a faction is a content edit; the
id is what code references.

---

## 4. Accrual

### 4.1 The rule

```
gain = base × gangMultiplier
```

- **`base`** comes from the action: a quest reward, a delivered contract, a job for
  that faction's Fixer.
- **`gangMultiplier`** is `1.0` normally, and higher when the actor's gang is aligned
  with the faction being credited. A solo player is never blocked, only unmultiplied
  — the announcement promises solos remain viable, and a multiplier keeps that true
  where a gang-only pool would not.

Gang standing accrues from the same event, so member effort compounds into the gang
pool exactly as described: *"how effective your gang is increases the standing for
everyone."*

### 4.2 Negative standing

Standing may go below zero. Below a configured hostility threshold:

- that faction's Fixer refuses to offer or accept quests, with a stated reason
- the refusal is a **content hook, not a wall** — a redemption path is a quest like
  any other, gated on `rep:` being low rather than high

Hostility is deliberately not wired to NPC aggression or service denial in this
spec. Those are separate systems and each deserves its own decision; standing simply
becomes readable by them.

### 4.3 The floor problem

A player who wrecks their standing everywhere must not become unplayable. Two
guards, both cheap:

- accrual for a faction at or below the hostility threshold is **damped, not zero** —
  it is always possible to climb back
- radiant work from a *neutral* faction is never gated on standing, so there is
  always something to do

---

## 5. Perks — relative gating

Perks are ordinary talent rows. What is new is the gate.

A faction perk requires that its faction be the player's **highest-standing** faction,
not merely that standing exceed a number. So values stay independent and easy to
reason about, while allegiance is still a real commitment: a player who spreads
effort evenly unlocks nothing.

```sqf
// in the talent row's own gate
[_factionId] call AP_fnc_isPrimaryFaction && {AP_faction_rep_primary >= _threshold}
```

`AP_fnc_isPrimaryFaction` resolves ties as **no primary** rather than picking one.
A tie means the player has not chosen, and silently choosing for them is how a perk
appears to flicker on and off as standing drifts.

Points come from thresholds on the primary faction's standing, mirroring
`fn_calGangTalents.sqf`. Perk ids live in `AP_faction_talents` and are checked
`id in AP_faction_talents`, identical to every existing gate.

**Switching allegiance** costs the perks of the faction you left, because the gate is
evaluated live rather than baked at purchase. That is the intended cost of realigning
and must be stated in the UI before a player commits — an unexplained perk loss reads
as a bug.

---

## 6. ArmaQuest integration

Three additions, all following the library's existing host-escape-hatch pattern —
the library learns nothing about what a faction is, exactly as it knows nothing about
what a licence is.

### 6.1 A fifth `requires[]` token

```
rep:<factionId>:<n>     standing with that faction is at least n
```

Negative `n` is meaningful and is how hostile-gated content is written:
`rep:f_dock:-500` offers a quest only to someone the dock faction hates.

Evaluation stays a pure function of one player and one quest, which is the property
that keeps offer order from affecting what is reachable.

### 6.2 Two profile capabilities

```
getRep  [uid, factionId]      -> NUMBER
addRep  [uid, factionId, n]   -> BOOL
```

Server-side, UID-keyed, same contract as every other paying capability. `addRep`
applies the gang multiplier internally, so no caller has to know the rule.

### 6.3 A reward field

```cpp
class rewards { money = 2500; xp = 5; rep[] = { {"f_neon", 100} }; };
```

An array of pairs so one quest can move several factions at once — which is how a
zero-sum feel can be authored per quest without hardcoding a rivalry matrix into the
system. Helping the docks at the neon faction's expense becomes a content decision,
reversible per quest, rather than a global rule that has to be balanced once for
everything.

---

## 7. What this does not do

- **No rivalry matrix.** Cross-faction consequences are authored per quest (§6.3).
  A global matrix can be added later if authoring proves repetitive; starting with
  one would fix the relationships before any content exists to tune them against.
- **No NPC hostility, denied services or territory bounties.** Standing becomes
  readable by those systems; each is its own decision.
- **No real-time world state.** *"The main quest evolves depending on player actions"*
  needs server-wide state that changes what is offered to **everyone**, and
  `requires[]` is per-player by design. That is a separate token kind reading
  published server state, and a separate spec.

---

## 8. Verification

Reputation is unusually testable for this codebase, because most of it is server-side
arithmetic rather than interaction:

- `getRep` on a fresh player returns 0 for every faction, with no row written
- `addRep` moves the stored value, survives a relog, and survives a server restart
- the mres column round-trips through a real save/load cycle — **read bare**, and
  verified against a decoded row rather than assumed
- a `rep:` token gates a quest in and out as standing crosses the threshold, in both
  directions
- negative standing is storable, readable, and gates a hostile-only quest **in**
- a gang-aligned member's gain exceeds an unaligned member's for the same action
- the primary-faction tie case resolves to no primary, and a perk gated on it is not
  granted
- realigning a gang removes the old faction's perks on the next evaluation

**Not verifiable without players:** whether the multiplier makes gangs feel worth
joining, whether the hostility threshold is reachable by accident, and whether losing
perks on realignment reads as a cost or as a bug. Those are playtest questions and
should be treated as such rather than settled in config.
