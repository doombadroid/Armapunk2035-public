# M0 spike — Linux launch through Steam (2026-09-22)

Machine: owner's box (Gentoo, GE-Proton10-34, Arma 3 2.22).

## Command
```
steam -applaunch 107410 -noLauncher "-mod=Z:\home\timb\.local\share\armapunk-launcher\files\@Armapunk2035" -skipIntro -noSplash -world=empty
```

## Observed
- Process: `comm` = **`rvMain`** (Arma 2.22 names its main thread; `comm` is NOT the exe name),
  `args` = `Z:\home\timb\.local\share\Steam\steamapps\common\Arma 3\Arma3_x64.exe -mod=Z:\home\timb\.local\share\armapunk-launcher\files\@Armapunk2035 -skipIntro -noSplash -world=empty -malloc=system -debug`
- Steam appends the launch-options tail (`-malloc=system -debug`) AFTER the `-applaunch` args, so a
  stale `-malloc=` in launch options would override the launcher's; `steamcfg::managed_options`
  strips it.
- RPT: `…\armapunk-launcher\files\@Armapunk2035\addons\ap_vcity.pbo` loaded — an absolute `Z:\`
  mod path outside the game folder works (no symlink fallback needed). `Allocator: Windows`
  (from `-malloc=system`).
- After the process ended, no process matched.

## Rule for `launch::is_arma`
**argv[0]'s file name** (split on `\` and `/`) equals `arma3_x64.exe`, case-insensitive. Never
match on `comm` (`rvMain`), and never on "the command line contains the text": the first
end-to-end run proved a shell whose `grep` mentioned the exe made the launcher refuse with
"Arma 3 is already running". Command lines must be requested explicitly from sysinfo
(`ProcessRefreshKind::with_cmd`) — the default refresh leaves them empty.

# M1 acceptance, 2026-09-22 (headless core run: `launcher/core/examples/e2e_linux.rs`)

Release `2026.09.22-1` (83 files, 365 MB, signed with the test key) served from 127.0.0.1:8750.

- Verify + sync: all 83 files downloaded and hash-checked into `~/.local/share/armapunk-launcher/files`.
- Launch (auto-join off): Arma started through Steam with
  `-mod=Z:\…\armapunk-launcher\files\@Armapunk2035 -malloc=mimalloc_ap -hugePages -enableHT -exThreads=7 -skipIntro -noSplash -world=empty`.
- During the session the Arma folder held `dxgi.dll`, `d3dcompiler_47.dll`, `ReShade.ini`, `reshade-presets/`,
  `reshade-shaders/`, `reshade-addons/`, `Dll/mimalloc_ap.dll`; ReShade 6.8.0 initialised.
- After Arma exited: outcome `Exited`, `session.json` gone, every file path/type/size/mtime identical to the
  pre-launch snapshot (7,381 entries). Only the mtimes of the `Arma 3` and `Dll` directories changed (adding and
  removing entries updates a directory's mtime).

Bugs found and fixed on the way (both regression-tested):
1. sysinfo 0.39's default refresh leaves `cmd()` empty → Arma never detected → `NeverStarted` cleanup while the
   game was loading. `command_lines()` now requests cmd explicitly.
2. Substring matching made any shell mentioning `arma3_x64.exe` count as Arma → "already running". Match argv[0].

Still open (needs the owner / next milestones):
- **RPT shows `Allocator: Windows`**: Steam appends the launch options' `-malloc=system` after the launcher's
  `-malloc=mimalloc_ap`, and the last one wins. The UI's FIX (Steam closed) rewrites the launch options without it;
  not yet exercised because it needs Steam closed.
- The full UI click-through (SYNC → FIX → LAUNCH with auto-join) is the owner's acceptance run.
