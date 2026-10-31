# PostgreSQL + PySQF — migration plan

Replacing the extDB3 → MariaDB data layer with PySQF → PostgreSQL.

Grounded in a full static inventory of the schema, the query surface, the
serialisation layer, the concurrency model, the non-game consumers and the
adversarial risk pass. Every number below was computed, not estimated.

---

## 1. The reframe: this is two migrations, and they must not be one

The instinct is "move the database". The inventory says that is the wrong unit
of work, because two independent hard problems are hiding inside it:

- **The transport.** extDB3 → PySQF. Changes how SQF reaches the database, what
  a failure looks like, and what the per-frame cost is.
- **The dialect.** MariaDB → PostgreSQL. Changes what SQL is legal, what types
  come back, and what was previously tolerated.

Doing both at once means every new bug has two candidate causes, and the failure
mode of this codebase is *silence* — so you would be debugging invisible
problems with two variables.

**Superseded 2026-08-14 — the separation was achieved a better way.** This
section originally said "run the new transport against the same MariaDB, with
every SQL string byte-identical". That would have meant writing a MySQL module
for a system whose entire purpose is to replace MySQL: throwaway work to prove a
property that is already proven.

The transport is isolated by the **smoke test's first four stages**, which
exercise extension loading, the verb protocol, Python reachability and the error
channel using `diag.*` probes and **no SQL whatsoever**. That is a cleaner
isolation than a MariaDB module would have given, because it removes the
database from the picture entirely rather than holding it constant.

**Those four stages passed inside Arma on 2026-08-14. The transport is proven;
what remains is the dialect.**

Two things preserve the rest of the property, and both should be kept:

- **Leave extDB3 loaded alongside.** Nothing forces a hard swap — `DB_fnc_*`
  and `APS_fnc_pysqf*` coexist. That keeps a *live* A/B reference rather than a
  historical one, which is better than the original plan offered.
- **Let the error channel do the attribution.** A transport failure and a SQL
  failure both arrive as `ok=false`, with visibly different messages — one from
  PySQF, one from PostgreSQL. That only works because stage 4 passed, which is
  why stage 4 is the gate and not a formality.

---

## 2. Verified current state

Earlier figures in conversation were wrong; these are re-derived.

| | measured |
|---|---|
| Files calling `DB_fnc_asyncQuery` | **156** `.sqf` files |
| Invocations | **459** |
| …fire-and-forget (mode 1, **no error channel**) | **229** |
| …blocking reads (mode 2) | 198 (+32 unresolved) |
| Distinct SQL literals | **539**, across 172 files |
| `CREATE TABLE` statements / distinct tables | 74 / **~46** |
| Decode helpers | 4 functions + **414 downstream coercions** (189 `QUOTE(`, 134 `parseNumber format`, 91 `parseSimpleArray`) |
| Transactions anywhere in `server/` | **0** |
| `LOCK TABLES` anywhere | **0** |
| Live database size | 49 tables, ~65 MB gzipped, 5-second dump |

### Scope: settled

**Only this project moves to PostgreSQL. The live box stays on MariaDB.**
**Its player data carries across once, at open beta (§9).** (Owner decisions,
2026-08-14.)

That removes the hardest constraint in this plan — there is no dual-write, no
engine sync, no same-day three-consumer switch, and no rollback-to-MariaDB path
to maintain for this project.

What remains is two separable pieces of work:

1. **The engine port** (§3–§8) — greenfield, no data, no players, reversible.
2. **A one-time ETL** (§9) — live MariaDB → this project's PostgreSQL, one
   direction, one event, at beta launch.

They share almost nothing except the dialect rules. Build and rehearse them
separately; the ETL is a Python data problem, not an Arma problem.

It also introduces one new cost, which is worth naming rather than discovering:
**the two projects now run different engines from a shared code ancestry.** The
website, the bots and the deploy scripts are forked from the same source and
currently default to the predecessor's database (`website/src/lib/db.ts:19`).
Each of them will eventually need either a fork or a dual-driver path. That is
cheap now and expensive after both sides have diverged further.

### There is a working baseline, and it is the most valuable asset in this plan

⚠ **`MALDEN.md:101` is stale.** It still says *"the mission packs (2,147 files),
but nothing has been run."* That is no longer true and the line should be fixed,
because it is the kind of claim someone plans around.

Observed state:

```
arma3server_x64 -config=server.cfg -name=loonydev -port=2342
                -serverMod=@extDB3;@AP_server -filePatching -autoInit
```

with `@extDB3/extdb3-conf.ini` → `Type = MySQL`, `127.0.0.1:3306`,
`Database = looneybin_test`. A dev instance is running, tracking `main`.

This changes the plan's confidence, not its shape. It means:

- **Phase 1's gate is meaningful.** "A week of normal play with no RPT errors"
  can be measured against a known-good reference rather than an assumption.
- **Every risk in §11 is testable before it is dangerous.** The boolean-typing
  trap, the `[]` conflation, the latched lock — each can be reproduced against
  the running instance and fixed under MariaDB first, exactly as §4 prescribes.
- **A/B is available at every phase**, which is the single thing that makes
  "transport before dialect" more than a slogan: when something breaks after the
  transport swap, there is a working instance to diff against.
- **It is the ETL rehearsal target.** §9's transform can be loaded into a
  PostgreSQL instance and this dev server pointed at it, repeatedly, at zero
  risk.

`looneybin_test`'s own data is **disposable** (owner, 2026-08-14), so pointing
this instance at PostgreSQL is a config change, not a migration.

### The schema lives in four places, not one

Any migration reading only `sql/` will be wrong.

| Source | Status |
|---|---|
| `sql/looneybin_dev_schema.sql` | The only real structure dump (2026-06-26). **Authoritative base.** |
| 9 post-dump feature fragments | Dated after the dump. **Authoritative deltas.** |
| `deploy/run-boot2.sh:95-137` | 8 `ALTER` + 1 `CREATE`, run **every boot**, output sent to `/dev/null`. Six live columns exist only here. |
| Runtime DDL in SQF | 3 `CREATE TABLE IF NOT EXISTS`, 6 `ALTER TABLE`. Two tables exist nowhere in `sql/`. |
| ~~`sql/looneybin_schema.sql`~~ | Stale. Keep only for its 3 stored procedures, which appear nowhere else. |
| ~~`sql/_inferred_2020_schema.sql`~~ | Self-identified guess; ~40% of its column names do not exist. **Delete before someone reads it by accident.** |

A `mysqldump --no-data --routines --triggers --events` against the live box is a
**prerequisite**, not an optimisation — `deploy/run-boot2.sh:96` drops a trigger
that exists in no `.sql` file here, which proves the repo does not know the full
schema.

---

## 3. The one thing to fix before anything else

```sqf
fn_asyncQuery.sqf:49   if((_queryResult select 0) isEqualTo 0) exitWith { diag_log …; [] };
fn_asyncQuery.sqf:52   if(count _return == 0) exitWith {[]};
```

**`[]` means "no rows", "the query failed", and "the extension is gone."**

198 mode-2 call sites cannot distinguish them, and PostgreSQL's entire value
proposition is that it *rejects* statements MariaDB tolerated. Every one of
those rejections arrives at a caller that reads it as "there is no such row",
and the caller then substitutes a plausible default. That single conflation is
the mechanism behind almost every serious risk in this plan.

Give `DB_fnc_asyncQuery` a real error channel — a discriminated result, not a
sentinel — **while still on MariaDB, where the old and new paths can be
A/B compared.** Nothing else in this plan is worth starting first.

Second, on the same principle: `fn_asyncQuery.sqf:24` sets `DB_Async_Active =
true`, and if the script dies before line 46 nothing ever resets it. Every
subsequent query on the server then blocks forever at line 15 with one line in
the RPT. That latch exists *today*; a Python exception is a new and much more
frequent way to reach it.

---

## 4. Phase 0 — prerequisites, all under MariaDB

None of these need PostgreSQL, all of them are independently valuable, and
skipping them makes every later phase unattributable.

1. **Real error channel** for `asyncQuery` (§3), plus a `DB_Async_Active` reset
   on every exit path.
2. **Convert the login read to named columns.** `fn_queryRequest.sqf:79` selects
   **30 columns positionally** and consumes them as `_p select 0` … `select 29`
   with no name mapping. Insert or reorder one column during the port and every
   field after it shifts — `bankacc` read as `new_drachma`, `title` as `isswat`
   — and the periodic save writes the wrong values back. This must not be live
   during an engine change.
3. **Enumerate fail-open vs fail-closed.** Some paths are deliberately fail-open
   (the ban gate), some deliberately fail-closed, some fail-open by accident.
   Nothing documents which. The list must exist before failures get more common.
4. **Add the missing unique index** on `gang_vehicles (gang_id, plate)` properly.
   It is currently created by a MySQL-only statement whose result is discarded,
   so it may not exist — and the `ON CONFLICT` form PostgreSQL needs *requires*
   it.
5. **Bound the unbounded reads.** 36 `SELECT`s in `server/` have no `WHERE`
   clause, including full scans of `houses` that decode per row.

**Gate:** a full boot with the new error channel, and a deliberate broken query
proving an error is now distinguishable from an empty result.

---

## 5. Phase 1 — transport swap ✅ DONE 2026-08-14

**Status: passed inside Arma.** Stages 1–4 of `APS_fnc_pysqfSmoke` green on the
dev server — extension loaded, verb protocol decoding, Python reachable, and a
deliberately failing call arriving *as* a failure. Stage 5 fails only because no
PostgreSQL exists to point at yet, which is Phase 2's job.

The transport is [PySQF](https://github.com/doombadroid/PySQF), not the
third-party option this section originally named: a small server-side extension
with a ticketed non-blocking protocol, `ipc` back end. `call` holds the engine
thread for 0.72 µs.

Two engine facts were marked UNVERIFIED here and are now confirmed by that run:

- The array form of `callExtension` returns `[string, returnCode, errorCode]` —
  observed as `["["ok","0.1.0","ipc"]",0,0]`.
- **SQF's number type loses a Unix timestamp.** `diag.ping` returned
  `[time,1.78675e+09]` — ten significant digits rendered in six, because SQF
  numbers are 32-bit floats. This is §7.3 happening in front of you, for free:
  it is exactly why currency must travel as a string and why deleting
  `DB_fnc_numberSafe` would quietly corrupt balances above ~16.7M.

### What this phase originally said

Same database, same SQL strings, new extension — isolating the three things that
can take the server down while every query stays known-good.

**What must be got right on day one:**

- **What SQF sees when Python raises.** If the binding surfaces a traceback as a
  string, the existing `call compile` path turns it into nil, then a thrown
  error, then a permanently latched lock. The wrapper must return a typed
  `[ok, rows]` and the SQF side must default before touching it. Everything else
  in this plan is recoverable; this is not.
- **Per-frame budget.** extDB3 did the round trip on a worker thread. A
  synchronous call inside `callExtension` blocks the calling thread for the full
  round trip. PySQF's protocol is non-blocking by construction — `call`
  dispatches to a worker and returns a ticket, measured at 0.72 µs of engine
  thread time — so this concern is answered rather than outstanding. What is
  NOT answered is the per-frame cost on a populated server, as opposed to the
  bench loop that produced that figure. Original note follows: assuming the
  buffer win is free, and keep the heavy no-`WHERE` reads off the main path.
- **Missing-interpreter handshake.** `init.sqf:50-52` already does this for
  extDB3 and publishes a client-visible flag. Reproduce it, or a missing
  interpreter looks like a healthy server that quietly eats data.

**What you get immediately, before touching PostgreSQL:**

- The 10240-byte return cap disappears, which deletes the 5 pagination loops
  (one has a page size of **2**) and the `O(n²)` string-concatenation drain.
- The four decode helpers and much of the 414 downstream coercions become
  deletable — but **not yet** (see §7).

**Gate:** a week of normal play with no RPT errors, and the pagination loops
removed and measured.

**Rollback:** swap one extension back.

---

## 6. Phase 2 — engine swap, table by table

Order is chosen so the first mistakes are cheap and visible.

**First: `player_names`.** Four columns, one writer, read only by the Discord
bot's `!info`. It exercises the upsert rewrite, the `NOW()` rewrite, the
`datetime` decision and a bot driver swap. If it is wrong for a week the only
symptom is a stale alias list.

**Then `log`.** Append-only, mode 1, one game writer. The write-volume shakedown.

**Then `bot_commands`.** Converting its 5-second poll to `LISTEN/NOTIFY` removes
~17,280 queries a day and is the cheapest visible payoff. A missed message is
obvious immediately, which is exactly what you want from the first NOTIFY.

**Last: `players`, `houses`, `vehicles`, `gangs`, `exchange`** — only after §4.2
and §3 are done.

### Dialect work, by category

| Construct | Count | Rewrite |
|---|---|---|
| `ON DUPLICATE KEY UPDATE` | 12 | `ON CONFLICT (cols) DO UPDATE` — **requires the unique index to exist** |
| `AUTO_INCREMENT` | 58 | `GENERATED … AS IDENTITY` |
| `ENGINE=` / charset / collate | 69 | delete |
| `tinyint(1)` | 46 | `boolean` — **and see §7.1** |
| `ON UPDATE current_timestamp()` | 4 | trigger function per column; without it `players.lastupdated` freezes forever |
| `unsigned` | 10 | drop, or `CHECK (col >= 0)` |
| `QUOTE(...)` | 189 | **delete**, do not translate |
| `DATE_SUB` / `CONVERT_TZ` / `UNIX_TIMESTAMP` / `TIME_TO_SEC` | several | `interval` arithmetic, `AT TIME ZONE`, `extract(epoch …)` |
| `INSERT IGNORE` | — | `ON CONFLICT DO NOTHING` — trivial to translate, and a bank double-spend if dropped for one release |
| Stored procedures | 3 | recreate, or inline; currently called at mode 1 with no signal |

---

## 7. What is explicitly **not** in scope on day one

Each of these is a separate, later change. Bundling any of them into the engine
swap converts a recoverable migration into an unattributable one.

**7.1 The encoding — this one reverses now that scope is settled.**

The original advice here was "keep the TEXT columns byte-identical, change the
encoding much later." That was correct while a live database and three working
decoders were in play. **With no data and no consumer yet wired to this
project's database, it inverts: do JSONB now, at greenfield.**

The reasoning is the same either way — the custom array codec is implemented
**four times in three languages** (SQF, two Python bots, TypeScript in the
website), and changing it under live data means all three external decoders
return null against real player property, with a documented prior incident where
exactly that destroyed stored items. That is a nightmare *later* and nearly free
*now*: there is nothing to decode, and the consumers have to be repointed off
the predecessor's database regardless.

Doing it now also deletes the four SQF helpers and much of the 414 downstream
coercions in the same change, rather than leaving them to be unpicked against
live data. **This is the single largest saving available in the whole plan, and
it is only available before the first player connects.**

**The incoming carry-over (§9) makes this better, not worse.** Player data
arrives from the live database in the old encoding — so the transcode happens
**once, inside the ETL, in Python, using a decoder that already exists and is
already validated byte-identical** (`loonybot/enrique.py:84-115`). The
alternative — carry the old encoding across and convert later — means running
two encodings in production and doing the dangerous version of this change with
real players attached. Transcode at the door.

Caveat that survives the reversal: `houses.vinv`, `pinv`, `keyholders`, the
suite equivalents and `storage_vault` are the columns whose decode failures have
historically destroyed player property. Greenfield or not, they get the
round-trip assertions first.

**7.2 Removing the global lock.** It never guaranteed exclusion — the `waitUntil`
and the flag set are separated by a suspend point — but it *did* guarantee write
ordering, and the codebase says so explicitly in two places. **Mode 2 is being
used as a transaction substitute.** There are **63 read-modify-write pairs across
35 files**, including a marketplace escrow with no transaction, manual primary-key
allocation for gangs (`SELECT MAX(id)+1` then `INSERT`), and a lifetime-stats
array read-mutate-write that is already racy. Keep the lock, migrate the engine,
then remove it per call site with that list as the checklist.

**7.3 Deleting `DB_fnc_numberSafe`.** It exists to stop SQF emitting scientific
notation into a bigint column. SQF's only numeric type is a 32-bit float, exact
to 2²⁴ = 16,777,216. Hand `cash`/`bankacc` to PostgreSQL natively and every
balance above ~16.7 M silently rounds — into a column that accepts it without
complaint. Needs a non-float path first.

**7.4 The exact-decimal currency column.** Its correctness rests on the value
never becoming a float, and automatic type conversion is precisely the mechanism
that would make it one. Migrate with an explicit text cast and a round-trip
assertion on a 14-digit value with a non-zero fourth decimal.

**7.5 Removing the input sanitizers.** They strip quotes, so with parameterised
queries they are redundant — but they have been *mangling* data for years
(`O'Brien` is stored as `OBrien`). Delete them and apostrophes start reaching
~30 shell-interpolated `docker exec … -e "<sql>"` call sites that are **not**
parameterised. **Removing the sanitizer creates an injection vector.** Keep them
until every consumer is parameterised, and treat them as data normalisation, not
security.

---

## 8. The three-consumer problem

The game is not the only writer. `players`, `houses`, `players_global`, `bans`
and `bot_commands` are written by **three** processes; `server_control` has
**five** writers including three OS-level daemons.

**Scope settles most of this.** The frozen box keeps MariaDB, and its website,
bots and deploy scripts keep working against it, untouched. There is no same-day
three-way cutover, because this project's consumers are not yet pointed at a
database of its own at all — `website/src/lib/db.ts:19` still defaults to the
predecessor's.

What remains is a **fork-divergence** problem rather than a migration problem:
the shared code has to grow either a second driver or a second branch. Decide
which deliberately. Dual-driver is tempting and usually rots; a fork is honest
but doubles the maintenance of anything genuinely common.

The constraint that still bites, if these consumers are ever pointed at both
engines at once: **dual operation across engines is not possible for shared
tables** — there is no replication path for the custom encoding, and the bank
balance is written by three processes.

The website is unusually cheap — all ~102 placeholders funnel through one
`q(sql, params)` in `website/src/lib/db.ts`, so a `?` → `$n` rewrite inside that
one function converts all 133 call sites at once. Nine `insertId` uses need
`RETURNING id`.

**The consumers nobody counts are the CLI ones.** Roughly ten scripts —
including the restart watchdog and the scheduled-restart control plane — shell
out to `docker exec … mariadb -e "<sql>"`. **They have no driver to swap; they
invoke a binary that will not exist.** They fail simultaneously, and several of
them are how the server gets restarted. Inventory and port these *before*
cutover, not after.

Also note the only two real transactions in the estate are in the bots
(`SELECT … FOR UPDATE`), and they protect the bots from each other but not from
the game's full-row flush. The mitigation is a *convention* — both bots check an
`online` table first — which depends on an `INSERT IGNORE` that runs at mode 1
with no error channel.

---

## 9. The one-time carry-over

**This is the real cutover, and it is not an engine migration.**

The live server is running now, near-stock, on the old map, with real players.
This project is the overhaul plus a map change. At open beta, **player data
carries across**: live MariaDB → this project's PostgreSQL. One direction, one
event, no sync, no dual-write, and no path back.

That is a *much* easier problem than the dual-run this plan was originally
guarding against. It is also a completely different problem from everything in
§1–§8, and it should be built and rehearsed separately.

### The hard part is semantics, not engines

A map change means **anything anchored to the old map cannot carry**. This is a
product decision with a technical floor, and it is the biggest question in the
whole project:

| Carries cleanly | Cannot carry | Judgement call |
|---|---|---|
| money, bank | `houses.worldspace` (owned buildings) | vehicles — the rows are non-spatial while garaged, so they carry if you force `active = 0` |
| licences | `storage.worldspace` / `houseworldspace` | gang bases — identity and bank carry, the plot does not |
| exp, levels, talents, prestige | `players.position` (reset to spawn) | wanted / bounties — carry, or amnesty at launch? |
| gear, loadouts | `vehicle_mem` (restart persistence only) | suites — the tower is map furniture |
| stats, achievements | turf, cartels, capture points | rigs, skimmers — anchored to world objects |
| bans, Discord links | | |
| gang identity, membership, bank | | |

**Players who own property will lose it.** That needs a compensation rule —
refund at purchase price, at market value, or grant a credit — and the ETL has
to implement whatever is chosen. Deciding it late means deciding it under
pressure with players watching.

There is a second, quieter question: this project overhauls the economy. Carrying
balances forward at 1:1 imports the old economy's inflation into a new one. A
scaling factor is worth considering while it is still cheap to apply.

### Shape of the ETL

Source schema is **the live box, dumped fresh** — not `sql/`. The repo does not
know the full schema in either direction: this project's own additions
(`cyberdeck_modules`, `intake_*`, `malden*`) appear in **no** `.sql` file, only
in `deploy/run-boot2.sh` and runtime SQF DDL.

One Python script, run repeatedly, doing four things at once:

1. **Dialect** — MySQL types and syntax to PostgreSQL (§6).
2. **Encoding** — the custom array codec to JSONB (§7.1), with the existing
   validated decoder.
3. **Schema delta** — new columns defaulted, dropped columns discarded, renamed
   columns mapped **by name, never by position** (the positional-read hazard in
   §4.2 applies to the ETL too, and here a one-column slip silently moves every
   player's money).
4. **Semantics** — the carry-over rules above, including compensation.

### Rehearse it early and often

The whole thing is testable at zero risk, and the loop should exist long before
beta: dump live → transform → load into a scratch PostgreSQL → boot this project
against it → inspect. Repeat until boring.

Two properties worth building in from the first run:

- **Idempotent.** Re-runnable from a fresh dump without hand-cleaning.
- **Reconciling.** It should *count* what it moved and assert against the source
  — players in, players out, total currency in, total currency out, per-table
  row deltas — and refuse to complete on a mismatch. The failure mode of a
  silent ETL is discovering three weeks later that 4% of players lost their
  licences.

Run it against a copy of the live database, not a synthetic fixture. Real data
is where the encoding edge cases live — the empty strings, the apostrophes the
sanitizers mangled, the balances above the float-exact range (§7.3).

### Freeze semantics

Live keeps running while this is built. At beta you take a final dump, and
anything players do on live after that instant is lost. Either take a
maintenance window, or accept a known delta and say so publicly beforehand.
Decide which, and communicate it — this is the one part of the plan players
experience directly.

---

## 10. Cutover and rollback

**Forced order:** dump the live structure *with routines, triggers and events* →
Phase 0 fixes under MariaDB → transport swap → engine swap per §6 → everything
in §7, separately.

**The engine cutover is free; the carry-over is the real one.**

For the engine port there is no production cutover at all — no live players on
this project, and `looneybin_test` is disposable, so it is a config change. The
sharp end of cutover risk (in-flight fire-and-forget writes, queue drains,
maintenance windows, angry people) belongs to §9's ETL and to nothing else here.

**Rollback, during the engine port, is a branch revert.** Not a reverse
migration. That is worth stating explicitly because it is the single biggest
reason to do the aggressive version of this work *now*: every irreversible
decision in §7 is reversible today and permanent the moment §9 runs.

So the corollary is a deadline. **Everything in §7 that would be "later" under a
live database is "now or never" here**, and the deadline is open beta, not some
vague future: the encoding, the money representation, the named-column login
read, the error channel. Once player data has landed, each becomes a data
migration with three consumers — exactly the situation this plan was written to
avoid, arrived at by procrastination instead of necessity.

**After §9 runs, rollback stops being free.** From the first post-ETL login,
going back means a reverse transform — and unlike the forward one, nobody will
have written or tested it.

---

## 11. The three things to keep on the wall

1. **`[]` means "no rows", "query failed", and "extension gone."** Fix that
   first or every other risk gets one degree quieter.
2. **229 writes have no error channel at all.** Anything broken in a mode-1
   statement is invisible by construction.
3. **The one that will actually get you is a boolean.** `SELECT (predicate)`
   returns `1` in MariaDB and `true` in PostgreSQL, and SQF's `isEqualTo` is
   type-strict, so `true isEqualTo 1` is `false`. One such site silently charges
   players for a free daily action, with no error, no log, no `[]`, and a UI
   that is self-consistently wrong. **Grep every `SELECT (<predicate>)` before
   cutover, not after.**

---

## 12. Open questions

- ~~Does the frozen production box move?~~ **Settled 2026-08-14: no. Only this
  project moves; the frozen box stays on MariaDB.**
- ~~Does the transport expose an async call form?~~ **Answered: yes, by
  construction.** PySQF never blocks — `call` returns a ticket, `poll` and
  `chunk` do no work. Confirmed in Arma 2026-08-14.
- What is on the live database that the repo does not know about — triggers,
  views, events, grants? Still needed, but the reason has changed: not to
  migrate it, but because it is the only complete description of the schema this
  project inherits. `deploy/run-boot2.sh:96` drops a trigger that exists in no
  `.sql` file here, which proves the repo's picture is incomplete.
- Do the website and bots fork, or grow a second driver? (§8) Cheap to decide
  now, expensive after further divergence.
- ~~Is the `looneybin_test` data disposable?~~ **Settled: yes.** The dev cutover
  is a config change.
- **What carries over, and what compensates for what does not?** (§9) The single
  biggest open question in the project, and a product decision rather than a
  technical one. Owned property cannot survive the map change; players who paid
  for it need a rule.
- **Do balances carry at 1:1, or scaled?** (§9) Carrying an old economy's
  inflation into an overhauled one is a decision worth taking deliberately while
  it is still a one-line change in a transform script.
- **When is the freeze, and is there a maintenance window?** (§9) This is the
  only part of the plan players experience directly.
- `MALDEN.md:101` needs correcting — it claims nothing has been run, and a dev
  instance has been running against `looneybin_test`.
