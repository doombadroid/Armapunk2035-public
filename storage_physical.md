# Physical storage in the web STORAGE screen (houses)

**Date:** 2026-09-05
**Status:** implemented 2026-09-05, dev b0946 — **no client has pressed a key on it**
**Surfaces:** `fn_takeInventory.sqf`, `fn_storeInventory.sqf`, `fn_refreshInventory.sqf`,
`fn_storageBridge.sqf`, `fn_deckTrunk.sqf`, `ui/html/storage.html` (×2 copies)

## Problem

The web STORAGE screen (`AP_web_storage`, idd 938000) renders both manifests in physical
mode, but every mutation refuses:

```sqf
if !(AP_is_virtual) exitWith { createHashMapFromArray [["ok", false], ["msg", "physical moves aren't wired into this screen yet"]] };
```

`fn_storageBridge.sqf:234` (`stMove`) and `:294` (`stBulkVehicle`). The `⇄ SWITCH TO
PHYSICAL` toggle works — `stMode` flips `AP_is_virtual` and re-pushes — so the screen
offers a mode in which nothing can be moved.

## Root cause of the wider outage

The bridge's header comment justifies the refusal by claiming `fn_takeInventory` /
`fn_storeInventory` "take ZERO params" and read only TrunkMenu's listboxes. **That is
stale.** Both natives grew a DECK ROUTE:

```sqf
params [["_deckItem", "", [""]], ["_deckQty", "", [""]]];
private _fromDeck = _deckItem isNotEqualTo "";
```

and `fn_deckTrunk.sqf:85-87` already drives *physical house moves* through them.

But the physical branch of each native still reads the listbox for its quantity ceiling,
with no deck fallback:

| File | Line | Read |
|---|---|---|
| `fn_takeInventory.sqf` | 80 | `_maxValue = lbValue[4502, (lbCurSel 4502)]` |
| `fn_storeInventory.sqf` | 89 | `_maxValue = lbValue[4503, (lbCurSel 4503)]` |

Off dialog 4500 there is no such control. `lbValue` yields `0`, the next line clamps
`_quantity` to `0`, and the transfer loop `for "_i" from 1 to 0` runs zero iterations.
**Physical moves are a silent no-op on every route that is not TrunkMenu** — the deck
trunk app included. This is a pre-existing defect, not one introduced here.

Those `lbValue` reads are the values `fn_refreshInventory` writes at `:184` / `:192`:
`lbSetValue` = the item's count in that list. So the correct deck ceiling is the same
number, sourced from the caller.

## Decisions

| Question | Decision |
|---|---|
| Which containers get physical mode? | **Houses only.** |
| Take/store mechanism | **Reuse the natives** via the deck route; fix the ceiling. |
| Bulk TO VEHICLE in physical mode | **Wired**, landing in the vehicle's **real engine cargo**. |

### Why houses only

`fn_refreshInventory.sqf:9-11` is a hard bar:

```sqf
if (!_isVirtual && (_veh isKindOf "Car" || _veh isKindOf "Air" || _veh isKindOf "Ship")) exitWith {closeDialog 0;
    ["Physical inventory via this method is not allowed on vehicles! Please use the Arma 3 inventory method.", "basic"] spawn AP_fnc_handleMessage;
};
```

`fn_deckTrunk.sqf:79` mirrors it. The rule is structural, not cosmetic: a vehicle already
owns real engine cargo, so a parallel script-side `AP_pinv` would give one rifle two
homes — the dupe shape CLANKR watches. A house has no engine container, which is why
`AP_pinv` exists for it at all. This design does not override that bar in any of the three
places it appears.

### Why reuse over reimplementation

`fn_storeInventory`'s physical branch is ~130 lines of per-slot logic (rifle / launcher /
pistol / headgear / goggles / vest / backpack / uniform / NVG / attachments-by-prefix),
carrying named regression fixes: #288 disconnect-dupe, #328/#341 bipod loss, #369 loose
attachments, #545 second-backpack loss, #581 launcher missiles. `fn_takeInventory` carries
the matching set plus the **cop seize path** (`AP_effSide isEqualTo west && House_F` →
forced `_quantity = 1`, illegal items routed into the nearest police vehicle with a server
broadcast). A second copy would silently drop all of it. The repo's own comment at the top
of `fn_takeInventory` states the rule: *"One copy of the transfer logic — this is CLANKR's
most-watched surface and a second copy is how dupes are born."*

## Design

### 1. Deck-route quantity ceiling (both natives)

Add an optional third deck parameter; use it only on the deck route:

```sqf
params [["_deckItem", "", [""]], ["_deckQty", "", [""]], ["_deckMax", -1, [0]]];
...
private _maxValue = if (_fromDeck) then { _deckMax } else { lbValue[4502, (lbCurSel 4502)] };
```

- `fn_takeInventory` — caller passes the qty of that class in the container's `AP_pinv`.
- `fn_storeInventory` — caller passes the qty the player holds (worn + carried tally).

Neither native grows a tally of its own; the callers already computed these numbers to
render their manifests. A `_deckMax` of `-1` (default, deck route, caller supplied
nothing) must be treated as "no ceiling supplied" and fall back to the listbox read, so
an un-updated caller behaves exactly as today rather than newly clamping to `-1`.

### 2. `fn_refreshInventory` deck-route guard

Today the early exit covers only the deck display:

```sqf
if (isNull (findDisplay 4500) && {!isNull (findDisplay 937500)}) exitWith { ... push "trunk" ... };
```

With STORAGE open (938000) and no 4500, control falls through to
`(findDisplay 4500) displayCtrl 4502` → `controlNull`, and the following `lbClear` /
`ctrlSetText[4504, ...]` throw. The natives call `AP_fnc_refreshInventory` at the end of
every move, so each physical move would spray the RPT. Widen the guard to dispatch by
which web display is open:

```sqf
if (isNull (findDisplay 4500)) exitWith {
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (isNull _c) exitWith {};
    if !(isNull (findDisplay 937500)) exitWith { [_c, "trunk", (["data"] call AP_fnc_deckTrunk)] call webui_fnc_push; };
    if !(isNull (findDisplay 938000)) exitWith { [_c, "storage", (call (uiNamespace getVariable "AP_storageData"))] call webui_fnc_push; };
};
```

No new function: `fn_storageBridge` already parks its data builder in
`uiNamespace` as `AP_storageData`, and the bridge itself pushes through exactly this call.

Ordering note: this exit must stay **before** the dead-vehicle `closeDialog 0`, for the
reason the existing comment gives — a despawn must not shut the whole phone.

### 3. `fn_storageBridge.sqf`

**`stMove`** — replace the blanket refusal with a house gate, then delegate:

- refuse physical when the container is neither `isKindOf "House_F"` nor
  `(typeOf _c) in AP_houseTypes`, reusing the native's own wording so the message a
  player sees is the same one TrunkMenu gives.
- compute `_max`: for `take`, the qty of that class in the container's `AP_pinv` (read
  directly); for `store`, the qty in the player's physical tally (see below).
- `call` the native with `[_itemId, str _qty, _max]`, then push the storage channel.
  `AP_is_virtual` is **not** touched here — `stMode` already set it to match the screen,
  and it must stay that way across successive moves. (This differs from
  `fn_deckTrunk`'s batch verb, which flips the global per queued move and resets it to
  `true` at the end because one batch may mix both kinds.)

**Player physical tally.** Three copies of this walk already exist —
`fn_refreshInventory`'s `_pCache`, the bridge's `_data` builder, and
`fn_refreshAdminInventory` — and `stMove` needs a fourth unless it is shared. The bridge's
copy lives inside the code block parked in `uiNamespace`, so a file-scoped `private` is
not visible to it at call time. Extract one small mission function,
`AP_fnc_physTally` (player worn + carried gear → `[[classname, qty], ...]`), and call it
from both the bridge's data builder and `stMove`. `fn_refreshInventory`'s copy is left
alone — changing TrunkMenu's rendering is outside this work.

Quantity travels as the **string** the natives expect from `ctrlText` — the same
convention `fn_deckTrunk.sqf:85-87` uses.

**`stBulkVehicle`** — add a physical branch mirroring the virtual one's discovery,
eligibility and reservation walk (nearest keyed vehicle ≤ 25 m, unlocked, not in use, not
seizing), but landing in real engine cargo, dispatched by class kind:

- `CfgWeapons` weapon → `addWeaponCargoGlobal`
- backpack (`CfgVehicles`, `isKindOf "Bag_Base"`) → `addBackpackCargoGlobal`
- everything else → `addItemCargoGlobal`

Headroom is the vehicle's `maximumLoad` against current `load`, not `AP_vcap`. Partial
fit is allowed; only the quantity that actually landed is removed from the house
`AP_pinv`, and the house's physical weight is recomputed with
`AP_fnc_physicalInventoryWeight` rather than arithmetic on the old total.

**`stMode`** — refuse `"physical"` unless the active container is a house.

**Header comment** — the "take ZERO params" paragraph is factually wrong and gets
rewritten to describe the deck route and the ceiling fix.

### 4. `fn_deckTrunk.sqf`

The batch verb passes no ceiling, so its physical moves are subject to the same no-op.
Pass `_deckMax` from the data the `"data"` verb already builds (`_phys` for takes, `_mine`
for stores). Three lines; it repairs an existing shipped path rather than leaving a known
dead one behind.

### 5. `storage.html` (mission + server copies)

The pushed `storage` payload gains one field:

```
AP.on("storage", { mode, cont, house, conts:[...], you:{...} })
```

`house` is a boolean. The page hides the `⇄` toggle when it is false, rather than
offering a switch whose only outcome is an error string. The page's documented CONTRACT
block is updated to match.

Both copies — `mission/Armapunk2035.Malden/ui/html/storage.html` and
`server/AP_server/web/ui/html/storage.html` — are updated identically, so the sha1
handshake reports `unchanged` and no 121 KB hot-serve transit happens on open.

## Out of scope

- **Physical DROP.** The page hint reads `DROP IS PHYSICAL ONLY`, but TrunkMenu's drop
  buttons (4521 / 4522) were never given a bridge verb, and the CONTRACT block lists no
  drop call. The hint stays; the verb is a follow-up.
- **Vehicle physical mode**, per the decision above.
- **`fn_takeInventory` physical gear-save asymmetry.** `fn_storeInventory`'s physical
  branch persists (`[false] call AP_fnc_saveGear` + `[3] call AP_fnc_ClupdatePartial`,
  added for #288); the take branch calls only `AP_fnc_refreshInventory`. Taking physical
  gear out of a house therefore leaves the player's DB `*_gear` row stale until some
  other save fires. This is pre-existing on the TrunkMenu path too and is recorded here
  as an observation, not changed by this work — it wants its own root-cause pass.

## Testing

No test harness exists for mission SQF; verification is structural gates plus an in-game
pass. Structural, before deploy:

- `tools/sqf_equiv` / brace and syntax gates over each touched `.sqf`.
- Both `storage.html` copies byte-identical (`cmp`).
- `grep` confirms no remaining `lbValue[450[23]` read that lacks a deck fallback.

In-game, dev server, at an owned house (`[AP-PROBE]` lines to the client RPT):

1. Open STORAGE at a house, press `⇄` → physical manifests render, toggle stays visible.
2. Open STORAGE at a keyed vehicle → `⇄` is **absent**.
3. Physical TAKE 1 of a stored item → it lands in the correct slot, house `AP_pinv` drops
   by exactly 1, no RPT error from `fn_refreshInventory`.
4. Physical TAKE with qty 10 / MAX on a stack → clamps to what is present, never 0
   (the regression this fixes).
5. Physical STORE a worn vest → migrates with contents per the native's rules; store a
   second backpack → refused with the #545 message, item stays in inventory.
6. Store a rifle with a bipod + suppressor → both stored (#328/#341), then take it back →
   attachments re-mount.
7. As a cop at a house: physical take is forced to qty 1 and illegal items route to the
   nearest police vehicle with the broadcast — unchanged from TrunkMenu.
8. Bulk TO VEHICLE in physical mode → gear appears in the vehicle's **native** inventory,
   `load` respected, partial fit leaves the remainder in the house.
9. Close the screen → `APS_fnc_updateHouseTrunk` persists; reopen shows the same contents.
10. Deck trunk app, physical move at a house → now moves (previously a no-op).

## Risks

- The natives are the codebase's most dupe-sensitive surface. Every change here is
  additive and gated on `_fromDeck`; the TrunkMenu path must be byte-equivalent in
  behaviour, and that is the first thing to verify.
- `_deckMax` defaulting must not newly clamp existing callers to zero — hence `-1` meaning
  "fall back to the listbox".
- Engine-cargo bulk is the one genuinely new mechanism; it has no native precedent to
  mirror, so its headroom maths and partial-fit accounting need the closest review.

---

## State (2026-09-05)

Built and committed on `main`. `run_checks.sh` 36/37 — the one failure is
`fab_check`'s pre-existing printer preview-class clash, unrelated and already
recorded in HANDOFF. Dev boot on b0946 is clean: every touched `.sqf` compiled,
zero `Error in expression` since boot.

**What is actually verified:** the suite-rent half, because it runs on a server
clock with nobody present. The 10:57:45 sweep reached its repossession query and
its summary line — both of which sit *after* the line that used to throw, so the
log proves the abort is gone rather than just the message.

**What is not:** every line of the storage feature. It needs a client, and the
testing section above is the script. Items 3, 4 and 8 are the ones that matter
most — 4 is the regression this whole change exists to fix (a physical take with
qty 10 or MAX clamping to what is present instead of to zero), and 8 is the only
mechanism here with no native precedent to have copied.

The deck trunk app's physical moves were repaired as a side effect and want the
same qty-clamp check (item 10).
