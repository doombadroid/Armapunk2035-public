# Needs manual testing

---

**Date:** 2026-08-28
**Build:** dev (Fast Rope)

## FAST ROPE (scroll wheel, in a hovering helicopter)

Airframes: MH-9 Hummingbird, M-900, PO-30 Orca, UH-80 Ghost Hawk, CH-67 Huron (ramp).
Envelope: 5-35 m ATL, under 15 km/h, passenger seats only. All numbers live in
`core/config/fn_fastRopeCfg.sqf`.

| # | Test | Pass looks like |
|---|---|---|
| 1 | Passenger in a hovering Hummingbird at ~20 m | "Fast Rope" on the scroll wheel; ropes appear and doors open as you go out |
| 2 | Ride it all the way down | Feet on the ground, animation cleared, you can move; ropes vanish when the last man is off |
| 3 | Press X halfway down | You drop from there and take the fall — nothing catches you |
| 4 | Pilot flies off mid-descent | You stop descending and ride along; "holding on until it settles"; descent resumes when they re-hover |
| 5 | Rope into a roof / tree / wall | "You hit something on the way down and lost the rope" and you come off it |
| 6 | Two passengers out together | One set of ropes, refcounted; ropes only disappear after BOTH are down |
| 7 | Huron | Both stations are on the ramp, not the sides; ramp animates open |
| 8 | Pilot seat / above 35 m / below 5 m / over 15 km/h | No scroll option (and the message if you somehow call it) |
| 9 | Restrained, downed, or dead | No option |
| 10 | Pilot flies off and the heli is destroyed / you disconnect mid-rope | You detach cleanly; no stuck `AP_action_in_use`, no orphan ropes on the wreck |
| 11 | Rope out of a heli owned by ANOTHER client (not you, not the server) | Ropes and doors still appear — this is the CfgRE `AP_fnc_fastRopeRope` path |

---

**Date:** 2026-08-27
**Build:** dev (deck-app wave part 2 — the three deferred screens)

## MOD BAY (deck garage → MODS tab)

| # | Test | Pass looks like |
|---|---|---|
| 1 | Garage → select stored vehicle → MODS tab | Twelve slots load with your CURRENT fits selected; preview total $0 |
| 2 | Change trunk + horn → FIT | Charged the sum; reopen shows both fitted at $0 preview |
| 3 | Re-select your CURRENT paint → FIT | "Nothing changed" — the native charged $2,500 here (bug, fixed) |
| 4 | Plate: type `AB!!` then `MDN471` | Bad charset refused at fit; clean plate costs $2,500 once |
| 5 | MOTORIST talent + autopilot module | Module free; the $45k Analog Retrofit still charges |
| 6 | Non-car (heli): horn/handling/nitrous/plate | All disabled; skin/trunk/locks/alarm/tracker work |
| 7 | Pull the vehicle after fitting | Mods actually present (trunk cap, horn, nitrous...) |

## EXCHANGE SELL TAB (deck exchange → SELL)

| # | Test | Pass looks like |
|---|---|---|
| 8 | Park owned vehicle w/ virtual goods at broker → SELL | Trunk contents listed with price bands; caps strip shows V/P/C counts |
| 9 | List a virtual stack | Fee = 5% of price×qty debited; stack leaves trunk; MINE shows it |
| 10 | Price below min / above max | Refused with the band named; nothing debited |
| 11 | List with 20 of a type already held | Refused on the cap |
| 12 | Physical item (weapon in cargo) list | Lists; REST of cargo survives in the trunk |
| 13 | Vehicle listing (aim at owned whitelisted car ≤25m) | ⚠ CARGO badge when loaded; lists; vehicle locks out of garage |
| 14 | Second client buys each kind | Goods deliver via vault/garage; seller paid |

## HOUSE TRUNK IN THE DECK (the serialize-lock one — test HARD)

| # | Test | Pass looks like |
|---|---|---|
| 15 | Open house storage (owner) | Deck trunk shows virtual BOTH ways + physical gear strip |
| 16 | Store 50 of something, close phone, REOPEN IMMEDIATELY, repeat ×5 | Never a false-empty; count always right (this is the Chris Blanco reopen race) |
| 17 | Store items → close → check next restart | Items persisted (updateHouseTrunk ran with the gen guard) |
| 18 | Take → instantly close phone | Item in inventory AND gone from house after the 1.25s settle |
| 19 | Two clients, same house | Second gets "in use"; after first leaves the app (not just closes phone) second can open |
| 20 | Physical TAKE ALL on a gear stack | Whole stack lands (weight permitting); house pinv updates |
| 21 | Cop scroll on a house | NATIVE dialog with Seize — cops never route to the deck |
| 22 | Get restrained with house trunk open | App kicked "you are restrained"; storage persists correctly |
| 23 | VEHICLE trunk close (regression) | Close log + gear save still fire — the close path moved to fn_trunkCloseSettle for BOTH kinds |

---

**Date:** 2026-08-21
**Build:** dev **b0723** (merged main — PG conversion + deploy-test features + admin ND)

## Admin ND grants + tonight's merge extras

| # | Test | Pass looks like |
|---|---|---|
| 1 | Deck staff app → ACTIONS → NEW DRACHMA: TO SELF with an amount | Balance rises by exactly that amount; `-ADMINACTION-` row in the log |
| 2 | Same → TO TARGET with a player selected (needs a 2nd client) | Target's balance rises; target gets the "staff granted you N ND" toast |
| 3 | Classic admin dialog → Add ND (SEL)/(SELF) buttons | Same behavior; buttons don't visually collide with the query window (nudge me if they do) |
| 4 | Bounds: try 0 and 2,000,000 | Both refused with a message; nothing credited |
| 5 | Your 1000 ND starting grant | Shows at login |
| 6 | Faces: spawn + look at NPCs/players | No SetFace error spam in the RPT (110-face roster landed) |
| 7 | Detonate quickhack (spec: detonate.md) | Merged unplayed — exercise per spec |

---

**Date:** 2026-08-20 (late)
**Branch:** `pg-native/harness` (13 commits on top of duty/pr10)
**State:** THE POSTGRESQL CONVERSION IS CODE-COMPLETE. Every SQF statement and the website
are native PG; the translator is retired (a 40-line value-coercion module survives it); the
lint in run_checks keeps the tree MySQL-free. All machine gates green: repo idempotency 0,
EXPLAIN --native 346/0, run_checks 21/21, dbSoak 28/28 on the bare stack, bridge 22/22,
website tsc+build green, lib-layer probes good. Snapshots at ~/db_final_dumps/pgm-*.

## PG conversion — the owner passes that close it

| # | Test | Pass looks like |
|---|---|---|
| 1 | Full play session on dev b0720+ (login, save, money, gear, house+vehicle+storage buy/store/retrieve, gang, market/ND buys, duty cycle, quest accept+complete, relog, restart-survive) | Zero `QUERY FAILED` / decode errors in loonydev.log across the whole session; everything persists |
| 2 | After the session: `python3 tools/pgmigrate/coverage_report.py /home/timb/arma3server_dev/loonydev.log` | High coverage, 0 unmatched lines, 0 failures — the statements never exercised live are the ones to poke next session |
| 3 | ND ledger exactness: note balance before/after a buy+sell round | Matches to all 4 decimal places |
| 4 | Website logged-in smoke (auth-gated routes 307 for the rig): leaderboards, log search, tickets, wiki edit, whitelist rank change, vpn-exempt add | Pages render; the two upsert flows update rather than duplicate |
| 5 | ArmaQuest store: play a quest, restart server, progress survives | `[AQ]` read-back confirms; the old chunk-corrupt line gone |

---

**Date:** 2026-08-20
**Branch:** `duty/pr10-landing-fixes` (PR #45, commits `355ceb03..e12107c1`)
**Deployed:** dev **b0705**, boots clean, `ENGINE: extDB3 / MariaDB`, zero `Missing ]` decode
errors at boot. Owner already passed rounds 1-3 on b0704 (spawn standing, logout-alive restore,
death→menu); the items below are what changed since.

## Spawn / persistence / duty round 2 — parked, verify when convenient

| # | Test | Pass looks like | Context |
|---|---|---|---|
| 1 | Clock on MaxSec → **disconnect mid-shift** → rejoin | Civ spawns at the clock-on spot (near the HQ terminal), no spawn menu | b0704 fail: shift begun right after a death left the death-`[]` in `position`; disconnect handler now writes the roster's clock-on pos (`fn_playerDisconnected`) |
| 2 | Re-run spawn + logout-alive once on b0705 | Spawn standing; relog restores exact spot | Regression check only — passed on b0704, code around it moved |
| 3 | HQ tablet / kiosk pages | Pages open with **no** `tried to remoteExec a disabled function: 'aps_fnc_webpagesrv'` in server log | CfgRE entry existed only as a comment; added for real. Daemon now serves pages from the duty worktree (`AP_WEBPAGES_ROOT`) |
| 4 | Glance at licenses + gear after a login | All licenses present, kit intact | b0704 only: every mres decode threw `Missing ]` — mixed-engine boot (pg daemon flag up, calls falling back to extDB3, `fn_mresToArray` branches on the global flag). b0705 boots extDB3; error class gone at boot, confirm at a login |
| 5 | Die → logout **while dead** → rejoin | Spawn menu (death sentinel still wins) | Disconnect save's dead test moved to engine `alive`/`lifeState` off the stuck-true-prone `Revive` var |

**For the pg workstream, not this branch:** the mixed-engine split-brain is real and player-visible
— `AP_db_postgres` is a boot-global flag while apdb refuses unscheduled callers per-call (they fall
back to extDB3), so every fallback decode takes the wrong `fn_mresToArray` branch. First actual
player-login result on the PG path. Value provenance must be per-result, or fallback must be
boot-granular.

---

**Date:** 2026-08-18
**Branch:** `armaquest` (64 commits)
**Automated state:** `bash tools/run_checks.sh` — **17/17 pass, exit 0** (content structure,
event verbs, Arma-aware balance over 1441 .sqf, 9 unittest suites, 5 script suites). Dev boots clean
on **b0636**: config gate clean, `[AQ-VALIDATE] result: PASS — 0 problem(s)`, 8 world
resolvers registered, `srvInit: online`, gang→faction mirror published. The only
errors left in the boot log are the two pre-existing ones at the bottom of this page.

**The harness passed on a file that could not compile.** `fn_storageBridge.sqf`
had `_tally toArray` — missing the required operand — which is a syntax error
that takes the whole function down, not just the line. `sqf_balance.py` passed
it and was right to: the brackets balance. There is no SQF parser outside the
game, so **the boot log is the gate, and a green `run_checks.sh` is not
evidence a new file loads.** Read the log after every deploy.

**Nothing below has ever been exercised by a real player.** Every server-side
behaviour that can be verified without a client has been; everything here needs
someone at a keyboard. Roughly 30 minutes on dev covers the lot.

Why so much: there is no SQF runtime, parser or test runner outside the game.
`tools/run_checks.sh` catches structure, balance and the Python tooling; the boot
log catches config parsing, catalogue validation and store health. Neither can
press a button, stand in a marker, or hold an item.

Connect with:
`bash /home/timb/loonybin-doomba/deploy/launch-client-direct.sh 127.0.0.1 2342`

---

## Blocking — the core loop is unproven

| # | Test | Pass looks like | Why it can't be automated |
|---|---|---|---|
| 1 | Walk up to each of the six Fixers | All six spawn; scroll action appears; board opens | Needs a client in the world |
| 2 | Open a Fixer through the cyberdeck | Same board as the walk-up path | Custom trigger driver; it must also fire `aq_talked`, or every `talk` objective becomes uncompletable |
| 3 | Accept → progress → complete one quest | Journal and native task both update; completion fires | `srvAccept`/`srvFact` take a player **object**; a synthetic UID cannot stand in |
| 4 | Payout lands | `new_drachma` moves in Postgres **and** the on-screen balance refreshes without a relog | The only path that moves money |
| 5 | Quest state survives a server restart | Progress returns after reload | Proves per-player persistence, not just the board record |

---

## Important — most likely to be subtly wrong

| # | Test | Pass looks like | What to watch |
|---|---|---|---|
| 6 | `gather` and `deliver` objectives complete | Counter fills, quest completes | The server's `countItem` is a **stale** DB read (spec §5.3). Expect completion one inventory event late rather than at the stated count |
| 7 | Position objectives — `visit`, `zoneHold`, delivery arrival | Progress ticks while in the marker | Client-side watchers, entirely untested |
| 8 | Journal opens in the deck ("Quest Log") and is clickable | Page renders, accept/abandon work | A whitelist miss lets the page render perfectly and be **mute**, with no error on either side |
| 9 | Side gating | Cop sees MaxSec's board populated and a Fixer's empty; civ sees the reverse | The only thing keeping three sides' content apart |
| 10 | Login and spawn | Money, gear, licences intact | The legacy deletion edited the login SELECT; index 31/32 were appended for this reason |

---

## Faction system — entirely new, zero runtime exposure

| # | Test | Pass looks like | What to watch |
|---|---|---|---|
| 11 | `addRep` moves standing, survives a relog | `players.faction_rep` updates and reloads | The mres round trip was verified by hand against the live DB; the SQF around it was not |
| 12 | A `rep:` gate opens and closes | Quest appears above the threshold, disappears below | Test **both** directions |
| 13 | A `world:` gate reacts live | Toggle `AP_fed_robbed`; the quest appears/disappears with no restart | The whole live-world premise |
| 14 | **A quest already accepted survives its world gate flipping** | Accept during a purge, finish after it ends — still completes | ⚠ The case most likely to be wrong, and the one a player would most resent. Prerequisites gate *offering*, not *holding* |
| 15 | Gang alignment | Leader-only; mirror republishes; `world:cartelf_*` resolves to the faction | Rank and gang are re-derived from the database inside the receiver, never trusted from the client |
| 16 | Buy a perk, then realign the gang | The perk stops applying | Intended cost — but it **must be warned in the UI first** or it reads as a bug |
| 17 | Tie for highest standing | No primary faction; no perk granted | Deliberate. Verify it does not flicker as standing drifts |

---

## New HTML screens — three ports, none ever loaded in a running game

Built from the owner's `design_handoff_phone_rework` mocks. All three are the
**primary** UI as of 2026-08-18 (owner call). The native dialogs are not gone —
they moved one modifier away, so a page that misbehaves in front of players is a
keypress from working rather than a redeploy:

| Screen | Primary | Fallback (old UI) |
|---|---|---|
| Visor | `SHIFT+Y` | `CTRL+SHIFT+Y` → `AP_fnc_qhDock` |
| Car radio | `TAB` in a vehicle | `SHIFT+TAB` → `AP_fnc_radioRadial` |
| Storage | `T`, house menu, crate action | `CTRL+SHIFT+T` → `AP_fnc_openInventory` |

Delete the fallbacks once the new screens have been played properly.

| # | Test | Pass looks like | What to watch |
|---|---|---|---|
| 18 | **Visor** — `SHIFT+Y` | Plate stack renders; a quickhack casts exactly as it did from the dock | Casting goes out through `AP_fnc_qhCast` unmodified — a cast that behaves *differently* from the dock is the bug to look for, not one that fails. Still gates on goggles + firmware, so it stays inert without them. **While restrained it must still fire the CUFF CRACKER**, not the visor — that branch was deliberately left ahead of the swap |
| 19 | **Car radio** — `TAB` in a vehicle | Ring dial renders; station changes; bystanders hear the change | Labels read **"ORIGIN FM"**, from `radioCfg.hpp`'s `AUTORADIO_StreamLabel` — the config the native radial never read. Confirmed wanted; noted so the difference from the old radial is not mistaken for a bug |
| 20 | **Storage** — `T` at a house and at a vehicle | Both manifests populate; items move both ways; counts reconcile | ⚠ **The highest-risk item on this page — the only new screen that moves items.** Count both sides before and after every move. Then have a second player try the same container while it is open: `AP_activeTrunk` must refuse them. That reservation is the anti-dupe interlock |
| 20a | **Storage — someone else's vehicle** | `T` on a car that is not yours does nothing | The vehicle gate lives in the key tree, **not** in `fn_openInventory`, which only gates houses. Test the `CTRL+SHIFT+T` fallback the same way — its first version skipped that gate and shipped on b0635 |
| 20b | **Storage — a crate or ammo box** | The **native** TrunkMenu opens, as before | `AP_fnc_storageOpen` is the front door now and delegates anything it does not model (cargo nets, ammo boxes, and event loot: supply plane / airdrop / UFO / Santa / quest). A dead end here, or a message telling you to use the trunk menu, means the delegation broke |
| 21 | Storage bulk "store all" / "take all" | Everything moves, weight ends correct | Single-shot, deliberately **not** the native paced `uiSleep` loop — same reservation flags, no scheduler gap mid-move. Different code path from the per-item move, so test it separately |
| 22 | Storage in *physical* mode | Manifest displays; moves are refused with a message | Read-only by design — no callable core exists for physical moves that isn't the native TrunkMenu listbox |
| 23 | Loot card item weights | Non-zero, and they match the trunk's numbers | They have been displaying **0 for every item, for everyone** — `fn_lootBridge` asked `fn_virtItemCfg` for a case that does not exist. Fixed this session; this is the check that it took |

A page that renders perfectly but does nothing on click is the failure mode to
expect first, and it looks identical on both sides: it means a bridge verb or a
whitelist entry is missing, not that the page is broken.

---

## Known-unfixed, and not regressions from this work

- **House `vinv`/`pinv` fail to decode at boot.** `fn_queryHouses.sqf:8` →
  `Error Missing ;` on `"[[["marijuana",40],...`, four times per boot on the
  current dev data. The columns are read bare (correct — they are `mres`), but
  what arrives still has doubled quotes and the decode chokes. **This one now
  matters more than it did:** house storage is exactly what test 20 above
  exercises, so if that test fails on a *house* and passes on a *vehicle*, this
  is the reason and the new screen is not at fault. Pre-existing — last touched
  by the 2026-08-14 namespace rename, untouched by this branch. `HANDOFF.md`
  already flags inventory on the Postgres path as untested, and its standing
  rule applies: fix the **translator**, not the call site.
- **Gang talents never load.** `fn_receiveGangs.sqf:12` →
  `parseSimpleArray format error`, once per boot. The query
  `QUOTE(COALESCE(talents,'[]'))` hands back a quote-wrapped value that
  `parseSimpleArray` cannot read, so every gang silently falls back to `[]` —
  the fallback is why nothing looks broken. Also pre-existing and also untouched
  by this branch.
- **3 achievements, 7 titles and ~24 perks are unobtainable.** Their gates read
  `AP_completedLifetimeQuests`, which nothing repopulates since the legacy quest
  system was deleted. Recoverable by re-homing those rewards onto ArmaQuest, which
  is content design rather than code.
- **Faction-level turf gating** has no `world:` key. Turf state lives in
  `turf_state` with no published mirror, and a resolver reading a variable nobody
  sets is worse than no resolver — content gets written against it.
- **Legacy quest columns remain in the PostgreSQL database.** An earlier drop hit
  MariaDB instead. Harmless (nothing reads them) and left deliberately, because
  that database is the migration rehearsal target and unilateral schema divergence
  there could skew rehearsal results before the 2026-09-11 freeze.

## Placeholders, by design — not defects

- Faction display names (`Neon Faction`, `Dock Faction`, …) and Fixer names.
  The **ids** are the stable part; content references those, never the names.
- Giver marker positions. Moving one is a 3DEN drag with no code change.
- Faction perk effects and the standing→points curve. Deliberately modest:
  standing is new and untuned, and shipping strong perks off an unbalanced curve
  is how a progression system gets nerfed in week two and feels bad afterwards.

---

## If something fails

The boot log is `/home/timb/arma3server_dev/loonydev.log`. Deploy with:

```
AQ_SRC=/home/timb/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

`AQ_SRC` is not optional — both reload scripts otherwise hardcode a different
worktree, and you would be testing someone else's code.

`read from bank` is **not** a health check: a `description.ext` that fails to parse
still reaches it. The reload script prints a CONFIG GATE verdict; that is the real
one.


## Fixer territories and the weekly war (2026-08-30)

Full script: `FACTION_WAR.md` section 7. The short version of what only a person
can settle:

- [ ] Banner fires once per territory crossing and names the right fixer
- [ ] A solo is never red to anyone, anywhere
- [ ] Swear to a fixer from Gang Command; `gangs.faction` changes and the
      align-gated contract appears on that fixer's board
- [ ] Defection refused, with a stated reason, for each of: not leader, gang bank
      short, inside cooldown, your fixer is a belligerent this week
- [ ] TWO CLIENTS: opposed aligned gangs render each other RED inside a
      belligerent territory and normal outside it, both directions
- [ ] TWO CLIENTS: **no map marker ever appears for the enemy**
- [ ] A gang aligned to the NEUTRAL fixer is red to nobody
- [ ] `[] call aq_fnc_validate` and `[] call aq_fnc_reachability` run from a
      client after the world is up (preInit defers all 13 marker checks)

## SUMMON VEHICLE (2026-09-02, dev b0843)

Headless self-test passed all three kinds (car arrived 64 s / 82 s; heli landed 143 s on open ground, hover at 2 m over the respawn square; VTOL landed 114 s). Owner rows:

| # | Test | Expect | Notes |
|---|---|---|---|
| 1 | GARAGE app → star a car → SUMMON VEHICLE tile → SUMMON | Car appears ~1 km out, drives to you, stops locked (your keys open it), engine off; phone shows EN ROUTE with distance/ETA then "is here" | free; cooldown 120 s after a delivery |
| 2 | Same with a starred heli | Lifts off ~1 km out, cruises high (clears the Lux tower), descends vertically, lands within ~40 m or hovers at 2 m with the "climb in" message | landing needs an isFlatEmpty spot; town squares hover |
| 3 | Same with a VTOL | As 2 | |
| 4 | Star vehicle is OUT in the world → SUMMON | The world copy vanishes; a fresh one comes from 1 km with the same fuel/damage/trunk | occupied → refused |
| 5 | Refusals: no HC / in a vehicle / nothing starred / on cooldown / two copies out | Exact messages in the tile and chat; nothing spawns | |
| 6 | Seated heli AP: set NAV on the web map, TAB → AP wedge | Flies there at object-clearing altitude, lands; touching the controls disengages | needs the Autopilot Module (garage slot 9) |
| 7 | Robotaxi | Gone from the launcher; no errors in RPT | |
| 8 | Summon twice fast / walk away during spawn | Second press says "already on its way"; a late spawn is ignored (log line), the copy stays out for the next summon to reclaim | |
| 9 | Summon a heli / the Blackfish and WATCH it from outside (b0859+) | It flies like an AI-piloted aircraft: banking, steady motion, no position steps; heli lands on its own, Blackfish flies in fast then descends vertically the last stretch | the pilot is invisible and leaves on arrival |
| 10 | Summon an aircraft and let it crash on the landing, or have it shot down, WITHOUT boarding (next deploy after b0885) | Deck: "your X was wrecked on the way -- it is back in your garage"; the wreck vanishes; the garage lists it again with the damage / fuel it had before; trunk intact. Board it first and crash: NO refund, normal wreck | |
| 11 | Hold'em after the next deploy (fix committed on b0885, NOT deployed): buy in, watch the phone/page bank figure; play a hand; cash out; also buy in with a bank between $1M and $10M whose last digits are not round | Bank drops by the buy-in the moment you sit; rises by the stack when you leave; no "THE BANK DID NOT ANSWER" on a funded seat; the DB and the phone agree after the next ATM use. Duty bounty payoff shows the debit too | |
| 12 | DEALERBOT'S TABLE after the next deploy: open blackjack, sit, bet, play a hand with two players | Seats are takeable; table and wallet update live; no "[WEBUI] push refused 'bj:...'" in the RPT (channels renamed bj.table / bj.you / bj.event after the 8/29 webui sweep) | |
| 13 | Heli summon in a TOWN (La Trinite plaza beside the vending rows / HQ) and on open ground (committed 9/7, next deploy) | Touchdown on the nearest clear spot, never at your feet: rotor radius + 2 m from every wall / tree / vehicle / person, nothing overhead, you can lift straight off. HC log: `[FLYSPOT] ... spot=[x,y] dist=N` and `HCFLYAI end ... padDist<=~10 ground=true`. Walk 30 m mid-flight: the pad follows only if the clear spot changed. Deep in a city with nothing clear within 150 m: hovers beside you, "climb in" message | seated heli AP (row 6) lands the same way |
| 14 | I-screen GUNSMITH (next deploy, d18c2fe5): open the I-screen, click the primary / handgun, mount + detach an attachment, unload/reload a mag; then close it and keep the I-screen open a minute | The gunsmith panel actually appears with sockets and a fit list; no `-SCRIPTERR-` in the log table for fn_invGunsmith and no `Error in expression ... toJSON _value` in the client RPT while the I-screen refreshes | the 9/7 19:04 errors were every refresh with the panel closed |
| 13 | The Wheel after the next deploy: spin until a CASH segment hits; also a car | Result shows the dollar figure (was $NaN); session log row shows +$amount; a car row shows the legend's value | |
