# LooneyBin Deploy Runbook (`update.md`)

Canonical process to ship code to the LIVE server: **stage → version/PBO bump → patch notes → guard → warned restart → verify → migrations**. Keep this current; it exists so the process isn't re-learned every time.

## Environment (the boxes)

| What | Where |
|---|---|
| LIVE server | **10.1.24.96** — `ssh -i ~/.ssh/id_lb timb@10.1.24.96` (fallback pw: see local notes, NOT in git). Shell is **fish** → always `ssh ... 'bash -s' <<'EOF'`. |
| LIVE deploy source | `~/Documents/LooneyBin Altis Life` on .96 (a git checkout on `main` BUT **460+ dirty on-box files** — obfuscation + on-box-only content). **NEVER `git pull`/`reset`/`checkout` here.** Edit in place / push individual files. **NEVER pack from git.** |
| DEV / git | **10.1.24.221** (this box) `~/loonybin-doomba` (branch `doomba`). `gh` token works here (account `tabiznet`); pushes = https + token only. |
| Live DB | docker `looneybin-db`, schema `looneybin` (dev = `looneybin_test`). `docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin -e "..."` — in an ssh heredoc add `</dev/null`. |
| `$A3SRV` | `$HOME/.local/share/Steam/steamapps/common/Arma 3 Server` on .96. Live mission PBO = `$A3SRV/mpmissions/Loonybin_bNNNN.Altis.pbo`; server = `$A3SRV/@AP_server/addons/AP_server.pbo`. (NOT `~/arma3server`.) |
| Watchdog | `deploy/restart_watchdog.sh` on .96 (`pgrep -af restart_watchdog` — must be ALIVE or flags do nothing). Executes the deploy when server_control flips. |

## Step 1 — STAGE code onto .96 `~/Documents`

Surgical, preserving on-box divergence. From .221 git:
- **New / clean-base files**: `git archive <mainSHA> -- <paths> | ssh ... "tar -x -C '/home/timb/Documents/LooneyBin Altis Life'"`. A file is "clean-base" if its live md5 == the git pre-change md5 (then a wholesale overwrite is exact).
- **Divergent files** (registries, minified configs, big action files): fetch the live copy, `patch --fuzz=3` or Edit the specific hunks, push back. md5-verify both ends.
- Always brace/bracket-balance check edited `.sqf`/`.hpp`/`.cpp` (`tr -cd '{'|wc -c` vs `}`): a mismatch = mission won't load = outage.

## Step 2 — VERSION + PBO bump (4 spots, on .96)

- `mission/LooneyBin.Altis/version.hpp` → `AP_VERSION_STR "Beta X.Y.Z"` (one `sed 's/Beta 0\.1\.NN/Beta 0.1.MM/'` also catches AP_ONLOAD_NAME/MISSION)
- `mission/LooneyBin.Altis/core/configuration.sqf` → `AP_version = "Beta X.Y.Z";`
- `deploy/run-boot2.sh` → the `pack_pbo.py ... Loonybin_bNNNN.Altis.pbo` line
- `deploy/server.cfg` → `template = "Loonybin_bNNNN.Altis";`

**Rule:** `Z` bumps EVERY deploy. `Y` = content bump, OWNER-EXPLICIT ONLY. PBO `bNNNN` increments every deploy (fresh client cache slot).

## Step 3 — PATCH NOTES

Write `deploy/patchnote_override.txt`. `gen_patchnotes.py` runs automatically inside `run-boot2.sh` on every pack: it posts the override **verbatim** to the patch-notes channel, substitutes `{version}`, then deletes the override (one-shot). Rules:
- `{version}` placeholder; keep **< 2000 chars** post-substitution (Discord limit — check `sed 's/{version}/Beta 0.1.MM/' file | wc -c`).
- Player-facing only: NO admin/foreign-server/CfgRE mentions; no `@everyone` unless asked.
- No override → it posts BUGS.md `(reboot pending` entries, or "maintenance update — no player-facing changes".

## Step 4 — GUARD (pre-flight, must pass)

```
python3 deploy/predeploy_guard.py "$PROJ/mission/LooneyBin.Altis" "$A3SRV/mpmissions/Loonybin_b<LIVE>.Altis.pbo"
```
Must print `[guard] OK` (RC 0). Blocks when the source is *behind* the live PBO (core files shrank/vanished). Override only with `DEPLOY_GUARD_OVERRIDE=1` after reconciling.

## Step 5 — DEPLOY (warned restart)

```
setsid python3 deploy/scheduled_restart.py HH:MM "<label>" > /tmp/lb_sched.log 2>&1 < /dev/null &
```
`HH:MM` = now + warning minutes (`date -d '+3 minutes' +%H:%M`). It warns players via **BE RCON** (creds `deploy/battleye/beserver_x64.cfg`, port 2310) + Discord countdown, then at T-0 sets `server_control.restart_now=1, hard_pending=1`.

The watchdog then runs `FORCE_DEPLOY=1 run-boot2.sh` → **FORCE_DEPLOY sets FREEZE=0**, punching through the nightly **22:00–09:00 deploy freeze** → guard → `pack_pbo` mission (`Loonybin_bNNNN`) + `pack_pbo` server (`AP_server.pbo`) → relaunch arma → `gen_patchnotes` posts.

- `scheduled_restart.py`'s stdout is block-buffered under `setsid` (log looks empty — normal; it's still running: `pgrep -af scheduled_restart`).
- STAGE-ONLY when players are on unless the owner OKs the restart. Staged source during the freeze does NOT deploy on a *natural* restart (FREEZE=1 skips repack) — only FORCE_DEPLOY ships it.

## Step 6 — VERIFY

- `/tmp/lb_boot.log`: `[guard] OK`, both `pack_pbo ... bytes` lines (mission + AP_server), `[gen_patchnotes] ... override posted`.
- New `Loonybin_bNNNN.Altis.pbo` on disk, old one gone.
- `console.log`: `::LooneyBin Server:: READY`, `extDB3: Connected`, 0 `Error in expression`/`Undefined variable`.
- New `arma3server_x64` pid (relaunched), stable uptime.
- **Fix landed in the PBO**: PBOs pack with `0 LZSS` (uncompressed) → `grep -c '<fix string>' <pbo>` works. Watch for the same string appearing in unrelated files (grep the specific file/composition to be sure).

## Step 7 — DB MIGRATIONS (if any)

Backup first: `docker exec -i looneybin-db mariadb-dump -ulooneybin -plooneybin looneybin players houses | gzip > deploy/backups/db_pre_<tag>.sql.gz`. Run migrations AFTER the server is back on the new PBO (removed items are already invalid → no re-add race). Migration scripts use `docker exec looneybin-db mariadb ... <schema>`; dry-run (no `--apply`) writes a preview `.sql` first.

## Gotchas that have bitten us

- **Watchdog env poisoning (bit us 2026-07-23):** the power-loss recovery unit starts the server via
  `NO_REPACK=1 run-boot2.sh`; if the watchdog isn't running, run-boot2 auto-starts it and the watchdog
  **inherits `NO_REPACK=1` forever** — then every UPDATE deploy it launches carries FORCE_DEPLOY=1 *and*
  NO_REPACK=1, and "NO_REPACK wins last" silently freezes the repack (server restarts on the OLD PBO; the
  only tell is `*** DEPLOY FROZEN ***` in `/tmp/lb_boot.log` with a fresh timestamp). Fixed by pinning BOTH
  vars on the watchdog launch lines (`NO_REPACK=0 FORCE_DEPLOY=1 …` / `FORCE_DEPLOY=0 NO_REPACK=1 …`). If a
  deploy "succeeds" but the bNNNN PBO never appears: `tr '\0' '\n' </proc/$(pgrep -f restart_watchdog)/environ | grep -E 'NO_REPACK|FORCE_DEPLOY'`.
- **In-boot predeploy guard is a no-op**: its glob targets the NEW `Loonybin_bNNNN*` (sed-bumped each
  deploy), which doesn't exist until after the pack → `_gpbo` empty → guard skipped every time. The manual
  Step-4 guard run is the only one that actually checks anything.
- **`deploy/.deploy_freeze`** = manual hold; FORCE_DEPLOY still punches through it — check for the file and
  read its note before any deploy, and get owner OK before `rm`.
- **scp SFTP mode does NOT expand `$HOME`/`~`** → use absolute `/home/timb/...` remote paths.
- **background monitor loops**: a trailing `[ "$X" = 0 ] && echo ...` returns 1 → the task reports "failed". End the script with `exit 0`.
- **Minified files** (`configuration.sqf`): a hand-merge must `diff` the WHOLE file for ALL changed line numbers, not just the one you expect (missing `AP_furnitureItems` on line 87 cost a hotfix).
- **`[] spawn {}` in SRV functions** does NOT inherit the file's `private` helpers → pass them in (`[_fn] spawn { params ["_fn"]; ... }`). A bare spawn calling `_spawnRig` made every placed rig vanish on restart.
- **DEV (doomba) can hold fixes that never reached `main`** → deploying from main ships stale/broken code. Sync doomba↔main (see the standing rule) and check doomba's working-tree for post-merge fixes before deploying a feature.

## Power-loss auto-recovery (added 2026-07-22)
User unit `loonybin-arma.service` on .96 (`~/.config/systemd/user/`, linger on) starts the live server at
boot via `NO_REPACK=1 run-boot2.sh` — freeze relaunch of the already-deployed PBOs, so an unattended boot can
NEVER ship staged source. Guards: aborts if the server is already running (accidental `systemctl --user start`
cannot bounce a live session — tested); waits up to 120s for the DB container (docker `unless-stopped`).
`Restart=no` on purpose: after boot, restarts/deploys belong to restart_watchdog exactly as before. The other
half of recovery was already systemd (stats site, tunnel, loonybot, loonyhc, loonybones, mariadb container).

## Game-version update (Arma build, NOT a mission deploy) — proven 2026-08-27

Players "Session Lost / Verifying PBO failed (enoch\addons\ui_f_enoch.pbo)" =
CLIENTS updated on Steam, the server's BASE DATA is stale. The version STRING
matching proves nothing -- 2.22.153995 vs .154045 was invisible until boot.

steamcmd on .96 stalls on this: `app_update 233780` says "already up to date"
against its cached appinfo, and with `+app_info_update 1` in-session it goes
"Timed out waiting for update to start, bailing" then LIES "Success! fully
installed". Hours of retries did not clear it.

**The path that works: rsync the base data from THIS box.** Samurai's Steam
client auto-updates `.local/share/Steam/steamapps/common/Arma 3 Server`
(manifest appmanifest_233780.acf tracks the real build). Confirm samurai is
newer (md5 the complained-about pbo both ends), then per BI-owned dir:

    for d in addons aow argo curator dta enoch expansion heli jets kart mark orange tacops tank linux64; do
        rsync -a --delete -e "ssh -i ~/.ssh/id_lb" "./$d/" "timb@10.1.24.96:.local/.../Arma 3 Server/$d/"
    done
    # + binaries (arma3server, arma3server_x64, lib*.so, steamclient.so) and keys/a3.bikey (NO --delete on keys/)

--delete INSIDE those dirs only (stale .bisign files are exactly what fails
verify); never at the install root -- @mods, mpmissions, cfgs, extDB3 live there.
**rvMain (2026-09-02):** Arma 3 2.22+ renames the server process to `rvMain`, so `pkill -x arma3server_x64` / `pgrep -x arma3server_x64` match NOTHING (silent no-op -> zombie servers on random ports + OOM storm, 3 weeks). Kill/guard by CMDLINE only: `pkill -f '[a]rma3server_x64 -config=server.cfg'` (bracket = no self-match, `-config=` skips the `-client` HC), then verify with `pgrep`. Healthy signature: `restart_log` = 6 rows/day.

Then pkill the server and `systemctl --user start loonybin-arma` (separate ssh
invocations -- a pkill and a start in one heredoc raced once).

Also seen that day: FIVE stacked arma3server processes (the oldest weeks old,
holding UDP 2302) + two watchdogs -- kill ALL of them before relaunching, or
the ghost keeps the port and the fresh boot cannot bind.
