# A story questline for Armapunk — proposal

## Where we are

134 quests, and they are **flat**. Every one is an independent objective —
"Chop down 25 trees", "Kill a cop", "Sell 90 Meth" — with no order, no teller,
and nothing that follows from anything else. The row has `multiStage` and a
`questType`, but no "next quest" field, so a chain cannot currently be expressed
at all.

Two consequences:

- **A new player has no path.** They open the quest app to 65 restart-cycle
  objectives with no suggested first one.
- **The cyberdeck has zero quest hooks.** `fn_handleQuest` has 99 call sites
  across 47 distinct triggers — `robstore`, `choptree`, `capturf`, `shank`,
  `skydive`, `learntalent` — and not one of them is a quickhack, a breach, a
  proxy burn or an ICE trace. The signature system of the whole mod is invisible
  to the quest system.

## The structural idea worth borrowing

The reference mission's chain is a **linked list**: each quest names the next.
That one field is what turns objectives into a story — it gives an author
ordering, pacing, and a place to put a turn.

Its starter chain is 78 steps that teach the whole economy in sequence: ID →
licences → first vehicle → farming → processing → mining → trucking, handed off
between three named characters. Buried inside it is a real arc — a priest on a
mountain sends you for weed, then cocaine, then LSD, then heroin, then has you
deal each one in a different town, and it ends with **his funeral**. Teaching the
drug economy inside a tutorial that has a death in it.

We should take the **shape**, not the content: a linked list, named handlers, one
arc with a turn. Characters, setting and text are ours.

## What we would add to the data

One field. `nextId` on the quest row, `-1` for standalone. Everything else the
system already does — `handleQuest` fires triggers, `questSync` persists, the app
lists and accepts.

Then the missing triggers, which is the real work:

| trigger | fires from | teaches |
|---|---|---|
| `qhcast` | `fn_qhCast` | you own a deck and it does something |
| `qhbreach` | the four breach tools | unlock / house / atm / cuffs |
| `proxyarm` / `proxyburn` | `fn_useItem`, `APS_fnc_iceTrace` | that being quiet costs money |
| `icetraced` | `APS_fnc_iceTrace` | that the MaxSec heard you |
| `chipinstall` | `fn_useItem` | the firmware economy |
| `qhtraced` | `fn_qhTrace` | that the victim can trace back |

Six one-line additions next to existing `handleQuest` calls. No new subsystem.

## THE SIGNAL — a proposed starter chain

Sixteen steps. Each teaches one system and hands to the next. Names are
placeholders; the shape is the proposal.

**Act 1 — you are nobody (1–5).** A fixer called **VESSEL** contacts you on the
handset — the phone is the first thing you touch, which is right, because it is
the best thing we have. Get an ID. Buy the cheapest licence. Ride a Robotaxi to
her, because that teaches the GPS (Robotaxi — replaced by SUMMON VEHICLE 2026-09-02). Collect.

**Act 2 — you are useful (6–10).** Gather a field, process it, sell it into the
market — and the quest text names the **premium band**, so the player learns on
their first sale that prices move and why. Buy a vehicle with the proceeds.

**Act 3 — you are dangerous (11–16).** VESSEL puts a **firmware flash** in your
hand. First quickhack — `Ping.exe` on anything. Then a breach: an ATM, which is
the cleanest teacher because it is a real crime with a real trace. Then the turn:
she tells you to arm a **Proxy Chain** before the next one, and the next one is a
house. If you skip the proxy, you get traced, and the quest **still completes** —
the MaxSec arriving is the lesson, not a failure state.

**The turn.** VESSEL goes quiet. The last step is a marker on a body and a
handset you can read: she was traced weeks ago and kept working. Her deck is
yours. The final reward is a chip.

That is the priest's funeral, in our fiction, teaching our system.

## Why this fits what already exists

- The **phone is done** — 25 of 32 apps. A quest chain that lives on the handset
  has a screen to live on.
- **Robotaxi and the GPS** exist and nothing points a new player at them.
- The **market premium band** is real and invisible; a quest is the natural place
  to explain it.
- The **ICE trace and proxy chain** are the best mechanics in the mod and are
  currently discovered by accident or not at all.
- `fn_deckList` already renders quests on the deck, so the chain has a home
  without new UI.

## Cost, honestly

- `nextId` field + the app showing "next: …" — small
- six `handleQuest` triggers — small, one line each
- 16 quest rows with real text — a writing job, not an engineering one
- markers and NPC placement — map work, and markers must go in the map layer,
  never `createMarker` in init
- **no voice.** The reference has none either. Text and a completion cue is the
  established bar; VO is a separate project and should not gate this.

## What I would not do

- Copy their text, their character names, or their arc beat-for-beat. The
  structure is a pattern; the writing is theirs.
- Build a second quest system. Everything above rides the existing one.
- Gate the chain behind the cyberdeck. Acts 1 and 2 must work for a player who
  never touches a deck, or it stops being an onboarding.

---

## FOUND WHILE SCOPING (2026-08-12) — the existing onboarding is off-map

Shelved mid-investigation; recorded so it is not rediscovered.

There is already an onboarding arc: **THE INTAKE** (Act 1, wake in the Bin),
**PAROLE PAPERS** (Act 2, a fixed 6-contract chain), **MENTOR PROGRAM** (Act 3).
`fn_handleQuest` already forwards every event to `AP_fnc_parole` while it is
active, so the plumbing is good — it is a proper step engine with BIS tasks, a
marker per step, and progress persisted in `players.intake_step`.

**Every coordinate in it is an ALTIS coordinate, and Malden is 12800 × 12800.**

| step | position | |
|---|---|---|
| peach field | 13118.8, 19672.2 | OFF MAP |
| Athira market NPC | 14041.3, 18786.6 | OFF MAP |
| Athira DMV | 14036.5, 18760.1 | OFF MAP |
| Athira car dealer | 14034.9, 18757.5 | OFF MAP |
| Parole Officer | 14060.9, 18747.3 | OFF MAP |

`fn_intake.sqf` is the same shape — `INTAKE_CELL [3761.87, 13016.4]`,
`INTAKE_DOC_POS [3772.55, 13010.6]`, both past 12800 on Y.

So the entire new-player onboarding almost certainly points at empty ocean or
nothing at all. This is the same class as the Kabuki Electronics markers that
were pulled on 2026-07-27 and `AP_marketHubs`, which still holds Kavala /
Athira / Pyrgos / Sofia positions and is referenced nowhere.

**Verify before writing any new quest content**, because if the arc does not
run, extending it is wasted work and the right move is to re-site it on Malden
first. The step table itself is fine — it is only the five `#define`s and the
intake's two.

The six contracts, for reference, cover: driver's licence, buy a vehicle, pick
15 peaches, sell 10 peaches, learn a talent, report to the officer. Not covered
anywhere: the handset, processing, the cyberdeck, housing, storage, squads,
banking, the casino, Loonazon, the Robotaxi, or what happens when the MaxSec take
an interest in you.
