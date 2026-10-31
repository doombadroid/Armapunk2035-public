# Armapunk portal plan (2026-09-09) — spec `PORTAL_SPEC.md`

> Executed inline in one session; checkboxes track progress. No test harness exists for the site
> beyond `npm run build` (TS + lint) and HTTP smoke, so every task's red state is an observed
> failure of those.

### Task 1: rebrand + config
- Files: `website/src/{proxy.ts,app/layout.tsx,app/login/page.tsx,app/page.tsx,lib/arma.ts,components/WikiIndex.tsx,components/Sidebar.tsx,lib/bm.ts,lib/leaderboards.ts}`, `website/{README,PRODUCT,DESIGN,AGENTS,CLAUDE}.md`, `website/tools/gen_*_items.js` → regenerate `src/lib/{compItems,houseItems}.ts`.
- [x] Red: `grep -rniE 'loonybin|looneybin|altis|projectloonybin' website/src` ≠ 0 lines. Green: only the heist label remains. `npm run build` exit 0.

### Task 2: HouseMap on Malden
- Files: `website/public/malden-map.jpg` (from `scratchpad/sat_atlas/malden_sat256.png`), `website/src/components/HouseMap.tsx`.
- [x] Red: component references `altis-map.jpg` and Altis bounds. Green: world 12800, image swapped, build clean, a known house (from `houses.pos`) lands on its town in the rendered page.

### Task 3: database role
- Files: `website/sql/pg/role_web.sql`. Apply on .96 (`docker exec armapunk-pg psql`), password in the box's `.env.local` only.
- [x] Red: role absent. Green: `psql -U armapunk_web` can SELECT players, INSERT web_tickets, and is refused UPDATE players.cash.

### Task 4: deploy kit + first live build on :3011
- Files: `website/deploy/push-96.sh`, `deploy/systemd/armapunk-portal.service`, delete the LooneyBin deploy files. On the box: `~/armapunk-portal`, `.env.local`, unit enabled.
- [x] Red: `curl 127.0.0.1:3011/` connection refused. Green: `/`, `/players`, `/leaderboard`, `/gameserver/gangs`, `/bounties`, `/login`, `/wiki` → 200 with real rows; journal clean.

### Task 5: reskin
- Files: `website/src/app/{globals.css,layout.tsx,page.tsx}`, `website/src/components/Sidebar.tsx` (+ any nav component), `website/DESIGN.md`.
- [x] Green: build clean, cyan default theme, Michroma/Space Mono loaded (network fonts self-hosted by next/font), home hero reads Armapunk 2035 / Malden. Redeploy :3011.

### Task 6: cutover (owner go required)
- `~/.cloudflared/armapunk.yml`: `armapunk.com` + `www` → path `^/kits/` → :3010, else → :3011; `sudo systemctl restart armapunk-tunnel`; move teaser assets to `~/armapunk-site/retired-teaser/`.
- [x] Green: `https://armapunk.com/` = portal, `https://armapunk.com/kits/` still 401, missions/grafana untouched.

### Task 7: records
- [x] `PORTAL_SPEC.md` findings, memory `armapunk-portal.md` + index line, HANDOFF "Open" item about the generators closed.
