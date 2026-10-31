# Malden Fed + bank — in-game test pass

Everything in `maldenfed.md` and `maldenbank.md` is built and on the dev server. Nothing below has
been exercised with a player in the world; that is what this document is for.

**Dev server:** `~/arma3server_dev` (a.k.a. `~/loonydev`). Redeploy with
`bash deploy/reload-armapunk2035.sh`. Server log: `/home/timb/arma3server_dev/loonydev.log`.

**Before you start:** decide whether FED OVERRIDE is on. It waives the cop requirement and clears
every heist cooldown on a 4-second loop, including this event's new lockout — which makes back-to-back
runs possible but means you will never see the 5-minute HIGH SECURITY window unless you turn it off.
Test both ways if you can.

A useful tail for the whole session:

```bash
tail -f /home/timb/arma3server_dev/loonydev.log | grep --line-buffered 'maldenFed\]\|maldenBank\]\|-FED-\|-SEC-'
```

---

## 1. Boot — already verified, confirm it still says this

```
[maldenFed] anchor GATE   = Land_ConcreteWall_01_l_gate_F   8.9 m
[maldenFed] anchor DOME   = Land_Dome_Big_F                 0.0 m
[maldenFed] anchor CENTRE = Land_Medevac_HQ_V1_F            0.0 m
[maldenFed] anchor SAFE 0..9 = Land_Medevac_house_V1_F, buildingPos 1   (ten lines)
[maldenFed] state [0,-1,0,-1,-1]
[maldenFed] fedLockdown: locked 15 object(s) -- 3 perimeter gate(s), dome, centre and 10 safe(s)
[maldenBank] gate = Land_BackAlley_01_l_gate_F at 2.3 m from the brief
[maldenBank] gate SEALED
```

Any `WARN safe` line means a safe coordinate has become ambiguous against its neighbour — nothing
should print one today.

Corrected 2026-07-29: the `fedLockdown` line above read `13 object(s) -- gate, ...`, which was the
one-gate arithmetic left unrevised when e7e7c01 resolved the whole perimeter. 3 gates + dome + centre
+ 10 safes = **15**. The boot section also prints one `perimeter gate` line per gate now, not a single
`anchor GATE`, plus a line recording that the two `Land_BackAlley_01_l_gate_F` were deliberately left
unsealed.

**The gate count is the acceptance criterion, not the total.** `_sealed` drops whenever any anchor
fails to resolve, so `13` cannot be told apart from "three gates, eight safes". `3 perimeter gate(s)`
is what proves the whole perimeter was found rather than just the breach anchor — treat
`1 perimeter gate(s)` as a failure however the total reads.

**Walk up and confirm by hand:** all three perimeter gates, the dome, the centre building and any two
ring buildings will not open. This is the state a player finds between robberies.

---

## 2. The Fed, start to finish

| # | Do this | Expect |
|---|---|---|
| 1 | Aim at the perimeter gate with a Cyberdeck | Scroll shows **Breach Perimeter Gate**. Without a deck it does not appear. |
| 2 | Win the Sequence Breach (buffer 10) | Gate opens. MaxSec broadcast. Red "Robbery in Progress" marker at the ring centre. Everyone in the compound picks up the Federal Reserve Robbery charge. Log: `state [1,...]` and `-FED- perimeter gate breached`. |
| 3 | Lose it instead | Gate stays shut, no alarm, no phase change. |
| 4 | Go to the dome, scroll **Breach Dome Terminal** | Nine-command terminal minigame. |
| 5 | Win it | Cyan countdown box top-right, ten minutes, draining. Log: `state [2,...]` and `dome terminal cracked`. |
| 6 | **During the countdown**, try a ring building | Both **Crack Safe** and **Plant Demo Charge** offer. Demo works with no talents. Each opens that building. Log: `-FED- safe N opened`. |
| 7 | Let the clock run out | Dome's doors swing open. Log: `state [3,...]`, `dome opened`, then ten `gold case N -> ... (buildingPos)` lines. |
| 8 | Check each ring building | One briefcase **inside** each, 1–5 gold bars. Any `FALLBACK` in the log means that one landed outside its door — tell me which. |
| 9 | Also look for | One crypto mining component in a case beside a random gold case. |

**Then the Alamo:**

| # | Do this | Expect |
|---|---|---|
| 10 | Scroll at the centre building | **Start an Alamo Fed** — only now, not before the dome opened. |
| 11 | Win the terminal | Amber countdown, twenty minutes. Log: `ALAMO started`. |
| 12 | Let it expire | Centre opens. Five cases × 2 bars inside. Log: `ALAMO opened`. |
| 13 | Immediately | "Getaway boat has arrived" broadcast. Log: `getaway boat spawned at ... dir 150, keys to N player(s)`. |
| 14 | Go to the boat | Afloat (not beached, not sunk), facing 150. Anyone who was in the compound can drive it; nobody else can. Its T inventory already holds 10 gold bars and accepts far more. Minigun works. |

---

## 3. The ending

| # | Do this | Expect |
|---|---|---|
| 15 | Leave un-looted gold, leave the boat un-driven, walk everyone past 200 m | Within ~60 s: everything re-locks, un-looted cases gone, boat gone, siren stops. Log: `compound empty (1/2)`, `(2/2)`, `RESET (compound empty)`. |
| 16 | Try the gate again immediately | Refused: "Security is high… try again in N minute(s)" — unless FED OVERRIDE is on, which clears it within 4 s. |
| 17 | Re-run and this time sit in the boat 300 m offshore when the compound empties | Reset fires but the **boat survives**. A boat you escaped in is yours. |
| 18 | As a cop, with a robber still inside | **Secure the Reserve** refuses and tells you how many suspects remain. |
| 19 | As a cop, compound clear | It ends the event immediately, no 60-second wait. Log: `RESET (secured by MaxSec)`. |
| 20 | `!srv resetfed` mid-robbery | Clears everything and lets you retry at once. |

---

## 4. The bank

| # | Do this | Expect |
|---|---|---|
| 21 | Before anything | The back-alley gate will not open by hand. |
| 22 | Start the drill at the gate | Drill prop appears, red draining box, cops get **Disable Drill**. |
| 23 | Let the full 15 minutes run | **The gate opens** (it never did before — the inherited code animated a door this gate does not have). Ten briefcases at `[6228.43, 2864.01]`, splitting $50k + $50k per cop online, plus the mining component. |
| 24 | Three minutes later | Gate re-seals. |
| 25 | Open the gate by hand during those three minutes, then wait for the re-seal | Gate still ends up shut. This is the animation-source bug — if it stays open, that fix did not hold. |
| 26 | Try again inside 20 minutes | Refused. |

---

## 5. Things I already know about — no need to report these

- **Cop requirements are 0** on both heists for testing. `TODO.md` carries the restore values (Fed 6, bank 4).
- **HIGH SECURITY is 300 s**, deliberately short. `TODO.md` says to lengthen it once you have played it.
- **MaxTac never comes** — `AP_fnc_maxtacDispatch` has no Malden spawn table.
- **`goldbar` may have nowhere to sell** on this map yet; that is the map-data pass.
- **The countdown box only reaches players within 400 m when the timer starts** — a cop responding from
  town sees no clock. Your call, left as-is for now.
- **A cracked safe unlocks but does not swing open**; you open the door yourself. Matches the original.
- **The dome and centre are 2.1 m apart**, so both terminals are effectively the same spot,
  distinguished by phase. Worth judging the layout in game.
- On the demo route the door flags flip a few seconds before the charge detonates — state only,
  nothing pops open early.

---

## 6. If something fails

Grab the matching log lines and send them. The useful greps:

```bash
grep -n 'maldenFed\]\|maldenBank\]' /home/timb/arma3server_dev/loonydev.log   # the event's own trace
grep -n '\-SEC-' /home/timb/arma3server_dev/loonydev.log                       # anything the server refused
grep -n -i 'undefined variable\|error in expression' /home/timb/arma3server_dev/loonydev.log
```

The last one printed **zero** on the current build. If it starts printing, that is the first thing to
send me.

---

# Addendum — b0128 (2026-07-29)

Two bugs you reported were fixed, and one thing I told you about them was **wrong**. Read the
correction first, because it changes what you should test.

## What was actually wrong

**The two unsealed gates — real, now fixed.** The compound has **five** gates, not one. The resolver
only ever searched a 15 m bubble around your breach anchor, so it found one and never touched the
other two concrete perimeter gates at 65 m and 70 m. Those are what you were opening by hand. All
three are now sealed at boot and all three open on a successful breach.

**The briefcases — real, now fixed.** `Land_Suitcase_F` is a PhysX body and they were spawned live
with simulation on, so they settled wherever gravity took them. They are now frozen and re-placed,
and the boot/spawn log re-reads their positions afterwards to prove it took.

**The door-lock "casing bug" — NOT REAL. I got this wrong.** I told you `bis_disabled_door_N` and
`bis_disabled_Door_N` were different keys and that every Fed door had been openable since it was
written. SQF variable names are case-insensitive (BIKI `Identifier`: "Identifiers are
case-insensitive"; `allVariables` returns every name lower-cased). Both spellings are the same
variable. The dome, the centre and the ten ring safes were locking correctly the whole time — which
is exactly why you said the dome was fine. The spelling was standardised anyway, but it fixed
nothing, and seven comment blocks that claimed otherwise have been retracted.

## The trap — do not report this as a bug

The vanilla **"Open Door" scroll option is ALWAYS offered, even on a perfectly locked gate.** Its
config condition tests the door's animation phase, not the lock variable — only "Close Door" tests
the lock. Using it on a sealed gate plays the locked jiggle and nothing opens. This is true of the
gates, the dome, the centre and all ten safes. **A locked door still shows the option.**

## Boot — verified on b0128, confirm it still reads this

```
[maldenFed] anchor GATE 1/3 [perimeter] ... 0.0 m from the breach anchor      <- the one you nominated
[maldenFed] anchor GATE 2/3 [perimeter] ... 70.17 m from the breach anchor
[maldenFed] anchor GATE 3/3 [perimeter] ... 65.27 m from the breach anchor
[maldenFed] gate NOT SEALED (pedestrian, deliberate) x2
[maldenFed] fedLockdown: locked 15 object(s) -- 3 perimeter gate(s), dome, centre and 10 safe(s)
```

**Read the gate count, not the total.** `3 perimeter gate(s)` is the field that proves the fix.

## Test

| # | Do this | Expect |
|---|---|---|
| A1 | With no robbery running, walk to **each of the three concrete gates** and try to open by hand | All three refuse. The option appears (see the trap above) — it just doesn't open. |
| A2 | The two **back-alley pedestrian gates** (west, toward the pier) | These **do** open. Deliberate — they are not perimeter, they have no breach path, so sealing them would be permanent. Logged at boot as such. |
| A3 | Breach the front gate with the Sequence minigame | **All three** concrete gates open, not just the one you breached. |
| A4 | After the reset | All three re-seal. |
| A5 | Let the dome timer run out, then check every ring building | Briefcases sit **inside**, on the floor, at the height they were placed. None under the compound, none on the terrain below. |
| A6 | The Alamo centre cases, and the boat's gold | Same — placed, not fallen. |
| A7 | Grab a briefcase | Pickup still works. The freeze must not have broken it. |

## Known, do not report

- **Why half the briefcases fell is still unexplained.** The freeze fixes it either way, but the
  original theory (no server-side floor under them) turned out to be wrong — the cases do sit on
  server-side floors. Only the mining component's placement jitter still fits that story. If any
  case still moves, that is worth telling me; the answer is in that gap.
- `animateSource` on these `disableSimulation = 1` gates is proven on the anchor gate and now
  applied to three. If gate 2 or 3 looks inert after a breach, tell me.
- The dome/centre/safes lock exactly as they did before b0128. Nothing about them changed.
