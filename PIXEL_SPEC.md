# Armapunk Pixel — v3: LITERAL 1:1 clone of the reference game

**Owner 2026-09-10 (fourth request): "again its not 1:1 — I want a literal 1:1 of asylum pixel to then edit."**
v3 removes every rename layer of v1/v2. The reference's cities (Kavala, Neochori, Athira, Pyrgos, Sofia),
site ids (`kav_apple`…), item names (Pixie Dust), blurbs, guide copy, UI strings, Tailwind classes, layout,
theme tokens and numbers ship verbatim. The owner edits afterwards. Sanctioned differences, the whole list:
the brand string ("Armapunk Pixel") in the h1 / title, the API base `/api/pixel/`, our Steam session and
Postgres, the portal shell around the page. Plan and contract: `pixel_plan.md`. Reference material:
`~/archive/asylum-pixel-ref-20260910/` (never delete) and `website/src/lib/pixel/reference/`.
The sections below are the v3 state; the v1/v2 text that follows the "---" is history.

## v3 status

- Client port: see § UI (lane C keeps this section current).
- Server: § Rules, § API, § Data model below (lane S). 160 vitest cases in 12 files green
  (`npx vitest run src/lib/pixel`; the store round-trip `store.db.test.ts` needs `PIXEL_TEST_DB=postgres://…`
  and ran green against a scratch cluster with the v3 DDL applied twice), `tsc` and `eslint` clean on
  `src/lib/pixel` + `src/app/api/pixel`. `website/vitest.config.mts` adds the `@/` alias tests need.

## Rules (v3: the reference's rules, its ids and its wire format)

Everything below is a vitest case in `website/src/lib/pixel/__tests__/`. Content is
`reference/statics.json` verbatim (`content.ts` re-exports it; `CONTENT_TABLES` deep-equals the file).
Cities `kavala neochori athira pyrgos sofia`, sites `kav_apple` … `sof_crystal` (61), items `apple` …
`cigars` (58, `pixied` = "Impure Pixie Dust"), 12 skills, 13 licences, 14 talents, 7 star perks, 34
crews, 27 process rates, the 100-entry `xpCurve`, gear / backpacks / tools / copGear, the gang and
prestige tables, the travel matrix. The only values not in the statics are `CHEST_DETAILS` (chest xp and
paper ranges, from the client bundle's own chest table) and the `INFERRED` table (below).

### Vocabulary and result shape

`POST /api/pixel/action` body `{ type, ...payload, sinceChat, chatRevision, chatGeneration }`, the 52
reference types with the reference payload keys (`parse.ts`, `ACTION_TYPES`): `work {siteId}`,
`sell {itemId, amount: n | "all"}`, `drop {itemId, amount}`, `travel {cityId}`, `license {licenseId}`,
`skill {skillId}`, `talent {talentId}`, `starperk {perkId}`, `tool {kind}`, `gear`, `pack`, `copgear`,
`crew {siteId}`, `crewpause {siteId | null, paused}` (null = every crew: the client's "Pause all"),
`worker {siteId, minutes, kind}`, `craftcontract {qty}`, `openchest {rarity}`, `autosell`,
`workerautosell` (both toggles, no payload), `payheat`, `ditch`, `respec`, `prestige`, `reset`,
`faction {faction}`, `switch {faction}`, `bust {targetId}`, `casestart {practice}`,
`caseanswer {id, round, choice}`, `release`, `prisonstart`, `prisonrotate {custodyId, jobId, tile}`,
`prisoncomplete {custodyId, jobId}`, `pursuitready {id}`, `pursuitanswer {id, round, choice}`,
`pursuitsurrender {id}`, `verify {id, answer}`, `hp`, `chat {text}`, `gangcreate {name, tag}`,
`gangjoin {gangId, code}`, `gangleave`, `gangkick {targetId}`, `gangprivacy {private}`,
`blackjackdeal {bet}`, `blackjackhit`, `blackjackstand`, `slots {bet}`, `roulette {bet, choice, number}`,
`pokerjoin {buyIn}`, `pokerdeal`, `pokerleave`. Unknown type or bad payload → HTTP 400 `{ error: "Bad action" }`.

The response is `{ snapshot, result }` with HTTP 200 even when `result.ok === false`. `result` is what the
reference client pops: `{ ok: true, gained?: {itemId: n}, cash?: ±n, xp?, papers?, chest?: rarity, heat?,
talentPoints? ("LEVEL UP"), message?, jackpot?: true, casino?: {reels, bet, payout} | {number, color, bet, payout} }`
or `{ ok: false, error }`. `message` is only shown by the client when no `gained` / `cash` / `xp` came with it.

### Gates (in order, `engine.ts apply`)

1. Tick (stamina, heat cooling, arrival, custody release, crews, contractors, salary, case expiry, pursuit deadlines).
2. Rate limit: under 200 ms since the last accepted action → `"Too fast"`; the route turns that into HTTP 429 + `Retry-After: 1`.
3. `reset` → a fresh save at the career picker (leaves the gang and the poker table), `{ ok: true }`.
4. No career yet: only `faction {civ|cop}` goes through (`"Pick a career first."`); picking twice → `"You already have a career."`.
5. For everything except `hp verify chat release prisonstart prisonrotate prisoncomplete pursuitready pursuitanswer pursuitsurrender`:
   a pending checkpoint → `"Answer the checkpoint first."`; an activity lock → `"Locked out. Try again in Ns."`;
   custody → `"You are in custody."`; the road → `"You are on the road."` (the reference disables the whole UI while
   `travelUntil > now`: every action waits, not just the site ones as in v2).
6. The handler. A rejection keeps only the tick; a checkpoint miss is the one "keep the change, report an error" path.

### Civilian career (ids as the reference)

1. **Level** = highest i+1 with `xp ≥ xpCurve[i]`; `xpInto`, `xpNeeded` (1 at level 100, as the snapshot shows). Talent points = `level − 1 − spent` per career.
2. **XP** on every gain: `round(base × (1 + 0.08·quickLearner) × (1 + 0.08·starXp) × (1 + 0.01·gangLevel))`; half of it feeds the gang. Level-ups feed `reached level N` and put `talentPoints` in the result.
3. **Stamina** `max = 100 + 15·endurance + 10·starStamina` (300 verified); `regen = (1.6 + 0.22·endurance)(1 + 0.12·secondWind)`/s (6.78 verified); the view floors it.
4. **Capacity** `= round((gear + pack) × (1 + 0.08·strength) × (1 + 0.10·mule))` (10 447 verified); officers carry the starter gear (45).
5. **Travel** `ms = travel[from][to] × gear.speed × 1000` (officers ride tier 0), min 1 s; `"On the road to X."`; `"You are already there."`.
6. **Site gate** with the client's button labels: officer on an illegal site `"APD personnel cannot work illegal sites."`, `"That site is not in this city."`, `"Level N"`, the licence name (`"Farming License"`), `"Too tired"`, `"Pack full"`, `"Need Raw Cotton"`.
7. **Work**: `perClick = max(1, floor(yield × tool.mult × (1 + 0.12·skill) × (1 + gangYield) × (1 + 0.06·starYield)))`; officers `max(1, floor(yield × 0.5 × gang × star))` with the starter tool. Bumper Crop doubles a gather with chance `0.08·rank`; Efficiency skips the input with `0.07·rank`; output clamped to bag room; jackpot with `chance × (1 + 0.30·prospector)` (`gained[item]`, `jackpot: true`, feed `struck Pearl at Oyster Beds`); chest with `chestChancePerClick` (rarity by weight; epic and up feed `unearthed a Smuggler's Cache at Apple Orchard`); paper with `paperDropChance`. Rng order per click: bonus, jackpot, chest (+ rarity), paper, then the checkpoint draw when one is due. Auto-sell (level 6, civ) sells the main output at the local price; jackpots and raw goods stay in the bag. Illegal sites add `heatGather` / `heatProcess` × `(1 − 0.07·stealth)(1 − 0.09·ghost)(1 − 0.08·starGhost)`; the gain is in `result.heat`.
8. **Heat** cools `heatCoolPerMin × (1 + 0.05·stealth)` per minute; `wanted = heat ≥ visibleAt = 22 + 3·lowProfile`. `bustEstimate = { fine = 2385 + 150·level, fineCeiling = fine, seized = Σ illegal qty × sell, bounty = round(0.05 × priced illegal units), bountyCeiling = round(2.78 × units) }` (17 385 / 327 600 / 4 / 217 verified on the snapshot). `payheat` costs `bribeCost = 1000·heat + 0.35204·seized` (115 328 verified): `"Not available once you are in custody."`, `"Your record is clean."`, `"You are $N short."`. `ditch` drops all contraband and halves the heat (`"Ditched N units of contraband."`, `"Nothing to ditch."`).
9. **Selling** `price = round(sell × mult × (1 + 0.03·haggling) × (illegal ? 1 + 0.06·fence : 1) × demand × (1 + 0.04·starHaggle))` (apple 11, cotton 514, meth 8 762 verified); after a sale `mult = max(0.4, mult × max(0.8, 1 − 0.02·ln(1 + units)))`, recovering 0.004/min to 1.18. Sales of $100 000+ feed `moved Nx Item for $X`. Illegal sales add `max(1, units/10)` heat. `"Nobody buys that raw."`, `"You do not have that."`, `"Unknown item."`, officers `"Officers do not fence contraband."`. `netWorth = cash + Σ qty × sell`.
10. **Purchases**: licences of the career once (`"That licence is not for your career."`, `"Already held."`, `"Not enough cash."`); skills `costs[rank]` to 12 (`"Already maxed."`); talents need level and points (feed `trained Pack Mule 4`, message `Learned X N.`); respec `(17 000 + 2 000·spent) × (1 + 0.5·respecs)` (121 000 verified); tools / `gear` / `pack` next tier (`"Top of the ladder."`, `"Needs level N."`), officers `"Officers use standard issue."`; `copgear` needs its certification (`"Needs the Firearms Certification."`); star perks one pick per rank (`"No star to spend."`). Every cash purchase pays `cost / 1000` XP.
11. **Crews** (civ, gather sites in `crews`): `cost × 1.65^owned`, max 10 (`"Crew maxed (10)"`), `perMinute × (1 + 0.15·logistics)` per whole minute into the bag, XP at a third of the hand rate, illegal crews `crewHeatPerMin`; paused crews make nothing; crews sleep on APD duty and resume (no catch-up) on the switch back.
12. **Contractors**: 15/20/30-minute gather contracts for 3/5/7 papers, processing contracts for 1/2/3 crafted contracts (`craftcontract {qty}` = 5 papers each); max 3 (`"Already running 3 contracts"`); rate = `crew.perMinute × 2.5` or `processRates × 2.5`; run on wall clock whichever career is active; `workerAutoSell` sells at the site's city resting price into `earned`.
13. **Chests** `cash × (1 + level/20)`, `CHEST_DETAILS.xp × (1 + level/20)`, papers uniform in the range.
14. **Prestige** per career: level 100, every licence of the career, civ tools 6/6 + Tempest Device + Bergen Hauler (cop: Tactical Response Unit), fee `1 000 000 + 250 000·prestige`; `prestigeBlockers` are the strings the UI lists; the career resets (cash to `100 000 × starBankroll`), keeps chests / papers / stats / perks; `starPicks += 1`; feed kind `raid`: `retired a civilian run for star N`.

### APD career

`faction cop` or `switch {faction: "cop"}`. Two careers are separate builds (cash, xp, licences, skills, talents, respecs, equipment, bag, prestige, star perks); stamina, heat, chests, papers, stats, city, custody and gang are the player's. Switch: 15-minute cooldown (`"Paperwork pending — Ns."`), `heat > 1` blocks joining (`"The APD will not take you while you are under investigation. Let your heat cool."`). Salary `100 + 5·level` per whole minute on duty, online or not. Officers: legal sites at half rate with starter gear; no illegal sales, crews, contractors, auto-sell (`"Officers cannot hire crews."`, `"Auto-sell is a civilian perk."`). Cop licences / skills / talents / `copgear` from the statics.

Dispatch: `casestart {practice}` opens `apdCase {id, status, practice, targetScore 180, reward, rounds[3], answers[], startsAt = now + 3 s, until = startsAt + 45 s}`; paid calls need `npcCrime[city] ≥ 2` (`"No paid calls here"`), no cooldown (`"Cooling down (Ns)"`), `patrolStamina 8 + gear.staminaDelta − floor(rapidResponse/2)` stamina (`"Too tired"`), take 20 crime off the city, count a click; `caseanswer` in order, scored per checkpoint (100 for the cheapest street, 0 for the dearest); 3 answers settle: total ≥ target → `won`, paid: `caseReward = round((400 + 20·level)(1 + 0.12·rapidResponse)(1 + 0.04·dispatch)(1 + 0.10·starBadge) × gear.bountyMult × manpowerMult)` in cash, 30 XP, a chest roll, 60 s cooldown; else `lost`; the window expires by tick. `manpowerMult = clamp((civs online here + 1)/(officers online here + 1), 0.5, 1.5)` (others only). `bust {targetId}`: `"Only APD officers make arrests."`, `"Too tired"` (< 14), and alone always `"No such suspect."`.

### Gangs (civ)

`gangcreate` $250 000 at level 5+, name 3-20, tag 2-4 uppercased, unique; `gangjoin` needs a slot (`cap = min(10, 5 + floor(level/2))`, `"Full — slots unlock as the gang levels"`) and, for private gangs, the invite code (`"Wrong invite code."`); the code is derived from the gang's seed, the 30-minute window and a use counter, so it rolls on the clock and on every use; leaving passes the lead to the longest-standing member, the last member dissolves the gang; only the leader kicks and sets privacy. Gang level from `gang.xpCurve`, `yieldBonus = xpBonus = 0.01·level`. The reference's own refusal for an unknown gang: `"That gang no longer exists."`.

### Chat

`chat {text}`: trimmed, non-empty (`"Say something."`), ≤ 240 (`"Keep it under 240 characters."`); allowed on the road and in custody. Delta protocol (`chat.ts`): the client sends `sinceChat` (newest id it holds), `chatRevision`, `chatGeneration`; a revision or generation mismatch (or no cursor) gets the newest 40 rows, otherwise only rows above `sinceChat`; `chatOldestId` is the oldest retained row (newest 200 kept; a prune bumps the revision); `chatGeneration` is one uuid per install (`web_pixel_meta`).

### Casino (`canAccessCasino` true; `snapshot.casino = { blackjack, poker }`)

Blackjack: a wager is deducted at `blackjackdeal`, a natural pays 2.5× at once (push against a dealer natural), `blackjackhit` busts over 21, `blackjackstand` draws the dealer to 17 (stands on every 17), win 2×, push returns the bet; `"Finish the hand first."`, `"No hand in play."`, `"Bad wager."`, `"Not enough cash."`. The wire hides the hole card (`dealerCards: [card, null]`, `dealerScore: null`) while playing. Slots: three reels off a 13-symbol strip (5 CHERRY, 4 BAR, 3 BELL, 1 seven); 7-7-7 25×, BAR 10×, BELL 6×, CHERRY 4×, two cherries 1×; `result.casino = { reels, bet, payout }`, `result.cash` = net. Roulette: single zero; red / black / even / odd 2×, green and exact number 36× (`"Pick a number 0-36."`); `result.casino = { number, color, bet, payout }`. Poker: `pokerjoin {buyIn}` takes a seat (first seat fixes the table buy-in: `"Buy-in (table requires $N)"`, max 4), `pokerdeal` needs 2 (`"Waiting for one more player."`) and deals a five-card board and two hole cards, best five of seven, winners split the pot into `lastResult`, the table clears; `pokerleave` refunds a seat that has not been dealt.

### Checkpoint, honeypot, custody, pursuit

Every 150 work clicks (paid calls count) `me.checkpoint {id, target, options[3], lockedUntil}` is issued from the 12-icon pool; `verify {id, answer}` clears it, a miss is refused with `"Wrong one. Try again."` but kept, the third miss locks for 60 s with a fresh checkpoint (`"Too many misses. A fresh checkpoint opens when the timer runs out."`); a stale id: `"That checkpoint has expired."`. `hp` (the hidden "Claim free cash" button) sets `activityLockUntil = now + 10 min`.

Custody (an arrest seizes every illegal item, clears the heat, `sentence = 120 s + 3 s per heat point`, `fine = 2385 + 150·level`): `release` pays `releaseCost = round(fine × (1 + 0.5 × remaining/sentence))` ("starts above the fine and gets cheaper the longer served"); the workshop: `prisonstart` after the first 60 s (`"No eligible work time yet — the first 60 seconds of any sentence must be served."`), worth `min(45 s, workRemaining)` where the sentence's work cap is half its length (`"You've worked off as much of this sentence as the rules allow — ride out the rest, or pay to leave."`); a solvable, scrambled 3×3 pipe grid (bits N=1 E=2 S=4 W=8, inlet west of tile 0, outlet east of tile 8); `prisonrotate` a quarter turn clockwise; `prisoncomplete` after 20 s (`"Working... Ns"`) credits the seconds if the pipes connect (`"Repair accepted. Ns off your sentence."`) or nothing (`"The pipes leak. Try again."`).

Pursuits mirror one `duel` on both players (`newDuelPair`): 30 s to ready up, then 3 route checkpoints in a 45 s window starting 3 s after both are ready; `pursuitanswer` scores like a case; higher total wins, a tie escapes; a civilian who does not ready up (or surrenders) is taken into custody (`"Civilian did not ready up in time and was taken into custody."`), an officer who does not ready up cancels it; without a pursuit: `"No active pursuit."`, a stale id `"That pursuit is over."`, an officer surrendering `"Officers do not surrender."`.

### Unreachable alone (implemented, tested, never triggered by one player)

`bust` (always `"No such suspect."`), the whole pursuit start (no cop-versus-civ pair; the state machine is driven in tests through `newDuelPair`), custody by arrest (tests call `jailPlayer` directly), `pokerdeal` (`"Waiting for one more player."`; the showdown is tested through a seeded second seat), gang joins of other players, `dispatch` / `suspects` rows (empty), `manpowerMult` other than 1, other players' poker payouts (the store credits them by `jsonb_set`; never exercised).

### INFERRED (server-side in the reference; `content.ts INFERRED`, each fitted to the named figure)

| key | value | fitted to |
|---|---|---|
| staminaBase / regenBase | 100 / 1.6 | 300 = 100 + 15·12 + 10·2; 6.78 at endurance 12, Second Wind 5 |
| clickXpPerStamina | 2 | "about twenty clicks gets you to level 2" (apple 3 stamina, xpCurve[1] = 120) |
| saleXpPerDollar / purchaseXpPerDollar / crewXpFraction / caseXp | 1/200 / 1/1000 / 1/3 / 30 | plausible; "crews earn a third of the rate" |
| heatGather / heatProcess / heatSalePerUnits / heatCoolPerMin / heatCoolStealthPct / heatMax / crewHeatPerMin | 2 / 3 / 10 / 2 / 0.05 / 100 / 0.5 | plausible; "Stealth cools it faster" |
| fineBase / finePerLevel | 2385 / 150 | fine 17 385 at level 100; fineCeiling = fine (equal in the snapshot) |
| bountyPerUnitMin / Max | 0.05 / 2.78 | bounty 4 / ceiling 217 with 78 priced illegal units |
| bribeHeatCost / bribeSeizedPct | 1000 / 0.35204 | 115 328 at heat 0 with 327 600 seizable |
| marketRest / Floor / RecoverPerMin / DropMin / DropLog | 1.18 / 0.4 / 0.004 / 0.8 / 0.02 | resting 1.18 and post-dump 0.98 observed; 2 180 units → ×0.846 |
| chestChancePerClick / chestLevelScale | 0.02 / 1/20 | plausible; "pays with your level" |
| respecBase / respecPerPoint / respecRepeatPct | 17 000 / 2 000 / 0.5 | 121 000 at 52 points; "gets pricier each time" |
| travelMinMs | 1000 | floor |
| copSalaryBase / PerLevel | 100 / 5 per minute | "salary accrues every minute" |
| patrolStamina / caseRewardBase / PerLevel / caseDispatchPct / caseTargetScore / caseReadyDelayMs / caseWindowMs / caseCooldownMs | 8 / 400 / 20 / 0.04 / 180 / 3000 / 45 000 / 60 000 | plausible; gear staminaDelta and Rapid Response apply |
| npcCrimeRegenPerMin / CostPerCase / Max | 1 / 20 / 100 | "Reported criminal activity" meter 0..100, paid call needs ≥ 2 |
| manpowerMin / Max | 0.5 / 1.5 | "heavily staffed" below 0.99, "stretched thin" above 1.01 |
| checkpointEveryClicks / MaxMisses / LockMs / honeypotLockMs | 150 / 3 / 60 000 / 600 000 | lockout shown as mm:ss |
| jailBaseSeconds / jailPerHeatSeconds / bailStartMult / prisonJobCreditSeconds / prisonWorkCap | 120 / 3 / 1.5 / 45 / 0.5 | "bail starts above the fine"; job ≥ 20 s, first 60 s served |
| duelReadyMs / StartDelayMs / WindowMs / pursuitFleeCost / arrestChanceBase | 30 000 / 3000 / 45 000 / 9 / 0.5 | fleeCost 9 is the snapshot value |
| feedSaleMin / feedLimit / chatWindow / chatRetain | 100 000 / 40 / 40 / 200 | the capture's feed shows one $18.9M sale and no small ones |
| slots paytable and reel strip | BAR 10×, BELL 6×, CHERRY 4×, two cherries 1×; 5/4/3/1 strip | "7s pay 25×"; RTP about 88 % |
| gangInviteCodeLen | 6 | "ABC234" placeholder |

### Deviations from the reference (the whole list, lane S)

- Brand: the join feed line says "landed on the island as a civilian" (the reference's `join` text is not in the bundle); island name "Altis" is not used in server strings.
- `GET /api/pixel/gang` returns `{ gang: {...} }` with `members[{steamId, name, level, prestige, leader, online}]` (what the reference client reads), plus `id name tag leaderName private createdAt isMine`, not the `faction / isLeader` member rows the plan sketched.
- `me` has 63 keys, the count of the example (the brief said 66).
- `result.casino` (slots and roulette) is an extra result key the reference client reads; `snapshot.casino` is `{ blackjack, poker }` (the example captured `null` because its player had no casino access).
- Roster rows carry `wanted` / `heat` only for an officer viewer (absent for civilians, as in the example); `gangTag` only in a gang.
- Server error strings not in the bundle are ours in the reference's voice (listed above); every string the client shows verbatim (`"Too tired"`, `"Pack full"`, `"Need X"`, `"Level N"`, `"Full — slots unlock as the gang levels"`, `"Paperwork pending — "`, `"Cooling down (…)"`, `"No paid calls here"`, `"The APD will not take you …"`, the prison and checkpoint sentences, `"That gang no longer exists."`, `"Waiting for one more player."`, `"Buy-in (table requires …)"`) is the reference's.

## API (v3)

- `GET /api/pixel/state?sinceChat=&chatRevision=&chatGeneration=` → the snapshot (`types.ts Snapshot`: `now, me, prices, mults, roster, gangs, online, headsByCity, feed, chat, chatOldestId, chatRevision, chatGeneration, dispatch, suspects, leaderboard, npcCrime, wantedAt, pursuitFleeCost, casino`); ticks and persists first; 401 `{ error: "Your session expired. Sign in again." }`, 404 for non-owners.
- `POST /api/pixel/action` → `{ snapshot, result }` (200 even on `result.ok === false`); 400 `{ error: "Bad action" }`; 401 `{ error: "Signed out" }`; 429 `{ error: "Too fast" }` + `Retry-After: 1`.
- `GET /api/pixel/gang?id=` → `{ gang }` or 404 `{ error: "That gang no longer exists." }`.
- `store.getView(steamId, name, avatar)` = the page's initial snapshot. All routes `force-dynamic`, owner-only (`access.ts` unchanged).

## Data model (v3, `website/sql/pg/web_pixel.sql`; migration `web_pixel_v3.sql` drops the v2 tables first)

```
web_pixel_players   (steamid PK, name, avatar_url, state jsonb (v = 3), faction NULL|civ|cop, city, level, prestige,
                     net_worth, gang_id, heat, wanted, jailed_until, travelling, last_seen, created_at, updated_at)
web_pixel_market    (city, item, mult, updated_at, PK(city, item))
web_pixel_events    (id, steamid, at, kind bust|raid|sale|jackpot|join|level, text)      -- feed, newest 40
web_pixel_chat      (id, at, steamid, name, faction, text varchar(240))                   -- newest 200 retained
web_pixel_gangs     (id PK, name, tag, leader_steamid, record jsonb (GangRecord: members inside), created_at)
web_pixel_npc_crime (city PK, value, updated_at)
web_pixel_casino    (id PK = 'poker', state jsonb, updated_at)
web_pixel_meta      (key PK, value)   -- chat_generation (uuid), chat_revision
```
`online` = `last_seen` within 2 minutes; `headsByCity` counts the online roster per city; `leaderboard` = top 10 by
`net_worth`; `roster` = online players with a career (gang tag joined from `web_pixel_gangs`). Every request runs
`BEGIN … SELECT state FOR UPDATE … gangs FOR UPDATE … casino FOR UPDATE … COMMIT`; a save with `state.v ≠ 3` is
replaced by a fresh one. Apply on the box: `docker exec -i armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 < website/sql/pg/web_pixel_v3.sql` then the same with `web_pixel.sql`.

---

# Armapunk Pixel — server-authoritative idle RPG on the portal (`/pixel`)

Owner 2026-09-10: "theres a web based game I want you to copy and apply to my server" → the source
was reverse-engineered into private session notes (not in the repo) and this is a **rebuild of the
mechanics with Armapunk's own content and code**: no third-party code, art, copy or identifiers ship
(standing rule: never name other servers in anything git-tracked). Decisions on record:
**name "Armapunk Pixel"**, **no tie-in to the game server yet** (portal-only state), **restricted to
the owner's Steam account only for now** (`OWNER_STEAMID`, 404 for everyone else). Plan:
`pixel_plan.md`.

## What it is

A click-and-idle economy game played in the browser: work Malden's five towns, gather raw goods at
fields and mines, refine them at processors, haul them to market, buy permits, train skills, hire
crews that keep producing while you are away, and run the illegal chains without getting busted.
Everything that pays, punishes or times runs on the server; the browser only sends intents.

## Scope

**MVP (this build):** civilian career only; 5 towns × 52 sites over the real Armapunk item
catalogue (generated from `fn_virtItemCfg.sqf`); stamina, bag weight, levels 1–50, 7 permits,
6 skills, 6 bag tiers, 6 tool tiers, per-town drifting prices, heat + NPC busts + bribes, crews,
jackpots, travel, event log, reset. UI: React panels + a PixiJS map of Malden (procedural, no
sprites) in the portal's cyan skin.

**Phase 2 (not built, listed so nobody re-derives them):** MaxSec career (patrol/arrest other
players), talents + prestige stars, gangs with shared bonuses, player-vs-player pursuits,
chests/contracts, casino, chat, "person at the wheel" checkpoints (only matters once it is public),
and the game-server tie-in (owner said "no tie in yet").

## Access (owner-only for now)

- `website/src/lib/pixel/access.ts` → `pixelAllowed(session)`: true only when
  `session.uid === process.env.OWNER_STEAMID`.
- `/pixel` page: `notFound()` unless allowed. `/api/pixel/*`: JSON 404 unless allowed. The
  site-wide Steam gate (`proxy.ts`) still runs first, so anonymous users hit `/login` as today.
- Sidebar shows "Armapunk Pixel" only when the layout computed `staff.pixel` (same owner test).
- Opening it up later = change `pixelAllowed` (one function) and the nav flag. Nothing else knows.

## Architecture

```
browser  PixelGame.tsx ──POST /api/pixel/action {action}──▶ route: gate → withPlayer(lock) →
         (polls GET /api/pixel/state every 5 s,               tick(state, now) → apply(state, market,
          interpolates stamina between polls)                  action, now, rng) → persist → view()
```

- `engine.ts` is **pure**: `(state, market, action, now, rng) → {state, market, events} | {error}`.
  No I/O, no Date.now, no Math.random. Unit-tested with vitest (`npm test`). Every rule below is
  a test.
- `store.ts` owns Postgres: one row per player (`state jsonb`), one row per (town, item) market
  multiplier, an append-only event log. Actions run inside `BEGIN … SELECT … FOR UPDATE … COMMIT`
  so two tabs cannot double-spend.
- `view.ts` derives what the client sees (prices, lock reasons, next costs). The client never
  computes money. `prices` covers every sellable item in the current town plus the bag (raw goods
  at 0), `market` carries the town multiplier per priced item, `me.netWorth` = cash + bag at local
  prices, and every site entry has its own `crewCost`.
- Content is data: `content.ts` (towns, sites, permits, skills, tiers, constants) and
  `items.ts` (**generated** by `website/tools/gen_pixel_items.js` from the mission catalogue:
  classname, display name, legal flag, base sell price = the in-server sell price idx8, weight
  idx2). A content test asserts every site's inputs/outputs exist in `items.ts`.

## Content (Malden)

Towns = the five the portal already maps (`HouseMap.tsx`), coordinates in Malden metres (12,800
world, y north). Sites sit on the mission's real markers where one exists (mines, oil fields,
processors, the smash field, the uranium ship, the black market); otherwise near the town.

| Town | Pos | Character |
|---|---|---|
| La Trinité | 7264, 7931 | Capital and spawn. Orchard, chicken farm, mineral processor, the smash chain. |
| Chapoi | 5559, 4234 | Industrial south. Copper, sand, glass, oil, trawler, the glitter precursors. |
| Le Port | 8300, 3240 | Harbour. Fishing, salt, gem cutter, the low-tier weed chain. |
| La Pessagne | 3367, 6292 | West coast. Timber, iron, diamonds, turtle poaching, the black market fence. |
| Larche | 6027, 8640 | North. Farms, moonshine, the cartel-named illegal sites (Boomtown oil, Blacksite lab, Grimstone seam, Wreckridge uranium). |

Chains (raw → refined, Armapunk classnames): apple, peach, berry, grapes, tobaccou, chicken→chickenp,
copperore→copper_r, sand→glass, salt→salt_r, ironore→iron_r, timber→plank, timberh→plankh,
oilu→oilp (+rubber side-yield), diamond→diamondc (jackpot diamondf; ruby at the mine; goldnugget at
Grimstone), mackerel (jackpot tuna), tuna (jackpot turtle), cannabis→marijuana,
smashpowder→smash→smashbrick, sparkdust+redshift+toxicslurry→glitterbase→glitter and
→lacebase→blacklace→blacklaceprime, corn→moonshinehash→moonshine→moonshinep, boost,
uraniumu→uraniump (jackpot element115), turtle. Raw goods with no in-server sell price (ore, sand,
salt, crude, stems, powder) cannot be sold: they must be processed, same as in-game.

Full table: `website/src/lib/pixel/content.ts` (SITES). Every number there is Armapunk Pixel's
own; only the catalogue (names, weights, legality, base prices) is the game server's.

## v2: the 1:1 balance pass (owner 2026-09-10: "start with a 1:1 of their version. Balance and all. Then tweak")

The reference game's client bundle and its SSR hydration payload carry every data table and every
displayed formula. Those are now the balance of Armapunk Pixel, verbatim, in `content.ts` /
`items.ts` (generated once from the extraction in session scratch; edit the files directly from
here on). The only rename layer: their five cities map onto Malden's five towns by character
(capital → La Trinité, timber country → Larche, crossroads → Chapoi, port → Le Port, far side →
La Pessagne), site ids take our town prefixes, and their pixie-dust chain is Armapunk's own glitter
chain (`glitterbase` → `glitter`). Copy (blurbs, guide) is ours. Everything server-side that the
bundle does not show is inferred and lives in `INFERRED` (below) so it can be tuned.

### Scope of v2

Civilian career, complete: 5 cities with the travel matrix, 58 items, 61 sites, 9 civ licences,
6 civ skills (12 ranks, `round(base × rank^2.05)`), 10 civ talents (1 point per level, rank costs
1/1/2/2/3, respec), 7 star perks, 6 vehicles, 5 backpacks, 7 + 7 tools, crews (permanent, gather
sites, `×1.65` per extra crew, max 10 per site, pause), contractors (papers → 15/20/30-minute
gather contracts; crafted processing contracts), chests (4 rarities), auto-sell (level 6) and
contractor auto-sell, heat and the wanted floor (22 + 3 per Low Profile), bribe (`payHeat`),
ditch, prestige and stars (25 max), the 100-level XP table, lifetime stats; the world around the
player: roster, feed, leaderboard by net worth. **Not in v2** (they need other players or are
feature-flagged in the reference): the APD career and gear, pursuits/duels, jail, gangs, chat,
casino, checkpoints. Their tables (`COP_GEAR`, cop licences, cop skills/talents, `GANG`) ship in
content so the switch is data-complete.

### Rules (each a vitest case; numbers come from `content.ts` unless marked INFERRED)

1. **Level** = the highest i+1 with `xp ≥ XP_CURVE[i]`; `xpInto = xp − XP_CURVE[level−1]`,
   `xpNeeded = XP_CURVE[level] − XP_CURVE[level−1]` (0 at 100). Talent points = `level − 1 −
   talentSpent` (`CONST.talentPointsPerLevel`).
2. **XP multiplier** on every gain: `(1 + 0.08·quickLearner) × (1 + 0.08·starXp)`, rounded.
   INFERRED amounts: work click `clickXpPerStamina × site.stamina`; sale `revenue ×
   saleXpPerDollar`; licence/skill/tool/vehicle/pack purchase `cost × purchaseXpPerDollar`; crews
   `crewXpFraction` of the hand rate per unit; contractors none; chests their table × level scale.
3. **Stamina:** `max = staminaBase + 15·endurance + 10·starStamina`; `regen = (regenBase +
   0.22·endurance) × (1 + 0.12·secondWind)` per second, applied lazily by tick, offline too.
4. **Capacity** `= round((VEHICLES[vehicleTier].capacity + BACKPACKS[packTier].capacity) ×
   (1 + 0.08·strength) × (1 + 0.10·mule))`; `carried = Σ qty × weight`. "Pack full" blocks
   gathering when `carried ≥ capacity`.
5. **Travel:** `ms = TRAVEL[from][to] × VEHICLES[vehicleTier].speed × 1000` (min
   `INFERRED.travelMinMs`). On the road: work, sell, crew, worker and travel wait; everything else
   goes through.
6. **Site gate** (order): on the road; not in this city; `level < minLevel`; licence missing;
   stamina < cost; gather: bag has no room for one unit; process: `inventory[input] < inputPer`.
7. **Work** (`work {site}`): `perClick = max(1, floor(yield × TOOLS[kind][tier].mult ×
   (1 + 0.12·skill) × (1 + 0.06·starYield)))` where skill = harvesting (gather) or refining
   (process); gather: with chance `0.08·bumperCrop` the click yields double; process: consumes
   `inputPer` per output unit of the base `yield` (not the boosted one), skipped with chance
   `0.07·efficiency`; output clamped to bag room (input leaves first). Jackpot with chance
   `jackpot[1] × (1 + 0.30·prospector)` adds `jackpot[2]` of `jackpot[0]` (stays in the bag even
   with auto-sell). With `autoSell` on and level ≥ `CONST.autoSellUnlockLevel` the main output is
   sold immediately at the local price (rule 9) instead of entering the bag. Stamina −cost. Illegal
   site: heat +`heatGather` / +`heatProcess` (INFERRED) × `(1 − 0.07·stealth)(1 − 0.09·ghost)(1 −
   0.08·starGhost)`. Each work click: chest with chance `chestChancePerClick` (rarity by weight),
   paper with chance `CONTRACTS.paperDropChance`. rng order: bumper/efficiency, jackpot, chest,
   paper (documented in code; tests script it).
8. **Heat** cools `heatCoolPerMin × (1 + heatCoolStealthPct·stealth)` per minute (INFERRED),
   capped at `heatMax`. `wanted = heat ≥ visibleAt`, `visibleAt = CONST.wantedAt + 3·lowProfile`.
   No busts in v2 (there are no officers). `bustEstimate`: `seized = Σ illegal qty × sell`, `fine
   = fineBase + finePerLevel·level` (INFERRED). `payHeat` costs `bribeHeatCost·heat +
   bribeSeizedPct·seized` (INFERRED), heat → 0, keeps the bag; rejected at heat 0. `ditch` drops
   all contraband and halves heat.
9. **Selling** (`sell {item, n | "all"}`): unit price `round(sell × mult × (1 + 0.03·haggling) ×
   (illegal ? 1 + 0.06·fence : 1) × city.demand × (1 + 0.04·starHaggle))`; `sell = 0` → "Nobody
   buys this raw". After a sale the city's multiplier becomes `max(marketFloor, mult ×
   max(marketDropMin, 1 − marketDropLog·ln(1 + units)))` (INFERRED) and recovers
   `marketRecoverPerMin` toward `marketRest` (INFERRED, resting 1.18 observed). Illegal sale heat
   `+max(1, units / heatSalePerUnits)` after the reductions. `netWorth = cash + Σ qty × sell`
   (base price, verified).
10. **Licences** once, cash ≥ cost, civ ones only. **Skills** rank r costs `SKILLS.costs[r−1]`,
    max 12. **Talents** need `level ≥ minLevel` and points ≥ `costs[rank]`; **respec** refunds
    every point for `respecCost = respecBase × (respecs + 1) × (1 + respecSpentPct·talentSpent)`
    (INFERRED). **Tools** (`tool {kind}`), **vehicle**, **pack**: next tier, `level ≥ minLevel`,
    cash ≥ cost. **Star perks** need `starPicks > 0`, rank < max, faction civ/both.
11. **Crews** (`crew {site}`): gather sites in `CREWS`, usable now (gate minus stamina/room);
    cost `CREWS[site].cost × 1.65^owned` (owned at that site), max `CONST.maxCrewsPerSite`; each
    crew makes `perMinute × (1 + 0.15·logistics)` units per wall-clock minute into the bag (stops
    when it will not fit), XP at `crewXpFraction`, illegal sites `crewHeatPerMin` heat per crew.
    `crewPause {site}` toggles; paused = no output, XP or heat. Production is settled by tick
    per whole minute since `crewsAt`.
12. **Contractors** (`worker {site, minutes, kind}`): gather contracts cost the paper count in
    `CONTRACTS.worker` for those minutes; processing contracts cost `CONTRACTS.process` crafted
    contracts (`craftContract {n}`: `processContractPaperCost` papers each). Max
    `workerMaxActive` running; the same site extends the window. Rate `perMinute` =
    `CREWS[site].perMinute × workerRateMult` (gather) or `PROCESS_RATES[site] × workerRateMult`
    (process, consuming `inputPer` per unit from the bag, idle without input). Every whole minute
    up to `until`: with `workerAutoSell` the output is sold at the local price (`earned` grows),
    otherwise it goes to the bag while it fits. Only sites whose output has a price take contracts.
13. **Chests** (`openChest {rarity}`): pays `cash × (1 + chestLevelScale·level)` and the same on
    xp (INFERRED scale), plus papers drawn uniformly in `[min, max]`.
14. **Prestige:** ready when level 100, every civ licence, tools 6/6, vehicle 5, pack 4, and
    `fee = PRESTIGE.cashBase + PRESTIGE.cashStep × prestige` in cash (blockers listed otherwise);
    max `PRESTIGE.max`. `prestige` resets cash (to `100,000 × starBankroll`), xp, licences, skills,
    talents, respecs, tools, vehicle, pack, bag, crews, workers, auto-sell; keeps chests, papers,
    stats, perks; `prestige += 1`, `starPicks += 1`. `starPerk {id}` spends one pick.
15. **Rate limit** 200 ms; **reset** wipes the save; **determinism** and **immutability** as v1.

### World (store, not engine)

`web_pixel_players` gains `level`, `net_worth`, `city`, `last_seen` columns kept in step with the
state on every write; roster = every player (online = seen within 2 minutes), leaderboard = top 10
by net worth, feed = the newest 40 level/sale/jackpot/chest/prestige events across players
(`web_pixel_events` gains `steamid` joins to names). The owner-only gate is unchanged.

### Inferred (server-side in the reference, never shown)

See `INFERRED` in `content.ts`: stamina base/regen, XP per action, heat gain and cooling, fine and
bribe, market drop and recovery, chest chance and level scale, respec cost, travel floor. Each
entry names the string or snapshot number it was fitted to.

## Data model (v2 history)

```
web_pixel_players (steamid varchar(17) PK, name varchar(64), state jsonb, created_at, updated_at)
web_pixel_market  (town text, item text, mult double precision, updated_at, PK(town,item))
web_pixel_events  (id bigserial PK, steamid varchar(17), at timestamptz, kind text, text text)
```

## API (v2 history)

- `GET /api/pixel/state` → `ClientView` (ticks and persists first: crews collect on view).
- `POST /api/pixel/action` body `Action` (`types.ts`) → `ClientView` or `{ error }` (400).
- Both `force-dynamic`, JSON, owner-only (404 otherwise).

## UI (`/pixel`): v3, the literal client port (lane C, 2026-09-10)

`website/src/components/pixel/**` is the reference page (`archive work/AsylumPixel.deminified.jsx`,
3.2k lines) split into typed TSX files, one per component, named for what they render. Every
className, string, icon, hook, effect, constant, condition and layout decision is the reference's;
only identifiers were renamed. The v2 files (own copy, PixiJS `TownScene`, `pixi.js` dependency)
are deleted. Two fidelity tests keep it that way (below).

### Component to file map (reference function in brackets)

| File | Renders |
|---|---|
| `PixelGame.tsx` | the page (`AsylumPixelPage`): header, fullscreen, "What now?" chips, tab bar, tab routing (`tq` TAB_IDS), pops (`tV` POP_TONES), chat FAB + sheet, checkpoint / pursuit overlays, the `hp` honeypot |
| `usePixelClient.ts` | the inline polling/action hook: GET `/api/pixel/state` (2.5 s visible / 30 s hidden, back-off `min(30000, 2500*2^min(fail,4))`, 10 s abort, 429 `Retry-After`), chat merge by generation/revision (`mergeChat`), 100 ms clock, POST `/api/pixel/action` `{type, ...payload, sinceChat, chatRevision, chatGeneration}` and the result pops |
| `PlayerCard.tsx` | HUD card (`Y`): identity, cash, stamina, load, heat/duty, location, bag strip, custody / travel banner |
| `CityGrid.tsx` | "Altis" city cards (`V`) |
| `WorkTab.tsx`, `SiteCard.tsx` | Work tab filter + grid (`es`), the site card (`ea`) |
| `MarketTab.tsx` | Market tab (`ec`), `MarketTag` HOT/FLOODED (`ed`) |
| `InventoryTab.tsx` | Inventory view (`tL`): chests (`tS` tones), contract papers, active contracts, bag, lifetime |
| `UpgradesTab.tsx` | Upgrades view (`ev`): skills, tools, licences, APD equipment, backpack, vehicle, career / prestige / star perks / wipe, work crews |
| `TalentsTab.tsx` | Talents view (`eO`) |
| `PatrolTab.tsx` | APD Patrol tab (`eL`) |
| `PursuitRounds.tsx` | route-choice checkpoint rounds (`eS`) + `scoreTone` (`eP`) |
| `PursuitDialog.tsx` | pursuit overlay (`tg`) |
| `CheckpointDialog.tsx` | "Routine checkpoint" overlay (`th`, icon map `tu`) |
| `PrisonWorkshop.tsx` | prison pipe puzzle (`tj`, `ty` PipeTile, `tb`) |
| `GangTab.tsx` | Gang tab (`e0`), privacy card (`e3`) |
| `GangBits.tsx` | member row (`e1`), gang XP bar (`e5`), bonus chips (`e2`) |
| `GangDirectory.tsx` | directory (`e4`), profile dialog (`e6`) with `useGangProfile` (GET `/api/pixel/gang?id=`) |
| `StreetScene.tsx` | "On the street" (`tr`), the pixel character (`ts`), `fnv1a` (`e9`), palettes |
| `ChatPanel.tsx` | chat (`eR`) |
| `IslandRail.tsx` | On the island / Activity / Richest on Altis (`e$`, `eI` tones) |
| `CareerPick.tsx` | "Choose your life on Altis" (`eE`, `eF` card) |
| `CasinoTab.tsx` | casino (`tH`): `tF` roulette bets, `tE` games, `tO` card, `tB` hand, `tU` note, `t_` wager, `tG` net |
| `GuideTab.tsx` | guide (`tN`, `tk` Step, `tw` Term) |
| `MobileTabBar.tsx` | phone bottom bar + More sheet (`tz`) |
| `primitives.tsx` | `Bar` (`_`, `U` tones), `Panel` (`G`), `Stat` (`H`), `Empty` (`W`) |
| `format.ts` | `fmtMoney` (`F`), `fmtCompact` (`E`), `fmtSecs` (`O`), `fmtAgo` (`B`) |
| `types.ts` | `Statics`, `Snapshot`, `Me` (all keys of `state_example.json`), `ActionPayloads` (the 46 actions), `ActionResult`, `GangProfile`, `TabDef`... strict, no `any` |
| `ui/button, input, switch, table, tabs, sheet, dialog, alert-dialog.tsx` | the reference's shadcn wrappers (Base UI flavour, `work/ui/*.jsx`) on `@base-ui/react` 1.8 |
| `ui/select.tsx`, `ui/badge.tsx`, `ui/use-toast.ts` | not in the page chunk; recovered verbatim from the site's shared chunks (archive `work/ui/*.recovered.jsx`) |
| `ui/pagination.tsx`, `ui/date-value.tsx`, `ui/fmt.ts` | their portal `Pagination` (+ shadcn base, `pageWindow`), `DateValue`, `FMT` |
| `app/pixel/page.tsx` | owner gate (`pixelAllowed` / `notFound()`), `metadata.title.absolute = "Armapunk Pixel — Altis"`, Geist / Geist Mono via `next/font`, `<div className="pixel-theme dark ...">`, `NuqsAdapter`, `PixelGame statics={reference/statics.json} canAccessCasino` |

The inline data tables of the bundle (`v` items, `k` chests, `C` sites...) are dead duplicates of
`statics`: nothing re-declares them; the only module-level lookup (`k[o.chest].name` in the pops)
reads `reference/statics.json`.

### Theme (globals.css, `/* pixel: reference theme, verbatim */`)

- `@import "tw-animate-css"` (their dialog enter/exit utilities) and the reference's variant
  mechanics: `@custom-variant dark (&:is(.dark *))` and the shadcn Base UI `data-open / closed /
  active / checked / unchecked / disabled / horizontal / vertical` variants compiled exactly as in
  their `site/*.css` (`:where([data-state=x]), :where([data-x]:not([data-x=false]))`). Registered
  globally; grep proved the portal uses none of these variants or class names.
- `@theme inline`: every semantic colour of `theme.css` (`--color-card: var(--card)`, `--color-primary-emphasis`, `--color-surface`, `--color-border-subtle`...) and the radius scale
  (`--radius-sm/md/lg/xl/2xl` = `.6 / .8 / 1 / 1.4 / 1.8 * --radius`) with the Tailwind defaults as
  fallback, so `rounded-*` outside `.pixel-theme` is unchanged. `--color-destructive-foreground` is
  deliberately absent (absent from their build too).
- `.pixel-theme` = their `:root` light set + `body`/`html` rules (background, colour, Geist,
  antialiasing); `.pixel-theme.dark` / `.dark .pixel-theme` = their `.dark` set. The page wrapper is
  `pixel-theme dark` (the portal is dark); drop `dark` for their light theme.
- `@layer base { .pixel-theme * { border-color: var(--border); outline-color: var(--ring) } }`,
  their custom utilities (`h-below-topbar`, `z-60`, `font-heading`, `font-sans`, `font-mono` to
  Geist Mono, scoped), and the three styled-jsx blocks (`.ap-street/.ap-wanted`, `.ap-char/.ap-jailed`,
  `.ap-pop`) verbatim without the `jsx-...` scoping suffix.
- Two portal rules are neutralized inside `.pixel-theme` with `revert-layer`: `.tabular-nums`
  (portal forces Space Mono at 0.95em) and `:focus-visible` (portal accent outline + 6px radius).

### Dependencies

Added: `@base-ui/react` 1.8.0, `nuqs` 2.10.1, `class-variance-authority`, `clsx`,
`tailwind-merge`, `tw-animate-css`; dev: `@testing-library/react`, `jsdom`, `@babel/parser`,
`@babel/traverse`, `@types/babel__traverse`. Removed: `pixi.js`. New: `src/lib/utils.ts` (`cn`).
`vitest.config.mts` carries the `@/` alias (both lanes need it).

### Tests (`src/components/pixel/__tests__`, `npx vitest run src/components/pixel`)

- `fidelity.test.ts`: `extract.ts` (Babel parse, one extractor for both sides) collects every
  string literal / template chunk / JSX text (JSX whitespace rules applied) and every class string
  (className-suffixed attributes and keys, `cn()` / `cva()` arguments) from every `.ts/.tsx` under
  `components/pixel` plus `app/pixel/page.tsx`, and asserts each is in the union of the archive's
  `reference_strings.json` / `reference_classes.json` and `derived_*.json` (the same extractor run
  over the de-minified page, `work/ui/*.jsx` and the recovered wrappers). Allowlist, each with a
  reason: the brand strings, the three `/api/pixel/` bases, next/font args, `force-dynamic`, the
  `"u"` typeof guard, Badge's `span`/`badge` (keyed differently in the chunk), class `pixel-theme dark`.
  Negative-probed: a mutated JSX text, string literal, attribute and class are all flagged.
- `PixelGame.smoke.test.tsx` (jsdom): mounts `PixelGame` with `state_example.json` behind a mocked
  `fetch`; asserts the "Landing at Kavala…" loader, the state query params, "$5.50M" / "$5,495,846",
  "LVL 100", "APD sees you at 22", the five city cards, "2 online", the Work tab and the rail.

### Deviations from the reference (the complete list)

Sanctioned: (1) brand string in the h1 and `<title>`; (2) API base `/api/pixel/`; (3) the player
comes from our Steam session (server side); (4) `next/head` replaced by page `metadata`
(`title.absolute` keeps the portal's title template off it; the reference's `<title className="">`
attribute has no equivalent). Everything else, listed so nothing hides:

- Toasts: `useToast()` keeps the recovered signature (`success / error / info (text, timeout?)`,
  error default 8 s) but drives sonner (the portal's toaster); the reference uses a Base UI toast
  manager with its own Toaster and 5 s default. Visual toast differs.
- Fonts: Geist / Geist Mono self-hosted by `next/font/google` on the wrapper (their variable names).
- Theme scoping: tokens on `.pixel-theme` instead of `:root` / `html.dark`; the portal shell
  (56 px topbar, which matches the reference's 56 px sticky offset; `max-w-6xl mx-auto px-4 py-6`
  content container around the page's own `max-w-screen-2xl px-4 pt-8 pb-20`; sidebar; dark
  scrollbars; the portal's `prefers-reduced-motion` 0.01 ms override, which the reference does not
  have) stays around the page. Fullscreen mode (`fixed inset-0`) escapes the shell as in the reference.
- Not in the page chunk, recovered from the site's shared JS chunks instead: `Badge` (all 17
  variants including `amber` / `accent`), the `Select*` wrappers (translucent popup, `z-70`
  positioner, `bg-card` trigger), `useToast`. Saved to the archive as `work/ui/*.recovered.jsx`.
- styled-jsx scoping tokens (`jsx-3f46096a1f042a87`, `jsx-60ed9125e79421a2`) dropped from
  classNames (build artifacts; the CSS is global in the pixel block).
- JSX text containing `'` or `"` is written as `{"..."}` containers (ESLint
  `react/no-unescaped-entities`); rendered text identical.
- Typing shims, behaviour-identical: `A && el ?` narrowing of the snapshot in the page;
  `inventory[site.input ?? ""]`; `custody?.job` guards on `prisonrotate` / `prisoncomplete` and
  `apdCase?.id ?? ""` / `duel?.id ?? ""` where the reference dereferences unconditionally (all only
  fire when the object exists); `Select onValueChange={(e) => x(e ?? m)}` (Base UI types `null`,
  never emitted for this select); `56 * Number(!er)`; `optionIcon()` for `tu[a] ?? HelpCircle`;
  `Pagination` typed on `HTMLAttributes<HTMLElement>` for its `<a>` / `<button>` render branches.
- Structure only: the inline hook is `usePixelClient`, the chat merge is `mergeChat`, the gang
  fetch hook is `useGangProfile`, gang member row / XP bar / bonus chips live in `GangBits.tsx`
  (shared by the tab and the directory), the casino card parser is `parseCard`; the minified
  comma / `&&` expression statements are plain statements; chained `const a = useMemo(), b = ...`
  declarators are split (React Compiler lint).
- Lint annotations on the reference's own patterns (`eslint-disable` with the reason): ref written
  during render (`ChatPanel`), `Date.now()` during render (gang privacy countdown), setState inside
  effects (`useGangProfile` reset, fullscreen preference restore, `DateValue`).
- `react-hooks/exhaustive-deps`: the unmount cleanup of `usePixelClient` captures the in-flight
  controller set in a local (same `Set` object) instead of reading `$.current` in the cleanup.
- The v2 page fetched the first snapshot server-side; v3 does what the reference does: client
  poll, "Landing at Kavala…" until the first response.

### Not verifiable headless

Visual result in a browser (Tailwind output, Base UI sheet / dialog / select popups, Geist),
the `revert-layer` neutralizations, sticky offsets against the real topbar, fullscreen API and
Escape handling, the polling / back-off / 429 path against the real routes, chat scroll anchoring,
toasts. `npx tsc --noEmit` (zero errors), `npx eslint src/components/pixel src/app/pixel` (zero
problems) and `npx vitest run src/components/pixel` (5 tests) are green; `npm test` whole-project
green at hand-off. The owner opens `/pixel` next to the reference.

## Verification

- `npm test` (vitest): engine + content tests, red before green.
- `npm run build` clean (TS + lint).
- Deploy smoke (`push-96.sh`): `/pixel` and `/api/pixel/state` → 200 as the owner session and
  **404 as a minted non-owner session**; `/api/pixel/action` gather round-trip changes the bag.
- What headless cannot prove: the Pixi scene renders; the owner eyeballs `/pixel` in a browser.

## Residual decisions taken

- JSONB state instead of normalised tables: one player row per action, no joins, trivially
  versioned (`state.v`); market rows are separate because they are shared between players.
- Polling (5 s) instead of a socket: the portal has no socket server and the game's pace does not
  need one.
- The black market fence lives in La Pessagne (the mission's Black Market marker); the northern
  cartel names label Larche's illegal sites rather than being towns of their own.

## Status 2026-09-10 14:20 CDT

**Built and live on `.96:3011` behind the owner gate (commit `c49590c5`).** Engine 116 vitest cases
(rules 1-15, content, parser, format) green; `tsc`, lint and `next build` clean; deploy smoke green:
owner session 200 on `/pixel` and `/api/pixel/state`, a minted non-owner session 404 on both, bad
action 400. `web_pixel_*` created on the box, `armapunk_web` writes proven. Engine decisions taken by
the worker and kept: sell/drop clamp `n` to what is held; `reset` is allowed while travelling;
`siteBlock()` is shared by `apply` and `view` so lock reasons cannot drift; every site view entry
carries its own `crewCost` (the hire action charges exactly that). Content gap caught by the content
test: Larche had no free level-1 site, fixed with the Hillside Orchard (52 sites).

**Not provable headless:** the PixiJS map renders and the panels feel right. The owner opens
`https://armapunk.com/pixel` (signed in) and looks. Balance numbers are first-pass; tune in
`content.ts` / `RULES`, each change through its test.
