# PySQF — runbook

Getting PySQF running on the dev server, and finding out why when it is not.

PySQF lets SQF call Python. It is the seam the PostgreSQL work needs
(`postgres_plan.md` §1: transport first, dialect second). **Nothing calls it
yet** — this change adds the client and the two diagnostics, and touches no
existing behaviour.

The extension, the daemon and the Python package live in their own repo:
**https://github.com/doombadroid/PySQF** (private). The SQF side — the client
*and* both diagnostics — is vendored here.

---

## What this change adds

| path | what | origin |
|---|---|---|
| `server/AP_server/core/pysqf/fn_pysqfRaw.sqf` | verb level: `call` / `poll` / `chunk` / `free` / `version` / `stats` | vendored |
| `server/AP_server/core/pysqf/fn_pysqfCall.sqf` | ergonomic wrapper, returns `[ok, result]` | vendored |
| `server/AP_server/core/pysqf/fn_pysqfSmoke.sqf` | five-stage diagnostic | vendored |
| `server/AP_server/core/pysqf/fn_pysqfConform.sqf` | conformance suite — the corners the smoke test does not reach | vendored |
| `server/AP_server/config.cpp` | registers the four under `APS_` | this repo |
| `scratchpad/vendor_pysqf.py` | generates the four from an upstream checkout | this repo |

**All four SQF files are generated. Do not hand-edit them.** Re-run
`scratchpad/vendor_pysqf.py` after pulling upstream; it does a mechanical
rename and nothing else, so an upstream fix arrives here by re-running it and a
local edit is silently discarded the next time anyone does. Each file carries a
banner saying so and naming the upstream file it came from.

The rename is `pysqf_fnc_*` → `APS_fnc_*`, because the server compiles both
CfgFunctions trees into `missionNamespace` and a client function sharing a name
silently overwrites the server one. The mapping is the `SUBS` table in the
vendoring script, and the script re-scans its own output afterwards and prints
any upstream name that survived the rename — so a missed one shows up in the
vendoring output rather than as an undefined function at runtime.

**The smoke test and the conformance suite used to be authored here. They are
not any more** (moved upstream 2026-08-14). The reason is specific: the
conformance suite asserts byte-exact properties of Python fixtures in
`python/pysqf/diag.py` — that `diag.raw(nbytes)` serialises to exactly
`nbytes + 2` bytes, that `diag.awkward` puts a `\uXXXX` escape across the
8192-byte seam. Assertions in this repo and the fixtures they assert against in
that one would drift, and the drift would surface here as a conformance failure
blaming the transport. So both halves move together, upstream, and this repo
takes a copy.

What this repo still owns is the integration: the `config.cpp` registration, the
`APS_` names, the dev-box deployment below, and this runbook.

---

## Install

Four things, and **three of the four fail silently** if you get them wrong.
That is what the smoke test exists for.

### 1. Build the extension

```sh
git clone git@github.com:doombadroid/PySQF.git ~/PySQF
cd ~/PySQF && make                       # -> build/ipc-release/pysqf_x64.so
```

`make` builds the `ipc` back end, which is the recommended one — see
`bench/results.md` in that repo for why. `make BACKEND=embed` builds the other.

### 2. Put it where the server will load it

Arma loads extensions from a mod folder named in `-serverMod`. The dev server
already runs:

```
-serverMod=@extDB3;@AP_server
```

so the simplest placement is alongside the existing server addon:

```sh
cp ~/PySQF/build/ipc-release/pysqf_x64.so ~/arma3server_dev/@AP_server/
```

**The filename matters.** A 64-bit Linux server looks for `pysqf_x64.so` when
SQF asks for `"pysqf"`. Wrong name, wrong architecture, or wrong folder all
present identically: `callExtension` returns an empty string and nothing is
logged.

### 3. Install the Python side

```sh
python3 -m venv ~/pysqf-venv
~/pysqf-venv/bin/pip install 'psycopg[binary]'
```

`psycopg` is **not** installed system-wide on this box — checked 2026-08-14. The
daemon imports it lazily, so it starts fine without it and only fails when a
query runs, which is exactly the kind of late failure worth pre-empting.

### 4. Run the daemon

```sh
cd ~/PySQF/python
PYSQF_MODULES='pysqf.db,pysqf.diag' \
PYSQF_SOCKET=/run/user/$(id -u)/pysqf.sock \
PYSQF_DB_DSN='host=127.0.0.1 port=5432 user=... dbname=...' \
~/pysqf-venv/bin/python pysqfd.py
```

Validate config without starting anything:

```sh
~/pysqf-venv/bin/python pysqfd.py --check
```

**`PYSQF_MODULES` must include `pysqf.diag` or the conformance suite tests nothing.**
It defaults to `pysqf.db` alone, so every `diag.*` fixture is absent -- and the
suite reported that as 2 CRITICAL and 46 failures whose text reads like protocol
defects, because a missing fixture and a broken contract both surface as a failed
call. `--check` prints the function count: 4 means diag is missing, 15 means it is
loaded. The suite now refuses to run rather than produce that verdict, but the
daemon is still where it is fixed.

**`PYSQF_SOCKET` must be identical for the daemon and the server process.** A
mismatch here is the single most likely failure, and it looks like "Python is
down" rather than "you typed two different paths".

---

## Verify

On the server, in the debug console:

```sqf
[] spawn APS_fnc_pysqfSmoke;
```

(Vendored from upstream `sqf/fn_pysqfSmoke.sqf`; the full account of what each
stage does and why is that file's own header and `sqf/README.md` upstream. What
follows is the operational summary for this box.)

Then read the RPT for `[pysqf-smoke]`. Five stages, each gated on the last, each
naming the layer that broke:

| stage | proves | a FAIL here means |
|---|---|---|
| 1 extension loaded | `callExtension` answers | wrong `-serverMod`, filename or architecture |
| 2 protocol | the verb layer decodes | the `.so` and the vendored SQF client disagree |
| 3 python reachable | the daemon is alive | daemon down, or `PYSQF_SOCKET` differs between the two sides |
| 4 error channel | a failure arrives **as** a failure | the error path is broken — distrust everything above it |
| 5 database | `select 1` works | DSN, server, or `psycopg` — **not** a PySQF problem |

All five passing prints:

```
[pysqf-smoke] RESULT: all stages passed. PySQF is reachable end to end.
```

Stage 4 is the one to read carefully. If a deliberately failing call reports
success, failure and emptiness are being conflated — which is the specific
defect this whole subsystem exists to avoid inheriting, so treat a pass on
stages 1-3 as meaningless until 4 is green.

All five passed on the dev server on 2026-08-14. See **Status** below for what
that did and did not settle.

---

## The conformance suite

```sqf
[] spawn APS_fnc_pysqfConform;                  // everything
["chunks"] spawn APS_fnc_pysqfConform;          // one group
[["chunks","db"]] spawn APS_fnc_pysqfConform;   // several
```

Vendored from upstream `sqf/fn_pysqfConform.sqf`. Upstream `sqf/README.md` is
the full account — the ten groups, the fixture contract, the rules for adding a
case. What follows is what someone running it on this box needs.

### What it is for

The smoke test proves the path exists: five layers, in order, first one that
breaks named. It walks the happy path and one deliberate failure, and that is
all it is meant to do. Everything it does not touch is where a transport breaks
in production — a result that needs more than one chunk, an argument at the size
ceiling, a call that times out while another is in flight, a string with a
quote or a non-ASCII character in it, a number too precise for a 32-bit float, a
ticket freed twice.

The conformance suite is those corners, run **inside the engine**, because that
is the only place where the engine's own argument quoting, string handling and
number rendering are in the loop. The bench harness in the PySQF repo drives the
same entry points out of process and cannot see any of it.

Run the smoke test first. Conform assumes the extension and the daemon are up; if
they are not it refuses in one line rather than reporting a wall of failures whose
common cause the smoke test would have named. The **database** is a precondition
it checks for itself: with no DSN configured, or a DSN that does not answer, the
whole `db` group is SKIPped with the reason printed once, because fifteen
identical database failures on a box with no database teach the reader to scroll
past red.

It is read-only — it touches no game state and issues no SQL that writes. Its
own footprint is two `missionNamespace` scratch variables, cleared at the end,
and one EachFrame handler that removes itself on its first frame. It takes
noticeably longer than the smoke test, because some cases deliberately wait: a
timeout must be observed timing out, a slow call must be observed not blocking a
fast one, and the largest payload is a 1 MiB document read as 128 chunks. Expect
tens of seconds, not one.

### Reading the output

RPT lines prefixed `[pysqf-conform]`, one per case, then a per-group breakdown,
a total and a verdict:

```
[pysqf-conform] PASS <group>/<case> — <detail> [<n>ms]
[pysqf-conform] OBS  <group>/<case> — <what arrived, and what it cost> [<n>ms]
[pysqf-conform] FAIL <group>/<case> — <what was expected, and what arrived> [<n>ms]
[pysqf-conform] CRIT <group>/<case> — <a failure that must stop a migration> [<n>ms]
[pysqf-conform] SKIP <group>/<case> — <why the whole group could not run>
[pysqf-conform] TOTAL: <n> passed, <n> failed, <n> CRITICAL, <n> observation(s), <n> skipped
[pysqf-conform] VERDICT: …
```

Four line kinds, not two. **OBS** is not a failure: SQF numbers are 32-bit
floats, 16777217 cannot survive the crossing, and reporting physics as a bug
would train the reader to ignore red. An observation is a true fact about the
engine, measured and printed at a moment when someone is looking. **CRIT** is
the opposite — failure and emptiness became the same answer, one ticket
received another's result, or money crossed as a float — and it prints a banner
at the end that is deliberately impossible to scroll past.

Every case runs inside `_runOne`, the conform runner's equivalent of the smoke
test's `_guard`, so **a case that throws is reported as that case's own FAIL
with the exception text attached**,
and the run continues. This is not decoration. A diagnostic that throws does not
merely fail, it misattributes: execution stops after the last line that printed
PASS, and the output then implicates a component that was working. That already
happened once here — a `String` tag read as a `Bool`, `!"ok"` threw, and stages
2-5 of the smoke test never ran while the log looked like stage 1 was the last
good thing. Read a FAIL as being about the case it names and nothing else.

A FAIL is a finding, not necessarily a bug in this repo. It may be in the C
core, the daemon, the vendored SQF client, or the engine's behaviour that the
client assumes. The case detail is written to say which.

### Adding a case

**Not here.** `fn_pysqfConform.sqf` in this repo is generated; a case added to
it disappears the next time anyone runs `scratchpad/vendor_pysqf.py`.

Add it upstream, in `sqf/fn_pysqfConform.sqf`, then re-vendor. The rules are in
that file's own header and in upstream `sqf/README.md`; the short version is
that a case is one row — `["group", "what it proves", { … }]`, body returning
`[ok, detail]` — and that the detail string must be useful **when the case
fails**: "expected 3 chunks, poll said 1" is a diagnosis, "chunk count wrong" is
a second investigation.

If a case needs a new Python-side fixture it goes in `python/pysqf/diag.py`,
upstream, in the same commit as the case that reads it. That coupling is the
whole reason the suite lives there rather than here. A case calling a fixture
the deployed daemon does not have fails with an unresolvable-name error, which
is the correct outcome and not something to code around — it means the daemon on
this box is older than the suite.

---

## Engine facts the first live run settled

Two things that were assumptions in the client's comments until 2026-08-14, and
are now observed. Both change how calling code should be written.

**The array form of `callExtension` returns `[<String>, <returnCode>, <errorCode>]`.**
That is what the client's `_hop` already assumed and read positionally, and it
is now confirmed from a real server rather than from documentation. So the
engine-level error check (`_ec != 0`) is live, and an empty element 0 really
does mean "extension not loaded or unknown ticket", not "empty result".

**SQF rendered a Unix timestamp as `1.78676e+09`.** `diag.ping` returns
`time.time()`; ten significant digits arrived, six came back out. SQF numbers
are 32-bit floats, so about seven significant decimal digits is the ceiling for
*any* number that passes through an SQF variable — this is the engine, not
PySQF, and no amount of care on the Python side changes it.

The consequence is a rule, not a curiosity: **currency, account balances, ids
and timestamps must travel as strings.** A bank balance of 2,147,483,647 does
not survive the round trip as a number; it is silently rounded, and a rounding
that silently *adds* money is a duplication bug that looks like a database
fault. The database module already returns exact-decimal values as strings for
this reason. Do not `parseNumber` them back for anything but display, and never
for arithmetic that gets stored.

---

## Using it

```sqf
private _r = ["db.query", ["select id, name from players where playerid = %s", [_uid]], 10] call APS_fnc_pysqfCall;
_r params ["_ok", "_rows"];
if (!_ok) exitWith { diag_log format ["query failed: %1", _rows]; };
```

Two rules:

- **Scheduled context only.** It polls and yields between attempts. Calling it
  unscheduled starves the VM — the same mistake that cost a scheduler stall in
  the existing DB path.
- **`_ok` is not optional.** `[false, "<message>"]` and `[true, []]` are
  different answers. Never write code that treats them the same.

### The two return conventions

The two functions answer in **different vocabularies**, and nothing about the
shape of the reply distinguishes them — both are a two-element array.

| function | element 0 | why |
|---|---|---|
| `APS_fnc_pysqfRaw` | `String` — `"ok"` \| `"err"` \| `"pending"` | `poll` genuinely has three outcomes and a Bool cannot carry three |
| `APS_fnc_pysqfCall` | `Bool` | by the time it returns, the polling is over: it worked or it did not |

Mixing them has already cost one debugging session. A `String` tag was read as a
Bool, `!"ok"` threw, and four stages of a diagnostic silently never ran while
the log implicated the one stage that had passed.

So read element 0 through `params` **with a type filter**, always. The filter is
what turns a mix-up into a loud failure at the line that made the mistake,
rather than a throw at the first operator that cares:

```sqf
// verb level — String tag
private _raw = ["version", []] call APS_fnc_pysqfRaw;
_raw params [["_tag", "err", [""]], ["_payload", []]];
if (_tag isNotEqualTo "ok") exitWith { /* … */ };

// wrapper — Bool
private _r = ["db.query", ["select 1 as ok", []], 10] call APS_fnc_pysqfCall;
_r params [["_ok", false, [false]], ["_rows", ""]];
if (!_ok) exitWith { /* _rows is the message */ };
```

The defaults matter as much as the types: both default to the *failing* value,
so a reply of an unexpected shape is read as a failure rather than as a success
with a missing result.

Diagnostics available from SQF, all in the PySQF repo's `python/pysqf/`. This
table is a snapshot taken 2026-08-14; upstream is authoritative, and
`diag.names` answers the only question that actually matters at a call site —
what the daemon **on this box** has registered:

| name | what it is for |
|---|---|
| `diag.ping` | Python is reachable, and which interpreter answered. |
| `diag.echo` | the argument path, which fails separately from the result path. |
| `diag.boom` | raises on purpose: a failure must arrive as a failure. |
| `diag.slow` | sleeps: timeouts, and head-of-line blocking. |
| `diag.sized` | a payload of a requested size inside an object — what real traffic looks like. |
| `diag.raw` | a payload of a requested size as a bare JSON string, so the document is exactly `nbytes + 2` bytes and a chunk count can be asserted as an equality. |
| `diag.awkward` | every character class that has broken a layer before, in a document long enough to cross a chunk seam with an escape sitting on it. |
| `diag.shapes` | one value per JSON type the mapping must survive, including the ones SQF cannot hold. |
| `diag.nothing` | returns `None`: the shortest complete result, to be compared against a real failure. |
| `diag.echo_args` | what the argument decoder actually delivered (positional vs keyword). |
| `diag.names` | every dotted name this daemon has registered — "is the fixture I am calling in THIS daemon". |
| `diagdb.ready` | whether a database is configured at all, without dialling one. |
| `diagdb.null` `diagdb.exact` `diagdb.empty` | NULL, exact `numeric`, and an empty result set — each carrying its own expected value. |
| `diagdb.db_error` `diagdb.usage_error` | a failure from PostgreSQL versus one caught before anything is sent. |

---

## Status, honestly

**The smoke test has run inside Arma. The conformance suite has not.** Keep
those two facts apart; they are the whole of what is and is not known.

On 2026-08-14 all five smoke stages passed end to end on the dev server, `ipc`
back end, against PostgreSQL 18.6 in a container. The first query — `select 1`,
on a cold connection, so it includes the pool opening its first connection to
the database — returned in 77 ms.

That settles the integration questions the earlier version of this section
listed as open: the server loads and calls the `.so`, the array form of
`callExtension` behaves as the vendored client assumes, a dispatched call
completes, a deliberate failure arrives as a failure and not as an empty
success, and a real query reaches a real database and comes back.

Verified out of process, as before, and unchanged by the live run:

- both back ends build clean under `-Wall -Wextra -Werror`
- the C and Python suites pass
- the transport is benchmarked, and `call` holds the calling thread for 0.72 µs
- the database module was exercised against a real PostgreSQL 18.4 — a
  parameterised query, an apostrophe surviving intact, an exact-decimal value
  returned as a string rather than a float, an injection attempt inert, and an
  error arriving as `ok=False`

### What one green smoke run does not prove

It proves the path works. It does not prove it works correctly in the corners,
and it says nothing at all about cost under load. Still unproven:

- **Per-frame cost on a populated server.** The 0.72 µs figure is a bench loop
  on an idle box, and the 77 ms query is one call with nothing else happening.
  Neither measures what the call costs when the server is running a full slot
  count and the scheduler is already contended. Until that is measured, treat
  every latency figure here as a lower bound.
- **Everything the conformance suite checks.** Multi-chunk
  results and their reassembly; the argument size ceiling and where the engine
  actually truncates, as opposed to the conservative 8000-char floor the client
  refuses above; timeouts firing as timeouts; concurrent and interleaved
  tickets; `free` behaving idempotently and tickets not leaking; strings with
  quotes, backslashes and non-ASCII surviving both directions; numeric
  precision at the edges of a 32-bit float; error text arriving intact rather
  than truncated at the first quote. None of that has been observed in-engine
  yet. **The suite has been written upstream, vendored here and registered in
  `config.cpp`. It has not been run inside Arma — not once, not partially.**
  Built and wired up is not the same as green, and nothing here should be read
  as if it were.

## Known unknowns

- Whether Arma's `dlopen` flags let the `embed` back end initialise. It
  re-opens libpython `RTLD_GLOBAL` by soname to control this itself, but that is
  untested inside the engine. **The live run used `ipc`, which does not care**,
  so this is exactly as open as it was.
- The real input limit of `callExtension`'s array form. The client refuses an
  args payload over 8000 chars rather than risk a silent truncation; that number
  is a conservative floor, not a measurement.
- Real per-frame cost under a populated server, as opposed to a bench loop.
