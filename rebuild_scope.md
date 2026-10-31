# LooneyBin — Clean Rebuild Scope

Working checklist for moving off Asylum-derived code onto a **legitimately-licensed Altis Life
base**, rewriting only the parts that carry real copyright risk. Companion to `legal.md`.

_Created 2026-06-08._

## The rule (why this list exists)

- The law judges the **artifact**, not your process: infringement = access + **substantial
  similarity of protected expression**. You've seen the code (access is conceded), so the only
  thing that matters is whether your version **shares fingerprints** with theirs.
- **~80% of the codebase is standard/community Altis Life or function-dictated** — unprotectable,
  converges no matter how you write it. Keep it or take it nearly free from a licensed base.
- **~15–20% is Asylum-original creative work.** For those, **rewrite from behavior**: write down
  *what it does*, close their file, implement fresh on the licensed base, then check you didn't
  mirror their structure.
- **Fingerprint test** for each rewritten system: line-for-line parallel to theirs = you
  transformed it (redo). Organized differently, every structural choice explainable as *yours* =
  you rewrote it (good).

## The data trap

For configs — talent/prestige trees, quest/achievement sets, cartel/turf layouts — the individual
numbers aren't protectable, but a complex **selection-and-arrangement** (their exact 36-node talent
tree with these prereqs/costs) can be protected as a **compilation**. **Redesign the structure;
never copy-and-tweak.** "A cop prestige tree" = free idea. *Their* tree = the fingerprint.

---

## 🔴 Distinctive — rewrite from behavior (highest risk)

- [ ] **Progression: prestige + talents + infamy + honor** — `core/talents` (13) + the **trees** in
      `core/config/fn_talentCfg`, `fn_prestigeCfg` + prestige/talent menus. Most recognizable Asylum
      system. Redesign the tree (nodes/prereqs/costs/specialties), not just the menu code.
- [ ] **Gangs (deep) + fortress + turf** — `core/gangs` (43) + `core/gangfort` (4) + gang logic in
      `server/TON`. Gang funds, wars, gang talents, fortress capture, turf control. Biggest chunk.
- [ ] **Cartels / capture / conquest meta** — `server/system` cartel+capture monitors
      (`fn_monitorCaptures`, cartel loops) + capture actions + turf/cartel flags. The territory
      endgame.
- [ ] **Heist / objective designs** — `server/bank` (2) + Fed Reserve + Evidence Lockup + Jewelry
      Emporium + Bank of Altis + vault-hack + prison break + mental hospital. The mechanics +
      choreography (gates, alarms, hack steps, defense systems, payouts); layouts live in
      `fn_mapData`.
- [ ] **Bounty Hunter / Skiptracer / Honor** — `core/bounty` (8) + honor talents + skiptracer.

## 🟡 Semi — standard shell, Asylum guts to redesign

- [ ] **Governor / Politics** — `core/gov` (8) + `server/politics` (5). Redesign gov *mechanics*;
      voting/UI plumbing is generic.
- [ ] **Resource Exchange** — `core/exchange` (9). Rebuild matching/listing logic; keep generic UI.
- [ ] **Wanted / Warrant Squad** — `server/wantedsys` (9) + distinctive slice of `core/cop`
      (warrant squad, profiteer, SCD/prestige gear — ~15 of 55). Core arrest/restrain/ticket
      is standard (🟢); the progression-linked cop features are theirs.
- [ ] **Stats / Titles / Achievements / Quests** — `core/quests` (7) + achievements + titles +
      `APV_stats`. Redesign the *set* (compilation), values are free.
- [ ] **Drugs / addiction effects** — `core/drugs` (10). Loop is standard AL; addiction/effect
      system is Asylum-flavored. Low-ish.

## 🟢 Standard Altis Life — keep / light-touch (~80%, low risk)

`session` (login/save) · `DB` (extDB/Tonic layer + your fixes) · `inventory` · `shops` ·
`vehicle` (spawn/garage/keys/lockpick) · `housing` · `groups` · `medical` core · `items`/food ·
basic gathering/processing · money/ATM/bank-account/paycheck · `licenses` · `pmenu`/map/markers ·
`admin` tools · `compat` (your own 2017↔2020 merge work) · most `dialog/*.hpp` (functional UI
layouts, thin protection).

Shared community AL or dictated-by-function. Independent and transformed versions converge; little
to none of it is ownable. Take from the licensed base.

---

## Weight estimate

gangs+fortress (~47) · talents (13) · bounty (8) · gov+politics (13) · exchange (9) · quests (7) ·
wantedsys (9) · bank (2) · cartel/capture (~15) · cop-distinctive (~15) · the trees
≈ **~150–165 of ~1,100 files (~15%)**, plus the heist/location *designs*. The 🟢 80% comes nearly
free on a licensed base.

## Process checklist (per 🔴/🟡 system)

1. [ ] Write a behavior spec (inputs / outputs / mechanic / state) from how it *plays*, not from their source.
2. [ ] Close their file. Implement fresh on the licensed base.
3. [ ] Fingerprint-check: structure differs, no shared magic numbers / quirks / bugs / decomposition.
4. [ ] For configs: redesign the tree/set structure, don't port it.
5. [ ] Note it done here + keep a short record of how you built it.

## Foundation (do first)

- [ ] Pick the licensed base (Tonic's licensed AL release / a maintained open framework). Confirm its license terms.
- [ ] Stand up the 🟢 base, get a server booting.
- [ ] Then port 🔴/🟡 systems one at a time, highest-distinctiveness first.

> Not legal advice — see `legal.md`. Before any serious/public/monetized launch, run it past an IP lawyer.
