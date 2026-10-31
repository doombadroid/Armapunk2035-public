# Feedback on PATTERNS.md — verified against the code, and now built

Feed this back with `PATTERNS.md`. Everything here was checked against the files
named, and pattern C has since been **implemented against the corrected model**,
so this is not review notes — it is what the working screen actually does. Where
the two documents disagree, this one wins.

---

## What was right

Checked line by line, and most of it holds:

- `ping` really is **`2s up · 60s cd · 150m`** (`fn_qhCfg.sqf`).
- The six ring slots really are **`ping · whiteout · synapse · leech · static ·
  distract`** (`AP_qhConsoleDefault`) — matching the glyph map exactly.
- The server really does own the upload channel (`APS_fnc_qhSRV`).
- **The pattern C collapse is real**, and see below — it is *cleaner* than the
  brief claimed.
- **The missing-glyph catch was news to us and it is correct.** `ghouse`,
  `gcuffs`, `gshield` and `gcarlock` are all in the `AP_qhIcon` table at
  `configuration.sqf:232` but absent from the baked `icon_order.json`. That is
  our bug, found by the design pass. Still open.

---

## 1. Pattern C — right instinct, wrong machine underneath

**The collapse is better than you pitched it.** All six apps resolve to two
catalogue functions and a category string:

| App | catalogue | category | learned list |
|---|---|---|---|
| Talents | `fn_talentCfg` | `standard` | `AP_side_talents` |
| Perks | `fn_prestigeCfg` | `gang` | `AP_gang_talents` |
| Honor | `fn_prestigeCfg` | `bh` | `AP_honor_talents` |
| Prestige | `fn_prestigeCfg` | `cop` | `AP_cop_talents` |
| TT Prestige | `fn_prestigeCfg` | `medic` | `AP_medic_talents` |
| Infamy | `fn_prestigeCfg` | `rebel` | `AP_infamy_talents` |

(`Perks` is the gang talent tree — that one is not obvious from the app name.)

But the node model is not what the brief assumed, on four counts.

**No ranks.** A row is `[id, side, parentId, depth, name, desc]`. Learned or not.
The rank pips — one flex bar per rank, pinned with `margin-top:auto` — would read
1-of-1 on every node in the game. They are gone from the built tile; the state
dot carries owned / available / locked instead.

**Gating is per node, not per tier.** Each row names its *own* prerequisite in
field 2. `Porch Pirate Protection` needs `Delivery Expert` specifically, not "any
node in the tier above". The rule as written would have shown players talents
they cannot buy.

**`-1` means root, and there are 21 of them** in civ talents (depth spread
21/27/14/2/1). A literal "tier 0" row would be 21 nodes wide. **Your left-column
tree switcher is what saves this** — it was the best idea in the pattern. Pointed
at *branches* instead of apps, each branch is 2–8 nodes and the tier rows fit
exactly as you drew them.

**There are two economies, not one.**

- **Talents and Perks** spend a **point pool** against a cap
  (`AP_currentTalents` / `AP_currentGangTalents`).
- **Honor, Prestige, TT Prestige, Infamy** spend an **XP currency** at a
  **per-node price** carried in a *seventh* field the talent rows do not have.
  Balances are `AP_honor_exp`, `AP_prestige`, `AP_medic_exp`,
  `AP_infamy_exp`.

So the pool card renders two ways: `12 / 20 SPENT` for point trees,
`4,300 HONOR · 6 OF 15 LEARNED` for XP trees.

### Unlearn — the state you had no slot for

`fn_learnTalent` and `fn_learnPrestige` are **toggles**. Clicking a node you own
unlearns it. That is one verb, not two, and the built screen labels the button
from the node state rather than offering a separate action. The rules are not
uniform:

| Tree | unlearn |
|---|---|
| Talents | costs `AP_respec_fee`, blocked while a learned child depends on it |
| Perks | free, same child block |
| Honor / Infamy | **$5,000 cash**, and the node's XP is refunded |
| Prestige / TT Prestige | **impossible — those cases are literally empty** |

Cop Prestige and TT Prestige are permanent. The button reads `PERMANENT` and is
disabled, rather than failing on click.

### Two things to delete from the design

**`RESPEC TREE` must not exist.** `fn_respec` was taken off the DMV by the owner
on 2026-06-12 — *"the talent system was stripped, so a respec could corrupt
player state"* — and is reachable from nothing. Wiring it to the phone would
quietly reverse that call. The built screen has no respec button.

**`RESPEC $250,000` is fiction.** `AP_respec_fee` is
`__SETCONST__(AP_respec_fee, 0)` — it compiles to **0**. Unlearning a talent is
free today. Never draw a price the game will not charge; the built screen reads
the fee live so it follows if the owner ever sets one.

### Gates a tree screen has to show

Each of these mirrors a specific refusal in the native code, so the button label
*is* the validation:

- Honor caps at **15** specialities, Infamy at **21**.
- Honor nodes 11 and 22 are masters — they need every node below them.
- Infamy needs a **rebel licence** (civ only).
- TT Prestige needs **AEMT or higher** (`AP_medicLevel >= 3`).
- Talent 8, Master Bounty Hunter, is refused while you hold Rebel Training.

### The trap that would have eaten every purchase

**Neither learn function saves.** The tree dialogs persist on *close* — they wait
for display 123000 to disappear, then call `ClupdatePartial`. A phone screen
never opens that dialog, so a talent bought on the deck would have been gone at
the next relog with no error anywhere. The sync numbers are not interchangeable:
**4** standard, **14** bh, **16** cop, **22** rebel, **23** medic — and gang
talents do not use `ClupdatePartial` at all, they are broadcast to online members
and written by `APS_fnc_updateGangTalents`.

Worth stating as a general rule for the remaining patterns: **assume no native
function persists.** Ask where the dialog syncs before wiring anything that
mutates.

---

## 2. Pattern G — SUPERSEDED, AND PARTLY WRONG

> **RETRACTED 2026-08-12.** The claim below that "there is no 10-second window"
> is FALSE. `fn_qhCfg`'s header lists the trace window as one of three universal
> levers and `fn_qhEffect` implements it: a targeted hack arms a 10s window on
> the VICTIM, who gets a TRACE INTRUSION action that pings the hacker's position
> back. The original design had this right.
>
> What confused me: there are TWO mechanics called "trace". The victim's 10s
> window, and `APS_fnc_iceTrace`, which instantly pings goggled MaxSec within 650m
> with a location and a crime but never a name. Both are live. I described the
> second and wrongly concluded the first did not exist.
>
> Still correct below: Proxy Chain is a consumable item, not a slotted chip, so a
> reactive BURN button cannot exist. Also correct, and conceded: the two-chip cap.
>
> **Use `PATTERN_G_BRIEF.md` instead of this section.**

### Original text, retained for the record

## 2. Pattern G — ICE TRACE is not a countdown, and Proxy Chain is not a chip

`APS_fnc_iceTrace` is the single authority on "was this hack quiet?", and it
resolves **instantly**. There is no timer in it.

What a cast actually does:

1. If the hacker has an **armed Proxy Chain**, it is burned, the hack is silent,
   and they get a cyan `PROXY BURNED` message. One charge, one hack.
2. Otherwise every **MaxSec officer wearing TAL goggles within 650 m** is pinged
   with the location and *what was hit* — **never the hacker's name**. They still
   have to find the person.

Against the brief:

- **No 10-second window.** Nothing counts down. The 10s is almost certainly
  `Ping.exe`'s blurb — *"paints a target on your map for 10s"* — a different
  mechanic.
- **The victim is not the actor.** Nearby goggled cops are.
- **Proxy Chain is a consumable inventory item, not a slotted chip.** It is armed
  *ahead of time* (`fn_useItem.sqf` sets `AP_proxyActive`) and the server burns
  it automatically at cast.

So `BURN PROXY CHAIN` designs an interaction the game does not have. Replace it
with a **pre-arm state**, which is a better screen anyway — a real decision with
a real cost, taken before the risk:

```
PROXY CHAIN   ● ARMED          (or)   ○ NONE · 2 IN INVENTORY   [ARM ]
```

After a cast that spent it, flip to `NONE` and put `PROXY BURNED — that hack left
no trace` in the status strip. `ICE TRACE` is a **result**, not a live meter:
last cast was `QUIET` or `TRACED`.

Everything else in pattern G — upload/cooldown/range, six slots, server-owned
channel, the glyph mapping — is correct.

---

## 3. The delivery is not shippable HTML

`Armapunk Phone — Patterns.dc.html` is a design-tool export: `<x-dc>` elements
plus a 69 KB `support.js`. Fine for review, and the interactions do work, but the
in-game rule is one self-contained file with no `<script src>`. As with the last
round, the screens get rebuilt against the real page. Not a complaint — just
don't expect a drop-in.

---

## Open questions, answered

**The rem divisor is fixed, not resolution-dependent.** Measured, not inferred: a
`CT_WEBBROWSER` control gets **30 CSS px per UI_GRID unit at dpr 1**, whatever the
screen resolution. The deck's control is 40 × 20 UI_GRID, so the viewport is
**1200 × 600 CSS px at 1080p and at 1440p alike**. A second control at 19 × 9
returned 570 × 270, which is what proves it is a per-unit rule and not a fixed
1200 × 600. So `1rem = width/75` = **16 px, always**. Measure the screen element
anyway for the spool's ~7%, but there is no per-resolution case to handle.

**Casino** — pattern E is right, it is a launcher for five separate games.

**Market favourites** — `favGood` has no consumer. Either build the view or drop
the verb; don't ship a button that writes to nothing.

**Glyphs** — confirmed missing, still ours to fix: bake `ghouse`, `gcuffs`,
`gshield`, `gcarlock`.

---

## What is now in the game

Pattern C is live on the deck at build **b0433**, all six apps, against the
corrected model above:

- one screen, category-switched; branch switcher in the left column
- point-pool *and* XP-currency pool cards
- per-node prerequisite gating, locked nodes shown at reduced opacity
- toggle button labelled from state — `LEARN` / `UNLEARN — $5,000` /
  `PERMANENT` / `UNLEARN ITS CHILD FIRST` / the specific refusal reason
- every mutation persists with the right sync number

Not yet done: patterns D, E, F, G, and the glyph bake.
