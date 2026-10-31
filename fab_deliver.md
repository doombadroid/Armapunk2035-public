# Fabricator auto-delivery — output goes into the house, not your pockets

Owner call 2026-08-30: *"the fabricators should store items into the house they are placed in, not
make you collect and add to your inventory."*

Today a finished job sits in the machine until a player stands at it and presses **Collect**, and
the grant lands in that player's inventory. That contradicts the feature's own premise — the machine
runs on a server clock *while the owner is logged off* (`FAB.md`), and then makes them come back and
walk to it anyway. This replaces collect with delivery: the job finishes, the server puts the output
in the house's storage, and the machine moves on.

Spec status: design approved by owner 2026-08-30. Not implemented. See *Open items* at the bottom.

---

## Decisions the owner made

| Question | Answer |
|---|---|
| Keep a collect step? | **No.** Auto-deposit the moment the job finishes, online or not. |
| House full? | **Refuse at queue time** — you cannot start a job the house has no room for. |
| XP and quest credit? | **XP on deposit** (works offline). **Quest event queued**, fires on next login. |
| Printed weapons and gear? | **Into the house's `pinv`**, alongside the virtual items. |

---

## The shape

| | |
|---|---|
| Depositor | `server/.../TON/fn_fabDeliver.sqf` — **new**, a loop from `init.sqf` |
| Write path | `APS_fnc_updateHouseTrunk`, called server-internal (`_src == 0`) — **reused, not reimplemented** |
| Capacity gate | `APS_fnc_fabSRV` `queue` arm — new pre-flight against `AP_vcap` / `AP_phys_cap` |
| XP | `APS_fnc_fabXp` — extended to an offline (`players.fab_level` / `fab_xp`) state source |
| Quest credit | queued on the job's `queued_by`, delivered by the same loop |
| Schema | `house_printer_jobs` gains `queued_by varchar(17)` |
| Deleted | `AP_fnc_fabCollect`, `fabSRV` `collect` arm, `fn_deckFab` `collect` verb, two buttons |

---

## 1. The depositor

`APS_fnc_fabDeliver`, server-only, driven from `init.sqf`:

```sqf
[] spawn { uiSleep 25; while { true } do { [] call APS_fnc_fabDeliver; uiSleep 30; }; };
```

A **loop rather than a timer per job**, for the reason `APS_fnc_offlineMsgDeliver` already states in
its own header: polling catches the condition for free a few seconds later and cannot break anything
if it fails. The boot settle is 25 s so it lands after the `uiSleep 22` fabricator reload that
respawns the anchors.

One query per tick:

```sql
SELECT id, printer_id, recipe, qty, queued_by
FROM house_printer_jobs
WHERE finish_at <= extract(epoch from now())::bigint
ORDER BY id LIMIT 30
```

`LIMIT 30` matches `offlineMsgDeliver`'s. A backlog drains over successive ticks rather than in one
long-running frame.

Each row resolves its printer anchor out of `AP_fabAnchors`, then the building under it through the
existing `_resolveHouse` — the same resolver `queue` and the old `collect` use, so a printer standing
on a buyable-shed spot still finds the intact shed rather than the hidden derelict.

## 2. The deposit itself

House storage is the most data-loss-prone subsystem in this codebase. Three separate incidents are
recorded in its own source: the b0093 hydrate-display wipe, the #542 rapid open/close TOCTOU that
clobbered a live session, and the Jeff Stall gun dupe that came from reading `AP_pinv` off the object
mid-take. The depositor is written to be timid about exactly those:

**It never writes a house that has a live session.** If any of `AP_invHydrated`, `AP_activeTrunk` or
`AP_trunkLock` is set on the building, the job is skipped this pass and retried on the next tick. A
finished job is durable in the database — waiting 30 s costs nothing, and racing an open trunk costs
somebody's stash.

**It writes through `APS_fnc_updateHouseTrunk`, server-internal.** `_src == 0` is the trusted path
that already passes every gate, owns the mres encode, re-asserts the server-local copy and issues the
`UPDATE`. Reusing it rather than writing a second `UPDATE houses SET vinv=…` is the same rule
`fn_vehicleToHouseStore` follows and states: *"reuses the EXACT proven machinery instead of a new
write path."*

**Column split by the same oracle collect used.** `(["getItemRow", _key] call AP_fnc_virtItemCfg)
isNotEqualTo []` → `vinv`; otherwise `pinv`. Physical gear no longer crosses the wire at all, which
also closes the hole `AP_fnc_fabGiveGear` documents in its own header — a modified client could
decline delivery of its own item. It has nothing to decline now.

**Order per job, and it matters:**

1. building resolves, and has **no** live session (§2 above) — else skip, retry next tick;
2. the output **fits** the house's headroom (§3) — else hold, retry next tick;
3. take the `AP_fabBusy` `"j<id>"` lock;
4. `DELETE` the job row, and prove the delete committed (`SELECT COUNT(*) … = 0`);
5. write the items.

Both "retry" exits sit **before** the delete, so a skipped or held job still has its row and cannot
be lost by the pass that declined it. Steps 4–5 keep the existing collect arm's fail-closed order
unchanged: it prefers losing a job to duplicating one, and this change does not silently reverse
that trade.

## 3. Capacity

**At queue time.** Before accepting a job, `queue` computes the finished batch's weight — virtual via
`AP_fnc_virtItemCfg`'s item weight, physical via `AP_fnc_physicalInventoryWeight` — and compares it
against the house's headroom: `AP_vcap` minus the current `vinv` weight, `AP_phys_cap` minus `pinv`.
Not enough room, the job is refused with the shortfall named.

**The case the queue check cannot cover.** Someone else fills the house while the job runs. Then the
deposit finds no room, the job is **held in the machine** and retried every tick, and the queuer gets
a single message if they are online. Production stalls until room is made; nothing is lost and
nothing is duplicated. This is the leftover case, not a competing policy — the queue check is still
the primary gate.

## 4. XP

Two things block paying XP today:

**`APS_fnc_fabXp` needs the player object.** It reads `AP_fabLevelSrv` / `AP_fabXpSrv` off the unit
and writes them back, so it cannot pay someone who is logged off — which is now the normal case, the
whole point of a machine that runs offline. It gains a uid-keyed path: state comes from the player
object when that player is online, and from `players.fab_level` / `fab_xp` when they are not. **One
roll-up loop, two state sources** — the multi-level roll-up must not be duplicated, or the two paths
drift and only one of them stays correct.

**Nothing records who queued a job.** `house_printer_jobs` is `(id, printer_id, recipe, qty,
finish_at)`. Collect paid whoever pressed the button; with no button there is no such player. The
table gains `queued_by varchar(17)`, written at queue from the server's own `getPlayerUID`, and the
deposit pays that uid. This is what makes a gang printer fair: the gang member who queued the job
earns for it, not the house's owner.

Migration follows the boot block's existing shape:

```sqf
["ALTER TABLE house_printer_jobs ADD COLUMN IF NOT EXISTS queued_by varchar(17)", 2] call DB_fnc_asyncQuery;
```

Jobs already in flight at deploy have `queued_by` NULL. They deposit normally and pay no XP — a
one-time loss of a few jobs' progression, preferred over guessing an earner.

The XP window is unchanged: the recipe's level must be inside `[playerLevel - 1, playerLevel]`,
evaluated at **deposit** (it was evaluated at collect).

## 5. Quest credit

`AP_fnc_fabQuestEvent` runs on the client, so it cannot fire for an absent player. The event is
queued against `queued_by` and delivered by the same loop once that uid turns up in `allPlayers` —
the `offlineMsgDeliver` model, which exists precisely because the login path is long and already
carries money and gear restore.

## 6. UI

Collect disappears from every surface:

| Surface | Change |
|---|---|
| `dialog/fab_menu.hpp` | remove `Collect_Button` (idc 1831) |
| `ui/html/deck.html` | remove the `COLLECT` button and its `fabCollect` handler |
| `core/web/fn_deckFab.sqf` | remove the `"collect"` verb |
| `core/items/fn_fabCollect.sqf` | delete |
| `server/.../fn_fabSRV.sqf` | delete the `collect` arm |

The job list gains a destination line — *"→ stored in this house"* — and a **HELD** state for a job
whose deposit is being retried, so a stalled machine reads as stalled rather than as broken.

## 7. What this must not break

- `fab_check.py` asserts the recipe/schematic bijection and the receiver chain. Unaffected, but it
  runs in `run_checks.sh` and must stay green.
- The `_mayUsePrinter` access model (installer / owner / keyholder / gangmate) is untouched. Delivery
  does not consult it — a finished job belongs to the house it is standing in.
- Pickup stays narrower than use: only the installer or the property owner may take a machine away.

## Open items

- Nothing here has been played. It is proven by the checks and by negative tests until an owner
  session says otherwise — the same standing caveat `FAB.md` carries for the whole feature.
- `FAB.md` is the living document for the fabricator and must be updated when this lands; this file
  is the design record, not the reference.
