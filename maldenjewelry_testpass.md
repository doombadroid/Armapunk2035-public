# Jewelry Emporium — in-game test pass

Built, reviewed and on the dev server as **`Armapunk2035_b0127`**. Nothing below has been
exercised with a player in the world; that is what this document is for.

**Changed since b0125 — the things most worth your attention:**

| What | Why it matters |
|---|---|
| Drill radius 6 m → **10 m** | At 6 m the option was unreachable *standing against the gate* — it measured 6.35 m, because `distance` runs to the object's origin. This is the fix for "no scroll wheel option". |
| The back gate is now **sealed** | It was never locked, so the drill opened nothing. Locked at boot, opened by the drill, re-sealed at window close. |
| `jewelBag` now sells for **$17,500** | It was **$0**. A completed run destroyed the haul and paid nothing. |
| The **African Warlord** now exists on Malden | He was standing on an Altis coordinate off the edge of the map, so there was nobody to sell to. Now at `[8546.79, 7674.1]`, ~3 km from the shop. |
| The **15-minute cross-heist lockout is live** | It was read by five heists and armed by none. Now armed at heist start *and* end. This changes pacing for the Fed, bank, convoy, prison break and Loony Bin too — not just jewelry. |
| Cop counting now matches server-side | The client counted every cop online; the server counted only cops on duty 5+ minutes. A legal-looking drill could be refused *after* the 10-second bar. |

**Dev server:** `~/arma3server_dev`. Redeploy with `bash deploy/reload-armapunk2035.sh`.
Log: `/home/timb/arma3server_dev/loonydev.log`.

Useful tail for the session:

```bash
tail -f /home/timb/arma3server_dev/loonydev.log | grep --line-buffered 'maldenJewel\]\|\[jewelry\]\|-SEC-'
```

Note the feature logs under **two** prefixes — `[maldenJewel]` at boot, `[LooneyBin][jewelry]` at
event time. Grep for both or you will miss half of it.

---

## 1. Boot — already verified, confirm it still reads this

```
[maldenJewel] gate  = Land_BackAlley_01_l_gate_F via nearestObjects (mission object) at [7535.69,10577.1,0.52], 1.7 m from the anchor
[maldenJewel] safe  = Fridge_01_closed_F at [7538.99,10583.7,0.15] (terrain 28.86, 15.2 m from the emporium centre)
[maldenJewel] display cases: 8 authored server-side, 8 found ..., 8 of them inside AP_JEWEL_POLY, 8 frozen and re-placed
[maldenJewel] display case heights 2 s after the freeze: [...] -- 0 off by more than 0.05 m
```

`0 off by more than 0.05 m` and `8 frozen and re-placed` are the two numbers that matter. A
`MOVED after being frozen` warning means all 8 cases are sitting under the shop floor on every
client while the heist still tests as working — stop and tell me if you see it.

The `4 display case(s) slid more than a metre` line is **informational and expected**. They are put
back at the authored spot.

---

## 2. Before the robbery

| # | Do this | Expect |
|---|---|---|
| 1 | Walk up to the display cases | **Break Jewel Case** offers, but acting refuses with a message about the drill. That is deliberate — it matches the crowbar guard. |
| 2 | Try to open a display case as a container | It must not open. These are `maximumLoad 4000` containers; if one opens you have 8 free gear lockers at a landmark. **Report this if it opens.** |
| 3 | Look at the safe | **Laser Cut Safe** may offer; acting refuses. |
| 4 | Walk the shop | 8 cases, upright, sitting on the floor — not sunk, not floating, not scattered. |

---

## 3. The robbery, start to finish

| # | Do this | Expect |
|---|---|---|
| 5 | Stand at the back-alley gate with ICEBREAKER firmware | **Start Drilling Door** offers within 6 m. Walk 10 m away — it disappears. |
| 6 | **Aim at the sky while standing at the gate** | The option **stays**. This is the specific bug fixed this session; if it flickers with where you look, the fix did not hold. |
| 7 | Drill it | 10 s bar. Alarm audible. MaxSec broadcast + cop alert. Every civ within 90 m picks up charge 76. Log: `robbery started by <name>`. |
| 8 | Note where the alarm sound comes from | It emits from the **gate**, not the shop — known, recorded in TODO. Tell me if it is silent entirely. |
| 9 | Smash cases with a crowbar | Each yields a gold trophy that grabs as a `jewelBag`. |
| 10 | **Smash one case, then stand between it and an intact one** | The intact one must still offer. A smashed case used to mask its neighbour — that is the `#152` symptom, fixed this session. |
| 11 | Take the crypto mining component from whichever case has it | Take it and **look at that case**. It must still be there. If the case vanishes, the `AP_questloot` fix failed and the heist will degrade by one case per run. |
| 12 | Smash 7 of 8 | The safe still refuses. |
| 13 | Smash the 8th | Safe unlocks, broadcast fires. Log: slot 2 flips. |
| 14 | Weld the safe with a butane torch | It visibly swaps to an open fridge, loot inside. |
| 15 | **Look at where the four gold trophies landed** | They sit 0.8 m off the safe, heading-relative. If they are inside a wall, tell me — this is the one placement I could not settle from code. |
| 16 | Loot the safe | Several `jewelBag`s — this is the big prize, not one bag. |

---

## 4. The getaway

| # | Do this | Expect |
|---|---|---|
| 17 | After looting | "Getaway boat"-style broadcast; an armed Qilin at `[7515.07, 10599.3]` facing south (dir 180). |
| 18 | Check the Qilin | Not inside a wall or rock. Loaded with 10 `jewelBag`. Unlimited T inventory. Anyone who was on site can drive it. |
| 19 | Read the message on each trophy pickup | It should point you at the **African Warlord**, not a "loading container" — there is no container on this map. |

## 4b. The payday — this is the part that has never worked

| # | Do this | Expect |
|---|---|---|
| 20 | Open the map | A **Black Market**-style marker at `[8546.79, 7674.1]` plus a red illegal-area ring around it. |
| 21 | Drive there (~3 km from the shop) | The **African Warlord** NPC is standing there, facing roughly at the dead-end road. He did not exist on this map before today. |
| 22 | Sell the haul | `jewelBag` pays **$17,500** each. A full run is ~23 bags, so roughly **$402,500**. If it says **$0**, the price fix did not take — stop and tell me. |
| 23 | While wanted, stand near him | Being inside a red illegal zone means an informant can report you to MaxSec. Same as every other illegal site. |

---

## 4c. The cross-heist lockout — new, and it affects every heist

This is the change most likely to surprise you, because it is not jewelry-specific.

| # | Do this | Expect |
|---|---|---|
| 24 | Right after starting the emporium job, try to start the **Fed or the bank** | Refused — "security is high due to a recent robbery". Before today this was read by five heists and armed by none, so it never fired once. |
| 25 | Finish or abandon the emporium job, then try another heist | Refused for a further 15 minutes. It arms at heist **start** and again at heist **end**. |
| 26 | Same test from the **prison break** side | Same behaviour. The prison break also gained the server-side cop check, cooldown and lockout it never had — its gates were client-only. |
| 27 | Reboot, then immediately start any heist | Must be **allowed**. A lockout that blocked the first heist of a session would be a regression. |

## 5. Reset and re-run

| # | Do this | Expect |
|---|---|---|
| 20 | Leave it 20 minutes | Scene resets: cases restored, safe closed again, un-grabbed trophies swept. The Qilin **survives** — that is intended, a crew that drove off keeps it. |
| 21 | Try immediately | Refused, 30-minute cooldown. |
| 22 | Wait it out and re-run **as a different player** | The whole heist must work again, including the weld. The welder claim used to outlive the reset so only the first welder could ever weld again. |
| 23 | Complete a second run | Only **one** Qilin on the pad. A second used to spawn inside the first and leave an unlocked armed vehicle with $25k aboard for any passer-by. |
| 24 | Restart the server | The Qilin is **gone**. |

---

## 6. Things I already know about — no need to report

- **Cop requirement** is whatever slot 6 holds, floored at 1, matching how the Fed and bank were left. Production value is your call; it is in `TODO.md`.
- **`SRV_lastRobbery`**, the 15-minute cross-heist cooldown, is still client-only. Shared across heists, so I did not widen into it.
- **14 dead display-case rows** still sit at the old map's coordinates, 14.5 km away, off Malden. Harmless, never spawn. Your call whether to strip them.
- **`fn_setupActions.sqf:895-902`** has old "Jewelry Desk/Gate" camera options on the old map's coordinates. Unrelated to this work.
- **The sportsbook** still points the jewelry market at the old map's coordinates (`init.sqf:294`). Port residual.
- **`lockInventory` is documented `eff = local`** — step 2 above is what actually settles whether it bound.

---

## 7. If something fails

```bash
grep -n 'maldenJewel\]\|\[jewelry\]' /home/timb/arma3server_dev/loonydev.log
grep -n '\-SEC-' /home/timb/arma3server_dev/loonydev.log
grep -n -i 'undefined variable\|error in expression' /home/timb/arma3server_dev/loonydev.log
```

The last one printed **zero** on this build. If it starts printing, that is the first thing to send me.
