# LooneyBin — Migration to New Hardware (→ CachyOS)

Runbook for moving the live LooneyBin Altis Life server + full stack to a new box running **CachyOS**
(Arch-based, systemd). The current box is **Gentoo (OpenRC)**, so services get translated OpenRC → systemd.

**Strategy:** *dump-and-restore + rebuild-from-source*, not disk-clone.
- **Code** comes from `git clone` (the mission + server SQF are authoritative in git).
- **Arma base** comes from `steamcmd` (a clean current install).
- Only the **irreproducible** bits travel in a bundle: the **database**, the **secrets**, the **custom
  Arma parts** (extDB3 connector + libs + keys), the **deploy state markers**, and the **bot venv reqs**.
- The migration is **non-disruptive to prep**: `migrate_bundle.sh` only reads + takes a
  `--single-transaction` DB dump (no write lock — verified, all 49 tables InnoDB, ~65 MB gz in 5 s).
  The live server keeps serving until the brief cutover.

The two scripts do the work: **`deploy/migrate_bundle.sh`** (run on OLD box) and
**`deploy/provision_cachyos.sh`** (run on NEW box, phased).

---

## 1. Stack inventory

| Component | Location (old box) | Size | How it migrates |
|---|---|---|---|
| Mission + server SQF (code) | `~/Documents/LooneyBin Altis Life` (git `main`) | ~small in git | `git clone` |
| Dev worktree | `~/loonybin-doomba` (git `doomba`) | | `git worktree` / clone |
| Arma 3 Dedicated Server (base) | `~/.local/share/Steam/steamapps/common/Arma 3 Server` | 6.3 G | `steamcmd` app **233780** |
| extDB3 connector + `libtbbmalloc` + server `keys/` + `steam_appid.txt` | same dir | 35 M | **bundle → restore** |
| `@AP_server` + mission PBO | same dir | small | **repacked from source** by `run-boot2.sh` (not bundled) |
| **Database `looneybin`** | docker `looneybin-db` (mariadb:11), vol `16a82e…035d` | **644 M / 49 tbl** | **mysqldump → restore into a clean named volume** |
| Secrets (tokens/RCON/signing key/DB creds) | gitignored (see §3) | tiny | **bundle (separate tarball)** |
| Bot venv | `loonybot/venv` (aiohttp, discord.py, PyMySQL) | | **recreate from `requirements.txt`** |
| Deploy state markers | `deploy/.*_done` | tiny | **bundle** (so one-time DB migrations never re-run) |
| Services | OpenRC `loonybot`, `officer-maggot`, `docker` | | **systemd units** (`deploy/systemd/`) |
| Support bots | `clankr/lagwatch/ddos_watch/enrique/latoya/restart_watchdog` | | **auto-launched by `run-boot2.sh`** (setsid) — no unit needed |

No user crontab. No other loonybin services. The `obico-*` docker containers are a 3D-printer app — **not** part of LooneyBin, do not migrate.

## 2. Ports / firewall (open on the new box)

| Port | Proto | Use |
|---|---|---|
| 2302 | udp | Arma game |
| 2303 | udp | Steam query |
| 2304 | udp | Steam master |
| 2306 | udp | (Arma aux) |
| 2310 | udp/tcp | **BattlEye RCON** (BattleMetrics) |
| 3306 | tcp | MariaDB — **bind 127.0.0.1 only**, never public |

## 3. Secrets manifest (never in git — travel in the `_secrets.tar.gz`)

- `loonybot/config.json` — Discord token(s), RCON creds, DB creds for loonybot/CLANKR/lagwatch
- `loonybot/enrique.config.json`, `loonybot/latoya.config.json` — separate Discord tokens (Enrique gardener, LaToya IRS)
- `loonybot/clankr_state.json`, `loonybot/*.ranknicks.json` — bot runtime state
- `deploy/battleye/beserver_x64.cfg` (+ `beserver.cfg`) — **RCON password**
- `deploy/keys/looneybin.biprivatekey` — **PBO signing private key** (⚠️ irreplaceable: regenerating it changes the public `.bikey`, so every client would need the new key — keep this one)
- extDB3 password — the trivial default `looneybin` (repo template is `CHANGE_ME`; `run-boot2.sh` injects it at boot). The deployed copy is bundled too.

## 4. Prerequisites on the new box

- CachyOS installed, a user `timb` (paths are hardcoded to `/home/timb/...`), `sudo`.
- A **Steam account that owns Arma 3** (anonymous login can't download app 233780).
- Ports above reachable from the internet; DNS / the players' connect IP updated at cutover.
- **`steam_appid.txt` must stay `107410`** — `233780` crashes this box class (stalled cross-thread pipe). The bundle carries the right one.

## 5. Migration procedure

### Phase A — Prep (OLD box, zero downtime)
```
cd "$HOME/Documents/LooneyBin Altis Life"
deploy/migrate_bundle.sh            # -> ~/loonybin-migration/bundle_<stamp>_{main,secrets}.tar.gz
```
Non-disruptive (single-transaction dump). Produces two tarballs + a `MANIFEST.txt` with checksums.

### Phase B — Transfer
```
scp ~/loonybin-migration/bundle_<stamp>_main.tar.gz    timb@NEWBOX:~/loonybin-migration/
scp ~/loonybin-migration/bundle_<stamp>_secrets.tar.gz timb@NEWBOX:~/loonybin-migration/   # handle with care; delete after import
```

### Phase C — Provision the new box (NEW box, no cutover yet)
Run phase-by-phase so you can watch each step:
```
cd ~/loonybin-migration    # where the tarballs are
export BUNDLE_DIR=~/loonybin-migration
PHASE=deps     ~/Documents/"LooneyBin Altis Life"/deploy/provision_cachyos.sh   # pacman + docker + steamcmd
PHASE=code     ...                                                              # git clone main + doomba
PHASE=arma     ...                                                              # steamcmd 233780 + restore @extDB3/keys/appid
PHASE=db       ...                                                              # clean named volume + restore the dump
PHASE=secrets  ...                                                              # tokens / RCON / signing key / markers
PHASE=venv     ...                                                              # recreate the bot venv
PHASE=services ...                                                              # systemd loonybot + officer-maggot
PHASE=verify   ...                                                              # sanity (no launch)
```
(First `provision_cachyos.sh` with no `PHASE` runs them all in order.) After `code`, the provision script
lives at its final path, so switch to `~/Documents/"LooneyBin Altis Life"/deploy/provision_cachyos.sh`.

### Phase D — Dry run (NEW box, still no cutover)
The `db` phase restored a copy of the DB. Launch the stack and connect a test client to prove it works —
**the old box is still live and untouched**:
```
cd "$HOME/Documents/LooneyBin Altis Life/deploy" && ./run-boot2.sh
```
`run-boot2.sh` repacks + signs the PBOs from source, injects the extDB3 pass, starts the server + CLANKR +
watchers. Verify: extDB3 "Connected to Database", a client joins, money/inventory load, RCON binds (2310).
Then stop it (`pkill -x arma3server_x64`) until the real cutover.

### Phase E — Cutover (brief downtime)
1. Announce a restart in-game (or `deploy/scheduled_restart.py <HH:MM> <ver>` for timed warnings).
2. Stop the OLD server cleanly so players save: let the scheduled restart drain, then `pkill -x arma3server_x64`
   on the old box (graceful saves fire on the in-game warnings, not on SIGTERM — so use the scheduled path).
3. **Fresh final dump** on the OLD box (server now down = perfectly consistent): re-run `migrate_bundle.sh`,
   scp the new `db/looneybin_<stamp>.sql.gz`, and on the NEW box re-run `PHASE=db` to load the fresh data.
4. Start the NEW stack: `deploy/run-boot2.sh`.
5. **Repoint players to the new IP** (update DNS / the advertised connect address / the Steam server entry).
6. Verify §7, then announce back up.

### Phase F — Rollback
Keep the OLD box powered + intact until the new one is proven over a full play session. Rollback = start the
old server again and repoint back. Do **not** wipe the old DB volume until you're confident.

## 6. OpenRC → systemd translation

`deploy/systemd/` holds the units + space-free launchers (systemd, like OpenRC, dislikes the space in the
project path, so it runs via `/usr/local/bin/{loonybot,officer-maggot}`):
- `loonybot.service` / `officer-maggot.service` — `Restart=always, RestartSec=5`, `User=timb`, `After=docker.service`.
- Installed + enabled by `provision_cachyos.sh PHASE=services`.
- The setsid support bots (CLANKR/lagwatch/ddos_watch/enrique/latoya/restart_watchdog) are **not** services —
  `run-boot2.sh` auto-launches them (pgrep-guarded) when the server starts.

## 7. Post-migration verification

- [ ] `docker ps` → `looneybin-db` up (restart=unless-stopped) on the **clean named volume** `looneybin-db-data`
- [ ] DB: 49 tables, `players` row count matches the old box
- [ ] `run-boot2.sh` → RPT shows `extDB3 Loaded` + `Connected to Database`; PBOs signed (verifySignatures=2 passes)
- [ ] A real client connects → spawn-select → money/bank/inventory/licenses load → relog persists
- [ ] RCON binds on 2310 (BattleMetrics reconnects); loonybot + officer-maggot `systemctl is-active` = active
- [ ] CLANKR running (hard prereq — server refuses to launch without it)
- [ ] The `.*_done` deploy markers are present (one-time DB migrations did **not** re-run)

## 8. Gotchas (all handled by the scripts, but know them)

- **`steam_appid.txt` = 107410**, never 233780 (crashes this box class).
- **`LD_LIBRARY_PATH=$A3SRV`** — extDB3 dlopens `libtbbmalloc.so.2` from the server root (run-boot2 sets it).
- **`-bepath=battleye`** — required for RCON to bind on Linux (BE self-relocates its `.so` otherwise).
- **Hash-named DB volume → clean named volume** `looneybin-db-data` (fixes the old run-boot2 TODO; done via the dump/restore, not a volume copy).
- **Keep the `biprivatekey`** — the signing key is irreplaceable without re-keying every client.
- **Transfer the deploy `.*_done` markers** — or the one-time DB migrations (stats de-clobber, talent wipe, house restore, sativa/housetax comps) re-run on the new box.
- Network-adapter flakiness on the *old* box (USB NIC `enp198s0f4u1`) is hardware-specific — the new box won't inherit it.
