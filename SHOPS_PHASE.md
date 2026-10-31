# Shops / storage phase — scope and order

Four dialogs left from the design delivery. The virtual shop (THE CLIP) is
done and in game; it proved the pattern — new page, new dialog, one hooked
entry point, money recomputed in SQF.

## Order, and why

**1. Weapon shop (ARMORY) — replaces weaponShop.hpp, idd 39400**

`fn_weaponShopBuy` is coupled to three listboxes on 39400 (filter 39402, main
39404, side 39405) — the same narrow shape as the virtual shop, so the same
re-plumb works.

The catalogue is the interesting part: for `rebelwep`, `police_weapons` and
`swat_weapons`, `fn_weaponShopCfg` BUILDS ITSELF AT RUNTIME from `CfgWeapons`
— every scope-2 rifle/MG/sniper/SMG plus handguns, one entry per unique
display name to kill camo duplicates, priced by calibre damage. So the payload
must read that generated list, not a static table, and `AP_dynGuns` is
cached after the first build.

Ammo and optics come from `fn_weaponAddons` / `AP_dynShopMags`, scoped to
the selected weapon — the design's `fits:[ids]`.

**2. Clothing (FITTING ROOM) — replaces clothing.hpp, idd 3100**

Trickiest of the four despite being small: selecting a row EQUIPS THE ITEM FOR
REAL as a preview, and CANCEL restores the saved loadout. That is live world
state driven from a page, and getting the restore wrong loses someone's
clothes. Needs the saved-loadout path read properly before anything is wired.

**3. Loot pickup (LOOT CARD) — replaces the suitcase interaction**

Smallest and lowest risk. `Land_Suitcase_F` + `AP_droppedItems`, merged within
6 m, 20–30 min TTL. Server owns the case, so two players on one case reconcile
on the push and first call wins the stack.

**4. Storage (DUAL MANIFEST) — replaces trunk.hpp, idd 4500**

Biggest win and the most dangerous thing in this list. It replaces the dialog
for EVERY container — house, vehicle trunk (T), tent, crate — and the Y-key
virtual inventory opens the same screen. One payload shape, every entry point.

**DO NOT START THIS AT THE END OF A LONG SESSION.** It is ~980 lines across
fn_openInventory / fn_refreshInventory / fn_moveItemInventory /
fn_takeInventory / fn_storeInventory, and it already carries TWO fixed dupe
exploits whose comments are still in the code:

- `fn_openInventory:67` — "owner 2026-06-18 (CLANKR dupe): refuse to OPEN
  while the storage is locked for serialization"
- `fn_openInventory:223` — "owner 2026-06-19 (HOUSE-STORAGE DUPE — Jeff
  Stall): AP_pinv/AP_vinv are mutated CLIENT-side via async"

plus the `AP_activeTrunk` reservation model and the `AP_trunkLock` guard that
`fn_vehicleToHouseStore` and `fn_houseToVehicleStore` both rely on.

Container inventories are mutated client-side. A second caller into that path
is exactly how both of those exploits happened. It needs all five functions
read end to end first, and the anti-dupe lock honoured by the new path rather
than reimplemented.

## Rules carried from the work so far

These were each learned by breaking something:

1. **A new web page needs the head block** — the `WEBUIReady` promise plus the
   `A3API.RequestFile` self-load — before anything else. Without it the page
   renders perfectly and is deaf, because `window.WEBUI` does not exist while
   the page's own script runs.
2. **Check what a re-plumbed function OPENS, not just what it reads.**
   fn_createGroup, fn_kickGroup, fn_setGroupLeader and fn_leaveGroup all
   reopened a native dialog on success and replaced the screen the player was
   standing in front of.
3. **The page never sends a price, or any other authority value.** It sends an
   id and an amount; SQF recomputes.
4. **Extract a shared helper rather than copy a money chain.** The virtual shop
   had the sell price in two places kept in step by a comment; a third copy was
   the trigger to pull it out.
5. **Anchor patches on a unique CSS rule, never a comment** — section comments
   exist in both the style and script blocks, and an unanchored replace puts
   CSS inside `<script>`.
