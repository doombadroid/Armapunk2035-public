# Armapunk 2035 → 10.1.24.96 Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, with owner checkpoints at every ⛔ gate) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is an OPS plan: "tests" are observable states on a real box, named per step.

**Goal:** Make 10.1.24.96 the live Armapunk 2035 server, with the LooneyBin player database carried into Armapunk's PostgreSQL, and LooneyBin fully retired from that box.

**Architecture:** Same stack as the dev box, translated to systemd: docker `armapunk-pg` (PostGIS 18) on loopback → `pysqfd` user service (DB transport + UI page serving over a pinned unix socket) → Arma 3 2.22 dedicated server + headless client as user units → cloudflared (existing `armapunk` tunnel) fronting a mission fast-download origin. Code reaches the box by rsync from samurai; git never runs on .96. Player data arrives once, via `tools/pgmigrate` from the FINAL LooneyBin dump taken 2026-09-08 00:59 UTC.

**Tech Stack:** CachyOS/systemd (box hostname `MakeArmaNotWar`, AMD BC-250, 12 threads, 11 GiB RAM, 881 GB free), Arma 3 Server 2.22 (process comm `rvMain`), PySQF (C extension + Python 3.14.6 daemon, psycopg 3.3.4), PostgreSQL 18 / PostGIS 3.6 (`postgis/postgis:18-3.6`), Docker 29 + Compose 5, cloudflared, Node 26.

**Status legend:** ✅ done 2026-09-07 · ⛔ owner gate (do not proceed past without the owner's word) · 🔧 work · 🔎 verify

---

## 0. What already happened (2026-09-07, 19:55–20:10 CDT)

Everything below is DONE and verified. It is recorded here because the plan's starting state is this, not the state in `CLAUDE.md`/`MALDEN.md` ("the .96 box still runs LooneyBin and stays up" is no longer true).

| Item | State |
|---|---|
| LooneyBin Arma server (pid 2421049, `rvMain -config=server.cfg`) | STOPPED 19:57 CDT (= 2026-09-08 00:57 UTC). 0 players were online (last connect 10:32, server-side disconnect 11:38). No `rvMain` process, no UDP 23xx listener. |
| Headless client (`loonyhc.service`) | stopped + disabled, unit file removed |
| `loonybin-arma.service`, `loonybin-watchdog.service`, `loonybones.service` (user units) | stopped + disabled, unit files moved to `~/loonybin-decom-20260907/units/user/` |
| clankr.py, lagwatch.py, enrique.py, latoya.py, ddos_watch.sh, server_control_agent.py, run-boot2.sh | killed (TERM by explicit PID), none running |
| `loonybot.service`, `officer-maggot.service`, `missionfiles.service` (SYSTEM units, root-owned) | ✅ stopped + disabled 20:35 CDT; unit files + `/usr/local/bin/{loonybot,officer-maggot}` moved to `~/loonybin-decom-20260907/units/system/` |
| DB dump PRESTOP (server still up, `--single-transaction`) | `looneybin_PRESTOP_20260907_195527.sql.gz` 64,788,837 B, 67 tables |
| DB dump FINAL (after stop; **this is the freeze dump**) | `looneybin_FINAL_20260907_195940.sql.gz` 64,788,837 B, sha256 `ba8ce3e5…ceb03`, `-- Dump completed on 2026-09-08 0:59:48` |
| NAS copy | `/mnt/nas/Backups/loonybin-decommission-2026-09-07/` — 4.0 GB, 11 files, `sha256sum -c SHA256SUMS` = 11 OK **on the NAS side** |
| Also on NAS | deploy tree (3.0 GB, 1584 on-box-only edits) minus secrets; A3SRV LooneyBin subset (mpmissions b0118–b0189, @life_server, @lb_server, @extDB3); `~/arma3server` profiles/RPTs; home strays; unit files; grants; table inventory |
| Secrets (Discord tokens, BM token, RCON pw, `looneybin.biprivatekey`, website `.env.local`, all three cloudflared certs) | `loonybin_SECRETS_20260907_195940.tar.gz` — on .96 (`~/loonybin-decom-20260907/`) and on samurai `~/loonybin-secrets-backup/` (0700). **Deliberately NOT on the NAS** (open share; the 2026-08-18 cleanup already had to delete exposed keys from it). |
| `looneybin-db` MariaDB container + volume | **KEPT RUNNING** — the stats website (`projectloonybin.com`) reads it. Retire in §11. |
| `loonybin-stats` + `loonybin-tunnel` (projectloonybin.com), `armapunk-site` + `armapunk-tunnel` (armapunk.com) | untouched, active |
| `~/Documents/LooneyBin Altis Life` (deploy tree) | ✅ moved to `~/loonybin-decom-20260907/LooneyBin-Altis-Life/` (20:35 CDT) |
| `~/.local/share/Steam/steamapps/common/Arma 3 Server` | base install intact and **byte-identical to dev** (`dta/bin.pbo` sha256 `815b6e7466e649fc…`, 392 addons, `arma3server_x64` 41,681,008 B, Aug 27 05:23). LooneyBin parts moved to `~/loonybin-decom-20260907/A3SRV-loonybin/`. `keys/` = a3, jsrssoundmod2025, looneybin. `steam_appid.txt` = 107410. |
| Ports 2302–2306, 2310 | free; ufw ACTIVE, rules read 20:35: `22/tcp`, `2302:2306/udp`, `2310/udp`, `2312:2316/udp` (v2 dev), `2412:2414/udp`, KDE Connect — v4+v6. 8091/8092 NOT allowed (good: mission origin stays loopback-only behind the tunnel) |
| pgmigrate dry run against the FINAL dump | ran 2026-09-07 20:12 CDT on samurai, `--allow-decide --allow-undecided-policy`, **exit 2** with exactly two reconciliation failures (see §7). First time the ETL met real data. Report: `~/pgmigrate-work/decom_rehearsal/report.json`. |

Rollback of the decommission (if ever wanted): everything was moved, nothing deleted. `~/loonybin-decom-20260907/` (8.8 GB) holds units, the A3SRV subset, strays; the deploy tree is untouched; `systemctl --user enable --now` the four units after copying them back. ~15 minutes.

---

## 1. Decisions the owner must clear before execution ("read and clear")

All gates were answered by the owner on 2026-09-07 (evening); the answers are recorded inline. Execution started the same evening.

- ✅ **D0 — Finish the decommission — DONE 2026-09-07 20:35 CDT** (owner supplied sudo). Nothing LooneyBin runs on .96 except `loonybin-stats` + `loonybin-tunnel` + the MariaDB container (D9). What was run:
  ```bash
  sudo systemctl disable --now loonybot officer-maggot missionfiles
  sudo mv /etc/systemd/system/{loonybot,officer-maggot,missionfiles}.service ~/loonybin-decom-20260907/units/system/
  sudo mv /usr/local/bin/loonybot /usr/local/bin/officer-maggot ~/loonybin-decom-20260907/units/system/
  sudo systemctl daemon-reload && systemctl list-units --all --no-legend | grep -iE 'loony|maggot|missionfiles' || echo "clean"
  mv "$HOME/Documents/LooneyBin Altis Life" ~/loonybin-decom-20260907/LooneyBin-Altis-Life
  sudo ufw status numbered
  ```
  Result: `clean (system)` apart from stats+tunnel, `clean (user)`, zero LooneyBin processes; ufw listing recorded in §0.
- ✅ **D1 — Freeze** (recorded in `rules.FREEZE`, 2026-09-07: dump 2026-09-08T00:59:40Z, maintenance window, announced 2026-09-07). Proposed answer (a fact now, not a choice): `Freeze(dump_taken_utc="2026-09-08T00:59:40Z", maintenance_window=True, announced_on=<date you post it>)`. Players who played LooneyBin after 00:57 UTC 2026-09-08 lost nothing (nobody was online). Post the announcement; that date is `announced_on`.
- ✅ **D2** (owner: "good as designed") **— Live DB name = `armapunk`**, freshly created on .96 (dev keeps `pgm_full_scratch`; `rename-dev-db.sh` is not run). Password: new, generated on .96, lives only in `~/.config/armapunk/pysqfd.env`, `~/.pysqf_dsn` and `deploy/postgres/.env` there.
- ✅ **D3** (owner: "make sure git is synced before the transfer" → `push-96.sh` refuses a dirty tree; main pushed to origin before the first mirror) **— Code transport = rsync mirror from samurai** (`deploy/push-96.sh`, §6). No git on .96 (it cannot fetch the private repo, and the "never checkout on the live box" rule stands). Provenance = `DEPLOYED_COMMIT` file written by the push.
- ✅ **D4** (owner: good) **— Ports** stay LooneyBin's: 2302 game / 2303 query / 2304 master / 2306 aux / 2310 BE RCON; mission HTTP origin 8092 loopback behind the tunnel.
- ✅ **D5** (owner 2026-09-07: "set to 0 for now but literally remind me daily that that needs to be changed — armapunk addon needs work and publishing") **— `verifySignatures=0`, `BattlEye=1`** (log-only filters). `maldenradio.bikey` is already in `keys/` for the day it flips to 2. **Daily reminder = `armapunk-d5-reminder.timer` on .96 (09:00 CDT)**, one Discord REST post to the admin channel pinging the owner, credentials in `~/.config/armapunk/discord.env` (no bot process). Retire with `systemctl --user disable --now armapunk-d5-reminder.timer` when verifySignatures=2 ships. Also pinned at the top of the memory index.
- ✅ **D6** (owner: "use the armapunk domain") **— `missions.armapunk.com`** live 2026-09-07 21:00 (CNAME routed with `--origincert cert-armapunk.pem`, HTTP 200 through the tunnel) on the existing `armapunk` tunnel (account B, `--origincert cert-armapunk.pem`). Alternative: reuse `missions.projectloonybin.com` (account A, already points at 8091).
- ✅ **D7** (owner: "go with your suggestion") **— Map content sync dev→live.** The map lives in `map_objects` (10,009 rows on dev), not in the PBO. Proposed rule: **map is edited on dev only**; every push that changes the map replaces live's `map_objects`/`map_meta`/`map_edit_log`/`faction_territory` wholesale (§6 step 7). Live's in-game F12 editor stays available to the owner but its edits are overwritten by the next map push unless pulled back to dev first. Alternative: disable F12 on live.
- ✅ **D8** (owner: confirmed; applied in commit 5bea9ebc — `AP_devAutoAdmin=false`, Loony Bin cops 0→2, Fed 0→6, bank 0→4, client createUnit/createAgent re-blocked; `AP_betaMaxStats`/`SRV_grantNewbieRoles` were already off; `!pos` already gone; CfgRE hardening §3 stays deferred to PUBLIC open) **— `launch.md` UNDO checklist** (god-stats 1B, `AP_devAutoAdmin`, `SRV_grantNewbieRoles`, cop requirements 0, `!pos`, CfgDisabledCommands) must be executed before the first non-owner player connects (§9). Confirm the list or strike items.
- ✅ **D9** (owner: "both shut down") — done 21:03: `loonybin-stats` disabled, `looneybin-db` stopped (`--restart=no`, volume kept), `projectloonybin.com` → 404. **Exception: `loonybin-tunnel` stays up for ONE hostname, `radio.projectloonybin.com`**, because the client addon has that host compiled in (`radio/extension/src/state.rs`); it moves to `radio.armapunk.com` when the addon is rebuilt (rides the D5 reminder). **— What stays running from LooneyBin:** `projectloonybin.com` stats site + its MariaDB until the website's PG port lands (§11), or shut both now. The `web_*` tables (tickets, wiki, votes, changelogs) are DROPPED by pgmigrate policy — they only survive on MariaDB.
- ✅ **D10** (owner: "no bots") **— Discord bots: none at go-live.** All of `loonybot/` is pymysql→3306; porting is §11. Confirm no bot is required for opening.
- ✅ **D11** (owner: "do it") — LIVE 21:10: no Arch packages exist for icecast/liquidsoap (deb-only upstream), so the dev-tested docker pair runs on .96 (`radio/docker-compose.live.yml`, loopback :8000, music in `~/radio-music`), five mounts 200 audio/mpeg externally via `radio.projectloonybin.com` **— Radio** (`radio/INSTALL-96.md`, needs `paru`/AUR + root): after go-live, §11.
- ✅ **D12** (owner: hostname `Armapunk 2035 [COMING SOON]`, join password set — lives in `deploy/secrets.env` on .96 as `AP_JOIN_PW`, never in git) **— Opening date/time** and whether a closed test (owner + testers, `password` set) precedes public.

---

## Global Constraints (repo rules that bind every task)

- `.96` shell is **fish** → every remote script is `ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF' … EOF`. `docker exec -i` inside such a heredoc eats the rest of the heredoc → never `-i`, or append `</dev/null`.
- Kill the server by cmdline `pkill -f '[a]rma3server_x64 -config=server.cfg'` (bracket = no self-match). **Never** `pkill -x rvMain` / `pgrep -f` without the bracket.
- `PYSQF_SOCKET` must be byte-identical in the daemon's env and the server launcher (2026-08-21 incident). Pinned here to `/run/user/1000/pysqf.sock` (uid on .96 = 1000, linger = yes).
- Mission PBO and `@AP_server` addon are **one deployable unit** — never from different commits (HANDOFF.md).
- `steam_appid.txt` stays `107410`.
- Deploy freeze 22:00–09:00 local and "stage only, owner triggers restarts" return the moment players are on (CLAUDE.md). PR discipline returns with them.
- `mission.sqm` is plain text; never binarize; never sweep the word "Malden".
- Versioning once live: `Beta X.Y.Z`, bump `Z` every push; PBO `Armapunk2035_bNNNN.Malden`. Live build counter starts at **b2001** so it can never collide with dev (dev is at b1011).
- No secret in git: `deploy/secrets.env`, `deploy/postgres/.env`, `*.biprivatekey`, `~/.pysqf_dsn` are all gitignored/outside; the push script excludes them.
- Never name other Arma servers in tracked files; no `@everyone`.

---

## 2. Phase A — Box prerequisites 🔧

**Files:** none in repo. Box: `~/PySQF/`, `~/pysqf-venv/`, `~/Armapunk2035/`, `~/.config/armapunk/`.

- [ ] **Step 1: Confirm toolchain on .96** (all already present — this is the check):
  ```bash
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  python3 --version; gcc --version | head -1; make --version | head -1; docker compose version; loginctl show-user timb -p Linger --value; id -u
  EOF
  ```
  Expected: `Python 3.14.6`, `gcc (GCC) 16.1.1`, `GNU Make 4.4.1`, `Docker Compose version 5.1.4`, `yes`, `1000`.
- [ ] **Step 2: Copy PySQF source and build the extension ON the box** (glibc differs from Gentoo; never copy the `.so`):
  ```bash
  rsync -az --exclude=build --exclude=__pycache__ -e 'ssh -i ~/.ssh/id_lb' ~/PySQF/ timb@10.1.24.96:PySQF/
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  cd ~/PySQF && make 2>&1 | tail -3 && ls -la build/ipc-release/pysqf_x64.so
  python3 -m venv ~/pysqf-venv && ~/pysqf-venv/bin/pip install -q 'psycopg[binary]==3.3.4' && ~/pysqf-venv/bin/python -c 'import psycopg; print(psycopg.__version__)'
  EOF
  ```
  Expected: `pysqf_x64.so` exists (≈52 KB on dev), `3.3.4`. 🔎 red state if `make` fails: `-Werror` is mandatory — fix the warning, do not relax the flag.
- [ ] **Step 3: First code mirror** (repo minus the big/irrelevant trees; 5.5 GB total on dev, most of it `textures_png/`):
  ```bash
  cd ~/Armapunk2035 && git rev-parse HEAD > DEPLOYED_COMMIT
  rsync -az --info=stats1 -e 'ssh -i ~/.ssh/id_lb' \
    --exclude='.git/' --exclude='scratchpad/' --exclude='textures_png/' --exclude='website/node_modules/' --exclude='website/.next/' \
    --exclude='radio/dist/@Armapunk2035/addons/' --exclude='loonybot/venv/' --exclude='__pycache__/' \
    --exclude='deploy/postgres/.env' --exclude='deploy/secrets.env' --exclude='*.biprivatekey' \
    ~/Armapunk2035/ timb@10.1.24.96:Armapunk2035/
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'du -sh ~/Armapunk2035; ls ~/Armapunk2035/mission/Armapunk2035.Malden/mission.sqm ~/Armapunk2035/server/AP_server/config.cpp ~/Armapunk2035/tools/pysqf_modules/apdb.py'
  ```
  Expected: three paths listed; size well under 1 GB. (`DEPLOYED_COMMIT` is untracked — add it to `.gitignore` in §6.)

## 3. Phase B — PostgreSQL 🔧 (gate: D2)

- [ ] **Step 1: Create `deploy/postgres/.env` on .96 with a generated password** (never on samurai, never in git):
  ```bash
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  mkdir -p ~/Armapunk2035/deploy/postgres/initdb ~/.config/armapunk
  PW=$(openssl rand -hex 20)
  printf 'PGDATABASE=armapunk\nPGUSER=armapunk\nPGPASSWORD=%s\n' "$PW" > ~/Armapunk2035/deploy/postgres/.env; chmod 600 ~/Armapunk2035/deploy/postgres/.env
  printf 'host=127.0.0.1 port=5432 dbname=armapunk user=armapunk password=%s\n' "$PW" > ~/.pysqf_dsn; chmod 600 ~/.pysqf_dsn
  echo ok
  EOF
  ```
- [ ] **Step 2: Production compose override** — create `deploy/postgres/compose.live.yml` in the repo (committed; no secrets):
  ```yaml
  # Live overrides for compose.yml on .96: quiet logs, same image/volume/ports.
  # Use: docker compose -f compose.yml -f compose.live.yml up -d
  services:
    postgres:
      command:
        - postgres
        - -c
        - shared_buffers=512MB
        - -c
        - work_mem=16MB
        - -c
        - max_connections=50
        - -c
        - log_min_duration_statement=500
        - -c
        - timezone=UTC
  ```
  (`log_statement=all` from the dev file is dropped — "deafening in production" per `deploy/postgres/README.md`.)
- [ ] **Step 3: Start it**
  ```bash
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  cd ~/Armapunk2035/deploy/postgres && set -a && . ./.env && set +a
  docker compose -p armapunk-live -f compose.yml -f compose.live.yml up -d
  sleep 15; docker ps --format '{{.Names}} {{.Status}}' | grep armapunk-pg
  docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "select version()" | cut -c1-40
  docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "create extension if not exists postgis; select postgis_version()"
  EOF
  ```
  Expected: `armapunk-pg Up … (healthy)`, `PostgreSQL 18.6`, `3.6 …`. Port 5432 is loopback-only (compose binds `127.0.0.1:5432`).
  🔎 red state: `docker compose` refuses with `set PGPASSWORD` → `.env` was not sourced (fish vs bash — the heredoc is bash, keep it that way).

## 4. Phase C — pysqfd as a systemd user service 🔧

**Files (repo, committed):** `deploy/systemd/armapunk-pysqfd.service`, `deploy/systemd/pysqfd.env.example`. **Box:** `~/.config/systemd/user/armapunk-pysqfd.service`, `~/.config/armapunk/pysqfd.env` (0600).

- [ ] **Step 1: Write the unit** (`deploy/systemd/armapunk-pysqfd.service`):
  ```ini
  [Unit]
  Description=Armapunk 2035 PySQF daemon (PostgreSQL transport + UI page serving)
  Documentation=file:///home/timb/Armapunk2035/deploy/openrc/pysqfd
  After=network-online.target

  [Service]
  Type=simple
  WorkingDirectory=/home/timb/PySQF/python
  EnvironmentFile=/home/timb/.config/armapunk/pysqfd.env
  ExecStartPre=/usr/bin/timeout 120 /bin/bash -c 'until (echo > /dev/tcp/127.0.0.1/5432) 2>/dev/null; do sleep 2; done'
  ExecStart=/home/timb/pysqf-venv/bin/python pysqfd.py --modules pysqf.db,apdb,webpages
  Restart=always
  RestartSec=5
  StandardOutput=journal
  StandardError=journal

  [Install]
  WantedBy=default.target
  ```
- [ ] **Step 2: Write the env template** (`deploy/systemd/pysqfd.env.example`) and the real file on the box:
  ```bash
  # deploy/systemd/pysqfd.env.example -- copy to ~/.config/armapunk/pysqfd.env (chmod 600) and fill the password.
  # PYSQF_SOCKET MUST equal the value in arma3server_live/run-live.sh (2026-08-21: mismatched defaults = silent extDB3 fallback).
  PYSQF_SOCKET=/run/user/1000/pysqf.sock
  PYSQF_DB_DSN=host=127.0.0.1 port=5432 dbname=armapunk user=armapunk password=CHANGEME
  AP_DB_POSTGRES=1
  AP_WEBPAGES_ROOT=/home/timb/Armapunk2035/server/AP_server/web
  PYTHONPATH=/home/timb/PySQF/python:/home/timb/Armapunk2035/tools/pysqf_modules:/home/timb/Armapunk2035/tools/pgmigrate
  ```
  On the box: `sed "s/password=CHANGEME/password=$(sed -n 's/^PGPASSWORD=//p' ~/Armapunk2035/deploy/postgres/.env)/" ~/Armapunk2035/deploy/systemd/pysqfd.env.example > ~/.config/armapunk/pysqfd.env && chmod 600 ~/.config/armapunk/pysqfd.env`
- [ ] **Step 3: Install + start**
  ```bash
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
  mkdir -p ~/.config/systemd/user && cp ~/Armapunk2035/deploy/systemd/armapunk-pysqfd.service ~/.config/systemd/user/
  systemctl --user daemon-reload && systemctl --user enable --now armapunk-pysqfd && sleep 3
  systemctl --user is-active armapunk-pysqfd; ls -la /run/user/1000/pysqf.sock; journalctl --user -u armapunk-pysqfd -n 5 --no-pager
  EOF
  ```
  Expected: `active`, socket present (mode 0600), journal shows the modules loaded and `apdb` connected. 🔎 red state: no socket → the unit lacks `PYSQF_SOCKET` (check `systemctl --user show armapunk-pysqfd -p Environment`).

## 5. Phase D — Arma server, HC, mission download 🔧 (gates: D4 D5 D6)

**Files (repo):** `deploy/systemd/armapunk-arma.service`, `deploy/systemd/armapunk-hc.service`, `deploy/systemd/armapunk-missionfiles.service`, `deploy/systemd/armapunk-watchdog.service`, `deploy/live/run-live.sh`, `deploy/live/reload-live.sh`, `deploy/live/restart_watchdog_pg.sh`, `deploy/live/server.cfg`. **Box:** `~/arma3server_live/` (symlink farm over the Steam install, same pattern as `~/arma3server_dev` on samurai).

- [ ] **Step 1: Build the live instance dir on .96**
  ```bash
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  A3="$HOME/.local/share/Steam/steamapps/common/Arma 3 Server"; L=$HOME/arma3server_live
  mkdir -p $L/mpmissions $L/profiles $L/profiles_hc $L/@AP_server/addons $L/keys $L/battleye $L/tools
  for d in addons aow argo curator dta enoch expansion heli jets kart mark orange tacops tank linux64 steam_appid.txt libsteam_api.so libsteam.so libtbbmalloc.so.2 libtier0_s.so libvstdlib_s.so steamclient.so basic.cfg; do ln -sfn "$A3/$d" $L/; done
  cp -p "$A3/arma3server_x64" $L/
  ln -sfn "$A3/keys/a3.bikey" $L/keys/a3.bikey
  cp -p ~/Armapunk2035/radio/dist/@Armapunk2035/keys/maldenradio.bikey $L/keys/
  cp -p "$A3"/battleye/beserver*.so $L/battleye/; cp -p ~/Armapunk2035/deploy/battleye/*.txt $L/battleye/
  cp -p ~/Armapunk2035/deploy/tools/pbo_http.py $L/tools/
  echo 2000 > $L/.build
  ls $L; ls $L/keys $L/battleye | head -30
  EOF
  ```
  Expected: `keys/` = `a3.bikey maldenradio.bikey`; `battleye/` = `beserver.so beserver_x64.so` + 18 filter `.txt`.
- [ ] **Step 2: RCON config** — `~/arma3server_live/battleye/beserver_x64.cfg` (NOT in git; the LooneyBin one is in the secrets tarball if you want the same password):
  ```
  RConPassword <new, openssl rand -hex 12>
  RConPort 2310
  ```
  Write with `printf 'RConPassword %s\nRConPort 2310\n' "$(openssl rand -hex 12)" > ~/arma3server_live/battleye/beserver_x64.cfg` and record the password in `~/.config/armapunk/rcon` (0600). BattleMetrics needs it later.
- [ ] **Step 3: `deploy/live/server.cfg`** (committed template; the reload script substitutes the two passwords from `deploy/secrets.env` exactly as `run-boot2.sh` did):
  ```
  hostname        = "Armapunk 2035";
  password        = "";                   // set for a closed test (D12)
  passwordAdmin         = "@AP_ADMIN_PW@";
  serverCommandPassword = "@AP_CMD_PW@";
  maxPlayers      = 60;
  persistent      = 1;
  BattlEye        = 1;                    // D5
  verifySignatures = 2;                   // D5 -- keys/maldenradio.bikey is the one that matters
  allowedFilePatching = 1;
  missionHTTPDownloadBaseURL = "https://missions.armapunk.com/";   // D6
  forceRotorLibSimulation = 0;
  disableVoN      = 0;
  vonCodecQuality = 20;
  kickDuplicate   = 0;
  maxPing            = 500;
  maxPacketLoss      = 50;
  maxDesync          = 300;
  disconnectTimeout  = 30;
  kickClientsOnSlowNetwork[] = { 0, 0, 0, 0 };
  voteThreshold   = 1.5;
  voteMissionPlayers = 999;
  allowedVoteCmds[] = {};
  allowedVotedAdminCmds[] = {};
  timeStampFormat = "full";
  logFile         = "armapunk_server.rpt";
  headlessClients[] = {"127.0.0.1"};
  localClient[]     = {"127.0.0.1"};
  class Missions { class Armapunk { template = "Armapunk2035_b2001.Malden"; difficulty = "Custom"; }; };
  ```
  Plus `deploy/secrets.env` on the box (0600, from `deploy/secrets.example.env`): `AP_ADMIN_PW=…`, `AP_CMD_PW=…` — new values, not the dev `N3xusZer0!#!`.
  Also copy the difficulty profile: `cp ~/Armapunk2035/deploy/looneybin.Arma3Profile ~/arma3server_live/profiles/home/armapunk/armapunk.Arma3Profile` (create the dir; the `-name=armapunk` profile must exist for `difficulty="Custom"` to resolve `CustomDifficulty`).
- [ ] **Step 4: `deploy/live/run-live.sh`** (the launcher the unit execs):
  ```bash
  #!/usr/bin/env bash
  # Armapunk 2035 LIVE launcher (10.1.24.96). Exec'd by armapunk-arma.service; do not run by hand
  # while the unit is active (the unit's ExecStartPre guard would then refuse the next start).
  set -u
  LIVE=/home/timb/arma3server_live
  # MUST match ~/.config/armapunk/pysqfd.env -- see deploy/systemd/pysqfd.env.example.
  export PYSQF_SOCKET=/run/user/1000/pysqf.sock
  cd "$LIVE"
  exec ./arma3server_x64 \
    -config=server.cfg -cfg=basic.cfg \
    -profiles="$LIVE/profiles" \
    -name=armapunk -port=2302 \
    -bepath="$LIVE/battleye" \
    -serverMod="@AP_server" \
    -filePatching -autoInit
  ```
- [ ] **Step 5: `deploy/live/reload-live.sh`** — derived from `deploy/reload-armapunk2035.sh` with these exact deltas (copy the dev script, then apply):
  1. `DEV=/home/timb/arma3server_dev` → `DEV=/home/timb/arma3server_live`; `BUILDF="$DEV/.build"` (starts at 2000 → first live build `b2001`).
  2. Delete the debug-console `sed` block and its `trap` (lines that patch `enableDebugConsole` / `BIS_fnc_debugConsoleExec`). Live keeps `enableDebugConsole[]={"76561190000000001"}` as committed.
  3. Delete the "seed the CLIENT's mission cache" block (no client on this box). Keep the `KEEP=3` prune for `$DEV/mpmissions`.
  4. Replace the `pkill -f 'name=loonydev'` + `nohup … run-armapunk2035.sh` launch with:
     ```bash
     SECRETS="$SRC/deploy/secrets.env"; [ -f "$SECRETS" ] && . "$SECRETS"
     sed -e "s/@AP_ADMIN_PW@/${AP_ADMIN_PW:-CHANGE_ME}/" -e "s/@AP_CMD_PW@/${AP_CMD_PW:-CHANGE_ME}/" \
         -e "s/template = \"[^\"]*\"/template = \"$MNAME\"/" "$SRC/deploy/live/server.cfg" > "$DEV/server.cfg"
     export XDG_RUNTIME_DIR=/run/user/$(id -u)
     systemctl --user restart armapunk-arma
     LOG="journalctl --user -u armapunk-arma -n 400 --no-pager"
     ```
     and change the CONFIG GATE loop to read `$($LOG)` instead of `$DEV/loonydev.log` (the unit's stdout is the journal, as it was for LooneyBin — the RPT under `profiles/` is 0 bytes).
  5. Keep `map_generate.py --write` (it proves the DB is reachable before packing; it reads `~/.pysqf_dsn`). Keep the AP_server pack, the lowercase `ap_server.pbo` rule, the UI-page republish block, `pbo_exclude.txt`.
  🔎 Verify the derived script before first use: `bash -n deploy/live/reload-live.sh` and `diff deploy/reload-armapunk2035.sh deploy/live/reload-live.sh | grep '^[<>]' | wc -l` (expect ≈ 40 changed lines, no other drift).
- [ ] **Step 6: Units** — `deploy/systemd/armapunk-arma.service`:
  ```ini
  [Unit]
  Description=Armapunk 2035 live Arma server
  After=network-online.target armapunk-pysqfd.service
  Wants=armapunk-pysqfd.service

  [Service]
  Type=simple
  WorkingDirectory=/home/timb/arma3server_live
  # [a]rma bracket is load-bearing (2026-07-24 outage: the guard matched its own bash -c and blocked every boot).
  ExecStartPre=/bin/bash -c '! pgrep -f "[a]rma3server_x64 -config=server.cfg" >/dev/null'
  ExecStartPre=/usr/bin/timeout 120 /bin/bash -c 'until (echo > /dev/tcp/127.0.0.1/5432) 2>/dev/null; do sleep 2; done'
  ExecStartPre=/usr/bin/timeout 60 /bin/bash -c 'until [ -S /run/user/1000/pysqf.sock ]; do sleep 1; done'
  ExecStart=/bin/bash /home/timb/arma3server_live/run-live.sh
  KillSignal=SIGTERM
  TimeoutStopSec=30
  Restart=always
  RestartSec=15

  [Install]
  WantedBy=default.target
  ```
  `deploy/systemd/armapunk-hc.service`:
  ```ini
  [Unit]
  Description=Armapunk 2035 headless client (vehicle autopilot / AI offload)
  After=armapunk-arma.service
  BindsTo=armapunk-arma.service

  [Service]
  Type=simple
  WorkingDirectory=/home/timb/arma3server_live
  Environment=HOME=/home/timb
  Environment=LD_LIBRARY_PATH=/home/timb/arma3server_live
  ExecStartPre=/usr/bin/timeout 300 /bin/bash -c 'until ss -lun | grep -q ":2302 "; do sleep 5; done'
  ExecStart=/home/timb/arma3server_live/arma3server_x64 -client -connect=127.0.0.1 -port=2302 -profiles=/home/timb/arma3server_live/profiles_hc -name=loonyhc -filePatching
  Restart=always
  RestartSec=20

  [Install]
  WantedBy=default.target
  ```
  (The LooneyBin HC ran exactly this way on .96 — `-client` needs no Steam login; the dev box's Steam-session scraping exists only because a desktop client runs alongside there.)
  `deploy/systemd/armapunk-missionfiles.service`:
  ```ini
  [Unit]
  Description=Armapunk 2035 mission PBO HTTP origin (missionHTTPDownloadBaseURL, behind cloudflared)
  After=network-online.target

  [Service]
  Type=simple
  ExecStart=/usr/bin/python3 /home/timb/arma3server_live/tools/pbo_http.py 8092 --dir /home/timb/arma3server_live/mpmissions
  Restart=always
  RestartSec=3

  [Install]
  WantedBy=default.target
  ```
  `pbo_http.py` binds all interfaces; ufw is the fence (confirm 8092 is NOT allowed in the D0 listing; if it is, `sudo ufw deny 8092`).
  Install all three: `cp ~/Armapunk2035/deploy/systemd/armapunk-{arma,hc,missionfiles}.service ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable armapunk-arma armapunk-hc armapunk-missionfiles` (enable only — first start is §8).
- [ ] **Step 7: Tunnel ingress** (D6). On .96, add to `~/.cloudflared/armapunk.yml` before the 404 catch-all:
  ```yaml
    - hostname: missions.armapunk.com
      service: http://127.0.0.1:8092
  ```
  then `~/bin/cloudflared tunnel --origincert ~/.cloudflared/cert-armapunk.pem route dns armapunk missions.armapunk.com` (the `--origincert` flag is mandatory — without it cloudflared silently creates the CNAME in the projectloonybin zone) and `sudo systemctl restart armapunk-tunnel`.
  🔎 `systemctl --user start armapunk-missionfiles; curl -sI https://missions.armapunk.com/ | head -1` → `HTTP/2 200` (or 404 with an empty dir; not 502).

## 6. Phase E — Push script and map sync 🔧 (gates: D3 D7)

**Files (repo):** `deploy/push-96.sh`, `deploy/live/map-push-live.sh`, `.gitignore` (+`DEPLOYED_COMMIT`).

- [ ] **Step 1: `deploy/push-96.sh`** (runs on samurai):
  ```bash
  #!/usr/bin/env bash
  # Push the working tree to the live box and repack+restart there. This is THE live deploy path.
  #   deploy/push-96.sh            # code push + reload
  #   deploy/push-96.sh --map      # also replace live map content from the dev DB (D7)
  #   deploy/push-96.sh --no-reload
  set -euo pipefail
  SRC=/home/timb/Armapunk2035; HOST=timb@10.1.24.96; SSH="ssh -i /home/timb/.ssh/id_lb -o BatchMode=yes"
  cd "$SRC"
  if [ -n "$(git status --porcelain)" ]; then echo "push-96: working tree dirty -- commit first (live must be reproducible from a commit)"; exit 1; fi
  H=$(date +%H); if [ "$H" -ge 22 ] || [ "$H" -lt 9 ] && [ "${FORCE_DEPLOY:-0}" != 1 ]; then echo "push-96: 22:00-09:00 freeze (FORCE_DEPLOY=1 to override)"; exit 1; fi
  git rev-parse HEAD > DEPLOYED_COMMIT
  rsync -az --delete --info=stats1 -e "$SSH" \
    --exclude='.git/' --exclude='scratchpad/' --exclude='textures_png/' --exclude='website/node_modules/' --exclude='website/.next/' \
    --exclude='radio/dist/@Armapunk2035/addons/' --exclude='loonybot/venv/' --exclude='__pycache__/' \
    --exclude='deploy/postgres/.env' --exclude='deploy/secrets.env' --exclude='*.biprivatekey' \
    "$SRC/" "$HOST:Armapunk2035/"
  [ "${1:-}" = --map ] && bash "$SRC/deploy/live/map-push-live.sh"
  [ "${1:-}" = --no-reload ] && exit 0
  $SSH $HOST 'bash -s' <<'REMOTE'
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
  bash /home/timb/Armapunk2035/deploy/live/reload-live.sh
  REMOTE
  ```
  (`--delete` never removes the excluded on-box files — rsync protects excludes unless `--delete-excluded`.)
- [ ] **Step 2: `deploy/live/map-push-live.sh`** — the D7 rule, executed:
  ```bash
  #!/usr/bin/env bash
  # Replace LIVE map content with DEV's. Wholesale, by design: the map is edited on dev only (D7).
  set -euo pipefail
  SSH="ssh -i /home/timb/.ssh/id_lb -o BatchMode=yes"; HOST=timb@10.1.24.96
  T="-t map_objects -t map_meta -t map_edit_log -t faction_territory"
  docker exec armapunk-pg pg_dump -U armapunk -d pgm_full_scratch --data-only --disable-triggers $T | gzip > /tmp/mapcontent.sql.gz
  scp -q -i /home/timb/.ssh/id_lb /tmp/mapcontent.sql.gz $HOST:/tmp/
  $SSH $HOST 'bash -s' <<'REMOTE'
  docker exec armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 -c "truncate map_objects, map_meta, map_edit_log, faction_territory" </dev/null
  gunzip -c /tmp/mapcontent.sql.gz | docker exec -i armapunk-pg psql -U armapunk -d armapunk -v ON_ERROR_STOP=1 -q
  docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "select count(*) from map_objects" </dev/null
  REMOTE
  ```
  🔎 Expected last line = dev's `select count(*) from map_objects` (10,009 on 2026-09-07). The server reads `map_objects` on its next poll (≤10 s), no restart needed.
- [ ] **Step 3: Commit** the new files (`deploy/systemd/armapunk-*.service`, `deploy/systemd/pysqfd.env.example`, `deploy/live/*`, `deploy/postgres/compose.live.yml`, `deploy/push-96.sh`, `.gitignore` +`DEPLOYED_COMMIT`) and a `MIGRATION_96.md` pointer in `CLAUDE.md` replacing the "no live server" paragraph.

## 7. Phase F — Player carry-over (pgmigrate) 🔧 (gates: D1 D2)

The FINAL dump is the freeze. The dry run on it (2026-09-07 20:12 CDT, samurai) found exactly two defects; both must be fixed and the rehearsal re-run to **exit 0** before the real load. Numbers from `~/pgmigrate-work/decom_rehearsal/report.json`:

| Fact | Value |
|---|---|
| Source tables | 67 (incl. 7 `_backup_*` tables) |
| Carried | 20 — as-is: apd_applications→maxsec_applications, bans, bounties, foreskins, looner_likes, looner_posts, opfor_whitelist, player_names, talent_points, wars; transformed: discord_links, exchange, gang_vehicles, gangs, loadouts, players (570 rows in = 570 out), players_global, storage_vault, vehicles, wanted |
| Dropped by policy | 47 — houses (Altis property → refund route), log (2.2M rows), storage, turf*, vehicle_mem, server_control, restart_log, all `web_*`, bot tables, `_backup_*` … |
| Money reconciliation | players.bankacc in = out = 4,809,001,805; cash 483,002; gangs.bank 490,507,840; wanted.bounty 22,749,400; new_drachma 17,942.9158 — all exact, scale 1 |
| Warnings | CARRY has entries for `casino_chip_pity`, `casino_chips`, `houses_malden` that the live dump lacks (never existed on live — expected) |
| Failure 1 | `maxsec_applications: no CREATE TABLE was emitted` — `rules.py:956` maps `apd_applications` → `target_table="maxsec_applications"`, but the DDL stage emits the CREATE under the SOURCE name |
| Failure 2 | `houses.classname 'Land_u_Addon_02_V1_F' (pk 1396518781) has no price in prices.py` — the Altis house config had a building type `gen_prices.py` (which reads the Malden config) never saw; the refund route needs its purchase price |

- [ ] **Step 1: Record the freeze** in `tools/pgmigrate/rules.py` (replaces the `UNDECIDED` sentinel; commit):
  ```python
  FREEZE: Freeze | _Undecided = Freeze(
      dump_taken_utc="2026-09-08T00:59:40Z",   # looneybin_FINAL_20260907_195940.sql.gz; server stopped 00:57Z, 0 players
      maintenance_window=True,                 # server down for good, nothing after the dump can be lost
      announced_on="<D1>",
  )
  ```
  🔎 `PYTHONPATH=tools python3 -c "import pgmigrate.rules as r; r.validate(); print('gate open')"` → `gate open`.
- [ ] **Step 2: Fix failure 1** — in the DDL emitter (find with `grep -n 'no CREATE TABLE was emitted' tools/pgmigrate/*.py` and `grep -n 'target_table' tools/pgmigrate/ddl.py tools/pgmigrate/etl.py`), emit the CREATE TABLE under `carry.target_table or source_name`. Red state first: `PYTHONPATH=tools python3 -m pytest tools/pgmigrate/test_ddl.py -q` with a new test `test_renamed_table_ddl_uses_target_name` asserting the emitted DDL for `apd_applications` contains `CREATE TABLE maxsec_applications` — see it FAIL, fix, see it PASS.
- [ ] **Step 3: Fix failure 2** — extend `gen_prices.py` to ALSO read the LooneyBin Altis house config from the decommission archive (`/mnt/nas/…/LooneyBin_Altis_Life_deploytree_*.tar.gz` → `mission/LooneyBin.Altis/core/config/fn_houseConfig.sqf`, extract to `~/pgmigrate-work/altis_config/`) via a `--extra-house-config PATH` flag, regenerate `prices.py`, and add a test that `Land_u_Addon_02_V1_F` resolves. Then `PYTHONPATH=tools python3 tools/pgmigrate/gen_prices.py --check` → exit 0. Do not hand-type the price; the whole point of the failure is that a guessed price is a wrong refund.
- [ ] **Step 4: Rehearse to exit 0 on samurai** (no waivers this time):
  ```bash
  cd ~/Armapunk2035 && rm -rf ~/pgmigrate-work/final_rehearsal && mkdir -p ~/pgmigrate-work/final_rehearsal
  PYTHONPATH=tools python3 -m pgmigrate.etl --dump ~/pgmigrate-dumps/looneybin_FINAL_20260907_195940.sql \
     --out ~/pgmigrate-work/final_rehearsal/out --report ~/pgmigrate-work/final_rehearsal/report.json; echo rc=$?
  ```
  Expected: `rc=0`, `report.json` `status: ok`, `reconciliation.ok: true`, `compensation.computed: true` with a non-zero total (the Altis houses are refunded into `players.bankacc`). If `rc=3`, `rules.open_questions()` lists tables still `DECIDE` — decide them in `rules.py`, never with `--allow-decide`.
- [ ] **Step 5: Assemble a full rehearsal database on samurai and boot dev against it.** The ETL creates only the 20 carried tables; the other 52 (map_objects, config, server_control, faction_war, casino_*, house_printers, suites, …) come from dev's schema, and map/config CONTENT from dev's rows:
  ```bash
  cd ~/Armapunk2035
  tools/pgmigrate/run_rehearsal.sh ~/pgmigrate-dumps/looneybin_FINAL_20260907_195940.sql armapunk_rehearsal --yes
  C=""; for t in $(python3 -c "import json;print(' '.join(json.load(open('/home/timb/pgmigrate-work/final_rehearsal/report.json'))['carried']))"); do C="$C -T $t"; done
  docker exec armapunk-pg pg_dump -U armapunk -d pgm_full_scratch --schema-only $C | docker exec -i armapunk-pg psql -U armapunk -d armapunk_rehearsal -v ON_ERROR_STOP=1 -q
  docker exec armapunk-pg pg_dump -U armapunk -d pgm_full_scratch --data-only --disable-triggers -t map_objects -t map_meta -t map_edit_log -t faction_territory -t config -t price_overrides -t radio_schedule -t itemstock | docker exec -i armapunk-pg psql -U armapunk -d armapunk_rehearsal -v ON_ERROR_STOP=1 -q
  docker exec -i armapunk-pg psql -U armapunk -d armapunk_rehearsal -v ON_ERROR_STOP=1 -f - < deploy/postgis.sql
  docker exec armapunk-pg psql -U armapunk -d armapunk_rehearsal -tAc "select count(*) from pg_tables where schemaname='public'"
  ```
  Expected: `72` (or 73 with the rehearsal marker). Then point the dev daemon at `armapunk_rehearsal` (`sudo sed -i 's/dbname=pgm_full_scratch/dbname=armapunk_rehearsal/' /etc/conf.d/pysqfd && sudo rc-service pysqfd restart`), `bash ~/arma3server_dev/reload-armapunk2035.sh`, log in as the owner and check **in this order: money → owned items → licences → gang → vehicles in garage → gear** (README §5; money and container contents are the two that die silently). Also check `maxsec_applications` and `wanted` rows appear in-game. Put the DSN back afterwards.
  Then apply the two hand-ALTER deliveries HANDOFF.md warns about (columns that exist on dev only because someone ALTERed them; the ETL's target schema may lack them): `docker exec -i armapunk-pg psql -U armapunk -d armapunk_rehearsal -v ON_ERROR_STOP=1 -f - < deploy/faction_war.sql` and the same for `deploy/hud_layout.sql` (both are idempotent per their headers — verify with `head -5`).
  🔎 Every column the game reads must exist: `for t in players players_global gangs vehicles; do docker exec armapunk-pg psql -U armapunk -tAc "select string_agg(column_name,',' order by ordinal_position) from information_schema.columns where table_name='$t'" -d armapunk_rehearsal; done` compared against the same query on `pgm_full_scratch` — expect identical lists; any difference = the ETL's target schema drifted from dev and must be regenerated (`gen_target_schema.py`).
- [ ] **Step 6: The real load on .96** (once, after Step 5 is boring):
  ```bash
  scp -q -i ~/.ssh/id_lb ~/pgmigrate-dumps/looneybin_FINAL_20260907_195940.sql timb@10.1.24.96:pgmigrate-dumps/
  ssh -i ~/.ssh/id_lb timb@10.1.24.96 'bash -s' <<'EOF'
  cd ~/Armapunk2035 && set -a && . deploy/postgres/.env && set +a
  PYTHONPATH=tools ~/pysqf-venv/bin/python -m pgmigrate.etl --dump ~/pgmigrate-dumps/looneybin_FINAL_20260907_195940.sql \
     --out ~/pgmigrate-work/live/out --report ~/pgmigrate-work/live/report.json \
     --load "postgresql://armapunk:${PGPASSWORD}@127.0.0.1:5432/armapunk"; echo rc=$?
  EOF
  ```
  then the same schema/content/postgis assembly as Step 5 with `-d armapunk` on .96 (dump the schema/content on samurai, `scp`, restore — the `map-push-live.sh` pattern). Keep `~/pgmigrate-work/live/report.json` forever; it is the carry-over's audit record.
  🔎 `docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "select count(*) from players; select sum(bankacc) from players; select count(*) from map_objects"` → `570`, `4809001805` **plus the computed house refunds**, `10009`.

## 8. Phase G — First boot and smoke 🔎

- [ ] **Step 1:** `deploy/push-96.sh` from samurai (clean tree, daytime). Watch: `ssh … 'journalctl --user -u armapunk-arma -f'`.
  Expected within 90 s: `Mission Armapunk2035_b2001.Malden read from bank`, then `Game started`, no `Undefined base class`, no `Missing 'description.ext::Header'`, no `Initializing Steam server failed`. `ss -lunp | grep -E ':230[2346]'` → four `rvMain` sockets; `:2310` too.
- [ ] **Step 2:** HC: `systemctl --user is-active armapunk-hc` → `active`; journal shows the HC in the `HeadlessClient_F` slot.
- [ ] **Step 3:** PySQF: from the owner's debug console with **LOCAL exec**, `["smoke"] remoteExec ["APS_fnc_pysqfDiag", 2];` (CfgRE `allowedTargets = 2`; the server re-checks adminlevel ≥ 3 by `remoteExecutedOwner`) → `[pysqf-smoke]` 5/5 stages pass in the server RPT. `APS_fnc_pysqfSmoke` itself is server-only and .96 has no SERVER EXEC, so do not call it directly. The engine flag must be PostgreSQL: `"AP_db_postgres" call DB_fnc_flag` is server `localNamespace` since 2026-09-26 and cannot be read from a client, so read the server RPT instead, `[apdb] PostgreSQL reachable: …` then `[apdb] ENGINE: PySQF / PostgreSQL`; if it says extDB3 / MariaDB, the socket paths differ (§4/§5) — do not play against that boot.
- [ ] **Step 4:** Owner login: money, inventory, licences, gang, garage, gear as carried (§7 Step 5 order). One vehicle pulled from the garage and driven. One house-refund balance spot-checked against `report.json` `compensation`.
- [ ] **Step 5:** Mission download from OUTSIDE the LAN: a tester joins; the download must come from `missions.armapunk.com` (server console logs the HTTP path; client sees the fast path). With `verifySignatures=2`, a client running `@Armapunk2035` is NOT kicked (proves `maldenradio.bikey`).
- [ ] **Step 6:** Kill test: `systemctl --user kill -s SIGKILL armapunk-arma` → back within ~30 s (`Restart=always`), HC follows (`BindsTo`).

## 9. Phase H — Go-live hardening 🔧 (gate: D8, D12)

- [ ] `launch.md` items, each as its own commit + push: beta god-stats off **and** the SQL wipe listed there; `AP_devAutoAdmin=false` in `mission/Armapunk2035.Malden/initServer.sqf`; remove `SRV_grantNewbieRoles` auto-grant in `server/AP_server/core/DB/fn_queryRequest.sqf`; `copsRequired` 0→2; Fed Reserve cop req 0→6 (4 spots); `CfgDisabledCommands` re-tightened; `!pos` removed. 🔎 for each: a fresh non-owner test account logs in with 0 money, no admin, no faction rank.
- [ ] `password = ""` → set for the closed test window; cleared at public open.
- [ ] BattleMetrics: add the server (2302, RCON 2310, the §5 Step 2 password) if the VPN-flag/ban mirror is wanted at open (it was LooneyBin's only VPN detection).

## 10. Phase I — Operations 🔧

- [x] **Watchdog (PG) — DONE 2026-09-07 21:42, rewritten the same evening for the owner's schedule: SOFT restart every 4 h, HARD every 12 h.** The mission keeps its 4-h countdown/warnings/feature-lock/graceful-save and writes `restart_now=1`; `deploy/live/restart_watchdog_pg.sh` decides: `hard_pending=1` or process uptime ≥ 11 h → HARD (`systemctl --user restart armapunk-arma`, HC follows via `Wants=`); else SOFT = BE RCON `#restart` (`deploy/live/be_rcon.py`; verified: `Game restarted` → `Game started` in 6 s, same PID) then `systemctl --user restart armapunk-hc` (a headless client survives `#restart` but parks in the lobby); no `Game started` within 120 s → fall back to HARD. `restart_log.mode` = `soft`/`hard`. Exercised live 21:41:54 → soft, HC re-slotted, flags cleared. The original single-mode draft follows for history:
  ```bash
  #!/usr/bin/env bash
  # Live restart driver: polls server_control.restart_now (the mission sets it at T-0 after warning players)
  # and bounces the unit. Repacks never happen here -- push-96.sh is the only deploy path.
  set -u
  export XDG_RUNTIME_DIR=/run/user/$(id -u)
  Q() { docker exec armapunk-pg psql -U armapunk -d armapunk -tAc "$1" </dev/null; }
  while true; do
    if [ "$(Q "select restart_now from server_control where id=1")" = "1" ]; then
      Q "update server_control set restart_now=0, hard_pending=0 where id=1" >/dev/null
      Q "insert into restart_log(ts, mode) values (now(), 'watchdog')" >/dev/null
      systemctl --user restart armapunk-arma
      sleep 120
    fi
    sleep 15
  done
  ```
  Unit `deploy/systemd/armapunk-watchdog.service`: `ExecStart=/bin/bash /home/timb/Armapunk2035/deploy/live/restart_watchdog_pg.sh`, `Restart=always`, `RestartSec=10`, `WantedBy=default.target`. 🔎 `Q "update server_control set restart_now=1 where id=1"` by hand → server restarts within 15 s, one `restart_log` row.
- [ ] **Backups.** On .96, `~/.config/systemd/user/armapunk-pgbackup.{service,timer}` (daily 04:30 local): `docker exec armapunk-pg pg_dump -U armapunk -d armapunk -Fc > ~/pg_backups/armapunk_$(date +%F).dump` + delete older than 14 days. On samurai, a daily `rsync` of `.96:pg_backups/` to `/mnt/nas/Backups/armapunk-pg/` (samurai has the NAS; .96 does not). 🔎 first dump restores into a scratch DB on samurai: `pg_restore -l` lists 72 tables.
- [ ] **Discord notice on restart** (was the loonybot outbox): defer to §11; until then the in-game warnings are the only notice.
- [ ] Re-read `update.md` and fold the live parts into it: kill pattern, `journalctl --user -u armapunk-arma`, push-96 usage, the freeze rule. Mark the LooneyBin procedures superseded.
- [ ] Turn PR discipline back on (CLAUDE.md) the day players are on.

## 11. Later (not blocking open)

- **Website** — finish the `website/` mysql2→pg port (11 `web_*` tables already exist in PG), deploy on .96 as `armapunk-web` (port 3011) behind the armapunk tunnel; then `sudo systemctl disable --now loonybin-stats loonybin-tunnel`, `docker rm -f looneybin-db` (volume `looneybin-db-data` after one last `mariadb-dump`). D9.
- **Bots** — port `loonybot/` to psycopg (tables `bot_commands`, `clankr_alerts`, `discord_links`, `maxsec_applications`, `bones_dm` exist in PG). New tokens; the LooneyBin ones are in the secrets tarball if the same Discord apps are reused. D10.
- **Radio** — `radio/INSTALL-96.md` (icecast + liquidsoap, root). D11.
- **Client mod on Workshop** — `radio/WORKSHOP.md`; owner's Steam account.
- **Delete** `~/loonybin-decom-20260907/` (8.8 GB) once the NAS copy has been restored once as a test.

---

## Self-review (writing-plans + extras gate)

- [x] Riskiest plan code executed: the pgmigrate transform ran on the real FINAL dump (exit 2, two named defects, money reconciles). Unverified and marked: `reload-live.sh` deltas (§5 step 5, verify by `bash -n` + diff count), `restart_log` INSERT columns (§10), `pbo_http.py` behind cloudflared with 77 MB files (LooneyBin used `python -m http.server` on 8091 the same way).
- [x] Every verify step names an observable red state on THIS environment (journal lines, socket path, row counts, `rc=`).
- [x] Lifecycle owners enumerated: server lifecycle = systemd unit (`Restart=always`) + watchdog (restart only); repack = `push-96.sh` only; map content = dev DB via `map-push-live.sh`; pysqfd outlives mission restarts (by design, OpenRC comment). The old LooneyBin owners (run-boot2 repack-on-restart, watchdog FORCE_DEPLOY, mission `.repack_on_restart` flag) are gone — the mission's `[autorestart]` DB write is the only surviving contract and §10 honours it.
- [x] Artefact paths vs ignore rules: `deploy/postgres/.env`, `deploy/secrets.env`, `*.biprivatekey`, `DEPLOYED_COMMIT` (add) are ignored; everything else in `deploy/live/` and `deploy/systemd/` is meant to be committed.
- [x] Spec coverage: stop ✅ · backup to NAS ✅ · bots stopped/removed (3 root units pending D0) ✅ · clean-up ✅ · migration plan = this file · DB migration = §7.

---

## 12. Execution record — 2026-09-07 20:50–21:30 CDT (all phases run the same evening the gates were cleared)

**Armapunk 2035 is LIVE on 10.1.24.96** as `Armapunk 2035 [COMING SOON]` (password-protected, D12), build `Armapunk2035_b2001.Malden`, deployed through `deploy/push-96.sh`.

| Phase | Result / evidence |
|---|---|
| A prerequisites | PySQF built ON the box (`build/ipc-release/pysqf_x64.so` 49,440 B, `-Werror` clean), venv psycopg 3.3.4 on Python 3.14.6, repo mirrored (no git on the box, `DEPLOYED_COMMIT` written) |
| B PostgreSQL | `armapunk-pg` (postgis/postgis:18-3.6) healthy, loopback 5432, `armapunk` DB, PostGIS 3.6, timezone UTC, `log_min_duration_statement=500`; `.env`/`~/.pysqf_dsn` generated on the box |
| C pysqfd | `armapunk-pysqfd.service` active, socket `/run/user/1000/pysqf.sock` mode 0600, modules pysqf.db+apdb+webpages |
| D Arma | `~/arma3server_live` symlink farm, `keys/` = a3 + maldenradio, BattlEye on (log-only filters), new RCON pw (`~/.config/armapunk/rcon`), `deploy/secrets.env` (admin/cmd/join pws), units enabled; `missions.armapunk.com` → 8092 via the armapunk tunnel (HTTP 200) |
| E push | `push-96.sh` fixed once (a stats grep + pipefail made it exit 1 silently before the reload); `reload-live.sh` derived from the dev script (56 changed lines, `bash -n` clean) |
| F carry-over | ETL met real data: three defects fixed with red→green tests (renamed-table DDL column map; Altis house prices via vendored config + five documented aliases; renamed-table sequence seed). Clean transform: 20 tables, 2,225,609 rows read, 10,056 written, money reconciles, **159 players credited $110,083,060** for Altis property. Live load verified row-for-row against MANIFEST.json; other 52 tables from dev's schema; map content 10,009 rows with geometry; `faction_war.sql`/`hud_layout.sql` applied; `server_control` singleton inserted. Audit: `.96:~/pgmigrate-work/live/CARRYOVER_REPORT_20260907_211523.json` |
| G first boot | `Mission Armapunk2035_b2001.Malden read from bank` 21:17:20, `Connected to Steam servers`, `Game started` 21:17:26, `[apdb] ENGINE: PySQF / PostgreSQL`, asyncExec smoke OK, runtime DDL added the 5 dev-only columns, HC connected (after adding `-password=${AP_JOIN_PW}` to its unit), **dbsoak 28/28 green on the live DB**, mapselftest core 9/10 (see open items), watchdog + nightly backup timers active (first dump 782 KB, pulled to `/mnt/nas/Backups/armapunk-pg/`) |
| H hardening | launch.md items applied in commit 5bea9ebc (see D8). God-stat SQL wipe **NOT run**: the carried players show organic progression (max civ_exp 424,521; no ≥1e9 exp anywhere) — the wipe would have destroyed real LooneyBin progress. Two accounts hold ≥$1B bank: `pain` (76561190000000010) $1,012,018,904 and `player097` (76561190000000011) $1,001,690,500 — tester money, owner's call |
| D9/D11 | stats site + MariaDB stopped; radio live (5 mounts, docker on .96) at `radio.projectloonybin.com` through the retained loonybin tunnel (that hostname's CNAME never existed before tonight) |
| D5 | `armapunk-d5-reminder.timer` posts daily 09:00 CDT to the admin channel pinging the owner (test post HTTP 200 at 21:03) |

**Open items (not blocking the closed test):**
1. `mapselftest` phase 7 fails on the live HC (live 1,209 vs expected 2,401 at the HC's position) and passes on dev. Root cause: on a client with no interface `AP_fnc_mapTick` ignores the player-position focus that the test computes its expectation from (`fn_mapTick.sqf:20-22` uses `AP_mapFoci`), so the phase is only consistent on an interfaced client; dev passes by coincidence of what its HC has around it. Test artifact, not a streaming defect — real players stream around themselves (phase 3a, the same mechanism with an explicit focus, passes 1,209/1,209 on live). Fix the test to skip/adjust phase 7 when `!hasInterface`. Logged in NEEDSFIX.md.
2. NAS pull of `.96:~/pg_backups/` needs a cron entry on samurai, and samurai's cron spool is root-owned and missing (`crontab: '/var/spool/cron/crontabs' is not a directory`). Owner: `sudo mkdir -m 1730 /var/spool/cron/crontabs && sudo chgrp crontab /var/spool/cron/crontabs` (or equivalent), then `crontab -e` → `15 5 * * * rsync -a -e 'ssh -i /home/timb/.ssh/id_lb' timb@10.1.24.96:pg_backups/ /mnt/nas/Backups/armapunk-pg/`. Until then, pull by hand.
3. `Server: Object 2:344 not found (message Type_136/108)` once at boot — a mission.sqm entity reference; benign so far, worth a look with the map tools.
4. Radio hostname: the client addon has `radio.projectloonybin.com` compiled in; move to `radio.armapunk.com` and retire the loonybin tunnel when the addon is rebuilt (D5 reminder covers it).
5. CfgRE/server.cfg RCE hardening (launch.md §3) stays deferred to PUBLIC open.

**Addendum 21:45 — restart schedule (owner: "soft restart (back to lobby) every 4 hours and one hard restart every 12 hours").** Implemented as above (commit 0fae4f6b, build b2002). Timeline from a process start: T+4h soft, T+8h soft, T+12h hard (uptime 11 h threshold at the third T-0), repeat. Manual: `update server_control set restart_now=1 where id=1` = soft now (hard if uptime ≥ 11 h); `..., hard_pending=1` = hard now. Client mission PBO on join: `Armapunk2035_b2002.Malden.pbo` 76.7 MB (served by `missions.armapunk.com`); the optional client mod `@Armapunk2035` is a separate 258 MB (three addons).

**Addendum 22:25 — "all custom buildings gone" (owner report ~21:50) — ROOT CAUSE + FIX, live on b2003.**
Evidence: your client's RPT had zero `[AP-MAP]` lines; the server journal showed `[AP-MAP] fetch: cache not ready, owner 6/7 refused` every 2 s from 21:49 (your two joins), and no `[AP-MAP] boot` after the 21:41:54 soft restart. Cause: `server/AP_server/init.sqf` spawned `mapLoad`/`territoryLoad`/`mapEditPoll` INSIDE the `if (isNil {uiNamespace getVariable "AP_sql_id"}) then {…}` block (lines 122–154). `uiNamespace` survives a mission `#restart`, so that block runs once per PROCESS; every soft restart skipped the map load, `APS_mapReady` stayed nil, every client fetch was refused after the 120 s grace and nothing streamed (custom buildings, everything). Latent on dev (no soft restarts there). Fix (commit 05cf88b1): the spawn moved below the block, still behind the engine-decision wait. Verified: soft restart → `[AP-MAP] boot: 9585 rows` 10 s after `Game started` (22:07:22, 22:14:25, 22:18:11).
Two watchdog follow-ups found while verifying: (1) `#restart` with a headless client in-mission can leave the dedi in `Waiting for next game.` (the HC parks in the lobby and never re-slots; A/B tested 22:07 vs 22:08) → the soft path now stops the HC unit, `#restart`s, and starts it after `Game started` (commit c-series "take the HC out"); (2) a `#restart` inside the first minute of a boot wedged the mission cycle → no soft restart under 3 min of uptime (hard instead). Both cycles since then: `Game restarted` → `Roles assigned` 2 s → `Game started` 6 s → map boot 10 s → HC back, `restart_log` = soft.
Known HC quirk (pre-existing): the HC's first map fetch after joining is refused (`no resolvable requester`, owner 0) and retried 90 s later; real clients are served at once.

---

## 13. 2026-09-08 — .96 becomes the dev server, and patch notes start

**Owner, 2026-09-08:** *"for the next little while we will use the main server as the dev server"* and *"have loonybot start posting patch notes as of today when we make a change"*. Both are live as of build **b2004** (commit `ec02cdaf`).

**Dev mode.** `deploy/LIVE_IS_DEV` is the switch and the documentation. While it exists: `push-96.sh` waives the 22:00–09:00 freeze, stage-only and owner-called-restarts are suspended (CLAUDE.md), and .96 — not `~/arma3server_dev` — is the test target. The dirty-tree refusal stays, because a live build must be reproducible from a commit and the commit range is what the patch note is built from. **Deleting that one file** re-arms the freeze in `push-96.sh` and is the cue to restore the rest of the live discipline (stage-only, owner-called restarts, branch+PR). The box-local dev server on samurai is untouched and still works as the fallback.

**Patch notes.** Every `push-96.sh` deploy now posts to Discord **#📝patch-notes-and-teasers** (`100000000000000974`) as **LoonyBot**. The bot PROCESS stays retired — it is pymysql→3306 and still needs the psycopg port — but its identity posts over REST, which is all the old `gen_patchnotes.py → loonybot/outbox → bot` bridge ever did.

| Piece | What it does |
|---|---|
| `push-96.sh` | reads the box's `DEPLOYED_COMMIT` **before** mirroring, so the deployed range `prev..HEAD` is exact; posts after a successful reload; `--no-notes` deploys silently |
| `deploy/live/build_patchnote.py` | composes the note: (1) `deploy/patchnote_override.txt` — curated, `{version}` substituted, consumed on post and archived to `~/.armapunk_patchnotes/`; (2) BUGS.md `(reboot pending` entries via `gen_patchnotes.collect()`, reusing the single copy of the player-facing EXCLUDE filter; (3) commit subjects minus infrastructure prefixes (docs/chore/test/ci/deploy/live/watchdog). Exits 1 when nothing is player-facing → **no post**, which is what keeps a dev-mode day of deploys off the channel |
| `deploy/live/post_patchnote.py` | the REST call, on the box where the token lives. Splits >1900 chars on line boundaries, refuses any note containing `@everyone`/`@here`, `allowed_mentions.parse=[]` so a stray mention cannot ping |

First note posted 2026-09-08 09:21 CDT (verified back through the API: author LoonyBot, correct channel) covering the move, the carry-over, the property refund, the map-after-restart fix, the restart schedule and the radio. To curate the next one, write `deploy/patchnote_override.txt` and deploy; otherwise the commit subjects speak.

**Addendum 09:40 — closed ALPHA, not beta (owner 2026-09-08).** The first note went out labelled "Beta 0.2.1" (the string in `version.hpp`) and was **deleted from the channel** before I could edit it — the D5 reminders in the admin channel are untouched, so the deletion was specific to that post. Renamed at the source instead of in one message: `AP_VERSION_STR` and `AP_ONLOAD_MISSION` (loading screen), `AP_version` in `configuration.sqf` and the landing screen's fallback label all read **Alpha 0.2.1**, and CLAUDE.md's versioning rule is `Alpha X.Y.Z` with "never call it a beta anywhere a player reads". `post_patchnote.py` now refuses any note matching `\bbeta\b` (`--allow-beta` to override), so a hand-written override cannot put the word back. Live on **b2006**, deployed with `--no-notes`: the corrected announcement is parked at `deploy/patchnote_override.txt.draft` (gitignored) rather than reposted over a deletion — arm it with `mv deploy/patchnote_override.txt{.draft,}` and deploy, or delete the draft if the announcement is being written by hand.

**Addendum 09:31 — the announcement is up.** Owner: *"post it"*. Posted the parked draft directly (`post_patchnote.py` on the box, stdin) rather than through a deploy — **b2006 already carries everything the note describes, so restarting the server just to emit a message would have been the wrong tool**. Verified back through the API: id `100000000000000975`, author LoonyBot, 0 occurrences of "beta". Direct posting skipped the version header that `build_patchnote.py` adds on a deploy, so `post_patchnote.py --header` now composes the same header from the box's own `version.hpp` + `~/arma3server_live/.build` (a hand-posted note cannot drift from the pipeline's format), and the live message was edited to carry it: **Armapunk 2035 — Alpha 0.2.1 · server update · b2006**. Draft archived to `~/.armapunk_patchnotes/` and removed.
