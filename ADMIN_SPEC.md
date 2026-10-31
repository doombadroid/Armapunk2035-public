# STAFF DECK — HTML admin menu. Design brief

Design the HTML replacement for the staff/admin menu of a cyberpunk Arma 3
roleplay server. Self-contained; you do not need the repo. **Every function,
gate and payload below was read out of the running dialog and its handlers**
(`admin_menu.hpp` idd 12900 + `core/admin/fn_*` — 35 functions), not from
memory. Where this brief and your instincts disagree, this brief is the game.

The phone, casino and 3D map you designed for this project are shipped and in
game. This screen replaces the last native staff surface. Same tokens, same
mono/sans split; a staff tool wants the TAL OS temperature — amber on gunmetal —
rather than the civilian acid:

```css
--scr:#050a10 --scr2:#0a121c --panel:#0c1622 --panel2:#0e1a28
--acc:#f5a623 --acc2:#54b0ff --danger:#ff4d4d --ok:#7ad06d --magenta:#ff3d81
--ink:#dbe6f2 --dim:#7d8b9e --faint:#3c4a5c --line:rgba(245,166,35,.15)
--mono: ui-monospace,'JetBrains Mono','SF Mono',Menlo,Consolas,monospace
```

---

## 1. The shape of the thing

Full-screen dialog (same frame contract as the casino/map: dpr 1, Esc closes,
head block mandatory, no libraries/network/storage). Three standing regions:

1. **The roster** (left) — every connected player, live. This is the heart:
   most actions operate on the selected player.
2. **The workbench** (center/right) — tabbed panels: ACTIONS · EVENT TOOLS ·
   WEAPONS & GEAR · VEHICLES · CLOTHING · OWNER.
3. **The status rail** — persistent toggles with visible state (godmode,
   invisible, admin mode, markers, stimmy, fed override) + a status strip for
   refusals and confirmations. Refusals never modal.

**RANK GATING IS THE DESIGN PROBLEM.** Every action carries a minimum level,
and the UI must render only what the viewer's level allows — a hidden button,
not a disabled one, except within a tier section where mixed gating exists
(then: visible-but-locked with the level named, e.g. `LEVEL 4`). The payload
carries `level`; SQF re-checks every action server-side regardless, so the page
gates for HONESTY, not security.

---

## 2. Ranks

`AP_adminLevel` is server-assigned at login, constant for the session.

| level | tier label (suggested) | unlocks |
|---|---|---|
| 2 | MODERATOR | menu itself, spectate both kinds, TP (all forms), jail, revive/revive-all, restrain/unrestrain, godmode, admin mode, invisible, bullet cam, admin message, get/set pos, player info, markers toggle, restart timers, weapon/gear spawner, vehicle spawner, clothing spawner, event vehicle markers |
| 3 | ADMIN | kick, add money (self), weather (snow/rain/day/night), admin cam |
| 4 | SENIOR ADMIN | ban |
| 5 | OWNER | news broadcast, economy editor, stimmy checks, fed control, fun guns, charge-self test, spawn dummy |
| — | UID-locked | Owner Mode (ESP + no-sway + Super Spangle) — separate phone tile, NOT in this menu; do not design it in |

(Numbers are the law; the tier labels are yours to style.)

---

## 3. The roster

Live payload, 1 Hz while open:

```js
AP.on("staff", s => ...)
s = { level: 3,                       // the VIEWER's admin level
      toggles: { god:false, invis:false, adminMode:true, markers:false,
                 stimmy:false, fedOverride:false },
      players: [{ uid, name, side:"civ"|"cop"|"med", ping: 43,
                  cash: 12000, bank: 4500000, adminLevel: 0,
                  veh:"none"|"car"|..., restrained:false, alive:true }] }
```

- Sortable by name/side; a filter box (typed input works).
- Selecting a row arms every player-targeted action and opens the **dossier**:
  the deep-inspect the native menu shows (`fn_adminInfo`) — money, licenses,
  primary/secondary/handgun/vest/backpack by display name, gang, steam name,
  uid (click to copy via the coords-readout pattern).
- Selection survives repaints (the click-rebuild lesson from the casino is
  law: never rewrite a row the cursor is on unless its content changed).

## 4. The actions, exhaustively

Verbs below are the contract; one call shape:
`AP.call("staffAct", [action, targetUid, args]) → {ok, msg}` (optimistic; the
1 Hz payload is the truth).

### Player-targeted (roster selection required)
| action | level | notes |
|---|---|---|
| `spectate` | 2 | closes the deck, engine spectate |
| `spectateEsp` | 2 | ESP spectate variant |
| `tpToMe` | 2 | brings THEM (their whole vehicle) |
| `tpToThem` | 2 | sends you |
| `jail` | 2 | admin jail |
| `revive` | 2 | single |
| `restrain` / `unrestrain` | 2 | |
| `kick` | 3 | reason text (typed input) |
| `ban` | 4 | reason text; confirm step ON THE PAGE (arm-then-commit — native confirm() is sandboxed out) |
| `info` | 2 | fills the dossier |

### Self / global
| action | level | notes |
|---|---|---|
| `tpMapClick` | 2 | OPENS MALDEN GRID armed in TP mode — already built; the button just calls it |
| `tpFacing` | 2 | short teleport the way you face |
| `getPos` self/selection | 2 | fills the coords box + clipboard |
| `setPos` self/selection | 2 | from the coords box; **refuse [0,0,0]** — the box must be filled (the debug-island incident is in the code comments) |
| `reviveAll` | 2 | confirm step |
| `godmode` / `invisible` / `adminMode` | 2 | toggles; state in the rail |
| `bulletCam` | 2 | closes the deck |
| `adminMessage` | 2 | text to a player |
| `newsBroadcast` | 5 | server-wide broadcast, styled editor welcome |
| `addMoneySelf` | 3 | amount |
| `weather` snow/rain/day/night | 3 | four buttons |
| `restart` | 2 | two ladders: HARD (now / 1 / 10 / 30 / 60 min) and UPDATE (now / 1 / 10 / 30 / 60 min) — confirm step on both; these end the server |
| `eventVehMarkers` | 2 | toggle: live vehicle markers on the map |
| `giftAll` | 2 | give gift to all civs |
| `fixTrunk` | 2 | clears a stuck `AP_activeTrunk` on the cursor object — needs the WORLD cursor, so it closes the deck and instructs |
| `eventMenu` | 2 | opens the native event menu (modes live there; do not redesign it in this pass) |

### Spawners (three catalogues, one pattern)
| panel | level | source |
|---|---|---|
| WEAPONS & GEAR | 2 | catalogue payload: grouped weapon/mag/item classes with display names; search box; click = spawn to self |
| VEHICLES | 2 | grouped list (Auto / Heli / Plane / Boat …), spawn at your position facing you |
| CLOTHING | 2 | uniforms/vests/headgear, click to wear |

Catalogues arrive once on open (`AP.call("staffCatalog", [panel])`) — they are
static per session and hundreds of rows; render lazily, filter page-side.

### OWNER panel (level 5 — the whole tab hidden below 5)
| action | notes |
|---|---|
| `economy` | opens the native economy editor (separate dialog; not this pass) |
| `stimmy` on/off | status text with colour ("Status: ON (10x cartel)") |
| `fedReset` / `fedOverride` on/off | confirm steps; override disables heist cop-requirements AND cooldowns — say so in the confirm copy |
| `funGun` lynx/subcannon/off × me/all | six buttons, clearly labelled as chaos |
| `chargeSelf` | test tool |
| `spawnDummy` | invincible test dummy 4m ahead that prints ballistics |

---

## 5. Live map tie-in

The 3D map (MALDEN GRID) already shows admins every player at 1 Hz and carries
the TP mode. This screen should LINK, not duplicate: a "GRID" button on the
roster header opens the map; `tpMapClick` opens it armed. Do not build a
second map inside the staff deck.

---

## 6. Do not

- render an action above the viewer's level (hide; or locked-with-level inside
  mixed sections)
- treat the `staffAct` reply as state — the 1 Hz payload is the truth
- use native confirm() (sandboxed out); confirms are arm-then-commit on the page
- rebuild roster rows under the cursor (the casino click lesson)
- design Owner Mode into this menu (separate UID-locked tile)
- redesign the event menu or economy editor in this pass — they open native
- libraries, fonts, network, storage; rAF while idle

## 7. Deliverables

- One self-contained `staff.html` (inline CSS/JS, the mandatory `WEBUIReady` +
  `A3API.RequestFile("webui\\ui\\webui.js")` head block)
- An `AP` stub behind `typeof AP === "undefined"`: mock roster of ~8 players
  across sides (one restrained, one dead, one in a heli), viewer level
  switchable 2/3/4/5 in the stub so every gate renders in review, toggles
  cycling, catalogue mocks (~40 rows each)
- A note: what animates (the answer should be "nearly nothing"), and how the
  gate rendering degrades at each level
