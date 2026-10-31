# ArmaQuest → Armapunk 2035 dev integration — design

**Date:** 2026-08-15
**Target:** `arma3server_dev` (port 2342, `Armapunk2035.Malden`, `-serverMod=@extDB3;@AP_server`)
**Upstream library:** https://github.com/doombadroid/ArmaQuest
**Status:** design, approved decisions recorded below; not yet implemented

---

## 1. What this is

ArmaQuest is a config-driven quest library — 11,077 lines of SQF across 58 files —
that has **never been executed**. Its own README says so. This change installs it
into the Armapunk 2035 mission on the dev server, wires it to the mission's real
economy and database, builds an all-new quest catalogue on it across six givers and
three sides, and deletes the legacy quest system — and all 134 of its quests — that it
replaces.

It is deliberately done as **one cut** rather than staged. That was decided with the
staged alternative on the table: staging (boot → store → economy → triggers → journal
→ content → deletion) would keep every failure attributable to one surface, and one
cut means a first boot that is simultaneously exercising an unrun library, an
unbridged economy, an in-flight database migration and a webview. The owner chose one
cut with that trade-off stated. §9 lists what that costs and how we keep it debuggable
anyway.

### Decisions on the record

| Question | Answer |
|---|---|
| Scope | Full integration in one pass |
| Legacy system | Replaced, not coexisting |
| Persistence | PostgreSQL via PySQF — **not** extDB |
| Journal UI | HTML journal now, via the already-vendored arma-webui |
| Payout mechanism | Direct DB write + client refresh |
| `countItem` on the server | Stale-DB read, limitation documented (§5.3) |
| Legacy quest DB columns | Dropped in the same cut |
| Legacy quest content | **All 134 dropped.** Catalogue is all-new (§7) |
| Quest givers | 6: four civ Fixers, one cop, one med (§7.1) |
| Story | One civ mainline; radiant on all three sides (§7.2, §7.3) |
| Giver access | NPC walk-up **and** cyberdeck contact (§7.4) |

---

## 2. What already exists (verified, not assumed)

Everything in this section was read off the tree or the running server, not recalled.

**The dev server is up and already speaks Postgres.** PySQF is loaded
(`@AP_server/pysqf_x64.so`, daemon `pysqfd.py --modules pysqf.db,apdb`), the
`armapunk-pg` container is healthy on loopback 5432, and `DB_fnc_asyncQuery` routes
through `apdb.query`. The dev log carries a successful `[apdb] PostgreSQL reachable`
handshake.

**That path is not currently healthy.** The same log carries repeated
`apdb.query was refused: backend refused the call` and `[pysqf/ipc] disconnected:
read failed or peer closed`, plus `UntranslatableSQL` on legacy MariaDB dialect
(`AUTO_INCREMENT`, `CONVERT_TZ`, `UNIX_TIMESTAMP`). This is the in-flight migration's
problem, not ArmaQuest's, but ArmaQuest's store sits on top of it — see §9.2.

**There is a vendoring precedent.** `arma-webui` lives at
`mission/Armapunk2035.Malden/webui/` as a plain copy, wired by one `#include` in
`Functions.h` and one entry in `description.ext`'s `allowedHTMLLoadURIs`. PySQF uses
a stricter pattern (`scratchpad/vendor_pysqf.py` regenerates its four SQF files, which
carry "do not hand-edit" banners) because it needs a symbol rename. ArmaQuest needs no
rename — its `aq_` prefix is already unique — so it follows the webui pattern with a
sync script added for provenance.

**The legacy quest system is entirely client-authoritative.** `AP_activeQuest`,
`AP_questProgress`, `AP_completedLifetimeQuests` are client variables;
`fn_handleQuest.sqf`'s `_handleQuestComplete` credits `AP_atmcash` on the client and
calls `AP_fnc_ndRequest` for New Drachma. 111 references to `fn_handleQuest` across
mission and server. The catalogue is `core/config/fn_questsCfg.sqf` — 24 KB minified
onto 2 lines, 134 quests, decoded in `QUESTS.md`.

**Money is already server-authoritative; items are not.** `APS_fnc_ndCreditSrv` does
`UPDATE players SET new_drachma = new_drachma + …` then pushes `AP_fnc_ndSync` to the
owning client — direct DB write plus client refresh, exactly the payout model chosen.
Virtual items have no equivalent: they live in client `missionNamespace` vars
(`AP_invMonVars`), are persisted only by mode-3 `ClupdatePartial` saves, and every
server-side grant in the codebase (`fn_miningSRV`, `fn_qhLootSRV`) works by
`[[true,_cls,_qty],"AP_fnc_handleInv",_player] spawn AP_fnc_MP`.

---

## 3. Vendoring

`~/ArmaQuest` is copied to `mission/Armapunk2035.Malden/ArmaQuest/`, preserving its
directory layout (`config/ functions/ server/ types/ diagnostics/ ui/`).

`scratchpad/vendor_armaquest.py` performs the copy and writes the upstream commit SHA
into `ArmaQuest/VENDORED.txt`. It is a copy, not a generator: files are byte-identical
to upstream, so a local edit is not silently discarded the way an edit to a generated
PySQF file would be. The rule is instead directional — **library changes are made in
`~/ArmaQuest` and land here by re-running the script.** The one library change this
work requires (§4) is authored upstream first.

The mission's `.gitignore` must not exclude the vendored tree.

## 4. Wiring — three touch points

```cpp
// description.ext, top level
#include "ArmaQuest\config\CfgArmaQuest.hpp"

// description.ext, in the existing CfgCommands block
allowedHTMLLoadURIs[] += { …, "ArmaQuest\\ui\\*" };

// Functions.h, OUTSIDE class AP_Client_Core
#include "ArmaQuest\config\CfgFunctions.hpp"
```

The placement of the third include is load-bearing and is the same footgun already
documented in-tree at `Functions.h:1079` for arma-webui: nested one level too deep,
`CfgFunctions` resolves the path relative to the enclosing class and every function
fails to compile with `Script ArmaQuest\functions not found`, once per attempt.

ArmaQuest's server functions compile into `missionNamespace` on the server along with
everything else; they guard themselves with `isServer`. No `AP_server` change is
needed except the SQL adapter in §5.1.

## 5. The host boundary

### 5.1 Store — a new `sql` driver

ArmaQuest's store driver contract is four verbs moving strings, with no knowledge of
quests:

```
"init"  []             -> BOOL
"load"  [_key]         -> STRING   the stored JSON, "" when absent
"save"  [_key, _json]  -> BOOL
"flush" []             -> BOOL
```

Keys are `"board"` and `"player:<uid>"`. Nothing else is stored. Write-behind is owned
by the facade above the driver (`AQ_Settings >> flushInterval`, default 30s), so
progress ticks do not become database writes.

Store selection is a hardcoded `switch` in `aq_fnc_srvStore`, so a new backend is an
**upstream ArmaQuest change**: add `server/fn_storeSql.sqf`, a
`case "sql": { "aq_fnc_storeSql" }` arm, and the `CfgFunctions` entry.

The driver stays host-agnostic. It reads a new setting:

```cpp
// AQ_Settings
store   = "sql";
sqlExec = "APS_fnc_aqSql";   // host function: [_sql, _mode] -> result
```

Armapunk supplies that function as a three-line server-only mission file that calls
`DB_fnc_asyncQuery`. **Routing through `DB_fnc_asyncQuery` rather than `apdb.query`
directly is deliberate**: ArmaQuest inherits whatever transport that already resolves
to, and the library keeps zero knowledge of PySQF's existence.

**Which engine that is, is a RUNTIME fact — not a property of this branch.**
`DB_fnc_asyncQuery` selects PostgreSQL (over PySQF) only when the PySQF daemon carries
`AP_DB_POSTGRES=1`, and falls back to extDB3/MariaDB on any doubt: a missing daemon, an
unset flag, an unreachable database. That fallback is deliberate — it is what makes the
migration reversible by one flag rather than 400 edits.

Two consequences the store must respect. Both have already produced a wrong answer
during this work, which is why they are stated rather than assumed:

- **The table must exist on whichever engine is live**, and on the specific database
  that engine is pointed at. The PostgreSQL dbname comes from the daemon's own
  `PYSQF_DB_DSN`, which is **not** necessarily the one in `deploy/postgres/.env` — they
  differed here, and the migration was first applied to a database nothing reads. Read
  the DSN off the running process. Getting this wrong fails silently: the store reports
  the table missing at init, which reads like a code fault rather than a misplaced
  migration.
- **The driver's SQL must be correct on BOTH engines**, because either can be live. This
  is why the escaping defect mattered: MySQL/MariaDB's default `sql_mode` treats
  backslash as an escape and corrupts `toJSON` output, while PostgreSQL
  (`standard_conforming_strings=on`) does not. Measured on both. A defect that manifests
  on only one engine is not hypothetical here — it is one unset flag away.

**Dialect: MariaDB.** `apdb.py` states its input contract is MariaDB-flavoured SQL and
translates on the way through. The driver writes MariaDB, which also means it works
unchanged if the transport falls back to extDB3.

**Schema** (created by migration, never by the driver — the dev log already shows a
runtime `CREATE TABLE … AUTO_INCREMENT` refused as untranslatable):

```sql
CREATE TABLE armaquest_state (
  skey       VARCHAR(64) PRIMARY KEY,
  data       TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

`data` is **TEXT and must never become `jsonb`**. `apdb.py` re-encodes `jsonb` columns
into the game's own `mres` array codec on read; ArmaQuest's payload is its own JSON,
and that translation would corrupt it silently. It is also not an mres column, so it
is read `QUOTE()`-wrapped like any plain text column — the inverse of the mres rule in
§5.3.

Single-quote escaping in `data` is the driver's responsibility before interpolation.

### 5.2 Profile — money

```
payMoney   [uid, amount] -> APS_fnc_ndCreditSrv
takeMoney  [uid, amount] -> APS_fnc_ndDebitSrv
```

Both already do direct DB write plus client refresh and hold a per-UID lock. They take
a unit object, not a UID; the profile stub resolves UID → unit with the helper
`profile_default.sqf` ships, and returns `false` when the player is offline rather
than reporting a payment that did not happen — a `payMoney` returning `true` without
paying is the single worst outcome the system can produce (the player cannot repeat
the quest and has nothing to show for it).

**Amounts stay strings for the entire path.** `new_drachma` is `decimal(20,4)`; SQF
numbers are 32-bit floats and lose exact representation above 16,777,216. Config
rewards are authored in legacy cash and converted with `AP_fnc_ndFromLegacy` (6000:1),
matching the conversion the mission already applies to quest rewards — so a reward
authored as a cash figure is worth what a player expects a cash figure to be worth,
and reward values stay comparable to the rest of the economy rather than becoming a
second, unanchored currency scale.

### 5.3 Profile — items, and the honest limitation

```
giveItem  [uid, class, qty] -> remoteExec AP_fnc_handleInv to the owning client
takeItem  [uid, class, qty] -> remoteExec AP_fnc_handleInv (negative) to the client
countItem [uid, class]      -> see below
```

There is **no authoritative server-side read of a player's virtual inventory** in this
mission (§2). ArmaQuest's design assumes there is: the server re-reads `countItem`
before agreeing with any client-reported count, and that re-read is what makes a lying
client harmless rather than profitable.

`countItem` is one of the two profile entries called on **both** machines, so it gets
two implementations behind one name:

- **On the client** — read the live `missionNamespace` item variable. Accurate, free.
  This feeds the watcher's own gating and the local display.
- **On the server** — `SELECT <sideGearCol> FROM players WHERE playerid='<uid>'`,
  decode with `DB_fnc_mresToArray`, count the class.

The gear column is side-specific (`civ_gear` / `cop_gear` / `med_gear`, selected as
`_gearCol` in `fn_queryRequest.sqf:73`), so the stub resolves the player's side first.

**The column is mres-encoded and must be read BARE — never `QUOTE()`-wrapped.**
`DB_fnc_mresArray` stores `str(str(x))`, so the blob keeps its own outer quotes, which
are the delimiters `DB_fnc_asyncQuery`'s `call compile` consumes. A `QUOTE()` adds a
second layer, `DB_fnc_mresToArray` receives literal outer quotes, its inner
`call compile` produces malformed SQF and returns nil, and the value never decodes.
This has bitten this codebase twice (house keyholders, gang fortress leaderboard), both
times as silent data loss rather than an error at the call site.

**The limitation, stated plainly:** the server's copy is only as fresh as the player's
last mode-3 `ClupdatePartial` save. Between syncs it is stale. Therefore `gather`,
`sell` and `deliver` objectives in this host are **client-reported with a lagging
server sanity check**, not server-verified. A client that can manipulate its own item
vars can outrun the sync window and satisfy an item objective it did not earn.

Everything else remains server-side and unaffected: fact rate limiting
(`factRateLimit`, 60 per 10s), the count ceiling (`factMaxCount`), position re-checks
with the radius multiplier, the quest state machine, prerequisite evaluation, and every
payout. The exposure is bounded to item-count objectives, and the ceiling on the abuse
is the reward attached to one such quest.

Two ways out exist and are explicitly **not** in this scope: forcing a mode-3 sync at
payout time and reading fresh (one round trip per completion, needs a timeout path),
or a server-side inventory mirror fed by every `handleInv` call site (a subsystem, and
one that would fix dupe classes elsewhere). Whichever is chosen later, only this one
stub changes.

### 5.4 Profile — the rest

```
hasLicense   [uid, license] -> read the side licence column, mres-decoded, BARE
grantLicense [uid, license] -> write it back + refresh the client
playerUid    [object]       -> getPlayerUID
notify       [uid, text]    -> remoteExec AP_fnc_handleMessage to the client
```

`playerUid` is the one entry that may never be empty — without it there is no key to
persist under, and `preInit` fails loudly rather than starting.

## 6. Objective types — one new host type

ArmaQuest ships eight types (`gather`, `sell`, `craft`, `deliver`, `zoneHold`, `visit`,
`kill`, `talk`). None of them expresses "do X, N times" against an arbitrary host
event — "breach three ATMs", "burn a proxy", "take a cyberdeck job" — which the deck
content in particular is built out of.

`aq_fnc_registerType` exists for exactly this: a host registers a type behind a
five-verb contract (`arm`, `event`, `progress`, `describe`, `disarm`) with no engine
edit. Registration is a gate — the type is probed against a real config class before it
is admitted, and one that cannot render `progress` and `describe` is rejected loudly,
so an incomplete type cannot reach players.

We add **one** type, `action`, which counts named event verbs:

```cpp
class objectives {
    class chop { type = "action"; verb = "choptree"; count = 25; };
};
```

That is a direct structural match for the host's existing `[_mode, _item, _quantity]`
event shape, so instrumenting a new verb costs one line at the site that already knows
the thing happened.

**Call-site instrumentation is demand-driven, not a port.** Because no legacy quest
survives (§7), there is no 111-site mechanical conversion. Instead: **the set of
instrumented verbs is derived from the authored content**, so a verb is added only
when a quest or template actually references it. The generator that builds the content
emits the verb list, and a check asserts every referenced verb has at least one
`aq_fnc_event` call site — turning "silently missed a site", which has no error
attached, into a build-time failure naming the verb.

The six cyberdeck triggers `QUESTLINE_PROPOSAL.md` identifies as missing (`qhcast`,
`qhbreach`, `proxyarm`/`proxyburn`, `icetraced`, `chipinstall`, `qhtraced`) are in
scope, because the mainline is written to teach the deck and those are the verbs it
needs.

`fn_handleQuest` and every one of its 111 references are deleted outright (§9), not
converted.

## 7. Content — all new

**No legacy quest is ported.** All 134 are deleted with the system that ran them
(§9). The catalogue is authored from scratch against the new structure, which means
the content is designed for the objective types and giver model that exist rather
than bent to fit rows written for a different engine.

What that buys, concretely: the 111-site mechanical conversion disappears (§6), and
the ⚔ quests that cannot be finished solo, the `multiStage`/`qreserved` fields nothing
reads, and the flat no-ordering catalogue `QUESTLINE_PROPOSAL.md` complains about all
go away rather than being carried forward.

### 7.1 Giver roster

Six givers. Names are placeholders and are expected to change; the ids are what
content references, so the ids are what must be stable.

| id | display name | side served | role |
|---|---|---|---|
| `fixer_1` | Fixer 1 | civ | mainline opener + radiant |
| `fixer_2` | Fixer 2 | civ | mainline act + radiant |
| `fixer_3` | Fixer 3 | civ | mainline act + radiant |
| `fixer_4` | Fixer 4 | civ | mainline act + radiant |
| `maxsec_command` | MaxSec Command | cop | radiant only |
| `pharma_technica` | Pharma Technica | med | radiant only |

**Givers have no side field** — only quests and templates do. So all six exist in the
world for everyone, and a player of the wrong side opening MaxSec Command sees an
empty board. Side lives on every quest (`side = "civ" | "cop" | "med"`) and every
template, mapped through `AQ_Settings >> sideMap`, which already reads
`{ {"civ","CIV"}, {"cop","WEST"}, {"med","GUER"}, {"reb","EAST"} }` — an exact match
for this mission's sides, so no settings change is needed.

### 7.2 The mainline (civ)

One authored questline, civ side, spread across the four Fixers.

- **Entry is `fixer_1` only.** An authored quest's `giver` is a single mandatory
  string, matched by exact equality at `server/fn_srvBoard.sqf:325`; only radiant
  templates take a `givers[]` array. So "any Fixer can start you" is not expressible
  without a library change, and we are not making one. After the opener the line
  spreads across Fixers 2–4.
- **Within one Fixer's stretch**, use `chain` — it offers the next quest immediately
  on completion, by the same giver.
- **Between Fixers**, use `requires[] = {"quest:<previous_id>"}` on a quest whose
  `giver` is the next Fixer. `chain` cannot hand off across givers.

Both are shipped fields. The distinction matters because using `chain` for a
cross-giver step produces a quest that is never offered by anyone, which
`aq_fnc_reachability` reports by name but which is invisible in the config itself.

`QUESTLINE_PROPOSAL.md`'s THE SIGNAL sketch (three acts, a fixer contacting you on the
handset, teaching the deck) is the starting point for this content, not a separate
future project — its structure is what the four-Fixer split is for. The actual beats
are authored during implementation and reviewed as content, not fixed here.

### 7.3 Radiant

Radiant boards on all three sides, per giver:

| side | givers | templates |
|---|---|---|
| civ | `fixer_1`–`fixer_4` | `side = "civ"` |
| cop | `maxsec_command` | `side = "cop"` |
| med | `pharma_technica` | `side = "med"` |

Each template declares `side` and a `givers[]` list; each giver declares its own
`boardSize`. `AQ_Settings >> boardSize` stays at its default of `0`, so a giver holds
radiant offers only where one was explicitly asked for — a giver quietly holding
offers nobody authored is content appearing where nobody put it.

`boardMode` stays `"shared"`: the server keeps K offers per giver, visible to
everyone, and `offerLifetime` expiry creates the competition a job board exists to
create. Per-giver `boardSize` and `offerLifetime` values are content decisions, set
during authoring.

### 7.4 Reaching a giver — two triggers

Both access paths are supported, and a giver may carry either or both.

- **Walk-up NPC** — the shipped `addAction` driver. No new code. Requires the giver
  to declare `object` and `marker`, which `aq_fnc_srvSpawnGivers` then spawns
  server-side and publishes as `aq_giverObj_<giverId>` so clients can bind to it.
- **Cyberdeck contact** — a host trigger driver registered with
  `["deck", <fnc>] call aq_fnc_registerTrigger`, so a Fixer can reach the player on
  the handset. This is the one piece of new client code the giver model needs.

**A registered driver must fire `aq_talked` itself.** The shipped `addAction` driver
does it for you; a custom one that forgets makes every `talk` objective on the server
impossible to complete — and a `talk` objective is exactly what the return leg of a
courier job uses, so the failure lands on finished work.

An unknown `trigger` name is a preInit error naming the giver, deliberately: a giver
nobody can reach is content that exists and cannot be played, which is worse than a
giver that does not exist.

### 7.5 Placement

Six markers on Malden, one per giver, plus the NPC objects. This is map work and goes
through the existing pipeline (`tools/edit-map.sh`, `npc_place.py`) rather than being
invented here — the map is the owner's, and marker positions are a content decision.

Marker ids follow the library's own convention, `aq_giver_<giverId>`. The names are
fixed here because content and config both reference them; the positions are not.

## 8. Journal

`ArmaQuest/ui/journal.html` becomes a cyberdeck app. `aq_fnc_journal` is already built
for this: it exposes `["attach", _ctrl]` to bind an arma-webui browser control,
`["sync", _records]` as the single inbound full-replacement verb, and it guards every
call into the web layer so a missing or unopened page degrades to native tasks rather
than erroring per repaint.

Registration follows the existing deck pattern (`LIST_APPS` / `TREE_APPS` and the app
catalogue in `ui/html/deck.html`).

**The page → SQF payload cap is 10,240 characters, measured**, and is enforced by
arma-webui's own guard. Only player actions travel that direction (accept, abandon,
select), all of which are small; state pushes go SQF → page and are uncapped. The
journal must not be built to send state upward.

Native tasks stay enabled underneath. They cost nothing, they work before the page is
ever opened, and they are the fallback that makes the webview non-critical.

## 9. Deletion

Removed in the same cut:

- `core/quests/` — all six functions, including `fn_handleQuest` and all 111
  references to it (deleted, not converted — §6)
- `core/config/fn_questsCfg.sqf` and the entire 134-quest catalogue it holds
- their `Functions.h` entries
- the `fn_questSel` dialog and its `MasterHandler.h` registration
- the `AP_quest*` / `AP_completedLifetimeQuests` / `AP_LifetimeProgressQuests` client
  variables and their `ClupdatePartial` cases
- the legacy quest columns `completed_quests` and `progress_quests`, dropped by
  migration, and removed from the `fn_queryRequest.sqf:73` select list

Kept: `sounds/questStart.ogg`, `questDoneNormal.ogg`, `questDoneSeasonal.ogg`, rewired
to ArmaQuest notifications.

**Dropping the columns is the one irreversible step in this change.** It runs against
the dev database only. The live database is frozen behind the 2026-09-11 migration
window and is not touched. Dev is explicitly *not* a valid rehearsal source for live
(its faction sweep already renamed columns forward), so this drop proves nothing about
the live drop and must be re-planned for live separately.

## 10. Risks

1. **11,077 unrun lines, one cut.** Expect several boot failures. A malformed include
   or unbalanced brace does not degrade — the mission fails to load entirely. Every
   edited `.sqf`/`.hpp` gets a brace/bracket balance check before packing.
2. **The DB transport is currently unhealthy.** `backend refused the call` and IPC
   disconnects are in the dev log right now. If the store fails, that is the first
   suspect, and it must be root-caused rather than worked around — a store that
   silently falls back to `none` and a store hitting a database outage must not be
   indistinguishable, which is why `aq_fnc_srvStore` logs both loudly.
3. **Decimal money through a float.** Any point where an ND amount becomes an SQF
   number loses places. The path is string-only by construction; a reviewer should
   check it as such.
4. **Every quest in the game is deleted and replaced with content that does not exist
   yet.** This is now the largest risk in the change, and it is a content risk rather
   than a technical one: the cut removes 134 working quests, and what ships in their
   place is however much of the mainline and however many radiant templates are
   actually authored. A thin catalogue is a visible regression to players even if
   every line of code works. Authoring volume is the schedule driver, not the wiring.
5. **A missed event verb is a dead quest with no error.** Mitigated structurally
   rather than by review: the content generator emits the referenced verb list and the
   build asserts each one has an `aq_fnc_event` call site (§6).
6. **No fallback quest UI.** Deleting the legacy system in the same cut means that if
   the journal fails, dev has no quest interface at all. Native tasks are the mitigation
   and are enabled from the start.
7. **A custom trigger driver that forgets `aq_talked`** makes every `talk` objective
   uncompletable (§7.4) — a failure that only shows up at the end of a courier job.
8. **Item objectives are not server-verified** (§5.3). Accepted, scoped, documented.

## 11. Verification

Nothing is claimed working on the strength of the code having been written.

**Boot gates** — in the dev RPT after `reload-armapunk2035.sh`:
- `[AQ]` preInit validation passes with no `PROBLEM` lines
- the store driver reports `init` success and names `sql`, not a fallback to `none`
- zero `Script ArmaQuest\… not found`

**Static gates:**
- `aq_fnc_validate` — catalogue clean
- `aq_fnc_reachability` — every authored quest reachable; specifically, no mainline
  step orphaned by using `chain` where a cross-giver `requires[]` token was needed
  (§7.2), which is the one structural mistake this content shape invites
- every event verb referenced by content has an `aq_fnc_event` call site (§6)
- `aq_fnc_dryRun`
- `grep -rn "fnc_handleQuest"` returns nothing

**In-game, on dev, as a real client:**
- accept a quest from the journal page; it appears as a native task too
- make progress; the counter moves in the journal and in the task
- complete it; `new_drachma` for that UID changes in Postgres and the client's balance
  refreshes without a relog
- reload the server; the player's quest state comes back — proving `armaquest_state`
  was written and read, which is the only thing that proves the Postgres path end to
  end
- open the journal on a second client to confirm the board is server-owned

**Giver gates** — each needs a client actually standing there:
- all six givers spawn and are interactable via walk-up
- a Fixer reached through the **deck** path offers the same board as the walk-up path,
  and completing a `talk` objective through the deck driver works — proving the custom
  driver fires `aq_talked` (§7.4)
- a **cop** client sees MaxSec Command's board populated and a Fixer's civ board empty,
  and a **civ** client sees the reverse — proving `side` gating, which is the only
  thing keeping three sides' content separate
- the mainline opener is offered by `fixer_1` and by no other Fixer

**Explicitly unverifiable in this pass:** live-database behaviour. Dev is not a
rehearsal source for live.

## 12. Out of scope

- Cop and med **mainlines**. Both sides get radiant content in this pass; authored
  storylines for them are a later pass, and the structure supports them without change.
- Adding `givers[]` to authored quests. Considered and declined (§7.2) — the mainline
  opens on `fixer_1` rather than changing the library.
- Final giver names. `Fixer 1`–`4`, `MaxSec Command`, `Pharma Technica` are
  placeholders; the **ids** are the stable part.
- Giver marker positions on Malden — content decision, existing map pipeline (§7.5).
- Fixing `countItem`'s staleness (§5.3)
- Any live-server deployment or live schema change
- The extDB3 → Postgres switch itself, which remains a separate project
