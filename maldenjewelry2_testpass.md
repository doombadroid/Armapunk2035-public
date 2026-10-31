# Jewelry Emporium — redesign test pass (b0132)

Live on dev now. This is the **new** flow, not the old one — the crowbar and the plasma cutter are
gone, everything is a hack, and the Qilin is no longer the reward for the safe.

Design: `maldenjewelry2.md`. Server log: `/home/timb/arma3server_dev/loonydev.log`.

```bash
tail -f /home/timb/arma3server_dev/loonydev.log | grep --line-buffered 'maldenJewel\]\|\[jewelry\]\|-SEC-'
```

---

## What you need

- **ICEBREAKER firmware** — flash at Kabuki. Civilian only; a cop who flashed it on their civ
  character does not count. **No crowbar, no plasma cutter** — both delisted from the Rebel Market.
- **At least 1 cop online**, or FED OVERRIDE in the admin menu.
- Nothing else. Every stage is a Cyberdeck hack now.

## The new flow, in order

1. Breach **any** of the six sealed gates → **starts the job**: alarm, MaxSec broadcast, wanted charge
   within 90 m, 20-minute window, and the coffins become crackable.
2. Hack each display case — **eight separate Sequence hacks**, one per case.
3. All eight done → the safe unlocks.
4. **Terminal** hack on the safe → it swings open, four trophies drop, and the **Hope Diamond** is
   inside.
5. Take the diamond and the safe's bag off the safe by scroll.
6. Carry the haul to the **crane** at `[7515.6, 10596.1]` → **"Load Jewelry"** → 2-minute bar.
7. The **Qilin** spawns loaded, and you drive to the African Warlord at `[8546.79, 7674.1]`.

---

## 1. Boot — verified, confirm it still reads this

```
[maldenJewel] 6 gate(s) SEALED
[maldenJewel] gate NOT SEALED (decorative -- cannot be opened) = Land_BrickWall_03_l_gate_F
[maldenJewel] boot complete -- 6 gate(s) sealed (anchor bound: true), safe true, crane anchor [...]
[maldenJewel] crane OBJECT = NULL   <- CORRECT, not a bug. See note below.
errors: 0
```

`crane OBJECT = NULL` is deliberate. The crane is a client-local object the server cannot see, so
"Load Jewelry" gates on **distance to the coordinate**, the same way the Fed's dome terminal does.

---

## 2. The six gates

| # | Do this | Expect |
|---|---|---|
| 1 | Before anything, try each of the six gates by hand | None opens. **"Open Door" still appears on all of them** — that option tests the animation phase, not the lock, so its presence proves nothing. Judge by whether the gate *moves*. |
| 2 | At `[7551.46, 10607.5]` note there are **two** gate-looking objects | The brick one is decorative — no doors, cannot be opened or sealed, logged as such at boot. The real gate is 5 cm further out. Not a bug. |
| 3 | Breach the **back gate** `[7535.69, 10577.1]` | Sequence hack. Alarm, MaxSec broadcast, charge 76 within 90 m, red marker, 20-min window. |
| 4 | Reset, then breach one of the **concrete gates at 42 m** instead | **The job starts from there too.** This is new — the alarm can now be tripped from outside the shop. |
| 5 | Mid-heist, breach a second gate | It opens, silently, and does not restart the job. Deliberate. |
| 6 | Leave a breached perimeter gate alone for 10 minutes | It **re-seals**. Without this, one breach per gate defeated the boot seal for the rest of the session. |

---

## 3. The cases and the safe

| # | Do this | Expect |
|---|---|---|
| 7 | Hack a display case | Sequence hack, no crowbar. A gold trophy appears **sitting on the case lid**, not floating a metre above it. |
| 8 | Look closely at the trophy | Boot log should read `gap 0.000 m`. If it floats, tell me the log line. |
| 9 | **Take the crypto mining component from whichever case has it, then look at that case** | The case must still be there. If it vanishes, stop — the heist degrades by one case per run. |
| 10 | Hack 7 of 8 | The safe still refuses. |
| 11 | Hack the 8th | Safe unlocks. |
| 12 | **Terminal** hack the safe | It opens. Four trophies drop, sitting on the safe, not floating. |
| 13 | Read the broadcast and the hint | Both should now **name the Hope Diamond** and tell you it must be scrolled off the safe. |
| 14 | Scroll the safe | The option reads **"Take Safe Loot — HOPE DIAMOND"** while the diamond is in there. |
| 15 | Take it | You get the diamond **and** the safe's bag. Log: `safe looted by ... granted 1 Hope Diamond + 1 jewelBag`. |

**Step 15 is the one that failed last run.** The diamond was always there and flagged — nothing told
you to scroll the safe, and the log shows you never did. If it still fails, send me the log line.

---

## 4. The crane and the getaway

| # | Do this | Expect |
|---|---|---|
| 16 | Carry the haul to the crane `[7515.6, 10596.1]` | **"Load Jewelry"** offers. |
| 17 | Run the 2-minute bar | Your bags and the diamond leave your inventory, the Qilin spawns at `[7515.07, 10599.3]` facing south, loaded with what you gave it **plus 5 bonus bags**. |
| 18 | Check the log | `crane load by ...: claimed N bag(s) + N Hope Diamond(s), accepted N + N (cap ...), loaded N bag(s) with the 5 flat bonus`. |
| 19 | Try to load a second time | Refused. Must not mint a second Qilin. |
| 20 | Check the Qilin | Armed, unlimited T inventory, drivable by anyone who was on site, gone after a restart. |
| 21 | Drive to the Warlord `[8546.79, 7674.1]` and sell | ~$17,500 a bag. |

---

## 5. Known, deliberate — please don't report these

- **`crane OBJECT = NULL` at boot** is correct, as above.
- **The decorative brick gate at C** cannot be sealed. It has no doors.
- **"Open Door" appears on locked gates.** Config condition tests the animation phase, not the lock.
- **The diamond can be pocketed and sold on foot** for $108,000 without loading the Qilin. You chose
  this — it's a second, quiet escape route and a reason to frisk.
- **A refused perimeter breach still opens the gate**, silently. The commonest reason is "a robbery is
  already running", and shutting the gate there would strand the crew.
- **The doors do not auto-open when the load completes.** That part of your brief is not built —
  `["open"]` with no argument only touches the anchor gate. Tell me which doors you meant.

## 6. Open, waiting on you

- **"Take Jewelry Piece" still gates on `cursorObject`** — the same split the safe loot had. Left
  alone because up to 12 trophies exist at once, so no single anchor works, and the fix changes
  *which* trophy you pick up. Your call.
- **Two players grabbing one trophy each get a bag.** Pre-existing and shared with fishing, turtles
  and skinning — but a bag is now $17,500, not the $2,500 it was when that was last judged
  acceptable.
- **8 case hacks + up to 6 gate hacks + a terminal** is a lot of minigames per run. You chose one
  hack per case knowingly; worth re-judging once you've played it end to end.

## 7. If something fails

```bash
grep -n 'maldenJewel\]\|\[jewelry\]' /home/timb/arma3server_dev/loonydev.log
grep -n '\-SEC-' /home/timb/arma3server_dev/loonydev.log
grep -n -i 'undefined variable\|error in expression' /home/timb/arma3server_dev/loonydev.log
```

The last one printed **zero** on this build.
