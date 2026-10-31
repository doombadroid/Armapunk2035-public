# Spawn screen on the 3D map — design

Owner handoff: `spawn.zip` (`recolor/spawn/spawn.html` + `README.txt`), 2026-09-11.
Owner instruction: "use the 3d map for it and impliment it on live".

The handoff is a SPOOL MK-II deck mockup: satmap-mosaic pane + pin list + deploy
progress button. The mosaic pane is an explicit placeholder ("AP.texture SATMAP
MOSAIC"). This design replaces that placeholder with the real 3D renderer and
wires the page to the spawn system that already exists.

## What exists today

| piece | where |
|---|---|
| spawn menu | native dialog 38500 (`dialog/spawnSelection.hpp`), list 38510 + map control 38502 |
| redeploy menu | `class redeploy_selection`, ALSO idd 38500 |
| row builder | `AP_fnc_spawnPointCfg` — per-side rows `[marker, label]`, filters unusable rows OUT |
| selection | `AP_fnc_spawnPointSelected` sets `AP_spawn_point`, moves the map control |
| teleport | `AP_fnc_spawnConfirm` — 50 km hold release, `setPosATL`, post-release settle loop, `[TPTRACE]` |
| openers | `fn_spawnMenu` (4 call sites), `fn_redeployMenu` (3 call sites) |
| 3D renderer | `ui/html/grid3d.js` — heightfield, terrain, sea, satellite atlases, mesh library, building batcher. Shared by `map.html` and the HUD minimap. |
| web bridge | `webui_fnc_init/on/push/serve`, pages under `ui/html/`, already whitelisted by `ui\html\*` |

## Decisions (owner, 2026-09-11)

1. **Scope: all of it.** First spawn, respawn, redeploy; civilian, MaxSec, Trauma.
2. **Camera: fly-to.** Island overview on open, ~420 ms animation to the selected
   point at building-height tilt. Drag-orbit and wheel zoom. No search, no
   waypoints, no group blips, no cartel rings, no admin layer.
3. **Locked rows: shown, greyed, with the reason in place.** This CHANGES
   behaviour — today an unusable point silently vanishes from the list.
4. **Rollout: kill switch plus native fallback, straight to live on .96.**

## Architecture

```
fn_spawnMenu / fn_redeployMenu
  └─ AP_fnc_spawnWebOpen  ── declines ──▶ native dialog 38500 (unchanged)
       │ takes the screen
       ├─ dialog AP_web_spawn (938700) ─ onLoad ─▶ AP_fnc_spawnWebBridge
       │                                            ├─ spawnReady  → push "spawn"
       │                                            ├─ spawnDeploy → AP_fnc_spawnConfirm
       │                                            └─ spawnCancel
       └─ ui/html/spawn.html ─ loads ─▶ ui/html/grid3d.js (shared renderer)
```

### New SQF

**`AP_fnc_spawnPointList [_isRedeploy]`** — the one source of rows. Returns an
array of hashmaps: `id`, `label`, `kind` (`home`/`city`/`duty`/`gang`/`hot`),
`x`, `y`, `near` (players within 500 m), `reason` (empty = usable).

It calls `AP_fnc_spawnPointCfg` with a new third parameter `_withReasons`. With
the flag the builder keeps rows it would have dropped and appends a reason
string; without it the function behaves exactly as it does today, so the native
menu's list does not move. Positions are resolved the same way
`fn_spawnConfirm` resolves them — marker position, Mobile HQ's literal position,
the persisted gang HQ position, the `phouse_` id fallback — and a row that still
resolves to `[0,0,0]` is returned with a reason rather than a pin in the sea.

**`AP_fnc_spawnWebOpen [_isRedeploy]`** — returns `true` when it took the
screen and has already blocked until the player deployed or closed, `false`
when it declined. Declines for: unscheduled caller, no interface,
`SRV_spawnWebEnabled` false, the webui library absent, `createDialog` failing,
the display never appearing. Every decline falls through to the native dialog.

**`AP_fnc_spawnWebBridge [_display]`** — dialog onLoad. Wires three verbs and
re-pushes the row payload on a 2 s poll while the display lives, so a point that
becomes contested while the menu is open greys out in place. That poll replaces
the `waitUntil`-on-`AP_disabled_spawns` thread the native menu spins.

### Deploy path

`spawnDeploy [id]` rebuilds the list, finds the row, refuses with the row's
current reason if it has one, writes `AP_spawn_point` in the
`[marker, label]` shape `fn_spawnConfirm` already expects, and calls
`[_isRedeploy] call AP_fnc_spawnConfirm`. The hold, the teleport, the settle
loop and the `[TPTRACE]` line are not touched. That loop is the fix for players
falling 50 km on spawn; re-implementing the teleport would put it back at risk.

### The page

`ui/html/spawn.html`, built from the owner's mockup. Kept: the SPOOL MK-II
chrome, the pin/list/deploy layout, the deploy-button-as-progress-bar, the
`.tal` palette for duty sides, the WAKE PROTOCOL boot overlay. Changed: the
mosaic pane becomes a WebGL canvas plus a 2D overlay driven by `grid3d.js`.
Deleted: the dev `#demo` strip, per the handoff README.

The camera block is a reduced copy of `map.html`'s — same calibration
constants, same `camMat`/`project` path through `R.setProjection`, same boot
chain order (renderer, atlases, sea, heightfield, satellite atlases,
buildings, late mesh/fence feeds). It is a copy and this design says so: the
shared half is `grid3d.js`, and extracting `map.html`'s camera into a second
shared module is a larger refactor than this task earns. The reduced set is
smaller than the original, not a superset.

**The camera targets the selected spawn, never the player.** During the spawn
menu `fn_spawnMenu` holds the player frozen at map centre at 50 km, so
`map.html`'s `homeOnSelf` would aim the camera at empty sky. The page homes on
the first row of the first payload instead.

**The loading layer.** `fn_spawnMenu` cuts `AP_loadingScreen` before opening the
dialog. The page carries its own WAKE PROTOCOL overlay, and native layers do not
composite above a browser control, so the web path cuts that layer down and lets
the page own the screen. Verified in game, not assumed.

### Reason strings

| reason | when |
|---|---|
| `DISABLED BY STAFF` | id is in `AP_disabled_spawns` |
| `TAXES UNPAID` | house or gang building with `AP_house_tax` set |
| `CONTESTED — ACTIVE WAR ZONE` | within 800 m of an active turf, 600 m of a cartel |
| `CONTESTED — ACTIVE HEIST` | within 800 m of the live jewellery emporium |
| `POSITION UNRESOLVED` | the row resolves to `[0,0,0]` |

Turf, cartel and heist rows deliberately share generic text. Naming the event
would tell a spawning player where a heist is running, which the current hidden
behaviour does not leak.

## Security

Nothing new is authorised. The page picks an id from a list the client already
had and the deploy path is the same `AP_fnc_spawnConfirm` the native button
calls. Anyone who can run JS in the page could already call `spawnConfirm` from
the debug console. No new `CfgRemoteExec` entry, no new server function. The
reason strings are computed client-side exactly as `spawnPointCfg` computes its
filters today, so a faked reason only lets a client refuse its own spawn.

## Verification

1. Offline: headless Chrome against the page's standalone `A3API` stub. Asserts
   the renderer boots, pins project, fly-to animates, locked rows are greyed and
   unclickable.
2. In game on .96: first connect, death respawn, cop redeploy, each of the three
   sides, a deliberately disabled spawn point, and the `[TPTRACE]` line showing
   the settle loop still runs on a web-path deploy.
3. Kill switch: `SRV_spawnWebEnabled = false` returns the native dialog with no
   repack.

## Out of scope

Spawn-point pricing, new spawn points, the intake path (it owns a fresh
account's first login and declines the landing screen for the same reason), and
`map.html`'s own chrome.
