# Jewelry Emporium — redesign 2026-07-29

Owner brief from an in-game test of b0130. Three bugs, one new stage, and a change of tooling across
the whole heist. Supersedes the flow in `maldenjewelry.md`; everything not mentioned here still
stands.

Four design questions were put to the owner and answered; those answers are recorded inline and are
not open.

---

## 1. Three unlocked ways in

The emporium's perimeter has three more openings, none of which anything in the build has ever
touched. All three are currently openable by hand, so the drill gate is not the only way in and the
heist can be walked past.

| # | Owner's position | What is there |
|---|---|---|
| A | `[7537.35, 10557.0, 0.66]` | between two `Land_BackAlley_01_l_1m_F` fence panels — a back-alley gate |
| B | `[7504.37, 10580.2, 0.13]` | beside a `Land_ConcreteWall_01_l_8m_F` run — a concrete perimeter gate |
| C | `[7551.46, 10607.5, 0.08]` | by a `Land_Canal_WallSmall_10m_F` and stairs |

All three must be **sealed at boot** and opened only by a **sequence hack**, the same way the Fed's
perimeter gate works. The Fed already solves this exact problem for the same classes — see
`APS_fnc_maldenFedSRV` case `"boot"` (which now resolves a LIST of gates, `AP_fedGates`) and
`APS_fnc_fedLockdown`. Reuse that shape rather than inventing one.

**These are `mission.sqm` objects**, like the existing drill gate, so they resolve by proximity at
boot. Log each one at boot with class, position and distance from its anchor, the way the Fed does.

---

## 2. Everything is a hack now — the torch and crowbar go

The heist currently needs a **Crowbar** ($500) to smash cases and a **Plasma Cutter** ($1,200) to
weld the safe. Both are removed as requirements.

| Stage | Was | Becomes |
|---|---|---|
| The four gates (drill gate + A, B, C) | 10-second drill on one, nothing on three | **sequence hack**, each |
| The 8 display cases | crowbar + 25-second bar, each | **sequence hack**, each — **8 separate hacks** |
| The safe | plasma cutter + weld bar | **terminal hack** |

**Owner decision — the existing back gate at `[7535.69, 10577.1]` converts to a sequence hack too.**
One rule, no exceptions; the 10-second drill bar disappears. ~~That gate is still the one that raises
the alarm and starts the event.~~

> **SUPERSEDED 2026-07-29 — see §9.** The back gate is no longer the *only* gate that raises the alarm
> and starts the event. **Every one of the six sealed gates now does.** The clause above was written
> before the owner was asked which gates he meant and is kept only so the change is traceable.

**Owner decision — eight separate case hacks**, not one hack that unlocks all eight. Accepted cost:
12 minigames in a full run (4 gates + 8 cases) plus the safe's terminal.

`jewelCrowbar` and `jewelLaser` stop being required. Whether they are also pulled from the Rebel
Market's stock is left to the owner; nothing else uses them.

---

## 2b. The gold trophies float a metre over the cases

Owner, in game: the `Land_Trophy_01_gold_F` a smashed case yields spawns **about 1 m above the
coffin**. It should sit **as close to the top of the case as is feasible**.

The spawn is in `APS_fnc_jewelryEmporiumSRV` case `"createCase"`. Do not guess the offset — read the
case's real height with `boundingBoxReal` on `Coffin_02_F` and place the trophy on the top face, then
verify with the same settle-read idiom the Fed's gold uses (spawn, freeze, re-read a couple of
seconds later against the case it belongs to, and log the difference).

Note the display cases are frozen and sit at a known height, so a trophy placed on the case's top
surface will stay there; this is placement, not physics.

The same question applies to the **four trophies the safe drops** — they use
`AP_jewelSafe modelToWorld [(_i - 1.5) * 0.7, 0.8, 0]`, which was never eyeballed in game. Check
both while in there.

## 3. The crane — a new stage between the safe and the getaway

`Land_RepairDepot_01_tan_F` at `[7515.6, 10596.1, 3.84]`, beside the owner's marked spot
`[7515.43, 10598.2, 4.21]`.

**This is the reference build's missing container stage.** On Altis `AP_jewerlyContainer` was a
`Land_RepairDepot_01_green_F` — the same object family — and Malden bound it to `objNull` because no
container was placed. The "Load Container" scroll entry already exists in `fn_setupActions.sqf`,
gated on that variable. Binding it to this crane revives a stage that was designed and never wired.

**The flow:**

1. Loot the safe and the cases as now. The Qilin does **not** spawn at this point any more.
2. Carry the haul to the crane.
3. Scroll option **"Load Jewelry"** → **2-minute progress bar**.
4. On completion the **Qilin spawns**, loaded, with the emporium's doors thrown open, and the crew
   drives out to the African Warlord.

**Owner decision — the load takes what you are carrying, plus a bonus.** The bar strips `jewelBag`
and `jewelHope` out of the loader's inventory into the Qilin and adds bonus bags on top. Loot nobody
collected is lost. Several players can each load their own share into the same vehicle.

That makes clearing the whole shop worth doing and punishes a crew that rushes the safe — which is
the point of having eight cases at all.

---

## 4. The Hope Diamond returns

`jewelHope`, "Hope Diamond", already configured at **$108,000** in `fn_virtItemCfg.sqf` and already
in the vehicle-swap blocklist. Nothing spawns it today; the reference build did.

**The safe spawns it** — one per run, the jackpot and the heist's only real variance.

### ~~Owner decision — it must be loaded into the Qilin like everything else.~~ RETRACTED 2026-07-29

> The original rule read: *"It must be loaded into the Qilin like everything else. It cannot be
> pocketed and walked out. One escape route, one prize: lose the Qilin and the run's value goes with
> it."*

**This rule is withdrawn. The Hope Diamond STAYS SELLABLE ON FOOT. Do not delist it.**

**Owner decision, 2026-07-29 — the retraction and why it was asked for:**

- The rule was never implemented and could not be implemented cheaply. `jewelHope` is an ordinary
  virtual item with an ordinary sell price in `fn_virtItemCfg.sqf` (`$108,000`), so "cannot be
  pocketed and walked out" would have meant **delisting it** — stripping its sell price so the only
  thing that could ever pay for it was the Qilin's trunk.
- An agent was asked to do exactly that and **correctly refused**, on the grounds that delisting a
  configured sell price to enforce a flow rule is a large, silent economic change made to satisfy a
  comment. The question went back to the owner, who **changed the rule instead of the code.**
- **Pocketing the diamond and walking out is now an accepted second escape route.** It is the
  low-variance play: no Qilin to lose, no convoy to intercept, but you carry $108,000 on your body
  through however many MaxSec checkpoints are between you and a buyer.
- **It is a reason to frisk.** That is the point of keeping it: it gives MaxSec something worth
  searching a fleeing civilian for, and gives the crew a real choice between the vehicle and the
  pocket. One escape route was less interesting than two.

**Consequences that are now correct and must not be "fixed" back:**

- `jewelHope` keeps its sell price. Nothing in this heist may remove it.
- The load stage still accepts the diamond (`case "loadJewelry"` clamps `_hopeClaim` to 1, and only
  when the safe was actually opened) — loading it is an option, not a requirement.
- The player-facing string in `fn_jewelryEmporium` case `"takeSafeContents"` used to announce that the
  diamond *"only pays if it goes in the Qilin"*. **That was false when it was written** and it is
  false now. It has been reworded to state the two things that are true: one per job, and two ways to
  cash it. **Do not restore the old wording, and do not implement the rule it described.**

---

## 5. What this changes about the Qilin

The Qilin is no longer the reward for looting the safe — it is the reward for **completing the
load**. Everything else about it stands: armed `O_LSV_02_armed_F`, unlimited virtual inventory
(`AP_vcap = 999999`), keys to every alive civilian on site via `AP_fnc_addVehicle2Chain`,
`AP_eventVeh = true`, and **no `dbInfo` / `AP_dbInfo`** so it does not survive a restart.

It already spawns at `[7515.07, 10599.3]` facing 180 — 1.2 m from the crane. So the existing spawn
point is already the right place for a vehicle you load at the crane; nothing moves.

---

## 6. Answered 2026-07-29 — these are closed

- **One loader, not several.** The load is a single-player action and runs **once** per robbery. It
  still needs a repeat guard so a second call cannot mint a second armed Qilin — this build has
  already shipped that exact bug once, in `weldSafe`, where nothing read the done-flag and a repeat
  remoteExec produced another loaded vehicle. Same shape here.
- **Whatever the loader is carrying.** No requirement to have the whole haul; the bar takes what is
  in that player's inventory.
- **5 bonus bags**, flat. Does not scale with what was loaded.
- **Pull `jewelCrowbar` and `jewelLaser` from the Rebel Market.** They stop being required and stop
  being sold. Leave the item definitions in `fn_virtItemCfg.sqf` so existing stock in players'
  inventories and houses still has a name, a weight and a sell price.

Correction to section 3 as first written: it said "several players can each load their own share into
the same vehicle". That is **not** the design — one loader, one load.

---

## 7. Things that must not regress

- The frame lesson from the Fed: `buildingPos` returns **PositionAGL**; `setPosATL` measures from the
  terrain. Anything placed near water must convert with `AGLToASL` and write `setPosASL`, and the
  conversion must happen **once at the anchor**, never per-item inside a spread loop.
- Display cases are frozen (`enableSimulationGlobal false`) and carry `AP_furniture` **and**
  `AP_questloot` — the second stops `fn_pickupItem` deleting the case when its dropped-item list
  empties, which would otherwise destroy one case per run permanently.
- `-SEC-` rows take their subject from `remoteExecutedOwner`, never from the remoteExec payload.
- The vanilla "Open Door" action is offered on a locked gate regardless; it tests the animation
  phase, not the lock. Never judge a seal by whether the option appears.

---

## 8. Recon corrections, 2026-07-29 — the site is not what section 1 assumed

Established from `mission.sqm` and the game's own configs, not inferred:

- **There are SIX gates, not four.** The owner's point B is *two* `Land_ConcreteWall_01_l_gate_F`
  either side of his coordinate (Eden ids 10941 at 3.71 m and 11637 at 5.06 m), and a sixth
  `Land_BackAlley_01_l_gate_F` (id 11044) stands 6.03 m from the drill gate, perpendicular to it —
  an L corner, two separate gateways. `APS_fnc_maldenJewelSRV`'s own header already named that one.
  All six are in scope.
- **Point C has a decoy.** The object NEAREST the owner's coordinate is a
  `Land_BrickWall_03_l_gate_F` (id 10789, 0.13 m) which inherits `Wall_F`: no `numberOfDoors`, no
  `AnimationSources`, no `UserActions`. It cannot be opened and cannot be sealed. The real gate at C
  is a `Land_BackAlley_01_l_gate_F` (id 10814) 0.18 m out. Log the decoy explicitly at boot as
  "decorative, no doors, not sealed" so nobody re-derives a missing gate there later.
- **The crane is NOT a `mission.sqm` object.** It is a `core/config/fn_mapData.sqf` row with
  `_xIsServer = false` — a per-client `createSimpleObject` that the SERVER CANNOT SEE with
  `nearestObjects`, and that a client only creates while the zone loader has that zone up. A boot
  resolver modelled on the drill gate would silently publish `objNull`. It must be promoted to a
  server row, exactly as the eight display cases were. Unlike the cases it will not free-fall
  (`Land_RepairDepot_01_base_F` is a `House_F` static with no simulation override), so no freeze is
  needed — but tag it `AP_furniture` so the cleanup sweep cannot take it.
- **Promoting the crane makes it a working vehicle repair point.**
  `Land_RepairDepot_01_base_F` carries `transportRepair = 200000000` and `supplyRadius = 5`, so a
  server-side crane repairs vehicles within 5 m — including the getaway Qilin.
  **Owner, 2026-07-29: accepted. "Repair point is fine, doesn't matter at all in the gameplay loop."**
  Closed; do not raise it again.
- **The Qilin pad is further from the crane than section 5 said.** `[7515.07, 10599.3, 0.19]` is
  3.28 m from the crane in 2D and **3.65 m below it** — the pad is on the lower quay, the crane on
  the raised deck. The pad does not move; the load action's range check just has to allow for the
  drop.

---

## 9. Any sealed gate starts the job — 2026-07-29, owner report on b0131

Owner, in game on b0131: *"breaching any of the 2 gate doors on the building should let you start
cracking the coffins."* Asked which of the six sealed gates he meant, he chose: **any sealed gate.**

### The new rule

**A breach of ANY of the six gates runs the full robbery start.** Not just the anchor
(`AP_jewelGate`, the back gate 12.29 m from the emporium centre). The full start means everything it
has always meant: the alarm, the global "is being ROBBED" broadcast, the MaxSec `copalert`, wanted charge
76 on every civilian within 90 m of the centre, `casesLootable` (slot 4), both cooldown stamps (slot 0
and `SRV_lastRobbery`), the anchor gate swung open, and the 20-minute window.

This replaces the old behaviour, where the five non-anchor gates sent `"perimeterGate"` and that case
**deliberately touched no event state at all**. Any sentence in this document or in the code that says
the perimeter gates do not start the event or do not raise the alarm is now wrong and has been
corrected where it appeared.

### Why "starts the job" and not "quietly unlocks the loot"

`"lets you start cracking the coffins"` has two readings, and the controller's decision — recorded here
because the reasoning is the part worth keeping — is the first:

- **Read as "starts the job".** Every gate is the first move of the heist. Chosen.
- **Read as "quietly unlocks the loot"** — a far gate that sets slot 4 *without* alarming. **Rejected.**
  It would hand a crew a silent heist with no police response, and the police response *is* the event
  the whole heist is built around. Eight case hacks and a safe terminal with nobody coming is not the
  job; it is a vending machine.

The owner's own rule that the back gate raises the alarm is therefore preserved by making **every** gate
raise it, not by carving out a quiet exception.

### Accepted consequence: the alarm can be tripped from further out

From the boot log, distances from the emporium centre: anchor **12.29 m**; back-alley gates at A
**15.69 m**, at the L corner **17.98 m**, at C **37.66 m**; the two `Land_ConcreteWall_01_l_gate_F` at
the owner's point B **42.10 m** and **43.98 m**. So the alarm can now be tripped from three times as far
out as before. **Accepted.** The 90 m wanted sweep is measured from the centre and has never keyed off
the gate, so the furthest breacher is still comfortably inside it.

### Ruling — a refused start still opens a PERIMETER gate

If one of the start's guards refuses (a job already running, a live federal event, too few tenured cops,
the 30-minute re-breach cooldown, the 15-minute cross-heist lockout), the perimeter gate **still opens**,
nothing is armed, and the player is told why the job did not start.

- The Sequence Breach is a completed action with its own cost — it can be failed and traced. Voiding its
  own effect after it succeeded, over state the player cannot see, is a silent loss.
- Opening a fence arms nothing: no event state, no spawn, no payout. The existing 10-minute per-gate
  re-seal already bounds it, so a gate opened inside the 30-minute cooldown is shut again about 20
  minutes before anybody could use it.
- **The decisive case is "a robbery is already running."** That is the ordinary reason a perimeter breach
  does not start a job — a second crew member cutting a way in, or opening a way out for the getaway —
  and refusing the gate there would be a straight functional regression.
- It keeps the change purely additive: in every state where the job cannot start, a perimeter breach
  behaves exactly as it did before.

**The anchor is the exception and keeps its current behaviour exactly**: its opening is *part* of the
start, so a refused anchor breach still leaves the anchor shut. The anchor is the vault door, not a
fence.

### One further behaviour worth knowing

A start triggered from a perimeter gate **also opens the anchor**, because that is what the start has
always done. This is deliberate, not an oversight: once the job is live the client hides "Breach Emporium
Gate" and the server refuses an already-active start, so otherwise a job begun at a far concrete gate
would leave the anchor welded shut for the whole 20-minute window — worse than before the change. The
anchor is also the alarm emitter and the one gate the 10-minute perimeter re-seal can never touch, so
opening it is what guarantees the crew a way in and out for the window.

### Not changed, on purpose — owner calls, not side effects

- **The perimeter Sequence Breach stays at buffer 6.** The anchor uses 10 because it is "the first move
  of a federal event", which all six gates now are, so there is an argument for 10 across the board.
  That is a difficulty change; it needs the owner's word.
- **The `jewelrydrilled` stat still counts anchor breaches only.** It is bumped client-side in case
  `"hackGate"` and not in `"perimeterGate"`, so it now under-counts robbery *starts* — but it counts what
  its name says and what it has always counted, and it feeds a title. Completions are already counted
  server-side in `jewelryscompleted`.
- **The perimeter action's labels and preconditions.** The client action deliberately does **not** gain
  the start's preconditions: a client-side pre-check would refuse the breach entirely on state that the
  ruling above says must not cost the player their gate. Offer condition and refusal therefore still test
  exactly the same seven things (civilian, deck, on foot, membership, not-the-anchor, still-sealed, 10 m).

---

## 10. The Hope Diamond was invisible to the player — 2026-07-29, same report

Owner: the Hope Diamond *"didn't spawn"*.

**It did.** The server flags it on the open safe (`AP_jewelHopeInSafe`) at the weld and case
`"takeSafeContents"` logs every grant path — grants, refusals and race losers alike. The dev log for that
run has **no `takeSafeContents` line at all**: the take was never attempted. Two mechanical explanations
were put up and both refuted with evidence (cursor occlusion cannot apply — the action is offered on
*proximity* to `AP_jewelSafeOpen` and the server never reads a client-named object; carry weight cannot
apply — the client asks for room first and a refusal would have been logged). The timeline settles it:
weld at 17:42:54, crane bar starting about 17:43:26, and 11 of the 12 gold trophies banked in between.
The player stood at the safe collecting its four trophies and walked away with $108,000 still in it.

**The cause is discoverability. Nothing told him a diamond was there, or that it is a separate scroll
action on the safe rather than one of the trophies he was already picking up.** Fixed with wording only —
no new stage, no new item, no change to how the diamond is delivered:

1. **The weld broadcast names it.** It said "The Jewelry Emporium safe is OPEN." and stopped; it now says
   the HOPE DIAMOND is inside it. This is a global `systemChat` line, which is the right channel for the
   whole server (MaxSec learning a $108,000 diamond is loose is exactly why the owner kept it sellable
   on foot, §4) and the wrong one to rely on for the player who has to act.
2. **A direct hint to the welder** through `AP_fnc_handleMessage "basic"` — the prominent channel the
   grant messages already use — telling the one player standing at the safe that the diamond is NOT one
   of the gold trophies and has to be scrolled off the safe.
3. **The scroll label names the prize.** `Take Safe Loot` reads, while the diamond is still in there,
   `Take Safe Loot -- HOPE DIAMOND`. The stem is kept because the code and this document reference it;
   the suffix is conditional because the same action still grants the jewelBag afterwards, so a fixed
   label would become a lie the moment somebody takes the diamond.

**Considered and declined**, so it is not re-litigated: a map marker on the safe (it is 5 m from the
welder — a marker tells him nothing he cannot see), a proximity re-announcement to everyone near the safe
(a third channel repeating the same sentence), and a periodic reminder while the flag is set (noise, and
the scroll label now carries it permanently).
