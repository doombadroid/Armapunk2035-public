# Phone screens — full design brief

Design the remaining screens of an in-game smartphone for a cyberpunk Arma 3
roleplay server. Four screens are already built and signed off; everything here
must match them. This file is self-contained — you do not need the repo.

**This supersedes `PHONE_REDESIGN_SPEC.md` and `PHONE_WEB_BRIEF.md`.** Both were
written against constraints that turned out to be false. §3 says which.

---

## 1. What already exists — match it, do not redesign it

**Chassis: SPOOL MK-II.** The phone is a baton that unrolls left-to-right off a
spindle when opened and winds shut on Esc. Built, working, and not up for
revision. It is chassis only — it never affects what is inside the screen.

**Four screens, signed off and implemented:** Launcher, Gang roster, Keychain,
Money. Their layout language is the house style:

- a fixed **header** across the top: status dot or `◂ BACK`, `NEON AEGEAN`,
  the app name, a `// BREADCRUMB`, then right-aligned live figures
- a permanent **left rail**, 3.3rem wide: home button, hairline, then the four
  global apps (Sync, Money, Message, Inventory), and `ESC CLOSES` rotated
  vertically at the bottom
- the **app pane** fills the rest

**The row grammar** — build every list from this, it is already implemented:

```
state dot · [glyph] · label · type chip · right-aligned metric · 1–3 action buttons
```

Actions **disable in place and keep their slot** — never hide them. A disabled
action is `#33453c` on `rgba(70,90,81,.35)`, `cursor:not-allowed`. Failure
reasons go in the `.status` strip at the foot of the panel, never a tooltip,
never a modal.

**Glyphs:** 32 exist as inline SVG `<symbol>`s, two-layer (a `stroke-width:7`
`currentColor` body plus a `stroke-width:5` accent on `var(--ia)`) so one symbol
recolours per category. Ask for new ones in the same style; do not switch icon
language.

---

## 2. Tokens — use these, not literals

```css
/* surfaces */
--scr:#050b09  --scr2:#0a1310  --panel:#0c1712  --panel2:#0e1a15
/* accents */
--acc:#c9e21a (acid, primary/money/active)   --acc2:#33ffbb (cyan, live/secondary)
--danger:#ff5a3c   --amber:#ffb020   --ice:#5fd3ff   --violet:#b57bff
--magenta:#ff3d81 (admin only)
/* text */
--ink:#dcefe0   --dim:#7f938a   --faint:#465a51   headers #eaf2ec / #c9d8cd
/* lines */
--line:rgba(201,226,26,.15)     /* every 1px border on screen */
--mono: ui-monospace,'JetBrains Mono','SF Mono',Menlo,Consolas,monospace
--sans: -apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif
```

**Cop recolour (`.tal` on the root).** Same geometry, colours only:
`--scr:#050a10 --scr2:#0a121c --panel:#0c1622 --panel2:#0e1a28
--acc:#f5a623 --acc2:#54b0ff --danger:#ff4d4d --amber:#54b0ff
--ink:#dbe6f2 --dim:#7d8b9e --faint:#3c4a5c --line:rgba(245,166,35,.15)`

**Type.** Mono for every label, number, chip and button. Sans for names and body.
Scale (rem): `.52 .55 .56 .58 .6 .62 .66 .68 .72 .74 .78 .8 .82 1 1.35 1.7 2.3`.
Section labels `.6rem`/`.16em`/uppercase. Row labels `.74–.8rem`. All numbers
`font-variant-numeric:tabular-nums`.

**Spacing** `.3 .35 .4 .45 .5 .55 .6 .7 .85 .9 1 1.4` rem. Body padding `.7rem`,
panel padding `.75–.9rem`, header padding `.62rem 1rem`.

**Radii** screen `.55` · panel `.7` · row/tile `.55` · chip/button `.35` · pill
`.28–.3` rem.

**Heights** list row `2.9rem` · ledger row `2.35rem` · rail button `2.4rem` ·
primary button `2.5rem` · secondary `2.1rem`.

---

## 3. Constraints — corrected, these are measured

Two constraints in the earlier briefs were **wrong**. Design against these.

**Keyboard input WORKS.** Real `<input>`, `<textarea>` and `contenteditable` all
work — every key event fires and `.value` holds the text. The earlier brief
banned them on the strength of a probe that measured nothing. Use real fields:
search-as-you-type, inline rename, filters, chat composers, multi-field forms.
A native prompt exists (`promptText`) but is now optional.

**Animation WORKS.** CSS transitions, `@keyframes` and `requestAnimationFrame`
all render. Frame delivery is dirty-driven, so a static screen costs nothing and
only animating regions pay. Four keyframes already exist and set the tone:
`apPulse` (2.4s status dot), `apScan` (scanlines creeping one 3px period every
5.5s), `apFlicker` (opacity .42→.5 over 6.1s), `apDrift` (a 26%-tall acid glow
band crossing every 11s). Keep motion at that level — CRT texture, not UI
choreography. Hover is `.14s` on border/transform.

**Still true:**

- **One self-contained `.html`**, inline CSS and JS. No `<script src>`, no
  external stylesheet, web font, CDN or icon pack. Images are data URIs or
  fetched from the game with `AP.texture("icons\\foo.paa", 256)`.
- **No network, no storage.** `fetch`, `XHR`, `localStorage`, `IndexedDB` are
  blocked. Every value arrives from the game; settings round-trip through it.
- **The frame is 2:1.** The chassis eats ~7%, leaving a usable screen of
  **960 × 472** at reference scale (~2.03:1). Fit it or scroll exactly **one**
  region; the chrome never moves.
- **No fixed-pixel layout.** `1rem = screen width / 75` (16px at reference).
  Everything in rem.
- **Esc closes the phone** and now plays the roll-shut. No page-level Esc handler.
- **Fetch on open, push on change.** Never poll per frame.

---

## 4. The bridge — you are defining the contract

```js
AP.on("channel", v => render(v));     // replays the last value on subscribe
AP.get("channel");                    // last value or undefined
await AP.call("verb", [args]);        // ~15–21 ms; answers { ok, msg }
await AP.ask("isCop");                // bool, ~half that
AP.handle("name", fn);                // let the game call into the page
await AP.texture("icons\\x.paa", 256);// a game texture as a data URL
```

For each screen, propose the channel(s) it consumes with payload shapes, and the
call verbs it needs with argument and return shapes. The game side is written to
match you.

---

## 5. What to design

**33 entries.** The win is that they collapse into **eight patterns**. Design the
pattern once, then each screen is a payload and a set of verbs.

### Pattern A — LIST (built: Gang roster, Keychain)
Reuse as-is. `Wanted` · `Gangs Online` · `Licenses` · `Captures` · `Group` ·
`Contacts` (from Phone) · `Achieve` · `Titles` · `Quests`

Design work: only the left identity column and the row payload per app.

### Pattern B — DATA (built: Money)
Big figures, meters, ledger. `Stats` (personal totals) is the only other one.

### Pattern C — POINT SPEND — **new, biggest win**
Six apps are the same screen with different trees: `Talents` · `Perks` ·
`Infamy` · `Prestige` · `TT Prestige` · `Honor`. Each shows a pool of unspent
points, a set of specialities, prerequisites, and a spend action. **Design one
tree screen that takes a tree as data.** Getting this right removes six screens.

### Pattern D — COMMERCE — new
`Market` (live prices, two-sided, drift) ·
`Housing` (property list, tax due, pay). Prices, quantities, a confirm step.
Quantity entry: an in-page keypad exists on Money — reuse or use a real field now
that typing works.

### Pattern E — PICKER — new
`Wallpaper` (24 images, needs `AP.texture`) · `Inventory` (virtual items, weight,
drop/give). Grid of tiles, selection state, one action bar.

### Pattern F — COMPOSE — new, now unblocked by keyboard input
`Message` (thread list + composer) · `Phone` (dial/contacts/call state).
Real text fields. This is the pattern the old brief made impossible.

### Pattern G — TERMINAL — **the signature screens, most attention**
`ICEBREAKER OS` (civ hacking), `TAL OS` (cop grid), `Deck OS`. Nearby-target
list, loadout of quickhacks, firewall chips, an upload/progress state, cooldowns.
This is where the fiction lives and where motion is most justified. Give it a
dedicated pass rather than fitting it to another pattern.

### Pattern H — ODDITIES
`Casino` (launcher for blackjack/roulette/slots/hi-lo/coinflip/crash — a menu of
games, the games themselves are separate) · `Browser` (an in-fiction web browser
*inside* the phone — chrome, address bar, page area) · `Settings` (view distance,
brightness, markers, theme, favourites) · `Sync` (a button with feedback, not a
screen) · `Bounty` (request form) · `Summon Vehicle` (star a vehicle in the
Garage app, then one button: recall state — `GARAGED` / `OUT` / `EN ROUTE` /
`ARRIVED` / `FAILED` — distance, ETA, cooldown, no destination to pick since
it always summons to the player's current spot).

**Skip:** `Admin`, `Camera`, `Owner Mode` — staff tools, no player value.

### Gating
Server-side. The launcher receives only the apps this player passes — 22 civ /
17 cop typical. A short category row must still look deliberate; a row with zero
apps is dropped, label included.

---

## 6. Deliverables

Per screen:

- one self-contained `.html`, openable in a browser for review
- a small `AP` stub so it renders standalone with mock data
- the `AP.on()` channels consumed, with payload shapes
- the `AP.call()` verbs needed, with argument and return shapes

Once across the set:

- the shared CSS layer, as real CSS with the tokens named
- any new glyphs, as two-layer `<symbol>`s matching the existing 32
- a note on which screens are the same pattern with different data, so the
  implementation builds the pattern once

Order: **Pattern C first** (six screens for the price of one), then F (newly
unblocked), then D and E, then G on its own.

---

## 7. Do not

- redesign the chassis, header, rail or row grammar — they are built
- introduce a second icon language, a web font, or a colour outside the tokens
- use a modal for an error; the `.status` strip is the pattern
- design fixed-pixel layouts
- exceed the frame without exactly one internal scroll region
- bake changing values into images — all dynamic text is live DOM
- assume typed text or animation are unavailable; both were tested and work
