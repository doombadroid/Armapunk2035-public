# Casino phone app — build plan

**V1 = BLACKJACK ONLY** (owner 2026-07-05 "start with blackjack only"). Slots = V2 (deferred; §7).

Owner spec: **bank-funded** (`AP_atmcash`), **high-roller $10k–$500k**, **house-favored** (blackjack **6:5**, dealer stands on 17), **playable anywhere except** jailed/restrained or downed/in-combat (**wanted players allowed**). Solo (you vs the dealer). Phone app, no physical casino/zone. Icon = **`icons\Casino.paa`** (✅ done — the deob's tuxedo donor icon `phone_donate.paa`, copied + renamed neutral into mission `icons/`).

## 1. Architecture

Phone app **"Casino"** (VIP icon) → opens the **Blackjack** dialog directly (V1 has one game; a landing screen is added in V2 when slots lands). Server owns the deal + dealer AI + payout; client is display-only.

```
Phone (Y) → Casino app → Blackjack dialog
  client: bet → APS_fnc_blackJackSRV (shuffle/deal)         → deal callback → render cards
  client: hit/stand/double → APS_fnc_blackJackSRV (resolve) → result callback → render + server-gated credit
```

**Security spine (non-negotiable — gambling.md §8 + security.md §2.4):**
- Server (`APS_fnc_blackJackSRV`) owns the shuffle, deal, dealer play, and the payout **amount**; **gates the credit**.
- Caller identity from `remoteExecutedOwner` → `(allPlayers select {owner _x isEqualTo _src}) param [0,objNull]`. **Never** trust a player/uid in the payload.
- Bet debit client-side (`["atm","take",_bet] call AP_fnc_uC`) — architectural limit (`AP_atmcash` is a client cache). Server **nets** the game: only credits the server-computed payout, **never echoes the bet**, and **logs the wager** for CLANKR mass-balance.
- Credit only to the betting client, server-gated: `[["atm","add",_payout],"AP_fnc_uC",_caller,false,false] spawn AP_fnc_MP`, OR dedicated `fn_blackJackReceive` with `if (remoteExecutedOwner != 2) exitWith {}`. `AP_fnc_uC` already CfgRE-whitelisted (allowedTargets=1).
- Persist `[1] call AP_fnc_ClupdatePartial` (bank). Server clamps per-bet $500k + a ~1.5s per-caller cooldown + tracks in-progress hand state server-side (client can't re-request a resolve).
- **Mirror `fn_copSplit.sqf` (server) + `fn_copSplitReceive.sqf` (client receiver).**
- Hand state (dealt cards, bet) lives **server-side** keyed by uid, not on the client — the client only knows what the server told it to render. Prevents "re-deal until I win" / forged hands.

## 2. Reusable Asylum assets (deob → `scratchpad/a1013_casino/`)

- **52 card faces** + `backside.paa` + felt bg → re-skin neutral, re-path into `images/casino/`.
- `fn_blackJack.sqf` (748 lines) + `black_jack.hpp` (idd 7700) = **reference only** — full-screen table layout → re-lay-out phone-sized; money made server-authoritative (Asylum's is client-credit — do NOT copy that).
- Asylum strings scrubbed, assets renamed neutral (no-foreign-refs rule).

## 3. File manifest (V1 blackjack)

**New — client (`mission/LooneyBin.Altis/`):**
- `core/casino/fn_casinoApp.sqf` — phone-app entry (opens blackjack; clone `core/pmenu/fn_money.sqf`)
- `core/casino/fn_blackJack.sqf` — blackjack client (adapt Asylum skeleton → phone layout; send bet/choice, render server results)
- `core/casino/fn_blackJackReceive.sqf` — server-gated payout receiver (clone `fn_copSplitReceive.sqf`)
- `dialog/blackjack.hpp` (idd 930000) — phone-framed; reuse PhoneWallpaper 90300 + HomeButton idc 1005; clone `money.hpp`/`mental_input.hpp`
- `images/casino/` — re-skinned cards + felt; (`icons\Casino.paa` = app icon, owner-provided)

**New — server (`server/AP_server/`):**
- `core/TON/fn_blackJackSRV.sqf` — shuffle/deal/dealer-AI/resolve/payout + identity + clamp + logging (clone `fn_copSplit.sqf`)

**Edits:**
- `core/configuration.sqf` — `AP_phone_buttons` += `["Casino","icons\Casino.paa","[] spawn AP_fnc_casinoApp",{playerSide isEqualTo civilian && !AP_restrained},"Play blackjack"]`
- `Functions.h` — register casino client fns (casinoApp/blackJack/blackJackReceive)
- `dialog/MasterHandler.h` — `#include "blackjack.hpp"` (grep-verify after — b0101 footgun)
- `CfgRE.hpp` — `class APS_fnc_blackJackSRV{allowedTargets=2;}` (~L750)
- `server/AP_server/config.cpp` — register `blackJackSRV` in Renamed_TON (~L300)
- `dialog/smartphone.hpp` — add `ButtonTwentyFive idc=90224` (24-slot ceiling safety)
- `loonybot/clankr.py` + `config.json` — `-CASINOWIN-`/`-CASINOLOSS-` net-gain rule (payout $ first in the log string)

## 4. Blackjack rules (per spec)

Server shuffle + deal, dealer **stands on 17** (incl. soft-17, standard), **blackjack pays 6:5**, bet $10k–$500k from **bank**. Actions: **hit / stand / double / split** (full). Server resolves each hand; outcomes → payout (BJ 6:5, win 1:1, push 0, loss −bet). Split = up to N hands, per-hand bet debited (bank must cover), split-aces get one card each, resolve each hand vs the dealer. Client renders cards + choice buttons per active hand.

## 5. Build phases (V1)

1. **Money spine + CLANKR** — `APS_fnc_blackJackSRV` skeleton (identity/clamp/cooldown/log/server-side hand state) + receiver + CfgRE + `config.cpp` + trivial test payout. Prove the secure round-trip first.
2. **Blackjack core** — server shuffle/deal/dealer/resolve + payout math; client bet + hit/stand/double + render (Asylum card art, phone layout).
3. **App wiring + restrictions** — VIP icon, registry entry, `!AP_restrained`/downed/combat gates, status bar, balance pass.
4. **Adversarial verify** — can a client forge a win / spoof identity / replay a payout / re-deal / exceed caps? Fix before ship. Stage on `doomba`, deploy via repack flow.

## 6. Open decisions

- **Icon** — ✅ resolved (`icons\Casino.paa`).
- **Blackjack scope** — ✅ FULL incl. split (owner 2026-07-05). Server hand-state is an array of hands per player; each hand carries its own bet + cards + status (active/stood/busted/done).

## 8. Progress log

- **2026-07-05 — Phase 1 (server spine) DONE, unwired-to-client:**
  - `server/AP_server/core/TON/fn_blackJackSRV.sqf` — full engine (deal/hit/stand/double/split/dealer/resolve/payout 6:5, server-held hand state `AP_bjGames` keyed by uid, `remoteExecutedOwner` identity, $10k–$500k clamp, 0.2s cooldown, `-CASINOBJ-`/`-CASINOBET-` logging).
  - `mission/.../core/casino/fn_blackJackReceive.sqf` — `owner==2`-gated bank credit.
  - `CfgRE.hpp` — `APS_fnc_blackJackSRV` (allowedTargets=2) + `AP_fnc_blackJack`/`AP_fnc_blackJackReceive` (allowedTargets=1).
  - `config.cpp` — `class blackJackSRV {}` in Renamed_TON.
  - Icon `icons/Casino.paa` in place.
- **NEXT — Phase 2/3 (client + wiring + assets):** `dialog/blackjack.hpp` (phone-framed table), `core/casino/fn_blackJack.sqf` (render server `_view` + bet/hit/stand/double/split buttons + restriction gate), `core/casino/fn_casinoApp.sqf` (phone entry), register in `Functions.h`, `#include` in `MasterHandler.h`, app tuple in `configuration.sqf` `AP_phone_buttons`, `ButtonTwentyFive` in `smartphone.hpp`, re-skin 52 cards → `images/casino/`, CLANKR net-gain rule. Then adversarial verify the engine + pack-test.

## 7. V2 (later) — Slots

3-reel, server RNG, ~88% RTP paytable, new slot-symbol art, added as a second game behind a Casino landing screen. Nothing from Asylum (they had no slots).
