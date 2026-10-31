# INVENTORY — the combined I screen — design brief

Design the screen that opens when a player presses **I**: one HTML page that
replaces Arma 3's native inventory display and shows, in one place, everything
the player carries — the **physical gear** the engine tracks (clothes, weapons,
attachments, magazines, the contents of uniform / vest / backpack) and the
**virtual bag** the mission tracks (340 role-play items: food, drugs, tools,
chips, materials). Today those are two screens with two vocabularies. This brief
makes them one.

**This file is self-contained. You do not need the repo.** It extends
`UI_DESIGN_HANDOFF.md` (full-size dialogs) and `PHONE_SCREENS_SPEC.md` (the
phone). Tokens, row grammar and bridge contract are repeated here so nothing has
to be looked up.

Decided by the owner, 2026-09-02, not open for alternates:

- **I opens this screen.** Y still opens the phone. T still opens storage.
- **Scope: self + nearby engine cargo.** Left is *you*; right is what is within
  reach — the ground pile and, when a vehicle or crate is in reach, its real
  engine cargo (what native I shows today). Virtual trunks of houses and
  vehicles are NOT on this screen — they stay on the STORAGE screen (T).
- **Frame: windowed, 40 × 22 grid × the player's deck scale, centred.** Same
  convention as the armoury and storage screens. The world stays visible behind.
- **Drag-and-drop is the primary gesture**, and every drag has a no-drag path.

---

## 0. What to produce

**Three structural alternates**, per the standing rule of `UI_DESIGN_HANDOFF.md`
§0: same house style, different structure. Vary at least:

- **How the body is drawn** — a paper-doll of equipment slots with containers
  beside it, vs. a slot rail with one big shared list, vs. three container
  columns with the worn item as each column's header.
- **Where the virtual bag lives** — a fourth container that sits with the
  physical ones, a tab on the same column, or its own half of the screen.
- **Where quantity lives** — a stepper in a side panel, chips on the tile
  (`+1` / `STACK`), or a scrubber that appears while dragging.
- **Where refusals land** — a status strip at the foot, an inline flash on the
  tile that snapped back, or both.

Deliverable per alternate: one self-contained `inventory-a.html` / `-b.html` /
`-c.html` with the sample data from §7 hard-coded, plus a one-paragraph note on
what it optimises for and what it gives up. If drafting on a canvas first, each
alternate is one artboard at **1600 × 880** (that is 40 × 22 grid units at 40 px;
the ratio, 1.82:1, is the thing that matters). Then one `index.html` contact
sheet.

State in your notes which panel is *the* scroll region. Exactly one scrolls.

---

## 1. What the player is managing — three inventories, one screen

A designer has to know these are different things, because the rules differ.

### 1a. Physical gear (engine-owned)

Arma tracks this. Slots and containers, capacity **by mass, not by cell count** —
there is no grid of squares; every container is a list with a load bar.

**Equipment slots (one item each):**

| Slot | Holds | Notes |
|---|---|---|
| Primary | rifle / SMG / shotgun | carries up to 4 attachments + a loaded magazine |
| Launcher | RPG-class | rare on this server |
| Handgun | pistol | attachments + loaded magazine |
| Uniform | clothing | **is a container** (typ. cap 40) |
| Vest | vest / harness | **is a container** (typ. cap 100–160) |
| Backpack | pack | **is a container** (typ. cap 160–320; Carryall 320) |
| Headgear | hat / helmet | |
| Facewear | glasses / mask / bandanna | |
| Binocular | binoculars / rangefinder | |
| Assigned ×6 | map · GPS · radio · compass · watch · night-vision | fixed slots; all players spawn with map, compass, watch, GPS |

**Container contents:** magazines (each one carries its own round count — a
half-empty mag is a distinct object), attachments (optic, suppressor, pointer,
bipod), first-aid kits, tools, spare clothing, spare backpacks (a backpack in a
backpack is allowed by the engine). Each item has a **mass**; the container has a
**max load**; the load bar is `sum(mass) / max`. Typical masses: magazine 8,
first-aid kit 4, optic 4–10, suppressor 6. These come from game config at
runtime; the page never hard-codes them.

**Weapon attachments** are slots on the weapon: dragging an optic onto the rifle
mounts it; dragging a magazine onto the rifle loads it. The rifle tile therefore
needs an expanded state showing its four attachment sockets and its loaded mag.

**Stacks:** the engine has none. The page *presents* identical full magazines and
identical items as one tile with `×N`; partial magazines never stack (show the
round count, e.g. `17/30`).

**Swapping worn containers** (dragging a new uniform / vest / backpack onto the
slot): the engine moves the old one's contents into the new one as far as they
fit; anything that does not fit **spills to the ground pile**. The displaced
garment goes back to where the new one came from if it fits, else the ground.
This is the one interaction that can move many things at once, and the design
must show the consequence — before (a hover preview: "3 items will spill") or
after (a status line: "3 items spilled to the ground"). Pick one and say why.

### 1b. The virtual bag (mission-owned)

The mission tracks this. ~340 item types: food and drink, drugs and their
paraphernalia, tools (bolt cutters, lockpicks, repair kits), cyberdeck chips,
raw and processed materials, placeables (cones, barriers, a boom box), dirty
money. Each type has a **name, weight, icon, sell price, an `illegal` flag** and
usually a one-line description. The bag is a **single weight-capped list**:

- `LOAD current / max`. Base max **64**; plus **round(backpack maxLoad ÷ 10)**
  when a backpack is worn (Kitbag → 88, Carryall → 96, hard cap 96 for the
  Carryall); talents add +24 and +12. Police and medics on duty sit at 96.
- Over the cap the player is **forced to walk**. Show an OVERWEIGHT state.
- Quantities are integers. Stacks exist natively (`apple × 6`).
- Actions: **USE** (eat, arm a chip, open a kit — a 200-line game-side switch
  decides what each does), **GIVE** (to a nearby player, pick from a list),
  **DROP** (creates a suitcase on the ground). No "equip".
- Some items cannot be dropped (debit card, scalps). Some are `illegal` — flag
  them; police searches key off it.
- A read-only oddments group also exists: loot-crate keys and infamy scalps.
  They have no actions and today render as chips under the bag. Keep them out
  of the actionable list.

**Virtual items never enter a physical container, and physical items never
enter the bag.** A drop of one onto the other is an invalid target — draw it as
one.

### 1c. What is in reach (the right side)

- **GROUND** — one merged pile within ~5 m: engine weapon-holders (dropped
  physical gear) **and** suitcases (dropped virtual items). One list, two item
  kinds, each kind only draggable to its own home. Suitcases despawn (20–30 min,
  shown as a countdown when under 5 min); the page gets `despawn` seconds.
- **CONTAINER** — present only when a vehicle or crate is in reach and the game
  allows it (unlocked, or you hold keys, or you are police; not being seized;
  not on an event timer; nobody else is in it — one player at a time). Engine
  cargo only: weapons, magazines, items, backpacks, each with mass; the
  container has one max load. Header names the thing (`OFFROAD · 4 items · 212 /
  1000`). Its **virtual trunk is not here** — a one-line pointer to T is
  enough.

Nothing else is ever in reach on this screen: other players, bodies and their
backpacks keep their existing flows.

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
`--scr:#050a10 --scr2:#0a121c --panel:#0c1622 --panel2:#0e1a28 --acc:#f5a623
--acc2:#54b0ff --danger:#ff4d4d --amber:#54b0ff --ink:#dbe6f2 --dim:#7d8b9e
--faint:#3c4a5c --line:rgba(245,166,35,.15)`. Police open this screen more than
anyone; it must work in both. Never hard-code an accent.

**Type.** Mono for every label, number, chip and button. Sans for item names and
descriptions. Scale (rem): `.52 .55 .56 .58 .6 .62 .66 .68 .72 .74 .78 .8 .82 1
1.35 1.7 2.3`. Section labels `.6rem`/`.16em`/uppercase. Row labels `.74–.8rem`.
All numbers `font-variant-numeric:tabular-nums`.

**Spacing** `.3 .35 .4 .45 .5 .55 .6 .7 .85 .9 1 1.4` rem. **Radii** screen `.55`
· panel `.7` · row/tile `.55` · chip/button `.35` · pill `.28–.3` rem.
**Heights** list row `2.9rem` · ledger row `2.35rem` · primary button `2.5rem` ·
secondary `2.1rem`.

**Row grammar** (already implemented across 17 screens — build lists from it):

```
state dot · [glyph or item art] · label · type chip · right-aligned metric · 1–3 action buttons
```

Actions **disable in place and keep their slot** — never hide them. Disabled is
`#33453c` on `rgba(70,90,81,.35)`, `cursor:not-allowed`. Failure reasons go in a
`.status` strip, never a tooltip, never a modal.

**Item art comes from the game.** Every tile shows the item's real picture —
weapon and gear art from Arma's config, virtual item icons from the mission —
via `AP.texture(path, size)` (§4). Weapon pictures are wide and left-aligned
inside a large transparent canvas; the bridge trims them to their alpha box
before the page sees them. Design tiles for a **square** thumbnail and a **wide**
one (weapons). No raster in the file.

**Glyphs** for slot placeholders (empty uniform / vest / pack / head / eyes /
primary / handgun / binocular / the six assigned) are inline SVG `<symbol>`s in
the two-layer language (a `stroke-width:7` `currentColor` body plus a
`stroke-width:5` accent on `var(--ia)`). 32 exist; draw the ones you need in the
same language.

---

## 3. Constraints — measured, not assumed

- **Frame** 40 × 22 grid ≈ 1.82:1, windowed, world visible behind. Pages set
  their rem basis off the viewport: `html{font-size:clamp(9px,1.22vw,22px)}`.
  **No fixed-pixel layout anywhere.** The player can scale the window (deck
  scale slider); everything is rem.
- **Input is left mouse button and wheel ONLY.** The embedded browser never
  delivers right-click, and **modifier state is stripped from page events**
  (`e.shiftKey` is always false). The dialog mirrors Shift/Ctrl/Alt into
  `window.__mods = {s,c,a}` over the bridge, so a page *can* read them — but
  treat modifiers as an accelerator, never the only path. **No right-click
  menus. No hover-only affordances for anything essential.**
- **Drag is pointer-event drag**, not the HTML5 drag-and-drop API:
  `pointerdown` → `setPointerCapture` → `pointermove` → `pointerup`, with a
  single absolutely positioned ghost element. The live map page already does
  this and it works in game.
- **Do not rebuild markup that has not changed.** A push arrives after every
  mutation; if the page re-renders a list with `innerHTML` while the player's
  button is between mousedown and mouseup, the click is lost. Patch tiles in
  place; keep stable element identity per item id.
- **Keyboard input WORKS** — a search field over the bag (340 types) is
  expected. Esc closes the dialog (game-side; no page Esc handler).
- **Animation WORKS but is budgeted.** CSS transitions, keyframes and rAF all
  render; frame delivery is dirty-driven, so a static screen costs nothing.
  House keyframes exist: `apPulse` (2.4 s dot), `apScan`, `apFlicker`,
  `apDrift`. CRT texture, not UI choreography. Hover `.14s`. Nothing may depend
  on animation to be legible — some players run the browser at 1 fps.
- **One self-contained `.html`.** Inline CSS and JS. No `<script src>`,
  stylesheet, web font, CDN, icon pack, `fetch`, `XHR`, `localStorage`.
- **Fetch on open, push on change.** Never poll.

---

## 4. The bridge — the contract you design against

```js
AP.on("inv", v => render(v));           // game pushes; replays last value on subscribe
const r = await AP.call("invMove", [...]); // page asks; ~20 ms; -> { ok, msg }
const url = await AP.texture("icons\\apple.paa", 128);   // .paa -> data URL
```

**Every mutation is a request, never a fact.** The page sends intent; the game
validates (capacity, ownership, distance, legality) and answers with a fresh
push. So every commit action has **three visual states — idle, in-flight,
refused-with-a-reason** — and the refusal string comes from the game. A dragged
tile that is refused **snaps back** and the reason lands in the status strip.
Do not design a screen whose only drawn state is success.

One push carries the whole screen. Prefer it over chatty calls.

### 4a. Push — `inv`

```js
AP.on("inv", {
  you: {
    name: "Rook Delacroix", side: "civ",            // "civ" | "cop" | "medic" — "cop" adds .tal
    flags: { overweight:false, restrained:false, inVehicle:false },
    slots: {                                         // null = empty slot
      primary:  { id:"w1", cls:"arifle_TRG21_F", name:"TRG-21 5.56 mm", wide:true,
                  icon:"\\A3\\Weapons_F\\Rifles\\TRG20\\Data\\UI\\gear_trg21_x_ca.paa",
                  mass:80, mag:{ id:"m9", cls:"30Rnd_556x45_Stanag", name:"5.56 mm 30Rnd", ammo:23, cap:30 },
                  sockets:{ optic:{ id:"a1", cls:"optic_Aco", name:"ACO (Red)", icon:"..." },
                            muzzle:null, pointer:null, bipod:null } },
      launcher: null,
      handgun:  { id:"w2", cls:"hgun_Pistol_heavy_01_F", name:"4-five .45", wide:true, icon:"...",
                  mass:20, mag:{ id:"m10", cls:"11Rnd_45ACP_Mag", name:".45 ACP 11Rnd", ammo:11, cap:11 },
                  sockets:{ optic:null, muzzle:null, pointer:null } },
      uniform:  { id:"u1", cls:"U_C_Poloshirt_blue", name:"Polo Shirt (Blue)", icon:"...", mass:20 },
      vest:     { id:"v1", cls:"V_TacVest_khk", name:"Tactical Vest (Khaki)", icon:"...", mass:40 },
      backpack: { id:"b1", cls:"B_Kitbag_cbr", name:"Kitbag (Coyote)", icon:"...", mass:40 },
      headgear: { id:"h1", cls:"H_Bandanna_khk", name:"Bandanna (Khaki)", icon:"...", mass:6 },
      facewear: { id:"g1", cls:"G_Shades_Black", name:"Shades (Black)", icon:"...", mass:2 },
      binocular:null,
      assigned: { map:{ id:"i1", cls:"ItemMap", name:"Map" }, gps:{ id:"i2", cls:"ItemGPS", name:"GPS" },
                  radio:null, compass:{ id:"i3", cls:"ItemCompass", name:"Compass" },
                  watch:{ id:"i4", cls:"ItemWatch", name:"Watch" }, nvg:null }
    },
    containers: [                                    // physical, engine-owned, mass-capped
      { id:"uniform", label:"UNIFORM", cls:"U_C_Poloshirt_blue", load:12, cap:40,
        items:[ { id:"p1", cls:"FirstAidKit", name:"First Aid Kit", icon:"...", kind:"item", mass:4, qty:3 } ] },
      { id:"vest", label:"VEST", cls:"V_TacVest_khk", load:56, cap:100,
        items:[ { id:"p2", cls:"30Rnd_556x45_Stanag", name:"5.56 mm 30Rnd", icon:"...", kind:"mag", mass:8, qty:6, ammo:30, cap:30 },
                { id:"p3", cls:"30Rnd_556x45_Stanag", name:"5.56 mm 30Rnd", icon:"...", kind:"mag", mass:8, qty:1, ammo:11, cap:30 } ] },
      { id:"backpack", label:"BACKPACK", cls:"B_Kitbag_cbr", load:70, cap:240,
        items:[ { id:"p4", cls:"muzzle_snds_M", name:"Sound Suppressor (5.56 mm)", icon:"...", kind:"attach", socket:"muzzle", mass:6, qty:1 },
                { id:"p5", cls:"optic_Hamr", name:"RCO", icon:"...", kind:"attach", socket:"optic", mass:10, qty:1 },
                { id:"p6", cls:"U_C_Man_casual_3_F", name:"Casual Outfit", icon:"...", kind:"uniform", mass:20, qty:1 },
                { id:"p7", cls:"11Rnd_45ACP_Mag", name:".45 ACP 11Rnd", icon:"...", kind:"mag", mass:5, qty:4, ammo:11, cap:11 } ] }
    ],
    bag: {                                           // virtual, mission-owned, weight-capped
      load:31, cap:88,                               // 64 base + Kitbag 24
      items:[
        { id:"apple",       name:"Apple",              icon:"icons\\apple.paa",       qty:6,  wt:1, total:6,  sell:5,    illegal:false, canDrop:true,  desc:"Crunchy. Restores a little hunger." },
        { id:"beer",        name:"Pint of Beer",       icon:"icons\\beer.paa",        qty:2,  wt:1, total:2,  sell:7,    illegal:false, canDrop:true,  desc:"" },
        { id:"bloodbag",    name:"Blood Bag",          icon:"icons\\bloodbag.paa",    qty:3,  wt:3, total:9,  sell:75,   illegal:false, canDrop:true,  desc:"" },
        { id:"boltCutter",  name:"Bolt Cutter",        icon:"icons\\boltCutter.paa",  qty:1,  wt:4, total:4,  sell:500,  illegal:false, canDrop:true,  desc:"" },
        { id:"marijuana",   name:"Marijuana",          icon:"icons\\marijuana.paa",   qty:12, wt:1, total:12, sell:0,    illegal:true,  canDrop:true,  desc:"" },
        { id:"proxychain",  name:"Proxy Chain",        icon:"icons\\qhchip.paa",      qty:2,  wt:1, total:2,  sell:0,    illegal:false, canDrop:true,  desc:"USE to arm: your next hack leaves no trace for MaxSec." },
        { id:"bank_money",  name:"Dirty Money",        icon:"icons\\bank_money.paa",  qty:4200, wt:0, total:0, sell:0,   illegal:true,  canDrop:true,  desc:"" },
        { id:"debitcard",   name:"Debit Card",         icon:"icons\\debitcard.paa",   qty:1,  wt:0, total:0,  sell:0,    illegal:false, canDrop:false, desc:"" }
      ],
      odd:[ { name:"Loot Key", qty:2 }, { name:"Camo 1 Key", qty:1 } ]   // read-only chips
    }
  },
  ground: {                                          // merged pile within reach, may be empty
    dist:1.4,
    physical:[ { id:"gp1", cls:"hgun_P07_F", name:"P07 9 mm", wide:true, icon:"...", kind:"weapon", mass:20, qty:1, sockets:{}, mag:null },
               { id:"gp2", cls:"16Rnd_9x21_Mag", name:"9 mm 16Rnd", icon:"...", kind:"mag", mass:5, qty:2, ammo:16, cap:16 } ],
    virtual:[  { case:"c1", id:"apple", name:"Apple", icon:"icons\\apple.paa", qty:3, wt:1, despawn:1140 } ]
  },
  container: {                                       // null when nothing is in reach
    id:"veh_1234", label:"OFFROAD", sub:"KEYED · YOURS", load:212, cap:1000,
    items:[ { id:"c1", cls:"30Rnd_556x45_Stanag", name:"5.56 mm 30Rnd", icon:"...", kind:"mag", mass:8, qty:10, ammo:30, cap:30 },
            { id:"c2", cls:"B_AssaultPack_khk", name:"Assault Pack (Khaki)", icon:"...", kind:"backpack", mass:20, qty:1 },
            { id:"c3", cls:"arifle_MX_F", name:"MX 6.5 mm", wide:true, icon:"...", kind:"weapon", mass:80, qty:1, sockets:{}, mag:null } ],
    lockedNote:""                                    // non-empty = shown instead of items, e.g. "LOCKED — no keys"
  },
  players:[ { uid:"7656...", name:"Sable Okonkwo", dist:2.1 } ]   // GIVE targets, ≤ 5 m
});
```

`icon` is a game texture path; the page resolves it once per path through
`AP.texture` and caches. `id`s are stable per session so the page can patch in
place. Sockets present on a weapon object are the sockets that weapon has.

### 4b. Calls

| Call | Args | Meaning |
|---|---|---|
| `invMove` | `[fromLoc, itemId, toLoc, qty]` | the one verb behind every drag. `loc` is one of `"uniform" "vest" "backpack" "ground" "container"` or a slot name (`"primary" "handgun" "launcher" "headgear" "facewear" "binocular" "assigned"`), or `"primary:optic"` / `"handgun:mag"` for a socket / loaded mag. qty ≥ 1 for stacks. |
| `invEquip` | `[itemId]` | double-click shortcut: put the item where it belongs (a uniform to the uniform slot, a mag into the matching weapon, a FAK into the first container with room). Returns `{ ok, msg, to }`. |
| `invUnequip` | `[slot]` | slot → first container with room, else ground. |
| `bagUse` | `[itemId]` | virtual USE. |
| `bagGive` | `[itemId, qty, uid]` | virtual GIVE to a listed nearby player. |
| `bagDrop` | `[itemId, qty]` | virtual DROP → suitcase on the ground. |
| `groundTake` | `[caseId, itemId, qty]` | take virtual items from a suitcase into the bag. |
| `invClose` | `[]` | page-side close button, if you draw one (Esc also closes). |

Every call returns `{ ok:true|false, msg:"" }` and is followed by an `inv` push.
`msg` is shown verbatim on refusal — it is written by the game, e.g. *"Not
enough room in your vest."*, *"You cannot access the inventory of locked
vehicles."*, *"You can only drop items once per 3 seconds."*

---

## 5. Interactions — the rules the layout must make legible

### 5a. Drag matrix

| Drag this | onto | Result |
|---|---|---|
| physical item (any container / ground / vehicle) | uniform / vest / backpack panel | move (mass check) |
| physical item | matching equipment slot | equip; displaced item returns to the source if it fits, else ground |
| uniform / vest / backpack item | its slot | **swap with content migration**, overflow spills to ground (§1a) |
| attachment | weapon tile (or its socket) | mount; displaced attachment → source, else ground |
| magazine | weapon tile | load; the ejected mag → source, else ground |
| any physical item | GROUND | drop |
| any physical item | CONTAINER | store (container mass check) |
| virtual item | GROUND | drop (suitcase) |
| virtual item from a suitcase | BAG | take (bag weight check) |
| virtual item | any physical container / slot / CONTAINER | **invalid target** — draw as such while hovering, snap back on release, no call |
| physical item | BAG | **invalid target** |

Valid targets **light up while a drag is live** (a `--acc` line + faint wash);
invalid ones dim. A hovered valid container shows the load bar's *projected*
fill (current + dragged mass) — display only, the game re-checks.

### 5b. Quantity

Stacks (virtual items, grouped magazines, `×N` items) need three quantities
without a right-click:

- default drag = **the whole stack**;
- a `+1` chip on the stack tile skims one (same grammar as the loot screen);
- an **AMOUNT** stepper (`− n + ALL`) in the selected-item panel sets the
  quantity the next drag or button uses.

Shift while dragging (via `window.__mods`) may mean "one", Ctrl "half" — as an
accelerator only. Say in your notes where quantity lives in your alternate.

### 5c. No-drag paths

Every drag has a button equivalent, reachable by click alone:

- select a tile → the selected-item panel shows name, art, description, mass or
  weight, round count, sell price, `ILLEGAL` chip, and the actions that apply:
  physical **EQUIP / UNEQUIP / TO UNIFORM / TO VEST / TO PACK / DROP / STORE /
  TAKE**; virtual **USE / GIVE / DROP**; suitcase **TAKE**.
- **double-click** = `invEquip` for physical, `bagUse` for virtual.
- Actions that do not apply are disabled in place, never hidden.

### 5d. Weight and load

- Physical: **one load bar per container** (uniform, vest, backpack, vehicle),
  `load / cap`, turning `--amber` above 90 %, `--danger` when a drop would not
  fit. Total physical mass is *not* a player-facing number here.
- Virtual: **one LOAD bar for the bag**, `31 / 88`; `--danger` + an
  `OVERWEIGHT — WALKING` chip when over cap. The cap changes live when the
  backpack changes — the push carries the new `cap`; animate the bar, not the
  layout.

### 5e. States to draw

1. **Loading** — the push has not landed (`READING THE BAG`, ≤ 1 s typical).
2. **Idle.**
3. **Drag live** — ghost under the cursor, targets lit/dimmed, projected fill.
4. **In-flight** — released tile ghosted with the house pulse until the push
   lands (~20–300 ms; can be longer for vehicle cargo, which the server
   serialises).
5. **Refused** — tile snaps back, status strip shows the game's `msg`, strip
   clears after 2.6 s.
6. **Container gone / locked** — vehicle drove off, someone else opened it,
   seizure started: the right panel shows `lockedNote` in place of items and
   any in-flight drag to it is refused.
7. **Empty states** — empty container ("EMPTY"), empty bag ("YOUR BAG IS
   EMPTY"), nothing in reach (right side collapses or shows a quiet "NOTHING IN
   REACH" — your call; say which).
8. **Cop recolour** — the whole thing in `.tal`.

### 5f. Search and grouping

The bag can hold dozens of types; **a real text field filters it as you type**.
Group or chip by kind where it helps: consumable, tool, material, chip, illegal.
The physical side is small enough to never need a filter.

---

## 6. What stays out

- Virtual trunks (house / vehicle) — STORAGE screen, T. A one-line pointer at
  most.
- Bodies, other players' backpacks, police searches, seizures — existing flows.
- Buying, selling, crafting — shops and fabricator.
- The phone's pocket **Inventory** app (virtual only, use / give / drop) stays
  as it is; this screen supersedes it for management but does not remove it.
- A native fallback bind (Ctrl+Shift+I → the old engine inventory) exists until
  this page has been played; it is not designed here.

---

## 7. Sample data

Use the `inv` object in §4a verbatim as the hard-coded state: a civilian
rebel-lite kit (TRG-21 with a red-dot, a .45, khaki vest, Kitbag), three
containers at 30 % / 56 % / 29 %, a bag at 31 / 88 with one illegal stack and
one undroppable item, a small ground pile with a pistol and a suitcase of
apples, and a keyed Offroad in reach with ten magazines, a pack and an MX. Draw
a second artboard or a toggle for the **cop** case: `.tal`, side `"cop"`, a
vest at 92 % (amber), no container in reach, bag `12 / 96`.

Item art: while hard-coding, use a neutral placeholder block with the item's
initials for every `icon` — the game supplies the real art. Wide tiles for
`wide:true`.

---

## 8. Acceptance — what "done" looks like for the chosen alternate

- Every action in §5a and §5c is reachable with the left button alone.
- A refused move visibly snaps back and the reason is readable without hover.
- Swapping a backpack for a smaller one shows what will (or did) spill.
- Loading a magazine by drag and by button both work; the rifle tile shows the
  round count.
- The bag search filters on the first keystroke.
- Renders correctly at 1080p and 4K with deck scale 0.8–1.3 (rem only).
- Works in `.tal`.
- No `innerHTML` rebuild of an unchanged list on push (stable tile identity).
- Nothing depends on animation; the screen is operable at 1 fps.

---

## Appendix A — engine facts for the implementer (not for the designer)

Recorded here so the design and the SQF side agree; the designer may skip it.

**Hooks.** `InventoryOpened` EH ending in `true` suppresses the native display
(display 602) — the existing gate `evh/fn_inventoryOpened.sqf` already returns
`true` on most refusal paths; the pass-through tail (wait for 602, single-user
lock, watchdog) is what changes to `createDialog` the web dialog. The vehicle
`AP_veh_in_use` single-user lock and its watchdog carry over unchanged. Y →
`AP_fnc_deckPhone`, T → storage, both untouched. Fallback bind Ctrl+Shift+I →
native, same pattern as Ctrl+Shift+T.

**Snapshot.** `getUnitLoadout player` (slots, attachments, loaded mag with ammo),
`magazinesAmmoFull`, `uniformItems/vestItems/backpackItems`, `loadAbs` /
`getContainerMaxLoad` per container; item mass from `CfgWeapons >> ItemInfo >>
mass`, `CfgMagazines >> mass`, `CfgWeapons >> WeaponSlotsInfo >> mass`,
`CfgVehicles >> mass`; pictures from each class's `picture`. Ground:
`nearestObjects [player, ["WeaponHolder","WeaponHolderSimulated"], 5]` plus
suitcases carrying `AP_droppedItems`. Container: the object `fn_inventoryOpened`
was handed, cargo via `getWeaponCargo/getMagazineCargo/getItemCargo/
getBackpackCargo`, cap `getContainerMaxLoad`. Bag: `AP_inv_<id>` counters via
`AP_fnc_virtItemCfg` (modes `getName/getItemWeight/getIcon/getIllegalPrice/
getLowestPrice`), `AP_carryWeight/AP_maxWeight`, descriptions `AP_itemDesc`.

**Apply.** Own containers are local: `addItemToUniform/Vest/Backpack`,
`removeItem`, `forceAddUniform`/`addVest`/`addBackpack`/`addHeadgear`/
`addGoggles`, `addWeapon`, `addPrimaryWeaponItem`/`removePrimaryWeaponItem`,
`addHandgunItem`, `linkItem`/`unassignItem`. Validate first with `canAdd`,
`canAddItemToUniform/Vest/Backpack`, `getContainerMaxLoad − loadAbs`. Prefer
per-item commands over `setUnitLoadout`; if `setUnitLoadout` is used, pass
`fullMagazines = false` or partial mags refill.

**Hazards — each is a requirement, not a note.**

1. **Scripted moves fire none of the engine EHs the native UI fired for free.**
   `Take`/`Put` today do the `-TOOKITEM-`/`-STOREDITEM-` logging, the shared-
   container dupe checks (backpack/vest/uniform container identity vs nearby
   players), the role-item drops (governor uniform, medic vest, low-rank MaxSec
   SMGs, civ UAV terminals, passive-JIP weapons), `saveGear` + `ClupdatePartial`
   and the 450 s clean-time on ground holders. The bridge must call the same
   code paths explicitly on every mutation.
2. **No single-item remove from a container's cargo.** Taking one magazine from
   a vehicle means `clearMagazineCargoGlobal` + re-add the rest — a race against
   the engine's own inventory and other players. Route **all vehicle/crate cargo
   and ground-holder mutations through one server function** that serialises
   them; own-body moves stay client-local.
3. **Worn-container swap** must reproduce the engine's content migration and
   spill overflow to a ground holder, then re-run `AP_fnc_clothingTextures`
   (`setUniform` / `setBackpack`, skin indices in `AP_uniformBackpack_skins`) and
   the invisible-backpack rule (`AP_invisBag`).
4. Cross-side uniforms are allowed on this server (`forceAddUniform`); the
   *only* clothing gates are the role items in `fn_onTakeItem` — reuse that
   switch as the validation table, do not invent a new one.
5. The in-game browser delivers LMB + wheel only; modifiers arrive via the
   dialog's KeyDown/KeyUp mirrored into `window.__mods` (`fn_mapOpen` pattern).
6. `A3API.RequestTexture` resolves a ~23-char stub on a miss; the bridge shim's
   `AP.texture` already handles the miss and the alpha trim. Mission-relative
   `icons\*.paa` need the mission-root retry `WEBUI.texture` performs.
7. Push after **every** mutation, including ones the player did not make (a mag
   emptied by firing, a vehicle driving off, another player opening the
   container).

---

## 9. Build design — chosen alternate **4a** (3a figure overlay + Gunsmith), 2026-09-03

The owner picked board 4a of Claude Design's `inventory-options-tal` sheet and pasted its handoff
notes. This section is the engineering design for that alternate. Everything above (§1–§8,
Appendix A) still holds; where the handoff and the brief disagreed, the resolution is recorded here.

### 9.0 Residual decisions (recorded, not re-asked)

1. **The mock file was not delivered.** `inventory-options-tal.html` exists nowhere on disk (filename
   and content search, Downloads, archives, artifact list). The page is built from the handoff text
   + this brief's §4 contract. When the mock is dropped, reconcile geometry/spacing against it; the
   structure will not change.
2. **Frame = windowed 40 × 22 × `AP_deckScale`, centred** (armory convention). The handoff's aside
   "in-game it is the deck screen (960px, rem = SCREEN_W/75)" is the designer's guess; the mock's
   own numbers (1600 × 880 at rem 19.5) are exactly `html{font-size:clamp(9px,1.22vw,22px)}` on a
   1.82:1 control — storage.html's formula. Use that. No JS fit script.
3. **One push channel for the screen, one for the gunsmith.** `inventory` carries the §4a `inv`
   object verbatim (keys `you / ground / container / players`); `gunsmith` carries the weapon
   panel (`null` when closed). Call results are the verdict (`{ok,msg}` on the promise, the deck
   rule) — no separate `invVerdict` channel. Dots/underscores only in channel names (fn_push regex).
4. **Refusal strip timing = 5 s** (handoff) for this screen, then `READY`.
5. **Physical item identity** (the engine has none): `id = "<loc>|<cls>|<ammo>"` where `loc` is
   `uniform / vest / backpack / container / ground:<netId>`, `ammo` is the round count for
   magazines and `-1` otherwise; identical (cls, ammo) pairs in one location group into one row
   with `qty`. Worn slots: `slot|<slotName>|<cls>`. Virtual rows use the catalogue id. Ids are
   deterministic, so pushes patch in place.
6. **Weapons carry their `weaponsItems` array** everywhere (`[wpn, muzzle, pointer, optic,
   [mag, ammo], [mag2, ammo], bipod]`) and move with `addWeaponWithAttachmentsCargoGlobal`, so an
   MX with an RCO in a trunk stays an MX with an RCO.
7. **Worn container going INTO a container/vehicle must be empty** ("EMPTY IT FIRST"). The engine
   turns a worn uniform into a bare class when stored; migrating its contents into the target is
   the native dialog's magic and is out of scope for this cut. Swapping worn containers (§1a) IS
   in scope and migrates + spills.
8. **Bag USE / GIVE / DROP reuse the phone's functions** (`AP_fnc_useItem / giveItem / dropItem`,
   explicit-arg forms). Their refusals surface as the game's own hint, not the strip (they
   `spawn` and message internally); the strip shows `…` then READY and the push corrects the list.
9. **Ground pile = merged view** of every `WeaponHolder` within 5 m plus every `Land_Suitcase_F`
   with `AP_droppedItems` within 5 m. Physical rows carry the holder netId in their id.

### 9.1 Files

| file | role |
|---|---|
| `ui/html/inventory.html` | the page — deck grammar, `.tal` by side, shim from storage.html, wheel shim, no external anything |
| `dialog/web_inventory.hpp` | `AP_web_inventory` idd **938500**, Page idc 938501, 40×22, `url = "ui\html\inventory.html"`, onLoad → `AP_fnc_invBridge`; included from `dialog/MasterHandler.h` |
| `core/inventory/fn_invOpen.sqf` | entry: `[_container] spawn AP_fnc_invOpen` — reserve `AP_veh_in_use`, `createDialog` |
| `core/inventory/fn_invBridge.sqf` | onLoad: `webui_fnc_init/serve`, geometry, handlers, watcher, Unload cleanup |
| `core/inventory/fn_invSnapshot.sqf` | builds the `inventory` payload |
| `core/inventory/fn_invItemInfo.sqf` | `[cls] → {name, icon, mass, kind, socket, wide}` cached per session |
| `core/inventory/fn_invCargoRead.sqf` | `[containerObj] → rows` (mags with ammo, weapons with items, backpacks, items) — used by client and server |
| `core/inventory/fn_invLocal.sqf` | own-body verbs: `move / equip / unequip / swapWorn / spill` |
| `core/inventory/fn_invGunsmith.sqf` | `open / mount / detach / unload / reload / close` + the `gunsmith` payload |
| `core/inventory/fn_invCommit.sqf` | Appendix A hazard 1 tail after every mutation: onTake/onPut replication, `saveGear`, `ClupdatePartial 3`, re-push |
| `core/inventory/fn_invCargoRecv.sqf` | client receiver for server verdicts (`remoteExecutedOwner == 2` guard) |
| `server/AP_server/core/TON/fn_invCargo.sqf` | `APS_fnc_invCargo` — the ONE serialised mutator for vehicle/crate cargo and ground holders |
| `evh/fn_inventoryOpened.sqf` | null container → web self; vehicle/crate tail → web with container; `AP_invForceNative` bypass |
| `evh/fn_keyDownHandler.sqf` | CTRL+SHIFT+I (DIK 23) → native 602 fallback, alongside CTRL+SHIFT+T/Y |
| `Functions.h`, `CfgRE.hpp`, `server/AP_server/config.cpp` | registrations; `APS_fnc_invCargo {allowedTargets=2}`, `AP_fnc_invCargoRecv {allowedTargets=1}` |

### 9.2 Opening and closing

- `I` → engine fires `InventoryOpened [unit, container]` → `fn_inventoryOpened`. Existing guard chain
  unchanged (firefighter, admin bypass, bag stealing, bodies, seizing, cooldown, event crates, locked
  vehicles, single-user lock). Two edits: `isNull _container` → `[objNull] spawn AP_fnc_invOpen; true`
  (self + ground); the pass-through tail (was: wait for 602) → `[_container] spawn AP_fnc_invOpen; true`.
  `AP_invForceNative` (set by CTRL+SHIFT+I, consumed once) → `false` (native opens).
- `fn_invOpen`: refuses restrained / `AP_action_in_use` (mirrors the Gear key branch), sets
  `_container setVariable ["AP_veh_in_use", player, true]` when a container is in reach, stores
  `uiNamespace AP_invContainer`, `createDialog "AP_web_inventory"`.
- Bridge Unload EH releases `AP_veh_in_use` (only if it is still `player`), clears the watcher,
  `AP_action_in_use = false`.
- Watchdog (was keyed on 602): while 938500 is open, close it if `serverRestartLock`, the container's
  `AP_trunkLock`, or the container gone / driven > reach.
- Esc: dialog KeyDown. If the gunsmith is open (`uiNamespace AP_invGsOpen`), Esc closes the gunsmith
  (`closeGunsmith()` over exec) and is swallowed; otherwise the dialog closes. `I` also closes (same
  as the native).

### 9.3 Snapshot (`inventory` push)

`fn_invSnapshot` returns the §4a object. Sources:
- slots: `primaryWeapon / secondaryWeapon / handgunWeapon` + `weaponsItems player` for sockets and the
  loaded mag (ammo from the weaponsItems entry); `uniform / vest / backpack / headgear / goggles /
  binocular player`; assigned from `assignedItems player` classified by `simulation`
  (ItemMap/ItemGPS/ItemRadio/ItemCompass/ItemWatch) and NVG (`ItemInfo>>type == 616`).
- containers: for each worn container object (`uniformContainer / vestContainer / backpackContainer`):
  `load = loadAbs obj`, `cap = maxLoad obj`, rows from `fn_invCargoRead`.
- bag: `["inv"] call AP_fnc_deckData` remapped (`wt`, `total`, `sell`, `desc`) + `illegal`
  (`getIllegalPrice >= 0`), `canDrop` (false for `scalp*`/keys — the deck's undroppables), `icon`
  (`getIcon`), `load/cap = AP_carryWeight / AP_maxWeight`, `odd`.
- ground: `nearestObjects [player, ["WeaponHolder"], 5]` (covers GroundWeaponHolder and
  WeaponHolderSimulated) → rows with `loc = "ground:<netId>"`; suitcases
  `nearestObjects [player, ["Land_Suitcase_F"], 5]` with `AP_droppedItems` → virtual rows with
  `case = netId`, `despawn = AP_dropUntilSrv - serverTime`.
- container: `uiNamespace AP_invContainer` if non-null and still within reach: `label` display
  name, `sub` (`KEYED · YOURS` when `in AP_vehicles`, `POLICE` when west, else `UNLOCKED`),
  `load/cap`, rows; `lockedNote` set when `AP_veh_in_use` is someone else, `AP_trunkLock`, or gone.
- players: the deck's `nearby` filtered to ≤ 5 m.
- flags: `overweight = AP_carryWeight > AP_maxWeight`, `restrained`, `inVehicle`.
- Mass per class (`fn_invItemInfo`): `CfgWeapons>>ItemInfo>>mass` (items, attachments, clothing),
  `CfgMagazines>>mass`, `CfgWeapons>>WeaponSlotsInfo>>mass` (weapons), `CfgVehicles>>mass`
  (backpacks); `icon = picture`; `wide = weapon`; `kind` from config class + `ItemInfo>>type`
  (101 muzzle, 201 optic, 301 pointer, 302 bipod, 605 headgear, 616 nvg, 701 vest, 801 uniform;
   CfgGlasses → facewear; weapon type 4096 → binocular; simulation Item* → assigned).

**Watcher (hazard 7):** a 1 Hz loop while the dialog is open builds a cheap signature
(`str [getUnitLoadout player, loads, holder count, cargo counts, AP_carryWeight, lock vars]`) and
re-pushes on change. The page never polls.

### 9.4 Mutations

Every verb returns `{ok, msg}`; on success it runs `fn_invCommit` (below) which re-pushes.
Validation first (`canAdd` on the destination, kind vs slot, item present), then the move.

**Own body (client-local, `fn_invLocal`):**
- `move [fromLoc, id, toLoc, qty]` between uniform/vest/backpack: per unit, `_fnRemoveOwn` +
  `_fnAddOwn`. Magazines are removed by rebuilding the source container's magazine cargo without
  one `[cls, ammo]` (`magazinesAmmoCargo → clearMagazineCargoGlobal → addMagazineAmmoCargo`), so a
  17/30 stays 17/30; weapons the same way on the weapon cargo (`weaponsItemsCargo →
  clearWeaponCargoGlobal → addWeaponWithAttachmentsCargoGlobal`); everything else
  `removeItemFromX cls` / `addItemToX cls`. Nested backpacks: class only (contents not preserved —
  the engine's `addBackpackCargoGlobal` creates an empty one; documented, rare).
- `equip [id, slot]`: weapon → `addWeapon` + `addWeaponItem` per attachment and `[mag, ammo]`;
  displaced weapon → source container if `canAdd`, else `spill`. headgear/facewear: remove old →
  source/spill → add. binocular: `addWeapon`. assigned: `linkItem` (removes from container).
  uniform/vest/backpack → `swapWorn`.
- `swapWorn [id, slot]` (hazard 3): snapshot old contents via `fn_invCargoRead`, `removeUniform /
  removeVest / removeBackpack`, `forceAddUniform / addVest / addBackpack` new, re-add contents with
  `canAdd`, leftovers + the old garment (if the source can't take it) → `spill`; then
  `[uniform player, "setUniform", ""] call AP_fnc_clothingTextures` / `setBackpack`, and
  `[true] call AP_fnc_invisBag` after a backpack change. The page previews the spill count on hover
  (projected from masses) and the verdict message states what spilled.
- `unequip [slot]` → first container with room (vest → backpack → uniform order for attachments and
  mags; backpack first for clothing), else `spill`.
- `spill [rows]`: the `AP_fnc_forceDropItem` pattern — `createVehicle "GroundWeaponHolder"` at the
  player, fill with the rows (mags with ammo, weapons with items), then
  `[[_gwh, 450], "APS_fnc_setCleanTime", 2]` — client-local because the holder is new and only ever
  filled with the player's own displaced gear.

**Shared containers (server, `APS_fnc_invCargo`):** vehicle/crate cargo and EXISTING ground
holders. Client sends `[ticket, verb, target, spec]` with `[..., "APS_fnc_invCargo", 2]`; the server
takes the actor from `remoteExecutedOwner` (never the payload), validates reach (vehicle: 10 m + half
its size, holder: 5 m), the single-user lock, `AP_trunkLock` / seizing, then runs the mutation inside
`isNil { }` (unscheduled = atomic against every other script), and answers with
`[[ticket, ok, msg], "AP_fnc_invCargoRecv", owner]`. The bridge handler waits on the ticket (5 s).
- `take [cls, kind, ammo, toLoc, qty]`: rebuild the cargo without the unit → add to the player's
  container (`addItemToX` / `addMagazineAmmoCargo` / `addWeaponWithAttachmentsCargoGlobal` — all
  AG/EG) after `canAdd`; weapon slot targets use `addWeaponGlobal` and hand the attachment list back
  to the client in the verdict for `addWeaponItem` (local-arg command). Fails → cargo restored.
- `store [fromLoc, cls, kind, ammo, qty]`: verify the player HAS it (global reads), remove from the
  player (global commands; slots via `removeWeaponGlobal / removeHeadgear / removeGoggles /
  removeUniform / removeVest / removeBackpackGlobal`, worn containers only when empty), add to cargo
  after `_target canAdd`.
- `drop [fromLoc, cls, kind, ammo, qty]`: like `store` onto the nearest `WeaponHolder` within 2 m
  of the player, else a new `GroundWeaponHolder`; `APS_fnc_setCleanTime [holder, 450]`.
- `pickup [holderNetId, cls, kind, ammo, toLoc, qty]`: like `take` from a holder. Empty holders
  delete themselves (engine).
- Backpacks in cargo keep their contents across the rebuild: `everyBackpack` before and after,
  contents copied per index.

**Virtual (existing functions):** `bagUse → [controlNull, id] spawn AP_fnc_useItem`,
`bagGive → [controlNull, id, qty, uid] spawn AP_fnc_giveItem`, `bagDrop → [id, qty] spawn
AP_fnc_dropItem`, `groundTake [case, id, qty]` → fn_lootBridge's pre-split `_take` against the case
by netId under an `AP_inUse` reservation held only for the call.

**Gunsmith (`fn_invGunsmith`):**
- `open [slot]` (primary | handgun; launcher out of scope): refuses when in a vehicle turret seat
  (`HOLSTER THE WEAPON TO EDIT IT.`). Payload: weapon `{cls,name,icon,mass}`, sockets from
  `WeaponSlotsInfo` (`MuzzleSlot / CowsSlot / PointerSlot / UnderBarrelSlot` present ⇒ socket
  shown; muzzle/optic/pointer/bipod) with the current item from `weaponAccessories`, `mag` from
  `weaponsItems` (`{cls,name,ammo,cap}`), `magsInContainers` (count of compatible mags in the three
  containers), `fits` = `BIS_fnc_compatibleItems` ∩ rows in containers + reach container, each with
  its socket type and source.
- `mount [id, socket]`: `fits` check + socket type match; displaced attachment → the new item's
  source container (`canAdd`), else vest → backpack → uniform → `spill`. Order: reserve room, remove
  new from source (own container: local; reach container: server `take` into the vest/backpack
  first, then mount), `removePrimaryWeaponItem old`, `addPrimaryWeaponItem new`, add old to its
  destination. Handgun uses the `addHandgunItem / removeHandgunItem` pair.
- `detach [socket]` → backpack → vest → uniform → `spill` (never refused: spill is the floor).
- `unload` → mag with ammo → vest → backpack → uniform (`addMagazineAmmoCargo`), else spill.
- `reload` → fullest compatible mag in the containers, removed by rebuild, loaded with
  `addWeaponItem [wpn, [cls, ammo], true]`; the previous mag goes back with its count.
- `close` → clears `uiNamespace AP_invGsOpen`, pushes `gunsmith = null`.

**`fn_invCommit` (hazard 1):** after ANY successful physical mutation: for each item that entered
the player's gear `[player, container, cls] spawn AP_fnc_onTakeItem`; for each that left
`[player, container, cls] spawn AP_fnc_onPutItem` (they log `-TOOKITEM-/-STOREDITEM-`, run the
shared-container dupe check, the role-item force-drops, `saveGear` + `ClupdatePartial 3`, the
450 s clean time). Then `[false] call AP_fnc_saveGear; [3] call AP_fnc_ClupdatePartial` once more
after 0.2 s (the handlers' own tail is spawned) and re-push `inventory` (+ `gunsmith` if open).

### 9.5 Page (`inventory.html`)

Layout per the handoff: `.hdr` (led · INVENTORY · name · side chip · ESC hint), `.body` with four
columns flex 1.45 / 1 / .95 / .95, `.status` strip. Column 1 WORN: figure SVG (silhouette + blue
sling path when a weapon is open), eight slot cards (left: primary wide, backpack, handgun wide,
binocular; right: headgear, facewear, vest, uniform) with dashed leader lines drawn in an overlay
SVG from each card to its body anchor (recomputed on render/resize), ASSIGNED strip of six cells.
Column 2: three container panels (`.ph` label + cls · load bar `used / cap` · list · foot hint) —
replaced by the GUNSMITH panel while open (`.panel.lit`, anatomy per the handoff). Column 3:
vehicle panel (KEYED chip, load bar, `lockedNote`), GROUND panel (distance, physical + suitcase
rows), SELECTED panel (art, name, kv, AMOUNT stepper `− n + ALL`, actions). Column 4 BAG (search,
list, USE / GIVE / DROP; `.dimmed` while the gunsmith is open; GIVE opens a `.ovl` player picker).

Row grammar: `state dot · art · name · chip · metric · acts`; illegal = red dot; `.row.fits` /
`.row.nofit` while the gunsmith is open; `+1` chip on suitcase and reach-container stacks.
Drag: pointer-event drag (map.html pattern) with one `.ghost.row` at 60 %; targets carry
`data-drop`; valid targets light (`--acc` line + wash) and show the projected load; invalid dim;
release on nothing = cancel; refused = snap back + strip. Every drag has a button in SELECTED.
Double-click: weapon slot → gunsmith; physical row → `invEquip`; FITS row → mount; bag row →
`bagUse`. Lists patch in place by id (`syncList`), never `innerHTML` on an unchanged list.
Loading state `READING THE BAG` until the first push. Textures via `AP.texture` cached per path.

### 9.6 Verification

1. `tools/html_js_check.py` parses; `node --check` clean.
2. Offline harness `scratchpad/inv_harness/inv_harness.mjs` (puppeteer, dev stub data = §7): boots,
   renders 1600×880 and 1280×704 without horizontal overflow, gunsmith opens on double-click,
   drag onto a socket issues `invMount`, refusal lands in the strip, `.tal` renders. Screenshots
   kept beside the harness.
3. SQF: brace balance (Arma-aware), `tools/fn_check.py`, `tools/dialog_reachability.py`.
4. Dev deploy → `read from bank` → server log clean of `[INV]` errors.
5. In-game: open I, RPT shows `[INV] screen ready` and `[INV] inventory page up`, the push lands
   (the page leaves READING THE BAG), the gunsmith opens on a double-click of PRIMARY;
   mount/detach round-trip; drop/pickup on a ground holder; store/take on a keyed vehicle.

### 9.7 Owner playtest (the part no offline gate can cover) — dev b0888

Nothing in §9.1–9.5 has run in a client yet: the page passed its headless harness, the SQF passed
the structural gates, and the dev server booted clean, but no `I` has been pressed. Probes for the
debug console (Esc → console; `[AP-PROBE]` lines land in the client RPT):

```sqf
// 1. the reader trio: three containers, the worn slots, a partial mag with its count
[] spawn { diag_log "[AP-PROBE] snap"; diag_log str ([] call AP_fnc_invSnapshot); };
// 2. press I (no vehicle in view): dialog 938500, RPT "[INV] screen ready", page renders
// 3. look at a keyed vehicle, press I: OFFROAD panel with KEYED · YOURS and its cargo
// 4. CTRL+SHIFT+I: the native 602 opens once; the next I is the web screen again
// 5. drag a FAK vest → backpack; a 17/30 mag between containers keeps its count
// 6. double-click PRIMARY → GUNSMITH; mount an optic from the backpack; mount another → the first
//    returns to the backpack; UNLOAD → mag lands in the vest with its rounds; RELOAD → fullest mag
// 7. drop 2 mags to GROUND with the backpack full → a GroundWeaponHolder appears; pick them back up
// 8. store 2 mags into the vehicle, take the MX out into the primary slot (attachments intact)
// 9. equip a spare uniform while the worn one is full → contents migrate, spill count in the strip
// 10. after each step: RPT has -TOOKITEM- / -STOREDITEM- where the native would have logged them,
//     and `[3] call AP_fnc_ClupdatePartial` saved (no "gear not synced" on relog)
```
Escape hatch while playing: CTRL+SHIFT+I is the native inventory, one keypress away.

Step 0 (owner, 2026-09-03 request): the figure is your BODY, not a drawing — §9.8. Eyeball the
framing first; the five `AP_invFig*` tunables are live in the console.

### 9.8 The live figure — the player's actual body in the WORN column (owner, 2026-09-03)

"The body of the character as it is" → "isolate just the body" → "match the HTML UI, higher res,
wider" → "single image, drag to rotate" → "a light so you can see it at night." Twenty-five dev
builds (b0889–b0913). `fn_invFigure.sqf`'s header carries the same laws.

1. **Nothing native draws above the browser control.** A sibling declared or `ctrlCreate`d after
   it never shows. The browser alpha-composites over what was drawn *before* it (the deck's
   see-through chassis). So the figure group (idc 938502) is declared **before** the Page control
   and the page masks a transparent hole at the strip (`body.figlive #frame`,
   `mask-composite: exclude`, box from `reportFigure()`). The README's "natives draw on top" was
   wrong and is corrected; only separate displays (engine error boxes) draw above the browser.
2. **A PiP always renders at the screen's aspect at a capped resolution** (~1024×432 on the
   owner's rig, `pipQuality` 4), whatever texture size/shape is asked and whatever the r2t
   `aspect` parameter says (256×1024, 1024×2048, aspect 0.46 all tried). An upright body gets
   ~2 px per texel at this strip size. Two stacked cameras (b0902–b0907) doubled that but never
   read as one body (a duplicated or missing band at the waist, and the engine's **camera FOV
   floor ≈ 0.086** silently clamped the telephoto requests — measured twice), so it is **one
   camera at mid height**, and the player **drags the strip to turn the mannequin**
   (`invFigureRot`, 0.6°/px) to make up for the resolution. The picture is [strip height ×
   screen aspect] wide, cropped by the group to the strip.
3. **`ctrlSetAngle` rotates within the control's own bounds** — a rolled camera cannot be turned
   upright without clipping; closed.
4. **The studio is off-world.** A mannequin created locally (`createVehicleLocal "C_man_1"`; no
   network object; `setUnitLoadout`/`setFace`/`setObjectTexture` work on it) 300 m over the sea
   corner (`AP_invFigStudioPos`), re-synced from the player on every push (`AP_fnc_invFigSync`).
   Planes attached to the real player blacked out the world around the dialog (b0896);
   `attachTo` children of an unsimulated parent are never placed (b0897) — absolute positions.
   Camera positions are AGL (`ASLToAGL`; `getPosATL` over the sea is height above the sea FLOOR
   and the camera stared at the sky, b0908).
5. **Light and exposure.** The PiP shares the main view's HDR adaptation, so an unlit studio
   rendered one backdrop three colours depending on where the player stood, and at night showed
   nothing. The studio is a **closed black box** (roof, floor, side walls, a wall behind the
   camera; `UserTexture10m_F`, both faces since single-sided) with **key + fill `#lightpoint`s**
   (1.0 / 0.5, no ambient — 4 / 2 blew everything to white), the backdrop 4.4 m behind the
   mannequin with steep attenuation, and the **aperture pinned** (`setAperture 20`, set in
   `fn_invOpen` before the dialog and again by the figure) while the figure is live, auto again
   on close. Under that the render is **steady** (five samples over 30 s identical).
   **The panel colour cannot be rendered exactly:** the tonemapper crushes scene luminance below
   ~0.052 to black and the first non-black it renders is ~30 at aperture 20 (0.05 → 0, 0.058 → 31,
   0.075 → 36, 0.10 → 49, 0.20 → 80); closing to 60 lowers the floor only to ~20 and turns the
   player's world near-black. `--panel` (12,21,33) is below that floor at any exposure that keeps
   the world visible. So the backdrop is the closest smooth tone (`color(0.058,0.096,0.139)`,
   `#(argb,…)` — `#(rgb,…)` is DXT-quantised to 5–6 bits and snaps between levels) and the page
   draws a **vignette** (`#figVignette`, a sibling of `#frame` so the hole mask does not cut it,
   composited above the native render) that blends the strip's edges into the panel colour. Reads
   as a spotlit figure; exposure-proof. `AP_invFigBackdrop / 2` stay tunable (two-tone calibration:
   set them to different colours, sample screen-left = `AP_invFigBackdrop` since the camera faces
   south).
6. **Geometry decoded:** at the owner's uiScale 0.55, 1 UI unit = 1064 × 792 px, `pixelGrid` 12,
   safezone `[-1.116, -0.409, 3.233, 1.818]`; the 40×22 window at deck scale 1.7 = 2040 × 1122 px.
   The page reports the strip as fractions of the VIEWPORT (= the control), not of `#frame`.
   WORN column widened (flex 1.9, side cards 8.4 rem) → strip ≈ 400 × 862 px there.
7. Falls back to the drawn silhouette when PiP is off in the video options (`isPiPEnabled`), in a
   vehicle, or without a dialog. Cost: one PiP render while the screen is open.
8. **The light dial (owner-tuned 2026-09-04):** night `aperture 8 / key 4 / fill 2 / ambient 0.4`,
   day `aperture 50 / key 1.5 / fill 0.7 / ambient 0`, blended on `sunOrMoon` by `AP_fnc_invFigTune`
   (aperture in log space, lamps linear). Setting `AP_invFigAperture` / `AP_invFigKey` /
   `AP_invFigFill` / `AP_invFigNightAmbient` in the console overrides that knob. The body lamps
   are range-limited (stop ~5 m, short of the backdrop); the ambient lives on its own unlimited
   lamp. Lamps are placed with `setPosASL` — `createVehicleLocal`'s ATL over the sea is height
   above the sea floor, which had the lamps 100 m under the box for six builds. Other knobs:
   `AP_invFigDist` 6.5 · `AP_invFigSide` 0 · `AP_invFigBottom` −0.3 · `AP_invFigTop` 2.25 ·
   `AP_invFigBackdrop` / `2` · `AP_invFigIsolate` · `AP_invFigRes` 2048 · `AP_invFigStudioPos`.
