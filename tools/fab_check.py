#!/usr/bin/env python3
"""
fab_check.py -- structural validator for the 3D printer's recipe table.

Run standalone or via tools/run_checks.sh. Exits non-zero on any failure.

WHY THIS EXISTS. The crafting system this was ported from shipped 785 recipes with no build-time
validation, and paid for it three ways that a few lines of parsing would have caught:

  * 39 recipes were authored, balanced and level-gated but unreachable -- no blueprint existed and
    they were absent from the free list, so no player could ever make them.
  * Two more were pure CASE bugs: a blueprint spelled BP_U_I_pilotCoveralls against a recipe keyed
    U_I_PilotCoveralls. SQF HashMap keys are case-sensitive, so the two never met and the failure
    was completely silent.
  * One fully specified, droppable, learnable blueprint pointed at a recipe that did not exist.

So: assert the two tables are a bijection, assert every key resolves, and assert it at build time
where a machine can see it -- not at runtime where only a confused player can.

It also re-derives the recursive backbone cost in Python and compares the shape of the result
against the SQF resolver's contract. That matters because the recursive-vs-direct gap IS the
pricing model: if no intermediate contains the backbone, the recursive walk returns exactly the
top-level number and the resolver silently becomes an expensive no-op. That is a real mistake that
was made and caught while authoring this table, and it is invisible without a check like this one.

Schematic-table assertions are stubbed until fn_fabSchemCfg.sqf exists; see needs_schematics().
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIS = os.path.join(REPO, 'mission', 'Armapunk2035.Malden')
FAB = os.path.join(MIS, 'core', 'config', 'fn_fabCfg.sqf')
VIRT = os.path.join(MIS, 'core', 'config', 'fn_virtItemCfg.sqf')
RECIPE = os.path.join(MIS, 'core', 'config', 'fn_recipeDetail.sqf')
SCHEM = os.path.join(MIS, 'core', 'config', 'fn_fabSchemCfg.sqf')
GEN = os.path.join(MIS, 'core', 'config', 'fn_fabGen.sqf')

# Anything that moves money. A parts list containing one of these is a design violation, not a
# balance choice: production costs materials and time, never currency (owner 2026-08-21).
CURRENCY = {'AP_cash', 'AP_atmcash', 'AP_inv_new_drachma', 'AP_nd', 'AP_bank'}

fails = []
notes = []


def fail(msg):
    fails.append(msg)


def strip_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def _spans(text, start=0):
    """Yield (open, close) index pairs for every TOP-LEVEL [...] in text from start.

    A regex cannot do this. `\\[(.*?)\\]` stops at the first inner bracket, so a parts list of
    [["a",1],["b",2]] captures only up to ["a",1] and everything after it lands in the next group --
    which produced 60 bogus "empty parts list" / "unknown flag" failures the first time this ran.
    Nested brackets need a counter, not a pattern.
    """
    depth = 0
    open_at = None
    for i in range(start, len(text)):
        c = text[i]
        if c == '[':
            if depth == 0:
                open_at = i
            depth += 1
        elif c == ']':
            depth -= 1
            if depth == 0 and open_at is not None:
                yield open_at, i
                open_at = None
            elif depth < 0:
                return


def _rows_from(body):
    """Parse a [...] body of ["key", [lvl, [parts], [flags]]] rows."""
    out = {}
    for ro, rc in _spans(body):                      # each row: ["key", [lvl, [parts], [flags]]]
        row = body[ro + 1:rc]
        km = re.match(r'\s*"([A-Za-z0-9_]+)"\s*,', row)
        if not km:
            raise SystemExit(f'fab_check: unparseable row: {row[:60]!r}')
        key = km.group(1)
        vo, vc = next(_spans(row, km.end()))         # the [lvl, [parts], [flags]] value
        val = row[vo + 1:vc]
        lm = re.match(r'\s*(\d+)\s*,', val)
        if not lm:
            raise SystemExit(f'fab_check: {key}: no level field')
        lvl = int(lm.group(1))
        inner = list(_spans(val, lm.end()))
        if len(inner) != 2:
            raise SystemExit(f'fab_check: {key}: expected [parts] and [flags], found {len(inner)} arrays')
        parts_s = val[inner[0][0] + 1:inner[0][1]]
        flags_s = val[inner[1][0] + 1:inner[1][1]]
        parts = [(p.group(1), int(p.group(2)))
                 for p in re.finditer(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*(\d+)\s*\]', parts_s)]
        flags = re.findall(r'"([A-Za-z0-9_]+)"', flags_s)
        out[key] = (lvl, parts, flags)
    return out


def _literal_after(src, anchor):
    """The first top-level [...] body following `anchor` in src."""
    m = re.search(anchor, src)
    if not m:
        return None
    i = src.index('[', m.end() - 1) if '[' not in m.group(0) else m.start() + m.group(0).index('[')
    # walk to the first '[' at or after the anchor
    j = src.find('[', m.end() - 1)
    o, c = next(_spans(src, j))
    return src[o + 1:c]


def parse_fab():
    """Hand-authored rows from fn_fabCfg MERGED OVER the generated block in fn_fabGen.

    The two live in separate files, and the checker has to read both or it validates half the
    catalogue and reports the other half missing. Hand rows win on a key collision, matching
    createHashMapFromArray's later-entry-wins behaviour at runtime.
    """
    out = {}
    if os.path.exists(GEN):
        gsrc = strip_comments(open(GEN, encoding='utf-8').read())
        body = _literal_after(gsrc, r'private\s+_recipes\s*=\s*')
        if body is None:
            raise SystemExit('fab_check: fn_fabGen.sqf has no _recipes literal')
        out.update(_rows_from(body))

    src = strip_comments(open(FAB, encoding='utf-8').read())
    m = re.search(r'"AP_fabMap"\s*,\s*createHashMapFromArray', src)   # localNamespace setVariable ["AP_fabMap", ...]
    if not m:
        raise SystemExit('fab_check: could not find AP_fabMap -- the format changed')
    j = src.find('+ [', m.end())
    if j == -1:
        j = src.find('[', m.end())
    else:
        j += 2
    o, c = next(_spans(src, j))
    out.update(_rows_from(src[o + 1:c]))
    return out


def parse_virt_keys():
    src = strip_comments(open(VIRT, encoding='utf-8').read())
    return set(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"[^"]*"\s*,\s*-?\d+\s*,', src))


def parse_factory_outputs():
    src = strip_comments(open(RECIPE, encoding='utf-8').read())
    return set(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*\[\s*\[', src))


def parse_backbone():
    src = strip_comments(open(FAB, encoding='utf-8').read())
    m = re.search(r'case\s+"backbone"\s*:\s*\{\s*\[\s*"([A-Za-z0-9_]+)"\s*,\s*(\d+)\s*\]', src)
    if not m:
        raise SystemExit('fab_check: could not read the backbone tuple')
    return m.group(1), int(m.group(2))


def bare(ing):
    return ing[7:] if ing.startswith('AP_inv_') else ing


def backbone_units(fab, backbone, key, n=1, seen=()):
    """Mirror of AP_fnc_fabFee's walk, including its cycle guard."""
    if key == backbone:
        return n
    if key not in fab:
        return 0
    if key in seen:
        return 0
    chain = seen + (key,)
    return sum(backbone_units(fab, backbone, bare(v), n * q, chain) for v, q in fab[key][1])


def needs_schematics(fab):
    """Bijection between recipes and schematics. Active once fn_fabSchemCfg.sqf lands."""
    if not os.path.exists(SCHEM):
        notes.append('fn_fabSchemCfg.sqf not present yet -- bijection checks skipped (expected before P2)')
        return
    src = strip_comments(open(SCHEM, encoding='utf-8').read())
    schem = set(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*\[', src))
    if os.path.exists(GEN):
        gsrc = strip_comments(open(GEN, encoding='utf-8').read())
        gbody = _literal_after(gsrc, r'private\s+_schematics\s*=\s*')
        if gbody:
            schem |= set(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*\[', gbody))
            src = src + gbody
    for key, (_lvl, _parts, flags) in fab.items():
        if 'noSchematic' in flags:
            if key in schem:
                fail(f'{key}: flagged noSchematic but also has a schematic row -- pick one')
        elif key not in schem:
            fail(f'{key}: gated recipe with no schematic row -- unreachable, nothing can unlock it')
    for key in schem:
        if key not in fab:
            fail(f'schematic {key!r}: no recipe with that key -- check case, keys are case-sensitive')

    # Every declared source must actually yield a non-empty pool, and every rarity must be
    # reachable. A faucet whose pool comes back empty is not an error at runtime -- it is simply a
    # source that never drops anything, which reads as unlucky RNG rather than as a bug. That is
    # exactly how an inverted _x/_y in the HashMap forEach (value/key, the opposite way round from
    # an array forEach) survived review once.
    rows = re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*\[\s*(\d+)\s*,\s*\[([^\]]*)\]\s*,\s*"([a-z]+)"\s*\]\s*\]', src)
    if not rows:
        fail('schematic rows parsed to zero -- the format changed')
    declared_sources = set()
    rarities = {}
    for key, chance, sources, rarity in rows:
        srcs = re.findall(r'"([a-z]+)"', sources)
        if not srcs:
            fail(f'schematic {key!r}: no sources -- nothing can ever grant it')
        declared_sources.update(srcs)
        rarities.setdefault(rarity, []).append(key)
        if int(chance) < 1:
            fail(f'schematic {key!r}: dropchance {chance} -- 1-in-0 is not a probability')
    for s in sorted(declared_sources):
        pool = [k for k, _c, srcs, _r in rows if f'"{s}"' in srcs]
        if not pool:
            fail(f'source {s!r} is declared but its pool is empty')
    for r in ('common', 'rare', 'epic'):
        if r not in rarities:
            notes.append(f'no {r} schematics -- shard_{r} would roll from an empty pool')
    print(f'  sources: ' + ', '.join(f'{s}={len([1 for k,_c,ss,_r in rows if chr(34)+s+chr(34) in ss])}'
                                     for s in sorted(declared_sources)))
    print(f'  rarities: ' + ', '.join(f'{r}={len(v)}' for r, v in sorted(rarities.items())))



def check_closure_scope():
    """Every closure must be CALLED from somewhere it actually exists.

    fn_fabSRV.sqf shipped with _mayUse and _mayUsePrinter spliced into the middle of
    _resolveHouse's body -- its params/_c lines above them, its return line and closing
    brace below. Braces stayed globally balanced, so sqf_balance.py passed; the closures
    simply never existed at top level, and every arm that called one threw "Undefined
    variable in expression: _mayuse" at runtime. The house and gang access gate was dead
    from the day the file was written, and no static check noticed for four commits.

    A balance checker answers "do the braces match". This asks the question that was
    actually wrong: "does this closure's brace belong to the block I think it does" --
    by giving each declaration the extent of its enclosing block and failing any call
    made outside it. Closures declared and used inside one switch arm (the _refund
    pattern) are legal and stay legal.
    """
    bad = []
    for rel in ("server/AP_server/core/TON/fn_fabSRV.sqf",
                "server/AP_server/core/TON/fn_fabGrantSRV.sqf",
                "server/AP_server/core/TON/fn_fabDebugSRV.sqf",
                "server/AP_server/core/TON/fn_fabXp.sqf"):
        f = os.path.join(REPO, rel)
        if not os.path.exists(f):
            continue
        lines = open(f, encoding="utf-8").read().splitlines()
        depth, decls, calls, open_at = 0, [], [], {}
        for ln, line in enumerate(lines, 1):
            code = line.split("//")[0]
            m = re.match(r"\s*private (_\w+)\s*=\s*\{", code)
            if m:
                decls.append([m.group(1), depth, ln, len(lines)])   # extent closed below
            for c in re.finditer(r"\bcall\s+(_\w+)", code):
                calls.append((c.group(1), ln))
            for ch in code:
                if ch == "{":
                    open_at.setdefault(depth, []).append(depth)
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    # A declaration dies when the block that HELD it closes -- i.e. when depth
                    # drops below the depth it was declared at. Not when its own closing brace
                    # lands, which is the same depth and would kill every one-line closure on
                    # the line that defines it.
                    for d in decls:
                        if d[1] > 0 and depth == d[1] - 1 and d[3] == len(lines) and d[2] <= ln:
                            d[3] = ln
        for name, ln in calls:
            live = [d for d in decls if d[0] == name and d[2] <= ln <= d[3]]
            if not live and any(d[0] == name for d in decls):
                where = ", ".join(f"L{d[2]}-{d[3]}" for d in decls if d[0] == name)
                bad.append(f"{rel}:{ln} calls {name}, which only exists in {where} -- "
                           f"out of scope here, so this throws at runtime")
    return bad


def main():
    fab = parse_fab()
    virt = parse_virt_keys()
    factory = parse_factory_outputs()
    backbone, tth = parse_backbone()

    if not fab:
        raise SystemExit('fab_check: parsed zero recipes -- the format changed')

    # --- per-recipe structure
    for key, (lvl, parts, flags) in fab.items():
        if not 1 <= lvl <= 20:
            fail(f'{key}: level {lvl} outside 1..20')
        if not parts:
            fail(f'{key}: empty parts list')
        for var, qty in parts:
            if var in CURRENCY:
                fail(f'{key}: parts list contains currency {var} -- production must cost materials only')
            if qty <= 0:
                fail(f'{key}: ingredient {var} has non-positive quantity {qty}')
            b = bare(var)
            if b not in virt and b not in fab:
                fail(f'{key}: ingredient {var} is neither a virtual item nor a recipe key')
        for f in flags:
            if f not in ('noSchematic', 'bench'):
                fail(f'{key}: unknown flag {f!r}')

    # --- the two-stage weapon chain. A weapon is assembled at a bench from exactly ONE printed
    # lower receiver; nothing else may contain one. Both halves are asserted, because the failure
    # in either direction is silent: a weapon with no receiver is a bench recipe the printer step
    # never gates, and a printer recipe holding a receiver is a gun you can make without a bench.
    RECEIVERS = {'lower_pistol', 'lower_smg', 'lower_rifle', 'lower_heavy'}
    WEAPONISH = re.compile(r'^(arifle_|srifle_|hgun_|SMG_|LMG_|MMG_|sgun_|launch_)')
    for key, (_lvl, parts, flags) in fab.items():
        recv = [bare(v) for v, _q in parts if bare(v) in RECEIVERS]
        onbench = 'bench' in flags
        if WEAPONISH.match(key) and not onbench:
            fail(f'{key}: looks like a weapon but is not flagged "bench" -- it would be printable')
        if onbench and len(recv) != 1:
            fail(f'{key}: bench recipe with {len(recv)} lower receivers, must be exactly 1')
        if not onbench and recv:
            fail(f'{key}: printer recipe contains {recv[0]} -- receivers belong in bench recipes')
        if onbench and any(bare(v) == 'filament' for v, _q in parts):
            fail(f'{key}: bench recipe holds raw filament -- the printed part of a gun is its receiver')
    benches = sum(1 for _k, v in fab.items() if 'bench' in v[2])
    print(f'  chain: {benches} bench recipes (each 1 receiver), {len(fab) - benches} printer recipes')

    # --- outputs must exist as something, and must not collide with the Factory
    for key in fab:
        if key in factory:
            fail(f'{key}: also produced by the Factory (fn_recipeDetail) -- two systems minting one class')

    # --- cycles. The resolver guards against them at runtime, but a cycle is always an authoring
    # bug and silently prices the item at zero, so refuse to ship one.
    def find_cycle(key, stack):
        if key in stack:
            return list(stack[stack.index(key):]) + [key]
        if key not in fab:
            return None
        for var, _q in fab[key][1]:
            c = find_cycle(bare(var), stack + [key])
            if c:
                return c
        return None

    for key in fab:
        c = find_cycle(key, [])
        if c:
            fail(f'ingredient cycle: {" -> ".join(c)}')
            break

    # --- the backbone must actually nest, or the recursive resolver is a no-op
    if backbone not in fab:
        fail(f'backbone {backbone!r} is not a recipe key')
    nesting = [k for k, (_l, parts, _f) in fab.items()
               if k != backbone and any(bare(v) == backbone for v, _q in parts)
               and any(bare(v) in fab and bare(v) != backbone for v, _q in parts)]
    if not nesting:
        fail(f'no recipe nests {backbone!r} inside a sub-component -- the recursive fee resolver '
             f'would return the same number as the top-level parts list, i.e. do nothing')

    # --- report the pricing table so the curve is auditable rather than asserted
    print(f'  backbone={backbone}  {tth} ten-thousandths ND per unit')
    print(f'  {"recipe":<24} {"L":>2} {"direct":>7} {"recursive":>10} {"ND":>10}')
    priced = [(k, v) for k, v in fab.items() if 'noSchematic' not in v[2]]
    for key, (lvl, parts, _f) in sorted(priced, key=lambda kv: (kv[1][0], kv[0])):
        direct = sum(q for v, q in parts if bare(v) == backbone)
        rec = backbone_units(fab, backbone, key)
        if rec <= 0:
            fail(f'{key}: prices to zero backbone units -- its schematic would be free')
        nd = f'{(rec * tth) // 10000}.{(rec * tth) % 10000:04d}'
        print(f'  {key:<24} {lvl:>2} {direct:>7} {rec:>10} {nd:>10}')

    # Every printable class must be listable on the Exchange, or the closed economy has goods that
    # can be made and never traded -- which is the one thing the whole design is for.
    exch = os.path.join(MIS, 'core', 'config', 'fn_exchangeCfg.sqf')
    if os.path.exists(exch):
        esrc = strip_comments(open(exch, encoding='utf-8').read())

        # Rows must live INSIDE _exchangeArray, and the file must contain no empty-leading-comma
        # array. Both of those were briefly false: an append that anchored on the file's LAST ']'
        # put 65 rows into a different function's `_return=[]` and produced `_return=[,[...]]`.
        # That is bracket-BALANCED, so sqf_balance passed it, and the rows still matched the
        # content regex from anywhere in the file, so this check passed it too -- the only thing
        # that caught it was the server refusing to parse the expression at boot. Assert placement
        # and shape, not just presence.
        if '=[,' in esrc.replace(' ', ''):
            fail('fn_exchangeCfg.sqf has an array literal starting with a comma -- '
                 'something was appended at the wrong bracket')
        em = re.search(r'_exchangeArray\s*=\s*\[', esrc)
        if not em:
            fail('fn_exchangeCfg.sqf: no _exchangeArray literal found')
            inner = esrc
        else:
            o, c = next(_spans(esrc, esrc.index('[', em.start())))
            inner = esrc[o + 1:c]
            outside = (len(re.findall(r'\["[A-Za-z]+","[A-Za-z0-9_]+"', esrc))
                       - len(re.findall(r'\["[A-Za-z]+","[A-Za-z0-9_]+"', inner)))
            if outside:
                fail(f'{outside} exchange row(s) sit OUTSIDE _exchangeArray -- they are in the '
                     f'wrong array and will not be listable')
        listable = set(re.findall(r'\["[A-Za-z]+","([A-Za-z0-9_]+)",', inner))
        gap = sorted(k for k in fab if k not in listable)
        if gap:
            fail(f'{len(gap)} printable classes cannot be listed on the Exchange '
                 f'(e.g. {", ".join(gap[:5])}) -- add rows to fn_exchangeCfg.sqf')
        else:
            print(f'  exchange: all {len(fab)} printable classes are listable')

    # --- REACHABILITY. Every machine must be obtainable without already owning one.
    #
    # printer_i3 was flagged noSchematic and described in its own comment as "the bootstrap, and a
    # machine you cannot build without already owning a machine is a dead economy" -- while having
    # ZERO sources anywhere in the mission. No shop, no drop, no quest, no vendor. The only way to
    # get a printer was to print one, so the entire feature was unreachable in-game and every gate
    # here passed anyway, because each recipe was individually valid.
    #
    # noSchematic means "needs no schematic". It does NOT mean obtainable.
    tsrc = strip_comments(open(FAB, encoding='utf-8').read())
    machines = set(re.findall(r'\d+\s*,\s*[\d.]+\s*,\s*\d+\s*,\s*"([a-z0-9_]+)"\s*,\s*"ap_', tsrc))
    if not machines:
        fail('could not read the machine item keys out of the tier table')
    shops = os.path.join(MIS, 'core', 'config', 'fn_virt_shops.sqf')
    ssrc = strip_comments(open(shops, encoding='utf-8').read()) if os.path.exists(shops) else ''
    # The placed NPCs live in map_objects now; the committed snapshot of it (mapdb.md D7) is the
    # offline copy this check reads. Nothing in the mission tree carries a row any more.
    mapsrc = strip_comments(open(os.path.join(REPO, 'deploy', 'map_snapshot', 'map_objects.sqf'),
                                 encoding='utf-8').read())
    # Menus that open a virtual shop directly, so a shop with no NPC is still reachable.
    menusrc = ''
    for d in ('core/housing', 'core/pmenu', 'core'):
        dp = os.path.join(MIS, d)
        if os.path.isdir(dp):
            for fn in os.listdir(dp):
                if fn.endswith('.sqf'):
                    menusrc += open(os.path.join(dp, fn), encoding='utf-8', errors='ignore').read()

    def shop_of(item):
        """Which virt-shop case sells `item`, or None."""
        for m in re.finditer(r'case\s+"([a-z]+)"\s*:\s*\{', ssrc):
            nxt = re.search(r'case\s+"[a-z]+"\s*:\s*\{', ssrc[m.end():])
            seg = ssrc[m.end(): m.end() + (nxt.start() if nxt else len(ssrc))]
            if f'"{item}"' in seg:
                return m.group(1)
        return None

    def reachable(shop):
        """A shop the player can actually open: an NPC on the map, or a menu that opens it."""
        if f"'{shop}'" in mapsrc or f'"{shop}"' in mapsrc:
            return 'npc'
        if re.search(r'AP_fnc_virtualShopMenu', menusrc) and f'"{shop}"' in menusrc:
            return 'menu'
        return None

    # REACHABILITY, and it has to go all the way to the WORLD. Checking "is it in a shop" is what
    # passed while printer_i3 sat in `tech` -- Kabuki Electronics, which has zero placements in
    # the map snapshot and therefore sells nothing to anybody. A shop that exists in a config but not in
    # the world is not a source. So: find the shop, then prove the shop is openable.
    obtainable = {}
    for m in sorted(machines):
        sh = shop_of(m)
        via = reachable(sh) if sh else None
        if via:
            obtainable[m] = f'{sh} ({via})'
        elif m not in fab:
            fail(f'{m}: no source at all -- not printable, and not in any reachable shop')
        elif sh and not via:
            fail(f'{m}: sold in "{sh}", but that shop has no NPC on the map and no menu opens it '
                 f'-- it is not obtainable')
        else:
            notes.append(f'{m}: print-only (fine for an upgrade, fatal for the entry machine)')

    # PLACEABILITY. Buying a machine is not enough -- it has to be usable from the Y menu and it
    # has to survive fn_placeObject. Both hinge on ONE list, and not the one you would guess:
    #
    #   AP_placeable      -- [itemKey, previewClass, label, rot, dist, damagable]
    #   AP_furnitureItems -- a HARDCODED literal of item keys
    #   AP_furnitureClasses = AP_placeable filtered BY AP_furnitureItems
    #
    # The derivation runs placeable -> classes THROUGH furnitureItems, so adding a row to
    # AP_placeable does not put an item on the furniture list; it only gives it a preview class.
    # fn_useItem routes on `_item in AP_furnitureItems`, and fn_placeObject's whole house branch --
    # including the fabricator intercept -- is nested inside the same test. All three machines had
    # AP_placeable rows and no AP_furnitureItems entry, so "Use" answered "this item is not usable"
    # and the intercept was unreachable code.
    conf = os.path.join(MIS, 'core', 'configuration.sqf')
    csrc = open(conf, encoding='utf-8').read()
    fm = re.search(r'AP_furnitureItems\s*=\s*\[(.*?)\]', csrc, re.S)
    pm = re.search(r'AP_placeable\s*=\s*\[', csrc)
    furn = set(re.findall(r'"([A-Za-z0-9_]+)"', fm.group(1))) if fm else set()
    placeable = set()
    if pm:
        o, c = next(_spans(csrc, csrc.index('[', pm.start())))
        placeable = set(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"[A-Za-z0-9_]+"', csrc[o:c + 1]))
    # PREVIEW CLASSES MUST BE UNIQUE ACROSS AP_placeable. fn_placeObject works out WHICH ITEM you
    # are placing from `typeOf AP_placing` -- the preview object's class -- so two rows sharing a
    # class are indistinguishable and the first one silently wins. Both printers were given
    # Land_PortableServer_01_olive_F, which cryptoRig already owned, so placing a printer resolved
    # as placing a mining rig: wrong item consumed, wrong intercept, and the preview prop left
    # standing in the world as "a server".
    cls_of = dict(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"([A-Za-z0-9_]+)"', csrc[o:c + 1])) if pm else {}
    seen_cls = {}
    for key, cls in re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"([A-Za-z0-9_]+)"', csrc[o:c + 1]) if pm else []:
        seen_cls.setdefault(cls, []).append(key)
    for cls, keys in sorted(seen_cls.items()):
        if len(keys) > 1:
            fail(f'AP_placeable: {len(keys)} items share the preview class {cls} '
                 f'({", ".join(keys)}) -- fn_placeObject resolves the item FROM that class, so all '
                 f'but the first are unplaceable')

    for m in sorted(machines):
        if m not in placeable:
            fail(f'{m}: no AP_placeable row -- it has no preview object and cannot be positioned')
        if m not in furn:
            fail(f'{m}: not in AP_furnitureItems -- "Use" will answer "this item is not usable", '
                 f'and fn_placeObject\'s intercept is nested inside that same test')

    if not obtainable:
        fail('NO fabricator can be obtained without already owning one -- the feature is '
             'unreachable in-game. At least one machine needs a source a player can actually reach.')
    else:
        print('  reachable: ' + ', '.join(f'{k} via {v}' for k, v in sorted(obtainable.items())))

    needs_schematics(fab)

    for msg in check_closure_scope():
        fail(msg)

    for n in notes:
        print(f'  note: {n}')
    if fails:
        print()
        for f in fails:
            print(f'  FAIL: {f}')
        print(f'\n{len(fails)} failure(s)')
        return 1
    print(f'\n{len(fab)} recipes OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
