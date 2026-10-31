#!/usr/bin/env python3
"""Generate `prices.py` from the game's own config files.

WHY THIS IS GENERATED AND NOT TYPED OUT
    Decision 2 is "refund at purchase price". The purchase price of a house is
    not a number somebody chose for this migration -- it is a number that lives
    in `core/config/fn_houseConfig.sqf`, one row per building class, and it moves
    when the owner rebalances housing. A hand-copied table is correct on the day
    it is copied and silently wrong afterwards, and "silently wrong" here means
    every house owner is refunded the wrong amount with no error anywhere.

    So: this script parses the SQF, `prices.py` is its committed output, and
    `--check` fails if the two have drifted. Run it after any housing or virtual
    item price change.

        python3 gen_prices.py            # rewrite prices.py
        python3 gen_prices.py --check    # exit 1 if prices.py is stale

SOURCES
    mission/.../core/config/fn_houseConfig.sqf   house buy price + storage tiers
    mission/.../core/config/fn_virtItemCfg.sqf   virtual item base prices (idx 7)
    mission/.../core/configuration.sqf           AP_keyUpgradeCosts
    mission/.../core/housing/fn_upgradeProperty.sqf   barrel/greenhouse/lead costs
    server/.../core/system/fn_placeStorage.sqf   storage item -> crate classname
    mission/.../core/items/fn_miningAssemble.sqf the 8 rig components
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MISSION = REPO / "mission" / "Armapunk2035.Malden"
SERVER = REPO / "server" / "AP_server"

HOUSE_CFG = MISSION / "core" / "config" / "fn_houseConfig.sqf"
VIRT_CFG = MISSION / "core" / "config" / "fn_virtItemCfg.sqf"
CONFIGURATION = MISSION / "core" / "configuration.sqf"
UPGRADE_PROP = MISSION / "core" / "housing" / "fn_upgradeProperty.sqf"
# The carry-over refunds ALTIS houses (decision 2), and the Altis map had building types the Malden
# config never lists (first real dump, 2026-09-07: `Land_u_Addon_02_V1_F` had no price). The frozen
# LooneyBin house config is vendored as a fixture; its rows fill in only classnames Malden lacks.
EXTRA_HOUSE_CFGS = [Path(__file__).resolve().parent / "fixtures" / "altis_houseConfig.sqf"]
# Classnames that exist in the live `houses` table but in NO house config, priced as the building they
# are a variant of. `Land_u_Addon_02_V1_F` is the unfinished/derelict shell of `Land_i_Addon_02_V1_F`;
# one Altis owner holds it (house 1396518781). Refunding at the sibling's price beats refunding nothing.
# Full audit of the FINAL dump (529 rows, 35 classnames; 2026-09-07): six rows carry classnames that no
# house config ever priced and that `houses` stores no purchase price for. They are priced as the nearest
# configured building so the refund route pays SOMETHING defensible rather than nothing:
#   Land_i_Addon_03/03mid/04 (5 rows) -> Land_i_Addon_02 (40,000; the only Addon the Altis config priced)
#   Land_Kiosk_papers_F (1 row)       -> Land_Slum_House01_F (20,000; the cheapest tier on Altis)
HOUSE_CLASS_ALIASES = {
    "Land_u_Addon_02_V1_F": "Land_i_Addon_02_V1_F",
    "Land_i_Addon_03_V1_F": "Land_i_Addon_02_V1_F",
    "Land_i_Addon_03mid_V1_F": "Land_i_Addon_02_V1_F",
    "Land_i_Addon_04_V1_F": "Land_i_Addon_02_V1_F",
    "Land_Kiosk_papers_F": "Land_Slum_House01_F",
}
PLACE_STORAGE = SERVER / "core" / "system" / "fn_placeStorage.sqf"
MINING_ASSEMBLE = MISSION / "core" / "items" / "fn_miningAssemble.sqf"

OUT = Path(__file__).resolve().parent / "prices.py"


def _strip_comments(text: str) -> str:
    """Remove // and /* */ comments. Prices live in comments too ("$20k"), and a
    comment that happens to contain a number would otherwise be parsed as one."""
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def _ints(blob: str) -> list:
    """Parse a nested SQF numeric array literal into nested Python lists."""
    return eval(blob.replace(" ", "").replace("\n", ""), {"__builtins__": {}})  # noqa: S307 -- digits and brackets only, checked by the caller


def parse_house_config(path: Path) -> dict:
    """classname -> {buy, sell, phys, virt, upkeep}.

    Handles SQF `case` fall-through (`case "A"; case "B": {...}`), which is how
    the six colour variants of each Malden swap shell share one row. A parser
    that ignored it would silently price five of every six houses at zero.
    """
    text = _strip_comments(path.read_text(encoding="utf-8"))
    # the getHouses registry is a plain string list, not a price row
    text = re.sub(r'if \(_house == "getHouses"\).*?\};', " ", text, flags=re.S)

    out: dict[str, dict] = {}
    pending: list[str] = []
    # case "X";           -> fall-through, remember the name
    # case "X": {[...]};  -> the row, applies to X and every pending name
    token = re.compile(r'case\s+"([^"]+)"\s*(;|:\s*\{\s*(\[.*?\])\s*\}\s*;)', re.S)
    for m in token.finditer(text):
        name = m.group(1)
        if m.group(2) == ";":
            pending.append(name)
            continue
        row = _ints(m.group(3))
        if len(row) < 5:
            raise SystemExit("houseConfig row for %s has %d fields, expected 5" % (name, len(row)))
        buy, sell, phys, virt, upkeep = row[0], row[1], row[2], row[3], row[4]
        for cls in pending + [name]:
            out[cls] = {"buy": buy, "sell": sell, "phys": phys, "virt": virt, "upkeep": upkeep}
        pending = []
    if pending:
        raise SystemExit("houseConfig ends with unterminated fall-through: %s" % pending)
    if not out:
        raise SystemExit("houseConfig parsed to zero rows -- the format changed")
    return out


def parse_virt_items(path: Path) -> dict:
    """item id -> base/buy price (row index 7, per fn_virtItemCfg getBasePrice).

    Index 7 and not 6: `getBasePrice` reads `_row select 7`. Index 6 is the
    dynamic-market ceiling and index 8 the sell floor; picking either would
    quietly refund the wrong side of the spread.
    """
    text = _strip_comments(path.read_text(encoding="utf-8"))
    out: dict[str, int] = {}
    row = re.compile(r'\[\s*"([A-Za-z0-9_]+)"\s*,\s*"[^"]*"\s*,((?:\s*-?\d+\s*,){7})\s*-?\d+\s*,\s*"[^"]*"\s*\]')
    for m in row.finditer(text):
        nums = [int(n) for n in m.group(2).replace(" ", "").strip(",").split(",")]
        # nums = [weight, i3, i4, i5, i6, buy(idx7), sell(idx8)] -> buy is nums[5]
        out[m.group(1)] = nums[5]
    if not out:
        raise SystemExit("virtItemCfg parsed to zero rows -- the format changed")
    return out


def parse_key_costs(path: Path) -> list:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"AP_keyUpgradeCosts\s*=\s*(\[[\d,\s]*\])\s*;", text)
    if not m:
        raise SystemExit("AP_keyUpgradeCosts not found in configuration.sqf")
    return _ints(m.group(1))


def parse_upgrade_costs(path: Path) -> dict:
    text = _strip_comments(path.read_text(encoding="utf-8"))
    out = {}
    for var, key in (("_barrelCost", "barrel"), ("_greenhouseCost", "greenhouse"),
                     ("_leadContainerCost", "leadcontainer")):
        m = re.search(re.escape(var) + r"\s*=\s*(\d+)\s*;", text)
        if not m:
            raise SystemExit("%s not found in fn_upgradeProperty.sqf" % var)
        out[key] = int(m.group(1))
    return out


def parse_crate_map(path: Path) -> dict:
    """crate classname -> the virtual item that was spent to place it."""
    text = _strip_comments(path.read_text(encoding="utf-8"))
    out = {}
    for m in re.finditer(r'case\s+"([a-zA-Z0-9_]+)"\s*:\s*\{\s*_crate\s*=\s*"([^"]+)"\s*;', text):
        out[m.group(2)] = m.group(1)
    if not out:
        raise SystemExit("placeStorage crate switch not found")
    return out


def parse_rig_parts(path: Path) -> list:
    text = _strip_comments(path.read_text(encoding="utf-8"))
    m = re.search(r"_parts\s*=\s*\[((?:\s*\"[A-Za-z0-9_]+\"\s*,?)+)\]", text)
    if not m:
        raise SystemExit("mining rig _parts list not found")
    return re.findall(r'"([A-Za-z0-9_]+)"', m.group(1))


def render(houses, virt, keys, upgrades, crates, rig_parts) -> str:
    rig_cost = sum(virt[p] for p in rig_parts)
    missing = [p for p in rig_parts if p not in virt]
    if missing:
        raise SystemExit("rig components absent from virtItemCfg: %s" % missing)
    crate_prices = {}
    for crate, item in sorted(crates.items()):
        if item not in virt:
            raise SystemExit("placeStorage names item %r, absent from virtItemCfg" % item)
        crate_prices[crate] = virt[item]

    lines = [
        '"""Purchase prices, GENERATED from the game config by gen_prices.py. Do not edit.',
        "",
        "Decision 2 (DECISIONS.md) is refund at purchase price, so these are the",
        "numbers the refund is computed from. Regenerate after any price change:",
        "",
        "    python3 tools/pgmigrate/gen_prices.py",
        "",
        "Every value is an exact integer in source currency units.",
        '"""',
        "",
        "# house classname -> base purchase price (fn_houseConfig row 0)",
        "HOUSE_BUY = {",
    ]
    for cls in sorted(houses):
        lines.append("    %r: %d," % (cls, houses[cls]["buy"]))
    lines.append("}")
    lines.append("")
    lines.append("# house classname -> [[cap, price], ...] storage tiers. Tier 0 is the BASE cap,")
    lines.append("# seeded free with the house (fn_handleHouse), so its price was never paid.")
    lines.append("HOUSE_PHYS_TIERS = {")
    for cls in sorted(houses):
        lines.append("    %r: %r," % (cls, houses[cls]["phys"]))
    lines.append("}")
    lines.append("")
    lines.append("HOUSE_VIRT_TIERS = {")
    for cls in sorted(houses):
        lines.append("    %r: %r," % (cls, houses[cls]["virt"]))
    lines.append("}")
    lines.append("")
    lines.append("# fn_upgradeProperty purchase costs -- NOT the resale figures fn_houseMenu shows")
    lines.append("HOUSE_UPGRADES = {")
    for k in sorted(upgrades):
        lines.append("    %r: %d," % (k, upgrades[k]))
    lines.append("}")
    lines.append("")
    lines.append("# AP_keyUpgradeCosts: cost of the Nth extra key slot, index = slots already held")
    lines.append("KEY_SLOT_COSTS = %r" % (keys,))
    lines.append("")
    lines.append("# storage.classname is the spawned crate; this is what the player spent to place it")
    lines.append("STORAGE_CRATE_BUY = {")
    for crate in sorted(crate_prices):
        lines.append("    %r: %d,   # %s" % (crate, crate_prices[crate], crates[crate]))
    lines.append("}")
    lines.append("")
    lines.append("# a mining rig is assembled from 8 components, never bought; this is their total")
    lines.append("RIG_COMPONENTS = %r" % (rig_parts,))
    lines.append("RIG_BUY = %d" % rig_cost)
    lines.append("")
    lines.append("# ATM skimmer, bought outright from the rebel dealer")
    lines.append("SKIMMER_BUY = %d" % virt["atmskimmer"])
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit 1 if prices.py is stale")
    args = ap.parse_args()

    houses = parse_house_config(HOUSE_CFG)
    for extra in EXTRA_HOUSE_CFGS:
        for cls, row in parse_house_config(extra).items():
            houses.setdefault(cls, row)
    for alias, real in HOUSE_CLASS_ALIASES.items():
        if real not in houses:
            raise SystemExit("HOUSE_CLASS_ALIASES: %s -> %s, but %s is not in any house config" % (alias, real, real))
        houses.setdefault(alias, houses[real])
    text = render(
        houses,
        parse_virt_items(VIRT_CFG),
        parse_key_costs(CONFIGURATION),
        parse_upgrade_costs(UPGRADE_PROP),
        parse_crate_map(PLACE_STORAGE),
        parse_rig_parts(MINING_ASSEMBLE),
    )
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("prices.py is STALE -- rerun gen_prices.py", file=sys.stderr)
            return 1
        print("prices.py is current")
        return 0
    OUT.write_text(text, encoding="utf-8")
    print("wrote %s" % OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
