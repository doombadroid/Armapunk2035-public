# Inventory 4a (I-screen + Gunsmith) — build plan

> Design: `INVENTORY_SPEC.md` §9 (build design), §4 (contract), Appendix A (engine hazards).
> Execution: inline, this session (autonomous handoff 2026-09-03). Steps use `- [ ]`.

**Goal:** one HTML screen on `I` that shows worn gear, the three containers, what is in reach and the
virtual bag, with drag/drop moves, and a GUNSMITH mode for the primary/handgun (attachments + mag).

**Architecture:** `inventory.html` (deck grammar) ↔ `fn_invBridge` (webui) ↔ own-body moves local
(`fn_invLocal`, `fn_invGunsmith`) / shared cargo through ONE server fn (`APS_fnc_invCargo`, atomic).
Every mutation ends in `fn_invCommit` (Take/Put replication, saveGear, re-push).

**Tech:** SQF (Arma 3 2.22), arma-webui bridge (`webui_fnc_*`), self-contained HTML (no libs).

## Global constraints (from the spec / CLAUDE.md)

- One self-contained `.html`; no `<script src>`, fetch, XHR, localStorage. LMB + wheel only; modifiers
  only via `window.__mods`. Everything rem; `html{font-size:clamp(9px,1.22vw,22px)}`.
- Never `innerHTML` an unchanged list on push; stable element per item id.
- Every mutation is a request → `{ok,msg}` → push. Refusal string comes from SQF. Strip 5 s.
- Own-body moves client-local; vehicle/crate/existing-holder cargo ONLY through `APS_fnc_invCargo`.
- After every physical mutation: onTake/onPut replication + `[false] call AP_fnc_saveGear` +
  `[3] call AP_fnc_ClupdatePartial` (`fn_invCommit`).
- Server actor = `remoteExecutedOwner`, never the payload. CfgRE whitelist entries for both new fns.
- New client fn → `Functions.h`; new server fn → `server/AP_server/config.cpp`.
- Channel names: `[A-Za-z_][A-Za-z0-9_.-]*` (dots, never colons).
- Commit trailer per CLAUDE.md (defunct-AI Co-Authored-By, rotate; no Anthropic trailer).
- Dialog `UI_GRID_*` coords bare, never quoted. `mission.sqm` untouched.

## Contract (both halves build against THIS — copy, don't paraphrase)

**Push `inventory`** = spec §4a object. Physical row:
`{id, cls, name, icon, kind, mass, qty, ammo, cap, socket, wide, loc}`
- `kind` ∈ `weapon mag attach item uniform vest backpack headgear facewear binocular nvg assigned`
- `loc` ∈ `uniform vest backpack container ground:<netId>`; `id = loc + "|" + cls + "|" + ammo`
  (`ammo` = round count for mags, `-1` otherwise; `cap` = mag capacity or 0)
- `socket` ∈ `muzzle optic pointer bipod` for `attach`, else `""`; `wide` true for weapons
Slot object: `{id:"slot|<slot>|<cls>", cls, name, icon, mass, kind, wide, mag:{cls,name,ammo,cap}|null,
sockets:{optic|muzzle|pointer|bipod: {cls,name,icon}|null}}` (only sockets the weapon has).
`you.containers[] = {id:"uniform"|"vest"|"backpack", label, cls, load, cap, items[]}`.
`you.bag = {load, cap, items[{id,name,icon,qty,wt,total,sell,illegal,canDrop,desc}], odd[{name,qty}]}`.
`ground = {dist, physical[rows with loc "ground:<netId>"], virtual[{case,id,name,icon,qty,wt,despawn}]}`.
`container = null | {id:netId, label, sub, load, cap, items[], lockedNote}`. `players[{uid,name,dist}]`.
`you = {name, side, flags:{overweight,restrained,inVehicle}, slots:{…, assigned:{map,gps,radio,compass,watch,nvg}}, containers, bag}`.

**Push `gunsmith`** = `null` | `{slot, weapon:{cls,name,icon,mass,wide}, sockets:[{type,item:{cls,name,icon}|null}],
mag:{cls,name,ammo,cap}|null, magsInContainers, fits:[{id,cls,name,icon,mass,socket,loc,source}]}`.

**Calls** (all → `{ok, msg}`; a push follows every call):
```
invMove       [fromLoc, id, toLoc, qty]   toLoc: uniform|vest|backpack|ground|container|<slot>
invEquip      [id]                        put it where it belongs (returns {ok,msg,to})
invUnequip    [slot]
invOpenWeapon [slot]                      slot: primary|handgun  → pushes gunsmith
invMount      [id, slot, socket]          socket "" = auto by item type
invDetach     [slot, socket]
invUnload     [slot]
invReload     [slot, id]                  id "" = best mag in containers
invCloseWeapon[]                          → pushes gunsmith null
bagUse [id] · bagGive [id, qty, uid] · bagDrop [id, qty] · groundTake [case, id, qty]
invRefresh [] · invClose [] · log [msg]
```

---

### Task 1 — the page `ui/html/inventory.html` (+ offline harness)

**Files:** create `mission/Armapunk2035.Malden/ui/html/inventory.html`;
create `scratchpad/inv_harness/inv_harness.mjs`.
**Consumes:** contract above. **Produces:** the page; dev stub implements every call against §7 data.

- [ ] Write the page: shim (copy of storage.html's, `"inventory page up"`), `:root` tokens (deck
      `.tal` values are the defaults per the handoff — cop palette; civ = the acid palette from §2
      applied when `you.side != "cop"` via `body.civ`), grammar CSS (`.panel .ph .row .act .status
      .kv .chip .lb .meta`), layout (4 columns 1.45/1/.95/.95), WORN figure + 8 slot cards + leader
      SVG + ASSIGNED, containers ×3, reach (vehicle/ground/selected), bag (search/list/acts),
      GUNSMITH panel, `.ghost`, `.ovl` GIVE picker, wheel shim.
- [ ] JS: `syncList(el, rows, key, make, update)`; `render()` from `S.inv` + `S.gs`; pointer drag
      (down → 6 px → ghost; `elementFromPoint` → `[data-drop]`; `canDrop(item, target)` matrix from
      §5a + gunsmith rules; release → call; refused → snap + `say(msg,false)`); double-click routes;
      SELECTED actions + AMOUNT stepper; `+1` chips; search filter; textures cached; Esc handled
      game-side (no page Esc handler); `closeGunsmith()` exposed for SQF exec.
- [ ] Dev stub (`typeof AP === "undefined"`): §7 sample data, every call mutates the stub state and
      re-pushes, refusals for the §9 strings.
- [ ] Observe red: `node --check` on the extracted script before the stub is wired (page must at
      least parse); `python3 tools/html_js_check.py` → `all ui/html scripts parse`.
- [ ] Harness: puppeteer (npx cache path from `scratchpad/serve_harness`), viewport 1600×880 and
      1280×704, screenshot both, assert `document.body.scrollWidth <= clientWidth`, dblclick the
      PRIMARY card → `#gs` visible, drag a FITS row onto `[data-drop="sock:optic"]` → stub log has
      `invMount`, type in the bag search → list filters, no `pageerror`. Run: `node
      scratchpad/inv_harness/inv_harness.mjs` → prints `PASS` lines.
- [ ] Commit: `feat(inventory): the I-screen page (4a: figure overlay + gunsmith)`.

### Task 2 — readers: `fn_invItemInfo`, `fn_invCargoRead`, `fn_invSnapshot`

**Files:** create `core/inventory/fn_invItemInfo.sqf`, `fn_invCargoRead.sqf`, `fn_invSnapshot.sqf`;
modify `Functions.h` (class inventory: add `invItemInfo invCargoRead invSnapshot`).
**Produces:** `[cls] call AP_fnc_invItemInfo` → hashmap `{name, icon, mass, kind, socket, wide, cap}`
(cached in `uiNamespace AP_invInfoCache`); `[obj, locTag] call AP_fnc_invCargoRead` → array of row
hashmaps (loc/id set); `[] call AP_fnc_invSnapshot` → the `inventory` hashmap.

- [ ] `fn_invItemInfo`: config lookup order CfgMagazines → CfgWeapons → CfgVehicles → CfgGlasses;
      mass rules §9.3; kind rules §9.3; `icon` = `picture` with a leading `\` stripped (storage
      pattern); `cap` = `CfgMagazines>>count`.
- [ ] `fn_invCargoRead`: `magazinesAmmoCargo` → group by [cls, ammo]; `weaponsItemsCargo` → one row
      per weapon (qty 1, `wi` kept in a parallel `uiNamespace AP_invWI` map keyed by id for the
      mutators); `getItemCargo` → group; `getBackpackCargo` → group. Row order: weapons, mags,
      attachments, items, clothing.
- [ ] `fn_invSnapshot` per §9.3 (uses `["inv"] call AP_fnc_deckData` for the bag).
- [ ] Observe (in-game, after Task 3 deploy): `gamectl.py sqf "diag_log str ([] call AP_fnc_invSnapshot)"`
      → RPT shows the hashmap with three containers and the worn slots; a partial mag shows its count.

### Task 3 — dialog + open + bridge (READ-ONLY milestone)

**Files:** create `dialog/web_inventory.hpp`, `core/inventory/fn_invOpen.sqf`,
`core/inventory/fn_invBridge.sqf`; modify `dialog/MasterHandler.h` (include), `Functions.h`,
`evh/fn_inventoryOpened.sqf` (two edits + force-native), `evh/fn_keyDownHandler.sqf` (CTRL+SHIFT+I).

```c
// dialog/web_inventory.hpp
class AP_web_inventory {
    idd = 938500; name = "AP_web_inventory"; movingEnable = false; enableSimulation = true;
    onLoad = "[_this select 0] spawn AP_fnc_invBridge;";
    class controls {
        class Page {
            idc = 938501; type = 106; style = 0;
            x = -20 * UI_GRID_W + UI_GRID_X; y = -11 * UI_GRID_H + UI_GRID_Y;
            w  =  40 * UI_GRID_W;            h =  22 * UI_GRID_H;
            colorBackground[] = {0,0,0,0}; colorText[] = {1,1,1,1};
            font = "RobotoCondensed"; sizeEx = 0.6 * UI_GRID_H;
            url = "ui\html\inventory.html";
        };
        #include "..\webui\config\prompt_overlay.hpp"
    };
};
```
- [ ] `fn_invOpen [_container]`: restrained / `AP_action_in_use` / dialog-already-open guards;
      `uiNamespace setVariable ["AP_invContainer", _container]`; reserve `AP_veh_in_use` when non-null;
      `createDialog "AP_web_inventory"`.
- [ ] `fn_invBridge`: init, serve `ui\html\inventory.html`, 40×22 geometry (armory block verbatim),
      handlers `inventory` (data), `log`, `invRefresh`, `invClose`; every mutation verb registered
      here but delegating to Task 4–7 fns; KeyDown EH (Esc/I; gunsmith-open swallow); Unload EH
      (release lock, stop watcher, `AP_action_in_use = false`); watcher `spawn` loop (1 Hz signature);
      first push.
- [ ] `fn_inventoryOpened`: top: `if (missionNamespace getVariable ["AP_invForceNative", false]) exitWith { AP_invForceNative = false; false };`
      `isNull _container` branch → `[objNull] spawn AP_fnc_invOpen; true`;
      tail (after the reservation) → `[_container] spawn AP_fnc_invOpen; true` — keep the guard
      chain, delete the 602 waiter (the bridge's Unload releases the lock).
- [ ] `fn_keyDownHandler`: `_code in [21, 20]` → `[21, 20, 23]`; branch `23` →
      `AP_invForceNative = true; player action ["Gear", objNull];`.
- [ ] Deploy: `bash /home/timb/arma3server_dev/reload-armapunk2035.sh` → `grep "read from bank"`.
- [ ] Observe (in-game): press I → web screen, RPT `[INV] page build`, no `Undefined variable`; look
      at a vehicle + I → reach panel filled; CTRL+SHIFT+I → native 602.
- [ ] Commit: `feat(inventory): I opens the web inventory (read-only), CTRL+SHIFT+I = native`.

### Task 4 — own-body mutations `fn_invLocal` + `fn_invCommit`

**Files:** create `core/inventory/fn_invLocal.sqf`, `core/inventory/fn_invCommit.sqf`; `Functions.h`.
**Produces:** `[verb, args] call AP_fnc_invLocal` → `{ok,msg}`; verbs `move [from,id,to,qty]`,
`equip [id, slot]`, `unequip [slot]`, `swapWorn [id, slot]`, `spill [rows]`;
`[tookRows, putRows] call AP_fnc_invCommit` (each `[containerObj, cls]`).

- [ ] Helpers inside `fn_invLocal`: `_contOf loc` (uniformContainer/vestContainer/backpackContainer),
      `_parseId id` → `[loc, cls, ammo]`, `_findRow loc id` (via `fn_invCargoRead`), `_removeOwn`,
      `_addOwn` (per §9.4; `canAdd` first), `_firstRoom row` → loc or "".
- [ ] `move`, `equip` (weapon/headgear/facewear/binocular/assigned/clothing→swapWorn), `swapWorn`
      (hazard 3 + textures + invisBag), `unequip`, `spill` (forceDropItem pattern + setCleanTime 450).
- [ ] `fn_invCommit`: spawn onTake/onPut per row, then `[] spawn { uiSleep 0.2; [false] call
      AP_fnc_saveGear; [3] call AP_fnc_ClupdatePartial; }`, then push `inventory` (+ `gunsmith`).
- [ ] Bridge handlers `invMove` (own-body locs → invLocal; ground/container → Task 6), `invEquip`,
      `invUnequip`.
- [ ] Observe (in-game): drag a FAK vest→backpack: vest row count −1, backpack +1, RPT `-STOREDITEM-`
      then `-TOOKITEM-`; drag a 17/30 mag: count preserved; equip a spare uniform with a full old
      uniform: contents migrate, RPT lists the spill; drop 3 mags onto the ground when backpack
      full → `GroundWeaponHolder` appears (native I confirms).
- [ ] Commit: `feat(inventory): own-body moves, equip, worn-container swap`.

### Task 5 — gunsmith `fn_invGunsmith`

**Files:** create `core/inventory/fn_invGunsmith.sqf`; `Functions.h`.
**Produces:** `[verb, args] call AP_fnc_invGunsmith` → `{ok,msg}`; `["data", slot] call` → payload.
- [ ] `open`, `data`, `mount`, `detach`, `unload`, `reload`, `close` per §9.4; socket type from
      `ItemInfo>>type`; presence from `WeaponSlotsInfo` subclasses (`MuzzleSlot CowsSlot PointerSlot
      UnderBarrelSlot`); compat = `[wpn] call BIS_fnc_compatibleItems`; mag compat =
      `getArray (cfg >> "magazines")` (+ muzzles' magazines, the fetchCfgDetails walk).
- [ ] Bridge handlers `invOpenWeapon invMount invDetach invUnload invReload invCloseWeapon`;
      `uiNamespace AP_invGsOpen`.
- [ ] Observe: dblclick PRIMARY → gunsmith; mount an optic from the backpack → `weaponAccessories`
      shows it, backpack row gone; mount another optic → the first returns to the backpack; UNLOAD →
      vest gets the 23/30 mag; RELOAD → fullest mag loaded, previous back with its count.
- [ ] Commit: `feat(inventory): GUNSMITH — sockets, magazine, displacement`.

### Task 6 — server cargo arbiter `APS_fnc_invCargo` + `AP_fnc_invCargoRecv`

**Files:** create `server/AP_server/core/TON/fn_invCargo.sqf`, `core/inventory/fn_invCargoRecv.sqf`;
modify `server/AP_server/config.cpp` (`class invCargo {};` in TON), `Functions.h`, `CfgRE.hpp`
(`class APS_fnc_invCargo {allowedTargets = 2;};`, `class AP_fnc_invCargoRecv {allowedTargets = 1;};`).
**Produces:** client helper `[verb, target, spec] call AP_fnc_invCargoAsk` (inside fn_invBridge:
ticket = `AP_invTicket + 1`, `[[ticket, verb, netId target, spec], "APS_fnc_invCargo", 2] call
AP_fnc_MP`, `waitUntil` ticket answered or 5 s) → `{ok,msg,extra}`.

```sqf
// atomic block skeleton (server)
private _res = [false, "nothing happened"];
isNil {
    // read cargo, find unit, rebuild without it, add to player (canAdd) -- no sleeps in here
    _res = [true, "..."];
};
```
- [ ] Verbs `take store drop pickup` per §9.4; reach/lock validation; backpack contents preserved
      across rebuild (`everyBackpack` before/after); holders: reuse within 2 m else create;
      `[_h, 450] call APS_fnc_setCleanTime`.
- [ ] `fn_invCargoRecv [ticket, ok, msg, extra]`: `if (remoteExecutedOwner != 2) exitWith {}`;
      `AP_invTickets set [ticket, [...]]`.
- [ ] Bridge: `invMove` with `to`/`from` = container | ground → ask; `invEquip` from reach → `take`
      into a staging container, then local equip.
- [ ] Observe: with a keyed Offroad: store 2 mags → `magazinesAmmoCargo veh` shows them, vest −2;
      take the MX → in backpack? no — into the primary slot via `addWeaponGlobal` + attachments;
      two clients (owner + HC not possible) → single-client race: spam-click take ×5 on one item →
      exactly one succeeds, rest `that item is gone`.
- [ ] Commit: `feat(inventory): one server function owns vehicle/crate/ground cargo moves`.

### Task 7 — virtual verbs + polish + docs

- [ ] Bridge `bagUse bagGive bagDrop groundTake` (§9.4), `players` ≤ 5 m.
- [ ] `HANDOFF.md`: add the I-screen state line; `INVENTORY_SPEC.md` §9 stays the design.
- [ ] Full checks: `tools/html_js_check.py`, `tools/fn_check.py`, `tools/dialog_reachability.py`,
      brace balance; deploy; in-game pass of §9.6.
- [ ] Commit: `feat(inventory): bag verbs on the I-screen; docs`.

## Self-review

- Spec coverage: §5a drag matrix → T4/T6 (+ virtual T7); §5b quantity → T1 (+1, AMOUNT); §5c
  buttons → T1 SELECTED; §5d bars → T1; §5e states → T1 (loading/idle/drag/in-flight/refused/
  locked/empty/tal); §5f search → T1; hazards 1–7 → T4 commit, T6 arbiter, T4 swapWorn, T4 role
  items via onTake, T1 mods, shim textures, T3 watcher; handoff Gunsmith → T5/T1.
- Riskiest unverified plan code: `addWeaponGlobal` on a remote unit + `addWeaponItem` from the
  client afterwards (T6); `clearMagazineCargoGlobal` on `uniformContainer player` (T4);
  `player action ["Gear", objNull]` re-firing InventoryOpened (T3). Each has an observe step.
- Lifecycle owners: `AP_veh_in_use` — fn_inventoryOpened sets, the bridge Unload releases (the 602
  waiter is deleted so there is one releaser). `AP_action_in_use` — fn_inventoryClosed no longer
  fires for us; the bridge Unload resets it. `AP_inUse` on suitcases — held per call only.
- Artefact paths: `ui/html/*` is whitelisted for `url=`; the served copy is published by the reload
  script only for files already in the web root (add `inventory.html` there after the first deploy
  so live edits work).
