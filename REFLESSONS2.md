# Armapunk 2035 — Lessons from a Second Reference Mission

Debranded, actionable lessons from a decompiled reference Altis Life mission (a large German
RP server, 2026 build), mapped onto Armapunk's actual files. Source server names are stripped
throughout; it is only ever "the reference mission". Companion to `Olylessons.md`.

**Nothing here is ported code.** These are techniques and design findings only. The reference
mission is someone else's work; copying its source would be both a licence problem and against
the debranding rule. Everything below is "build this yourself", not "paste this in".

---

## 0. What that server actually was

A ~135 MB mission, 9561 entries, 95 % art assets and 5 % source. Standard Altis Life underneath
(cop / medic / civ / rebel, gather→process→sell, houses, gangs, drugs, robbery) with a large
progression layer bolted on top: 146 quests, 175 gang skills, 87 achievements, 785 craft
recipes, 709 weapon blueprints, 2203 items, three currencies.

**Zero AI combat.** `createAgent`, `BIS_fnc_spawnGroup`, `addWaypoint`, `setBehaviour`,
`setCombatMode`, `doTarget`, `commandAttack`, `setSkill` — all zero occurrences. The two
`createUnit` calls are player-body swaps for side changes. Their "PvE" is entirely
player-versus-systems.

That is the strategic finding: **they solved the empty-server problem with progression content,
not with spawned enemies.**

---

## 1. Boot-time config self-validation — highest value, cheapest to build

**Technique.** The reference mission validates its own configs at mission start and throws a
visible dialog when they are malformed. Checks it runs:

| check | failure surfaced |
|---|---|
| item ids unique | "Duplicate ids" |
| item ids strictly increasing | "IDs are not in strictly increasing order" |
| vehicle `alias` equals the item `displayName` (after stripping a title prefix) | "Invalid Aliases" list |
| goggles-category entries really are `CfgGlasses`, headgear entries are not | "Glasses in Headgear" |
| quest sub-class names are numeric | "config names must be numbers" |
| skin filename and size validity | "Size error" / "Name error" |

**Why it beats Armapunk's current approach.** We have **no boot-time config validators** — a
grep for this class of check across `mission/` returns nothing. We also have a live, unexplained
data-integrity bug in exactly this family: stats landing in the wrong slots and 146/209 titles
defective (`maldenafterdark-stat-title-corruption`). An id-uniqueness + monotonic-ordering
assertion over the item/stat tables is the same shape of check that would have caught it at
boot instead of in production.

**How to apply.** Add a `core/config/fn_validateConfigs.sqf` run from init, non-fatal but loud:
assert id uniqueness and ordering over the virtual-item table, cross-check every vehicle alias
against its display name, and assert every stat index maps to exactly one slot. Log to RPT and
show the dialog only when `AP_devMode`. This doubles as a spec for what a valid config is —
useful ahead of the open-source cut.

---

## 2. Progression as the answer to low player counts

**Technique.** 431 of their 541 features are playable without an opposing player. The spine is:

- **146 quests** with a real engine — 14-field records, terminals, prerequisites, auto-accept
  chains (float ids let 2 → 2.1 → 7.1 chain), 54 of 146 on daily rotation, 11 objective types
  (hold N items with live inventory hooks, own a licence, own a vehicle from a list, gear
  equipped, timed zone delivery, radius dwell polled every 5 s).
- **A second and third currency.** 1593 items priced in one emblem currency, 538 in another,
  earned from world quests and spent in a dedicated shop. Money inflation in the main economy
  does not devalue the reward track.
- **Crafting deep enough to drive gathering.** 709 weapon blueprints drop while gathering at
  1-in-N, with the drop source keyed to the activity (hand / pickaxe / rig / delivery run), and
  785 recipes recursing down to a single base material.

**Why it matters for us.** `MISSING_FEATURES.md` Tier 1 is a list of *client-complete,
server-stubbed* content — the Loony Bin heist, convoy robbery, jewelry server half, evidence
chain. Those are all high-ceremony, multi-player, cop-versus-crook events. When three people are
online, none of them are playable. A quest/progression track is the content that works at
player count 1.

**How to apply.** Do not build 146 quests. Build the *engine* — a flat quest record, a terminal,
prerequisite gating, and three objective types (collect N, deliver to zone, reach location) —
then let content accumulate. The float-id chaining trick is worth stealing outright: it makes
inserting a quest mid-chain a config edit rather than a renumber.

---

## 3. Licence exams instead of licence purchases

**Technique.** Licences are not bought, they are *sat*. Their multiple-choice test system backs
a driving test, a truck test, a pilot test, a service-fitness exam, a weapon-rules test, an
anti-cheat gang training, and a general-knowledge quiz whose question bank is **AI-generated**.

**Why it beats ours.** Our licences are a money sink and nothing else. An exam converts a
paywall into a knowledge check, teaches the server rules at the moment they matter, and is
almost free to build if a quiz UI already exists.

**How to apply.** We have `MultipleChoiceTest`-shaped needs already in the rules-acknowledgement
flow. Gate the truck and pilot licences behind a short test drawn from `wiki.md` content. The
AI-generated bank is the interesting half: a question table regenerated periodically defeats
answer-sharing, which is the usual reason servers abandon quizzes.

---

## 4. Protection posture — a decision, not a recommendation

**What they did.** Layered, in increasing cost to the attacker:

1. Junk preprocessor directives on nearly every line
2. Source files given **fake media extensions** — the item table lives in an entry named with
   control characters, the quest config in one ending `.ogg`
3. Decoy config blocks and a decoy function registry parked in dead `#if 0` branches
4. An **anti-tamper trap** — a fake decoder that, if executed, hijacks the session into a
   mission-host lobby
5. A **runtime tripwire**: the spawn button hashes the server name and the player UID and
   disables input if the mission is running somewhere it should not be

**Measured cost: 0.23 MB, 0.17 % of the PBO.** Effectively free to ship.

**What it actually bought them.** The extension trick defeated a commercial deobfuscator
outright — it quarantined ~18 MB of source as junk media, which is why the configs looked
missing for most of an analysis session. The decoys and the trap cost analyst hours. None of it
prevented recovery once the original PBO was unpacked without content sniffing.

**Our position.** We are heading toward open source (`launch.md`, the pre-open-source refactor).
Obfuscation is incompatible with that and should not be adopted. **But item 5 is independent of
obfuscation and worth having regardless:** a server-identity check at spawn is what actually
deters a stolen-mission redeploy, and it survives open-sourcing because knowing the mechanism
does not give you the allowlist. Consider it for the closed-beta window at minimum.

---

## 5. Bug classes to sweep for

The reference mission shipped ~30 probable bugs. The *classes* are what transfer:

| class | example found | our exposure |
|---|---|---|
| modulo on a possibly-negative value | parity bets paid out on green pockets, giving a **player-positive** roulette | ✅ **already guarded** — `fn_casinoSRV.sqf` draws `floor (random 38)` and excludes green before parity |
| unreachable jackpot | `== 20` tested against `floor (random 20)` | sweep `gambling.md` / `casino_plan.md` payouts for equality tests against an exclusive bound |
| off-by-one cap | quest slot limit used `>` where `>=` was meant | sweep any "max N" gate |
| cross-wired effect | jail retention skill for backpacks applied to the vest slot | audit talent/prestige perks where several perks share a handler |
| inverted modifier | a bail-reduction skill *increased* bail | same audit — assert sign on every modifier |

The generalisable rule: **any perk or skill that modifies a number needs a unit test asserting
the direction of the change**, not just that it changed.

---

## 6. Methodology lessons (for our own audits)

Two mistakes made during this analysis that apply directly to how we audit our own code:

1. **Never trust a tool's file classification.** A deobfuscator sorted 3763 plain-text config
   files into a "junk" folder because their extensions said `.paa` / `.jpg` / `.ogg`. Believing
   it produced a confident, wrong conclusion that a megabyte of config "did not exist in the
   archive". When a tool categorises, verify by content.

2. **A negative result measured downstream of your own transform is a statement about the
   transform.** "X is absent" was reported three times off a filtered copy; each time X was
   present in the raw source. Before reporting an absence, re-run the check against the most
   upstream artifact that could support it. This is already logged as a standing observation and
   it applies to `AUDIT.md` sweeps as much as to reverse engineering.

---

## Priority order

1. **§1 config validators** — cheapest, directly relevant to a live data-integrity bug
2. **§5 modifier-direction sweep** — small, and the bug class is one we plausibly share
3. **§2 quest engine skeleton** — the real strategic gap; content works at low player count
4. **§3 licence exams** — cheap RP depth once a quiz UI exists
5. **§4 spawn tripwire** — beta-window only; do not adopt obfuscation
