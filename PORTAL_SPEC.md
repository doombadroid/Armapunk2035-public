# Armapunk portal — repurposing the LooneyBin stats site for armapunk.com

Owner 2026-09-09: "find the loonybin website source code we're going to re-purpose it for
armapunk" → decisions: **merge into armapunk.com** (replaces the teaser landing page; hero video
and sound logic dropped — "it was just for the teaser page"), **keep every page**, **reskin to the
Armapunk cyberpunk look**. Plan: `portal_plan.md`. Lives at the repo root (`docs/` is ignored).

## What exists (verified 2026-09-09)

- Source: `website/` in this repo — Next.js 16.2.9, React 19, Tailwind v4, `pg` (Phase W
  2026-08-20 ported it from mysql2; the README still says mysql2). 27 pages, 8 API routes, Steam
  OpenID login, hybrid data model (read-only game tables + own `web_*` tables). Builds clean on
  node 26 locally.
- Old deployment `.96:~/loonybin-website` (7/13 MySQL build): `loonybin-stats.service` **failed**,
  `looneybin-db` exited 47 h ago, projectloonybin.com retired. Dead; nothing to keep but env keys.
- Teaser `.96:~/armapunk-site` (`serve.js`, zero-dep static server on 127.0.0.1:3010, unit
  `armapunk-site.service`, system unit `armapunk-tunnel` → armapunk.com/www → :3010). Not in git.
  Since 2026-09-09 11:33 it also serves the **Eden Live designer kits** under `/kits/<32-hex>/…`
  behind per-designer Basic auth (`~/.config/armapunk/edenlive.kitauth`), which EdenLive tooling
  depends on. That path survives; the teaser page does not.
- Database `armapunk` on `armapunk-pg` already holds all 11 `web_*` tables (copied with the dev
  schema) and every game table the site reads. Only role: `armapunk` (owner).
- **`players.instance` is 0 for all 570 rows**; the site defaults `DB_INSTANCE=1` → must be 0.
- Malden satellite: `scratchpad/sat_atlas/malden_sat256.png`, 3328 × 3328, full island
  (0–12,800 m, `map.html` `MAP_M = 12800`). The site's HouseMap is hard-coded to an Altis crop.
- Branding: 30 `LooneyBin/Loonybin/Altis/projectloonybin` hits in 8 source files + the docs
  (`README.md`, `PRODUCT.md`, `DESIGN.md`). Item generators `website/tools/gen_*_items.js`
  point at the dead `mission/LooneyBin.Altis` path (HANDOFF "Open").
- Teaser look: Michroma (display) + Space Mono, cyan `#05d9e8` (dominant), magenta `#ff2a6d`,
  near-black `#050302`, cream `#fff8ea`. Deck UI: ink `#dbe6f2`, dim `#7d8b9e`, amber `#f5a623`,
  ice `#54b0ff`, magenta `#ff3d81`, danger `#ff4d4d`. The portal's `DESIGN.md` already has a
  runtime-switchable accent ramp (`[data-theme]`, amber default) — the reskin adds a cyan ramp
  and makes it the default; layouts stay.

## Design

1. **Hosting.** Portal = user unit `armapunk-portal.service`, `next start` on `127.0.0.1:3011`,
   tree at `.96:~/armapunk-portal` (rsync from `website/`, `npm ci`, `npm run build` on the box).
   Cloudflared ingress for `armapunk.com` + `www`: **path rule `^/kits/` → :3010** (serve.js
   keeps the designer kits), everything else → :3011. Cutover = that ingress edit + tunnel
   restart; rollback = revert it. `armapunk-site.service` stays up for `/kits/` only; its
   `index.html`, `hero.mp4`, `poster.jpg` are retired (moved aside, not deleted).
2. **Home.** The portal's existing home (server status, top rankings, wanted, gangs) is the
   landing page. No video, no autoplay logic.
3. **Rebrand.** `NEXT_PUBLIC_SITE_NAME="Armapunk 2035"`; every hit in the 8 files; `proxy.ts`
   allowed hosts → `armapunk.com`/`www.armapunk.com`; docs rewritten; the "Loony Bin Breached"
   leaderboard key keeps its data mapping but reads "Loony Bin Breached" only if the fork still
   has that heist (it does — the Loony Bin heist survived the fork). Generators repointed to
   `mission/Armapunk2035.Malden` and re-run so `compItems.ts` / `houseItems.ts` are generated
   again instead of hand-maintained.
4. **HouseMap on Malden.** `public/malden-map.jpg` from the 256-tier atlas (full island), world
   size 12,800, no crop offsets. Coordinates come straight from `houses.pos`.
5. **Reskin.** `globals.css`: cyan accent ramp as the default theme (`#05d9e8` at 400/500),
   surfaces shifted from `gray-950` to the teaser's near-black with a blue-black tint, magenta as
   the brand flourish, danger red unchanged. Fonts via `next/font/google`: Michroma for the
   wordmark and page titles, Space Mono for data (numbers, ids, tables), system sans for body.
   Nav wordmark "ARMAPUNK 2035". Home hero copy rewritten for Malden 2035. Nothing else moves.
6. **Data.** New role `armapunk_web` (`website/sql/pg/role_web.sql`): `SELECT` on every table,
   `INSERT/UPDATE/DELETE` on `web_*`, `UPDATE (coplevel, mediclevel)` on `players_global`. The
   site connects as that role; `DB_INSTANCE=0`. `ranks.ts` stat indexes re-checked against the
   fork's `fn_requestReceived.sqf` (A_stats layout unchanged).
7. **Auth.** Steam OpenID realm `SITE_URL=https://armapunk.com`, `STEAM_API_KEY` reused from the
   old env, fresh `SESSION_SECRET`, `OWNER_STEAMID=76561190000000001`. `BM_TOKEN` optional (the
   VPN page degrades to "not configured").
8. **Deploy kit.** `website/deploy/push-96.sh` (rsync excluding node_modules/.next/.env*, build
   on the box, restart unit, curl smoke of 6 pages), `deploy/systemd/armapunk-portal.service`,
   `.env.local` on the box (0600), old `website/deploy/{looneybin-stats,cloudflared-looneybin,
   nginx-projectloonybin.conf}` deleted.

## Order and gates

rebrand + data + deploy kit (live on :3011, verified against the real DB) → reskin → **ingress
cutover only on the owner's explicit go**. Each stage: `npm run build` clean, `curl` of every
page on the box returns 200 (login page renders; Steam round-trip needs a browser), no
`LooneyBin|Altis` left in `src/` except the heist name, HouseMap shows Malden houses in place.

## Residual decisions taken

- `serve.js` stays for `/kits/` rather than porting the auth into Next: EdenLive's tooling owns
  that contract and its edge cases (revocation, no-store caching).
- Teaser assets retired, not deleted (`~/armapunk-site/retired-teaser/`).
- Accent = cyan (the public brand colour), not the deck's amber; the deck palette supplies the
  neutrals and the magenta/danger semantics.

## Status 2026-09-09 21:30 CDT

Tasks 1–5 done and **live on `.96:3011`** (commit `c913abf5`): rebrand, Malden HouseMap,
regenerated item tables, `armapunk_web` role, deploy kit, reskin. The deploy smoke renders the
public home, the login page, and all 21 gated routes as the owner (minted session) against the
live database: 23/23 → 200. Found and fixed on the way: five MySQL-isms that survived the 8/20
port (`HAVING <alias>`, `JSON_VALID`, `INTERVAL 7 DAY`), four unquoted camelCase aliases folding
to lower case, three boolean-vs-integer comparisons, and `DB_INSTANCE` (live rows are instance 0).

**Task 6 (cutover) DONE 21:40 CDT on the owner's "go".** Ingress: `/kits(/|$)` → :3010, rest → :3011
(backup `~/.cloudflared/armapunk.yml.bak-pre-portal-*`), tunnel restarted, teaser assets moved to
`~/armapunk-site/retired-teaser/`. Edge-verified: `/` 200 with the portal title, `/players` 307 →
`/login`, `/kits/…` 401, `www` 308 → apex, grafana and missions unchanged. Rollback = restore the
backup and restart the tunnel.
