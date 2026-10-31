# LooneyBin — UNDO-BEFORE-PUBLIC-LAUNCH checklist

Beta conveniences + deferred hardening that MUST be reverted before a real public launch.
Closed-beta (trusted players) = fine as-is. Public = do all of the below.

---

## 1. BETA GOD-STATS (everyone spawns maxed)  🔴 REMOVE
**What:** every player loads with **1,000,000,000** in every progression currency (cop prestige, TT
prestige, infamy, honor, standard talent points, gang points) + **every PRESTIGE tree fully unlocked**.
**Where:** `mission/LooneyBin.Altis/core/session/fn_requestReceived.sqf` — the
`if (missionNamespace getVariable ["AP_betaMaxStats", true])` block (look for `BETA GOD-STATS`).

> ⚠️ NOT a beta revert: the **standard talent trees** (civ/cop/medic `AP_side_talents`) are now
> PERMANENTLY baseline by owner decision (2026-06-11) — the standard talent SYSTEM was removed and the
> perks merged into the game. `fn_requestReceived` line ~70 forces `AP_side_talents` to the full
> faction list every load, and the "Talents" phone button is gone. Do NOT re-lock these at launch;
> only the prestige/honor/infamy/gang currencies + trees above are the god-stats to wipe.

**Undo:**
- **Disable the grant:** delete that block, OR set the flag off at server boot
  (`server/AP_server/init.sqf`): `AP_betaMaxStats = false; publicVariable "AP_betaMaxStats";`
  then repack + reboot. (Code change alone stops *new* grants but does NOT clear already-saved accounts.)
- **Wipe the persisted god-stats** (the vars get written by the periodic save, so they're in the DB):
  ```sql
  -- players: progression currencies + talent/prestige trees
  UPDATE players SET prestige='0', cop_talents=NULL, pre_talents=NULL,
      medic_prestige=0, medic_talents=NULL, med_talents=NULL,
      civ_talents=NULL, infamy_talents=NULL,
      civ_exp=100, cop_exp=0, med_exp=0, infamy_exp=0;
  -- players_global: honor
  UPDATE players_global SET honor_exp=0, honor_talents=NULL;
  -- gangs: gang talent points
  UPDATE gangs SET experience=0, talents=NULL;
  ```
  (Or just do a full character wipe if launching fresh.)

## 2. AUTO-GRANT NEW PLAYERS = CHIEF / CHIEF / SENIOR-ADMIN  🔴 DISABLE
**What:** new accounts are auto-floored to MaxSec Chief (cop 7) + TT Chief (medic 6) + admin lvl 4, and it
**persists** (GREATEST upgrade on every login). Beta testing only — on public this hands everyone admin.
**Where:** `server/AP_server/core/DB/fn_queryRequest.sqf` — the `SRV_grantNewbieRoles` block.

**Undo:**
- Set `SRV_grantNewbieRoles = false` (server var) so the grant stops, OR remove the block.
- Reset already-granted accounts in `players_global` (adminlevel/coplevel/mediclevel) for anyone who
  shouldn't keep them. Verify real staff/owner ranks are preserved.

## 2b. FEDERAL-EVENT COP REQUIREMENTS = ZERO  ✅ DONE (owner 2026-06-17, #333)
**What (was):** every federal event (bank, fed reserve, prison break, evidence lockup, convoy, jewelry,
Loony Bin) started with NO cops online — `fn_policeRequired` short-circuited to true while
`AP_betaZeroCops` (default true) was set. Beta-testing convenience (2026-06-09).
**Done:** `init.sqf:535` already sets `AP_betaZeroCops = false; publicVariable` at boot, AND `fn_policeRequired`'s
default is now FALSE too (cops required even on an unsynced JIP client). Plus gas-station robbery
(`fn_robStoreAction`) — the one crime that never called `policeRequired` — now requires ≥1 cop (#333). Cop
requirements are ENFORCED across every heist. (Only re-waivable by explicitly setting `AP_betaZeroCops=true`.)

## 2c. CfgDisabledCommands — re-tighten client unlocks  🔴 RESTORE
**What:** for beta QoL the client was allowed: CREATEUNIT/CREATEAGENT/CREATEVEHICLECREW (BIS arsenal
preview mannequin, #100), ALLVARIABLES/REMOVEALLITEMS/REMOVEALLEVENTHANDLERS/ONPRELOAD* (arsenal
internals), GETMOUSEPOSITION/CREATEGEARDIALOG (#78). Client createUnit/createAgent = classic AI-spawn
hack vector.
**Undo:** re-block client column (x,0,0) for the create* trio at minimum; either drop the admin
arsenal button or keep arsenal staff-only and accept the rest.

## 2d. LOONY BIN copsRequired = 0 (TEST)  🔴 RESTORE to 2
**What:** `server/AP_server/init.sqf` sets `SRV_loonyBinData`'s copsRequired slot (index 6) to **0** so the
mental-asylum / Loony Bin event can be breached solo for testing (owner 2026-06-18). Intended live value = **2**.
**Undo:** change the trailing `0` back to `2` in `SRV_loonyBinData = [-2700, false, 0, "", true, objNull, 0]`,
repack + reboot.

## 2e. FEDERAL RESERVE (gold-bar) cop req = 0 (TEST)  🔴 RESTORE to 6
**What:** owner 2026-06-19 — the gold-bar Federal Reserve was un-startable in beta (whole fed gates on
**6 cops**, and `AP_betaZeroCops` was turned off in 2b). Lowered the fed-reserve cop requirement to **0**
so it can be robbed solo for beta. This is the fed reserve ONLY — bank/prison/evidence/convoy/jewelry/Loony
Bin still enforce their own reqs.
**Where (4 spots, all commented `fed cop req 6->0 for beta`):**
- `mission/.../core/actions/fn_openGate.sqf` — `[0, true]` → restore `[6, true]`
- `mission/.../core/actions/fn_openVault.sqf` — `[0, true]` → restore `[6, true]`
- `mission/.../core/actions/fn_openSafe.sqf` — `[0, true]` → restore `[6, true]`
- `server/AP_server/core/bank/fn_fedAlarm.sqf` — `(west countSide allPlayers) < 0` → restore `< 6`
**Undo:** revert the four to their `6` values, repack + reboot. (NOTE: did NOT touch `AP_betaZeroCops` —
that stays off, so bank/jewelry/etc are unaffected.)

## 3. CfgRE / server.cfg RCE HARDENING  🔴 DO (deferred)
**What:** full public-launch hardening was DEFERRED for closed beta (trusted admins). See
`memory: loonybin-cfgre-rce-deferred` + the project notes. Lock down remoteExec/CfgRE whitelist +
`server.cfg` before exposing to the public.

## 4. !link reward / report channels — sanity check (not a revert)
- `!link` 500k bank incentive (`link_reward`) — keep or lower for public; one-time per account.
- No in-game ownership proof on `!link` (trusts the PID). Add an in-game `/linkcode` before public if
  abuse matters.

---

_Created during closed beta. Owner: run this list at the actual public-launch cutover._

## 5. !pos chat command — 🔴 REMOVE before public
**What:** `!pos` (core/chatcom/settings/commands.hpp, `class pos`) prints any player's exact world
XY + grid on screen and logs `[LB-LOG][-POS-]` server-side. Added 2026-06-11 as an owner mapping tool.
**Why remove:** any PLAYER can read precise coords → meta-gaming (exact cartel/event/stash spots,
calling out positions, scouting). Fine while it's just the owner mapping; pull it before public.
**Undo:** delete the `class pos { ... }` block from commands.hpp, repack + reboot. (Or gate it behind
`(call AP_adminLevel) >= 5` inside the code if you want to keep it owner-only.)

## Dev auto-admin (added 2026-07-25)

`AP_devAutoAdmin = true` in `mission/Armapunk2035.Malden/initServer.sqf` makes **every player
who joins admin level 4**. Read by `fn_queryRequest` (`_admin = _admin max 4`).

**Set it to false before public launch.** It is applied in memory only and never written to
`players_global`, so flipping it off is sufficient -- no DB cleanup, and nobody's real level was
overwritten. That is the difference from the older newbie grant in the same file, which DOES
persist with `UPDATE players_global ... GREATEST(...)`.
