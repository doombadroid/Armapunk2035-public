# ArmaQuest Dev Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install ArmaQuest into the Armapunk 2035 mission on the dev server, wired to the real economy and PostgreSQL, with six givers, a civ mainline, per-side radiant boards and an HTML journal — replacing and deleting the legacy quest system.

**Architecture:** ArmaQuest is vendored into the mission as a plain copy and wired by two `description.ext`/`Functions.h` includes. Persistence is a new host-agnostic `sql` store driver that routes through the mission's existing `DB_fnc_asyncQuery`, so it inherits the PySQF→Postgres transport without knowing PySQF exists. Money is paid server-side by direct DB write plus client refresh; items are granted by remoteExec to the owning client, and item *counting* on the server is a documented stale read. Content is all new: one civ mainline across four Fixers, radiant templates on three sides.

**Tech Stack:** SQF (Arma 3 2.18+), Arma config (`.hpp`/`.ext`), PostgreSQL 18 via PySQF/`apdb`, Python 3 (tooling + `unittest`), arma-webui (HTML journal).

**Spec:** `ARMAQUEST_SPEC.md` in this repo. Where plan and spec disagree, the spec is wrong and must be updated — do not silently diverge.

---

## Global Constraints

Copied from `CLAUDE.md` and the spec. Every task's requirements implicitly include this section.

- **Client fn** `core/<domain>/fn_name.sqf` → called `AP_fnc_name` → **MUST** be added to `Functions.h`.
- **Server fn** `server/AP_server/core/TON|DB/fn_name.sqf` → called `APS_fnc_name` → **MUST** be added to `server/AP_server/config.cpp`.
- **`AP_` vs `APS_` is load-bearing.** The server compiles both CfgFunctions trees into `missionNamespace`; a client fn and a server fn sharing a name silently overwrite each other. Never flatten `APS_` to `AP_`.
- **remoteExec is whitelisted.** `CfgRE.hpp` is `mode = 1`. Any function called across machines **must** have an entry or it silently fails. `allowedTargets`: `2` = server only (client→server), `1` = clients only (server→client), `0` = any.
- **Always call through `AP_fnc_MP`**, not raw remoteExec, for mission code: `[[args], "fn_name", target, false] spawn AP_fnc_MP`. (Vendored ArmaQuest uses raw `remoteExec`; it is whitelisted instead — see Task 5.)
- **Never persist CODE or action strings in `profileNamespace`** — client-writable, a real past injection vector.
- **`core/configuration.sqf` is minified — append, never reformat.**
- **mres/str2-encoded DB columns are read BARE, never `QUOTE()`-wrapped.** Plain string columns are the inverse: always `QUOTE()`. Getting this backwards is silent data loss, not an error.
- **ND money is `decimal(20,4)` and stays a STRING end to end.** SQF numbers are 32-bit floats, exact only to 16,777,216.
- **Arma 3 floor: 2.18** (`toJSON`/`fromJSON`, HashMaps).
- **Never commit to `main`.** Work is on branch `armaquest`; PRs only.
- **Dev only.** No live-server deploy, no live schema change. The live DB is frozen behind the 2026-09-11 migration window.
- Brace/bracket-balance every edited `.sqf`/`.hpp` before packing, with an **Arma-aware tokenizer**: `""` is an escaped quote (not `\"`), and `//` / `/* */` must be skipped. A naive `tr -cd '{'` miscounts braces inside strings and comments. A mismatch means the mission does not load at all.
- **Deploy to dev is `AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh`.** Both reload scripts hardcode `SRC=/home/timb/Armapunk2035` (the other worktree); `AQ_SRC` overrides it. Without it you deploy someone else's tree and every gate below passes against the wrong code. Never `reload-loonydev.sh` — that packs the frozen LooneyBin project.
- **"read from bank" is NOT a health check.** A `description.ext` that fails to parse still reaches that marker, and the server boots with no Header, no `disabledAI`, no `enableDebugConsole` and no `CfgFunctions` — four unrelated-looking bugs. The reload script's CONFIG GATE is the real check; read its output, not just the bank marker.

### Testing model — read this before Task 1

There is **no SQF test runner.** TDD's value here is the *confirmed-failing observation*, not a framework. So:

- **Python work** (Tasks 1, 10 tooling) uses the real test runner. `test_apdb_sql.py` is **`unittest`**-style (`python3 -m unittest test_apdb_sql`), not pytest — pytest is not installed on this box. Normal red-green-commit.
- **SQF / in-game work** replaces "write a failing test" with **"observe the failure in this environment"**, and the red state **must actually be seen** before the fix. The instruments are:
  - `AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh` — repack + restart dev
  - `/home/timb/arma3server_dev/loonydev.log` — the dev server log (this is the RPT equivalent; the live box uses `/home/timb/arma3server/profiles/console.log`, which is a *different* server — do not confuse them)
  - `bash /home/timb/loonybin-doomba/deploy/launch-client-direct.sh 127.0.0.1 2342` — join dev as a real client
  - the in-game debug console (dev reload patches `enableDebugConsole=2`)

A step that says "expect FAIL with X" means: run it, read X with your own eyes, and only then implement. Skipping the red observation silently degrades this into unverified work.

---

## File Structure

**Upstream library — `~/ArmaQuest` (separate repo, edited FIRST, then vendored):**

| path | responsibility |
|---|---|
| `server/fn_storeSql.sqf` | *new* — the `sql` store driver: four verbs, strings in/out, no quest knowledge |
| `server/fn_srvStore.sqf` | *modify* — add `case "sql"` to the driver switch |
| `config/CfgFunctions.hpp` | *modify* — register `storeSql` |
| `config/CfgArmaQuest.hpp` | *modify* — `store`, `sqlExec`, `AQ_Givers`, content |
| `docs/SCHEMA.md` | *modify* — document the `sql` store and `sqlExec` |

**Mission — `mission/Armapunk2035.Malden/`:**

| path | responsibility |
|---|---|
| `ArmaQuest/` | *new* — vendored copy of the library, byte-identical to upstream |
| `description.ext` | *modify* — `CfgArmaQuest` include + `allowedHTMLLoadURIs` |
| `Functions.h` | *modify* — `CfgFunctions` include **outside** `class AP_Client_Core`, + deck trigger fn |
| `CfgRE.hpp` | *modify* — six remoteExec whitelist entries |
| `core/web/fn_aqDeckTrigger.sqf` | *new* — `AP_fnc_aqDeckTrigger`, the deck-contact trigger driver |
| `ui/html/deck.html` | *modify* — register the journal as a deck app |
| `core/quests/` | **deleted** |
| `core/config/fn_questsCfg.sqf` | **deleted** |

**Server addon — `server/AP_server/`:**

| path | responsibility |
|---|---|
| `core/DB/fn_aqSql.sqf` | *new* — `APS_fnc_aqSql`, the 3-line bridge onto `DB_fnc_asyncQuery` |
| `core/TON/fn_ndCreditSrv.sqf` | *modify* — return a truthful BOOL (Task 6) |
| `config.cpp` | *modify* — register `aqSql` |

**Tooling / schema:**

| path | responsibility |
|---|---|
| `sql/armaquest_state.sql` | *new* — the migration DDL |
| `tools/pysqf_modules/apdb_schema.py` | *modify* — one `UNIQUE_KEYS` entry |
| `tools/pysqf_modules/test_apdb_sql.py` | *modify* — regression test for the upsert |
| `scratchpad/vendor_armaquest.py` | *new* — vendoring + provenance |
| `tools/aq_verbcheck.py` | *new* — assert every content verb has a call site |

---

## Task 1: Postgres table + apdb schema entry

The store cannot upsert until `apdb_sql` knows the table has a unique key. This was **verified by execution**, not assumed: without the entry, `apdb_sql.translate()` raises `UntranslatableSQL: table 'armaquest_state' has no unique key in apdb_schema`. With it, the statement translates to `ON CONFLICT (skey) DO UPDATE`, and that translated form was then run against the live dev Postgres inside a transaction and rolled back.

Note `apdb_schema.py`'s header claims it is generated by `gen_apdb_schema.py`. **That generator does not exist in any branch or worktree** — the file is hand-maintained. Adding the entry by hand is therefore the only path, and it is what a regeneration would produce anyway, since `skey` is the table's PRIMARY KEY.

**Files:**
- Create: `sql/armaquest_state.sql`
- Modify: `tools/pysqf_modules/apdb_schema.py`
- Test: `tools/pysqf_modules/test_apdb_sql.py`

**Interfaces:**
- Produces: table `armaquest_state(skey VARCHAR(64) PK, data TEXT NOT NULL, updated_at TIMESTAMP)`; `UNIQUE_KEYS['armaquest_state'] = [('skey',)]`.
- Consumed by: Task 2's driver, which emits MariaDB-dialect SQL against this table.

- [ ] **Step 1: Write the failing test**

Append to `tools/pysqf_modules/test_apdb_sql.py`:

```python
def test_armaquest_state_upsert_translates():
    """The ArmaQuest store's save is an upsert; it needs a conflict target,
    which comes from apdb_schema.UNIQUE_KEYS."""
    sql = (
        "INSERT INTO armaquest_state (skey,data) "
        "VALUES ('player:76561190000000001','{\"a\":1}') "
        "ON DUPLICATE KEY UPDATE data=VALUES(data), updated_at=NOW()"
    )
    out = apdb_sql.translate(sql).sql
    assert "ON CONFLICT (skey) DO UPDATE" in out
    assert "data=EXCLUDED.data" in out


def test_armaquest_state_load_strips_quote():
    """data is a plain text column, so it is read QUOTE()-wrapped and apdb
    turns that into a bare select plus a stringify marker."""
    out = apdb_sql.translate("SELECT QUOTE(data) FROM armaquest_state WHERE skey='board'")
    assert out.sql == "SELECT data FROM armaquest_state WHERE skey='board'"
    assert 0 in out.stringify
```

- [ ] **Step 2: Run it and SEE it fail**

```bash
cd ~/Armapunk2035/tools/pysqf_modules
python3 -m unittest test_apdb_sql.TestThingsThatFailSilently.test_armaquest_state_upsert_translates -v
```

Expected: `test_armaquest_state_upsert_translates` FAILS with
`UntranslatableSQL: table 'armaquest_state' has no unique key in apdb_schema`.
(`test_armaquest_state_load_strips_quote` should already pass — QUOTE handling is existing behaviour.)

- [ ] **Step 3: Add the schema entry**

In `tools/pysqf_modules/apdb_schema.py`, inside `UNIQUE_KEYS`, in alphabetical position (between `apd_applications` and `atm_skimmers`):

```python
    'armaquest_state': [('skey',)],
```

- [ ] **Step 4: Run the tests and verify they pass**

```bash
python3 -m unittest test_apdb_sql.TestThingsThatFailSilently.test_armaquest_state_upsert_translates \
                   test_apdb_sql.TestThingsThatFailSilently.test_armaquest_state_load_strips_quote -v
```
Expected: `Ran 2 tests ... OK`.

- [ ] **Step 5: Run the whole apdb suite for regressions**

```bash
python3 -m unittest test_apdb_sql -q
```
Expected: no NEW failures versus the pre-change run. Note the suite may already be
red from unrelated in-flight work in these files — establish the pre-change
failure list first and compare against it, rather than expecting green.

- [ ] **Step 6: Write the migration**

Create `sql/armaquest_state.sql`:

```sql
-- ArmaQuest persistence. One row per store key: 'board' and 'player:<uid>'.
--
-- data is TEXT and must NEVER become jsonb: apdb re-encodes jsonb columns into
-- the game's own mres array codec on read, which would silently corrupt
-- ArmaQuest's JSON. It is a plain text column, so it is read QUOTE()-wrapped.
CREATE TABLE IF NOT EXISTS armaquest_state (
    skey       VARCHAR(64) PRIMARY KEY,
    data       TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

- [ ] **Step 7: Apply it to the dev database and verify the table exists**

```bash
set -a; . /home/timb/Armapunk2035/.claude/worktrees/crafting-system/deploy/postgres/.env; set +a
docker exec -i armapunk-pg psql -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 \
  < ~/Armapunk2035-armaquest/sql/armaquest_state.sql
docker exec armapunk-pg psql -U "$PGUSER" -d "$PGDATABASE" -Atc \
  "select count(*) from information_schema.tables where table_name='armaquest_state'"
```
Expected: `CREATE TABLE`, then `1`.

- [ ] **Step 8: Commit**

```bash
git add sql/armaquest_state.sql tools/pysqf_modules/apdb_schema.py tools/pysqf_modules/test_apdb_sql.py
git commit -m "feat(aq): armaquest_state table and its apdb conflict target"
```

---

## Task 2: The `sql` store driver (upstream ArmaQuest)

Done in `~/ArmaQuest` and vendored later (Task 4) — never edited in the mission copy.

**Files:**
- Create: `~/ArmaQuest/server/fn_storeSql.sqf`
- Modify: `~/ArmaQuest/server/fn_srvStore.sqf`, `~/ArmaQuest/config/CfgFunctions.hpp`, `~/ArmaQuest/config/CfgArmaQuest.hpp`, `~/ArmaQuest/docs/SCHEMA.md`

**Interfaces:**
- Consumes: `AQ_Settings >> sqlExec` — the NAME of a host function with contract `[_sql, _mode] -> result`, where mode 1 = fire-and-forget returning anything, mode 2 = first row as an array.
- Produces: `aq_fnc_storeSql`, answering the driver contract `["init"] -> BOOL`, `["load", _key] -> STRING` (`""` when absent), `["save", _key, _json] -> BOOL`, `["flush"] -> BOOL`.

- [ ] **Step 1: Add the setting**

In `~/ArmaQuest/config/CfgArmaQuest.hpp`, in `class AQ_Settings`, **leave `store` and its
existing comment block exactly as they are** — the library's default stays
`"profileNamespace"` so a fresh clone of ArmaQuest still works standalone, and the block
documenting every driver stays intact. Extend that block's list with the new driver and
add `sqlExec` beneath it:

```cpp
    //   "sql"               host database, reached through the function named in
    //                       `sqlExec`. Nothing is persisted until that is wired.
```

```cpp
    // Host function NAME with the contract [_sql, _mode] -> result.
    //   mode 1  fire and forget
    //   mode 2  first row, as an array
    // Only read when store = "sql". Empty means the sql store is unusable, which is a
    // loud init failure rather than a silent fallback to forgetting everything.
    sqlExec = "";
```

**Do not set `store = "sql"` here.** Selecting the driver is the HOST's decision and
belongs in the mission's own config (Task 5), not in the library's default.

- [ ] **Step 2: Register the function**

In `~/ArmaQuest/config/CfgFunctions.hpp`, beside the other store drivers in the server class:

```cpp
        class storeSql {};
```

- [ ] **Step 3: Add the switch arm**

In `~/ArmaQuest/server/fn_srvStore.sqf`, in the driver-name switch (near the existing `case "extdb3":`), add:

```sqf
    case "sql":              { "aq_fnc_storeSql" };
```

- [ ] **Step 4: Write the driver**

Create `~/ArmaQuest/server/fn_storeSql.sqf`:

```sqf
// SPDX-License-Identifier: MIT
/*
    server/fn_storeSql.sqf   —   aq_fnc_storeSql

    Purpose: persist store records into a host's SQL database, without knowing
    anything about that database.

    WHY THIS EXISTS
      The shipped stores are a client-side namespace (wrong for a persistent
      server, because the client then owns its own quest history) and a stub.
      A real server wants its own database — but which database, reached through
      which extension, is the host's business and changes over a host's lifetime.

      So this driver knows SQL and nothing else. The host names ONE function in
      AQ_Settings >> sqlExec that takes [sql, mode] and returns rows, and the
      host is free to point that at whatever transport it currently uses. A host
      migrating between database engines does not touch this file.

    DIALECT
      MariaDB/MySQL flavour, deliberately: it is the dialect the widest set of
      Life-derived hosts already speak, and hosts that have moved to another
      engine reach it through a translating layer that expects exactly that.

    THE TABLE
      armaquest_state(skey VARCHAR(64) PRIMARY KEY, data TEXT, updated_at TIMESTAMP)
      Created by the host's own migration, NOT by this driver: a driver that
      issues DDL at boot is a driver that needs schema privileges at boot.

      `data` is TEXT. It must not be a JSON column type — a host layer that
      re-encodes JSON columns on read will corrupt this payload, and it will do
      it silently, because the result is still a valid string.

    Usage:  ["save", _key, _json] call aq_fnc_storeSql;
*/

params [["_verb", "", [""]]];
private _a = _this param [1];
private _b = _this param [2];

if (!isServer) exitWith {
    diag_log text "[AQ] storeSql called off the server; refused.";
    false
};

// ------------------------------------------------------------ the executor
private _execName = ["sqlExec", ""] call aq_fnc_setting;
if (_execName isEqualTo "") exitWith {
    diag_log text "[AQ] storeSql: AQ_Settings >> sqlExec is empty; there is no host executor to call.";
    false
};
if (isNil _execName) exitWith {
    diag_log text format ["[AQ] storeSql: sqlExec names '%1', which is not defined on this machine.", _execName];
    false
};
private _exec = missionNamespace getVariable _execName;

// ------------------------------------------------------------ escaping
// Only the single quote needs escaping inside a single-quoted SQL literal.
// The payload is JSON and therefore full of double quotes, which are ordinary
// characters here; doubling them too would corrupt every record written.
private _esc = {
    params ["_s"];
    private _out = "";
    { _out = _out + (if (_x isEqualTo "'") then { "''" } else { _x }); } forEach (_s splitString "");
    _out
};

switch (toLower _verb) do {

    // Prove the table is reachable AND readable. COUNT(*) rather than a
    // SELECT of a row, because an empty table and a missing table must not
    // look the same: the first returns a row containing 0, the second fails.
    case "init": {
        private _r = ["SELECT COUNT(*) FROM armaquest_state", 2] call _exec;
        if !(_r isEqualType []) exitWith {
            diag_log text format ["[AQ] storeSql init: executor '%1' did not return an array (got %2). Store unusable.", _execName, typeName _r];
            false
        };
        if (_r isEqualTo []) exitWith {
            diag_log text "[AQ] storeSql init: COUNT(*) returned no row; armaquest_state is probably missing. Run the migration.";
            false
        };
        diag_log text format ["[AQ] storeSql init: armaquest_state reachable, %1 record(s).", _r param [0, "?"]];
        true
    };

    case "load": {
        private _key = [_a] call _esc;
        private _r = [format ["SELECT QUOTE(data) FROM armaquest_state WHERE skey='%1'", _key], 2] call _exec;
        // No row is a legitimate answer meaning "nothing stored yet", and it is
        // NOT the same as a failure. Both arrive here as something that is not
        // a one-element array of string, so both return "" — but the failure is
        // logged, because a store that is silently failing every read looks
        // exactly like a brand-new server.
        if !(_r isEqualType []) exitWith {
            diag_log text format ["[AQ] storeSql load('%1'): executor returned %2, not an array.", _a, typeName _r];
            ""
        };
        if (_r isEqualTo []) exitWith { "" };
        private _v = _r param [0, ""];
        if !(_v isEqualType "") exitWith {
            diag_log text format ["[AQ] storeSql load('%1'): first column was %2, not a string.", _a, typeName _v];
            ""
        };
        _v
    };

    case "save": {
        private _key  = [_a] call _esc;
        private _json = [_b] call _esc;
        [format [
            "INSERT INTO armaquest_state (skey,data) VALUES ('%1','%2') ON DUPLICATE KEY UPDATE data=VALUES(data), updated_at=NOW()",
            _key, _json
        ], 1] call _exec;
        true
    };

    // Every save is issued immediately; the write-behind buffer that makes that
    // cheap lives in the facade above, not here. Nothing is batched at this
    // level, so there is nothing to commit.
    case "flush": { true };

    default {
        diag_log text format ["[AQ] storeSql: unknown verb '%1'.", _verb];
        false
    };
};
```

- [ ] **Step 5: Verify the file parses as SQF**

There is no SQF linter, so check the thing that actually breaks a mission — brace balance:

```bash
cd ~/ArmaQuest
for f in server/fn_storeSql.sqf server/fn_srvStore.sqf; do
  echo "$f: { = $(tr -cd '{' < $f | wc -c)  } = $(tr -cd '}' < $f | wc -c)"
done
```
Expected: the two counts match for each file. They must be equal or the mission will not load.

- [ ] **Step 6: Document it**

In `~/ArmaQuest/docs/SCHEMA.md`, in the `AQ_Settings` table, add a `sqlExec` row and extend the `store` row's description to list `"sql"`. State the table shape and that `data` must not be a JSON column type.

- [ ] **Step 7: Commit upstream**

```bash
cd ~/ArmaQuest
git add server/fn_storeSql.sqf server/fn_srvStore.sqf config/CfgFunctions.hpp config/CfgArmaQuest.hpp docs/SCHEMA.md
git commit -m "feat: sql store driver behind a host-named executor"
```

---

## Task 3: Host SQL adapter `APS_fnc_aqSql`

**Files:**
- Create: `server/AP_server/core/DB/fn_aqSql.sqf`
- Modify: `server/AP_server/config.cpp`

**Interfaces:**
- Consumes: `DB_fnc_asyncQuery` (`[_sql, _mode] -> result`).
- Produces: `APS_fnc_aqSql`, matching the `sqlExec` contract from Task 2.

**This task also owes a fix carried over from Task 2's review.** `aq_fnc_storeSql`'s `save`
issues its write in mode 1 (fire-and-forget) and then returns `true` unconditionally. The
facade's write-behind layer reads `true` as "committed — clear the dirty flag", so a write
that failed because the database was down is indistinguishable from one that succeeded: the
record is marked clean, never retried, and the update is lost silently at the next restart.
`fn_storeExtDB.sqf`'s own docstring states a driver "must never report success it is not sure
of", so this violates the driver contract as written, and the store facade's whole
loud-on-failure design assumes it does not happen.

It could not be fixed in Task 2 because the fix depends on how THIS adapter signals a failed
query versus an empty result — which did not exist yet. So:

1. Decide and document `APS_fnc_aqSql`'s failure signal. `DB_fnc_asyncQuery` at mode 2 returns
   rows; the host's PostgreSQL layer surfaces an error as a distinguishable value rather than
   an empty array (its own docstring is explicit that "no rows" and "failure" must not look
   alike). Read `server/AP_server/core/DB/fn_asyncQuery.sqf` and
   `/home/timb/Armapunk2035/tools/pysqf_modules/apdb.py` before choosing.
2. Then change `aq_fnc_storeSql`'s `save` upstream to issue its write in a mode that yields a
   result, check it, and return the truth. Re-vendor afterwards.

Do not skip step 1 and guess the failure shape — an adapter that reports success on failure
reproduces the exact bug this is fixing, one layer down.

Routing through `DB_fnc_asyncQuery` rather than calling `apdb.query` directly is the whole point: ArmaQuest inherits whatever transport the mission currently resolves to, and survives the extDB3→Postgres switch without a change.

- [ ] **Step 1: Write the adapter**

Create `server/AP_server/core/DB/fn_aqSql.sqf`:

```sqf
/*
    File: fn_aqSql.sqf  (APS_fnc_aqSql)
    The host side of ArmaQuest's `sql` store: AQ_Settings >> sqlExec names this.

    ArmaQuest hands us MariaDB-flavoured SQL and a mode, and wants rows back. That
    is exactly DB_fnc_asyncQuery's contract, so this is a pass-through — and it is
    a pass-through ON PURPOSE. Pointing the library at DB_fnc_asyncQuery rather
    than at apdb.query means ArmaQuest follows the mission's transport wherever it
    goes (extDB3 yesterday, PySQF+Postgres today) with no library change.

    Server-only: it is a database call, and the library never calls it elsewhere.
*/
params [["_sql", "", [""]], ["_mode", 2, [0]]];
if (!isServer) exitWith { [] };
if (_sql isEqualTo "") exitWith { [] };
[_sql, _mode] call DB_fnc_asyncQuery
```

- [ ] **Step 2: Register it**

In `server/AP_server/config.cpp`, in the `DB` class beside the other `DB` functions:

```cpp
        class aqSql {};
```

- [ ] **Step 3: Observe the red state — the function does not exist yet on the running server**

Reload dev, then in the in-game debug console (or via the server log after a `diag_log`):

```bash
AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```
Then in the debug console, server-exec:
```sqf
diag_log format ["AQSQL TEST: %1", ["SELECT COUNT(*) FROM armaquest_state", 2] call APS_fnc_aqSql];
```
Expected BEFORE this task's files ship: `Undefined variable in expression: APS_fnc_aqSql` in `loonydev.log`. **See that error before continuing.**

- [ ] **Step 4: Reload with the adapter and verify it answers**

```bash
AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh
grep -a "AQSQL TEST" /home/timb/arma3server_dev/loonydev.log | tail -3
```
Expected: `AQSQL TEST: [0]` — a one-element array holding the row count from Task 1's empty table. An empty `[]` means the query failed; check the same log for `[apdb] QUERY FAILED`.

- [ ] **Step 5: Commit**

```bash
git add server/AP_server/core/DB/fn_aqSql.sqf server/AP_server/config.cpp
git commit -m "feat(aq): APS_fnc_aqSql, the host bridge for ArmaQuest's sql store"
```

---

## Task 4: Vendor ArmaQuest into the mission

**Files:**
- Create: `scratchpad/vendor_armaquest.py`, `mission/Armapunk2035.Malden/ArmaQuest/**`

**Interfaces:**
- Produces: the vendored tree, and `ArmaQuest/VENDORED.txt` recording the upstream commit.

Unlike the PySQF vendoring (which rewrites symbols and therefore bans hand-edits), this is a byte-identical copy — ArmaQuest's `aq_` prefix is already unique. The rule is directional instead: **edit upstream, re-run the script.**

- [ ] **Step 1: Write the vendoring script**

Create `scratchpad/vendor_armaquest.py`:

```python
#!/usr/bin/env python3
"""Vendor ~/ArmaQuest into the mission as a byte-identical copy.

The copy is byte-identical on purpose, so a local edit is not silently
discarded the way an edit to a generated file would be. The discipline is
directional instead: change the library upstream, then re-run this.
VENDORED.txt records which upstream commit the tree corresponds to, so a
divergence is answerable rather than guessed at.
"""
import hashlib
import pathlib
import shutil
import subprocess
import sys

SRC = pathlib.Path.home() / "ArmaQuest"
DST = pathlib.Path(__file__).resolve().parent.parent / "mission/Armapunk2035.Malden/ArmaQuest"
COPY = ("config", "functions", "server", "types", "diagnostics", "ui")


def main() -> int:
    if not SRC.is_dir():
        print(f"upstream missing: {SRC}", file=sys.stderr)
        return 1
    sha = subprocess.run(
        ["git", "-C", str(SRC), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    dirty = subprocess.run(
        ["git", "-C", str(SRC), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if dirty:
        print("REFUSING: upstream has uncommitted changes; commit them first so "
              "VENDORED.txt names something real:\n" + dirty, file=sys.stderr)
        return 1

    if DST.exists():
        shutil.rmtree(DST)
    DST.mkdir(parents=True)

    n = 0
    for sub in COPY:
        s = SRC / sub
        if not s.is_dir():
            print(f"upstream is missing {sub}/", file=sys.stderr)
            return 1
        shutil.copytree(s, DST / sub)
        n += sum(1 for _ in (DST / sub).rglob("*") if _.is_file())
    shutil.copy2(SRC / "LICENSE", DST / "LICENSE")

    digest = hashlib.sha256()
    for p in sorted(DST.rglob("*")):
        if p.is_file() and p.name != "VENDORED.txt":
            digest.update(p.relative_to(DST).as_posix().encode())
            digest.update(p.read_bytes())
    (DST / "VENDORED.txt").write_text(
        f"upstream: https://github.com/doombadroid/ArmaQuest\n"
        f"commit:   {sha}\n"
        f"files:    {n}\n"
        f"tree:     sha256:{digest.hexdigest()}\n"
        f"\nDo not edit this tree. Change the library upstream and re-run\n"
        f"scratchpad/vendor_armaquest.py.\n"
    )
    print(f"vendored {n} files from {sha[:12]} -> {DST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Run it**

```bash
cd ~/Armapunk2035-armaquest && python3 scratchpad/vendor_armaquest.py
```
Expected: `vendored 58 files from <sha> -> .../ArmaQuest`.

- [ ] **Step 3: Verify the copy is byte-identical to upstream**

```bash
diff -r ~/ArmaQuest/functions mission/Armapunk2035.Malden/ArmaQuest/functions && echo "IDENTICAL"
```
Expected: `IDENTICAL`, no diff output.

- [ ] **Step 4: Verify nothing is gitignored**

The plan's own write path must land — `docs/` in this repo is ignored, so do not assume.

```bash
git check-ignore -v mission/Armapunk2035.Malden/ArmaQuest/functions/fn_preInit.sqf || echo "NOT IGNORED"
```
Expected: `NOT IGNORED`.

- [ ] **Step 5: Commit**

```bash
git add scratchpad/vendor_armaquest.py mission/Armapunk2035.Malden/ArmaQuest
git commit -m "feat(aq): vendor ArmaQuest into the mission"
```

---

## Task 5: Wire the includes and the remoteExec whitelist

This is the first boot gate, and the task where the mission most easily fails to load at all.

**Files:**
- Modify: `mission/Armapunk2035.Malden/description.ext`, `mission/Armapunk2035.Malden/Functions.h`, `mission/Armapunk2035.Malden/CfgRE.hpp`

**Interfaces:**
- Produces: `aq_fnc_*` compiled and callable; `AQ_Quests` / `AQ_Settings` / `AQ_Givers` readable from config; six whitelisted remoteExec targets.

**The whitelist is not optional.** `CfgRE.hpp` is `mode = 1`, and ArmaQuest calls raw `remoteExec` at 35 sites across exactly six targets. Without entries they fail **silently** — no error, no quest, no clue.

- [ ] **Step 1: Add the config includes**

In `description.ext`, at ROOT level (not inside any class), near the other root includes:

```cpp
#include "ArmaQuest\config\CfgArmaQuest.hpp"   // library defaults + shipped types
#include "aq_content.hpp"                       // OURS: settings override, givers, content
```

Order matters: ours comes second so its definitions win.

- [ ] **Step 1b: Create the mission-owned content file**

Create `mission/Armapunk2035.Malden/aq_content.hpp`. This is the file Armapunk owns; the
vendored `ArmaQuest/` tree is pure upstream and is overwritten wholesale on every
re-vendor, so nothing project-specific may live there.

```cpp
/*
    aq_content.hpp — Armapunk's ArmaQuest configuration and content.

    Everything project-specific lives HERE, never in ArmaQuest/. That tree is a
    byte-identical vendored copy of the upstream library and is replaced wholesale
    by scratchpad/vendor_armaquest.py; anything authored inside it is destroyed on
    the next re-vendor, with no error.

    Included AFTER the library's own config so these definitions win.
*/

class AQ_Settings {
    // The host database, reached through APS_fnc_aqSql -> DB_fnc_asyncQuery ->
    // whatever transport the mission currently resolves to.
    store   = "sql";
    sqlExec = "APS_fnc_aqSql";
};
```

Givers (Task 8) and quests/templates/pools (Task 10) are added to this same file.

- [ ] **Step 2: Add the journal page to the HTML whitelist**

In `description.ext`, in the existing `class CfgCommands`, extend the list:

```cpp
	allowedHTMLLoadURIs[] += {
		"ui\\html\\*",
		"ui\\html\\casino\\*",
		"webui\\ui\\*",
		"ArmaQuest\\ui\\*"
	};
```

- [ ] **Step 3: Add the functions include — placement is load-bearing**

In `Functions.h`, **outside** `class AP_Client_Core`, beside the existing arma-webui include at the bottom of the file:

```cpp
// ArmaQuest. Must sit OUTSIDE class AP_Client_Core for the same reason the
// arma-webui include above does: CfgFunctions resolves a file path relative to
// the enclosing class, so nested one level too deep every function fails to
// compile with "Script ArmaQuest\functions not found", once per attempt.
#include "ArmaQuest\config\CfgFunctions.hpp"
```

- [ ] **Step 4: Whitelist the six remoteExec targets**

In `CfgRE.hpp`, add:

```cpp
	// ArmaQuest. mode=1 means anything not listed here silently does nothing,
	// which for a quest system means quests that can be accepted and never
	// progress, with an empty log. allowedTargets: 2 = server only (client->
	// server), 1 = clients only (server->client).
	class aq_fnc_srvAccept { allowedTargets = 2; };
	class aq_fnc_srvBoard  { allowedTargets = 2; };
	class aq_fnc_srvFact   { allowedTargets = 2; };
	class aq_fnc_srvFail   { allowedTargets = 2; };
	class aq_fnc_journal   { allowedTargets = 1; };
	class aq_fnc_sync      { allowedTargets = 1; };

	// Host-side helpers the profile calls server->client (Task 6).
	class AP_fnc_aqGrantLicense { allowedTargets = 1; };
```

`AP_fnc_handleInv` and `AP_fnc_handleMessage` are called server→client by the profile too — confirm both already have entries before relying on them:

```bash
grep -nE "class (handleInv|handleMessage|AP_fnc_handleInv|AP_fnc_handleMessage)" mission/Armapunk2035.Malden/CfgRE.hpp
```
Expected: both present (existing server code already calls them this way). If either is missing, add it with `allowedTargets = 1`.

- [ ] **Step 5: Balance-check every edited file before packing**

```bash
cd ~/Armapunk2035-armaquest/mission/Armapunk2035.Malden
for f in description.ext Functions.h CfgRE.hpp; do
  echo "$f: { = $(tr -cd '{' < $f | wc -c)  } = $(tr -cd '}' < $f | wc -c)"
done
```
Expected: counts match per file. A mismatch means the mission will not load — fix before reloading.

- [ ] **Step 6: Reload dev and read the boot gate**

```bash
AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh
sleep 45
grep -aE "\[AQ\]|ArmaQuest" /home/timb/arma3server_dev/loonydev.log | tail -30
```

Expected, and each line is a distinct gate:
- **the reload script's CONFIG GATE passes.** This task edits `description.ext`, `Functions.h` AND `CfgRE.hpp` — exactly the change that produces a silent config abort. Read the gate's verdict before reading anything else; if it fails, nothing below is meaningful.
- `[AQ] preInit: indexed N quests, M templates, P pools, 6 givers` — config parsed
- `[AQ] storeSql init: armaquest_state reachable, 0 record(s).` — Task 2+3 wired
- **no** `Script ArmaQuest\… not found` — the Step 3 placement is right
- **no** `[AQ] … PROBLEM` lines

If `Script ArmaQuest\functions not found` appears, the include in Step 3 went inside a class. That is the single most likely failure of this task.

- [ ] **Step 7: Commit**

```bash
git add mission/Armapunk2035.Malden/description.ext mission/Armapunk2035.Malden/Functions.h mission/Armapunk2035.Malden/CfgRE.hpp
git commit -m "feat(aq): wire ArmaQuest includes and whitelist its six remoteExec targets"
```

---

## Task 6: Profile — money, items, licences

**Files:**
- Create: `mission/Armapunk2035.Malden/core/quests/fn_aqProfile.sqf` (all nine capabilities)
- Modify: `mission/Armapunk2035.Malden/aq_content.hpp` (`class AQ_Profile` override), `mission/Armapunk2035.Malden/Functions.h`, `mission/Armapunk2035.Malden/CfgRE.hpp`, `server/AP_server/core/TON/fn_ndCreditSrv.sqf`

**Where the profile lives — do NOT put it in the vendored tree.** The library documents
`config/profile_default.sqf` as "the ONLY file a host edits", but that file is inside
`ArmaQuest/`, which `vendor_armaquest.py` replaces wholesale — a host edit there is
destroyed by the next re-vendor with no error. The library's own stubs are `isNil`-guarded
so a host definition wins, but relying on that means relying on preInit declaration order.

So instead: define the capabilities as ordinary mission functions with our own names, and
point `AQ_Profile` at those names from `aq_content.hpp` (which is included after the
library's config, so it wins). No ordering dependency, nothing host-specific inside the
vendored tree, and the library's shipped stubs simply go unused.

```cpp
// aq_content.hpp
class AQ_Profile {
    payMoney     = "AP_fnc_aqPayMoney";
    takeMoney    = "AP_fnc_aqTakeMoney";
    giveItem     = "AP_fnc_aqGiveItem";
    takeItem     = "AP_fnc_aqTakeItem";
    countItem    = "AP_fnc_aqCountItem";
    hasLicense   = "AP_fnc_aqHasLicense";
    grantLicense = "AP_fnc_aqGrantLicense";
    playerUid    = "AP_fnc_aqPlayerUid";
    notify       = "AP_fnc_aqNotify";
};
```

Use the `AP_` (mission) prefix, not `APS_`: `countItem` and `playerUid` are called on BOTH
machines, and only the mission's CfgFunctions tree is compiled on clients. The server-only
bodies inside them may call `APS_fnc_*` freely, because they only ever run there.

**Interfaces:**
- Consumes: `APS_fnc_ndCreditSrv`, `APS_fnc_ndDebitSrv`, `AP_fnc_handleInv`, `AP_fnc_ndFromLegacy`, `AP_fnc_MP`, `DB_fnc_asyncQuery`, `DB_fnc_mresToArray`.
- Produces: `aq_life_fnc_payMoney/takeMoney/giveItem/takeItem/countItem/hasLicense/grantLicense/playerUid/notify`, plus the helper `aq_life_fnc_unitFromUid`.

`profile_default.sqf` is by the library's own design the one file a host edits, so the host mapping lives there and is re-vendored with the tree.

- [ ] **Step 1: Make `ndCreditSrv` answer truthfully**

`aq_fnc_payMoney` must return `false` when it did not pay — a `true` that did not pay produces a completed quest with no reward and no way to repeat it, which is the worst outcome the system can produce. `APS_fnc_ndCreditSrv` currently returns whatever its last statement evaluates to, which is not a success signal.

In `server/AP_server/core/TON/fn_ndCreditSrv.sqf`, make each early exit return `false` and the success path return `true`:

```sqf
if (!(_amt regexMatch "\d{1,14}(\.\d{1,4})?") || {_amt isEqualTo "0"}) exitWith {
    diag_log format ["[LooneyBin][ND] ndCreditSrv bad amount '%1' (%2)", _amt, _reason]; false };
```
```sqf
if (AP_ndLocks getOrDefault [_uid, false]) exitWith { diag_log format ["[LooneyBin][ND] ndCreditSrv lock bail %1", _uid]; false };
```
```sqf
if (_new isEqualTo "") exitWith { diag_log format ["[LooneyBin][ND] ndCreditSrv reselect failed %1", _uid]; false };
```
and after the final `AP_fnc_MP` spawn, add:
```sqf
true
```

This is backwards-compatible: every existing caller (mining rigs, deck loot) ignores the return value.

- [ ] **Step 2: Write the profile stubs**

Replace the demo-economy bodies in `~/ArmaQuest/config/profile_default.sqf` with:

```sqf
// ---------------------------------------------------------------- helpers
// The library calls everything that pays or grants with a UID, because the
// server is the only machine allowed to decide a reward happened and a UID
// outlives an object reference. The host's own functions want a unit, so the
// resolution happens here, once.
aq_life_fnc_unitFromUid = {
    params [["_uid", "", [""]]];
    private _hit = allPlayers select { getPlayerUID _x isEqualTo _uid };
    _hit param [0, objNull]
};

// ---------------------------------------------------------------- money
// New Drachma is decimal(20,4). It stays a STRING for the whole path: SQF
// numbers are 32-bit floats and are exact only to 16,777,216, so a balance
// above that is rounded on the way through, and rounding money is how a dupe
// starts. Rewards are authored as legacy cash and converted at the rate the
// mission already applies, so a reward reads at the scale players expect.
aq_life_fnc_payMoney = {
    params [["_uid", "", [""]], ["_amt", 0, [0, ""]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    // Offline is a real answer, not an error: report it truthfully so the
    // server can retry rather than record a payout that never landed.
    if (isNull _unit) exitWith { false };
    // ndFromLegacy already returns a STRING — its last expression is `_r toFixed 4`.
    // Do NOT wrap it in str(): that would double-encode the amount, and
    // ndCreditSrv's regex would reject the result.
    private _str = if (_amt isEqualType "") then { _amt } else { [_amt] call AP_fnc_ndFromLegacy };
    [_unit, _str, "armaquest"] call APS_fnc_ndCreditSrv
};

aq_life_fnc_takeMoney = {
    params [["_uid", "", [""]], ["_amt", 0, [0, ""]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    if (isNull _unit) exitWith { false };
    private _str = if (_amt isEqualType "") then { _amt } else { [_amt] call AP_fnc_ndFromLegacy };
    [_unit, _str, "armaquest"] call APS_fnc_ndDebitSrv
};

// ---------------------------------------------------------------- items
// There is no server-side write path for virtual items in this mission: every
// server-side grant in the codebase asks the owning client to apply it. So do
// the same thing, rather than invent a second mechanism that would disagree
// with the first.
aq_life_fnc_giveItem = {
    params [["_uid", "", [""]], ["_class", "", [""]], ["_qty", 1, [0]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    if (isNull _unit) exitWith { false };
    [[true, _class, _qty], "AP_fnc_handleInv", _unit, false] spawn AP_fnc_MP;
    true
};

aq_life_fnc_takeItem = {
    params [["_uid", "", [""]], ["_class", "", [""]], ["_qty", 1, [0]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    if (isNull _unit) exitWith { false };
    [[false, _class, _qty], "AP_fnc_handleInv", _unit, false] spawn AP_fnc_MP;
    true
};

/*
    countItem is called on BOTH machines, and answers differently on each —
    which is not a shortcut, it is the honest shape of this host.

    On the client it reads the live variable, which is exact.

    On the server there is no live read available: virtual items live in client
    variables and reach the database only when the client next runs a mode-3
    save. So the server's answer is the last SAVED value, and it is therefore
    STALE by up to one save interval. Item objectives in this host are
    client-reported with a lagging server check, not server-verified. See
    ARMAQUEST_SPEC.md section 5.3 — this is a documented, scoped limitation, and
    the fix is a separate piece of work.

    The gear column is mres-encoded, so it is selected BARE. A QUOTE() around it
    adds a second quote layer, mresToArray's inner compile produces malformed
    SQF, and the value decodes to nothing — silently. This codebase has been
    bitten by that twice.
*/
aq_life_fnc_countItem = {
    params [["_uid", "", [""]], ["_class", "", [""]]];

    if (hasInterface && {_uid isEqualTo (getPlayerUID player)}) exitWith {
        missionNamespace getVariable [_class, 0]
    };
    if (!isServer) exitWith { 0 };

    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    private _col = switch (side group _unit) do {
        case west:        { "cop_gear" };
        case independent: { "med_gear" };
        default           { "civ_gear" };
    };
    private _r = [format ["SELECT %1 FROM players WHERE playerid='%2'", _col, _uid], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { 0 };
    private _gear = [_r param [0, ""]] call DB_fnc_mresToArray;
    if !(_gear isEqualType []) exitWith { 0 };
    // gear shape: [[...loadout...], [[[class,qty], ...], weight], [...]]
    private _virt = (_gear param [1, []]) param [0, []];
    private _hit = _virt param [_virt findIf { (_x param [0, ""]) isEqualTo _class }, []];
    _hit param [1, 0]
};

// ---------------------------------------------------------------- licences
aq_life_fnc_hasLicense = {
    params [["_uid", "", [""]], ["_lic", "", [""]]];
    if (hasInterface && {_uid isEqualTo (getPlayerUID player)}) exitWith {
        (missionNamespace getVariable [format ["license_civ_%1", _lic], false])
    };
    if (!isServer) exitWith { false };
    private _r = [format ["SELECT civ_licenses FROM players WHERE playerid='%1'", _uid], 2] call DB_fnc_asyncQuery;
    if (!(_r isEqualType []) || {_r isEqualTo []}) exitWith { false };
    private _lics = [_r param [0, ""]] call DB_fnc_mresToArray;
    if !(_lics isEqualType []) exitWith { false };
    private _i = _lics findIf { (_x param [0, ""]) isEqualTo _lic };
    if (_i isEqualTo -1) exitWith { false };
    ((_lics select _i) param [1, false]) isEqualTo true
};

// This mission has NO licence-grant primitive — verified: Functions.h has only
// licenseCfg / licenseCheck / licensesRead, and fn_buyLicense grants by setting
// the client variable directly. So one is added (Step 2b) rather than pretending
// AP_fnc_setLicense exists.
aq_life_fnc_grantLicense = {
    params [["_uid", "", [""]], ["_lic", "", [""]]];
    if (!isServer) exitWith { false };
    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    if (isNull _unit) exitWith { false };
    [[_lic], "AP_fnc_aqGrantLicense", _unit, false] spawn AP_fnc_MP;
    true
};

// ---------------------------------------------------------------- identity
aq_life_fnc_playerUid = {
    params [["_unit", objNull, [objNull]]];
    if (isNull _unit) exitWith { "" };
    getPlayerUID _unit
};

aq_life_fnc_notify = {
    params [["_uid", "", [""]], ["_text", "", [""]]];
    private _unit = [_uid] call aq_life_fnc_unitFromUid;
    if (isNull _unit) exitWith { false };
    [[_text, "basic"], "AP_fnc_handleMessage", _unit, false] spawn AP_fnc_MP;
    true
};
```

- [ ] **Step 2b: Add the missing licence-grant primitive**

Create `mission/Armapunk2035.Malden/core/actions/fn_aqGrantLicense.sqf`:

```sqf
/*
    File: fn_aqGrantLicense.sqf  (AP_fnc_aqGrantLicense)
    Grant a licence to THIS client and persist it.

    This mission had no grant primitive: licences are client variables, and
    fn_buyLicense sets them inline as part of the purchase flow. ArmaQuest's
    profile needs a grant that is not a purchase, so this is it — the smallest
    function that sets the variable and puts it through the existing save path.

    Persistence is ClupdatePartial mode 2, which is the case that walks
    AP_licenses and saves the ones matching the player's side.
*/
params [["_lic", "", [""]]];
if (!hasInterface) exitWith { false };
if (_lic isEqualTo "") exitWith { false };
private _var = format ["license_civ_%1", _lic];
missionNamespace setVariable [_var, true];
[2] call AP_fnc_ClupdatePartial;
true
```

Register it in `Functions.h` under the appropriate client class:

```cpp
        class aqGrantLicense {};
```

And whitelist it in `CfgRE.hpp` — it is called server→client, so it needs an entry or it silently does nothing:

```cpp
	class AP_fnc_aqGrantLicense { allowedTargets = 1; };
```

- [ ] **Step 3: Confirm the licence variable naming matches this mission**

```bash
grep -rn "license_civ_" ~/Armapunk2035-armaquest/mission/Armapunk2035.Malden/core/actions/fn_buyLicense.sqf | head -3
grep -rn "AP_licenses" ~/Armapunk2035-armaquest/mission/Armapunk2035.Malden/core/configuration.sqf | head -1 | cut -c1-200
```
Expected: `license_civ_<name>` variables, and an `AP_licenses` table listing them with a side flag. If cop/med licences use a different prefix, `grantLicense` and `hasLicense` must branch on side the way `countItem` does.

- [ ] **Step 4: Re-vendor and observe preInit accept the profile**

```bash
cd ~/ArmaQuest && git add -A && git commit -m "feat: wire profile_default onto the Armapunk economy"
cd ~/Armapunk2035-armaquest && python3 scratchpad/vendor_armaquest.py
AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh
sleep 45
grep -aE "\[AQ\].*(profile|PROBLEM)" /home/timb/arma3server_dev/loonydev.log | tail -20
```
Expected: no `PROBLEM` naming an unresolved profile entry. An entry that resolves to nothing is reported by name at preInit — read the list and fix each before continuing.

- [ ] **Step 5: Prove a payout actually moves money**

Join dev as a client, then from the debug console (server-exec):

```sqf
diag_log format ["AQPAY: %1", [getPlayerUID player, 5000] call (missionNamespace getVariable "aq_life_fnc_payMoney")];
```
Then:
```bash
set -a; . /home/timb/Armapunk2035/.claude/worktrees/crafting-system/deploy/postgres/.env; set +a
docker exec armapunk-pg psql -U "$PGUSER" -d "$PGDATABASE" -Atc \
  "SELECT new_drachma FROM players WHERE playerid='76561190000000001'"
```
Expected: `AQPAY: true` in the log, the balance increased, and the client's on-screen balance updated **without a relog** — that last part is what proves the refresh half of "direct DB write + client refresh".

- [ ] **Step 6: Commit**

```bash
git add mission/Armapunk2035.Malden/ArmaQuest server/AP_server/core/TON/fn_ndCreditSrv.sqf
git commit -m "feat(aq): profile mapped onto ND money, handleInv items and licences"
```

---

## Task 7: The `action` objective type

**Files:**
- Create: `~/ArmaQuest/types/fn_typeAction.sqf` (then re-vendor)
- Modify: `~/ArmaQuest/config/CfgFunctions.hpp`, `~/ArmaQuest/functions/fn_postInit.sqf`

**Interfaces:**
- Consumes: `aq_fnc_registerType`, `aq_fnc_fact`.
- Produces: objective type `action`, taking `verb` (STRING) and `count` (NUMBER).

Registration is a gate, not bookkeeping: the type is probed against a real config class before admission, and one that cannot answer `progress` and `describe` with the right shapes is rejected loudly and simply not available. Quests using it then fail validation by name at preInit.

- [ ] **Step 1: Write the type**

Create `~/ArmaQuest/types/fn_typeAction.sqf` implementing the five verbs `arm`, `event`, `progress`, `describe`, `disarm`, where:
- `arm` subscribes to the configured `verb` via `aq_fnc_subscribe`
- `event` increments the objective's state count by the reported quantity, clamped by `factMaxCount`
- `progress` returns `[_have, _need, _label]`
- `describe` returns a STRING renderable **from config alone with empty state** — the offer screen calls it before any state exists, and a type that cannot do that shows a blank line to every player looking at the board
- `disarm` unsubscribes

Match the structure of the shipped `types/fn_typeGather.sqf` exactly; read it in full first rather than adapting from memory.

- [ ] **Step 2: Register it**

`config/CfgFunctions.hpp`:
```cpp
        class typeAction {};
```
and in `functions/fn_postInit.sqf`, beside the other `registerType` calls:
```sqf
["action", aq_fnc_typeAction] call aq_fnc_registerType;
```

- [ ] **Step 3: Observe the red state**

Add a throwaway quest using `type = "action"` to `AQ_Quests` **before** the type is registered, re-vendor, reload, and read:

```bash
grep -aE "\[AQ\].*(action|PROBLEM)" /home/timb/arma3server_dev/loonydev.log | tail -10
```
Expected: a preInit PROBLEM naming the quest and the unknown type `action`. **See it**, then register the type.

- [ ] **Step 4: Verify registration is accepted**

Reload and expect the PROBLEM to be gone and the quest indexed. If instead the log says the type was *rejected*, the probe found `describe`/`progress` returning the wrong shape — fix the renderer, not the probe.

- [ ] **Step 5: Commit**

```bash
cd ~/ArmaQuest && git add -A && git commit -m "feat: action objective type, counting named host event verbs"
cd ~/Armapunk2035-armaquest && python3 scratchpad/vendor_armaquest.py
git add mission/Armapunk2035.Malden/ArmaQuest && git commit -m "feat(aq): vendor action objective type"
```

---

## Task 8: Givers, markers and the deck trigger

**Files:**
- Modify: `mission/Armapunk2035.Malden/aq_content.hpp` (`AQ_Givers`), `mission/Armapunk2035.Malden/Functions.h`, `mission/Armapunk2035.Malden/mission.sqm` (markers)
- Create: `mission/Armapunk2035.Malden/core/web/fn_aqDeckTrigger.sqf`

**Interfaces:**
- Produces: givers `fixer_1`…`fixer_4`, `maxsec_command`, `pharma_technica`; trigger driver registered as `"deck"`; markers `aq_giver_<id>`.

**Markers go in `mission.sqm` via the map pipeline, never `createMarker` in init** — that is a standing rule in this codebase and the migration is one-way.

- [ ] **Step 1: Define the givers**

In `mission/Armapunk2035.Malden/aq_content.hpp` — **not** the vendored tree, which is overwritten on re-vendor — define the six givers. Ids are stable; display names are placeholders. Example for one; repeat the shape for all six:

```cpp
class AQ_Givers {
    class fixer_1 {
        name      = "Fixer 1";
        trigger   = "addAction";
        object    = "C_man_polo_1_F";
        marker    = "aq_giver_fixer_1";
        boardSize = 3;
    };
    // fixer_2, fixer_3, fixer_4 — same shape, own marker, own boardSize
    class maxsec_command {
        name      = "MaxSec Command";
        trigger   = "addAction";
        object    = "C_man_polo_1_F";
        marker    = "aq_giver_maxsec_command";
        boardSize = 3;
    };
    // pharma_technica — same shape
};
```

Givers carry **no side**. Side lives on quests and templates (Task 10).

- [ ] **Step 2: Place the six markers through the map pipeline**

Use `tools/edit-map.sh` / `npc_place.py` per `tools/MAP_EDITING.md`. Marker names must be exactly `aq_giver_<giverId>`. Positions are a content decision — pick sensible ones and expect the owner to move them.

- [ ] **Step 3: Observe the red state — givers do not spawn**

Reload before the markers exist:
```bash
grep -aE "\[AQ\].*giver" /home/timb/arma3server_dev/loonydev.log | tail -10
```
Expected: complaints about missing markers / zero givers spawned. **See it**, then add the markers and confirm the count reaches 6.

- [ ] **Step 4: Write the deck trigger driver**

Create `core/web/fn_aqDeckTrigger.sqf` (`AP_fnc_aqDeckTrigger`), registered at postInit with:

```sqf
["deck", AP_fnc_aqDeckTrigger] call aq_fnc_registerTrigger;
```

**The driver MUST fire `aq_talked` itself.** The shipped `addAction` driver does it for you; a custom driver that forgets makes every `talk` objective on the server impossible to complete — and `talk` is the return leg of every courier job, so the failure lands on finished work:

```sqf
["aq_talked", [_giverId, _giverObj]] call aq_fnc_fact;
```

Add the function to `Functions.h` under the appropriate client class.

- [ ] **Step 5: Prove both paths reach the same board**

In game: open a Fixer by walking up, note the offers. Open the same Fixer through the deck. Expected: identical offer list. Then complete a `talk` objective through the **deck** path specifically — that is the one that proves `aq_talked` fires.

- [ ] **Step 6: Commit**

```bash
cd ~/Armapunk2035-armaquest
git add mission/Armapunk2035.Malden/aq_content.hpp \
        mission/Armapunk2035.Malden/core/web/fn_aqDeckTrigger.sqf \
        mission/Armapunk2035.Malden/Functions.h \
        mission/Armapunk2035.Malden/CfgRE.hpp \
        mission/Armapunk2035.Malden/mission.sqm
git commit -m "feat(aq): givers, markers and the deck trigger driver"
```
No upstream change and no re-vendor: givers are content, and content lives in the mission.

---

## Task 9: Journal as a deck app

**Files:**
- Modify: `mission/Armapunk2035.Malden/ui/html/deck.html`, `mission/Armapunk2035.Malden/Functions.h`

**Interfaces:**
- Consumes: `aq_fnc_journal` verbs `["open"]`, `["attach", _ctrl]`.
- Produces: a "Quests" entry in the deck app registry.

- [ ] **Step 1: Register the app**

Add a Quests entry to the deck's app catalogue in `ui/html/deck.html` (the `LIST_APPS` / app-list structures around lines 1194 and 1912), opening the journal via `["open"] call aq_fnc_journal`.

- [ ] **Step 2: Respect the measured payload cap**

The page→SQF direction is capped at **10,240 characters** — measured, and enforced by arma-webui's own guard. Only player actions travel that way (accept, abandon, select) and all are small. **Do not build the journal to send state upward.** State pushes go SQF→page and are uncapped.

- [ ] **Step 3: Observe the red state**

Open the deck before the whitelist entry from Task 5 Step 2 is present: the page renders and can never call back, with no error. Confirm you can reproduce that, then confirm the whitelist entry fixes it — this is the failure mode the whitelist exists for and it is worth seeing once.

- [ ] **Step 4: Verify native tasks still work as the fallback**

Disable/close the journal and confirm quests still appear as native Arma tasks, still progress, and still pay. The webview must remain non-critical.

- [ ] **Step 5: Commit**

```bash
git add mission/Armapunk2035.Malden/ui/html/deck.html mission/Armapunk2035.Malden/Functions.h
git commit -m "feat(aq): quest journal as a cyberdeck app"
```

---

## Task 10: Content — mainline, radiant, and the verb gate

**Files:**
- Modify: `mission/Armapunk2035.Malden/aq_content.hpp` (`AQ_Quests`, `AQ_Templates`, `AQ_Pools`)
- Create: `tools/aq_verbcheck.py`

**Interfaces:**
- Produces: the authored catalogue and a build-time assertion that every referenced verb has an `aq_fnc_event` call site.

**Scope for this pass: a vertical slice, decided by the owner.** Not the full catalogue —
enough content to exercise every mechanism once, so that bulk authoring afterwards is
repetition rather than risk:

- **A five-quest civ mainline spanning two Fixers.** Entry on `fixer_1`; the handoff to
  `fixer_2` must use `requires[] = {"quest:<prev>"}`, because `chain` only offers to the
  SAME giver. Between them the five quests must use at least `gather`, `deliver`, `talk`
  and `action`, so four of the nine types are proven end to end.
- **One radiant template per side** — civ (`givers[] = fixer_1..4`), cop
  (`maxsec_command`), med (`pharma_technica`) — each with `side` set, so side gating is
  demonstrably doing something.

That set proves chains, cross-giver prerequisites, side gating, radiant slot filling,
payout and persistence. The remaining beats are a later authoring pass and are reviewed as
content, not as code (spec §7.2).

- [ ] **Step 1: Structure the mainline correctly**

- Entry: `giver = "fixer_1"`, `side = "civ"`, `requires[] = {}`.
- Within one Fixer's stretch: `chain = "<next_id>"`.
- **Across Fixers: `requires[] = {"quest:<previous_id>"}` with `giver` set to the next Fixer.** `chain` hands off to the *same* giver only — using it for a cross-giver step produces a quest nothing ever offers, which `aq_fnc_reachability` reports but which looks completely correct in config.

- [ ] **Step 2: Structure the radiant boards**

Templates declare `side` and `givers[]`:

```cpp
class AQ_Templates {
    class civ_courier {
        side     = "civ";
        givers[] = { "fixer_1", "fixer_2", "fixer_3", "fixer_4" };
        weight   = 1;
        // slots, objectives, rewards
    };
    class cop_patrol {
        side     = "cop";
        givers[] = { "maxsec_command" };
        weight   = 1;
    };
    class med_supply {
        side     = "med";
        givers[] = { "pharma_technica" };
        weight   = 1;
    };
};
```

- [ ] **Step 3: Write the verb gate**

Create `tools/aq_verbcheck.py`: parse every `verb = "<name>";` out of the ArmaQuest config, grep the mission and server trees for `aq_fnc_event` call sites naming each verb, and exit non-zero listing any verb with no site.

- [ ] **Step 4: Run it and SEE it fail**

```bash
cd ~/Armapunk2035-armaquest && python3 tools/aq_verbcheck.py
```
Expected: non-zero exit listing every authored verb not yet instrumented — including the deck verbs `qhcast`, `qhbreach`, `proxyarm`/`proxyburn`, `icetraced`, `chipinstall`, `qhtraced`.

- [ ] **Step 5: Instrument exactly those verbs**

Add one `["<verb>", [_item, _qty]] call aq_fnc_event;` line at each site that already knows the thing happened. Only for verbs the content actually references — instrumentation is demand-driven, not a sweep.

- [ ] **Step 6: Run the gate until it passes**

```bash
python3 tools/aq_verbcheck.py && echo "ALL VERBS INSTRUMENTED"
```

- [ ] **Step 7: Run the static content gates**

Reload dev, then in the debug console:
```sqf
[] call aq_fnc_validate;
[] call aq_fnc_reachability;
[] call aq_fnc_dryRun;
```
Expected: validate clean; reachability reports **no** unreachable quest. Any quest listed unreachable is almost certainly a cross-giver step written with `chain`.

- [ ] **Step 8: Commit**

```bash
cd ~/Armapunk2035-armaquest
git add mission/Armapunk2035.Malden/aq_content.hpp tools/aq_verbcheck.py
git add -u mission/ server/          # the instrumented call sites
git commit -m "feat(aq): content, verb instrumentation and the verb gate"
```
No upstream change and no re-vendor — same reason as Task 8.

---

## Task 11: Delete the legacy quest system

Last, deliberately: until now dev has kept a working quest system throughout.

**Files:**
- Delete: `mission/Armapunk2035.Malden/core/quests/` (6 files), `mission/Armapunk2035.Malden/core/config/fn_questsCfg.sqf`
- Modify: `Functions.h`, `dialog/MasterHandler.h`, the `fn_questSel` dialog, `core/session/fn_ClupdatePartial.sqf`, `server/AP_server/core/DB/fn_queryRequest.sqf`
- Create: `sql/drop_legacy_quest_columns.sql`

- [ ] **Step 1: Enumerate the name's meanings before deleting by name**

```bash
grep -rn "AP_fnc_handleQuest\|questsCfg\|AP_activeQuest\|AP_questProgress\|AP_completedQuests\|AP_completedLifetimeQuests\|AP_LifetimeProgressQuests\|AP_questItems\|AP_questAntiCheese\|fnc_questSync\|fnc_questSel\|fnc_questAccept\|fnc_createQuestLoot\|fnc_questPlayerKilled" mission/ server/ | tee /tmp/aq_legacy_sites.txt | wc -l
```
Work from that list. Deleting by name without enumerating meanings is how a shared variable's readers get missed — readers fail silently where writers fail loudly.

- [ ] **Step 2: Delete the files and every reference**

Remove the six functions, the catalogue, their `Functions.h` entries, the `fn_questSel` dialog and its `MasterHandler.h` registration, and the quest cases in `ClupdatePartial` — specifically **case 20**, which pushes `AP_completedLifetimeQuests` into the save packet. Removing the variable without removing its save case leaves a case that serialises an undefined variable every time it fires.

- [ ] **Step 3: Remove the columns from the login select**

In `server/AP_server/core/DB/fn_queryRequest.sqf:73`, drop `completed_quests` and `progress_quests` from the select list. **This shifts every positional index after them** — audit every consumer of that result row, because they read positionally.

- [ ] **Step 4: Verify nothing references the legacy system**

```bash
grep -rn "fnc_handleQuest\|questsCfg" mission/ server/ | wc -l
```
Expected: `0`.

- [ ] **Step 5: Balance-check and reload**

```bash
cd mission/Armapunk2035.Malden
for f in Functions.h dialog/MasterHandler.h core/session/fn_ClupdatePartial.sqf; do
  echo "$f: { = $(tr -cd '{' < $f | wc -c)  } = $(tr -cd '}' < $f | wc -c)"
done
AQ_SRC=~/Armapunk2035-armaquest bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```
Then join and confirm a player still logs in, spawns, and keeps money/gear — the login path was just edited.

- [ ] **Step 6: Drop the columns (irreversible — dev only)**

Create `sql/drop_legacy_quest_columns.sql`:
```sql
ALTER TABLE players DROP COLUMN completed_quests;
ALTER TABLE players DROP COLUMN progress_quests;
```
Apply to the **dev** database only. The live database is frozen behind the 2026-09-11 window; dev is not a valid rehearsal source for it, so this proves nothing about the live drop and must be planned separately.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(aq): delete the legacy quest system and its columns"
```

---

## Task 12: Full verification pass

Nothing is claimed working on the strength of having been written.

- [ ] **Step 1: Boot gates** — `loonydev.log` shows `[AQ] preInit` indexing the catalogue and 6 givers, `storeSql init` naming `sql`, no `PROBLEM`, no `Script ArmaQuest\… not found`.
- [ ] **Step 2: Static gates** — `aq_fnc_validate`, `aq_fnc_reachability`, `aq_fnc_dryRun` clean; `aq_verbcheck.py` exits 0; `grep -rn "fnc_handleQuest"` returns 0.
- [ ] **Step 3: Round trip** — accept a quest from the journal; it also appears as a native task; progress moves in both; completion credits `new_drachma` in Postgres and the client balance refreshes without a relog.
- [ ] **Step 4: Persistence** — reload the server and confirm quest state returns. Verify directly:
```bash
docker exec armapunk-pg psql -U "$PGUSER" -d "$PGDATABASE" -Atc \
  "SELECT skey, left(data,80) FROM armaquest_state ORDER BY skey"
```
This is the only check that proves the Postgres path end to end.
- [ ] **Step 5: Side gating** — a **cop** client sees MaxSec Command's board populated and a Fixer's board empty; a **civ** client sees the reverse. This is the only thing keeping three sides' content apart.
- [ ] **Step 6: Giver access** — all six spawn and are interactable; the deck path and walk-up path show the same board; a `talk` objective completes through the deck driver.
- [ ] **Step 7: Mainline entry** — the opener is offered by `fixer_1` and by no other Fixer.
- [ ] **Step 8: Board is server-owned** — open the journal on a second client and confirm the same offers.

**Explicitly unverifiable in this pass:** live-database behaviour. Dev is not a rehearsal source for live.

---

## Self-Review Notes

**Executed rather than proofread** (the riskiest plan code):
- `apdb_sql.translate()` on the store's upsert → reproduced the real `UntranslatableSQL` failure, then confirmed the fix produces `ON CONFLICT (skey) DO UPDATE SET data=EXCLUDED.data`.
- The translated DDL + upsert run against the live dev Postgres in a transaction, verified overwrite semantics, rolled back, confirmed no table left behind.
- `QUOTE(data)` → confirmed it translates to a bare select plus `stringify={0}`.
- ArmaQuest's remoteExec targets enumerated from source: exactly six, across 35 sites.
- `gen_apdb_schema.py` searched across all branches and worktrees — confirmed absent.

**Two plan bugs found and fixed during self-review, both by checking rather than reading:**
- `AP_fnc_setLicense` **does not exist** — `Functions.h` has only `licenseCfg`, `licenseCheck`, `licensesRead`, and `fn_buyLicense` grants by setting the client variable inline. The plan originally called a function that was never there. Fixed by adding `AP_fnc_aqGrantLicense` (Task 6 Step 2b) instead of inventing a name.
- `AP_fnc_ndFromLegacy` **already returns a string** (`_r toFixed 4`, `core/configuration.sqf:478`). The plan originally wrapped it in `str()`, which would have double-encoded every reward and been rejected by `ndCreditSrv`'s own amount regex. Fixed.

**Marked UNVERIFIED — these are claims, not artifacts:**
- All SQF in this plan. There is no SQF parser available outside the game; brace-balance is the only static gate and the boot log is the real one.
- The `civ_gear` decode shape in `aq_life_fnc_countItem` is inferred from how `fn_queryRequest` selects it, not from a decoded sample. Decode one real row before trusting the item count.
- `AP_licenses`' side-flag structure — `hasLicense`/`grantLicense` assume a `license_civ_` prefix; Task 6 Step 3 checks whether cop/med use another.
- Every giver's `boardSize`, `offerLifetime` and the whole content catalogue: content decisions, deliberately not fixed here (spec §7.2).

**Known gap carried from the spec:** item objectives are not server-verified in this host (§5.3).
