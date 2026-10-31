# Handoff — current state

`CLAUDE.md` imports this file, so it is in context every session. Keep it
short and keep it true: what is in flight, what is next, and what will bite.
Finished work belongs in the doc for its subsystem, not here.

Last updated 2026-09-03.

---

## Luxe AV (autonomous air taxi) — 2026-09-22, quad-rotor rebuild live b2041 (09-23), UNPLAYED

`ap_av_lux` in the new `ap_av` addon (`@Armapunk2035`); the mission now REQUIRES `ap_av`. Admin-spawn
only (admin vehicle list); passengers pick one of six verified helipads (`AP_avDest`, server_init) and the
SERVER flies it with the summon core (`APS_fnc_avSRV` verbs → `APS_fnc_avFly` → `AP_fnc_hcFly`). Kill
switch `SRV_avEnabled`. Engine smoke flies the real code end to end
(`design/av-hovercraft/engine_smoke_av.py`, 0 m pad error). Playtest: **`AV_SOAK.md`**. Two things to
know: the dedicated server cannot see streamed map objects, so destinations must be verified pads; and
Arma vehicle models face -Z (the build maps Blender (x,y,z) -> P3D (-x, z, -y)). Since 09-23 it is a quad-rotor (tilting pods gone);
the heli sim needs the `rotor_main_center`/`rotor_tail_center` memory points above the roof or it
ground-strikes its own virtual rotors and kills them.

## Vertical City tower replaced skyscraper30 — 2026-09-22, live b2038

The ap_vcity addon tower (`design/vertical-city/`, hard-surface pass, `HARDSURFACE_LOG.md`) stands
on skyscraper30's site: `custom_p3ds/vcity_tower.sqf` assembles 199 `Land_vc_*` objects server-side
(kill switch `SRV_vcityEnabled`). **The mission now REQUIRES ap_vcity** (mission.sqm `addons[]`):
players need `@Armapunk2035`; server + HC load it via `-mod=@Armapunk2035` (box copy in
`~/arma3server_live/@Armapunk2035/`, ap_vcity only). **Luxe Suites is OFF** — the skyscraper30 row
(9649) and kiosk row (13678) are soft-deleted with 19 street pieces; restore SQL in
`deploy/map_backups/vcity_site_20260922.sql` (tombstones purge after 7 days). Remapping suites onto
the new tower's apartments is the open follow-up. `ap_vcity.pbo` has no `radio/addon/` source tree —
see `radio/addon/PROVENANCE.md` before running `build_addon.sh`.

## Deck-app wave (UI overhaul) — 2026-08-26

The owner's design handoff (design_handoff_dialogs zip) is IMPLEMENTED: every
approved mock is a deck app behind `AP_deckApps` (init.sqf, default true —
false falls every routed entry back to its native dialog in one flip).

**Built (16 apps + infra):** Bank (ATM), Exchange (browse/buy/mine/vault),
Fabricator, Garage, Trunk (queue-and-commit, vehicles), Vehicle Shop
(+configure), House dashboard, Gang command (bank/tag/wars/leadership on the
existing My Gang view), Chop Shop, Pay 'n' Spray, Loadout Rack, Stencils
(spray+hex picker), MaxSec Intake (charges+tickets), Trauma Dispatch, Luxe
Suites, The Pit (duels), Daily Bonus. Infrastructure: CTX_APPS registry in
deck.html, viewConnect handshake, AP_deckCtx on fn_deckOpenApp,
tools/html_js_check.py in run_checks.

**Method:** natives are parametrized, not copied — pull/sell/repair/to-gang,
take/store, vehicle buy, equip loadout, bank trio, gang bank trio, chop
sell/claim all take params and fall back to their own listboxes. One copy of
every rule. closeDialog calls inside them are guarded to their own idd.

**Deliberately still native (each with its reason in the commit):**
  - Factory (mock has vehicle prints in printer slots; server builds instantly)
  - Garage MOD BAY (own 135-line screen; deck closes into it and reopens after)
  - Exchange CREATE LISTING (reads a trunk interactively at the broker)
  - Trunk for HOUSES + admin force-opens (seize/store-all + the serialize-lock
    history)
  - Treasure map (engine AP_RscMapControl — cannot exist in CEF)
  - Spawn selection (respawn choreography is its own pass)
  - Gang garage list (personal garage is deck; gang variant next pass)
  - Tutorial content (the mock's paying checklist is design work)
  - cyberdeck native DIALOG FILES (entries all rerouted; files deleted after
    playtest per the fallback doctrine in fn_keyDownHandler)

**Group/Squadnet:** already fully covered by the deck list app — nothing to port.
**Playtest:** every app + the AP_deckApps=false fallback path.

## Physical storage in the STORAGE screen — built 2026-09-05, unplayed

The web STORAGE screen (938000) can move PHYSICAL gear in and out of a house,
not just virtual goods. Design + playtest script: **`storage_physical.md`**.

Three things worth knowing before touching it:

- **The natives do the moving.** `stMove` sets nothing up of its own: it hands
  `fn_takeInventory` / `fn_storeInventory` `[item, str qty, max]` and lets them
  run, because their physical branches carry #288, #328/#341, #369, #545, #581
  and the cop seize path. Do not grow a second copy of that logic here.
- **`_deckMax` is the whole fix, and -1 is load-bearing.** Those branches took
  their quantity ceiling from `lbValue[4502/4503]`, which off dialog 4500 reads
  0 — so the transfer loop ran zero times and every physical move through the
  deck app and this screen was a silent no-op. -1 means "not supplied" and keeps
  an un-updated caller on the old listbox read; make it 0 and you re-break it.
- **Physical is HOUSES only, and that is a rule not a preference.**
  `fn_refreshInventory:9-11` refuses physical on a Car/Air/Ship because a vehicle
  already owns real engine cargo; a parallel `AP_pinv` would give one rifle two
  homes. Physical bulk-to-vehicle therefore writes real engine cargo.

State: dev b0946, clean boot, `run_checks` 36/37 (`fab_check` pre-existing).
**Nothing has been played.** The deck trunk app's physical moves were dead for
the same reason and are fixed alongside — they need the same qty-clamp check.

## mapdb — zero placement data in the client PBO — built 2026-09-04, headless-proven

`map_objects` is the ONLY source of placed objects. `fn_mapData.sqf`, `custom_p3ds/malden_buildings.sqf`,
the 19 zone circles and the composition-zone loader are gone from the mission. The server loads the
table at boot (`APS_fnc_mapLoad`, ~11 s for 9,469 rows), bins it into 1 km cells and hands each cell
to clients on demand as one engine-deflated blob; clients run a per-object streamer (`AP_fnc_mapTick`:
create within `stream_r`, delete beyond `stream_r + 250`, skip rows above the detail tier). Design
**`mapdb.md`**, plan `mapdb_plan.md`.

Four things worth knowing before touching it:

- **Numbers never go through `str`/`format` on the way to a client.** Both print six significant
  figures; `AP_fnc_mapRowText` (toFixed) is the one serialiser and `APS_fnc_mapRowUpdate` keeps the
  PARSE of that text as the server's canonical row, so server, blob and client agree by construction.
  The old delta path's `parseNumber format` coercion was silently rounding east-map coordinates by up
  to 5 cm; it now leaves Numbers untouched.
- **`AP_fnc_mapTick` is the only creator/deleter on a client.** `AP_fnc_mapEditApply` only edits the
  row maps and marks ids dirty, because remoteExec'd functions run scheduled and would interleave
  with the tick. An edit that races a cell fetch is buffered per cell and replayed by rev.
- **Rows carry `init` CODE.** `APS_fnc_mapFetch` is read-only (CfgRE 2, requester from
  `remoteExecutedOwner`, 6 requests / 10 s, ≤ 64 keys); the reply fns and `AP_fnc_mapEditApply` are
  server-origin only (not in CfgRE + a `remoteExecutedOwner != 2` gate, `mapdb.md` D6), and the
  row stores on both sides (the client streamer's `AP_map*`, the server cache's `APS_map*` including
  the SELECT column list) live in `localNamespace`, which `publicVariable` cannot reach — no client
  can push a row or a blob at another. `init` stays trusted-writer-only (`APS_fnc_mapEditSRV` never writes it).
- **Editing:** F12 in-game editor unchanged; 3DEN = `edit-map.sh stage` (reads the DB, both layers
  carry `AP_ID=`) → edit → `push` (both layers by id; `AP_LOD=` / `AP_R=` tokens set tier / radius).
  `apply` is retired. SQL works too: `UPDATE map_objects SET stream_r = 300 WHERE id = N` lands on
  every client within 10 s (poll). Migration inputs are FROZEN beside `tools/map_migrate_v3.py`.

State: dev b0943, gate 35/36 (the one failure is `fab_check`'s pre-existing printer preview-class
clash), headless `mapselftest core` 10/10 PASS, **owner joined and the town streamed in (2,282
objects within 10 s)** after two same-day fixes (`mapdb.md` §Owner playtest). The rest of the
owner checklist (`mapdb.md` §Playtest, items 3-7) is still open. `lux_footprint.sqf` still hard-codes the lux tower's
centre; move the row, move the literal.

## PostGIS — installed 2026-09-04

Dev DB runs `postgis/postgis:18-3.6`. `map_objects.geom` (GiST), `map_cell_key()`, and the
`faction_territory` table with the fixer polygons (server publishes `AP_factionPolys`; bot verb
`territoryreload`; `tools/bake_territory.py` writes the table). `tools/map_query.py` for spatial
questions. Notes, install steps, verify: **`postgis.md`**.

## The I-screen + GUNSMITH — built 2026-09-03, unplayed

`I` opens `ui/html/inventory.html` (dialog 938500) in place of the engine's display 602:
worn gear on a figure, the three containers, what is in reach (vehicle / crate cargo, the
ground pile, suitcases) and the virtual bag on one page, drag-and-drop with a button for every
drag, and a GUNSMITH panel (double-click PRIMARY / HANDGUN) for attachments and the magazine.
Design + build design: **`INVENTORY_SPEC.md`** (§9 is the build), plan `inventory_plan.md`.

Three things worth knowing before touching it:

- **Own-body moves are client-local; anything shared goes through ONE server function.**
  `APS_fnc_invCargo` is the only code that rebuilds a vehicle's, crate's or ground holder's
  cargo (read → clear → re-add, inside `isNil { }` so nothing interleaves). Do not add a second
  cargo writer anywhere; that is the dupe class the native dialog's single-user lock was hiding.
- **Every scripted move replays the Take/Put handlers** (`fn_invCommit`): logging, the
  shared-container dupe check, role-item force-drops, saveGear. A new verb that skips
  `fn_invCommit` silently loses all of that.
- **CTRL+SHIFT+I is the native 602**, one keypress away, until this has been played. The hook
  is two lines in `evh/fn_inventoryOpened.sqf` (`AP_invForceNative`); revert those and the
  engine inventory is back.

The WORN figure is the player's real body: a local off-world mannequin in a lit black-box
studio, shot by one PiP camera into a native picture UNDER the browser (the page cuts a
hole for it; nothing native draws above the browser); drag the strip to turn him. Exposure
is pinned while it's up. Every law learned is spec §9.8 / `fn_invFigure.sqf`'s header.

State: page harness 17/17, `run_checks` balance green, dev b0928. Figure verified in-game by the owner day and night (b0927/b0928: owner-tuned light dial blended on sunOrMoon). **No `I` has
been pressed in a client.** The owner probe list is `INVENTORY_SPEC.md` §9.7.

## Faction rework (duty system) — code complete, unplayed

MaxSec and Trauma Team are no longer lobby slots. `mission.sqm` ships 60
identical civilian slots and nothing else; a player walks to an HQ terminal and
clocks on, and the server writes a roster entry (`AP_dutyRoster`, uid →
`[faction, role, startTime, startPos, confirmed, ownerId]`) that lasts until they
clock off, disconnect, or the watchdog takes it back. **The roster is the
authority** — not the engine side, not a slot name, not anything the client
sends. Every server-side "is this a cop" check goes through
`APS_fnc_isDutyCop` / `APS_fnc_isDutyMed`.

Chain, in order, all open at the time of writing:

| PR | branch | what |
|---|---|---|
| #35 | `duty/pr1-group-hygiene` | `deleteWhenEmpty` player groups, initGang race, squad side guards |
| #36 | `duty/pr2-effside` | `AP_effSide` indirection over `playerSide` (zero-behaviour sweep) |
| #37 | `duty/pr3-payload` | whitelist levels in every login payload + effSide co-gates |
| #38 | `duty/pr4-framework` | the duty framework itself, behind `AP_dutyEnabled` (default off) |
| #39 | `duty/pr5-routing` | server-side trust: roster-routed saves, garage, disconnect, 48 gates |
| #40 | `duty/pr6-respawn` | Trauma hospital spawns, duty-proof respawn, roster tenure, FSM pay |
| #41 | `duty/pr7-flip` | **the flip** — civilian-only lobby, duty on by default |
| — | `duty/pr8-hardening` | hardening, dead-code cut, and `DUTY_SOAK.md` |
| — | `duty/pr9-landing` | the landing screen: welcome splash + faction picker at connect |

They merge in that order or not at all.

**The kill-switch.** `AP_dutyEnabled` in `server_init.sqf`. Set it false and
redeploy and the world runs as a plain all-civilian server: no groups, no roster,
no terminals, `APS_fnc_dutySRV` exits at its first line, every compat clause
falls back to its pre-duty reading. Rolling back is one boolean, not a revert of
seven PRs. Flipped at RUNTIME it now also drains the roster within 60 s
(one `["remove","flag-off"]` push per rostered player) instead of stranding
everyone west in a duty kit — that drain is the only thing in the system that
runs with the flag off, and it is why `AP_fnc_dutyClient`'s `"remove"` arm is
deliberately let through its own flag gate.

**The deploy invariant, and it bites hard.** The compat clauses key on the flag
ALONE, never on "the roster is empty". Ship the flag `true` against a
mission.sqm that still has west/independent slots and **every serving officer
loses all authority the moment the server boots**. Flag and slots are one
deployable unit, in both directions. Never deploy the mission PBO and the server
addon from different commits.

**The landing screen has its own switch.** PR9 replaced the lobby welcome's PLAY
gate with a full-screen page (`dialog\web_landing.hpp`, 938100) that also picks
the deployment: solo civilian, MaxSec or Trauma. It rides the EXISTING
`APS_fnc_dutySRV` request path with the faction's default role, adds no CfgRE
entry, and is gated by `SRV_landingEnabled` (`server_init.sqf`, publicVariable'd,
default true) — a **separate** boolean from `AP_dutyEnabled`, so a bad welcome
screen can be reverted without taking the shifts down and vice versa. False =
`AP_fnc_landingOpen` declines and `fn_initCiv` runs the pre-PR9 flow verbatim.
Fresh accounts on the intake path and jailed accounts never see it.

**Nothing here has been played.** It is proven by static tracing and one clean
boot (60 roles, roster live, zero errors). The owner playtest script is
**`DUTY_SOAK.md`** at the repo root — sections A–C need one client, D needs two,
E is the kill-switch, G is the list of calls only the owner can make, and H is
the landing screen (which you meet before A, on the connect itself). Run it
before this goes anywhere near players.

**A pgmigrate side-effect, unrelated to playability.** `pgmigrate` corpus.json
still attributes 4 statements to files deleted in the rework — harmless
(consumers read only `row.sql`); next re-harvest drops 400→396, above the
>350 floor.

---

## PostgreSQL — the conversion is DONE; the game and website are native

Landed 2026-08-21 via #45+#46 (the whole chain: harness → codec unification →
port batches → translator retirement → website). The state that matters:

- **Every SQL statement in the tree is native PostgreSQL.** The runtime
  translator (`apdb_sql.py`) is DELETED. What survives it: `apdb_coerce.py`
  (MariaDB's implicit rounding of fractional writes at integer columns —
  transport semantics the writers were built on, proven load-bearing) and
  `tools/pgmigrate/realise.py` (the placeholder realizer the gate needs).
- **The lint keeps it done**: `harvest_corpus.py --lint` fails run_checks on
  any MySQL-ism entering the tree. The corpus tracks the SQF (`--check`).
- **Gates, all green at merge**: repo translate-idempotency 0; EXPLAIN
  --native 346/0 (48 dynamic statements covered by dbSoak, 13 DDL by boot);
  `dbsoak` bot verb 28/28; bridge suite 22/22 vs live PG; website tsc+build.
- **The 36 codec columns are text with ONE stored shape** (ETL-generation
  rows normalized by `tools/pgmigrate/migrate_codec_columns.py`, idempotent,
  ALTER-first — its header records why order matters). `fn_mresToArray` has
  one decode path again.
- **Daemon**: OpenRC service in `deploy/openrc/` (init script + conf; conf
  defaults point at THIS checkout and are correct post-merge — fill the DSN
  password, 0640 root). `AP_DB_POSTGRES=1` stays the boot flag; a boot
  without the daemon aborts init loudly rather than half-booting (there is
  no extDB3 to fall back to — the extension and MariaDB container were
  deleted 2026-08-20, final dumps in `~/db_final_dumps/`).
- **What still needs a human**: the closing owner passes in `needstest.md`
  (one full play session + `coverage_report.py` over its log, ND ledger
  exactness, logged-in website smoke, a quest surviving a restart). The
  containerd shim on this box refuses NEW containers (NEEDSFIX) — that
  killed the MariaDB equivalence rig; its fallback gates carried the port.
- **Live (.96) migration is untouched by all this**: pgmigrate's ETL owns
  it at the 9/11 freeze, and `rules.transcoded_columns()` returning [] is
  now the policy the ETL inherits (codec columns carry as text).


---

## PySQF — in flight

An Arma extension that lets SQF call Python. It is the transport the
PostgreSQL migration needs (`postgres_plan.md`), and the intended replacement
for the extDB3 path. Full runbook: `pysqf.md`.

**It lives in its own private repo: `github.com/doombadroid/PySQF`.** The
extension, the daemon and the Python package are only there. The SQF side is
**vendored** into this repo.

### The rule that matters

All four files in `server/AP_server/core/pysqf/` are **generated**:

```
fn_pysqfRaw.sqf  fn_pysqfCall.sqf  fn_pysqfSmoke.sqf  fn_pysqfConform.sqf
```

Do not hand-edit them. Fix upstream, then re-run `scratchpad/vendor_pysqf.py`,
which does a mechanical rename (`pysqf_fnc_*` → `APS_fnc_*`) and nothing else.
A local edit survives exactly until the next person re-vendors, and then it is
gone with no error. Each file carries a banner saying so.

The smoke test and conformance suite were authored here and moved upstream on
2026-08-14. The reason is worth knowing before anyone moves them back: the
conformance suite asserts byte-exact properties of Python fixtures in
`python/pysqf/diag.py` — that `diag.raw(n)` is exactly `n+2` bytes, that
`diag.awkward` puts an escape across the 8192-byte chunk seam. Assertions in
this repo and fixtures in that one drift, and the drift arrives here looking
like a transport bug. Both halves stay together.

### State

| | |
|---|---|
| Extension builds | yes, both back ends (`ipc` recommended, `embed` also builds) |
| Smoke test in Arma | **all five stages passed on dev, 2026-08-14** |
| Conformance suite in Arma | **never run.** Written, registered, not executed once |
| Anything calling PySQF in gameplay | **yes, since 2026-08-18** — UI page serving reads pages off disk through `webpages.read` (`tools/pysqf_modules/webpages.py`). Soft dependency: if the daemon is down or lacks the module, every screen renders from the mission PBO exactly as before |

### Next concrete step

Run the conformance suite on the dev server and read the result:

```sqf
[] spawn APS_fnc_pysqfConform;          // all groups
["chunks"] spawn APS_fnc_pysqfConform;  // one group
```

Then `grep '\[pysqf-conform\]'` in the RPT. Output is `PASS` / `FAIL` / `CRIT`
/ `OBS` / `SKIP` per case, then a per-group breakdown and a verdict.

`OBS` is not a failure — it marks a value that arrived lossily by the rules of
a 32-bit float, which is a fact about SQF and not a defect. `CRIT` is a
failure that should stop a migration. A `SKIP` group means it could not run at
all; read why before treating the run as coverage.

Expect the first real run to find disagreements. That is the point of it.

---

## The Fabricator (3D printer) — built 2026-08-22, unplayed

Player-owned manufacturing: a printer placed in a house, loaded with materials, running on a
server clock that keeps running while the owner is offline. Production costs **materials and time,
never money**; the only currency is the New Drachma price of a schematic. Full spec, tuning levers
and the playtest script: **`FAB.md`**.

Three machines from the owner's three.js drops, generated through the `scratchpad/skyscraper`
pipeline: two printer tiers (i3, CoreXY — separate keys/prices/tier stats, both now drawing the
single **F770** industrial printer model as of 2026-09-02, `PRINTER_F770_SPEC.md`) and a gunsmith
bench. **Weapons are a two-stage chain** — the printer makes only a gun's lower receiver, the bench
assembles the gun from it. Interaction is proximity-based against an invisible anchor rather than
the mining rig's cursor pattern (`cursorObject` needs geometry); the F770 body carries real
collision, the bench always has, and both use the same proximity path anyway.

State: all 20 gates green, `verify_printer.py` ALL PASS, `fab_check.py` negative-tested. **Not one
line of it has run in-game.** Run `FAB.md`'s playtest before it goes near players — especially the
offline-collect path, which is the only part whose failure mode is silent.

**The Factory is vehicles-only now** (161 recipes -> 25, all cash removed) and its other 136 moved
to the printer with their ingredients verbatim. The catalogue is 574 recipes, 551 of them generated
by `scratchpad/gen_fab_catalogue.py`. **The Grand Exchange is placed and reachable** for the first
time since the fork.

Open: P4 — money is still client-authoritative, the Exchange does not escrow item listings and
debits the buyer client-side, and the NPC shops are still stocked. Until those land this is the
production half of an economy that is not yet closed. Gang-house access is owner-or-keyholder.

---

## HUD UI editor — built 2026-08-29, unplayed

Settings → INTERFACE → **Rearrange HUD** opens a transparent full-screen dialog (938400)
showing the real status HUD, and the player drags its pieces where they want them. Seven
handles: a VITALS GROUP that moves the four plates and the status chips together, each of
those five as a breakout handle of its own, and the minimap. Saved to
**`players_global.ui_layout` (jsonb)** — an account preference, so it follows the player
across civ/cop/medic. Full spec, mechanism and playtest script: **`hudeditor.md`**.

Three things worth knowing before touching it:

- **`hud.html` is never edited.** The drag overlay is `ui/html/hudedit.js`, fetched at
  runtime by the page through `A3API.RequestFile`, and the position stylesheet is ExecJS'd
  in. That is not squeamishness — the page's own header says a designer re-drop replaces the
  whole document and keeps only the bridge shim, so anything written into it is lost on the
  next art update with no error.
- **Position rides on `transform`, and only on `transform`.** `render()` rewrites
  `style.bottom` and `className` on most of the targets at 12 Hz; anything the editor wrote
  there would be reverted within 83 ms, silently. `tools/hudlayout_parity.py` asserts the
  SQF emitter and the JS emitter still produce byte-identical CSS — they cannot be merged and
  a divergence would render one way while editing and another way once saved.
- **The live HUD stays receive-only.** `hudLayoutSet`/`hudLayoutCancel` are registered on the
  editor's control alone; layer 938301 never gains a verb, so the display-only property its
  header describes is intact. Server side, identity is `remoteExecutedOwner` (captured before
  the DB call spawns), the payload is validated to seven number pairs in [-1,1] and rejected
  whole if it is not, both statements are parameterised, and the column is read with
  `parseSimpleArray` — nothing in this feature compiles anything or writes `profileNamespace`.

State: `run_checks.sh` 25/25, `tools/test_hudedit.js` 36/36 against a stubbed DOM, both SQL
statements round-tripped against the dev schema, clean dev boot on `b0798`. **Nobody has
dragged anything yet.** `deploy/hud_layout.sql` is applied to dev (`pgm_full_scratch`) and
will need applying wherever else it runs. Playtest script is `hudeditor.md` §8.

---

## Fixer territories and the weekly war — built 2026-08-30, unplayed

Malden splits five ways: the north cartel belt stays the redzone, La Trinite is
neutral, and Larche / Chapoi / La Port belong to the Lightrunners (Nero), the
Crusaders (Pope) and the Silent Partners (The Administrator). A gang swears to
one in the Gang Command deck app; at five members an unaligned crew is told the
best contracts are closed to it, and nothing else happens to them. Every week two
fixers fight and one sits out, decided by the contract score their aligned gangs
earned. Full design, file map and playtest script: **`FACTION_WAR.md`**.

Four things worth knowing before touching it:

- **The faction ids are placeholders and stay that way.** `f_dock` is the
  Crusaders and has nothing to do with a dock. A stored standing array keys off
  the id, so renaming one orphans every player's reputation silently.
- **Territory is a POLYGON, and the shipped shapes are defaults.** Octagons sized
  off existing spawn anchors so the system is testable, not design. Redraw them by
  placing `aq_terr_<factionId>_p1..pN` in Eden and running
  `tools/bake_territory.py`. The polygon is the authority; the web map draws from
  the same array, so the drawing and the rule cannot drift.
- **Hostility is rules-and-rendering only.** A red name, a banner, and a diary
  entry saying the kill is legal. No damage change, no relations, and NO map
  marker revealing an enemy — `fn_trackMarkers` is deliberately untouched.
- **`deploy/faction_war.sql` also delivers four columns that were never delivered.**
  `gangs.faction`, `gangs.faction_rep`, `players.faction_rep` and
  `players.faction_talents` existed on dev only because somebody ALTERed it by
  hand; they are in no migration and cannot go in the generated target schema.
  Any other database this project is stood up on needs that file.

**The vendored ArmaQuest tree is NOT byte-identical to its recorded commit**, and
a routine re-vendor reverted the PostgreSQL store fixes on 2026-08-30 before they
were restored from git. `vendor_armaquest.py` now diffs against the recorded
commit and refuses without `--force`; `ArmaQuest/VENDORED.txt` lists both diverged
files and why. The standing fix is making the store dialect-aware upstream.

**Nothing here has been played.** Boot gates are green on b0805 and the weekly
rollover was proven by forcing a stale week key; the two-client hostility checks
and every "does this feel right" question are in `FACTION_WAR.md` section 7.

---

## Hazards

- **The dev database is `pgm_full_scratch`, NOT `armapunk`.** The names are backwards from what
  anyone would guess. `pgm_full_scratch` has 66 tables and the real player rows — it began as the
  pgmigrate ETL's full-run scratch target and quietly became the dev database because it was the
  populated one. `armapunk` is an empty 13-table shell the container created from compose.yml's
  `POSTGRES_DB` default and nothing has ever used. On seeing a column you just added "missing", the
  obvious move is to check `armapunk`, find it absent and conclude the write failed — it did not,
  it went somewhere else. That has cost time twice now.
  `deploy/postgres/rename-dev-db.sh` fixes the naming for good (dump → stop → rename → repoint
  `/etc/conf.d/pysqfd` → restart, reversible at every step). It needs root for that one conf file,
  so it is a deliberate manual step rather than something a session does on its own.

- **`pkill -f arma3server_x64` kills every Arma server on the box, including
  the live one.** Match the instance instead: `pkill -f 'name=loonydev'`.
- **Deploy to dev with `reload-armapunk2035.sh`, never `reload-loonydev.sh`.**
  The latter packs the *other* project and overwrites `@AP_server` with its
  build, leaving this mission running against the wrong server addon. It has
  cost a round once already.
- **`deploy/postgres/.env` holds the dev database password.** It is gitignored
  on `main` now, but check `git status` before any `git add -A` on a branch
  cut before that landed.

---

## Open

- **Armapunk Pixel (2026-09-10, `PIXEL_SPEC.md`)**: owner-only idle RPG live at `/pixel` on the portal (`c49590c5`), no game-server tie-in by decision. Gate = `website/src/lib/pixel/access.ts` + the layout nav flag; everything else 404s. Engine is pure with 116 vitest cases (`cd website && npm test`); balance is first-pass in `content.ts`/`RULES`. OPEN: the owner has not yet eyeballed the PixiJS map in a browser; Phase 2 (cop career, talents/prestige, gangs, pursuits, chests, casino, chat, checkpoints, tie-in) is listed in the spec and not built.

- ~~**Generator scripts point at the dead pre-fork Altis path.**~~ **Closed 2026-09-09**: both
  generators read `mission/Armapunk2035.Malden` and the outputs are generated again (portal
  rebrand, `PORTAL_SPEC.md`). Original note kept for history:
  **Generator scripts point at the dead pre-fork Altis path.** Both
  `website/tools/gen_comp_items.js` and `website/tools/gen_house_items.js`
  hardcode the source path as `mission/LooneyBin.Altis/core/config/fn_virtItemCfg.sqf`,
  which does not exist in this fork. The correct path is
  `mission/Armapunk2035.Malden/core/config/fn_virtItemCfg.sqf`. Until the
  generators are updated to use the new path, the generated outputs
  (`website/src/lib/compItems.ts` and `website/src/lib/houseItems.ts`) are
  hand-maintained as a result, and both files carry auto-generation headers
  that are currently misleading. Either repoint the generators or drop them
  and own the outputs by hand.

- **The quickhack spec has no file behind it.** `CLAUDE.md` points at
  `docs/quickhacks-design.md`; `docs/` is gitignored as removed content
  (`.gitignore` §"removed content", owner 2026-06-25) and holds only
  `WALLPAPERS.md` locally. So the spec was most likely scrubbed with that
  directory. Either restore it somewhere tracked or drop the pointer — right
  now `CLAUDE.md` sends every session to a file that cannot exist in a clone.

  This file was the same problem: `CLAUDE.md` imported `@docs/HANDOFF.md`, so
  the import silently failed every session *and* could never have worked, an
  ignored path being uncommittable. It lives at the repo root now, with the
  other docs.
