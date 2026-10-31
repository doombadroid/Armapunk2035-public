# The remaining screens — design brief

Design the ~40 in-game screens that have not yet been converted to HTML for a
cyberpunk Arma 3 roleplay server (**Armapunk 2035**, Malden). Seventeen screens
are already built and signed off; everything here must match them.

**This file is self-contained. You do not need the repo.**

It extends `PHONE_SCREENS_SPEC.md`, which covered the phone. Where the two
overlap — tokens, row grammar, bridge contract — they agree, and this one adds
the constraints that only apply to the full-size dialogs.

**`uidesign.md` is superseded.** It documents the NIGHT CITY palette (cyan
`#37E8F0` / magenta on graphite `#1E2735`). That direction was replaced by the
acid-on-black-green deck palette in §2. If you find NIGHT CITY tokens in older
docs or in a native dialog's `colorText[]`, they are the thing being replaced,
not a reference.

---

## 0. What to produce

**Three alternates per screen.** The house style in §2 is fixed and not an axis —
alternates must differ in **structure**, not skin. Vary:

- **Information density** — one screen that trusts a table, one that trusts cards
- **Navigation model** — tabs across the top vs. a left rail vs. master–detail
  vs. a single scroll
- **Where the commit action lives** — inline per row, a persistent footer bar, or
  a confirm step
- **What gets promoted** — for a shop, is the hero the item art, the price, or
  the stock count

Three alternates that are the same layout with different corner radii are one
alternate. If a screen genuinely has one sane layout, say so and ship two.

**Deliverable per screen:** three self-contained `.html` files named
`<screen>-a.html`, `<screen>-b.html`, `<screen>-c.html`, each with hard-coded
representative sample data (see §6 for the shape), plus a one-paragraph note per
alternate saying what it optimises for and what it gives up.

**Plus one `index.html` contact sheet** linking every alternate, grouped by
screen, so the whole set can be reviewed in one pass.

**Order.** Tier 1 (§5) first, in the order listed — that is roughly descending
by how often a player touches the screen. Do not start Tier 2 until Tier 1 is
reviewed; the picks from Tier 1 will constrain Tier 2.

---

## 1. What already exists — match it, do not redesign it

Sixteen screens are live: the phone/deck (with ~21 apps inside it), the casino
(a landing plus nine game tables), the virtual shop, the armoury, the clothing
fitting room, loot crates, the map, storage, the car radio, the
quickhack breach screen, the visor, the MaxSec duty terminal, the HUD, the
landing screen and the quest journal.

**The row grammar** — build every list from this, it is already implemented:

```
state dot · [glyph] · label · type chip · right-aligned metric · 1–3 action buttons
```

Actions **disable in place and keep their slot** — never hide them. A disabled
action is `#33453c` on `rgba(70,90,81,.35)`, `cursor:not-allowed`. Failure
reasons go in a `.status` strip at the foot of the panel, never a tooltip, never
a modal.

**Glyphs** are inline SVG `<symbol>`s, two-layer (a `stroke-width:7`
`currentColor` body plus a `stroke-width:5` accent on `var(--ia)`) so one symbol
recolours per category. 32 exist. Draw new ones in the same language; do not
switch icon sets.

**Chrome does not move.** Header and any rail are fixed; exactly one region
scrolls.

---

## 2. Tokens — use these, not literals

```css
/* surfaces */
--scr:#050b09  --scr2:#0a1310  --panel:#0c1712  --panel2:#0e1a15
/* accents */
--acc:#c9e21a (acid: primary, money, active, focus)
--acc2:#33ffbb (cyan: online/live, secondary action)
--danger:#ff5a3c   --amber:#ffb020   --ice:#5fd3ff (standing/records)
--violet:#b57bff (progress)          --magenta:#ff3d81 (admin ONLY)
/* text */
--ink:#dcefe0   --dim:#7f938a   --faint:#465a51   headers #eaf2ec / #c9d8cd
/* lines */
--line:rgba(201,226,26,.15)     /* every 1px border on screen */
--mono: ui-monospace,'JetBrains Mono','SF Mono',Menlo,Consolas,monospace;
--sans: -apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;
```

**Cop recolour (`.tal` on the root).** Same geometry, colours only:
`--scr:#050a10 --scr2:#0a121c --panel:#0c1622 --panel2:#0e1a28
--acc:#f5a623 --acc2:#54b0ff --danger:#ff4d4d --amber:#54b0ff
--ink:#dbe6f2 --dim:#7d8b9e --faint:#3c4a5c --line:rgba(245,166,35,.15)`

Any screen a police player opens must work in both. Never hard-code an accent.

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

## 3. Constraints — these are measured, not assumed

**The frame is different from the phone.** These are full dialogs, not a handset.
The standard is **40 × 22 grid units, about 1.82:1**, and a few are 40 × 20. Do
not design to the phone's 2:1 `960 × 472`.

Pages set their own rem basis off the viewport —
`html{font-size:clamp(9px,1.22vw,22px)}` is the pattern in use. **No fixed-pixel
layout anywhere.** Everything in rem, so the same page survives 1080p and 4K.

Most existing pages draw a centred panel inside the frame rather than bleeding to
the edges (`width:26rem;max-width:94vw;height:94vh;max-height:40rem`). That is a
convention, not a rule — a garage or an exchange may well want the full frame.
Say which you chose and why.

**Keyboard input WORKS.** Real `<input>`, `<textarea>` and `contenteditable` all
work; every key event fires and `.value` holds the text. Use real fields:
search-as-you-type, inline rename, numeric amount entry, filters. A native prompt
overlay exists as a fallback but is optional.

**Animation WORKS.** CSS transitions, `@keyframes` and `requestAnimationFrame`
all render. Frame delivery is dirty-driven, so a static screen costs nothing and
only animating regions pay. Four keyframes set the tone and already exist:
`apPulse` (2.4s status dot), `apScan` (scanlines creeping one 3px period every
5.5s), `apFlicker` (opacity .42→.5 over 6.1s), `apDrift` (a 26%-tall acid glow
band crossing every 11s). Keep motion at that level — **CRT texture, not UI
choreography.** Hover is `.14s` on border/transform.

Motion budget matters more here than it looks: the embedded browser renders at
1 fps for any player who has not turned off Steam's GPU-accelerated web
rendering. Nothing may depend on animation to be legible or operable.

**Still true, all of it:**

- **One self-contained `.html` per alternate.** Inline CSS and JS. No
  `<script src>`, no external stylesheet, web font, CDN or icon pack.
- **No network, no storage.** `fetch`, `XHR`, `localStorage`, `IndexedDB` are all
  blocked. Every value arrives from the game; settings round-trip through it.
- **Game art comes from the game.** `AP.texture("icons\\foo.paa", 256)` returns a
  data URL for any `.paa` in the game filesystem — weapon and vehicle pictures,
  item icons, map tiles. Eight live pages use it. Everything else is CSS or an
  inline SVG. No raster assets in the file.
- **Esc closes the dialog.** No page-level Esc handler.
- **Fetch on open, push on change.** Never poll per frame.

---

## 4. The bridge — the contract you are designing against

Four directions, and nothing else:

```js
AP.on("money", v => render(v));        // game pushes; replays last value on subscribe
AP.get("money");                        // last value, or undefined
const info  = await AP.call("gangInfo"); // page asks game, ~15-21 ms
const isCop = await AP.ask("isCop");     // boolean only, ~half that
AP.handle("selectedRow", () => state.selected);  // game can now read from the page
const url   = await AP.texture("icons\\x.paa", 256);
```

Design the payloads you want and name them in your notes — the SQF side is
written to fit the page, not the other way round. Prefer **one push per screen
with everything on it** over six chatty calls; a round trip is ~20 ms and a
screen that makes forty of them on open is visibly slow.

**Every mutation is a request, never a fact.** The page never decides that money
moved, an item transferred or a vehicle spawned. It sends intent, the server
validates, and the answer comes back as a push. So every commit action needs
three visual states — idle, in-flight, and refused-with-a-reason — and the
refusal string comes from the game. Do not design a screen whose success state is
the only one drawn.

---

## 5. The screens

Content below is the current native screen's actual vocabulary — the labels,
figures and actions that exist today. Treat it as the functional floor, not a
layout. If a screen is doing something stupid, say so; several are.

### Tier 1 — daily, and worth the most

**1. Grand Exchange** *(three native dialogs, ~530 lines — the biggest win)*
The player-to-player marketplace. It is the centre of a deliberately closed
economy: the design goal is that nothing is bought from an NPC, everything is
crafted by a player and sold here.
- *Browse:* category → product → listings. Per listing: seller, quantity, unit
  price, total. Actions: **Purchase**, **Check Availability**, **Refresh**.
- *Sell:* create a listing from inventory **or from a vehicle trunk** (bulk
  materials matter), with a quantity and a price. 5% listing fee. Caps per
  category. Actions: **Retract Listing**.
- *Storage:* a separate screen holding bought goods and expired listings.
  Actions: **Retrieve Item(s)**, **Re-List Listing**. 7-day expiry.
- Vehicles list differently from items — a vehicle listing transfers ownership.
- The single most important thing to fix: a player should be able to answer
  "what is this worth and is anyone buying" without three navigations.

**2. Fabricator** *(new feature, still native)*
A 3D printer or gunsmith bench the player places in their house. Player-facing
model: materials and time, never money.
- Header: fabrication **level**, XP toward next, and the cap this machine prints
  to. Machines have tiers with different parallel job slots and speed.
- Recipe list, ~579 recipes, searchable. **Row colour encodes the XP rule, not
  affordability**: green earns progress, red is above your level or the machine's
  cap, dim is printable but you have outgrown it. Keep that; it is the thing that
  makes the ladder legible.
- Detail panel: ingredient list green/red by what you hold, print time, and the
  recursive material total (a recipe listing 34 filament may contain 71).
- A job panel: one row per slot, recipe, quantity, time remaining, **Collect**.
- Modes: **Print**, **Buy Schematics** (the one place money appears, in a
  separate currency), **Burn to Shard** (trade a known schematic away).

**3. Vehicle garage** *(351 lines + a gang variant)*
- Two lists: **STORED** and **AVAILABLE**, plus a **VEHICLE INFORMATION** panel.
- Actions: **Get Vehicle**, **Sell Vehicle**, **Repair**, **To Gang**, **Mod
  Vehicle** / **Purchase Mods**.
- Mods are a second screen's worth on their own: License Plate, Paint Job,
  Custom Horn, Nitrous, Tracker, Alarm, Hardened Locks, Doors, Autopilot,
  Vehicle Handling, Physical Storage — each with an **Upgrade Cost**.
- Vehicle art via `AP.texture` on the class picture.

**4. Trunk** *(244 lines)*
Two-column transfer: **ON YOU** ↔ **IN STORAGE**, with **TAKE**, **STORE**,
**Swap**, **Drop**. Both sides are weight-capped and the cap is the whole
tension. Physical items and virtual items are different lists today; ask whether
they should be.

**5. Vehicle shop** *(155 lines)* — the one shop still native.
Browse by class, **CONFIGURE** (colour/variant), **TOTAL**, **PURCHASE**. Should
match the armoury and virtual shop already built, so this one is closer to a port
than a design — but it needs the configure step they do not have.

**6. Player inventory / settings** *(194 + 66 lines)*
Currently a hub that is really six screens wearing one hat: **CURRENT ITEMS**
(with **USE**, **Give**, **Remove**), **LICENSES**, **MONEY STATS**, plus
launcher buttons into Cell Phone, Key Chain, My Gang, Wanted List, Settings and
Sync Data. Most of those launchers now open the phone. The real question for this
one is what should remain here at all versus move into the deck.

**7. House menu** *(218 lines + a keys screen)*
**HOUSE MANAGEMENT**: View/Unlock Storage, Upgrade Physical Storage, Upgrade
Virtual Storage, Manage Keys / View Key Holders, Rename House, Add Helipad,
Turn Lights On, Malden Makeover (furniture), List for Sale, Sell to Market.
Keys screen: Give Access, Remove, Change Locks.
Furniture placement is where players buy and place fabricators, so this screen
now feeds a production chain and deserves better than a button stack.

**8. Gang menu** *(409 lines + bank 87 + history 45)*
**Gang Management**: roster with Promote, Demote, Kick, Invite, Set Tag,
Transfer Leadership/Ownership, Leave, Disband. **Gang Creation**. **Gang War
Management**: Challenge, Accept, Surrender, Wars list. **Gang Bank**: Deposit,
Deposit All, Withdraw, Transfer, Bank History.
Note the deck already has a read-only "My Gang" roster app — this is the screen
where things actually change, and the two must not contradict each other.

**9. Group menu** *(522 lines — the largest non-admin dialog)*
Temporary squads, separate from gangs. Create Group, Current Groups (browse),
Join with password, Set Pass, Lock/Unlock, Set Leader, Kick, Leave.
522 lines for what is a list and five buttons. The strongest candidate in the set
for "the redesign is mostly deletion".

**10. ATM / bank** *(97 lines)*
Deposit, Deposit All, Withdraw, Transfer, and a free debit card. Small screen,
touched constantly. Worth a card-thin layout rather than a dialog.

**11. Loadouts** *(233 lines)*
**AVAILABLE LOADOUTS** list, **LOADOUT PREVIEW**, Save, Delete, Equip. Priced in
both currencies. Preview is the interesting problem — it currently shows a text
list where it wants to show a figure.

**12. Spawn selection** *(85 lines)*
A map with spawn points and a **DEPLOY** button. First screen of every session,
so it sets the tone for everything else. Currently the plainest screen in the
mission.

**13. Factory** *(80 lines)* — vehicles only now, 25 recipes, materials not cash.
Same shape as the fabricator's print tab but a much shorter list. Consider
whether it should simply *be* the fabricator's vehicle tab; say what you think.

**14. Chop shop** *(79 lines)* — Claim Vehicle, Sell Vehicle. Tiny, criminal,
should feel like it.

**15. Vehicle skin shop** *(65 lines)* — a texture picker. Wants to be a grid of
`AP.texture` previews and nothing else.

### Tier 2 — situational, design after Tier 1 is picked

Give these one alternate each unless the screen is obviously contested.

- **Cyberdeck natives still open despite the web breach/visor screens existing:**
  `qh_console` (the pick/load/fire console), `vr_dock`, `tal_home`,
  `cyberdeck_home`, `cyberdeck_ring`, `ring_loadout`. Work out what the two web
  screens already cover before designing — this may be a consolidation, not six
  screens.
- **Governor:** law editor, voting, candidate registration, government bank.
- **Police / medical:** intake (booking), ticket issue and pay, charge picker,
  medic response.
- **Property:** suites (apartment tower), the native storage vault that still
  exists alongside the web one.
- **Progression and onboarding:** welcome screen, tutorial, login bonus, player
  stats, treasure map, duel arena.
- **Small utilities:** spray menu, hex icon picker, GPS search, radial radio,
  cell call, broadcast, simple shop, item pickup, drone treatment, light switch,
  economy readout, map-region picker.

### Tier 3 — explicitly out of scope

Do not design these, and say so if asked:

- **Admin tooling** (956-line admin menu, event menu, spectate settings). Staff
  tools, high density, low aesthetic value, and changing them risks live moderation.
- **HUDs** — chat, messages, toasts, gang fortress, radio, GPS, progress bar,
  loading background. These render *over* gameplay rather than in a dialog and
  are a different technical problem; the one web HUD that exists was built
  separately for that reason.

---

## 6. Sample data

Hard-code representative data in each alternate — an empty screen hides every
layout problem worth catching. Specifically:

- **Long names.** Player names, gang names and vehicle classes overflow. Include
  at least one row that is far too long, and show what you do about it.
- **Big numbers.** Money runs to eight digits and is formatted with separators.
  A second currency runs to four decimal places. Both appear on the same screens.
- **Empty and full.** Show a list at zero rows and one at 200. Both are real.
- **A refusal.** Every screen needs its "the server said no" state drawn, with a
  sentence in it.
- **Both palettes** for any screen a police player opens.

---

## 7. Naming

The project was **LooneyBin** and is now **Armapunk 2035**; the map is Malden.
Several native screens still say the old name in their titles — "LoonyBin
Exchange", "LoonyBin Personal Bank", "LOONYBIN LOADOUT SYSTEM". Do not carry
those across. Use Armapunk naming, or better, in-world names for in-world
things — a bank in a cyberpunk city has a brand, not a server name.

Never reference any other Arma server, its staff or its feature names anywhere.
