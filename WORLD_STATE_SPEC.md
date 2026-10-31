# World state in quest prerequisites — design

**Date:** 2026-08-17
**Status:** design; not implemented
**Companion to:** `FACTION_REP_SPEC.md`. Both add `requires[]` token kinds and share
one mechanism, which is why they are specified together and implemented once.

---

## 1. What this is for

The launch design says the main quest *"branches and will evolve depending on player
actions in the server, in real time."*

Half of that already works. `requires[] = {"quest:<id>"}` gives a directed graph
rather than a line, so one player's choices open different branches for them. What
does not work is the other half: a quest whose availability depends on what the
**server** looks like right now — who holds a cartel, whether the Fed was hit this
restart, which turf is contested.

`requires[]` is deliberately a pure function of one player and one quest. That
property is worth keeping: it is what stops the order offers are built in from
changing what is reachable. World state does not break it — the world is the same for
everyone at the moment of evaluation — but it does need a token kind of its own.

## 2. The world state already exists

This is the important finding, and it changes the shape of the work.

The mission already maintains server-wide state, persisted and published:

| source | examples |
|---|---|
| tables | `cartel_state`, `turf_state`, `gov_state`, `server_control` |
| published globals | `AP_fed_robbed`, `AP_bank_inProgress`, `AP_seizeAcquired`, `AP_purgeZone`, `AP_prison_inProgress`, `AP_chemtrailZone` |
| key/value | `config` (`index` INTEGER, `value` TEXT) — present, currently empty |

So this layer invents no state. It makes state that already exists **readable by
quest prerequisites**, which is a far smaller and more honest change than building a
world-flag system beside the one the mission has been running all along.

## 3. The token

```
world:<key>            the world flag is truthy
world:<key>:<value>    the world flag equals that value
```

Examples, all against state that exists today:

```cpp
requires[] = { "world:fed_robbed" };                  // only while the Fed is down
requires[] = { "world:cartel_arms:f_neon" };          // only while neon holds arms
requires[] = { "quest:aq_fx2_flash", "world:purge" }; // a branch that opens during a purge
```

## 4. Resolution — a registry, not a lookup table

A key does **not** map directly to a variable name. It maps to a host-registered
resolver:

```sqf
["fed_robbed",   { !isNil "AP_fed_robbed" && {AP_fed_robbed} }] call aq_fnc_registerWorld;
["cartel_arms",  { ["arms"] call AP_fnc_cartelOwner }]          call aq_fnc_registerWorld;
```

Three reasons it is a registry:

- **The library stays ignorant.** It knows a key and a piece of code, never what a
  cartel is — the same discipline as `sqlExec`, the profile, and trigger drivers.
- **An unregistered key is a validation problem at preInit, named.** A quest gated on
  a world flag nobody registered is content that can never appear, and the whole point
  of validating at boot is that this is caught then rather than by a player who never
  sees a quest and has no way to know it exists.
- **The mapping is one place.** Reading published globals directly from content would
  scatter mission-specific names through a config file that is meant to be portable —
  and, later, through a web quest editor written by people who do not know them.

**A resolver must be cheap and must not block.** It is called during offer building,
per candidate quest, for every player who opens a giver. Anything that queries a
database belongs behind a cached published variable, not inside a resolver.

## 5. Evaluation and the property worth protecting

Evaluation stays a pure function of `(player, quest, world-at-this-instant)`. No
resolver may consider which quests were checked before it, and none may mutate
anything. Prerequisites are read-only by construction.

The consequence is deliberate and must be designed for rather than papered over:

> **A quest can be offered, and then stop being available before it is accepted.**

The Fed gets un-robbed, a cartel flips, the purge ends. A player looking at a board
sees an offer that no longer qualifies. This is not a bug — it is the *point* of the
feature, and it is what makes the world feel live rather than scripted.

But it must be handled explicitly at two moments:

- **On accept.** `aq_fnc_srvAccept` re-evaluates `requires[]` server-side already.
  A world flag that has since flipped fails there, and the refusal must say **why** —
  "the moment has passed" reads as the world moving on; a silent refusal reads as a
  broken button.
- **Mid-quest.** A quest already accepted is **not** cancelled when the world changes.
  Prerequisites gate *offering*, not *holding*. A player who takes a job during a purge
  and finishes after it ends still finishes. Anything else means work lost to timing a
  player could not control, which is the least defensible failure a quest system has.

Content that genuinely must expire mid-run has a mechanism already: `timeLimit`.

## 6. What this enables, concretely

The branching main quest in the launch design becomes authorable:

- a branch that only opens while a faction holds a territory
- a Fixer who offers different work depending on who won the last turf war
- content that appears only during a server event and is gone afterwards
- with `FACTION_REP_SPEC.md`'s `rep:` token, a quest gated on **both** standing and
  world state — *"the docks trust you, and the neon faction has just lost the arms
  cartel"* — which is where the two specs compose into something neither gives alone

## 7. Shared implementation with `rep:`

Both specs add a token kind. `requires[]` parsing currently recognises exactly four,
and an unrecognised kind is already treated as **unsatisfied** — the safe reading of
"I do not understand this gate" being "closed". That default is what makes adding
kinds safe.

Implement the parser change once, for both:

- `rep:<faction>:<n>` — profile-backed, per player (`FACTION_REP_SPEC.md` §6.1)
- `world:<key>[:<value>]` — registry-backed, per server (§3 above)

Both are read-only, both are pure at the moment of evaluation, and both fail closed.
`aq_fnc_validate` gains one check per kind: a `rep:` naming an unknown faction, and a
`world:` naming an unregistered key, are each a named problem at preInit.

## 8. What this does not do

- **No scheduling.** "Every Sunday" or "three hours after a restart" is a timer, not a
  world flag. A host can register a resolver that reads one, but the library gains no
  notion of time beyond `timeLimit`.
- **No writing.** Quests read world state; they do not set it. A quest that changes
  the world does it through a host function in its rewards, which is a deliberate
  separation — prerequisites that could mutate state would make offer-building
  order-dependent, destroying the property §5 protects.
- **No history.** Only the current value is visible. "Has the Fed *ever* been robbed"
  is a different question and belongs in the host's own state if it is wanted.

## 9. Verification

Mostly server-side, so mostly testable without players:

- a quest gated on a world flag appears and disappears as the flag is toggled, in
  both directions, without a restart
- an unregistered key is a **named** preInit problem, not a silently unavailable quest
- a resolver that throws does not take the offer build down with it, and is reported
  once by key rather than once per evaluation
- accepting a quest whose world gate has flipped since it was offered is refused with
  a stated reason
- **a quest already accepted survives its world gate flipping** — the case most likely
  to be got wrong, and the one a player would most resent
- `rep:` and `world:` in the same `requires[]` both gate correctly, independently

**Not verifiable without players:** whether an offer vanishing between looking and
clicking reads as the world being alive or as the UI cheating. That is a playtest
question, and the wording of the refusal is most of the answer.
