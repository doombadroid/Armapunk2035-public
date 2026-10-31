# Cyberdeck — Approved Feature Backlog (`cdfeatures.md`)

Approved 2026-07-19. All build on the shipped cyberdeck (see `cyberdeck.md`): **Sequence Breach** = hex-grid buffer; **Terminal Breach** = type Linux commands vs the trace. Reuse the charge config (`Cyber Crime` $10k / `Breaking & Entering` $10k) + the two minigames. **Everything server-authoritative** — CLANKR trusts nothing client-side.

---

## 1. Loonazon package steal (removed 2026-09-02)
- **What:** hack a Loonazon delivery van mid-route → **disable it in place** (immobilize where it stands, NOT shoot the engine), then loot the package.
- **How:** Sequence Breach on the van (cursorObject in range) → on success the van is engine-killed + locked for a window and the parcel drops/grants to the hacker.
- **Ties:** `fn_loonazonSRV` / the HC-autopilot van + the existing **robbery event** (disable van → redzone) — reuse that disable path, triggered by hack instead of damage. Porch Pirate synergy.
- **Risk/guardrails:** alarm pings the recipient (+ maybe MaxSec); Cyber Crime charge; cooldown; only mid-delivery vans.

## 2. ATM jackpot
- **What:** hack an ATM → **jackpot-style random payout $100–$50,000** (cap 50k).
- **How:** Sequence Breach on an ATM → server rolls a weighted-random payout (mostly small, rare big — tune the curve so it's not a printer) → silent alarm pings MaxSec.
- **Ties:** ATM objects + skimmer code.
- **Risk/guardrails:** per-ATM cooldown (no farming one machine) + per-player cooldown; wanted (Cyber Crime); alarm so cops can respond; payout rolled + granted server-side only.

## 3. Any-vehicle engine-kill — "Hack Ignition"
- **What:** hack any vehicle in range → engine dies and **won't restart ~20-25s**. Works on ANY vehicle. **Folds in the existing `engineKillSwitch` item** (one-device theme, like lockpick/drill/usb).
- **How:** scroll "Hack Ignition" within ~25m → quick **4-symbol Sequence Breach** (short so a passenger can do it mid-chase) → server adds an **`"Engine"` EventHandler** to the target that force-`engineOn false` on any start attempt for the window; fire one `engineOn false` up front; remove the EH after.
  - **Why the EH, not a polling loop:** event-driven (fires only on a start attempt) → cheap, authoritative, instant re-kill of every restart.
- **Ties:** `AP_engineKillSwitch` (subsume it).
- **Guardrails (abusable — important):** only **occupied or recently-moving** vehicles (can't brick parked empties); per-hacker **and** per-vehicle cooldown (~45-60s); short window; small wanted bump.

## 4. Market manipulation
- **What:** hack the dynamic-market board → spike or crash **one** resource price for ~5 min → insider buy/sell.
- **How:** Terminal Breach at a market terminal → pick resource + direction → temporary server-side price override, broadcast.
- **Ties:** dynamic market (two-sided/drift/regional + phone board).
- **Risk/guardrails:** per-resource + per-player cooldown; the swing is **visible + logged** (cops/CLANKR flag repeat abuse); cap the swing %; Cyber Crime; server-authoritative price.

## 5. Bank micro-siphon
- **What:** digital skimmer — deck siphons a % of nearby ATM/bank transactions for a window.
- **How:** Terminal Breach near a bank/ATM → plant a siphon → for N min, X% of others' deposits/withdrawals in range trickle to the hacker.
- **Ties:** ATM skimmer (`fn_atmSkimSRV`) — digital cousin.
- **Risk/guardrails:** capped total per window; cooldown; victims see a small "fee"/log → traceable; Cyber Crime.

## 6. Counter-hack
- **What:** when your rig/house gets hacked, you get a short trace-back window to hack the attacker (steal back / mark them wanted).
- **How:** on a successful breach against you (`houseBreach` / `cryptoTakeover`), the victim gets a toast + a time-limited "Trace" → a Terminal Breach → success = reclaim (relock / reassign the rig) + wanted-mark the attacker.
- **Ties:** `fn_cyberdeckSRV` houseBreach / cryptoTakeover.
- **Guardrails:** window only; needs the victim online with a cyberdeck.

## 7. ICE talent (defense)
- **What:** Hacker-tree defensive talent — attackers face **harder** breaches on YOUR house/rig (+symbols on Sequence, +commands on Terminal).
- **How:** when computing a breach's difficulty (bufLen / cmd count), add the **defender's** ICE rank.
- **Ties:** Hacker talent tree (250-256), `fn_cyberdeckSeq` bufLen, `fn_cyberdeckTerm` `_N`.
- **Note:** pure defense, no grief surface.

## 8. Wardrive scan
- **What:** deploy the deck → briefly reveals nearby hackable targets (locked vehicles, rigs, safes, ATMs) on the map for a radius.
- **How:** scroll/phone action → server returns nearby hackable objects → temp map markers ~30s.
- **Ties:** map markers + the hackable-object registries.
- **Guardrails:** cooldown; radius cap; markers fade.

## 9. Hacker contract board
- **What:** phone app handing out randomized, **repeatable** hack jobs ("crack X for $Y; cops get pinged"). Endless hacker missions.
- **How:** phone app (like Loonazon/quests) → rotating server-issued contract (target type + reward) → complete the hack → payout scaled to difficulty.
- **Ties:** quest / anti-cheese framework (`fn_questMenu`, `AP_completedQuests`), phone app registry.
- **Risk/guardrails:** cooldown between contracts; server-issued targets + payouts (no client trust).

## 10. Logic bomb
- **What:** plant a **delayed** hack on a car/house/rig that triggers minutes later (timed payback/sabotage).
- **How:** hack (Sequence/Terminal) to ARM a bomb on the target → after a timer the effect fires (lock, engine-kill, rig-hijack, door-open).
- **Ties:** whichever target system it's armed on.
- **Guardrails:** the victim gets a **faint warning ping** when armed and can **counter-hack to disarm** before it blows; cooldown; Cyber Crime on arm.

---

### Build-order suggestion
1. **Quick wins** (reuse minigames + one action gate): Hack Ignition, ATM jackpot, Wardrive scan.
2. **Economy:** Market manipulation, Bank micro-siphon.
3. **Systems:** Loonazon package steal, Counter-hack, ICE talent, Logic bomb, Hacker contract board.
