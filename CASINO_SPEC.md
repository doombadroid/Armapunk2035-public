# Casino — design brief

Design the seven tables of an in-game casino for a cyberpunk Arma 3 roleplay
server. Self-contained; you do not need the repo.

**Every rule and every payload below was read out of the running server code**,
not from a design doc. Previous rounds on this project invented mechanics that
did not exist and had to be rebuilt, so where this brief and your instincts
disagree, this brief is the game.

---

## 1. The one thing that shapes everything

**The page never decides an outcome and never moves money.**

All seven games already run server-side and have for a long time. The page sends
the same *intent* the current dialogs send, the server settles it, credits the
player through its own gated receiver, and pushes back a result payload. Your
job is the table: the felt, the pieces, the reveal, the feel of winning.

Practically: there is no "roll the dice" in your code. You send a bet and you
animate whatever comes back. A spin that finishes before the answer arrives is a
bug; a spin that *waits* and then lands on the server's number is the design.

---

## 2. What already exists

A foundation is in game and working: dialog, bridge, landing screen, bet chips,
and coin flip end-to-end. Reuse or replace it — it is a scaffold, not a
constraint.

**The visual system** comes from the phone you already designed for this
project: same tokens, same mono/sans split, same row grammar where lists appear.
The casino adds a felt green (`--felt:#0d2a1e`) and leans warmer than the phone.

```css
--scr:#050b09  --scr2:#0a1310  --panel:#0c1712  --panel2:#0e1a15
--acc:#c9e21a  --acc2:#33ffbb  --danger:#ff5a3c  --amber:#ffb020  --magenta:#ff3d81
--ink:#dcefe0  --dim:#7f938a  --faint:#465a51  --line:rgba(201,226,26,.15)
--felt:#0d2a1e
--mono: ui-monospace,'JetBrains Mono','SF Mono',Menlo,Consolas,monospace
--sans: -apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif
```

There is already a **WebGL fragment-shader backdrop** — felt weave, a drifting
warm key light, an acid rim, slow motes, throttled to 30 fps. Replace it if you
can do better; it is eighty lines and not precious.

---

## 3. Technical constraints — measured, not assumed

**WebGL2 is real and hardware-accelerated.** Probed in the live control:
`ANGLE (AMD Radeon 8060S, radeonsi strix_halo ACO, OpenGL 4.6)`, canvas 2D and
WebGL both draw *and read back*, sustained **60.2 fps** on a busy 2D scene.
`OffscreenCanvas` and `AudioContext` present. `devicePixelRatio` 1.

So canvas and shaders are both on the table. But:

**No libraries.** No `<script src>`, no `<link>`, no CDN, no fonts, no network of
any kind. The page has no resolvable base URL — a `src` silently resolves to
nothing. three.js would have to be inlined whole. In practice: raw GL for
full-screen effects (a quad and a fragment shader needs no matrices), canvas 2D
for game pieces, DOM for anything with text.

**No storage.** `localStorage` and `IndexedDB` are unavailable. Every value comes
from the game and goes back to it.

**Frame delivery is dirty-driven.** A still screen costs nothing; a full-bleed
animation marks the whole surface dirty every frame, on top of Arma's own
rendering. This is the real budget. Animate *during* a spin, settle to still
after. Say in your handoff what animates and roughly how much surface it covers.

**Typed input works** — real `<input>`, every key event. Use it for a custom bet
amount if you want one.

**The frame** is a 40×20 UI_GRID browser control = **1200 × 600 CSS px at dpr 1,
at any screen resolution**. `1rem = width/75` = 16px. One internal scroll region
at most; the chrome never moves.

**Esc closes the dialog.** No page-level Esc handler.

---

## 4. The seven games, as the server actually plays them

Bets are clamped **$10,000 – $500,000** server-side on every game. The existing
chip ladder is `10k · 50k · 100k · 250k · 500k`.

### COIN FLIP
Pick heads or tails. **Win probability 0.46**, pays **2×**. That is the house
edge and it should not be hidden — but nor does it need a number on screen.

`play [bet, pick]` — pick `0` heads, `1` tails
→ `[win, pick, face, bet, ret, net]` — `face` is `0`/`1`, and is the side the
player experiences: on a win it equals their pick, on a loss it is the other.

### SLOTS
Three reels, five symbols, weighted `[6,5,4,3,2]` — so symbol 4 is rarest.
Three-of-a-kind pays, indexed by symbol: **8× · 12× · 22× · 45× · 150×**.
Anything else pays nothing. There is a configurable jackpot nerf that can turn a
natural 150× into a near-miss, so **design the near-miss** — two matching and a
third that lands one position off is a real and frequent outcome.

`play [bet]` → `[[r1, r2, r3], mult, bet, ret, net]`

### ROULETTE
38 pockets: `0`, `00` (sent as **37**), and 1–36. Outside bets pay **2×**, dozens
**3×**, a straight number **36×**.

Bet types: `red · black · odd · even · low` (1–18) · `high` (19–36) ·
`dozen1 · dozen2 · dozen3 · straight`

`play [bet, betType, betVal]` — `betVal` only used by `straight` (0–37)
→ `[spin, isRed, isGreen, win, bet, ret, net, betType]`

### HI-LO
A card is dealt; call the next **higher or lower**. Each correct call multiplies
the pot, **capped at 30×**. Cash out any time. Busting loses everything —
except that cashing out at ≤1.0× returns **half the bet**, which is the
consolation and should read as one.

`deal [bet]` · `hi []` · `lo []` · `cash []`
→ `["play"|"bust"|"cashout", card, mult, bet, pot, prevCard, tag]`
Cards are `0–51`: suit = `floor(c/13)` in `C D H S`, rank = `c mod 13` in
`2 3 4 5 6 7 8 9 10 J Q K A`.

### CRASH
A multiplier climbs from 1.00× and busts at a server-chosen point — **7% chance
of an instant bust at 1.00×**, otherwise `0.93/(1−r)` capped at **20×**. Cash out
before it goes. The bust point is decided the moment you bet; the climb is
theatre, and the tension is entirely in the leaving.

`deal [bet]` · `cashout []`
→ `["start", bet, startTime]` · `["cashout", mult, bet, ret]` ·
  `["bust", bustMult, bet, 0]`

This is the one table that animates continuously. Budget for it.

### THE WHEEL
One spin, **$50,000** (server-authoritative — never a client literal), with a
**free daily spin** the server tracks. Twelve segments in this exact ring:

```
cash · bust · cash · ifrit · cash · bust · cash · qilin · cash · bust · cash · blackfish
```

`cash` pays $1,000–$200,000 on a cubic curve, so **small wins are the norm and a
big one is rare** — the curve is the drama. `bust` is a server-wide event. The
three vehicles are real cars: Ifrit ($1.25m), Qilin ($2m), Blackfish ($5m).

`spin [useFree]` · `checkfree []`
→ `["spin", segment, prize, cashWon, xpWon, label, wasFree]` ·
  `["status", freeAvailable, cost]`

### BLACKJACK
Its own engine, its own dialog today. Hit, stand, double, split — splits mean
**multiple hands on screen at once** with one active.

`deal [bet]` · `hit` · `stand` · `double` · `split`
→ `["render", [handsView, dealerView, activeIdx, actions, "player"|"resolved"]]`
`actions` is the list of legal moves right now — the table should offer exactly
those and nothing else.

---

## 5. What the screens have to answer

In priority order, for every table:

1. What is my bet, and can I change it here?
2. What did I just win or lose — as a number, immediately legible
3. What is my balance now
4. Whose turn is it / what can I do right now
5. What happened last time

Bank balance is always visible. Refusals ("you can't gamble in combat", "not
enough in the bank") go in a status strip, never a modal.

---

## 6. The bridge

```js
AP.on("casino",    v => render(v));   // balance, bet, chips, limits, gate, wheel state
AP.on("casResult", r => settle(r));   // { game, payload } — the server's answer
await AP.call("casBet",  [amount]);   // clamped 10k–500k both ends
await AP.call("casPlay", [game, action, args]);
```

`casPlay` answers immediately and optimistically — it means *sent*, not
*settled*. The real answer arrives on `casResult`. A table that treats the
`casPlay` reply as an outcome will be wrong.

`casino` carries a **gate** string: empty means play, non-empty is the reason
(cell / restrained / downed / in combat / wrong side) and every bet button
should be disabled with it showing.

---

## 7. Deliverables

- One self-contained `.html` per table, plus the landing — inline CSS and JS,
  openable in a browser for review
- A small `AP` stub with mock data so each renders standalone
- Anything shared (the backdrop, chips, the bet bar, card rendering) as one
  file the tables include by copy, since there is no `<link>`
- A note per table: what animates, how much surface, and whether it settles to
  still

---

## 8. Do not

- decide an outcome, roll anything, or compute a payout — the server has already
  done it before your animation finishes
- treat the `casPlay` reply as a result
- draw a bet the server would refuse; the clamp is 10k–500k
- hide the wheel's cost or invent a different one — it is server-authoritative
- use a library, a web font, or any external asset
- animate continuously on a table that has settled; the frame budget is shared
  with the game rendering behind it
