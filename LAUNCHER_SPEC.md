# Armapunk 2035 Launcher — design spec

**Status:** approved in design review with the owner, 2026-09-22. Not built.
**Goal:** one launcher for Windows and Linux that keeps `@Armapunk2035` up to date, starts Arma 3
the fastest way it can run, and packs Marty McFly's iMMERSE shaders, a faster memory allocator and
(on Windows) DXVK — every one of them a toggle. Armapunk look and feel.

**Why this is possible now:** the live server runs `BattlEye = 0` (2026-09-22). BattlEye used to
block exactly these files (ReShade `dxgi.dll`, unlisted allocator DLLs, DXVK). Other servers the
player joins still run BattlEye, which is why everything placed in the Arma folder is per-session.

**Out of scope:** the in-game main menu (`armapunk_menu.pbo`), Steam Workshop publishing, a
benchmark suite (owner: skip), code-signing certificates.

---

## 1. Architecture

Four pieces with clear boundaries.

### 1.1 Launcher app (Tauri: Rust core + HTML/CSS UI)

- **UI** (`launcher/ui/`): pages and toggles only, in the deck styling from `ui/html` (charcoal,
  cyan, magenta, HUD fonts). Talks to the core through five Tauri commands:
  `get_state`, `set_toggle`, `sync`, `launch`, `repair`.
- **Core** (`launcher/src-tauri/src/`), one module per job, each testable alone:

| Module | Job |
|---|---|
| `paths` | find Steam, the Arma 3 install, the Proton prefix (Linux), the Steam user config |
| `manifest` | fetch the release manifest, verify its ed25519 signature, diff against local files |
| `sync` | resumable downloads (HTTP Range), SHA-256 verify, atomic swap, prune |
| `session` | per-session install into the Arma folder and guaranteed cleanup |
| `profile` | turn toggles into Arma parameters, files to place and environment settings |
| `launch` | Windows: start `arma3_x64.exe` directly. Linux: `steam -applaunch 107410 -noLauncher …`. Both: watch the Arma process until it exits |
| `steamcfg` | Linux only: write Wine DLL overrides / env into Steam's launch options while Steam is closed, backing the file up first |

### 1.2 Release pipeline (`tools/release_launcher.py`)

Stages `@Armapunk2035` plus the launcher-managed file sets from the gitignored
`launcher-release/` folder, hashes every file, writes the manifest, signs it with an ed25519 key
kept outside the repo (next to the mod key, never on the CDN), uploads.

### 1.3 CDN

Manifest plus content-addressed files (`blobs/<sha256>`).
- **Testing:** a static folder on .96 served through the existing Cloudflare tunnel (free plan).
- **Production:** Cloudflare R2 (no download fees; Cloudflare's terms discourage bulk binaries
  through the standard proxied CDN).

### 1.4 Server entry

The launcher shows the Armapunk server with its player count (standard Arma/Steam server query)
and joins with the saved password.

### 1.5 Session lifecycle

On **Launch**:
1. Refuse if Arma is already running. Clean any leftovers from a previous session (see 3.4).
2. Place the enabled session files, recording every path in a session record:
   `Dll/mimalloc_ap.dll`; ReShade `dxgi.dll` + `ReShade.ini` + `ReShadePreset.ini` +
   `reshade-shaders/` + `reshade-addons/`; `d3dcompiler_47.dll` (Linux); DXVK `d3d11.dll` +
   `dxgi.dll` (Windows).
3. If a file already exists at a target path and the launcher did not place it (e.g. the player's
   own ReShade), move it to `backup/<session>/` and restore it after the session. Never delete a
   file the launcher does not own.
4. Launch, wait for Arma to exit, remove exactly what the record lists, restore backups, delete the
   record. The Arma folder must end byte-identical to how it started.

The mod itself is **not** in the Arma folder: it lives in the launcher's data folder and is passed
as `-mod=<absolute path>` (`Z:\home\…` under Proton).

### 1.6 Security

The launcher places DLLs into players' game folders, so the manifest is the trust anchor:
- HTTPS only; the manifest is signed (ed25519 over its exact bytes); the public key is compiled
  into the launcher with a second slot for key rotation; an unverified manifest is refused.
- Every file is SHA-256-checked against the signed manifest before placement.
- The launcher never executes downloaded code; only Arma loads the DLLs.
- Launcher self-updates use Tauri's updater with its own signing key.

---

## 2. Toggles

Defaults in brackets. Everything is exposed.

### 2.1 Graphics — Marty McFly's iMMERSE Ultimate through ReShade

- ReShade master switch [on]; hotkeys: effects on/off [End], overlay [Home].
- Preset picker: **Armapunk Neon** [default] (RTGI + bloom + grading, authored with the owner
  in-game), **Cinematic** (everything maxed), **Performance** (MXAO + sharpen), **Off**, **Custom**.
- Per-effect switches with their main settings: RTGI Diffuse (quality Very Low–Ultra, bounce and
  AO strength), RTGI Specular, MXAO, FFT Bloom, Clarity, ReGrade+, Solaris, Exposure Fusion, SMAA,
  Sharpen, Depth of Field, Parallax DOF, Film Grain, ReLight, LUT Manager.
- Depth buffer set up automatically for Arma (Generic Depth D24X8 filter, correct layer,
  linearization values), plus a "Show depth" check.

### 2.2 Performance

- Memory allocator: **mimalloc (Armapunk build)** [default] / Arma default (TBB) / System.
  Source: GoldJohnKing's Arma 3 mimalloc port (MIT). Built for AVX2; the launcher falls back to
  the Arma default on CPUs without AVX2.
- Huge pages `-hugePages` [on]. Windows needs the "Lock pages in memory" right; the launcher shows
  its status and offers a one-time elevated fix.
- DXVK, Windows only [off, experimental].
- CPU: `-enableHT`; `-exThreads` 0/1/3/5/7 [7]; `-cpuCount` override; main-thread pinning
  `-cpuMainThreadAffinity` Auto (fastest core cluster) / Off / manual mask; `-cpuAffinity`;
  `-setThreadCharacteristics` (Windows).
- `-maxMem`, `-maxVRAM`, `-noLogs`.

### 2.3 Game

- Auto-join the Armapunk server [on] with the saved password, or start at the main menu.
- Window mode: fullscreen / windowed / borderless.
- `-skipIntro` `-noSplash` [on]; empty main-menu world `-world=empty` [on].
- `-noPause`, `-showScriptErrors` (developer), profile name `-name`.

### 2.4 Linux (Proton)

Launch-option manager, written into Steam's launch options while Steam is closed, with a status
light: Wine overrides [managed: `d3dcompiler_47=n;dxgi=n,b`], GameMode, Wayland, DXVK HUD,
DXVK frame cap.

### 2.5 Maintenance

Verify files, Repair (clean the Arma folder), channel Stable / Test, open logs, Uninstall.
Credits/licences page (ReShade BSD-3, mimalloc MIT, DXVK Zlib, iMMERSE — Marty's grant).

### 2.6 DXVK + ReShade on Windows

Both want to be `dxgi.dll`. With DXVK on, ReShade must attach on the Vulkan side as a Vulkan layer
registered only for the session (per-user registry entry, removed at cleanup). **Unproven — this
is spike M0.** Fallback if it fails: DXVK and ReShade are mutually exclusive on Windows and the UI
says why. Linux has no conflict: Proton already runs Arma on DXVK and ReShade as `dxgi.dll` works
on top of it (verified on the owner's machine, 2026-09-22).

---

## 3. Releases, updates, failure handling

### 3.1 Manifest

`manifest.json` + `manifest.json.sig`, one per channel. Shape only — sizes and hashes below are
elided, the pipeline fills them:

```json
{
  "schema": 1, "channel": "stable", "release": "2026.09.22-1",
  "min_launcher": "0.1.0",
  "server": { "name": "Armapunk 2035", "host": "…", "port": 2302 },
  "files": [
    { "set": "mod",      "os": "all",     "path": "@Armapunk2035/addons/ap_vcity.pbo", "size": 66100703, "sha256": "…" },
    { "set": "mimalloc", "os": "all",     "path": "Dll/mimalloc_ap.dll",               "size": 453120,   "sha256": "…" },
    { "set": "reshade",  "os": "all",     "path": "dxgi.dll",                           "size": 0,        "sha256": "…" },
    { "set": "immerse",  "os": "all",     "path": "reshade-shaders/Shaders/iMMERSE/…",  "size": 0,        "sha256": "…" },
    { "set": "dxvk",     "os": "windows", "path": "d3d11.dll",                          "size": 0,        "sha256": "…" }
  ],
  "presets": [ { "id": "armapunk-neon", "sha256": "…" } ]
}
```

- Files are downloaded from `blobs/<sha256>`: immutable, cacheable forever. Only the manifest has a
  short cache lifetime.
- `set = "mod"` installs into the launcher data folder; every other set is a session set placed
  into the Arma folder at launch.
- `d3dcompiler_47.dll` is not redistributed: Windows 10/11 ships it; on Linux the launcher fetches
  Microsoft's redistributable at setup time, the way winetricks does.

### 3.2 Update flow

1. Fetch the manifest (short timeout), verify the signature, check `min_launcher`.
2. Diff against the local record (path, size, SHA-256).
3. Check free disk space (download total + 10 %).
4. Download to `.part` files, resuming with HTTP Range.
5. Verify SHA-256, swap into place atomically.
6. Prune files in launcher-managed folders that the manifest no longer lists.
7. Save the local record.

The mod set must be complete before Launch unlocks. Session sets download the first time their
toggle is switched on.

### 3.3 Limits

Largest file today: 137 MB (`zee_fsof.pbo`), under Cloudflare's usual 512 MB cap for files cached
on the free plan (verify before release). First download ~350 MB; later updates are deltas.

### 3.4 Failure handling

| Situation | Behaviour |
|---|---|
| CDN unreachable | Launch with the last verified local state and warn; block only if the mod was never installed |
| Bad signature | Refuse the update, keep current files, show an error |
| SHA-256 mismatch | Re-download twice, then fail that file and keep the old one |
| Disk full | Stop before downloading; say how much space is needed |
| Leftover session files after a crash | Session record cleans them on next start |
| File at a target path not placed by the launcher | Back up, restore after the session; never delete unowned files |
| Arma already running | Block Launch and Repair |
| Linux: Steam open when launch options need changing | Ask to close Steam, or launch now with ReShade off (its compiler needs the Wine override) |
| Linux: no Proton prefix yet | Setup screen: "Run Arma once from Steam, then come back" |
| Arma not running 120 s after Launch | Clean up session files; "didn't start" error with the log path |
| Windows: Steam not running | Start Steam first (the Arma licence needs it) |
| CPU without AVX2 | mimalloc option disabled, Arma default allocator used |

---

## 4. Build, test, location

### 4.1 Layout

- `launcher/src-tauri/` Rust core; `launcher/ui/` web UI.
- `tools/release_launcher.py` release pipeline.
- `launcher-release/` (gitignored) staging for everything that must stay out of git: iMMERSE
  files, allocator, ReShade, DXVK.

### 4.2 Builds (GitHub Actions, new workflow on `launcher-v*` tags)

- Windows x64 on a Windows runner: NSIS installer, unsigned for now (SmartScreen "unknown
  publisher" prompt).
- Linux x64: AppImage.
- Artifacts attached to a GitHub release; the self-updater points at those releases.

### 4.3 Automated tests (`cargo test` in CI)

- `manifest`: good signature, bad signature, one byte tampered, wrong key, second key slot.
- `sync`: diff, resume after interrupted download (local HTTP server), hash mismatch re-download,
  disk full.
- `session`: place/remove in a temporary fake Arma folder; player's own `dxgi.dll` backed up and
  restored; crash recovery; nothing outside the record removed.
- `profile`: expected-output tests: each toggle produces exactly its parameters, files and env.
- `steamcfg`: edits a sample Steam config file, writes a backup, changes nothing else.
- `paths`: sample Steam library files for Windows and Linux layouts.

### 4.4 Manual acceptance (owner's Linux box + one Windows machine)

1. Fresh install → sync → launch → join the server.
2. Every toggle launches; ReShade presets load.
3. After Arma exits, the Arma folder is byte-identical to before.
4. A BattlEye server still works afterwards.
5. Kill Arma mid-session → next launcher start cleans up.
6. Update from an older release.
7. Windows: DXVK + ReShade together (spike result).

### 4.5 Milestones

- **M0 — spikes:** Windows DXVK + ReShade as a session Vulkan layer; Linux `steam -applaunch` +
  process watch (manual version already worked 2026-09-22).
- **M1:** core modules + minimal UI, Linux first.
- **M2:** Windows build, DXVK, huge-pages helper.
- **M3:** full toggle UI, Armapunk theme, presets (Armapunk Neon tuned in-game with the owner),
  server status.
- **M4:** release pipeline, test CDN on .96, self-update, credits/licences page, Marty's
  provenance entry.

---

## 5. Licensing and provenance (blocks M4, not M1–M3)

- ReShade (BSD-3), mimalloc Arma port (MIT), DXVK (Zlib): redistributable with their licence
  files, listed on the credits page.
- **iMMERSE Ultimate:** the owner obtained Marty McFly's (Pascal Gilcher's) permission to ship it
  in the mod (2026-09-22). Its LICENSE forbids redistribution without explicit permission, so before
  M4 the grant is recorded word for word, with date and source, in `radio/addon/PROVENANCE.md`,
  and the original (email/letter + payment receipt) is kept outside git. It must cover: the shader
  files, textures and add-on DLLs; ideally future updates; public download by any player from our
  CDN (and Workshop, if used); whether shader files may be edited (presets are separate files);
  credit wording and placement; duration, revocation and any restrictions.
- The iMMERSE files never enter git (gitignored staging; CDN only).
