# Malden Federal Reserve Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Malden Federal Reserve heist described in `maldenfed.md` — hack the perimeter gate, crack the dome on a 10-minute countdown, loot ten locked safes, run an optional 20-minute "Alamo Fed" on the centre building for a getaway boat, and reset the whole thing when the compound empties.

**Architecture:** One server function (`APS_fnc_maldenFedSRV`) owns all state, all timers and every transition; it is built up task by task. Clients only *request* transitions and only *render* the result — every request is re-validated server-side against the caller's real identity, position and the current phase. The Altis fed client actions (`fn_openGate`, `fn_openVault`, `fn_openSafe`) are rewritten in place for Malden's objects, since this repo ships Malden only.

**Tech Stack:** Arma 3 SQF; mission PBO `mission/Armapunk2035.Malden/`; server addon `server/AP_server/`; dev server at `/home/timb/arma3server_dev` (symlinked as `~/loonydev`); `deploy/reload-armapunk2035.sh` packs and restarts it.

## Global Constraints

- **The spec is `maldenfed.md` in the repo root.** Where this plan and the spec disagree, the spec wins; fix the plan.
- **Clients request, the server decides.** Every client-facing mode of `APS_fnc_maldenFedSRV` re-derives its caller from `remoteExecutedOwner`, and re-checks that the caller is a live, un-restrained civilian within range of the anchor they claim, and that the phase allows it. `remoteExecutedOwner isEqualTo 0` means the call came from the server itself and is trusted.
- **No SQF test framework exists.** "Test first" here means: write the `diag_log` assertion and the exact `grep` that must match, prove it does *not* match on the current build, then implement until it does. In-game checks are listed explicitly and are the owner's to run.
- **Every SQF/HPP file touched must pass `python3 tools/sqf_balance.py <file>` before it is committed.** A brace mismatch in a client function does not error visibly — the player's entire scroll menu silently disappears.
- **Never match braces by per-line net delta.** `} else {` is net zero and a `]` closing a `{` balances by count. `tools/sqf_balance.py` walks a stack; use it.
- **Do not run `git checkout` or any destructive git command on the working tree.** It carries uncommitted in-flight work (island anti-air, radar sabotage, spawn-hold fixes). Commit only the paths each task names.
- **Cop requirement is 0 for testing**, with the restore value in a comment. **The HIGH SECURITY lockout is 300 seconds**, with a TODO to lengthen after testing.
- Log prefix for everything in this feature: `[maldenFed]`. Server RPT is `/home/timb/arma3server_dev/loonydev.log`.
- Commit messages follow the repo's style: a sentence-case subject that says what changed, a body that says *why* and what was ruled out, and a `Co-Authored-By:` line naming a defunct AI (ELIZA, SmarterChild, Microsoft Bob and Dr. Sbaitso are used — pick a fresh one). No Anthropic address.

### Anchor constants (used by every task)

```sqf
AP_FED_CENTRE   = [11197.8, 4459.3];      // ring centre; also an AA battery site
AP_FED_GATEPOS  = [11237.5, 4382.56];     // Land_ConcreteWall_01_l_gate_F, 2.1 m away in mission.sqm
AP_FED_DOMEPOS  = [11197.99, 4459.21, 18.80];   // Land_Dome_Big_F      -- corrected after the first deploy
AP_FED_CTRPOS   = [11196.29, 4457.90, 18.45];   // Land_Medevac_HQ_V1_F -- corrected after the first deploy
AP_FED_BOATPOS  = [11153.3, 4534.19];     // dir 150, placed on the water surface
```

The ten safes, as owner coordinates paired with the `Land_Medevac_house_V1_F` each one names (every pair verified within 3.7 m by parsing `mission.sqm`):

```sqf
AP_FED_SAFEPOS = [
    [11219.5, 4460.22, 18.02], [11219.7, 4453.85, 17.51], [11216.9, 4447.24, 17.15],
    [11186.5, 4438.64, 17.66], [11180.4, 4443.68, 18.54], [11177.5, 4449.53, 19.33],
    [11174.6, 4456.98, 19.14], [11195.7, 4480.83, 21.32], [11202.8, 4480.58, 20.93],
    [11209.5, 4477.60, 20.08]
];
```

### Guarding the server-internal modes

**Added 2026-07-27, after Task 7.** Some modes (`domeOpen`, `alamoOpen`, `boat`, `reset`) must be
reachable only by the server's own timers, never by a client. The obvious guard — refuse when
`remoteExecutedOwner` is non-zero — rests on an assumption nobody can confirm: whether a `spawn`ed
child inherits its parent's `remoteExecutedOwner`. The BIKI says only that the value holds "in this
scope" and is silent on child scripts, and every internal call here is made from inside a `spawn`. If
it *is* inherited, every internal transition refuses itself and the heist silently stops dead ten
minutes in.

Do not bet on it. `case "boot"` generates a key that is never published:

```sqf
        AP_fedInternalKey = str (round (random 1e9));   // server-only; deliberately NOT publicVariable'd
```

and every internal call passes it:

```sqf
            ["domeOpen", AP_fedInternalKey] call APS_fnc_maldenFedSRV;
```

with each internal mode checking it as its first act:

```sqf
        private _key = missionNamespace getVariable ["AP_fedInternalKey", ""];
        if (_key isEqualTo "" || {_arg isNotEqualTo _key}) exitWith {
            diag_log "[maldenFed] domeOpen refused -- missing internal key"; };
```

**The `_key isEqualTo ""` half is not redundant.** `_arg`'s own default is also `""`, so a bare
comparison would *pass* on a server where `boot` never ran and the key was therefore never generated —
the check would silently approve exactly the broken state it exists to catch. Each internal mode also
re-checks its own state precondition (the phase it expects), which closes the same hole from the other
side; keep both, and keep both when copying this to `alamoOpen`, `boat` and `reset`.

A client cannot read the key (it never leaves the server) and cannot guess it, so this is strictly
stronger than the `remoteExecutedOwner` check *and* immune to the question above. Client-facing modes
(`gate`, `dome`, `alamo`, `secure`) keep validating their caller as before — they are supposed to be
called remotely.

### State

```sqf
SRV_maldenFed = [_phase, _phaseEndsAt, _alamo, _alamoEndsAt, _lockoutUntil];
// _phase:  0 SECURE · 1 BREACHED (gate open, alarm live) · 2 COUNTDOWN (10:00) · 3 OPEN (looting)
// _alamo:  0 none · 1 counting (20:00) · 2 open, boat delivered
```

### Deploy / verify loop (referenced by every task)

```bash
cd /home/timb/Armapunk2035
bash deploy/reload-armapunk2035.sh
# then wait for boot — use the Monitor tool with this until-loop, do NOT foreground a bare sleep:
timeout 240 bash -c 'until grep -q "\[maldenFed\]" /home/timb/arma3server_dev/loonydev.log; do sleep 5; done' && echo BOOTED
grep -n '\[maldenFed\]' /home/timb/arma3server_dev/loonydev.log
```

---

## File Structure

**New**

| File | Responsibility |
|---|---|
| `tools/sqf_balance.py` | Arma-aware bracket balance check. Every task's gate. |
| `server/AP_server/core/TON/fn_maldenFedSRV.sqf` | The entire heist: anchors, state, transitions, timers, gold, boat, sweep, reset. Single authority. |
| `mission/Armapunk2035.Malden/core/actions/fn_alamoFed.sqf` | Client: centre-building scroll → terminal minigame → request. |

**Modified**

| File | Change |
|---|---|
| `mission/Armapunk2035.Malden/initServer.sqf` | create the `fed_reserve` marker |
| `server/AP_server/init.sqf` | boot call |
| `server/AP_server/config.cpp` | register `maldenFedSRV` |
| `server/AP_server/core/system/fn_fedLockdown.sqf` | rewrite for Malden objects |
| `server/AP_server/core/TON/fn_fedGoldSpawn.sqf` | retarget to the ten safes |
| `server/AP_server/core/bank/fn_fedAlarm.sqf` | retarget: cop gate 0, marker, dispatch, charges |
| `server/AP_server/core/system/fn_resetFed.sqf` | clear `SRV_maldenFed` |
| `server/AP_server/core/system/fn_fedEventActive.sqf` | read `SRV_maldenFed` |
| `mission/Armapunk2035.Malden/core/functions/fn_activeFederalEvent.sqf` | read `SRV_maldenFed` |
| `mission/Armapunk2035.Malden/core/actions/fn_openGate.sqf` | rewrite: Sequence Breach, no boltcutter |
| `mission/Armapunk2035.Malden/core/actions/fn_openVault.sqf` | rewrite: dome terminal |
| `mission/Armapunk2035.Malden/core/actions/fn_openSafe.sqf` | Malden safes, no talent gate, phase ≥ 2 |
| `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` | six scroll actions |
| `mission/Armapunk2035.Malden/dialog/function/fn_handleMessage.sqf` | two countdown types |
| `mission/Armapunk2035.Malden/CfgRE.hpp` | whitelist `APS_fnc_maldenFedSRV` |
| `mission/Armapunk2035.Malden/Functions.h` | register `alamoFed` |
| `TODO.md` | the two deliberate follow-ups |

---

### Task 0: Stop `initPlayerLocal` aborting on the Altis fed gates

**This is a live defect, found while planning, and it blocks testing everything below.**

`initPlayerLocal.sqf:86` reads `AP_fed_gates = [fedGate_west, fedGate_east, fedGate_SE];`. Those are three **Altis mission.sqm object names**; parsing Malden's sqm finds none of them, and grep finds no other definition in the tree. An undefined variable in an expression does not warn in SQF — it raises and **halts the script**, so the remaining ~359 lines of `initPlayerLocal.sqf` never run on any client.

Evidence, from today's dev server RPT:

```
2026/07/27, 19:04:54 "[LB-LOG][-SCRIPTERR-] steamuser (76561190000000001):
  [Undefined variable in expression: fedgate_west, ...initPlayerLocal.sqf,80,3232,..."
```

**Files:**
- Modify: `mission/Armapunk2035.Malden/initPlayerLocal.sqf:86`

**Interfaces:**
- Consumes: nothing.
- Produces: `AP_fed_gates` as a real (possibly empty) array on every client, and an `initPlayerLocal` that runs to the end.

- [ ] **Step 1: Confirm the fault is still live on the current build**

```bash
grep -n 'Undefined variable in expression: fedgate_west' /home/timb/arma3server_dev/loonydev.log | tail -3
```

Expected: at least one line. If there is none, re-check against a fresh client join before assuming it is fixed — this only fires when a player initialises.

- [ ] **Step 2: Confirm the names are defined nowhere**

```bash
cd /home/timb/Armapunk2035
grep -rn 'fedGate_west\|fedGate_east\|fedGate_SE' --include=*.sqf --include=*.hpp --include=*.h .
```

Expected: exactly one hit — line 86 itself. No definition anywhere.

- [ ] **Step 3: Replace the line**

```sqf
// The three names this used to reference -- fedGate_west/east/SE -- are ALTIS mission.sqm objects.
// Malden's sqm has none of them, and an undefined variable in an expression HALTS the script rather
// than warning, so every client aborted initPlayerLocal here and silently skipped everything below
// (confirmed in the RPT: "Undefined variable in expression: fedgate_west"). The Malden Fed resolves
// its gate at boot instead, into AP_fedGate, which arrives by publicVariable and may not be here yet
// on a fast join -- hence the default rather than a direct read.
AP_fed_gates = [missionNamespace getVariable ["AP_fedGate", objNull]] select { !isNull _x };
```

- [ ] **Step 4: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initPlayerLocal.sqf
```

Expected: `ok mission/Armapunk2035.Malden/initPlayerLocal.sqf`

- [ ] **Step 5: Deploy, join, and confirm the abort is gone**

Deploy, join with a client, then:

```bash
grep -c 'Undefined variable in expression: fedgate_west' /home/timb/arma3server_dev/loonydev.log
```

Expected: `0` for the current run. Confirm in game that the client's scroll menu and HUD are intact.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/initPlayerLocal.sqf
git commit -m "$(cat <<'EOF'
Stop every client aborting initPlayerLocal on three Altis gate names

AP_fed_gates was built from fedGate_west/east/SE -- objects that exist in ALTIS's mission.sqm and
nowhere on this map. An undefined variable in an expression does not warn in SQF, it halts the script,
so initPlayerLocal died at line 86 on every join and the ~359 lines below it never ran. The RPT has
been saying so on every client init: "Undefined variable in expression: fedgate_west".

The Malden Fed resolves its own gate at boot into AP_fedGate, so that is what the list is built from
now, filtered for null because publicVariable may not have landed yet on a fast join.

Co-Authored-By: Jeeves
EOF
)"
```

---

### Task 1: Promote the bracket checker into the repo

`sqf_balance.py` has been rebuilt from scratch in at least three past sessions because it only ever lived in a session scratchpad. Every task below depends on it, so it goes in the tree first.

**Files:**
- Create: `tools/sqf_balance.py`
- Modify: `tools/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `python3 tools/sqf_balance.py <file>...` — prints `ok <file>` per clean file, `<file>:<line>:<col> ...` per fault, exit code 1 if any file is bad.

- [ ] **Step 1: Copy the tool in**

```bash
cd /home/timb/Armapunk2035
cp /tmp/claude-1000/-home-timb/e6e8779c-cb16-48d4-8469-533efde73c63/scratchpad/sqf_balance.py tools/sqf_balance.py
chmod +x tools/sqf_balance.py
```

If that scratchpad is gone, the file is 83 lines and its docstring is quoted in `maldenfed.md`'s sibling memory; rewrite it to this contract: walk a stack over the file, treat `""` inside `"…"` and `''` inside `'…'` as escaped quotes, ignore `//` and `/* */` **only outside strings**, and report the first closer that does not match the opener on top of the stack, with line and column.

- [ ] **Step 2: Prove it catches a real fault**

```bash
cd /home/timb/Armapunk2035
printf 'if (true) then {\n    private _a = [1, 2};\n};\n' > /tmp/bad.sqf
python3 tools/sqf_balance.py /tmp/bad.sqf; echo "exit=$?"
```

Expected: a line naming `/tmp/bad.sqf` line 2 with a `}` closing a `[`, and `exit=1`.

- [ ] **Step 3: Prove it passes the tree it will be gating**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py $(git ls-files 'mission/Armapunk2035.Malden/core/actions/*.sqf') | grep -v '^ok' ; echo "exit=$?"
```

Expected: no output above the `ok` lines. (`grep -v` exiting 1 on no matches is the pass.)

- [ ] **Step 4: Document it**

Append to `tools/README.md`:

```markdown
### sqf_balance.py

Arma-aware bracket balance check. `python3 tools/sqf_balance.py <file>...`

SQF escapes a quote by DOUBLING it (`""` inside `".."`), a backslash means nothing, and comments only
count outside strings. A per-line net delta is useless -- `} else {` is net zero, and a mis-PAIRED
bracket (a `]` closing a `{`) balances perfectly by count. This walks a stack and reports the first
bracket that closes the wrong opener, with line and column. Run it on every .sqf you touch: a brace
fault in a client function throws no visible error, it silently deletes the player's whole scroll menu.
```

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add tools/sqf_balance.py tools/README.md
git commit -m "$(cat <<'EOF'
Put the bracket checker in the tree instead of rebuilding it every session

This has been written from scratch at least three times because it only ever existed in a session
scratchpad. It is the gate on every SQF edit here: a mismatched brace in a client function raises
nothing at load, it just silently removes the player's entire scroll menu, and the naive check --
per-line net delta -- cannot see the two faults that actually happen, since `} else {` is net zero and
a `]` closing a `{` balances by count.

Co-Authored-By: Dr. Sbaitso
EOF
)"
```

---

### Task 2: The `fed_reserve` marker, and the three consumers it wakes up

`fed_reserve` does not exist on Malden. Creating it lights up code in `AP_server/init.sqf` that has been inert since the fork. Audit before creating, so nothing starts firing unexamined.

**Files:**
- Modify: `mission/Armapunk2035.Malden/initServer.sqf` (marker creation, near the existing gather-field alias block ~line 67)
- Read only: `server/AP_server/init.sqf:288, 769-830, 1069`

**Interfaces:**
- Consumes: nothing.
- Produces: global marker `fed_reserve` at `[11197.8, 4459.3]`, readable by `getMarkerPos "fed_reserve"`.

- [ ] **Step 1: Audit the three consumers and write down what each will now do**

```bash
cd /home/timb/Armapunk2035
grep -n 'fed_reserve' server/AP_server/init.sqf
sed -n '765,830p;1065,1072p' server/AP_server/init.sqf
```

Expected: three sites — the federal-event dispatch target (line ~288), a boot lockdown block plus a 600 m broken-terrain repair sweep (~769-830), and a `Land_Cargo_Patrol_V1_F` destruction pass within 200 m (~1069).

Record the verdict in the commit body. The known answers: the map has **zero** `Land_Cargo_Patrol_V1_F` (it carries V3/V4), so the destruction pass is a no-op; the repair sweep is desirable; the boot lockdown block is superseded by Task 4 and must be checked for double-locking.

- [ ] **Step 2: Write the assertion first**

Add to `mission/Armapunk2035.Malden/initServer.sqf`, immediately after the gather-field alias `forEach` block (search for `["mine_3",` to find its end):

```sqf
// MALDEN FEDERAL RESERVE -- the whole feature keys off this marker (dispatch, map marker, the AA
// battery list, the boot lockdown). It does not exist on this map, so it is created here at the ring
// centre. Creating it wakes three previously-inert consumers in AP_server\init.sqf; all three were
// audited before this line went in (see the commit).
if ((getMarkerPos "fed_reserve") isEqualTo [0,0,0]) then {
    createMarker ["fed_reserve", [11197.8, 4459.3]];
    "fed_reserve" setMarkerAlpha 0;   // an anchor, not a label -- the robbery marker is created live
    diag_log format ["[maldenFed] fed_reserve marker created at %1", getMarkerPos "fed_reserve"];
} else {
    diag_log format ["[maldenFed] fed_reserve marker already present at %1", getMarkerPos "fed_reserve"];
};
```

- [ ] **Step 3: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initServer.sqf
```

Expected: `ok mission/Armapunk2035.Malden/initServer.sqf`

- [ ] **Step 4: Deploy and confirm**

Run the deploy/verify loop from Global Constraints, then:

```bash
grep -n 'fed_reserve marker' /home/timb/arma3server_dev/loonydev.log
```

Expected: `[maldenFed] fed_reserve marker created at [11197.8,4459.3,0]`

Also confirm the marker did not get swept: `initServer.sqf` deletes every global marker outside the world at boot+20 s. `11197.8 < worldSize` on Malden (12800), so it survives — check:

```bash
grep -n 'MAP CLEANUP' /home/timb/arma3server_dev/loonydev.log
```

Expected: the cleanup list does **not** contain `fed_reserve`.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/initServer.sqf
git commit   # subject: "Anchor the Malden Fed on a fed_reserve marker"; body records the three-consumer audit
```

---

### Task 3: Resolve the anchors at boot and log what they are

Two of the anchors are Malden terrain objects whose classes cannot be read offline — they are in neither `mission.sqm` nor `custom_p3ds/`. Resolve them by proximity and log class, model and distance, the way `APS_fnc_fedRadarSRV` already resolves the radar tower.

**Files:**
- Create: `server/AP_server/core/TON/fn_maldenFedSRV.sqf`
- Modify: `server/AP_server/config.cpp` (near line 275, beside `fedRadarSRV`)
- Modify: `server/AP_server/init.sqf` (beside the existing `APS_fnc_fedRadarSRV` boot call, ~line 1077)

**Interfaces:**
- Consumes: marker `fed_reserve` (Task 2).
- Produces, all `publicVariable`d so client action conditions can compare objects directly:
  `AP_fedGate` (object), `AP_fedDome` (object), `AP_fedCentre` (object), `AP_fedSafes` (array of 10 objects), `AP_FED_CENTRE` (position), `AP_FED_BOATPOS` (position).
  Entry point `["boot"] call APS_fnc_maldenFedSRV`.

- [ ] **Step 1: Write the assertion that must fail now**

```bash
grep -c '\[maldenFed\] anchor' /home/timb/arma3server_dev/loonydev.log
```

Expected: `0` — nothing resolves anchors yet.

- [ ] **Step 2: Create the function**

`server/AP_server/core/TON/fn_maldenFedSRV.sqf`:

```sqf
/*
    APS_fnc_maldenFedSRV -- the Malden Federal Reserve heist, end to end.

    ONE AUTHORITY. Phase, both countdowns, the gold, the boat, the sweep and every reset live here.
    Clients REQUEST a transition and RENDER the result; they never own state. Each client-facing mode
    re-derives its caller from remoteExecutedOwner and re-checks identity, distance and phase, because
    the CfgRE whitelist makes this callable by any client with any arguments (model: fn_fedRadarSRV,
    fn_chopShopSell). remoteExecutedOwner == 0 means the server called it and is trusted.

    THE ANCHORS ARE NOT ALL OURS. The gate is in mission.sqm; the dome and the centre building are in
    neither the sqm nor custom_p3ds/, so they belong to Malden's terrain and their classes cannot
    be read offline. They are resolved by proximity at boot and LOGGED -- class, model, distance -- so
    the classes can be hardcoded once the RPT says what they are, exactly as the radar tower was.

    MODES
      ["boot"]            server-internal: resolve anchors, lock down, start the sweep
      ["gate"]            client: perimeter gate breached  (phase 0 -> 1)
      ["dome"]            client: dome terminal breached   (phase 1 -> 2, 10:00)
      ["alamo"]           client: centre terminal breached (alamo 0 -> 1, 20:00)
      ["secure"]          cop:    force the reset when the compound is already empty
      ["reset", _reason]  server-internal
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]], ["_arg", "", ["", objNull, 0]]];

AP_FED_CENTRE  = [11197.8, 4459.3];
AP_FED_BOATPOS = [11153.3, 4534.19];
private _gatePos = [11237.5, 4382.56];
private _domePos = [11218.9, 4471.06, 18.16];
private _ctrPos  = [11189.1, 4459.5, 19.78];
private _safePos = [
    [11219.5, 4460.22, 18.02], [11219.7, 4453.85, 17.51], [11216.9, 4447.24, 17.15],
    [11186.5, 4438.64, 17.66], [11180.4, 4443.68, 18.54], [11177.5, 4449.53, 19.33],
    [11174.6, 4456.98, 19.14], [11195.7, 4480.83, 21.32], [11202.8, 4480.58, 20.93],
    [11209.5, 4477.60, 20.08]
];

// ---- describe one object for the log: class, model, distance. Terrain objects report an empty
//      typeOf, which is exactly why the model name is logged next to it.
private _fnc_describe = {
    params ["_obj", "_from"];
    if (isNull _obj) exitWith { "NULL" };
    format ["%1 (model %2) at %3, %4 m",
        typeOf _obj,
        (getModelInfo _obj) param [0, "?"],
        getPosATL _obj,
        ((getPosATL _obj) distance _from) toFixed 1];
};

switch (toLower _mode) do {

    case "boot": {
        // The gate is a real sqm object; nearestObjects on the class is exact.
        private _gates = nearestObjects [_gatePos, ["Land_ConcreteWall_01_l_gate_F"], 15];
        AP_fedGate = _gates param [0, objNull];
        diag_log format ["[maldenFed] anchor GATE   = %1", [AP_fedGate, _gatePos] call _fnc_describe];

        // The dome and the centre are unknown. Take the nearest object of ANY class that is not one of
        // the ring's safes and not a piece of scenery clutter, and log it for identification.
        private _fnc_nearestStructure = {
            params ["_pos", "_radius"];
            private _cands = (nearestObjects [_pos, [], _radius]) select {
                !(typeOf _x isEqualTo "Land_Medevac_house_V1_F")
                && {!((getModelInfo _x) param [0, ""] isEqualTo "")}
                && {(boundingBoxReal _x) params ["_bmin", "_bmax"]; ((_bmax select 2) - (_bmin select 2)) > 2.5}
            };
            _cands param [0, objNull]
        };
        AP_fedDome   = [_domePos, 25] call _fnc_nearestStructure;
        AP_fedCentre = [_ctrPos,  25] call _fnc_nearestStructure;
        diag_log format ["[maldenFed] anchor DOME   = %1", [AP_fedDome, _domePos] call _fnc_describe];
        diag_log format ["[maldenFed] anchor CENTRE = %1", [AP_fedCentre, _ctrPos] call _fnc_describe];

        // The ten safes: one Land_Medevac_house_V1_F per owner coordinate. Log the match distance and
        // whether the building reports interior positions -- a safe with none would drop its briefcase
        // at the owner's coordinate, ~3 m OUTSIDE its own door, i.e. lootable without breaching.
        AP_fedSafes = [];
        {
            private _s = (nearestObjects [_x, ["Land_Medevac_house_V1_F"], 12]) param [0, objNull];
            if (isNull _s) then {
                diag_log format ["[maldenFed] anchor SAFE %1 = NULL -- no medevac house within 12 m of %2", _forEachIndex, _x];
            } else {
                if !(_s in AP_fedSafes) then { AP_fedSafes pushBack _s; };
                diag_log format ["[maldenFed] anchor SAFE %1 = %2, buildingPos %3",
                    _forEachIndex, [_s, _x] call _fnc_describe, count (_s buildingPos -1)];
            };
        } forEach _safePos;

        { publicVariable _x; } forEach ["AP_fedGate", "AP_fedDome", "AP_fedCentre", "AP_fedSafes",
                                        "AP_FED_CENTRE", "AP_FED_BOATPOS"];
        diag_log format ["[maldenFed] boot complete -- gate %1, dome %2, centre %3, %4 safe(s)",
            !isNull AP_fedGate, !isNull AP_fedDome, !isNull AP_fedCentre, count AP_fedSafes];
    };

    default { diag_log format ["[maldenFed] unknown mode '%1' -- ignored", _mode]; };
};
true
```

- [ ] **Step 3: Register the function**

In `server/AP_server/config.cpp`, beside line 276 (`class fedRadarSRV {};`), add:

```cpp
 class maldenFedSRV {};      // the Malden Federal Reserve heist (one authority: state, timers, gold, boat, reset)
```

In `server/AP_server/init.sqf`, beside the existing `[] call APS_fnc_fedRadarSRV;` line, add:

```sqf
["boot"] call APS_fnc_maldenFedSRV;   // Malden Federal Reserve: resolve anchors, lock down, start the sweep
```

- [ ] **Step 4: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenFedSRV.sqf server/AP_server/init.sqf
```

Expected: `ok` for both.

- [ ] **Step 5: Deploy and read the anchors**

Run the deploy/verify loop, then:

```bash
grep -n '\[maldenFed\] anchor\|\[maldenFed\] boot complete' /home/timb/arma3server_dev/loonydev.log
```

Expected: 13 anchor lines (gate, dome, centre, ten safes) and `boot complete -- gate true, dome true, centre true, 10 safe(s)`.

**Stop and show the owner these lines.** The dome and centre classes are unknown until this runs; the owner confirms they name the right buildings before anything is built on top of them. If either resolved to the wrong object, hardcode the class in `_fnc_nearestStructure` and re-run this task.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenFedSRV.sqf server/AP_server/config.cpp server/AP_server/init.sqf
git commit   # subject: "Resolve the Malden Fed's anchors at boot and log what they are"
```

---

### Task 3b: Promote the dome and the centre, and resolve them by class

**Added 2026-07-27 after the first deploy proved Task 3's resolution wrong.** The boot log resolved
`DOME` and `CENTRE` to `w_sharpstone_02` — rocks, at sea level, 19 m away. The real structures are not
in `mission.sqm`; they are `fn_mapData.sqf` entries, and on the server they did not exist at all.

```
Land_Dome_Big_F       [11197.993, 4459.207, 18.803]  init="" isServer=false   -> 10-minute target
Land_Medevac_HQ_V1_F  [11196.290, 4457.902, 18.449]  init="" isServer=false   -> Alamo centre
```

`isServer = false` with an empty init means `fn_createVehicleLocal` builds them with
`createSimpleObject` on each client: a statue with no doors, no animations and no interaction, which
the server never spawns. Nothing in this plan that locks, unlocks or animates a door can work against
that. Owner approved promoting both.

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` (two entries)
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (`"boot"` resolution)

**Interfaces:**
- Consumes: Task 3's `"boot"` mode.
- Produces: `AP_fedDome` = the `Land_Dome_Big_F`; `AP_fedCentre` = the `Land_Medevac_HQ_V1_F`. Both
  real, server-side, door-bearing objects. Same variable names as before, so no later task changes.

- [ ] **Step 1: Assert the fault is still live**

```bash
grep -n 'anchor DOME\|anchor CENTRE' /home/timb/arma3server_dev/loonydev.log | tail -2
```

Expected: both lines name `w_sharpstone_02.p3d` with an empty class — that is the bug.

- [ ] **Step 2: Promote the two entries**

In `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf`, find these two entries by their exact
coordinates and change the **fifth field** (the `isServer` flag, the `false` immediately before the
entry's closing `]`) to `true`:

```
["Land_Dome_Big_F",[11197.993,4459.207,18.803],[[-0.4669,0.8843,0.0000],[0.0000,0.0000,1.0000]],"",false]
["Land_Medevac_HQ_V1_F",[11196.290,4457.902,18.449],[[-0.8829,-0.4695,0.0000],[0.0000,0.0000,1.0000]],"",false]
```

Leave the init field empty. It only selects `createSimpleObject` on the **client** branch, which no
longer runs for these two: `fn_dynamicMapSystem` handles only entries where `!(_xIsServer)`, and the
server branch of `fn_createVehicleLocal` is `isServer && isDedicated -> createVehicle` regardless of
the init. Verify that claim by reading both files before you edit, and say so in your report.

`fn_mapData.sqf` is ~15,700 entries on very long lines. Match on the full coordinate triplet, not on
the class name — `Land_Dome_Big_F` and `Land_Medevac_HQ_V1_F` each appear more than once on this map,
including a second pair ~1.7 km away at `[9472.7, 4244.7]` that must **not** be touched.

- [ ] **Step 3: Resolve by class instead of guessing**

In `fn_maldenFedSRV.sqf`, replace the `_fnc_nearestStructure` helper and its two call sites with exact
class matches at the known positions:

```sqf
        // The dome and the centre are fn_mapData objects, promoted to isServer = true so the server
        // spawns them for real (see the commit). Both are known classes at known positions now, so
        // this is an exact match with a tight radius -- and a NULL here means the promotion did not
        // take, which is exactly what the log needs to say.
        AP_fedDome   = (nearestObjects [_domePos, ["Land_Dome_Big_F"], 12]) param [0, objNull];
        AP_fedCentre = (nearestObjects [_ctrPos, ["Land_Medevac_HQ_V1_F"], 12]) param [0, objNull];
```

Delete `_fnc_nearestStructure` entirely — nothing else uses it. Keep both `diag_log` lines exactly as
they are; they are the assertion.

- [ ] **Step 4: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenFedSRV.sqf mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
```

Expected: `ok` for both. (The mapData check matters — it is a single enormous array literal and one
stray bracket silently deletes every map object on the server.)

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/config/fn_mapData.sqf server/AP_server/core/TON/fn_maldenFedSRV.sqf
git diff --cached --stat   # must be exactly these two files
git commit   # subject: "Give the Fed's dome and centre building to the server, with doors"
```

The controller deploys afterwards and confirms both anchors resolve to the right classes.

---

### Task 4: Lock the Fed down at boot

Everything is locked before anyone touches it: the gate, the dome, the ten safes and the centre.

**Files:**
- Modify: `server/AP_server/core/system/fn_fedLockdown.sqf` (full rewrite)
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (call it from `"boot"`)

**Interfaces:**
- Consumes: `AP_fedGate`, `AP_fedDome`, `AP_fedCentre`, `AP_fedSafes` (Task 3).
- Produces: `[] call APS_fnc_fedLockdown` — idempotent; every anchor ends `AP_vaultlocked = 1`, doors disabled and shut, `AP_goldSpawned = false`.

- [ ] **Step 1: Write the assertion that must fail now**

```bash
grep -c 'fedLockdown: locked' /home/timb/arma3server_dev/loonydev.log
```

Expected: `0`.

- [ ] **Step 2: Rewrite the lockdown**

Replace the whole of `server/AP_server/core/system/fn_fedLockdown.sqf`:

```sqf
/*
    APS_fnc_fedLockdown -- put the Malden Federal Reserve back to a clean, robbable state.

    Was Altis-shaped: it searched 400 m of the fed marker for Land_Dome_Big_F domes,
    Land_Research_house_V1_F safes and Land_BarGate_F gates. Malden has NONE of those classes, so on
    this map it locked nothing at all and silently reported three zeroes. It now works off the anchors
    APS_fnc_maldenFedSRV resolves at boot, which include two objects that belong to the terrain.

    Idempotent by design -- boot, every reset and the admin's !srv resetfed all call it.
*/
private _fnc_seal = {
    params ["_obj"];
    if (isNull _obj) exitWith { false };
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _obj) >> "numberOfDoors");
    // CAPITAL D to match the engine's own spelling in BIS_fnc_Door -- NOT because the casing matters.
    // Retracting a note added here on 2026-07-29 that called the lowercase form "a different key" and
    // the lock "a no-op for a month": SQF variable names are case-insensitive (BIKI Identifier;
    // BIKI allVariables returns every name in lower case), so both spellings are the same variable and
    // the lock always worked. Either spelling is correct; do not treat this as a bug fix.
    for "_i" from 1 to _n do { _obj setVariable [format ["bis_disabled_Door_%1", _i], 1, true]; };
    // Corrected 2026-07-27: the dome and the centre turned out to be a real Land_Dome_Big_F and a
    // Land_Medevac_HQ_V1_F (fn_mapData entries, promoted to server-spawned in Task 3b), so both DO
    // report numberOfDoors and the loop above is live for them. Shutting every animation source on
    // top of that is what the Altis lockdown did, and it is what closes anything the door indices
    // miss -- the concrete gate in particular drives an animationSource, not a door.
    { _obj animate [_x, 0, true]; } forEach (animationNames _obj);
    _obj setVariable ["AP_vaultlocked", 1, true];
    _obj setVariable ["AP_goldSpawned", false, true];
    true
};

private _sealed = 0;
{ if ([_x] call _fnc_seal) then { _sealed = _sealed + 1; }; }
    forEach ([AP_fedGate, AP_fedDome, AP_fedCentre] + (missionNamespace getVariable ["AP_fedSafes", []]));

// the gate carries the bar-gate contract too: gate_max 0 = fully shut, door action disabled
if (!isNull AP_fedGate) then {
    AP_fedGate setVariable ["gate_max", 0, true];
    AP_fedGate setVariable ["bis_disabled_Door_1", 1, true];
    AP_fedGate animateSource ["door_1_sound_source", 0];
};
missionNamespace setVariable ["AP_fedComponentSpawned", false, true];   // re-arm the mining-component drop

// NOTE 2026-07-29: the shipped line has since grown a gate count, because the perimeter turned out to
// be THREE gates, not one (e7e7c01). What the build actually logs is:
//   ["[maldenFed] fedLockdown: locked %1 object(s) -- %2 perimeter gate(s), dome, centre and %3 safe(s)",
//       _sealed, _gatesSealed, count (missionNamespace getVariable ["AP_fedSafes", []])]
diag_log format ["[maldenFed] fedLockdown: locked %1 object(s) -- gate, dome, centre and %2 safe(s)",
    _sealed, count (missionNamespace getVariable ["AP_fedSafes", []])];
true
```

- [ ] **Step 3: Call it from boot**

In `fn_maldenFedSRV.sqf`, in `case "boot"`, immediately before the `publicVariable` loop:

```sqf
        [] call APS_fnc_fedLockdown;
```

- [ ] **Step 4: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/system/fn_fedLockdown.sqf server/AP_server/core/TON/fn_maldenFedSRV.sqf
```

Expected: `ok` for both.

- [ ] **Step 5: Deploy and confirm**

```bash
grep -n 'fedLockdown: locked' /home/timb/arma3server_dev/loonydev.log
```

Expected: `locked 15 object(s) -- 3 perimeter gate(s), dome, centre and 10 safe(s)`.

Corrected 2026-07-29: this said **13**, which was the arithmetic for a ONE-gate perimeter and was left
unrevised when e7e7c01 grew the list to three. `_sealed` counts every non-null object the seal returned
true for — 3 gates + dome + centre + 10 safes = **15**.

**Read the gate count, not the total.** The total moves whenever a safe fails to resolve, so it cannot
tell "three gates and eight safes" apart from "one gate and ten safes". `3 perimeter gate(s)` is the
discriminating field — it is what proves the resolver found the whole perimeter instead of only the
breach anchor, which is the regression e7e7c01 fixed. `1 perimeter gate(s)` is a failure whatever the
total reads.

**In game:** walk up to the gate, the dome, the centre and any two safes. None of them opens by hand.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/system/fn_fedLockdown.sqf server/AP_server/core/TON/fn_maldenFedSRV.sqf
git commit   # subject: "Lock the Malden Fed at boot instead of searching for Altis classes"
```

---

### Task 5: State, and the two event-active checks that read it

**Files:**
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (state helper + boot init)
- Modify: `server/AP_server/core/system/fn_fedEventActive.sqf:14` (the `fed` row)
- Modify: `mission/Armapunk2035.Malden/core/functions/fn_activeFederalEvent.sqf` (its `fed` row)

**Interfaces:**
- Consumes: Task 4.
- Produces: `SRV_maldenFed` (publicVariable'd), and `AP_fnc_fedSetState` as a local helper inside `fn_maldenFedSRV.sqf` — call as `[_phase, _phaseEndsAt, _alamo, _alamoEndsAt, _lockoutUntil] call _fnc_setState`, any element passed as `-1` meaning "leave unchanged".

- [ ] **Step 1: Write the assertion that must fail now**

```bash
grep -c 'maldenFed\] state' /home/timb/arma3server_dev/loonydev.log
```

Expected: `0`.

- [ ] **Step 2: Add the state helper**

In `fn_maldenFedSRV.sqf`, after `_fnc_describe`:

```sqf
// ---- the ONLY writer of SRV_maldenFed. -1 in any slot means "leave that one alone".
//      AP_fed_robbed is kept in lockstep as a compatibility shim: the evidence-bomb fuse, the cop
//      actions and several client conditions still read it, and none of them need to learn a new name.
private _fnc_setState = {
    params ["_p", "_pEnd", "_a", "_aEnd", "_lock"];
    private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
    if (_p    isNotEqualTo -1) then { _s set [0, _p]; };
    if (_pEnd isNotEqualTo -1) then { _s set [1, _pEnd]; };
    if (_a    isNotEqualTo -1) then { _s set [2, _a]; };
    if (_aEnd isNotEqualTo -1) then { _s set [3, _aEnd]; };
    if (_lock isNotEqualTo -1) then { _s set [4, _lock]; };
    SRV_maldenFed = _s;
    publicVariable "SRV_maldenFed";
    AP_fed_robbed = [((_s select 0) > 0), serverTime];
    publicVariable "AP_fed_robbed";
    diag_log format ["[maldenFed] state %1", _s];
    _s
};
```

And in `case "boot"`, before `[] call APS_fnc_fedLockdown;`:

```sqf
        [0, -1, 0, -1, -1] call _fnc_setState;
```

- [ ] **Step 3: Point the server-side mutual-exclusion check at it**

In `server/AP_server/core/system/fn_fedEventActive.sqf`, replace the `fed` row:

```sqf
    ["fed",      ((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) > 0],
```

- [ ] **Step 4: Point the client check at it**

In `mission/Armapunk2035.Malden/core/functions/fn_activeFederalEvent.sqf`, replace its `fed` row the same way. Read the file first — it is the client twin and its array is laid out identically, but confirm the row's exact text before editing:

```bash
cd /home/timb/Armapunk2035
grep -n '"fed"' mission/Armapunk2035.Malden/core/functions/fn_activeFederalEvent.sqf
```

- [ ] **Step 5: Balance-check and deploy**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenFedSRV.sqf \
    server/AP_server/core/system/fn_fedEventActive.sqf \
    mission/Armapunk2035.Malden/core/functions/fn_activeFederalEvent.sqf
```

Then deploy and:

```bash
grep -n 'maldenFed\] state' /home/timb/arma3server_dev/loonydev.log
```

Expected: `[maldenFed] state [0,-1,0,-1,-1]`.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenFedSRV.sqf server/AP_server/core/system/fn_fedEventActive.sqf mission/Armapunk2035.Malden/core/functions/fn_activeFederalEvent.sqf
git commit   # subject: "Give the Malden Fed one state variable and make both event-active checks read it"
```

---

### Task 6: The perimeter gate — Sequence Breach, alarm, MaxSec

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/actions/fn_openGate.sqf` (full rewrite)
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (replace the civ "Bolt Cut Gate" entry, ~line 605)
- Modify: `mission/Armapunk2035.Malden/CfgRE.hpp` (~line 17)
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (`"gate"` mode)
- Modify: `server/AP_server/core/bank/fn_fedAlarm.sqf` (cop gate 0, Malden marker/dispatch)

**Interfaces:**
- Consumes: `SRV_maldenFed`, `AP_fedGate` (Tasks 3-5).
- Produces: client `AP_fnc_openGate` (no arguments; reads `cursorObject`); server mode `["gate"] call APS_fnc_maldenFedSRV`; phase 1.

- [ ] **Step 1: Whitelist the remoteExec target**

In `mission/Armapunk2035.Malden/CfgRE.hpp`, beside line 17:

```cpp
    class APS_fnc_maldenFedSRV {allowedTargets = 2;};      // client -> server request only; the server re-checks caller, distance and phase
```

- [ ] **Step 2: Rewrite the client action**

Replace the whole of `mission/Armapunk2035.Malden/core/actions/fn_openGate.sqf`:

```sqf
/*
    AP_fnc_openGate -- breach the Federal Reserve's perimeter gate.

    Malden's Fed has no boltcutter path: the gate is locked at boot, locked after every reset, and the
    Sequence Breach is the only way through. Buffer 10, the asylum-laptop tier -- this is the first
    move of a Federal event, not a car door.

    Everything this decides is re-decided on the server (APS_fnc_maldenFedSRV "gate"). What happens
    here is the minigame and the local feedback; the gate itself, the alarm and the phase are the
    server's.
*/
if !(playerSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck to breach the gate."] call AP_fnc_broadcast};

private _state = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
if ((_state param [0, 0]) isNotEqualTo 0) exitWith {
    [2, "The Reserve is already breached."] call AP_fnc_broadcast};
if ((_state param [4, -1]) > serverTime) exitWith {
    [2, format ["Security is high at the Reserve. Try again in %1 minute(s).",
        ceil (((_state param [4, -1]) - serverTime) / 60)]] call AP_fnc_broadcast};
if (["fed"] call AP_fnc_activeFederalEvent) exitWith {
    ["There is already another Federal Event happening.", "basic"] spawn AP_fnc_handleMessage};
if (isNull AP_fedGate || {(player distance AP_fedGate) > 5}) exitWith {
    [2, "You are not at the Reserve gate."] call AP_fnc_broadcast};

AP_action_in_use = true;
private _r = [10] call AP_fnc_cyberdeckSeq;
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {[2, "The trace caught you -- the gate stays shut."] call AP_fnc_broadcast;};
};

[["gate"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
```

- [ ] **Step 3: Swap the scroll action**

In `mission/Armapunk2035.Malden/core/fn_setupActions.sqf`, replace the civilian `Bolt Cut Gate` entry (line ~605, the one whose condition tests `"Land_BarGate_F"` and `AP_inv_boltCutter`) with:

```sqf
            AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Perimeter Gate</t>",AP_fnc_openGate,"",0,false,false,"",'(playerSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_fedGate", objNull ] )) && (cursorObject isEqualTo (missionNamespace getVariable [ "AP_fedGate", objNull ] )) && ((player distance cursorObject) <= 5) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) isEqualTo 0) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);
```

Note the condition is a **string**, and this file has been through a formatter — keep it on one line and keep the spacing style of its neighbours.

- [ ] **Step 4: Add the server mode**

In `fn_maldenFedSRV.sqf`, add a caller-resolution helper after `_fnc_setState`:

```sqf
// ---- who really called this. 0 = the server itself (trusted). Anything else must resolve to a live,
//      un-restrained civilian standing at the anchor they claim -- the whitelist means the arguments
//      themselves prove nothing.
private _fnc_caller = {
    params ["_anchor", "_maxDist"];
    private _src = remoteExecutedOwner;
    if (_src isEqualTo 0) exitWith { objNull };                       // server-internal: no check, no caller
    private _c = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _c
        || {!alive _c}
        || {side _c isNotEqualTo civilian}
        || {_c getVariable ["AP_restrained", false]}
        || {(_c distance _anchor) > _maxDist}) then {
        ["-SEC-", _c, format ["BLOCKED maldenFedSRV (dist %1) by %2",
            if (isNull _c) then {-1} else {round (_c distance _anchor)},
            if (isNull _c) then {"?"} else {getPlayerUID _c}]] call APS_fnc_logIt;
        _c = objNull;
        AP_fedReject = true;
    };
    _c
};
```

and the mode itself, before `default`:

```sqf
    case "gate": {
        AP_fedReject = false;
        private _caller = [AP_fedGate, 8] call _fnc_caller;
        if (AP_fedReject) exitWith {};
        private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isNotEqualTo 0) exitWith {};
        if ((_s param [4, -1]) > serverTime) exitWith {};
        if (["fed"] call APS_fnc_fedEventActive) exitWith {};

        // open the gate
        AP_fedGate setVariable ["gate_max", 1, true];
        AP_fedGate setVariable ["bis_disabled_Door_1", 0, true];
        AP_fedGate setVariable ["AP_vaultlocked", 0, true];
        AP_fedGate animateSource ["door_1_sound_source", 1];
        { AP_fedGate animate [_x, 1, true]; } forEach (animationNames AP_fedGate);

        [1, -1, -1, -1, -1] call _fnc_setState;
        [_caller] call APS_fnc_fedAlarm;
        ["-FED-", _caller, "perimeter gate breached -- Malden Fed phase 1"] call APS_fnc_logIt;
    };
```

- [ ] **Step 5: Retarget the alarm**

In `server/AP_server/core/bank/fn_fedAlarm.sqf`:

- change the tenured-cop gate to `< 0` and update the comment to read `owner 2026-07-27: Malden testing -- cop requirement 0. Restore to < 6 at public launch.`
- delete the `AP_fed_robbed = [true, serverTime]; publicVariable "AP_fed_robbed";` pair — `_fnc_setState` owns that variable now.
- keep the dispatch, the `robberyMarker`, the `Sound_Alarm` source and the 30-second sweep that adds the **wanted charge** to new arrivals.
- the `fed_alarm` object referenced by `createSoundSource [..., position fed_alarm, ...]` is an **Altis sqm object and does not exist here** — `position` on an undefined variable halts the script the same way Task 0's fault did. Replace both uses with `AP_FED_CENTRE`:

```sqf
_soundOn = createSoundSource ["Sound_Alarm", AP_FED_CENTRE, [], 0];
deleteMarker "robberyMarker";
createMarker ["robberyMarker", AP_FED_CENTRE];
```

- **Delete the end-detector half of that same loop.** Inside `while {AP_bank_inProgress} do {...}` the branch beginning `if (_activeRobbers == 0) then {_success = true; ...}` runs the entire Altis ending: it re-locks `AP_bank_gates` / `AP_bank_vaults` / `AP_bank_safes` (three lists that name Altis classes and are empty here), sets `SRV_lastRobbery`, resolves the sportsbook, clears `AP_bank_inProgress` and re-titles the marker. **The Malden sweep in Task 12 owns the ending**, and two authorities racing to end the same heist is exactly the "stuck robbery" deadlock `fn_resetFed` exists to clean up after. Keep the loop, keep the `_newRobbers` / `APS_fnc_wantedAdd` branch, and cut the `_activeRobbers == 0` branch down to nothing but the sportsbook resolve, which Task 12's reset then triggers instead:

```sqf
if (_activeRobbers == 0) then {
    // owner 2026-07-27: the ENDING moved to APS_fnc_maldenFedSRV's sweep (two-empty-sweeps rule).
    // What used to be here re-locked three Altis object lists that are empty on this map, set the
    // 15-minute SRV_lastRobbery cooldown the Malden Fed deliberately does not use, and cleared
    // AP_bank_inProgress -- all of it now belongs to case "reset". This loop only recruits robbers.
};
```

  Everything the deleted branch did that is still wanted — dispatch resolution, the "no longer tracking" broadcast, the marker retitle, the sportsbook resolve — moves into `case "reset"` in Task 12. Add them there as part of this task's follow-through and note it in the commit.

- [ ] **Step 6: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/actions/fn_openGate.sqf \
    mission/Armapunk2035.Malden/core/fn_setupActions.sqf \
    server/AP_server/core/TON/fn_maldenFedSRV.sqf \
    server/AP_server/core/bank/fn_fedAlarm.sqf
```

Deploy, then in game: aim at the gate → **Breach Perimeter Gate** appears with a Cyberdeck and not without one. Win the sequence → gate opens, the MaxSec broadcast fires, a red "Robbery in Progress" marker appears at the ring centre, and everyone in the compound picks up the Federal Reserve Robbery charge. Then:

```bash
grep -n 'maldenFed\] state\|perimeter gate breached' /home/timb/arma3server_dev/loonydev.log
```

Expected: `state [1,-1,0,-1,-1]` and the `-FED-` log line.

Try the gate again from a second account: refused, phase is no longer 0. Try `[["gate"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;` from a client debug console while standing 300 m away: refused, with a `-SEC- BLOCKED` line in the log.

- [ ] **Step 7: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/actions/fn_openGate.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf mission/Armapunk2035.Malden/CfgRE.hpp server/AP_server/core/TON/fn_maldenFedSRV.sqf server/AP_server/core/bank/fn_fedAlarm.sqf
git commit   # subject: "Breach the Malden Fed's gate with the Sequence Breach, and fire the alarm from it"
```

---

### Task 7: The dome terminal and the 10-minute countdown

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/actions/fn_openVault.sqf` (full rewrite)
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (replace the "Break Into Dome (Side Door)" entry, ~line 599)
- Modify: `mission/Armapunk2035.Malden/dialog/function/fn_handleMessage.sqf` (two new types, beside `case "bank_robbery"` ~line 74)
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (`"dome"` mode + the timer loop)

**Interfaces:**
- Consumes: phase 1 (Task 6).
- Produces: phase 2 with `_phaseEndsAt = serverTime + 600`, then phase 3 at expiry with the dome's doors open. Message types `fed_countdown` and `alamo_countdown`.

- [ ] **Step 1: Add both countdown message types**

In `mission/Armapunk2035.Malden/dialog/function/fn_handleMessage.sqf`, immediately after `case "bank_robbery": {...};`:

```sqf
        case "fed_countdown": {_duration = (60 * 10);
                _priority = 10;
                _color = [0.2, 1.0, 0.73];   // cyberdeck cyan, same as the bank drill
            };
        case "alamo_countdown": {_duration = (60 * 20);
                _priority = 10;
                _color = [0.957, 0.686, 0.176];   // amber -- a second, longer clock, visibly not the first
            };
```

- [ ] **Step 2: Rewrite the client action**

Replace the whole of `mission/Armapunk2035.Malden/core/actions/fn_openVault.sqf`:

```sqf
/*
    AP_fnc_openVault -- crack the Federal Reserve dome from the terminal at its side door.

    Was the Altis flow: hack a Land_Dome_Big_F's electrical panel, then hold a 2-minute pylon-disarm
    bar, then the doors open immediately. Malden's dome is a terrain object with no named door
    selections to stand next to, and the owner's flow is different: the terminal STARTS a ten-minute
    clock, and the doors open when it runs out. So there is no progress bar here at all -- the wait IS
    the bar, it runs server-side, and it does not care whether the hacker stays.

    The alarm has already fired: the gate breach is what wakes MaxSec (phase 1), which gives them the
    ten minutes to arrive.
*/
if !(playerSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck to breach the dome."] call AP_fnc_broadcast};

private _state = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
if ((_state param [0, 0]) isNotEqualTo 1) exitWith {
    [2, "Cut the perimeter gate first."] call AP_fnc_broadcast};
if (isNull AP_fedDome || {(player distance AP_fedDome) > 12}) exitWith {
    [2, "You are not at the dome terminal."] call AP_fnc_broadcast};
if (!isNil "AP_fedHackCooldown" && {AP_fedHackCooldown > serverTime}) exitWith {
    [2, format ["Your deck is still cooling down -- %1s left.", ceil (AP_fedHackCooldown - serverTime)]] call AP_fnc_broadcast};

AP_action_in_use = true;
private _r = [3] call AP_fnc_cyberdeckTerm;   // difficulty 3 = 9 commands, the Fed tier
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {AP_fedHackCooldown = serverTime + 120;
        [2, "The trace locked your deck out for two minutes."] call AP_fnc_broadcast;};
};

[["dome"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
```

- [ ] **Step 3: Swap the scroll action**

In `fn_setupActions.sqf`, replace the `Break Into Dome (Side Door)` entry (~line 599) with:

```sqf
            if(player distance getMarkerPos"fed_reserve"<=400) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Breach Dome Terminal</t>",AP_fnc_openVault,"",0,false,false,"",'(playerSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_fedDome", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_fedDome", objNull ] )) <= 12) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) isEqualTo 1) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);
```

- [ ] **Step 4: Add the server mode and the timer**

In `fn_maldenFedSRV.sqf`, add a door-opening helper beside `_fnc_setState`:

```sqf
// ---- open every door-ish animation on an object and re-enable its door actions. Deliberately NOT
//      "animate everything to 1": a terrain structure has animation sources that are not doors, and the
//      Altis vault code learned this the hard way.
private _fnc_throwOpen = {
    params ["_obj"];
    if (isNull _obj) exitWith {};
    private _n = getNumber (configFile >> "CfgVehicles" >> (typeOf _obj) >> "numberOfDoors");
    // CAPITAL D, same as the seal above, to match the engine's own spelling -- and for no other
    // reason. See the retraction at the seal: SQF variable names are case-insensitive, so the
    // lowercase form this plan used to show addressed the SAME variable and unlocked correctly.
    for "_i" from 1 to _n do { _obj setVariable [format ["bis_disabled_Door_%1", _i], 0, true]; };
    _obj setVariable ["AP_vaultlocked", 0, true];
    { _obj animate [_x, 1, true]; } forEach ((animationNames _obj) select {
        private _a = toLower _x;
        ((_a find "door") >= 0) && {(_a find "locked") isEqualTo -1}
    });
};
```

and the mode:

```sqf
    case "dome": {
        AP_fedReject = false;
        private _caller = [AP_fedDome, 15] call _fnc_caller;
        if (AP_fedReject) exitWith {};
        private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isNotEqualTo 1) exitWith {};

        private _ends = serverTime + 600;
        [2, _ends, -1, -1, -1] call _fnc_setState;
        ["-FED-", _caller, "dome terminal cracked -- 10:00 running"] call APS_fnc_logIt;

        // the top-right draining box, to everyone who can see the fight
        private _near = allPlayers select { (_x distance AP_FED_CENTRE) < 400 };
        ["RESERVE VAULT CYCLING -- 10 MINUTES", "fed_countdown",
            {((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isEqualTo 2}]
            remoteExec ["AP_fnc_handleMessage", _near];
        [[[0,1,2], "The Federal Reserve vault is cycling open. Ten minutes."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;

        [_ends] spawn {
            params ["_ends"];
            waitUntil { uiSleep 2;
                serverTime >= _ends
                || {((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isNotEqualTo 2} };
            if (((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isNotEqualTo 2) exitWith {
                diag_log "[maldenFed] 10:00 timer abandoned -- phase changed under it (reset)"; };
            ["domeOpen"] call APS_fnc_maldenFedSRV;
        };
    };

    case "domeopen": {   // server-internal only -- reached from the timer above
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {
            diag_log "[maldenFed] domeOpen refused -- client-originated"; };
        [AP_fedDome] call _fnc_throwOpen;
        [3, -1, -1, -1, -1] call _fnc_setState;
        // Called DIRECTLY, not through AP_fnc_MP: fn_fedGoldSpawn's security block reads
        // remoteExecutedOwner and treats 0 as "the server asked, trust it". Routing a server-side call
        // back through the MP layer would put a non-zero owner on it and trip its own proximity gate.
        [AP_fedDome] call APS_fnc_fedGoldSpawn;
        [[[0,1,2], "The Reserve vault is OPEN."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        ["-FED-", objNull, "dome opened -- phase 3, gold spawning"] call APS_fnc_logIt;
    };
```

`APS_fnc_fedGoldSpawn` is retargeted in Task 9; until then it will log that it found no inner buildings, which is expected and harmless.

- [ ] **Step 5: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/actions/fn_openVault.sqf \
    mission/Armapunk2035.Malden/core/fn_setupActions.sqf \
    mission/Armapunk2035.Malden/dialog/function/fn_handleMessage.sqf \
    server/AP_server/core/TON/fn_maldenFedSRV.sqf
```

In game, after breaching the gate: the terminal action appears at the dome, the nine-command minigame runs, and on a win the countdown box appears top-right and drains. Ten minutes later the dome's doors open on their own.

```bash
grep -n 'maldenFed\] state\|dome terminal cracked\|dome opened' /home/timb/arma3server_dev/loonydev.log
```

Expected: `state [2,<t>,0,-1,-1]`, then ten minutes later `state [3,...]` and `dome opened`.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/actions/fn_openVault.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf mission/Armapunk2035.Malden/dialog/function/fn_handleMessage.sqf server/AP_server/core/TON/fn_maldenFedSRV.sqf
git commit   # subject: "Crack the dome on a ten-minute clock instead of a pylon-disarm bar"
```

---

### Task 8: The ten safes — crack or blow, no talent gate

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/actions/fn_openSafe.sqf`
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (the "Crack Safe" and "Plant Demo Charge" entries, ~lines 601 and 603)

**Interfaces:**
- Consumes: `AP_fedSafes`, phase (Tasks 3, 5).
- Produces: each safe ends `AP_vaultlocked = 0` with its doors open.

- [ ] **Step 1: Read the current gates before changing them**

```bash
cd /home/timb/Armapunk2035
sed -n '1,45p' mission/Armapunk2035.Malden/core/actions/fn_openSafe.sqf
```

Note where it tests `typeOf` against the Altis safe classes and where `43 in AP_side_talents` appears.

- [ ] **Step 2: Retarget the action**

In `fn_openSafe.sqf`, replace the class test — wherever it checks `(typeOf _safe) in ["Land_Research_house_V1_F", "Land_Research_HQ_F"]` — with membership of the resolved list, which is exact and needs no class name:

```sqf
if !(_safe in (missionNamespace getVariable ["AP_fedSafes", []])) exitWith {
    [2, "That is not a Reserve safe."] call AP_fnc_broadcast};
```

and add the phase gate beside the other early exits:

```sqf
// Available from the moment the vault starts cycling, so the countdown is prep time rather than
// standing around: a safe opened early simply has its briefcase appear inside it when the clock ends.
if (((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) < 2) exitWith {
    [2, "The safes are sealed until the vault starts cycling."] call AP_fnc_broadcast};
```

- [ ] **Step 3: Swap both scroll actions**

In `fn_setupActions.sqf`, replace the `Crack Safe` entry (~line 601):

```sqf
                AP_actions pushBack(_plb_obj addAction ["Crack Safe",AP_fnc_openSafe,false,0,false,false,"",'(cursorObject in (missionNamespace getVariable [ "AP_fedSafes", [ ] ] )) && ((player distance cursorObject) <= 6) && ((cursorObject getVariable [ "AP_vaultlocked", 1 ] ) isEqualTo 1) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) >= 2) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);
```

and the `Plant Demo Charge` entry (~line 603) — same condition, `AP_inv_demoCharge >= 1` instead of the deck, and **no** `43 in AP_side_talents`:

```sqf
                AP_actions pushBack(_plb_obj addAction ["Plant Demo Charge",AP_fnc_openSafe,true,0,false,false,"",'(cursorObject in (missionNamespace getVariable [ "AP_fedSafes", [ ] ] )) && ((player distance cursorObject) <= 6) && ((cursorObject getVariable [ "AP_vaultlocked", 1 ] ) isEqualTo 1) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) >= 2) && (AP_inv_demoCharge >= 1) && (!AP_action_in_use) && (isNull objectParent player)',6]);
```

- [ ] **Step 4: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/actions/fn_openSafe.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
```

In game: before the dome terminal is cracked, neither action offers on a safe. During the countdown both do. Crack one with the sequence game and blow one with a demo charge — both open, and the demo charge is consumed. Confirm the demo route works on a character with **no** talents.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/actions/fn_openSafe.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
git commit   # subject: "Point the safe breach at Malden's ten ring buildings and drop the talent gate"
```

---

### Task 9: The gold

**Files:**
- Modify: `server/AP_server/core/TON/fn_fedGoldSpawn.sqf`

**Interfaces:**
- Consumes: `AP_fedSafes` (Task 3), called from `"domeOpen"` (Task 7).
- Produces: one `Land_Suitcase_F` per safe carrying `AP_droppedItems = [["goldbar", 1..5]]`, plus the existing one-per-event crypto mining component.

- [ ] **Step 1: Write the assertion that must fail now**

```bash
grep -n 'no inner buildings near dome' /home/timb/arma3server_dev/loonydev.log
```

Expected: present — the function is still looking for Altis `Land_Research_house_V1_F` and finding none.

- [ ] **Step 2: Retarget the search**

In `fn_fedGoldSpawn.sqf`, replace the `_buildings` line:

```sqf
private _buildings = missionNamespace getVariable ["AP_fedSafes", []];
```

and its failure message:

```sqf
if (_buildings isEqualTo []) exitWith {
    diag_log "[maldenFed] fedGoldSpawn: AP_fedSafes is empty -- no gold spawned (boot resolve failed?)";};
```

Keep everything else: the `#302` event-exclusion gate, the caller/proximity/`AP_vaultlocked` security block, the once-per-dome `AP_goldSpawned` flag, the 1-5 bars per case, the 30-minute self-delete, and the mining-component drop.

Change the security block's distance test from `> 60` to `> 120`: the ring is ~50 m across and the caller now stands at the dome, not at the building being filled.

- [ ] **Step 3: Log which spawn spot each case got**

Inside the `forEach _buildings` loop, right after `_pos` is chosen, add:

```sqf
    diag_log format ["[maldenFed] gold case %1 -> %2 (%3)", _forEachIndex, _pos,
        if (_spots isEqualTo []) then {"FALLBACK: object centre -- check this one is INSIDE"} else {"buildingPos"}];
```

- [ ] **Step 4: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fedGoldSpawn.sqf
```

Run the heist to the end of the ten minutes, then:

```bash
grep -n 'maldenFed\] gold case\|spawned .* gold case' /home/timb/arma3server_dev/loonydev.log
```

Expected: ten `gold case N -> [...] (buildingPos)` lines and `spawned 10 gold case(s)`.

**Any line reading FALLBACK means that safe's briefcase is at the owner's coordinate, ~3 m outside its own door — lootable without breaching.** Report those to the owner before going further; the fix is a hand-picked interior offset per affected building.

In game: each case is inside its building, is picked up with the standard Y-menu pickup, and carries 1-5 gold bars.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_fedGoldSpawn.sqf
git commit   # subject: "Fill Malden's ten ring safes with the gold instead of Altis research houses"
```

---

### Task 10: Alamo Fed — the centre building

**Files:**
- Create: `mission/Armapunk2035.Malden/core/actions/fn_alamoFed.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h` (beside line 151-152)
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (new entry beside the dome terminal)
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (`"alamo"` and `"alamoOpen"` modes)

**Interfaces:**
- Consumes: phase 3 (Task 7).
- Produces: `alamo = 1` with `_alamoEndsAt = serverTime + 1200`, then `alamo = 2` with the centre open, 5 cases × 2 bars inside, and the boat call in Task 11.

- [ ] **Step 1: Register the client function**

In `mission/Armapunk2035.Malden/Functions.h`, beside `class openVault {};`:

```cpp
 class alamoFed {};
```

- [ ] **Step 2: Write the client action**

`mission/Armapunk2035.Malden/core/actions/fn_alamoFed.sqf`:

```sqf
/*
    AP_fnc_alamoFed -- start an Alamo Fed on the Reserve's centre building.

    The second, bigger score, and only for a crew that already holds the ground: it needs the dome
    open (phase 3), and it runs a twenty-minute clock on top of a robbery that is already live and
    already has MaxSec driving at it. What it buys is ten more bars in the centre and the getaway
    boat.
*/
if !(playerSide isEqualTo civilian) exitWith {};
if !(isNull objectParent player) exitWith {[2, "You cannot do this from within a vehicle."] call AP_fnc_broadcast};
if (AP_action_in_use) exitWith {};
if (!(call AP_fnc_hasDeck)) exitWith {[2, "You need a Cyberdeck for this."] call AP_fnc_broadcast};

private _state = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
if ((_state param [0, 0]) isNotEqualTo 3) exitWith {
    [2, "Open the Reserve vault first."] call AP_fnc_broadcast};
if ((_state param [2, 0]) isNotEqualTo 0) exitWith {
    [2, "An Alamo Fed is already running."] call AP_fnc_broadcast};
if (isNull AP_fedCentre || {(player distance AP_fedCentre) > 12}) exitWith {
    [2, "You are not at the centre building."] call AP_fnc_broadcast};

AP_action_in_use = true;
private _r = [3] call AP_fnc_cyberdeckTerm;
AP_action_in_use = false;
if !(_r isEqualTo 1) exitWith {
    if (_r isEqualTo 0) then {[2, "The trace caught you -- the Alamo stays sealed."] call AP_fnc_broadcast;};
};

[["alamo"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;
```

- [ ] **Step 3: Add the scroll action**

In `fn_setupActions.sqf`, immediately after the Breach Dome Terminal entry:

```sqf
            if(player distance getMarkerPos"fed_reserve"<=400) then {AP_actions pushBack(_plb_obj addAction ["<t color='#FF0000'>Start an Alamo Fed</t>",AP_fnc_alamoFed,"",0,false,false,"",'(playerSide isEqualTo civilian) && (!isNull (missionNamespace getVariable [ "AP_fedCentre", objNull ] )) && ((player distance (missionNamespace getVariable [ "AP_fedCentre", objNull ] )) <= 12) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) isEqualTo 3) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0, -1, 0 ] ] ) param [ 2, 0 ] ) isEqualTo 0) && ((call AP_fnc_hasDeck)) && (!AP_action_in_use) && (isNull objectParent player)',6]);
```

- [ ] **Step 4: Add both server modes**

In `fn_maldenFedSRV.sqf`, before `default`:

```sqf
    case "alamo": {
        AP_fedReject = false;
        private _caller = [AP_fedCentre, 15] call _fnc_caller;
        if (AP_fedReject) exitWith {};
        private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isNotEqualTo 3) exitWith {};
        if ((_s param [2, 0]) isNotEqualTo 0) exitWith {};

        private _ends = serverTime + 1200;
        [-1, -1, 1, _ends, -1] call _fnc_setState;
        ["-FED-", _caller, "ALAMO started -- 20:00 running"] call APS_fnc_logIt;

        private _near = allPlayers select { (_x distance AP_FED_CENTRE) < 400 };
        ["ALAMO FED -- 20 MINUTES", "alamo_countdown",
            {((missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isEqualTo 1}]
            remoteExec ["AP_fnc_handleMessage", _near];
        [[[0,1,2], "An ALAMO FED has been started at the Reserve. Twenty minutes."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;

        [_ends] spawn {
            params ["_ends"];
            waitUntil { uiSleep 2;
                serverTime >= _ends
                || {((missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isNotEqualTo 1} };
            if (((missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0]]) param [2, 0]) isNotEqualTo 1) exitWith {
                diag_log "[maldenFed] 20:00 Alamo timer abandoned -- state changed under it (reset)"; };
            ["alamoOpen"] call APS_fnc_maldenFedSRV;
        };
    };

    case "alamoopen": {   // server-internal only
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {
            diag_log "[maldenFed] alamoOpen refused -- client-originated"; };
        [AP_fedCentre] call _fnc_throwOpen;
        [-1, -1, 2, -1, -1] call _fnc_setState;

        // Ten bars, as FIVE cases of two, so the crew shares instead of one player taking the lot.
        private _spots = AP_fedCentre buildingPos -1;
        private _base  = if (_spots isEqualTo []) then { getPosATL AP_fedCentre } else { selectRandom _spots };
        if (_spots isEqualTo []) then {
            diag_log "[maldenFed] alamo gold FALLBACK: centre has no buildingPos -- cases at the object centre, verify they are INSIDE"; };
        for "_i" from 0 to 4 do {
            private _p = _base vectorAdd [(_i - 2) * 0.6, 0, 0];
            private _c = "Land_Suitcase_F" createVehicle _p;
            _c setPosATL _p;
            _c setVariable ["owner", "alamo_gold", true];
            _c setVariable ["AP_droppedItems", [["goldbar", 2]], true];
            diag_log format ["[maldenFed] alamo gold case %1 at %2", _i, _p];
        };
        [[[0,1,2], "The Alamo vault is OPEN."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        ["-FED-", objNull, "ALAMO opened -- 10 bars in 5 cases"] call APS_fnc_logIt;
        ["boat"] call APS_fnc_maldenFedSRV;   // Task 11
    };
```

Until Task 11 lands, `["boat"]` falls through to `default` and logs an unknown mode. That is expected.

- [ ] **Step 5: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/actions/fn_alamoFed.sqf \
    mission/Armapunk2035.Malden/core/fn_setupActions.sqf \
    server/AP_server/core/TON/fn_maldenFedSRV.sqf
```

In game: the Alamo action does **not** appear before the dome opens, appears after, runs the nine-command terminal, and puts a second amber countdown on screen alongside nothing else (the first box is gone by then — phase 3 ends it). Twenty minutes later the centre opens with five cases of two bars.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/actions/fn_alamoFed.sqf mission/Armapunk2035.Malden/Functions.h mission/Armapunk2035.Malden/core/fn_setupActions.sqf server/AP_server/core/TON/fn_maldenFedSRV.sqf
git commit   # subject: "Add the Alamo Fed on the Reserve's centre building"
```

---

### Task 11: The getaway boat

**Files:**
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (`"boat"` mode)

**Interfaces:**
- Consumes: `"alamoOpen"` (Task 10).
- Produces: `AP_fedBoat` (object, publicVariable'd) — a `B_Boat_Armed_01_minigun_F` with keys distributed, `AP_vcap = 999999` and ten bars already in its virtual trunk.

- [ ] **Step 1: Add the mode**

In `fn_maldenFedSRV.sqf`, before `default`:

```sqf
    case "boat": {   // server-internal only -- called from alamoOpen
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {
            diag_log "[maldenFed] boat refused -- client-originated"; };

        // The owner's coordinate carries z 8.65, which is above the waterline here (the piers alongside
        // sit at -4.8), so only the XY is used and the hull is put on the surface.
        private _pos = [AP_FED_BOATPOS select 0, AP_FED_BOATPOS select 1, 0];
        private _boat = createVehicle ["B_Boat_Armed_01_minigun_F", _pos, [], 0, "NONE"];
        _boat setPosASL [_pos select 0, _pos select 1, 0.6];
        _boat setDir 150;
        _boat lock 0;
        _boat setFuel 1;
        _boat setVariable ["AP_eventVeh", true, true];
        _boat setVariable ["owner", "malden_fed_boat", true];
        // Unlimited virtual (T) inventory, the asylum Tempest's mechanism -- fn_openInventory reads
        // AP_vcap and defaults it to 100, which would not hold a single haul out of here.
        _boat setVariable ["AP_vcap", 999999, true];
        // Ten bars already aboard. AP_vinv is [[[item, qty], ...], totalWeight]; a gold bar weighs 64
        // in fn_virtItemCfg, so ten of them is 640.
        _boat setVariable ["AP_vinv", [[["goldbar", 10]], 640], true];

        // Keys go to everyone who was in the compound, keyed off the FED and not off the boat: it sits
        // ~120 m offshore, so a boat-centred radius would miss the crew still inside the walls.
        private _keys = [];
        {
            if ((side _x isEqualTo civilian) && {alive _x} && {(_x distance AP_FED_CENTRE) < 400}) then {
                _keys pushBack [getPlayerUID _x, name _x];
                [[_boat], "AP_fnc_addVehicle2Chain", _x, false, false] spawn AP_fnc_MP;
            };
        } forEach allPlayers;
        _boat setVariable ["AP_vehOwners", _keys, true];

        AP_fedBoat = _boat;
        AP_fedBoatSpawn = getPosATL _boat;
        publicVariable "AP_fedBoat";
        [[0, "The getaway boat has arrived on the west shore -- it is already carrying ten bars."],
            "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
        diag_log format ["[maldenFed] getaway boat spawned at %1 dir 150, keys to %2 player(s)", getPosASL _boat, count _keys];
        ["-FED-", objNull, format ["getaway boat delivered, %1 key holder(s)", count _keys]] call APS_fnc_logIt;
    };
```

- [ ] **Step 2: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenFedSRV.sqf
grep -n 'getaway boat spawned' /home/timb/arma3server_dev/loonydev.log
```

Expected: one line, the position at sea level (not 8.65), and a key count matching who was on site.

In game: the boat is afloat, not beached and not sunk; it faces 150; anyone who was in the compound can drive it and nobody else can; its T inventory already holds 10 gold bars and accepts far more; the minigun turret works.

- [ ] **Step 3: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenFedSRV.sqf
git commit   # subject: "Deliver the Alamo getaway boat with the crew's keys and ten bars aboard"
```

---

### Task 12: The failure condition — empty compound, HIGH SECURITY, reset

**Files:**
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (sweep loop in `"boot"`, `"reset"` mode)
- Modify: `TODO.md`

**Interfaces:**
- Consumes: everything above.
- Produces: `["reset", _reason] call APS_fnc_maldenFedSRV` — server-internal; leaves phase 0, `alamo` 0, `_lockoutUntil = serverTime + 300`.

- [ ] **Step 1: Add the reset mode**

In `fn_maldenFedSRV.sqf`, before `default`:

```sqf
    case "reset": {   // server-internal only
        if (remoteExecutedOwner isNotEqualTo 0) exitWith {
            diag_log "[maldenFed] reset refused -- client-originated"; };
        private _s = missionNamespace getVariable ["SRV_maldenFed", [0, -1, 0, -1, -1]];
        if ((_s param [0, 0]) isEqualTo 0) exitWith {};   // already secure

        [] call APS_fnc_fedLockdown;

        // un-looted payout goes with it
        private _killed = 0;
        {
            if ((_x getVariable ["owner", ""]) in ["fed_gold", "fed_component", "alamo_gold"]) then {
                deleteVehicle _x; _killed = _killed + 1; };
        } forEach (nearestObjects [AP_FED_CENTRE, ["Land_Suitcase_F"], 400]);

        // ---- kill the siren. fn_fedAlarm creates a Sound_Alarm source and, on Altis, deleted it in the
        //      end-detector branch that this plan cut (Task 6) -- so nothing stops it any more. The alarm
        //      now publishes its handle as AP_fedAlarmSound for exactly this.
        private _siren = missionNamespace getVariable ["AP_fedAlarmSound", objNull];
        if (!isNull _siren) then { deleteVehicle _siren; };
        AP_fedAlarmSound = objNull;
        publicVariable "AP_fedAlarmSound";

        // the boat only dies if nobody ever took it: empty, and still where it was put
        private _boat = missionNamespace getVariable ["AP_fedBoat", objNull];
        private _boatGone = false;
        if (!isNull _boat) then {
            private _spawn = missionNamespace getVariable ["AP_fedBoatSpawn", [0,0,0]];
            if ((crew _boat isEqualTo []) && {((getPosATL _boat) distance2D _spawn) < 150}) then {
                deleteVehicle _boat; _boatGone = true; };
        };
        AP_fedBoat = objNull;
        publicVariable "AP_fedBoat";

        [0, -1, 0, -1, serverTime + 300] call _fnc_setState;   // TODO lengthen after testing (owner 2026-07-27)

        // ---- everything the alarm's deleted end-detector used to do, now that this is the only ending.
        //      Success is "did the vault ever open": phase 3 was reached, so gold was on the floor.
        private _success = ((_s param [0, 0]) isEqualTo 3);
        if (!isNil "AP_bank_inProgress") then { AP_bank_inProgress = false; publicVariable "AP_bank_inProgress"; };
        AP_bank_robbers = [];
        publicVariable "AP_bank_robbers";
        ["resolve", "fed", (["no", "yes"] select _success)] call APS_fnc_sportsbookResolve;   // LoonyBets
        [[[0,1,2], "The federal reserve security is no longer tracking unauthorized persons. Continue with standard duties."],
            "AP_fnc_broadcast", west, false] spawn AP_fnc_MP;
        "robberyMarker" setMarkerText "Elevated Security";
        [] spawn { uiSleep 300; deleteMarker "robberyMarker"; };
        [[[0,1,2], "The Federal Reserve has re-secured. Security is HIGH."], "AP_fnc_broadcast", -2, false] spawn AP_fnc_MP;
        diag_log format ["[maldenFed] RESET (%1) -- %2 case(s) removed, boat removed: %3", _arg, _killed, _boatGone];
        ["-FED-", objNull, format ["Reserve reset (%1)", _arg]] call APS_fnc_logIt;
    };
```

- [ ] **Step 2: Add the sweep**

In `case "boot"`, after the lockdown call:

```sqf
        // ---- THE FAILURE CONDITION. Two consecutive empty sweeps, 30 s apart, end the heist. One is
        //      not enough: a wipe or a thirty-second retreat to the treeline would otherwise close a
        //      job the crew is still fighting for.
        [] spawn {
            private _empty = 0;
            while { true } do {
                uiSleep 30;
                private _phase = (missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0];
                if (_phase isEqualTo 0) then { _empty = 0; } else {
                    private _inside = {
                        (side _x isEqualTo civilian)
                        && {alive _x}
                        && {isPlayer _x}
                        && {!(_x getVariable ["AP_restrained", false])}
                        && {(_x distance AP_FED_CENTRE) < 200}
                    } count allPlayers;
                    if (_inside isEqualTo 0) then {
                        _empty = _empty + 1;
                        diag_log format ["[maldenFed] compound empty (%1/2)", _empty];
                        if (_empty >= 2) then { _empty = 0; ["reset", "compound empty"] call APS_fnc_maldenFedSRV; };
                    } else { _empty = 0; };
                };
            };
        };
```

- [ ] **Step 3: File the two follow-ups**

Append to `TODO.md`:

```markdown
## Malden Federal Reserve (built 2026-07-27, see maldenfed.md)

- **Lengthen the HIGH SECURITY lockout.** It is 300 s in `APS_fnc_maldenFedSRV` case `"reset"`, chosen
  so testing does not spend its life waiting. Owner's call on the real number once the heist has been
  played through a few times.
- **Restore the cop requirement.** `fn_fedAlarm`'s tenured-cop gate is `< 0` for Malden testing; the
  public-launch value is `< 6` and is in the comment beside it.
- **MaxTac has no Malden spawn table.** `AP_fnc_maxtacDispatch` switches on `worldName` and only carries
  Altis and Australia, so the Reserve never calls MaxTac here.
```

- [ ] **Step 4: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenFedSRV.sqf
```

In game: run the heist to phase 3, leave un-looted cases on the ground, leave the boat un-driven, and walk everyone out past 200 m. Within ~60 s:

```bash
grep -n 'compound empty\|maldenFed\] RESET' /home/timb/arma3server_dev/loonydev.log
```

Expected: `compound empty (1/2)`, `compound empty (2/2)`, then `RESET (compound empty) -- N case(s) removed, boat removed: true`.

Then confirm: every anchor is locked again, the gate refuses the breach for five minutes with the "Security is high" message, and after five minutes it works again.

Re-run once with a crew member sitting in the boat 300 m offshore: the reset must **not** delete it.

- [ ] **Step 5: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenFedSRV.sqf TODO.md
git commit   # subject: "End the Reserve heist when the compound empties, and put it into HIGH SECURITY"
```

---

### Task 13: Cop counterplay — Secure the Reserve

**Files:**
- Modify: `server/AP_server/core/TON/fn_maldenFedSRV.sqf` (`"secure"` mode)
- Modify: `mission/Armapunk2035.Malden/core/fn_setupActions.sqf` (cop section, beside the existing "Unlock Reserve Gate" entry ~line 923)

**Interfaces:**
- Consumes: `"reset"` (Task 12).
- Produces: `["secure"] call APS_fnc_maldenFedSRV` — a `west` caller within 50 m ends the heist immediately when no robbers are inside.

- [ ] **Step 1: Add the server mode**

In `fn_maldenFedSRV.sqf`, before `default`:

```sqf
    case "secure": {
        // Cop-side. Deliberately NOT routed through _fnc_caller, which demands a civilian.
        // NOTE the shape: a flat _bad flag, never a nested exitWith. An exitWith inside a then{} only
        // leaves the then-block, so the rest of the case would run anyway -- the exact footgun called
        // out in fn_fedAlarm and fn_bankDrillVault, where it once let understaffed robberies start.
        private _src = remoteExecutedOwner;
        private _cop = if (_src isEqualTo 0) then { objNull }
                       else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
        private _bad = (_src isNotEqualTo 0)
            && {isNull _cop || {!alive _cop} || {side _cop isNotEqualTo west} || {(_cop distance AP_FED_CENTRE) > 50}};
        if (_bad) exitWith {
            ["-SEC-", _cop, "BLOCKED maldenFedSRV secure (not a cop on site)"] call APS_fnc_logIt; };
        if (((missionNamespace getVariable ["SRV_maldenFed", [0]]) param [0, 0]) isEqualTo 0) exitWith {};

        // The whole point is that it cannot cut a live fight short: robbers on site means no.
        private _inside = {
            (side _x isEqualTo civilian) && {alive _x} && {isPlayer _x}
            && {!(_x getVariable ["AP_restrained", false])}
            && {(_x distance AP_FED_CENTRE) < 200}
        } count allPlayers;
        if (_inside > 0) exitWith {
            [[2, format ["There are still %1 suspect(s) inside the Reserve.", _inside]], "AP_fnc_broadcast", _cop, false] spawn AP_fnc_MP; };

        // The reset is key-guarded (see "Guarding the server-internal modes"): key in slot 2, reason
        // in slot 3. Without the key this call is refused and the cop action silently does nothing.
        ["reset", (missionNamespace getVariable ["AP_fedInternalKey", ""]), "secured by MaxSec"] call APS_fnc_maldenFedSRV;
    };
```

- [ ] **Step 2: Add the cop scroll action**

In `fn_setupActions.sqf`, in the cop block beside the `Unlock Reserve Gate` entry (~line 923):

```sqf
            AP_actions pushBack(_plb_obj addAction ["<t color='#3B7BFF'>Secure the Reserve</t>",{[["secure"], "APS_fnc_maldenFedSRV", 2] spawn AP_fnc_MP;},"",0,false,false,"",'(playerSide isEqualTo west) && ((player distance (missionNamespace getVariable [ "AP_FED_CENTRE", [ 0, 0, 0 ] ] )) <= 50) && (((missionNamespace getVariable [ "SRV_maldenFed", [ 0 ] ] ) param [ 0, 0 ] ) > 0) && (!AP_action_in_use) && (isNull objectParent player)',6]);
```

- [ ] **Step 3: Balance-check, deploy, test in game**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_maldenFedSRV.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
```

In game, as a cop with the heist live: with a robber inside, the action refuses and says how many are still there. With the compound clear, it resets immediately — no 60-second wait.

```bash
grep -n 'RESET (secured by MaxSec)\|BLOCKED maldenFedSRV secure' /home/timb/arma3server_dev/loonydev.log
```

Also try it from a **civilian** debug console: refused, and logged.

- [ ] **Step 4: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/TON/fn_maldenFedSRV.sqf mission/Armapunk2035.Malden/core/fn_setupActions.sqf
git commit   # subject: "Let MaxSec secure the Reserve once the ground is clear"
```

---

### Task 14: `!srv resetfed`, and the full run-through

**Files:**
- Modify: `server/AP_server/core/system/fn_resetFed.sqf`

**Interfaces:**
- Consumes: everything.
- Produces: `call APS_fnc_resetFed` clears the Malden state as well as the legacy bank/fed variables.

- [ ] **Step 1: Extend the admin reset**

In `server/AP_server/core/system/fn_resetFed.sqf`, before its existing `[] call APS_fnc_fedLockdown;` line:

```sqf
// Malden Federal Reserve: clear the phase, both clocks and the HIGH SECURITY lockout. Goes through the
// heist's own reset so the un-looted gold and an un-driven getaway boat are cleaned up too, rather than
// being left behind for the next run to inherit.
if (!isNil "SRV_maldenFed") then {
    // Key in slot 2, reason in slot 3 -- the reset is key-guarded and refuses an unkeyed call.
    ["reset", (missionNamespace getVariable ["AP_fedInternalKey", ""]), "admin resetfed"] call APS_fnc_maldenFedSRV;
    // The reset deliberately arms the HIGH SECURITY lockout; an admin clearing the Fed by hand wants
    // to retry NOW, so clear that one slot afterwards. Do NOT re-assign the whole array -- the reset
    // has just set the phase and the shim through the state helper, and a blanket overwrite here would
    // silently undo both. This is the same bounded, cooldown-slot-only write FED OVERRIDE makes.
    SRV_maldenFed set [4, -1];
    publicVariable "SRV_maldenFed";
};
```

- [ ] **Step 1b: Teach FED OVERRIDE about the new lockout**

**Found by Task 5's review; nothing in the spec knew this existed.** `AP_fedOverride` is the owner's
"Fed Control" toggle — persisted in `server_control.fedoverride`, so it survives reboots — and while it
is on, a 4-second scheduled task (`"fedOverrideClear"`, registered at `server/AP_server/init.sqf`
~:632) keeps every heist's **cooldown timestamp** cleared so heists can be run back to back. It zeroes
`SRV_lastRobbery`, `AP_fed_robbed[1]`, `AP_bank_robbed[1]` and `SRV_loonyBinData[0]`, and
deliberately never touches an active-robbery flag.

It cannot see this event's lockout, which lives in `SRV_maldenFed` slot 4. So with the override **on**
— the state the owner is most likely to be in while testing this — the Malden Fed would still refuse
for five minutes after every reset, and the toggle would look broken.

In `server/AP_server/init.sqf`, inside the `"fedOverrideClear"` scheduled block, beside the existing
timestamp clears:

```sqf
        // The Malden Fed's HIGH SECURITY lockout is slot 4 of its own state array, not a AP_*_robbed
        // timestamp, so the clears above cannot reach it. Same rule as the others: cooldown only, never
        // the phase -- slot 0 is left exactly as it is, so an in-progress robbery is untouched.
        if (!isNil "SRV_maldenFed" && {(SRV_maldenFed param [4, -1]) != -1}) then {
            SRV_maldenFed set [4, -1]; publicVariable "SRV_maldenFed"; };
```

This is the one place in the plan that writes `SRV_maldenFed` outside `_fnc_setState`, and it is
deliberate: it mirrors the existing override's own idiom for the four state arrays it already clears,
and touching only the cooldown slot is what makes it safe. Note it in the commit body.

- [ ] **Step 2: Balance-check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/system/fn_resetFed.sqf server/AP_server/init.sqf
```

- [ ] **Step 3: Run the whole spec's test plan**

Deploy, then execute `maldenfed.md` §9 steps 1-9 end to end in one sitting. Every step must pass. Write the result — including anything that did not — into the commit body.

- [ ] **Step 4: Full-tree balance check**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py $(git diff --name-only HEAD~13 HEAD | grep -E '\.(sqf|hpp|h)$') | grep -v '^ok'; echo "exit=$?"
```

Expected: no output above the `ok` lines.

- [ ] **Step 5: Verify the client functions actually compile**

A syntax fault in a client `.sqf` shows up only as a player's entire scroll menu silently vanishing — the dedicated server never compiles those files. Add a temporary probe to `initServer.sqf`:

```sqf
// TEMPORARY PARSE PROBE -- remove before the next deploy. compile PARSES without running.
{
    private _ok = true;
    try { private _c = compile preprocessFileLineNumbers _x; } catch { _ok = false; };
    diag_log format ["[maldenFed] parse %1 : %2", _x, ["FAILED", "ok"] select _ok];
} forEach ["core\actions\fn_openGate.sqf", "core\actions\fn_openVault.sqf",
           "core\actions\fn_openSafe.sqf", "core\actions\fn_alamoFed.sqf",
           "core\fn_setupActions.sqf", "dialog\function\fn_handleMessage.sqf"];
```

Deploy, confirm six `ok` lines, then **delete the probe** and deploy once more.

```bash
grep -n 'maldenFed\] parse' /home/timb/arma3server_dev/loonydev.log
```

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add server/AP_server/core/system/fn_resetFed.sqf mission/Armapunk2035.Malden/initServer.sqf
git commit   # subject: "Make !srv resetfed clear the Malden Reserve too"; body carries the full run-through result
```

---

## Deferred, deliberately

These are in `TODO.md` and are **not** part of this plan:

- Lengthening the 300-second HIGH SECURITY lockout once the heist has been played.
- Restoring the cop requirement from 0 to 6 before public launch.
- A Malden MaxTac spawn table for `AP_fnc_maxtacDispatch`.
- A place on Malden to sell `goldbar` — `fn_mapData` still carries Altis dealer coordinates. This is the map-data pass, not this feature, but until it lands the payout has nowhere to go.
