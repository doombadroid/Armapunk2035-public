#!/usr/bin/env python3
"""gen_fab_catalogue.py -- generate the wide half of the Fabricator catalogue.

    python3 scratchpad/gen_fab_catalogue.py

Writes ONE file: mission/Armapunk2035.Malden/core/config/fn_fabGen.sqf, which fn_fabCfg and
fn_fabSchemCfg merge with their hand-authored rows. The split is the point -- a generated block
inside a hand-edited file is a block someone will hand-edit and then lose on the next run, which is
why edenNPC_data.sqf carries its own do-not-hand-edit banner rather than living inside a config.

TWO SOURCES, TREATED DIFFERENTLY.

  * MIGRATED (scratchpad/fab/factory_snapshot.json) -- the 136 non-vehicle recipes the Factory used
    to mint. Their ingredient lists are HAND-TUNED and are carried over verbatim; the generator adds
    only a filament line and derives a level. Snapshotted as committed input precisely so that
    cutting them out of fn_recipeDetail does not change what this script produces -- a generator
    whose output depends on a file the same change deletes is not reproducible.

  * SHOP-DERIVED -- every civ/rebel clothing and gear class the shops sell. The shop's cash price is
    the only value anchor these have, and it stays meaningful after the shops are emptied -- but it
    ORDERS them, it does not price them. See the CONFIG block for why.

BOTH SOURCES ARE RANKED TOGETHER, so a migrated Factory recipe and a shop-derived one are levelled
against each other rather than on two unrelated scales.

WHY FILAMENT IS ADDED TO MIGRATED RECIPES. The printer's cost model is denominated in one backbone
material; AP_fnc_fabFee prices a schematic by counting it through the whole tree, and a recipe
carrying none prices its schematic at zero, which fab_check.py fails. The quantity comes from the
level curve, exactly as it does for a generated recipe.

EXCLUSIONS. Cop and medic clothing (not civilian content), the 25 vehicle classes (the Factory
keeps those), anything already hand-authored in fn_fabCfg, and duplicates.

Every constant that shapes the economy is in the CONFIG block below. Nothing is authored per item.
"""
import json
import os
import re
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MIS = os.path.join(REPO, 'mission', 'Armapunk2035.Malden')
CFG = os.path.join(MIS, 'core', 'config')
OUT = os.path.join(CFG, 'fn_fabGen.sqf')
SNAP = os.path.join(HERE, 'fab', 'factory_snapshot.json')

# ----------------------------------------------------------------------------- CONFIG
#
# PRICE ORDERS THE CATALOGUE; IT DOES NOT SET THE CURVE. Deriving level and cost directly from the
# shop price was the obvious approach and it was measurably wrong: it put 183 of 551 recipes at
# level 1, 374 below level 4, 487 of them "common", and gave a MEDIAN cost of one filament. That is
# a ladder with no middle and four hundred items not worth the walk to the printer -- because the
# inherited shop prices cluster hard at $10-50 for clothing and then jump three orders of magnitude
# for rebel gear, which is a shape that suited a cash shop and suits a progression tree not at all.
#
# So: sort every recipe by price, then spread the sorted list evenly across the 20 levels. Price
# still decides what is cheap and what is prestigious -- an item never outranks a dearer one -- but
# the ladder is designed rather than inherited, and every level has content.
LEVELS = 20

# Filament cost per level, geometric. L1 costs 2, L20 costs ~180 -- well past the 96 carry cap, so
# the top of the tree is a truck job by construction. Time and logistics are the price here; money
# is not involved in production at all.
COST_BASE = 2.0
COST_GROWTH = 1.27

# Which intermediates a category pulls in, and how much per 10 levels.
CATEGORY = [
    (r'^U_',                          [('polymer_pellet', 2)]),
    (r'^V_',                          [('ballistic_plate', 1), ('nanofoam', 2)]),
    (r'^H_',                          [('nanofoam', 1)]),
    (r'^G_',                          [('optic_blank', 1)]),
    (r'^B_',                          [('carbon_weave', 2)]),
    (r'^(optic_|acc_)',               [('optic_blank', 2), ('circuit_lamina', 1)]),
    (r'^(arifle_|srifle_|hgun_|SMG_|LMG_|MMG_|sgun_|launch_)',
                                      [('ballistic_plate', 1), ('circuit_lamina', 1), ('carbon_weave', 2)]),
    (r'Rnd_',                         [('circuit_lamina', 1)]),
    (r'^(Chemlight|SmokeShell|HandGrenade|MiniGrenade)', [('polymer_pellet', 1)]),
]
DEFAULT_PARTS = [('polymer_pellet', 1)]

# WEAPONS ARE ASSEMBLED, NOT PRINTED. Every gun is a "bench" recipe carrying exactly one printed
# lower receiver plus its materials; the printer makes the receiver and nothing else about a gun.
# Four receiver classes rather than one universal part means the printer's own level decides which
# weapon classes a player can supply the bench with.
WEAPON = re.compile(r'^(arifle_|srifle_|hgun_|SMG_|LMG_|MMG_|sgun_|launch_)')
RECEIVER = [
    (r'^hgun_',                'lower_pistol'),
    (r'^SMG_',                 'lower_smg'),
    (r'^(arifle_|sgun_)',      'lower_rifle'),
    (r'^(srifle_|LMG_|MMG_|launch_)', 'lower_heavy'),
]


def receiver_for(cls):
    for pat, r in RECEIVER:
        if re.match(pat, cls):
            return r
    return 'lower_rifle'

# Rarity and drop rate by level band.
def rarity_of(level):
    if level <= 8:
        return 'common'
    return 'rare' if level <= 15 else 'epic'

def dropchance_of(level):
    return {'common': 20 + level * 6, 'rare': 60 + level * 8, 'epic': 140 + level * 12}[rarity_of(level)]

def sources_of(level):
    r = rarity_of(level)
    if r == 'common':
        return ['gather', 'mine', 'shop']
    if r == 'rare':
        return ['mine', 'shop', 'heist']
    return ['shop', 'heist']


# ----------------------------------------------------------------------------- parsing
def strip(t):
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
    return re.sub(r'//[^\n]*', '', t)


def read(name):
    return strip(open(os.path.join(CFG, name), encoding='utf-8').read())


def clothing_rows(name):
    """[(class, price)] from a clothing config -- rows are [class, name|nil, price, texture?]."""
    s = read(name)
    return [(m.group(1), int(m.group(2)))
            for m in re.finditer(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*(?:"[^"]*"|nil)\s*,\s*(\d+)', s)]


def weapon_rows():
    s = read('fn_weaponShopCfg.sqf')
    return [(m.group(1), int(m.group(2)))
            for m in re.finditer(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"[^"]*"\s*,\s*(\d+)', s)]


def addon_rows():
    s = read('fn_weaponAddons.sqf')
    return [(m.group(1), int(m.group(2)))
            for m in re.finditer(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"[^"]*"\s*,\s*(\d+)', s)]


DERIVED_PRICES = None


def derived_prices():
    """classname -> the DERIVED cash price, for every class the economy model can price.

    ECONOMY 2026-09-05: shop prices stopped being the price source of truth for guns, attachments
    and armour. fn_weaponShopCfg now computes a firearm's price from CfgAmmo at runtime
    (AP_fnc_gunPrice), fn_weaponAddons tiers attachments by prefix, and fn_clothingFilter bands
    armour from each item's own HitpointsProtectionInfo -- so the numbers still sitting in the
    curated arrays are inert leftovers. Ranking this catalogue by them would re-import every
    inversion the derived curve was written to remove, one level band at a time.

    tools/derived_prices.json is that model's output, extracted once from the shipped game configs.
    Regenerate it whenever the curve constants change; it is data, not a second implementation.
    A class missing from it falls through to its shop row exactly as before.
    """
    global DERIVED_PRICES
    if DERIVED_PRICES is None:
        path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                            'tools', 'derived_prices.json')
        try:
            with open(path, encoding='utf-8') as fh:
                DERIVED_PRICES = json.load(fh)
        except FileNotFoundError:
            DERIVED_PRICES = {}
    return DERIVED_PRICES


def hand_authored_keys():
    s = read('fn_fabCfg.sqf')
    m = re.search(r'AP_fabMap\s*=\s*createHashMapFromArray\s*\[(.*?)\n\];', s, re.S)
    return set(re.findall(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*\[\s*\d+', m.group(1))) if m else set()


def item_values():
    """classname -> sell value, for costing the migrated recipes' authored ingredients."""
    s = read('fn_virtItemCfg.sqf')
    out = {}
    for m in re.finditer(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"[^"]*"\s*,((?:\s*-?\d+\s*,){7})\s*(-?\d+)\s*,\s*"[^"]*"\s*\]', s):
        nums = [int(n) for n in m.group(2).replace(' ', '').strip(',').split(',')]
        out[m.group(1)] = max(nums[5], int(m.group(3)), 0)   # buy or sell, whichever is real
    return out


# ----------------------------------------------------------------------------- derivation
def filament_for(level):
    return max(1, round(COST_BASE * (COST_GROWTH ** (level - 1))))


def parts_for(cls, level):
    # A weapon's filament is in its RECEIVER, not in the gun. The bench assembles; it does not print.
    if WEAPON.match(cls):
        parts = [(receiver_for(cls), 1)]
    else:
        parts = [('filament', filament_for(level))]
    extra = DEFAULT_PARTS
    for pat, p in CATEGORY:
        if re.search(pat, cls):
            extra = p
            break
    scale = max(1, round(level / 5))
    for name, per in extra:
        parts.append((name, max(1, per * scale)))
    return parts


def main():
    snap = json.load(open(SNAP, encoding='utf-8'))
    values = item_values()
    hand = hand_authored_keys()
    vehicles = set(snap['vehicles'])

    recipes = {}          # key -> (level, [(item, qty)])
    origin = {}
    # (sortValue, key, keptParts|None, origin) -- one flat list so migrated and shop-derived
    # recipes are levelled against EACH OTHER rather than on two unrelated scales.
    ranked = []

    # ---- migrated: authored ingredients kept, filament added, level derived from their value
    for key, parts in sorted(snap['migrating'].items()):
        if key in hand or key in vehicles:
            continue
        worth = sum(values.get(v[7:], 0) * q for v, q in parts if v.startswith('AP_inv_'))
        kept = [(v[7:], q) for v, q in parts if v.startswith('AP_inv_')]
        ranked.append((worth, key, kept, 'factory'))

    # ---- shop-derived
    shop = []
    for f in ('fn_clothing_civ.sqf', 'fn_clothing_reb.sqf'):
        shop += clothing_rows(f)
    shop += weapon_rows()
    shop += addon_rows()

    best = {}
    for cls, price in shop:
        if price <= 0:
            continue
        best[cls] = max(best.get(cls, 0), price)     # a class sold twice takes its dearer price

    # ECONOMY 2026-09-05: the DERIVED price wins wherever the model can produce one. The curated
    # numbers still in the shop arrays are no longer what a player pays for a gun, an optic, a can
    # or a vest -- those are computed at runtime now -- so ranking by them would rebuild the very
    # inversions the curve removed. Anything the model cannot price (shotguns, launchers, flare
    # guns, uniforms, backpacks) keeps its shop row and is unaffected.
    _derived = derived_prices()
    _overridden = 0
    for cls in list(best):
        if cls in _derived:
            if best[cls] != _derived[cls]:
                _overridden += 1
            best[cls] = _derived[cls]

    seen = {k for _w, k, _p, _o in ranked}
    for cls, price in sorted(best.items()):
        if cls in hand or cls in vehicles or cls in seen:
            continue
        ranked.append((price, cls, None, 'shop'))

    # Spread the price-sorted catalogue evenly over the levels. Ties keep a stable order so a
    # regeneration cannot shuffle two equally-priced items between levels.
    ranked.sort(key=lambda r: (r[0], r[1]))
    n = len(ranked)
    for i, (_worth, key, kept, org) in enumerate(ranked):
        lvl = min(LEVELS, 1 + (i * LEVELS) // max(1, n))
        if kept is None:
            recipes[key] = (lvl, parts_for(key, lvl))
        elif WEAPON.match(key):
            # migrated WEAPON: authored ingredients verbatim, plus its receiver instead of filament.
            # The receiver is where the printed part of a gun lives now.
            recipes[key] = (lvl, [(receiver_for(key), 1)] + kept)
        else:
            # migrated: authored ingredients verbatim, plus the level's filament line
            recipes[key] = (lvl, [('filament', filament_for(lvl))] + kept)
        origin[key] = org

    # ---- emit
    lines = []
    lines.append('/*')
    lines.append('    fn_fabGen.sqf  (AP_fnc_fabGen)  --  G E N E R A T E D.  Do not hand-edit.')
    lines.append('')
    lines.append('    Written by scratchpad/gen_fab_catalogue.py; that script is the source of truth. An edit')
    lines.append('    here survives exactly until the next regeneration and then vanishes with no error.')
    lines.append('    Hand-authored recipes live in fn_fabCfg.sqf, which merges this in.')
    lines.append('')
    lines.append('        call AP_fnc_fabGen  ->  [[<recipeRows>], [<schematicRows>]]')
    lines.append('')
    lines.append(f'    {len(recipes)} recipes: {Counter(origin.values())["factory"]} migrated from the Factory')
    lines.append('    (their authored ingredients carried over verbatim, plus the level curve\'s filament line)')
    lines.append(f'    and {Counter(origin.values())["shop"]} derived from shop catalogues. Both are ranked by price')
    lines.append('    TOGETHER and spread evenly over the 20 levels -- price orders them, the curve costs them.')
    lines.append('')
    lines.append('    Every one of these is schematic-gated. The intermediates tier and the two printers are')
    lines.append('    hand-authored and stay noSchematic, so a new player always has something to build.')
    lines.append('*/')
    lines.append('')
    lines.append('private _recipes = [')
    body = []
    for key in sorted(recipes, key=lambda k: (recipes[k][0], k)):
        lvl, parts = recipes[key]
        ps = ', '.join(f'["AP_inv_{n}", {q}]' for n, q in parts)
        flags = '"bench"' if WEAPON.match(key) else ''
        body.append(f'    ["{key}", [{lvl:2d}, [{ps}], [{flags}]]]')
    lines.append(',\n'.join(body))
    lines.append('];')
    lines.append('')
    lines.append('private _schematics = [')
    body = []
    for key in sorted(recipes, key=lambda k: (recipes[k][0], k)):
        lvl, _ = recipes[key]
        srcs = ', '.join(f'"{s}"' for s in sources_of(lvl))
        body.append(f'    ["{key}", [{dropchance_of(lvl):4d}, [{srcs}], "{rarity_of(lvl)}"]]')
    lines.append(',\n'.join(body))
    lines.append('];')
    lines.append('')
    lines.append('[_recipes, _schematics]')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

    lv = Counter(v[0] for v in recipes.values())
    print(f'wrote {os.path.relpath(OUT, REPO)}')
    print(f'  {len(recipes)} recipes  ({Counter(origin.values())["factory"]} migrated, '
          f'{Counter(origin.values())["shop"]} shop-derived)')
    print('  by level: ' + ' '.join(f'L{k}={lv[k]}' for k in sorted(lv)))
    w = sum(1 for k in recipes if WEAPON.match(k))
    print(f'  bench recipes (weapons): {w}   printer recipes: {len(recipes) - w}')
    print('  by rarity: ' + ' '.join(f'{r}={sum(1 for v in recipes.values() if rarity_of(v[0]) == r)}'
                                     for r in ('common', 'rare', 'epic')))
    fil = [dict(v[1]).get('filament', 0) for v in recipes.values()]
    print(f'  filament per recipe: min={min(fil)} median={sorted(fil)[len(fil)//2]} max={max(fil)}')


if __name__ == '__main__':
    main()
