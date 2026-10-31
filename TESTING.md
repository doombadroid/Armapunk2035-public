# TESTING — LooneyBin (deployed this session, not yet live-verified)

Check off as confirmed. `[SOLO]` you alone (owner/admin powers ok) · `[2P]`/`[3P]` need other players.
Repro is in-game actions (no console paste on this client). Watch for the noted expected result.

## 🔴 Highest priority — money / dupe (verify first)

- [ ] **Gang bank** `[SOLO, need a gang]` — interact with the gang ATM.
      Expect: balance LOADS (not stuck "Loading…"). Deposit $X → fund up, cash down. Withdraw $X →
      reverse. Withdraw MORE than the fund → rejected, no money created.
- [ ] **Wire transfer** `[2P]` — at an ATM, wire $X to another player.
      Expect: they receive $X, you lose $X. (Was broken: money vanished — receiver got nothing.)
- [ ] **Inventory dupe (store)** `[SOLO]` — put a stackable item in a vehicle trunk, wait ~3 s, relog.
      Expect: item is in the trunk ONLY, not also back in your inventory.
- [ ] **Buy/sell money dupe** `[SOLO]` — buy a virtual item, relog within ~2 s.
      Expect: you keep the item AND the cash stays spent (no cash-back-keep-item).
- [ ] **Vehicle sell** `[SOLO]` — sell a garaged vehicle.
      Expect: bank credited the sell price exactly once (no double-credit on a fast double-click).
- [ ] **Cartel tax** `[2P+, captured cartel]` — a gang controls a cartel (drug/oil/wongs/arms); a
      player NOT in that gang processes there.
      Expect: the controlling gang's bank rises by the tax cut. (Also: no server lag buildup near cartels.)
- [ ] **Medic split** `[3P]` — a medic revives a downed player with another TT medic nearby.
      Expect: BOTH medics get a payout (reviver + partner each a share). "Medical assist payout" message.

## Connection / respawn

- [ ] **Reconnect-in-place** `[SOLO]` — log out in the field (away from a spawn), reconnect.
      Expect: you spawn where you logged out, not the spawn menu / town. Crash test (kill the client):
      reconnect → within walking distance of where you were.
- [ ] **Bleedout timer = 30 min** `[SOLO]` — die as civ.
      Expect: bleed timer counts from 30:00 (respawn button still unlocks ~36 s in). #41 corpse persistence
      already confirmed; just sanity-check the new duration.

## Gang

- [ ] **Gang ownership transfer** `[2P, gang]` — as gang owner (rank 1), transfer ownership to a member.
      Expect: they become owner, you demote. Reopen the gang menu → ranks correct. Persists on relog.
- [ ] **Gang tag** `[2P]` — set a gang tag in the gang menu.
      Expect: the tag shows network-wide (e.g. death messages read "[TAG] Name").
- [ ] **Gang menu** `[2P, gang]` — open gang management.
      Expect: members list populates; promote / kick / disband all work (earlier fix).

## Vehicle / heli

- [ ] **Vehicle repair** `[SOLO]` — damage a vehicle, store it, use the garage repair option, pull it.
      Expect: it comes out undamaged.
- [ ] **enableCoPilot** `[2P]` — fly a heli with a passenger aboard; die as the pilot.
      Expect: the passenger gets "you've got the controls" + can fly/land (not an automatic crash).
- [ ] **adminDelVeh** `[SOLO, admin ≥3]` — look at a vehicle, press the bound delete key (User Action 211).
      Expect: it despawns; if owned, the owner can re-pull it from the garage (not permanently destroyed).

## PvP

- [ ] **Duel arena** `[2P]` — courthouse duel NPC → invite a player + set a wager → they accept at the
      courthouse.
      Expect: both pay half the wager → teleport to the arena → first to 2 kills → winner gets 90% of the
      pot → both restored to pre-duel loadout/position. Refund if it fails.

## Passive (not interactive — check server logs)

- [ ] **wacClient** — if anyone equips restricted gear or trips the memhack report, the server RPT logs
      `912` (illegal equipment) / `913` (tamper report). Advisory only (no auto-kick).

---
Earlier this session's BUGS.md fixes (VON, side chat type-only, oil cartel, news broadcast, turf capture,
VDM karts, #40 group password, #44 chop claim, #23 restrain, #43 Orca rotor) — re-verify from BUGS.md if
not already confirmed.


---

# TESTING — the phone/deck retirement pass (b0548, 2026-08-14)

Everything below shipped in one branch (`feat/staff-deck`, PR #15). None of it is
live-verified. `[SOLO]` you alone · `[2P]` needs a second player · `[⚠]` destructive.

## 🔴 First — the two breach minigames replaced live gameplay

These gate lockpicking, ATMs, safes, gates, the prison, the fed, the bank and the
vault. If one of them is wrong, a dozen jobs are wrong.

- [ ] **Sequence breach** `[SOLO]` — pick any lock, or `[6] spawn AP_fnc_cyberdeckSeq;`
      Expect: 4×4 hex grid, amber buffer slot, only the lit row clickable, clock
      counting down. Completing the buffer opens the thing. Wrong row = 1.5 s lost.
- [ ] **Sequence at length** `[SOLO]` — `[12] spawn AP_fnc_cyberdeckSeq;`
      Expect: 12-code buffer wrapping rows, still solvable — every required code
      must be present in its active row. This is the rule most likely to be wrong.
- [ ] **Sequence abort** `[SOLO]` — open it, press Esc.
      Expect: the calling action treats it as cancelled, not as a failure.
- [ ] **Terminal breach** `[SOLO]` — `[2] spawn AP_fnc_cyberdeckTerm;` (6 commands)
      Expect: type each command exactly, Enter accepts, typos show red under the
      caret, wrong Enter costs 1.5 s. Backspace works.
- [ ] **Terminal at fed length** `[SOLO]` — `[3] spawn AP_fnc_cyberdeckTerm;` (9)
- [ ] **Breach Kit** `[SOLO]` — arm one, then start either game.
      Expect: auto-solve, charge spent, no minigame.
- [ ] **Overclock module** `[SOLO]` — with module 1 installed, either game.
      Expect: +4 s on the clock.

## 🟠 The phone is the deck now

- [ ] **Y opens the deck** `[SOLO]`. CTRL+Y is gone; there is no native phone.
- [ ] **Every app opens** `[SOLO]` — walk the launcher. Money, gang, keys, market,
      licenses, titles, achievements, quests, wanted, captures, gangs online,
      housing, settings, wallpaper, inventory, messages, the six point-spend trees.
- [ ] **TT Prestige** `[SOLO, medic]` — opens the deck tree, not a native dialog.
- [ ] **Keybinds land on the right app** `[SOLO]` — the gangs-online key, the
      housing key, the inventory key, the messages key, the wanted key.
- [ ] **Player-settings panel buttons** `[SOLO]` — Wanted / My Gang / Settings /
      Key Chain all open the deck on that app.
- [ ] **Cyberdeck ring** `[SOLO]` — TURF and MARKET wedges open the deck; BOLO
      opens Wanted.
- [ ] **/stats chat command** `[SOLO]` — opens Titles on the deck.
- [ ] **Incoming call** `[2P]` — ring someone. Expect the Phone app, not a dialog.
- [ ] **Gang create** `[SOLO]` — still the native creation dialog (deliberate: the
      deck has no create screen yet). It must still work.

## 🟠 Staff deck (admin panel, now an app)

- [ ] **Opens three ways** `[SOLO]` — Admin tile, User14 keybind, inventory button.
- [ ] **Roster** — every player, live; ping shows an em dash (not scriptable);
      cash/bank fill within ~5 s; dead/restrained flags right.
- [ ] **Toggles follow the payload** — godmode / invisible / ESP / markers flip in
      the rail within a second, not on click.
- [ ] **Targeted verbs** `[2P]` — TP to me, go to them, restrain/unrestrain, revive,
      jail, mark.
- [ ] **Coords** — GET fills the box + clipboard; SET moves; empty or `0,0,0` refuses.
- [ ] **Spawners** — weapons (+3 mags, addons ×1/×5), vehicles, clothing wear/give.
- [ ] **Weather** `[SOLO, L4+]` — day/night/rain/snow actually change the sky.
- [ ] **Gating** — needs a level-2/3 staffer to confirm OWNER hides and mixed
      sections lock with the level named.
- [ ] `[⚠]` **Restart ladders, ban, delete admin vehicles, fun guns, fed override**
      — last, or never.

## 🟡 Money screen

- [ ] **New Drachma card** `[SOLO]` — shows the exact 4dp balance, cyan, under Bank.
- [ ] **Fines box** `[SOLO]` — commit a crime, check it lists your charges with
      counts, total = your bounty, no PAY button, and it SCROLLS when long.
- [ ] **Transfer** `[2P]` — send cash to a nearby player; refusals for too far,
      too much, zero.
- [ ] **No deposit/withdraw** — those buttons are gone; banking is an ATM errand.

## 🟡 Gang rename (new feature, costs money)

- [ ] **Non-leader** `[2P]` — field and SAVE disabled, "LEADER ONLY".
- [ ] **Leader, poor gang** `[SOLO]` — refusal naming the fee and the balance.
- [ ] **Leader, funded** `[2P]` — rename lands for every online member, gang bank
      −$50,000, `gangs.name` updated, `gang_bank_log` gains a type-2 row.
- [ ] **Duplicate name** — refused.

## 🟢 Wallpaper / regression

- [ ] **Wallpaper picker** — one static (Hack The Planet) + the live CSS Matrix.
      No "16F" badge anywhere.
- [ ] **Stale wallpaper id** — `(profileNamespace getVariable "PLBClientSettings") set [0,2];`
      then reopen. Expect no RPT error and a silent fall back to entry 1 (and NO
      anti-cheat report — that was the fix).
- [ ] **Casino / shops / map** — unchanged, still open their own pages.

## ⚠ Open question found during the purge (b0549)

- [ ] **`AP_fnc_KRON_Strings` undefined at `init.sqf:85`** — appeared once in the
      b0549 boot log and not in earlier boots this session. The file exists
      (`core/functions/fn_KRON_Strings.sqf`) and is registered (`Functions.h:453`);
      `cfgfn_audit` is clean and the config braces balance. That points at an
      init-ORDER race — init.sqf reaching line 85 before CfgFunctions has finished
      compiling — which deleting ~30 entries would plausibly shift the timing of
      rather than cause. Not patched: hiding it behind an isNil guard would mask a
      real ordering problem. Watch for it recurring, and whether any string helper
      (KRON_StrToArray / KRON_StrInStr) misbehaves server-side when it does.
