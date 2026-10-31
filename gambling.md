# Gambling / Casino — how A1013 (Asylum) built it

Reverse-engineered from the A1013 mission deobfuscation (`/tmp/a1013_re`, extracted from
`A1013_Altis_Life_deobfuscated.Altis.zip`). This is the **client (mission) side only** — the deob is a mission
PBO, so the server functions (`APS_fnc_*SRV`) that hold the RNG, card dealing, payout math, and the lottery pool
are NOT present and have to be inferred from the client↔server message protocol (and rebuilt if we port it).

LooneyBin does NOT currently have any of this. This doc is the reference for porting it (cleanly, server-authoritative,
foreign-refs scrubbed).

---

## 1. What it is

A casino district (the `casino_marker` zone) with three games:

| Game | Client fn | Dialog | Server fn(s) | Bankroll |
|---|---|---|---|---|
| **Roulette** | `core/casino/fn_roulette.sqf` (~500 lines) | `dialog/roulette.hpp` (idd **7800**) | `APS_fnc_rouletteSRV`, `APS_fnc_casinoTracker` | cash (`AP_cash`) |
| **Blackjack** | `core/casino/fn_blackJack.sqf` (~900 lines) | `dialog/black_jack.hpp` (idd **7700**) | `APS_fnc_blackJackSRV`, `APS_fnc_casinoTracker` | cash (`AP_cash`) |
| **Lottery** | `core/actions/fn_lottoTix.sqf` | (NPC `BIS_fnc_guiMessage` prompt) | `APS_fnc_add2Lotto` | bank (`AP_atmcash`) |

Plus `core/casino/fn_casinoBan.sqf` (per-restart table ban) and a no-crime safe-zone keyed on the `casino_marker`.

Server fns are CfgRE-whitelisted (`CfgRE.hpp`): `APS_fnc_rouletteSRV` (754), `APS_fnc_blackJackSRV` (751),
`APS_fnc_casinoTracker` (757), `APS_fnc_add2Lotto` (592) — all `allowedTargets=2` (client→server).

---

## 2. Architecture / message protocol

Every game is a **dispatcher fn**: `[_caseType, _data] call AP_fnc_<game>`. The dialog buttons and the server
callbacks all re-enter the same fn with a different `_caseType` string.

Client→server (the player acts) and server→client (results) both ride `remoteExec`/`AP_fnc_MP`:

```
ROULETTE
  client: ["registerBet", [player, _type, _amount]] remoteExec ["APS_fnc_rouletteSRV", 2]
  server: ["payout", [_type, _payout, _loss, _kickPlayer]] -> AP_fnc_roulette   (on the betting player)
  exit:   [player, "roulette", wagered, won] remoteExec ["APS_fnc_casinoTracker", 2]

BLACKJACK
  client: ["registerBet", [player, tableObject, _amount]]      remoteExec ["APS_fnc_blackJackSRV", 2]
  client: ["sendChoice",  [player, tableNumber, _action]]      remoteExec ["APS_fnc_blackJackSRV", 2]   // hit/stand/double/split
  server: ["endGame", [_id, _payout, _loss, _kickPlayer]] -> AP_fnc_blackJack   (on the player)

LOTTERY
  client: [player] call AP_fnc_MP -> "APS_fnc_add2Lotto"     // buy a ticket (adds you to the pool)
  server: [2, _amount] -> AP_fnc_lottoTix                    // you won the jackpot
```

The server callbacks are protected by **`AP_fnc_checkSender`** (rejects the call unless it actually came from the
server — anti-spoof) and **`AP_fnc_checkIntegrity`** (SpyGlass anti-cheat). Both matter a lot for security (§8).

Per-table state lives on the **table object** as `setVariable`s the server populates: `ga_roulette_data`,
`ga_blackjack_data`, `ga_blackjack_p`. The client reads these (e.g. `_table getVariable ["ga_roulette_data", []]`).

---

## 3. Roulette (`fn_roulette.sqf`, dialog idd 7800)

A simplified **colour-only** roulette: bet on RED / GREEN / BLACK. Not the full 0–36 number board.

- **Bet types** (`placeBet [_type]` from the dialog buttons): `0 = RED`, `1 = GREEN`, `2 = BLACK`.
- **Bet amounts** (`_betOptions`): `[5000, 10000, 15000, 25000, 50000, 100000]` — a listbox; `lbValue` = the amount.
- **Per-colour cap**: $100,000 total on one colour (`(_amount + _currentBet) > 100000` rejects).
- **Per-bet cap**: `_amount > 999999` rejects; must be `>0` and `<= AP_cash`.
- **Assets**: `images\casino\roulette_red.paa` / `roulette_green.paa` / `roulette_black.paa` (the wheel slots).

**Flow** (the `switch (_caseType)`):
1. `init [_table]` — opens the game. Guards: `AP_casino_closed`, `AP_casino_playing`, `playerSide==civilian`,
   `AP_casino_banned`. Sets `AP_casino_playing=true`, `AP_casino_tableObject=_table`, `AP_casino_track=[0,0]`
   (`[wagered, won]`), spawns a fixed **camera** (`AP_casino_cam`) framing the table, reads `ga_roulette_data`.
2. `startBet [_timer]` (default 10s) — opens betting, runs a countdown (`AP_casino_bet=true` during the window).
3. `placeBet [_type]` — validates, **debits client-side** `AP_cash -= _amount` + `ClupdatePartial`, tracks
   `AP_casino_track[0] += _amount`, then `registerBet` to the server. Updates the RED/GREEN/BLACK on-screen totals.
4. server spins → `payout [_type, _payout, _loss, _kickPlayer]`:
   - `_type=0` → loss (stat `casinoloss` only, no cash).
   - `_type=1` → win → **credits client-side** `AP_cash += _payout` + stat `casinogain` + `-CASINOROULETTE-` log.
   - `_kickPlayer=true` → `["ban"] call AP_fnc_casinoBan` + exit (server-flagged cheat).
   - tracks `AP_casino_track[1] += _payout`.
5. `exitGame` — tears down the camera/dialog, and (for non-admins) sends `casinoTracker [player,"roulette",wagered,won]`.

---

## 4. Blackjack (`fn_blackJack.sqf`, dialog idd 7700)

Full multi-table blackjack with **hit / stand / double / split**. Tables are numbered
(`AP_casino_bj_tableNumber`) and identified by object (`AP_casino_bj_tableObject`).

- **Deck**: `AP_blackJackCardArray` = the standard 52 (`C2`..`CA`, `D…`, `H…`, `S…`) with values (face=10, A=1 base;
  soft-ace handled server-side). Card faces are `images\casino\<card>.paa`; the back is `images\casino\backside.paa`.
- **Bet amounts** (`_betOptions`): `[10000, 15000, 20000, 25000, 40000, 50000]`.
- **Card deal animation**: `_cardDealSpeed = 0.5`s, positions in `_cardPosArray` (5 player seats + dealer slot).
- Dialog buttons → `sendChoice`: `hit` / `stand` / `double` / `split`; plus `placeBet` and `exitGame`.

**Flow**:
1. `init` / `placeBet` — bet (debited client-side), `registerBet` to server → server deals.
2. `sendChoice [action]` — `["sendChoice",[player, tableNumber, _action]] remoteExec APS_fnc_blackJackSRV`. Server
   resolves the hand (deals cards, dealer plays, computes the result).
3. server → `endGame [_id, _payout, _loss, _kickPlayer]` (checkSender + checkIntegrity guarded). `_id` outcomes:
   - `1` = player busted (loss).
   - `2` = dealer busted (win).
   - `3` = blackjack (win — pays the BJ bonus, e.g. 3:2).
   - `4` = beat the dealer (win).
   - `5` = push (original bet returned).
   - `6` = other win.
   - All winning cases **credit client-side** `AP_cash += _payout` + stat `casinogain` + `-CASINOBLACKJACK-` log.

The dealing logic, dealer-stands-on-17, soft-ace, split/double resolution, and the payout amounts all live in the
**server fn `APS_fnc_blackJackSRV`** (not in the deob).

---

## 5. Lottery (`fn_lottoTix.sqf`)

A periodic jackpot the server draws.

- **Ticket price**: `$2000`, paid from **bank** (`AP_atmcash`). Rate-limited (`scriptAvailable(4)`).
- `_mode 0` — show the current jackpot (`AP_lotteryVal * 1000`).
- `_mode 1` — buy: confirm prompt → `[player] call AP_fnc_MP -> "APS_fnc_add2Lotto"` (server adds you to the pool),
  debit `AP_atmcash -= 2000`, stat `lottoloss`.
- `_mode 2` — **win** (server callback, checkSender guarded): credit `AP_atmcash += _amount` to **bank**, stat
  `lottowin`. The jackpot accumulates server-side and is paid to a drawn winner.

Server-side (`APS_fnc_add2Lotto` + a draw timer, not in the deob): tracks ticket holders, grows `AP_lotteryVal`,
draws a winner on a schedule, and calls `[2, _amount]` back to that winner.

---

## 6. The casino zone (`casino_marker`)

A map marker that defines a safe / no-crime district. Other systems check distance to it:
- `fn_moonshineLab.sqf:79`, `fn_crankLab.sqf:79` — labs blocked within **250 m**.
- `fn_onFired.sqf:103` — firing weapons blocked within **350 m** (no shooting in the casino).
- `fn_useItem.sqf:416`, `fn_pocketCars.sqf:17` — deployables / pocket-cars blocked within **350 m**.

So porting needs a `casino_marker` placed in Eden/mapData and these guards (LB equivalents) added.

---

## 7. Casino ban (`fn_casinoBan.sqf`)

A **per-restart** table ban (e.g. for a server-flagged cheater via `_kickPlayer`).
- Stored in **`profileNamespace`** as `ga_casino_ban = [ASY_instance_id, true]` (the instance id ties it to the
  current restart; cleared when the id changes).
- `"check"` → reads it, sets `AP_casino_banned`. `"ban"` → sets it + messages the player.
- ⚠️ **Client-side only** — `profileNamespace` is fully attacker-controlled (see security.md §1.1), so a cheater can
  wipe the ban. A real ban must be server/DB-enforced if we want it to stick.

---

## 8. Money flow + SECURITY (read before porting)

**This is the part LB must NOT copy verbatim.** A1013's casino is **client-trusted money**:

- The **bet is debited client-side** (`AP_cash -= amount` / `AP_atmcash -= 2000`).
- The **payout is credited client-side** (`AP_cash += _payout`) when the server's `payout`/`endGame`/win callback
  fires.

This is exactly the *"client credits itself"* money-printer class flagged in **security.md §2.1** (cf.
`APS_fnc_createItem`, the exchange/chop-shop bugs). A1013 mitigates it with two client guards:
- `AP_fnc_checkSender` — the credit case bails unless the callback genuinely originated from the server (id 2),
  blocking a client from `remoteExec`-ing `payout`/`endGame` at itself.
- `AP_fnc_checkIntegrity` — the SpyGlass anti-cheat.

**Both are gone / unavailable in LB**: SpyGlass was removed entirely; `AP_fnc_checkSender` would have to be ported.
And even with them, the cash mutation is client-side — one bypass = free money. So for LooneyBin:

> **Make payouts server-authoritative.** The server fn (`AP_fnc_*SRV`) should debit the bet AND credit the winnings
> against the player's **server-side** cash/bank (the authoritative DB value when needed), and only *notify* the client
> for UI. Mirror the established LB pattern (server recompute + `remoteExecutedOwner` identity check) from the §2.4
> security fixes. The client should never touch `AP_cash`/`AP_atmcash` for a gambling result.

CLANKR already has cash-rule plumbing (`-CASINOROULETTE-` / `-CASINOBLACKJACK-` logs feed it) — keep those tags and
add a per-player net-flow rule to catch anomalous casino gain.

---

## 9. What's MISSING from the deob (must be rebuilt server-side)

The mission deob has the client + dialogs only. These server fns hold the actual game logic and are NOT present:
- `APS_fnc_rouletteSRV` — the RNG spin, resolve each colour bet, compute payout, anti-cheat, write `ga_roulette_data`.
- `APS_fnc_blackJackSRV` — shuffle/deal, dealer AI, hit/stand/double/split resolution, payout (incl. BJ 3:2), seats.
- `APS_fnc_add2Lotto` + the draw loop — ticket pool, jackpot growth, scheduled draw, winner payout.
- `APS_fnc_casinoTracker` — per-player net wagered/won bookkeeping.
- The **table setup**: whatever spawns the roulette/blackjack table objects, seeds `ga_roulette_data` /
  `ga_blackjack_data`, and attaches the scroll-wheel `addAction` that calls `["init",[_table]] call AP_fnc_<game>`
  (not in the deob — server-side spawn + remoteExec'd actions).

These are the heart of the feature and where the house-edge / fairness lives. They must be authored fresh for LB
(clean-room — and we *want* to, to be server-authoritative anyway).

---

## 10. Porting plan for LooneyBin

1. **Scrub all foreign refs** (no-foreign-refs rule). Rename on import:
   - `ASY_instance_id` → the LB instance id; `ga_*` → `AP_*` (`ga_roulette_data`→`AP_roulette_data`,
     `ga_blackjack_data`/`ga_blackjack_p`, `ga_casino_ban`, `ga_roulette`).
   - Strings: `"Asylum Casino"`, `"Asylum Lottery"`, `"Asylum - Roulette"` bar text, `"Asylum Lottery Commission"`
     → LooneyBin equivalents.
   - `AP_fnc_*` casino fns → keep `AP_fnc_` (LB convention) but register in Functions.h.
2. **Assets** — `images\casino\` (roulette_red/green/black, backside, the 52 card faces). Re-create / re-skin
   neutral (mission-embedded, like the cyber Ifrit textures).
3. **Server-authoritative rebuild** — author `AP_fnc_rouletteSRV` / `AP_fnc_blackJackSRV` / lottery+draw /
   tracker. Server debits the bet + credits the win against authoritative cash/bank. Pick a house edge (roulette
   colour odds, BJ rules, lottery rake). Whitelist them in CfgRE `allowedTargets=2`, and the *result* callbacks
   `allowedTargets=1` (server→client is exempt on our server, but list them for clarity).
4. **Casino zone** — place a `casino_marker`, add the LB-side no-lab / no-fire / no-deployable guards (250/350 m).
5. **Casino ban** — back it with a DB/server flag, not just `profileNamespace`.
6. **Anti-cheat** — keep the `-CASINOROULETTE-`/`-CASINOBLACKJACK-` logs; add a CLANKR net-gain rule. Don't rely on
   SpyGlass (removed) or client `checkIntegrity`.
7. **Caps / balance** — A1013 used $100k/colour, $5k–100k roulette chips, $10k–50k BJ, $2k lotto. Re-tune for the
   LB economy before launch.

---

*Source: A1013 mission deob (`/tmp/a1013_re/core/casino/`, `dialog/roulette.hpp`, `dialog/black_jack.hpp`,
`core/actions/fn_lottoTix.sqf`). Server-side game logic inferred from the client message protocol.*
