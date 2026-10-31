# The Fabricator (3D printer + gunsmith bench)

Player-owned manufacturing. A machine is installed in a house, loaded with materials, and runs on
a server clock that keeps running while the owner is logged off.

**Weapons are a two-stage chain** (owner, 2026-08-22). A printer makes exactly one part of a gun —
its **lower receiver** — out of filament. Everything else about that gun is assembled at a
**gunsmith bench** from the receiver, the rest of its materials and its schematic. So the printer's
level decides which weapon CLASSES you can supply, and the bench decides the specific gun.

Four receiver classes rather than one universal part, and rather than one per gun: one per gun
would have meant ~80 more item rows, icons and recipes to make the same decision.

| Receiver | Printed at | Feeds |
|---|---|---|
| `lower_pistol` | L4, 10 filament | `hgun_*` |
| `lower_smg` | L8, 18 filament | `SMG_*` |
| `lower_rifle` | L13, 34 filament | `arifle_*`, `sgun_*` |
| `lower_heavy` | L18, 60 filament | `srifle_*`, `LMG_*`, `MMG_*`, `launch_*` |

`fab_check.py` asserts the chain both ways: every weapon is bench-flagged and carries exactly one
receiver, and no printer recipe may contain one. Both failures are silent otherwise — a weapon with
no receiver is a gun the printer step never gates, and a printer recipe holding a receiver is a gun
you can make without a bench.

**Production costs materials and time, never money** (owner, 2026-08-21). The only currency in the
feature is the price of a schematic, and that is New Drachma.

Built 2026-08-22. **Nothing here has been played** — it is proven by the static gates below and by
negative tests, not by a session. See *Playtest* at the bottom.

---

## The shape

| | |
|---|---|
| Recipes | `fn_fabCfg.sqf` (23 hand) + `fn_fabGen.sqf` (551 **generated**) = 574 |
| Schematics | `fn_fabSchemCfg.sqf` + the generated block — `[dropchance, sources, rarity]` |
| Schematic price | `core/config/fn_fabFee.sqf` — recursive backbone count × a config rate |
| Authority | `server/.../TON/fn_fabSRV.sqf` — place / queue / collect / pickup |
| Progression | `server/.../TON/fn_fabXp.sqf` — **not** in CfgRE; that absence is the gate |
| Schematic grants | `server/.../TON/fn_fabGrantSRV.sqf` — roll / give / buy / shard / **burn** |
| UI | `dialog/fab_menu.hpp` (idd 1810) + `core/items/fn_fab*.sqf` |
| Models | `custom_p3ds/ap_printer_f770_{body,bridge,head,platform,screen_ready,screen_printing}_r1.p3d` (both printer tiers), `ap_gunsmith_bench_r2.p3d` (r2 = clean metal sheets; r1 pointed at rust-streaked base-game textures) — see *Models* |
| Storage | `house_printers` table + `players.fab_level` / `fab_xp` / `fab_schematics` |
| Generator | `scratchpad/gen_fab_catalogue.py` → `fn_fabGen.sqf` (do not hand-edit) |
| Build gate | `tools/fab_check.py`, wired into `tools/run_checks.sh` |

**Two tiers**, one shared model: i3 (1 job, 1.0×, recipes to L10) and CoreXY (3 jobs, 2.0×,
to L20) keep their separate item keys, prices and tier stats, but both now draw the same **F770**
industrial printer — bridge, head and platform move and the HMI screen reads PRINTING while a job
runs; the tiers are told apart only by their name and their job count, not by their model. Both are
themselves printable; the i3 needs no schematic, because a machine you cannot build without already
owning a machine is a dead economy.

Slots are **rows in `house_printer_jobs`**, not columns on the printer. The first cut put
`recipe`/`qty`/`finish_at` on `house_printers`, which silently capped every machine at one job while
the tier table advertised three — a tier whose headline number is not implemented is worse than a
tier that does not exist. Rows also keep collect fail-closed per job: one job failing its proof
withholds that job and nothing else.

**Access**: the printer's installer always; otherwise the house's owner, anyone with keys, or — if
the building is the designated gang house (`AP_house_gang`) — any member of that gang. There is no
server-side per-player gang variable in this codebase, so the gang arm reads `players.gang0`,
bounded to the path where the first two checks already failed. **Pickup is narrower than use**: a
gang member may run a gang printer, only the installer or the property owner may take it away.

---

## Decisions that are load-bearing

**The clock is the database's.** `finish_at` is an absolute epoch written as
`extract(epoch from now())::bigint + N` and read as `GREATEST(finish_at - now, 0)`. This is the
`fn_qhSRV.sqf:50-52` rule and the `drone_recharge_until` shape — deliberately **not** the
greenhouse's `AP_bootUnix + serverTime`, which pays an epoch-offset tax (`AP_GH_EPOCH = 1.7e9`)
because SQF floats have a ~128 s ULP at raw unix. A deadline only ever asks "past it or not", so
letting PostgreSQL answer removes the offset, the JIP publicVariable and every `toFixed`.

**Rows, not a column on `houses`.** The obvious shape is a `houses.printers` blob beside
`greenhouse_crop`. It is the shape the mining rig *started* with, and `houses.miner varchar(48)`
**is** what caused its collect dupe: a malformed write overflowed the varchar, the UPDATE was
rejected, `asyncQuery` reported that exactly like a success, the stamp froze, and every later
collect re-minted the full accrual on 10 of 13 live rigs (`BUGS.md` #555). Copy the destination of
that migration, not its origin.

**Collect is fail-closed in three layers**, from the same post-mortem: a per-printer in-flight
lock; a blocking UPDATE that clears the job before the lock is released; and a re-SELECT proving
the clear committed before a single item is granted. Pickup proves the row is gone before
refunding. A withheld legitimate collect just retries; that asymmetry is deliberate.

**Two copies of progression.** `AP_fabLevelSrv` / `AP_fabXpSrv` / `AP_fabSchemSrv` are the server's:
uid-keyed hashmaps in `localNamespace` (created in `vars.sqf`, seeded ONCE per server run by `DB_fnc_queryRequest` — a
later call never overwrites a live entry, since its DB read may predate an in-flight burn or learn),
and they are what the server gates on and persists from. `AP_fabLevel` / `AP_fabSchem` on the unit are
published for the UI. A client can `setVariable` a public value on an object it owns, so a gate reading
the published copy is not a gate — it is the client asserting its own level, which is the exploit in the
system this was ported from. The server copies are NOT object variables: a client's public
`setVariable` overwrites a same-named unpublished one on the server as well (audit 2026-09-26, mints2).

**The printers have no collision** (owner, 2026-08-22) — 0.5 m desk props, and a player who can
snag on one is a player stuck in his own printer room. One real consequence: `cursorObject` is a
raycast and needs geometry, so the mining rig's targeting pattern cannot work. **The bench does**
have collision (five boxes, mass 140) because it is a 2 m object you stand at. Both use the same
proximity path anyway (`AP_fnc_fabNear`, 4 m) against the invisible anchor that carries the
identity and the actions — two targeting mechanisms for one interaction would mean two sets of
edge cases for no gain. The model is a client-local simple object attached to the anchor, lifted by
its own half-height (0.2975 printers / 0.9463 bench, carried in the tier tuple).

**One grant funnel.** `APS_fnc_fabGrantSRV` is the only thing that grants a schematic — roll, give,
buy, shard. No faucet rolls client-side: gather and mining *report* that an action finished and the
server rolls, because a permanent unlock is a mint.

**Why New Drachma.** It is the only server-owned wallet here; cash and bank are client variables
the client persists itself. `APS_fnc_ndDebitSrv` is absent from CfgRE (its whole security model),
atomic in SQL, and fail-closed, so the schematic is written only on a true `_ok`. Note the
signature asymmetry that will bite: **`ndDebitSrv` takes a UID string** (it must charge offline
players) **while `ndCreditSrv` takes the object.**

---

## How you get one

Both machines are bought from the **Homegoods Store** — the button in the house menu that also
sells furniture — and placed exactly like furniture: Y → Use → position → confirm.

| Machine | Source |
|---|---|
| **i3 Fabricator** | Homegoods Store, $75,000. The on-ramp. |
| **Gunsmith Bench** | Homegoods Store, $160,000. Also printable at L10. |
| **CoreXY Fabricator** | Schematic (drop / heist / ND vendor) → print it on your i3 |

Money buys the **machine**, never the goods. Everything the machines make is materials and time.
Both entry machines stay printable too, so a second one costs materials rather than cash, and once
P4 empties the NPC shops players buy them off each other on the Exchange — all three fabricators
are already whitelisted there.

**That store has no NPC and does not need one**: it is opened from `core/housing/fn_houseMenu.sqf`.
This is worth knowing because it is where two bugs landed in a row. `printer_i3` first shipped with
NO source at all — printable only, so the only way to get a printer was to print one — and the fix
for that put it in the `tech` shop (Kabuki Electronics), which reads fine in the config and has
**zero placements in `fn_mapData`**. A shop that exists in a config but not in the world sells
nothing to anybody. `fab_check.py` now resolves a machine all the way to the world: which shop
sells it, and whether that shop has an NPC on the map *or* a menu that opens it.

---

## Tuning

Everything worth moving is one constant.

| Lever | Where |
|---|---|
| Schematic prices | `ND_PER_UNIT_TTH` in `fn_fabCfg`'s `"backbone"` arm (500 = 0.05 ND per unit) |
| XP curve | `AP_fabXpCurve` — ~450 qualifying prints to L20 (the original needed 1,590) |
| Print times | `AP_fabDurations`, keyed by derived category |
| Drop rates | `dropchance` per schematic row; generated ones from `dropchance_of()` |
| Catalogue curve | `LEVELS`, `COST_BASE`, `COST_GROWTH` in the generator |
| Fabricators per PLAYER | `FAB_MAX_PER_PLAYER` (5) — total, any mix of printers and benches, across all houses |

**ND arithmetic is integer ten-thousandths, never floats.** `0.05` is not exactly representable in
binary, and `fn_ndDebitSrv`'s header states the rule: all ND arithmetic is SQL on `DECIMAL(20,4)`
and SQF's 32-bit floats never touch the ledger. `fn_fabFee` multiplies integers and renders the
string by division and modulo, which also guarantees the output satisfies `ndDebitSrv`'s
`\d{1,14}(\.\d{1,4})?` validator — a float would fail it the moment `format` chose scientific
notation.

---

## Models

Both printer tiers (i3 and CoreXY) draw one animated model, the **F770** industrial printer
(2026-09-02 — full spec `PRINTER_F770_SPEC.md`, plan `printer_f770_plan.md`), from the owner's
three.js drop (`f770.js`, archived in-repo — **diff it before any regen**,
`scratchpad/skyscraper/ARMA3_HANDOFF_F770.md`). It is six generated p3ds
(`ap_printer_f770_{body,bridge,head,platform,screen_ready,screen_printing}_r1.p3d`): the body is
static, the bridge/head/platform move while a job runs (`AP_fnc_fabAnim`, mirroring the Resource
Extractor rig's client-side pose loop), and the HMI screen swaps between a READY quad and a
PRINTING quad. Item keys, prices and tier stats are unchanged — only the drawn model changed, so
the two tiers are no longer visually distinct from each other.

    node harness_f770.mjs     && python3 build_f770.py     && python3 verify_f770.py     # ALL PASS
    node harness_gunsmith.mjs && python3 build_gunsmith.py && python3 verify_gunsmith.py  # ALL PASS

The bench's suite asserts collision's PRESENCE and shape where the F770's asserts the body carries
real geometry (walking through a 2.24×1.09×1.80 m machine reads as a bug, unlike the old desk
printers). It also clamps the handoff's authored boxes to the visible bounds.

Bump `_rN` on every regen: Arma caches models by path, so an in-place swap looks like no change.
The old desktop-printer generator (`{harness,build,verify}_printer.*`, `printer.js`,
`ARMA3_HANDOFF_PRINTER.md`) is archived at `scratchpad/skyscraper/archive/printer_desktop/`; the
old `ap_printer_i3_r1.p3d` / `ap_printer_corexy_r1.p3d` are deleted from the mission.

---

## Free build — the testing override

Turn it on from an admin console (adminlevel ≥ 3):

```sqf
["free", [true]]  remoteExec ["APS_fnc_fabDebugSRV", 2];   // on
["free", [false]] remoteExec ["APS_fnc_fabDebugSRV", 2];   // off
["state", []]     remoteExec ["APS_fnc_fabDebugSRV", 2];   // what is it now
```

**Ignores three things**: the ingredients a recipe calls for, the fabrication level it needs, and
whether you have learned its schematic. The menu shows the machine's whole catalogue and the header
turns green.

**Everything else still runs**, on purpose — the machine must exist, be yours, and be the right
KIND for the recipe (a bench for a weapon); the job takes its full time; collect is the same
fail-closed path. The point is to prove the rest of the system without first grinding a catalogue
of materials, so the parts being proven have to behave exactly as they will in production.

Admin-gated on `adminlevel` read from the database for `remoteExecutedOwner`, never from the
packet. The client's copy of the flag is advisory — it greys the right things and skips consuming
materials, but every gate it bypasses is re-read from the server's own copy, so a client that sets
its local flag gets a nicer menu and identical refusals. **It does not survive a restart**: boot
sets it false, because a testing override that quietly persists is one that ends up on a live
server.

---

## Playtest

`bash /home/timb/arma3server_dev/reload-armapunk2035.sh`, then:

1. Print an i3 (L3, no schematic), Y → Use → place it in a house you own.
1b. Print a `gunsmith_bench` (L10) and place it. It should have collision — you cannot walk
    through it — and it should stand ON the floor, not sunk to the worktop.
1c. Try to queue a weapon on a printer → refused, told to use a bench. Try to queue a non-weapon
    on the bench → refused the other way. Print a `lower_rifle`, take it to the bench, assemble.
2. Load a job, **log off, log back in** — elapsed time must match wall-clock, not session time.
3. Collect. Item arrives, XP +1. Collect something below level −1: item arrives, **XP does not move**.
4. Spam Collect on a finished job from two clients — granted exactly once.
5. Try to pack up a printer with a job in it — refused, contents intact.
6. Queue a recipe above the machine's tier cap — refused even if your own level allows it.
7. Buy a schematic with too little ND — refused, nothing learned, balance unchanged.
8. Gather/mine until a schematic drops; relog and confirm it persisted.

Probes log under `[AP-PROBE]`; the feature logs under `-FAB-`.

**Tamper tests, which are the point of the design:**

- `[["queue", [player, <id>, "MMG_02_F", 99]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP` from a level-1
  client with no schematic → refused, materials refunded, `-SEC-`-class log line.
- Set `AP_fabSchem` locally to every recipe → still refused; the server reads its own copy.
- Set `AP_fabLevel` locally → no effect; no client path writes it.
- `player setVariable ["AP_fabSchemSrv", <every recipe>, true]`, then learn or burn → only the real
  list changes; the server copy is in `localNamespace`.
- Burn a schematic while re-sending `[player, playerSide]` to `DB_fnc_queryRequest` → one shard, and the
  schematic stays gone (the map is seeded once, not refreshed). Two burns of one key in the same frame →
  one shard.

---

## Not done

- **P4, the closed economy proper.** Cash and bank are still client-authoritative, the Exchange
  still debits the buyer client-side and does not escrow item listings, and the NPC shops are still
  stocked. Until that lands this is the production half of an economy that is not yet closed.
  `AUDIT.md:148` records the no-escrow listing as accepted BY-DESIGN for a *loose* economy; that
  reasoning does not survive this direction.
- **Site confirmation** for the Exchange NPC — run `debug/exchangesite.sqf`.
- **Stale "LoonyBin" branding** in the Exchange's player-facing strings. Left alone deliberately:
  renaming half of it is worse than renaming none, and the sweep is its own pass.
- **Dead branches in `fn_craftRecipe.sqf`** — the 7.62 licence list and the quest-492 discount are
  unreachable now the Factory is vehicles-only. Harmless; rewriting a working 151-line craft path
  to delete branches that cost nothing is churn with real regression risk. The MRAP licence gate
  and the 490/491 discounts are still LIVE, because those are vehicles.

---

## Everything else is playtest

`FAB.md`'s script above is the remaining work. The gates that can run offline all pass — 20/20 in
`run_checks.sh`, `verify_printer.py` ALL PASS, `fab_check.py` over 574 recipes, and a
cross-reference audit confirming every `AP_fnc_fab*` / `APS_fnc_fab*` is registered in
`Functions.h` / `config.cpp` / `CfgRE.hpp` and every dialog idc referenced exists.

None of that executes a line of SQF. There is no SQF runtime outside Arma.
