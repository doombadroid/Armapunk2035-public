# Armapunk 2035 portal

A self-hosted stats & community portal for the Armapunk 2035 (Malden) server — a
clean-room, from-scratch stats site, **minus the Stripe store**.

Built with **Next.js 16** (App Router, React 19, server components), **Tailwind
CSS v4**, **pg** (PostgreSQL, since 2026-08-20), Steam OpenID login, and a `lucide-react` / `sonner` UI.

## Features

Game data (read-only from the live `armapunk` PostgreSQL DB):
- **Players** — searchable directory + rich player detail (wallet, civ/cop/medic
  XP & playtime, ranks, gang, houses, vehicle garage, mailbox, alias history,
  recent activity feed from the `log` table)
- **Leaderboard** — civ/cop/medic XP, bank, honor, infamy
- **Gangs** — lookup + detail (members, bank, XP, wars, fortress wins)
- **Gang Territories** — cartels, turf, capture points, Gang Fortress
- **Governor Election** — live vote tally
- **Bounty Board** — current wanted list
- **MaxSec** — roster by rank + application review queue (staff-gated)

Site-native (own `web_*` tables, Steam-auth gated writes):
- **Support Tickets** — open/track/reply, staff can answer & close
- **Feature Voting** — suggest features, one vote each, staff set status
- **Changelogs** — markdown posts (editors)
- **Wiki** — categorized markdown pages (editors edit, everyone reads)

Plus: Ctrl-K command palette search, runtime theme switcher (amber/blue/
emerald/rose/violet), collapsible sidebar.

## Setup

```bash
cd website
npm install
cp .env.example .env.local   # then edit values
```

Apply the site-native tables once (the game tables already exist):

```bash
mysql -u root looneybin < sql/web_schema.sql
```

### Environment (`.env.local`)

| var | meaning |
|-----|---------|
| `DB_HOST/PORT/USER/PASSWORD/NAME` | live `looneybin` MySQL connection |
| `DB_INSTANCE` | server instance id (live = `1`) for the `online` presence table |
| `SESSION_SECRET` | 64-hex string signing the session JWT (`openssl rand -hex 32`) |
| `SITE_URL` | public origin, e.g. `https://stats.yourdomain.com` (Steam OpenID realm + return URL) |
| `STEAM_API_KEY` | *optional* — enables real Steam display names/avatars |
| `OWNER_STEAMID` | owner UID, granted editor/staff everywhere |
| `NEXT_PUBLIC_SITE_NAME` | brand shown in UI |
| `NEXT_PUBLIC_DISCORD_URL` | Discord invite for the topbar button |

### Recommended DB user (production)

Don't point the site at the game's full-privilege DB user. Create a
least-privilege one (read-all, write only `web_*`):

```bash
mysql -u root < sql/web_user_grants.sql   # edit the password first
```

## Run

```bash
npm run dev                       # http://localhost:3000 (Turbopack)
npm run build && npm run start    # production
```

### Deploy (behind Cloudflare, like the original)

1. `npm run build`, then `npm run start` (default port 3000) under a process manager.
2. Reverse-proxy your domain → `127.0.0.1:3000` (nginx/caddy), Cloudflare in front.
3. Set `SITE_URL` to the public `https://` origin so Steam OpenID returns correctly.

OpenRC service (this box uses OpenRC) — `/etc/init.d/armapunk-portal`:

```sh
#!/sbin/openrc-run
name="armapunk-portal"
command="/usr/bin/npm"
command_args="run start"
command_background=true
directory="/home/timb/armapunk-portal"
pidfile="/run/armapunk-portal.pid"
output_log="/var/log/armapunk-portal.log"
error_log="/var/log/armapunk-portal.log"
depend() { need net; after mysql; }
```

`rc-update add armapunk-portal default && rc-service armapunk-portal start`

## Data-layer notes

- Arma TEXT columns (gear, inventory, mailbox, keyholders, stats) are
  mres/str2-encoded; `src/lib/arma.ts` decodes them (byte-identical to the
  validated `loonybot/enrique.py` routine).
- Playtime lives in `players_global.stats` (the 17-int `A_stats`): civ=`[11]`,
  cop=`[14]`, med=`[15]`, in minutes (pinned from `fn_requestReceived.sqf`).
- Rank names & stat indices are pinned from the game SQF in `src/lib/ranks.ts`.
- The donor system was stripped from the LooneyBin era, so there is no donor badge.
