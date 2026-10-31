# DUTY_SOAK.md — owner playtest script for the faction rework

Everything in the faction rework (chain PRs #35–#41 plus this one) was proven by
reading code, tracing control flow and booting a server. **Nothing in it has been
proven by a human playing the game.** This file is the script that closes that
gap.

It is written to be worked through top to bottom in one or two sittings. Sections
A–C need one client. Section D needs **two**. E–G can be done in any order once
A–C pass. **Section H is the two web sign-on screens** — H1–H12 are the landing
screen, which is the first thing you see on every connect, so you have already
exercised it by the time you reach A; run those cases the first time you join.
H13–H17 are the MaxSec duty terminal at the HQ tablet and belong with B.

Read section 0 first — two of the rules in it will cost you an evening if you
learn them the hard way.

---

## 0. Before you start

### The one deploy rule that is not negotiable

**The flag and the slot layout are ONE deployable unit, in both directions.**

`AP_dutyEnabled` (server_init.sqf) is the master switch. Every compat clause in
the tree keys on that flag **alone** — never on "is the roster empty". So:

| you ship | against a mission.sqm with | result |
|---|---|---|
| flag `true` | 60 civilian slots (current) | correct |
| flag `false` | 60 civilian slots | all-civilian world, terminals dead, coherent |
| flag `true` | old west/independent slots | **every serving officer loses all authority at boot** |
| flag `false` | old west/independent slots | the pre-rework world |

Never deploy the mission PBO and the server addon from different commits.

### What "off duty" means now

There are no police or medic lobby slots. Everyone joins civilian. MaxSec and
Trauma Team are a **shift**: you walk to an HQ terminal, clock on, and the server
writes a roster entry that lasts until you clock off, disconnect or the watchdog
takes it back. The roster (`AP_dutyRoster`), not the engine side and not a slot
name, is what every server-side authority check reads.

### Terminals

| faction | where | condition |
|---|---|---|
| MaxSec | within **5 m** of marker `cop_spawn_2` — Emergency Response HQ, `[10502.0, 4048.0]` | flag on, no dialog open, on foot |
| Trauma Team | within **5 m** of marker `med_spawn_1` — main hospital, `[7200.0, 7850.0]` | same |

5 m is deliberate and tight. If you cannot find the action, walk closer before
you conclude it is broken.

The action now hangs on the owner's **tablet props** at each HQ rather than on
distance to the marker, and at a MaxSec tablet it opens two different things
depending on your state: **off duty** -> the HTML duty terminal (938200, five
role rows); **on duty** -> the clock-off turnaround, unchanged. Trauma keeps the
old picker in both directions. See H13-H17.

### Setup

**Deploy to dev** (never `reload-loonydev.sh` — that packs the other project):

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

**Wait for the boot marker** (~40–90 s):

```bash
grep "read from bank" /home/timb/arma3server_dev/loonydev.log
```

**Tail the server log for duty traffic** (leave this running in a second pane):

```bash
tail -f /home/timb/arma3server_dev/loonydev.log | grep -E '\[AP-DUTY\]|\[LB-LOG\]|Number of roles'
```

**Client RPT** (the `[AP-DUTY]` breadcrumbs that never reach the DB land here,
on the machine they happened on — newest file by mtime):

```bash
ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1
```

**DB peek** — dev schema is `looneybin_test`:

```bash
DBQ() { docker exec looneybin-db mariadb -ulooneybin -plooneybin looneybin_test -N -B -e "$1"; }
```

The four queries you will use constantly (substitute your Steam64 — the owner's
is `76561190000000001`):

```bash
U=76561190000000001

# 1. the duty audit trail, newest first
DBQ "SELECT ts,tag,playerid,name,message FROM log
     WHERE tag IN ('-DUTY-','-SEC-','-DISCONNECT-','-MONEYGUARD-')
     ORDER BY id DESC LIMIT 40;"

# 2. the three characters' gear, as lengths -- you are watching which one MOVES
DBQ "SELECT LENGTH(civ_gear) civ, LENGTH(cop_gear) cop, LENGTH(med_gear) med,
            LENGTH(civ_talents) civT, LENGTH(cop_talents) copT, civ_exp, cop_exp, med_exp
     FROM players WHERE playerid='$U';"

# 3. whitelist levels (what the terminal actually reads)
DBQ "SELECT coplevel, adminlevel, mediclevel FROM players_global WHERE playerid='$U';"

# 4. garage partition
DBQ "SELECT side, COUNT(*) FROM vehicles WHERE pid='$U' GROUP BY side;"
```

### The five log tags

| tag | where it lands | what it means |
|---|---|---|
| `-DUTY-` | `log` table + RPT as `[LB-LOG]` | normal roster life: GRANTED, CONFIRMED, RELEASED, ROLLBACK, REFUSED, REAPED, ROUTE MISMATCH |
| `-SEC-` | `log` table + RPT | something was refused as an attack: BLOCKED, EJECTED |
| `[AP-DUTY]` | **RPT only, on the machine it happened on** | breadcrumbs that must never reach the DB — forged-call refusals, throttles, stash failures |
| `[LANDING]` | **the CLIENT's RPT only** | the landing screen's own trace: which decline it took, the deploy verb, the grant/refusal it correlated. Nothing about it reaches the server log, so section H needs the client RPT open: `ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt \| head -1` |
| `[DUTYTERM]` | **the CLIENT's RPT only** | the MaxSec duty terminal page's own trace: the open (display up and bound, or which fallback it took), each local refusal, and the request it correlated. Same client RPT as `[LANDING]`. |

A `-SEC-` row during honest play is a bug **in this rework**, not a cheater.
Write down which test produced it.

### Setting the whitelist for testing

Levels live in `players_global`, and the terminal reads them from the server, so
editing them in the DB is the real thing:

```bash
DBQ "UPDATE players_global SET coplevel=6, adminlevel=0, mediclevel=1 WHERE playerid='$U';"
```

Take effect at the next **sign-on request** (they are read live, not cached at
login), so you do not need to relog between whitelist changes.

---

## A. Boot — no client needed (5 min)

**A1. Roles and the slot count.**
`grep "Number of roles" /home/timb/arma3server_dev/loonydev.log`
→ expect **`Number of roles (60)`**, and **no** `is different from maxPlayer`
warning (PR8 set `description.ext` maxPlayers to 60 to match).

**A2. Duty init ran.**
`grep "\[AP-DUTY\] init" loonydev.log`
→ one line, `init: MaxSec=<netId> TraumaTeam=<netId> roster ready`.
If it is absent, the flag is false or `["init"]` never ran, and every later test
will fail for that reason and no other.

**A3. Clean RPT.** Sweep for `Error`, `Undefined variable`, `Missing`, and in
particular for missing-function errors from the PR7 `Functions.h` / `CfgDebriefing`
deletions and the PR8 `config.cpp` deletions. One known pre-existing exception:
`server_init.sqf: unknown command token: HC1` — that reproduces on clean history
and is not new.

**A4. The two terminals exist.** Fly/teleport to `cop_spawn_2` and `med_spawn_1`
and confirm the scroll actions appear within 5 m. This is the first thing that
proves the mission and the server addon are from the same build.

---

## B. The happy path — one client (20 min)

Set `coplevel=6, mediclevel=1` first (test B7 lowers it again).

**B1. Sign on to MaxSec.**
Walk to the MaxSec terminal, take the action, pick `patrol`.
Expect: you go west, get the MaxSec group ("MaxSec"), get a kit, and see
`You are on duty: MAXSEC (patrol).`
Log: `-DUTY- GRANTED faction=maxsec role=patrol uid=…` then, within a second or
two, `-DUTY- CONFIRMED faction=maxsec role=patrol uid=…`.
**If CONFIRMED arrives with `reason=engine-confirmed (no ack)` ~10 s later**, the
client's ack is not landing — note it; the shift still works, but that is a real
finding.

**B2. Your kit is YOUR kit.** If `cop_gear` had a saved loadout, you should be
wearing it — weapons, uniform, backpack, **virtual inventory** and clothing skin
indices all restored. Not naked, and not a fresh default. This is the bug class
(PR4 C-4 / IMP-2) that ate kits twice; check the Y-inventory, not just the gun.

**B3. Nothing of your civilian character came with you.** Your virtual inventory
should be the cop's, not the civilian's — no contraband carried across. Check the
Y menu.

**B4. The talent trees moved too.** Open the talent UI. You should be looking at
the MaxSec trees and exp, not the civilian's. (The trees ride along with the kit
by design; a shift that loads one without the other is a half-restored character.)

**B5. Paycheck.** Wait for a paycheck tick.
Expect **10000** on duty as MaxSec `patrol` (plus the fed-proximity bonus and cop
prestige accrual if applicable), **10000** on duty as Trauma `ttmedic` (no fed
bonus, no prestige), **350** off duty as a civilian.
This is PR6's fix for a real defect — the FSM used to read `playerSide`, which is
frozen at lobby side and never matches a duty cop.

**B6. Clock off.** Back to the terminal, take the release action.
Expect: `You are off duty (released).`, you are civilian again, your **civilian**
kit + virtual inventory + skins are back, and you are put back where you were
standing when you signed on.
Log: `-DUTY- RELEASED faction=maxsec role=patrol uid=…` then `-DUTY- OFF CONFIRMED`.

**B7. The whitelist actually gates.** Run the matrix — this is the arm that a
comment-rewrite silently deleted once (PR7-fix CRITICAL), so test all three:

| coplevel | adminlevel | expect |
|---|---|---|
| 1 | 0 | granted |
| 0 | 1 | granted |
| 0 | 0 | **refused**: "You are not on this faction's roster." + `-DUTY- REFUSED … reason=not whitelisted (cop 0 admin 0 med …)` |

**B8. Trauma Team.** Repeat B1–B6 at the hospital terminal with `mediclevel=1`.
Then set `mediclevel=99` and try again → **refused**. 99 was the old
EMT-volunteer sentinel and must never be a Trauma credential; the tier is closed
deliberately and this is an owner-visible policy change.

**B9. Cooldown.** Immediately after a clock-off, try to clock straight back on.
Expect a refusal naming the seconds left (600 s window) — **and no grant**. Both
happening at once was PR4's C-2 (the PHANTOM-ELSE class); if you get the message
*and* the shift, that bug is back.

**B10. Terminal spam is throttled.** Scroll-spam a sign-on request.
Expect: at most one DB round trip per 10 s per account, and **silence** — no
player-facing message. The throttle logs to the RPT only:
`[AP-DUTY] request throttled: faction=… uid=… (within 10s of the last one)`.

**B11. Invisible backpack survives the swap.** If you use the invis-bag shop
option, clock on and off and confirm the bag is still invisible. `setUnitLoadout`
rebuilds the backpack as a visible object, and the post-swap re-skin skips it
because its skin index is -1, so it is re-hidden explicitly. Easy to regress
silently.

**B12. The terminal actions survive a whole session.** The DONG action scanner
sweeps `addAction` titles and bodies for a denylist and will `removeAction` a
match **and report the player**. Both terminal actions were checked against that
list statically. Play a normal hour and confirm the actions are still there at
the end of it, and that nothing about you shows up in the `log` table under an
anti-cheat tag.

**B13. Entry state gates.** Try to clock ON while dead, downed, restrained,
jailed, in a clothing store, in an event, or as an active MAXTAC/firefighter →
refused before any DB read. Try to clock OFF while restrained, wanted (bounty),
or during an active federal event / structure fire → refused with the specific
reason. These gates run on BOTH ends of the shift (PR4 I-A).

**B14. The bounty gate is faction-split now.** Owner ruling 2026-08-20. Give
yourself a real bounty first — commit an actual charge rather than editing the
DB, because the figure the terminal quotes is `APS_wantedList` index 3 (server
`localNamespace`), which `APS_fnc_wantedSyncList` rebuilds from the charge counts
the offender's own client pushes up (count × charge value, never the client's total).
It is the same number an arresting officer is paid.

| you are | you try | expect |
|---|---|---|
| wanted, `mediclevel>=1` | clock ON at the **hospital** terminal | **granted.** No bounty check runs for Trauma at all |
| wanted, on Trauma duty | clock OFF at the hospital terminal | **granted.** The clock-off gate follows the same exemption — otherwise a medic who signed on legally would be stuck on shift until the bounty cleared |
| wanted, `coplevel>=1` | clock ON at the **MaxSec** tablet | **refused**, and the line names the money: `YOU HAVE AN OUTSTANDING BOUNTY OF $N. CLEAR IT OR PAY IT OFF.` |
| wanted, on MaxSec duty | clock OFF at the MaxSec tablet | **refused**, unchanged — an officer does not clock off to walk away from their own bounty |

Server log for the MaxSec refusal:
`-DUTY- REFUSED faction=maxsec uid=... reason=wanted $N (buyout $N)`. The two
figures differ only if the owner has moved `SRV_dutyBuyoutMult` off 1.0.

**B15. Pay the bounty off at the terminal.** This is the money path — run every
row, and check `bankacc` in the DB before and after each one, not just the last.

| case | expect |
|---|---|
| **not enough money** | the confirm appears; after it, `YOU CANNOT AFFORD THE $N PAYOFF -- YOUR BANK HOLDS $M.` **`bankacc` unchanged, wanted level unchanged, no `-DUTY- DEBIT` row.** The refusal is issued *before* the write, so there is nothing to reconcile |
| **enough money** | one confirm (`Pay off your $N bounty and sign on?`), then a green `Bounty settled -- $N paid` toast, then the shift is granted with no second click |
| the debit | `bankacc` falls by **exactly** the figure the server quoted. `SELECT * FROM log WHERE tag='-DUTY-' AND message LIKE 'DEBIT%' ORDER BY ts DESC LIMIT 1` → `DEBIT $N (duty bounty payoff) bank $X -> $Y`, **one row, written after the read-back**, never on the click |
| the clear | your bounty goes to **0 on your own HUD**, you disappear from a second client's cop Wanted menu, and `SELECT * FROM wanted WHERE playerid='$U'` returns nothing. All three because it went through `APS_fnc_wantedPardon` and not a hand-rolled clear — if any one of them still shows you wanted, that is the bug this case exists to catch |
| the retry | exactly **one** re-send. Client RPT: `[DUTYSCROLL] request sent` → refused → `[DUTYSCROLL] payoff confirmed` → `[DUTYSCROLL-RETRY] request sent` → granted. A third request is a loop and a defect |
| **pay it twice** | do it again inside 10 s: nothing happens and the server RPT says `[AP-DUTY] payoff throttled`. After 10 s: `YOU HAVE NO OUTSTANDING BOUNTY TO PAY OFF.` **No second debit, either way** |
| **not whitelisted** | `coplevel=0, adminlevel=0`, wanted, use the scroll action anyway → `YOU ARE NOT ON THIS FACTION'S ROSTER.` and **`bankacc` unchanged**. This is the one that matters: without it, buying a wanted-level clear would be open to any civilian |
| **jailed** | wanted + serving a sentence → `YOU CANNOT GO ON DUTY WHILE INCARCERATED.`, no debit |
| **inside the release cooldown** | clock off, then try to pay within 10 min → the cooldown refusal, **no debit**. Money must not move for a shift that cannot start |
| **Trauma** | there is no payoff action at a hospital tablet, and a forced `["payoff","trauma"]` is refused with `THERE IS NO BOUNTY GATE ON THIS FACTION'S ROSTER.` before any read |

The multiplier is `SRV_dutyBuyoutMult` in `server_init.sqf` (1.0 = face value).
Set it to 2 and re-run the "enough money" row: the quote, the confirm, the debit
and the `log` row must all four move together.

---

## C. Persistence — one client + the DB (20 min)

This section is the one that catches silent data loss. Run query **#2** from
section 0 before and after every step and watch **which column changes**.

**C1. Civilian kit is flushed BEFORE the side moves.** Note `LENGTH(civ_gear)`.
Change your civilian kit (buy something), then clock on.
Expect: `civ_gear` **updated at clock-on**, `cop_gear` untouched until you change
something on duty. If `cop_gear` moved and `civ_gear` did not, the flush ran a
line late and your civilian character just went into the cop column — stop and
report it.

**C2. On-duty changes land in the DUTY column.** On duty, buy/drop something.
Expect `cop_gear` (or `med_gear`) to change; `civ_gear` frozen.

**C3. Clock-off flushes the duty character BEFORE flipping back.**
Expect `cop_gear` updated at clock-off, then `civ_gear` updated again right after
with your restored civilian kit.

**C4. Talents round-trip.** Learn or respec a talent on duty, clock off, check
`cop_talents`/`cop_exp` changed and `civ_talents`/`civ_exp` did not. Then check
your civilian trees are back in the UI.

**C5. Immediate re-persist on clock-off.** Clock off, then **quit within 60 s**.
Relog. Your civilian kit must be intact. (Before PR4 I-F this waited on a 240 s
tick and a fast quit lost it.)

**C6. Position is the civilian's, always.** Sign on at the terminal, walk to the
far side of the map, disconnect while on duty, relog.
Expect: you come back **where you were standing when you signed on**, not at HQ.
`position` is the civilian character's column and an on-duty logoff spot must
never reach it (bug #439).

**C7. Garage is partitioned and the cap counts the same partition.** On duty,
open the garage: you should see the `side='cop'` rows only. Buy a vehicle on
duty and confirm query #4 shows it landing in `cop`, not `civ`. Clock off and
confirm the civilian garage is unchanged.

**C8. The base-ring exemption is narrow and self-healing.** The HQ terminal
sits inside the 1000 m no-gear-save ring around `respawn_west`, so the duty
flushes carry a deliberate one-shot bypass (`AP_dutyFlushBypass`) around exactly
those three calls. Two things to confirm: C1–C3 above must work **at the
terminal** (that is what the bypass is for), and an *ordinary* civilian gear save
made while standing at MaxSec HQ must still be **refused** by the ring — the
bypass must not have leaked into the organic save path. If you ever see
`[AP-DUTY] flush bypass self-cleared 10s after the flush that set it` in your
RPT, a swap errored mid-flush; the self-heal caught it, but the swap that
produced it is a finding.

**C9. No ROUTE MISMATCH on honest play.** After all of C1–C7:

```bash
DBQ "SELECT ts,message FROM log WHERE tag='-DUTY-' AND message LIKE 'ROUTE MISMATCH%' ORDER BY id DESC LIMIT 20;"
```

**Expect zero rows.** A `ROUTE MISMATCH` on an honest client means the roster and
the client disagree about who you are, and the save was re-routed — it landed in
the right column, but the disagreement is the finding.

**C10. No -MONEYGUARD- and no money movement you did not cause.** Check cash and
bankacc before and after a full sign-on/clock-off cycle. They must not change.
This has bitten twice (Vista, player108 — both money-to-zero at connect).

---

## D. Two clients (30 min) — the section that cannot be faked

Bring a second account up. Several of these are the only way to observe the
behaviour at all.

**D1. Two officers, one roster.** Both clients clock on to MaxSec.
Expect: both in the same "MaxSec" group, both see each other on the map / in side
chat, `AP_dutyCopCount` reads 2 (visible via the cop-count HUD / dispatch), and
the log shows two GRANTED + two CONFIRMED.

**D2. Death does not clock you off.** On-duty officer is killed by the other
client. After the respawn:
Expect: still on duty, still west, still in the MaxSec group, still on the roster,
kit restored per the death-gear rules. This was verified by enumeration only —
PR6 explicitly owes this test.

**D3. The death screen sees on-duty medics.** With one client on duty as Trauma
(or as MaxSec role `medic`/`all`), the other client goes down.
Expect: the death screen's "Trauma Team Online" counter is non-zero and "Nearest
TT Medic" resolves. Both counters read the retired slot name until PR7-fix
re-homed them onto `AP_unitCopRole`; if they read 0 with a medic clearly online,
the re-home did not take.

**D4. Request-TT reaches an all-role officer.** An on-duty MaxSec officer with
role `all` must be reachable by Request-TT and must be counted by the death
screen (PR7-fix's last commit). Test with role `all`, not just `medic`.

**D5. Markers are mutually exclusive.** On duty as MaxSec, open the map: cop
markers. Clock off: they must be **gone**. On duty as Trauma: TT hexes. Clock
off: gone. A player who holds both sets orphans one forever, and the TT hex
handler would otherwise draw over every civilian in view every frame.

**D6. Non-lethal must clear on clock-off.** Officer clocks on, equips rubber
rounds, clocks off, then shoots the other client with a normal weapon.
Expect: **real damage**. The flag is read off the *shooter* with a default of
`true`, so a stale one leaves a civilian firing tasers forever. This is
load-bearing, not tidiness.

**D7. Forged remove.** From the second client's debug console (owner UID has it
enabled), aim a forged remove at the on-duty client:

```sqf
["remove", "released"] remoteExec ["AP_fnc_dutyClient", owner <victimUnit>];
```

Expect: **nothing happens** to the victim — no side change, no kit change, no
roster change. On the victim's RPT (and only there) exactly one line:
`[AP-DUTY] BLOCKED dutyClient: sender owner N is not the server. args=…`
Nothing in the `log` table. The forged call must never be able to make the
victim's client write a DB row.

**D8. Forged apply at yourself.** Same console, at your own client:
`["apply", "maxsec", "all", [], AP_dutyGroupCopNet] remoteExec ["AP_fnc_dutyClient", owner player];`
Expect: refused identically. No kit, no side change.

**D9. Self-joining the published group.** The duty groups are published by netId
(`AP_dutyGroupCopNet`), so a client can join one directly:

```sqf
[player] joinSilent (groupFromNetId AP_dutyGroupCopNet);
```

Expect: you go west with no kit and no roster entry, and **within 60 s** the sweep
ejects you back to a civilian group and writes
`-SEC- EJECTED from duty group AP_dutyGroupCop: uid … holds no maxsec roster entry`.
Also try it as a **Trauma-rostered** player joining the **MaxSec** group — the
test is "roster entry for THIS group's faction", not merely "rostered", so that
must eject too.
⚠ Known residual: for those up-to-60 s you receive side-`west`-targeted cop
intel (~20 remoteExec sites still target the side). Confirm nothing worse than
chatter arrives.

**D10. Tenure and the heist gates read the roster.** Heist gates ask "how many
TENURED cops are on?" — that is now counted off the roster and each officer's
shift start time, not off `side _x` and not off a client variable that resets on
clock-off. With two officers on duty long enough to be tenured, confirm a
federal-event / heist gate that requires N cops actually opens; with both off
duty, confirm it stays shut. A silent zero here means every heist is either
permanently open or permanently closed.

**D11. Cross-account save (this PR's A1).** From the second client's console,
forge a save naming the FIRST client's Steam64:

```sqf
[player, civilian, "<victim Steam64>", 3, []] remoteExec ["DB_fnc_updatePartial", 2];
```

Expect: **the victim's `cop_gear`/`civ_gear` does not change**, and one row:
`-SEC- BLOCKED cross-account partial-save mode=3: packet named uid <victim>, sender is <attacker>`
with the row attributed to the **attacker**, and carrying `@SRC=<attacker uid>`.
Then confirm the honest path still works by doing an ordinary gear save (C2)
straight afterwards — the gate must be invisible to honest clients.

**D12. Unresolvable sender is a breadcrumb, not a lost-save mystery (this PR's
hardening).** D11's branch has a sibling: `_src` is real (not the server) but
names nobody currently in `allPlayers` — the sender disconnected between
sending the save and the server processing it. This is a genuine race, not an
attack: the restart force-flush broadcasts `AP_fnc_ClupdateRequest` to `-2`
(every connected client — see `!srv softr` / `init.sqf`'s scheduled path), and
respawn transients open the same window for a partial save. There must be no
`-SEC-` row and no `cop_gear`/`civ_gear`/`bankacc` mutation for anybody either
way.
Hard to force exactly (the window is a couple of network round trips wide).
Best-effort recipe: from the server console, fire the same broadcast the
restart path uses —
`[[], "AP_fnc_ClupdateRequest", -2, false, false] spawn AP_fnc_MP;` — and
alt-F4 a client as close to instantly afterward as you can manage.
Expect **one line, RPT-only, on the machine that ran the save** (never the
`log` table): `[AP-DUTY] full-save dropped, unresolvable sender: payload
uid=… owner=…` (or the partial-save wording, with `mode=…`, if a partial loses
the race instead). **Pre-fix, this branch was byte-silent** — nothing in the
RPT, nothing in the DB — so a save that quietly never happened looked
identical to one that succeeded; the breadcrumb is the only thing that turns
"why did this row never update" back into an expected, attributable drop.

---

## E. The kill-switch (10 min) — new in PR8

`AP_dutyEnabled` is documented as a runtime kill-switch. Until this PR, flipping
it off with officers on duty **stranded them**: west, in the duty kit, holding a
headcount, with no terminal to clock off at.

**E1. Flip it off with two rostered.** Both clients on duty, then queue the
`dutyswitch` bot verb (`server/AP_server/init.sqf`, bot_commands bridge). It is
the only runtime path: the server acts on its `localNamespace` copy since audit
Lsec-0-1, a client-side `publicVariable` of the global is refused, restored and
logged `-SEC-`, and .96 has no SERVER EXEC. The bot process is not ported yet
(MIGRATION_96 D10), so insert the row by hand — on .96
`docker exec armapunk-pg psql -U armapunk -d armapunk -c "…"`, on dev the same
against `pgm_full_scratch`:

```sql
INSERT INTO bot_commands (command, arg1, issued_by) VALUES ('dutyswitch', 'off', 'soak');
```

The bridge polls every 5 s; the row goes `done` (`error` = arg1 was not
`on`/`off`) and the server RPT says `[AP-DUTY] kill-switch off by bot_commands #N`.

Expect, within **60 s** (the sweep interval):
- both clients get "You are off duty (flag-off)." and are civilian again,
- both civilian kits, virtual inventories and skins restored,
- both duty characters flushed to `cop_gear`/`med_gear` first (check query #2 —
  the duty column should move, then the civ column),
- **position is NOT restored** — you stay where you are standing. That is
  deliberate: a drained player is not where they signed on.
- log: one `-DUTY- RELEASED faction=… uid=… reason=kill-switch drain` per entry,
- RPT: `[AP-DUTY] kill-switch: roster drained, N entries removed`,
- the terminal actions disappear.

**E2. Flip it off with nobody rostered.** Expect an absolute no-op apart from
the verb's own `[AP-DUTY] kill-switch off by bot_commands #N` line: no rows, no
further RPT line, no message, every 60 s forever.

**E3. Flip it back on.** Same as E1 with `'on'`:
`INSERT INTO bot_commands (command, arg1, issued_by) VALUES ('dutyswitch', 'on', 'soak');`
Expect: terminals reappear, and you can clock straight back on **with no
cooldown** — a drain deliberately stamps none. No second `["init"]` is needed;
the groups and maps survive the off state. (On a server that *booted* with the
flag false — E5 — there is no roster yet, and the verb runs `["init"]` itself.)

**E4. The flag-off silence contract changed here, deliberately.** Before this
PR a forged call to `AP_fnc_dutyClient` arriving with the flag off was
**byte-silent** — no message, no DB write, not even an RPT line. That is still
true for every mode except `"remove"`. With the flag off, repeat D7's forged
remove and expect **exactly one line** in the victim's RPT
(`BLOCKED dutyClient: sender owner N is not the server`) and **nothing** in the
`log` table. That one line is the entire price of being able to end a shift while
the switch is off. If you see a DB row, or the victim actually comes off duty,
the origin assertion has been weakened and that is a critical.

**E5. Cold boot with the flag false.** Set the `localNamespace setVariable ["AP_dutyEnabled", …]` literal to `false` in
`server_init.sqf`, redeploy, and confirm the world is a coherent all-civilian
server: no terminals, no groups, no `[AP-DUTY] init` line, nobody with cop
authority, and no errors. This is the rollback state and it is one boolean.

---

## F. Failure and cleanup paths (20 min)

**F1. Watchdog rollback.** Clock on, then alt-F4 / kill the client within the
10 s ack window, then relog.
Expect: `-DUTY- ROLLBACK faction=… uid=… reason=no ack within 10s`, the roster
entry gone, headcount back down. (If the side change actually landed before you
died, you should instead see `CONFIRMED … reason=engine-confirmed (no ack)` —
both are correct outcomes, the difference is whether the flip completed.)

**F2. Relog while on duty.** Clock on, quit properly, relog.
Expect: you come back a **civilian** (the roster entry was dropped by the
disconnect handler, `-DUTY- RELEASED … reason=disconnect`), and the duty kit was
flushed to the duty column before that happened.

**F3. Stale-entry reap.** Force the crash path: kill the client process (so
HandleDisconnect never fires), reconnect fast, and try to clock on.
Expect: the request **reaps** the stale entry and proceeds — `-DUTY- REAPED
stale-entry faction=… uid=… owner was N now M` — rather than refusing you
"already on a duty roster" forever.

**F4. Sweep picks up a genuinely gone player.** Kill a client while on duty and
leave it gone. Within 60 s: `-DUTY- RELEASED faction=… uid=… reason=sweep (gone)`
and the headcount drops.

**F5. Nak cannot be used as a free clock-off.** From the console of a
**confirmed, on-duty** officer:
`["nak", "maxsec", "test"] remoteExec ["APS_fnc_dutySRV", 2];`
Expect: **refused** — `-SEC- BLOCKED dutySRV nak: … confirmed=true …`, and you
stay on duty. An honest nak (an apply that genuinely failed to find its group)
should roll back cleanly with a **30 s** cooldown, not 600.

**F6. Server-internal modes are refused from the wire.** From a client console:
`["init"] remoteExec ["APS_fnc_dutySRV", 2];`
Expect: `-SEC- BLOCKED dutySRV server-internal mode init from owner N (uid …)`,
and **the roster is untouched** — check that everybody on duty stays on duty.
Repeat with `["sweep"]` and `["disconnect", "<someone else's uid>"]`, same form.

**F7. The unscheduled variant of F6 (this PR's A2).** Same three, sent with
`remoteExecCall` instead of `remoteExec`:
`["init"] remoteExecCall ["APS_fnc_dutySRV", 2];`
Expect: **identical** refusal, naming the same owner id. The respawn guard must
not launder the caller into "the server called me". If the roster is wiped by
this, stop the soak — that is a critical.
Then confirm the honest unscheduled path works too:
`["request", "maxsec", "patrol"] remoteExecCall ["APS_fnc_dutySRV", 2];`
→ should behave exactly like the terminal (grant, or a refusal naming YOUR
account), not error out in the RPT.

**F8. Gear restore failure is loud and non-destructive.** Hard to force
deliberately; if you ever see
`Gear restore failed -- RELOG to recover your civilian kit; it is safe in the database.`
then check that `civ_gear` in the DB is **unchanged** and a relog restores you.
The one thing that must never happen is a fresh default kit being written over
your real civilian row.

---

## G. Eyeball and policy calls — the owner decides

These are not pass/fail. They are things the code got right on its own terms and
that only you can rule on.

**G1. Does `med_spawn_1` read as "the hospital"?** The marker at `[7200, 7850]`
was derived from a heuristic because the `Kavala Hospital` layers are empty in
the sqm. Clearance is ~8 m so nobody spawns inside geometry, but the surroundings
read like a lobby/plaza (office chairs, memorial wreaths, a MapBoard) with the
Grand Palace / Night Club / Casino icons within 61 m. Stand on it and decide.

**G2. `respawn_west` moved to MaxSec HQ, and it is not only a spawn point.**
Roughly 15 runtime call sites across ~12 files read `getMarkerPos "respawn_west"`
as a 1000 m or 750 m safety ring — bank transfer, moonshine and glitter lab
placement, gun-game and battle-royale checks, the arrest action, bounty tracking,
civ repair, wire transfer, and the gear-save guard. All of those rings moved to
MaxSec HQ with the marker. Not individually audited. Specifically check the
`useItem` "safezone" behaviour near the cop HQ, which was never true near La
Trinite.

**G3. The La Trinite gear-save dead zone.** Separately from the rework: no
civilian within 1 km of the main town spawn has been persisting gear. It is a
live, severe, pre-existing bug and probably wants its own ticket ahead of any
public deploy.

**G4. The SGT+ reserved seat has no successor.** `cop_17` was a *seat* (a
guaranteed slot for senior staff), not a power. Roles replaced the power; nothing
replaced the seat. You may want a replacement mechanism.

**G5. Off-duty `AP_track_radius` is 300, not 1400.** Deliberate: 1400 off duty
would widen the civilian bounty-track scroll actions from 300 m to 1400 m. One
line to change if you disagree.

**G6. `fn_copLoadout` still gates undercover gear on `copLevel >= 6`** rather than
on the `all` role, because `all` is granted for `copLevel >= 6` **or**
`adminLevel >= 3` — flattening it re-opens the 2026-06-18 "SCD gear leaked to
cadets" bug for an admin at cadet rank. Reversible in one line.

**G7. Firefighter callout redeploy.** Six dead Altis marker rows were replaced
with four real Malden hospitals (La Trinite, La Port, Chapoi, La Pessagne).
`marker_94`'s own icon says "Chapoi Fire Station" but it stands 331 m from La
Pessagne PD and ~3 km from Chapoi; it is labelled La Pessagne deliberately. Test
a redeploy and see whether you agree.

**G8. Trauma medic drone battery.** The revive-drone battery gate moved from "is
independent" to `mediclevel >= 1`. Confirm a TT medic's battery **persists across
a relog** rather than coming back full — a silent full battery would make every
relog a free recharge.

**G9. Three orphan `CfgDebriefing` endings remain** (`SpyGlass`, `MemHackCash`,
`AFKdetected`). `MemHackCash` probably should stay as the re-arm marker. Tidy-up,
not a bug.

---

## H. The web sign-on screens (25 min)

H1-H12 are the landing screen (PR9). H13-H17 are the MaxSec duty terminal page
(PR11), which is the same machinery seen from the HQ tablet: both go
through `AP_fnc_dutyRequest`, so a bug in the correlation shows up in both.
H18-H26 are the **STATUS HUD** — the first web page in this mission that is not a
dialog, and the only one you can play the game underneath. **H18 is PROVEN as of
2026-08-20**: it drew in game on the owner's playtest, which is why the native HUD
has been retired and why H25/H26 (the satellite tiles and the icon name labels)
exist at all. **H31-H34 are the four things the owner called on b0697** — the sea
painting as sand, the panel not tracking him, the map spinning as he walked past
north, and the chat sitting on top of it — and they are at the end of this
section. Re-run H18 anyway on the first connect of each session — it is one
glance and it is the leg everything else stands on. H27-H30 are the **staff/admin
menu** — a native dialog, not a web page, and nothing to do with the faction
rework; it is parked at the end of this section because it is the same
owner-playtest pass.

The lobby welcome's PLAY gate is gone. Every connect now opens
`dialog\web_landing.hpp` (938100) — a full-screen welcome splash, then a
deployment picker: **SOLO** (civilian, the old behaviour), **MAXSEC**,
**TRAUMA TEAM**. Picking a faction sends the SAME `["request", faction, role]`
to `APS_fnc_dutySRV` that the HQ terminal sends, with the faction's default role
(`patrol` / `ttmedic`); role refinement still only happens at a terminal.

Keep the **client** RPT open for this section (path in the log-tag table above)
and grep `\[LANDING\]`. The server log shows only the `-DUTY-` rows.

**H1. It appears, and it is not deaf.** Connect. Expect the splash within a
couple of seconds of "Finishing Client Setup", `LOADING PLAYER DATA` already at
`100%`, and **PLAY lit** (it stays grey until the first push lands — a grey PLAY
means the page never received `landing`, which is the classic un-whitelisted-path
symptom). Client RPT: `[LANDING] open: display up, waiting on the player` then
`[LANDING] bridge ready`.

**H2. The footer is real, not the demo defaults.** Bottom bar should read your
build (`BETA 0.2.1  Armapunk2035_b0NNN.Malden`) and `N / 60 ONLINE` with the real
N. If it says `BUILD 2035.8.19` and `87 / 120 ONLINE` you are looking at the
page's built-in demo values and no push arrived.

**H3. The locks match your whitelist.** With `coplevel=0, adminlevel=0,
mediclevel=0`: MAXSEC and TRAUMA TEAM both greyed, footer `NOT WHITELISTED`,
clicking them does nothing. Raise `coplevel` to 6 and relog: MAXSEC unlocks,
TRAUMA stays locked. This is a client-side read of the same two tests
`APS_fnc_dutySRV` re-runs from the DB — a wrong lock here is a display bug, a
wrong **grant** is a security bug.

**H4. SOLO changes nothing.** Pick SOLO → DEPLOY. Expect the screen to close and
the login to land exactly where it used to: the spawn menu on a fresh/near-origin
position, or the straight relog teleport to where you logged out. Confirm the
teleport case specifically — log out somewhere distinctive, relog, pick SOLO, and
you should be back on that spot with no spawn menu at all.

**H5. Deploying to MaxSec from the landing.** `coplevel=6`. Pick MAXSEC → DEPLOY.
Expect: the button holds `DEPLOYING…` for a beat, the screen closes, you get
`You are on duty: MAXSEC (patrol).`, and then **the spawn menu opens with MaxSec
precincts in it, not civilian spawns**. Server log: `-DUTY- GRANTED faction=maxsec
role=patrol` then `CONFIRMED`. Client RPT: `[LANDING] deploy maxsec as patrol --
request sent` then `[LANDING] deploy maxsec granted`.
Repeat for Trauma (`mediclevel=1`, role `ttmedic`, TT helipads in the list).

**H6. A refusal has to SHOW ON THE PAGE.** The easiest to produce is the
cooldown: clock off at a terminal, relog inside 10 minutes, pick MAXSEC → DEPLOY.
It is also the refusal you will see the most without asking for it: reconnecting
while still ON duty — a crash, an alt-F4, an ordinary relog between soak
sections — stamps the identical full 600s cooldown as a clean terminal release
(`fn_dutySRV.sqf`'s `"disconnect"`/`"sweep"` cases both do this), so almost any
reconnect soon after a MaxSec/Trauma stretch lands on this exact refusal —
expected, not a bug.
Expect an amber line under the deploy bar reading
`YOU CAME OFF DUTY TOO RECENTLY. N SECONDS LEFT.` and **DEPLOY re-enabled** so you
can pick SOLO instead. A stuck `DEPLOYING…` is a failure even if the toast
appears. Same test with an outstanding bounty gives
`YOU HAVE AN OUTSTANDING BOUNTY. CLEAR IT FIRST.`
If the line reads `NO ANSWER FROM THE SERVER -- TRY AGAIN`, the request was
refused by one of the three paths that deliberately send no message, or it was
throttled — check the server log for the `-DUTY- REFUSED` row before calling it a
bug.

**H7. Esc must not strand you.** Press Esc on the picker. The dialog closes and
you should fall straight through to the ordinary flow — spawn menu or relog
teleport, as a civilian. You should NOT be left frozen on a black screen, and you
should NOT be able to re-open the landing. (This is the documented fallback, not
a defect: closing is equivalent to picking SOLO.)

**H8. The kill-switch.** From the server console:

```sqf
SRV_landingEnabled = false; publicVariable "SRV_landingEnabled";
```

Relog. Expect the **old lobby welcome** (the tablet screen with PLAY / RETURN TO
LOBBY and the rules tree), then the spawn menu — i.e. the world exactly as it was
before this PR. Client RPT: `[LANDING] open: SRV_landingEnabled is false`. Set it
back to `true` and relog to confirm the landing returns. Note this is a
**separate** switch from `AP_dutyEnabled`: with duty off but landing on you should
still get the splash, with both faction cards greyed and footer
`DUTY SYSTEM OFFLINE`.

**H9. A fresh account still gets the intake.** Make a fresh account
(`UPDATE players SET intake_path=0 WHERE playerid='$U';`) and connect. Expect the
**intake cinematic**, no landing screen at all, and `[LANDING] open: fresh account
on the intake path` in the client RPT. From that account's SECOND login onwards
the landing appears normally.

**H10. A jailed account goes straight to the cell.** With
`AP_is_arrested` loaded as jailed (serve a sentence, then relog), expect no
landing screen and the usual jail placement. Client RPT: `[LANDING] open: account
is serving a sentence`.

**H11. Two clients — the counter and two simultaneous deploys.** Both clients
connect at once. Each footer should show the same `N / 60 ONLINE`, counting the
other. Then both deploy to MaxSec in the same few seconds: expect **two** GRANTED
rows, `AP_dutyCopCount` at 2, and both spawn menus showing precincts. Neither
client's page may report the other's refusal — if client B ever shows a line that
belongs to client A's request, the refusal tap is correlating across sessions and
that is a real bug.

**H12. Two clients — the pre-spawn position guard.** This is the case the landing
introduced and the one worth the most attention. Client A logs out somewhere
distinctive as a **civilian**, then relogs and deploys to **MaxSec from the
landing** (never spawning as a civilian at all). Now:

```bash
DBQ "SELECT position FROM players WHERE playerid='$U';"
```

The saved civilian position must still be the **distinctive spot**, not
`[5826.91, 6873.62, …]` (the mission.sqm slot at 50 km) and not empty. Then have
A clock off at a MaxSec terminal: they must be left **standing where they are**,
not teleported into the sky. Client B is there to watch A during the clock-off,
because a 50 km yank looks like a disconnect from the inside.
Client RPT during the deploy should carry
`[LB-SPAWNHOLD] position save skipped: player is still held pre-spawn`.

This covers the mode-10 partial-save write only (`fn_ClupdatePartial.sqf`). A
second, separate writer of the same field exists: the full-save packet
`fn_ClupdateRequest.sqf` builds for every civilian client on a scheduled restart
or `!srv softr`/`!srv hardr` (server `init.sqf:447`/`:1287`, broadcast to every
online client), gated only by the same distance-from-respawn tests the 50 km
hold passes. That path now leaves the loaded `AP_ses_last_pos` untouched during
the hold — a skip, not an early exit, so the money/talents/exp halves of the
restart flush still land. Not exercised by A/B above: it only fires on a restart
broadcast, not an ordinary clock-off, so soaking it means landing on the screen
and triggering (or waiting out) a scheduled restart or a `!srv softr` from
another session.

**Note on the 120s rescue.** `initPlayerLocal.sqf`'s stuck-at-altitude failsafe
(pre-existing, not part of this PR) still applies while `AP_spawnHold` is true:
linger on the landing — or anywhere else in the pre-spawn hold — past 120
seconds and it teleports you to a real spawn point and logs
`[LB-SPAWNHOLD] rescue: held ...`. Bounded and harmless, but expect it if a
picker is left open that long during a soak session.

**H13. The terminal opens, and it is not deaf.** Off duty, whitelisted, walk to
a MaxSec tablet at Emergency Response HQ and use the scroll action. Expect the
five-row console: PATROL / WARRANT / MEDIC / STREET CRIME DIVISION / ALL, the
header reading `// EMERGENCY RESPONSE HQ` and `OFFICER <your name> · <RANK> (n)`.
Client RPT: `[DUTYTERM] open: display up and bound` then `[DUTYTERM] bridge
ready`. If the header says `// PRECINCT 01 — CENTRAL` and `V. KOVAC`, you are
looking at the designer's demo values and no push arrived.

**H14. The locks are your rank and your SCD flag.** At `coplevel=4`: PATROL
unlocked, WARRANT and MEDIC unlocked, ALL locked with `REQUIRES CAPTAIN (RANK 6)
— YOU ARE SERGEANT (4)`. SCD locked with `REQUIRES SCD WHITELIST` unless
`isscd=1`, in which case the header gains a `· SCD` badge and the row unlocks.
Drop to `coplevel=1` and relog: only PATROL (and SCD if flagged) is selectable.
A wrong lock is a display bug; a wrong **grant** is a security bug —
`APS_fnc_dutySRV` re-runs the same table from the DB.

**H15. Sign on, and the counts are real.** Arrow keys or `1`-`5` to select,
ENTER (or click the row) to arm, ENTER again to confirm. GO shows `REPORTING…`,
then a green `ON DUTY — PATROL` toast, then the screen closes on its own about a
second and a half later and you are west with the duty kit. The per-row `n ON
DUTY` numbers count players by their public `AP_unitCopRole`, so with a second
client on duty as WARRANT that row must read `1`. They are a **snapshot taken
when the screen opens** — deliberately, because the page treats any later push
as a fresh boot — so reopening is how you refresh them.

**H16. A refusal reaches the page, not just the chat.** Clock off, then
immediately reopen the terminal and try to sign on again: the 600 s cooldown
refusal must arrive as a **toast on the page** (uppercase, the server's own
wording), and GO must come back live. Same for signing on while wanted, or while
another client has just taken the last roster slot. A refusal that leaves GO
stuck on `REPORTING…` is the correlation bug this section exists to catch — the
page gives up at 20 s and the bridge at 15 s, so nothing should ever hang.

**The bounty refusal at the kiosk points somewhere.** Sign on wanted at the
tablet and the toast reads `YOU HAVE AN OUTSTANDING BOUNTY OF $N. CLEAR IT OR
PAY IT OFF. USE THIS TABLET'S SCROLL MENU.` — and the scroll menu, at that same
tablet, must now be offering **Pay Off Bounty (MaxSec)**. That pointer
is deliberate and is not a stopgap to be "fixed" by adding a button:
`duty_maxsec.html` is the designer's page and its refusal surface is a single
`toast(...)` call with no action in it, so the button does not exist to be
wired. Full reasoning in `AP_fnc_dutyTermBridge`'s comment at the refusal.
Take the scroll action and B15 runs from there, identically.

**H17. It is never a dead tablet, and clock-off is unchanged.** Esc closes the
screen with no side effects; the ✕ does the same. While ON duty, the same tablet
action must give you the **old** behaviour — an immediate clock-off request, no
web screen at all. And the fallback: with the page deliberately broken (rename
`ui\html\duty_maxsec.html` in a test PBO, or set the dialog's class name wrong),
using the tablet must fall through to the old `BIS_fnc_GUIMessage` role picker
with `[DUTYTERM] open: ... falling back to AP_fnc_dutyTerminal's picker` in the
client RPT — never a scroll action that does nothing.

### The STATUS HUD (H18-H26, H31-H34) — read this first

The owner's vitals HUD, rebuilt as an HTML page and hosted on an **RscTitles
layer** (`dialog\hudWeb.hpp`, class `AP_web_hud`, page `ui\html\hud.html`), cut
with `cutRsc` rather than opened with `createDialog`. That distinction is the
whole feature: a dialog is a focused display, so it would eat your mouse and your
movement keys the moment it appeared. A title layer is never focused, which is
what makes `AP_ToastBase`, `AP_AutoRadioMenu` and `AP_GpsHud` non-interactive and
what makes this one safe to leave up in a firefight.

**The native HUD is RETIRED.** It used to run alongside this one so H18 would be
an unambiguous yes/no; it was, so the old bottom-right cluster is gone. Nothing was
deleted to do it: every native drawing statement in `AP_fnc_hudUpdate` still exists,
inside one flag-gated block, and everything that function did that was NOT about
pixels — the `bounty_apb` / `bounty_dot_apb` cleanup, the four `profileNamespace`
writes, the web push — still runs on both paths. `AP_fnc_hudSetup` no longer cuts
`AP_playerHUD` at init, and the web keeper cuts layer 2 down if anything else does
(the Killed EH re-cuts it on every death). That last part matters: `AP_playerHUD`'s
class defaults are *visible*, so a layer that is cut and never drawn into shows a
heap of placeholder bars rather than nothing.

**Nothing here changed on the server and nothing here has a CfgRE entry.** The HUD
is display-only: every value it draws is read locally on the client that draws it.

`AP_webHudEnabled` is the switch, default **true**, read through a getVariable
default so it needs no server publish. Flip it live from the debug console:

```sqf
AP_webHudEnabled = false;   // layer down within a second, native HUD only
AP_webHudEnabled = true;    // back up within a second
```

Keep the **client** RPT open and grep `\[HUDWEB\]`.

**H18. IT DRAWS — PROVEN 2026-08-20.** Connect and spawn. Within a second or two
of the world appearing, a stack of angular plates must be visible in the
bottom-right: **HP**, **H2O**, **FOOD**, each with a glyph tile, ten segments and
a number. There are no native bars underneath them any more. Client RPT:
`[HUDWEB] keeper up on layer N` then `[HUDWEB] layer up and bridged, ctrl 938301`.

**This was the one unproven leg in the whole feature and it is now closed.** A
`type = 106` browser control composites *visible pixels* inside an `RscTitles`
layer. Nothing shipped in this mission had exercised that: `AP_map_warm` proves a
browser control RUNS in a title layer but is a 0.02 x 0.02 speck that draws nothing
on purpose, and `AP_web_visor` proves a transparent full-screen browser control
renders over the live world but does it in a *dialog*. The owner's playtest closed
the gap, and the retirement of the native HUD is what that finding bought.

If a future change ever brings back both log lines with **nothing on screen**, that
is this same leg failing: the bridge came up (so `A3API` bound and the page ran) but
the control painted no pixels. **Stop and say so** — the wiring is sound and the
host is wrong, and the fix is a different host, not a fix to any of these files.
The escape hatch in the meantime is `AP_webHudEnabled = false`, which is a whole
native HUD, not a degraded one.

Nothing on screen **and** no `[HUDWEB]` lines is a different, much duller bug —
the layer never got cut. Check `AP_webHudEnabled`.

**H19. It is transparent, and the world is behind it.** Stand somewhere with
something busy behind the bottom-right corner — a lit street, a vehicle, moving
NPCs. The plates have their own dark translucent fill, but between and around
them you must see the **world**, moving. A black rectangle over the whole screen,
or a black box around the plates, means the transparency chain broke, and it has
exactly three links: the page's own `html,body{background:transparent}`, the shim
adding no background of its own, and the control's `colorBackground[] =
{0,0,0,0}` in `dialog\hudWeb.hpp`. Any one of them going opaque does this.

**H20. It does not take input. Play with it up.** With the HUD on screen and no
dialog open: walk, sprint, turn, aim down sights, fire, drive, open the map, open
inventory, use a scroll action, open the phone with CTRL+Y. Every one must behave
exactly as it does with `AP_webHudEnabled = false`. Specifically: **the mouse must
still turn the camera** over the corner the HUD occupies, **Esc must open the game
menu** rather than close anything, and clicking on the plates must do nothing at
all. Anything else means the layer is taking focus, which it must never do — that
would be the reason this is not a dialog, defeated.

**H21. It tracks, on the same events the native HUD tracks.** Watch the plates and
the native bars together; they must move as one, because they are the same numbers
from the same variables one screen layer apart.

| do this | expect |
|---|---|
| take damage (fall, get shot) | HP segments drop, number drops, and **at 20 or below the plate turns red and breathes** |
| drink | H2O climbs back to 100 |
| eat | FOOD climbs back to 100 |
| gain a bounty as a civilian | the magenta **WANTED** plate appears at the bottom, the stack slides up to make room, the dollar figure matches the native `WANTED $n` line, and the chevrons fill at 50k / 100k / 250k / 500k / 1M |
| clear the bounty | the WANTED plate disappears and the stack slides back down |
| clock on to MaxSec or Trauma | WANTED goes away and stays away for the whole shift, same as the native bar |

A plate that never moves while the native bar next to it does means the push is
not arriving; a plate that moves but disagrees with the native number means the
two are reading different variables, which they must not be.

**H22. The two chips are honest.** Above the stack, on the right:

- **▮▮ METERS PAUSED** (amber) must appear whenever hunger and thirst have
  genuinely stopped draining — i.e. while the spawn-select map (38500) is open,
  and while you are **restrained**. Get cuffed by a second client and watch it
  light. Those are the exact two conditions `fn_survival` gates its drain ticks
  on, so a chip that is lit while the meters are falling is a real bug.
- **REGEN+** (cyan) must appear while health is actually regenerating: H2O and
  FOOD both **at or above 75**, damage above 0 but at or below 0.25, legs under
  half hurt, not downed, not in the revive window. Take light damage on a full
  stomach and watch it light, then watch HP tick up while it is lit. It reads
  `AP_regenActive`, which `fn_survival`'s own regen tick now publishes from the
  one evaluation it was already doing, so the chip cannot drift from the effect.

Both chips ride the same 4 Hz change-gated tick as the minimap, as well as every
native HUD refresh, so they appear or clear within about a quarter of a second.

**H23. Death, respawn and the toggle.** Die. The HUD must disappear together with
the native one (both key off `AP_isDead`) — a frozen stack of a dead player's
vitals sitting over the death camera is a bug. Respawn: it must come back on its
own within about a second, with correct values, **without a relog**. RPT shows
`[HUDWEB] layer down` then a fresh `[HUDWEB] layer up and bridged`. There is no
respawn hook anywhere in this feature; a 1 Hz keeper notices and re-cuts, which is
also what covers the layer being lost to anything else.

Then, from the debug console, `AP_webHudEnabled = false;` — within a second the
plates vanish, `[HUDWEB] layer down` appears, and **the whole old native HUD comes
back on its own**: the segmented HP / H2O / FOOD bars bottom-right, the WANTED bar
under them for a civilian with a bounty, the centre status strip, the cop APB line
at the top. RPT: `[HUDWEB] toggle off -- native HUD restored`. Set it back to
`true` and within a second the plates return and the RPT says `[HUDWEB] native HUD
layer cut down -- the web HUD is the HUD`. **Both directions must work without a
relog** — that flag is the entire rollback for the retirement, so if the old HUD
does not come back, say so and stop.

Do this at least once with a web dialog already open (the phone on CTRL+Y):
re-cutting the layer must not break the open page, because the HUD hands back the
shared `WEBUI_ctrl` slot it borrows during its own bridge init.

One thing that is *not* a bug: die with the HUD on and, for up to a second, a small
cluster of misplaced bars may appear on the death screen. The Killed EH re-cuts
`AP_playerHUD` on every death and the keeper cuts it back down on its next 1 Hz
tick. Before this change those bars sat there for the *whole* death screen, so this
is strictly less of them, not more.

**H24. The minimap is honest, and it is honest about what it does not know.**
The page gained a minimap in a revision part-way through this work; it rides the
same single `hud` push as an optional `map` member. Bottom-**left**, same plate
family: a GPS bearing strip over a square panel.

| watch | expect |
|---|---|
| turn on the spot | the bearing number and its cardinal letter track your heading continuously (pushed at 4 Hz), and the red **N** marker counter-rotates so it always points at real north |
| walk in a straight line | the 100 m grid slides under you and the range rings stay centred on the ▲ |
| the strip's right-hand label | `500M` — the zoom is a constant, because the page has no verb to change it and this shim gives it no way to call SQF |
| group members | a cyan dot each, moving as they move; someone beyond the panel edge clamps to the rim and dims |
| a custom waypoint (set one on the M map) | a `◆` at its position, matching the 3D waypoint marker `AP_fnc_mapWpHud` already draws |
| the four hospitals | a red `+` at each of `med_spawn_1..4` — Main Hospital [7409, 8108], La Port [7971, 3262], Chapoi [6080, 3593], La Pessagne [3057, 6175] — drawn in place inside **227 m** and clamped to the rim beyond it (the mark clamp is 5.9 rem against 0.026 rem/m; the panel's imagery reaches 375 m, which is what the old "375 m" in this row was measuring) |

Client RPT at first push: `[HUDWEB] static marks resolved: 4 of 4 med sites`. **A count
below 4 means a `med_spawn_*` marker was renamed or removed** — the resolver drops
anything that resolves to the map origin rather than drawing a hospital in the sea,
which is the exact trap the three sibling copies of that name list are commented
about. Fewer pins is the safe failure; a pin in the water would be the bug.

**H25. Real map imagery, and it is the game's own.** The panel shipped tile-less;
it is not any more, and no bake was made for it. The imagery the owner asked for —
"the 3d map from the main map" — is not generated by the 3D map at all: the 3D map
*reads* it out of the game's PBOs, `a3\map_malden\data\layers\s_<col>_<row>_lco.paa`,
a 13 x 13 grid (`map.html:673-675`). The minimap is pointed straight at the same
files, and `AP_map_warm` already pre-converts all 169 of them at every connect, so
on a warmed client this is a cache hit.

| watch | expect |
|---|---|
| the panel, standing still | actual Malden terrain under the grid, rings and blips — coastline, fields, the shape of the town you are in |
| walk in a straight line | the imagery slides with the grid, at the same rate, with **no drift between the two** |
| turn on the spot | the imagery rotates with the panel and the ▲ stays over the same piece of ground |
| stand on a hospital pin | the pin is on the hospital *in the imagery*, not near it |
| the sea | dark water, in the right places — the fastest way to spot a mirrored or flipped island. **This row was aspirational until PR15 and is the reason H31 exists:** the layer these tiles come from has no sea in it at all, so until PR15 the ocean painted *sand* |

**Two failures to watch for specifically, because both look plausible at a glance.**
An island that is *upside down* (or blips that drift steadily north as you walk
south) means the row flip is wrong — the game's layer rows count from the NORTH
edge while the page's count from the south. Imagery that is right but sits slightly
**small**, so the seams between tiles creep away from the blips the further you are
from the panel centre, means the 16 px per-edge overlap is not being accounted for;
one image covers 1050.3 m, not the 984.6 m tile step.

A missed tile is never a broken-image icon, and cannot be: `RequestTexture` resolves
a lookup failure with a short stub instead of rejecting (a documented engine defect),
and the page guards on that stub the same way `webui.js`'s own `texture()` already
does — nothing is assigned to `img.src` below a length floor. What a miss actually
looks like is an **unpainted tile**: a gap in the mosaic showing the dark map
background behind it, nothing more. What you must NOT see is the demo's green
procedural checkerboard (the bridge shim failed and the page fell into its demo
branch — which also paints an opaque backdrop over the whole screen, so H19 would
have failed first).

Client RPT at first push:
`[HUDWEB] tiles: a3\map_malden\data\layers\s_<col>_<row>_lco.paa, 13x13, worldSize 12800, tileMeters 984.6`.

Every field is a plain mission variable, so the console overrides any of them live,
and **`AP_hudWebTileBase = ""` is the off switch** back to the marks-only panel:

```sqf
AP_hudWebTileBase = "";     // tiles off, panel returns to grid + rings + blips
AP_hudWebTileRes  = 512;    // sharper, at the cost of a conversion warm.html did not prepay
AP_hudWebTileOv   = 0;      // disable the overlap correction -- imagery goes ~6.7% small
```

They are world-gated: a world other than Malden has no known layer path, emits no
`tiles` member at all, and degrades to exactly the marks-only panel rather than to
a pool of images that can never load.

**H26. Icon name labels, inside 500 m.** Each minimap icon that has a name draws it
just below itself, small and dim, once you are within **500 m** of it.

| watch | expect |
|---|---|
| walk toward a hospital | at 500 m a label appears under the red `+` — `Main Hospital`, `La Port`, `Chapoi` or `La Pessagne` |
| walk away from it | the label goes at 500 m; the pin stays |
| a group member near you | their name under the cyan dot, following them |
| a group member past the panel edge but under 500 m | the dot clamps to the rim and dims, and **the label clamps and dims with it** |
| turn on the spot | every label stays upright and stays directly UNDER its icon, whichever way you face |
| your own custom waypoint (`◆`) | **no label** — it has no name to draw, deliberately |

A label that reads `Garage` on a hospital would mean someone switched the source to
`markerText`: all four `med_spawn_*` markers are captioned "Garage", because the
caption names the vehicle garage at the site, not the site. The names come from the
site list in `fn_spawnPointCfg`'s independent case instead.

Kinds with no name source draw no label and render exactly as they did before. The
500 m test happens in the page, off the distance it already computes for the rim
clamp, so it costs nothing extra per push.

**The other marker kinds draw nothing, and that is a finding rather than a
shortcut: this mission has no POI system.** Two independent sweeps of `mission/`
and `server/` found no `AP_hospitals`, `AP_atmLocations`, `AP_fuelStations`,
`AP_garages` or `AP_shops` — no `AP_*_positions` family exists at all, and
`fn_mapOpen.sqf` sends the map page no POI list either. Per kind:

| kind | why it draws nothing |
|---|---|
| `gas` | no source whatsoever — zero markers with gas/fuel text, one NPC, and `nearestTerrainObjects [..., ["FUELSTATION"], ...]` is never called anywhere in this repo |
| `garage` | six markers carry the text `Garage`, but **four of them are `med_spawn_1..4`** — the text names the vehicle garage *at* the site, not the site. Feeding it would print a garage pin on every hospital |
| `atm` | one marker on the whole map against ten placed ATM objects — and `fn_setupActions`' own ATM gate names Altis classes that do not exist on Malden, so the question has no correct in-game answer today either |
| `shop` | `fn_virt_shops` has the type catalogue with no positions; `edenNPC_data.sqf` has 61 positioned NPCs but is **generated tooling input, never loaded at runtime** |
| `gang` | `AP_gangMembersList` rows are `[uid, name, rank]` with **no position**, behind a 10 s rate-limited server round-trip. Group blips are free because the engine syncs group members; gang blips simply are not available |
| `quest` `enemy` `veh` | not asked for, no source |

A HUD that shows a hospital where there is none is worse than one that shows no
hospitals, so each of these draws nothing rather than something invented. Feeding
them properly means authoring a POI table first — a piece of work of its own.

### The minimap, after the owner's b0697 pass (H31-H34)

Four things the owner called on b0697. All four are page-side or push-side; none
of them changed what a tile is or where it goes.

**H31. The sea is water, not sand.** The owner's words were "minimap needs to
show water instead of sand", and they were exactly right in a way the triage
was not: **the tile mapping was never wrong.** `a3\map_malden\data\layers\s_*_lco.paa`
is the *satellite* layer and Arma composites the water surface at draw time, so
the layer paints the **seabed** — which on Malden is sand. Draw the layer raw and
every square metre of ocean is sand-coloured. `map.html` never had the problem
because it does not draw the layer raw either: it draws its own water pass over
it (`map.html:334` `buildWater` / `:257` `watP`).

So the panel now masks the sea from `ui\html\malden_hf.txt` — the same
heightfield `map.html` already fetches (`map.html:1392`), through the same
`A3API.RequestFile` leg the page's own shim uses for `webui.js`. No bake, no new
asset, no server call.

| watch | expect |
|---|---|
| stand on any coast | the water is **dark teal**, the land is not, and the line between them follows the coastline in the imagery |
| a beach | still sandy. Malden's beaches are real land above sea level and must NOT be painted over — a beach that goes blue means the shore threshold is wrong, not right |
| walk from land into the sea | the colour changes as you cross, not tens of metres early or late |
| stand in the middle of the island | no water anywhere on the panel |
| the coast edge, closely | a soft ~1-cell gradient rather than a hard line. **Deliberate:** the heightfield is sampled at 64 m, so its coastline disagrees with the satellite's by a few tens of metres; alpha ramps with depth so the disagreement reads as shallows instead of blue spilling onto a visible beach |

`AP_hudWebTileHf = ""` turns the water layer off and returns the panel to exactly
what PR14 shipped. It is self-invalidating the same way the hospital pins are: a
heightfield whose extent does not match `worldSize` is another world's file and is
**refused**, so the failure is "no water" and never "sea over dry land".

**H32. It tracks you.** pos and dir now ride their own channel, `"hudmap"`, at
8 Hz on top of the unchanged 4 Hz full payload — **12 position updates a second
against the 4 the panel used to get.**

| watch | expect |
|---|---|
| sprint in a straight line | the imagery, the 100 m grid, the rings and the blips all move **together**, every frame, with no layer lagging another |
| turn on the spot at any speed | the panel turns with you, not behind you |
| stand perfectly still | nothing repaints and nothing is sent — the change gate still holds on **both** channels |
| the vitals stack while you run | unchanged. Vitals are still change-driven; only the map got the new rate |

**Nothing on the panel eases any more, and that is the fix, not a regression.**
The page used to put a `.2s` transition on `#mrot` and on the grid's
background-position but could not put one on the blips (they are rebuilt through
`innerHTML` every render, and a brand-new element has no previous style to ease
*from*). So the grid glided while the tiles and blips stepped — which is the
"not 1 to 1" report. Worse, an ease *is* a lag: `.2s` against an 83 ms push
leaves the layer permanently ~2.4 pushes behind you. If you see one layer sliding
smoothly while another steps, a transition has been put back.

**H33. Walking past north does not spin the map.** The push sends a 0-359
bearing, so crossing north used to be a 359 → 1 step and `rotate()` took it
literally: a **358° spin the long way round**, every single time.

| watch | expect |
|---|---|
| walk a slow circle through north, both ways | the panel rotates smoothly through it. **No spin, no snap, no flick** |
| the `N` marker, the blips and the name labels while you cross north | they stay upright and stay put — they are counter-rotated off the *same* accumulated angle, so they cannot be a wrap apart from the map |
| the `GPS` read-out | still counts `359° → 0° → 1°`. That is a compass and is correct; only the transform is unwrapped |

Worked example, read straight off `#mrot` in the page: heading `350 → 10` adds
`((10 - 350 + 540) mod 360) - 180 = +20`, so the accumulator goes `350 → 370` and
the map turns **twenty degrees clockwise, not three hundred and forty
anti-clockwise**. Going back, `10 → 350` is `-20`.

**H34. The chat does not sit on top of the minimap.** The panel was
bottom-left; so is the engine's in-mission chat. `RscChatListMission` is anchored
`y = safezoneY + safezoneH - 10.5 * GUI_GRID_H` with `rows = 6.25`, and
`GUI_GRID_H` is `0.04` at every aspect ratio ≥ 1.2 — so the chat owns the band
from **22% to 42% of the screen height above the bottom edge** and grows into it as
messages arrive. The panel reached 27.3% and sat straight under it. It is anchored
to the **top** of the safezone now (`#mapwrap { left: 2rem; top: 2rem }`), where it
occupies 3.2vh–31.3vh from the top.

| watch | expect |
|---|---|
| fill the chat — six or more lines, side and global | **not one line touches the panel.** The chat stays in the bottom-left; the map is in the top-left |
| the vitals stack and the chips | unchanged, bottom-right. The move reflowed nothing |
| pull the UI vertical bounds slider in and reconnect | still clear. The clearance is 27 points at `safezoneH = 1` and still 16 at `safezoneH = 0.8` |
| a 4:3 or an ultrawide client | still clear — `GUI_GRID_H` is `0.04` at any aspect ≥ 1.2, and the panel is sized in `vh` through `clamp(11px, 1.6vh, 20px)` |

If a player has dragged the chat in the game's own UI layout editor, it is on
`IGUI_GRID_CHAT_Y` and can be anywhere; that is their choice and no page-side
number can follow it.


### The staff/admin menu (H27-H30) — scroll and legibility

Not part of the faction rework; parked here because it is the same
owner-playtest pass. The staff menu is `idd 12900` (`dialog\admin_menu.hpp`),
five tabs across one dialog: ACTIONS, EVENT TOOLS, WEAPONS AND GEAR, VEHICLES,
CLOTHING. Owner report 2026-08-19: *"the scroll is glitchy it resets on scroll
sometimes you have to drag the bar scroll wheel doesnt work and gear/gun
spawning is squished cant be read and the scroll issue is all throughout it."*

Two config faults were found and fixed; both are eyeball-only, so nothing below
can be proven from the repo.

- Each tab panel was an `AP_RscControlsGroup` — a controls group **with**
  scrollbars (`VScrollbar width = 0.021`, `HScrollbar height = 0.028`). A
  scrollable group is a mouse-wheel consumer over its whole area, so the
  listboxes nested inside it never saw the wheel, and the group's own tiny
  scroll range gave the snap-back. Every panel's content already fits inside its
  own rect, so all five are now `AP_RscControlsGroupNoScrollbars` — the same
  class the weapon shop, exchange, loadouts and stats screens use for exactly
  this arrangement.
- Every listbox in the menu overrode `sizeEx` (0.035 / 0.04) while inheriting
  `rowHeight = 0.04` from `AP_RscListBox`, i.e. rows only 1.0-1.1x the height of
  the text in them. Both values now come off the same safezone expression at the
  BI-canonical `rowHeight = 1.75 * sizeEx`, so the ratio holds at every
  resolution and UI scale.

**H27. The wheel scrolls every list.** Open the menu (level 3+ for the gear
tabs). On EACH of the five tabs, put the cursor **over the list itself** and roll
the wheel both ways: the player list (left, all tabs but VEHICLES), the weapon
list and the mags/attachments list on WEAPONS AND GEAR, the vehicle list on
VEHICLES, the clothing list on CLOTHING. Each must scroll under the wheel alone.
Dragging the list's own scrollbar must still work as well — that was never
broken, and if it is the ONLY thing that works the fix did not land.
**Nothing on any tab may move as a block** when you roll the wheel: the panel
itself no longer scrolls, so buttons and labels around the list must stay put.

**H28. Scroll position survives a selection.** On WEAPONS AND GEAR, scroll the
weapon list a long way down (past the visible page several times), then click a
row. The list must stay where you left it with the row selected — it must not
jump back to the top, and the panel behind it must not shift. Repeat on
CLOTHING, and on the player list on ACTIONS. Then scroll the mags/attachments
list and click a row there.
One reset is CORRECT and expected: picking a **different weapon** rebuilds the
mags/attachments list from scratch, so *that* list returns to the top. The weapon
list must not.

**H29. The gear and clothing lists are readable.** WEAPONS AND GEAR: rows must
have visible space between them, no glyphs clipped top or bottom, no row
crowding into the one under it, and the weapon icon must not crush the name.
Roughly 12 rows fit the weapon list now where about 17 were crammed in before —
fewer rows on purpose. Same check on the CLOTHING list, the VEHICLES list and the
player list. The three search boxes (weapon, clothing, vehicle) must show their
text un-clipped — those were 0.035-tall text in 0.03-tall boxes.
The WEAPONS AND GEAR search label now reads just **SEARCH ANY WEAPON**; it used
to run under the COMPATIBLE MAGS + ATTACHMENTS heading next to it.

**H30. Nothing fell off a panel, and the vehicle search works.** With no
scrollbars there is nothing to scroll a panel back with, so anything positioned
past a panel's width or height is clipped and unreachable. Walk all five tabs at
your normal resolution and again at a different UI Size (Options > Game > UI
Size): every button, label and readout must be fully on screen inside its panel.
Owner only: check the OWNER TOOLS block on EVENT TOOLS, including the relocated
purple **START EVENT** button.
Then, on VEHICLES: type into the search box and confirm the list filters. Select
a player on ACTIONS first (which fills the query readout), come back to VEHICLES
and type again — the list must still filter. That path was broken: the vehicle
search box carried `idc = 12944`, a **duplicate** of the ACTIONS-tab query
readout `queryTxt1`, so `displayCtrl 12944` handed back the readout and the
filter was read from the player dossier text. The search box is `12947` now.

---

---

## I. What this script does NOT cover

Recorded so nobody mistakes a green run for full coverage.

- **The clock-off flush routes on the client's claimed side.** `release` deletes
  the roster entry *before* the client's mode-3/4 packets arrive, so those last
  two saves are client-trusted in an otherwise server-routed path. C3 checks they
  land correctly for an honest client; it cannot check a dishonest one.
- **SCD clock-off gear persistence** has a separate pre-existing defect in the
  mode-17 route. Real SCD officers are affected; deliberately not put in the
  entry gate, because that would strand them on duty.
- **`AP_cop_talents` is empty for a duty cop who never had a cop character**, so
  `AP_track_radius` falls to its 1400 default and other cop-talent reads are
  inert.
- **Mixed transition states** (flag on, old west slots still present) are not
  tested and must not be deployed — see section 0.
- **Nothing here is a load test.** Two clients is enough to find correctness
  bugs and nowhere near enough to find contention on the serialized extDB3 mutex.

---

## J. Provenance — where each chain finding ended up

So a reviewer can check this script for completeness rather than take it on
trust. Labels are the ones the chain's own PR reports used.

| source | finding | case |
|---|---|---|
| PR4 C-1 | origin gate on `AP_fnc_dutyClient` | D7, D8 |
| PR4 C-2 | cooldown refusal must not also grant (PHANTOM-ELSE) | B9 |
| PR4 C-3 | `nak` cannot self-deroster | F5 |
| PR4 C-4 | gear unpack — the kit-loss bug | B2 |
| PR4 I-A | state gates run on clock-OFF too | B13 |
| PR4 I-B | stale-entry reap on relog | F3 |
| PR4 I-C | a server remove is never dropped | F1 |
| PR4 I-D | request throttle, silent | B10 |
| PR4 I-E | `dutyFlushBlock` predicate | B13 |
| PR4 I-F | immediate `civ_gear` re-persist on clock-off | C5 |
| PR4 I-G | group-vs-roster sweep, self-joiner ejection | D9 |
| PR4 IMP-1 | forged call is silent with the flag off | E4 (**contract changed here**) |
| PR4 IMP-2 | corrupted stash must not overwrite `civ_gear` | F8 |
| PR4 MIN-1/4 | nak after the side moved; 30 s nak cooldown | F5 |
| PR4 MIN-6 | invisible backpack survives a swap | B11 |
| PR4 §9.1 / PR6 §6 | paycheck matrix (`playerSide` was frozen at lobby side) | B5 |
| PR4 §9.4 | flag-off strand | §E |
| PR4 §9.5 / PR6 §10.3 | `med_spawn_*` placement | G1 |
| PR4 §9.7 / PR6 §10.5 | tenure ledger re-keyed onto the roster | D10 |
| PR4 §9.8 | needs two clients | §D |
| PR4 fix §7.1 | `AP_cop_talents` empty for a duty cop | §I |
| PR4 fix §7.3 | SCD clock-off gear persistence | §I |
| PR4 fix §7.4 | on-duty gear never periodically persisted | C2 |
| PR4 fix, track radius | off-duty `AP_track_radius` is 300 not 1400 | G5 |
| PR4 6.2 | DONG action scanner vs the terminal actions | B12 |
| PR4 6.3 | `AP_nonlethal` must clear on clock-off | D6 |
| PR4 6.4 | marker handlers mutually exclusive | D5 |
| PR5 (a) | mode-3 gear save lands `cop_gear` | C2 |
| PR5 (b) | garage query and the purchase cap agree | C7 |
| PR5 (c) | off-duty civilian save byte-identical | C1, E5 |
| PR5 (d) | pre-flip gates — superseded by the flip | §I (mixed states) |
| PR5 (e) | rostered disconnect clears the roster after the flush | F2, C6 |
| PR5 F-1 | engine-confirm when a client withholds its ack | B1 |
| PR5 F-2 | an on-duty mode-10 position write is dropped | C6 |
| PR5 F-3 | vehicle buy persists `side='cop'` | C7 |
| PR5 res.1 | ~20 `remoteExec` sites still target the side `west` | D9 (residual) |
| PR5 res.3 | clock-off flush routes on the claimed side | §I |
| PR5 res.5 | `fn_updatePartial`'s client-supplied uid | D11 (**fixed here**) |
| PR6 §7 / fix / fix2 | `respawn_west` moved, ~15 safety rings moved with it | G2 |
| PR6 fix3 | `AP_dutyFlushBypass` scope and self-heal | C8 |
| PR6 §10.2 | La Trinite gear-save dead zone | G3 |
| PR6 §10.4 | sqm validated by parser only, boot owed | §A |
| PR6 6.5/6.6 | firefighter redeploy, medic spawn rows | G7 |
| PR6 6.7 | death must not clock you off | D2 |
| PR7 boot list | roles 60, `read from bank`, clean RPT, terminals, one round trip | A1–A4, B1 |
| PR7 4B.1 | `fn_copLoadout` gate deviation | G6 |
| PR7 4B.2 | revive-drone battery gate | G8 |
| PR7 4B.3 | orphan `CfgDebriefing` endings | G9 |
| PR7 4B.4 | `maxPlayers` 150 vs 60 slots | A1 (**fixed here**) |
| PR7 D5 | the deploy invariant | §0 |
| PR7-fix CRITICAL | the `maxsec` entry gate a comment rewrite deleted | B7 |
| PR7-fix IMP-1 | death-screen TT counters re-homed | D3, D4 |
| PR7 6.9 | the SGT+ reserved seat has no successor | G4 |
| PR7 6.10 | Trauma entry tightened, volunteer tier closed | B8 |
| PR8 A1 | cross-account save refused | D11 |
| PR8 A2 | unscheduled dispatch keeps its caller | F7 |
| PR8 B | kill-switch drains instead of stranding | §E |
| PR9 landing | the screen itself, contract and locks | H1–H3 |
| PR9 landing | solo keeps the pre-PR9 flow | H4 |
| PR9 landing | deploy rides the existing dutySRV request | H5 |
| PR9 landing | async refusal correlated back to the page | H6, H11 |
| PR9 landing | Esc falls through instead of stranding | H7 |
| PR9 landing | `SRV_landingEnabled` kill-switch | H8 |
| PR9 landing | intake and jail keep their own flows | H9, H10 |
| PR9 landing | pre-spawn position + stash guards | H12 |


## Quick reference

**Roster row:** `AP_dutyRoster` is uid → `[faction, role, startTime, startPos, confirmed, ownerId]`.
Slot 4 (`confirmed`) is the ack flag every save-routing site waits on; slot 5 is
the network owner id that tells a reconnect apart from a duplicate request.

**Server globals:** `AP_dutyEnabled` (server reads its `localNamespace` copy), `AP_dutyRoster` (`localNamespace` only), `AP_dutyCooldown`,
`AP_dutyReqStamp`, `AP_dutyCopCount`, `AP_dutyMedCount`, `AP_dutyGroupCop`/`Med`,
`AP_dutyGroupCopNet`/`MedNet`, `SRV_dutyCooldown = 600`, `SRV_dutyNakCooldown = 30`,
`AP_tenuredCopCount`.

**Client globals:** `AP_onDuty`, `AP_dutyFaction`, `AP_copRole`, `AP_effSide`,
`AP_dutyStash`, `AP_dutySwapGuard`/`At`, `AP_dutyFlushBypass`/`At`,
`AP_dutyPaycheck`, `AP_track_radius`, `AP_nonlethal`, `AP_unitCopRole`,
`AP_dutyMedMarkersReg`, `AP_gear`.

**Landing globals:** server `SRV_landingEnabled` (publicVariable'd, default
true); client `AP_landingPick` (""/solo/maxsec/trauma), `AP_landingWait` (the
faction of a request in flight — this is what arms the refusal tap in
`fn_handleMessage`), `AP_landingWaitAt` (its self-heal stamp), `AP_landingErr`
(the captured refusal text). `AP_quitWelcomeUI` is still the tree's "past the
welcome screen" signal and the landing sets it when it takes over.

**DB:** `players` (`civ_gear`/`cop_gear`/`med_gear`, `civ_talents`/`cop_talents`/
`med_talents`, `civ_exp`/`cop_exp`/`med_exp`, `position`, `isscd`),
`players_global` (`coplevel`, `adminlevel`, `mediclevel`), `vehicles.side`
(`'civ'`/`'cop'`/`'med'`), `log` (the `-DUTY-`/`-SEC-` sink).

**`-DUTY-` messages:** `GRANTED` · `CONFIRMED` (± `reason=engine-confirmed (no ack)`) ·
`OFF CONFIRMED` · `RELEASED` (`reason=released` / `disconnect` / `sweep (gone)` /
`kill-switch drain`) · `ROLLBACK` (`no ack within 10s` / `nak-abort`) ·
`REFUSED` · `REAPED stale-entry` · `ROUTE MISMATCH`.

**`-SEC-` messages:** `BLOCKED dutySRV server-internal mode …` ·
`BLOCKED dutySRV nak: …` · `BLOCKED cross-account partial-save …` ·
`BLOCKED cross-account full-save …` · `EJECTED from duty group …`.

**`[AP-DUTY]` (RPT only):** `init: …` · `BLOCKED dutyClient: sender owner N is not
the server` · `BLOCKED dutyClient: unscheduled delivery` · `request throttled: …` ·
`kill-switch: roster drained, N entries removed` · `kill-switch on|off by bot_commands #N` · `remove (…): no usable civilian
stash -- NOT falling back to civLoadout` · `swap guard self-cleared` ·
`flush bypass self-cleared`.

**`[LANDING]` (CLIENT RPT only):** `open: unscheduled caller` · `open:
SRV_landingEnabled is false` · `open: fresh account on the intake path` · `open:
account is serving a sentence` · `open: createDialog AP_web_landing failed` ·
`open: display 938100 never appeared in 5s` · `open: display up, waiting on the
player` · `bridge ready` · `deploy solo` · `deploy <f> as <role> -- request sent`
· `deploy <f> granted` · `deploy <f> refused: …` · `deploy <f> refused locally: …`
· `deploy wait self-cleared`.
