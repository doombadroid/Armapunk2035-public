# HUD UI EDITOR — drag the status HUD where you want it, remember it in the database

Spec. 2026-08-29. **v2 2026-09-07: resize (§9) — every handle also carries a uniform scale.**

The status HUD (`ui\html\hud.html`, layer `AP_web_hud` 938300) draws where the designer
drew it: vitals plates bottom-right, minimap top-left. This adds a Settings option that
opens a full-screen editor over the live world, lets the player drag those pieces
anywhere, and stores the result **in Postgres** — not in the profile, and never through
`compile`.

---

## 1. What moves

Seven handles. The vitals are a **group with breakout**: drag the group badge and all
four plates plus the chips travel together; drag one plate and it leaves the formation
with its own offset. Resetting a member snaps it back into the stack; resetting the group
sends everything home.

| # | Handle        | Element     | Belongs to |
|---|---------------|-------------|------------|
| 0 | VITALS GROUP  | `#stack`    | —          |
| 1 | HP            | `#p_hp`     | group      |
| 2 | H2O           | `#p_h2o`    | group      |
| 3 | FOOD          | `#p_food`   | group      |
| 4 | WANTED        | `#wplate`   | group      |
| 5 | CHIPS         | `#chips`    | group      |
| 6 | MINIMAP       | `#mapwrap`  | —          |

The minimap moves as one piece — `#brg` (the GPS bearing bar) is sized to sit directly
above `#map` and is orphaned on its own.

---

## 2. Mechanism — why `transform`, and why a stylesheet

Measured against `hud.html`, not assumed:

* `render()` rewrites **`style.bottom` on all three plates** (line 285) and **`style.bottom`
  on `#chips`** (line 308), every tick. Anything the editor writes to `bottom`/`top`/`left`
  is gone within 83 ms.
* `render()` rewrites **`className` on all three plates** (line 288) and on `#wplate`
  (line 298). A CSS class added by the editor is wiped just as fast.
* `transform` is written **nowhere** on `#stack`, `#p_*`, `#wplate`, `#chips` or `#mapwrap`.
  The only transforms in the page are on `.seg i`, `#mrot`, `#mnorth`, `.ring` and `#mme` —
  all children or unrelated.

So position is carried by `transform`, and it is delivered as an injected stylesheet
(`<style id="apLay">`) rather than inline style, so nothing the page writes per-tick can
collide with it.

Plates are **children of `#stack`**, so a transform on `#stack` moves them for free — the
group is one property, not five. `#chips` is a *sibling* of `#stack`, so it adds the group
vars explicitly. `#mapwrap` is independent.

```css
#stack   { transform: translate(calc(var(--apgx)*100vw), calc(var(--apgy)*100vh)) }
#p_hp    { transform: translate(calc(var(--aphx)*100vw), calc(var(--aphy)*100vh)) }
#p_h2o   { transform: translate(calc(var(--apwx)*100vw), calc(var(--apwy)*100vh)) }
#p_food  { transform: translate(calc(var(--apfx)*100vw), calc(var(--apfy)*100vh)) }
#wplate  { transform: translate(calc(var(--apbx)*100vw), calc(var(--apby)*100vh)) }
#chips   { transform: translate(calc((var(--apgx) + var(--apcx))*100vw),
                                calc((var(--apgy) + var(--apcy))*100vh)) }
#mapwrap { transform: translate(calc(var(--apmx)*100vw), calc(var(--apmy)*100vh)) }
```

Offsets are **viewport fractions**, not pixels or rem. `100vw`/`100vh` is the browser
control's own box, and the control is `safezoneX/Y/W/H`, so a layout built at one
resolution or UI-scale lands in the same relative place at another. Default `0,0` is the
designer's layout, untouched.

### 2.1 The `off` reflow, and when it gets pinned

When a bounty exists the page sets `off = 3.15` and shoves all three plates and the chips
up by that much, clearing `bottom: 0` for `#wplate`. In a hand-built row that is a 3.15rem
jump the moment the player gets wanted.

Pinning `bottom` at the *no-bounty* values is not an option: `#p_food` sits at `bottom: 0`
and `#wplate` is also at `bottom: 0` and 2.75rem tall — they would overlap. The pin
therefore uses the **wanted-present** values, so the layout is identical either way:

```css
#p_hp  { bottom: 9.05rem !important }   /* 5.90 + 3.15 */
#p_h2o { bottom: 6.10rem !important }   /* 2.95 + 3.15 */
#p_food{ bottom: 3.15rem !important }   /* 0.00 + 3.15 */
#chips { bottom: 14.15rem !important }  /* 11.0 + 3.15 */
```

**The pin only arms in breakout mode** — when at least one *member* offset (handles 1–5) is
non-zero. A player who never opens the editor, or who only moved the group or the minimap,
gets the stock page behaviour byte for byte. No default HUD change for anyone who did not
ask for one. The editor arms the pin the instant the first plate is dragged out of
formation, so what is on screen while editing is what ships.

### 2.2 `hud.html` is not edited

Its header states that a designer re-drop replaces the whole document and preserves only
the bridge shim element. Any drag code written into the file would be lost on the next
drop. Everything the editor does is injected at runtime:

* the stylesheet, via `webui_fnc_exec`;
* the editor overlay itself, from `ui\html\hudedit.js`, fetched by the page through
  `A3API.RequestFile` — the same call the shim already uses to load `webui.js`, and the
  one path the arma-webui audit proved is never refused (`loadFile` is, uncatchably, on
  clients). `ui\html\*` is already in the `allowedHTMLLoadURIs` whitelist.

---

## 3. The editor

### 3.1 Host

New dialog `AP_web_hudedit` — **idd 938400**, browser control **938401**, `safezoneX/Y/W/H`,
`colorBackground[] = {0,0,0,0}`, `url = "ui\html\hud.html"`.

A title layer is cut with `cutRsc` and is never focused, which is exactly why the live HUD
can sit over gameplay — and exactly why it can never be dragged. The editor is therefore a
**dialog**. Precedent is shipped: `AP_web_visor` (941700) is a full-screen transparent
browser dialog over the live world.

The live layer (938300) is cut down for the duration, so the player is not dragging one
HUD across a frozen copy of itself. `AP_hudEditActive` gates `fn_hudWebInit`'s keeper so it
does not fight to re-cut the layer while the editor is open.

### 3.2 What SQF does on open

1. `webui_fnc_init` on control 938401.
2. Push one **synthetic payload** on the `hud` channel — real vitals and real map, but with
   `wanted` forced non-zero, `regen` and `paused` forced true. Without that the WANTED plate
   is `display:none` and the chips are absent, and a player with no bounty could not place
   two of the seven handles.
   Implemented as a third mode on `AP_fnc_hudWebPush` (`"edit"`) with an explicit target
   control, so the payload is built by the one function that already knows how — no second
   copy of the tile/marker logic to drift.
3. Apply the current layout (stylesheet + vars).
4. Inject the editor bootstrap, which pulls `ui\html\hudedit.js` and runs it.
5. Register `hudLayoutSet` / `hudLayoutCancel` **on this control only**.

### 3.3 Interaction

* Click selects, drag moves. Group badge drags the whole vitals formation.
* Arrow keys nudge the selection 1px; Shift+arrow 10px. Page-side `keydown` is proven in
  this mission — `terminal.html` is the breach minigame and the player types into it,
  single characters with `preventDefault()`.
* Snap guides against the other handles' edges and centres, and against the viewport
  centre lines and thirds. 6px threshold, guides drawn on the overlay.
* Drag and nudge both clamp to the viewport via `getBoundingClientRect()`, so nothing can
  be lost off-screen.
* Toolbar: **SAVE**, **CANCEL**, **RESET SELECTED**, **RESET ALL**.
* Selection outlines and labels live on a **separate absolutely-positioned overlay layer**
  mirroring each target's bounding box — never classes or inline style on the targets,
  because `render()` overwrites both.
* Esc and dialog `onUnload` both revert. Only SAVE writes.

---

## 4. Security

`hud.html`'s shim is display-only on purpose: no `call()`, no `ask()`, no verb registered
against the live layer, and consequently no `CfgRemoteExec` entry for the HUD at all. Its
header is explicit that there is no name a page-side script can reach SQF through.

That property is preserved:

* `hudLayoutSet` / `hudLayoutCancel` are registered with `webui_fnc_on` **on the editor
  control (938401) only**. The live layer's control never has them.
* The live layer stays receive-only. The stylesheet reaches it as `ExecJS` — SQF → page,
  which requires nothing of the page.
* The editor's injected JS reaches SQF via `window.WEBUI.call` directly. The shim's
  omission of `call()` was never a sandbox, and the verbs exist only on the dialog the
  player just deliberately opened.

Server side:

* Identity comes from `remoteExecutedOwner`, never the payload — the standing `-SEC-` rule.
  `remoteExecutedOwner` is frame-local and the handler suspends on the DB, so the owner id
  is captured in the first frame and carried across the `spawn`, the `APS_fnc_dutySRV`
  pattern.
* The payload is validated to be **exactly seven pairs of numbers in `[-1, 1]`** before
  anything else happens. Anything else is refused and logged.
* The SQL is built from the **validated numbers**, formatted `%1` by SQF from real numeric
  values. No client text reaches a query.
* `allowedTargets = 2` on `APS_fnc_hudLayoutSRV` (client → server) and `allowedTargets = 1`
  on `AP_fnc_hudLayoutRecv` (server → client).

### 4.1 The two constraints, explicitly

* **Never compiled.** The stored layout is read back with `parseSimpleArray`, matching
  `fn_queryRequest.sqf:40` ("SECURITY: parse, never call compile — a poisoned free-text
  column would otherwise execute as SQF on login (Lystic compile-RCE class)"). Nothing in
  this feature calls `compile`, `call compile`, or `compileFinal`, in any namespace.
* **Not the profile.** `profileNamespace` is not written and `saveProfileNamespace` is not
  called anywhere in this feature. The database is the only store. The client cache lives
  in `missionNamespace` as `AP_hudLayout` — plain numbers, and it is rebuilt from the DB on
  every login.

---

## 5. Persistence

```sql
ALTER TABLE players_global ADD COLUMN IF NOT EXISTS ui_layout jsonb DEFAULT NULL;
```

`players_global`, not `players`: a HUD layout is an account preference, and it should
follow the player across civ / cop / medic and every character. `players_global` is
already the account-scope table (achievements, stats, keys, mailbox).

Stored as an **array of arrays of numbers** in the handle order of §1. v1 wrote pairs; v2 (§9)
writes triples `[dx, dy, s]`. Pairs are still read (s = 1):

```json
[[0,0,1],[0.10,-0.04,1],[0.05,-0.04,1.2],[0,-0.04,1],[0,0,1],[0,0.02,1],[-0.31,0.44,1.5]]
```

Numbers only, no object keys — which is what makes `parseSimpleArray` sufficient and
`compile` unnecessary. `NULL` means "never edited" and reads back as seven zero pairs.

### 5.1 Load path — deliberately not the login array

`DB_fnc_queryRequest` builds "the exact 32-element side-array" that `fn_requestReceived`
reads **by index**. That index map is the same class of structure that produced the
stat/title corruption; a cosmetic setting is not worth touching it.

Instead the layout is fetched **once, by the HUD keeper, on its first successful bridge**.
One extra query per login, off the login critical path, zero index-map churn. The HUD
renders at the designer's defaults until the answer lands a fraction of a second later —
which is the correct failure mode: a DB hiccup gives the player the shipped layout, not a
broken one.

---

## 6. Entry point

`AP_fnc_deckSettings` grows an **INTERFACE** group with one row of a new type, `action`:

```
INTERFACE
  Rearrange HUD                              [ OPEN ]
```

`action` is the third row type after `toggle` and `range`/`pct`; `deck.html` renders it as
a labelled button and posts `settingsAction` with the row id. `AP_fnc_deckOpen` registers
`settingsAction`, which for `hudEdit` closes the deck (two dialogs cannot be open at once)
and spawns `AP_fnc_hudEdit`.

---

## 7. Files

**New**

| Path | Purpose |
|---|---|
| `dialog/hudEdit.hpp` | `AP_web_hudedit` 938400 / control 938401 |
| `ui/html/hudedit.js` | the editor overlay — drag, snap, nudge, toolbar |
| `core/web/fn_hudEdit.sqf` | entry point: guard, cut the live layer, create the dialog |
| `core/web/fn_hudEditOpen.sqf` | dialog `onLoad`: bridge, synthetic payload, inject, verbs |
| `core/web/fn_hudLayoutApply.sqf` | build and push the stylesheet to a given control |
| `core/web/fn_hudLayoutGet.sqf` | ask the server for this account's layout |
| `core/web/fn_hudLayoutRecv.sqf` | server → client reply: validate, cache, apply |
| `server/AP_server/core/web/fn_hudLayoutSRV.sqf` | get / set, owner from `remoteExecutedOwner` |
| `deploy/hud_layout.sql` | the `ALTER TABLE` |

**Modified**

| Path | Change |
|---|---|
| `description.ext` | `#include "dialog\hudEdit.hpp"` |
| `Functions.h` | six client function entries |
| `CfgRE.hpp` | `APS_fnc_hudLayoutSRV` (2), `AP_fnc_hudLayoutRecv` (1) |
| `server/AP_server/config.cpp` | `hudLayoutSRV` in the web class |
| `core/web/fn_hudWebInit.sqf` | fetch layout on first bridge, apply on every re-bridge, stand down while the editor is open |
| `core/web/fn_hudWebPush.sqf` | optional target control + `"edit"` mode |
| `core/web/fn_deckSettings.sqf` | INTERFACE group, `action` row |
| `core/web/fn_deckOpen.sqf` | `settingsAction` verb |
| `ui/html/deck.html` | render an `action` row, handle its click |

---

## 8. Verification

No script can confirm the thing that matters — that a dragged plate is where the player
put it, on their screen, at their UI scale. So the check is split.

**Automated — all of this ran, results as noted**

* `tools/run_checks.sh` — 25 passed, 0 failed, including two gates added for this feature.
* `tools/test_hudedit.js` — 36 assertions against `hudedit.js` driven through a stubbed DOM:
  offset round-trip, group-moves-members, minimap independence, breakout arming the pin only on
  a member move, viewport clamp in both directions for all seven handles, nudge (including the
  correct *refusal* to nudge into an edge), the save payload's shape against the server
  validator's contract, and both resets.
* `tools/hudlayout_parity.py` — extracts the `RULES` and `PIN` blocks from
  `fn_hudLayoutApply.sqf` and from `hudedit.js` and diffs them. Currently byte-identical.
  Negative-tested: perturbing one copy makes it exit 1, so it is a gate and not a decoration.
* `node --check ui/html/hudedit.js`, `sqf_balance.py` over all 1519 SQF files,
  `sqf_cmd_check.py` over every new and changed file (only unknown-token hits are the webui
  library names and the mission's own globals, as on the files that already existed).
* `harvest_corpus.py --lint` — the two new statements are native PostgreSQL, corpus refreshed
  437 → 439.
* Both SQL statements executed against the dev schema inside a transaction, parameterised
  exactly as the server sends them, and rolled back. **This is where a guess turned out to be
  right for a measurable reason:** `ui_layout::text` comes back as
  `[[0.00000, 0.00000], [0.10000, -0.04000], …]` — *with* a space after every comma, which
  `parseSimpleArray` does not accept. The strip in `fn_hudLayoutSRV` is now measured, not
  anticipated.
* Dev deploy (`Armapunk2035_b0798.Malden`): config parsed clean, clean boot, no script errors,
  no undefined variables.
* `deploy/hud_layout.sql` applied to the dev database (`pgm_full_scratch` — *not* `armapunk`,
  see HANDOFF's hazards); `players_global.ui_layout` is present and jsonb.

Not covered by any of it: the SQF validator itself. There is no SQF test harness in this repo,
so `_fnNorm`'s reject cases are argued rather than executed. It is deliberately the strict half
of the pair, and the client's clamping twin stands between a bad answer and a broken HUD.

**In game**

1. Open the deck → Settings → INTERFACE → Rearrange HUD. Editor opens, world visible
   through it, WANTED plate and both chips present even with no bounty.
2. Drag the group badge — all four plates and the chips move together.
3. Drag HP out — HP alone moves; the others hold; the stack settles onto its pinned
   positions and does not move again when the fake bounty is on screen.
4. Nudge with arrows, check the snap guides catch the other plates' edges.
5. SAVE → editor closes, live HUD returns wearing the new layout.
6. Relog → layout is still there. `SELECT ui_layout FROM players_global WHERE playerid=…`
   shows seven pairs.
7. CANCEL after moving things → nothing persisted, live HUD unchanged.
8. RESET ALL → SAVE → column back to seven zero pairs, HUD back to the designer's layout,
   and the `!important` pin is gone (verify the stack shifts again when a bounty lands).

---

## 9. RESIZE — v2, 2026-09-07

Placing was not enough: a player at 4K wants the plates bigger, a player on a laptop wants the
minimap smaller. Every handle gains a **uniform scale `s`**, default 1, range **0.25–3.0**.
Uniform, not stretch: `scale(sx, sy)` would distort the glyphs and the angled clip-path corners,
and nothing in the HUD reads better wider than taller.

### 9.1 Data

| | v1 | v2 |
|---|---|---|
| entry | `[dx, dy]` | `[dx, dy, s]` |
| dx, dy | viewport fraction, `[-1, 1]` | unchanged |
| s | — | number, `[0.25, 3]`, default 1 |
| emitted | `toFixed 5` | `toFixed 5`, all three |

* **Server `get`** accepts an entry of **2 or 3** numbers; a pair reads as `s = 1`. Legacy rows
  keep working with no migration — the column is jsonb, its shape is the array, no `ALTER`.
* **Server `set`** stays strict and rejects: exactly 7 entries, each exactly 3 finite numbers,
  dx/dy in `[-1, 1]`, s in `[0.25, 3]`. Anything else refused whole, `-SEC-` logged, answered
  with what is stored (unchanged pattern).
* **Client `AP_fnc_hudLayoutNorm`** clamps: `param [2, 1]`, non-finite → 1, out of range → edge.
* `_zero` becomes seven `[0, 0, 1]`.

### 9.2 CSS — the same channel, one more function

`transform` already carries position and `render()` never writes it, so scale rides in the same
declaration. Each rule gains `scale(var(--apXs))` and a `transform-origin`:

| Element | origin | why |
|---|---|---|
| `#stack`, `#p_*`, `#wplate`, `#chips` | `right bottom` | anchored `right`/`bottom`; the plates' right edges stay aligned, the staircase keeps its shape |
| `#mapwrap` | `left top` | anchored `left`/`top` |

```css
#stack  { transform-origin:right bottom;
          transform: translate(calc(var(--apgx)*100vw), calc(var(--apgy)*100vh)) scale(var(--apgs)) }
#p_hp   { transform-origin:right bottom;
          transform: translate(calc(var(--aphx)*100vw/var(--apgs)), calc(var(--aphy)*100vh/var(--apgs))) scale(var(--aphs)) }
/* #p_h2o #p_food #wplate identical in shape */
#chips  { transform-origin:right bottom;
          transform: translate(calc((var(--apgx) + var(--apcx))*100vw),
                               calc((var(--apgy) + var(--apcy))*100vh - 12.15rem*(var(--apgs) - 1)))
                     scale(calc(var(--apgs)*var(--apcs))) }
#mapwrap{ transform-origin:left top;
          transform: translate(calc(var(--apmx)*100vw), calc(var(--apmy)*100vh)) scale(var(--apms)) }
```

Three things in there are load-bearing:

* **Members divide their translate by the group scale.** A member is a child of the scaled
  `#stack`, so a raw `calc(var(--aphx)*100vw)` would land at `dx·vw·sg` screen pixels and a saved
  member offset would mean something different at every group scale. Dividing by `--apgs` keeps
  `[dx, dy]` a true screen fraction for every handle, which is also what keeps the editor's
  `appliedPx` a single formula. Members' *effective* scale is `sg × own` for free, by nesting.
* **Chips ride the scaled stack.** `#chips` is a sibling, so it neither inherits the group scale
  nor moves when the stack grows. Its scale is written as the product, and its Y gains
  `−12.15rem·(sg − 1)`: with the pin armed the chips' bottom is 14.15rem and the stack's is 2rem,
  so the chips sit 12.15rem above the stack's origin and scaling the stack about that origin
  moves them by exactly that much. Both are `right: 2rem`, so X is already aligned.
* **The pin arms when `sg ≠ 1`, as well as in breakout.** Unscaled, a bounty shoves plates and
  chips up 3.15rem in lockstep. Scaled about `right bottom`, the plates' shove is `3.15·sg` on
  screen and the chips' is `3.15` — they separate. Pinning removes the shove and the 12.15rem
  constant above becomes exact. Member scale alone does not arm the pin: it changes no `bottom`.

The empty-sheet condition becomes: every dx, dy = 0 **and** every s = 1.

### 9.3 Editor geometry

The editor reads live boxes with `getBoundingClientRect()` and needs the untransformed base rect
back. Live = base scaled about its origin corner by `s_eff`, then translated by `T`. Inverting:

```
right-bottom origin:  B.w = live.w / s     B.right  = live.right  - Tx     B.bottom = live.bottom - Ty
left-top origin:      B.w = live.w / s     B.left   = live.left   - Tx     B.top    = live.top    - Ty
s_eff (members)   = sg · s_own          s_eff (group, minimap) = s_own
```

Clamp and snap keep operating on the **live** rect, so nothing changes there — a scaled plate is
kept on screen by its scaled edges.

**Corner grips.** The selected box shows four 8px grips. Dragging grip C with opposite corner F:

```
s' = clamp( max( |cursor.x - F.x| / B.w , |cursor.y - F.y| / B.h ), 0.25, 3 )
```

F stays screen-fixed. When F is not the transform-origin corner, the translate is compensated by
the amount the origin-relative scaling would have moved F (e.g. origin RB, F = LT:
`Tx' = Tx + B.w·(s' − s)`, `Ty' = Ty + B.h·(s' − s)`). For a member, the compensation is in the
member's own (group-divided) fraction. The group's grips sit on the union box and scale the group;
the members' own scales multiply on top.

**Wheel** over any box: ±2 % per notch, **centre-fixed** (translate compensated so the box grows
about its middle). **Keys** `+`/`=` and `-`: ±1 %, Shift ×5, on the selection, centre-fixed.
**RESET THIS** → `[0, 0, 1]`; **RESET ALL** → seven of them. Hint line:
`CLICK SELECT · DRAG MOVE · CORNERS/WHEEL/+- RESIZE · ARROWS NUDGE · SHIFT ×10`.

### 9.4 Untouched

`hud.html` (the re-drop rule in §2.2 still holds), the SQL schema, `fn_hudWebInit`,
`fn_hudWebPush`, the deck entry, `CfgRE`.

### 9.5 Known limits

* The minimap's tiles are rem-sized `<img>`s and its water mask a 320px canvas; the page cannot be
  told to re-render at a larger size, so at `s > 1` the map is softer than the plates. Accepted.
* A v1 row's member offsets were saved under "raw child translate" semantics. They differ from v2
  semantics only when the group is scaled, and no v1 row has a group scale — so nothing moves.

### 9.6 Files

| Path | Change |
|---|---|
| `ui/html/hudedit.js` | scale in `L`, RULES with scale + origins, base-rect inversion, grips, wheel, keys, triple payload |
| `core/web/fn_hudLayoutApply.sqf` | RULES/PIN with scale, `--apXs` vars, `_moved`/`_breakout` conditions |
| `core/web/fn_hudLayoutNorm.sqf` | triples, clamp s |
| `server/AP_server/core/web/fn_hudLayoutSRV.sqf` | `_fnNorm` lenient-on-get / strict-on-set, `_zero`, triple JSON |
| `core/web/fn_hudEditOpen.sqf` | `APHE_INIT` triples |
| `tools/test_hudedit.js` | scale round-trip, fixed-corner invariant, wheel centre invariant, legacy pair read, clamp at 0.25 / 3, payload shape, pin on group scale |
| `tools/hudlayout_parity.py` | verify the scan still binds; adjust only if the anchors moved |

### 9.7 Verification

Automated: `tools/run_checks.sh` (parity + harness), `node --check`, `sqf_balance.py`,
`sqf_cmd_check.py` on every changed file, dev deploy clean boot.

In game (owner):

1. Editor open → select HP → drag its top-left grip outward: HP grows, its bottom-right corner
   does not move, other plates hold.
2. Wheel over the minimap: grows about its centre, stays on screen at 3.0.
3. Scale the VITALS GROUP: plates and chips grow together, chips stay above the stack. SAVE.
   Get a bounty — nothing jumps (pin armed by the group scale).
4. Relog → sizes persist. `SELECT ui_layout …` shows seven triples.
5. RESET ALL → SAVE → row is seven `[0,0,1]`, HUD stock, pin gone.
6. An account that never opened the v2 editor (pairs in the column) loads with s = 1 everywhere.
