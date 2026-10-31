# Editing the custom building .p3d files

Hard-won notes from fixing the Grand Palace. Read this before editing any of the designer's models
in Blender — two of these will cost you an afternoon each otherwise.

The models live in `mission/Armapunk2035.Malden/*.p3d` and are loaded at runtime by
`custom_p3ds/malden_buildings.sqf` via `createSimpleObject` + `getMissionPath ""`. They are
**MLOD** (editable), not binarized.

**Pristine originals**: `~/Downloads/ProjectMaldenMerge.Malden.zip` → `ProjectMaldenMerge.Malden/*.p3d`.
Keep that zip. The repair workflow below depends on having an untouched copy to replay onto.

---

## 1. Blender destroys the topology, and it looks like a texture bug

Importing with Arma Toolbox, deleting something, and exporting **splits every shared vertex**. On the
palace:

| | pristine | after Blender |
|---|---|---|
| LOD0 points | 14,403 | **51,840** |
| LOD1 points | 540 | 2,280 |
| LOD2 points | 1,677 | 4,928 |
| LOD3 points | 443 | 1,127 |

LODs 1–3 were never touched by the edit — that is how you know it is the exporter, not you. The
giveaway is that the new point count equals the pristine **normal** count (LOD1 2280 = 2280, LOD2
4928 = 4928): the importer makes one vertex per *(point, normal)* pair and the exporter writes each
back as its own point.

Nothing is wrong with the textures. Texture paths, rvmats, UVs and per-face texture assignment all
survive intact. What breaks is that no face shares a normal with its neighbour any more, so every
edge renders hard, the `#SharpEdges#` list (28,397 pairs on the palace) becomes meaningless, and the
whole model shades flat. It *reads* as "the textures are out of whack".

Note Arma's MLOD stores **UVs per face-corner, inside the face record** — splitting vertices was
never necessary to carry UVs.

### The fix: replay the edit onto the pristine file

```bash
python3 tools/p3d_replay_edit.py <pristine.p3d> <your-blender-export.p3d> <output.p3d>
```

It matches faces between the two files by *(vertex count, texture, sorted rounded corner positions)*
— positions survive re-indexing, indices do not — then removes exactly the faces you removed from a
byte-identical copy of the original. Points are deliberately **not** compacted, so `#SharpEdges#`,
selection weights and all per-point data stay valid with no remapping.

It **aborts** if any face exists only in your export, i.e. if you added or moved geometry. It can
only replay deletions.

Expected output for a clean run:

```
kept                 : 15799
dropped (the edit)   : 583
in edited only       : 0        <- must be 0
```

### If you need to add or move geometry

The replay tool cannot help. Fix the welding in Blender before exporting:

1. Edit Mode → `A` → `M` → **Merge by Distance**, threshold `0.0001`
2. `Shade Smooth`, then mark hard edges with **Edge → Mark Sharp** instead of splitting geometry
3. Verify the point count came back down before shipping (see §4)

---

## 2. Arma caches models BY PATH — swapping a .p3d in place does nothing

This one cost about six rounds. The mission root is `mpmissions\__cur_mp.<WORLD>\`, which is
**world**-based, so it is byte-identical on every build. Replacing `Foo.p3d` with new contents ships
the new file, and the client keeps rendering the copy it already loaded.

A correct fix looks like no fix. Worse, an *incorrect* fix looks the same, so you cannot tell them
apart and you start "fixing" things that were never broken.

**Every time you change a .p3d, do one of:**
- rename the file and update the reference in `custom_p3ds/malden_buildings.sqf` (this is why
  the palace is on `MaldenGrandPalaceBuilding.p3d`), or
- fully exit Arma to desktop before rejoining — a plain rejoin is not enough

The build-numbered mission PBO does *not* help here: the mission name changes, the model path does
not.

---

## 3. The origin is the geometric CENTRE — placement depends on the bounding box

`boundingBoxReal` on the palace is symmetric: `min z = -13.9034`, `max z = +13.9034`. The model's
origin sits at its middle, not its base.

So placement height is tied to the model's size. `malden_buildings.sqf` places the palace at
`z 174.676` with `setObjectScale 0.7`; if an edit changes the bounding box or moves the pivot, the
building sinks or floats by half the difference and it will look like a placement bug rather than a
model change.

**After any edit, check the bbox is unchanged.** If it did change deliberately, the ground-contact
height is `base + halfHeight * scale`.

Related, already burned: **`setDir` resets `setObjectScale`.** In `malden_buildings.sqf` the order
must always be `setDir` *then* `setObjectScale`. Reversed, every scaled building silently renders at
1.0 — the palace came out 113 m wide instead of 79 m and half sunk.

---

## 4. Verify before you ship

```bash
python3 - <<'EOF'
import struct
exec(open("tools/p3d_set_roadway_surface.py").read().split('if __name__')[0])
for p in ("<pristine.p3d>", "<yours.p3d>"):
    raw,ver,lods = parse(p)
    print(p, [(l['npts'], l['nfaces']) for l in lods])
EOF
```

What to look for:
- **point counts** close to pristine — a 3× jump means the vertex explosion (§1)
- **face counts** matching your intent — only the LOD you edited should differ
- LOD **resolutions** unchanged: `1` = visual, `11002` = coarse visual, `1e13` = Geometry,
  `3e15` = Roadway

Then repack and rejoin. `bash /home/timb/arma3server_dev/reload-armapunk2035.sh` takes ~2s and
seeds the client cache, so there is no download.

---

## 5. Things that are NOT your fault

- **"UV coordinate on point N is too big"** — ~28 warnings per load. The palace's UVs span
  u −200…227, v −390…50 and Arma quantises UVs per LOD, so it loses precision. Present in the
  designer's untouched original. Only worth chasing if a surface visibly warps.
- **Footstep sound on custom buildings is wrong** (sounds like soft sand, not matching stock
  buildings). Pre-existing on all ten models, unresolved — see `MALDEN.md` "Known gaps" for the full
  state and what has been ruled out. Not caused by editing, and editing will not fix it.

---

## 6. Tools

| tool | what it does |
|---|---|
| `tools/p3d_replay_edit.py` | replay a deletion-only edit onto a pristine file (§1) |
| `tools/p3d_set_roadway_surface.py` | rewrite the Roadway LOD's material; also a usable MLOD parser via `parse()` |

Both are plain-Python MLOD readers/writers — no Blender, no Object Builder, no P: drive. They only
handle **MLOD**; binarized ODOL models (anything from BI's own PBOs) will be rejected.

## 3b. Skyscraper20 is GENERATED — regen, don't edit

`Skyscraper20_rN.p3d` is not a designer model: it is generated from a three.js
prototype by `scratchpad/skyscraper/` (README there has the pipeline). To change it,
edit the generator and regenerate — hand-editing the p3d loses the change on the next
regen. Everything else in this file (cache-buster renames §2, centre-origin placement
§3, Geometry-LOD doctrine §4) applies to it unchanged.

## 4. Geometry-LOD collision: the mentalasylum13 saga (fixed 2026-08-01, two causes)

A model that ships only Resolution/ShadowBuffer/Roadway LODs has walkable floors and **no solid
walls**. The fix is a Geometry LOD (res 1e13) of closed convex components — but this building
needed TWO fixes, and the second one changes how to think about custom collision entirely.

**Cause 1 (file):** the box generator's bbox filter dropped — instead of clamped — 42 facade slabs
generated flush outside the visual bbox. Fixed in r19/r20 (restore + shift flush + mask fills).
Lesson: verify a claim against the SHIPPED bytes, not the pipeline's intermediate; diff element
COUNTS across pipeline stages first (json 413 → file 371 was the whole mystery in one number).

**Cause 2 (engine):** `lineIntersectsSurfaces` and the WALKING CAPSULE are different collision
consumers. Rays hit every valid component everywhere; the character path ignored a stable,
site-specific subset of them — byte-identical mirrored components behaved differently, a
Bank-sized recentred slice still failed at the site, the same object 100 m away was fully solid,
and sea/mid-air spawns had no character collision at all. Undecodable from outside; treat it as a
fact of the terrain spot. **Fix: embed `Land_InvisibleBarrier_F` segments
(vanilla, purpose-built invisible collision, 4×1 m) inside the wall volume over the dead zones**
(`custom_p3ds/asylum_collision_belt.sqf`, self-sized rows covering both walk bands).
Map-class statics never fail. **`hideObjectGlobal` REMOVES an object's collision** (measured) —
hiding a normal wall is not a path to invisible colliders.

**Verification doctrine (the big one): verify with the modality that failed.** Rays "proved" the
walls solid twice while players walked through them. Only an AI-unit shove probe
(`debug/walltest.sqf` — spawn, `disableAI "ALL"`, `setVelocity` into the wall, compare model-frame
position) reproduces what a player experiences. Grep [WALLTEST] / [RAYPROBE] in loonydev.log.

Also learned: `lineIntersectsSurfaces` reports a solid's ENTRY face (a wall crossed from inside
logs at its inner face); a ray STARTED inside a component reports "none"; the engine inflates GEOM
contact surfaces ~0.2 m; `isOnRoad` is a unary prefix command; engine honors component indices
>255 for both rays and walking; `setObjectScale` must come AFTER `setDir` (setDir resets scale).

---

## 7. Binarizing: the models ship as ODOL, the MLODs are the source (2026-08-19)

All 27 models in `custom_p3ds/` are **binarized ODOL**. They were MLOD until
2026-08-19; the mission PBO was 295 MB and one model alone (`skyscraper30_r17`,
146 MB) sat above GitHub's 100 MB hard limit, so the branch could not be pushed.

    custom_p3ds  199 MB -> 16 MB   (12.8x)
    mission PBO  295 MB -> 112 MB
    the tower    146 MB -> 7.0 MB  (21x)

### Doing it

Arma 3 Tools ships the binarizer and it runs under plain wine. It takes
DIRECTORIES, not files, and converts everything it finds:

    export WINEPREFIX=<a prefix>   # a stale prefix gives "wineserver version mismatch"
    cd "$HOME/.local/share/Steam/steamapps/common/Arma 3 Tools/Binarize"
    wine64 binarize_x64.exe -always -silent -maxProcesses=6 "Z:\\home\\timb\\src" "Z:\\home\\timb\\dst"

Two things it is silent about, measured 2026-09-02 (the palace _r5):
- Give it BACKSLASH paths. `"Z:/home/timb/src"` makes it build
  `z:/home/timb/src\model.p3d` and fail with `Cannot open object` / `Loading of
  model ... failed`, no matter which prefix; `"Z:\\home\\timb\\src"` works.
- Name the source file in LOWERCASE. It lowercases every path before opening
  it, and this filesystem is case-sensitive, so `Palace.p3d` is looked up as
  `palace.p3d` and is not found. Rename the OUTPUT back to the cased name the
  mission references; Arma's PBO lookup does not care.

`Cannot load material file a3\...rvmat` in its output is EXPECTED and harmless:
there is no P: drive here, so it cannot open the material, but it writes the
path through unchanged and the engine resolves it at run time. Binarize also
**lowercases every path** it embeds, which is meaningless to Arma but will make
a naive before/after string comparison look like data loss. Compare case-insensitively.

### The trap: current binarize emits ODOL v75, and every reader here expects v73

Shipped Arma 3 addons are ODOL **v73**. The 2025 binarize writes **v75**, and
the engine loads it fine (verified on dev, b0680, zero errors) — but
`~/blender_work/odol73_to_mlod.py` asserted `ver < 75` and, once that assert was
relaxed, silently mis-parsed everything downstream.

**v75 inserts 8 bytes between `appID` and the `muzzleFlash` string.** That is
the whole delta; the rest of the header and ModelInfo are unchanged. Without it
`nLods` reads as 0 and every bounding box comes back around 1e38. The reader
now handles it:

    r.u32()                          # appID
    if ver >= 75: r.u32(); r.u32()   # v75: 8 new bytes
    r.asciiz()                       # muzzleFlash

Sanity check on any new version: `nLods` should be a small int and
`resolutions[0]` should be exactly `1.0` (the visual LOD).

### What to verify after binarizing

Binarize is not lossless in representation, only in meaning, so check meaning:

- **LOD count and resolutions** identical to the MLOD.
- **Bounding box EXTENT** identical — not the corners. Binarize bakes
  autocentring in, so `bmin`/`bmax` come back centred on the origin and the
  corners legitimately move by the model's own centre offset (58.46 m for the
  tower, which is exactly the `arma_z = p3d_y - 58.46` figure in §3). The
  extent must not move at all; all 27 came back at 0.0000.
- **Texture, rvmat and procedural-colour strings** preserved, case-insensitively.
- **Placement, in game.** The extent test cannot prove the engine agrees. The
  jewellery-case probe already in `initServer.sqf` does: it logs the 8 case
  heights against their authored values, and after binarizing all 8 were within
  0.05 m. That is the proof autocentring did not shift anything.

### Two things that look like new damage and are not

`Strange convex componentNNN in ...jewelrybuildingmodel.p3d:geometry` — 7
components of a designer model whose geometry was already non-convex. The same
boot logs 11 more of these against **Bohemia's own** boats, houses, a palm and
the research dome, which is the fastest way to see it is routine engine noise.

`Geometry LOD has UVSet, it is useless` — cosmetic, from the builders writing a
UV set into geometry LODs.

### Sources

The ODOLs are build output. The MLOD masters for the 26 designer models are in
git history. The tower's MLOD is NOT: it is 146 MB, `scratchpad/skyscraper/` is
gitignored, and it is regenerated by `build_lux.py` from `lux_dump.json` — which
is the rule for everything in that directory anyway (scripts are the source of
truth). Re-binarize after any rebuild; the mission never ships an MLOD again.
